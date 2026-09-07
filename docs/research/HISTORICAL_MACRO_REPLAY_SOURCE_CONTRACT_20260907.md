# Historical Macro Replay Source Contract — 2026-09-07

Status: SOURCE/PROVENANCE CONTRACT ONLY / REAL DATASET NOT YET QUALIFIED
Authority: research-data qualification only; no trading, runtime, risk/default, HOLDOUT, optimization, Candidate, deployment, or policy authority.

## Purpose

Define the minimum source and timestamp contract required before EA_LAB may call a historical macro/news package point-in-time evidence. This contract feeds the existing `tools/knowledge_validation/offline_replay_validator.py`; it does not replace that validator and does not itself qualify a dataset.

## Current source decision

For U.S. macro series, use two independent source roles rather than treating one feed as authoritative for everything:

1. **Value/revision lineage:** ALFRED/FRED real-time/vintage observations.
2. **Release clock:** the originating agency's official release schedule or release page.

FRED/ALFRED vintage dates identify when values were new or revised and can reconstruct data as it existed on historical vintage dates. They do not, by themselves, prove the intraday instant at which a trader could first observe a release.## Source-specific rules

### FRED / ALFRED

- `fred/series/observations` is acceptable for point-in-time value/revision retrieval when the request pins the series, real-time/vintage parameters, output type, and response bytes.
- `fred/series/vintagedates` is acceptable for the dates on which a series changed or new values were released.
- The FRED `release/dates` endpoint is **not** accepted as an intraday `available_at_utc` authority: FRED documents that source release dates do not necessarily represent when data became available on FRED/ALFRED.
- FRED Web Services require an API key. Credential creation/use is outside this contract; no key is copied into Git, no paid fallback is assumed, and absence of an approved credential blocks ingest rather than weakening provenance.

### BLS

- BLS official release calendars are acceptable release-clock sources for BLS series.
- BLS states that calendar times are Eastern Time. Conversion to UTC must use a versioned `America/New_York` DST mapping for the historical release date, not a fixed UTC offset.

### BEA

- BEA official release schedules are acceptable release-clock candidates for BEA releases such as GDP, Personal Income and Outlays, and international trade.
- A displayed BEA clock time is not converted to UTC until the source package also binds the timezone semantics from an authoritative BEA source or equivalent source metadata. Do not infer a timezone from geography alone.## Required immutable package

Every qualified ingest must preserve raw source responses outside any model-generated transformation and bind them into one package with:

- `dataset_id` and immutable `dataset_version`;
- exact series/release identifiers and request parameters;
- source URL/endpoint identity without credentials;
- fetch/receipt timestamp as observation metadata, not historical availability evidence;
- SHA-256 of every raw response plus an aggregate source-snapshot SHA-256;
- `record_id` and distinct `revision_id` for every historical state;
- source-native value/revision identity;
- source release date/time evidence and the exact source used to derive it;
- versioned source-timezone -> UTC conversion, including historical DST rule;
- `available_at_utc` only after the release-clock evidence and timezone mapping are resolved;
- explicit coverage interval and `COMPLETE`, `COMPLETE_NO_EVENTS`, `PARTIAL`, `MISSING`, or `UNKNOWN` coverage state.

A transformed CSV/JSON alone is not source evidence. Raw bytes, derivation metadata, and hashes must remain reproducible.## `available_at_utc` rule

`available_at_utc` means the earliest source-supported instant at which that exact revision was publicly available under the package's evidence contract.

It must **not** be derived from:

- an observation period/date;
- a FRED vintage date alone;
- a source release date with no clock when intraday ordering matters;
- the time EA_LAB fetched the data;
- today's latest revision;
- a broker candle timestamp;
- an assumed fixed Eastern/UTC offset across DST boundaries.

If the precise release clock cannot be sourced, the record remains `UNKNOWN` for intraday replay and must not be silently rounded to midnight or market open.## Replay qualification boundary

The existing offline replay validator remains the deterministic selector authority. A real package must still pass its current fail-closed rules, including source-snapshot hash, complete coverage, decision-time selection, distinct revision identities, future-revision exclusion, duplicate conflict refusal, record-state handling, and versioned clock mapping.

Passing that validator means only `OFFLINE_DATA_SELECTOR_ONLY` evidence is qualified. It does **not** qualify:

- broker-server historical clock/DST mapping;
- alignment to an MT5 tester timeline;
- an EA's reaction to the selected event;
- MacroGate/NewsGuard trading policy;
- strategy performance or robustness;
- any runtime or deployment action.

Broker clock qualification and EA replay are later, separate consumers and may not be inferred from a data-package PASS.## Acceptance for the next ingest milestone

The next ingest milestone is READY only when one bounded source set has:

1. an approved credential route if the source requires one;
2. exact series/release identifiers and a finite historical interval;
3. raw response preservation and reproducible hashes;
4. source-backed release clocks for every event class in scope;
5. versioned timezone/DST conversion to UTC;
6. revision/vintage lineage sufficient to reconstruct what was known at each decision time;
7. explicit complete/partial/missing coverage evidence;
8. deterministic conversion into `ea_lab_offline_replay_package/1`;
9. the canonical offline replay validator green on positive and adversarial cases.

No non-U.S. macro source is qualified by this document. Do not widen the source set during the first real ingest merely to improve coverage.## Source references checked 2026-09-07

- FRED `series/observations`: `https://fred.stlouisfed.org/docs/api/fred/series_observations.html`
- FRED `series/vintagedates`: `https://fred.stlouisfed.org/docs/api/fred/series_vintagedates.html`
- FRED `release/dates`: `https://fred.stlouisfed.org/docs/api/fred/release_dates.html`
- BLS release calendar: `https://www.bls.gov/schedule/2026/`
- BEA release schedule: `https://www.bea.gov/news/schedule`

Direct consumer: first real U.S. macro historical ingest package -> `tools/knowledge_validation/offline_replay_validator.py` -> later broker-clock qualification -> later EA replay. No model interpretation is needed to decide which revision is visible at a decision timestamp.