# QA task: independent verification pass on scripts/portfolio_risk_admission.py (round 3)

You are doing a neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py`
at commit `d3ae4224` (HEAD). Two prior QA rounds each found real defects; the code has since been
revised. Your job is to determine, independently and adversarially, whether the following claims hold
in the CURRENT code. Do not assume any claim is true because a comment says so.

## Ground rules
- Read-only with one exception: you MAY create temporary files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Judge by executing concrete failing-input probes wherever possible, not by reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk,
  MINOR), each with a concrete reproducing input and observed output.

## Claims to verify (from the round-3 revision)
1. `build_report()`'s admission-demo path sizes candidates against basket-COLLAPSED active risk
   units, so the account summary and the admission decision can no longer disagree on the same
   input. Probe: L1+L2 ACTIVE sharing basket BX (DD95 10 each, basket-level) + PENDING C (DD95 10),
   DEMO budget 25 -> expect ADMIT_FULL at portfolio 20.0, consistent with the summary.
2. `collapse_basket_risk_units()` cannot merge a basket_id with an unrelated standalone magic of
   the same name (namespace separation), and measured correlations for standalone magics still
   resolve (keys stay raw magics).
3. Every number `admit_candidate()` emits (existing, full-size, and the EMITTED reduced point)
   passes the `max(DD95) <= est <= sum(DD95)` invariant via `portfolio_dd_est()`. Probe the round-2
   counterexample: `admit_candidate("C", 20.0, {"A": 10.0}, {frozenset(("A","C")): -0.23456},
   10.0, broker_min_lot_factor=0.001)`.
4. Basket-fold/conflict messages appear in the rendered MARKDOWN, not only JSON.
5. `_num()` classifies "nan"/"inf"/"-inf"/"1e309" as CORRUPT; a nan P&L cell in a real deals CSV
   poisons that magic end-to-end (excluded from `compute_corr_matrix()`, pair falls back to 1.0,
   no non-finite value in the matrix).
6. `admit_candidate()` validates its own numeric inputs: non-finite/bool candidate_dd95, non-finite
   budget_pct, and broker_min_lot_factor outside (0,1] or non-finite all raise RiskAdmissionError.
   Probe the round-2 counterexamples: `admit_candidate("C", float("inf"), {"A":1.0}, {}, 25.0)` and
   `admit_candidate("C", 300000.0, {}, {}, 0.01, broker_min_lot_factor=0.0)`.
7. `_assert_safe_output_path()` refuses an NTFS hard-link alias of a protected file (create a temp
   protected file + `os.link` alias with a .txt name and probe). Legitimate fresh report paths are
   still allowed.
8. The self-test suite (now 18 tests) actually covers the production paths above: check by
   mutation where practical (e.g. in-memory replacement of `portfolio_dd_est` without the
   type/finite guard, or bypassing the collapse in the admission path, should now FAIL at least
   one test).
9. Coverage metadata reflects the `--expectations` path actually supplied, not the default.

Also look for NEW defects introduced by this revision (regressions in previously-verified behavior
count double). Previously-verified behaviors that must still hold: parser rejection of
0/negative/inf/nan DD95; missing corr -> 1.0 default; REAL_CENT -> REPORT_ONLY; broker minimum
None -> DEFER_ESCALATE; floor-not-round of the emitted factor; refusal to write over
DEPLOYMENTS/expectations/.set paths.

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER170_ROUND3_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL` (any found)
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
