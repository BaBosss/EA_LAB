# QWEN SWEEP — Session 2 of 3
# Symbols: GER40, UK100, SPX500
# Estimated time: ~1.5–2 hr
# Run after Session 1 is done.

---

## CONTEXT

EA `EA_RUNNER` (MACD crossover + Zero-Line Filter) is validated on GBPUSD H1 (OOS PF=1.11).
Your job: find new symbols where it works better (OOS PF > 1.30).
This session covers: **GER40**, **UK100**, **SPX500**.

Session 1 already ran US30 and NAS100. Check `D:\EA_LAB\SWEEP_RESULTS_SESSION1.md` for those results.

---

## FILES AND TOOLS

- Deploy .ex5 path: `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\`
- MT5 terminal: `D:\Meta 5\terminal64.exe`
- Scripts: `D:\EA_LAB\scripts\`
- Base set: `D:\EA_LAB\_mt5_auto\EARUN_OPT_BASE.set`
- **MT5 must be CLOSED** before any run.

## MT5 MODEL CODES
- Model=2 for ALL optimize + backtests
- Model=4 only if OOS PF > 1.30

---

## STEP-BY-STEP (repeat for each symbol)

### Step 1 — Optimize (IS: 2020.01.01–2023.12.31)
```powershell
cd D:\EA_LAB\scripts
.\mt5_optimize.ps1 -Expert "EA_RUNNER" -Symbol <SYM> -Period H1 -FromDate 2020.01.01 -ToDate 2023.12.31 -SetFile "D:\EA_LAB\_mt5_auto\EARUN_OPT_BASE.set" -Model 2 -Optimization 2 -ReportName "OPT_<SYM>_IS"
```
If XML has < 50 passes → REJECT.

### Step 2 — Select robust params
```powershell
python select_robust_pass.py "D:\EA_LAB\_mt5_auto\optimizations\OPT_<SYM>_IS.xml"
```
Use `center_params`. If 0 robust passes → REJECT.

### Step 3 — Write locked .set
Write to `D:\EA_LAB\_mt5_auto\EARUN_<SYM>_candidate.set`:
```
InpAllowLiveOrders=true
InpUseZeroLineFilter=true
InpMinCrossStrength=0.0
InpVerboseLogging=false
InpHoldBars=0
InpLotSizerMode=0
InpLotSizerBase=0.01
InpLotSizerStep=0.01
InpLotSizerMax=0.10
InpLotSizerLegs=5
InpLotSizerOnMax=0
InpStopLossPoints=<center SL>
InpTakeProfitPoints=<center TP>
InpMacdFast=<center Fast>
InpMacdSlow=<center Slow>
InpMacdSignal=<center Signal>
```

### Step 4 — IS backtest
```powershell
.\mt5_run.ps1 -Expert "EA_RUNNER" -Symbol <SYM> -Period H1 -FromDate 2020.01.01 -ToDate 2023.12.31 -SetFile "D:\EA_LAB\_mt5_auto\EARUN_<SYM>_candidate.set" -Model 2 -ReportName "BT_<SYM>_IS"
python parse_mt5_report.py "D:\EA_LAB\_mt5_auto\reports\BT_<SYM>_IS.htm"
```
Gate: IS PF > 1.30, DD < 25%.

### Step 5 — OOS backtest (verdict)
```powershell
.\mt5_run.ps1 -Expert "EA_RUNNER" -Symbol <SYM> -Period H1 -FromDate 2024.01.01 -ToDate 2026.06.01 -SetFile "D:\EA_LAB\_mt5_auto\EARUN_<SYM>_candidate.set" -Model 2 -ReportName "BT_<SYM>_OOS"
python parse_mt5_report.py "D:\EA_LAB\_mt5_auto\reports\BT_<SYM>_OOS.htm"
```
Gate: OOS PF > 1.30, DD < 35%, Trades > 20.

### Step 6 — Model=4 (only if OOS PF > 1.30)
```powershell
.\mt5_run.ps1 -Expert "EA_RUNNER" -Symbol <SYM> -Period H1 -FromDate 2024.01.01 -ToDate 2026.06.01 -SetFile "D:\EA_LAB\_mt5_auto\EARUN_<SYM>_candidate.set" -Model 4 -ReportName "BT_<SYM>_OOS_M4"
python parse_mt5_report.py "D:\EA_LAB\_mt5_auto\reports\BT_<SYM>_OOS_M4.htm"
```
Gate: Model=4 OOS PF > 1.20.

---

## SYMBOLS THIS SESSION

| # | Symbol | TF | Try names |
|---|--------|----|-----------|
| 1 | GER40 | H1 | GER40, DAX, GER30, DE30 |
| 2 | UK100 | H1 | UK100, FTSE, UK100.cash |
| 3 | SPX500 | H1 | SPX500, SP500, US500, SPX500.cash |

If symbol name invalid → try alternate → if all fail, mark UNAVAILABLE.

---

## OUTPUT — write results here at the end

Save to `D:\EA_LAB\SWEEP_RESULTS_SESSION2.md`:

```
## Session 2 Results

| Symbol | IS PF | IS DD% | OOS PF | OOS DD% | OOS T | M4 PF | Verdict |
|--------|-------|--------|--------|---------|-------|-------|---------|
| GER40  |       |        |        |         |       |       |         |
| UK100  |       |        |        |         |       |       |         |
| SPX500 |       |        |        |         |       |       |         |
```
