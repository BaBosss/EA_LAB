# ORDER-174 round-4 independent QA audit

VERDICT: PASS

No SEV-1 or SEV-2 findings were found. No MINOR findings were found.

## Scope and identity

- Audited `scripts/portfolio_risk_admission.py` at HEAD `d5320e5c987b1010f7d01eeec34ea7b1f2f41f1c`.
- Working-tree blob: `64a5db5a339149d444eac7e9586c608767586564`.
- `d5320e5:scripts/portfolio_risk_admission.py` blob: `64a5db5a339149d444eac7e9586c608767586564`.
- Therefore the executed script exactly matches the requested commit.
- Production changes are confined to the requested surfaces at
  `scripts/portfolio_risk_admission.py:323-329`, `:397-405`, and `:471-477`;
  the remaining changes are cage-30 fixtures/assertions at `:2177-2226`.

## Claim-by-claim verification

| Claim | Status | Evidence |
|---|---|---|
| 1. Exactly one consistent thousands separator; malformed grouping poisons the series | VERIFIED | Direct helper probes parsed `'1,234,567.5' -> 1234567.5`, `'1 234' -> 1234.0`, `'-2,000' -> -2000.0`, and `'1 234 567.5' -> 1234567.5`. They returned `CORRUPT` for `'3,000 000'`, `'1,234 567'`, `'1,0'`, leading separator `',123'`, trailing separator `'1,234,'`, 4-digit group `'1,2345'`, separator-before-decimal `'1,.5'`, multiple decimals `'1,234.5.6'`, doubled comma `'1,,234'`, and doubled space `'1  234'`. Each malformed value was also placed after four valid months in a mapped report: the whole `BAD` magic was absent, the pair was unmeasured, and effective fallback correlation was `1.0`. Code: `scripts/portfolio_risk_admission.py:323-342`. |
| 2. Strict timestamp: space only, seconds range, full anchor, and further malformed edges | VERIFIED | End-to-end report probes for `'2026.01.15T10:00:00'`, `'2026.01.15 10:00:99'`, and `'2026.01.15 10:00:00JUNK'` each excluded the whole `BAD` magic, left the pair unmeasured, and yielded effective fallback `1.0`. The same result held for leading junk, double space, non-zero-padded month, hour 24, minute 60, month 13, day 00, and fractional seconds. Valid `'2026.01.15 10:00'` and `'2026.01.15 10:00:00'` passed. The deliberate design case `'2026.02.31 23:59:59'` also passed. Code: `scripts/portfolio_risk_admission.py:326-329` and `:392-405`. |
| 3. No-realized-deals exclusion says `WHOLE magic excluded` | VERIFIED | Empty genuine-shaped report produced exactly: `EMPTY: no realized 'out' deals parsed from mapped report(s) -- WHOLE magic excluded, pairs default to 1.0`. Code: `scripts/portfolio_risk_admission.py:473-477`. |
| 4. Cage 30 kills all four specified mutations | VERIFIED | In-memory source mutation, one mutation per run: removing the timestamp `$` anchor failed cage 30 with survivor `J`; restoring `[ T]` failed with survivor `T`; removing `second > 59` failed with survivor `S`; restoring per-group `[ ,]` failed with survivor `MIX`. Every source replacement matched exactly once. No repo file was changed. Cage: `scripts/portfolio_risk_admission.py:2159-2226`. |
| 5. No new defect/regression; genuine reports, cages, prior behaviors, ORDER-170 invariants, and current inventory | VERIFIED | Exact self-test: 30/30 cages passed. Explicit calls to cages 28/29/30 passed. Four newest genuine MT5 reports (all UTF-16; all 4,784 `.htm` reports present are UTF-16) parsed with `reason=None`, and their monthly dictionaries were byte-for-value identical to the parent revision: `PVM4_HOLD.htm` (6 months), `PVM4_BWD.htm` (35), `PVM4_MAIN.htm` (36), `PVC_sl1p5_tp3p5_BWD.htm` (34). Concrete regressions: overlapping February returned `monthly=None`; directory map target was fail-soft and excluded the whole magic; synthetic `PermissionError` returned an unreadable-report reason; 12-cell `out` row poisoned; prefix timestamp `2026.013.15 10:00:00` poisoned. Actual CLI output-protection probe exited 1, emitted `REFUSED`, preserved the protected input SHA-256, and created no second output. ORDER-170 spot checks: two 10% sibling legs collapsed to one `basket::BK` 10% unit; absent correlation for 10%+20% produced conservative 30%; DD95 `0`, negative, `nan`, and `inf` were all refused. Current-inventory CLI with the checked-in empty map exited 0 and reported 946 possible pairs, 0 measured (0 live, 0 backtest), and 946 default-1.0 pairs. |

## Detailed observed outputs

### Malformed money end-to-end

Every input below produced the same conservative outcome:
`survivors=['GOOD']`, `measured=False`, `effective_corr=1.0`, with
`corrupt money cell ... series poisoned, WHOLE magic excluded, pairs default to 1.0`.

```text
'3,000 000'
'1,234 567'
'1,0'
',123'
'1,234,'
'1,2345'
'1,.5'
'1,234.5.6'
'1,,234'
'1  234'
```

### Malformed timestamp end-to-end

Every input below produced `survivors=['GOOD']`, `measured=False`,
`effective_corr=1.0`, and an explicit poisoned-whole-magic reason.

```text
'2026.01.15T10:00:00'       -> unparseable deal timestamp
'2026.01.15 10:00:99'       -> impossible calendar month/date
'2026.01.15 10:00:00JUNK'   -> unparseable deal timestamp
'JUNK2026.01.15 10:00:00'   -> unparseable deal timestamp
'2026.01.15  10:00:00'      -> unparseable deal timestamp
'2026.1.15 10:00:00'        -> unparseable deal timestamp
'2026.01.15 24:00:00'       -> impossible calendar month/date
'2026.01.15 10:60:00'       -> impossible calendar month/date
'2026.13.15 10:00:00'       -> impossible calendar month/date
'2026.01.00 10:00:00'       -> impossible calendar month/date
'2026.01.15 10:00:00.123'   -> unparseable deal timestamp
```

### Regression probes

```text
CAGE_28=PASS
CAGE_29=PASS
CAGE_30=PASS
OVERLAP monthly=None reason=month(s) ['2026-02'] appear in more than one mapped report -- overlapping windows double-count deals; map only non-overlapping, month-boundary-aligned reports
UNREADABLE monthly=None reason=unreadable mapped report a.htm: synthetic access denied
DEAL_SHAPE (None, 'deals-shaped row with 12 cells (expected 13) in shape.htm -- report structurally malformed')
PREFIX_TS (None, "unparseable deal timestamp '2026.013.15 10:00:00' in prefix.htm -- report data corrupt")
ORDER170_BASKET units={'basket::BK': 10.0} dd=10.0
ORDER170_MISSING_CORR_ADDITIVE 30.0
```

Actual CLI protection probe:

```text
exit=1
stderr='REFUSED: --out-md=<temp>\DEPLOYMENTS.csv would overwrite the deployments inventory it reads'
input_sha_unchanged=True; out_json_exists=False
```

Current-inventory actual CLI run:

```json
{"backtest_map_found": true, "backtest_skipped": [], "default_1_0_pairs": 946, "measured_pairs": 0, "measured_pairs_backtest": 0, "measured_pairs_live": 0, "possible_pairs_active_or_pending": 946}
```

## Findings

None. There is no severity/file:line/reproducer block because no SEV-1, SEV-2, or
MINOR defect was reproduced. The documented-standards axis and the audit-spec axis
were also reviewed independently; both produced zero findings.

## Exact `--selftest` output

Command:

```text
D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest
```

Exact output:

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
PASS  28_backtest_corr_provenance
PASS  29_backtest_map_fail_soft_hardening
PASS  30_malformed_report_rows_poison
ALL PASS
```
