# QA task: independent verification pass on scripts/portfolio_risk_admission.py (round 5)

Neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py` at commit
`7c694dd0` (or later -- verify the script blob is the one from `7c694dd0` if HEAD advanced). Four
prior QA rounds each found real defects; the code has been revised again. Determine independently
and adversarially whether the claims below hold in the CURRENT code.

## Ground rules
- Read-only, with one exception: you MAY create temp files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Prefer executing concrete failing-input probes over reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk,
  MINOR), each with a concrete reproducing input and observed output.

## Claims to verify (round-5 revision, responding to the round-4 findings F1-F3)
1. (was F1, SEV-1) With MULTIPLE PENDING candidates on one account, admission decisions COMPOSE:
   they are sequential in inventory order, each granted candidate is carried forward at its
   granted lot into the portfolio the next candidate is sized against, later decisions carry an
   explicit `assumes_admitted_first` list, and the Markdown demo header states the sequential
   semantics. Probe the round-4 repro: A ACTIVE (DD95 10) + C,D PENDING (10 each), empty corr,
   DEMO budget 25 -> C ADMIT_FULL, D must NOT be ADMIT_FULL (expected DEFER_ESCALATE seeing 20%
   existing). Also: two PENDING siblings of one basket -> first sized, second CANNOT_RUN.
   Try to construct ANY multi-pending input whose emitted decisions, applied together as written,
   breach the budget.
2. (was F2, SEV-2) `pearson()` never raises (no `** 2` overflow); any non-finite intermediate
   makes the pair unmeasurable (None -> conservative 1.0 fallback), and no 0.0-from-overflow or
   non-finite value can be stored by `compute_corr_matrix()`. Probe: monthly P&L
   [1e308, -1e308, 1e308, -1e308] vs [1,2,3,4] through a real deals CSV, plus any adversarial
   magnitude pattern you can devise.
3. (was F3, SEV-2) An existing portfolio exactly AT budget yields DEFER_ESCALATE ("no positive
   lot fits"), not a REFUSED "corr matrix invalid" misclassification -- with broker minimum None
   and with 0.01. Probe `admit_candidate("C", 1.0, {"A": 25.0}, {}, 25.0)` both ways. Confirm the
   just-over-budget case still takes the pre-existing-over-budget branch.
4. The self-test suite (now 24 tests) covers all three round-4 findings with production-path
   fixtures (cages 22-24); check by mutation where practical (e.g. reverting the sequential
   carry-forward, restoring `** 2` in pearson, or restoring the x<=0 raise should each fail at
   least one cage).

Also hunt for NEW defects introduced by this revision (the sequential-demo rework in
`build_report()` is the largest new surface -- scrutinize its interaction with basketed
candidates, CANNOT_RUN entries, REFUSED entries, REAL_CENT/REPORT_ONLY accounts, and the JSON/
Markdown rendering), and regression-check the previously verified behaviors: single-pending
basketed candidate identity (round-4 claim 1); basket collapse in summary+admission; namespace
separation; emitted-reduced lower-bound refusal; nan/inf/1e309 and aggregation-overflow P&L
poisoning; admission input validation; non-finite sum-of-squares refusal in portfolio_dd_est;
1e308 candidate -> RiskAdmissionError; NTFS hard-link output refusal; coverage metadata reflecting
--expectations; parser rejection of 0/negative/inf/nan DD95; missing corr -> 1.0; REAL_CENT ->
REPORT_ONLY; broker minimum None -> DEFER_ESCALATE when a positive reduced factor exists;
floor-not-round.

Deliberate design points, not defects (flag only if you can produce a WRONG number through them):
- a basketed candidate's measured raw-magic correlation being ignored in favor of the
  conservative 1.0 default (basket-level correlation was never measured);
- sequential order being inventory order (any deterministic order is acceptable; the report
  names the assumption);
- an unmeasurable (overflow) correlation pair falling back to 1.0 rather than being reported as
  an error.

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER170_ROUND5_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL`
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
