# Baseline Analysis - Gold SMC continuous

## Verdict

**NEEDS LOGIC FIX**

This baseline has visible potential, but it is not optimization-ready. The result is profitable over a useful sample, yet the profit is produced by a basket/recovery engine with lot multiplication, no real stop loss on orders, high exposure spikes, and one very large loss event. Optimizing this version would likely optimize recovery survival rather than validate strategy edge.

## Test Context

- Expert: `Gold_SMC_Continuous_MT5`
- Symbol: `XAUUSD`
- Period: `H1 (2025.01.01 - 2026.06.01)`
- History quality: `99% real ticks`
- Initial deposit: `10,000`
- Report currency field: `profit in pips`
- Bars: `8,320`
- Ticks: `90,310,031`
- Files reviewed: MT5 HTML report, XLSX export, testergraph CSV, set file, equity/holding/MFE-MAE/HST images.

## Core Metrics

| Metric | Value |
|---|---:|
| Total net profit | 27,181.36 |
| Gross profit | 87,737.20 |
| Gross loss | -60,555.84 |
| Profit factor | 1.45 |
| Expected payoff | 38.50 |
| Recovery factor | 3.45 |
| Sharpe ratio | 2.00 |
| Total trades | 706 |
| Total deals | 1,412 |
| Win rate | 73.23% |
| Long trades | 429, 78.55% won |
| Short trades | 277, 64.98% won |
| Average win | 169.70 |
| Average loss | -320.40 |
| Median closed-trade profit | 33.70 |
| Largest profit trade | 6,179.84 |
| Largest loss trade | -12,074.24 |
| Average holding time | 18:26:38 |
| Max holding time | 104:00:14 |

## Drawdown And Exposure

| Risk Metric | Value |
|---|---:|
| Balance DD maximal | 12,074.24 (28.25%) |
| Balance DD relative | 28.25% |
| Equity DD maximal | 7,868.09 (22.44%) |
| Equity DD relative | 27.75% |
| Min equity from testergraph | 8,517.96 |
| Max deposit load from testergraph | 92.53% |
| Max input/recovery lot observed | 2.56 |
| Recovery entries >= 0.16 lot | 132 |
| Recovery entries >= 1.00 lot | 15 |
| Longest balance stagnation below prior high | about 109 days |

## Equity Curve Quality

The balance curve is a grind-up with multiple sharp step jumps. It is not a smooth single-position equity curve. The large jumps are caused by baskets closing after recovery sequences, not by steady independent trades.

Quality concerns:

- The curve depends on a few large recovery events.
- February 2026 contributes 7,112.39 profit, about 26% of total net profit.
- The largest loss is -12,074.24, roughly 44% of total net profit.
- A long stagnation period appears from 2026-02-09 to 2026-05-29.
- MFE/MAE plots show a heavy negative outlier and asymmetric tail risk.
- Holding graph shows most positions are moderate duration, but outlier holds and basket closures are meaningful.

## Risk Structure

Risk is the main blocker.

The EA uses `InpLotMultiplier=2` and opens recovery orders after `InpMinGapPts`. Source review confirms the next lot is derived from the last lot times the multiplier. Orders are sent with `SL=0`; exits rely on basket floating profit, daily target, and TP on individual orders. That means adverse moves are absorbed by adding exposure rather than by predefined loss containment.

Risk concerns:

- Drawdown around 28% is high for a baseline before optimization.
- Max deposit load at 92.53% is not acceptable for production-style risk.
- One losing close of -12,074.24 is too large relative to the system's normal median trade of 33.70.
- Recovery cycles reached up to 11 entries and max lot 2.56.
- Basket net exposure reached about 4.2 lots in the reconstructed cycle estimate.
- There is clear martingale-like behavior, even if it is framed as smart recovery.

## Trade Distribution

The sample size is sufficient for a first baseline: 706 trades across about 17 months is not too few.

Distribution concerns:

- Win rate is high at 73.23%, but average loss is about 1.89x average win.
- Median profit is only 33.70, while tail losses are very large.
- Long side is stronger than short side: long win rate 78.55% vs short 64.98%.
- Hour 1 contributes 13,148.53, while hours 20-22 are net negative, including hour 22 at -5,454.59.
- Monthly results are all positive in this sample, but that may be because recovery eventually closed most baskets rather than because every month had clean signal edge.

## Overtrading And Martingale-Like Signs

There is strong recovery behavior:

- `InpLotMultiplier=2`
- `CT_Rec_Buy` / `CT_Rec_Sell` orders appear frequently.
- Lot progression reaches 2.56.
- Basket cycles reach 8-11 entries in multiple periods.
- Large winners and losers cluster around the same recovery events.
- The system has no hard max positions or max lot guard visible in the reviewed logic.

This is not a clean SMC single-entry baseline. It is an SMC-triggered basket recovery system.

## Final Assessment

The EA has potential as a research candidate because it trades often enough, produces a positive baseline, and shows a clear directional edge on long trades. But it should not proceed to optimization until risk containment is added or confirmed:

- hard max recovery levels
- hard max lot
- max floating DD stop
- daily loss stop
- basket loss stop
- optional trading session filter
- clear rule for stopping recovery after regime failure

Current verdict: **NEEDS LOGIC FIX**.
