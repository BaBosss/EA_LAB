# QA task: independent verification pass on scripts/portfolio_risk_admission.py (round 10)

Neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py` at commit
`d3261b8` (verify the script blob matches that commit if HEAD advanced). Round 9 verified the
strict budget engine end-to-end (your own 100,000-case fuzz: zero breaches) and left one SEV-2 +
two MINORs, all metadata/test-quality items, addressed in this small revision. Changed surfaces:
`_fits_budget()` helper (both admit_candidate budget checks route through it), row-set account
type derivation in `summarize_account()`, cage 27 extensions, cage 11 strictness.

## Ground rules
- Read-only, with one exception: you MAY create temp files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Prefer executing concrete failing-input probes over reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk,
  MINOR), each with a concrete reproducing input and observed output.

## Claims to verify
1. (was round-9 F1) Account type derives from the normalized row SET: blank types do not vote;
   the sole non-blank type wins in every row order (probe blank+DEMO both orders -> DEMO budget
   25 and identical decisions); case differences (demo vs DEMO) are not conflicts; two or more
   distinct non-blank normalized types -> fail-closed conflict with a deterministic
   CONFLICT(TYPE1|TYPE2) label and CANNOT_RUN for every pending, identical in every order.
   All-blank accounts get no budget (unrecognized) as before.
2. (was round-9 F2) Both budget comparisons in `admit_candidate()` route through the single
   strict `_fits_budget()` helper, and cage 27 mutation-locks it: making `_fits_budget` tolerant
   (`dd <= budget + 1e-9`) must fail the suite; verify no other hand-written budget comparison
   remains that a tolerance could quietly return on.
3. (was round-9 F3) The conflicted account's reported `type` is order-independent.
4. No NEW defects from this revision. Scrutinize: type normalization interactions (whitespace,
   REAL_CENT case variants, unrecognized non-blank types like 'LIVE'), summary display fields,
   and that the strict-budget engine behavior from round 9 is unchanged (spot-check the boundary
   probes: 25.0000000005 never ADMIT_FULL; 25.0 exactly ADMIT_FULL).

Regression-check the standing invariants briefly (cages cover most; independent spot-checks
where cheap): UNKNOWN-leg basket seeding; conflicting siblings canonical DD95 both orders;
sequential composition + provenance; emitted-reduced lower bound; P&L poisoning at all levels;
pearson range clamp; admission input validation; exact-budget DEFER; hard-link refusal;
--expectations metadata; parser rejections; missing corr -> 1.0; REAL_CENT -> REPORT_ONLY;
broker minimum None -> DEFER; floor-not-round.

Deliberate design points, not defects (flag only if you can produce a WRONG number through them):
- blank rows not voting (the sole non-blank type identifies the account);
- strictness float-noise refusals; equality admits;
- conservative direction everywhere (canonical = max; unmeasurable corr -> 1.0; deferred
  candidates not carried; fail-closed REFUSED on genuine bounds violations);
- sequential inventory order; UNKNOWN standalone ACTIVE magics excluded-but-reported;
- an unrecognized non-blank type (e.g. 'LIVE') getting no budget with the existing
  "unrecognized account type" note (pre-existing contract, not new).

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER170_ROUND10_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL`
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
