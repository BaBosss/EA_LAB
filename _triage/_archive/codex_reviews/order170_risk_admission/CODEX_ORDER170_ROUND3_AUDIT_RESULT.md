# ORDER-170 Round-3 Independent QA Audit

VERDICT: FAIL

Target: `D:\EA_LAB\scripts\portfolio_risk_admission.py`  
Inspected commit/HEAD: `d3ae4224ddfb547644f3dc874d5ce9e3427c3a07`

Audit method: source inspection plus direct probes using
`D:\EA_LAB\tools\python312\python.exe`. All probe artifacts were created under
temporary directories. No repository source, `.set`, portfolio CSV, or git index was
modified.

The prescribed claim-1 fixture now passes, as do most round-3 fixes. However, the
broader summary/admission consistency claim still fails for a pending candidate that
itself has a basket ID. That path can emit an incorrect `ADMIT_FULL` sizing decision.

## Claim-by-claim result

| # | Status | Evidence |
|---|---|---|
| 1 | **NOT VERIFIED** | The prescribed L1+L2/BX + C fixture passes: summary `20.0`, admission `ADMIT_FULL` at `20.0`. A basketed pending candidate still uses inconsistent identities, however: summary uses `basket::BX`, admission uses raw magic `C`. Reproducer below yields summary `30.0`/OVER BUDGET but admission `ADMIT_FULL` at `22.360679774997898`. |
| 2 | **VERIFIED** | `{"BASKET_X":20,"LEG":10}`, with `LEG -> basket_id BASKET_X`, produces two units: raw standalone key `BASKET_X` and `basket::BASKET_X`, total `30.0` under missing-correlation default. Standalone keys remain raw; `get_corr()` resolves an explicit `S1/S2=0.25`, producing estimate `8.0` for DD95 4 and 6. |
| 3 | **VERIFIED** | The exact round-2 counterexample raises `RiskAdmissionError`: emitted point would be `9.999719`, below `max(DD95)=10.0`. Existing, full-size, and emitted reduced DD estimates are routed through `portfolio_dd_est()`. |
| 4 | **VERIFIED** | Conflicting basket values 10/12 render in Markdown as `basket fold: L2: basket 'basket::BX' has conflicting DD95 values (10.0 vs 12.0) -- kept the larger`. |
| 5 | **PARTIAL** | `_num("nan")`, `"inf"`, `"-inf"`, and `"1e309"` all return `CORRUPT`. A real deals CSV containing `profit=nan` poisons that magic, excludes its pair, leaves the matrix finite/empty, and `get_corr()` falls back to `1.0`. A separate finite-value overflow path can still insert `nan` into the matrix; see SEV-2 finding 2. |
| 6 | **VERIFIED** | Non-finite/bool candidate DD95, non-finite budget, and broker minimum `0`, non-finite, negative, or greater than 1 all raise `RiskAdmissionError`. Both specified round-2 inputs raise. |
| 7 | **VERIFIED** | On NTFS, a `.txt` hard link to a protected temp file is refused because it has two links; the protected content remains byte-identical. A fresh report path is allowed. Direct protected inputs and `.set` destinations are also refused. |
| 8 | **NOT VERIFIED** | Removing the formula input guard kills cage 15; bypassing active-basket collapse kills cage 12. Nevertheless, the actual SEV-1 basketed-candidate identity defect below survives all 18 tests. Cage 12 uses a standalone pending candidate with an empty correlation matrix, and cage 13 tests only the collapse helper. |
| 9 | **VERIFIED** | Running `main()` with a temp custom expectations path writes coverage metadata with that exact supplied path and `expectations_csv_found=true`, not the default path. |

## Findings

### SEV-1 — A basketed pending candidate uses a different correlation identity in summary and admission

File: `scripts/portfolio_risk_admission.py:729-744`

`summarize_account()` collapses the candidate to the namespaced risk-unit key
`basket::BX`. In `build_report()`, the admission call still passes the candidate's raw
magic `C`. Consequently, the same measured raw-magic correlation is ignored by the
summary (safe fallback `1.0`) but used by admission. The two number-emitting paths can
therefore disagree and admission can approve a lot that the summary says exceeds the
budget.

Concrete reproducing input:

```python
deployments = [
    _mk_row("111", "A", "ACTIVE"),
    _mk_row("111", "C", "PENDING_ATTACH"),
]
dd95 = {"A": 20.0, "C": 10.0}
basket_of = {"C": "BX"}
corr = {frozenset(("A", "C")): 0.0}

build_report(deployments, dd95, corr, basket_of=basket_of)
```

Observed output:

```text
account summary portfolio_dd_est = 30.0
account summary over_budget      = True
admission status                 = ADMIT_FULL
admission portfolio_dd_est_after = 22.360679774997898
budget_pct                       = 25.0
```

The Markdown likewise displays `portfolio_DD_est = 30.00%`, `OVER BUDGET`, and
`ADMIT_FULL` in the same report. This is a wrong sizing decision, not merely a display
difference.

### SEV-2 — Finite deal cells can overflow aggregation and insert `nan` into the correlation matrix

File: `scripts/portfolio_risk_admission.py:287-335`

The new `_num()` check rejects individually non-finite cells, but the monthly sum and
Pearson result are not checked for finiteness. Multiple individually finite values can
overflow during aggregation.

Concrete reproducing input: a real-format temp deals CSV with four months; magic `A`
has two realized rows of `profit=1e308` in each month, while magic `B` has one row with
profits 1, 2, 3, and 4.

Observed output:

```text
monthly["A"] = {
  "2026-01": inf, "2026-02": inf, "2026-03": inf, "2026-04": inf
}
corrupted = set()
corr[frozenset(("A", "B"))] = nan
all(math.isfinite(v) for v in corr.values()) = False
```

Downstream sizing refuses the non-finite result, so this did not produce a wrong lot in
the probe. It does violate the fail-closed ingestion contract: corrupt data should
poison the magic and make the pair fall back to `1.0`, never enter the matrix.

### SEV-2 — The 18-test suite misses the remaining production-path SEV-1

File: `scripts/portfolio_risk_admission.py:1100-1141`,
`scripts/portfolio_risk_admission.py:1259-1276`

The exact self-test reports all 18 tests passing while SEV-1 finding 1 remains
reproducible. The two relevant fixtures do not compose candidate basket namespacing
with a measured raw-magic correlation:

- cage 12 has basketed active legs, but its pending candidate is standalone and the
  correlation matrix is empty;
- cage 13 tests namespace separation only inside
  `collapse_basket_risk_units()`.

Mutation evidence is otherwise positive:

```text
MUTATION_FORMULA_GUARD: KILLED AssertionError
  portfolio_dd_est accepted invalid DD95 {'A': inf}

MUTATION_ADMISSION_COLLAPSE: KILLED AssertionError
  admission path did not collapse baskets: ... DEFER_ESCALATE ...
```

Claim 8 is still not satisfied because a directly relevant production-path defect
survives the suite unchanged.

### MINOR — An extreme but finite candidate DD95 escapes the documented error type

File: `scripts/portfolio_risk_admission.py:449-450`,
`scripts/portfolio_risk_admission.py:499`

Concrete input:

```python
admit_candidate(
    "C", 1e308, {}, {}, 1.0,
    broker_min_lot_factor=0.01,
)
```

Observed output:

```text
OverflowError: (34, 'Result too large')
```

The call fails closed and the value is outside any realistic DD percentage, so this is
not a sizing error. It is a robustness/API-consistency gap: the value passes the
function's finite-positive validation, then `candidate_dd95 ** 2` raises a raw
`OverflowError` instead of `RiskAdmissionError`.

## Previously verified behavior regression check

| Behavior | Result |
|---|---|
| Parser/formula rejection of 0, negative, `inf`, and `nan` DD95 | VERIFIED |
| Missing correlation defaults to `1.0` | VERIFIED |
| REAL_CENT returns `REPORT_ONLY` with no lot factor | VERIFIED |
| Unknown broker minimum (`None`) returns `DEFER_ESCALATE` when reduction is needed | VERIFIED |
| Emitted factor is floored, not rounded up | VERIFIED: candidate 30 / budget 10.001 emits `0.3333`, DD `9.998999999999999` |
| Refusal to overwrite deployments, expectations, or `.set` paths | VERIFIED, including NTFS hard-link alias |

## Exact self-test output

Command:

```text
D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest
```

Exit code: `0`

Exact stdout:

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
ALL PASS
```
