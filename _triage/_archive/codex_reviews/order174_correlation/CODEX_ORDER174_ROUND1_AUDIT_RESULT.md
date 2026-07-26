# ORDER-174 round-1 independent QA audit

VERDICT: FAIL

Audited `scripts/portfolio_risk_admission.py` at commit
`4bf85cf82f523b3851fe926ce2049474bbca368a`.

Blob verification:

- commit `4bf85cf` blob: `dc598d2e5632873c2373a2704018b746ed3c74d8`
- HEAD during audit: `060d8f90a3cc742234892d03daf2630b8431f7b1`
- HEAD blob: `dc598d2e5632873c2373a2704018b746ed3c74d8`
- worktree blob: `dc598d2e5632873c2373a2704018b746ed3c74d8`

Therefore HEAD and the worktree still contained the exact audited script blob from
`4bf85cf`. All behavioral fixtures were real temporary `.htm`/CSV files created under
a `TemporaryDirectory`; no portfolio CSV, `.set`, source file, or git-index entry was
modified.

## Claim-by-claim result

| # | Result | Evidence |
|---|---|---|
| 1 | **NOT VERIFIED** | The normal parser path is correct: 13-cell `out` rows, `profit + commission + swap`, UTF-8 and BOM UTF-16, and four poison spellings (`nan`, `inf`, `1e309`, `text`) were exercised. UTF fixtures produced `{"2026-01": 9.5, "2026-02": 19.0}` and all four corrupt fixtures poisoned the whole series. However, syntactically matching but impossible months `2026.13` through `2026.16` were accepted as four observations and produced a measured correlation and wrong portfolio number (F2). |
| 2 | **VERIFIED** | Four-month backtest fixture produced source `backtest`; four-month live fixture for the same pair overwrote it with source `live`; a third absent magic returned `get_corr(...)=1.0`; three shared months produced no pair. `get_corr` and `portfolio_dd_est` were untouched by the commit diff. |
| 3 | **NOT VERIFIED** | A missing map file cleanly disabled the feature. Missing, corrupt, and empty mapped reports each surfaced a reason in JSON and Markdown when they were the only report for a magic. But a magic with one present report and one missing mapped report was still admitted from the partial series and measured (F1). A mapped directory also crashed the run instead of failing soft (F5). |
| 4 | **VERIFIED** | A 3-magic fixture reported 3 possible, 1 measured backtest, 0 live, and 2 default; Markdown contained `| A~B | -1.0 | **backtest** |`. Against the current inventory with an empty map and empty live directory, the CLI emitted exactly `0/903 pairs measured`, `0 live`, `0 backtest`, and `903` default, with `backtest_map_found=true`. A missing map emitted `backtest_map_found=false` and the Markdown “Backtest corr map not found” notice. |
| 5 | **VERIFIED** | Selftest passed 28/28 with exit code 0. Independent probes also confirmed strict budget (`25.0` fits, `25.000000000000004` does not) and canonical basket DD95 (conflicting sibling values 10 and 30 collapsed to one `basket::BASK` unit at 30; portfolio DD estimate 30, not 40). No ORDER-170 engine regression was found. |
| 6 | **NOT VERIFIED** | A 300,000-digit nested-tag money cell poisoned only its own magic and did not affect a good magic. However, impossible months changed a risk number (F2), a directory path crashed ingestion (F5), and output arguments can overwrite the new map or any mapped report after reading it (F4). |

## Findings

### F1 — SEV-1 — Missing one mapped segment still permits a partial magic series and a wrong risk number

**Location:** `scripts/portfolio_risk_admission.py:380` and
`scripts/portfolio_risk_admission.py:385`

The loader records a missing row and continues. If another mapped path for the same
magic exists, that remaining subset is parsed and published as the magic's complete
series. This contradicts the documented/claimed magic-level fail-soft behavior.

Concrete reproducer:

```text
map.csv
magic,report_path,notes
A,a_is.htm,IS
A,missing_oos.htm,OOS missing
B,b.htm,

a_is.htm: four 13-cell out rows, 2026.01..2026.04, P&L [1, 2, 3, 4]
b.htm:    four 13-cell out rows, 2026.01..2026.04, P&L [1, -1, -1, 1]
commission=swap=0 in every row
```

Observed output:

```json
{
  "loaded_magics": ["A", "B"],
  "skipped": ["A: report not found: ...\\missing_oos.htm"],
  "pair_measured": true,
  "corr": 0.0,
  "portfolio_dd_est_for_10_and_10": 14.142135623730951,
  "portfolio_dd_if_A_were_skipped_and_pair_defaulted": 20.0
}
```

The warning is surfaced, but the incomplete magic still backs a measured pair and
lowers the risk number. An empty one of several mapped segments has the same structural
problem: `_extract_backtest_monthly(paths)` only rejects the magic when the aggregate
across all existing paths is empty.

### F2 — SEV-1 — Invalid calendar months count toward `MIN_SHARED_MONTHS` and lower the default

**Location:** `scripts/portfolio_risk_admission.py:348`

The timestamp regex accepts any two digits as a month and performs no range validation.
Four impossible months therefore satisfy the four-shared-month measurement gate.

Concrete reproducer:

```text
A report: months [2026.13, 2026.14, 2026.15, 2026.16], P&L [1, 2, 3, 4]
B report: months [2026.13, 2026.14, 2026.15, 2026.16], P&L [1, -1, -1, 1]
Both reports use 13-cell out rows; commission=swap=0.
```

Observed output:

```json
{
  "months_A": ["2026-13", "2026-14", "2026-15", "2026-16"],
  "skipped": [],
  "source": "backtest",
  "corr": 0.0,
  "portfolio_dd_est_for_10_and_10": 14.142135623730951,
  "portfolio_dd_with_absent_pair_default_1_0": 20.0
}
```

This is a direct wrong-number path from hostile/corrupt report data. The conservative
fallback is bypassed despite there being zero valid calendar months.

### F3 — SEV-1 — Overlapping report rows double-count a month and bias correlation

**Location:** `scripts/portfolio_risk_admission.py:357` and
`scripts/portfolio_risk_admission.py:384`

Multiple rows per magic intentionally concatenate windows, but there is no overlap or
duplicate-deal detection. An overlapping boundary month is summed twice. The bias is
input-dependent; the reproducer below biases correlation downward and therefore lowers
the portfolio risk estimate.

Concrete reproducer:

```text
A IS:  Jan..Apr P&L [1, 2, 3, 4]
A OOS: Apr..Jul P&L [4, 3, 2, 1]   # April overlaps/duplicates
B:     Jan..Jul P&L [1, 2, 3, 4, 3, 2, 1]
```

Without the duplicate, A and B are identical and correlation is 1.0. Observed:

```json
{
  "A_monthly": {
    "2026-01": 1.0,
    "2026-02": 2.0,
    "2026-03": 3.0,
    "2026-04": 8.0,
    "2026-05": 3.0,
    "2026-06": 2.0,
    "2026-07": 1.0
  },
  "observed_corr": 0.8877760302855439,
  "correct_deduplicated_corr": 1.0,
  "observed_portfolio_dd_for_10_and_10": 19.4307798622986,
  "correct_portfolio_dd": 20.0
}
```

The map needs either a non-overlap invariant that is validated, or deal-level
deduplication/overlap refusal. Silently adding overlapping monthly totals is unsafe.

### F4 — SEV-2 — Output paths can overwrite the new map and mapped report inputs

**Location:** `scripts/portfolio_risk_admission.py:2069` and
`scripts/portfolio_risk_admission.py:2121`

The protected output-path set contains deployments and expectations, but not
`args.backtest_map` or the report paths read from that map. The program reads these
inputs and then can overwrite them successfully.

Concrete map-alias command:

```text
python portfolio_risk_admission.py ... --backtest-map map_alias.csv \
  --out-md map_alias.csv --out-json out.json
```

Observed:

```json
{
  "exit": 0,
  "before_sha256": "12ebd07ab6ae04f5d0c2ad6c56c09a2c953e2ea3a3af828fc95e6abf2af8178b",
  "after_sha256": "cc66a78a29bb8779e9fb5f286d74284b74dbe82924f5cad73239b8e79cdbe37c",
  "after_prefix": "# ORDER-154 -- Portfolio Risk Admission:"
}
```

The same probe with `--out-md report_alias.htm`, where `report_alias.htm` was a mapped
report, also exited 0 and replaced the report with Markdown:

```json
{
  "before_sha256": "289313a4c5bd04ef8b3205e829b78f929bb8dee37bf30df8a49b078bb1c3e9f3",
  "after_sha256": "cc66a78a29bb8779e9fb5f286d74284b74dbe82924f5cad73239b8e79cdbe37c",
  "after_prefix": "# ORDER-154 -- Portfolio Risk Admission:"
}
```

Only temporary files were destroyed in these probes.

### F5 — SEV-2 — An existing non-file mapped path crashes the run

**Location:** `scripts/portfolio_risk_admission.py:326` and
`scripts/portfolio_risk_admission.py:381`

The loader tests only `exists()`. A directory passes that test and reaches unguarded
`Path.read_bytes()`.

Concrete reproducer:

```text
magic,report_path,notes
D,C:\Users\patip\AppData\Local\Temp\<fixture-directory>,directory path
```

Observed output on Windows:

```json
{
  "crashed": true,
  "exception": "PermissionError",
  "message": "[Errno 13] Permission denied: 'C:\\Users\\patip\\AppData\\Local\\Temp\\<fixture-directory>'"
}
```

No `backtest_skipped` result or final report was produced. Other unreadable existing
paths have the same unhandled-I/O structure.

## Verified parser and reporting evidence

- UTF-8 report: profit 10, commission -1, swap 0.5 produced January P&L 9.5.
- BOM UTF-16 report: profit 20, commission -2, swap 1 produced February P&L 19.0.
- An otherwise valid `in` row with profit 999 was ignored.
- Each of `nan`, `inf`, `1e309`, and `text` in a money cell returned a poisoned whole
  series (`None`), never zero or a partial series.
- A 300,000-digit money cell wrapped in nested `<span>` tags was classified
  corrupt/non-finite; its magic was skipped while an unrelated good magic loaded.
- Backtest fixture source was `backtest`; adding a measured live series for the same
  pair changed the source to `live`.
- Three shared months did not produce a pair; four shared months did.
- The skip-surfacing CLI fixture contained one missing report, one poisoned report, and
  one empty report. All three exact reasons appeared in both JSON
  `corr_coverage.backtest_skipped` and Markdown.
- Its coverage arithmetic was consistent: 5 active magics = 10 possible pairs, 1
  measured backtest pair, 0 live pairs, 9 default pairs.
- Current-inventory empty-map probe headline:

```text
## Correlation coverage (ORDER-174): **0/903 pairs measured** (0 live, 0 backtest) -- **903 pairs on the conservative default 1.0**
```

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
PASS  28_backtest_corr_provenance
ALL PASS
```
