# Boss19 P4 Regime Attribution Contract

Status: P4A FROZEN RESEARCH CONTRACT
Authority: deterministic research attribution only. It grants no strategy verdict, quality grade, sample-policy change, optimization, HOLDOUT use, runtime regime gate, risk/default change, deployment, or trading authority.

## 1. Scope, consumer, and fixed evidence identity

This contract is the direct input to the mechanical P4b timeline-build/join lane. Its only purpose is to attribute the accepted Boss19 H3 fixed-config evidence against the frozen classifier in [Boss19 P4 Regime Classifier V1](BOSS19_P4_REGIME_CLASSIFIER_V1.md).

| Evidence field | Frozen value |
|---|---|
| Family / variant | Boss19 / `19-0` AdaptiveTrendGrid V0 fixed configuration |
| Accepted H3 contract head | `47c7732048406277096c1ccc31734b4122ae7285` |
| Result-package SHA-256 | `3d62d6d358831dc3897357d3d2008e9c0f1c9211716844112f8af96f79c7eeb2` |
| Evidence shape | 36 Model-1, full-window eligible cells: 6 symbols × 3 TF × MAIN/BWD |
| Symbols | `XAUUSD`, `EURUSD`, `GBPUSD`, `AUDUSD`, `USDJPY`, `BTCUSD` |
| TF | `M15`, `H1`, `H4` |
| MAIN | `2023-01-01..2025-12-31` |
| BWD | `2020-01-01..2022-12-31` |
| HOLDOUT | `2026H1` is `UNSPENT`; excluded |
| Optimization | none; excluded |

The known H3 qualification fact is only `PASS 36/36`. This contract deliberately does not inspect or reinterpret H3 P&L/outcomes while defining regimes. P4b must reject a package whose SHA-256 differs from the row above, a run outside this matrix, a HOLDOUT row, an optimization result, or an unidentifiable raw unit.

## 2. Required ordering and immutable timeline gate

The causal sequence is mandatory:

```text
hash market inputs -> build classifier timeline -> hash/lock timeline
-> verify H3 package identity -> read units -> deterministic as-of join -> aggregate -> visuals/interpretation
```

P4b must write an immutable timeline manifest before it opens the H3 outcome/trade records. The manifest must contain:

- `classifier_id = BOSS19_P4_REGIME_CLASSIFIER_V1` and version;
- classifier-contract Git blob ID and the MRIS source/config hashes named by the classifier contract;
- raw market input manifest SHA-256;
- canonical CSV/Parquet serialization details, row count, first/last timestamp, and SHA-256 of the exact timeline bytes;
- per-symbol/TF coverage and counts of full/partial/unknown classifications; and
- creation command/version and UTC creation timestamp.

The join input must name that exact `timeline_sha256`. Rebuilding after looking at results, overwriting the timeline, or joining against an unpinned file is `BLOCKED(TIMELINE_NOT_IMMUTABLY_PINNED)`. Different classifier/timeline hashes are different evidence strata and may not be mixed in an aggregate.

## 3. Attribution unit and as-of join

Boss19 is a grid/multi-position system, so order tickets alone may exaggerate independence. P4b must create both of the following levels where source identity permits:

| Level | Required definition | Primary timestamp / regime label |
|---|---|---|
| `DEAL` | One unique realized closed deal/position record from the H3 raw evidence. Its key is `h3_run_id + source_deal_id`. | Durable opening timestamp (`entry_utc`), joined to the latest timeline row whose `valid_from_utc <= entry_utc < valid_to_utc`. |
| `BASKET` | One complete strategy basket/episode whose member deals carry a durable, source-emitted `basket_id`; its key is `h3_run_id + basket_id`. | First member's `entry_utc`, using the same as-of rule. |

`BASKET` is the preferred independent-opportunity reporting unit. P4b must not invent baskets from temporal proximity, order number, or P&L. If the H3 raw export lacks a durable basket ID, emit `basket_status = UNAVAILABLE_NO_SOURCE_BASKET_ID`, retain the mandatory DEAL analysis, and label all opportunity/basket interpretations unavailable rather than treating deals as independent baskets.

For either level, a missing or malformed entry timestamp, missing matching `Symbol × TF` timeline, or any unknown dimension produces an `UNKNOWN` attribution row. It remains counted as an unidentified/unknown unit and is never reassigned using close time, future state, or `NEUTRAL`. Exit timestamp/state may be retained as a descriptive secondary field, but it must not replace the entry-context primary label. Open/unclosed records are excluded from realized-P&L aggregates and reported separately.

## 4. Required P4b outputs

P4b must emit machine-readable detail plus aggregate views. All outputs carry `evidence_package_sha256`, `timeline_sha256`, `classifier_id`, classifier version, source data identity, and creation UTC.

1. `REGIME_ATTRIBUTION_DETAIL` — one row per DEAL and, where available, one row per BASKET; includes keys, run/window, entry/exit times, as-of timeline key, full regime tuple, classification status, realized P&L/exposure fields present in source, and source-record hash.
2. `REGIME_AFFINITY` — the aggregate schema below.
3. `REGIME_ATTRIBUTION_RECONCILIATION` — check-by-check PASS/FAIL/BLOCKED values, source totals, joined totals, and explanation.
4. `REGIME_ATTRIBUTION_COVERAGE` — market-timeline and unit attribution coverage, including unknown/partial macro counts.

### `REGIME_AFFINITY` schema

One row is one unambiguous aggregation cell. At minimum P4b emits rollups by `year × macro × local × vol × symbol × tf × window × attribution_unit`; it may additionally emit explicit `ALL` rollups, never mixed with a dimension value.

| Field | Meaning |
|---|---|
| `evidence_package_sha256`, `timeline_sha256`, `classifier_id`, `classifier_version` | Immutable provenance; mandatory in every row |
| `h3_run_id`, `window`, `year`, `symbol`, `tf`, `attribution_unit` | Evidence partition. `year` is UTC entry year; `ALL` only in explicit rollups. |
| `macro_state`, `local_state`, `vol_state`, `classification_status` | Exact frozen tuple; `UNKNOWN` is retained, not imputed. |
| `eligible_unit_count`, `classified_unit_count`, `unknown_unit_count`, `participation_share` | Participation and classifier coverage. `participation_share = eligible_unit_count / total eligible units in the stated run/window/unit level`. |
| `net_realized`, `gross_profit`, `gross_loss`, `profit_factor` | Realized outcome fields. `profit_factor` is `NULL` when gross loss is zero; it is never infinity. |
| `partition_realized_equity_dd`, `dd_basis` | Max drawdown of the cumulative realized P&L sequence ordered by close timestamp **within this partition**, from zero; `dd_basis = PARTITION_REALIZED_SEQUENCE`. It is not the original whole-run equity DD and is not additive. |
| `hard_kill_count`, `max_open_exposure`, `exposure_basis` | Included only when present in exact source; otherwise `NULL` / `UNAVAILABLE`. |
| `macro_coverage_min`, `macro_partial_unit_count`, `unknown_reason_counts` | Data-quality visibility; no silent full-data claim. |
| `participation_confidence` | `DESCRIPTIVE_ONLY`: `HIGH`, `MEDIUM`, `LOW`, or `UNKNOWN`, assigned from explicit coverage/span observations documented below—not a grade or kill rule. |
| `concentration_flags`, `evidence_status` | Semicolon-separated predeclared flags and `COMPLETE`, `PARTIAL`, or `BLOCKED`; never a strategy verdict. |

`participation_confidence` is descriptive and strategy-aware: P4b must record unit count, calendar span, active months/days when derivable, basket availability, and unknown share. It must not apply a universal 100-trades rule or translate this field into a grade, PASS/FAIL, or candidate decision.

## 5. Concentration and coverage flags

Flags are visibility requirements, not action rules. Calculate them separately for each `h3_run_id × window × attribution_unit` population, before any interpretation:

- `UNKNOWN_REGIME_COVERAGE_GT_10PCT` when unknown-attribution units exceed 10% of eligible units.
- `MACRO_PARTIAL_COVERAGE_PRESENT` when any joined unit has partial macro coverage.
- `SINGLE_TUPLE_PARTICIPATION_GE_50PCT` when one full `(macro, local, vol)` tuple contains at least half of classified units.
- `SINGLE_YEAR_ABS_NET_GE_50PCT` when one entry year contributes at least half of absolute net realized P&L across the population.
- `SINGLE_TUPLE_ABS_NET_GE_50PCT` under the same absolute-net definition for one full tuple.
- `BASKET_UNAVAILABLE` when source cannot supply a durable basket identity.
- `SHORT_CALENDAR_SPAN` when attributed entries cover fewer than three distinct UTC calendar years in a nominal three-year MAIN/BWD window.

If the denominator is zero, emit `NO_ELIGIBLE_UNITS`, leave percentage-based flags `UNAVAILABLE`, and do not infer a loss or a regime incompatibility. These thresholds are predeclared presentation flags; they were not fitted to H3 performance and do not alter sample, grade, BWD, production, or KINT-001 policy.

## 6. Reconciliation and fail-closed checks

P4b may publish a joined aggregate only when all applicable checks pass:

1. Package SHA-256, H3 head, run/window/symbol/TF matrix, model, and no-HOLDOUT/no-optimization assertions match Section 1.
2. Timeline manifest exists before join and the referenced timeline SHA-256 is exact; timeline rows are sorted, non-overlapping, and carry no forward-looking valid-from time.
3. Every eligible realized DEAL appears exactly once in detail as either classified or `UNKNOWN`; no duplicate `h3_run_id + source_deal_id` exists.
4. When basket IDs exist, every eligible deal belongs to exactly one basket, and each basket has exactly one first-entry timestamp.
5. For each H3 run, `classified_unit_count + unknown_unit_count = eligible_unit_count`; all rollup partitions reconcile to the detail population without double counting.
6. Realized net, gross profit, gross loss, and deal count reconcile to the exact raw H3 unit source and, where the H3 package exposes comparable total fields, to its run total. Currency comparison tolerance is `0.01` account-currency units; count tolerance is zero. A non-comparable source field is `UNAVAILABLE`, not a waived comparison.
7. `partition_realized_equity_dd` is recomputed from its stated ordered sequence; it is never summed to claim whole-run DD. Whole-run DD is preserved only as its source-defined metric.
8. MAIN/BWD, year, symbol, TF, and regime rollups use the same evidence and timeline identities. `UNKNOWN` remains a visible partition.

Any failed identity, accounting, or unique-unit check is `BLOCKED(ATTRIBUTION_RECONCILIATION_FAIL)`; P4b must not silently drop rows or publish a performance conclusion. A lack of timestamped unit evidence is `BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)`, not evidence about Boss19.

## 7. Evidence, interpretation, and staged visuals

P4b produces evidence and reproducible data views only. It must not write a regime verdict such as preferred/avoid, identify an operating envelope, or map any result to runtime action.

The following visuals are staged consumers of the immutable P4b outputs:

| Stage | Required visual when that report stage is requested | Guardrail |
|---|---|---|
| R2 mechanism/rescue | selected-cell entry timeline with macro/local/vol strips; year × regime participation/net matrix; per-tuple participation versus net/PF scatter with unknowns visible | Show the exact timeline/package hashes and unit level. No causal claim from a sparse cell. |
| R4 robustness/finalist | MAIN versus BWD regime matrix; yearly participation/PF/net by regime; entry-time regime timeline beside equity/DD; return/trade-or-basket concentration view; unknown/partial-coverage panel | Preserve BWD/MAIN and symbol/TF strata; never pool them into an unlabelled universal regime result. |

The Report Ladder's R2/R4 requirements still apply. A graph is evidence presentation, not a decision. Any interpretation must cite exact output rows, their participation/confidence/concentration fields, and the frozen timeline hash; it may say only what the evidence supports.

## 8. Explicit exclusions and handoff result

This contract does not redesign Boss19, consume HOLDOUT, change a candidate/grade/sample/BWD production policy, resolve KINT-001, activate MacroGate, or create `ENABLE`, `REDUCE`, `BLOCK_NEW`, sizing, risk, or deployment mappings.

P4b is ready to proceed deterministically once it has the exact H3 package and timestamped unit source, constructs and hash-pins the classifier timeline first, and satisfies every reconciliation check. If one of those prerequisites is absent, it returns the named `BLOCKED(...)` status while leaving H3 evidence and all policies unchanged.
