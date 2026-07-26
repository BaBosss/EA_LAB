# ORDER-170 round-4 independent QA report

VERDICT: FAIL

Target inspected: `scripts/portfolio_risk_admission.py` as stored at commit `cdfadd28`
(blob `8a947c816619a684eafbab7ab80f7351e5abc0ac`).

The repository HEAD had advanced to `1ccf6054` when this audit ran. The target script is
byte-identical between `cdfadd28` and `1ccf6054`, so the probes below exercised the requested
round-4 revision. No repository input, `.set`, portfolio CSV, or git-index entry was modified.

## Claim-by-claim result

| Claim | Result | Evidence |
|---|---|---|
| 1. A basketed PENDING candidate uses the same `basket::<id>` risk-unit identity in summary and admission | VERIFIED | Independent reproduction produced summary `portfolio_dd_est=30.0`, `over_budget=True`, budget `25.0`; admission produced `DEFER_ESCALATE`, real `"magic": "C"`, and `"risk_unit": "basket::BX"`. Replacing the production admission argument with raw magic in-memory made cage 19 fail with the old `ADMIT_FULL` result at `22.360679774997898`. |
| 2. Overflowed monthly aggregation poisons the magic; non-finite Pearson values never enter the matrix | PARTIAL | Two `1e308` deals/month poisoned magic `111`; the matrix stayed `{}` and fallback correlation was `1.0`. `nan`, `inf`, and `1e309` cells also poisoned end-to-end. However, finite monthly observations can make `pearson()` raise raw `OverflowError`, aborting matrix ingestion instead of safely omitting/poisoning the pair (finding F2). |
| 3. `portfolio_dd_est()` refuses non-finite sum-of-squares | VERIFIED | `portfolio_dd_est({"A": 1e308, "B": 1e308}, {})` raised `RiskAdmissionError: non-finite sum-of-squares (inf) ...`. |
| 4. Extreme finite candidate raises the documented refusal type and finite-checks the solved factor | VERIFIED | `admit_candidate("C", 1e308, {}, {}, 1.0, broker_min_lot_factor=0.01)` raised `RiskAdmissionError: quadratic coefficients overflow ...`, not `OverflowError`. The solved factor has an explicit finite check before flooring at lines 552-599. |
| 5. 21-test suite covers the round-3 basketed-candidate defect and detects the raw-magic mutation | VERIFIED | The exact self-test run reported 21 PASS results. An in-memory mutation changing the admission identity from `cand_key` back to raw `m` made cage 19 fail: `admission approved full size while the summary says OVER BUDGET`, with `ADMIT_FULL` and `portfolio_dd_est_after=22.360679774997898`. |

## Findings

### F1 — SEV-1: multiple PENDING candidates are each admitted without the other PENDING risk units

Locations: `scripts/portfolio_risk_admission.py:719-730`, `:739-750`, `:781-783`

The account summary includes every `ACTIVE` and `PENDING_ATTACH` row, but each admission decision
builds its existing portfolio from `ACTIVE` rows only. With multiple pending candidates, the report
can therefore show an over-budget summary beside multiple independently usable `ADMIT_FULL`
decisions. Nothing in the decision dict says those approvals are mutually exclusive.

Concrete reproducing input:

```python
deployments = [
    row("111", "A", "ACTIVE"),
    row("111", "C", "PENDING_ATTACH"),
    row("111", "D", "PENDING_ATTACH"),
]
dd95 = {"A": 10.0, "C": 10.0, "D": 10.0}
corr = {}  # missing pairs conservatively default to 1.0
build_report(deployments, dd95, corr)
```

Observed output:

```text
MULTI_PENDING_SUMMARY {'portfolio_dd_est': 30.0, 'over_budget': True, 'budget_pct': 25.0}
MULTI_PENDING_DECISIONS [('C', 'ADMIT_FULL', 20.0), ('D', 'ADMIT_FULL', 20.0)]
```

The two full-size approvals compose to 30%, above the 25% budget. This is a wrong/unsafe sizing
decision surface, not merely a display mismatch. Cage 19 only contains one pending candidate, so it
cannot detect this composition failure.

### F2 — SEV-2: finite P&L observations can crash Pearson ingestion with raw `OverflowError`

Locations: `scripts/portfolio_risk_admission.py:306-317`, `:338-345`

The round-4 filter rejects a returned non-finite correlation, but `pearson()` squares centered
observations using `** 2`. Python raises `OverflowError` for sufficiently large finite operands
before a value is returned, and `compute_corr_matrix()` does not catch it. Cage 20 tests monthly
addition overflow but does not exercise the Pearson-overflow path claimed by its docstring.

Concrete reproducing input: four valid monthly rows for magic `X` with P&L
`[1e308, -1e308, 1e308, -1e308]`, and four valid rows for `Y` with P&L `[1, 2, 3, 4]`.
Every CSV cell and every monthly aggregate is finite; neither magic is marked corrupted.

Observed output:

```text
PEARSON_OVERFLOW_PRE {'X': {'2026-01': 1e+308, '2026-02': -1e+308,
'2026-03': 1e+308, '2026-04': -1e+308}, 'Y': {'2026-01': 1.0,
'2026-02': 2.0, '2026-03': 3.0, '2026-04': 4.0}} set()
PEARSON_OVERFLOW_EXCEPTION OverflowError (34, 'Result too large')
```

No `nan`/`inf` is stored, but the advertised best-effort ingestion path aborts rather than failing
closed to a missing pair and conservative correlation `1.0`.

### F3 — SEV-2: an existing portfolio exactly at budget is misclassified as invalid/REFUSED

Locations: `scripts/portfolio_risk_admission.py:504-515`, `:544-561`,
`build_report()` exception mapping at `:790-794`

The pre-existing-over-budget branch uses `existing_dd > budget_pct`, not `>=`. When existing risk
equals the budget and correlations are conservatively additive, the only mathematical fitting
factor is zero. The solver correctly obtains `x=0`, but the code labels this a broken correlation
matrix and raises. This is a valid matrix and should be `DEFER_ESCALATE` because no positive lot can
fit; with an unknown broker minimum it must also follow the documented fail-closed DEFER behavior.

Concrete reproducing input:

```python
admit_candidate(
    "C", 1.0, {"A": 25.0}, {}, 25.0,
    broker_min_lot_factor=None,
)
```

Observed output:

```text
EXACT_BUDGET None EXCEPTION RiskAdmissionError
solved lot_factor <= 0 for C -- corr matrix invalid
```

The same call with `broker_min_lot_factor=0.01` raises the same exception. Through `build_report()`
the observed decision is:

```text
{'account': '111', 'magic': 'C', 'ea_name': 'C', 'status': 'REFUSED',
 'message': 'solved lot_factor <= 0 for C -- corr matrix invalid'}
```

This is a correctness and contract-classification failure; it does not emit a wrong number.

## Exact round-4 counterexample evidence

```text
CLAIM1_SUMMARY {'portfolio_dd_est': 30.0, 'over_budget': True, 'budget_pct': 25.0}
CLAIM1_DECISION {'magic': 'C', 'status': 'DEFER_ESCALATE', 'lot_factor': None,
'required_lot_factor': 0.5, 'broker_min_lot_factor': None, 'budget_pct': 25.0,
'message': 'a reduced lot is required to fit the budget, but broker_min_lot_factor
(broker_min_lot / locked_set_lot) was not supplied, so it cannot be verified as
placeable -- defer attach, escalate to user', 'risk_unit': 'basket::BX',
'account': '111', 'ea_name': 'C'}
```

Mutation result:

```text
MUTATION_CAGE19 AssertionError admission approved full size while the summary says
OVER BUDGET: {'magic': 'C', 'status': 'ADMIT_FULL', 'lot_factor': 1.0,
'portfolio_dd_est_after': 22.360679774997898, 'budget_pct': 25.0,
'message': 'fits at locked-set lot (lot_factor 1.0)', 'risk_unit': 'basket::BX',
'account': '111', 'ea_name': 'EA'}
```

## Regression checks

| Behavior | Result | Observed evidence |
|---|---|---|
| Basket collapse in summary and admission (round-3 fixture) | PASS | Self-test cages 7 and 12 passed. |
| Basket namespace separate from raw magic | PASS | `{'BASKET_X': 20.0, 'basket::BASKET_X': 10.0}` |
| Emitted-reduced lower-bound refusal | PASS | Round-2 input raised `RiskAdmissionError: bounds violated ... portfolio_DD_est=9.999719 ...`. |
| `nan`/`inf`/`1e309` P&L poisoning end-to-end | PASS | Each token produced `corrupt={'111'}`, `corr={}`, fallback `1.0`. |
| Admission rejects infinite candidate | PASS | `RiskAdmissionError` |
| Broker minimum `0`, `nan`, `1.5`, `-0.1` | PASS | Every input raised `RiskAdmissionError`. |
| NTFS hard-link output refusal | PASS | Existing alias with two links raised `SystemExit: REFUSED ... has 2 hard links ...`. |
| Coverage reflects `--expectations` path | PASS | Custom existing temp CSV produced `expectations_csv_found=True` and its exact custom path. |
| Parser rejects DD95 `0`, negative, `inf`, `nan` | PASS | Each one produced `{}`. |
| Missing correlation defaults to `1.0` | PASS | `get_corr({}, "A", "B") == 1.0`; DD95 4+6 produced `10.0`. |
| REAL_CENT/report-only path | PASS | Budget `None` produced `REPORT_ONLY`, `lot_factor=None`. |
| Broker minimum `None` when a positive reduced factor exists | PASS | Existing 20 + candidate 20, budget 21 produced `DEFER_ESCALATE`, required factor `0.05`. F3 documents the exact-budget zero-factor counterexample. |
| Floor, not round-up | PASS | Candidate 30, budget 10.001 emitted factor `0.3333`, DD `9.998999999999999`. |
| Individually finite cells overflow monthly aggregation | PASS | Magic `111` monthly totals became `inf`, was placed in `corrupted`, omitted from matrix, fallback `1.0`. |

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
ALL PASS
```

## Standards and maintainability axis

No hard source-code-standard violation was found in the target script. Two judgement-call smells
remain around the round-4 identity fix:

- `scripts/portfolio_risk_admission.py:779-786`: one raw string alternately represents a real magic
  and a synthetic risk unit, is passed through an API named `candidate_magic`, then the returned
  `"magic"` is overwritten. A separate `candidate_risk_unit` contract would make the distinction
  explicit.
- Basket-key construction (`f"basket::{...}"`) is repeated at lines 180, 762, and 779 instead of
  being centralized, leaving normalization sites able to drift.

Process note, not counted in this code verdict: commit `cdfadd28` carries a
`Co-Authored-By: Claude Fable 5` trailer, while the current repository rule in `AGENTS.md` requires
the Opus trailer for Claude commits.

