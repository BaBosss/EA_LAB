# FB-G01 — Persistent Adaptive Donchian Grid

## 1. Thesis

Harvest range oscillation with a bounded physical grid, but stop blindly adding against an established breakout. Donchian state directs which side may add, adaptive spacing responds to volatility/price scale, and the entire basket is managed as one persistent cycle.

This is a **multi-position basket/grid** hypothesis. The Facebook post's 79/100 code-readiness score is not performance evidence.

## 2. Evidence versus EA_LAB design

Owner-supplied screenshots explicitly mention Percent Grid, BUY/SELL separation, Zone Clamp, Donchian filter, Anti-Churn, Auto Reset, Profit Target, persistent grid/snapshot state, deposit/credit shift, median-of-50 spread handling and Global Variables.

The screenshots do not expose exact formulas for grid spacing, Donchian state, zone-clamp width, profit target, reset semantics or account adjustment. Those details are either explicit EA_LAB design choices below or remain contract fields.

## 3. V0 role

- Direction: two-sided in RANGE state.
- Position style: real sequential grid fills; multiple positions can coexist within one strategy basket.
- Lot progression: flat/fixed per rung only in V0; no martingale or geometric multiplier.
- Regime owner: Donchian state.
- Exit owner: basket-level net-profit target plus shared hard-kill/risk cage.
- Recovery/Hedge: OFF in V0.

## 4. Cycle and anchor

A cycle starts only while the strategy is flat. It freezes one `CycleID`, `Anchor`, spacing inputs and account baseline.

The anchor may be the cycle-start market price or another preregistered deterministic reference; the executable contract must choose exactly one. No silent re-anchoring while positions are open.

## 5. Adaptive grid spacing

Owner-approved design intent:

`GridDistance = max(PercentDistance, ATRDistance)`

where the executable contract freezes:

- percent-of-price definition and reference price;
- ATR timeframe/period/finality;
- ATR multiplier;
- broker tick/point normalization;
- minimum and maximum allowed spacing if any.

The rule is intended to avoid a single hard-coded pip spacing across XAU, BTC and FX. It is not a claim that this formula is optimal.

## 6. Physical grid levels

For spacing `S` and anchor `A`:

- BUY rung `k`: `A - k*S`
- SELL rung `k`: `A + k*S`

A rung may fill at most once per cycle unless the executable contract explicitly defines replenishment. V0 defaults to **no same-rung refill** because repeated churn at one level would obscure the mechanism.

Maximum real rungs per side and maximum aggregate lot remain bounded contract fields. Reaching the zone clamp blocks additional positions; it never widens itself automatically.

## 7. Donchian regime director

The Donchian layer decides which side is allowed to add; it does not own individual grid-rung prices.

Required states:

`RANGE / TREND_UP / TREND_DOWN / HALT`

The executable contract must freeze Donchian lookback, closed-bar breakout rule, equality handling and re-entry-to-range rule.

V0 directional policy:

- `RANGE`: both BUY and SELL grid additions may be enabled within all other gates.
- `TREND_UP`: block new countertrend SELL additions; BUY-side pullback additions may continue only under the frozen basket/exposure limits.
- `TREND_DOWN`: block new countertrend BUY additions; SELL-side rally additions may continue only under the frozen limits.
- `HALT`: no new order; existing basket is managed only by its frozen exit/risk rules.

A future variant may choose to flatten the losing countertrend side on regime change, but V0 does not infer or add that behavior automatically.

## 8. Zone clamp

`ZoneClamp` is a hard inventory boundary around the frozen cycle anchor. Once price reaches the maximum configured rung or aggregate exposure limit, no new grid order may be added beyond it.

A zone-clamp hit is not permission to martingale, widen the grid, start recovery, hedge, or reset the anchor while positions remain open.

## 9. Basket exit and auto reset

All strategy-owned positions in the current cycle form one basket.

Primary V0 exit:

`BasketNetProfit >= BasketTarget`

The executable contract must freeze whether `BasketTarget` is account currency, percent of cycle-start balance, or another deterministic unit. Mixing target units after results is forbidden.

On basket exit:

`EXIT_REQUESTED -> FLAT_VERIFIED -> SNAPSHOT_CLOSED -> RESET -> NEW_CYCLE_ELIGIBLE`

Auto Reset may not begin a new cycle until the prior basket is confirmed flat and the terminal cycle state has been persisted.

## 10. Persistent state

At minimum the implementation must persist and restore:

- strategy identity (`StrategyID + Magic + Symbol + ChartTF` or an equivalently collision-safe key);
- CycleID and cycle state;
- Anchor and frozen spacing inputs/effective spacing;
- filled BUY/SELL rung map;
- basket position identity/count and aggregate lots;
- balance/credit baseline used by the cycle;
- last open/close timestamps needed by anti-churn;
- reset/invalidation reason.

The screenshot mentions terminal Global Variables. EA_LAB does not treat that storage mechanism as mandatory until the implementation contract evaluates atomicity, namespace collision and recovery behavior.

## 11. Deposit / credit change handling

An external balance or credit change during a live basket must not be mistaken for grid profit or loss.

V0 requirement: detect a baseline discontinuity and record it separately from trading P/L. Whether a changed balance/credit rebases the basket target, freezes new entries, or waits until the next cycle is an explicit implementation-contract decision. No silent rebasing.

## 12. Adaptive spread guard

Owner-approved concept: sample recent spreads and use a robust baseline rather than only a fixed `MaxSpread`.

The first executable design should preserve the screenshot's idea of a median over 50 qualified samples, with a frozen sample cadence and multiplier, plus an absolute emergency spread ceiling. Missing/invalid spread history fails closed for new entries rather than fabricating a normal baseline.

## 13. Anti-churn

Mandatory mechanics:

- one order submission per decision/tick boundary;
- same-rung duplicate guard;
- `MinHold` before strategy-driven non-emergency close if enabled;
- `OpenCooldown` and `CloseCooldown` as frozen parameters if enabled;
- no auto-reset until flat verified;
- no repeated re-anchor while the basket is live;
- deterministic handling of pending/position race conditions.

## 14. Relationship to ZCAG and current grids

This strategy deliberately keeps **real physical grid fills**. ZCAG deliberately keeps the adverse ladder virtual while flat and compresses exposure later. They are separate hypotheses and should never share one test cell as if they were equivalent.

Existing B11/B14 and other grid families remain unchanged. Reusing shared Template services does not grant authority to rewrite their semantics.

## 15. Required evidence

Before any edge claim, report at minimum:

- position count over time;
- rung fills and same-rung duplicate refusals;
- lot ladder and aggregate lots/exposure;
- grid span and time in basket;
- basket net P/L and exit reason;
- zone-clamp and spread-guard refusals;
- restart/restore and deposit-credit discontinuity cases;
- regime-state time and blocked countertrend additions;
- PF/net/DD/trades only from an authorized Model-1 research contract;
- frozen same-lineage Model-4 MAIN+BWD before Candidate eligibility.

## 16. Direct consumer

A future dedicated Template identity/entry/basket engine after a separate executable implementation contract and after current core-writer conflicts clear. This design does not allocate a Boss number or LAB_ENTRY.
