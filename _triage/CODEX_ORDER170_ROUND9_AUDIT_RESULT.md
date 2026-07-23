# ORDER-170 round-9 independent QA audit

VERDICT: FAIL

Reason: the strict budget fix is correct in the current blob and the three required
mutations are killed, but mixed blank/DEMO account-type metadata still produces
row-order-dependent sizing (SEV-2). Two MINOR test/report determinism gaps are also
documented below.

## Target integrity

- Requested commit: `48c7d50ff5ad27faad2e5788113330659a27d9dd`
- HEAD during audit: `d76e1ff6f6a57f482c4e8f93fd99322d42985ec1`
- `48c7d50:scripts/portfolio_risk_admission.py` blob:
  `9ec4e5687a8d154ac0d7e6552c7b805c80c12dcd`
- HEAD and worktree script blob:
  `9ec4e5687a8d154ac0d7e6552c7b805c80c12dcd`
- `git diff --exit-code 48c7d50 -- scripts/portfolio_risk_admission.py`
  returned exit 0.

The audited worktree script is therefore byte-identical to the requested commit,
despite HEAD having advanced for unrelated EA files.

## Claim-by-claim result

| # | Result | Evidence |
|---|---|---|
| 1. Strict full/reduced budget comparisons | **VERIFIED** | Boundary probes: `25.0000000005` and `25.000000001` were never `ADMIT_FULL`; with broker minimum `0.0001`, both became conservative `ADMIT_REDUCED` at factor `0.9999`, implying respectively `24.997500000499947` and `24.9975000009999` against budget `25.0`. Exact `25.0` was `ADMIT_FULL` with implied DD `25.0`. A deterministic 100,000-case correlated fuzz (`seed=17009`) produced 97,903 grants (50,004 full, 47,899 reduced), with **0 strict breaches** and **0 breaches greater than 1e-12**; maximum observed `implied_dd - budget` among grants was `0.0`. |
| 2. DEMO/REAL_CENT type conflict fails closed and is order-independent | **PARTIAL** | Both row orders produced `type_conflict=true`, `budget_pct=null`, the same explicit conflict note, and `CANNOT_RUN` for every pending magic. However, `accounts[].type` remains first-row-dependent (`"DEMO"` in one order, `"REAL_CENT"` in the other), so the full report is not literally order-independent. See F3. |
| 3. Cage 27 kills required practical mutations | **VERIFIED** | Restoring `+ 1e-9` at the full-size comparison, removing the `build_report()` conflict short-circuit, and disabling conflict detection each made cage 27 fail and the suite end `SOME FAILED`. See the mutation table below. |
| 4. No new defects; edge/regression behavior remains correct | **NOT VERIFIED** | Budget/floor/broker-min/basket/parser/P&L and other requested regressions passed, but mixed blank/DEMO types remain order-dependent and can flip `REPORT_ONLY` to `ADMIT_FULL` on row reorder (F1). |

## Findings

### F1 — SEV-2: blank plus DEMO type metadata can flip sizing solely by row order

**Location:** `scripts/portfolio_risk_admission.py:702`, `:708-716`, and the
budget use at `:900`.

`acct_type` is taken from `rows[0]`, while `types_seen` discards blank strings:

```python
acct_type = rows[0]["type"] if rows else ""
types_seen = sorted({r["type"] for r in rows if r["type"]})
```

Concrete reproducer:

- Same account `111`
- `C` and `D`, both `PENDING_ATTACH`
- DD95 map `{"C": 10.0, "D": 10.0}`
- Empty correlation map
- Same two rows, reordered

Observed output slices:

```text
rows: C(type=""), D(type="DEMO")
type=""  type_conflict=false  budget_pct=null
C=REPORT_ONLY  D=REPORT_ONLY

rows: D(type="DEMO"), C(type="")
type="DEMO"  type_conflict=false  budget_pct=25.0
D=ADMIT_FULL  C=ADMIT_FULL
```

Thus incomplete metadata neither triggers the new fail-closed conflict path nor
selects the sole known type deterministically. Inventory order decides whether
sizing is issued. This is a correctness/safety risk; the blank row's real type is
unknown, so the probe does not establish a numerically wrong portfolio DD and is
classified SEV-2 rather than SEV-1.

The same root is not canonicalized consistently: `["DEMO", "demo"]` is treated as
a conflict and returns `CANNOT_RUN`, even though `budget_pct_for_account_type()`
normalizes case at line 458. Either blank/nonblank must fail closed, or the sole
nonblank normalized type must be selected independently of row order.

### F2 — MINOR: the strict reduced-output comparison is not mutation-locked

**Location:** production guard at `scripts/portfolio_risk_admission.py:670`;
cage assertion at `:1267-1272`; cage 27 at `:1666-1696`.

Concrete mutation:

```diff
- if dd_at_emit > budget_pct:
+ if dd_at_emit > budget_pct + 1e-9:
```

Observed output:

```text
occurrences 1
ok True
ALL PASS
```

The current production comparison itself is strict and passed the independent
fuzz. This finding is a cage-quality gap only: cage 27 exercises the full-size
boundary but not a reduced-output boundary, while cage 11 explicitly permits
`implied <= budget + 1e-9`. A future restoration of the old tolerance on the
second comparison would survive all 27 cages.

### F3 — MINOR: conflicted summary `type` remains first-row-dependent

**Location:** `scripts/portfolio_risk_admission.py:702` and `:732`.

Concrete reproducer: the requested `C(type=DEMO)` plus
`D(type=REAL_CENT)` conflict, in both orders.

Observed:

```text
C,D order: accounts[0].type = "DEMO"
D,C order: accounts[0].type = "REAL_CENT"
```

In both orders, `type_conflict=true`, `budget_pct=null`, the conflict note is
identical, and both candidates are `CANNOT_RUN`, so there is no sizing safety
breach. The residual `type` field nevertheless prevents the full account summary
from being order-independent and can mislead a downstream reader.

## Standards / cage-quality evidence

All mutations were executed only in memory or in OS temporary copies; the repo
script and git index were not changed.

| Mutation | Observed cage result |
|---|---|
| Full check restored to `full_dd <= budget_pct + 1e-9` | Cage 27 failed: candidate `25.0000000005` was wrongly `ADMIT_FULL`; suite ended `SOME FAILED`. |
| Conflict short-circuit changed to `if False and acct_summary.get("type_conflict")` | Cage 27 failed: conflicted candidate became `REPORT_ONLY` instead of `CANNOT_RUN`; suite ended `SOME FAILED`. |
| Conflict detection changed to `type_conflict = False` | Cage 27 failed: account received DEMO budget `25.0` with `type_conflict=false`; suite ended `SOME FAILED`. |
| Reduced guard restored to `dd_at_emit > budget_pct + 1e-9` | **All cages passed**; this is finding F2, outside the three explicit mutations required by claim 3. |

## Spec / behavioral evidence

### Strict boundary probes

Direct calls used `broker_min_lot_factor=0.0001` so the over-budget cases exercised
the emitted reduced path rather than stopping at unknown broker minimum:

```text
25.0000000005 -> ADMIT_REDUCED, factor=0.9999,
                 portfolio_dd_est_after=24.997500000499947
25.000000001  -> ADMIT_REDUCED, factor=0.9999,
                 portfolio_dd_est_after=24.9975000009999
25.0           -> ADMIT_FULL, factor=1.0,
                 portfolio_dd_est_after=25.0
```

### Strict-breach fuzz

Design: `seed=17009`, 100,000 cases, 0-5 existing risk units, finite positive
log-uniform DD95 values, equicorrelation in `[0,1)`, and budgets at exact full DD,
one ULP below/above it, random between existing/full DD, or within `1e-10`
relative of full DD. Every emitted factor was independently re-applied and
recomputed through `portfolio_dd_est()`.

```text
FUZZ seed=17009 cases=100000 grants=97903 full=50004 reduced=47899 defer=2 refused=2095
STRICT_BREACHES=0 BREACHES_GT_1E-12=0
WORST_DD_MINUS_BUDGET=0.0
```

The refusals were conservative fail-closed outcomes, principally one-ULP
below-boundary cases whose solved factor rounded back to `1.0`; none emitted a
grant.

### Requested type-conflict repro

For `C(type=DEMO)` plus `D(type=REAL_CENT)`, both orders produced:

```text
type_conflict=true
budget_pct=null
budget_note="CONFLICTING account-type metadata in DEPLOYMENTS.csv
             (DEMO vs REAL_CENT) -- data error, no budget assigned,
             fix the inventory before sizing anything"
C.status=CANNOT_RUN
D.status=CANNOT_RUN
```

The remaining first-row-dependent display field is recorded as F3.

## Regression evidence

The complete built-in cage suite passed 27/27. Independent spot checks (not merely
calling the cages) also passed 15 checks:

- UNKNOWN ACTIVE basket-leg seeding in both pending-row orders;
- sequential composition and provenance;
- near-equal basket collapse order independence;
- exact-budget `DEFER_ESCALATE`;
- missing correlation fallback `1.0`;
- broker-minimum `None` fail-closed behavior;
- floor-not-round (`0.05006` solved scale emitted as `0.05`);
- REAL_CENT-only `REPORT_ONLY`;
- custom `--expectations` path metadata;
- parser rejection of zero, infinity, NaN, text, and blank DD95;
- NTFS hard-link refusal;
- non-finite sum-of-squares refusal;
- basket/magic namespace refusal;
- pearson range protection.

The remaining requested cases are directly exercised by passing cages:

- basket collapse/identity/namespace/lower-bound: cages 7, 12-14, 19, 25;
- P&L poisoning at parse, magic, and overflow levels: cages 8, 16, 20;
- admission input validation and non-finite arithmetic: cages 17, 21, 23;
- sequential/pure-pending/conflicting siblings: cages 22, 24, 25;
- parser, missing-correlation, REAL_CENT, broker minimum, floor path:
  cages 3-6, 10-11, 17;
- exact-budget defer, hard-link refusal, expectations metadata, pearson clamp:
  cages 18, 23-26 plus the independent probes above.

No additional SEV-1/SEV-2 production finding was found in the budget, basket,
correlation, parser, P&L, numeric-validation, output-safety, or broker-minimum
paths beyond F1.

## Exact selftest output

Command:

```text
D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest
```

Exit code: `0`

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
