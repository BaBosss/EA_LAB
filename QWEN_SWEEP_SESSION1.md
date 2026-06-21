# QWEN SWEEP — Session 1 of 3
# Symbols: US30, NAS100
# Estimated time: ~1–1.5 hr
# Run this first. After it finishes, run Session 2.

---

## CONTEXT

EA `EA_RUNNER` (MACD crossover + Zero-Line Filter) is validated on GBPUSD H1 (OOS PF=1.11).
Your job: find new symbols where it works better (OOS PF > 1.30).
This session covers: **US30** and **NAS100** only.

---

## FILES AND TOOLS

- EA source: `D:\EA_Project\CURRENT_BUILD\TEMPLATE\EA_RUNNER.mq5`
- Deploy .ex5 path: `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\`
- MT5 terminal: `D:\Meta 5\terminal64.exe`
- Scripts: `D:\EA_LAB\scripts\`
- Base set: `D:\EA_LAB\_mt5_auto\EARUN_OPT_BASE.set`
- **MT5 must be CLOSED** before any run. Check with: `Get-Process terminal64 -ErrorAction SilentlyContinue`

## MT5 MODEL CODES
- Model=2 = Open price only → use for ALL optimize + backtests in this session
- Model=4 = Real ticks → only if OOS PF > 1.30 at the end

---

## STEP-BY-STEP (repeat for each symbol)

### Step 1 — Optimize (IS: 2020.01.01–2023.12.31)
```powershell
cd D:\EA_LAB\scripts
.\mt5_optimize.ps1 -Expert "EA_RUNNER" -Symbol <SYM> -Period H1 -FromDate 2020.01.01 -ToDate 2023.12.31 -SetFile "D:\EA_LAB\_mt5_auto\EARUN_OPT_BASE.set" -Model 2 -Optimization 2 -ReportName "OPT_<SYM>_IS"
```
Output XML: `D:\EA_LAB\_mt5_auto\optimizations\OPT_<SYM>_IS.xml`
If XML has < 50 passes → REJECT, skip to next symbol.

### Step 2 — Select robust params
```powershell
cd D:\EA_LAB\scripts
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

### Step 4 — IS backtest (confirm)
```powershell
.\mt5_run.ps1 -Expert "EA_RUNNER" -Symbol <SYM> -Period H1 -FromDate 2020.01.01 -ToDate 2023.12.31 -SetFile "D:\EA_LAB\_mt5_auto\EARUN_<SYM>_candidate.set" -Model 2 -ReportName "BT_<SYM>_IS"
python parse_mt5_report.py "D:\EA_LAB\_mt5_auto\reports\BT_<SYM>_IS.htm"
```
Gate: IS PF > 1.30, DD < 25%. Fail → REJECT.

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
| 1 | US30 | H1 | US30, DJ30, DOW30, US30.cash |
| 2 | NAS100 | H1 | NAS100, US100, NAS100.cash |

If symbol name invalid → try alternate → if all fail, mark UNAVAILABLE and skip.

---

## OUTPUT — write results here at the end

Save to `D:\EA_LAB\SWEEP_RESULTS_SESSION1.md`:

```
## Session 1 Results

| Symbol | IS PF | IS DD% | OOS PF | OOS DD% | OOS T | M4 PF | Verdict |
|--------|-------|--------|--------|---------|-------|-------|---------|
| US30   |       |        |        |         |       |       |         |
| NAS100 |       |        |        |         |       |       |         |
```

---

## EXECUTION LOG

### US30
- **Symbol tried:** US30 → history check timeout, no history data from 2020.01.01 to 2023.12.31
- **Alt 1:** DJ30 → symbol not exist
- **Alt 2:** DOW30 → symbol not exist
- **Alt 3:** US30.cash → symbol not exist
- **Verdict:** UNAVAILABLE — all names rejected

### NAS100
- **Symbol tried:** NAS100 → history synchronization error, no XML produced
- **Alt 1:** US100 → symbol not exist
- **Alt 2:** NAS100.cash → symbol not exist
- **Verdict:** UNAVAILABLE — all names rejected

### Overall Session 1 Result
**Both symbols UNAVAILABLE.** No robust parameters found. No locked .set written. No backtests performed. Session 1 cannot proceed to Sessions 2-3 without at least one valid symbol.

**Root cause:** The MT5 terminal (ThinkMarkets-Live) does not have historical data for US30 or NAS100 index symbols. The EURUSD symbol works fine (history available from 2017), but the CFD/contract symbols for US30 and NAS100 are either not subscribed to or not available in this broker's offering.

**Recommendation:** Before running Sessions 2-3, either:
1. Subscribe to US30/NAS100 history in MT5 Market Watch (right-click → Show All / Download History)
2. Use a different broker terminal that has these symbols
3. Switch to alternative symbols that are available (e.g., check what index symbols exist in this terminal)
