# QA task: independent verification of the ORDER-174 backtest-correlation extension (round 2)

Neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py` at commit
`f8fcf54` (verify the script blob matches that commit if HEAD advanced). Round 1 verified
provenance, live-override, poisoning basics, and the reporting sections, and found 3 SEV-1 +
2 SEV-2 on the ingestion surface, all addressed in this revision.

## Ground rules
- Read-only, with one exception: you MAY create temp files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Prefer executing concrete failing-input probes over reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk,
  MINOR), each with a concrete reproducing input and observed output.

## Claims to verify (responding to round-1 F1-F5)
1. (was F1) A magic whose mapped rows are not ALL present and readable is excluded ENTIRELY
   with a "WHOLE magic excluded" reason -- a partial series (IS present, OOS row missing) can
   no longer be published as complete. Probe the round-1 repro: A -> [good.htm, missing.htm],
   B -> [b.htm]; A must contribute no pair.
2. (was F2) An impossible calendar month (e.g. 2026.13) anywhere in a mapped report poisons
   that series with an "impossible calendar month" reason -- it can never count toward
   MIN_SHARED_MONTHS or displace the conservative 1.0 default.
3. (was F3) The same calendar month appearing in MORE THAN ONE mapped report for a magic
   poisons the series (overlap = double-counted deals). Probe the round-1 repro: d1 Jan-Apr,
   d2 Apr-Jul -> poisoned with the overlap month named; non-overlapping IS+OOS (Jan-Apr +
   May-Aug) still concatenates correctly.
4. (was F4) `--out-md`/`--out-json` refuse the corr map file and every report path listed in
   it as destinations (probe an actual CLI run attempting both). Fresh report paths still
   allowed.
5. (was F5) A mapped path that exists but is not a regular file (a directory), or an
   unreadable file, fails soft with a reason -- never an unhandled exception; the run
   completes and other magics still load.
6. The self-test suite (29 cages; new cage 29) kills practical mutations: reverting is_file()
   to exists(), removing the month-range check, removing the overlap check, or removing the
   map/report output protection should each fail at least one cage.
7. No NEW defects from this revision and no regression: cage 28 semantics (provenance,
   live-override, missing-map off-switch), the ORDER-170 engine invariants (spot-check one or
   two), and the current-inventory CLI run (empty map -> 0/903 measured, 903 default) all
   hold.

Robustness probes on malformed report data are in scope (degenerate HTML, very large cells,
odd month/number spellings) -- the expectation everywhere is fail-soft exclusion with a
surfaced reason and conservative 1.0 fallback, never a fabricated observation, never a crash,
and never an output write to any input file.

Deliberate design points, not defects (flag only if you can produce a WRONG number through
them): the map template being empty; refusal of mid-month-split windows (month-level overlap
refusal is intentionally conservative); live outranking backtest; absent pairs defaulting to
1.0; a poisoned/skipped magic silently falling back to 1.0 for its pairs (the reason is
surfaced in the report).

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER174_ROUND2_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL`
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
