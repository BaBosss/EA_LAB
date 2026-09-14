# Forward Alpha Real-Source Adapter Contract V1

Status: `SOURCE_GAP / BLOCKED_C_ENVIRONMENT_DEPENDENCY / RESEARCH_ONLY / NO_IMPLEMENTATION_AUTHORITY`

Canonical inspection base: `75c4f9104a48e774d495368278077fcb85c2d8d3`.
Accepted Forward Alpha owner: `docs/research/FORWARD_ALPHA_DISCOVERY_MODULE_V1.md` at canonical milestone `93557cf207f5d6d1201da870f99f0b5334bd3bf1`.

## 1. Decision

EA_LAB does not currently expose a qualified canonical price/quote/OHLC source that can safely produce Forward Alpha observations and later settlements with explicit provenance and `available_at` semantics.

Therefore this milestone stops before creating `tools/control_center/forward_alpha/adapters/*` and before adding a Forward Alpha panel to Monitor V3.1.

This is a source-qualification blocker, not a Forward Alpha product failure and not a strategy verdict. It grants no Candidate, Grade, KINT, HOLDOUT, optimizer, runtime, risk/default, DEMO/LIVE, deployment, trading or promotion authority.

## 2. Existing sources inspected

- `tools/control_center/contracts/SOURCE_MAP.md` and `source_map.json`: research/report evidence plus News/MRIS/guard seams only.
- `tools/control_center/guard_adapters/feeds.py`: pinned historical News/MRIS/Macro projections; runtime effectiveness remains `UNKNOWN`.
- `portfolio/news_week.csv`: event clock exists, but qualified producer observation/availability time does not.
- `portfolio/mris/regime_state.json`: producer UTC snapshot and dimensionless regime/risk context; not a price series.
- `portfolio/EA_LAB_mris_regime.csv`: historical regime timeline; row timestamps are not proof of source availability/freshness.
- `portfolio/live_deals/*`: historical trade/deal evidence, not a pre-outcome market observation source.
- Control Center CC03 design: explicitly expects future `qualified price/MRIS observations`; that seam is not implemented by current canonical sources.

## 3. Minimum source qualification

A future source may be adapted only when all of the following are source-owned or independently bound; the adapter must not manufacture them:

1. Stable `source_id` and exact source object identity.
2. Exact raw-byte SHA256 plus durable source reference; if Git-backed, exact canonical SHA.
3. Explicit UTC `available_at` describing when the observation became available to the research process, not filesystem mtime, export time guessed after the fact, or a later ingestion time substituted silently.
4. Explicit market timestamp for the quoted/barred price and an unambiguous price basis: bid, ask, mid, last, bar open/close, or another named basis.
5. Symbol and timeframe/source interval with broker/source namespace retained where material.
6. Frozen pre-outcome context bytes whose SHA256 becomes `snapshot_sha256`; regime/features may be included only when source-bound at observation time.
7. A later settlement source independently bound to its own raw bytes, provenance and `available_at`.
8. The settlement price must use the same declared price basis as the observation or a separately accepted conversion contract.
9. Source coverage/gaps must remain explicit; missing bars, market closures, ambiguous clocks or unavailable extrema cannot be filled by interpolation without a separate contract.
10. No source may claim trusted timestamp/witness guarantees beyond what its producer actually supplies.

The observation source and settlement source may be the same provider, but their exact evidence objects and availability bindings remain independent. A later file containing both start and end prices is not sufficient proof that the start observation existed pre-outcome.

## 4. Adapter output contract

A qualified adapter's smallest useful output is the existing strict Forward Alpha envelopes; it must not add a second ledger or score layer.

Observation output must provide exact source descriptor plus `forward_observation/1` payload fields already owned by Forward Alpha V1: observation ID, observed time, symbol, timeframe, strategy/family/variant/regime identities, direction, elapsed-seconds horizon, config hash or explicit `UNKNOWN`, `RESEARCH_ONLY`, snapshot hash and positive finite reference price.

Settlement output must provide `forward_settlement/1`, bind the exact observation hash, exact horizon endpoint and end price, and optionally source-covered high/low together. MFE/MAE stays unavailable when source extrema coverage is unavailable.

## 5. Mandatory adversarial acceptance for a future adapter

A future implementation must refuse or preserve uncertainty for at least:

- source bytes/hash mismatch or changed producer semantics;
- malformed or duplicate source fields;
- source `available_at` after the claimed observation time;
- future source availability relative to query `as_of`;
- wrong observation/context hash;
- duplicate exact observation/settlement versus divergent duplicate bytes;
- settlement before or after the exact contracted horizon endpoint;
- observation/settlement symbol, price-basis or source-lineage mismatch;
- missing/ambiguous market clock, unsupported timezone or session boundary;
- missing bars/source gaps, unavailable extrema and open observations;
- negative and zero forward outcomes, which must be retained exactly like positive evidence;
- stale/as-of projections and unsigned outcomes without fabricated directional hit statistics;
- forbidden authority fields or any automatic Alpha threshold, Candidate/PASS recommendation, PF/Grade mapping, optimization trigger, lot/risk change or trading control.

Focused Forward Alpha tests and impacted Control Center tests remain mandatory after any adapter lands. Monitor tests become mandatory only after an independently accepted honest data seam exists.

## 6. Monitor gate

Monitor V3.1 remains the single owner-facing application. A Forward Alpha panel may be added only after the source adapter is independently accepted and a real source-bound ledger/snapshot can be generated without fixture substitution.

Until then, no empty/fake Alpha card, fabricated regime/confidence, ranking score, STRONG/WEAK label or sample threshold is permitted. Missing source capability is represented by this contract and project state, not hidden by presentation.

## 7. Direct consumer and next action

Direct consumer: Control Tower source qualification before Forward Alpha adapter implementation and before Monitor integration.

Next action is exactly one of:

- `QUALIFIED_SOURCE_AVAILABLE`: open a new bounded adapter contract against exact source bytes/provider semantics; or
- `SOURCE_GAP_REMAINS`: keep Forward Alpha real-source adapter and Alpha Monitor panel blocked and continue unrelated READY work.

No MT5/VPS/runtime activation is requested or authorized by this contract. A source that requires new live collection, Scheduled Task, terminal attachment or external paid credentials needs its own authority/activation contract first.
