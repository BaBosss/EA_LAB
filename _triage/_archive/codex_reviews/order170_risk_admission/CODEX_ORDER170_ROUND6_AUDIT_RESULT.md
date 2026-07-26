# ORDER-170 Round-6 Independent QA

VERDICT: FAIL

Audit target: `scripts/portfolio_risk_admission.py` at commit
`7a71316556caa03de6bc77d59c3459f13dda5652`.

The current worktree script was verified byte-for-byte against that commit:

- commit blob: `2dea72b78e55215471a06ae8cc16c4ee2a71fcb4`
- worktree blob: `2dea72b78e55215471a06ae8cc16c4ee2a71fcb4`
- HEAD had advanced to `52581890b6878d7da5660b303234a9cb659a3a02`, but the audited script had not changed.

## Claim-by-claim result

| Claim | Result | Evidence |
|---|---|---|
| 1. Canonical conservative basket DD95 is used for every PENDING decision; decisions are order-independent and cannot breach budget when composed | **NOT VERIFIED** | The requested pure-PENDING E=10/F=30 repro passes in both orders, but a mixed ACTIVE/PENDING basket still understates existing risk and emits an `ADMIT_FULL` that takes canonical risk to 40% against a 25% budget (Finding F1). A second epsilon-boundary input remains inventory-order dependent (Finding F2). |
| 2. Post-admission `CANNOT_RUN` and `REFUSED` records carry `assumes_admitted_first` | **VERIFIED** | Direct probes produced `assumes_admitted_first: ["C"]` on both a later UNKNOWN `CANNOT_RUN` and a later bounds-invalid `REFUSED`. Current behavior is correct, although the REFUSED branch is not protected by the self-test (Finding F4). |
| 3. `pearson()` clamps epsilon overshoot and treats materially out-of-range finite results as unmeasurable | **VERIFIED** | The supplied subnormal repro returned `None`; no correlation outside `[-1,1]` was stored. Removing the range guard in memory made cage 26 fail with `pearson emitted out-of-range 1.0000673314140571`. |
| 4. The 26-test suite covers the round-5 fixes and kills the practical mutations | **PARTIAL** | Reverting admission to the row DD95 fails cage 25; removing the Pearson range guard fails cage 26. However, deleting the required `basket_dd95_used` field still gives 26/26 `ALL PASS`, and removing provenance only from the REFUSED path also gives 26/26 `ALL PASS` (Findings F3-F4). Cage 25 also misses the mixed ACTIVE/PENDING SEV-1 in F1. |

## Findings

### F1 — SEV-1: an ACTIVE basket is not upgraded to the all-row canonical DD95 before sizing an unrelated PENDING candidate

Location: `scripts/portfolio_risk_admission.py:783` (ACTIVE-only source),
`:791` (initial collapse), `:800` (all-row lookup), `:831` (early sibling
`CANNOT_RUN`), and `:845` (subsequent sizing).

Concrete reproducer:

```text
Account: 111, DEMO, budget 25
Rows:
  E ACTIVE          DD95=10  basket=BY
  F PENDING_ATTACH  DD95=30  basket=BY
  G PENDING_ATTACH  DD95=10  standalone
Correlation matrix: empty (all missing pairs conservatively default to 1.0)
```

Observed with pending order `F, G`:

```text
summary portfolio_dd_est = 40.0
summary over_budget       = true

F -> CANNOT_RUN
G -> ADMIT_FULL, lot_factor=1.0, portfolio_dd_est_after=20.0
```

Observed with pending order `G, F`:

```text
summary portfolio_dd_est = 40.0
summary over_budget       = true

G -> ADMIT_FULL, lot_factor=1.0, portfolio_dd_est_after=20.0
F -> CANNOT_RUN, assumes_admitted_first=["G"]
```

The summary correctly canonicalizes basket BY to `max(10,30)=30`, but
`existing_units` is built from ACTIVE rows only and retains BY=10. `units_all`
is used only as the current candidate's DD95. When F is rejected as a sibling
of an already-counted ACTIVE basket, its canonical 30 never upgrades
`existing_units`; G is therefore admitted against 10 instead of 30. Applying
the emitted grant gives canonical risk `30 + 10 = 40`, breaching the 25 budget
by 15 points.

This violates the explicit all-known-rows, mixed ACTIVE/PENDING, and
no-composed-budget-breach requirements.

### F2 — SEV-1: the “canonical max” remains inventory-order dependent for sibling DD95 values within the 1e-9 duplicate tolerance

Location: `scripts/portfolio_risk_admission.py:194-203` and `:805-846`.

Concrete reproducer:

```text
Account: 111, DEMO, budget 25
A ACTIVE          DD95=15.00000000075  standalone
E PENDING_ATTACH  DD95=10.0            basket=BY
F PENDING_ATTACH  DD95=10.0000000005   basket=BY
Correlation matrix: empty
```

Observed order `E, F`:

```text
basket fold: F described as a duplicate; retained basket DD95=10.0
E -> ADMIT_FULL, lot_factor=1.0, portfolio_dd_est_after=25.00000000075
F -> CANNOT_RUN
```

Observed reverse order `F, E`:

```text
basket fold: E described as a duplicate; retained basket DD95=10.0000000005
F -> DEFER_ESCALATE
E -> DEFER_ESCALATE
```

`collapse_basket_risk_units()` treats a difference of at most `1e-9` as an
equal duplicate and retains the first value rather than always applying
`max(prev, val)`. At the budget tolerance boundary this changes the sizing
decision from `ADMIT_FULL` to `DEFER_ESCALATE`. The numerical gap is tiny, but
the observed output is a different attach/sizing decision, so it meets the
prompt's SEV-1 definition and contradicts “max” and inventory-order
independence.

### F3 — MINOR: cage 25 does not require `basket_dd95_used` to exist

Location: `scripts/portfolio_risk_admission.py:1528`.

Mutation:

```text
Delete: decision["basket_dd95_used"] = cand_dd95
```

Observed self-test result after the in-memory mutation:

```text
delete_basket_dd95_used ok=True
ALL PASS
```

The assertion uses `first.get("basket_dd95_used", 30.0) == 30.0`; its default
is the expected value, so absence of the required field passes.

### F4 — MINOR: no cage protects REFUSED provenance after an earlier admission

Location: current behavior at `scripts/portfolio_risk_admission.py:871-875`;
test coverage at `:1534-1544`.

Current direct probe:

```text
C PENDING DD95=10
D PENDING DD95=10
corr(C,D)=-1

C -> ADMIT_FULL
D -> REFUSED, assumes_admitted_first=["C"]
```

Mutation:

```text
Remove _with_provenance(...) only from the RiskAdmissionError/REFUSED append.
```

Observed self-test result:

```text
remove_refused_provenance ok=True
ALL PASS
```

Cage 25 checks only a post-admission `CANNOT_RUN`; it does not exercise the
separate post-admission `REFUSED` append required by claim 2.

## Requested and regression probes

| Behavior | Result | Evidence |
|---|---|---|
| Round-5 E=10/F=30 pure-PENDING basket, both row orders | PASS | First decision is `DEFER_ESCALATE` at canonical 30 in both orders; neither sibling receives a lot. |
| `basket_dd95_used` when row differs from canonical | PASS in current code | Lower-valued sibling decisions contain `basket_dd95_used: 30.0`; F3 records the cage gap. |
| Round-4 A ACTIVE 10 + C,D PENDING 10, budget 25 | PASS | Cage 22: C `ADMIT_FULL`, D `DEFER_ESCALATE` with sequential provenance. |
| Single PENDING basketed-candidate identity | PASS | Cage 19 uses `risk_unit="basket::BX"` and does not resolve raw-magic correlation. |
| Basket collapse in summary and admission | **FAIL for mixed-status conflict** | Ordinary equal-value fixtures pass cages 7/12/19; F1 demonstrates the remaining mixed ACTIVE/PENDING conflict. |
| Basket/magic namespace separation | PASS | Cage 13 passes. |
| Reduced point lower-bound refusal | PASS | Cage 14 passes. |
| `nan`/`inf`/`1e309`, cell/aggregation/Pearson overflow poisoning | PASS | Cages 16, 20, 21, and 23 pass. |
| Admission input validation | PASS | Cage 17 passes. |
| Non-finite sum-of-squares refusal | PASS | Cage 21 passes. |
| Exact-budget DEFER, not REFUSED | PASS | Cage 24 passes. |
| NTFS hard-link output refusal | PASS | Cage 18 passes on this filesystem. |
| Coverage metadata reflects custom `--expectations` | PASS | `build_report(..., expectations_path=...)` writes that path and existence state at lines 886-889. |
| Parser rejects zero/negative/inf/nan DD95 | PASS | Cage 5 passes. |
| Missing correlation defaults to 1.0 | PASS | Cage 3 passes. |
| REAL_CENT is report-only | PASS | Cage 4's direct REAL_CENT branch passes. |
| Unknown broker minimum defers | PASS | Cage 10 passes. |
| Reduced factor floors rather than rounds upward | PASS | Cages 11 and 17 pass. |

## Mutation evidence

The two requested practical mutations were executed in memory, without
modifying the repository:

```text
raw_candidate_dd95 ok=False
FAIL  25_conflicting_siblings_canonical_dd95  -- order ('E', 'F'): first sibling must be sized at canonical 30 (> budget 25), got {'magic': 'E', 'status': 'ADMIT_FULL', 'lot_factor': 1.0, 'portfolio_dd_est_after': 10.0, 'budget_pct': 25.0, 'message': "fits at locked-set lot (lot_factor 1.0) (sized at the basket's canonical DD95 30.0, not this row's 10.0 -- conflicting sibling values, larger kept)", 'risk_unit': 'basket::BY', 'basket_dd95_used': 30.0, 'account': '111', 'ea_name': 'EA'}
SOME FAILED

remove_pearson_range_guard ok=False
FAIL  26_pearson_result_stays_in_range  -- pearson emitted out-of-range 1.0000673314140571
SOME FAILED
```

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

## Review-axis summary

- **Spec/correctness:** FAIL — two wrong sizing/order outcomes, worst severity
  SEV-1 (F1 and F2).
- **Standards/maintainability:** no separate documented-standard breach or
  material Fowler smell was found in the round-6 diff. The two MINOR findings
  are test-quality gaps rather than production-style violations.
