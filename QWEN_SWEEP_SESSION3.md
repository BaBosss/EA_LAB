# QWEN SWEEP — Session 3 of 3
# Symbols: EURCAD
# Estimated time: ~30–45 min
# Run after Session 2 is done.

---

## CONTEXT

EA `EA_RUNNER` (MACD crossover + Zero-Line Filter) is validated on GBPUSD H1 (OOS PF=1.11).
EURCAD showed IS PF=2.06 in a smoke test with GBPUSD params — needs a dedicated optimize.
This is the only FX cross worth retesting.

Sessions 1+2 results are in:
- `D:\EA_LAB\SWEEP_RESULTS_SESSION1.md`
- `D:\EA_LAB\SWEEP_RESULTS_SESSION2.md`

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

## STEP-BY-STEP

### Step 1 — Optimize (IS: 2020.01.01–2023.12.31)
```powershell
cd D:\EA_LAB\scripts
.\mt5_optimize.ps1 -Expert "EA_RUNNER" -Symbol EURCAD -Period H1 -FromDate 2020.01.01 -ToDate 2023.12.31 -SetFile "D:\EA_LAB\_mt5_auto\EARUN_OPT_BASE.set" -Model 2 -Optimization 2 -ReportName "OPT_EURCAD_IS"
```
If XML has < 50 passes → REJECT.

### Step 2 — Select robust params
```powershell
python select_robust_pass.py "D:\EA_LAB\_mt5_auto\optimizations\OPT_EURCAD_IS.xml"
```
Use `center_params`. If 0 robust passes → REJECT.

### Step 3 — Write locked .set
Write to `D:\EA_LAB\_mt5_auto\EARUN_EURCAD_candidate.set`:
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
.\mt5_run.ps1 -Expert "EA_RUNNER" -Symbol EURCAD -Period H1 -FromDate 2020.01.01 -ToDate 2023.12.31 -SetFile "D:\EA_LAB\_mt5_auto\EARUN_EURCAD_candidate.set" -Model 2 -ReportName "BT_EURCAD_IS"
python parse_mt5_report.py "D:\EA_LAB\_mt5_auto\reports\BT_EURCAD_IS.htm"
```
Gate: IS PF > 1.30, DD < 25%.

### Step 5 — OOS backtest (verdict)
```powershell
.\mt5_run.ps1 -Expert "EA_RUNNER" -Symbol EURCAD -Period H1 -FromDate 2024.01.01 -ToDate 2026.06.01 -SetFile "D:\EA_LAB\_mt5_auto\EARUN_EURCAD_candidate.set" -Model 2 -ReportName "BT_EURCAD_OOS"
python parse_mt5_report.py "D:\EA_LAB\_mt5_auto\reports\BT_EURCAD_OOS.htm"
```
Gate: OOS PF > 1.30, DD < 35%, Trades > 20.

### Step 6 — Model=4 (only if OOS PF > 1.30)
```powershell
.\mt5_run.ps1 -Expert "EA_RUNNER" -Symbol EURCAD -Period H1 -FromDate 2024.01.01 -ToDate 2026.06.01 -SetFile "D:\EA_LAB\_mt5_auto\EARUN_EURCAD_candidate.set" -Model 4 -ReportName "BT_EURCAD_OOS_M4"
python parse_mt5_report.py "D:\EA_LAB\_mt5_auto\reports\BT_EURCAD_OOS_M4.htm"
```
Gate: Model=4 OOS PF > 1.20.

---

## OUTPUT — write results here at the end

Save to `D:\EA_LAB\SWEEP_RESULTS_SESSION3.md`:

```
## Session 3 Results

| Symbol | IS PF | IS DD% | OOS PF | OOS DD% | OOS T | M4 PF | Verdict |
|--------|-------|--------|--------|---------|-------|-------|---------|
| EURCAD |       |        |        |         |       |       |         |
```
