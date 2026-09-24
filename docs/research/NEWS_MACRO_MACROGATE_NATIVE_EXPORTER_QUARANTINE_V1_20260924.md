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

## Recovery and deterministic qualification - 2026-09-25

The prospective sections above remain unchanged. Their exact pre-implementation commit is `e1693a8f25d13915a8c3db1ef30b43d1b4e7caa6`.

Author job `ct-news-macro-mg-native-exporter-quarantine-author-r4-20260924` reached durable `TIMED_OUT` without an author result or commit. On reconnection, its runner/child/postcondition were dead and no matching Codex descendant remained. The controller preserved the two source files and diff, then consumed the completed implementation rather than relaunching an author. Earlier CLI/model-launch failures and the timeout remain historical evidence; this milestone's source Repair1 is UNUSED.

Current implementation identities:

- exporter SHA256: `ec22220fb7995518fd71c694dca43008638bd8692386cba54283002c9a9163d1`
- exporter tests SHA256: `91a7aa5101f49eac48af871af7da006c6f1c53a96c5a6eaa0511ce27052558b3`
- native CSV SHA256: `6aba7e1e7bd01e82469db580ae666c9903803c4fb8d206f4cc44f8aab8afbb2a`
- quarantine CSV SHA256: `545c4e5f684ea8a5c4b231bf57360e65551f2acb8ef4bf3fd685dd211faa59d9`
- qualification evidence manifest SHA256: `59818dcb7363c89d9c476f74a2a49d01df2317bdf3e94643dd5ec3ad5d01b6ed`

Evidence root: `D:\EA_LAB_CONTROL\evidence\news-macro-mg-native-exporter-quarantine-v1-20260924\qualification-20260925`.

Actual deterministic results: News/Macro 196/196 tests, zero failures/errors/skips; 2,192 native rows = 2,180 stable exact round-trips plus 12 UNKNOWN markers; 12/12 transition cases; 19,092 independent interval/edge probes; 6/6 actual dependency-byte drift refusals; two fresh regenerations byte-identical to each other and the preserved r4 regeneration_c/regeneration_d artifacts. Every source interval is traced in SOURCE_NATIVE_TRACE.json. The independent checker reads actual CSV rows rather than accepting author PASS booleans.

Every March quarantine resumes on the next server date at 03:00; every November quarantine resumes at 02:00. The interval is inclusive at the transition's 00:00 marker and exclusive at that next stable row. On 2024-11-03, prior NEUTRAL is replaced by UNKNOWN, then RISK_OFF resumes at 2024-11-04 02:00.

### Native proof reuse and limitations

REUSED_NATIVE_BINDING.json binds the prior independent `SCRUTINY_PASS / HIGH` review of core seam head `5d6713cdc6b81191dc199f269bbc78789155c388`, its focused static/compile/no-trade PASS, and its hash-verified TPL Contract1 8/8 receipt. MacroGate_Core.mqh, MacroGate_UnknownSeam_Test.mq5 and its runner remain byte-identical to that accepted head. LabCore.mqh is separately bound to current canonical bytes. No new compiler/tester/live run was performed by recovery, and no existing MT5 owner was interrupted.

The qualification combines the new exporter/clock/CSV proof with the unchanged accepted native parser/action seam; Python checks are not represented as newly executed native MT5 assertions. The original native fixture exercised one magic; multi-magic clearing remains source-verified through the unchanged loop. Live preservation is source-verified, not a new live run. UNKNOWN means MacroGate inactive/ungated, not a trading-safety certification. RI/flags in UNKNOWN rows are source-provenance-only auxiliaries ignored by the bound native core, not contemporaneously available macro signals or an available_at claim.

The raw input/core/clock/normalizer hashes fail closed on drift. The manifest also binds the exporter/test implementation bytes and generated artifacts. Tool-emitted `native_parity_qualified=true` describes the bounded deterministic candidate; project acceptance additionally requires the one independent exact-head review and eligible canonical integration. At this candidate commit, those final controller steps are pending.

### Reproduction and evidence consumption

Use the installed portable Python via `scripts/use_python.ps1` and `Assert-PortablePython -Provision`. Run the namespace-compatible News/Macro tests with the preserved recovery_tests_v2_20260925.py external runner. For actual exports use `python -m tools.news_macro_lab.macrogate_native --timeline <accepted CSV> --manifest <accepted manifest> --repo <exact worktree> --out <fresh output directory>`. Preserve existing output directories; never overwrite accepted or negative evidence.

The qualification manifest includes the executed independent checker, all 12 case results, full source/native trace, raw generated CSV/manifests, six mutated-dependency refusal cases, the 196-test log, and copied upstream native review/TPL/focused evidence. Controller freeze/review/push receipts remain in the same milestone evidence root. They must bind the actual clean candidate HEAD; a prose readiness label or historical author success is not an acceptance receipt.

Authority remains source/parity-only: performance NOT_RUN, probability null, can_execute=false, HOLDOUT unspent, no EA parent selected and no A/B execution. Only after both independent exporter acceptance and native parity qualification may a separate prospective A/B contract be considered.
