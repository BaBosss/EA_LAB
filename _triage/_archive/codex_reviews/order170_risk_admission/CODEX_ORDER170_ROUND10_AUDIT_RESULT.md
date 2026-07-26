# ORDER-170 round-10 independent QA audit

VERDICT: PASS

No SEV-1 or SEV-2 production defect was found. The current strict-budget behavior,
row-set account-type normalization, and deterministic conflict reporting work as
specified. One MINOR test/centralization gap remains: the pre-existing-portfolio
budget guard is still a hand-written comparison outside `_fits_budget()`, and a
tolerance mutation there survives all 27 cages.

## Target integrity

- Requested commit: `d3261b876359c0cbe43d93867ed106c0f88eb3c6`
- HEAD during audit: `d3261b876359c0cbe43d93867ed106c0f88eb3c6`
- Requested script blob: `f7a29fbac4cb202032ac6a999f46e2c9e88a9898`
- Working-tree script blob: `f7a29fbac4cb202032ac6a999f46e2c9e88a9898`
- Result: exact blob match. Unrelated pre-existing worktree changes were not
  modified.

## Claim-by-claim result

| # | Result | Evidence |
|---|---|---|
| 1. Account type derives from the normalized row set | **VERIFIED** | Independent `build_report()` probes with blank+DEMO in both orders produced `type="DEMO"`, `budget_pct=25.0`, `type_conflict=false`, and `ADMIT_FULL` for both pending magics. `" demo "`+`"DEMO"` behaved identically. `" real_cent "`+`"REAL_CENT"` normalized to `REAL_CENT` and produced only `REPORT_ONLY`. LIVE+blank normalized to `LIVE` with no budget; all-blank normalized to `""` with no budget. Three distinct normalized types in both tested orders produced the same `CONFLICT(DEMO\|LIVE\|REAL_CENT)` label, note, and per-magic `CANNOT_RUN` decisions. |
| 2. One strict `_fits_budget()` helper and mutation lock | **PARTIAL** | Full-size line 581 and emitted-reduced line 678 both call `_fits_budget()`. Mutating the helper to `dd <= budget + 1e-9` makes cage 27 fail and the suite end `SOME FAILED`, as claimed. However, `admit_candidate()` line 546 still hand-writes `existing_dd > budget_pct`; a `+1e-9` mutation there survives all cages and can change DEFER to ADMIT_FULL. See F1. |
| 3. Conflicted account `type` is order-independent | **VERIFIED** | DEMO/REAL_CENT in both orders produced `CONFLICT(DEMO\|REAL_CENT)`, `budget_pct=null`, and `CANNOT_RUN` for every pending magic. A three-way DEMO/LIVE/REAL_CENT conflict was also deterministic in both tested orders. |
| 4. No new production defects; strict engine unchanged | **VERIFIED** | `25.0000000005` was not `ADMIT_FULL` (with a supplied broker minimum it became conservative `ADMIT_REDUCED`, factor `0.9999`, emitted DD `24.997500000499947`); exact `25.0` was `ADMIT_FULL`. A fresh deterministic 100,000-case fuzz found zero granted-budget breaches. All 27 cages passed. No present row-normalization, sizing, report, parser, correlation, basket, P&L, or output-safety regression was reproduced. F1 is a residual mutation-lock/centralization gap, not a current wrong decision. |

## Findings

### F1 — MINOR: pre-existing-portfolio budget guard remains outside the single helper

**Location:** `scripts/portfolio_risk_admission.py:455-460`,
`scripts/portfolio_risk_admission.py:546`, and mutation coverage at
`scripts/portfolio_risk_admission.py:1679-1739`.

The new helper is described as “THE single budget comparison,” but
`admit_candidate()` still contains:

```python
if existing_dd > budget_pct:
```

An AST inspection found `_fits_budget()` calls at lines 581 and 678, while line
546 remains the only direct DD-versus-budget comparison inside
`admit_candidate()`. This is strict and correct today, but it leaves the same
policy independently editable at a third site.

Concrete reproducer for the uncovered mutation:

```text
candidate: C, DD95=1.0
existing: A=15.0, B=10.0000000005
corr(A,B)=1.0
corr(A,C)=-1.0
corr(B,C)=-1.0
budget=25.0
broker_min_lot_factor=0.0001
mutation at line 546:
    existing_dd > budget_pct
 -> existing_dd > budget_pct + 1e-9
```

Observed output:

```text
current:
  status=DEFER_ESCALATE
  existing_portfolio_dd_est=25.000000000500002
  message="existing portfolio already exceeds budget..."

mutated:
  status=ADMIT_FULL
  lot_factor=1.0
  portfolio_dd_est_after=24.000000000500002

mutated selftest:
  ALL PASS
```

Thus a tolerance can still “quietly return” at a hand-written budget comparison
and change an admission decision without a cage failure. This is classified
MINOR because the checked-in comparison is strict and the current production
output is correct; the defect is incomplete centralization and mutation
coverage, not an extant wrong sizing result.

The summary display comparison at line 789 is also hand-written, but cage 27's
`over_budget is True` assertion detects the relevant tolerance restoration.

## Mutation evidence

The specifically requested helper mutation was killed:

```text
mutation:
  return dd <= budget
->return dd <= budget + 1e-9

observed:
FAIL  27_strict_budget_and_type_conflict  -- granted a full lot above the strict budget while summary says OVER BUDGET: {'magic': 'C', 'status': 'ADMIT_FULL', 'lot_factor': 1.0, 'portfolio_dd_est_after': 25.0000000005, 'budget_pct': 25.0, 'message': 'fits at locked-set lot (lot_factor 1.0)', 'account': '111', 'ea_name': 'EA'}
SOME FAILED
```

## Independent behavioral evidence

### Account-type normalization

```text
blank+DEMO, C then D:
  type=DEMO, conflict=false, budget=25.0
  C=ADMIT_FULL, D=ADMIT_FULL

blank+DEMO, D then C:
  type=DEMO, conflict=false, budget=25.0
  D=ADMIT_FULL, C=ADMIT_FULL

" demo "+DEMO:
  type=DEMO, conflict=false, budget=25.0

" real_cent "+REAL_CENT:
  type=REAL_CENT, conflict=false, budget=null
  both REPORT_ONLY

LIVE+blank:
  type=LIVE, conflict=false, budget=null
  note="unrecognized account type 'LIVE' -- no budget assigned, user decision needed"

all blank:
  type="", conflict=false, budget=null
  both REPORT_ONLY

demo+LIVE+REAL_CENT, both tested orders:
  type=CONFLICT(DEMO|LIVE|REAL_CENT)
  conflict=true, budget=null
  every pending magic CANNOT_RUN
```

### Strict-budget spot checks and fuzz

```text
candidate DD95=25.0000000005, budget=25.0, broker minimum=0.0001:
  status=ADMIT_REDUCED
  lot_factor=0.9999
  portfolio_dd_est_after=24.997500000499947

candidate DD95=25.0, budget=25.0:
  status=ADMIT_FULL
  lot_factor=1.0
  portfolio_dd_est_after=25.0

FUZZ seed=17010 cases=100000 full=50073 reduced=47875 defer=2 refused=2050
STRICT_BREACHES=0
WORST_DD_MINUS_BUDGET=0.0
```

The fuzz used 0-5 existing risk units, finite positive log-uniform DD95 values,
equicorrelation in `[0,1)`, and budgets at equality, one ULP below/above,
near-equality, or between existing and full-size DD. Every granted factor was
independently reapplied and recomputed through `portfolio_dd_est()`.

### Standing invariant checks

All named standing invariants are exercised by the passing cages. Independent
cheap probes additionally observed:

```text
missing corr for DD95 4 and 6 -> portfolio DD 10.0
existing DD exactly 25 plus positive candidate -> DEFER_ESCALATE
candidate DD 30, budget 25, broker minimum None -> DEFER_ESCALATE
candidate DD 100, budget 5.006 -> emitted factor 0.05, DD 5.0 (floor, not round)
candidate DD inf -> RiskAdmissionError
subnormal pearson probe -> None (unmeasurable, never outside [-1,1])
```

The complete cage run covers UNKNOWN-leg basket seeding; canonical DD95 for
conflicting siblings in both orders; sequential composition and provenance;
emitted-reduced lower-bound enforcement; non-finite and overflowing P&L
poisoning; Pearson range handling; admission input validation; exact-budget
DEFER; hard-link refusal; `--expectations` metadata; parser rejections; missing
correlation fallback; REAL_CENT report-only behavior; broker-minimum `None`; and
floor-not-round.

## Standards axis

No documented `AGENTS.md` violation was found in the round-10 script diff. F1 is
a judgement-call duplicated-policy/divergent-change smell: the strict budget
policy remains represented by `_fits_budget()` plus direct comparisons at lines
546 and 789. No other applicable baseline smell was found.

## Spec axis

Claims 1 and 3 are fully implemented, current strict sizing behavior in claim 4
is unchanged, and the requested tolerant-helper mutation is killed. Claim 2 is
only partial because the literal “single budget comparison/no tolerance can
quietly return” requirement is not satisfied at line 546. This produces one
MINOR test-quality finding and no SEV-1/SEV-2 current production finding.

## Exact selftest output

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
PASS  27_strict_budget_and_type_conflict
ALL PASS
```
