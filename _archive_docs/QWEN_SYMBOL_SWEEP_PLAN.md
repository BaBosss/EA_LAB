# QWEN AUTONOMOUS TASK — EA_RUNNER Multi-Symbol Sweep
# Created: 2026-06-20 | Assigned to: Qwen via claude-9arm

---

## WHAT YOU ARE DOING

The EA `EA_RUNNER` (MACD crossover + Zero-Line Filter) has been validated on FX majors.
Best result so far: GBPUSD H1 OOS PF=1.11 — this is the baseline to beat.

Your job: optimize + backtest EA_RUNNER on **new instrument types** (indices, oil, metals, crypto,
FX crosses) and report which ones (if any) produce OOS PF > 1.30.

This is a fan-out research run. Report a final table. Do NOT wire anything into production.

---

## FILES AND TOOLS

### EA Binary
- Source: `D:\EA_Project\CURRENT_BUILD\TEMPLATE\EA_RUNNER.mq5`
- Compiled .ex5 deploy path: `D:\MetaTraderData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\`
  (use D: path for file copies — C:\Users\patip\AppData is a junction that causes copy errors)
- MT5 terminal: `D:\Meta 5\terminal64.exe`
- **MT5 must be CLOSED** before any headless run. The scripts abort if terminal64.exe is running.

### Key Scripts (all in `D:\EA_LAB\scripts\`)
| Script | Purpose |
|--------|---------|
| `mt5_optimize.ps1` | Run genetic optimization → writes XML to `_mt5_auto\optimizations\` |
| `mt5_run.ps1` | Single backtest → writes HTML to `_mt5_auto\reports\` |
| `select_robust_pass.py` | Parse optimizer XML → pick plateau-center params |
| `parse_mt5_report.py` | Parse HTML report → extract PF/DD/trades |

### Base Optimize Set
`D:\EA_LAB\_mt5_auto\EARUN_OPT_BASE.set`
Covers: Fast∈{6..24 step 3}, Slow∈{18..48 step 6}, Signal∈{5..13 step 2},
SL∈{150..500 step 50}, TP∈{200..600 step 100}. ZLF locked to true (false = losing).

### Memory Files (read for context if stuck)
- `C:\Users\patip\.claude\projects\D--EA-Project\memory\mt5-headless-test.md` — run commands
- `C:\Users\patip\.claude\projects\D--EA-Project\memory\automation-pipeline-v2.md` — pipeline rules

---

## MT5 MODEL CODES — READ THIS

| Model code | Name | Speed | When to use |
|------------|------|-------|-------------|
| 0 | Every tick | Very slow | Don't use |
| **2** | **Open price only** | **Fastest (~0.5s/run)** | **Optimize + smoke screen** |
| 4 | Every tick real | Slow | Final validation only |

**Use Model=2 for ALL optimize + smoke runs. Use Model=4 only on OOS survivors.**

---

## INSTRUMENT PRIORITY LIST

### Check symbol names FIRST
ThinkMarkets symbol names may differ from standard. Before starting, list what's available:
- Check `D:\EA_LAB\_mt5_auto\` for any existing .set files with symbol names
- Or read any prior backtest HTML in `_mt5_auto\reports\` for symbol naming
- Typical ThinkMarkets names: `US30`, `NAS100`, `UK100`, `GER40`, `XTIUSD`, `XAGUSD`, `BTCUSD`
- If unsure: try the name, check the tester log — "invalid symbol" will appear if wrong

### Tier 1 — INDICES (highest priority — trending markets, MACD typically performs well)
| # | Symbol (try these names) | TF | Why |
|---|--------------------------|-----|-----|
| 1 | US30 (or DJ30, DOW30) | H1 | Dow Jones — strongly trending |
| 2 | NAS100 (or US100) | H1 | Nasdaq — high vol trend |
| 3 | GER40 (or DAX, GER30) | H1 | DAX — European index |
| 4 | UK100 | H1 | FTSE — more range-bound |
| 5 | SPX500 (or SP500, US500) | H1 | S&P 500 |

### Tier 2 — COMMODITIES (different regime — momentum potential)
| # | Symbol | TF | Notes |
|---|--------|-----|-------|
| 6 | XTIUSD (or USOIL, WTI) | H1 | WTI Crude Oil |
| 7 | XBRUSD (or BRENT, UKOIL) | H1 | Brent Crude — skip if XTIUSD passes |
| 8 | XAGUSD | H1 | Silver |
| 9 | XAUUSD | H1 | Gold — commercial EA in portfolio, but EA_RUNNER untested here |

### Tier 3 — FX CROSSES not yet tested
| # | Symbol | TF | Notes |
|---|--------|-----|-------|
| 10 | GBPJPY | H1 | Volatile, trending — promising |
| 11 | EURJPY | H1 | |
| 12 | AUDJPY | H1 | Risk-on/off driven |
| 13 | CADJPY | H1 | Already REJECTED in session 11 (OOS DD=72.9%) — skip |
| 14 | USDCHF | H1 | |
| 15 | EURCAD | H1 | IS PF=2.06 in smoke — promising with dedicated optimize |

### Tier 4 — CRYPTO (test last, likely high spread)
| # | Symbol | TF | Risk |
|---|--------|-----|------|
| 16 | BTCUSD | H1 | Wide spread may kill profit — check spread before optimizing |
| 17 | ETHUSD | H1 | Same concern |

**Skip a symbol if:** broker feed < 3 years of H1 data (insufficient OOS sample).

---

## STEP-BY-STEP WORKFLOW (per symbol)

### Step 0: Verify symbol is available
- Try running a 1-day backtest. If tester log says "invalid symbol" → try alternate name or skip.

### Step 1: OPTIMIZE (IS window only)
```powershell
cd D:\EA_LAB\scripts
& .\mt5_optimize.ps1 `
  -Expert "EA_RUNNER" `
  -Symbol <SYMBOL> `
  -Period H1 `
  -FromDate 2020.01.01 `
  -ToDate 2023.12.31 `
  -SetFile "D:\EA_LAB\_mt5_auto\EARUN_OPT_BASE.set" `
  -Model 2 `
  -Optimization 2 `
  -ReportName "OPT_<SYMBOL>_IS"
```
Output XML: `D:\EA_LAB\_mt5_auto\optimizations\OPT_<SYMBOL>_IS.xml`
Expected time: 5–20 min per symbol (genetic, Model=2).

### Step 2: SELECT ROBUST PARAMS
```powershell
cd D:\EA_LAB\scripts
python select_robust_pass.py "D:\EA_LAB\_mt5_auto\optimizations\OPT_<SYMBOL>_IS.xml"
```
- Use the **center_params** (plateau center), NOT profit-max peak.
- If 0 robust passes → REJECT immediately, skip to next symbol.
- If center_params exist, note the values: Fast, Slow, Signal, SL, TP.

### Step 3: CREATE LOCKED SET (center params)
Write a new .set file at `D:\EA_LAB\_mt5_auto\EARUN_<SYMBOL>_candidate.set`:
```
InpAllowLiveOrders=true
InpUseZeroLineFilter=true
InpMinCrossStrength=0.0
InpVerboseLogging=false
InpHoldBars=0
InpStopLossPoints=<center SL>
InpTakeProfitPoints=<center TP>
InpMacdFast=<center Fast>
InpMacdSlow=<center Slow>
InpMacdSignal=<center Signal>
```

### Step 4: IS BACKTEST (confirm no data snooping)
```powershell
& .\mt5_run.ps1 `
  -Expert "EA_RUNNER" -Symbol <SYMBOL> -Period H1 `
  -FromDate 2020.01.01 -ToDate 2023.12.31 `
  -SetFile "D:\EA_LAB\_mt5_auto\EARUN_<SYMBOL>_candidate.set" `
  -Model 2 -ReportName "BT_<SYMBOL>_IS"
```
Gate: IS PF > 1.30, IS DD < 25%.
If IS fails → REJECT (overfit in optimize).

### Step 5: OOS BACKTEST
```powershell
& .\mt5_run.ps1 `
  -Expert "EA_RUNNER" -Symbol <SYMBOL> -Period H1 `
  -FromDate 2024.01.01 -ToDate 2026.06.01 `
  -SetFile "D:\EA_LAB\_mt5_auto\EARUN_<SYMBOL>_candidate.set" `
  -Model 2 -ReportName "BT_<SYMBOL>_OOS"
```
**This is the verdict gate — Model=2, not seen during optimize.**

Parse results from HTML:
```powershell
cd D:\EA_LAB\scripts
python parse_mt5_report.py "D:\EA_LAB\_mt5_auto\reports\BT_<SYMBOL>_OOS.htm"
```

### Step 6: MODEL=4 VALIDATION (only if OOS PF > 1.30)
```powershell
& .\mt5_run.ps1 `
  -Expert "EA_RUNNER" -Symbol <SYMBOL> -Period H1 `
  -FromDate 2024.01.01 -ToDate 2026.06.01 `
  -SetFile "D:\EA_LAB\_mt5_auto\EARUN_<SYMBOL>_candidate.set" `
  -Model 4 -ReportName "BT_<SYMBOL>_OOS_M4"
```
Gate: Model=4 OOS PF > 1.20 (real-tick spread/slippage eats some profit).

---

## PASS CRITERIA SUMMARY

| Gate | Threshold | Verdict |
|------|-----------|---------|
| OOS PF (Model=2) | > 1.30 | PASS → continue to M4 |
| OOS PF (Model=2) | 1.15–1.30 | WATCH — marginal |
| OOS PF (Model=2) | < 1.15 | REJECT |
| OOS DD | > 35% | REJECT regardless of PF |
| OOS Trade count | < 20 | REJECT (insufficient sample) |
| Model=4 OOS PF | > 1.20 | CONFIRM |
| Model=4 OOS PF | < 1.20 | WATCH (spread eats edge) |

**Baseline to beat:** GBPUSD H1 OOS PF=1.11.

---

## ALREADY TESTED — SKIP THESE

These symbols were already swept with EA_RUNNER / MACD signal:
- GBPUSD H1 → PF=1.11 (locked baseline)
- EURUSD H1 → REJECTED
- USDJPY H1 → REJECTED
- AUDUSD H1 → REJECTED (IS<1.50)
- NZDUSD H1 → REJECTED (IS<1.50)
- USDCAD H1 → REJECTED (used in existing ST_EA03 portfolio)
- EURGBP H1 → REJECTED (OOS PF=1.16)
- GBPCAD H1 → REJECTED (IS<1.50)
- EURCAD H1 → REJECTED by RF gate (OOS RF=0.94) but IS PF=2.06 — OK to retry with deep optimize

---

## OUTPUT FORMAT

At the end of your run, report a table like this:

```
## EA_RUNNER Symbol Sweep Results — 2026-06-2X

| Symbol | TF | Fast | Slow | Sig | SL | TP | IS PF | IS DD% | OOS PF | OOS DD% | OOS T | M4 PF | Verdict |
|--------|----|------|------|-----|----|----|-------|--------|--------|---------|-------|-------|---------|
| US30   | H1 |  12  |  26  |  9  | 300| 400| 1.85  | 8.2%   | 1.62   |  11.4%  |  87   | 1.48  | CONFIRM |
| NAS100 | H1 | ...  | ...  | ... | ...| ...| ...   | ...    | REJECT |  ...    |  ...  | n/a   | REJECT  |
| ...    |    |      |      |     |    |    |       |        |        |         |       |       |         |

Summary: X CONFIRM / Y WATCH / Z REJECT / N tested
```

Then list any CONFIRM/WATCH symbols with the locked .set file path.

---

## IMPORTANT CAUTIONS

1. **Crypto spread** — before optimizing BTCUSD/ETHUSD, run a 1-week backtest and check the
   HTML for "Gross Profit" vs "Commission+Swap". If commissions > 30% of gross profit → REJECT
   without optimizing (spread will kill any OOS edge).

2. **Index data history** — some indices may only have data from 2021 or 2022.
   If optimize XML has < 50 passes → data window too short → skip.

3. **Model=2 vs real spreads** — indices and crypto have variable spread. A PF=1.40 on Model=2
   may drop to 1.05 on Model=4 due to spread. Always run Model=4 before declaring a PASS.

4. **Do not run optimize + backtest on same symbol simultaneously** — MT5 tester is single-instance.
   Run sequentially.

5. **Log file accumulation** — the tester agent log accumulates. To find your run's output:
   grep for EA_RUNNER or the timestamp. Don't assume the tail is your run.
   Agent log: `C:\Users\patip\AppData\Roaming\MetaQuotes\Tester\9CA16B8382AE4CF692710FB36B9DA355\Agent-127.0.0.1-3000\logs\<YYYYMMDD>.log`

---

## ESTIMATED TIME

- Tier 1 (5 indices): ~2hr (optimize) + ~30min (backtests) = ~2.5hr
- Tier 2 (4 commodities): ~1.5hr
- Tier 3 (5 FX crosses): ~1.5hr
- Tier 4 (2 crypto): ~30min (may skip after spread check)

Total: ~6hr if running all tiers. Run Tier 1 first and report; pivot if Tier 1 is promising.
