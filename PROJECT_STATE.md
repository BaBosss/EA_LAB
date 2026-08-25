# PROJECT_STATE — EA_LAB current canonical state (AI START HERE)

> **Role:** current status / accepted decisions / forward plan.
> **Last converged:** 2026-08-25 Asia/Bangkok.
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
- Implemented sidecar surfaces include deterministic Home/Window/Run identity, Parameter Surface V1, Telemetry V1, Range Generator V1, Derived Metrics V1, Grade/Confidence evidence scaffold, graph-first five-page report, SuperTrendFlip BTCUSD/H4 offline adapter, and the historical pilot artifact package.
- The accepted pilot uses existing `(TRD)_SuperTrendFlip_rev05`, logical `BTCUSD`, ExecutionTF `H4`, and the 2026H1 historical holdout with 100% real-ticks evidence. Exact pilot IDs, hashes, and measured counts are owned by `factory/vnext/pilots/supertrend_rev05_btcusd_h4_holdout26h1/pilot_manifest.json` and `artifact_index.json`.
- Current Factory production policy/verdict/optimization/risk/deployment authority is unchanged. No Factory candidate promotion, deployment/LIVE authority, risk/default change, or strategy trading-semantics change is created by this milestone.
- `KINT-001` remains intentionally OPEN. SuperTrend parameter semantic metadata remains unresolved; affected Range Generator evidence remains `SEMANTICS_REQUIRED`.
- Final numeric Grade/Confidence thresholds remain provisional/unratified; sidecar verdict/build-potential outputs remain non-authoritative.
### 1.3 Accepted control-plane capabilities

The following are accepted/canonical and should not be generically re-audited without a reproducible regression:

- Strategy & Evidence Consolidation M4.
- EA_LAB Harness v1.
- Lane Ownership / Shared Registry v1.
- active taskboard split: manifest + `taskboards/active/P01.md` / `P02.md` / `P03.md`.
- LNWJUD Local Execution Plane, M3 repository/identity work, and A-PATH observe bridge.
- Remote Desktop Commander persistence / zero-touch reboot path.
- POST-OPUS M0/M1 trust repairs.
- VPS DEMO preparation/hardening batch and PREDEV generic pre-development hardening.
- Long Job Runner durable detached execution support.
- Ziplime research/data-preparation module for the Factory vNext research sidecar.
- DEMO-safe MacroGate regime-only transport (-RegimeOnly / pull_regime.cmd) as a repository capability.
- Traycer EA_LAB orchestration foundation as a tooling/UI support module.

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
4. **Treat Factory vNext MVP Sidecar as accepted evidence, not production policy.** Do not reopen the accepted MVP generically. Further rollout/migration needs its own bounded consumer and may not select/promote a Factory candidate or migrate policy by implication.
5. **Use Lane Registry dynamically before writes/reviews/integration.** Do not infer writer ownership from old chat/session text.
6. **Use current pushed origin/master as integration base.** Reconcile neighboring accepted lanes only when they reach their own acceptance boundary.
7. **Keep MacroGate runtime activation separate from repo capability.** Persistent regime-only VPS automation requires its own authorized runtime task; do not reactivate or modify NewsGuard/REAL as a side effect.
8. **Keep Traycer support non-authoritative.** After owner authentication, functional A2A/read-only cage acceptance may proceed separately; bounded writes remain behind Lane Registry + Harness and existing authority boundaries.

### 5.2 NEXT EVIDENCE-DRIVEN TRANSITIONS

- Genuine ORDER-353 first trade -> record accepted `first_trade_epoch` through the canonical evidence/state path and derive the judge clock from the accepted rule.
- Reproducible monitoring regression -> open a bounded repair with a direct consumer; do not manufacture monitoring work from historical warnings.
- Further Factory vNext rollout/migration -> separate future milestone; broader Master Mold / Family / Variant production migration, Template Variant generator / MT5 Input UX / Boss11-18 compatibility remain future unless explicitly accepted.
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
| Harness v1 | `docs/EA_LAB_HARNESS_V1.md` + `tools/ea_lab_harness/` |
| Lane Registry | D:\EA_LAB_CONTROL\lanes\registry-v1\ |
| Long Job Runner | docs/LONG_JOB_RUNNER.md + scripts/long_jobs/ |
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
