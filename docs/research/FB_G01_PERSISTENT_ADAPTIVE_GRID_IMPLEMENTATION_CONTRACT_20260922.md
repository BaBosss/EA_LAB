# FB-G01 Persistent Adaptive Donchian Grid — executable implementation contract

Status: **OWNER-APPROVED RESEARCH IMPLEMENTATION CONTRACT / SOURCE_NOT_YET_IMPLEMENTED / NO_MT5**
Date: 2026-09-22
Parent design: `FB-G01` in `ea_template/strategy_cards/facebook_derived/FB-G01.md`
Accepted design lineage: `644417b661fe7dd8396adff7fae974ec7046c60a`
Prospective identity: `Boss_25_PersistentAdaptiveGrid` / `LAB_ENTRY_25` / tag `25_PersistentAdaptiveGrid`

## Authority ceiling

This freezes an executable research V0 only. Numeric values below are carrier/research defaults, not optimal/live defaults and not evidence that the external Facebook EA uses the same formulas. No Home/TF, performance, optimizer/HOLDOUT, Candidate/Grade/KINT, deployment, DEMO/LIVE, risk-default or trading authority follows.

## V0 invariant

This strategy deliberately uses **real physical sequential grid positions**. It is not ZCAG's virtual adverse ladder/compressed entry. V0 uses flat lot per rung only: no martingale/geometric progression, generic Recovery, generic Hedge, generic Stack, partial close or pending-order ladder.

The strategy owns cycle anchor/spacing, rung fill map, Donchian regime, basket target, persistence and auto-reset. Shared Execution and hard RiskControl remain safety infrastructure.

V0 requires `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`; netting mode refuses init because simultaneous BUY/SELL inventory and magic-isolated ownership would not be preserved.

## Frozen V0 parameter surface

| Parameter | V0 research default | Meaning |
|---|---:|---|
| `_25_GridPct` | 0.25 | percent of anchor price (0.25%, not 0.25 fraction) |
| `_25_GridATRMult` | 0.75 | ATR component of spacing |
| `_25_ATRPeriod` | 14 | closed-bar ATR period |
| `_25_DonchianBars` | 20 | closed-bar regime lookback |
| `_25_MaxRungsPerSide` | 5 | hard physical rung cap per side |
| `_25_FixedLot` | 0.01 | volume per filled rung before broker normalization |
| `_25_BasketTargetBalancePct` | 0.25 | target = 0.25% of cycle-start balance |
| `_25_SpreadSamples` | 50 | positive tick-spread window |
| `_25_SpreadMedianMult` | 2.5 | relative spread ceiling |
| `_25_SpreadATRCap` | 0.10 | absolute ceiling as fraction of ATR14 |
| `_25_OpenCooldownSec` | 1 | minimum seconds between successful new grid opens |

All values must be validated. Max rungs cannot exceed the implementation's fixed bitmask capacity. Fixed lot/spacing/target must be positive. No runtime auto-widening or auto-multiplier is allowed.

Chart symbol/timeframe are implementation bindings only; HomeSymbol/HomeChartTF are frozen later by the fixed Model-1 contract.

## Cycle start and frozen geometry

A new cycle may start only when all strategy-owned positions and pending orders are flat, no prior close intent is active, persistence is valid, 50 spread samples exist, ATR14[1] is valid, and shared safety permits new orders.

At the first eligible tick:

- `Anchor = (Bid + Ask) / 2`;
- `PctDistance = Anchor * (_25_GridPct / 100.0)`;
- `ATRDistance = ATR(_25_ATRPeriod)[1] * _25_GridATRMult`;
- `Spacing = max(PctDistance, ATRDistance)`.

Anchor, ATR used for spacing and final Spacing are frozen for the entire cycle. They are **not** recomputed/re-anchored while any cycle position is open.

For rung `k=1..MaxRungsPerSide`:

- BUY level = `Anchor - k*Spacing`;
- SELL level = `Anchor + k*Spacing`.

Each side/rung may fill at most once per cycle; there is no refill after a price revisit.

## Physical fill semantics

No pending orders are placed. On every eligible tick:

- a BUY rung is crossed when current Ask `<=` its level;
- a SELL rung is crossed when current Bid `>=` its level.

At most **one new order submission per tick**. If a gap crosses multiple unfilled rungs, select the smallest unfilled `k` (nearest to anchor) that is already crossed and permitted by regime, submit that one, and leave remaining crossed rungs for later ticks. Successful opens respect `_25_OpenCooldownSec`.

Broker-normalized lot must remain exactly one flat V0 rung lot after normalization; if minimum/step rounding would materially change the requested lot, the action is logged and the normalized value is used consistently for that cell. No lot escalation from prior fills.

## Donchian regime director

Regime is recalculated on each new chart bar using decision bar shift 1. Channel excludes the decision bar:

- `Upper = Highest(High[2..DonchianBars+1])`
- `Lower = Lowest(Low[2..DonchianBars+1])`.

Strict rules:

- `Close[1] > Upper` -> `TREND_UP`;
- `Close[1] < Lower` -> `TREND_DOWN`;
- otherwise -> `RANGE`.

No equality breakout. Missing channel data -> `HALT_DATA` for new entries until valid.

Entry permissions:

- `RANGE`: BUY and SELL rungs may fill;
- `TREND_UP`: block new SELL rungs, allow BUY pullback rungs;
- `TREND_DOWN`: block new BUY rungs, allow SELL rally rungs;
- `HALT_*`: no new rung.

A regime change never force-closes existing inventory in V0. It only controls **new** additions.

## Zone clamp and exposure boundary

The zone clamp is exactly the frozen rung map `1.._25_MaxRungsPerSide`; there is no level outside it. Once all permitted rungs on a side are filled, that side cannot add again during the cycle.

With the V0 defaults, the theoretical maximum is 10 positions (5 per side) and 0.10 requested aggregate lots before broker normalization. This is a research carrier bound, not a portfolio/live risk recommendation. Shared RiskControl may stop new orders earlier and always wins.

Zone-clamp contact grants no permission to widen spacing, add rungs, use martingale/recovery, change the anchor, or reset while positions remain.

## Basket target and close lifecycle

At cycle start freeze:

`TargetMoney = CycleStartBalance * (_25_BasketTargetBalancePct / 100.0)`.

The live target predicate uses the existing strategy-owned basket value equivalent to `sum(POSITION_PROFIT + POSITION_SWAP)` for this symbol+magic. Entry commissions are not part of this live trigger; later result reporting must use tester realized net and must not describe the trigger value as realized net profit.

When `BasketProfit >= TargetMoney`:

1. persist `CLOSE_INTENT=1` before discretionary close requests;
2. request close of all owned positions;
3. while close intent is active, no new order/anchor/reset is allowed;
4. retry normal close verification on later ticks until owned positions and pending orders are exactly flat;
5. persist the terminal cycle summary and clear close intent only after flat verification;
6. set `WAIT_NEW_BAR_AFTER_FLAT`; a new cycle cannot start in the same bar/tick as the close.

Shared hard-risk close/halt supersedes target behavior. A failed or partial close never counts as reset.

## Spread guard

Maintain the latest 50 positive `ask-bid` tick spreads. Until the sample window is full, new grid opens are blocked but exits and hard-risk management remain active.

New order permission requires both `CurrentSpread <= 2.5 * Median(last 50 spreads)` and `CurrentSpread <= 0.10 * ATR14[1]` using the exposed V0 parameters. The even-sample median is the mean of the two middle sorted values. Invalid spread or ATR data blocks new orders; no substitute baseline is fabricated.

## Persistence contract

V0 uses terminal Global Variables with an account/symbol/magic-scoped namespace and two-bank commit semantics. The active bank selector is written last; restore accepts only a complete bank with the expected schema version.

Persist at minimum: cycle id/state, anchor, spacing ATR and final spacing, BUY/SELL rung bitmasks, cycle-start balance, cycle-start credit, frozen target money, close-intent flag, last successful open time, last close time and wait-new-bar marker.

On init, owned live positions/pending orders must reconcile exactly with the committed snapshot. Missing fields, namespace collision, impossible bitmasks, or live-inventory mismatch => `PERSISTENCE_MISMATCH_HALT`: manage existing owned positions only through safety/exit logic, block every new rung/reset, and emit an explicit diagnostic. No silent fresh cycle is allowed over unresolved inventory.

When flat with no committed live cycle, initialization may create a fresh empty snapshot. Strategy persistence never adopts positions from another magic.

## Deposit / credit discontinuity

At cycle start freeze balance and credit. The basket money target remains the frozen `TargetMoney` for the lifetime of that cycle.

A credit change, or a balance change while the cycle is live that is not explained by realized strategy-owned deals, sets `ACCOUNT_BASELINE_DISCONTINUITY=1`. While set, no new rungs may open and no target rebasing is allowed. Existing inventory continues under the already-frozen basket target and shared hard-risk controls.

After the basket is flat and the terminal cycle snapshot is committed, the next cycle may take a new balance/credit baseline. External cash movement is therefore never counted as strategy P/L and never changes a live target silently.

## Risk / kill / circuit-breaker behavior

V0 introduces no new account-DD percentage or live risk default. Existing shared hard RiskControl is authoritative every tick and may refuse entries or force its normal emergency action.

If shared safety enters a halt/kill state, FB-G01 blocks new orders and auto-reset. It may not self-clear or start a new cycle merely because price returns inside the grid. Persistence/data/account-mode faults also fail closed until the fault is cleared by the normal initialization/recovery path.

## Source integration shape

Prospective source paths:

- `ea_template/Boss_25_PersistentAdaptiveGrid.mq5`
- `ea_template/core/entries/Entry_PersistentAdaptiveGrid.mqh` as the dedicated cycle/grid owner
- guarded `_25_*` inputs in `ea_template/core/Inputs.mqh`
- `LAB_ENTRY_25` include/init/tick/deinit dispatch in `LabCore.mqh`
- generated input/fingerprint surfaces
- dedicated engineering fixture plus PowerShell cage
- wrapper ownership and PARAM registry/linkage rows.

The engine may reuse shared Execution/RiskControl primitives, but generic Stack/Recovery/Hedge/Basket behavior must be inert for this identity. Existing grid families must remain byte/behavior compatible outside the additive LAB_ENTRY_25 path.

Current ownership gate: `ct-zcag-boss23-v0-impl-20260922` presently owns overlapping `ea_template/core` writer scope. FB-G01 source implementation must remain serialized until that ownership is released/reconciled; this contract does not bypass Registry conflict checks.

## Acceptance before any MT5 performance run

Required before a Model-1 strategy screen:

- wrapper and engineering fixture compile at 0 errors / 0 warnings;
- deterministic tests for anchor/spacing, gap-cross order priority, no-refill masks, regime permissions, spread warmup, basket close/flat/reset, persistence two-bank restore, corrupted snapshot refusal, deposit/credit discontinuity and shared-risk halt;
- adjacent Template regression plus generated input/fingerprint checks;
- clean exact frozen source head and separate read-only GPT Scrutiny;
- one bounded source repair maximum under the future implementation ownership.

Only after source acceptance may a separate fixed Model-1 MAIN+BWD contract freeze HomeSymbol/HomeChartTF and `.set`. The first screen uses no optimizer and no HOLDOUT.

## Hybrid gate

`FB-H01` is explicitly downstream. It may not be implemented, preregistered for performance, or tuned until **both** FB-A01 and FB-G01 have separately accepted source plus usable accepted Model-1 MAIN+BWD evidence. A weak/empty/mechanical-fail parent does not justify silently combining mechanisms.
