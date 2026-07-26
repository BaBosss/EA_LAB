# QA task: independent verification of the ORDER-174 backtest-correlation extension (round 1)

Neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py` at commit
`4bf85cf` (verify the script blob matches that commit if HEAD advanced). Context: the admission
tool's correlation previously read `portfolio/live_deals/` only; with ~1 month of live data every
pair fell back to the conservative 1.0 default. This revision adds backtest-report-derived
correlation per the original ORDER-154 DESIGN. The admission/budget engine itself passed a
10-round audit series (ORDER-170) and is NOT the focus -- but regressions in it count double.

## Ground rules
- Read-only, with one exception: you MAY create temp files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Prefer executing concrete failing-input probes over reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk,
  MINOR), each with a concrete reproducing input and observed output.

## Claims to verify (new surfaces: _read_report_text, _extract_backtest_monthly,
## load_backtest_monthly_by_magic, _pairs_from_monthly, compute_corr_with_backtest,
## corr_coverage in build_report/render_markdown, --backtest-map CLI)
1. Backtest parsing matches the `_mt5_auto/corr_monthly.py` method (13-cell deals rows,
   direction 'out', profit+commission+swap, YYYY.MM bucketing, UTF-16/UTF-8 reports) AND applies
   this module's corruption discipline: a present-but-unparseable or non-finite money cell (nan,
   inf, 1e309, text) poisons the ENTIRE magic series (skipped with reason, pairs fall back to
   1.0) -- it never becomes a fabricated 0.0/partial observation. Probe with real temp .htm
   fixtures, including a UTF-16-encoded one.
2. Provenance: every measured pair carries "live" or "backtest"; LIVE always outranks backtest
   when both measured a pair; a pair measured by neither stays ABSENT (get_corr -> 1.0). The
   1.0 default and the portfolio_dd_est formula are untouched. Both sources use the same
   MIN_SHARED_MONTHS=4 rule.
3. Fail-soft mapping: missing map file = feature off (no crash, empty skipped); missing report
   file, empty parse, poisoned series = that magic skipped WITH a reason surfaced in both JSON
   (`corr_coverage.backtest_skipped`) and Markdown. No path guessing anywhere -- only mapped
   rows are read.
4. Reporting: `corr_coverage` counts (possible/measured/live/backtest/default) are mutually
   consistent for pairs among ACTIVE+PENDING magics; the Markdown table shows per-pair source;
   an empty map yields the current-state "0/903 measured, 903 default" with the map-not-found
   or empty-map coverage intact.
5. No regression in the audited engine: selftest 28/28; spot-check one or two ORDER-170
   invariants of your choosing (e.g. strict budget, basket canonical DD95) still hold.
6. Security/robustness of the new input path: the map file and report files are DATA -- check a
   hostile report (huge cells, nested tags, absurd month strings, absolute/relative path tricks
   in report_path) cannot crash the run, corrupt unrelated magics, or cause a write anywhere.
   Note the tool itself never writes anything from this path.

Also hunt for NEW defects in the added ~270 lines generally (e.g. double-counting a magic mapped
to two report rows -- multiple rows per magic are INTENDED to concatenate IS+OOS windows of the
SAME config; flag if concatenation can double-count the same month across overlapping reports,
and how that would bias corr).

Deliberate design points, not defects (flag only if you can produce a WRONG number through them):
- the map template being committed empty (population is deliberate follow-up work);
- backtest corr being usable at all (the DESIGN says so; the report labels the tier);
- live outranking backtest even when live has fewer months (4-month minimum applies to both);
- absent pairs defaulting to 1.0 (never lowered).

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER174_ROUND1_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL`
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
