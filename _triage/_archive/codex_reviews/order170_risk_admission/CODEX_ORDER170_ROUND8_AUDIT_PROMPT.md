# QA task: independent verification pass on scripts/portfolio_risk_admission.py (round 8)

Neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py` at commit
`983115f` (verify the script blob matches that commit if HEAD advanced). Seven prior QA rounds
each found real defects; round 7 narrowed to ONE SEV-1, addressed in this revision.

## Ground rules
- Read-only, with one exception: you MAY create temp files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Prefer executing concrete failing-input probes over reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk,
  MINOR), each with a concrete reproducing input and observed output.

## Claims to verify (round-8 revision, responding to round-7 F1)
1. A basket with an ACTIVE leg whose OWN DD95 is UNKNOWN, but whose known basket-level value is
   supplied by a PENDING sibling row, is now part of the existing admission inventory. Probe the
   round-7 repro in both pending orders: E ACTIVE (UNKNOWN, basket BY) + F PENDING (20, basket
   BY) + G PENDING (10, standalone), empty corr, DEMO budget 25 -> F CANNOT_RUN (sibling of an
   ACTIVE basket), G DEFER_ESCALATE seeing existing risk 20 (full-size 30 > 25), NO grant in
   either order, consistent with the summary's 30/OVER BUDGET.
2. The general invariant, which every prior round chipped at -- try hard to break it:
   for ANY deployments/expectations/correlation input (conflicting siblings, UNKNOWN legs in any
   status combination, basket values supplied by any subset of rows, order permutations,
   boundary values), applying the emitted admission decisions as written can never take the
   account's KNOWN canonical risk (as the summary computes it, including every pending
   candidate's canonical value) above the budget; and outcomes are pending-order independent
   except for which candidate gets the budget first (sequential contract). Randomized/fuzz
   probing encouraged.
3. The self-test suite (26 cages, cage 25 extended) kills the practical mutation: removing the
   round-8 seeding loop (the `for r in rows: ... existing_units[k] = units_all[k]` block) must
   fail at least one cage.
4. No NEW defects from this revision (changed surface: the seeding loop only). Interactions to
   scrutinize: multiple distinct baskets part-ACTIVE part-PENDING; a basket whose ONLY known
   value comes from a PENDING sibling while ANOTHER pending sibling is also unknown; zero-known
   accounts; REAL_CENT.

Also regression-check (cheap, cages exist for most): pure-PENDING conflicting siblings both
orders; mixed known-value ACTIVE/PENDING conflict (E ACTIVE 10 / F PENDING 30 / G PENDING 10 ->
no grant); near-equal collapse order-independence; sequential composition; basketed identity;
namespace separation; emitted-reduced lower-bound; P&L poisoning at all levels; pearson range
clamp; admission input validation; non-finite sum-of-squares; exact-budget DEFER; hard-link
refusal; --expectations metadata; parser rejections; missing corr -> 1.0; REAL_CENT ->
REPORT_ONLY; broker minimum None -> DEFER; floor-not-round.

Deliberate design points, not defects (flag only if you can produce a WRONG number through them):
- conservative direction everywhere (canonical = max; unmeasurable corr -> 1.0; deferred
  candidates not carried; fail-closed REFUSED on genuine bounds violations);
- sequential inventory order deciding which candidate gets remaining budget first;
- a standalone ACTIVE magic with UNKNOWN DD95 staying excluded from the existing inventory
  (reported as UNKNOWN coverage, matching the summary's exclusion rule);
- basketed candidates' correlations falling back to 1.0.

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER170_ROUND8_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL`
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
