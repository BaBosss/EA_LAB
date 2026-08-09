# MERGE-02 Codex Proposal

Scope: independent second opinion from reading source under `D:\EA_Project\CURRENT_BUILD\CORE` and `D:\EA_LAB\ea_template\core` only. I did not use `AGENT_TASKBOARD_MERGE.md` or any Claude merge plan. This write-up is grounded in the code surfaces and top-level contracts/comments in the files themselves.

## 1. Source Inventory

### EA_CORE (`D:\EA_Project\CURRENT_BUILD\CORE`)

Observed file count:

- 114 total files in `CORE\`
- 76 source files (`.mqh`/`.mq5`)
- 20 `*_Contract.mqh` files
- 27 test source files (`*_Test.mq5`)
- 28 implementation modules excluding runners/tests/contracts

What the codebase actually contains:

| Group | Modules seen | Evidence from headers/comments |
|---|---|---|
| Infrastructure / observability | `Logging_v1`, `Diagnostics_v1`, `ConfigValidator_v1`, `EA_Lifecycle` | `Logging_v1` says infrastructure-only logging; `Diagnostics_v1` says infrastructure-only diagnostics; `Config_Contract` defines prefixing, safety gates, and optimizer restrictions; `EA_Lifecycle` wires init/load/validate of the whole stack. |
| Market/runtime adapters | `RuntimeMarketDataTerminalAdapter_v1`, `RuntimeMarketDataAdapter_v1`, `IndicatorDataTerminalAdapter_v1` | Terminal adapter is the single owner of raw terminal reads; market-data adapter normalizes runtime snapshot/rules; indicator adapter is the single owner of raw indicator reads and exposes normalized snapshots. |
| Safety / permissions | `RiskEngine_v1`, `MarketFilter_v1`, `EntryGate_v1`, `ExitGate_v1`, `PortfolioGuardian_v1` | `RiskEngine_v1` is runtime safety state + lot normalization; `MarketFilter_v1` blocks on stale/invalid market data and trade mode; entry/exit gates are permission-only; `PortfolioGuardian_v1` tracks equity peak and blocks new trades after DD breach. |
| Position / state | `PositionTracker_v1`, `StatePersistence_v1` | `PositionTracker_v1` is standalone read-only position tracking; `StatePersistence_v1` stores safe EA metadata only and explicitly does not restore positions/orders. |
| Intent / execution pipeline | `TradeIntent_v1`, `ExecutionValidator_v1`, `ExecutionMock_v1`, `ExecutionEngine_v1` | The contracts separate non-executing intent/validation/mock from the real broker-action owner; `ExecutionEngine_v1` is the only live broker-action owner in EA_CORE. |
| Sizing / trade structure | `LotSizer_v1`, `ScaleExecutor_v1`, `ScaleExecutor_v2` | `LotSizer_v1` is progressive step-on-loss sizing; `ScaleExecutor_v1` opens N market legs with per-leg TP; `ScaleExecutor_v2` is a pending-order pyramid executor with per-leg TP and cancel/close lifecycle. |
| Signals | `StrategySignal_v1` to `v5` | `v2` = MACD crossover, `v3` = MACD + RSI + EMA, `v4` = MACD consecutive-bar confirmation, `v5` = Donchian breakout + ATR-expand filter, `v1` = contract-compatible metadata stub. |
| Test discipline | `ScenarioHarness_v1`, `ScenarioHarness_Cases`, per-module `*_Test.mq5` | The harness is explicit standalone scenario/assertion infra, and almost every module has its own `_Test.mq5` harness. |

Implementation modules present (excluding test/contracts/runners):

- `ConfigValidator_v1.mqh`
- `Diagnostics_v1.mqh`
- `EA_Lifecycle.mqh`
- `EntryGate_v1.mqh`
- `ExecutionEngine_v1.mqh`
- `ExecutionMock_v1.mqh`
- `ExecutionValidator_v1.mqh`
- `ExitGate_v1.mqh`
- `IndicatorDataTerminalAdapter_v1.mqh`
- `Logging_v1.mqh`
- `LotSizer_v1.mqh`
- `MarketFilter_v1.mqh`
- `PortfolioGuardian_v1.mqh`
- `PositionTracker_v1.mqh`
- `RiskEngine_v1.mqh`
- `RuntimeMarketDataAdapter_v1.mqh`
- `RuntimeMarketDataTerminalAdapter_v1.mqh`
- `ScaleExecutor_v1.mqh`
- `ScaleExecutor_v2.mqh`
- `ScenarioHarness_Cases.mqh`
- `ScenarioHarness_v1.mqh`
- `StatePersistence_v1.mqh`
- `StrategySignal_v1.mqh`
- `StrategySignal_v2.mqh`
- `StrategySignal_v3.mqh`
- `StrategySignal_v4.mqh`
- `StrategySignal_v5.mqh`
- `TradeIntent_v1.mqh`

### Boss V2 (`D:\EA_LAB\ea_template\core`)

Observed source count: 16 files.

| Module | What it says it is |
|---|---|
| `Inputs.mqh` | Numbered dropdown/input surface for the chassis; must be included first. |
| `LabCore.mqh` | Shared `OnInit`/`OnTick`/`OnDeinit`; entry is compile-time, added orders are governed by `Stack.mqh`. |
| `Indicators.mqh` | Built-in indicator handles only; signal ATR and risk ATR are separate contexts. |
| `Execution.mqh` | The only place that touches `CTrade` / `OrderSend`; `Exec_Open` is market-only. |
| `ExitManager.mqh` | TP/SL/trailing plus basket exits; `Exit_ManageBasket()` closes the whole basket on money TP/SL or trend exit. |
| `RiskControl.mqh` | Supreme safety cage; hard equity-DD kill closes all and halts. |
| `MoneyManagement.mqh` | First-lot sizing plus progression, all clamped by risk control. |
| `Stack.mqh` | Decides whether to add stacked orders; grid trend vs grid against; operates on added orders only. |
| `Recovery.mqh` | Offensive add-into-loss layer, additive and cage-limited. |
| `Hedge.mqh` | Defensive opposite-direction lock, additive and default off. |
| `Basket.mqh` | Stub for future group/multi-symbol basket logic. |
| `entries/IEntry.mqh` | The entry seam; pure signal only. |
| `entries/Entry_GridTrendMA.mqh` | MA-cross trend signal. |
| `entries/Entry_Breakout.mqh` | Donchian breakout signal. |
| `entries/Entry_MeanReversion.mqh` | BB + RSI mean-reversion signal. |
| `entries/Entry_GridLog.mqh` | Stateful arm-and-wait emulation of a pending stop because the chassis has no pending-order infra. |

Important Boss V2 architecture facts from code:

- `Execution.mqh` is explicitly the only broker-action owner and exposes market open plus basket-wide close helpers.
- `ExitManager.mqh` is explicitly basket-oriented. `Exit_ManageBasket()` checks basket profit and calls `Exec_CloseAll()`.
- `ExitManager.mqh` already contains a compatibility patch for one case where Boss exits conflicted with imported behavior: `_2_SuppressLegTP` exists because a per-leg TP broke basket-cycle parity.
- `Entry_GridLog.mqh` already documents that Boss V2 has no pending-order infrastructure and therefore emulates a resting stop with state plus a market order.

## 2. What Is Worth Porting

My view: port only modules that add missing production capability to Boss V2 without forcing Boss V2 to adopt EA_CORE's whole contract stack. Boss V2 already has a readable broker-action owner, risk cage, sizing, entries, stack/recovery/hedge, and regression harness. The highest-value imports are the parts that fill real gaps: account-level gating, restart safety, pending ladder mechanics, and test style.

| EA_CORE module / group | Port? | One-line reason grounded in Boss V2 |
|---|---|---|
| `ScaleExecutor_v2` concept | YES, but as a new isolated additive mode | Boss V2 currently has no pending-order infra and even `Entry_GridLog` has to emulate pending behavior because `Execution.mqh` is market-only. |
| `PortfolioGuardian_v1` | YES | Boss V2 already has per-EA `RiskControl` kill logic, but it does not expose a clean account high-watermark gate that can block new entries before hard kill. |
| `StatePersistence_v1` | YES | Boss V2 has runtime stateful behaviors (`Entry_GridLog`, recovery/hedge flags, basket management) but no explicit safe metadata persistence layer for restart audit/re-arm safety. |
| `ScenarioHarness_v1` pattern | YES, but port the pattern not the whole framework | Boss V2 has regression at backtest-result level; EA_CORE adds module-level scenario harness discipline that is useful for tricky state machines. |
| `PositionTracker_v1` ideas | MAYBE, selectively | Boss V2 currently infers state from live positions via execution helpers; a read-only snapshot layer may help restart audit, but a full parallel tracker risks duplication. |
| `IndicatorDataTerminalAdapter_v1` pattern | MAYBE, selectively | The single-owner-of-raw-indicator-reads idea is sound, but Boss V2 already centralizes indicators in `Indicators.mqh`, so wholesale port adds indirection without a gap. |
| `RuntimeMarketDataAdapter_v1` / terminal adapter | MAYBE, selectively | Boss V2 lacks a normalized runtime snapshot object, but its simpler single-symbol chassis may only need a small stale/spread snapshot helper rather than the full adapter stack. |
| `ConfigValidator_v1` / `Config_Contract` rules | MAYBE, selectively | Boss V2 would benefit from a lightweight input validator and prefix/safety checks, but not the entire contract-first framework. |
| `Logging_v1` / `Diagnostics_v1` | MAYBE, selectively | Useful ideas for structured diagnostics, but Boss V2's owner-value is readability; a minimal event log is better than importing a large infra layer. |
| `LotSizer_v1` | NO | Boss V2 already has `MoneyManagement.mqh` with fixed/risk first lot and multiple progression modes plus cage clamps. |
| `RiskEngine_v1` | NO | Boss V2 already has `RiskControl.mqh` as the active safety cage and hard-kill owner; duplicating risk authority would create split ownership. |
| `MarketFilter_v1` | NO for full port | Boss V2 may need a tiny spread/session guard, but the full contract-driven filter stack is heavier than the current mold needs. |
| `EntryGate_v1` / `ExitGate_v1` | NO | Boss V2 directly owns entry and exit flow in `LabCore.mqh` and `ExitManager.mqh`; inserting permission gates would complicate a mold designed to stay readable. |
| `TradeIntent_v1` | NO | Boss V2 is intentionally direct and does not need an intermediate intent model unless the whole execution architecture is rewritten, which would violate additive-minimal merge. |
| `ExecutionValidator_v1` | NO | Same reason as `TradeIntent_v1`; Boss V2's execution path is intentionally short and already caged by `RiskControl`. |
| `ExecutionMock_v1` | NO | Useful in EA_CORE's contract pipeline, but redundant if Boss V2 keeps backtest regression plus targeted harnesses. |
| `ExecutionEngine_v1` | NO | Boss V2 already has `Execution.mqh` as the only broker-action owner; a second execution owner is the wrong merge shape. |
| `ScaleExecutor_v1` | NO | `ScaleExecutor_v2` supersedes it and Boss V2 already handles simultaneous/additive market stacking in `Stack.mqh`. |
| `StrategySignal_v1` | NO | It is basically contract-compatible metadata scaffolding, not a missing production edge. |
| `StrategySignal_v2` / `v3` / `v4` / `v5` | NO as framework ports | Boss V2 already has its own entry seam and production entries; if any signal edge matters, port it as a new `entries/Entry_*` implementation, not as EA_CORE signal modules. |
| `EA_Lifecycle.mqh` | NO | Boss V2's `LabCore.mqh` is already the lifecycle root and is deliberately simpler. |
| Full `*_Contract.mqh` layer | NO | This is architecture debt from the perspective of the stated target mold: it increases indirection more than owner-understandability. |
| Full per-module `*_Test.mq5` estate | NO | Port only the test ideas needed for new imported features; cloning the whole harness tree would overfit Boss V2 to EA_CORE's architecture. |

## 3. #1 Technical Risk: `ScaleExecutor_v2` into a Basket-Exit Chassis

The main risk is split exit ownership.

Why I think this is the top risk:

- `ScaleExecutor_v2` is designed around per-leg lifecycle ownership: market leg plus resting pending ladder, each leg has its own TP, refresh promotes pending to filled, and `CloseAll` must cancel resting orders and close live positions.
- Boss V2 is designed around basket ownership: `Exit_ManageBasket()` computes basket money P/L and can call `Exec_CloseAll()` at any tick.
- Boss V2 already has a code comment proving this class of conflict is real: `_2_SuppressLegTP` was added specifically because per-leg TP broke basket parity in the imported GridLog behavior.

Failure mode if merged naively:

1. A ladder leg hits its own TP and disappears.
2. Boss basket logic still sees an open structure and keeps managing on basket money.
3. Resting pending siblings may remain armed when the effective trade thesis is already partially realized.
4. On basket-close, `Exec_CloseAll()` would flatten positions but knows nothing about pending siblings unless the new ladder code also removes them.
5. Result: orphaned pending orders, unintended re-entry after basket close, or fragmented trade accounting where the same "basket" is no longer a single cycle.

Mitigation I would use:

- Do not graft `ScaleExecutor_v2` into current basket exits as "just another stack mode".
- Introduce a separate additive execution mode, default OFF, with one explicit owner of exit lifecycle for that mode.
- In that mode, pending ladder code must own all of these together:
  - placement of pending siblings
  - promotion/pruning state
  - per-leg TP handling
  - OCO or sibling-cancel behavior
  - final flatten that cancels pendings before closing filled legs
- While that mode is active, disable conflicting Boss behaviors for that basket:
  - basket money TP/SL close
  - basket partial close
  - recovery
  - hedge
  - normal `Stack.mqh` add logic
- Keep the integration additive by introducing new inputs default OFF and making the old path unchanged when OFF.

If forced to stage it conservatively, I would do it in two steps:

1. Port pending ladder placement + cancel/refresh state first, but keep per-leg TP/OCO disabled and let Boss basket exit remain sole owner.
2. Only after that passes regression and dedicated harness tests, add a true executor-owned per-leg TP/OCO mode behind a separate OFF-by-default switch.

That sequencing is slower, but it is the safest way to avoid hidden semantic breakage.

## 4. What I Would Explicitly Not Do

- I would not merge EA_CORE as a framework or transplant its contract tree wholesale. Boss V2's value is that the owner can read it.
- I would not port a second broker-action owner. `Execution.mqh` must stay the single owner in Boss V2.
- I would not import `TradeIntent -> Validator -> Mock -> Engine` as a pipeline unless the goal is to replace Boss V2 architecture entirely, which is outside this merge.
- I would not make pending ladder behavior share exit ownership with `ExitManager` on day one. One mode, one exit owner.
- I would not port signal modules as-is. If a signal is valuable, rewrite it as a Boss `Entry_*` module using the existing entry seam.
- I would not duplicate both `RiskEngine_v1` and `RiskControl.mqh`. One safety authority is mandatory.
- I would not port full `PositionTracker_v1` unless restart audit proves Boss needs a richer state snapshot than the current execution helpers can provide.
- I would not clone all EA_CORE test harness files. Port the scenario-testing pattern only where the imported feature has nontrivial state transitions.
- I would not touch live/demo wrappers or existing production EAs during this merge. New capability should land behind OFF-by-default inputs inside the mold and be exercised only by dedicated new wrappers/tests.
- I would not try to make the first merge slice be "perfect parity" for every ST_EA03 nuance. The first slice should establish safe ownership boundaries and regression cleanliness, not maximum feature completeness.

## 5. Bottom Line

If the target is "single production mold that stays understandable", the correct merge shape is selective absorption, not architectural unification.

My priority order would be:

1. `PortfolioGuardian_v1` style account-DD gate
2. `StatePersistence_v1` style safe metadata persistence
3. scenario-harness discipline for stateful features
4. a carefully isolated pending-ladder executor inspired by `ScaleExecutor_v2`

I would not port the contract-first scaffolding, duplicate execution/risk ownership, or move Boss V2 toward EA_CORE's indirection model. The best parts of EA_CORE are the missing capabilities, not the whole architecture.
