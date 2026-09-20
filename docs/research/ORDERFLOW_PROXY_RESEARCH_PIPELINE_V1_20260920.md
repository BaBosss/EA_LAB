# Order Flow Proxy Historical Research Pipeline V1

Status: `RESEARCH_PREPARATION_ONLY / NOT_RUN / COMMIT_REQUIRED`

Authority ceiling: deterministic offline planning, inert acquisition requests, and raw-artifact integrity preflight only. This package does not acquire data, call a terminal or process, execute MT5, launch the 72 cells, qualify real market data, implement a historical consumer, assess performance, use HOLDOUT, assign a grade, alter risk/defaults, deploy, or trade.

## Frozen experiment

The preregistration is `factory/runs/ofp_historical_v1_20260920/preregistration.json`. It freezes:

- symbols: `XAUUSD, EURUSD, GBPUSD, EURGBP, USDJPY, EURJPY`;
- variants and exact parentage: `OFPR-00 -> OFPR-01 -> OFPR-02` and `OFPC-00 -> OFPC-01 -> OFPC-02`;
- BWD requested interval `[2020-01-01T00:00:00, 2023-01-01T00:00:00)` and MAIN requested interval `[2023-01-01T00:00:00, 2026-01-01T00:00:00)`;
- all window timestamps are prospective broker-server-clock requests whose usable interpretation still requires a named clock contract. No local timezone, UTC offset, or DST conversion is inferred;
- D1 completed profile records, completed M15 context records, completed M5 signal records, and raw bid/ask/flags quote rows are distinct required inputs;
- the accepted profile, activity and quote-direction-imbalance mechanics and the six one-change variant definitions;
- no numeric verdict or grade floor;
- `flat_lot_probe=NOT_APPLICABLE_NO_EXECUTION_YET`;
- Model 4 is planned but never executed by this package. Model 1 does not provide authentic quote-path evidence, so `SIGNAL_INPUT_FIDELITY_UNQUALIFIED` remains until source-bound real quotes and a tested consumer exist.

The plan contains exactly 72 unique `Symbol x Variant x MAIN/BWD` cells. Every cell is `NOT_RUN`; `executed_cells=0`; PF, net, drawdown, trades and opportunities are null. The dates are requested windows, not evidence that history exists.

## Commands

Use the repository portable Python. Outputs may be written to an order-owned external evidence directory.

```powershell
. .\scripts\use_python.ps1
Assert-PortablePython -Root D:\EA_LAB_CONTROL\w\ofp-hist-0920 -Provision

python -B .\tools\orderflow_proxy\historical_pipeline\pipeline.py plan `
  --preregistration .\factory\runs\ofp_historical_v1_20260920\preregistration.json `
  --out D:\EA_LAB_CONTROL\evidence\ofp-pipeline-20260920\hist_author\plan.json

python -B .\tools\orderflow_proxy\historical_pipeline\pipeline.py request `
  --plan D:\EA_LAB_CONTROL\evidence\ofp-pipeline-20260920\hist_author\plan.json `
  --broker ThinkMarkets `
  --server ThinkMarkets-Live `
  --terminal-build 6182 `
  --out D:\EA_LAB_CONTROL\evidence\ofp-pipeline-20260920\hist_author\acquisition_request.json

python -B .\tools\orderflow_proxy\historical_pipeline\pipeline.py preflight `
  --manifest D:\order-owned-input\raw_manifest.json `
  --expected-manifest-sha256 <externally-frozen-lowercase-sha256> `
  --preregistration .\factory\runs\ofp_historical_v1_20260920\preregistration.json `
  --out D:\EA_LAB_CONTROL\evidence\ofp-pipeline-20260920\hist_author\preflight.json
```

The `request` command only writes a deterministic request description. It contains no network, terminal, process, or acquisition API. There is deliberately no launch command.

## Raw manifest preflight

The contract-specific manifest schema is `ofp_historical_raw_manifest/v1`. It must be externally frozen and passed with its exact SHA-256. The preflight requires one unique artifact for each of four roles for every symbol and requested window: `RAW_QUOTE_ROWS`, `D1_RATE_ROWS`, `M15_RATE_ROWS`, and `M5_RATE_ROWS` (48 artifacts total).

The manifest binds:

- exact broker, server, terminal build, logical symbol and broker symbol, repeated on every raw row;
- the fixed source graph from named broker history to the four raw payload types;
- exact six-symbol dataset scope and both requested half-open intervals;
- a named clock contract, with `NONE_INFERRED` timezone conversion;
- acquisition time in UTC, separately from each row's broker-clock historical market time;
- replay assumed availability and historical as-of availability as `UNKNOWN_NOT_PROVEN`;
- causal decision partitioning as `NOT_IMPLEMENTED`;
- relative artifact path, byte size, exact SHA-256, record count, role, symbol and interval identity.

Quote payload rows contain timestamped `bid`, `ask`, and `flags`. A2 envelopes, count/hash receipts, or quote-stream hashes are not quote rows and cannot substitute for them. Rate rows contain timestamped OHLC and integer `tick_volume`; a copied quote count is not presumed equal to bar tick volume. Bool counts, non-finite values, malformed JSONL, invalid OHLC, invalid quotes, non-increasing timestamps, out-of-window/future rows, hash or size mismatch, missing per-interval evidence, duplicate identities, path escapes/reparse components, source/symbol/build mixing, unknown clocks, and synthetic fixture substitution all fail closed.

A repeated broker-history export may claim only `REVISED_HISTORY_REPEATABLE`. Preflight does not establish exchange-wide completeness, historical point-in-time/as-of availability, or immutable broker history.

## Classification and gates

A structurally valid synthetic fixture is returned as `VALIDATED_FIXTURE_INPUT`. This proves only readability, schema enforcement, and artifact integrity; `real_data_qualified=false` and `execution_allowed=false` remain fixed.

A structurally valid broker export is returned as `RAW_ARTIFACT_INTEGRITY_VALIDATED`, not `REAL_DATA_QUALIFIED`. The next raw-history qualification must independently review the frozen manifest and evidence. No `qualified=true` input or receipt override exists.

Every successful preflight retains these unresolved gates:

- `RAW_HISTORY_QUALIFICATION_REVIEW_REQUIRED`;
- `HISTORICAL_SEAM_CONSUMER_NOT_IMPLEMENTED` — the accepted native seam admits only six exact current-window pins and is not widened or repinned here;
- `SIGNAL_INPUT_FIDELITY_UNQUALIFIED`;
- `EXECUTION_SEMANTICS_REQUIRED` — entry/fill, position arbitration, cost units, lot/balance/leverage, SL/TP normalization/rejections, post-fill 12-M5 exit boundary, and safety/holdover are not defaulted;
- `MODEL4_NOT_RUN`.

The current readiness snapshot is therefore truthful preparation only: accepted OFP source and the exact six current-window seam pins exist; historical raw quotes, historical D1/M15/M5 qualification, a historical consumer, causal replay availability, execution semantics, and Model-4 execution do not. There are no historical profiles, opportunities, trades, or performance claims in this milestone.
