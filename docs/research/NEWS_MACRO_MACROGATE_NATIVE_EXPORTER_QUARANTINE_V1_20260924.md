# News/Macro — MacroGate Native Exporter / DST-Quarantine V1 — 2026-09-24

Status: PROSPECTIVE CONTRACT FROZEN / IMPLEMENTATION NOT YET ACCEPTED / NO PERFORMANCE.

Lane: `ct-news-macro-mg-native-exporter-quarantine-v1-20260924`.

Authority ceiling: exporter/parity qualification only. This milestone grants no MT5 strategy-performance, optimizer, BWD retuning, HOLDOUT, Candidate, Grade/KINT, runtime/deployment, DEMO/LIVE, risk/default, or trading authority.

## Frozen upstream identities

- canonical base: `4219785c6f4cc6c0f38ec3cdf92869160eb522ca`
- accepted causal replay head: `5cff69e3d91f313a43c5ca6dae04fe06139fc50e`
- accepted historical native-parity head: `5e84dd3e7c662e80e631d7f9e72903d0ba2420c6`
- accepted explicit-UNKNOWN core-seam head: `5d6713cdc6b81191dc199f269bbc78789155c388`
- causal timeline SHA256: `44ed3c16451bf9d8e9066d1f552939c62d3c0bfcb1c9059613ad4150d963ed5f`
- causal manifest SHA256: `436baeeb45d1aba7d5176473dbc462963e43d1b31937e3fcbdf16ad76771d3e1`
- current `MacroGate_Core.mqh` SHA256: `afb74e22f75af3053d56ef6e8a485987fdc951f0995e44e91af91e6142778a0a`
- current `LabCore.mqh` SHA256: `92625d564f3eb461bd7d603c33633b0932e873d15267fb01cb94a98f4377039d`
- broker-clock contract SHA256: `ce472070a96b970ea280aa672988bc8c05207b9ded9234c86b08e49703737a37`
- accepted P4B normalizer SHA256: `cad32322e70fed379dc1ee8e19755d8256b29828fd4ccc3ea022fde19b1a34dd`
- pre-change exporter SHA256: `4476090ce2188333180387ee656df154946519d258d850b4d745b694df633906`
- pre-change exporter tests SHA256: `c25f0a9ed7330c012fceacd4818486e0d26a139bcd6022f0f5c6d7eee82e720c`

The current `MacroGate_Core.mqh` Git blob is byte-identical to the accepted core-seam head. `LabCore.mqh` is newer and is therefore bound independently at the current canonical base.
## Frozen ThinkMarkets quarantine timing semantics

The broker-lineage clock contract remains: stable standard-time server dates use UTC+2; stable daylight-saving server dates use UTC+3; the accepted transition server dates are `UNKNOWN_DST_TRANSITION`; no intra-day switch instant is guessed.

For each accepted transition server date:

1. Export exactly one explicit native `UNKNOWN` marker at `00:00` **server time** on that transition date.
2. The marker timestamp is a server-date boundary marker, not a claimed UTC-to-server conversion and not a guessed DST switch instant.
3. Quarantine starts inclusively at that `00:00` marker. `MG_RowAsOf` must select `UNKNOWN` from that point until a later recognized row becomes causally available.
4. Quarantine ends exclusively at the timestamp of the first later causal row whose UTC -> server mapping is stable, unique, and round-trips exactly under the accepted clock contract.
5. The following recognized row is exported at its actual stable mapped server time; it is never pulled backward to server midnight. Therefore UNKNOWN may remain selected for the first UTC+2/UTC+3 hours of the following stable server date. That extension is causal availability, not an extra guessed DST interval.
6. The transition causal row remains traceable in evidence by its exact source UTC interval, source state, RI, flags, transition server date, clock rule and provenance hashes. The native state presented to MacroGate for the quarantine interval is only `UNKNOWN`.
7. The previous recognized row cannot persist through the marker. In tester semantics, explicit UNKNOWN is retained, selected by RowAsOf, and `MG_Tick` clears MacroGate-owned BLOCK and LOTMULT state then returns.
8. The next accepted recognized row resumes ordinary MacroGate state/trigger semantics without reset or fabricated intermediate state.
9. There is no gap or overlap in RowAsOf selection: prior recognized row -> UNKNOWN marker -> next recognized row.
10. Malformed or unrecognized state text remains invalid/skipped; it never becomes a clear instruction.

The native CSV remains server-time with `_MG_OffsetHours=0`. Probability remains `null`; confidence remains source/agreement semantics only and is not performance-derived.

## Required transition cases

Exactly these 12 broker transition server dates are required: 2020-03-08, 2020-11-01, 2021-03-14, 2021-11-07, 2022-03-13, 2022-11-06, 2023-03-12, 2023-11-05, 2024-03-10, 2024-11-03, 2025-03-09, 2025-11-02.
The 2024-11-03 case is adversarial and mandatory: the source causal state is `RISK_OFF`, the preceding retained native recognized state is `NEUTRAL`, and the accepted result must expose `UNKNOWN`/inactive behavior rather than prior NEUTRAL or fabricated RISK_OFF during quarantine.

## Deterministic acceptance contract

Acceptance requires all of the following on one clean exact head:

- fail-closed binding of every frozen dependency hash above;
- causal input interval continuity with no gap/overlap;
- exact stable UTC -> server -> UTC round-trip;
- exactly 12 transition-date quarantine records and exactly 12 transition UNKNOWN markers;
- native rows strictly ascending and unique;
- all 2,192 causal daily intervals represented either by a stable recognized row or a transition UNKNOWN marker;
- accepted-current tester core semantics shown to retain explicit UNKNOWN, clear BLOCK/LOTMULT on selection, skip malformed INVALID state, and resume on the next recognized row;
- explicit proof for 2024-11-03 that prior NEUTRAL does not persist;
- no fabricated `NEUTRAL`, `RISK_ON`, `RISK_OFF`, or `STRESS` on a transition date;
- probability `null` and no performance authority;
- generated native CSV, quarantine evidence, source-bound manifest and implementation hashes bound by SHA256;
- deterministic regeneration into two fresh output directories yields byte-identical artifacts/hashes;
- malformed-state and dependency-drift negative tests fail closed.

No strategy-performance run is part of this acceptance. A no-trade native fixture is only needed if static/current-core binding plus already accepted core-seam evidence cannot prove the parser/action contract.

## Review and repair budget

After deterministic gates pass, freeze one clean exact candidate HEAD and immutable evidence set. Run exactly one separate read-only acceptance-grade GPT Scrutiny. The reviewer focuses on DST timing, UNKNOWN representation, current-core binding, prior-state clearing, malformed fail-closed behavior, provenance, continuity, deterministic generation and authority boundaries.

At most one bounded Repair1 is available for a genuine in-scope material defect, followed by impacted deterministic checks and one targeted exact-head recheck. No replacement lane or review budget reset is allowed.

## Downstream gate

Only when both `NATIVE_EXPORTER_QUARANTINE_ACCEPTED` and `NATIVE_PARITY_QUALIFIED` are established may Control Tower consider a separate prospective BASE / REAL_GUARD / PLACEBO preregistration. This document does not select an EA parent or authorize that experiment.
