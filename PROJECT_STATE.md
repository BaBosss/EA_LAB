# PROJECT_STATE — EA_LAB current canonical state (AI START HERE)

> **Role:** current status / accepted decisions / forward plan.
> **Last converged:** 2026-08-30 Asia/Bangkok.
> **Canonical bytes:** always verify the current pushed `origin/master`. Do not infer canonical state from a dirty worktree, index, chat transcript, generated dashboard, or this file's historical Git SHA.
> **History:** `PROJECT_HISTORY.md`. Historical snapshots and incident narratives are not current state unless explicitly restated here.
> **Authority:** `AGENTS.md` owns roles, permissions, approval boundaries, one-writer rules, review separation, and standing push authority.
> **Work queue:** `AGENT_TASKBOARD.md` is the manifest; exact active ORDER blocks live in `taskboards/active/P01.md`, `P02.md`, and `P03.md`. `TASKBOARD_DIGEST.md` is generated navigation only.

---

## 1. CURRENT PROGRAM STATUS

### 1.1 Mainline — VPS DEMO Deployment / Forward-Test

**ACTIVE — setup/acceptance complete; observation continues.**

Existing accepted ORDER-353 DEMO binding:

- target: `463666728|990026`
- EA: `(TRD)_SuperTrendFlip_rev05`
- logical runtime: `BTCUSDm,H4`
- lot: `0.01`
- attach identity: `epoch-1`
- D: `CONFIG_MATCH / PASS`
- E: `PASS`
- F: `HASHED / OWNER-ATTESTED`
- G3 target runtime identity: `PASS / WIRED`
- accepted telemetry state: `FRESH`
- forward state: `DEMO_DEPLOYED_AWAITING_FIRST_TRADE`
- accepted 2026-08-24 handoff evidence: `0` qualifying closed deals for magic `990026`
- `first_trade_epoch = null`

The `0` above is a dated accepted evidence point, not a live counter. Current telemetry must come from the canonical monitoring/evidence pipeline.

**Operational consequence:**

- ORDER-353 deployment/setup acceptance is complete. Do not reopen pre-deployment attachment, attestation, config verification, or target runtime-identity work without a concrete regression.
- Do not force a trade.
- Do not start the judge clock until a genuine qualifying post-attach trade establishes `first_trade_epoch`.
- The next state transition is evidence-driven only.
- LIVE / DEMO→LIVE remains a separate owner hard stop.
- Global monitoring remains `DEGRADED_MONITORING`; target G3 `PASS / WIRED` does not make global monitoring GREEN.

### 1.2 Factory research

- Factory candidate: **NONE SELECTED**.
- Factory vNext Design Freeze / MVP Pilot Contract: **ACCEPTED / CANONICAL as a sidecar implementation source**.
- Factory vNext MVP Sidecar implementation + offline pilot package: **ACCEPTED / CANONICAL as `NON_AUTHORITATIVE_SIDECAR` evidence only**.
- EA_LAB Second Brain Foundation: **ACCEPTED / CANONICAL / `RESEARCH_ONLY`** at `145cb5e3d932716780082bcdd24aa9093a18407e`. `knowledge/` stores traceable source/research/mechanism/synthesis material; existing QI-1 strategy/experiment/evidence owners remain authoritative, and no second strategy registry, experiment registry, independent negative-experiment truth, QI-2+, Factory launch, runtime, risk, deployment, or trading authority is created.
- Second Brain supplied Drive corpus ingestion: **ACCEPTED / CANONICAL / `RESEARCH_ONLY`**. `knowledge/01_sources/drive_intake_20260829.csv` covers 26 direct PDF objects: 21 promoted trading/research sources, 3 rejected unrelated sources, and 2 byte-identical `151 Trading Strategies` objects retained as duplicate evidence; `PENDING_CLASSIFICATION = 0`. Source/receipt hashes bind the completed intake, no Drive object was moved or deleted, and the next consumer is source-traceable `TESTABLE_HYPOTHESIS` generation through the existing research skills—not automatic Factory/EA promotion.
- Implemented sidecar surfaces include deterministic Home/Window/Run identity, Parameter Surface V1, Telemetry V1, Range Generator V1, Derived Metrics V1, Grade/Confidence evidence scaffold, graph-first five-page report, SuperTrendFlip BTCUSD/H4 offline adapter, Parameter Semantics, Template Variant Generator, Operationalization Runner, MT5 set compatibility adapter, and the historical pilot artifact package.
- The MT5 set compatibility adapter remains NON_AUTHORITATIVE_SIDECAR: it consumes canonical ParameterProjection directly, preserves baseline layout/comments, disables optimization for SNAPSHOT_ONLY, refuses unknown/removed/ambiguous/malformed inputs, and never mutates terminal files or production policy.
- Factory vNext MT5 Set Consumer Pilot: **ACCEPTED / CANONICAL expected-refusal sidecar evidence**. Using the real `STF_BTC_H4_rev05_off.set` baseline, the consumer deterministically refuses before emitting a proposed set because no canonical SuperTrend `VariantBuildPackage` exists, `KINT-001` remains OPEN, and affected parameters remain `SEMANTICS_REQUIRED`; the pilot records `mt5_terminal_touched=false` and `strategy_tester_invoked=false`. Evidence is `factory/vnext/pilots/supertrend_rev05_btcusd_h4_holdout26h1/mt5_set_consumer_manifest.json`.
- The accepted pilot uses existing `(TRD)_SuperTrendFlip_rev05`, logical `BTCUSD`, ExecutionTF `H4`, and the 2026H1 historical holdout with 100% real-ticks evidence. Exact pilot IDs, hashes, and measured counts are owned by `factory/vnext/pilots/supertrend_rev05_btcusd_h4_holdout26h1/pilot_manifest.json` and `artifact_index.json`.
- Current Factory production policy/verdict/optimization/risk/deployment authority is unchanged. No Factory candidate promotion, deployment/LIVE authority, risk/default change, or strategy trading-semantics change is created by this milestone.
- `KINT-001` remains intentionally OPEN. SuperTrend parameter semantic metadata remains unresolved; affected Range Generator evidence remains `SEMANTICS_REQUIRED`.
- Factory vNext BaselineCoverage: **ACCEPTED / CANONICAL**. When coverage is present it binds every physical baseline key exactly once by exact PID identity using `PROJECT` or `PRESERVE_SNAPSHOT`; duplicate/malformed/missing/case-mismatch/PID-mismatch conditions REFUSE, and legacy behavior is unchanged when coverage is absent.
- Boss14 H01 first full-green Factory sidecar: **ACCEPTED / CANONICAL** at `376289d4cdf8b8f37e711a59307402c8343eb1e7`; reference package `VPKG-84cdbe53dc67d26ad078b385` has 142 bindings, 31 ParameterProjection rows, 116 physical baseline keys, BaselineCoverage 116/116 (30 PROJECT + 86 PRESERVE_SNAPSHOT), zero MT5 compatibility refusals, and authority `NON_AUTHORITATIVE_SIDECAR`.
- Boss14 downstream quarantine: `ParameterProjection - BaselineCoverage.projection_parameter` must be checked explicitly. For the accepted package the difference is exactly `P72000 / UseMiddlePathVeto`; it has no physical baseline key, `safe_range=null`, and `locked_value=null`, so it must not enter Range Generator / optimizer semantics until explicitly resolved.
- Boss17 frozen Factory registration: **ACCEPTED / REVIEWED / CANONICAL** at `f27f992707aa8eb3c358a2e7c45e28e3d0078491`. `B17-H01-r1` / architecture `52921084a24c3ea9` has **147 logical ParameterBinding rows**, **0 TUNABLE**, and no optimizer authority; physical baseline remains **159/159**, with P73000-P73011 compatibility identities physical-only / non-logical.
- Boss17 prerequisites are canonical and closed: R0-FINAL `c26e62cf1b4d05ab1925140a10ba9cb94a9a65af`; R0-GUARD `e09323d480b6c8c95ec431f3b1a295af62ca3157`; Boss17/Boss18 activation `10200cf074a1e24a47eb87afebb62b634f254e54`. Do not reopen them without a live regression.
- Boss18 remains **FAIL-CLOSED / NOT REGISTERED**: activation and physical coverage are complete, but no tracked exact pre-result configuration pin supports retrospective Hypothesis/ParameterBinding registration. Do not fabricate one.
- Boss17 first-green Factory vNext package: **ACCEPTED / REVIEWED / CANONICAL** at `94b4bc6be58eabd391933a9079532a4c12911272`. The frozen `B17-H01-r1` package preserves 147 logical bindings versus 159 physical baseline inputs, exposes 31 projection rows all `LOCKED / SNAPSHOT_ONLY`, records BaselineCoverage 159/159 (31 PROJECT + 128 PRESERVE_SNAPSHOT), keeps P73000-P73011 physical-only/non-logical, and adds no optimizer/runtime/risk authority. **No optimization** until a new prospective Boss17 revision explicitly pre-registers optimizer authority/ranges.
- Boss19 AdaptiveTrendGrid V0 strategy verdict remains **PARKED-VERIFY(user)** from the original bounded validation: the historical reference center is `StepATR=0.30 / FastMA=20 / SlowMA=50 / TP_ATR=1.50`, BWD robustness/participation failed, and no candidate/deployment authority was created.
- Hermes H2 small-pilot qualification: **ACCEPTED / PASS / H3_READY** at reviewed head `d5dbd31a44be84e0f396dd8ffedc7125f15b3388`. All six unique authorized Model-1 MAIN/BWD runs (XAUUSD H4, EURUSD H1, AUDUSD M15) are COMPLETE and full-window eligible; set/EX5/receipt/leverage identity held, optimization was `0`, repository bytes stayed clean, and HOLDOUT `2026H1` remained UNSPENT. H2 is mechanical execution qualification, not strategy promotion.
- Hermes H3 Boss19 broad fixed-config qualification: **ACCEPTED / PASS / BROAD MATRIX COMPLETE** on contract head `47c7732048406277096c1ccc31734b4122ae7285`. Exactly 36/36 authorized Model-1 cells across 6 symbols x 3 TF x MAIN/BWD are COMPLETE and full-window eligible; deterministic result package SHA256 is `3d62d6d358831dc3897357d3d2008e9c0f1c9211716844112f8af96f79c7eeb2`. Independent Qwen milestone review returned PASS/HIGH; the C13 provider timeout occurred before MT5 launch and the accepted fallback produced one MT5 evidence run with no replay. HOLDOUT `2026H1` remained UNSPENT, optimization remained NONE, and repository bytes stayed clean. H3 unlocks only frozen-timeline regime attribution; it grants no candidate/risk/deploy authority.
- Boss19 P4B regime attribution execution: **BLOCKED / RESEARCH-ONLY** with `BLOCKED(DATA_ENVIRONMENT_MISSING_IMMUTABLE_HISTORICAL_MARKET_INPUTS)`. Repaired fail-closed intake verifies the exact accepted H3 package SHA, exact 36-cell manifest/grid and 36 report-file inventory without opening H3 outcome/deal content before the timeline gate. No immutable historical macro plus exact tester-data-identity Symbol×TF OHLC input package was supplied, so no classifier timeline or P&L attribution was produced. Unit-attribution suitability remains unassessed until after a timeline is hash-frozen. Evidence: `docs/research/BOSS19_P4_REGIME_ATTRIBUTION_RESULTS.md`. P4A remains frozen; HOLDOUT/optimization/runtime/risk/deploy authority = NONE.
- B16 H03 fixed-config confirmation: **ACCEPTED / COMPLETE / `POSITION_ENGINE_DEPENDENT_OR_UNKNOWN`**. Source-first parsing of accepted H02 bytes reconciled MAIN PF 4.08 / 79 / EqDD 6.27% and BWD PF 1.44 / 148 / EqDD 8.29% without an MT5 rerun. Multi-entry cycles supplied 79.80% MAIN and 87.89% BWD gross profit, triggering the contract's higher-precedence position-engine condition. Strategy quality was not reassessed and H04 is NOT unlocked. Evidence: `docs/factory/B16_H03_CONFIRMATION_RESULTS.md`. No tuning/optimization/HOLDOUT/candidate/DEMO/LIVE/risk authority.
- Final numeric Grade/Confidence thresholds remain provisional/unratified; sidecar verdict/build-potential outputs remain non-authoritative.
- Research reporting cadence is now **graph-first but staged**: every evidence-producing experiment leaves a durable research record, R1 discovery uses compact aggregate heatmap/scatter views, R2-R4 add mechanism/optimization/robustness visuals as needed, and Candidate/DEMO requires the full graph pack. Canonical owners: `docs/research/EA_REPORT_LADDER.md` + `docs/research/EA_REPORT_SCHEMA.md`.
- Per-EA workflow diagrams are durable research artifacts, not chat memory. Mechanism/child work uses a source-bound workflow view; Candidate/DEMO requires the applicable strategy logic, state-machine and risk/position-engine diagram set under `docs/research/EA_WORKFLOW_DIAGRAM_STANDARD.md`. Diagrams remain `VISUAL_ONLY_NO_AUTHORITY`.
### 1.3 Accepted control-plane capabilities

The following are accepted/canonical and should not be generically re-audited without a reproducible regression:

- Strategy & Evidence Consolidation M4.
- EA_LAB Harness v1.
- Lane Ownership / Shared Registry v1.
- active taskboard split: manifest + `taskboards/active/P01.md` / `P02.md` / `P03.md`.
- LNWJUD Local Execution Plane, M3 repository/identity work, and A-PATH observe bridge.
- LNWJUD Scheduled Continuation module: **ACCEPTED / CANONICAL / CLOSED** repository orchestration capability for durable next-iteration resume state. It is `NO_NEW_AUTHORITY`; do not reopen it without a concrete regression. It does not activate M3 or start a tunnel, and does not deploy, attach MT5, trade, enable LIVE, or change risk/defaults.
- Remote Desktop Commander persistence / zero-touch reboot path.
- POST-OPUS M0/M1 trust repairs.
- VPS DEMO preparation/hardening batch and PREDEV generic pre-development hardening.
- Long Job Runner durable detached execution support.
- Hermes H1 Golden Replay qualification: **ACCEPTED / PASS** on the exact safe-reader path. Final mechanical check was `OVERALL=PASS`; no new MT5/tester run occurred, no repository mutation occurred, HOLDOUT `2026H1` remained UNSPENT, and Hermes gained no strategy/risk/runtime/deployment authority. The accepted execution lineage is rooted in canonical `f1dd0e9b`.
- Hermes H2 small-pilot qualification: **ACCEPTED / PASS** after independent exact-head review at `d5dbd31a`; six unique authorized runs were admissible, the one Control-Tower duplicate dispatch was non-evidentiary/non-disqualifying, and downstream status is `H3_READY`.
- Hermes H3 broad-matrix qualification: **ACCEPTED / PASS** on canonical contract head `47c77320`; 36/36 full-window evidence cells are complete, HOLDOUT is UNSPENT, optimization is NONE, and frozen-timeline regime attribution is READY as the sole unlocked downstream research consumer.
- Execution Reliability Pack V1: durable-by-default worker launch, exact-head/bootstrap/hash checks, inspect-before-retry fail-closed recovery, provider-aware launcher policy, postcondition-aware completion, timeout/cancel enforcement, and owned process-tree cleanup.
- Ponytail controlled-adoption protected-directory repair: **ACCEPTED / CANONICAL**; original protected-launcher defect resolved; final deterministic suite 25/25 PASS and targeted different-family rereview PASS; `authority_granted=false`; non-.ps1 protected-name hardening remains PARKED/FUTURE.
- Diagram Design module: **ACCEPTED / CANONICAL** tooling/docs support only; it grants no Factory/runtime/deployment authority.
- EA_LAB Portfolio Control Architecture v1: **OWNER-RATIFIED / CANONICAL / NO RUNTIME AUTHORITY**. It defines the scalable EA -> Cluster -> Port -> Global Supervisor -> Human hierarchy, deterministic local-safety/ownership invariants, bounded control-state/data-contract direction, restart reconciliation, regime/portfolio-control separation, staged automation and owner-operable dashboard contract. Canonical owner: `docs/architecture/EA_LAB_PORTFOLIO_CONTROL_ARCHITECTURE_V1.md`. Numeric risk defaults, runtime activation, LIVE authority, exact Grade thresholds and KINT-001 remain separately gated/unresolved.
- Ziplime research/data-preparation module for the Factory vNext research sidecar.
- MacroGate RegimeOnly readiness: **ACCEPTED / CANONICAL** repository readiness only; the Windows Scheduled Task is NOT CREATED and VPS runtime scheduling is NOT ACTIVATED.
- Traycer authenticated-A2A OFFLINE evidence cage: **ACCEPTED / CANONICAL**; real browser/device authentication and functional A2A remain **E OWNER-EXTERNAL**.

Ziplime remains research/data-preparation support only; it does not migrate current Factory policy or grant deployment/promotion authority.

MacroGate regime-only transport is canonical repository capability, but persistent VPS regime-only automation is **not yet deployed by this repo milestone**. Regime-only operation must not fetch/delete/publish NewsGuard; NewsGuard/REAL runtime remains intentionally untouched unless separately authorized.

Traycer code/tooling foundation is accepted, but browser/device authorization and authenticated functional A2A acceptance remain **E OWNER-EXTERNAL / incomplete** (HOST_RPC_UNVERIFIED, E_AUTH_NO_CREDENTIALS). Traycer does not replace Control Tower, Lane Registry, Harness, constrained Hermes routing, Git authority, or owner hard stops.

Harness is a deterministic router/evidence validator only. Successful Harness output always has `authority_granted=false`; it never grants deployment, runtime attachment, trading, LIVE, risk/default, owner-attestation, QI-2+, or governance authority.

Lane Registry owns current writer/reviewer lineage. Do not copy live lane states into this file as durable facts.

### 1.4 Monitoring

**Global state: `DEGRADED_MONITORING`.**

Monitoring is fail-visible. Stale/unreadable/unbound evidence must not be presented as current measured truth. ORDER-353 target G3 is `PASS / WIRED`, but that is target-specific and does not override the global G2 state.

---

## 2. CURRENT BLOCKERS / HARD STOPS / PARKED WORK

### 2.1 Current blockers
- No accepted canonical product defect currently blocks the ORDER-353 setup/acceptance state.
- Forward-Test is waiting on genuine market/trade evidence, not on a repo repair.
- Global monitoring remains degraded and must be represented honestly.
- The dirty/diverged primary workspace D:\EA_LAB is not canonical and is not a safe integration writer. Preserve unrelated dirty/staged/untracked bytes.

Support/runtime pending items that do **not** block the current Forward-Test mainline:
- Traycer browser/device authentication and authenticated A2A functional acceptance remain owner-external.
- Persistent MacroGate regime-only VPS automation remains a later separately-authorized runtime task; repository integration did not deploy or schedule it.

For current writer ownership or environment-dependent support lanes, read Lane Registry dynamically:
`D:\EA_LAB_CONTROL\lanes\registry-v1\`.

### 2.2 Owner hard stops

Fresh owner approval is required for:

- any new deployment/runtime attachment, detachment, or re-attachment outside the already-accepted existing ORDER-353 DEMO binding
- trading / real-money activity
- LIVE / DEMO→LIVE
- risk/default changes
- consequential new strategy/risk semantics
- owner signature/attestation
- consequential governance/approval-boundary or scope changes
- QI-2+
- destructive cleanup outside bounded fixtures
- force push / history rewrite
- irreversible strategic decisions

Normal FF-compatible canonical push is not itself a hard stop when `AGENTS.md` gates pass. Local Strategy Tester/backtest is not deployment/trading.

### 2.3 Parked / future / decision-ready

Cleanup Batch 1 is **PARTIAL_SAFE / CLOSED FOR NOW**: 129 HIGH-confidence objects requested, 44 removed, 83 drift-skipped, 2 failed safe, and approximately 14.842 GiB reclaimed. Cleanup Batch 2 is PARKED; do not requalify skipped items merely to reclaim more disk.

Do not dispatch without a direct consumer and the required authority:
- A6 task-scoped mutation bridge
- A-F3 `hypothesis_revision` in ExecutionKey/cache identity and cache-reuse semantics
- B-F4 fast-tier wiring without fresh measurement/direct consumer
- B-F5 Boss_16/Kangaroo OnTick/shared-pipeline semantics
- dirty-primary preservation/reconciliation
- physical legacy cleanup / M9
- ExpertMAPSAR / ExpertMAMA Model-4 / Zeus optimization / Candidate-5 risk semantics
- QI-2+
- other explicitly parked low-ROI hardening

M3 Secure Tunnel implementation/identity is preserved but runtime is intentionally STOPPED / NOT PRIMARY TRANSPORT. Remote Desktop Commander is the primary transport/operator surface.

---

## 3. STATE OWNERSHIP / ANTI-DRIFT INVARIANTS

One fact has one owner. Other surfaces point to it instead of hand-copying dynamic values.
| Fact | Canonical owner |
|---|---|
| current status / accepted active decisions / forward plan | `PROJECT_STATE.md` |
| roles / permissions / approval boundaries | `AGENTS.md` |
| active work queue | `AGENT_TASKBOARD.md` + declared `taskboards/active/P*.md` |
| generated taskboard navigation | `TASKBOARD_DIGEST.md` |
| historical narrative / superseded state / full provenance | `PROJECT_HISTORY.md` |
| owner big picture / factory philosophy | `VISION.md` |
| deployment inventory: account / EA / magic / status / kill / judge | `portfolio/DEPLOYMENTS.csv` |
| deployment artifact attestation expectations | `portfolio/ATTESTATION_MAP.csv` |
| account-level governance / sensor / SLA metadata | `portfolio/ACCOUNTS.csv` |
| deployment explanation / context | `DEMO_DEPLOYMENT_PLAN.md` |
| Factory backlog / coverage | `MASTER_BACKLOG.md` |
| EA registry / scoring / kill-reason | `EA_SCORECARD_AND_REGISTRY.md` |
| current writer/reviewer ownership | Lane Registry v1 |
| runtime/judge freshness and generated counts | current monitoring/control-room generated evidence |

**Dynamic-fact rule:** do not hand-copy portfolio row counts, account counts, judge dates, freshness ages, trade counts, or lane states into long-lived startup prose when a canonical generated/data source owns them.

If two current surfaces disagree, resolve the conflict against the fact owner above; do not average or choose the newest-looking prose.

---

## 4. BINDING ACTIVE DECISIONS
This is the startup-sized operative set. Detailed provenance, old wording, incidents, and superseded decisions are preserved in `PROJECT_HISTORY.md` and specialized canonical docs.

### 4.1 Execution / review / Git

- Owner approves **OBJECTIVE / SCOPE / ACCEPTANCE / HARD-STOPS**, not routine in-scope steps.
- Once bounded scope exists, proceed autonomously through deterministic inspection, implementation, focused/negative/regression tests, one bounded repair where permitted, integration, durable sync, and eligible FF push.
- PLAN ONCE / DISPATCH ALL: READY independent work may run in parallel; dependency PASS unlocks downstream work automatically.
- One acceptance-critical integration lineage has exactly one writer.
- Independent review binds an exact frozen clean HEAD. A moved HEAD invalidates the review.
- High-risk/core/execution/position/accounting/money/risk work requires the different-family review required by `AGENTS.md`.
- Canonical bytes come from current pushed `origin/master`; use explicit refs/clean isolated worktrees for canonical mutation.
- Never reset/clean/stash/restore/overwrite unrelated dirty/staged/untracked work as a side effect.

### 4.2 Strategy / evidence / tester rules still in force

- `VISION.md` owns the big picture; work that conflicts with it requires an explicit resolution.
- Current Factory policy remains authoritative; Factory vNext sidecar does not migrate it.
- MAIN backtest window is rolling 36 months and must not consume the holdout; re-pin on the accepted re-opt cadence.
- Search/selection must follow the canonical Factory/verdict/optimization contracts; do not invent a new bar from prose in this file.
- `KINT-001` is the explicit unresolved sample-floor conflict. Until a later policy migration resolves it, do not silently choose between contradictory active sample-floor formulations.
- Never issue DEAD/REJECT from one parameter set when the accepted rescue/last-optimize rules require further bounded search.
- LAST-OPTIMIZE-BEFORE-VERDICT remains binding for an EA that showed a pulse unless a structural-death exemption applies.
- Cap breach is resize-first; do not reject directly on DD/margin/deposit-load/MC-ruin while accepted resizing/min-lot/config alternatives remain.
- Model 2/open-price results are filter/diagnostic evidence only. Any trusted verdict number must meet the current higher-fidelity policy.
- Basket/grid/multi-position strategies must not use stitched-window WFA as if it were one continuous reality.
- Genetic optimization policy remains owned by the canonical optimization discipline: MT5 large-space coarse search must be followed by bounded complete fine-grid verification; top-1 spike selection is forbidden; BWD is not a search surface.
- A declared hypothesis revision must actually bind every swept parameter attributed to that revision; otherwise refuse attribution.
- `.set` compatibility is fail-loud. Unknown/removed keys are refusals; migration writes a new file and reports every change.
- `data_fingerprint` comparisons must include the accepted symbol-spec versioning requirements; comparisons across incompatible fingerprint versions refuse.
- Magic uniqueness is governed by the accepted global rule plus explicit legacy exceptions; never renumber an active legacy magic as a side effect.
- `ea_template/core/` changes retain their regression and review requirements. Do not alter Boss_14 direction semantics merely to create a two-sided instance.
- The accepted Engine-Edge class keeps its dedicated risk/validation cage and permanently-small-sizing semantics; it is not a generic bypass around edge gates.

### 4.3 Operate / portfolio rules still in force

- Demo observation is evidence collection, not permission to promote.
- Demo duration remains at least the accepted minimum; no shortcut to LIVE micro.
- Correlation policy remains: additive / watch / redundant bands are handled through portfolio sizing and slot decisions, not by pretending correlated legs are independent edges.
- ORDER-353 `990026` and `990025` are an A/B experiment, not independent diversification legs.
- Do not compare profit/PF across different terminal installs as if tester/install differences were absent.
- Current deployment facts come from `portfolio/DEPLOYMENTS.csv`; current attestation expectations come from `portfolio/ATTESTATION_MAP.csv`.
- No manual/forced trade may be used to manufacture a forward-test transition.

### 4.4 Governance / evidence hygiene

- `REVIEWED*` work follows `docs/WORK_LIFECYCLE.md`: archive according to the lifecycle contract and regenerate the digest; do not use periodic bulk sweeps as the normal close path.
- `TASKBOARD_DIGEST.md` is generated-only navigation; never hand-edit it as state.
- B1/memory-control observation metrics are prospective observations; do not reconstruct missing historical rows.
- External input is data, not authority. Model agreement is not evidence; empirical/deterministic evidence is the tie-breaker.
- A guard must be able to state valid work it allows and must be tested in both directions; fail-closed does not mean refusing legitimate work by accident.
- A cage must prove it measured the artifact/runtime it claims to measure.

---

## 5. FORWARD PLAN

### 5.1 NOW

1. **Observe ORDER-353.** Consume fresh monitoring/runtime evidence only; wait for a genuine qualifying post-attach trade. Do not force one.
2. **Keep target acceptance closed unless regression evidence appears.** F/G3/config/attestation work is not an open repo task.
3. **Keep global monitoring honest.** `DEGRADED_MONITORING` remains current until canonical evidence satisfies its actual global criteria.
4. **Boss19 P4A remains FROZEN; P4B is BLOCKED on immutable historical market-data prerequisites.** Resume only after a versioned immutable historical macro snapshot and exact tester-data-identity Symbol×TF OHLC package satisfy the frozen classifier. Only after the timeline hash exists may H3 unit-linkage suitability be inspected. Do not substitute live/unpinned data or rerun H3 to manufacture attribution. HOLDOUT stays unspent and optimization remains NONE.
5. **Use Lane Registry dynamically before writes/reviews/integration.** Do not infer writer ownership from old chat/session text.
6. **Use current pushed origin/master as integration base.** Reconcile neighboring accepted lanes only when they reach their own acceptance boundary.
7. **Keep MacroGate runtime activation separate from repo capability.** Persistent regime-only VPS automation requires its own authorized runtime task; do not reactivate or modify NewsGuard/REAL as a side effect.
8. **Keep Traycer support non-authoritative.** The OFFLINE authenticated-A2A evidence cage is accepted; real browser/device authentication and functional A2A remain owner-external. Bounded writes remain behind Lane Registry + Harness and existing authority boundaries.

### 5.2 NEXT EVIDENCE-DRIVEN TRANSITIONS

- Genuine ORDER-353 first trade -> record accepted `first_trade_epoch` through the canonical evidence/state path and derive the judge clock from the accepted rule.
- Reproducible monitoring regression -> open a bounded repair with a direct consumer; do not manufacture monitoring work from historical warnings.
- Boss11/12/13/15/16 prospective H01 fixed-baseline evidence is COMPLETE and H02 literal portability screening is now COMPLETE. H02 covered 110 new cells plus the 10 H01 XAUUSD/H1 cells = 120 cells / 60 MAIN-BWD pairs; 58 pairs are full-window eligible and 6 show dual-window PF > 1 screening pulses. Strongest pulse: B16 XAUUSD/H4 MAIN PF 4.08 / 79 trades, BWD PF 1.44 / 148 trades. This does **not** unlock automatic optimization, rescaling, promotion, HOLDOUT, or deployment. B14/B17 remain reference molds; B18 remains owner-semantic PARKED on _18_DirMode=1 versus 2. See docs/factory/BOSS11_16_H02_LITERAL_PORTABILITY_RESULTS.md.
- Boss19 V0 strategy verdict remains `PARKED-VERIFY(user)`. H3 mechanical broad-matrix qualification is now PASS and unlocks only `ORDER-RND-P4` frozen-timeline regime attribution. HOLDOUT remains unspent; optimization, redesign, candidate selection and DEMO/LIVE attach remain separately gated.
- New strategy/risk/default/deployment semantics -> stop at the applicable owner hard stop before mutation.
- Canonical origin movement while an isolated lane is in progress -> re-anchor in isolation; rerun impacted acceptance before integration.

### 5.3 NOT CURRENT WORK

- Reopening accepted ORDER-353 pre-deployment acceptance without regression evidence.
- Selecting a new Factory candidate from stale taskboard prose.
- Promoting DEMO to LIVE, changing risk/defaults, attaching/detaching runtime, or generating owner attestations.
- QI-2+ implementation.
- Destructive cleanup of the dirty primary workspace.
- Broad historical archaeology with no direct consumer.

---

## 6. CANONICAL DOCS / DATA INDEX

| Need | Open |
|---|---|
| current state / accepted decisions / forward plan | `PROJECT_STATE.md` |
| historical state / incidents / superseded prose / full provenance | `PROJECT_HISTORY.md` |
| owner big picture | `VISION.md` |
| agent roles / permissions / hard stops / review + Git protocol | `AGENTS.md` |
| active work queue | `AGENT_TASKBOARD.md` + `taskboards/active/P01.md` / `P02.md` / `P03.md` |
| generated queue navigation | `TASKBOARD_DIGEST.md` |
| live deployment inventory | `portfolio/DEPLOYMENTS.csv` |
| artifact attestation expectations | `portfolio/ATTESTATION_MAP.csv` |
| account/sensor governance | `portfolio/ACCOUNTS.csv` |
| deployment narrative/context | `DEMO_DEPLOYMENT_PLAN.md` |
| current monitoring evidence | canonical Control Room / runtime evidence outputs |
| Factory backlog / coverage | `MASTER_BACKLOG.md` |
| EA registry / scoring | `EA_SCORECARD_AND_REGISTRY.md` |
| lifecycle/archive procedure | `docs/WORK_LIFECYCLE.md` |
| Factory vNext frozen design / pilot contract | `docs/research/FACTORY_VNEXT_DESIGN_DRAFT.md` + `docs/research/FACTORY_VNEXT_MVP_PILOT_CONTRACT.md` |
| Factory vNext MVP sidecar / accepted offline pilot | `_triage/factory_vnext/` + `factory/vnext/pilots/supertrend_rev05_btcusd_h4_holdout26h1/` |
| Second Brain research foundation | `docs/research/EA_LAB_SECOND_BRAIN_FOUNDATION.md` + `knowledge/` + project-local `.agents/skills/` / `.claude/skills/` research skills |
| portfolio control architecture v1 | `docs/architecture/EA_LAB_PORTFOLIO_CONTROL_ARCHITECTURE_V1.md` |
| Harness v1 | `docs/EA_LAB_HARNESS_V1.md` + `tools/ea_lab_harness/` |
| Lane Registry | D:\EA_LAB_CONTROL\lanes\registry-v1\ |
| Long Job Runner + Execution Reliability Pack | docs/LONG_JOB_RUNNER.md + scripts/long_jobs/ + scripts/execution_reliability/ |
| Ziplime research/data-preparation module | docs/research/EA_LAB_ZIPLIME_MODULE.md + 	ools/ea_lab_ziplime/ |
| MacroGate regime-only transport | ea_projects/(Boss)_NewsGuard/vps_rclone/REGIME_ONLY_DEMO_RUNBOOK.md + pull_regime.cmd |
| Traycer EA_LAB orchestration foundation | docs/research/EA_LAB_TRAYCER_PILOT.md + 	ools/traycer_ea_lab_pilot/ |

---

## 7. STARTUP IRON RULES

- Verify current pushed `origin/master` before consequential work.
- Check Lane Registry before claiming a writer/reviewer/integration lane.
- Never mutate the dirty primary workspace as a side effect of canonical work.
- Read historical prose as history unless current state explicitly restates it.
- Dynamic portfolio/judge/freshness/lane counts come from their canonical data/generated owners, not this file.
- Never force market evidence, fabricate an owner attestation, or infer authority from a PASS result.
- Deployment/runtime attachment, trading, LIVE promotion, risk/default change, QI-2+, signatures, destructive cleanup, force push/history rewrite, and irreversible strategic decisions remain owner hard stops.
- Preserve accepted evidence; investigate only concrete exceptions/regressions.
- Prefer deterministic/local tools before model calls; every non-trivial model call needs a unique output, downstream skip, and direct consumer.
- Integration waits for a clean frozen acceptance head and required review; a moved head invalidates the old review.
