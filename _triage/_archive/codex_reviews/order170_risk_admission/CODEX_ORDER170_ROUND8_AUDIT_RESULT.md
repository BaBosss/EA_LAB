# ORDER-170 Round-8 Independent QA

VERDICT: FAIL

Audit target: `scripts/portfolio_risk_admission.py` at commit
`983115fd2d1638cfdd08036d27df35d34169e860`.

Artifact pinning:

- HEAD during audit: `f62137b2dad6019ea0a88bdd4c7946a5cac2caca`
- requested-commit blob: `ae26f8216ac0fb982733d5cb8bdbaa3c714af80f`
- worktree blob: `ae26f8216ac0fb982733d5cb8bdbaa3c714af80f`
- result: byte-identical; although HEAD had advanced, the audited worktree script was exactly the requested revision
- round-8 diff: 28 added lines in this script only (the seeding loop and cage-25 assertions)

## Claim-by-claim result

| Claim | Result | Evidence |
|---|---|---|
| 1. UNKNOWN-own-DD95 ACTIVE basket leg is seeded from a known PENDING sibling; exact round-7 repro works in both pending orders | **VERIFIED** | For both F,G and G,F, the summary was `portfolio_dd_est=30.0`, `over_budget=true`; F was `CANNOT_RUN`; G was `DEFER_ESCALATE` with `lot_factor=null` and `required_lot_factor=0.5`. No lot was granted. |
| 2. General invariant for any deployments/expectations/correlation input, including boundary values and pending-order independence | **NOT VERIFIED** | Finding F1 is a strict over-budget `ADMIT_FULL` at the numeric boundary. Finding F2 makes the account's sizing mode depend on pending row order when same-account type metadata conflicts. Valid, type-consistent basket fuzz otherwise found no seeding-loop undercount or ACTIVE-basket grant. |
| 3. The 26-cage suite kills removal of the round-8 seeding loop | **VERIFIED** | The in-memory mutation removed exactly one loop. Cage 25 failed because F changed from `CANNOT_RUN` to `ADMIT_FULL`; the mutated suite exited 1 with `SOME FAILED`. |
| 4. No new defect from the round-8 seeding-loop revision; specified interactions remain correct | **VERIFIED** | No defect was found in lines 819-830. Multiple distinct part-ACTIVE baskets, a known PENDING value plus another UNKNOWN sibling, zero-known accounts, all tested permutations, and REAL_CENT behaved as specified. F1 and F2 are pre-existing surfaces outside the round-8 diff. |

## Findings

### F1 — SEV-1: the full-size tolerance grants a lot above the strict budget

Locations:

- `scripts/portfolio_risk_admission.py:568`
- `scripts/portfolio_risk_admission.py:664` (same tolerance on the reduced-lot post-check)
- `scripts/portfolio_risk_admission.py:757` (summary uses a strict comparison)

Concrete reproducing input to `build_report()`:

```text
deployments:
  account=111, type=DEMO, magic=C, status=PENDING_ATTACH
dd95_map:
  C=25.0000000005
corr_matrix:
  empty (missing correlation therefore falls back to 1.0)
basket_of:
  empty
DEMO budget:
  25.0
```

Observed output:

```json
{
  "summary_dd": 25.0000000005,
  "summary_over_budget": true,
  "decision": {
    "magic": "C",
    "status": "ADMIT_FULL",
    "lot_factor": 1.0,
    "portfolio_dd_est_after": 25.0000000005,
    "budget_pct": 25.0
  }
}
```

At DD95 `25.000000001`, the result was still `ADMIT_FULL`; at
`25.0000000011`, it changed to `DEFER_ESCALATE`.

Mechanism: line 568 accepts `full_dd <= budget_pct + 1e-9`, while line 757
marks every `pdd > budget_pct` as over budget. Therefore the same report can
emit a usable full-size lot and state `OVER BUDGET`. This directly falsifies
the claim that applying an emitted admission can never take known canonical
risk above the budget. The overage is numerically tiny, but the requested
invariant is strict and the output is a wrong sizing decision, so it is SEV-1
under the prompt's severity definition.

The seeded-basket fix did not introduce this defect; line 568 predates the
round-8 diff.

### F2 — SEV-2: conflicting same-account type metadata makes pending order select the sizing mode

Locations:

- `scripts/portfolio_risk_admission.py:88-106`
- `scripts/portfolio_risk_admission.py:696`

Concrete reproducing input:

```text
same account 111, empty correlation, no baskets:
  C PENDING_ATTACH, type=DEMO,      DD95=10
  D PENDING_ATTACH, type=REAL_CENT, DD95=10
```

Observed output with C,D inventory order:

```json
{
  "summary": {
    "type": "DEMO",
    "budget_pct": 25.0,
    "portfolio_dd_est": 20.0
  },
  "decisions": [
    ["C", "ADMIT_FULL", 1.0],
    ["D", "ADMIT_FULL", 1.0]
  ]
}
```

Observed output with D,C inventory order:

```json
{
  "summary": {
    "type": "REAL_CENT",
    "budget_pct": null,
    "portfolio_dd_est": 20.0
  },
  "decisions": [
    ["D", "REPORT_ONLY", null],
    ["C", "REPORT_ONLY", null]
  ]
}
```

Mechanism: `load_deployments()` accepts the per-row type values without
checking that an account has one consistent type. `summarize_account()` then
uses `rows[0]["type"]` for the entire account. Reordering pending rows switches
between DEMO sizing and REAL_CENT report-only behavior; this is not merely the
allowed sequential effect of deciding which candidate receives remaining
budget first.

The input is internally contradictory, so this is classified SEV-2 rather
than a demonstrated wrong number on a valid inventory. It nevertheless
violates the literal "ANY deployments input" and pending-order-independence
claim: the accepted input should be validated/fail closed instead of silently
choosing the first row. This surface also predates round 8.

## Round-8 repro and interaction evidence

### Exact round-7 repro

Input: E ACTIVE with own DD95 UNKNOWN, E/F in basket BY, F PENDING DD95 20,
G PENDING standalone DD95 10, empty correlation, DEMO budget 25.

| Pending order | Summary | F | G | Grant |
|---|---|---|---|---|
| F,G | 30.0, `over_budget=true` | `CANNOT_RUN` | `DEFER_ESCALATE`, required factor 0.5 | none |
| G,F | 30.0, `over_budget=true` | `CANNOT_RUN` | `DEFER_ESCALATE`, required factor 0.5 | none |

The changed loop correctly seeds `basket::BY=20` before either pending row is
processed.

### Interaction matrix

| Interaction | Observed result |
|---|---|
| Pure-PENDING conflicting siblings E=10/F=30, both orders | Summary 30/over budget; both candidates deferred; no grant |
| Mixed known ACTIVE/PENDING conflict E ACTIVE=10, F PENDING=30 in BY, G PENDING=10, both orders | Summary 40/over budget; F `CANNOT_RUN`; G `DEFER_ESCALATE`; no grant |
| Two distinct ACTIVE baskets whose known values exist only on PENDING siblings, plus UNKNOWN sibling and standalone candidate | All 24 pending permutations passed; both basket siblings and the UNKNOWN sibling were `CANNOT_RUN`; unrelated G saw the combined seeded risk |
| ACTIVE UNKNOWN E + known PENDING F=20 + UNKNOWN PENDING U in BY + standalone G=10 | All 6 pending permutations passed; F/U `CANNOT_RUN`; G `DEFER_ESCALATE` |
| Zero-known account | Summary risk absent (`null`); pending candidate `CANNOT_RUN`; no zero risk invented |
| REAL_CENT A ACTIVE=10 + C PENDING=10 | Summary 20; C `REPORT_ONLY`, no lot |
| Sequential composition A ACTIVE=10 + C,D PENDING=10 | First pending candidate `ADMIT_FULL`; second `DEFER_ESCALATE` with `assumes_admitted_first`; reversing order only swaps which candidate is first |
| Near-equal basket values 10.0/10.0000000005 | Both insertion orders collapsed to `basket::BY=10.0000000005` |

### Randomized probing

Deterministic seed `170008`; 50,000 type-consistent account cases; 1-8 rows
each; randomized ACTIVE/PENDING/INACTIVE status, UNKNOWN subsets, 0-3 baskets,
conflicting sibling values, REAL_CENT cases, and boundary values; empty
correlation for conservative additive risk:

```text
cases=50000
pending decisions=118883
grants=34403
crashes=0
grants for a basket already represented by an ACTIVE leg=0
strict over-budget grants=2425
strict overage range=1.0018652574217413e-12 to 1.000000082740371e-09
overages above 1.1e-9=0
```

Thus the fuzz found no additional seeding-loop failure. Every observed strict
breach was the line-568 tolerance defect in F1.

## Mutation evidence

The mutation was executed in memory; no repository file or index entry was
modified.

Mutation:

```text
remove lines 823-830:
  for r in rows:
      ...
      existing_units[k] = units_all[k]
```

Observed output excerpt:

```text
MUTATION_REMOVALS=1
...
FAIL  25_conflicting_siblings_canonical_dd95  -- order ('F', 'G'): sibling of an ACTIVE basket must not be sized: {'magic': 'F', 'status': 'ADMIT_FULL', 'lot_factor': 1.0, 'portfolio_dd_est_after': 20.0, 'budget_pct': 25.0, ...}
PASS  26_pearson_result_stays_in_range
SOME FAILED
MUTANT_EXIT=1
```

This verifies that the extended cage 25 kills the practical removal of the
new seeding loop.

## Regression checks

| Behavior | Result | Evidence |
|---|---|---|
| Pure-PENDING conflicting siblings, both orders | PASS | Independent interaction probe above |
| Mixed known-value ACTIVE/PENDING conflict | PASS | Independent interaction probe above |
| Near-equal collapse order independence | PASS | Independent direct-collapse probe |
| Sequential composition | PASS | Independent both-order probe and cage 22 |
| Basketed identity | PASS | Cage 19 |
| Basket/magic namespace separation | PASS | Cage 13 |
| Emitted-reduced lower bound | PASS | Cage 14 |
| P&L poisoning at cell/magic/aggregation levels | PASS | Cages 8, 16, and 20 |
| Pearson overflow and missing-correlation fallback | PASS | Cages 23 and 3 |
| Pearson range clamp | PASS | Cage 26 |
| Admission numeric input validation | PASS | Cage 17 |
| Non-finite sum-of-squares refusal | PASS | Cage 21 |
| Exact-budget existing portfolio defers | PASS | Cage 24 |
| Protected path / NTFS hard-link refusal | PASS | Cage 18 executed on this filesystem |
| `--expectations` metadata | PASS | Independent temp CLI run: exit 0; JSON reported the supplied existing temp path and `expectations_csv_found=true` |
| Parser rejection of 0/negative/inf/nan DD95 | PASS | Cage 5 |
| REAL_CENT report-only | PASS | Independent probe and cage 4 |
| Broker minimum `None` defers | PASS | Cage 10 |
| Floor-not-round and post-floor checks | PASS | Cages 11 and 17 |

## Exact self-test output

Command:

```text
D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest
```

Output:

```text
PASS  1_golden_sample
PASS  2_bounds_assert
PASS  3_missing_corr_defaults_to_one
PASS  4_lot_factor_bounds
PASS  5_parser_rejects_every_unknown_form
PASS  6_expectations_file_absent
PASS  7_basket_counted_once
PASS  8_corrupt_pnl_does_not_become_zero
PASS  9_admit_bounds_guard_on_existing
PASS  10_broker_min_fails_closed
PASS  11_rounded_factor_within_budget
PASS  12_admission_path_collapses_baskets
PASS  13_basket_id_magic_namespace_separation
PASS  14_emitted_reduced_respects_lower_bound
PASS  15_formula_guard_mutation_protection
PASS  16_nonfinite_pnl_poisons_magic_end_to_end
PASS  17_admission_validates_own_inputs
PASS  18_safe_output_path_guard
PASS  19_basketed_candidate_same_identity
PASS  20_overflowing_pnl_poisons_magic
PASS  21_extreme_finite_inputs_fail_closed
PASS  22_multiple_pending_decisions_compose
PASS  23_pearson_overflow_is_unmeasurable
PASS  24_exact_budget_defers_not_refuses
PASS  25_conflicting_siblings_canonical_dd95
PASS  26_pearson_result_stays_in_range
ALL PASS
```
