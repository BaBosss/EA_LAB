# QA task: independent verification pass on scripts/portfolio_risk_admission.py (round 6)

Neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py` at commit
`7a71316` (verify the script blob matches that commit if HEAD advanced). Five prior QA rounds each
found real defects; round 5 narrowed to one SEV-1 + two MINORs, all addressed in this revision.
Determine independently and adversarially whether the claims below hold in the CURRENT code.

## Ground rules
- Read-only, with one exception: you MAY create temp files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Prefer executing concrete failing-input probes over reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk,
  MINOR), each with a concrete reproducing input and observed output.

## Claims to verify (round-6 revision, responding to round-5 findings F1-F3)
1. (was F1, SEV-1) A basketed PENDING candidate is sized at its basket's CANONICAL conservative
   DD95 -- the max across conflicting sibling values, collapsed over ALL known rows on the
   account (same rule the summary uses) -- never at the first row's raw value, and the outcome is
   inventory-order independent. Probe the round-5 repro both ways: E=10, F=30 PENDING sharing
   basket BY, empty corr, DEMO budget 25 -> in BOTH row orders no decision may grant a lot at the
   understated 10 (expected: first sibling DEFER_ESCALATE at canonical 30, `basket_dd95_used`
   present when it differs from the row value, carry-forward would use the canonical value).
   Try to construct ANY input (conflicting siblings, mixed ACTIVE/PENDING baskets, order
   permutations) where an emitted decision understates a basket's canonical risk or where
   applying all decisions as written breaches the budget.
2. (was F2, MINOR) CANNOT_RUN and REFUSED records emitted after at least one admission carry
   `assumes_admitted_first` provenance.
3. (was F3, MINOR) `pearson()` clamps an epsilon overshoot beyond +/-1 and returns None
   (unmeasurable -> conservative 1.0 fallback) for a materially out-of-range finite quotient.
   Probe the round-5 subnormal repro: xs=[0,-1e-200,-1e-200,-1e-320,1e-160],
   ys=[-1e-320,-5e-324,-5e-324,-5e-324,1e-100]. No stored correlation may lie outside [-1,1].
4. The self-test suite (now 26 tests) covers the round-5 findings (cages 25-26); check by
   mutation where practical (e.g. reverting the admission call to use the row's raw dd95, or
   removing the pearson range guard, should each fail at least one cage).

Also hunt for NEW defects introduced by this revision (the canonical-DD95 lookup `units_all` and
the provenance helper are the new surfaces), and regression-check previously verified behaviors:
sequential composition with multiple pendings (round-4 F1 fixture: A ACTIVE 10 + C,D PENDING 10,
budget 25 -> C ADMIT_FULL, D DEFER_ESCALATE); single-pending basketed candidate identity;
basket collapse in summary+admission; namespace separation; emitted-reduced lower-bound refusal;
nan/inf/1e309 and overflow P&L poisoning (cell, aggregation, and pearson levels); admission input
validation; non-finite sum-of-squares refusal; exact-budget DEFER (not REFUSED); NTFS hard-link
output refusal; coverage metadata reflecting --expectations; parser rejection of 0/negative/inf/
nan DD95; missing corr -> 1.0; REAL_CENT -> REPORT_ONLY; broker minimum None -> DEFER_ESCALATE;
floor-not-round.

Deliberate design points, not defects (flag only if you can produce a WRONG number through them):
- basketed candidates' correlations falling back to the conservative 1.0 default;
- sequential inventory order; a deferred (not granted) candidate not being carried forward;
- an unmeasurable/out-of-range correlation pair falling back to 1.0;
- REFUSED entries when the corr matrix genuinely violates bounds (fail-closed is the contract).

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER170_ROUND6_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL`
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
