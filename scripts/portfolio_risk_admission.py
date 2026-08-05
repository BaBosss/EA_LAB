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
# ORDER-174: explicit magic -> backtest-report mapping. Reports in _mt5_auto/reports
# have ad-hoc names (4,700+ files) -- NEVER inferred/guessed; every row in this file
# is placed deliberately and is auditable. Missing file => backtest corr simply
# unavailable (pairs stay at the conservative 1.0 default).
BACKTEST_CORR_MAP = ROOT / "portfolio" / "backtest_corr_reports.csv"
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


# --------------------------------------------------------------------------- #
# 2026-07-25: single-leg-basket correlation resolution -- OFF BY DEFAULT, PENDING AUDIT
#
# THE OBSERVATION. A basket leg is keyed 'basket::<id>' so a basket-level DD95 is not
# counted once per leg. But get_corr() is keyed by MAGIC, so a 'basket::' key can never
# match a measured correlation and always falls back to the conservative 1.0. When a
# basket has only ONE leg with a known DD95, that rename buys no dedup at all and costs
# every correlation the leg has. On account 463666728 the two biggest units (the IchiADX
# baskets, 22.19% and 10.77%, each with exactly one known leg) were therefore treated as
# fully additive with all 12 other EAs: reported 73.04% where the same formula over the
# same already-measured correlations gives 38.35%.
#
# WHY IT IS STILL OFF. Over-statement is the safe direction, and the 1.0 default is a
# DELIBERATE, cage-protected choice (cage 19), not an oversight. Resolving it swaps a
# basket-level DD95 against a single LEG's correlation series -- defensible, but a
# judgment call on money-adjacent logic with no independent review available today
# (Codex quota exhausted). Same discipline ORDER-200 Phase D used: build it, default it
# off, change no live number until it is audited and the user ratifies.
#
# TO REVIEW: run with --resolve-single-leg-baskets and compare. Flipping the default is
# a decision, not a cleanup.
# --------------------------------------------------------------------------- #
RESOLVE_SINGLE_LEG_BASKETS = False


def basket_unit_keys(dd95_by_magic, basket_of, resolve_single_leg=None):
    """{basket_id: the risk-unit key that basket collapses to}, for the given set of
    known-DD95 magics. THE single source of truth for that mapping -- the account
    summary and the admission path must agree on a candidate's unit identity
    (ORDER-170 round-4 SEV-1), so neither may re-derive this rule by hand.

    >= 2 known legs -> 'basket::<id>' (a real collapse).
     1 known leg    -> 'basket::<id>' as well by DEFAULT (conservative: its
                       correlations stay unresolved at 1.0). Only when
                       RESOLVE_SINGLE_LEG_BASKETS is on does it key by that leg's own
                       magic so its measured correlations resolve -- see the block
                       comment above; that switch is unaudited and off in normal runs.
    """
    resolve = RESOLVE_SINGLE_LEG_BASKETS if resolve_single_leg is None else resolve_single_leg
    legs = {}
    for magic in dd95_by_magic:
        basket = basket_of.get(magic)
        if basket:
            legs.setdefault(basket, []).append(magic)
    return {
        b: (ms[0] if (resolve and len(ms) == 1) else _basket_key(b))
        for b, ms in legs.items()
    }


def collapse_basket_risk_units(dd95_by_magic, basket_of, unit_keys=None):
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

    # 2026-07-25 fix: a basket contributes a `basket::` key ONLY when it actually has
    # >= 2 legs to collapse here. With a single known-DD95 leg there is nothing to
    # dedup, and renaming that leg to `basket::<id>` silently destroyed every
    # correlation measured for it -- get_corr() is keyed by MAGIC, so a basket:: key
    # can never resolve and falls back to the conservative 1.0 against the whole
    # portfolio. Observed on account 463666728: the two largest DD95 units (the
    # IchiADX baskets, 22.19% and 10.77%, each with exactly ONE known leg) were being
    # treated as fully additive with all 12 other EAs, reporting 73.04% where the same
    # formula over the same measured correlations gives 38.35%. Over-statement is the
    # safe direction, but a number nobody can act on is its own failure.
    # Multi-leg baskets are UNCHANGED (still collapsed, still conservative): picking a
    # representative leg's correlation series for a real 2-leg basket is a judgment
    # call, not a bug fix, and is queued for the Codex risk-path audit.
    # `unit_keys` MUST be supplied whenever this is called on a SUBSET of an account's
    # magics (e.g. ACTIVE-only vs all rows). Deriving the rule per-subset makes a
    # basket's identity depend on which slice you happen to be looking at -- an
    # ACTIVE-only slice can see 1 leg (key = magic) while the all-rows slice sees 2
    # (key = 'basket::<id>'), and the two paths then disagree about the same basket.
    # Cage 12 caught exactly that. One canonical inventory decides, everyone follows.
    basket_keys = basket_unit_keys(dd95_by_magic, basket_of) if unit_keys is None else unit_keys

    # ORDER-433 (Codex blind audit 2026-07-27, second defect -- latent, no observed
    # failure on any current caller). A SUPPLIED unit_keys map was trusted verbatim and
    # never checked for coverage. Any basket it omits silently fails the identity test
    # below, so both legs keep their own magic keys and the basket is counted TWICE:
    # DD95={L1:10, L2:10} in basket BX with unit_keys={} reports 20.0% where the
    # canonical keys report 10.0%. That is an UNDERCOUNT of diversification, i.e. an
    # overstatement of risk -- the safe direction, which is exactly why it could sit
    # here unnoticed. It is still a wrong number produced silently, and the next caller
    # to build a partial map gets it with no warning at all.
    if unit_keys is not None:
        represented = {b for b in (basket_of.get(m) for m in dd95_by_magic) if b}
        uncovered = sorted(represented - set(basket_keys))
        if uncovered:
            raise RiskAdmissionError(
                "unit_keys does not cover every basket represented in dd95_by_magic: "
                f"missing {', '.join(uncovered)}. Supply the map from "
                "basket_unit_keys() over the SAME inventory slice, or pass None to "
                "have it derived. A partial map silently double-counts the omitted "
                "basket instead of collapsing it."
            )

    for magic, val in dd95_by_magic.items():
        basket = basket_of.get(magic)
        if basket and basket_keys.get(basket) != _basket_key(basket):
            basket = None   # single known leg -> keep the magic key so corr resolves
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


# ORDER-174 round-4 (audit F1): ONE consistent thousands separator per number --
# the per-group class [ ,] let '3,000 000' fabricate 3000000.0
_MONEY_GROUPED_RE = re.compile(r"^-?\d{1,3}(?:(?:,\d{3})+|(?: \d{3})+)(?:\.\d+)?$")
# strict full MT5 deal timestamp: 'YYYY.MM.DD HH:MM[:SS]' -- space separator ONLY
# (round-4 audit F2: '[ T]' accepted a 'T' MT5 never emits), full-match anchored
# (prefix-only matching let '2026.013...' count month '01' as a real observation)
_DEAL_TS_RE = re.compile(r"^(\d{4})\.(\d{2})\.(\d{2}) (\d{2}):(\d{2})(?::(\d{2}))?$")


def _parse_money_cell(s):
    """Money-cell parse with separator discipline (ORDER-174 round-3, audit F3):
    commas/spaces are accepted ONLY as well-formed thousands grouping ('1,234.5',
    '1 234'). '1,0' is malformed (or a locale decimal) and must be CORRUPT --
    blind comma deletion turned it into 10.0, a different finite number."""
    s = str(s).replace("\xa0", " ").strip()
    if "," in s or " " in s:
        if not _MONEY_GROUPED_RE.match(s):
            return CORRUPT
        s = s.replace(" ", "").replace(",", "")
    return _num(s)


def _read_report_text(path):
    """MT5 saves .htm reports as UTF-16 (BOM) or UTF-8 -- mirror of the decoder in
    _mt5_auto/corr_monthly.py, whose parsing method ORDER-154's DESIGN specified."""
    raw = Path(path).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")


def _extract_backtest_monthly(paths):
    """Monthly realized P&L (profit+commission+swap of 'out' deals) from MT5 backtest
    report HTML files -- the same bucket method as _mt5_auto/corr_monthly.py
    (ORDER-154 DESIGN source), with this module's corruption discipline on top.

    Returns (monthly, None) on success or (None, reason) when the series must be
    POISONED -- a poisoned series never contributes observations. Poison causes
    (ORDER-174 round-2, audit F2/F3/F5): unreadable file · unparseable or
    non-finite money cell · an impossible calendar month (a '2026.13' is corrupt
    data, not a 13th month) · the SAME month appearing in two mapped reports
    (windows must be non-overlapping and month-boundary-aligned; a month summed
    from two files double-counts deals and biases the correlation)."""
    monthly = defaultdict(float)
    months_by_file = []
    row_re = re.compile(r"<tr[^>]*>(.*?)</tr>", re.S)
    cell_re = re.compile(r"<t[dh][^>]*>(.*?)</t[dh]>", re.S)
    tag_re = re.compile(r"<[^>]+>")
    for path in paths:
        try:
            text = _read_report_text(path)
        except OSError as e:
            return None, f"unreadable mapped report {Path(path).name}: {e}"
        file_months = set()
        for r in row_re.findall(text):
            cells = [tag_re.sub("", c).strip() for c in cell_re.findall(r)]
            # ORDER-174 round-3 (audit F1): a row that carries a realized-deal
            # direction cell ('out') but NOT the 13-cell deals shape is structural
            # corruption -- silently skipping it published the remaining segment as
            # a complete series. Poison instead of pretending the row never existed.
            if len(cells) != 13:
                if any(c.lower() == "out" for c in cells):
                    return None, (
                        f"deals-shaped row with {len(cells)} cells (expected 13) in "
                        f"{Path(path).name} -- report structurally malformed"
                    )
                continue
            if cells[4].lower() != "out":
                continue
            mm = _DEAL_TS_RE.match(cells[0])
            if not mm:
                return None, (
                    f"unparseable deal timestamp {cells[0]!r} in {Path(path).name} "
                    "-- report data corrupt"
                )
            month, day = int(mm.group(2)), int(mm.group(3))
            hour, minute = int(mm.group(4)), int(mm.group(5))
            second = int(mm.group(6)) if mm.group(6) is not None else 0
            if (not (1 <= month <= 12) or not (1 <= day <= 31)
                    or hour > 23 or minute > 59 or second > 59):
                return None, (
                    f"impossible calendar month/date {cells[0]!r} in {Path(path).name} "
                    "-- report data corrupt"
                )
            parts = []
            for idx in (10, 8, 9):  # profit, commission, swap
                v = _parse_money_cell(cells[idx])
                if v is CORRUPT:
                    return None, f"corrupt money cell in {Path(path).name}"
                parts.append(v)
            ym = f"{mm.group(1)}-{mm.group(2)}"
            file_months.add(ym)
            monthly[ym] += sum(parts)
        months_by_file.append(file_months)
    for i in range(len(months_by_file)):
        for j in range(i + 1, len(months_by_file)):
            overlap = months_by_file[i] & months_by_file[j]
            if overlap:
                return None, (
                    f"month(s) {sorted(overlap)} appear in more than one mapped report "
                    "-- overlapping windows double-count deals; map only "
                    "non-overlapping, month-boundary-aligned reports"
                )
    if any(not math.isfinite(v) for v in monthly.values()):
        return None, "aggregation overflow (non-finite monthly total)"
    return monthly, None


def load_backtest_monthly_by_magic(map_csv=BACKTEST_CORR_MAP):
    """magic -> {YYYY-MM: P&L} from the explicit report map. Fail-soft by design:
    a missing map file, a missing report file, or a poisoned series just leaves that
    magic OUT (its pairs fall back to the conservative 1.0 default) and the reason
    is returned in `skipped` for the report. Never guesses, never crashes the run."""
    monthly_by_magic = {}
    skipped = []
    p = Path(map_csv)
    if not p.is_file():
        return monthly_by_magic, skipped
    paths_by_magic = defaultdict(list)
    # ORDER-174 round-2 (audit F1): a magic whose mapped rows are not ALL present and
    # readable is excluded ENTIRELY -- a partial series (IS present, OOS missing)
    # would be published as if complete and can bias the measured correlation.
    bad_magic = {}
    with open(p, encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            magic = (row.get("magic") or "").strip()
            rel = (row.get("report_path") or "").strip()
            if not magic or not rel:
                continue
            rp = (ROOT / rel) if not Path(rel).is_absolute() else Path(rel)
            if not rp.is_file():  # F5: a directory passes exists() but crashes reads
                bad_magic.setdefault(
                    magic, f"mapped path missing or not a regular file: {rel}")
                continue
            paths_by_magic[magic].append(rp)
    for magic, reason in bad_magic.items():
        skipped.append(
            f"{magic}: {reason} -- WHOLE magic excluded (a partial series would "
            "understate risk); its pairs fall back to the 1.0 default"
        )
        paths_by_magic.pop(magic, None)
    for magic, paths in paths_by_magic.items():
        monthly, reason = _extract_backtest_monthly(paths)
        if reason is not None:
            # round-3 (audit F5): every exclusion carries the same explicit wording
            skipped.append(
                f"{magic}: {reason} -- series poisoned, WHOLE magic excluded, "
                "pairs default to 1.0"
            )
            continue
        if not monthly:
            skipped.append(
                f"{magic}: no realized 'out' deals parsed from mapped report(s) -- "
                "WHOLE magic excluded, pairs default to 1.0"
            )
            continue
        monthly_by_magic[magic] = monthly
    return monthly_by_magic, skipped


def _pairs_from_monthly(monthly_by_magic, magics):
    """Measured Pearson pairs from monthly series -- shared measurement rule for both
    live and backtest sources (>= MIN_SHARED_MONTHS overlap, finite result only)."""
    corr = {}
    mags = [m for m in magics if m in monthly_by_magic]
    for i in range(len(mags)):
        for j in range(i + 1, len(mags)):
            a, b = mags[i], mags[j]
            common = sorted(set(monthly_by_magic[a]) & set(monthly_by_magic[b]))
            if len(common) < MIN_SHARED_MONTHS:
                continue
            c = pearson([monthly_by_magic[a][m] for m in common],
                        [monthly_by_magic[b][m] for m in common])
            if c is None or not math.isfinite(c):
                continue
            corr[frozenset((a, b))] = c
    return corr


def _add_basket_series(monthly_by_key, basket_of):
    """ORDER-433. Add a `basket::<id>` monthly series built by SUMMING every leg of
    that basket, so a collapsed basket risk unit carries correlations of its own
    instead of falling back to get_corr()'s conservative 1.0.

    WHY THIS REPLACES THE PROXY
    collapse_basket_risk_units keys a real multi-leg basket as `basket::<id>`, but the
    correlation matrix was keyed by MAGIC only, so that key could never resolve. The
    previously-proposed workaround was --resolve-single-leg-baskets: key the basket by
    ONE representative leg and borrow that leg's correlations. Codex's blind audit
    (2026-07-27, evidence in _triage/CODEX_AUDIT_RESULTS_2026-07-27.md sec 2) rejected
    that framing outright -- both second-leg reports are already on disk, and the merge
    scripts _mt5_auto/ichi_basket_merge_mc.ps1:18 and xau_basket_merge_mc.ps1:14 name
    the exact pairs. When the true combined series is computable, a proxy for it is not
    a conservative fallback, it is a guess whose error has no known sign.

    ALL-OR-NOTHING ON PURPOSE
    A basket whose legs are not ALL present is left out entirely, mirroring
    load_backtest_monthly_by_magic's existing rule for a partial per-magic series.
    A basket series summed from a SUBSET of its legs IS the single-leg proxy this
    replaces, wearing a basket's name -- worse than the 1.0 default, because it would
    look authoritative while being the same guess.

    Returns (new_mapping, added_basket_ids, incomplete) -- `incomplete` carries the
    reason per basket so the report can say what it could not measure rather than
    quietly measuring less.
    """
    legs_by_basket = defaultdict(list)
    for magic, basket in (basket_of or {}).items():
        if basket:
            legs_by_basket[basket].append(magic)

    out = dict(monthly_by_key)
    added = []
    incomplete = []
    for basket, legs in sorted(legs_by_basket.items()):
        legs = sorted(set(legs))
        if len(legs) < 2:
            # one leg total is not a basket to combine: there is nothing to sum, and
            # keying it as `basket::` would be the proxy again. Leave it to the 1.0
            # default, which is what the pre-registered rule already says.
            continue
        have = [m for m in legs if m in monthly_by_key]
        missing = [m for m in legs if m not in monthly_by_key]
        if missing:
            incomplete.append(
                f"{basket}: no series for leg(s) {', '.join(missing)} -- basket left "
                "UNMEASURED (a partial sum would be the single-leg proxy under another "
                "name); its pairs fall back to the 1.0 default"
            )
            continue
        summed = defaultdict(float)
        for m in have:
            for ym, v in monthly_by_key[m].items():
                summed[ym] += v
        # same poison rule as every other series in this file: a non-finite total is
        # corrupt data, not a number.
        if any(not math.isfinite(v) for v in summed.values()):
            incomplete.append(
                f"{basket}: aggregation overflow (non-finite monthly total) -- basket "
                "left UNMEASURED, pairs fall back to the 1.0 default"
            )
            continue
        out[_basket_key(basket)] = dict(summed)
        added.append(basket)
    return out, added, incomplete


def compute_corr_with_backtest(magics, live_deals_dir=LIVE_DEALS_DIR,
                               backtest_map_csv=BACKTEST_CORR_MAP, basket_of=None):
    """ORDER-174: correlation from BOTH sources with explicit per-pair provenance.
    LIVE wins over BACKTEST when both measured a pair (live is the higher-quality
    evidence); any pair neither could measure stays absent -> get_corr() applies the
    conservative 1.0 default exactly as before. The formula and the default are NOT
    touched here -- this only widens what can be measured.

    Returns (corr, quality, backtest_skipped):
      corr     {frozenset(pair): float}
      quality  {frozenset(pair): "live" | "backtest"}  (absent pair = default 1.0)
      backtest_skipped  [str] -- mapped magics that could not be used, with reasons
    """
    live_corr = compute_corr_matrix(magics, live_deals_dir, basket_of=basket_of)
    bt_monthly, bt_skipped = load_backtest_monthly_by_magic(backtest_map_csv)
    # ORDER-433: measure the basket units too, not only the magics. The keys the
    # formula actually asks get_corr() about are the RISK-UNIT keys that
    # collapse_basket_risk_units produces, and for a multi-leg basket that is
    # `basket::<id>` -- a key the matrix never contained.
    bt_monthly, _bt_baskets, bt_incomplete = _add_basket_series(bt_monthly, basket_of)
    bt_skipped = list(bt_skipped) + bt_incomplete
    bt_corr = _pairs_from_monthly(
        bt_monthly, list(magics) + _basket_keys_present(bt_monthly))
    corr = {}
    quality = {}
    for pair, v in bt_corr.items():
        corr[pair] = v
        quality[pair] = "backtest"
    for pair, v in live_corr.items():  # live overwrites backtest -- higher tier
        corr[pair] = v
        quality[pair] = "live"
    return corr, quality, bt_skipped


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


def _basket_keys_present(mapping):
    """The `basket::` keys in a series mapping, sorted. One place so the prefix test
    is not spelled out in three call sites (the drift _basket_key already guards)."""
    pref = _basket_key("")
    return sorted(k for k in mapping if isinstance(k, str) and k.startswith(pref))


def compute_corr_matrix(magics, live_deals_dir=LIVE_DEALS_DIR, basket_of=None):
    """Best-effort monthly-return correlation for the given magics from live deal
    history actually on disk. A pair with fewer than MIN_SHARED_MONTHS overlapping
    months is simply left OUT of the returned dict -- get_corr() is what applies the
    1.0-default safety rule, this function only reports what it could measure."""
    monthly, corrupted = load_monthly_pnl_by_magic(live_deals_dir)
    # ORDER-170 SEV-1 #2: a magic with ANY corrupted P&L cell is excluded from
    # measurement entirely, so every pair involving it stays missing and get_corr()
    # applies the conservative 1.0 default instead of a correlation computed from
    # partly-fabricated data.
    usable = {m: v for m, v in monthly.items() if m not in corrupted}
    # ORDER-433: basket units get a summed series here too, not only on the backtest
    # side. A `basket::` key that resolves from one source and not the other would make
    # the reported number depend on which evidence tier happened to be available.
    # The all-or-nothing rule in _add_basket_series inherits the poison rule for free:
    # a corrupted leg is simply absent from `usable`, so its basket stays unmeasured.
    usable, _added, _incomplete = _add_basket_series(usable, basket_of)
    # ORDER-170 round-4 SEV-2 (overflow -> nan/inf) and the MIN_SHARED_MONTHS rule both
    # live in _pairs_from_monthly, which is the shared measurement rule for live and
    # backtest alike -- this used to be a second hand-written copy of it.
    return _pairs_from_monthly(usable, list(magics) + _basket_keys_present(usable))


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


def _fits_budget(dd, budget):
    """ORDER-170 round-10: THE single budget comparison -- strict, equality admits.
    Both admit_candidate() call sites (full-size and emitted-reduced) must use this
    helper so a tolerance can never quietly return on one of them (round-9 audit F2:
    the reduced-path comparison was not mutation-locked while it was hand-written)."""
    return dd <= budget


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

    # round-10 audit MINOR: route through the same mutation-locked strict helper --
    # no hand-written DD-vs-budget comparison may remain anywhere in this function.
    if not _fits_budget(existing_dd, budget_pct):
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

    # ORDER-170 round-9 (audit round-8 F1): STRICT budget comparison. The former
    # +1e-9 tolerance could grant a full lot while the summary (strict) said OVER
    # BUDGET in the same report. Equality is allowed; any excess -- however tiny --
    # defers instead. Conservative direction: a float-noise refusal is acceptable,
    # a granted breach is not.
    if _fits_budget(full_dd, budget_pct):
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
    # round-9: strict, matching the full-size check and the summary's over_budget rule
    if not _fits_budget(dd_at_emit, budget_pct):
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
    acct_name = rows[0]["account_name"] if rows else ""
    # ORDER-170 round-9/10 (audit F2 + round-9 F1/F3): the account TYPE must be
    # derived from the ROW SET, never from rows[0] -- inventory order was selecting
    # between DEMO sizing and REAL_CENT report-only. Rules: normalize case; blank
    # rows are missing metadata and do not vote; exactly one distinct non-blank type
    # -> that type (order-independent); two or more -> data-error conflict: no
    # budget, deterministic CONFLICT(...) label, and build_report() refuses to size
    # any candidate on this account.
    types_seen = sorted({(r["type"] or "").strip().upper() for r in rows
                         if (r["type"] or "").strip()})
    type_conflict = len(types_seen) > 1
    if type_conflict:
        acct_type = "CONFLICT(" + "|".join(types_seen) + ")"
        budget_pct, budget_note = None, (
            f"CONFLICTING account-type metadata in DEPLOYMENTS.csv ({' vs '.join(types_seen)}) "
            "-- data error, no budget assigned, fix the inventory before sizing anything"
        )
    else:
        acct_type = types_seen[0] if types_seen else ""
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
        "type_conflict": type_conflict,
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
                 expectations_path=EXPECTATIONS_CSV,
                 corr_quality=None, backtest_skipped=None,
                 backtest_map_path=BACKTEST_CORR_MAP):
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
        # ORDER-170 round-9 (audit round-8 F2): conflicting account-type metadata =
        # data error; refuse to size anything on this account (REPORT_ONLY via a None
        # budget would look like a normal REAL_CENT outcome -- be explicit instead).
        if acct_summary.get("type_conflict"):
            for cand in pending:
                admission_demo.append({
                    "account": acct, "magic": cand["magic"], "ea_name": cand["ea_name"],
                    "status": "CANNOT_RUN",
                    "message": acct_summary["budget_note"],
                })
            continue
        active_known = {
            r["magic"]: dd95_map[r["magic"]]
            for r in rows if r["status"] == "ACTIVE" and r["magic"] in dd95_map
        }
        # ORDER-170 round-3 SEV-1 #1: the admission decision must see the SAME
        # collapsed risk units as the account summary, or the two paths disagree on
        # the same input (summary said 20%, admission sized against 30%). Collapse
        # basket legs BEFORE handing the existing portfolio to admit_candidate().
        # The canonical inventory for THIS account is all its known-DD95 rows (ACTIVE
        # and PENDING). Every collapse below is a slice of it and must be keyed by the
        # same rule -- see basket_unit_keys / cage 12.
        all_known = {r["magic"]: dd95_map[r["magic"]] for r in rows if r["magic"] in dd95_map}
        all_unit_keys = basket_unit_keys(all_known, basket_of or {})
        active_units, _active_folded = collapse_basket_risk_units(
            active_known, basket_of or {}, unit_keys=all_unit_keys)
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
        units_all, _ = collapse_basket_risk_units(
            all_known, basket_of or {}, unit_keys=all_unit_keys)
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
                k = all_unit_keys.get(b)
                if k is not None and k in units_all and k not in existing_units:
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
            cand_key = all_unit_keys.get(cand_basket, m) if cand_basket else m
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

    # ORDER-174: per-pair correlation provenance -- live and backtest are DIFFERENT
    # evidence quality and must never look the same; every pair not listed here ran
    # on the conservative 1.0 default.
    quality = corr_quality or {}
    active_magics = sorted({r["magic"] for r in active_rows})
    n_possible = len(active_magics) * (len(active_magics) - 1) // 2
    measured = []
    for pair, v in sorted(corr_matrix.items(), key=lambda kv: sorted(kv[0])):
        if not all(m in active_magics for m in pair):
            continue  # a pair with a removed/inactive magic backs no number above
        a, b = sorted(pair)
        measured.append({
            "pair": f"{a}~{b}",
            "corr": round(v, 4),
            "source": quality.get(pair, "live" if not quality else "unknown"),
        })
    corr_coverage = {
        "possible_pairs_active_or_pending": n_possible,
        "measured_pairs": len(measured),
        "measured_pairs_live": sum(1 for m in measured if m["source"] == "live"),
        "measured_pairs_backtest": sum(1 for m in measured if m["source"] == "backtest"),
        "default_1_0_pairs": n_possible - len(measured),
        "pairs": measured,
        "backtest_map_found": Path(backtest_map_path).exists(),
        "backtest_map_path": str(backtest_map_path),
        "backtest_skipped": list(backtest_skipped or []),
        "note": ("every pair NOT listed above used the conservative default corr=1.0 "
                 "(fully additive); live pairs outrank backtest pairs when both exist"),
    }

    report = {
        "limitation": LIMITATION,
        "corr_coverage": corr_coverage,
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
    cc = report.get("corr_coverage")
    if cc:
        lines.append(
            f"## Correlation coverage (ORDER-174): **{cc['measured_pairs']}/{cc['possible_pairs_active_or_pending']} "
            f"pairs measured** ({cc['measured_pairs_live']} live, {cc['measured_pairs_backtest']} backtest) "
            f"-- **{cc['default_1_0_pairs']} pairs on the conservative default 1.0**"
        )
        lines.append("")
        if cc["pairs"]:
            lines.append("| pair | corr | source |")
            lines.append("|---|---|---|")
            for m in cc["pairs"]:
                lines.append(f"| {m['pair']} | {m['corr']} | **{m['source']}** |")
            lines.append("")
        lines.append(
            "_Live and backtest correlations are different evidence quality -- live "
            "outranks backtest when both exist. Every pair not listed used corr=1.0 "
            "(fully additive, conservative)._"
        )
        if not cc["backtest_map_found"]:
            lines.append("")
            lines.append(
                f"**Backtest corr map not found** (`{cc['backtest_map_path']}`) -- backtest-derived "
                "correlation is OFF; populate the map (magic,report_path per row, deliberate "
                "entries only) to widen coverage before live history matures."
            )
        for s in cc["backtest_skipped"]:
            lines.append(f"- backtest map skipped: {s}")
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
    assert implied <= 10.001, f"emitted factor implies DD {implied} over budget 10.001 (strict)"


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


def _cage_27_strict_budget_and_type_conflict():
    """Round-9 (audit round-8 F1/F2): (a) the budget comparison is STRICT -- a
    candidate a hair over budget must not get ADMIT_FULL while the summary says
    OVER BUDGET; equality is still admitted. (b) an account whose rows disagree on
    the account type is a data error: no budget, nothing sized, order-independent."""
    # (a) strict budget
    report = build_report([_mk_row("111", "C", "PENDING_ATTACH")],
                          {"C": 25.0000000005}, {})
    acct = report["accounts"][0]
    d = report["admission_demo"][0]
    assert acct["over_budget"] is True
    assert d["status"] != "ADMIT_FULL", (
        f"granted a full lot above the strict budget while summary says OVER BUDGET: {d!r}"
    )
    exact = admit_candidate("C", 25.0, {}, {}, 25.0)
    assert exact["status"] == "ADMIT_FULL", f"exact-equality fit must still admit: {exact!r}"
    # (b) conflicting type metadata -- identical fail-closed outcome in both orders
    for order in (("C", "D"), ("D", "C")):
        rows = []
        for mg in order:
            r = _mk_row("111", mg, "PENDING_ATTACH")
            if mg == "D":
                r["type"] = "REAL_CENT"
            rows.append(r)
        report2 = build_report(rows, {"C": 10.0, "D": 10.0}, {})
        acct2 = report2["accounts"][0]
        assert acct2["type_conflict"] is True and acct2["budget_pct"] is None, f"{acct2!r}"
        # round-9 audit F3: the reported type must be deterministic, not rows[0]
        assert acct2["type"] == "CONFLICT(DEMO|REAL_CENT)", f"order {order}: {acct2['type']!r}"
        for dec in report2["admission_demo"]:
            assert dec["status"] == "CANNOT_RUN", (
                f"order {order}: type-conflicted account must not size anything: {dec!r}"
            )
    # round-9 audit F1: a BLANK type does not vote -- the sole non-blank type wins
    # in every row order (blank+DEMO used to flip REPORT_ONLY vs ADMIT_FULL)
    for order in (("C", "D"), ("D", "C")):
        rows = []
        for mg in order:
            r = _mk_row("111", mg, "PENDING_ATTACH")
            if mg == "C":
                r["type"] = ""
            rows.append(r)
        report3 = build_report(rows, {"C": 10.0, "D": 10.0}, {})
        acct3 = report3["accounts"][0]
        assert acct3["type"] == "DEMO" and acct3["budget_pct"] == 25.0, (
            f"order {order}: blank row must not decide the account type: {acct3!r}"
        )
        assert acct3["type_conflict"] is False
        for dec in report3["admission_demo"]:
            assert dec["status"] == "ADMIT_FULL", f"order {order}: {dec!r}"
    # case difference is NOT a conflict (normalization)
    rows = [_mk_row("111", "C", "PENDING_ATTACH"), _mk_row("111", "D", "PENDING_ATTACH")]
    rows[0]["type"] = "demo"
    report4 = build_report(rows, {"C": 10.0, "D": 10.0}, {})
    acct4 = report4["accounts"][0]
    assert acct4["type_conflict"] is False and acct4["budget_pct"] == 25.0, f"{acct4!r}"
    # round-9 audit F2: THE budget comparison is a single strict helper -- lock it
    assert _fits_budget(25.0, 25.0) is True
    assert _fits_budget(25.0 + 1e-10, 25.0) is False, (
        "_fits_budget must be strict -- no tolerance may return on any call site"
    )
    # round-10 audit MINOR: the pre-existing-over-budget branch must be strict too
    pre = admit_candidate("C", 1.0, {"A": 25.0000000005}, {}, 25.0,
                          broker_min_lot_factor=0.0001)
    assert pre["status"] == "DEFER_ESCALATE", (
        f"existing portfolio a hair over budget must defer, not admit: {pre!r}"
    )


def _write_tmp_report(path, rows):
    """Minimal MT5-report-shaped deals table: 13 cells per row, direction 'out'."""
    parts = ["<html><body><table>"]
    for t, profit in rows:
        cells = [t, "1", "XAUUSD", "buy", "out", "0.10", "2000.0", "1",
                 "0", "0", str(profit), "1000", ""]
        parts.append("<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>")
    parts.append("</table></body></html>")
    Path(path).write_text("".join(parts), encoding="utf-8")


def _cage_28_backtest_corr_provenance():
    """ORDER-174: backtest-derived correlation from the explicit report map --
    measured pairs carry 'backtest' provenance, LIVE overrides backtest when both
    exist, corrupt reports poison their magic (skipped, pair falls back to 1.0),
    and a missing map file cleanly disables the feature."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        months = ("2026.01", "2026.02", "2026.03", "2026.04")
        _write_tmp_report(td / "a.htm",
                          [(f"{m}.15 10:00:00", str(10.0 * (i + 1))) for i, m in enumerate(months)])
        _write_tmp_report(td / "b.htm",
                          [(f"{m}.15 10:00:00", str(10.0 * (4 - i))) for i, m in enumerate(months)])
        _write_tmp_report(td / "c.htm", [("2026.01.15 10:00:00", "not-a-number")])
        with open(td / "map.csv", "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["magic", "report_path", "notes"])
            w.writerow(["111", str(td / "a.htm"), ""])
            w.writerow(["222", str(td / "b.htm"), ""])
            w.writerow(["333", str(td / "c.htm"), "corrupt fixture"])
            w.writerow(["444", str(td / "missing.htm"), "missing fixture"])
        live_dir = td / "live"
        live_dir.mkdir()

        corr, quality, skipped = compute_corr_with_backtest(
            ["111", "222", "333", "444"], live_dir, td / "map.csv")
        pair = frozenset(("111", "222"))
        assert pair in corr and quality[pair] == "backtest", f"{corr!r} {quality!r}"
        assert abs(corr[pair] - (-1.0)) < 1e-9, f"anti-correlated fixture: {corr[pair]!r}"
        assert not any("333" in p for p in corr), "corrupt report must poison its magic"
        assert any("333" in s for s in skipped) and any("444" in s for s in skipped), f"{skipped!r}"
        assert get_corr(corr, "111", "333") == 1.0

        # LIVE data for the same pair must OUTRANK the backtest measurement
        with open(live_dir / "EA_LAB_deals_1_20260101.csv", "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["time", "magic", "entry", "profit", "swap", "commission"])
            for i, m in enumerate(months):
                w.writerow([f"{m}.15 10:00:00", "111", "1", str(1.0 + i), "0", "0"])
                w.writerow([f"{m}.15 11:00:00", "222", "1", str(2.0 + 2 * i), "0", "0"])
        corr2, quality2, _ = compute_corr_with_backtest(
            ["111", "222"], live_dir, td / "map.csv")
        assert quality2[pair] == "live", f"live must outrank backtest: {quality2!r}"
        assert abs(corr2[pair] - 1.0) < 1e-9, f"live series is perfectly correlated: {corr2[pair]!r}"

        # missing map file -> feature off, live-only, no crash
        corr3, quality3, skipped3 = compute_corr_with_backtest(
            ["111", "222"], live_dir, td / "no_such_map.csv")
        assert quality3.get(pair) == "live" and skipped3 == []

        # report JSON carries the provenance split
        report = build_report(
            [_mk_row("111", "111", "ACTIVE"), _mk_row("111", "222", "PENDING_ATTACH")],
            {"111": 10.0, "222": 10.0}, corr, basket_of={},
            corr_quality=quality, backtest_skipped=skipped,
            backtest_map_path=td / "map.csv")
        cc = report["corr_coverage"]
        assert cc["measured_pairs_backtest"] == 1 and cc["measured_pairs_live"] == 0, f"{cc!r}"
        assert cc["default_1_0_pairs"] == 0 and cc["backtest_map_found"] is True
        assert any("333" in s for s in cc["backtest_skipped"])


def _cage_29_backtest_map_fail_soft_hardening():
    """ORDER-174 round-2 (audit F1-F5): partial-missing magic excluded WHOLE,
    impossible months poison, overlapping windows poison, directory paths fail soft,
    and the output guard refuses the map and mapped reports as destinations."""
    import argparse as _ap
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        months = ("2026.01", "2026.02", "2026.03", "2026.04")
        _write_tmp_report(td / "good.htm", [(f"{m}.15 10:00:00", "10") for m in months])
        _write_tmp_report(td / "b.htm",
                          [(f"{m}.15 10:00:00", str(5.0 * (i + 1))) for i, m in enumerate(months)])
        _write_tmp_report(td / "badmonth.htm",
                          [(f"2026.1{d}.15 10:00:00", "1") for d in "3456"])
        _write_tmp_report(td / "d1.htm",
                          [(f"{m}.15 10:00:00", str(float(i + 1))) for i, m in enumerate(months)])
        _write_tmp_report(td / "d2.htm",
                          [(f"2026.0{d}.15 10:00:00", "1") for d in "4567"])  # April overlaps d1
        (td / "subdir").mkdir()
        with open(td / "map.csv", "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["magic", "report_path", "notes"])
            w.writerow(["A", str(td / "good.htm"), "present segment"])
            w.writerow(["A", str(td / "missing.htm"), "missing segment"])
            w.writerow(["B", str(td / "b.htm"), "clean"])
            w.writerow(["C", str(td / "badmonth.htm"), "months 13-16"])
            w.writerow(["D", str(td / "d1.htm"), "IS"])
            w.writerow(["D", str(td / "d2.htm"), "overlapping OOS"])
            w.writerow(["E", str(td / "subdir"), "a directory"])
        monthly, skipped = load_backtest_monthly_by_magic(td / "map.csv")
        assert set(monthly) == {"B"}, (
            f"only the clean magic may survive, got {sorted(monthly)} / skipped={skipped!r}"
        )
        # round-3 (audit F4): assert PER-MAGIC reasons -- a joined-string check let
        # unrelated records satisfy each other's phrases
        by_magic = {}
        for s in skipped:
            by_magic.setdefault(s.split(":", 1)[0], []).append(s)
        assert any("WHOLE magic excluded" in s for s in by_magic["A"]), by_magic
        assert any("impossible calendar month" in s for s in by_magic["C"]), by_magic
        assert any("more than one mapped report" in s for s in by_magic["D"]), by_magic
        assert any("not a regular file" in s for s in by_magic["E"]), by_magic

        # F4: the map and every mapped report are refused as output destinations
        dep = td / "dep.csv"
        exp = td / "exp.csv"
        dep.write_text("magic\n", encoding="utf-8")
        exp.write_text("magic\n", encoding="utf-8")
        args = _ap.Namespace(deployments=str(dep), expectations=str(exp),
                             backtest_map=str(td / "map.csv"))

        def refused(dest):
            try:
                _assert_safe_output_path("--out-md", str(dest), args)
            except SystemExit:
                return True
            return False

        assert refused(td / "map.csv"), "the corr map must be a protected destination"
        assert refused(td / "good.htm"), "a mapped report must be a protected destination"
        assert not refused(td / "fresh_report.md"), "a plain new report path must be allowed"


def _cage_30_malformed_report_rows_poison():
    """ORDER-174 round-3 (audit F1-F3): a deals-shaped row with the wrong cell count,
    a prefix-only-valid timestamp, and malformed money grouping must each poison the
    WHOLE magic (conservative 1.0 fallback) -- never publish a partial/fabricated
    series. Well-formed thousands grouping still parses."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        months = ("2026.01", "2026.02", "2026.03", "2026.04")
        _write_tmp_report(td / "good.htm",
                          [(f"{m}.15 10:00:00", str(float(i + 1))) for i, m in enumerate(months)])
        # F1: readable segment holding a 12-cell row that still carries direction 'out'
        cells12 = ["2026.05.15 10:00:00", "1", "XAUUSD", "buy", "out", "0.10",
                   "2000.0", "1", "0", "0", "100", "1000"]  # one cell short
        (td / "degen.htm").write_text(
            "<html><body><table><tr>" + "".join(f"<td>{c}</td>" for c in cells12) +
            "</tr></table></body></html>", encoding="utf-8")
        # F2: prefix-only timestamps ('month' 013) and trailing-junk timestamps
        _write_tmp_report(td / "x.htm",
                          [(f"2026.0{d}3.15 10:00:00", str(float(d))) for d in "1234"])
        _write_tmp_report(td / "y.htm", [("2026.01THIS_IS_NOT_A_DATE", "1.0")])
        # round-4 audit F2/F4: 'T' separator, out-of-range seconds, and a valid
        # PREFIX followed by trailing junk (locks the regex end anchor)
        _write_tmp_report(td / "t.htm", [("2026.01.15T10:00:00", "1.0")])
        _write_tmp_report(td / "s.htm", [("2026.01.15 10:00:99", "1.0")])
        _write_tmp_report(td / "j.htm", [("2026.01.15 10:00:00JUNK", "1.0")])
        # round-4 audit F1: mixed thousands separators are malformed
        _write_tmp_report(td / "mix.htm", [("2026.01.15 10:00:00", "3,000 000")])
        # F3: malformed money grouping vs well-formed thousands grouping
        _write_tmp_report(td / "n.htm", [("2026.01.15 10:00:00", "1,0")])
        _write_tmp_report(td / "m.htm", [("2026.01.15 10:00:00", "1,234.5"),
                                         ("2026.02.15 10:00:00", "-2,000")])
        with open(td / "map.csv", "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["magic", "report_path", "notes"])
            w.writerow(["A", str(td / "good.htm"), "IS"])
            w.writerow(["A", str(td / "degen.htm"), "OOS with malformed deals row"])
            w.writerow(["X", str(td / "x.htm"), "month 013"])
            w.writerow(["Y", str(td / "y.htm"), "trailing junk timestamp"])
            w.writerow(["N", str(td / "n.htm"), "money 1,0"])
            w.writerow(["M", str(td / "m.htm"), "well-formed thousands"])
            w.writerow(["T", str(td / "t.htm"), "T separator"])
            w.writerow(["S", str(td / "s.htm"), "seconds 99"])
            w.writerow(["J", str(td / "j.htm"), "trailing junk after valid prefix"])
            w.writerow(["MIX", str(td / "mix.htm"), "mixed separators"])
        monthly, skipped = load_backtest_monthly_by_magic(td / "map.csv")
        assert set(monthly) == {"M"}, f"{sorted(monthly)} / {skipped!r}"
        assert abs(monthly["M"]["2026-01"] - 1234.5) < 1e-9
        assert abs(monthly["M"]["2026-02"] - (-2000.0)) < 1e-9
        by_magic = {}
        for s in skipped:
            by_magic.setdefault(s.split(":", 1)[0], []).append(s)
        assert any("deals-shaped row with 12 cells" in s for s in by_magic["A"]), by_magic
        assert any("unparseable deal timestamp" in s for s in by_magic["X"]), by_magic
        assert any("unparseable deal timestamp" in s for s in by_magic["Y"]), by_magic
        assert any("corrupt money cell" in s for s in by_magic["N"]), by_magic
        # round-4: T separator, seconds range, end anchor, mixed separators
        assert any("unparseable deal timestamp" in s for s in by_magic["T"]), by_magic
        assert any("impossible calendar month/date" in s for s in by_magic["S"]), by_magic
        assert any("unparseable deal timestamp" in s for s in by_magic["J"]), by_magic
        assert any("corrupt money cell" in s for s in by_magic["MIX"]), by_magic
        # direct helper checks
        assert _parse_money_cell("1,0") is CORRUPT
        assert _parse_money_cell("3,000 000") is CORRUPT   # mixed separators
        assert _parse_money_cell("1,234 567") is CORRUPT   # mixed separators
        assert _parse_money_cell("1 234.5") == 1234.5
        assert _parse_money_cell("1,234,567.5") == 1234567.5
        assert _parse_money_cell("-12.5") == -12.5


def _cage_31_single_leg_basket_switch():
    """2026-07-25. The single-leg-basket resolution must be OFF by default (the live
    number may not move just because a switch was added), and when explicitly ON it
    must change ONLY the single-leg case -- never a real multi-leg collapse."""
    assert RESOLVE_SINGLE_LEG_BASKETS is False, (
        "the unaudited single-leg-basket resolution must default to OFF -- if this "
        "fires, someone flipped a money-path default without the audit"
    )
    basket_of = {"SOLO_LEG": "B_ONE", "L1": "B_TWO", "L2": "B_TWO"}
    dd95 = {"SOLO_LEG": 10.0, "L1": 5.0, "L2": 5.0, "PLAIN": 7.0}

    off = basket_unit_keys(dd95, basket_of, resolve_single_leg=False)
    assert off["B_ONE"] == _basket_key("B_ONE"), f"default must stay conservative: {off!r}"
    on = basket_unit_keys(dd95, basket_of, resolve_single_leg=True)
    assert on["B_ONE"] == "SOLO_LEG", f"resolution did not key by the lone leg: {on!r}"
    assert off["B_TWO"] == on["B_TWO"] == _basket_key("B_TWO"), (
        f"a genuine 2-leg basket must collapse identically either way: {off!r} vs {on!r}"
    )

    # and the switch must actually recover the correlation, not merely rename the key
    corr = {frozenset(("SOLO_LEG", "PLAIN")): 0.0}
    solo = {"SOLO_LEG": 10.0, "PLAIN": 7.0}
    u_off, _ = collapse_basket_risk_units(
        solo, basket_of, unit_keys=basket_unit_keys(solo, basket_of, resolve_single_leg=False))
    u_on, _ = collapse_basket_risk_units(
        solo, basket_of, unit_keys=basket_unit_keys(solo, basket_of, resolve_single_leg=True))
    dd_off = portfolio_dd_est(u_off, corr)
    dd_on = portfolio_dd_est(u_on, corr)
    assert abs(dd_off - 17.0) < 1e-9, f"OFF must stay fully additive (corr 1.0): {dd_off!r}"
    assert abs(dd_on - math.sqrt(10.0 ** 2 + 7.0 ** 2)) < 1e-9, (
        f"ON must use the measured corr=0.0: {dd_on!r}"
    )
    assert dd_on < dd_off, "resolution should lower the estimate here, never raise it"


def _cage_32_unit_key_rule_is_inventory_wide():
    """2026-07-25. A basket's risk-unit identity must be decided ONCE per account
    inventory, never re-derived per slice. Re-deriving it let the ACTIVE-only slice see
    1 leg (key = magic) while the all-rows slice saw 2 (key = 'basket::'), so the
    existing-portfolio lookup raised KeyError on its own key."""
    all_known = {"L1": 10.0, "L3": 10.0}      # both legs of BX: one ACTIVE, one PENDING
    active_known = {"L1": 10.0}                # the ACTIVE-only slice sees a single leg
    basket_of = {"L1": "BX", "L3": "BX"}
    for resolve in (False, True):
        keys = basket_unit_keys(all_known, basket_of, resolve_single_leg=resolve)
        units_all, _ = collapse_basket_risk_units(all_known, basket_of, unit_keys=keys)
        units_active, _ = collapse_basket_risk_units(active_known, basket_of, unit_keys=keys)
        assert set(units_active) <= set(units_all), (
            f"ACTIVE slice invented a unit key the inventory does not have "
            f"(resolve={resolve}): {units_active!r} vs {units_all!r}"
        )
    report = build_report(
        [_mk_row("111", "L1", "ACTIVE"), _mk_row("111", "L3", "PENDING_ATTACH")],
        all_known, {}, basket_of=basket_of,
    )
    assert report["admission_demo"][0]["status"] == "CANNOT_RUN", (
        "sibling-of-active-basket candidate must still escalate"
    )


def _cage_33_basket_series_is_summed_and_all_or_nothing():
    """ORDER-433. A multi-leg basket must be correlated as the SUM of its legs, under
    the same `basket::<id>` key the risk-unit collapse produces -- and must be left
    UNMEASURED when any leg's series is missing.

    Both halves matter. Without the first, the basket key never resolves and every
    pair falls to the conservative 1.0 default (the situation --resolve-single-leg-
    baskets was invented to work around). Without the second, a basket summed from a
    subset of its legs IS that proxy again, but now wearing the basket's name, which
    is worse: it looks like a measurement."""
    basket_of = {"L1": "BX", "L2": "BX", "S1": None}
    monthly = {
        "L1": {"2024-01": 10.0, "2024-02": -5.0, "2024-03": 3.0, "2024-04": 1.0},
        "L2": {"2024-01": 2.0, "2024-02": 4.0, "2024-03": -1.0, "2024-04": 6.0},
        # S1 must VARY: a constant series has zero standard deviation, so pearson()
        # correctly returns None and the pair is unmeasurable. First draft made it
        # flat 1.0 and this cage failed for a reason that had nothing to do with
        # baskets -- the code was right and the fixture was not.
        "S1": {"2024-01": 1.0, "2024-02": 3.0, "2024-03": 2.0, "2024-04": 5.0},
    }
    out, added, incomplete = _add_basket_series(monthly, basket_of)
    key = _basket_key("BX")
    assert added == ["BX"] and not incomplete, f"basket not built: {added} / {incomplete}"
    assert key in out, "combined series missing under the basket:: key"
    # summed, month by month -- not one leg, not an average
    assert out[key] == {"2024-01": 12.0, "2024-02": -1.0, "2024-03": 2.0, "2024-04": 7.0}, (
        f"combined series is not the leg-wise SUM: {out[key]!r}"
    )
    # the legs themselves are untouched: they still exist for their own pairs
    assert out["L1"] == monthly["L1"], "adding the basket series mutated a leg series"

    # ...and the key actually reaches the matrix that get_corr() reads
    pairs = _pairs_from_monthly(out, ["S1"] + _basket_keys_present(out))
    assert any(key in p for p in pairs), "basket:: unit produced no measurable pair"

    # all-or-nothing: drop one leg's series and the basket must vanish, NOT degrade
    # into the single-leg proxy.
    partial = {k: v for k, v in monthly.items() if k != "L2"}
    out2, added2, incomplete2 = _add_basket_series(partial, basket_of)
    assert added2 == [] and key not in out2, (
        "a basket with a missing leg was still published -- that is the single-leg "
        "proxy under another name"
    )
    assert incomplete2 and "L2" in incomplete2[0], (
        f"the missing leg must be NAMED in the skip reason, got {incomplete2!r}"
    )
    # a one-leg-total 'basket' is not a basket to combine and must not be invented
    out3, added3, _ = _add_basket_series({"Z1": {"2024-01": 1.0}}, {"Z1": "BZ"})
    assert added3 == [] and _basket_key("BZ") not in out3, (
        "a single-leg basket must stay on the 1.0 default, not become a combined series"
    )


def _cage_34_partial_unit_keys_is_refused_not_silently_wrong():
    """ORDER-433 / Codex blind audit 2026-07-27, second defect. A SUPPLIED unit_keys
    map that omits a represented basket used to be trusted verbatim: both legs kept
    their magic keys and the basket was counted TWICE (20.0% where canonical keys give
    10.0%). It over-states risk, which is the safe direction -- and is exactly why it
    could sit here unnoticed. A wrong number produced silently is still wrong."""
    basket_of = {"L1": "BX", "L2": "BX"}
    dd95 = {"L1": 10.0, "L2": 10.0}

    canonical, _ = collapse_basket_risk_units(dd95, basket_of)
    assert canonical == {_basket_key("BX"): 10.0}, (
        f"canonical collapse changed: {canonical!r}"
    )

    for bad in ({}, {"BOTHER": "basket::BOTHER"}):
        try:
            collapse_basket_risk_units(dd95, basket_of, unit_keys=bad)
        except RiskAdmissionError as e:
            assert "BX" in str(e), f"the uncovered basket must be named: {e}"
        else:
            raise AssertionError(
                f"unit_keys={bad!r} omits basket BX and was accepted -- the double-count "
                "is back"
            )

    # a COMPLETE supplied map must still work: this guard must not break the legitimate
    # inventory-wide call that cage 32 exists to protect.
    good = basket_unit_keys(dd95, basket_of)
    units, _ = collapse_basket_risk_units(dd95, basket_of, unit_keys=good)
    assert units == canonical, f"complete unit_keys map was rejected or changed: {units!r}"


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
    ("27_strict_budget_and_type_conflict", _cage_27_strict_budget_and_type_conflict),
    ("28_backtest_corr_provenance", _cage_28_backtest_corr_provenance),
    ("29_backtest_map_fail_soft_hardening", _cage_29_backtest_map_fail_soft_hardening),
    ("30_malformed_report_rows_poison", _cage_30_malformed_report_rows_poison),
    ("31_single_leg_basket_switch_is_off_by_default", _cage_31_single_leg_basket_switch),
    ("32_unit_key_rule_is_inventory_wide", _cage_32_unit_key_rule_is_inventory_wide),
    ("33_basket_series_summed_all_or_nothing", _cage_33_basket_series_is_summed_and_all_or_nothing),
    ("34_partial_unit_keys_refused", _cage_34_partial_unit_keys_is_refused_not_silently_wrong),
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

def _backtest_protected_paths(map_csv):
    """ORDER-174 round-2 (audit F4): the corr map and every report it points at are
    INPUTS -- collect their resolved paths so the output-path guard can refuse to
    overwrite them. Fail-soft: an unreadable map just protects the map path itself."""
    out = {}
    p = Path(map_csv)
    out[p.resolve()] = "the backtest corr map it reads"
    try:
        if p.is_file():
            with open(p, encoding="utf-8-sig", newline="") as f:
                for row in csv.DictReader(f):
                    rel = (row.get("report_path") or "").strip()
                    if rel:
                        rp = (ROOT / rel) if not Path(rel).is_absolute() else Path(rel)
                        out[rp.resolve()] = f"a mapped backtest report it reads ({rel})"
    except OSError:
        pass
    return out


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
    protected.update(_backtest_protected_paths(getattr(args, "backtest_map", BACKTEST_CORR_MAP)))
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
    ap.add_argument("--backtest-map", default=str(BACKTEST_CORR_MAP))
    ap.add_argument("--out-md", default=str(OUT_MD))
    ap.add_argument("--out-json", default=str(OUT_JSON))
    ap.add_argument(
        "--resolve-single-leg-baskets", action="store_true",
        help="EXPERIMENTAL, UNAUDITED (2026-07-25). Key a basket that has exactly ONE "
             "known-DD95 leg by that leg's magic, so its already-measured correlations "
             "resolve instead of falling back to the conservative 1.0. Changes reported "
             "risk numbers -- use to review the difference, not to publish. Default off "
             "until the Codex risk-path audit and user ratification.")
    args = ap.parse_args(argv)

    global RESOLVE_SINGLE_LEG_BASKETS
    RESOLVE_SINGLE_LEG_BASKETS = args.resolve_single_leg_baskets

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
    corr_matrix, corr_quality, bt_skipped = compute_corr_with_backtest(
        magics, args.live_deals, args.backtest_map, basket_of=basket_of)

    report = build_report(deployments, dd95_map, corr_matrix, basket_of=basket_of,
                          expectations_path=args.expectations,
                          corr_quality=corr_quality, backtest_skipped=bt_skipped,
                          backtest_map_path=args.backtest_map)
    md = render_markdown(report)

    Path(args.out_md).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out_md).write_text(md, encoding="utf-8")
    Path(args.out_json).write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(f"wrote {args.out_md}")
    print(f"wrote {args.out_json}")


if __name__ == "__main__":
    main()
