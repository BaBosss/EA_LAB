# ORDER-170 round-5 independent QA

VERDICT: FAIL

One SEV-1 sizing/admission defect remains. The three round-4 regressions named in
the prompt are fixed for their canonical fixtures, but the new sequential basket
path is unsafe when sibling DD95 values conflict.

## Scope and provenance

- Audited `scripts/portfolio_risk_admission.py` from the current working tree.
- `HEAD` during the audit: `456e283463a6a3c0e0f180a4c8f62642a15bb6e2`.
- `HEAD:scripts/portfolio_risk_admission.py` blob:
  `0fefc46cb6d556adc14e680025e71a2336821a9b`.
- `7c694dd0:scripts/portfolio_risk_admission.py` blob:
  `0fefc46cb6d556adc14e680025e71a2336821a9b`.
- Therefore the audited script is byte-identical to the requested round-5 blob.
- No repository input, `.set`, `portfolio/*.csv`, or git-index entry was changed.
  All probes and mutated script copies were created in temporary directories.

## Claim-by-claim result

| # | Result | Evidence |
|---|---|---|
| 1 | **NOT VERIFIED** | The canonical A=10 ACTIVE + C,D=10 PENDING fixture is fixed: C=`ADMIT_FULL`, D=`DEFER_ESCALATE`, D has `assumes_admitted_first=["C"]`, and the Markdown header states the sequential semantics. A 5,000-case additive-correlation randomized probe produced 6,256 grants and zero composed-budget breaches. Equal-DD95 pending basket siblings also produce first=`ADMIT_FULL`, second=`CANNOT_RUN`. However, conflicting-DD95 siblings produce an unsafe order-dependent `ADMIT_FULL`; see F1. Non-normal later records also omit the claimed explicit assumption list; see F2. |
| 2 | **VERIFIED** | A real deals CSV containing `[1e308,-1e308,1e308,-1e308]` against `[1,2,3,4]` produced an empty correlation matrix, direct `pearson()` returned `None`, and `get_corr()` returned conservative `1.0`. A 100,000-vector finite-float fuzz probe found zero exceptions and zero non-finite returns. `compute_corr_matrix()` does not store a non-finite value. A separate finite-underflow robustness issue is recorded as F3 because it can store an out-of-range finite value, not because this narrow claim failed. |
| 3 | **VERIFIED** | `admit_candidate("C",1.0,{"A":25.0},{},25.0)` returned `DEFER_ESCALATE` with `lot_factor=None` for broker minimum `None` and `0.01`, with the “no positive lot factor fits” message. Existing `25.000001` took the pre-existing-over-budget branch. |
| 4 | **PARTIAL** | All three requested mutations are killed by cages 22-24: reverting carry-forward fails cage 22; restoring `** 2` fails cage 23 with `OverflowError`; restoring the `x<=0` raise fails cage 24. However, cage 22 uses equal sibling DD95 values and checks only the second sibling's status, so it misses F1 and does not require `assumes_admitted_first` on the `CANNOT_RUN` branch. |

## Findings

### F1 — SEV-1: conflicting PENDING basket siblings use the first raw DD95 instead of the basket's conservative maximum

Relevant code:

- `scripts/portfolio_risk_admission.py:171-203` says conflicting sibling DD95
  values are one risk unit and conservatively keeps the larger value.
- `scripts/portfolio_risk_admission.py:716-724` applies that collapse to the
  account summary.
- `scripts/portfolio_risk_admission.py:799-822` assigns the basket risk-unit key
  but passes the current row's raw `dd95_map[m]` to `admit_candidate()`.
- `scripts/portfolio_risk_admission.py:834-837` carries that same raw value
  forward.
- `scripts/portfolio_risk_admission.py:807-818` then prevents the later sibling
  from being evaluated.

Concrete reproducer:

```python
deployments = [
    {"account":"111","account_name":"X","type":"DEMO","ea_name":"EAE",
     "magic":"E","symbol":"X","status":"PENDING_ATTACH"},
    {"account":"111","account_name":"X","type":"DEMO","ea_name":"EAF",
     "magic":"F","symbol":"X","status":"PENDING_ATTACH"},
]
dd95 = {"E": 10.0, "F": 30.0}
basket_of = {"E": "BY", "F": "BY"}
report = build_report(deployments, dd95, {}, basket_of=basket_of)
```

Observed account summary:

```json
{
  "portfolio_dd_est": 30.0,
  "headroom_pct": -5.0,
  "over_budget": true,
  "basket_folded": [
    "F: basket 'basket::BY' has conflicting DD95 values (10.0 vs 30.0) -- kept the larger"
  ]
}
```

Observed admission decisions:

```json
[
  {
    "magic": "E",
    "risk_unit": "basket::BY",
    "status": "ADMIT_FULL",
    "lot_factor": 1.0,
    "portfolio_dd_est_after": 10.0
  },
  {
    "magic": "F",
    "status": "CANNOT_RUN"
  }
]
```

The Markdown therefore shows `portfolio_DD_est = 30.00%` and OVER BUDGET while
also showing E as `ADMIT_FULL`.

The result is inventory-order dependent. Reversing the two rows makes F=30
`DEFER_ESCALATE`, then E=10 `ADMIT_FULL`, because a deferred candidate is not
carried forward. Both orders can ultimately admit the 10% row even though the
same basket's canonical conservative risk unit is 30%.

This is a wrong admission/sizing decision. The sequential workflow must obtain
one canonical DD95 per basket (the same conservative maximum used by
`collapse_basket_risk_units()`) before evaluating any sibling, rather than let
the first row choose the basket's risk.

### F2 — MINOR: later CANNOT_RUN and REFUSED records omit `assumes_admitted_first`

Relevant code:

- `scripts/portfolio_risk_admission.py:828-833` decorates only normal decisions
  returned by `admit_candidate()`.
- `scripts/portfolio_risk_admission.py:807-818` appends basket
  `CANNOT_RUN` directly.
- `scripts/portfolio_risk_admission.py:839-843` appends `REFUSED` directly.

Concrete reproducer 1: E and F are PENDING siblings of basket BY with equal
DD95=10. E is `ADMIT_FULL`; F is `CANNOT_RUN`.

Observed F record:

```json
{
  "account": "111",
  "ea_name": "EAF",
  "magic": "F",
  "status": "CANNOT_RUN",
  "message": "candidate's risk unit 'basket::BY' is already counted in the existing portfolio (ACTIVE basket leg, or a pending sibling admitted earlier in this report) -- independent admission is ill-defined, escalate to user"
}
```

It has no `assumes_admitted_first:["E"]`.

Concrete reproducer 2: A ACTIVE DD95=10, C PENDING DD95=5, D PENDING DD95=10,
with correlation `{frozenset(("A","D")): -2.0}`. C is admitted first; D is then
refused by the guarded formula evaluated against A+C.

Observed D record:

```json
{
  "account": "111",
  "ea_name": "EAD",
  "magic": "D",
  "status": "REFUSED",
  "message": "bounds violated: max(DD95)=10.000000 portfolio_DD_est=5.000000 sum(DD95)=25.000000 -- corr matrix invalid (parse error / not PSD). Refusing to emit a risk number."
}
```

It also omits `assumes_admitted_first:["C"]`. The global Markdown header states
the sequential rule, so this does not itself grant an unsafe size, but the JSON
record does not meet the explicit per-decision provenance claim.

### F3 — MINOR: finite underflow can produce and store a correlation outside [-1,1]

Relevant code:

- `scripts/portfolio_risk_admission.py:312-334` returns the raw finite Pearson
  quotient without checking its mathematical range.
- `scripts/portfolio_risk_admission.py:357-363` stores any finite result.

Concrete real-CSV monthly P&L input:

```text
magic 111: [0, -1e-200, -1e-200, -1e-320, 1e-160]
magic 222: [-1e-320, -5e-324, -5e-324, -5e-324, 1e-100]
```

Observed:

```text
corr_matrix {frozenset({'111', '222'}): 1.0000673314140571}
pearson 1.0000673314140571
portfolio RAISED RiskAdmissionError bounds violated: max(DD95)=10.000000 portfolio_DD_est=20.000337 sum(DD95)=20.000000 -- corr matrix invalid (parse error / not PSD). Refusing to emit a risk number.
```

This is fail-closed before sizing, so it is not a SEV-1 wrong-number path. It can
false-refuse a report for extreme finite inputs. Treat a materially out-of-range
Pearson result as unmeasurable; optionally clamp only machine-epsilon-sized
overshoots.

## Round-5 mutation checks

Temporary copies of the script were mutated; the repository script was not
changed.

| Mutation | Result |
|---|---|
| Replace sequential `existing_units` input with original `active_units` | exit 1; cage 22 failed because D became `ADMIT_FULL`; `SOME FAILED` |
| Restore `(x-mx) ** 2` / `(y-my) ** 2` | exit 1; cage 23 failed with `unexpected OverflowError: (34, 'Result too large')`; `SOME FAILED` |
| Restore raising when solved `x <= 0` | exit 1; cage 24 failed with the injected `RiskAdmissionError`; `SOME FAILED` |

## Regression checks

The full 24-test suite passed and the following prior behaviors were also
checked against their production-path cages or direct temporary fixtures:

- single-PENDING basket candidate identity: cage 19;
- basket collapse in summary and admission: cages 7 and 12;
- basket/magic namespace separation: cage 13;
- emitted reduced lower-bound refusal: cage 14;
- nan/inf/1e309 and aggregation-overflow poisoning: cages 16 and 20;
- admission input validation: cage 17;
- non-finite sum-of-squares refusal and 1e308 candidate domain error: cage 21;
- NTFS hard-link output refusal: cage 18;
- custom `--expectations` metadata: temporary CLI run reported the exact custom
  path with `expectations_csv_found=true`;
- DD95 parser rejection of zero/negative/inf/nan: cage 5;
- missing correlation fallback to 1.0: cage 3;
- REAL_CENT `REPORT_ONLY`: cage 4 plus a two-PENDING direct report probe;
- unknown broker minimum defers when reduction is needed: cage 10;
- emitted factor is floored and rechecked: cages 11 and 17.

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
ALL PASS
```
