VERDICT: FAIL

# ORDER-174 round-3 independent QA audit

Target: `scripts/portfolio_risk_admission.py` at commit
`49ed60b5fde709f39b5eb685c55f1e6e565d166b`.

Commit/blob identity was pinned before testing:

```text
HEAD                                      49ed60b5fde709f39b5eb685c55f1e6e565d166b
49ed60b^{commit}                          49ed60b5fde709f39b5eb685c55f1e6e565d166b
49ed60b:scripts/portfolio_risk_admission.py
                                          20ec9363928cc6b0c094ecea1ba874d8fc39c310
git hash-object scripts/portfolio_risk_admission.py
                                          20ec9363928cc6b0c094ecea1ba874d8fc39c310
```

The working-tree script therefore matched the requested commit exactly. Tests used only
in-memory inputs and files under Python temporary directories. No repository input, `.set`,
portfolio CSV, or git-index entry was modified.

## Claim-by-claim result

| Claim | Status | Evidence |
|---|---|---|
| 1. A non-13-cell row carrying `out` poisons the whole series | VERIFIED | Good four-month segment plus a 12-cell `out` row excluded magic A. The surfaced reason was `deals-shaped row with 12 cells ... series poisoned, WHOLE magic excluded`; A/B was absent, effective correlation was `1.0`, and two DD95=10 inputs produced portfolio DD `20.0`. Header/non-`out` rows remain skipped. |
| 2. Deal timestamps fully match the stated grammar/ranges | NOT VERIFIED | The two round-2 strings (`2026.013...` and `2026.01THIS_IS_NOT_A_DATE`) now poison correctly. However `[ T]` accepts an unrequested `T` separator and captured seconds are never range-checked. Four malformed rows can become four observations and a measured correlation; see F2. |
| 3. Only well-formed comma/space thousands grouping is accepted | NOT VERIFIED | `1,0` now poisons and the three advertised valid forms parse correctly. However the regex accepts a different separator for each group: `3,000 000` becomes `3000000.0`; see F1. |
| 4. Per-magic cage assertions, four requested mutations, unified wording | PARTIAL | Per-magic directory assertion works, and all four exact requested mutations (including restoration of the old year-month prefix block) fail a cage. However, a narrower removal of only the timestamp end anchor still exits `0` with all 30 cages passing. The no-realized-deals exclusion also lacks `WHOLE magic excluded`; see F3/F4. |
| 5. No new defects and no regressions | NOT VERIFIED | The requested regression probes, current-inventory run, ORDER-170 spot checks, and genuine-report parsing all passed, but F1/F2 are new wrong-number paths. |

## Findings — Standards axis

The independent standards review found two correctness-affecting breaches of the parser's
own documented strictness/corruption contract:

1. `_MONEY_GROUPED_RE` permits mixed thousands separators despite the local contract saying
   only well-formed grouping is accepted (F1).
2. The timestamp remains a partially hand-validated string: the grammar is broader than
   documented and its captured seconds are not validated (F2). This is also a possible
   Primitive Obsession smell (judgment call): a real datetime parser/value would centralize
   validity and avoid partial range checks.

No separate AGENTS.md/CLAUDE.md/README.md violation was found. Authorship follows the
money-adjacent rule: Claude wrote the change and Codex performed the blind audit.

## Findings — Spec axis

The independent spec review found that the exact timestamp grammar and malformed-grouping
requirements are still partial (F1/F2), and that the promised unified exclusion wording
does not cover the no-realized-deals path (F3). No other scope creep was found.

## Detailed findings

### F1 — SEV-1 — Mixed thousands separators are accepted as a fabricated finite P&L

**Location:** `scripts/portfolio_risk_admission.py:323-339`

The repeated character class `[ ,]` chooses a separator independently for every thousands
group. It therefore accepts mixed grouping, contrary to “commas/spaces ONLY as well-formed
thousands grouping” and “other malformed groupings are CORRUPT.”

Concrete reproducing input:

```text
MIX report, four valid 13-cell out rows:
  timestamps: 2026.01.15 10:00:00 through 2026.04.15 10:00:00
  profit cells: ["1", "2", "3,000 000", "4"]

ASC report, same months:
  profit cells: ["1", "2", "3", "4"]

commission=swap=0 for every row
```

Observed output:

```json
{
  "loaded": ["ASC", "MIX"],
  "MIX_months": {
    "2026-01": 1.0,
    "2026-02": 2.0,
    "2026-03": 3000000.0,
    "2026-04": 4.0
  },
  "skipped": [],
  "raw_corr": 0.2581996930331314,
  "effective_corr": 0.2581996930331314,
  "portfolio_dd_for_10_and_10": 15.86316294459041
}
```

Direct helper probe:

```text
_parse_money_cell("1,234 567") -> 1234567.0
```

Expected fail-soft behavior is whole-magic exclusion, correlation fallback `1.0`, and
portfolio DD `20.0`. The observed `15.86316294459041` is a wrong risk number that can alter
sizing/admission.

### F2 — SEV-1 — The “strict full” timestamp accepts malformed timestamps as observations

**Location:** `scripts/portfolio_risk_admission.py:326, 389-403`

Two independent gaps remain:

- `[ T]` accepts `T`, while the required grammar is `YYYY.MM.DD HH:MM[:SS]`.
- `_DEAL_TS_RE` captures seconds, but the range check validates only
  month/day/hour/minute. `:99` is accepted.

Concrete reproducing input A:

```text
T report, four valid 13-cell out rows:
  2026.01.15T10:00:00 profit 1
  2026.02.15T10:00:00 profit 2
  2026.03.15T10:00:00 profit 3
  2026.04.15T10:00:00 profit 4

B report, same months with normal space timestamps:
  profits [1, -1, -1, 1]
```

Observed output:

```json
{
  "loaded": ["B", "T"],
  "T_months": {
    "2026-01": 1.0,
    "2026-02": 2.0,
    "2026-03": 3.0,
    "2026-04": 4.0
  },
  "skipped_for_T": [],
  "raw_corr_T_B": 0.0,
  "effective_corr_T_B": 0.0,
  "portfolio_dd_for_10_and_10": 14.142135623730951
}
```

Concrete reproducing input B: replace the four T timestamps with
`2026.01.15 10:00:99` through `2026.04.15 10:00:99`. Observed output is the same:
magic `SEC` loads all four months, `raw_corr=0.0`, and portfolio DD is
`14.142135623730951`.

Both inputs are outside a valid MT5 timestamp but count toward `MIN_SHARED_MONTHS`.
Expected behavior is exclusion/default `1.0`/DD `20.0`; the observed result is a wrong
risk number.

### F3 — MINOR — The no-realized-deals exclusion lacks the promised unified wording

**Location:** `scripts/portfolio_risk_admission.py:467-470`

Concrete reproducing input:

```text
map.csv:
  magic E -> empty.htm

empty.htm:
  readable HTML table with no realized 13-cell out row
```

Observed output:

```text
E: no realized 'out' deals parsed from mapped report(s)
```

The magic is excluded safely, so this is not a wrong-number defect. It does not satisfy
the claim that every exclusion reason contains `WHOLE magic excluded`.

### F4 — MINOR — Cage 30 does not lock the full-match end anchor

**Location:** `scripts/portfolio_risk_admission.py:326, 2151-2200`

Concrete mutation in a temporary copy:

```diff
- _DEAL_TS_RE = re.compile(r"...(?::(\d{2}))?$")
+ _DEAL_TS_RE = re.compile(r"...(?::(\d{2}))?")
```

Observed output:

```text
exit=0
FAIL lines: []
...
PASS  30_malformed_report_rows_poison
ALL PASS
```

This mutation changes full matching to prefix matching (a valid timestamp followed by
trailing junk is accepted), yet no cage fails. Production still contains the end anchor,
so this is a mutation-coverage defect rather than a current wrong-number path. The exact
requested restoration of the old year-month-only parsing block *was* killed:

```text
exit=1
FAIL  30_malformed_report_rows_poison
loaded magics became ["M", "X", "Y"]
```

The other requested mutations were also killed:

```text
is_file -> exists:
  exit=1
  FAIL  29_backtest_map_fail_soft_hardening
  E's own reason became "unreadable mapped report subdir", so its per-magic
  "not a regular file" assertion failed.

remove deals-shape poison:
  exit=1
  FAIL  30_malformed_report_rows_poison
  loaded magics became ["A", "M"].

blind comma/space deletion:
  exit=1
  FAIL  30_malformed_report_rows_poison
  loaded magics became ["M", "N"].
```

## Verification evidence

### Round-2 F1-F3 repros

```json
{
  "12_cell_out_row": {
    "loaded": ["B"],
    "skipped": [
      "A: deals-shaped row with 12 cells (expected 13) in a_bad12.htm -- report structurally malformed -- series poisoned, WHOLE magic excluded, pairs default to 1.0"
    ],
    "effective_corr_A_B": 1.0,
    "portfolio_dd_for_10_and_10": 20.0
  },
  "prefix_timestamps": {
    "loaded": ["B"],
    "X_reason": "unparseable deal timestamp '2026.013.15 10:00:00' ... WHOLE magic excluded ...",
    "Z_reason": "unparseable deal timestamp '2026.01THIS_IS_NOT_A_DATE' ... WHOLE magic excluded ...",
    "effective_corr_X_B": 1.0,
    "effective_corr_Z_B": 1.0
  },
  "malformed_money": {
    "loaded": ["B"],
    "N_reason": "corrupt money cell in n.htm -- series poisoned, WHOLE magic excluded, pairs default to 1.0",
    "effective_corr_N_B": 1.0,
    "portfolio_dd_for_10_and_10": 20.0
  },
  "valid_money_helpers": {
    "1,234.5": 1234.5,
    "1 234": 1234.0,
    "-2,000": -2000.0
  }
}
```

### Regression probes

- Overlap refusal: April present in both mapped segments returned `monthly=None` with
  `month(s) ['2026-04'] appear in more than one mapped report`.
- Non-overlap control: January-August concatenated to 8 distinct months with `reason=None`.
- Directory path: magic E was excluded fail-soft with its own `not a regular file` and
  `WHOLE magic excluded` reason.
- Locked regular file: `_extract_backtest_monthly()` returned `monthly=None` and
  `unreadable mapped report locked.htm: [Errno 13] Permission denied`; it did not crash.
- Cage 28 passed: backtest provenance, live-over-backtest precedence, missing-map
  fail-soft behavior, and provenance counts remained intact.
- ORDER-170 spot checks: `get_corr({}, "A", "B") == 1.0`; two DD95=10 inputs with missing
  correlation produced `20.0`.

Actual CLI output-protection probes all exited `1`, created no alternate output, and left
the map/report SHA-256 unchanged:

```text
REFUSED: --out-md=...\map.csv would overwrite the backtest corr map it reads
REFUSED: --out-json=...\map.csv would overwrite the backtest corr map it reads
REFUSED: --out-md=...\report.htm would overwrite a mapped backtest report it reads (...)
REFUSED: --out-json=...\report.htm would overwrite a mapped backtest report it reads (...)
```

### Genuine MT5 report sanity check

The 12 most recent `.htm` reports were sampled. All parsed with `reason=None`. Examples:

```text
PVM4_HOLD.htm  -> 6 months,  2026-01 through 2026-06
PVM4_BWD.htm   -> 35 months, 2020-01 through 2022-12
PVM4_MAIN.htm  -> 36 months, 2023-01 through 2025-12
```

Thus the strict changes do not reject the sampled genuine MT5 output.

### Current-inventory CLI with the empty map template

The repository map contains only:

```csv
magic,report_path,notes
```

The CLI was run with current inventory inputs and temporary output paths:

```json
{
  "exit": 0,
  "measured_pairs": 0,
  "measured_pairs_live": 0,
  "measured_pairs_backtest": 0,
  "default_1_0_pairs": 946,
  "backtest_map_found": true,
  "outputs_exist": [true, true],
  "inputs_unchanged": true
}
```

This is the required `0/N measured, N default` behavior (`N=946`).

## Exact required self-test output

Command:

```text
D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest
```

Exact stdout (`exit=0`, stderr empty):

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
