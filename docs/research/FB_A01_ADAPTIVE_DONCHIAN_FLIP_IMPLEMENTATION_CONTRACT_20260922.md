# FB-A01 Adaptive Donchian Trend Flip — executable implementation contract

Status: **OWNER-APPROVED RESEARCH IMPLEMENTATION CONTRACT / SOURCE_NOT_YET_IMPLEMENTED / NO_MT5**
Date: 2026-09-22
Parent design: `FB-A01` in `ea_template/strategy_cards/facebook_derived/FB-A01.md`
Accepted design lineage: `644417b661fe7dd8396adff7fae974ec7046c60a`
Prospective identity: `Boss_24_AdaptiveDonchianFlip` / `LAB_ENTRY_24` / tag `24_AdaptiveDonchianFlip`

## Authority ceiling

This contract freezes an executable **research V0** so source can be implemented and mechanically reviewed. Numeric values below are carrier/research defaults, not profitable/optimal/live defaults. It creates no Home/TF claim, performance claim, optimizer/HOLDOUT authority, Candidate/Grade/KINT, deployment, DEMO/LIVE, risk-default or trading authority.

Owner authorization is the 2026-09-22 approval to implement the previously proposed FB-A01/FB-G01 strategies. The external Facebook screenshots remain concept evidence only; formulas and numeric values below are explicit EA_LAB choices, not claims about the external EA.

## V0 invariant

One strategy-owned directional position maximum. No Stack, Recovery, Hedge, partial-close, fixed TP or pending-order path may act. The strategy owns signal, initial SL, SuperTrend trail and stop/reverse lifecycle; shared Execution and hard RiskControl remain safety infrastructure.

V0 requires a hedging-mode account/tester (`ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`) so position ownership by strategy magic remains unambiguous. Netting mode refuses init.

## Frozen signal timing

All strategy decisions are closed-bar only. On the first tick of a new chart bar, decision bar = shift 1. The same decision bar may be acted on at most once except that a previously armed close/flat/reverse state may finish later in that same bar.

Donchian channel excludes the decision bar:

- `Upper = Highest(High[2..DonchianBars+1])`
- `Lower = Lowest(Low[2..DonchianBars+1])`
- equality is **not** a breakout; BUY needs strict `>` and SELL needs strict `<`.

Chart symbol and chart timeframe are the source binding. HomeSymbol/HomeChartTF are deliberately not frozen here; they belong to the later fixed Model-1 contract.

## Frozen V0 parameter surface

| Parameter | V0 research default | Meaning |
|---|---:|---|
| `_24_DonchianBars` | 20 | closed-bar channel lookback |
| `_24_ST_ATRPeriod` | 10 | SuperTrend ATR period |
| `_24_ST_Mult` | 3.0 | SuperTrend band multiplier |
| `_24_ATRPeriod` | 14 | entry/SL volatility ATR |
| `_24_ATRPctLookback` | 100 | prior closed ATR samples for percentile |
| `_24_ATRPctLow` | 20.0 | below this = LOW/block |
| `_24_ATRPctHigh` | 80.0 | at/above this and below Extreme = HIGH |
| `_24_ATRPctExtreme` | 95.0 | at/above this = EXTREME/block |
| `_24_BufferATR_Normal` | 0.10 | breakout buffer in NORMAL |
| `_24_BufferATR_High` | 0.20 | breakout buffer in HIGH |
| `_24_SL_ATR_Normal` | 2.0 | initial SL ATR distance in NORMAL |
| `_24_SL_ATR_High` | 2.5 | initial SL ATR distance in HIGH |
| `_24_FixedLot` | 0.01 | research fixed order volume before broker normalization |
| `_24_SpreadSamples` | 50 | positive tick-spread sample window |
| `_24_SpreadMedianMult` | 3.0 | relative spread ceiling |
| `_24_SpreadATRCap` | 0.10 | absolute ceiling as fraction of ATR14 |

Input validation must refuse nonsensical ordering (`0 < Low < High < Extreme <= 100`), nonpositive lookbacks/multipliers/lots, or insufficient history. Values are configurable for later prospective experiments but V0 source acceptance tests use the defaults above.

## ATR-percentile semantics

Current volatility value is `ATR(_24_ATRPeriod)[1]` using the standard MT5 ATR definition on the chart timeframe.

Percentile is deterministic and excludes the current ATR from its comparison population:

`Pct = 100 * count(ATR[j] <= ATR[1], j=2..Lookback+1) / Lookback`.

Ties count as `<=`. Missing/nonpositive ATR anywhere in the required set makes the signal unavailable; no fallback value is fabricated.

Regime mapping:

- `Pct < Low` -> `LOW`, no new entry;
- `Low <= Pct < High` -> `NORMAL`;
- `High <= Pct < Extreme` -> `HIGH`;
- `Pct >= Extreme` -> `EXTREME`, no new entry.

## SuperTrend semantics

Use `HL2=(High+Low)/2` and ATR(`_24_ST_ATRPeriod`) on closed bars. For each bar processed oldest -> newest:

- `BasicUpper = HL2 + _24_ST_Mult * ATR`
- `BasicLower = HL2 - _24_ST_Mult * ATR`
- `FinalUpper = BasicUpper` when `BasicUpper < PrevFinalUpper` or `PrevClose > PrevFinalUpper`; otherwise carry `PrevFinalUpper`.
- `FinalLower = BasicLower` when `BasicLower > PrevFinalLower` or `PrevClose < PrevFinalLower`; otherwise carry `PrevFinalLower`.
- if previous trend is DOWN and current close `> PrevFinalUpper`, trend becomes UP;
- if previous trend is UP and current close `< PrevFinalLower`, trend becomes DOWN;
- otherwise retain previous trend.

Warmup seed: at the oldest valid processed bar, initialize final bands from that bar's basic bands and trend from `Close >= HL2 ? UP : DOWN`. The decision uses only the finalized trend/bands for shift 1. No current forming-bar state is allowed into the signal.

## Entry rule

Let `A = ATR(_24_ATRPeriod)[1]`.

NORMAL:

- BUY iff `Close[1] > Upper + _24_BufferATR_Normal*A` and SuperTrend[1]=UP.
- SELL iff `Close[1] < Lower - _24_BufferATR_Normal*A` and SuperTrend[1]=DOWN.

HIGH uses `_24_BufferATR_High` instead. LOW/EXTREME cannot open a new position.

The spread gate must pass before opening, but spread never blocks an already-required close or hard-risk action.

## Spread gate

Maintain the latest 50 positive `ask-bid` tick spreads in price units. Until all 50 exist, new entries are blocked. At entry time:

`CurrentSpread <= _24_SpreadMedianMult * Median(last 50 spreads)` **and** `CurrentSpread <= _24_SpreadATRCap * ATR14[1]`.

Median for an even 50-sample set = arithmetic mean of the two middle sorted values. Invalid/nonpositive baseline => block new entry. Sampling and gate state are diagnostics; no fabricated baseline.

## Initial stop and trailing owner

At actual fill request price, initial SL distance is:

- NORMAL = `_24_SL_ATR_Normal * ATR14[1]`;
- HIGH = `_24_SL_ATR_High * ATR14[1]`.

No broker TP is submitted. The only discretionary trailing owner is the finalized closed-bar SuperTrend line. On each new bar, a LONG SL may move upward to the prior closed bar's SuperTrend lower/support line when that line is valid and tighter than the existing SL; SHORT is symmetric. Trailing may never loosen the stop. Broker stop-level normalization/refusal must be explicit in logs/counters; an invalid trail update leaves the prior stop unchanged.

Shared hard-DD/account safety remains evaluated every tick and takes precedence over strategy state.

## Stop-and-reverse state machine

States: `FLAT`, `LONG`, `SHORT`, `CLOSING_FOR_REVERSE`, `HALTED`.

When LONG receives a fully qualified SELL signal (or SHORT receives BUY):

1. latch `pending_reverse_direction` and the decision-bar timestamp;
2. request close of every strategy-owned position; do **not** submit the reverse order yet;
3. every later tick in that same decision bar may retry/finish close verification;
4. only after owned positions are exactly flat and no owned pending order exists may the reverse entry be submitted once, using the already latched closed-bar signal/regime/ATR values;
5. if the bar changes before flat verification, cancel the pending reverse and require a fresh signal on the new closed bar;
6. any open refusal, partial close, stale ownership view or broker error fails closed; no hedge overlap is created.

A same-direction qualified signal while already positioned does nothing. A position discovered on init sets LONG/SHORT from live strategy-owned state; there is no synthetic immediate reverse after restart.

## Source integration shape

Prospective source paths:

- `ea_template/Boss_24_AdaptiveDonchianFlip.mq5`
- `ea_template/core/entries/Entry_AdaptiveDonchianFlip.mqh` (dedicated full-pipeline owner)
- guarded `_24_*` inputs in `ea_template/core/Inputs.mqh`
- `LAB_ENTRY_24` include/init/tick/deinit dispatch in `LabCore.mqh`
- generated input/fingerprint surfaces
- dedicated engineering fixture + PowerShell cage
- wrapper ownership + PARAM registry/linkage rows.

The engine may reuse shared Execution/RiskControl helpers but must return before generic Entry/Stack/Recovery/Hedge/Basket paths can act. Generic shared selectors that are not V0 owners must be explicitly inert/hidden or init-refused.

## Acceptance before any MT5 performance run

Required: compile 0 errors/0 warnings for wrapper and fixture, deterministic formula/state-machine tests including warmup/ties/gaps/reverse-close failure/spread warmup, adjacent Template regression, input-surface/fingerprint gates, clean exact frozen head, separate read-only GPT Scrutiny. One bounded source repair maximum under the future implementation lane.

Only after source acceptance may a separate Model-1 MAIN+BWD contract freeze HomeSymbol/HomeChartTF and `.set`. No optimizer and no HOLDOUT in that first screen.

## Risk / kill / circuit-breaker behavior

V0 introduces no new account-DD percentage and does not alter any existing live/default risk setting. Shared hard RiskControl remains authoritative every tick and may block an entry or perform its normal emergency action regardless of strategy state.

A shared safety halt, invalid account mode, unrecoverable ownership ambiguity, or invalid required indicator history moves FB-A01 to `HALTED` for new entries. Stop/reverse may never be used to escape a safety halt. The strategy does not auto-clear a shared kill condition; recovery follows the existing shared safety lifecycle.

Current ownership gate: `ct-zcag-boss23-v0-impl-20260922` presently owns overlapping `ea_template/core` writer scope. FB-A01 source implementation must remain serialized until that ownership is released/reconciled; this contract does not bypass Registry conflict checks.

## Hybrid gate

`FB-H01` is explicitly downstream. It may not be implemented, preregistered for performance, or tuned until **both** FB-A01 and FB-G01 have separately accepted source plus usable accepted Model-1 MAIN+BWD evidence. No parent weakness may be hidden by premature hybridization.
