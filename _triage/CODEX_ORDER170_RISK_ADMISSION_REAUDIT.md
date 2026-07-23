# CODEX ORDER-170 — Neutral QA re-audit of portfolio risk admission

Target: `D:\EA_LAB\scripts\portfolio_risk_admission.py`  
Current HEAD inspected: `e2cb97c426e0d2633be3ce415ccd321aab44a39a`  
Target SHA-256: `A485513231A21EE8A5107DDEF244438C4F36A22B0B38D5A07BADB051F9F2CB43`  
Fix commit reviewed: `2a5fdcc7` against original implementation commit `c6d431ff`

Audit mode: current-code inspection plus direct in-memory/temporary-directory failing inputs. No source
file, deployment inventory, expectations file, `.set`, backtest, strategy verdict, git index, or commit
was modified.

## Result

ORDER-170 is **not fully verified**. The re-audit found **3 SEV-1**, **5 SEV-2**, and **1 MINOR**
current-code findings. Most individual defensive changes work, but basket collapse is absent from the
admission path, the collapse helper has an identifier-collision undercount, and a reduced-lot result can
still be emitted while violating the mandatory drawdown bounds.

## SEV-1 — wrong risk number or wrong sizing decision

### 1. Basket collapse is not applied to the admission path

`scripts/portfolio_risk_admission.py:623-630`, `:678-695`

`summarize_account()` collapses basket siblings, but `build_report()` independently rebuilds
`active_known` by magic and calls `admit_candidate()` without basket metadata. The
`admit_candidate()` signature has no basket argument. Thus the Markdown/JSON account summary and the
admission decision can disagree on the same input.

Concrete input:

```python
deployments = [
    # same DEMO account
    ACTIVE("L1"), ACTIVE("L2"), PENDING_ATTACH("C")
]
dd95 = {"L1": 10.0, "L2": 10.0, "C": 10.0}
basket_of = {"L1": "BX", "L2": "BX"}
corr = {}  # conservative 1.0 default
```

Observed:

- account summary collapses L1/L2 and reports `portfolio_dd_est = 20.0%` including C;
- admission path counts active L1+L2 separately, treats full-size total as `30.0%`, and returns
  `DEFER_ESCALATE`, `required_lot_factor=0.5`;
- passing the correctly collapsed active units to `admit_candidate()` returns `ADMIT_FULL` with
  `portfolio_dd_est_after=20.0%`.

This is the original basket double-count defect on a second number-emitting path. Claimed fix 1 is
**NOT VERIFIED**.

### 2. Basket IDs and standalone magic IDs share one raw-string namespace

`scripts/portfolio_risk_admission.py:170-185`

`collapse_basket_risk_units()` uses either `basket_id` or `magic` directly as the same dictionary key.
A basket ID equal to an unrelated standalone magic therefore merges two independent risk units.

Concrete input:

```python
dd95 = {"BASKET_X": 20.0, "LEG": 10.0}
basket_of = {"LEG": "BASKET_X"}
```

Observed output is one unit, `{"BASKET_X": 20.0}`. With missing correlation defaulting to 1.0, the
independent standalone magic plus basket leg should contribute `30.0%`, not `20.0%`. Current repository
names happen to avoid this collision, but the parser neither enforces nor namespaces that convention.
This defect was introduced by the basket-collapse fix.

### 3. The reduced-lot path can emit a drawdown below the mandatory lower bound

`scripts/portfolio_risk_admission.py:538-565`

After flooring, the code checks only `dd_at_emit <= budget`; it does not pass the emitted, scaled
portfolio through the required `max(DD95) <= estimate <= sum(DD95)` guard. With a valid negative
correlation, flooring can move the result just below the lower bound.

Concrete input:

```python
admit_candidate(
    "C",
    20.0,
    {"A": 10.0},
    {frozenset(("A", "C")): -0.23456},
    budget_pct=10.0,
    broker_min_lot_factor=0.001,
)
```

Observed:

```text
status=ADMIT_REDUCED
lot_factor=0.2345
portfolio_dd_est_after=9.99971859604059
scaled DD95 values: A=10.0, C=4.69
required lower bound: max(A,C)=10.0
```

Calling `portfolio_dd_est({"A":10.0, "C":4.69}, corr)` on the emitted portfolio correctly raises
`RiskAdmissionError` for the bounds violation. The pre-existing and full-size endpoints both pass;
only the emitted reduced point is unguarded. Claimed fix 5 is therefore **NOT VERIFIED** even though
the specific pre-existing-portfolio bypass was repaired.

## SEV-2 — correctness risk under plausible input

### 4. Conflicting basket sibling values are hidden from the Markdown report

`scripts/portfolio_risk_admission.py:176-183`, `:625-627`, `:761-780`

The helper records a useful conflict message and JSON retains it in `basket_folded`, but
`render_markdown()` never renders those messages. For sibling values 10 and 15, JSON says
`conflicting DD95 values (10.0 vs 15.0) -- kept the larger`; the primary human-readable report only
says that one sibling was folded. The conflict is therefore not visible in every report artifact as
claimed.

### 5. Non-finite P&L spellings bypass `CORRUPT` and enter correlation arithmetic

`scripts/portfolio_risk_admission.py:201-218`, `:266-274`, `:291-315`

Ordinary unparseable text is fixed: a `BROKEN` profit cell marks the whole magic corrupted, removes all
its measured pairs, and `get_corr()` returns the conservative `1.0`. However, Python accepts `nan`,
`inf`, and overflow such as `1e309` as floats, so `_num()` does not classify them as `CORRUPT`.

End-to-end temporary CSV probe with four monthly observations and one `profit=nan` cell produced:

```text
_num("nan") = nan
corrupted = set()
corr[{A,B}] = nan
get_corr(corr, "A", "B") = nan
```

The downstream bounds check refuses rather than emitting an understated number, so this is fail-closed
at the final calculation, but it violates the intended “bad magic drops to unknown correlation”
behavior and can make the report unavailable. Claimed fix 2 is **VERIFIED** for present-but-unparseable
text, with this non-finite numeric gap.

### 6. Admission numeric inputs are not consistently validated

`scripts/portfolio_risk_admission.py:396-415`, `:458-565`

`portfolio_dd_est()` has the new finite/type guard, but `admit_candidate()` still duplicates arithmetic
and validates only `candidate_dd95 <= 0`. It does not validate finite candidate/budget values or require
a supplied broker minimum to be finite and in `(0,1]`.

Concrete observed failures:

```python
admit_candidate("C", float("inf"), {"A": 1.0}, {}, 25.0)
# DEFER_ESCALATE with required_lot_factor = nan

admit_candidate("C", 300000.0, {}, {}, 0.01, broker_min_lot_factor=0.0)
# ADMIT_REDUCED, lot_factor = 0.0, portfolio_dd_est_after = 0.0
```

The second result directly violates the documented `0 < lot_factor <= 1.0` invariant. A `NaN` broker
minimum also passes both comparisons and can permit `ADMIT_REDUCED`. The exact `None` default is
fail-closed as claimed, but malformed or incorrectly threaded supplied minima are not.

### 7. Output protection is bypassable through an NTFS hard-link alias

`scripts/portfolio_risk_admission.py:1071-1085`, `:1117-1119`

`Path.resolve()` correctly blocked absolute, relative, case-varied, traversal, and directory-junction
aliases in direct probes. It does not identify two hard-link names as the same file. A hard link with a
`.txt` suffix to a protected CSV or `.set` passes both the resolved-path equality check and the suffix
check; writing the alias truncates the protected underlying file.

A temporary NTFS probe created `set-hardlink.txt` pointing to `live-config.set`. The guard returned
ALLOWED, and writing the alias changed the `.set` contents to `OVERWRITTEN`. Existing destinations need
a same-file/file-ID check, not only lexical resolved-path equality. Claimed fix 7 is **NOT VERIFIED**.

Direct file-symlink creation was unavailable in this Windows session (`WinError 1314`), but a directory
junction (also a reparse-point path) resolved to the protected target and was refused. The checks run
before input reads and writes; a protected custom-input probe left its file byte-identical.

### 8. The 11-test suite does not mutation-protect several claimed fixes

`scripts/portfolio_risk_admission.py:941-1048`

The suite prints 11 passes, but several tests cover only helpers rather than the production paths:

- basket test 7 calls the loader/collapse helper directly; it does not call `summarize_account()` or
  `build_report()` and cannot catch the SEV-1 admission omission or identifier collision;
- corrupt-P&L test 8 checks `_num()` only; it never calls `load_monthly_pnl_by_magic()` or
  `compute_corr_matrix()`, so removal of corrupted-magic exclusion would not fail it;
- parser test 5 protects parser rejection, but no test directly exercises the second guard inside
  `portfolio_dd_est()` or legitimate integer acceptance. Replacing `portfolio_dd_est()` in memory with
  the same formula/bounds but **without the new type/finite/positive guard still left all 11 tests
  passing**;
- test 10 does protect the `None` broker-minimum fail-closed behavior;
- test 9 protects the original existing-portfolio bounds bypass, but no test checks bounds on the
  emitted reduced portfolio;
- test 11 catches the old nearest-rounding budget overflow, but no test covers flooring below the
  broker minimum or removal of the explicit post-round budget recheck;
- no self-test calls `_assert_safe_output_path()`.

Claimed fix 8 is **NOT VERIFIED**.

## MINOR

### 9. Custom expectations-path metadata still checks the default file

`scripts/portfolio_risk_admission.py:714`, `:736-743`

`build_report()` and `render_markdown()` use `EXPECTATIONS_CSV` rather than the path supplied through
`--expectations`. If the default file exists but a custom file is missing, coverage metadata says the
expectations file was found and Markdown omits the missing-file warning. This is the prior audit's MINOR
finding; ORDER-170 did not claim to fix it, and it remains present.

## Claimed-fix verification matrix

| # | Claimed fix | Status | Independent result |
|---|---|---|---|
| 1 | Basket collapse on every number path; conflicts visible | **NOT VERIFIED** | Account summary collapses, admission path does not; Markdown hides conflict details; raw-key collision can undercount. |
| 2 | Corrupt P&L sentinel and conservative fallback | **VERIFIED** | Ordinary unparseable cell poisons the magic, measured pair disappears, fallback is 1.0, and `CORRUPT` does not enter `sum(parts)`. Non-finite numeric spellings remain a SEV-2 gap. |
| 3 | Reject zero/non-finite DD95 at parser and formula | **VERIFIED** | CSV parser excludes 0, negative, `inf`, `-inf`, and `nan`; direct formula rejects those plus bool/string. Legitimate integer `5` returns `5.0`. |
| 4 | No uncertifiable reduced factor when minimum omitted | **VERIFIED** | Default is `None`; every normal reduced-lot path without a supplied minimum returns `DEFER_ESCALATE` and `lot_factor=None`. Invalid supplied minima remain a SEV-2 gap. |
| 5 | Bounds guard throughout admission | **NOT VERIFIED** | Existing/pre-over-budget figure now goes through `portfolio_dd_est()` and is guarded, but the emitted reduced result can violate the lower bound. |
| 6 | Floor factor, recheck budget, escalate below minimum | **VERIFIED** | With a valid positive minimum, 30/10.001 emits 0.3333 and DD 9.999; exact factor 0.05005 floored below minimum 0.05004 escalates. Cross-cutting reduced-result bounds defect remains SEV-1 #3. |
| 7 | Safe output paths | **NOT VERIFIED** | Requested lexical forms are blocked before writes, but an NTFS hard-link alias bypasses both protected-name and `.set` checks. |
| 8 | Self-test quality | **NOT VERIFIED** | 11/11 passes, but production-path and mutation gaps above would allow several fix regressions to pass. |

The pre-existing-over-budget branch was probed separately:

```python
admit_candidate("C", 1.0, {"A": 30.0}, {}, 25.0)
```

It returns `DEFER_ESCALATE`, `lot_factor=None`, and guarded
`existing_portfolio_dd_est=30.0`; that specific branch is verified.

## Exact requested self-test output

Command:

```text
.\tools\python312\python.exe scripts\portfolio_risk_admission.py --selftest
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
ALL PASS
```
