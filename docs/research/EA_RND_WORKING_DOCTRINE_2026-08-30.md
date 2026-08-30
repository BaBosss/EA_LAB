# EA_LAB R&D + Portfolio + Recovery Working Doctrine — 2026-08-30

STATUS: WORKING DESIGN / UNRATIFIED

Purpose: durable capture of the owner/Control-Tower discussion so the same design is not repeatedly lost across chats.

IMPORTANT:
- This file does NOT replace ratified policy in `CLAUDE.md`, `PROJECT_STATE.md`, `AGENTS.md`, `EA_RND_PROTOCOL.md`, `EA_REPORT_SCHEMA.md`, or other canonical owners.
- Any conflict with current verdict/sample/risk/deployment rules remains unresolved until explicit owner ratification.
- No LIVE, risk-default, deployment, or promotion authority is granted here.
- Numeric examples below are research shapes, not defaults.

## 1. Portfolio philosophy
- EA_LAB is not capped at 30 EAs; 30+ qualified deployment instances are acceptable.
- More cent-account ports may be added as operational capacity grows.
- One strategy family qualified on five Symbol × TF homes may be five operational EA instances, but not automatically five independent edges.
- Ports are operational/risk containers; splitting correlated EAs across ports reduces account blast radius but does not remove market correlation.
- A qualified EA can continue running until a better qualified replacement exists, unless a structural/risk/execution hard failure requires earlier removal.
- Backtest qualifies; forward evidence makes instances compete; portfolio selection is evolutionary.
- Safe deployable parents may run while better children are researched.
- Improvement opportunity is not the same as unsafe weakness.

## 2. Family vs deployment instance
- Shared family architecture does not imply a shared preset.
- Optimization and preset selection are expected per Symbol × TF home.
- Parameter portability is not required; local parameter stability is required.
- A mechanics change such as Pullback to Breakout is a new variant or child, not just a preset.

## 3. Optimization doctrine under discussion
Optimization selection should use multiple dimensions rather than a single performance statistic.
Relevant evidence includes return quality, drawdown, participation appropriate to strategy type, average trade, plateau and neighbors, time/regime concentration, side concentration, active exposure, execution sensitivity, and basket depth where applicable.
Preferred flow: MAIN -> find a robust region -> choose a stable center/region -> LOCK -> BWD validation.
BWD must not silently become a second optimization surface.

## 4. Sample adequacy direction
- The owner rejects one universal trade-count interpretation for all strategy types.
- H4/D1 low-frequency trend systems cannot be judged like M5 scalpers.
- Grid ticket count may mislead; independent baskets/cycles can matter more than raw tickets.
- Adequacy should consider expected opportunities, independent setups, time coverage, regime coverage, concentration, side participation, and execution/data fidelity.
- Strategy Quality and Evidence Confidence should remain separate dimensions.
- The current ratified sample-floor conflict is not changed by this note.

## 5. Grade and portfolio role direction
Working conceptual meaning only:
- A = strongest overall quality/robustness.
- B = usable real edge with known weakness and potentially lower allocation.
- C = promising / build-on / incomplete evidence.
- D = exhausted or unacceptable.
Keep separate: Strategy Grade, Evidence Confidence, Portfolio/Slot Value, Regime Fit, Allocation State.
A redundant high-grade EA may have low slot value; a modest EA may have high diversification value.
Exact numeric mapping remains UNRATIFIED.

## 6. Strategy Thesis and Deployment Thesis
Before deployment, every instance should state what strategy it is, why the edge should exist, best regime, weak regime, why it qualified, expected drawdown behavior, and why it deserves risk now.
Strategy Thesis = why the edge should exist.
Deployment Thesis = why this instance deserves current portfolio risk.
Forward weakness should be interpreted relative to expected regime behavior, not one metric alone.

## 7. Incumbent / challenger lifecycle
Preferred lifecycle:
DISCOVER -> QUALIFY -> GRADE -> DEPLOY SMALL -> FORWARD EVIDENCE -> INCUMBENT.
New challengers then run head-to-head and end as KEEP BOTH / REPLACE / REJECT.
A prettier backtest does not automatically replace an incumbent with substantial forward evidence.
If incumbent and challenger exploit meaningfully different regimes or reduce each other's drawdown, both may remain.
Use a qualified incumbent until a better available qualified choice exists unless a structural/risk/execution hard-stop requires earlier removal.

## 8. Broad-home discovery
- For unknown-home concepts, broad discovery finds natural homes; it is not a universal portability gate.
- Scan eligible symbols, representative TFs, and several preregistered coarse configuration shapes.
- Inspect pulses, clusters, plateau and neighbors before deep optimization.
- A specialist XAU M5/H4 edge can be valid even when other symbols fail if local robustness and execution evidence support it.

## 9. Mechanism salvage before concept death
Weak standalone performance should be decomposed before killing a concept.
Reusable mechanisms include Direction, Entry, Filter, Exit, Position Engine, Recovery/Hedge, and Risk/Safety.
A low-frequency directional system can still reveal a useful direction/filter mechanism that seeds Pullback, Breakout, Directional Grid, or related children.
Do not require an arbitrary number of optimization rounds; use diagnosis-backed lever families and stop inventing extra levers when the strategy does not have them.

## 10. Scalper special handling
Scalpers are easy to make look good and hard to deploy because spread, commission, slippage, news, and tiny target geometry can erase apparent edge.
Use realistic execution relatively early. Failure under realistic execution should trigger diagnosis of cost, session, target geometry, holding time, and broker/symbol behavior before killing the concept.

## 11. Hybrid EA / mini-portfolio
One EA may intentionally contain more than one strategy when interaction is useful:
Primary Strategy + Secondary Strategy + Regime Allocation + Shared Risk Controller + Tail/Recovery Layer.
Secondary purpose can be to fill a regime gap, smooth equity, reduce recovery time, or profit while Primary is weak.
A Secondary does not need to be a superstar standalone if its preregistered conditional operating regime has positive expectancy and improves the combined system.
Preserve controls: A standalone, B standalone, A+B, and A+B+regime allocator.
Important question: what does B do while A is in drawdown or in A's weak regime?

## 12. Secondary vs Recovery
Secondary Strategy is an independent/complementary edge that may run continuously or conditionally.
Recovery Strategy is normally dormant, activates after damage, and is intended to retire trapped loss, shorten recovery, or control tail.
Do not disguise loss chasing as a Secondary strategy.

## 13. AW Recovery reference
The owner has strong positive experience with AW Recovery 3.3 MT4 when allowed to operate without manual interference.
Desired reference mechanics:
- identify original losing basket by ownership/magic,
- optionally lock/freeze directional exposure,
- run a separate recovery engine,
- generate recovery profit,
- use it to retire portions of the original loss,
- progressively reduce the trapped basket,
- release when recovery is complete.
Key lesson: once Recovery has ownership, manual intervention or another EA changing the basket can destroy state assumptions.
Position ownership therefore must be explicit and deterministic.

## 14. Recovery ownership state machine
Working structure:
NORMAL -> RECOVERY ARMED -> PRIMARY FROZEN/PROTECTED -> OWNERSHIP TRANSFER -> LOCK/RECOVER/PARTIAL RETIRE -> RECOVERY COMPLETE -> OWNERSHIP RETURN -> NORMAL.

During Recovery ownership:
- Primary must not add/remove owned positions.
- Secondary must not alter the same basket unless explicitly designed for shared ownership.
- Manual close is not normal workflow.
- Orders should be classified as ORIGINAL / LOCK / RECOVERY / SECONDARY.
- External order/volume mutation must be detected as a state-integrity event.

Emergency abort / controlled liquidation is a separate state, not ad-hoc intervention.

## 15. Context-aware progressive hedge
Desired direction: DD arms protection; market context determines how far protection escalates.

Research-shape sequence only:
- S0 NORMAL
- S1 ARMED / PARTIAL PROTECT
- S2 STRUCTURE DAMAGE
- S3 HTF CONTINUATION
- S4 LOCKED
- S5 AW-STYLE RECOVERY

Example partial-hedge bands discussed were roughly 25-30%, 50-60%, 75-90%, then near-full lock. These are NOT ratified defaults.
For same-symbol baskets, hedge target should reference net directional exposure rather than blindly using gross ticket lots.
For cross-symbol/port control, raw lots are insufficient; use risk-equivalent exposure.

## 16. Confluence evidence families
Avoid naive indicator vote counting because RSI, MACD, candle and related signals can be correlated descriptions of the same market condition.

Use evidence families:
1. DAMAGE — DD, floating loss, distance from average entry, basket duration.
2. MARKET STRUCTURE — H1/H4/D1 swings, support/resistance zones, break, reclaim, retest failure.
3. MOMENTUM / EXHAUSTION — RSI, RSI divergence, MACD, ADX/momentum slope.
4. HTF CONTEXT — Weekly/Daily structure, HTF candle close, Weekly MACD, HTF RSI, major trend direction.
5. EXTERNAL REGIME — NewsGuard, MacroGate, volatility shock/context.

Multiple indicators inside one family should not automatically count as multiple independent confirmations.
Think in two competing directions:
- DAMAGE / CONTINUATION evidence can escalate hedge/protection.
- REVERSAL / HOLD evidence can pause escalation or reduce hedge.

## 17. Structure-aware recovery behavior
For a long basket, desired behavior is:
1. DD crosses arm threshold -> partial protect.
2. Price is at meaningful HTF support with rejection/reclaim/divergence -> do not automatically escalate to full hedge.
3. Confirmed support break / HTF close below zone / failed retest -> escalate hedge.
4. Strong adverse HTF continuation -> escalate further.
5. Hard damage/exposure boundary -> override soft signals and lock/protect.
6. Confirmed reversal/reclaim -> progressively unwind hedge.

Support/resistance should be modeled as zones, preferably volatility-aware. Research pivots must be confirmed/non-repainting.
Wick sweep + reclaim must be distinguishable from structural close-through + failed retest.

## 18. Divergence role
Bullish divergence on a long basket is reversal/hold evidence, not automatically a reason to increase hedge.
A deterministic detector can use confirmed pivots, for example:
- Price Low2 < Low1,
- RSI Low2 > RSI Low1,
- bounded pivot distance,
- minimum price/RSI separation,
- pivot confirmation.

Divergence must never delay protection indefinitely. Any wait state needs bounded bars/damage and a hard override.

## 19. Progressive hedge unwind / hysteresis
The system must define not only when to add hedge, but when and how to remove it.
Desired behavior:
- avoid full hedge removal on one small rebound,
- use confirmed reclaim/reversal and staged reduction,
- avoid hedge/unhedge churn that leaks spread and slippage.

Example research shape only:
30% hedge -> reversal confirmation -> 15% -> second confirmation -> 0%.
Use hysteresis/state confirmation rather than noisy continuous switching.

## 20. Protect vs Recover are separate actions
PROTECTION MODE may freeze Primary adds, reduce correlated Secondary allocation, cap new exposure, tighten News/Macro rules, and partially hedge.
RECOVERY MODE may transfer basket ownership, lock more fully, run AW-style recovery logic, and retire original loss in controlled pieces.
A DD trigger can activate protection before recovery deployment is permitted.

## 21. Port-level recovery coordination
With many deployment instances, simultaneous recovery is a portfolio problem.
Each recovery needs local limits such as max recovery depth, exposure, duration, and carry budget.
The port also needs aggregate limits so several EAs do not independently consume the full account risk budget during the same macro shock.
If one EA already consumes substantial recovery capacity, another triggered EA may need to freeze/lock conservatively and wait rather than launch an aggressive independent recovery grid.
Exact portfolio risk rules remain owner-reserved and are not set by this document.

## 22. Recovery optimization objective
Recovery is not optimized by PF alone.
Important recovery metrics include:
- recovery success rate,
- median and worst recovery duration,
- maximum additional DD after trigger,
- peak recovery exposure,
- max recovery depth,
- original loss retired,
- failed/aborted cycles,
- swap/carry cost,
- behavior in runaway trend,
- simultaneous-recovery stress,
- false-lock frequency,
- unnecessary hedge cost.

A lower-PF recovery engine can be preferable if it reliably limits post-trigger additional DD and shortens trapped duration without creating a new ruin mechanism.

## 23. Module boundary requirement
This design is intentionally too complex for a monolith. Implementation should be modular so each layer can be tested independently and composed later.

Candidate modules:
- M01 Primary Strategy Adapter
- M02 Position / Basket Ownership Registry
- M03 Damage & DD Monitor
- M04 Structure Engine
- M05 Momentum / Divergence Engine
- M06 HTF Context / Regime Engine
- M07 NewsGuard / MacroGate Adapter
- M08 Progressive Hedge Controller
- M09 AW-Style Recovery Engine
- M10 Hedge Unwind / Recovery Exit Controller
- M11 Port Exposure / Recovery Budget Controller
- M12 Hard Tail / Emergency Cage
- M13 Telemetry + State/Event Logger
- M14 Research Replay / Attribution Harness

Hard rules:
- no module silently mutates another module's owned position state,
- inputs/outputs/state transitions must be explicit,
- parent/child experiments should change one causal layer at a time where practical,
- Recovery ownership must be deterministic and auditable.

## 24. Suggested build sequence
Do not implement the full intelligence stack at once.
Suggested research lineage:
- V1 DD-triggered progressive hedge
- V2 + HTF structure zones
- V3 + break / reclaim / retest logic
- V4 + RSI divergence / exhaustion
- V5 + Weekly / regime context
- V6 + NewsGuard / MacroGate
- V7 + AW-style recovery ownership/integration
- V8 + port-level simultaneous-recovery coordinator

At each step compare against the parent using recovery-specific metrics, not PF alone.
A safe deployable parent can continue generating forward evidence while children are researched.

## 25. Reporting and diagrams
Every meaningful mechanism child should preserve:
- family / variant / parent lineage,
- source/config binding,
- Strategy Thesis,
- Deployment Thesis when applicable,
- what changed vs parent,
- why the change should work,
- intended regime,
- expected failure regime,
- standalone-module evidence,
- combined-system evidence,
- forward evidence when available.

Recovery/hybrid diagrams should expose ownership and interaction among Primary, Secondary, Protection, Recovery, Regime, News/Macro, and Port Controller.
Diagrams have no decision authority; evidence and ratified policy remain authoritative.

## 26. Explicit unresolved items for later ratification
Do NOT silently decide these from this working file:
1. Exact Grade A/B/C/D numeric mapping.
2. Replacement of any current universal production/verdict sample floor with strategy-specific sample contracts.
3. Exact BWD treatment for Grade B deployment.
4. Exact DD thresholds for progressive protection/recovery.
5. Exact hedge percentages and progression schedule.
6. Exact support/resistance and divergence definitions.
7. Exact hard recovery/tail limits.
8. Exact portfolio/port recovery budget and allocation policy.
9. Exact LIVE/DEMO promotion semantics.
10. Any default risk change.

## 27. Durable-memory rule
The reason for this file is operational:

> A decision discussed in chat is transient until it is migrated into a durable repo owner.

This file is durable working memory, not a ratified policy owner.
Once individual rules are explicitly approved, migrate them into the appropriate canonical owner and mark the corresponding section here as RATIFIED with a pointer to that owner.

Current canonical base at capture start: `80006b62d919ae147004b63e2a8a82d3839bc44b`.
Capture date: 2026-08-30.

## 28. Direction asymmetry and regime allocation
If BUY and SELL both retain credible edge but one side is stronger in the historical sample, do not assume the weaker side should be permanently removed.
Useful children may include:
- two-sided base,
- side-only specialist,
- regime-aware asymmetric allocation.

The preferred control layer is often allocation rather than rewriting the signal itself.
Example concept: bullish higher-timeframe regime -> normal BUY allocation and reduced SELL allocation; bearish regime -> reverse the weighting.
Exact multipliers are research variables, not defaults.

## 29. Regime overlays and market context
A strategy can remain high quality while its current Regime Fit changes.
Weekly/Daily structure, Weekly MACD, HTF RSI, macro context, volatility state and NewsGuard can be studied as overlays that alter allocation or activation without rewriting the underlying strategy mechanics.
A regime overlay must be tested against the base EA and must show what winners it removes, what losses it avoids, effect on DD, participation, MAIN/BWD behavior and execution.
Do not use guards as an excuse for an unsafe base EA; they are defense-in-depth.

## 30. Multiple qualified presets can coexist
If two parameter regions are independently robust and have different useful personalities, there is no requirement to force one global winner.
Examples include Growth vs Smooth, higher-return vs lower-DD, or different regime specialists.
Both may run as separate deployment instances until forward/portfolio evidence provides a better replacement.
They remain related members of one risk/mechanism cluster when their trade streams are strongly correlated.

## 31. Python Portfolio Supervisor direction
The owner is considering a separate Python supervisor to oversee 30+ EA instances across multiple ports.
Working architecture direction:
- MQL/EA instances remain deterministic execution workers.
- Python acts as portfolio/control-plane intelligence, not as a replacement for local EA safety cages.
- Python may observe DD, exposure, regime, news/macro state, correlation clusters, and recovery state across instances.
- Python may publish bounded commands or allocation states such as NORMAL / REDUCE / BLOCK_NEW / PROTECT / RECOVERY_ALLOWED.
- Local EA hard stops and ownership rules must remain enforceable even if Python is offline.
- Supervisor failure must default fail-safe; an unavailable Python process must not silently increase risk.

Preferred hierarchy:
EA INSTANCE -> STRATEGY/SYMBOL CLUSTER -> PORT -> GLOBAL PORTFOLIO SUPERVISOR.

The supervisor should know each instance's family, symbol, TF, preset, magic/identity, current net exposure, DD, strategy thesis, weak regime, current regime fit, and recovery ownership state.

This is a control-plane concept only. Runtime attachment, live control, and risk-default changes remain owner hard stops.

## 32. Multi-level News/Regime control
NewsGuard and Regime control should not be only binary ON/OFF switches.
Candidate bounded action levels include:
- NORMAL: no restriction.
- REDUCE: reduce new risk/allocation while allowing existing position management.
- BLOCK_NEW: prohibit new entries/adds but allow exits and recovery management.
- PROTECT: permit defensive hedge/protection while blocking offensive risk growth.
- RECOVERY_ALLOWED: permit recovery only when ownership and budget gates pass.
- HARD_FREEZE: no new directional risk; only deterministic risk reduction/exit actions.

Different strategies may respond differently to the same event. A breakout strategy can benefit from volatility that is harmful to a scalper or mean-reversion system.
Therefore the supervisor should combine event severity with Strategy Thesis / regime sensitivity rather than apply one global news switch blindly.

Any future command interface must be explicit, versioned, logged, acknowledged by the EA, and bounded by local safety rules. Loss of communications must not leave ambiguous ownership or half-applied risk state.

## 33. Owner-operable without coding
The control system must not require the owner to read, edit, or debug Python during normal operation.
Python is an implementation detail behind a human-operable control surface.
Normal owner interaction should be through dashboard states, explanations, alerts, bounded controls, and clear health indicators.

Design implications:
- no routine CLI requirement,
- no manual JSON/file editing,
- no need to inspect Python logs to understand current risk state,
- every important automated action needs a human-readable reason,
- dashboard must show command age, heartbeat, current owner of each basket, and whether control is automatic/recommend-only/manual-safe,
- configuration should use named presets and guarded forms rather than raw code,
- recovery internals should not expose per-order manual controls as the normal workflow.

The implementation may be built and maintained by AI/worker lanes, but operation must remain understandable without programming knowledge.

## 34. Control State Contract direction
A common state vocabulary is required between Python, MQL adapters, Recovery, Port Controller, and the Human UI.
Working states:
- NORMAL
- REDUCE
- BLOCK_NEW
- NO_ADD
- PROTECT_1
- PROTECT_2
- PROTECT_3
- LOCK
- RECOVERY_WAIT
- RECOVERY_ALLOWED
- RECOVERY_ACTIVE
- UNWIND
- SAFE_LOCAL
- HARD_FREEZE

State semantics should be explicit and deterministic:
- NORMAL: ordinary strategy behavior within local cages.
- REDUCE: lower permitted new risk; existing management continues.
- BLOCK_NEW: no fresh entries; existing exits/management remain allowed.
- NO_ADD: existing basket can manage/exit but cannot increase directional exposure.
- PROTECT_1/2/3: progressively stronger defensive target while offensive risk growth is blocked.
- LOCK: near/full directional lock under explicit ownership rules.
- RECOVERY_WAIT: basket protected/owned but recovery entries not yet permitted.
- RECOVERY_ALLOWED: recovery engine may begin when local ownership and budget gates pass.
- RECOVERY_ACTIVE: recovery engine owns the defined basket lifecycle.
- UNWIND: progressively reduce hedge/recovery state after confirmed recovery conditions.
- SAFE_LOCAL: supervisor command is stale/offline; no risk increase from old external commands.
- HARD_FREEZE: no new directional risk; only bounded risk-reduction/exit behavior.

These names define intent, not ratified lot/DD values. Exact thresholds and hedge ratios remain unresolved.

## 35. Authority and ownership matrix direction
Every state must answer five questions:
1. Can Primary open a new trade?
2. Can Primary add to an existing basket?
3. Can Secondary open/add risk?
4. Can protection/recovery change hedge exposure?
5. Which component currently owns the basket?

No two components may independently believe they own the same mutable basket.
Python should normally publish desired policy/state; the local EA executes only actions allowed by its local contract and returns ACK/current state.
A Python command cannot override a stricter local hard cage.

## 36. Staged supervisor authority
Automation authority should be introduced progressively rather than jumping directly to autonomous recovery.
Working progression:
- MODE 0 MONITOR ONLY: observe and record; no commands.
- MODE 1 RECOMMEND ONLY: calculate desired state and show it to the owner; no execution authority.
- MODE 2 AUTO LOW-RISK: automatic non-risk-increasing controls such as BLOCK_NEW/NO_ADD where explicitly approved.
- MODE 3 AUTO ALLOCATION/REGIME: bounded allocation changes inside a separately ratified policy.
- MODE 4 AUTO PROTECTION: progressive hedge/protection under ratified limits.
- MODE 5 AUTO RECOVERY: ownership transfer and recovery lifecycle under ratified limits.

Moving to a higher mode changes runtime/risk authority and therefore requires the applicable owner hard-stop approval.
The same dashboard/data model should support all modes so research evidence can accumulate before authority is granted.

## 37. Supervisor data-contract direction
The supervisor needs a stable per-instance telemetry contract rather than scraping terminal UI.
Candidate EA -> Supervisor fields include identity, symbol, TF, family/variant/preset, magic/account/port, heartbeat, equity/balance context, floating P/L, local DD, BUY/SELL/net exposure, basket age/depth, current local state, recovery ownership, last command acknowledged, and local hard-cage status.

Candidate Supervisor -> EA fields include desired control state, regime classification, event/news state, bounded allocation/risk permission, recovery permission, command sequence/version, issue time, expiry/TTL, and human-readable reason code.

EA acknowledgment should include command sequence received, state accepted/rejected, resulting local state, timestamp, and rejection reason when a stricter local cage prevents execution.
Transport can start with auditable shared state files and later change without changing the semantic contract.
