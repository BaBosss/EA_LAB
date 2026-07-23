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
# ORDER-170 SEV-1 #4: this MUST default to None (fail closed), not to a placeholder.
# The real value is (broker_min_lot / locked_set_lot) and is not derivable from any
# file this script reads. A placeholder made the "cannot fit at broker minimum" branch
# effectively unreachable, so the script could hand back a reduced lot that is smaller
# than the broker will actually accept. With None, a run that needs a reduced lot
# escalates instead of emitting an uncertifiable sizing instruction.
DEFAULT_BROKER_MIN_LOT_FACTOR = None

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
    DD95 is unknown (file missing entirely, row missing, literal "UNKNOWN" string,
    unparseable, or NOT a finite positive number) -- callers must treat "absent" as
    UNKNOWN and never invent 0.0.

    ORDER-170 SEV-1 #3: a literal numeric 0 (or inf/nan) previously passed float()
    and was counted as a KNOWN DD95, so a single such row could make the whole
    account report portfolio_DD_est = 0.0 -- a silent understatement of risk, which
    is the dangerous direction. A DD95 of exactly 0 is not a real risk measurement
    for a trading strategy; it is a data error. Both are now rejected as UNKNOWN.
    """
    dd95, _basket_of = load_expectations_with_baskets(path)
    return dd95


def load_expectations_with_baskets(path=EXPECTATIONS_CSV):
    """Same as load_expectations() but also returns magic -> basket_id (only for
    magics that declare one). ORDER-170 SEV-1 #1: several magics can be legs of ONE
    basket whose DD95 was measured at basket level; counting that figure once per
    leg multiplies a single risk unit. Callers must collapse by basket via
    collapse_basket_risk_units() before summing."""
    dd95 = {}
    basket_of = {}
    p = Path(path)
    if not p.exists():
        return dd95, basket_of  # file not produced yet -- every magic is UNKNOWN
    with open(p, encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            magic = (row.get("magic") or "").strip()
            if not magic:
                continue
            basket = (row.get("basket_id") or "").strip()
            if basket and basket.upper() != "UNKNOWN":
                basket_of[magic] = basket
            raw = (row.get("dd95_expected") or "").strip()
            if raw == "" or raw.upper() == "UNKNOWN":
                continue
            try:
                val = float(raw)
            except ValueError:
                continue  # unparseable -- treat as UNKNOWN, never guess
            if not math.isfinite(val) or val <= 0.0:
                continue  # 0 / inf / nan are data errors, NOT a measured risk of zero
            dd95[magic] = val
    return dd95, basket_of


def _basket_key(basket_id):
    """Single place the namespaced basket risk-unit key is built (round-4 audit
    maintainability note: three hand-built f-strings can drift apart)."""
    return f"basket::{basket_id}"


def collapse_basket_risk_units(dd95_by_magic, basket_of):
    """Collapse magics that share a basket_id into ONE risk unit so a basket-level
    DD95 is counted once, not once per leg (ORDER-170 SEV-1 #1).

    Returns (units, dropped) where `units` is {key: dd95} keyed by basket id (for
    basketed magics) or by magic (for standalone ones), and `dropped` lists the
    sibling magics whose duplicate figure was folded away, for reporting.

    If two legs of the SAME basket carry DIFFERENT numbers, that is a genuine data
    contradiction we cannot silently pick a winner for -- take the LARGER (the
    conservative direction for a risk budget) and record it in `dropped` so the
    disagreement stays visible rather than being resolved invisibly.
    """
    units = {}
    dropped = []
    for magic, val in dd95_by_magic.items():
        basket = basket_of.get(magic)
        # ORDER-170 round-3 SEV-1 #2: basket ids and standalone magics must NOT share
        # one raw-string namespace -- a basket_id equal to an unrelated magic would
        # silently merge two independent risk units (an undercount, the dangerous
        # direction). Basket units get an explicit prefix; standalone magics keep
        # their raw key so measured correlations (keyed by magic) still resolve.
        if basket:
            key = _basket_key(basket)
        else:
            if magic.startswith("basket::"):
                raise RiskAdmissionError(
                    f"magic {magic!r} collides with the reserved basket key namespace "
                    "'basket::' -- rename the magic; refusing to build risk units"
                )
            key = magic
        if key in units:
            prev = units[key]
            # ORDER-170 round-7 (audit F2): ALWAYS keep the max, even inside the
            # near-equal tolerance -- keeping the first-seen value made the collapsed
            # figure depend on inventory order, which flipped a sizing decision at
            # the budget boundary. The tolerance now only picks the MESSAGE wording.
            units[key] = max(prev, val)
            if abs(prev - val) > 1e-9:
                dropped.append(
                    f"{magic}: basket '{key}' has conflicting DD95 values "
                    f"({prev} vs {val}) -- kept the larger"
                )
            else:
                dropped.append(
                    f"{magic}: duplicate of basket '{key}' DD95 {units[key]} -- counted once"
                )
        else:
            units[key] = val
    return units, dropped


class _Corrupt:
    """Sentinel: a numeric cell existed but could not be parsed. Distinct from an
    absent cell -- see _num()."""
    __slots__ = ()

    def __repr__(self):  # pragma: no cover -- debug aid only
        return "<CORRUPT>"


CORRUPT = _Corrupt()


def _num(x):
    """Return float, 0.0 for a genuinely EMPTY/absent cell, or CORRUPT when a value
    is present but unparseable.

    ORDER-170 SEV-1 #2: this used to return 0.0 for unparseable text, which turned a
    corrupted P&L cell into a real zero observation. That can drag a measured monthly
    correlation BELOW 1.0 and so bypass the conservative missing-correlation default
    -- understating portfolio risk. Corrupted input must poison the magic instead, so
    its pairs fall back to corr = 1.0 (fully additive)."""
    if x is None:
        return 0.0
    s = str(x).strip()
    if s == "":
        return 0.0
    try:
        v = float(s)
    except ValueError:
        return CORRUPT
    # ORDER-170 round-3 SEV-2 #5: Python's float() happily accepts "nan", "inf" and
    # overflow spellings like "1e309". A non-finite P&L observation is exactly as
    # corrupted as unparseable text -- it must poison the magic (-> corr falls back to
    # the conservative 1.0), never enter correlation arithmetic as a nan/inf point.
    if not math.isfinite(v):
        return CORRUPT
    return v


def load_monthly_pnl_by_magic(live_deals_dir=LIVE_DEALS_DIR):
    """Latest snapshot file per account (the daily dumps are cumulative, not
    incremental, so using the newest one avoids double-counting) bucketed into
    magic -> {"YYYY-MM": realized profit+swap+commission}. Mirrors the bucket-then
    -pearson method in _mt5_auto/corr_monthly.py / scripts/corr_matrix.py, generalized
    across both the MT5 "deals" export schema and the MT4 "orders" export schema."""
    d = Path(live_deals_dir)
    monthly = defaultdict(lambda: defaultdict(float))
    corrupted = set()
    if not d.exists():
        return monthly, corrupted

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
                parts = (_num(row.get("profit")), _num(row.get("swap")), _num(row.get("commission")))
                if any(p is CORRUPT for p in parts):
                    # ORDER-170 SEV-1 #2: do NOT let a corrupted cell become a 0.0
                    # observation -- that would fabricate a data point and can pull a
                    # measured correlation below the conservative 1.0 default.
                    corrupted.add(magic)
                    continue
                monthly[magic][ym] += sum(parts)

    # ORDER-170 round-4 SEV-2: individually finite cells can still overflow the
    # monthly aggregation to inf (e.g. two 1e308 deals in one month). A non-finite
    # monthly total is corrupt data exactly like an unparseable cell -- poison the
    # magic so its pairs fall back to the conservative 1.0 default.
    for magic, months in monthly.items():
        if any(not math.isfinite(v) for v in months.values()):
            corrupted.add(magic)
    return monthly, corrupted


def pearson(xs, ys):
    n = len(xs)
    if n < 3:
        return None
    mx = sum(xs) / n
    my = sum(ys) / n
    # ORDER-170 round-5 (audit F2): use multiplication, never ** 2 -- Python raises a
    # raw OverflowError from float ** on large finite operands, which aborted matrix
    # ingestion. Multiplication overflows to inf instead, and any non-finite
    # intermediate makes this pair UNMEASURABLE (None -> conservative 1.0 fallback).
    # Returning a number computed through inf would be worse: finite/inf gives 0.0,
    # which would UNDERSTATE risk from garbage data.
    numer = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    dx2 = sum((x - mx) * (x - mx) for x in xs)
    dy2 = sum((y - my) * (y - my) for y in ys)
    if not (math.isfinite(mx) and math.isfinite(my) and math.isfinite(numer)
            and math.isfinite(dx2) and math.isfinite(dy2)):
        return None
    dx = math.sqrt(dx2)
    dy = math.sqrt(dy2)
    if dx == 0 or dy == 0:
        return None
    r = numer / (dx * dy)
    # ORDER-170 round-6 (audit F3): finite underflow can push the quotient outside
    # the mathematical range [-1, 1] (observed 1.0000673 from subnormal inputs).
    # Clamp a machine-epsilon overshoot; anything materially out of range means the
    # inputs are numerically degenerate -- treat as unmeasurable (None -> 1.0 default).
    if not math.isfinite(r):
        return None
    if abs(r) > 1.0:
        if abs(r) <= 1.0 + 1e-9:
            return math.copysign(1.0, r)
        return None
    return r


def compute_corr_matrix(magics, live_deals_dir=LIVE_DEALS_DIR):
    """Best-effort monthly-return correlation for the given magics from live deal
    history actually on disk. A pair with fewer than MIN_SHARED_MONTHS overlapping
    months is simply left OUT of the returned dict -- get_corr() is what applies the
    1.0-default safety rule, this function only reports what it could measure."""
    monthly, corrupted = load_monthly_pnl_by_magic(live_deals_dir)
    corr = {}
    # ORDER-170 SEV-1 #2: a magic with ANY corrupted P&L cell is excluded from
    # measurement entirely, so every pair involving it stays missing and get_corr()
    # applies the conservative 1.0 default instead of a correlation computed from
    # partly-fabricated data.
    mags = [m for m in magics if m in monthly and m not in corrupted]
    for i in range(len(mags)):
        for j in range(i + 1, len(mags)):
            a, b = mags[i], mags[j]
            common = sorted(set(monthly[a]) & set(monthly[b]))
            if len(common) < MIN_SHARED_MONTHS:
                continue
            xs = [monthly[a][m] for m in common]
            ys = [monthly[b][m] for m in common]
            c = pearson(xs, ys)
            # ORDER-170 round-4 SEV-2: overflow inside pearson (finite inputs, huge
            # magnitudes) can yield nan/inf -- a non-finite correlation must never
            # enter the matrix; leaving the pair out applies the 1.0 default instead.
            if c is None or not math.isfinite(c):
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

    # ORDER-170 SEV-1 #3 / SEV-2 #7, defence in depth: the parser already refuses
    # 0/negative/inf/nan, but this function is public and callers can pass computed
    # values. Validate here too -- a 0.0 slipping in silently understates the whole
    # portfolio, and an inf sails through the bounds check (max == sum == inf).
    for m, v in dd95_by_magic.items():
        if not isinstance(v, (int, float)) or isinstance(v, bool) or not math.isfinite(v) or v <= 0.0:
            raise RiskAdmissionError(
                f"DD95 for {m!r} is {v!r} -- must be a finite number > 0. A zero or "
                "non-finite drawdown quantile is a data error, not a measured risk; "
                "exclude the magic as UNKNOWN instead of passing a placeholder."
            )

    sum_sq = 0.0
    for i in magics:
        for j in magics:
            sum_sq += get_corr(corr_matrix, i, j) * dd95_by_magic[i] * dd95_by_magic[j]

    # ORDER-170 round-4: individually finite but extreme inputs can overflow the
    # aggregation to inf/nan, and inf sails through the bounds check below
    # (inf <= inf is True). A non-finite intermediate is a data error -- refuse.
    if not math.isfinite(sum_sq):
        raise RiskAdmissionError(
            f"non-finite sum-of-squares ({sum_sq!r}) -- inputs overflow the formula; "
            "refusing to emit a risk number"
        )
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
    # ORDER-170 round-3 SEV-2 #6: this function must validate its OWN numeric inputs
    # instead of trusting callers. An inf candidate used to propagate into
    # required_lot_factor=nan, and a broker minimum of 0.0 (or nan) passed both
    # comparisons and could emit lot_factor=0.0 -- violating the documented
    # 0 < lot_factor <= 1.0 invariant. Refuse loudly instead.
    def _reject(name, v, why):
        raise RiskAdmissionError(f"{name}={v!r} for magic {candidate_magic!r} -- {why}; refusing to size")

    def _is_real_number(v):
        return isinstance(v, (int, float)) and not isinstance(v, bool)

    if not _is_real_number(candidate_dd95) or not math.isfinite(candidate_dd95) or candidate_dd95 <= 0.0:
        _reject("candidate_dd95", candidate_dd95, "must be a finite number > 0")
    if budget_pct is not None and (
            not _is_real_number(budget_pct) or not math.isfinite(budget_pct) or budget_pct <= 0.0):
        _reject("budget_pct", budget_pct, "must be a finite number > 0, or None for REPORT_ONLY")
    if broker_min_lot_factor is not None and (
            not _is_real_number(broker_min_lot_factor)
            or not math.isfinite(broker_min_lot_factor)
            or not (0.0 < broker_min_lot_factor <= 1.0)):
        _reject("broker_min_lot_factor", broker_min_lot_factor,
                "must be finite and in (0, 1] (broker_min_lot / locked_set_lot), or None when unknown")

    if budget_pct is None:
        return {
            "magic": candidate_magic,
            "status": "REPORT_ONLY",
            "lot_factor": None,
            "message": "no DD budget assigned for this account type -- report only, user decision needed",
        }

    others = dict(existing_dd95_by_magic)
    if candidate_magic in others:
        raise RiskAdmissionError(
            f"candidate {candidate_magic!r} already appears in the existing portfolio -- "
            "admitting it again would double-count one risk unit; refusing to size"
        )
    # ORDER-170 SEV-1 #5 (round 3 extended): EVERY portfolio figure this function
    # uses -- existing, full-size, and the emitted reduced point -- must come from
    # portfolio_dd_est(), the single guarded way to produce this number. Round 2
    # proved that any hand-rolled sqrt kept alongside it eventually skips a bound.
    if others:
        existing_dd = portfolio_dd_est(others, corr_matrix)
    else:
        existing_dd = 0.0
    sum_sq_others = existing_dd * existing_dd

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

    cross = sum(get_corr(corr_matrix, candidate_magic, m) * others[m] for m in others)
    # ORDER-170 round-4 MINOR: candidate_dd95 ** 2 raises a raw OverflowError for an
    # extreme-but-finite value (e.g. 1e308) -- use multiplication (-> inf) and refuse
    # through the documented error type instead of leaking a foreign exception.
    a = candidate_dd95 * candidate_dd95
    b = 2.0 * candidate_dd95 * cross
    if not (math.isfinite(cross) and math.isfinite(a) and math.isfinite(b)):
        raise RiskAdmissionError(
            f"quadratic coefficients overflow for {candidate_magic!r} "
            f"(cross={cross!r}, a={a!r}, b={b!r}) -- inputs are outside any plausible "
            "percent-of-equity range; refusing to size"
        )

    combined = dict(others)
    combined[candidate_magic] = candidate_dd95
    full_dd = portfolio_dd_est(combined, corr_matrix)

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
    if not math.isfinite(x):
        raise RiskAdmissionError(
            f"solved lot_factor is non-finite for {candidate_magic!r} -- refusing to size"
        )
    x = min(x, 1.0)   # never scale UP past the validated locked .set
    if x <= 0:
        # ORDER-170 round-5 (audit F3): with a VALID matrix this occurs exactly when
        # the existing portfolio already consumes the entire budget (existing_dd ==
        # budget under additive correlation) -- no positive lot can fit. That is a
        # defer condition per this function's contract, not a broken corr matrix.
        return {
            "magic": candidate_magic,
            "status": "DEFER_ESCALATE",
            "lot_factor": None,
            "required_lot_factor": None,
            "existing_portfolio_dd_est": existing_dd,
            "budget_pct": budget_pct,
            "message": (
                "existing portfolio consumes the entire budget -- no positive lot "
                "factor fits; defer attach, escalate to user"
            ),
        }

    # ORDER-170 SEV-1 #4: broker_min_lot_factor is (broker_min_lot / locked_set_lot)
    # and is NOT derivable from any file this script reads. It used to default to a
    # placeholder 0.01, which meant the "cannot fit at broker minimum" branch almost
    # never fired and the caller could be handed a reduced lot that is physically
    # unplaceable. With no real value supplied we must fail CLOSED: escalate rather
    # than emit a lot factor we cannot certify is placeable.
    if broker_min_lot_factor is None:
        return {
            "magic": candidate_magic,
            "status": "DEFER_ESCALATE",
            "lot_factor": None,
            "required_lot_factor": round(x, 6),
            "broker_min_lot_factor": None,
            "budget_pct": budget_pct,
            "message": (
                "a reduced lot is required to fit the budget, but broker_min_lot_factor "
                "(broker_min_lot / locked_set_lot) was not supplied, so it cannot be verified "
                "as placeable -- defer attach, escalate to user"
            ),
        }

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

    # ORDER-170 SEV-2 #6: rounding the solved factor for display can round UP and push
    # the portfolio back over budget. Round DOWN (floor at 4dp) so the emitted number
    # is always <= the exact solution, then re-verify against the budget before
    # emitting -- never emit a factor that has not itself been checked.
    x_emit = math.floor(x * 10000) / 10000
    if x_emit < broker_min_lot_factor:
        return {
            "magic": candidate_magic,
            "status": "DEFER_ESCALATE",
            "lot_factor": None,
            "required_lot_factor": round(x, 6),
            "broker_min_lot_factor": broker_min_lot_factor,
            "budget_pct": budget_pct,
            "message": "cannot fit even at broker-minimum lot after rounding -- defer attach, escalate to user",
        }
    # ORDER-170 round-3 SEV-1 #3: the EMITTED reduced portfolio must itself pass the
    # full max(DD95) <= est <= sum(DD95) invariant, not just the budget upper bound.
    # With a valid negative correlation, flooring can land the point just below the
    # lower bound; portfolio_dd_est() refuses that instead of emitting it.
    scaled = dict(others)
    scaled[candidate_magic] = candidate_dd95 * x_emit
    dd_at_emit = portfolio_dd_est(scaled, corr_matrix)
    if dd_at_emit > budget_pct + 1e-9:
        raise RiskAdmissionError(
            f"post-rounding budget check failed for {candidate_magic}: "
            f"factor {x_emit} implies DD {dd_at_emit:.6f} > budget {budget_pct:.6f}. "
            "Refusing to emit a sizing instruction."
        )

    return {
        "magic": candidate_magic,
        "status": "ADMIT_REDUCED",
        "lot_factor": x_emit,
        "portfolio_dd_est_after": dd_at_emit,
        "portfolio_dd_est_after_full_size": full_dd,
        "budget_pct": budget_pct,
        "message": f"reduce to {x_emit:.2%} of the locked-set lot to fit the budget",
    }


# --------------------------------------------------------------------------- #
# current-state report (markdown + JSON, advisory only, no side effects)
# --------------------------------------------------------------------------- #

PRIORITY_ACCOUNTS = ["463666728", "415573666"]


def _account_order(accounts):
    rest = sorted(a for a in accounts if a not in PRIORITY_ACCOUNTS)
    ordered = [a for a in PRIORITY_ACCOUNTS if a in accounts] + rest
    return ordered


def summarize_account(account, rows, dd95_map, corr_matrix, basket_of=None):
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

    # ORDER-170 SEV-1 #1: collapse basket legs into one risk unit BEFORE summing, so a
    # basket-level DD95 measured once is not counted once per leg.
    units, folded = collapse_basket_risk_units(known, basket_of or {})
    if folded:
        result["basket_folded"] = folded

    try:
        pdd = portfolio_dd_est(units, corr_matrix)
        result["portfolio_dd_est"] = pdd
        basket_note = (
            f" · {len(folded)} sibling leg(s) folded into their basket risk unit "
            f"({len(known)} known magics -> {len(units)} risk units)"
            if folded else ""
        )
        result["status_note"] = (
            f"computed from {len(known)}/{len(rows)} magics ({len(unknown_rows)} UNKNOWN "
            "excluded from the sum, not zeroed) -- treat as a PARTIAL number, not full coverage"
            + basket_note
            if unknown_rows else
            f"computed from {len(known)}/{len(rows)} magics (full coverage on this account)"
            + basket_note
        )
        if budget_pct is not None:
            result["headroom_pct"] = round(budget_pct - pdd, 4)
            result["over_budget"] = pdd > budget_pct
    except RiskAdmissionError as e:
        result["status_note"] = f"REFUSED (script will not guess): {e}"

    return result


def build_report(deployments, dd95_map, corr_matrix, basket_of=None,
                 expectations_path=EXPECTATIONS_CSV):
    active_rows = [r for r in deployments if r["status"] in ("ACTIVE", "PENDING_ATTACH")]
    by_account = defaultdict(list)
    for r in active_rows:
        by_account[r["account"]].append(r)

    total_magics = len(active_rows)
    total_known = sum(1 for r in active_rows if r["magic"] in dd95_map)
    total_unknown = total_magics - total_known

    accounts_out = []
    for acct in _account_order(list(by_account.keys())):
        accounts_out.append(summarize_account(acct, by_account[acct], dd95_map, corr_matrix, basket_of=basket_of))

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
        # ORDER-170 round-3 SEV-1 #1: the admission decision must see the SAME
        # collapsed risk units as the account summary, or the two paths disagree on
        # the same input (summary said 20%, admission sized against 30%). Collapse
        # basket legs BEFORE handing the existing portfolio to admit_candidate().
        active_units, _active_folded = collapse_basket_risk_units(active_known, basket_of or {})
        # ORDER-170 round-5 (audit F1): decisions for MULTIPLE pending candidates must
        # COMPOSE, not each pretend it is the only attach. Previously two ADMIT_FULL
        # decisions could sit side by side whose combined risk breaches the budget.
        # Admission is therefore SEQUENTIAL in inventory order: every granted candidate
        # is carried forward (at its granted lot) into the existing portfolio the next
        # candidate is sized against, and each decision names that assumption.
        existing_units = dict(active_units)
        admitted_prior = []
        # ORDER-170 round-6 (audit F1): the canonical DD95 of every risk unit on this
        # account, collapsed across ALL known rows (ACTIVE and PENDING). A basketed
        # candidate must be sized at its basket's conservative canonical value (the
        # max across conflicting siblings -- same rule the summary uses), never at
        # whichever sibling row happens to come first in inventory order.
        all_known = {r["magic"]: dd95_map[r["magic"]] for r in rows if r["magic"] in dd95_map}
        units_all, _ = collapse_basket_risk_units(all_known, basket_of or {})
        # ORDER-170 round-7 (audit F1): the EXISTING portfolio must also carry each
        # basket at its canonical all-row value. An ACTIVE basket leg at 10 whose
        # PENDING sibling declares the basket-level DD95 as 30 is a 30% risk unit
        # already on the account -- sizing an unrelated candidate against the
        # ACTIVE-only 10 admitted it into a 40% portfolio against a 25% budget.
        existing_units = {k: units_all[k] for k in existing_units}
        # ORDER-170 round-8 (audit round-7 F1): a basket with an ACTIVE leg belongs in
        # the existing portfolio even when that leg's OWN DD95 is UNKNOWN -- the known
        # basket-level value may be supplied by a PENDING sibling row, in which case
        # the key never appears in active_units and the upgrade above cannot add it.
        for r in rows:
            if r["status"] != "ACTIVE":
                continue
            b = (basket_of or {}).get(r["magic"])
            if b:
                k = _basket_key(b)
                if k in units_all and k not in existing_units:
                    existing_units[k] = units_all[k]

        def _with_provenance(entry):
            if admitted_prior:
                entry["assumes_admitted_first"] = list(admitted_prior)
            return entry

        for cand in pending:
            m = cand["magic"]
            if m not in dd95_map:
                admission_demo.append(_with_provenance({
                    "account": acct, "magic": m, "ea_name": cand["ea_name"],
                    "status": "CANNOT_RUN",
                    "message": "candidate DD95 UNKNOWN (no expectations.csv row) -- "
                               "admission function needs it before it can size anything",
                }))
                continue
            cand_basket = (basket_of or {}).get(m)
            # ORDER-170 round-4 SEV-1: a basketed candidate must be admitted under the
            # SAME risk-unit identity the account summary collapses it to
            # ('basket::<id>'), not its raw magic. Otherwise admission resolves a
            # measured raw-magic correlation the summary (conservatively) does not,
            # and the two paths can disagree -- round 3 showed ADMIT_FULL next to an
            # OVER-BUDGET summary in the same report.
            cand_key = _basket_key(cand_basket) if cand_basket else m
            if cand_key in existing_units:
                admission_demo.append(_with_provenance({
                    "account": acct, "magic": m, "ea_name": cand["ea_name"],
                    "status": "CANNOT_RUN",
                    "message": (
                        f"candidate's risk unit '{cand_key}' is already counted in the "
                        "existing portfolio (ACTIVE basket leg, or a pending sibling "
                        "admitted earlier in this report) -- independent admission is "
                        "ill-defined, escalate to user"
                    ),
                }))
                continue
            cand_dd95 = units_all[cand_key]
            try:
                decision = admit_candidate(
                    cand_key, cand_dd95, existing_units, corr_matrix, acct_summary["budget_pct"]
                )
                decision["magic"] = m
                if cand_key != m:
                    decision["risk_unit"] = cand_key
                if abs(cand_dd95 - dd95_map[m]) > 1e-9:
                    decision["basket_dd95_used"] = cand_dd95
                    decision["message"] = (
                        f"{decision.get('message', '')} (sized at the basket's canonical "
                        f"DD95 {cand_dd95}, not this row's {dd95_map[m]} -- conflicting "
                        "sibling values, larger kept)"
                    )
                decision["account"] = acct
                decision["ea_name"] = cand["ea_name"]
                if admitted_prior:
                    decision["assumes_admitted_first"] = list(admitted_prior)
                    decision["message"] = (
                        f"{decision.get('message', '')} (sequential: assumes "
                        f"{', '.join(admitted_prior)} attached first at the granted lot)"
                    )
                lf = decision.get("lot_factor")
                if decision["status"] in ("ADMIT_FULL", "ADMIT_REDUCED") and lf:
                    existing_units[cand_key] = cand_dd95 * lf
                    admitted_prior.append(m)
                admission_demo.append(decision)
            except RiskAdmissionError as e:
                admission_demo.append(_with_provenance({
                    "account": acct, "magic": m, "ea_name": cand["ea_name"],
                    "status": "REFUSED", "message": str(e),
                }))

    report = {
        "limitation": LIMITATION,
        "formula": "portfolio_DD_est = sqrt( sum_i sum_j corr_ij * DD95_i * DD95_j ), corr_ii = 1",
        "demo_budget_pct": DEMO_BUDGET_PCT,
        "demo_budget_source": BUDGET_SOURCE_NOTE,
        "coverage": {
            "total_active_or_pending_magics": total_magics,
            "known_dd95": total_known,
            "unknown_dd95": total_unknown,
            # ORDER-170 round-3 MINOR #9: reflect the expectations file this run
            # actually read (--expectations), not the hardcoded default path.
            "expectations_csv_found": Path(expectations_path).exists(),
            "expectations_path": str(expectations_path),
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
    if not cov["expectations_csv_found"]:
        lines.append("")
        lines.append(
            f"**the expectations file for this run (`{cov.get('expectations_path', 'portfolio/expectations.csv')}`) "
            "does not exist** (ORDER-153 has not "
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
        # ORDER-170 round-3 SEV-2 #4: basket-fold details (including CONFLICTING
        # sibling DD95 values) must be visible in the human-readable report too,
        # not only in the JSON -- a hidden data contradiction is how a wrong risk
        # number survives review.
        for msg in a.get("basket_folded", []):
            lines.append(f"  - basket fold: {msg}")
        lines.append("")

    if report["admission_demo"]:
        lines.append("---")
        lines.append("")
        lines.append("## Admission-function demo (PENDING_ATTACH candidates, illustrative only)")
        lines.append("")
        lines.append(
            "This does not attach anything and does not touch DEPLOYMENTS.csv -- it shows "
            "what `admit_candidate()` currently says, for whoever reviews the actual attach. "
            "Decisions are SEQUENTIAL in inventory order: each one assumes every earlier "
            "granted candidate on the same account is attached at its granted lot -- they "
            "compose within the budget and are NOT independent alternatives."
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
        # ORDER-170 SEV-1 #4: broker_min_lot_factor now defaults to None (fail closed),
        # so this test must supply a real one to reach the ADMIT_REDUCED path at all.
        # Passing it explicitly is also the honest way to exercise resize behaviour --
        # the previous implicit placeholder is exactly what made the "cannot fit at
        # broker minimum" branch unreachable in production.
        decision = admit_candidate(f"CAND{i}", cand_dd95, existing, corr, budget,
                                   broker_min_lot_factor=0.01)
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


def _write_tmp_expectations(tmpdir, rows, header=None):
    """Write a real CSV so the parser is exercised end-to-end. The old version of
    test 5 built a dict inline and never called load_expectations() at all, which is
    why it could not have caught SEV-1 #3 (Codex audit, ORDER-154)."""
    header = header or ["magic", "basket_id", "dd95_expected"]
    p = Path(tmpdir) / "expectations_fixture.csv"
    with open(p, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        for r in rows:
            w.writerow(r)
    return p


def _cage_5_parser_rejects_every_unknown_form():
    """SEV-1 #3 + audit gap: drive load_expectations() with a REAL csv covering every
    absence/garbage form. Must reject all of them, and must accept only the good row.
    Deliberately constructed so that inverting the parser default (mapping any of
    these to 0.0) FAILS this test -- the old test could not detect that."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        p = _write_tmp_expectations(td, [
            ["GOOD", "", "12.5"],
            ["EMPTY", "", ""],
            ["WORD", "", "UNKNOWN"],
            ["LOWER", "", "unknown"],
            ["SPACES", "", "   "],
            ["TEXT", "", "10.77% (MC DD_95th; basket-level)"],
            ["ZERO", "", "0"],
            ["ZEROF", "", "0.0"],
            ["NEG", "", "-4"],
            ["INF", "", "inf"],
            ["NAN", "", "nan"],
        ])
        got = load_expectations(p)
    assert got == {"GOOD": 12.5}, f"parser accepted something it must reject: {got!r}"
    for bad in ("ZERO", "ZEROF", "NEG", "INF", "NAN", "TEXT", "EMPTY", "WORD", "LOWER", "SPACES"):
        assert bad not in got, f"{bad} leaked into the known-DD95 map as {got.get(bad)!r}"


def _cage_6_expectations_file_absent():
    """load_expectations() on a nonexistent path must return an empty dict cleanly."""
    got = load_expectations(ROOT / "portfolio" / "__does_not_exist__.csv")
    assert got == {}, f"missing expectations.csv should yield an empty map, got {got!r}"


def _cage_7_basket_counted_once():
    """SEV-1 #1: two legs sharing a basket_id must contribute their basket DD95 ONCE."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        p = _write_tmp_expectations(td, [
            ["LEG1", "BASKET_X", "10"],
            ["LEG2", "BASKET_X", "10"],
            ["SOLO", "", "10"],
        ])
        dd95, basket_of = load_expectations_with_baskets(p)
    units, folded = collapse_basket_risk_units(dd95, basket_of)
    assert len(units) == 2, f"basket legs not collapsed: {units!r}"
    got = portfolio_dd_est(units, {})
    assert abs(got - 20.0) < 1e-9, f"expected 20.0 (basket once + solo), got {got!r}"
    naive = portfolio_dd_est(dd95, {})
    assert abs(naive - 30.0) < 1e-9, "fixture no longer demonstrates the double-count"
    assert folded, "the folded-away sibling must be reported, not silently dropped"


def _cage_8_corrupt_pnl_does_not_become_zero():
    """SEV-1 #2: an unparseable P&L cell must poison the magic (-> corr falls back to
    the conservative 1.0), NOT become a 0.0 observation that lowers measured corr."""
    assert _num("") == 0.0 and _num(None) == 0.0, "genuinely empty cell should be 0.0"
    assert _num("12.5") == 12.5
    assert _num("not-a-number") is CORRUPT, "unparseable cell must be CORRUPT, never 0.0"
    assert _num("1,234.5x") is CORRUPT


def _cage_9_admit_candidate_bounds_guard_on_existing():
    """SEV-1 #5: admit_candidate must not build a decision on an existing-portfolio
    figure that portfolio_dd_est() would refuse."""
    existing = {"A": 10.0, "B": 10.0}
    corr = {frozenset(("A", "B")): -1.0}   # collapses to 0.0 -> violates lower bound
    try:
        portfolio_dd_est(existing, corr)
        raise AssertionError("fixture is wrong: guarded path should have refused")
    except RiskAdmissionError:
        pass
    try:
        res = admit_candidate("C", 5.0, existing, corr, 25.0)
    except RiskAdmissionError:
        return  # correct: refused rather than sizing off an invalid figure
    raise AssertionError(f"admit_candidate accepted a bounds-violating portfolio: {res!r}")


def _cage_10_broker_min_fails_closed():
    """SEV-1 #4: with no broker_min_lot_factor supplied, a run that needs a reduced
    lot must ESCALATE, never emit an uncertifiable factor."""
    res = admit_candidate("C", 20.0, {"A": 20.0}, {}, 21.0)   # needs a big reduction
    assert res["status"] == "DEFER_ESCALATE", f"expected escalation, got {res!r}"
    assert res["lot_factor"] is None, "escalation must not carry a usable lot factor"
    ok = admit_candidate("C", 20.0, {"A": 20.0}, {}, 21.0, broker_min_lot_factor=0.01)
    assert ok["status"] == "ADMIT_REDUCED" and 0 < ok["lot_factor"] <= 1.0


def _cage_11_rounded_factor_still_within_budget():
    """SEV-2 #6: the EMITTED (rounded) factor must itself satisfy the budget."""
    res = admit_candidate("C", 30.0, {}, {}, 10.001, broker_min_lot_factor=0.001)
    assert res["status"] == "ADMIT_REDUCED", f"unexpected: {res!r}"
    implied = 30.0 * res["lot_factor"]
    assert implied <= 10.001 + 1e-9, f"emitted factor implies DD {implied} over budget 10.001"


def _mk_row(account, magic, status, ea_name="EA"):
    return {"account": account, "account_name": "test", "type": "DEMO",
            "ea_name": ea_name, "magic": magic, "symbol": "X", "status": status}


def _cage_12_admission_path_collapses_baskets():
    """Round-3 SEV-1 #1: build_report()'s admission demo must size against the SAME
    collapsed risk units as the account summary. Fixture: two ACTIVE legs of one
    basket (DD95 10 measured at basket level) + one PENDING candidate (DD95 10),
    budget 25. Collapsed existing = 10 -> full-size portfolio = 20 -> ADMIT_FULL.
    An uncollapsed admission path sees existing 20, full 30 > 25, and fails this."""
    deployments = [
        _mk_row("111", "L1", "ACTIVE"), _mk_row("111", "L2", "ACTIVE"),
        _mk_row("111", "C", "PENDING_ATTACH"),
    ]
    dd95 = {"L1": 10.0, "L2": 10.0, "C": 10.0}
    basket_of = {"L1": "BX", "L2": "BX"}
    report = build_report(deployments, dd95, {}, basket_of=basket_of)
    demo = report["admission_demo"]
    assert len(demo) == 1, f"expected exactly one admission decision, got {demo!r}"
    d = demo[0]
    assert d["status"] == "ADMIT_FULL", f"admission path did not collapse baskets: {d!r}"
    assert abs(d["portfolio_dd_est_after"] - 20.0) < 1e-9, f"wrong full-size figure: {d!r}"
    acct = report["accounts"][0]
    assert abs(acct["portfolio_dd_est"] - 20.0) < 1e-9, (
        "account summary and admission path disagree on the same input"
    )
    # a candidate that is itself a sibling of an ACTIVE basket must not be sized
    report2 = build_report(
        [_mk_row("111", "L1", "ACTIVE"), _mk_row("111", "L3", "PENDING_ATTACH")],
        {"L1": 10.0, "L3": 10.0}, {}, basket_of={"L1": "BX", "L3": "BX"},
    )
    d2 = report2["admission_demo"][0]
    assert d2["status"] == "CANNOT_RUN", (
        f"sibling-of-active-basket candidate must escalate, not be sized: {d2!r}"
    )


def _cage_13_basket_id_magic_namespace_separation():
    """Round-3 SEV-1 #2: a basket_id equal to an unrelated standalone magic must NOT
    merge two independent risk units."""
    dd95 = {"BASKET_X": 20.0, "LEG": 10.0}
    basket_of = {"LEG": "BASKET_X"}   # the LEG's basket shares its name with a real magic
    units, _ = collapse_basket_risk_units(dd95, basket_of)
    assert len(units) == 2, f"basket id collided with an unrelated magic: {units!r}"
    got = portfolio_dd_est(units, {})
    assert abs(got - 30.0) < 1e-9, f"expected 30.0 (independent units, corr default 1.0), got {got!r}"


def _cage_14_emitted_reduced_point_respects_lower_bound():
    """Round-3 SEV-1 #3: the EMITTED reduced portfolio must satisfy the full
    max(DD95) <= est <= sum(DD95) invariant. With this negative correlation the
    floored factor lands just below the lower bound -- the function must refuse
    (or defer), never hand back that point."""
    corr = {frozenset(("A", "C")): -0.23456}
    try:
        res = admit_candidate("C", 20.0, {"A": 10.0}, corr, 10.0, broker_min_lot_factor=0.001)
    except RiskAdmissionError:
        return  # correct: refused to emit a bounds-violating point
    assert res["status"] != "ADMIT_REDUCED" or res["lot_factor"] is None or (
        # if it DID emit, the emitted point must itself survive the guarded formula
        portfolio_dd_est({"A": 10.0, "C": 20.0 * res["lot_factor"]}, corr) is not None
    ), f"emitted a reduced point that violates the lower bound: {res!r}"


def _cage_15_formula_guard_mutation_protection():
    """Round-3 SEV-2 #8: directly exercise the type/finite/positive guard inside
    portfolio_dd_est() (removing it must fail THIS test) + legitimate int acceptance."""
    for bad in ({"A": float("inf")}, {"A": float("nan")}, {"A": 0.0}, {"A": -1.0},
                {"A": True}, {"A": "5"}):
        try:
            portfolio_dd_est(bad, {})
            raise AssertionError(f"portfolio_dd_est accepted invalid DD95 {bad!r}")
        except RiskAdmissionError:
            pass
    got = portfolio_dd_est({"A": 5}, {})   # legitimate integer must be accepted
    assert abs(got - 5.0) < 1e-12, f"integer DD95 mishandled: {got!r}"


def _cage_16_nonfinite_pnl_poisons_magic_end_to_end():
    """Round-3 SEV-2 #5, on the PRODUCTION path (not just _num): a 'nan' P&L cell in
    a real deals CSV must poison that magic so compute_corr_matrix() excludes it and
    get_corr() falls back to the conservative 1.0 -- and no nan may enter the matrix."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "EA_LAB_deals_999_20260101.csv"
        with open(p, "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["time", "magic", "entry", "profit", "swap", "commission"])
            for i, ym in enumerate(("2026.01", "2026.02", "2026.03", "2026.04")):
                w.writerow([f"{ym}.15 10:00:00", "111", "1", str(10.0 + i), "0", "0"])
                w.writerow([f"{ym}.15 11:00:00", "222", "1", str(20.0 - i), "0", "0"])
            w.writerow(["2026.02.20 12:00:00", "111", "1", "nan", "0", "0"])  # the poison
        corr = compute_corr_matrix(["111", "222"], td)
    for pair, v in corr.items():
        assert math.isfinite(v), f"non-finite correlation leaked into the matrix: {pair}={v!r}"
        assert "111" not in pair, f"poisoned magic 111 still produced a measured pair: {pair}"
    assert get_corr(corr, "111", "222") == 1.0, "poisoned magic must fall back to corr=1.0"


def _cage_17_admission_validates_own_inputs():
    """Round-3 SEV-2 #6: malformed numeric inputs must raise, never propagate into a
    nan factor or a lot_factor=0.0 that violates the 0 < lot_factor <= 1 invariant."""
    bad_calls = [
        dict(candidate_dd95=float("inf")),
        dict(candidate_dd95=float("nan")),
        dict(candidate_dd95=True),
        dict(budget=float("nan")),
        dict(bmf=0.0),           # the audit's ADMIT_REDUCED-with-lot_factor-0.0 case
        dict(bmf=float("nan")),
        dict(bmf=1.5),
        dict(bmf=-0.1),
    ]
    for kw in bad_calls:
        try:
            admit_candidate("C", kw.get("candidate_dd95", 300000.0), {"A": 1.0}, {},
                            kw.get("budget", 0.01),
                            broker_min_lot_factor=kw.get("bmf", 0.01))
            raise AssertionError(f"admit_candidate accepted malformed input {kw!r}")
        except RiskAdmissionError:
            pass
    ok = admit_candidate("C", 1.0, {}, {}, 25.0)
    assert ok["status"] == "ADMIT_FULL", f"valid input wrongly rejected: {ok!r}"
    # flooring below the broker minimum must escalate, never emit below-minimum
    res = admit_candidate("C", 100.0, {}, {}, 5.00045, broker_min_lot_factor=0.05001)
    assert res["status"] == "DEFER_ESCALATE", f"floored-below-minimum factor was emitted: {res!r}"


def _cage_18_safe_output_path_guard():
    """Round-3 SEV-2 #7/#8: _assert_safe_output_path must refuse .set targets,
    protected inputs, and hard-link aliases of protected files -- and allow a plain
    fresh report path."""
    import argparse as _ap
    import os
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        dep = Path(td) / "dep.csv"
        exp = Path(td) / "exp.csv"
        dep.write_text("magic\n", encoding="utf-8")
        exp.write_text("magic\n", encoding="utf-8")
        args = _ap.Namespace(deployments=str(dep), expectations=str(exp))

        def refused(dest):
            try:
                _assert_safe_output_path("--out-md", str(dest), args)
            except SystemExit:
                return True
            return False

        assert refused(Path(td) / "anything.set"), ".set destination must be refused"
        assert refused(dep), "the deployments input it reads must be refused"
        assert refused(exp), "the expectations input it reads must be refused"
        assert not refused(Path(td) / "fresh_report.md"), "a plain new report path must be allowed"

        alias = Path(td) / "innocent_report.txt"
        try:
            os.link(dep, alias)   # NTFS hard link -- same file, different name+suffix
        except OSError:
            alias = None  # filesystem without hard-link support: lexical checks stand
        if alias is not None:
            assert refused(alias), "hard-link alias of a protected file must be refused"


def _cage_19_basketed_candidate_same_identity_both_paths():
    """Round-4 SEV-1: a PENDING candidate that itself has a basket_id must be admitted
    under the same 'basket::<id>' risk-unit identity the summary collapses it to.
    Round-3 audit reproducer: summary said 30.0/OVER BUDGET while admission resolved a
    measured raw-magic correlation and said ADMIT_FULL at 22.36 in the same report."""
    deployments = [_mk_row("111", "A", "ACTIVE"), _mk_row("111", "C", "PENDING_ATTACH")]
    dd95 = {"A": 20.0, "C": 10.0}
    basket_of = {"C": "BX"}
    corr = {frozenset(("A", "C")): 0.0}   # measured raw-magic corr the summary ignores
    report = build_report(deployments, dd95, corr, basket_of=basket_of)
    acct = report["accounts"][0]
    assert abs(acct["portfolio_dd_est"] - 30.0) < 1e-9, f"summary drifted: {acct!r}"
    assert acct.get("over_budget") is True
    d = report["admission_demo"][0]
    assert d["status"] != "ADMIT_FULL", (
        f"admission approved full size while the summary says OVER BUDGET: {d!r}"
    )
    assert d["status"] == "DEFER_ESCALATE", f"expected escalation (no broker min): {d!r}"
    assert d["magic"] == "C" and d.get("risk_unit") == "basket::BX", (
        f"decision must report the real magic and the risk-unit identity used: {d!r}"
    )


def _cage_20_overflowing_pnl_poisons_magic():
    """Round-4 SEV-2: individually finite deal cells that overflow the monthly
    aggregation (or pearson) must poison the magic / stay out of the matrix -- a nan
    correlation must never be stored."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "EA_LAB_deals_998_20260101.csv"
        with open(p, "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["time", "magic", "entry", "profit", "swap", "commission"])
            for i, ym in enumerate(("2026.01", "2026.02", "2026.03", "2026.04")):
                w.writerow([f"{ym}.15 10:00:00", "111", "1", "1e308", "0", "0"])
                w.writerow([f"{ym}.15 10:30:00", "111", "1", "1e308", "0", "0"])  # sum -> inf
                w.writerow([f"{ym}.15 11:00:00", "222", "1", str(float(i + 1)), "0", "0"])
        monthly, corrupted = load_monthly_pnl_by_magic(td)
        assert "111" in corrupted, "overflowed monthly total must poison the magic"
        corr = compute_corr_matrix(["111", "222"], td)
    for pair, v in corr.items():
        assert math.isfinite(v), f"non-finite correlation stored: {pair}={v!r}"
        assert "111" not in pair, f"poisoned magic still measured: {pair}"
    assert get_corr(corr, "111", "222") == 1.0


def _cage_21_extreme_finite_inputs_fail_closed_with_domain_error():
    """Round-4 MINOR + formula guard: extreme-but-finite inputs must raise
    RiskAdmissionError (the documented refusal type), never a raw OverflowError,
    and portfolio_dd_est() must refuse a sum-of-squares that overflows to inf."""
    try:
        admit_candidate("C", 1e308, {}, {}, 1.0, broker_min_lot_factor=0.01)
        raise AssertionError("admit_candidate accepted a 1e308%% DD95")
    except RiskAdmissionError:
        pass
    try:
        portfolio_dd_est({"A": 1e308, "B": 1e308}, {})
        raise AssertionError("portfolio_dd_est emitted a number from overflowing inputs")
    except RiskAdmissionError:
        pass


def _cage_22_multiple_pending_decisions_compose():
    """Round-5 audit F1: with several PENDING candidates, decisions must compose within
    the budget (sequential), never emit side-by-side full-size approvals whose sum
    breaches it. Audit repro: A ACTIVE 10 + C,D PENDING 10 each, budget 25 -- the old
    code said ADMIT_FULL for BOTH (composing to 30)."""
    deployments = [_mk_row("111", "A", "ACTIVE"),
                   _mk_row("111", "C", "PENDING_ATTACH"), _mk_row("111", "D", "PENDING_ATTACH")]
    dd95 = {"A": 10.0, "C": 10.0, "D": 10.0}
    report = build_report(deployments, dd95, {})
    demo = {d["magic"]: d for d in report["admission_demo"]}
    assert demo["C"]["status"] == "ADMIT_FULL", f"first candidate should fit: {demo['C']!r}"
    assert demo["D"]["status"] == "DEFER_ESCALATE", (
        f"second candidate must see the first one's risk: {demo['D']!r}"
    )
    assert demo["D"].get("assumes_admitted_first") == ["C"], (
        f"sequential assumption must be explicit on the decision: {demo['D']!r}"
    )
    # pending siblings of ONE basket: first is sized, second must escalate
    report2 = build_report(
        [_mk_row("111", "E", "PENDING_ATTACH"), _mk_row("111", "F", "PENDING_ATTACH")],
        {"E": 10.0, "F": 10.0}, {}, basket_of={"E": "BY", "F": "BY"},
    )
    demo2 = {d["magic"]: d for d in report2["admission_demo"]}
    assert demo2["E"]["status"] == "ADMIT_FULL"
    assert demo2["F"]["status"] == "CANNOT_RUN", (
        f"pending sibling of an admitted basket must not be sized again: {demo2['F']!r}"
    )


def _cage_23_pearson_overflow_is_unmeasurable():
    """Round-5 audit F2: finite monthly observations that overflow inside pearson()
    must yield an UNMEASURABLE pair (conservative 1.0 fallback) -- never a raw
    OverflowError, and never a stored 0.0/non-finite correlation."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "EA_LAB_deals_997_20260101.csv"
        with open(p, "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["time", "magic", "entry", "profit", "swap", "commission"])
            vals = ("1e308", "-1e308", "1e308", "-1e308")
            for i, ym in enumerate(("2026.01", "2026.02", "2026.03", "2026.04")):
                w.writerow([f"{ym}.15 10:00:00", "111", "1", vals[i], "0", "0"])
                w.writerow([f"{ym}.15 11:00:00", "222", "1", str(float(i + 1)), "0", "0"])
        corr = compute_corr_matrix(["111", "222"], td)   # must not raise
    assert frozenset(("111", "222")) not in corr, (
        f"overflowing pair must be unmeasurable, got {corr!r}"
    )
    for v in corr.values():
        assert math.isfinite(v)
    assert get_corr(corr, "111", "222") == 1.0
    # direct probe: pearson on the overflowing series itself
    assert pearson([1e308, -1e308, 1e308, -1e308], [1.0, 2.0, 3.0, 4.0]) is None


def _cage_24_exact_budget_defers_not_refuses():
    """Round-5 audit F3: an existing portfolio exactly AT budget is a valid state --
    the candidate must get DEFER_ESCALATE (no positive lot fits), not a REFUSED
    'corr matrix invalid' misclassification."""
    for bmf in (None, 0.01):
        res = admit_candidate("C", 1.0, {"A": 25.0}, {}, 25.0, broker_min_lot_factor=bmf)
        assert res["status"] == "DEFER_ESCALATE", f"bmf={bmf!r}: {res!r}"
        assert res["lot_factor"] is None
    # just over budget still takes the pre-existing-over-budget branch
    over = admit_candidate("C", 1.0, {"A": 25.000001}, {}, 25.0)
    assert over["status"] == "DEFER_ESCALATE" and "existing portfolio" in over["message"]


def _cage_25_conflicting_siblings_use_canonical_basket_dd95():
    """Round-6 audit F1: PENDING basket siblings with CONFLICTING DD95 values must be
    sized at the basket's canonical conservative value (the larger -- same rule the
    summary uses), never at whichever sibling row comes first. Audit repro: E=10,
    F=30 sharing basket BY, budget 25 -- the old code admitted E at 10 while the
    summary said 30/OVER BUDGET; reversing row order changed the outcome."""
    for order in (("E", "F"), ("F", "E")):
        deployments = [_mk_row("111", mg, "PENDING_ATTACH") for mg in order]
        report = build_report(deployments, {"E": 10.0, "F": 30.0}, {},
                              basket_of={"E": "BY", "F": "BY"})
        first = report["admission_demo"][0]
        assert first["status"] == "DEFER_ESCALATE", (
            f"order {order}: first sibling must be sized at canonical 30 (> budget 25), "
            f"got {first!r}"
        )
        # round-6 audit F3: the understated row's decision must CARRY the field
        # (no .get default -- deleting the field must fail this test)
        d_e = next(d for d in report["admission_demo"] if d["magic"] == "E")
        assert d_e["basket_dd95_used"] == 30.0, f"order {order}: {d_e!r}"
        # no decision in either order may grant a lot at the understated 10
        for d in report["admission_demo"]:
            assert d["status"] not in ("ADMIT_FULL", "ADMIT_REDUCED"), (
                f"order {order}: understated sibling was granted a lot: {d!r}"
            )
    # round-6 audit F1: an ACTIVE basket leg must be carried at the basket's
    # canonical ALL-row value (PENDING sibling declares 30) before sizing an
    # unrelated candidate -- G must not be admitted into a 40% portfolio.
    for order in (("F", "G"), ("G", "F")):
        deployments = [_mk_row("111", "E", "ACTIVE")] + [
            _mk_row("111", mg, "PENDING_ATTACH") for mg in order]
        report = build_report(deployments, {"E": 10.0, "F": 30.0, "G": 10.0}, {},
                              basket_of={"E": "BY", "F": "BY"})
        demo = {d["magic"]: d for d in report["admission_demo"]}
        assert demo["F"]["status"] == "CANNOT_RUN", f"order {order}: {demo['F']!r}"
        assert demo["G"]["status"] == "DEFER_ESCALATE", (
            f"order {order}: G sized against the understated ACTIVE-only basket value: "
            f"{demo['G']!r}"
        )
    # round-7 audit F1: an ACTIVE basket leg with UNKNOWN own-DD95 whose PENDING
    # sibling supplies the known basket-level value is STILL existing risk -- the
    # sibling must be CANNOT_RUN and an unrelated candidate must see that risk,
    # in both pending orders.
    for order in (("F", "G"), ("G", "F")):
        deployments = [_mk_row("111", "E", "ACTIVE")] + [
            _mk_row("111", mg, "PENDING_ATTACH") for mg in order]
        report = build_report(deployments, {"F": 20.0, "G": 10.0}, {},
                              basket_of={"E": "BY", "F": "BY"})   # E's own DD95 UNKNOWN
        demo = {d["magic"]: d for d in report["admission_demo"]}
        assert demo["F"]["status"] == "CANNOT_RUN", (
            f"order {order}: sibling of an ACTIVE basket must not be sized: {demo['F']!r}"
        )
        assert demo["G"]["status"] == "DEFER_ESCALATE", (
            f"order {order}: G must see the ACTIVE basket's known risk 20: {demo['G']!r}"
        )
    # round-6 audit F4: a REFUSED record after an admission must carry provenance
    report3 = build_report(
        [_mk_row("111", "C", "PENDING_ATTACH"), _mk_row("111", "D", "PENDING_ATTACH")],
        {"C": 10.0, "D": 10.0}, {frozenset(("C", "D")): -1.0},
    )
    demo3 = {d["magic"]: d for d in report3["admission_demo"]}
    assert demo3["C"]["status"] == "ADMIT_FULL"
    assert demo3["D"]["status"] == "REFUSED", f"{demo3['D']!r}"
    assert demo3["D"]["assumes_admitted_first"] == ["C"], (
        f"REFUSED after an admission must name the assumption: {demo3['D']!r}"
    )
    # round-6 audit F2: near-equal siblings (inside the 1e-9 message tolerance)
    # must still collapse to the MAX in both insertion orders
    bof = {"E": "BY", "F": "BY"}
    u1, _ = collapse_basket_risk_units({"E": 10.0, "F": 10.0000000005}, bof)
    u2, _ = collapse_basket_risk_units({"F": 10.0000000005, "E": 10.0}, bof)
    assert u1 == u2 == {_basket_key("BY"): 10.0000000005}, (
        f"near-equal collapse is order-dependent: {u1!r} vs {u2!r}"
    )
    # F2: a later CANNOT_RUN sibling must carry the sequential provenance list
    report2 = build_report(
        [_mk_row("111", "E", "PENDING_ATTACH"), _mk_row("111", "F", "PENDING_ATTACH")],
        {"E": 10.0, "F": 10.0}, {}, basket_of={"E": "BY", "F": "BY"},
    )
    demo2 = {d["magic"]: d for d in report2["admission_demo"]}
    assert demo2["E"]["status"] == "ADMIT_FULL"
    assert demo2["F"]["status"] == "CANNOT_RUN"
    assert demo2["F"].get("assumes_admitted_first") == ["E"], (
        f"CANNOT_RUN after an admission must name the assumption: {demo2['F']!r}"
    )


def _cage_26_pearson_result_stays_in_range():
    """Round-6 audit F3: a finite pearson quotient outside [-1, 1] (subnormal
    underflow) must be clamped (epsilon overshoot) or unmeasurable (None) -- never
    stored out of range where it breaks the bounds invariant downstream."""
    xs = [0.0, -1e-200, -1e-200, -1e-320, 1e-160]
    ys = [-1e-320, -5e-324, -5e-324, -5e-324, 1e-100]
    r = pearson(xs, ys)
    assert r is None or abs(r) <= 1.0, f"pearson emitted out-of-range {r!r}"
    # a clean series still measures normally
    ok = pearson([1.0, 2.0, 3.0, 4.0], [2.0, 4.0, 6.0, 8.0])
    assert ok is not None and abs(ok - 1.0) < 1e-12


CAGE_TESTS = [
    ("1_golden_sample", _cage_1_golden_sample),
    ("2_bounds_assert", _cage_2_bounds_assert),
    ("3_missing_corr_defaults_to_one", _cage_3_missing_corr_defaults_to_one),
    ("4_lot_factor_bounds", _cage_4_lot_factor_bounds),
    ("5_parser_rejects_every_unknown_form", _cage_5_parser_rejects_every_unknown_form),
    ("6_expectations_file_absent", _cage_6_expectations_file_absent),
    ("7_basket_counted_once", _cage_7_basket_counted_once),
    ("8_corrupt_pnl_does_not_become_zero", _cage_8_corrupt_pnl_does_not_become_zero),
    ("9_admit_bounds_guard_on_existing", _cage_9_admit_candidate_bounds_guard_on_existing),
    ("10_broker_min_fails_closed", _cage_10_broker_min_fails_closed),
    ("11_rounded_factor_within_budget", _cage_11_rounded_factor_still_within_budget),
    ("12_admission_path_collapses_baskets", _cage_12_admission_path_collapses_baskets),
    ("13_basket_id_magic_namespace_separation", _cage_13_basket_id_magic_namespace_separation),
    ("14_emitted_reduced_respects_lower_bound", _cage_14_emitted_reduced_point_respects_lower_bound),
    ("15_formula_guard_mutation_protection", _cage_15_formula_guard_mutation_protection),
    ("16_nonfinite_pnl_poisons_magic_end_to_end", _cage_16_nonfinite_pnl_poisons_magic_end_to_end),
    ("17_admission_validates_own_inputs", _cage_17_admission_validates_own_inputs),
    ("18_safe_output_path_guard", _cage_18_safe_output_path_guard),
    ("19_basketed_candidate_same_identity", _cage_19_basketed_candidate_same_identity_both_paths),
    ("20_overflowing_pnl_poisons_magic", _cage_20_overflowing_pnl_poisons_magic),
    ("21_extreme_finite_inputs_fail_closed", _cage_21_extreme_finite_inputs_fail_closed_with_domain_error),
    ("22_multiple_pending_decisions_compose", _cage_22_multiple_pending_decisions_compose),
    ("23_pearson_overflow_is_unmeasurable", _cage_23_pearson_overflow_is_unmeasurable),
    ("24_exact_budget_defers_not_refuses", _cage_24_exact_budget_defers_not_refuses),
    ("25_conflicting_siblings_canonical_dd95", _cage_25_conflicting_siblings_use_canonical_basket_dd95),
    ("26_pearson_result_stays_in_range", _cage_26_pearson_result_stays_in_range),
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

def _assert_safe_output_path(label, dest, args):
    """Refuse to write over the script's own inputs or any .set file (ORDER-170 SEV-2 #8).
    This script is advisory-only; a run must never be able to destroy the inventory it
    reads, the expectations it consumes, or a live trading configuration."""
    p = Path(dest).resolve()
    if p.suffix.lower() == ".set":
        raise SystemExit(f"REFUSED: {label}={dest} targets a .set file -- this script never writes trading configs")
    protected = {
        Path(args.deployments).resolve(): "the deployments inventory it reads",
        Path(args.expectations).resolve(): "the expectations file it reads",
        Path(DEPLOYMENTS_CSV).resolve(): "portfolio/DEPLOYMENTS.csv",
        Path(EXPECTATIONS_CSV).resolve(): "portfolio/expectations.csv",
    }
    if p in protected:
        raise SystemExit(f"REFUSED: {label}={dest} would overwrite {protected[p]}")
    # ORDER-170 round-3 SEV-2 #7: Path.resolve() equality cannot see NTFS hard links
    # -- an alias named report.txt hard-linked to a protected CSV/.set passes both
    # lexical checks above, and writing it truncates the protected file. If the
    # destination already exists, compare file identity (st_dev, st_ino), and refuse
    # any multi-hard-link destination outright: this script only ever writes plain
    # single-link report files, so nlink > 1 means an alias we cannot certify.
    try:
        st = p.stat()
    except OSError:
        st = None  # destination does not exist yet -- nothing it can alias
    if st is not None:
        if getattr(st, "st_nlink", 1) > 1:
            raise SystemExit(
                f"REFUSED: {label}={dest} has {st.st_nlink} hard links -- cannot certify it is "
                "not an alias of a protected file; this script only writes single-link report files"
            )
        for q, why in protected.items():
            try:
                qst = q.stat()
            except OSError:
                continue
            if st.st_ino and qst.st_ino and (st.st_dev, st.st_ino) == (qst.st_dev, qst.st_ino):
                raise SystemExit(f"REFUSED: {label}={dest} is the same file as {why} (hard-link alias)")


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

    # ORDER-170 SEV-2 #8: --out-md/--out-json previously accepted ANY path, so
    # `--out-md portfolio/DEPLOYMENTS.csv` would read the inventory and then overwrite
    # it with markdown -- directly contradicting this script's "never writes to
    # DEPLOYMENTS/expectations/.set" guarantee. Refuse protected destinations.
    for label, dest in (("--out-md", args.out_md), ("--out-json", args.out_json)):
        _assert_safe_output_path(label, dest, args)

    deployments = load_deployments(args.deployments)
    dd95_map, basket_of = load_expectations_with_baskets(args.expectations)
    magics = sorted({r["magic"] for r in deployments})
    corr_matrix = compute_corr_matrix(magics, args.live_deals)

    report = build_report(deployments, dd95_map, corr_matrix, basket_of=basket_of,
                          expectations_path=args.expectations)
    md = render_markdown(report)

    Path(args.out_md).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out_md).write_text(md, encoding="utf-8")
    Path(args.out_json).write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(f"wrote {args.out_md}")
    print(f"wrote {args.out_json}")


if __name__ == "__main__":
    main()
