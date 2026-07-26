# QA task: independent verification pass on scripts/portfolio_risk_admission.py (round 7)

Neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py` at commit
`f5284f2` (verify the script blob matches that commit if HEAD advanced). Six prior QA rounds each
found real defects; round 6 found 2 SEV-1 + 2 test-gap MINORs, all addressed in this revision.
Determine independently and adversarially whether the claims below hold in the CURRENT code.

## Ground rules
- Read-only, with one exception: you MAY create temp files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Prefer executing concrete failing-input probes over reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk,
  MINOR), each with a concrete reproducing input and observed output.

## Claims to verify (round-7 revision, responding to round-6 findings F1-F4)
1. (was F1, SEV-1) The EXISTING portfolio used for admission carries every basket at its
   canonical ALL-row value: an ACTIVE basket leg whose PENDING sibling declares a larger
   basket-level DD95 is counted at that larger value before any unrelated candidate is sized.
   Probe the round-6 repro in both pending orders: E ACTIVE (10, basket BY) + F PENDING (30,
   basket BY) + G PENDING (10, standalone), empty corr, DEMO budget 25 -> summary 40/OVER
   BUDGET, F CANNOT_RUN, and G must NOT be granted a lot (expected DEFER_ESCALATE via the
   pre-existing-over-budget branch). Try to construct ANY mixed ACTIVE/PENDING/conflicting-
   sibling input where applying the emitted decisions as written breaches the budget or
   understates a basket's canonical risk.
2. (was F2, SEV-1) `collapse_basket_risk_units()` always keeps max(prev, val) -- the 1e-9
   tolerance only selects the message wording -- so the collapsed figure is insertion-order
   independent even for near-equal values. Probe the round-6 boundary repro: A ACTIVE
   15.00000000075 + E,F PENDING basket BY at 10.0 / 10.0000000005, budget 25, both orders ->
   identical decisions in both orders.
3. (was F3/F4, MINOR) Cage 25 now strictly requires `basket_dd95_used` (mutation: deleting the
   field must fail the suite) and covers REFUSED-after-admission provenance (mutation: dropping
   provenance from the REFUSED append must fail the suite). Verify both mutations are killed.
4. No NEW defects from this revision. The changed surfaces are: `collapse_basket_risk_units()`
   max semantics, the `existing_units = {k: units_all[k] ...}` canonical upgrade line in
   `build_report()`, and the expanded cage 25. Scrutinize interactions: ACTIVE-only baskets,
   baskets where the PENDING sibling has UNKNOWN DD95, accounts with zero pending, REAL_CENT
   accounts, and the account summary (must it now also reflect the canonical value? -- the
   summary already collapses over all known rows, check the two stay consistent).

Also regression-check previously verified behaviors: pure-PENDING conflicting siblings (E=10/
F=30, both orders, no grant at the understated value, basket_dd95_used present); sequential
composition (A ACTIVE 10 + C,D PENDING 10 -> C ADMIT_FULL, D DEFER); single-pending basketed
identity; namespace separation; emitted-reduced lower-bound refusal; nan/inf/1e309/overflow P&L
poisoning at cell/aggregation/pearson levels; pearson range clamp (subnormal repro); admission
input validation; non-finite sum-of-squares refusal; exact-budget DEFER; NTFS hard-link output
refusal; --expectations metadata; parser rejection of 0/negative/inf/nan DD95; missing corr ->
1.0; REAL_CENT -> REPORT_ONLY; broker minimum None -> DEFER_ESCALATE; floor-not-round.

Deliberate design points, not defects (flag only if you can produce a WRONG number through them):
- conservative direction everywhere: canonical basket value = max; unmeasurable/out-of-range
  correlation -> 1.0; deferred candidates not carried forward; fail-closed REFUSED when the
  matrix genuinely violates bounds;
- sequential inventory order for the admission demo;
- basketed candidates' correlations falling back to 1.0.

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER170_ROUND7_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL`
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
