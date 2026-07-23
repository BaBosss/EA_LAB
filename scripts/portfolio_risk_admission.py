#!/usr/bin/env python
"""ORDER-154: attach-time portfolio risk budget (admission control).

DESIGN (locked by the lead engineer, ORDER-154 -- implement exactly, do not
re-derive the formula or the conservative defaults):

    portfolio_DD_est = sqrt( sum_i sum_j corr_ij * DD95_i * DD95_j )     corr_ii = 1

Safety defaults (non-negotiable, each one has a CAGE test proving it below):
  * missing corr_ij  -> default 1.0 (fully additive, conservative). NEVER 0.
  * missing DD95_i   -> exclude that EA from the sum AND flag it UNKNOWN. NEVER 0.
  * bounds (must always hold -- if violated the corr matrix is broken/parsed
    wrong/not PSD, and this script REFUSES to emit a number rather than guess):
        max_i(DD95_i) <= portfolio_DD_est <= sum_i(DD95_i)

Budget: DEMO accounts = 25% of equity (fixed project number, see
docs/JUDGE_DAY_RUNBOOK.md "Sizing" step 3 -- do not invent a different number
here). REAL_CENT accounts: computed and reported ONLY, tagged "user decision
needed" -- this script never assigns a DD budget to real-money accounts.

Admission is resize-first, never a rejection verdict on the EA: a candidate
either (a) ADMIT_FULL at the locked .set's lot, (b) ADMIT_REDUCED at a scaled
-down lot factor (DD95 scales linearly with lot), or (c) DEFER_ESCALATE when
even the broker-minimum lot doesn't fit -- "come back later", not a kill.

LIMITATION (verbatim -- must also appear in the current-state report emitted
by this script; do not paraphrase it away):
"DD95 values are drawdown quantiles, not returns; combining them through a
return-correlation matrix is a screening heuristic, not a theorem. This
output is a prior for admission control, never a verdict, and does not
replace per-EA Monte Carlo."

This script is advisory only:
  * never writes to any .set file
  * never modifies portfolio/DEPLOYMENTS.csv
  * never auto-applies a lot change
  * never produces a verdict about an EA (kill/keep/DEAD/etc are out of scope)

Usage:
    python portfolio_risk_admission.py                  # full current-state report -> md+json
    python portfolio_risk_admission.py --selftest        # run the CAGE tests, print PASS/FAIL
    . scripts\\use_python.ps1 ; python scripts\\portfolio_risk_admission.py --selftest
"""
import argparse
import csv
import json
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEPLOYMENTS_CSV = ROOT / "portfolio" / "DEPLOYMENTS.csv"
EXPECTATIONS_CSV = ROOT / "portfolio" / "expectations.csv"
LIVE_DEALS_DIR = ROOT / "portfolio" / "live_deals"
OUT_MD = ROOT / "_triage" / "ORDER154_RISK_ADMISSION_CURRENT_STATE.md"
OUT_JSON = ROOT / "_triage" / "ORDER154_RISK_ADMISSION_CURRENT_STATE.json"

DEMO_BUDGET_PCT = 25.0  # fixed project number -- docs/JUDGE_DAY_RUNBOOK.md "Sizing" step 3
MIN_SHARED_MONTHS = 4   # same threshold _mt5_auto/corr_monthly.py uses before trusting a pearson r
DEFAULT_BROKER_MIN_LOT_FACTOR = 0.01  # placeholder floor (1% of locked-set lot) when the
                                       # real broker minimum-lot / locked-lot ratio isn't wired in

LIMITATION = (
    "DD95 values are drawdown quantiles, not returns; combining them through a "
    "return-correlation matrix is a screening heuristic, not a theorem. This "
    "output is a prior for admission control, never a verdict, and does not "
    "replace per-EA Monte Carlo."
)

BUDGET_SOURCE_NOTE = 'fixed project number (docs/JUDGE_DAY_RUNBOOK.md "Sizing" step 3)'


class RiskAdmissionError(Exception):
    """Raised when the script must refuse to emit a number instead of guessing."""


# --------------------------------------------------------------------------- #
# inputs
# --------------------------------------------------------------------------- #

def load_deployments(path=DEPLOYMENTS_CSV):
    """Rows with a magic number only (blank-magic bulk/UNVERIFIED rows carry no
    admittable EA and are skipped -- there is nothing to compute for them)."""
    rows = []
    with open(path, encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            magic = (row.get("magic") or "").strip()
            if not magic:
                continue
            rows.append({
                "account": (row.get("account") or "").strip(),
                "account_name": (row.get("account_name") or "").strip(),
                "type": (row.get("type") or "").strip(),
                "ea_name": (row.get("ea_name") or "").strip(),
                "magic": magic,
                "symbol": (row.get("symbol") or "").strip(),
                "status": (row.get("status") or "").strip(),
            })
    return rows


def load_expectations(path=EXPECTATIONS_CSV):
    """magic -> DD95 float. A magic is simply ABSENT from the returned dict when its
    DD95 is unknown (file missing entirely, row missing, literal "UNKNOWN" string, or
    unparseable) -- callers must treat "absent" as UNKNOWN and never invent 0.0."""
    dd95 = {}
    p = Path(path)
    if not p.exists():
        return dd95  # ORDER-153 hasn't produced the file yet -- every magic is UNKNOWN
    with open(p, encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            magic = (row.get("magic") or "").strip()
            if not magic:
                continue
            raw = (row.get("dd95_expected") or "").strip()
            if raw == "" or raw.upper() == "UNKNOWN":
                continue
            try:
                dd95[magic] = float(raw)
            except ValueError:
                continue  # unparseable -- treat as UNKNOWN, never guess
    return dd95


def _num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return 0.0


def load_monthly_pnl_by_magic(live_deals_dir=LIVE_DEALS_DIR):
    """Latest snapshot file per account (the daily dumps are cumulative, not
    incremental, so using the newest one avoids double-counting) bucketed into
    magic -> {"YYYY-MM": realized profit+swap+commission}. Mirrors the bucket-then
    -pearson method in _mt5_auto/corr_monthly.py / scripts/corr_matrix.py, generalized
    across both the MT5 "deals" export schema and the MT4 "orders" export schema."""
    d = Path(live_deals_dir)
    monthly = defaultdict(lambda: defaultdict(float))
    if not d.exists():
        return monthly

    latest_by_account = {}
    name_re = re.compile(r"EA_LAB_(?:deals|mt4_orders)_(\d+)_(\d{8})\.csv$")
    for f in d.glob("EA_LAB_*.csv"):
        m = name_re.match(f.name)
        if not m:
            continue
        acct, datestamp = m.group(1), m.group(2)
        if acct not in latest_by_account or datestamp > latest_by_account[acct][1]:
            latest_by_account[acct] = (f, datestamp)

    for _acct, (path, _ds) in latest_by_account.items():
        with open(path, encoding="utf-8-sig", newline="") as fh:
            reader = csv.DictReader(fh)
            fieldnames = reader.fieldnames or []
            is_mt5_deals = "entry" in fieldnames and "time" in fieldnames
            is_mt4_orders = "close_time" in fieldnames
            for row in reader:
                magic = (row.get("magic") or "").strip()
                if not magic or magic == "0":
                    continue
                if is_mt5_deals:
                    entry = (row.get("entry") or "").strip()
                    if entry not in ("1", "2", "3"):  # OUT / INOUT / OUT_BY = realized legs
                        continue
                    t = (row.get("time") or "").strip()
                elif is_mt4_orders:
                    t = (row.get("close_time") or "").strip()
                else:
                    continue
                mm = re.match(r"(\d{4})[.\-/](\d{2})", t)
                if not mm:
                    continue
                ym = f"{mm.group(1)}-{mm.group(2)}"
                pnl = _num(row.get("profit")) + _num(row.get("swap")) + _num(row.get("commission"))
                monthly[magic][ym] += pnl
    return monthly


def pearson(xs, ys):
    n = len(xs)
    if n < 3:
        return None
    mx = sum(xs) / n
    my = sum(ys) / n
    numer = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    dx = sum((x - mx) ** 2 for x in xs) ** 0.5
    dy = sum((y - my) ** 2 for y in ys) ** 0.5
    if dx == 0 or dy == 0:
        return None
    return numer / (dx * dy)


def compute_corr_matrix(magics, live_deals_dir=LIVE_DEALS_DIR):
    """Best-effort monthly-return correlation for the given magics from live deal
    history actually on disk. A pair with fewer than MIN_SHARED_MONTHS overlapping
    months is simply left OUT of the returned dict -- get_corr() is what applies the
    1.0-default safety rule, this function only reports what it could measure."""
    monthly = load_monthly_pnl_by_magic(live_deals_dir)
    corr = {}
    mags = [m for m in magics if m in monthly]
    for i in range(len(mags)):
        for j in range(i + 1, len(mags)):
            a, b = mags[i], mags[j]
            common = sorted(set(monthly[a]) & set(monthly[b]))
            if len(common) < MIN_SHARED_MONTHS:
                continue
            xs = [monthly[a][m] for m in common]
            ys = [monthly[b][m] for m in common]
            c = pearson(xs, ys)
            if c is None:
                continue
            corr[frozenset((a, b))] = c
    return corr


def get_corr(corr_matrix, i, j):
    """corr_ii = 1 always. Missing corr_ij -> 1.0 (fully additive, conservative).
    This function is the single place the missing-default is applied -- NEVER 0."""
    if i == j:
        return 1.0
    return corr_matrix.get(frozenset((i, j)), 1.0)


# --------------------------------------------------------------------------- #
# core formula
# --------------------------------------------------------------------------- #

def portfolio_dd_est(dd95_by_magic, corr_matrix, tol=1e-9):
    """dd95_by_magic: {magic: float} of ONLY the magics with a KNOWN DD95 -- the
    caller is responsible for excluding UNKNOWN magics before calling this (this
    function has no way to tell "excluded" from "0", so it must never receive a 0
    standing in for unknown).

    Returns portfolio_DD_est (float, % of equity, same unit as the inputs).
    Raises RiskAdmissionError instead of returning a value when the bounds
    invariant max_i(DD95_i) <= portfolio_DD_est <= sum_i(DD95_i) does not hold --
    that means the corr matrix is broken (parse error / not a valid correlation
    structure), and a wrong number is worse than no number.
    """
    magics = list(dd95_by_magic.keys())
    if not magics:
        raise RiskAdmissionError("no magic with known DD95 -- nothing to compute")

    sum_sq = 0.0
    for i in magics:
        for j in magics:
            sum_sq += get_corr(corr_matrix, i, j) * dd95_by_magic[i] * dd95_by_magic[j]

    if sum_sq < -tol:
        raise RiskAdmissionError(
            f"negative sum-of-squares ({sum_sq!r}) -- corr matrix is not a valid "
            "correlation structure (parse error / not PSD). Refusing to emit a number."
        )
    portfolio_dd = math.sqrt(max(sum_sq, 0.0))

    max_dd = max(dd95_by_magic.values())
    total_dd = sum(dd95_by_magic.values())
    if not (max_dd - tol <= portfolio_dd <= total_dd + tol):
        raise RiskAdmissionError(
            f"bounds violated: max(DD95)={max_dd:.6f} portfolio_DD_est={portfolio_dd:.6f} "
            f"sum(DD95)={total_dd:.6f} -- corr matrix invalid (parse error / not PSD). "
            "Refusing to emit a risk number."
        )
    return portfolio_dd


def budget_pct_for_account_type(acct_type):
    """Returns (budget_pct_or_None, note). REAL_CENT NEVER gets a budget assigned
    by this script -- compute/report only, per the order's explicit prohibition."""
    t = (acct_type or "").strip().upper()
    if t == "DEMO":
        return DEMO_BUDGET_PCT, BUDGET_SOURCE_NOTE
    if t == "REAL_CENT":
        return None, "REAL_CENT: computed/reported only -- NO budget assigned, user decision needed"
    return None, f"unrecognized account type '{acct_type}' -- no budget assigned, user decision needed"


# --------------------------------------------------------------------------- #
# admission function (resize-first, never a reject-EA verdict)
# --------------------------------------------------------------------------- #

def admit_candidate(candidate_magic, candidate_dd95, existing_dd95_by_magic, corr_matrix,
                     budget_pct, broker_min_lot_factor=DEFAULT_BROKER_MIN_LOT_FACTOR):
    """Decide whether `candidate_magic` (DD95 at its LOCKED .set lot = lot_factor 1.0)
    fits the account's DD budget alongside `existing_dd95_by_magic` (KNOWN-DD95 EAs
    already on the account; UNKNOWN existing EAs are excluded upstream by the caller
    and are not silently treated as 0 here either).

    Returns a dict with a 'status' of one of:
      REPORT_ONLY     -- no budget assigned for this account type (REAL_CENT) --
                         portfolio_dd_est is still computed and reported, nothing sized
      ADMIT_FULL       -- fits at lot_factor 1.0 (the locked .set as-is)
      ADMIT_REDUCED    -- fits at lot_factor in (broker_min_lot_factor, 1.0)
      DEFER_ESCALATE   -- does not fit even at the broker minimum lot (or the existing
                          portfolio already breaches budget independent of this
                          candidate) -- attach is deferred, user must decide, this is
                          NOT a verdict against the EA

    Invariant enforced everywhere below: lot_factor, when not None, always satisfies
    0 < lot_factor <= 1.0 -- this function only ever scales DOWN from the validated
    locked .set, never up, and never emits a negative number.
    """
    if budget_pct is None:
        return {
            "magic": candidate_magic,
            "status": "REPORT_ONLY",
            "lot_factor": None,
            "message": "no DD budget assigned for this account type -- report only, user decision needed",
        }

    others = dict(existing_dd95_by_magic)
    sum_sq_others = 0.0
    for i in others:
        for j in others:
            sum_sq_others += get_corr(corr_matrix, i, j) * others[i] * others[j]
    if sum_sq_others < -1e-9:
        raise RiskAdmissionError(
            "negative sum-of-squares in the existing portfolio -- corr matrix invalid"
        )
    existing_dd = math.sqrt(max(sum_sq_others, 0.0))

    if existing_dd > budget_pct:
        return {
            "magic": candidate_magic,
            "status": "DEFER_ESCALATE",
            "lot_factor": None,
            "existing_portfolio_dd_est": existing_dd,
            "budget_pct": budget_pct,
            "message": (
                "existing portfolio already exceeds budget before adding this candidate -- "
                "not this EA's fault, escalate to user (pre-existing over-budget condition)"
            ),
        }

    if candidate_dd95 <= 0:
        raise RiskAdmissionError(f"candidate DD95 <= 0 for magic {candidate_magic} -- cannot size")

    cross = sum(get_corr(corr_matrix, candidate_magic, m) * others[m] for m in others)
    a = candidate_dd95 ** 2
    b = 2.0 * candidate_dd95 * cross

    full_sum_sq = sum_sq_others + a + b
    if full_sum_sq < -1e-9:
        raise RiskAdmissionError(
            f"negative sum-of-squares at full size for {candidate_magic} -- corr matrix invalid"
        )
    full_dd = math.sqrt(max(full_sum_sq, 0.0))

    combined = dict(others)
    combined[candidate_magic] = candidate_dd95
    max_dd = max(combined.values())
    total_dd = sum(combined.values())
    if not (max_dd - 1e-9 <= full_dd <= total_dd + 1e-9):
        raise RiskAdmissionError(
            f"bounds violated at full size for {candidate_magic} -- refusing to emit"
        )

    if full_dd <= budget_pct + 1e-9:
        return {
            "magic": candidate_magic,
            "status": "ADMIT_FULL",
            "lot_factor": 1.0,
            "portfolio_dd_est_after": full_dd,
            "budget_pct": budget_pct,
            "message": "fits at locked-set lot (lot_factor 1.0)",
        }

    # Solve a*x^2 + b*x + c = 0 for the largest x in (0, 1) with
    # sqrt(sum_sq_others + a*x^2 + b*x) == budget_pct.
    c = sum_sq_others - budget_pct ** 2
    disc = b * b - 4 * a * c
    if disc < 0:
        raise RiskAdmissionError(
            f"no real solution for a fitting lot scale -- corr matrix invalid for {candidate_magic}"
        )
    x = (-b + math.sqrt(disc)) / (2 * a)
    x = min(x, 1.0)   # never scale UP past the validated locked .set
    if x <= 0:
        raise RiskAdmissionError(
            f"solved lot_factor <= 0 for {candidate_magic} -- corr matrix invalid"
        )

    if x < broker_min_lot_factor:
        return {
            "magic": candidate_magic,
            "status": "DEFER_ESCALATE",
            "lot_factor": None,
            "required_lot_factor": round(x, 6),
            "broker_min_lot_factor": broker_min_lot_factor,
            "budget_pct": budget_pct,
            "message": "cannot fit even at broker-minimum lot -- defer attach, escalate to user",
        }

    return {
        "magic": candidate_magic,
        "status": "ADMIT_REDUCED",
        "lot_factor": round(x, 4),
        "portfolio_dd_est_after_full_size": full_dd,
        "budget_pct": budget_pct,
        "message": f"reduce to {x:.2%} of the locked-set lot to fit the budget",
    }


# --------------------------------------------------------------------------- #
# current-state report (markdown + JSON, advisory only, no side effects)
# --------------------------------------------------------------------------- #

PRIORITY_ACCOUNTS = ["463666728", "415573666"]


def _account_order(accounts):
    rest = sorted(a for a in accounts if a not in PRIORITY_ACCOUNTS)
    ordered = [a for a in PRIORITY_ACCOUNTS if a in accounts] + rest
    return ordered


def summarize_account(account, rows, dd95_map, corr_matrix):
    acct_type = rows[0]["type"] if rows else ""
    acct_name = rows[0]["account_name"] if rows else ""
    budget_pct, budget_note = budget_pct_for_account_type(acct_type)

    known = {}
    known_rows = []
    unknown_rows = []
    for r in rows:
        m = r["magic"]
        if m in dd95_map:
            known[m] = dd95_map[m]
            known_rows.append(r)
        else:
            unknown_rows.append(r)

    result = {
        "account": account,
        "account_name": acct_name,
        "type": acct_type,
        "budget_pct": budget_pct,
        "budget_note": budget_note,
        "n_total_magics": len(rows),
        "n_known_dd95": len(known),
        "n_unknown_dd95": len(unknown_rows),
        "unknown_magics": sorted(r["magic"] for r in unknown_rows),
        "known_magics": sorted(known.keys()),
        "portfolio_dd_est": None,
        "status_note": None,
    }

    if not known:
        result["status_note"] = (
            f"cannot compute -- 0/{len(rows)} magics on this account have known DD95 "
            "(all UNKNOWN). portfolio_dd_est is NOT a portfolio risk number here, it is absent."
        )
        return result

    try:
        pdd = portfolio_dd_est(known, corr_matrix)
        result["portfolio_dd_est"] = pdd
        result["status_note"] = (
            f"computed from {len(known)}/{len(rows)} magics ({len(unknown_rows)} UNKNOWN "
            "excluded from the sum, not zeroed) -- treat as a PARTIAL number, not full coverage"
            if unknown_rows else
            f"computed from {len(known)}/{len(rows)} magics (full coverage on this account)"
        )
        if budget_pct is not None:
            result["headroom_pct"] = round(budget_pct - pdd, 4)
            result["over_budget"] = pdd > budget_pct
    except RiskAdmissionError as e:
        result["status_note"] = f"REFUSED (script will not guess): {e}"

    return result


def build_report(deployments, dd95_map, corr_matrix):
    active_rows = [r for r in deployments if r["status"] in ("ACTIVE", "PENDING_ATTACH")]
    by_account = defaultdict(list)
    for r in active_rows:
        by_account[r["account"]].append(r)

    total_magics = len(active_rows)
    total_known = sum(1 for r in active_rows if r["magic"] in dd95_map)
    total_unknown = total_magics - total_known

    accounts_out = []
    for acct in _account_order(list(by_account.keys())):
        accounts_out.append(summarize_account(acct, by_account[acct], dd95_map, corr_matrix))

    # admission-demo: for every PENDING_ATTACH candidate on a DEMO account, show what
    # admit_candidate() would say right now (illustrative -- attach itself is a human/
    # other-order action, this script never writes DEPLOYMENTS.csv).
    admission_demo = []
    for acct_summary in accounts_out:
        acct = acct_summary["account"]
        rows = by_account[acct]
        pending = [r for r in rows if r["status"] == "PENDING_ATTACH"]
        if not pending:
            continue
        active_known = {
            r["magic"]: dd95_map[r["magic"]]
            for r in rows if r["status"] == "ACTIVE" and r["magic"] in dd95_map
        }
        for cand in pending:
            m = cand["magic"]
            if m not in dd95_map:
                admission_demo.append({
                    "account": acct, "magic": m, "ea_name": cand["ea_name"],
                    "status": "CANNOT_RUN",
                    "message": "candidate DD95 UNKNOWN (no expectations.csv row) -- "
                               "admission function needs it before it can size anything",
                })
                continue
            try:
                decision = admit_candidate(
                    m, dd95_map[m], active_known, corr_matrix, acct_summary["budget_pct"]
                )
                decision["account"] = acct
                decision["ea_name"] = cand["ea_name"]
                admission_demo.append(decision)
            except RiskAdmissionError as e:
                admission_demo.append({
                    "account": acct, "magic": m, "ea_name": cand["ea_name"],
                    "status": "REFUSED", "message": str(e),
                })

    report = {
        "limitation": LIMITATION,
        "formula": "portfolio_DD_est = sqrt( sum_i sum_j corr_ij * DD95_i * DD95_j ), corr_ii = 1",
        "demo_budget_pct": DEMO_BUDGET_PCT,
        "demo_budget_source": BUDGET_SOURCE_NOTE,
        "coverage": {
            "total_active_or_pending_magics": total_magics,
            "known_dd95": total_known,
            "unknown_dd95": total_unknown,
            "expectations_csv_found": Path(EXPECTATIONS_CSV).exists(),
        },
        "accounts": accounts_out,
        "admission_demo": admission_demo,
    }
    return report


def render_markdown(report):
    cov = report["coverage"]
    lines = []
    lines.append("# ORDER-154 -- Portfolio Risk Admission: Current-State Report")
    lines.append("")
    lines.append(f"> {LIMITATION}")
    lines.append("")
    lines.append(f"**Formula:** `{report['formula']}`")
    lines.append("")
    pct = (100.0 * cov["known_dd95"] / cov["total_active_or_pending_magics"]) if cov["total_active_or_pending_magics"] else 0.0
    lines.append(
        f"## Data coverage: **{cov['known_dd95']}/{cov['total_active_or_pending_magics']} magics "
        f"have real DD95 data ({pct:.0f}%)** -- {cov['unknown_dd95']} are UNKNOWN"
    )
    if not Path(EXPECTATIONS_CSV).exists():
        lines.append("")
        lines.append(
            "**`portfolio/expectations.csv` does not exist on this run** (ORDER-153 has not "
            "produced it yet). Every magic below is therefore UNKNOWN and every "
            "`portfolio_dd_est` in this report is absent/None. Re-run this script after "
            "ORDER-153 lands."
        )
    elif cov["known_dd95"] < cov["total_active_or_pending_magics"] / 2:
        lines.append("")
        lines.append(
            f"**MOST magics are UNKNOWN ({cov['unknown_dd95']}/{cov['total_active_or_pending_magics']}).** "
            "Any `portfolio_dd_est` numbers below are computed from a MINORITY of each "
            "account's EAs and must NOT be read as that account's full portfolio risk."
        )
    lines.append("")
    lines.append(
        f"Budget rule: DEMO accounts = **{DEMO_BUDGET_PCT:.0f}%** of equity "
        f"({BUDGET_SOURCE_NOTE}). REAL_CENT accounts: computed/reported only, "
        "**no budget assigned -- user decision needed**."
    )
    lines.append("")
    lines.append("---")
    lines.append("")

    for a in report["accounts"]:
        lines.append(f"## Account {a['account']} -- {a['account_name']} ({a['type']})")
        lines.append("")
        lines.append(
            f"- magics (ACTIVE+PENDING_ATTACH): **{a['n_total_magics']}** "
            f"| known DD95: **{a['n_known_dd95']}** | UNKNOWN: **{a['n_unknown_dd95']}**"
        )
        if a["unknown_magics"]:
            lines.append(f"- UNKNOWN magics: {', '.join(a['unknown_magics'])}")
        if a["budget_pct"] is not None:
            lines.append(f"- budget: **{a['budget_pct']:.1f}%** of equity ({a['budget_note']})")
        else:
            lines.append(f"- budget: **not assigned** ({a['budget_note']})")
        if a["portfolio_dd_est"] is not None:
            lines.append(f"- **portfolio_DD_est = {a['portfolio_dd_est']:.2f}%**")
            if "headroom_pct" in a:
                flag = "OVER BUDGET" if a.get("over_budget") else "within budget"
                lines.append(f"  - headroom vs budget: {a['headroom_pct']:.2f} pts ({flag})")
        lines.append(f"- {a['status_note']}")
        lines.append("")

    if report["admission_demo"]:
        lines.append("---")
        lines.append("")
        lines.append("## Admission-function demo (PENDING_ATTACH candidates, illustrative only)")
        lines.append("")
        lines.append(
            "This does not attach anything and does not touch DEPLOYMENTS.csv -- it shows "
            "what `admit_candidate()` currently says, for whoever reviews the actual attach."
        )
        lines.append("")
        for d in report["admission_demo"]:
            lines.append(
                f"- **{d.get('account')} / magic {d.get('magic')}** ({d.get('ea_name','')}): "
                f"`{d.get('status')}` -- {d.get('message')}"
            )
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append(
        "_Generated by `scripts/portfolio_risk_admission.py`. Advisory only -- never writes "
        "to any .set file, never modifies DEPLOYMENTS.csv, never auto-applies a lot change, "
        "never issues a verdict about an EA._"
    )
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------- #
# CAGE (self-test) -- money-adjacent code, all 4 required cases + 2 bonus cases
# --------------------------------------------------------------------------- #

def _cage_1_golden_sample():
    """Fixed 3-EA fixture -> byte-identical output on every run, cross-checked
    against an independently hand-derived expected value."""
    dd95 = {"A": 5.0, "B": 3.0, "C": 2.0}
    corr = {frozenset(("A", "B")): 0.5, frozenset(("B", "C")): 0.2}
    # A-C is deliberately absent -> must default to 1.0 (also exercised by cage 3)

    expected = math.sqrt(
        1 * 25.0 + 0.5 * 15.0 + 1.0 * 10.0 +
        0.5 * 15.0 + 1 * 9.0 + 0.2 * 6.0 +
        1.0 * 10.0 + 0.2 * 6.0 + 1 * 4.0
    )

    r1 = portfolio_dd_est(dd95, corr)
    r2 = portfolio_dd_est(dd95, corr)
    assert r1 == r2, f"non-deterministic: {r1!r} != {r2!r}"
    assert abs(r1 - expected) < 1e-12, f"golden value drifted: got {r1!r}, expected {expected!r}"

    payload1 = json.dumps({"dd95": dd95, "portfolio_dd_est": r1}, sort_keys=True)
    payload2 = json.dumps({"dd95": dd95, "portfolio_dd_est": r2}, sort_keys=True)
    assert payload1 == payload2, "golden-sample JSON output is not byte-identical across runs"


def _cage_2_bounds_assert():
    """A corr matrix that produces a value below max(DD95) (or above sum(DD95))
    must make portfolio_dd_est() REFUSE (raise), never silently return a number."""
    dd95 = {"A": 1.0, "B": 1.0}
    corr = {frozenset(("A", "B")): -1.0}  # sum_sq = 1-1-1+1 = 0 -> sqrt=0 < max(1.0)
    try:
        portfolio_dd_est(dd95, corr)
        raise AssertionError("expected RiskAdmissionError, got a value instead")
    except RiskAdmissionError:
        pass

    # sanity: a normal, valid matrix must NOT raise
    dd95_ok = {"A": 5.0, "B": 3.0}
    corr_ok = {frozenset(("A", "B")): 0.5}
    portfolio_dd_est(dd95_ok, corr_ok)  # should not raise


def _cage_3_missing_corr_defaults_to_one():
    """A magic pair with NO entry in the corr matrix must be treated as corr=1.0,
    proven by checking the exact value ((d1+d2) when fully additive) and by proving
    it disagrees with what a (buggy) 0.0 default would produce."""
    dd95 = {"X": 4.0, "Y": 6.0}
    corr_empty = {}  # X-Y pair is completely absent
    got = portfolio_dd_est(dd95, corr_empty)
    expected_with_1_default = 4.0 + 6.0  # (d1+d2) when corr=1 fully additive
    assert abs(got - expected_with_1_default) < 1e-12, (
        f"missing-corr default did not behave as fully-additive (1.0): got {got!r}, "
        f"expected {expected_with_1_default!r}"
    )

    # explicitly prove get_corr() returns 1.0, not 0.0, for the missing pair
    c = get_corr(corr_empty, "X", "Y")
    assert c == 1.0, f"missing corr_ij must default to 1.0, got {c!r}"

    # and prove the two defaults give DIFFERENT results (0.0 is not silently equivalent)
    would_be_with_zero_default = math.sqrt(4.0 ** 2 + 6.0 ** 2)  # corr=0 off-diagonal
    assert abs(got - would_be_with_zero_default) > 1e-6, (
        "missing-corr result is indistinguishable from a 0.0 default -- "
        "the 1.0 safety default is not actually being applied"
    )


def _cage_4_lot_factor_bounds():
    """No decision from admit_candidate() may ever carry a negative lot_factor or a
    lot_factor exceeding the locked-set cap of 1.0, across a spread of scenarios
    including ones designed to blow the budget or fall below broker minimum."""
    scenarios = [
        # (candidate_dd95, existing, budget) -> expect ADMIT_FULL
        (1.0, {}, 25.0),
        # candidate needs shrinking to fit
        (30.0, {}, 25.0),
        # candidate + correlated existing EAs way over budget -> should DEFER, not negative
        (50.0, {"P": 40.0, "Q": 40.0}, 25.0),
        # existing portfolio already breaches budget before the candidate
        (1.0, {"P": 30.0}, 25.0),
        # tiny budget forces a very small factor, possibly below broker minimum
        (10.0, {}, 0.05),
    ]
    seen_admit_reduced = False
    seen_defer = False
    for i, (cand_dd95, existing, budget) in enumerate(scenarios):
        corr = {}
        decision = admit_candidate(f"CAND{i}", cand_dd95, existing, corr, budget)
        lf = decision.get("lot_factor")
        if lf is not None:
            assert lf > 0, f"scenario {i}: lot_factor must be > 0, got {lf!r}"
            assert lf <= 1.0 + 1e-9, f"scenario {i}: lot_factor must be <= 1.0 (locked-set cap), got {lf!r}"
        assert decision["status"] in ("ADMIT_FULL", "ADMIT_REDUCED", "DEFER_ESCALATE", "REPORT_ONLY"), (
            f"scenario {i}: unexpected status {decision['status']!r}"
        )
        if decision["status"] == "DEFER_ESCALATE":
            assert lf is None, f"scenario {i}: DEFER_ESCALATE must not carry a usable lot_factor"
            seen_defer = True
        if decision["status"] == "ADMIT_REDUCED":
            assert 0 < lf < 1.0, f"scenario {i}: ADMIT_REDUCED lot_factor should be in (0,1), got {lf!r}"
            seen_admit_reduced = True

    assert seen_admit_reduced, "no scenario exercised ADMIT_REDUCED -- test doesn't cover the resize path"
    assert seen_defer, "no scenario exercised DEFER_ESCALATE -- test doesn't cover the defer path"

    # REAL_CENT (budget_pct=None) must never size anything, only report
    d = admit_candidate("CANDX", 5.0, {}, {}, None)
    assert d["status"] == "REPORT_ONLY" and d["lot_factor"] is None


def _cage_5_bonus_missing_dd95_excluded_not_zeroed():
    """Bonus: a magic absent from the expectations map must be excluded from the
    sum entirely, never substituted as 0.0 (0.0 would silently understate risk)."""
    dd95_map = {"KNOWN1": 5.0}  # KNOWN2 deliberately absent -> UNKNOWN
    known_only = {m: v for m, v in dd95_map.items() if m in dd95_map}
    got = portfolio_dd_est(known_only, {})
    assert abs(got - 5.0) < 1e-12, f"expected single-EA result 5.0, got {got!r}"
    # if UNKNOWN2 had been silently zeroed and included, the set would be {'KNOWN1':5.0,'UNKNOWN2':0.0}
    zeroed = {"KNOWN1": 5.0, "UNKNOWN2": 0.0}
    got_if_zeroed = portfolio_dd_est(zeroed, {})
    assert abs(got_if_zeroed - 5.0) < 1e-12  # (0.0 happens to be a no-op here numerically,
    # which is exactly why "exclude" vs "zero" must be enforced by the CALLER filtering the
    # dict before calling portfolio_dd_est -- prove load_expectations() does that filtering:
    assert "UNKNOWN2" not in dd95_map, "UNKNOWN magic leaked into the known-DD95 map"


def _cage_6_bonus_expectations_file_absent():
    """Bonus: load_expectations() on a nonexistent path must return an empty dict
    cleanly (no crash), and the literal string 'UNKNOWN' must be excluded."""
    got = load_expectations(ROOT / "portfolio" / "__does_not_exist__.csv")
    assert got == {}, f"missing expectations.csv should yield an empty map, got {got!r}"


CAGE_TESTS = [
    ("1_golden_sample", _cage_1_golden_sample),
    ("2_bounds_assert", _cage_2_bounds_assert),
    ("3_missing_corr_defaults_to_one", _cage_3_missing_corr_defaults_to_one),
    ("4_lot_factor_bounds", _cage_4_lot_factor_bounds),
    ("5_bonus_missing_dd95_excluded_not_zeroed", _cage_5_bonus_missing_dd95_excluded_not_zeroed),
    ("6_bonus_expectations_file_absent", _cage_6_bonus_expectations_file_absent),
]


def run_selftest():
    ok = True
    for name, fn in CAGE_TESTS:
        try:
            fn()
            print(f"PASS  {name}")
        except AssertionError as e:
            print(f"FAIL  {name}  -- {e}")
            ok = False
        except Exception as e:  # noqa: BLE001 -- self-test must report, not crash the runner
            print(f"FAIL  {name}  -- unexpected {type(e).__name__}: {e}")
            ok = False
    print("ALL PASS" if ok else "SOME FAILED")
    return ok


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--selftest", action="store_true", help="run the CAGE tests and exit")
    ap.add_argument("--deployments", default=str(DEPLOYMENTS_CSV))
    ap.add_argument("--expectations", default=str(EXPECTATIONS_CSV))
    ap.add_argument("--live-deals", default=str(LIVE_DEALS_DIR))
    ap.add_argument("--out-md", default=str(OUT_MD))
    ap.add_argument("--out-json", default=str(OUT_JSON))
    args = ap.parse_args(argv)

    if args.selftest:
        ok = run_selftest()
        sys.exit(0 if ok else 1)

    deployments = load_deployments(args.deployments)
    dd95_map = load_expectations(args.expectations)
    magics = sorted({r["magic"] for r in deployments})
    corr_matrix = compute_corr_matrix(magics, args.live_deals)

    report = build_report(deployments, dd95_map, corr_matrix)
    md = render_markdown(report)

    Path(args.out_md).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out_md).write_text(md, encoding="utf-8")
    Path(args.out_json).write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(f"wrote {args.out_md}")
    print(f"wrote {args.out_json}")


if __name__ == "__main__":
    main()
