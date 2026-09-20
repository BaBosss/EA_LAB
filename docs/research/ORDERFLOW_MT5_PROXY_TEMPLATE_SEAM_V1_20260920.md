# Order Flow MT5 Proxy Template/Data Seam V1

Status: `SOURCE_ONLY / RESEARCH_INPUT_ONLY_CURRENT_WINDOW / COMMIT_REQUIRED`

Authority ceiling: `SOURCE_ONLY_TEMPLATE_SEAM / RESEARCH_INPUT_ONLY / NO_ENTRY_SIGNAL_MAPPING / NO_ORDER_EXECUTION / NO_BACKTEST_PERFORMANCE / NO_OPTIMIZATION / NO_HOLDOUT / NO_CANDIDATE / NO_DEPLOYMENT / NO_TRADING`.

## Purpose

This seam lets a future, separately contracted research consumer combine an existing `OFPDecision` with structurally validated ThinkMarkets A2 provider evidence without losing the decision's stop, target, risk/reward, setup/trigger clocks, profile identity, or provider identity.

It does not convert the decision to the current generic `EntrySignal`. That type has direction, strength, confidence, validity, and reason, but no structural stop, target, profile/window identity, provider provenance, prospective-quote identity, or consumer-owned time-exit contract. Mapping to it would discard decision-critical geometry and would invite invented strength/confidence values.

## Accepted provider scope

The only policy is `THINKMARKETS_LIVE_A2_V1`:

- server `ThinkMarkets-Live`;
- terminal build `6182`;
- reviewed repository head `041178539fe07a306af2b68b3209b8401822534c`;
- evidence manifest SHA256 `1b33325e46aceee5f80041e599cc1c20f71124adbbc726721b89bef83664ff0f`;
- exact-name logical/broker mappings only;
- exact reviewed current windows for `XAUUSD`, `EURUSD`, `GBPUSD`, `EURGBP`, `USDJPY`, and `EURJPY`.

`BTCUSD` and `ETHUSD` are rejected because both have `RATE_SNAPSHOT_CHANGED`. The source contains no toggle or caller-supplied `qualified=true` path that can override this.

Qualification means only that the provider-local `COPY_TICKS_INFO` quote stream was repeatable after synchronization for the frozen D1 profile interval plus 20 M5 warmup intervals and one candidate M5 interval. It does not mean market-wide completeness, true exchange order flow, executed-volume Delta, or standing qualification for a future decision window.

## Typed evidence validation

`ThinkMarketsA2Evidence.mqh` defines the provider envelope and 22 typed interval receipts. The validator checks:

- exact policy, classification, server, build, reviewed head, evidence-manifest hash, and exact symbol mapping;
- the per-symbol reviewed profile and candidate clocks;
- one D1 profile receipt followed by M5 ordinals 0 through 20, with ordinals 0 through 19 marked `WARMUP` and ordinal 20 marked `CANDIDATE`;
- positive counts, valid-bid/ask counts equal to copied counts, in-range first/last millisecond clocks, lowercase SHA256 shape, and successful copy states;
- pass-1/pass-2 equality of count, first/last time, valid quote count, and quote-stream hash;
- stable rate snapshots and a profile interval that ends no later than the candidate window;
- `true_orderflow=false` and `executed_volume_delta_qualified=false`.

Malformed, missing, duplicate, reordered, future, mismatched, unstable, unsupported, or broadened evidence fails closed.

## Geometry-preserving result

`OrderFlowProxyTemplateSeam.mqh` copies the complete `OFPDecision`, its complete `OFPGeometry`, and the provider evidence identity into `OFPTemplateSeamResult`. It exposes:

- `component_signal_valid`;
- `provider_window_valid`;
- direction and full geometry;
- `current_entry_signal_compatible=false`;
- `order_execution_authorized=false`;
- `time_exit_consumer_owned=true`;
- an explicit `binding_status` and `refusal_reason`.

Even a valid result is only `RESEARCH_INPUT_ONLY_CURRENT_WINDOW`. It does not place an order and does not authorize another component to place one. OFPC's proposed 12-M5 exit still begins only after a real fill and remains owned by a future geometry-aware consumer.

## Offline bundle builder

`tools/orderflow_proxy/provider_bundle.py` is an offline-only builder. It contains no MetaTrader import or call. Before emitting anything it verifies the immutable SHA256 of all eight consumed A2 files, then checks the reviewed `SCRUTINY_PASS / HIGH`, empty material findings, reviewed head, manifest hash, exact qualified/blocked sets, recovery record, terminal/provider identity, frozen selections, interval receipts, repeated quote-stream identities, and rate snapshots.

Example:

```powershell
. .\scripts\use_python.ps1
Assert-PortablePython -Provision
python -B .\tools\orderflow_proxy\provider_bundle.py `
  --evidence-root D:\EA_LAB_CONTROL\evidence\ct-ofp-thinkmarkets-sync-basis-20260920 `
  --output-dir D:\EA_LAB_CONTROL\evidence\ct-ofp-template-seam-v1-20260920\author_validation\bundles
```

The command writes one deterministic JSON file for each of the six accepted symbols. Each file includes the typed fields needed by the MQL validator and a deterministic payload hash. It deliberately excludes account ID, login, password, credentials, and terminal data-path identity.

The emitted bundle is valid only for its named current window. Every future decision window must be freshly synchronized, repeated, reviewed as required by its contract, and bundled again. Reusing this bundle as a permanent provider certificate is invalid.

## Validation boundary

Authorized validation is portable Python `-B`, the existing 24-case mirrored fixture replay, byte/diff checks, and MetaEditor compilation from an external copied tree. The MQL harnesses are compile-only and must never be attached or executed under this milestone. No MT5 Terminal or Tester run, Template core edit, `LAB_ENTRY`/FamilyID allocation, Registry mutation, performance claim, or deployment follows from source compilation.
