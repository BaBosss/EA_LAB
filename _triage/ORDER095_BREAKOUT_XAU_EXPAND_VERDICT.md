# ORDER-095 CAMPAIGN — EA_BREAKOUT_XAU symbol expansion (Opus lead, 2026-07-14)

Per ORDER-095 methodology + build-on-symbol-expand doctrine: EA_BREAKOUT_XAU has confirmed flat-lot
entry edge (source, validated, live on XAUUSD magic 991001) — eligible for expansion per taskboard §576.
Standalone EA, fixed lot 0.01 (no escalation to strip = flat-lot IS the locked config), tester-gate present
(_06_AllowLive, off by default — fine for backtest). Set = `_demo_deploy/MT5/EA_BREAKOUT_XAU_demo.set`
(BuyOnly=true), ex5 = `_demo_deploy/MT5/EA_BREAKOUT_XAU.ex5`.

## Step 1+2 (merged) — flat-lot smoke = full-config test, both-window, H4
`_mt5_auto/order095_breakout_expand_results.csv`

| symbol | MAIN PF | BWD PF | trades | both>1.0 |
|---|---|---|---|---|
| XAGUSD | 1.01 | 0.56 | 149/96 | ✗ (BWD collapse) |
| GBPUSD | 0.91 | 0.84 | 73/40 | ✗ |
| EURUSD | 0.87 | 0.60 | 75/29 | ✗ |
| **USDJPY** | **1.28** | **1.25** | 102/75 | ✅ |
| **US30** | **1.46** | **1.39** | 34/26 | ✅ (thinner sample) |

## Step 3 — correlation vs XAU home leg
`_mt5_auto/corr_order095_breakout.py`, home = `CORR_BRK_XAU_MAIN.htm` (XAUUSD H4 MAIN, 26mo, net 592.0)

| candidate | corr vs XAU leg | shared mo | gate(<0.8) |
|---|---|---|---|
| USDJPY_H4 | 0.066 | 19 | ✅ PASS additive |
| US30_H4 | −0.249 | 14 | ✅ PASS additive (near-zero/slightly negative) |

## VERDICT (lead)
**Both USDJPY H4 and US30 H4 qualify for demo expansion of EA_BREAKOUT_XAU.**
- Both-window PF>1, low DD (0.16–0.35%), near-zero correlation to the existing XAU leg = genuinely additive, not redundant.
- **US30 caveat:** only 26–34 trades total — passes the gate but thinner sample than USDJPY (75–102 trades); size conservatively / treat as WATCH until more OOS accumulates.
- XAG/GBP/EUR fail (BWD PF<1) — breakout-40/ATR-expand/EMA200 mechanism does NOT generalize to those instruments; do not expand there.
- **Next:** add USDJPY (+US30, smaller size) as new EA_BREAKOUT_XAU instances at demo, own magic per symbol (e.g. 991002 USDJPY, 991003 US30), locked set = same params (breakout40/ATR1.5-5/EMA200/buyonly/lot0.01), reuse compiled ex5 (magic differs per instance).
