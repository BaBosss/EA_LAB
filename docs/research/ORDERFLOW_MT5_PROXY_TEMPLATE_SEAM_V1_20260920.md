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

### Native cryptographic payload binding

Structural validation is followed by two independent exact pins. First, `bundle_sha256` must equal the reviewed Python bundle hash for the named symbol; a merely shape-valid or caller-recomputed digest is refused. Second, native MQL reconstructs a canonical payload preimage from the received envelope and all fields of all 22 receipts, hashes its UTF-8/ASCII bytes with `CryptEncode(CRYPT_HASH_SHA256)`, and compares the result with a separate per-symbol integrity pin. No integrity digest is accepted from the caller.

The canonical serialization is `orderflow_proxy_native_payload_integrity/v1\n` followed by fixed-order records of the form `name|type|ASCII-byte-length|value\n`. Type is `s`, `i`, or `b`; integers use unsigned decimal with no leading zeros and booleans are lowercase `true`/`false`. Envelope order is schema, policy, classification, provider, build, logical/broker symbols, reviewed head, evidence manifest, three current-window timestamps, the two provider claim booleans, the three fixed seam-authority booleans, and receipt count. Each receipt then serializes, in array order, kind, ordinal, role, start/end, both counts, both first/last timestamps, both valid-bid/ask counts, both quote-stream hashes, both API-success booleans, repeat identity, and snapshot stability. Accepted values are ASCII, so MQL `StringLen` equals the encoded byte length.

`bundle_sha256` is explicitly excluded from that preimage because it is separately pinned and including it would couple two digest domains; the native integrity digest is not a payload field, avoiding recursion. The exact reviewed pins are:

| Symbol | bundle_sha256 | native payload integrity SHA-256 |
|---|---|---|
| XAUUSD | `eb4ae690ae9c8cbe32e5ca3b69baef1e1ce42ebe63e1fa3eba560ab95da71a8d` | `217efde6f0f1e9528fb22fe26c8ed0921d97e595fe0c8a0d69f72bb25dba8381` |
| EURUSD | `776df940030826e6dc60389c0b2fe731999d66b8853a8651231947f73d1de75c` | `3c898de1e43fa4e703b0a9f2b2adf9304d8269dbfd5624faba239ec666686228` |
| GBPUSD | `3fa11f7c2db87873dcf809dafa344a487b9869fb091c351d68a3da7da7383046` | `ce455c8bf7f22bc3830f7791b5136992e0196d332d24e8aa1787bf1413d7fde5` |
| EURGBP | `330fb9d2e0cdbd4d82ab7fa25c998c47a51a0f1f520cbfe1f14fadc807966c92` | `468be594fc8f89a938add1e6673ce9f0f6a88206bd2e01c8d5733059a1739d24` |
| USDJPY | `26f6af2bba8bfa786e1940b1f818d4a84d2c7cec3c332ebe65267e5226953287` | `6059ab6923f47699d305085055c996e699cab487fc06e5640def01c7c3162a28` |
| EURJPY | `e9c2d00c7d193e5e488e0b30bb25418f6f506db7933eb33233ede02c73f10576` | `f10d000ac11fcb96f99cf0e9d9ea4624661405f6331859b5fa64ad6580743885` |

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
