# EA_LAB Portfolio Control Architecture v1

STATUS: RATIFIED ARCHITECTURE / NO RUNTIME AUTHORITY
OWNER RATIFICATION: 2026-08-30
BASELINE INTENT: control and observe 30+ EA deployment instances, scalable beyond 100, without requiring the owner to code Python.

## 1. Scope and authority boundary

This document ratifies the system architecture, module boundaries, ownership model, control-state vocabulary, data-contract direction, failure behavior, monitoring hierarchy, and staged automation path.

It does NOT ratify numeric risk defaults or activate runtime. The following remain separate owner hard stops or research decisions:
- LIVE / DEMO-to-LIVE promotion;
- runtime attachment or persistent scheduling;
- real-money trading;
- DD trigger percentages;
- hedge percentages;
- recovery depth/lot/exposure/duration budgets;
- port/global risk budgets;
- exact Grade A/B/C/D numeric mapping;
- exact sample-floor replacement;
- any default lot/risk change.

Architecture may therefore be implemented and tested offline/DEMO in bounded stages without silently granting production authority.

## 2. Design objective

EA_LAB shall behave as a portfolio operating system rather than a collection of isolated EAs.
Each EA remains responsible for deterministic local execution and hard safety, while portfolio-level intelligence is centralized in a Python Supervisor and exposed through a human-operable dashboard.

## 3. Architectural hierarchy

Canonical control hierarchy:

```text
EA INSTANCE
  -> STRATEGY/SYMBOL CLUSTER
  -> PORT / ACCOUNT
  -> GLOBAL PORTFOLIO SUPERVISOR
  -> HUMAN DASHBOARD
```

The hierarchy is intentionally layered because one EA can be locally safe while the cluster or port is globally overexposed.

### 3.1 EA Instance
Owns signal generation, order execution, local basket state, local hard cage, and deterministic handling of its own positions.

### 3.2 Strategy/Symbol Cluster
Aggregates related risk: same symbol, direction, strategy family, correlated timeframe, or strongly overlapping drawdown behavior. Cluster membership is evidence-driven and may change as forward evidence grows.

### 3.3 Port / Account
Owns aggregate account-level exposure, available risk/recovery capacity, simultaneous recovery pressure, margin and account-health context.

### 3.4 Global Portfolio Supervisor
Sees all ports and clusters, computes cross-portfolio regime/risk context, detects concentration/systemic stress, and publishes bounded desired states. It does not replace EA-local safety.

### 3.5 Human Dashboard
Owner-facing control and explanation surface. Daily operation must not require editing Python, JSON, MQL, terminal files, or command-line tools.

## 4. Six functional layers

### Layer 1 — Strategy / Execution
Each EA or strategy module owns entries, exits, local sizing rules, and strategy-specific position behavior. Symbol x TF presets are independently optimized; shared family architecture does not require parameter portability.

### Layer 2 — Local Safety / Ownership / Recovery
This layer contains basket identity, position ownership, local DD/exposure hard cages, protection state, hedge state, recovery state, emergency handling, and command rejection when Supervisor requests conflict with local safety.

### Layer 3 — Cluster Controller
Tracks correlated exposure, same-symbol directional stacking, family overlap, drawdown overlap, and simultaneous protection/recovery within a risk cluster.

### Layer 4 — Port Controller
Tracks account equity/DD, margin/exposure, port stress, aggregate recovery consumption, available recovery capacity, and restrictions that apply to all EAs inside a port.

### Layer 5 — Python Portfolio Supervisor
Computes shared market context, regime vectors, strategy-regime fit, cross-port concentration, alerts, desired allocation/control state, and reconciliation after restart. V1 is deterministic; LLM/AI is not in the runtime decision loop.

### Layer 6 — Human Dashboard
Shows global -> port -> cluster -> EA state, reasons, alerts, ownership, command age/acknowledgement, charts and history. Human controls are high-level and bounded.

## 5. Non-negotiable local-safety invariant

Python is a supervisor, not a safety dependency.
If Python, dashboard, transport, network, or shared-state storage fails:
- local hard cages remain active;
- current owned basket management remains deterministic;
- stale external commands cannot increase risk;
- no new recovery cycle starts from an expired command;
- existing recovery ownership is not silently abandoned;
- the EA may enter SAFE_LOCAL and refuse risk expansion.

## 6. Control State Contract

The Supervisor publishes bounded desired states rather than direct discretionary order instructions.

Core vocabulary:
- NORMAL — normal strategy authority inside local cages.
- REDUCE — lower new-risk/allocation authority while preserving orderly management.
- BLOCK_NEW — no new entries; existing positions may be managed/exited.
- NO_ADD — prohibit averaging/adds while allowing the existing basket and permitted exits.
- PROTECT_1 / PROTECT_2 / PROTECT_3 — progressive defensive states; exact hedge/exposure targets are profile-specific research parameters.
- LOCK — near/full directional lock or equivalent high-protection state under the local contract.
- RECOVERY_WAIT — recovery is armed but budget/context does not yet permit active recovery.
- RECOVERY_ALLOWED — permission exists to begin the declared recovery transition if local preconditions pass.
- RECOVERY_ACTIVE — Recovery Engine owns the declared basket/cycle.
- UNWIND — deterministic staged reduction of hedge/recovery exposure after exit/reversal criteria.
- SAFE_LOCAL — external control is stale/unavailable; no external risk expansion.
- HARD_FREEZE — no new directional risk; only contract-defined risk reduction, exit, or emergency behavior.

The exact permitted actions for each EA are defined by its Control Profile. A state name is a permission envelope, not a raw lot command.

Example: `PROTECT_1` means the EA executes its own validated Level-1 protection rule against current net exposure; Python does not send `SELL 0.37 now` as the primary v1 interface.

## 7. Authority precedence

When rules conflict, authority resolves in this order:
1. hard emergency/local safety cage;
2. current valid basket/recovery ownership contract;
3. port hard restriction;
4. cluster restriction;
5. Supervisor desired state;
6. strategy's ordinary signal/request.

A lower layer may reject a higher-level request when execution would violate a stricter safety/ownership rule. Every reject must be explicit and logged.

## 8. Position / Basket Ownership Contract

Every managed basket has exactly one active owner at a time.

Minimum ownership states:
- PRIMARY — strategy engine owns ordinary basket management.
- PROTECTION — protection controller owns hedge/protection transition.
- RECOVERY — recovery engine owns the declared recovery cycle.
- EMERGENCY — emergency controller owns controlled liquidation or hard-cage action.

Minimum durable identity:
- deployment/EA identity;
- symbol and magic/strategy identity;
- basket_id;
- owner_state;
- owner_id;
- recovery_cycle_id when applicable;
- monotonic sequence/version;
- last transition timestamp;
- expected position/order set fingerprint.

No Primary, Secondary, Recovery, human action, or Supervisor adapter may silently mutate a basket owned by another controller.
External/manual mutation is treated as a state-integrity event and must be detected, surfaced, and reconciled before normal authority resumes.

## 9. Recovery ownership state machine

Canonical architecture sequence:

```text
NORMAL
 -> ARMED / PROTECT
 -> PRIMARY FROZEN as required
 -> OWNERSHIP TRANSFER
 -> LOCK / RECOVER / PARTIAL RETIRE
 -> RECOVERY COMPLETE
 -> OWNERSHIP RETURN
 -> NORMAL
```

Emergency abort/controlled liquidation is a separate explicit transition. It is not equivalent to manually closing arbitrary recovery legs.

## 10. Progressive Protection and Recovery Context

DD alone does not fully determine protection escalation. The architecture separates:
- DAMAGE / CONTINUATION evidence, which can justify more protection;
- REVERSAL / HOLD evidence, which can justify holding or unwinding protection;
- hard boundaries, which override soft context.

Evidence families are kept independent to avoid indicator-counting illusions:
1. Damage — DD, floating loss, basket duration, distance from average entry.
2. Market Structure — confirmed swings, support/resistance zones, break/reclaim/retest.
3. Momentum / Exhaustion — RSI/divergence, MACD/momentum family, rejection/exhaustion evidence.
4. HTF Context — Weekly/Daily/H4 structure and higher-timeframe direction.
5. External Regime — NewsGuard, MacroGate, volatility shock/context.

The previously discussed 25-30%, 50-60%, 75-90%, near-full protection examples remain research shapes only. V1 architecture ratifies staged protection states, not those percentages.

For a same-symbol basket, hedge/protection targets are based on current net directional exposure rather than blindly summing gross tickets. Cross-symbol portfolio control must use risk-equivalent exposure rather than raw lot totals.

## 11. Regime Engine architecture

Market State, Strategy Fit, and Control Action are distinct objects.

`Market State` describes the market without deciding what an EA should do.
`Strategy Regime Profile` describes the conditions a particular EA likes, tolerates, or cannot trade safely.
`Regime Fit` compares those two.
`Control Action` then also considers current EA state, DD, exposure, cluster/port stress, news and ownership.

The same market state may therefore produce different actions for a trend EA, breakout EA, mean-reversion EA, scalper and grid EA.

### 11.1 Regime Vector

The Supervisor may classify, per symbol and relevant timeframe:
- W1/D1/H4/H1/M15 direction or structure;
- phase: trend expansion, pullback, reacceleration, range, range edge, breakout, failed breakout, reversal candidate/confirmed, volatility shock, transition;
- volatility and liquidity state;
- location relative to confirmed S/R zones;
- momentum/exhaustion family;
- NewsGuard state;
- MacroGate/context state;
- confidence.

Timeframe disagreement is information, not an error. Example: W1/D1 bullish + H1 bearish can be classified as HTF bull / LTF pullback rather than forced into one BULL/BEAR label.

Regime Fit presented to humans uses a compact class such as HIGH / MEDIUM / LOW / HOSTILE plus reasons. Internal deterministic scores may exist, but critical incompatibilities can cap/override the aggregate rather than being averaged away.

Low-confidence market classification reduces automation authority; uncertainty never grants more risk authority.

## 12. Cluster / Portfolio Risk Engine

Risk aggregation is evaluated at four levels:
- EA DD/exposure;
- cluster DD/exposure;
- port/account DD/exposure;
- global portfolio DD/exposure.

The engine also tracks return correlation, drawdown overlap, losing-period overlap, directional exposure overlap, simultaneous basket depth and simultaneous recovery triggers.
Drawdown overlap is first-class because moderate ordinary correlation can hide highly synchronized tail losses.

Port stress uses a bounded state vocabulary such as NORMAL / ELEVATED / STRESSED / DEFENSIVE / RECOVERY_CONSTRAINED. Exact numeric thresholds remain separate research/default decisions.

A cluster or port may restrict new risk before any individual EA reaches its own local DD trigger. This is the primary protection against many individually-valid EAs stacking the same macro/symbol risk.

Simultaneous recovery is explicitly capacity-constrained. A later EA may be forced to protect/freeze/wait while another recovery cycle consumes the permitted port recovery budget.

## 13. Supervisor Data Contract

Each EA publishes a machine-readable state snapshot containing at least:
- deployment identity, strategy family/variant, symbol, TF, preset/config identity and magic;
- heartbeat and schema/protocol version;
- current control state and owner state;
- open position/order identity and expected basket fingerprint;
- buy/sell/gross/net exposure;
- floating P/L and local DD;
- basket depth and age;
- local cage status;
- protection/recovery cycle state;
- last command id and acknowledgement state;
- telemetry timestamp.

The Supervisor publishes a bounded command/intention record containing at least:
- target deployment identity;
- desired control state;
- regime/fit summary;
- risk/allocation permission;
- recovery permission;
- machine-readable reason codes plus human explanation;
- command_id / sequence;
- issued_at and expires_at / TTL;
- protocol/schema version.

EA acknowledgement returns ACK or REJECT, actual applied state, reason, timestamp and resulting ownership/sequence.

## 14. V1 Transport Direction

Prefer the simplest inspectable transport first. A file/shared-state contract such as MT5 `FILE_COMMON` plus versioned JSON/CSV records is acceptable for the first prototype because it is deterministic, replayable and easy to diagnose.

Transport is replaceable. Socket/API/message-bus implementation may come later without changing control semantics if the contract remains stable.

Required transport properties:
- atomic or fail-visible writes;
- schema/protocol versioning;
- command sequence monotonicity;
- TTL/expiry;
- ACK/REJECT;
- duplicate/idempotency handling;
- durable event logging;
- no ambiguous partial command application.

## 15. Heartbeat / Restart / Reconciliation

A stale `NORMAL` command must never remain valid indefinitely.
Loss of fresh Supervisor heartbeat or expired command moves the EA to its declared stale-control behavior, normally SAFE_LOCAL or stricter local state.

Supervisor restart sequence:
1. start with authority to observe only;
2. load durable Supervisor state/event log;
3. request/read a fresh snapshot from every reachable EA;
4. reconcile positions, basket fingerprints, ownership, recovery cycle and last acknowledged sequence;
5. classify MATCH / MISMATCH / UNKNOWN;
6. only MATCH state may resume the previously allowed automation level;
7. MISMATCH/UNKNOWN freezes risk expansion and raises an actionable alert.

The Supervisor never infers recovery ownership from DD or open positions alone.

## 16. Event Store / Audit / Replay

Every material transition is recorded so the system can answer: `why did EA-X move from state A to B at time T?`

Minimum event information:
- before/after state;
- reason codes and decisive evidence families;
- market/regime snapshot identifier;
- EA/cluster/port DD and exposure context;
- command id and acknowledgement;
- ownership transition;
- recovery cycle id when applicable;
- source timestamps;
- human override if any.

The event stream is used for audit, post-incident RCA, deterministic replay, strategy/recovery research, and dashboard history. Missing evidence is shown as UNKNOWN rather than reconstructed as fact.

## 17. Human Dashboard contract

The owner-facing system must be usable without Python knowledge.
Default top-level view shows:
- Global equity/DD/exposure and control state;
- active ports and their stress states;
- EA counts by NORMAL / REDUCE / PROTECT / RECOVERY / critical state;
- current major regime/news/macro conditions;
- cluster concentration and simultaneous recovery pressure;
- communication/heartbeat health.

Drill-down order is Global -> Port -> Cluster -> EA -> Basket/Recovery cycle.
Each EA view exposes Strategy Grade, Evidence Confidence, Portfolio Value, Strategy Thesis, Regime Fit, current state, DD/exposure, owner, recovery state, last command/ACK, reasons and relevant charts.

The dashboard hides implementation complexity by default but preserves full logs/technical detail for AI/worker diagnosis.

### 17.1 Human override model

Human controls are high-level commands, not arbitrary per-ticket mutation during controlled recovery.
Candidate controls:
- PAUSE NEW RISK;
- REDUCE;
- SAFE MODE;
- DISABLE INSTANCE;
- FREEZE PORT;
- allow/block recovery permission where the current authority contract permits.

Manual mutation of a Recovery-owned basket is not a normal control path. Emergency manual intervention must explicitly transition ownership/state and create an audit event.

## 18. Alert model

Alert levels:
- INFO — state/regime changes retained in log/dashboard;
- WATCH — meaningful DD/cluster stress requiring owner awareness;
- ACTION — protection/recovery/defensive state transition requiring immediate notification;
- CRITICAL — heartbeat loss, ownership mismatch, hard cage, abnormal recovery or unreconciled state.

Alerts are event-driven and deduplicated. Thirty to one hundred EAs must not produce notification spam for ordinary internal transitions.
A daily portfolio brief may summarize global DD, port/cluster states, counts of protected/recovery instances, major regimes and critical anomalies.

## 19. Automation maturity ladder

Automation authority is deliberately staged:
- MODE 0 — MONITOR ONLY;
- MODE 1 — RECOMMEND ONLY;
- MODE 2 — AUTO bounded block/reduce actions;
- MODE 3 — AUTO regime/allocation actions;
- MODE 4 — AUTO protection;
- MODE 5 — AUTO recovery.

Moving to a higher mode requires separate acceptance evidence; the architecture document itself does not promote a runtime mode.

## 20. Strategy / R&D integration

Portfolio control does not collapse research evidence into one PASS/FAIL label.
The target model keeps separate:
- Strategy Grade — quality of the strategy itself;
- Evidence Confidence — strength/coverage of evidence;
- Portfolio Value — contribution/redundancy in the current portfolio;
- Build Potential — value of further research/mechanism reuse;
- Regime Fit — current-market suitability;
- Allocation State — current control consequence.

Grade and lifecycle are separate. A Grade B strategy can be qualified/active when its weakness is understood and evidence is adequate; a Grade A strategy with weak evidence can remain in DEMO/forward collection.

Sample adequacy is strategy-aware rather than interpreted by one universal raw trade count. Relevant sample units can include trades, independent setups, grid baskets/cycles, breakout opportunities, recovery cycles, years and regime coverage.

Exact numeric grade/sample policy remains separately unresolved until migrated into its canonical scoring/verdict owner. This architecture ratifies the separation of dimensions, not a hidden numerical replacement for KINT-001.

## 21. DEMO arbitration principle

DEMO is the preferred arbitration layer when a backtest leaves material uncertainty about real execution, broker behavior, state transitions, interaction or strategy behavior.

A roughly one-month DEMO comparison may be enough to expose many execution/backtest mismatches, but one calendar month is not automatically sufficient to prove a long-term edge. Low-frequency strategies remain opportunity-driven: insufficient setups means INSUFFICIENT EVIDENCE, not PASS/FAIL by calendar alone.

DEMO evidence compares expected vs observed behavior: entries/exits, fills/cost, state transitions, DD/exposure, regime response, recovery behavior and telemetry integrity.

## 22. Lifecycle / incumbent / challenger

Target lifecycle:
`RESEARCH -> QUALIFIED -> FORWARD/DEMO -> PRODUCTION-ELIGIBLE -> ACTIVE -> REPLACED/RETIRED`.

`PRODUCTION-ELIGIBLE` is an engineering/research state, not automatic permission for LIVE or real-money use.

Incumbent policy:
- a qualified incumbent remains in use while evidence remains consistent with its thesis and safety contract;
- short drawdowns do not automatically trigger replacement;
- wrong-regime weakness can change Regime Fit/allocation without changing historical Strategy Grade;
- execution drift, ownership defect, uncontrolled tail or safety defect may force immediate freeze independent of challenger availability.

Challenger policy:
- compare total quality, DD/tail, execution, plateau/stability, diversification, regime fit and forward evidence;
- higher PF alone is not sufficient;
- if two qualified variants have genuinely useful different profiles, KEEP BOTH is valid;
- related variants remain one risk/mechanism cluster when evidence shows shared exposure/tail behavior.

## 23. Module decomposition target

Implementation shall avoid a monolith. Initial module map:
- M01 Primary Strategy Adapter
- M02 Position/Basket Ownership Registry
- M03 Damage & DD Monitor
- M04 Structure Engine
- M05 Momentum/Divergence Engine
- M06 HTF Context / Regime Engine
- M07 NewsGuard/MacroGate Adapter
- M08 Progressive Protection/Hedge Controller
- M09 AW-style Recovery Engine
- M10 Unwind / Recovery Exit Controller
- M11 Cluster/Port Exposure & Recovery Budget Controller
- M12 Hard Tail / Emergency Cage
- M13 Telemetry / Event Store / Audit Logger
- M14 Replay / Attribution / Research Harness
- M15 Supervisor Policy Engine
- M16 Human Dashboard / Alert Surface

## 24. Build sequence

Build from observation to authority rather than implementing every intelligent feature at once.

Recommended implementation DAG:
1. Identity + telemetry contract + heartbeat.
2. Read-only Portfolio Monitor and event store.
3. Human dashboard with global/port/cluster/EA drill-down.
4. Supervisor reconciliation/restart cage.
5. Control State protocol in RECOMMEND ONLY mode.
6. Regime vector + per-EA Regime Profile/Fit.
7. Cluster/port exposure and DD aggregation.
8. AUTO bounded BLOCK_NEW / REDUCE with negative tests.
9. Progressive protection research lineage.
10. Recovery ownership + AW-style recovery research.
11. Simultaneous-recovery/port-capacity coordination.
12. Higher automation modes only after their own evidence and owner hard stops.

Recovery intelligence itself should evolve as controlled children rather than a single giant release: DD-only staged protection -> HTF structure -> break/reclaim/retest -> exhaustion/divergence -> regime context -> News/Macro -> AW-style recovery -> port coordination.

## 25. Required testing philosophy

Each module has a deterministic standalone cage before integration.
Acceptance includes positive and negative paths, restart/replay where relevant, stale command behavior, duplicate command behavior, ownership mismatch, external position mutation, partial/malformed telemetry, and unavailable Supervisor.

For recovery/protection, evaluation is not PF-only. Measure at least additional DD after trigger, recovery duration, peak exposure, depth, failed/aborted cycles, false locks, unnecessary hedge turnover/cost, carry/swap, recovery success and simultaneous stress.

No module may claim safety because the dashboard appears correct. Runtime/state evidence must bind the actual EA/basket/command identity.

## 26. Owner-operable requirement

The owner is not expected to maintain Python code manually.
Routine operation shall be possible through the dashboard and clear high-level controls. Technical implementation, tests and repairs may be performed by AI/worker lanes under EA_LAB contracts, but every decision-critical state must remain explainable to the owner in plain language.

Required owner-visible explanation pattern:
`WHAT happened -> WHY -> WHAT the system did -> WHO owns the basket -> WHAT would happen next`.

## 27. Canonical separation of concerns

This file owns the ratified portfolio-control architecture only.
It does not replace:
- `AGENTS.md` for authority/hard stops/review separation;
- `PROJECT_STATE.md` for current project status/accepted decisions/plan;
- `portfolio/DEPLOYMENTS.csv` for deployment identity/status;
- `docs/research/EA_RND_PROTOCOL.md` for R&D process;
- `docs/research/EA_REPORT_SCHEMA.md` and `EA_REPORT_LADDER.md` for evidence/reporting;
- `docs/research/EA_WORKFLOW_DIAGRAM_STANDARD.md` for diagram requirements;
- current Factory/verdict/optimization owners for numeric qualification policy.

The working discussion capture `docs/research/EA_RND_WORKING_DOCTRINE_2026-08-30.md` remains provenance/working-memory material. Where it conflicts with this file on architecture, this ratified architecture controls; unresolved numeric/policy items remain unresolved.

## 28. Acceptance statement

Architecture v1 is accepted when these principles remain true:
- scalable hierarchy EA -> Cluster -> Port -> Global -> Human;
- deterministic EA-local safety survives Supervisor loss;
- exactly-one basket owner and explicit recovery ownership transitions;
- versioned/expiring/acknowledged Supervisor commands;
- restart requires reconciliation before authority resumes;
- regime is market context matched to each strategy, not one global ON/OFF signal;
- cluster/port/global risk sees correlated and simultaneous tail exposure;
- human operation does not require coding;
- automation increases by staged evidence, not by architectural declaration;
- numeric risk/LIVE/runtime hard stops remain separate.

This is the baseline for subsequent implementation planning. Changes to these architectural invariants require an explicit architecture revision; empirical tuning within the declared profiles/contracts does not require rewriting the architecture.
