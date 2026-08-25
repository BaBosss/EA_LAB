# EA_LAB Ziplime Research Module

Status: isolated merge candidate. This module is a non-authoritative research/data-preparation sidecar for Factory vNext.

## Purpose

Prepare deterministic OHLCV research datasets and provenance artifacts for a later MT5-vs-Ziplime concordance pilot without changing strategy, risk, deployment, or Factory verdict authority.

Direct consumer: Factory vNext MVP sidecar pilot using the frozen SuperTrendFlip / BTCUSD / H4 research identity.

## Authority boundary

`authority = RESEARCH_ONLY` is mandatory. Module outputs cannot promote a Candidate, satisfy deployment evidence, alter DEMO/LIVE state, change risk/defaults, or replace MT5 Strategy Tester evidence.

Ziplime remains an external dependency. Its source is not vendored into EA_LAB. The expected research runtime is Python `>=3.12,<3.14` with Ziplime `1.19.16`.

## Commands

`doctor` checks the external Python/Ziplime runtime and never installs or updates packages.

`prepare` validates an explicit column map and source CSV, normalizes the data, and emits governed artifacts.

`verify` re-hashes the source, column map, and normalized dataset and rejects manifest/artifact drift.

## Input contract

`prepare` accepts CSV only through an explicit JSON `column_map`; it never guesses field names. V1 requires mappings for `timestamp, open, high, low, close, volume` and UTC timestamps.

The pilot identity is fail-closed to logical `BTCUSD` and execution timeframe `H4`. Any other symbol/timeframe returns `OUTSIDE_VALIDATED_CONTRACT`.

Rows must have strictly increasing unique timestamps, finite numeric values, non-negative volume, and internally consistent OHLC values.

## Deterministic outputs

Each preparation creates exactly:

- `normalized_dataset.csv`
- `dataset_manifest.json`

The normalized schema is `timestamp,open,high,low,close,volume`. Decimal formatting, timestamp representation, field order, JSON key order, and line endings are deterministic.

The manifest contains source and normalized SHA-256 values plus Concept/Home/Window/Profile/ParameterSet/Run identity, source commit, row count, first/last timestamps, tool version, expected Ziplime version, and `RESEARCH_ONLY` authority.

No generated-at timestamp or machine-specific absolute path is written into deterministic artifacts.

## Example

```powershell
$py = 'D:\EA_LAB\tools\python312\python.exe'
& $py tools\ea_lab_ziplime\module.py doctor
& $py tools\ea_lab_ziplime\module.py prepare `
  --input bars.csv --column-map column_map.json --output-dir out `
  --source-commit <40-hex> --concept SuperTrendFlip `
  --logical-symbol BTCUSD --execution-tf H4 `
  --home-contract-id STF-BTCUSD-H4 --window-contract-id W1 `
  --profile-id BASELINE --parameter-set-id P0 --run-id RUN-001
& $py tools\ea_lab_ziplime\module.py verify --output-dir out --source bars.csv --column-map column_map.json
```

## Merge gate

Focused tests must pass, including positive prepare/verify, byte-identical reproducibility, wrong Symbol/TF, missing mappings/headers, invalid OHLC, negative volume, duplicate/non-monotonic timestamps, source/artifact tampering, manifest-authority tampering, bad source commit, and runtime-version contract tests.

Before canonical integration also run `git diff --check`, the impacted Factory vNext design-freeze regression, and the required exact-HEAD independent review after active neighboring writer lanes are stable.

This module deliberately stops before Ziplime strategy execution. The next bounded milestone after integration is the SuperTrendFlip BTCUSD/H4 MT5-vs-Ziplime concordance pilot; that pilot determines whether Ziplime becomes a useful fast-screen engine or remains experimental.
