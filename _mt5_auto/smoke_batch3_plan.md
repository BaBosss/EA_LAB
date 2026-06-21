# Smoke Batch 3 — Untested EAs Plan
# วันที่: 2026-06-19

## Tier 1 — น่าสนใจ (non-grid, unknown strategy)
| # | Expert Name | Symbol | Period | Reason |
|---|---|---|---|---|
| 1 | EX162 - EMA Rising and EMA Crossover | EURUSD | H1 | EMA trend — proven category (MACD works) |
| 2 | (GPM) Almost 1 Direction v1.9.3 | EURUSD | H1 | directional bias — unknown strategy |
| 3 | The Day Zone v2 | GBPUSD | H1 | session-based (London window?) |
| 4 | Knight Sword EA | EURUSD | H1 | unknown — worth 1 smoke |
| 5 | KNTPTT_KnightSword_v2 | EURUSD | H1 | same family v2 |
| 6 | ZyFer_Noname | EURUSD | H1 | mystery EA |
| 7 | Black Wolf EA | EURUSD | H1 | unknown strategy |
| 8 | Boss - 6 Pivot Range Trading | EURUSD | H1 | pivot range (different from grid Boss) |
| 9 | EA Black Dragon MT5 V13 | EURUSD | H1 | unknown, possibly trend |

## Tier 2 — Gold/XAU specific
| # | Expert Name | Symbol | Period | Reason |
|---|---|---|---|---|
| 10 | The Gold Reaper MT5_4.3_fix_@FundedMillionAiress | XAUUSD | H1 | dedicated gold EA |
| 11 | XAU_Scalper_AI_v10 | XAUUSD | H1 | gold scalper AI |
| 12 | Sentinel XAU_1.2_fix | XAUUSD | H1 | XAU variant (KMZ was DD93%, this is different) |
| 13 | Gold_SMC_FiboRecovery_MT5 | XAUUSD | H1 | SMC+Fibo (different from GSMC basket) |

## Tier 3 — Low priority but quick to try
| # | Expert Name | Symbol | Period | Reason |
|---|---|---|---|---|
| 14 | (OH) Fibo Harmonic Pattern V01A | EURUSD | H1 | pattern-based |
| 15 | LQ Scalper | EURUSD | H1 | scalper |
| 16 | Scalping Trading v2.3 | EURUSD | H1 | scalper |
| 17 | SNOWBALL GENIUS HYBRID | EURUSD | H1 | hybrid strategy |
| 18 | Ghost by JOMHOD MA5 | EURUSD | H1 | MA-based ghost |

## Skip (tested or confirmed bad category)
- EA TREND / EA TREND V2 (tested, REJECT)
- (oh) MooDeng Bot (tested, REJECT)
- EX197 (tested, REJECT)
- Winning Pro 2.5 / Winning Semi auto (commercial, pattern = REJECT)
- CHICKEN LITTILE / BS Pofit888 / EasyMoney (commercial noise)
- (OH) Recovery Hedging (hedging = no-SL risk)
- FAST_Rebalance / V2_15 / PUMLOT (unclear utility)
- 11198621 / 143 E4.7.4 / [EX-127 (product IDs)
- Ghost Bot 01 G07 (keep Ghost by MA only)

## Gate
IS: 2023.01.01 - 2026.06.01 | PF >= 1.50, Trades >= 100, DD <= 30%
Symbol default: EURUSD H1 (non-gold) / XAUUSD H1 (gold)
Model: 1 (OHLC)

## Also run in parallel: NuiIndy #5 search
- (NuiIndy) Dynamic RSI+ADX Style (4) on USDJPY H1
- (NuiIndy) Dynamic RSI+ADX Style (4) on AUDJPY H1
- Use NuiIndy_EURUSD_robust.set as starting params
