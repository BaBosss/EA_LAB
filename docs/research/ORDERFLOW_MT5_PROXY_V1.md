# MT5 Activity/Quote Proxy Components V1 — OFPR / OFPC

Status: `SOURCE_IMPLEMENTED / PROXY_ONLY / ORDER_FREE / OFFLINE_FIXTURE_VALIDATED / COMPILE_ONLY`

Authority ceiling: source-only research components and read-only availability-audit tooling. This package is not TRUE_ORDERFLOW, an executed-volume profile, Delta, qualified broker data, a backtest, a strategy-performance result, a Template binding, a FamilyID/LAB_ENTRY allocation, a runtime default, or permission to deploy or trade.

## 1. Claim and lineage boundary

The proxy families are experimentally separate from accepted OF01/OF02. Their mechanics may be compared conceptually, but their parentage stays inside OFPR/OFPC and the accepted package under `ea_template/components/orderflow/` is unchanged.

```text
OFPR-00 PROFILE_PRICE_CONTROL
 `- OFPR-01 TICK_ACTIVITY
     `- OFPR-02 QUOTE_IMBALANCE

OFPC-00 PROFILE_PRICE_CONTROL
 `- OFPC-01 TICK_ACTIVITY
     `- OFPC-02 QUOTE_IMBALANCE
```

Every record and decision uses these literal labels:

- data identity: `MT5_ACTIVITY_QUOTE_PROXY`;
- profile identity: `TICK_ACTIVITY_PROFILE`;
- profile recipe: `MT5_TICK_ACTIVITY_PROFILE_V1`;
- imbalance identity: `QUOTE_DIRECTION_IMBALANCE_PROXY`;
- session identity: `MT5_BROKER_D1_BAR_V1`.

`TRUE_ORDERFLOW`, `EXECUTED_VOLUME_PROFILE`, and `DELTA` are forbidden labels for this package. There is no automatic provider fallback and no proxy-to-Delta equivalence.

## 2. Frozen profile recipe

The consumer supplies immutable instrument/source identity plus the adjacent broker-D1 records that bound the profile: the previous completed record and the current record. Their non-empty record IDs, consecutive sequences, source/instrument identity, open boundaries, completion state, and availability timestamps must agree. The profile interval is exactly `[previous_d1.open, current_d1.open)`; no fixed 24-hour duration, UTC, timezone, or DST rule is inferred. Context, M5, raw quote-tick, and prospective-quote inputs carry the same immutable identity, and every chronological record binds to the stored current-D1 record ID, sequence, and open boundary. Cross-symbol, cross-source, stale-session, non-adjacent, or overlapping-boundary input fails closed.

For each MT5 quote tick in the half-open interval `[session_start, session_end)`:

1. use `mid=(bid+ask)/2` only when both bid and ask are finite and positive;
2. never substitute `Last` for an invalid bid/ask pair;
3. choose `SYMBOL_TRADE_TICK_SIZE` when positive, otherwise `SYMBOL_POINT`; refuse when neither is positive;
4. calculate `bin_index=floor(mid/bin_size + 1e-12)`;
5. add exactly one activity count to that bin.

The POC bin has maximum activity; an exact tie selects the lower bin index. For the inherited point-target geometry, the stored deterministic POC price is the selected bin midpoint `(poc_bin_index + 0.5) * bin_size`. This is a coordinate for the quote-activity bin, not an executed-price claim.

The value area begins at POC and targets 70% of all qualifying activity counts. At each expansion step, compare the immediately adjacent lower and upper bin counts. Add the larger side; an exact tie adds both sides. Zero-count intervening bins remain part of adjacency. Stop once cumulative activity is at least 70%. `VAL` is the lower boundary of the lowest included bin and `VAH` is the upper boundary of the highest included bin.

This is quote-tick activity, never executed volume.

## 3. Shared completed-bar geometry

- Context uses the latest causally available completed M15 record.
- ATR(14) uses completed M5 bars ending immediately before the candidate.
- Zone and stop buffer are frozen at `0.20 * ATR`.
- Relative activity is `current completed M5 tick_volume >= 1.50 * median(previous 20 completed M5 tick_volume)`; the current bar is not in its own median.
- Quote imbalance uses consecutive qualifying mids inside one completed M5 bar. Strictly higher/lower mids increment up/down; unchanged mids are ignored. `ratio=(up-down)/(up+down)`. A zero denominator refuses the imbalance-required observation.
- All comparisons are completed-bar only.
- The returned quote is prospective, strictly post-confirmation, and never a fill. No fill simulation exists.
- Replay is chronological across multiple historical setups. Ordinary historical cancellation, expiry, or a historical qualifying trigger resets state and continues; only an envelope-bound current-bar signal, terminal invalid/rejected input, or the end of supplied history stops evaluation. Completed-bar and no-lookahead rules remain unchanged.

## 4. OFPR variants

The M15 context closes strictly inside `[VAL, VAH]`. A completed M5 test overlaps the frozen edge zone, closes back inside value, and has the relevant rejection wick at least 0.40 of full range. The next three completed M5 bars form the trigger window. Long closes strictly above test high; short closes strictly below test low. Two consecutive completed closes beyond the exterior frozen zone cancel.

Stop is beyond the most adverse test-through-confirmation extreme plus frozen buffer. Target is the proxy POC coordinate. Caller-supplied all-in price cost is added to risk and removed from reward; net RR must be at least 1.50.

| Variant | Parent | One logical change |
|---|---|---|
| OFPR-00 | none/base | profile, price, wick, trigger, and geometry only; no event-bar activity or imbalance gate |
| OFPR-01 | OFPR-00 | test-bar relative tick-activity gate |
| OFPR-02 | OFPR-01 | test-bar quote imbalance: long `<= -0.20`, short `>= +0.20` |

## 5. OFPC variants

The completed M15 context closes strictly beyond VAH for long or VAL for short. The first completed M5 close beyond the outer frozen zone fixes ATR/buffer. The next M5 bar must be a consecutive second close. Retest must occur in the next six completed M5 bars, overlap the frozen zone, and close on the breakout side of the profile edge. Confirmation must occur in the next three completed M5 bars and close strictly beyond the retest extreme. A close past the value-side boundary (`VAH-buffer` long, `VAL+buffer` short) cancels.

Stop is beyond the most adverse retest-through-confirmation extreme plus frozen buffer. Prospective target is exactly 2R from the supplied quote. The proposed 12-M5 time exit remains consumer-owned after an actual fill and is not implemented here.

| Variant | Parent | One logical change |
|---|---|---|
| OFPC-00 | none/base | profile, price, breakout/retest/confirmation, and geometry only; no activity or imbalance gates |
| OFPC-01 | OFPC-00 | second-breakout relative tick-activity gate |
| OFPC-02 | OFPC-01 | second-breakout imbalance long `>= +0.20` / short `<= -0.20`, plus strictly directional confirmation imbalance (`>0` long / `<0` short) |

## 6. Source interfaces

MQL5 source is isolated under `ea_template/components/orderflow_proxy/`:

- `OrderFlowProxyTypes.mqh` — proxy-only types and geometry;
- `OrderFlowProxyValidation.mqh` — label, chronology, completed-bar, ATR, activity, imbalance, quote, and envelope validation;
- `TickActivityProfile.mqh` — frozen D1 quote-tick activity profile;
- `OFPRReversal.mqh` — OFPR engine plus `OFPR00_Replay`, `OFPR01_Replay`, and `OFPR02_Replay`;
- `OFPCContinuation.mqh` — OFPC engine plus `OFPC00_Replay`, `OFPC01_Replay`, and `OFPC02_Replay`;
- `OrderFlowProxyComponents.mqh` — inert convenience include.

`OFP_BuildBarQuoteProxy` derives per-bar up/down/unchanged counts from raw timestamped bid/ask ticks in the half-open completed-M5 interval. It rejects non-monotonic tick input and cross-instrument/source ticks, excludes a tick exactly at the next bar open, ignores unchanged mids, and never substitutes `Last`. The profile builder accepts adjacent typed D1 records rather than arbitrary start/end timestamps.

`ea_template/tests/OrderFlowProxyComponents_Test.mq5` is a compile-only harness. Under this milestone it is never attached or executed.

The Python reference is `tools/orderflow_proxy/offline_reference.py`. It exposes the profile builder, relative-activity and quote-imbalance calculations, chronological variant evaluator, and fixture CLI. The fixture schema is `orderflow_proxy_fixture/v1`; fixture success does not qualify broker data or MQL runtime parity.

## 7. Read-only MT5 availability audit

`tools/orderflow_proxy/mt5_audit/OrderFlowProxyAvailabilityAudit.mq5` is an MQL5 service, so it requires no chart attachment. It has no trade library, order, or position calls and never calls `SymbolSelect`. If a controller later executes it under a separate runtime contract, it writes JSONL capability records only.

The logical universe is fixed to `XAUUSD, EURUSD, GBPUSD, EURGBP, USDJPY, EURJPY, BTCUSD, ETHUSD`. Discovery scans the terminal symbol catalogue for the logical name plus a recorded suffix and checks base/profit metadata when the broker exposes it. Zero or multiple matches fail closed as `BLOCKED_DATA`; no suffix is assumed.

Each record includes terminal name/path/data path/build/server identity, logical and exact broker symbols, suffix/candidate count, `SYMBOL_POINT`, `SYMBOL_TRADE_TICK_SIZE`, D1/M15/M5 server-first and last-bar timestamps, bounded rate coverage with tick/real-volume positive and zero rates, and chunked `CopyTicksRange` coverage with bid/ask, Last, volume, volume_real, tick flags, and quote-direction counts.

Capability means data availability only and is computed from exact completed intervals, not aggregate coverage counts:

- `P0_READY`: unambiguous symbol, positive bin size, an exact adjacent broker-D1 pair, and a successful exact `[previous_d1.open,current_d1.open)` tick copy with qualifying bid/ask ticks sufficient to form the profile-price control;
- `P1_READY`: P0 plus one exact completed candidate M5 record and its previous 20 completed M5 records, with sequence continuity and positive tick volume in every record;
- `P2_READY`: P1 plus successful exact quote-tick copies for the 21 M5 records and a non-zero within-bar directional denominator in the candidate record. Previous-mid state resets at every M5 boundary; cross-bar price changes never create readiness;
- `BLOCKED_DATA`: P0 cannot be formed or mapping is ambiguous/missing.

Copy failures, missing exact records, sequence gaps, and zero directional denominators are recorded explicitly and reduce capability rather than being inferred away. These labels do not claim strategy quality. This source milestone does not execute the service or collect broker data.

### 7.1 Copy presence is not qualified completeness

Each native `CopyRates` and `CopyTicksRange` request resets the last error before the call and captures it immediately afterward. The audit retains the requested half-open interval, expected `MqlRates.tick_volume`, returned count, array size, error, first/last tick times, timestamp ordering/range checks, price validity, source/symbol/boundary checks, synchronization state, pre/post rate-snapshot stability, count-consistency result, and refusal reason. Zero, partial, excess, errored, malformed, stale, changed-snapshot, unsynchronized, wrong-boundary, or count/array-disagreeing copies cannot support a completeness claim. Every completed M5 interval is reconciled independently; surplus ticks in another interval cannot compensate for a missing interval.

`COPY_TICKS_ALL` returned count is not assumed to equal `MqlRates.tick_volume` for every provider. The native audit has no provider-specific qualified count basis in this scope, so even a stable, error-free, count-matching observation remains `COUNT_BASIS_UNQUALIFIED` and the public capability remains `BLOCKED_DATA`. The JSON separates `raw_observed_capability` and data-presence fields from `completeness_qualified`; no input, toggle, or caller boolean can promote an unqualified observation to `P0_READY`, `P1_READY`, or `P2_READY`. The shared predicate's positive completeness branch is reserved for deterministic `FIXTURE_EXACT_NATIVE_EVENT_COUNT` controls and does not qualify real market data.

Constant-price records with a complete positive native count remain complete records. Directionality is a separate candidate-only P2 rule: prior M5 records may have zero within-bar directional denominators, while the candidate must have a nonzero denominator for P2. Cross-bar changes never create directionality.

### 7.2 Historical external diagnostic correction

The retained external `ct-orderflow-proxy-data-audit-ro-20260920` JSONs are `DATA_PRESENT_NOT_QUALIFIED / NOT_ACCEPTANCE_EVIDENCE`. Their historical `ALL_8_P2_READY_AT_AUDITED_INTERVALS` assertion is not a qualified readiness claim: multiple copied tick counts differ from candidate `tick_volume`, GBPUSD D1 is later than its M5 candidate, BTCUSD/ETHUSD D1 gaps remain unresolved, and receipts for all 21 completed M5 intervals are absent. Those files remain verbatim contrary observations and do not authorize a backtest or new MT5 audit execution.

## 8. Validation and remaining authority gates

Authorized validation is portable Python `-B`, mirrored fixture replay, external-copy MetaEditor compilation, allowlist/diff checks, and proof that accepted true-orderflow paths did not change. Terminal/Tester execution is prohibited.

The Python availability reference mirrors the copy-evidence predicate. Naked tick lists or omitted completion receipts can show data presence but remain unqualified. Counts, times, errors, boundaries, provenance, snapshot state, and synchronization fields are validated strictly; booleans, fractional/negative/non-finite counts, and malformed receipts fail closed. The compile-only MQL harness exercises the same predicate included by the audit service; it is never executed and establishes no runtime parity.

Still not authorized: data collection in this lane, numerical strategy judgement, backtesting, optimization, BWD/HOLDOUT/Model4, Template binding, FamilyID/LAB_ENTRY/wrapper/default/risk changes, deployment, DEMO/LIVE, or trading. A separately frozen experiment contract is required before any performance work.
