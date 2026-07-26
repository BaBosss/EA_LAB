# QA task: independent verification pass on scripts/portfolio_risk_admission.py (round 9)

Neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py` at commit
`48c7d50` (verify the script blob matches that commit if HEAD advanced). Round 8's fuzz (50,000
cases) found zero basket/seeding failures; every remaining strict breach traced to one budget
tolerance (F1) plus one metadata-validation gap (F2). Both are addressed in this revision, which
touches only: the two budget comparisons in `admit_candidate()`, the type-conflict detection in
`summarize_account()`, the CANNOT_RUN short-circuit in `build_report()`, and new cage 27.

## Ground rules
- Read-only, with one exception: you MAY create temp files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Prefer executing concrete failing-input probes over reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk,
  MINOR), each with a concrete reproducing input and observed output.

## Claims to verify
1. (was round-8 F1) Budget comparisons in `admit_candidate()` are STRICT: a candidate whose
   full-size portfolio_dd exceeds the budget by ANY amount is never ADMIT_FULL, and the emitted
   reduced point never exceeds the budget by any amount; exact equality still admits. Probe the
   round-8 boundary reproducers (candidate 25.0000000005 / 25.000000001 vs DEMO budget 25 ->
   never ADMIT_FULL; candidate 25.0 exactly -> ADMIT_FULL) and re-run a strict-breach fuzz of
   your own design: NO emitted grant may ever imply portfolio_dd_est > budget, even by 1e-12.
2. (was round-8 F2) An account whose DEPLOYMENTS rows disagree on `type` fails closed:
   `type_conflict=true`, `budget_pct=null` with an explicit conflict note, every pending
   candidate CANNOT_RUN, outcome identical in every row order. Probe the round-8 repro
   (C DEMO + D REAL_CENT on one account, both orders).
3. Cage 27 kills the practical mutations: restoring `+ 1e-9` on the full-size budget check must
   fail the suite; removing the type-conflict short-circuit (or the detection) must fail the
   suite.
4. No NEW defects from this revision. Scrutinize: does the strict comparison break any legitimate
   exact-fit or floor-path case (cages 10, 11, 22, 24 semantics)? Does the type-conflict guard
   misfire on accounts with a single consistent type, blank types, or REAL_CENT-only accounts?

Also regression-check (cages exist for most; spot-check independently where cheap): UNKNOWN-leg
basket seeding (round-7 repro); pure-PENDING and mixed conflicting siblings both orders;
near-equal collapse order-independence; sequential composition; basketed identity; namespace
separation; emitted-reduced lower-bound; P&L poisoning at all levels; pearson range clamp;
admission input validation; non-finite sum-of-squares; exact-budget DEFER; hard-link refusal;
--expectations metadata; parser rejections; missing corr -> 1.0; REAL_CENT -> REPORT_ONLY;
broker minimum None -> DEFER; floor-not-round.

Deliberate design points, not defects (flag only if you can produce a WRONG number through them):
- strictness itself: a float-noise DEFER of a mathematically exact fit is the accepted
  conservative trade-off; equality admits;
- conservative direction everywhere (canonical = max; unmeasurable corr -> 1.0; deferred
  candidates not carried; fail-closed REFUSED on genuine bounds violations);
- sequential inventory order; UNKNOWN standalone ACTIVE magics excluded-but-reported;
- basketed candidates' correlations falling back to 1.0.

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER170_ROUND9_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL`
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
