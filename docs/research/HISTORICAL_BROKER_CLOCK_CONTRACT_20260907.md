# Historical Broker Clock Contract — 2026-09-07

Status: QUALIFIED FOR THINKMARKETS-LIVE 2019-03-01..2025-12-31 / RESEARCH DATA CLOCK ONLY
Authority: timestamp normalization for offline research evidence only; no MT5 runtime, trading, strategy, risk/default, deployment, HOLDOUT, optimization, Candidate, or policy authority.

## Purpose

Bind historical macro/news `available_at_utc` evidence to the same broker-server clock semantics already accepted for Boss19 P4B local OHLC evidence, without inventing a universal broker timezone rule.

This contract is intentionally broker-lineage specific. It applies only when the replay evidence is bound to the accepted `ThinkMarkets-Live` tester/server lineage and the historical interval below.## Accepted mapping

Canonical implementation evidence is `tools/P4BMarketDataExporter/normalize_ohlc.py` plus `docs/research/BOSS19_P4_UNIT_EXPORT_CONTRACT.md`.

For raw ThinkMarkets tester/server timestamps:

- standard-time server offset = UTC+2;
- daylight-saving server offset = UTC+3;
- the accepted DST season follows the U.S. DST calendar used by the existing normalizer: after the second Sunday in March and before the first Sunday in November;
- the transition server dates themselves are **not assigned a guessed switch instant**. Rows on those dates remain `UNKNOWN_DST_TRANSITION` and are quarantined.

The existing P4B regression test covers standard offset, DST offset, return to standard time, and transition-date quarantine.## Source support checked 2026-09-07

ThinkMarkets' current support documentation states that MT4/MT5 server time is GMT+2, or GMT+3 during daylight saving time. ThinkMarkets' published 2025 and 2026 U.S. DST notices explicitly describe the server/trading-hours shift between GMT+2 and GMT+3 around the U.S. DST season.

These current public sources corroborate the already accepted P4B mapping. They do not retroactively create evidence for a different broker, server name, account lineage, or interval.

The historical acceptance authority remains the frozen EA_LAB P4B source/normalizer/test lineage; current web pages are supporting source provenance, not a replacement for the accepted package.## Replay package binding

For `ea_lab_offline_replay_package/1`, a ThinkMarkets-Live package may declare:

- `clock_mapping.version = THINKMARKETS_LIVE_US_DST_QUARANTINE_V1`;
- `clock_mapping.broker_timezone = ThinkMarkets-Live server time`;
- `clock_mapping.mapping_basis` naming this contract and the accepted P4B normalizer;
- the macro source timezone separately, as required by `HISTORICAL_MACRO_REPLAY_SOURCE_CONTRACT_20260907.md`.

Event/source time must first become source-backed UTC. Only then may the replay layer compare it with broker/tester UTC-normalized evidence. Do not shift an official release timestamp into broker time and then relabel it UTC.## Boundary / refusal rules

This mapping is **not** accepted for Exness, another ThinkMarkets server name, another broker, or evidence whose broker/server identity is missing or ambiguous.

It is frozen only for the already researched interval `2019-03-01..2025-12-31`. Extending the interval requires source-backed transition semantics for the added dates plus impacted regression; do not infer future years from the rule merely because the calendar formula is predictable.

Rows on quarantined DST transition server dates remain unknown-time coverage. They may not be imputed, shifted by one hour after seeing outcomes, or used to create a regime/session/news label.

A broker-clock PASS does not qualify the historical macro dataset, event coverage, EA replay, MacroGate/NewsGuard behavior, or strategy performance.## References

Canonical EA_LAB evidence:
- `docs/research/BOSS19_P4_UNIT_EXPORT_CONTRACT.md`
- `tools/P4BMarketDataExporter/normalize_ohlc.py`
- `scripts/_test/run_p4b_local_ohlc_export_tests.ps1`

Supporting ThinkMarkets sources checked 2026-09-07:
- `https://support.thinkmarkets.com/hc/en-gb/articles/11613703690385-What-is-ThinkMarkets-server-time`
- `https://www.thinkmarkets.com/za/announcements/2025-us-dst-trading-hours-update/`
- `https://www.thinkmarkets.com/au/announcements/2026-us-dst-trading-hours-update/`

Direct consumer: historical macro replay packages bound to the accepted ThinkMarkets-Live tester lineage -> offline replay selector -> later EA replay.