# ORDER-174 round-2 independent QA audit

VERDICT: FAIL

Audited `scripts/portfolio_risk_admission.py` at commit
`f8fcf544c59a41441e18b544264b2ace79aa7737`.

## Provenance and test isolation

- `HEAD` during the audit: `f8fcf544c59a41441e18b544264b2ace79aa7737`
- commit blob `f8fcf54:scripts/portfolio_risk_admission.py`:
  `ff5fb1bfe895eb0cad8cb377d1321d59ce027965`
- worktree script blob:
  `ff5fb1bfe895eb0cad8cb377d1321d59ce027965`
- Therefore the tested worktree script was byte-identical to the requested commit blob.
- All behavioral fixtures, mutated script copies, and CLI outputs were created under
  temporary directories. No repo input, `.set`, portfolio CSV, source file, or git-index
  entry was modified.

The exact round-1 F1-F5 repros are fixed. However, three additional malformed-report
inputs still fabricate observations and can displace the conservative correlation
default of `1.0`; all three are SEV-1 wrong-number paths under this prompt's robustness
requirement.

## Claim-by-claim result

| # | Result | Evidence |
|---|---|---|
| 1 | **PARTIAL** | The exact `A -> [good.htm, missing.htm]`, `B -> [b.htm]` repro now loads only `B`; `A` produces a `WHOLE magic excluded` reason, contributes no pair, and `get_corr(A,B)` is `1.0`. But a second mapped report that is present/readable yet contains an `out`-shaped 12-cell row is silently ignored; the good segment is then published as the complete `A` series with no reason (F1 below). An actually unreadable regular file is excluded safely, but its reason says `series poisoned`, not the claimed `WHOLE magic excluded` wording (F5). |
| 2 | **PARTIAL** | Literal `2026.13` is poisoned with `impossible calendar month` and contributes no observation. But the prefix-only regex accepts impossible/odd month tokens such as `2026.013...` as month `01`, so malformed timestamps can still reach `MIN_SHARED_MONTHS` and replace default `1.0` (F2). |
| 3 | **VERIFIED** | `d1` Jan-Apr plus `d2` Apr-Jul excludes the magic and names overlap `['2026-04']`. Jan-Apr plus May-Aug loads one correctly concatenated eight-month series, Jan through Aug. |
| 4 | **VERIFIED** | Actual CLI probes for both output flags and both input classes returned exit `1`, emitted `REFUSED`, and left SHA-256 unchanged: `--out-md map.csv`, `--out-json map.csv`, `--out-md mapped.htm`, and `--out-json mapped.htm`. Fresh Markdown and JSON destinations both succeeded with exit `0`. |
| 5 | **VERIFIED** | A mapped directory was excluded with `missing or not a regular file`; another magic still loaded. A regular report held open with Windows sharing disabled reached `is_file() == True`, failed at read time, was excluded with an `unreadable mapped report ... Permission denied` reason, and the CLI completed with exit `0`, writing both temp outputs; the other magic remained usable. |
| 6 | **NOT VERIFIED** | Removing the month-range check, overlap check, or map/report output protection each failed cage 29. Replacing `rp.is_file()` with `rp.exists()` nevertheless returned exit `0` and `ALL PASS` for all 29 cages (F4). |
| 7 | **NOT VERIFIED** | Cage 28 semantics pass; live overrides backtest, missing-map disables backtest, and provenance reporting remains intact. ORDER-170 spot checks also pass: missing pair `=1.0`, two DD95 values of 10 produce portfolio DD `20.0`, strict budget equality passes while `25.0000000001` fails, and conflicting basket siblings 10/30 collapse to one value of 30. The pinned `f8fcf54` inventory snapshot produces exactly `0/903 measured`, `903 default`. The live shared worktree currently produces `0/946`, because it contains an additional concurrent `PENDING_ATTACH` deployment row not present in the pinned commit; this is input drift, not a script regression. The overall no-new-defects claim fails because of F1-F3. |

## Findings

### F1 — SEV-1 — A readable structurally malformed mapped report is silently dropped while the magic's other segment is published

**Location:** `scripts/portfolio_risk_admission.py:355-376` and
`scripts/portfolio_risk_admission.py:429-432`

Rows with a cell count other than 13 are silently skipped. The magic is rejected only
when the aggregate of all reports is empty. Consequently, a malformed mapped segment
can disappear while another segment supplies four months and is published as though it
were the whole history.

Concrete reproducing input:

```text
map.csv
magic,report_path,notes
A,a_good.htm,IS
A,a_degenerate.htm,OOS
B,b.htm,

a_good.htm:
  four 13-cell out rows, Jan-Apr 2026, profits [1,2,3,4]
a_degenerate.htm:
  one readable HTML row for 2026.05 with cells[4]="out" and profit=100,
  but only 12 cells (one cell missing)
b.htm:
  four 13-cell out rows, Jan-Apr 2026, profits [1,-1,-1,1]
```

Observed output:

```json
{
  "loaded": ["A", "B"],
  "A_months": {
    "2026-01": 1.0,
    "2026-02": 2.0,
    "2026-03": 3.0,
    "2026-04": 4.0
  },
  "skipped": [],
  "corr_A_B": 0.0,
  "effective_corr_A_B": 0.0,
  "portfolio_dd_for_10_and_10": 14.142135623730951
}
```

The malformed OOS row is neither used nor surfaced; the partial IS series replaces the
required fallback. Excluding `A` would leave the pair absent, so effective correlation
would be `1.0` and portfolio DD would be `20.0`.

### F2 — SEV-1 — Prefix-only timestamp parsing accepts impossible/odd month spellings as valid observations

**Location:** `scripts/portfolio_risk_admission.py:359-366`

`re.match(r"(\d{4})\.(\d{2})", cells[0])` validates only the first two month
digits. It does not require a delimiter after the month or validate the complete
timestamp. For example, the invalid month token `013` is captured as month `01`, with
the extra `3` ignored as trailing text.

Concrete reproducing input:

```text
X report timestamps:
  2026.013.15 10:00:00
  2026.023.15 10:00:00
  2026.033.15 10:00:00
  2026.043.15 10:00:00
profits [1,2,3,4]

Y report uses the same malformed month spellings,
profits [1,-1,-1,1].
```

Observed output:

```json
{
  "loaded": ["X", "Y"],
  "months_X": ["2026-01", "2026-02", "2026-03", "2026-04"],
  "skipped": [],
  "corr_X_Y": 0.0,
  "portfolio_dd_for_10_and_10": 14.142135623730951
}
```

The same behavior was reproduced with arbitrary trailing junk such as
`2026.01THIS_IS_NOT_A_DATE`. These are fabricated calendar observations. A strict
timestamp parse should poison the magic and retain effective correlation `1.0`.

### F3 — SEV-1 — Blind comma deletion turns malformed/locale-decimal money into a different finite number

**Location:** `scripts/portfolio_risk_admission.py:369` and
`scripts/portfolio_risk_admission.py:232-256`

The backtest parser removes every comma before `_num()`. This does not distinguish a
valid thousands separator from malformed grouping or a locale decimal separator.
`"1,0"` therefore becomes `10`, not corrupt and not `1.0`.

Concrete reproducing input:

```text
N report, Jan-Apr profit cells: ["1,0", "2", "3,0", "4"]
B report, Jan-Apr profit cells: ["1", "2", "3", "4"]
commission=swap=0; all rows otherwise valid 13-cell out rows.
```

Observed output:

```json
{
  "parsed_N": [10.0, 2.0, 30.0, 4.0],
  "skipped": [],
  "corr_N_B": 0.10091233516771889,
  "portfolio_dd_for_10_and_10": 14.838546661770613
}
```

If comma is decimal punctuation, both series are `[1,2,3,4]` and correlation is `1.0`;
if the spelling is not supported, the prompt requires exclusion and the conservative
default `1.0`. Either interpretation yields portfolio DD `20.0`, not `14.84`.

### F4 — MINOR — Cage 29 does not kill the advertised `is_file() -> exists()` mutation

**Location:** `scripts/portfolio_risk_admission.py:2082-2086`

Concrete mutation:

```diff
- if not rp.is_file():
+ if not rp.exists():
```

Observed self-test result:

```text
exit=0
...
PASS  29_backtest_map_fail_soft_hardening
ALL PASS
```

The remaining guarded read still keeps behavior fail-soft, so this mutation is not a
current wrong-number defect. It does falsify claim 6. Cage 29 also checks the combined
`" | ".join(skipped)` string: `E:` can come from the directory reason while the phrase
`not a regular file` comes from `A`'s missing-file reason, allowing unrelated records
to satisfy one assertion.

For comparison, the other requested mutations were killed:

```text
remove_month_range: exit=1; FAIL 29; SOME FAILED
remove_overlap_check: exit=1; FAIL 29; SOME FAILED
remove_map_report_output_protection: exit=1; FAIL 29; SOME FAILED
```

### F5 — MINOR — Unreadable regular files are excluded safely, but not with the claimed whole-magic wording

**Location:** `scripts/portfolio_risk_admission.py:350-353` and
`scripts/portfolio_risk_admission.py:425-427`

Concrete reproducing input:

```text
map.csv:
  A,locked.htm
  B,good.htm

locked.htm is a regular file held open through CreateFileW with share mode 0.
```

Observed actual CLI output:

```json
{
  "exit": 0,
  "outputs_exist": [true, true],
  "measured_pairs": 0,
  "default_pairs": 1,
  "skipped": [
    "A: unreadable mapped report locked.htm: [Errno 13] Permission denied: '...locked.htm' -- series poisoned, pairs default to 1.0"
  ]
}
```

The behavior is conservative and satisfies claim 5. The wording does not satisfy claim
1's explicit requirement for a `"WHOLE magic excluded"` reason when not all mapped
reports are readable.

## Direct evidence for the fixed round-1 cases

### F1 original missing-segment repro

```json
{
  "loaded": ["B"],
  "skipped": [
    "A: mapped path missing or not a regular file: ...missing.htm -- WHOLE magic excluded (a partial series would understate risk); its pairs fall back to the 1.0 default"
  ],
  "pair_present": false,
  "effective_corr_A_B": 1.0
}
```

### F2 literal impossible month

```json
{
  "loaded": [],
  "skipped": [
    "C: impossible calendar month '2026.13.15 10:00:00' in badmonth.htm -- report data corrupt -- series poisoned, pairs default to 1.0"
  ]
}
```

### F3 overlap and non-overlap control

```json
{
  "overlap_loaded": [],
  "overlap_reason": "D: month(s) ['2026-04'] appear in more than one mapped report -- overlapping windows double-count deals; map only non-overlapping, month-boundary-aligned reports -- series poisoned, pairs default to 1.0",
  "non_overlap_months": [
    "2026-01", "2026-02", "2026-03", "2026-04",
    "2026-05", "2026-06", "2026-07", "2026-08"
  ],
  "non_overlap_skipped": []
}
```

### F4 actual CLI output-protection probes

```text
out_md_map:
  exit=1
  REFUSED: --out-md=...\map.csv would overwrite the backtest corr map it reads
  input unchanged=true

out_json_map:
  exit=1
  REFUSED: --out-json=...\map.csv would overwrite the backtest corr map it reads
  input unchanged=true

out_md_report:
  exit=1
  REFUSED: --out-md=...\report.htm would overwrite a mapped backtest report it reads (...)
  input unchanged=true

out_json_report:
  exit=1
  REFUSED: --out-json=...\report.htm would overwrite a mapped backtest report it reads (...)
  input unchanged=true

fresh destinations:
  exit=0
  wrote ...\fresh.md
  wrote ...\fresh.json
```

### F5 directory probe

```json
{
  "loaded": ["B"],
  "skipped": [
    "E: mapped path missing or not a regular file: ...adir -- WHOLE magic excluded (a partial series would understate risk); its pairs fall back to the 1.0 default"
  ]
}
```

## ORDER-170 invariant spot checks

```json
{
  "missing_corr": 1.0,
  "portfolio_two_10_missing_corr": 20.0,
  "fits_equal_25": true,
  "fits_25_0000000001": false,
  "basket_units_from_A10_B30_same_basket_and_C5": {
    "basket::K": 30.0,
    "C": 5.0
  }
}
```

## Pinned-inventory CLI evidence

Running the exact `f8fcf54` deployment/expectations/map snapshots with the audited
script and temp output paths returned exit `0` and:

```text
## Correlation coverage (ORDER-174): **0/903 pairs measured** (0 live, 0 backtest) -- **903 pairs on the conservative default 1.0**
```

The live shared worktree had gained one concurrent active/pending magic during the
audit, so a default CLI run against that newer input correctly reported 44 unique
magics, `0/946 measured`, and `946 default`.

## Exact self-test output

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
PASS  29_backtest_map_fail_soft_hardening
ALL PASS
```
