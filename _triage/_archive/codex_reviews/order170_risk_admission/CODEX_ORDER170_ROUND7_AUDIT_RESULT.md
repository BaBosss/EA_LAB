# ORDER-170 Round-7 Independent QA

VERDICT: FAIL

Audit target: `scripts/portfolio_risk_admission.py` at commit
`f5284f29c8ea090fad7cb3d8f541789182d20069`.

Artifact pinning:

- HEAD: `f5284f29c8ea090fad7cb3d8f541789182d20069`
- commit blob: `172d253d14a7301a0105c3de2265151ff25b620d`
- worktree blob: `172d253d14a7301a0105c3de2265151ff25b620d`
- result: byte-identical; the audited worktree script is the requested revision

## Claim-by-claim result

| Claim | Result | Evidence |
|---|---|---|
| 1. Existing admission inventory carries every basket at its canonical ALL-row DD95, independent of pending order, without emitting decisions that breach budget | **NOT VERIFIED** | The exact round-6 E ACTIVE=10 / F PENDING=30 basket BY + G PENDING=10 repro now passes in both orders: summary 40/OVER BUDGET, F `CANNOT_RUN`, G `DEFER_ESCALATE` with no lot. However, when the ACTIVE leg's own DD95 is UNKNOWN and a PENDING sibling supplies the known basket-level DD95, the basket key is absent from `active_units`; the canonical upgrade cannot add it. In pending order G,F the tool grants G `ADMIT_FULL` although the same report's known canonical risk is 30 against budget 25 (Finding F1). |
| 2. `collapse_basket_risk_units()` always retains `max(prev, val)` and near-equal outcomes are insertion-order independent | **VERIFIED** | Direct boundary probe with A ACTIVE=15.00000000075 and E/F PENDING basket BY=10.0/10.0000000005 produced summary `25.000000001249997` and `DEFER_ESCALATE` for both E and F in both pending orders. Direct collapse in both insertion orders retained `basket::BY=10.0000000005`. |
| 3. Cage 25 requires `basket_dd95_used` and protects REFUSED-after-admission provenance | **VERIFIED** | Both requested in-memory mutations were killed by cage 25: deleting `basket_dd95_used` caused `KeyError: 'basket_dd95_used'`; removing `_with_provenance(...)` only from the REFUSED append caused `KeyError: 'assumes_admitted_first'`. Both mutated suites ended `SOME FAILED`. |
| 4. No new defects from the round-7 revision; specified interactions remain correct | **NOT VERIFIED** | ACTIVE-only baskets, a PENDING sibling with UNKNOWN DD95, zero-pending accounts, REAL_CENT report-only, and summary/canonical consistency for the supplied known-value repro all passed. Finding F1 is a remaining mixed ACTIVE/PENDING canonical-inventory defect exposed by an UNKNOWN ACTIVE row plus a known sibling row. |

## Findings

### F1 — SEV-1: a known PENDING sibling cannot seed the canonical risk unit of an UNKNOWN-DD95 ACTIVE basket

Location: `scripts/portfolio_risk_admission.py:789-818` and
`scripts/portfolio_risk_admission.py:825-880`.

Mechanism:

1. `active_known` includes only ACTIVE magics that have their own known DD95
   (`:789-792`).
2. `active_units` therefore contains no basket key when the ACTIVE leg's DD95 is
   UNKNOWN (`:797`).
3. `units_all` correctly contains the basket key from a known PENDING sibling
   (`:811-812`).
4. The round-7 upgrade only replaces keys already present in `existing_units`
   (`:818`); it cannot add the missing active basket key.
5. An unrelated candidate can consequently be sized against an empty/understated
   existing inventory and receive a usable lot.

Concrete end-to-end reproducer (actual CLI, empty correlation directory):

```text
Account 111, DEMO, budget 25

DEPLOYMENTS rows, pending inventory order G then F:
  E  ACTIVE          basket BY
  G  PENDING_ATTACH  standalone
  F  PENDING_ATTACH  basket BY

expectations rows:
  E  basket BY  dd95_expected=UNKNOWN
  F  basket BY  dd95_expected=20
  G  standalone dd95_expected=10

correlation matrix: empty, so missing pairs default to 1.0
```

Observed output:

```text
process exit = 0
account summary:
  portfolio_dd_est = 30.0
  budget_pct       = 25.0
  over_budget      = true
  unknown_magics   = ["E"]

G:
  status                 = ADMIT_FULL
  lot_factor             = 1.0
  portfolio_dd_est_after = 10.0

F:
  status                 = DEFER_ESCALATE
  assumes_admitted_first = ["G"]
  required_lot_factor    = 0.75
```

The basket-level value supplied by F is usable for basket BY: the account summary
already uses it and reports canonical known risk `20 + 10 = 30`. Because E is an
ACTIVE member of BY, that 20-point risk unit is existing inventory before either
pending decision. G should therefore see existing risk 20 and must not receive a
full lot under a 25-point budget. Applying the emitted `G ADMIT_FULL` decision gives
known canonical risk 30, five points over budget.

The reverse pending order F,G is also semantically wrong, though it does not grant G:
F receives `ADMIT_FULL` for a risk unit already represented by ACTIVE E, rather than
`CANNOT_RUN`; G is then deferred. This confirms the result depends on pending order.

This is a wrong admission/sizing decision and violates the explicit "every basket at
its canonical ALL-row value" and "try ANY mixed ACTIVE/PENDING input" requirements.

## Requested round-7 probes

### Exact round-6 mixed known-value repro

Input: E ACTIVE 10 basket BY; F PENDING 30 basket BY; G PENDING 10 standalone;
empty correlation; DEMO budget 25.

| Pending order | Summary | F | G |
|---|---|---|---|
| F,G | 40.0, OVER BUDGET | `CANNOT_RUN` | `DEFER_ESCALATE`, `lot_factor=None`, existing DD 30 |
| G,F | 40.0, OVER BUDGET | `CANNOT_RUN` | `DEFER_ESCALATE`, `lot_factor=None`, existing DD 30 |

No lot was granted. This specific defect is fixed.

### Near-equal max boundary repro

Input: A ACTIVE `15.00000000075`; E/F PENDING basket BY
`10.0`/`10.0000000005`; empty correlation; DEMO budget 25.

Both pending orders produced:

```text
summary portfolio_dd_est = 25.000000001249997
E = DEFER_ESCALATE, lot_factor=None
F = DEFER_ESCALATE, lot_factor=None
canonical basket::BY = 10.0000000005
```

The decisions, compared by magic, were identical across insertion orders.

### Interaction matrix

| Interaction | Observed result |
|---|---|
| ACTIVE-only basket E=10 + standalone G=10 | summary 20/within budget; G `ADMIT_FULL` |
| E ACTIVE=10 basket BY + F PENDING UNKNOWN same basket + G=10 | summary 20/within budget; F `CANNOT_RUN`; G `ADMIT_FULL` |
| Account with zero pending rows | summary computed; `admission_demo=[]` |
| REAL_CENT A ACTIVE=10 + C PENDING=10 | summary 20; C `REPORT_ONLY`, no lot |
| Known mixed-status canonical case from claim 1 | summary 40 and admission existing risk 30 remain consistent |
| UNKNOWN ACTIVE basket leg + known PENDING sibling | **fails**, as Finding F1 shows |

## Mutation evidence

The mutations were executed in memory; no repository file or index entry was
modified.

Mutation 1:

```text
Delete: decision["basket_dd95_used"] = cand_dd95

FAIL  25_conflicting_siblings_canonical_dd95  -- unexpected KeyError: 'basket_dd95_used'
SOME FAILED
MUTATION_OK=False
```

Mutation 2:

```text
Change only the RiskAdmissionError append from:
  admission_demo.append(_with_provenance({...}))
to:
  admission_demo.append({...})

FAIL  25_conflicting_siblings_canonical_dd95  -- unexpected KeyError: 'assumes_admitted_first'
SOME FAILED
MUTATION_OK=False
```

## Regression checks

| Behavior | Result | Evidence |
|---|---|---|
| Pure-PENDING conflicting siblings E=10/F=30, both orders | PASS | summary 30/OVER BUDGET; both decisions defer; no usable lot; lower row carries `basket_dd95_used=30` |
| Sequential composition A ACTIVE 10 + C,D PENDING 10 | PASS | C `ADMIT_FULL`; D `DEFER_ESCALATE` with provenance |
| Single-pending basketed identity | PASS | cage 19; decision uses `risk_unit="basket::BX"` |
| Basket/magic namespace separation | PASS | cage 13 |
| Emitted-reduced lower-bound refusal | PASS | cage 14 |
| Cell `nan`/`inf`/`1e309` poisoning | PASS | cages 5 and 16 |
| Finite-cell monthly aggregation overflow poisoning | PASS | cage 20 |
| Pearson overflow/unmeasurable fallback | PASS | cage 23 |
| Pearson range clamp/subnormal repro | PASS | cage 26 |
| Admission input validation | PASS | cage 17 |
| Non-finite sum-of-squares refusal | PASS | cage 21 |
| Exact-budget DEFER | PASS | cage 24 |
| NTFS hard-link output refusal | PASS | cage 18 executed successfully on this filesystem |
| `--expectations` metadata | PASS | end-to-end temp CLI output reported the supplied temp expectations path and existence |
| Parser rejects 0/negative/inf/nan DD95 | PASS | cage 5 |
| Missing correlation defaults to 1.0 | PASS | cage 3 |
| REAL_CENT is report-only | PASS | direct build-report probe and cage 4 |
| Unknown broker minimum defers | PASS | cage 10 |
| Reduced factor floors rather than rounds upward | PASS | cages 11 and 17 |

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

