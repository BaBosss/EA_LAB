# QWEN TASK — MT4 EA Smoke Screen (batch)

You are screening MT4 Expert Advisors by running headless backtests.
Everything you need is below. Do NOT improvise paths or parameters.

## FIXED SETUP (do not change)
- Backtest script: `D:\EA_LAB\scripts\mt4_run.ps1`
- Parser: `D:\EA_LAB\scripts\parse_mt4_report.py`
- Results CSV (APPEND to this): `D:\EA_LAB\_mt4_auto\MT4_SCREEN_RESULTS.csv`
- Period: **H1** | Model: **2** | Window: **2025.06.01 → 2026.06.01**
- Symbols: test EACH EA on **XAUUSDc** then **EURUSDc**
- MT4 GUI must be CLOSED. The script aborts if a terminal is open — if it aborts,
  STOP and report (do not pass -Force).

## COMMAND PATTERN (run for each EA × each symbol, SEQUENTIALLY — never in parallel)
```powershell
& "D:\EA_LAB\scripts\mt4_run.ps1" -Expert "<EA NAME>" -Symbol XAUUSDc -Period H1 -FromDate 2025.06.01 -ToDate 2026.06.01 -ReportName "<TAG>_XAU" -Model 2 -TimeoutSec 300
python "D:\EA_LAB\scripts\parse_mt4_report.py" "D:\EA_LAB\_mt4_auto\reports\<TAG>_XAU.htm" --csv | Out-File "D:\EA_LAB\_mt4_auto\MT4_SCREEN_RESULTS.csv" -Append -Encoding utf8
```
Then repeat with `-Symbol EURUSDc` and `ReportName "<TAG>_EUR"`.
- `<EA NAME>` = exact name from the list (keep spaces/Thai chars; no `.ex4`).
- `<TAG>` = short uppercase id you pick (e.g. ARTGOLD, ZEUS, GREEZLY).
- If a run prints "NO REPORT": the EA failed to init / is locked / crashed.
  Append this line manually to the CSV and move on:
  `<EA NAME>,<SYM>,SKIP,,,,,,,NO_REPORT`

## RULES
1. One backtest at a time. Wait for each to finish before the next.
2. After every EA, the CSV must have 2 new rows (XAU + EUR), or a SKIP line.
3. Do NOT delete or rewrite existing CSV rows — only append.
4. Do NOT change mt4_run.ps1 or the parser.

## VERDICT (parser sets it automatically)
PASS = PF≥1.40 | WATCH = 1.10–1.40 | REJECT = PF<1.10 | THIN = <10 trades | NO_DATA

## WHEN DONE (your batch only)
Report a markdown table of YOUR batch sorted by XAU PF descending:
`EA | XAU PF | XAU DD% | XAU trades | EUR PF | verdict`
Flag any with DD>30% AND trades>2000 as "GRID risk".

---

## BATCHES (61 EAs) — do the batch you are told, e.g. "BATCH 1"

### BATCH 1
- (Jobot) Billionaire News EA ATR Hand
- (Jobot) Greed and Fear v3
- (Jobot) Price Action - Trend Line -Fibo -Martingale v3.2 Hedging + atr + nearby
- (NiyomBot) RSI Dynamic Candle V3.1
- AlgoScalpPro_2.6_Update
- ARTGOLDPro_TFH1Complete
- Aui grid 1.0 mt4
- AW Recovery EA V3.3_fix
- Boring Pips MT4_4.3_fix
- Broker Killer v 2 .2 by @SoftechFX_Robot
- BuRengNong207_FiniteBreakOut
- BuRengNong2073
- ClevrFX_EA
- DHW GoldEA4
- EA 2050 Pro 

### BATCH 2
- EA Game Changer_fix
- EA IRON MAN V.10
- EA Lambo   43168831
- EA Re Mink-Kwan 1.6
- EA Rebalance V.5+ by [NVF]
- EA_Golden_Elephant
- EA_Golden_Mammoth
- EA-HOKKYDJONG
- Espresso_Gold_Pro
- EURUSD Trading Forex Robot
- EX18 - GTSแก้แล้ว and Profit First_Last Closing Oder RV1+puUpper_limit
- Fancy Meal run_rev1 atr nearby
- Fibot EA
- Fx Setka Trader v2
- GARRY’S AI

### BATCH 3
- Ghost Bot 01 G07 (1)
- GMGS PRO V2 EA 01 2027
- God_s Blessing Expert
- God's Blessing Expert
- Gold Buster MT4-2.3-fix-1428+
- Gold_Kangaroo
- Goldex AI 1.4 @SoftechFX_Robot
- Greezly Bot Pro
- HFT2
- Infinix Currency  Ea
- Infinix ea
- Jesko_fix
- KRAPOOK AI 2026 SNIPER 1.1 SmartUnlock MT4
- KRAPOOK BLUE ANT GOAL KEEPER 1.00
- KRAPOOK YELLOW  ANT  BACK CENTER 1.00

### BATCH 4
- KZM V.1.20
- Little Birds EA
- Lots ex1+4 1111 P m1
- LOW_DD_EA
- MTG-SNB EA
- Pegasus Pro
- Quantum Dark Gold
- Quantum Dark Gold_fix
- Quantum King
- Ro ver.011The King Man Envelope  Follow Trend
- Ro ver.20 The King Man000
- SkyFX EA_fix
- SMC V2
- Vigorous EA
- Winning Pro 3.5
- Zeus Gold Hedge V1.2_fix_1420
