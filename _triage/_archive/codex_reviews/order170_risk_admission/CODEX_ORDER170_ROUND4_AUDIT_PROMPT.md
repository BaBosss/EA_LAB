# QA task: independent verification pass on scripts/portfolio_risk_admission.py (round 4)

Neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py` at commit
`cdfadd28` (HEAD). Three prior QA rounds each found real defects; the code has been revised again.
Determine independently and adversarially whether the claims below hold in the CURRENT code. Do not
assume a claim is true because a comment says so.

## Ground rules
- Read-only, with one exception: you MAY create temp files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Prefer executing concrete failing-input probes over reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk, MINOR),
  each with a concrete reproducing input and observed output.

## Claims to verify (round-4 revision, responding to the round-3 findings)
1. A PENDING candidate that itself carries a basket_id is admitted under the SAME risk-unit
   identity the account summary collapses it to (`basket::<id>`), so the summary and the admission
   decision can no longer disagree. Probe the round-3 counterexample:
   deployments A ACTIVE (DD95 20) + C PENDING_ATTACH (DD95 10, basket_of C->BX),
   corr {frozenset(("A","C")): 0.0}, DEMO budget 25 -> summary 30.0/OVER BUDGET and admission must
   NOT be ADMIT_FULL (expected DEFER_ESCALATE with no broker minimum). The decision dict should
   report both the real magic and the risk-unit identity used.
2. Individually finite P&L cells that overflow the monthly aggregation (e.g. two 1e308 deals in one
   month) poison that magic in `load_monthly_pnl_by_magic()`; non-finite pearson results are never
   stored by `compute_corr_matrix()`; no nan/inf can enter the matrix by any ingestion path.
3. `portfolio_dd_est()` refuses a non-finite sum-of-squares (inf must no longer satisfy the bounds
   check via inf <= inf). Probe `portfolio_dd_est({"A": 1e308, "B": 1e308}, {})`.
4. `admit_candidate("C", 1e308, {}, {}, 1.0, broker_min_lot_factor=0.01)` raises
   RiskAdmissionError (the documented refusal type), not a raw OverflowError; the solved lot
   factor is checked finite before flooring.
5. The self-test suite (now 21 tests) covers the round-3 SEV-1 specifically: cage 19 composes a
   basketed pending candidate WITH a measured raw-magic correlation. Check by mutation where
   practical (e.g. reverting the admission call to use the raw magic as identity should fail
   cage 19).

Also hunt for NEW defects introduced by this revision, and regression-check the previously
verified behaviors: basket collapse in both summary and admission (round-3 claim-1 fixture);
namespace separation basket:: vs raw magic; emitted-reduced lower-bound refusal (round-2
counterexample); nan/inf/1e309 P&L cell poisoning end-to-end; admission input validation
(inf candidate, broker minimum 0/nan/1.5/-0.1); NTFS hard-link output refusal; coverage metadata
reflecting --expectations; parser rejection of 0/negative/inf/nan DD95; missing corr -> 1.0;
REAL_CENT -> REPORT_ONLY; broker minimum None -> DEFER_ESCALATE; floor-not-round.

One deliberate design point, not a defect (flag only if you find a way it produces a WRONG number):
a basketed candidate's measured raw-magic correlation being ignored in favor of the conservative
1.0 default is intentional -- the basket risk unit's correlation was never measured at basket
level, and the conservative direction is the design contract.

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER170_ROUND4_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL`
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
