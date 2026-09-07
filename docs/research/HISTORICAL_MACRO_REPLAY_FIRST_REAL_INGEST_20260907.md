# Historical Macro Replay — First Real Ingest Evidence (PAYEMS V1)

Status: `REAL_SOURCE_SELECTOR_EVIDENCE_READY / DATASET_AND_EA_REPLAY_NOT_QUALIFIED`.

This is the first bounded real-source exercise of the historical macro source + broker clock contracts. It proves public point-in-time value/revision retrieval and deterministic available-at selection. It does not promote a historical dataset, MacroGate policy, EA result, Candidate, runtime, or deployment.

## Source set

- Series: `PAYEMS` — All Employees, Total Nonfarm.
- Originating agency: U.S. Bureau of Labor Statistics.
- Point-in-time value lineage: ALFRED public `Download Data` form.
- Download route observed without login or API key: `https://alfred.stlouisfed.org/series/downloaddata?seid=PAYEMS`.
- Requested vintages: `2025-02-07`, `2025-03-07`.
- Observation range: `2024-12-01..2025-02-01`.
- Output: observations by vintage / all observations, zipped text.

Raw zip was preserved outside Git and is identified by SHA256 `f3ad98c571f9613f2e604ff0a7b75d238bd68b03fee3ed372df18b0e872d7750`. The repository stores only the bounded receipt and hashes, not the downloaded archive.

## Observed point-in-time values

| Observation | 2025-02-07 vintage | 2025-03-07 vintage |
|---|---:|---:|
| 2024-12 | 158926 | 158942 |
| 2025-01 | 159069 | 159067 |
| 2025-02 | unavailable | 159218 |
## Release-clock binding

BLS release evidence fixes both availability clocks at `08:30 ET`:

- Employment Situation for January 2025: `2025-02-07 08:30 ET` -> `2025-02-07T13:30:00Z`.
- Employment Situation for February 2025: `2025-03-07 08:30 ET` -> `2025-03-07T13:30:00Z`.

The conversion is date-aware `America/New_York`, not a universal fixed ET offset. The broker side is separately bound to `HISTORICAL_BROKER_CLOCK_CONTRACT_20260907.md`; no other broker inherits that rule.

## Deterministic selector evidence

Canonical `offline_replay_validator.py` was run twice against the same raw snapshot lineage.

At decision `2025-02-07T13:31:00Z`:

- status `QUALIFIED_AS_OF_DECISION`;
- selected Jan-2025 PAYEMS = `159069` from vintage `2025-02-07`;
- the March revision and February value were withheld as `future_record_count=2`.

At decision `2025-03-07T13:31:00Z`:

- status `QUALIFIED_AS_OF_DECISION`;
- Jan-2025 selects revised value `159067` from vintage `2025-03-07`;
- Feb-2025 selects `159218` from vintage `2025-03-07`;
- `future_record_count=0`.
## Authority boundary

The validator intentionally returns `classification=OFFLINE_DATA_SELECTOR_ONLY`, `historical_dataset_qualified=false`, and `ea_replay_qualified=false`. Those fields remain controlling.

This evidence therefore proves only:

1. a real public no-key ALFRED point-in-time download route exists for this bounded source;
2. the raw response and inner data can be hash-pinned;
3. BLS release clocks can supply source-backed `available_at_utc` values;
4. the canonical selector excludes revisions that were not yet available and switches to the later revision only after its release.

Still required before broader historical dataset qualification: reproducible ingest tooling, explicit finite coverage policy, additional source classes only under separate contracts, and durable raw-evidence handling. Still required after that: EA/tester timeline replay. No strategy/risk/runtime/HOLDOUT/Candidate authority is created.

Durable machine receipt: `portfolio/HISTORICAL_MACRO_REPLAY_PAYEMS_V1_20260907.json`.
