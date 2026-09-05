# RuntimeIdentity Freshness Semantics Contract — 2026-09-05

Status: `CONTRACT_READY / NOT_IMPLEMENTED / MONITORING_ONLY`
Canonical base: `244c15d5c01dfdf31b3ce11daf578897b0376376`
Authority: monitoring telemetry semantics only; no strategy, risk, trading, deployment, attachment, or judge-clock authority.

## Problem proved

Current `RuntimeIdentity.mqh` publishes only at attach and first qualifying entry. After first trade, `RuntimeIdentity_Update()` returns permanently. The Python validator and lab collector independently reject producer `evidence_timestamp` older than 30 hours, and the VPS return transport also uses a 30-hour file-age gate. Therefore a healthy unchanged attachment self-expires by construction.

A tick-driven heartbeat is insufficient: an FX weekend can exceed 30 hours without ticks. A timer with `TimeCurrent()` is also insufficient. MQL5 documents `TimeCurrent()` outside `OnTick`, including `OnTimer`, as the time of the last quote received in Market Watch, so it may stop advancing while the process remains healthy.

## Frozen semantic split

Runtime identity authority and liveness authority are separate clocks:

- `attach_time_unix`: retain current broker/deal clock semantics. It is captured at real attach by existing `TimeCurrent()` logic and remains the authority boundary for qualifying post-attach deals.
- `attach_epoch`: unchanged. Heartbeats never increment or rewrite the epoch counter.
- `first_trade_epoch`: unchanged. Only a qualifying `DEAL_ENTRY_IN` after attach may establish it.
- `evidence_timestamp`: liveness timestamp only. New writes use `TimeGMT()` formatted as UTC ISO-8601 `YYYY-MM-DDTHH:MM:SSZ` so the clock advances from the terminal host clock even when no quote arrives.
## Frozen heartbeat contract

1. Register one per-program timer at successful EA initialization with `RUNTIME_IDENTITY_HEARTBEAT_SECONDS = 3600`.
2. Heartbeat cadence is one hour. This gives 29 hours of margin against the existing 30-hour freshness ceiling while keeping write volume negligible.
3. `OnTimer` republishes the existing RuntimeIdentity body through the existing atomic temp-file plus `FileMove(...FILE_REWRITE)` path.
4. A heartbeat may refresh only liveness time. It must not change configuration fingerprint, build receipt, symbol, timeframe, attach time, attach epoch, or first-trade epoch.
5. `EventKillTimer()` is called during deinitialization when this component owns the timer.
6. Where an EA already owns `OnTimer`, RuntimeIdentity must be integrated into that existing event handler/timer rather than declaring a second timer owner. MQL5 permits only one timer per program.
7. Timer-registration failure is telemetry-fail-visible, not strategy-fatal: log an explicit RuntimeIdentity timer failure and allow the EA to continue. Monitoring will then age to STALE under the unchanged 30-hour guard. Do not return `INIT_FAILED` solely because telemetry heartbeat registration failed.
8. Existing attach and first-trade writes remain immediate; the timer is additional liveness evidence, not a replacement.

## Consumer semantics

The canonical 30-hour stale threshold and 5-minute future tolerance remain unchanged. The collector continues to preserve producer JSON bytes and must not restamp evidence. Validator and first-trade derivation remain unchanged except for accepting the already-schema-valid UTC timestamp representation.

Old event-only `runtime_identity/1` records remain readable and fail stale exactly as today. No schema-version bump is required because `evidence_timestamp` is already a non-empty string field and the validator accepts timezone-aware ISO timestamps. New producers must emit the UTC `Z` representation prospectively.

`TimeGMT()` depends on the VPS/terminal host clock. A materially wrong host clock therefore remains fail-visible through the existing FUTURE/STALE checks; the heartbeat must not silently correct consumer time or infer broker time from file mtime.
## Minimum acceptance matrix before implementation can be accepted

- fresh attach/no trade -> fresh `AWAITING_FIRST_TRADE`;
- hourly heartbeats across more than 30 hours/no trade -> remains fresh;
- first trade then later heartbeat -> remains `VERIFIED`, with attach/first-trade identity byte-equivalent except liveness timestamp;
- no successful heartbeat for more than 30 hours -> `EVIDENCE_TIMESTAMP_STALE`;
- simulated 48-hour zero-tick period with timer events -> liveness timestamp advances and remains fresh;
- timer registration failure -> explicit log/finding, strategy initialization continues, monitoring ultimately goes stale;
- genuine process restart -> new attach epoch under the existing GlobalVariable mechanism;
- malformed/future timestamp remains fail-closed;
- existing RuntimeIdentity unit, PowerShell bridge, production-path, transport, and monitor cages stay green.

## Source basis

Repository: `ea_template/core/RuntimeIdentity.mqh`, `ea_template/core/LabCore.mqh`, `_triage/factory_os/runtime_identity.py`, `scripts/collect_live_deals.ps1`, `_triage/factory_os/schemas.json`.

External API semantics checked against MetaQuotes MQL5 Reference on 2026-09-05: `TimeCurrent` (last known quote time outside OnTick), `TimeGMT` (GMT calculated from client-computer local clock), and `EventSetTimer` (one timer per program; boolean registration result).

## Authority ceiling / current state

This contract authorizes no code change by itself and no VPS deployment. ORDER-353 remains `BLOCKED / E OWNER-EXTERNAL`; `first_trade_epoch=null`; `judge_date=null`. Global monitoring remains `DEGRADED_MONITORING`. Implementation must be a separate bounded core-code lane with tests and different-model-family review before any deployment decision.
