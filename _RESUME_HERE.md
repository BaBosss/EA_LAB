# RESUME HERE — อัพเดท 2026-06-18 (session 10)

อ่านไฟล์นี้ก่อนเสมอเมื่อเปิด session ใหม่

---

## Portfolio Candidates (ยืนยันแล้ว)

| # | EA | Symbol/TF | IS PF | OOS PF | OOS DD | OOS RF | Set File | สถานะ |
|---|---|---|---|---|---|---|---|---|
| 1 | MG_v1_locked | CHFJPY M15 | 1.97 | 2.08 | 23.8% | 1.81 | `_mt5_auto/MG_CHFJPY_v1_locked.set` | CONFIRMED |
| 2 | NuiIndy RSI+ADX | EURUSD H1 | 2.25 | 2.00 | 28.9% | 4.91 | `_mt5_auto/NuiIndy_EURUSD_robust.set` | CONFIRMED (WATCH DD) |
| 3 | ST_EA03 MACD | GBPUSD H1 | 2.38 | 2.47 | 5.1% | 4.26 | default params | CONFIRMED — Best |
| 4 | ST_EA03 MACD | USDCAD H1 | 1.76 | 2.62 | 6.3% | 2.43 | default params | CONFIRMED — New |

MC ยังไม่ได้รัน: NuiIndy, MACD_GBPUSD, MACD_USDCAD (รันใน session 10)

---

## Portfolio Correlation (OOS 2020-2023, 4 EAs equal 25%)

| Pair | Correlation | Level |
|---|---|---|
| MG_v1 x NuiIndy | 0.541 | MEDIUM |
| MG_v1 x MACD_GBPUSD | 0.768 | HIGH (flag) |
| MG_v1 x MACD_USDCAD | 0.607 | HIGH |
| NuiIndy x MACD_GBPUSD | 0.302 | MEDIUM |
| NuiIndy x MACD_USDCAD | 0.242 | LOW |
| MACD_GBPUSD x MACD_USDCAD | 0.572 | MEDIUM |

Combined (4 EAs): mean return 1.86%/month, worst month -0.81% (Jan 2020)
Blocking flag: MG_v1 x MACD_GBPUSD = 0.768 HIGH (CHF/GBP correlate)

---

## ถัดไปทันที (session ถัดไป)

### หา Portfolio Candidate #5
ตัวเลือก:
- ลอง EAs ใหม่ที่ยังไม่ได้ smoke (batch4 list: Boss Hedging, DayZone v2, GhostBot G07, Ghost JOMHOD, GridProfit2way, Grizzy BUY, NuiIndy TriArb, WinningPro25, E4_7_4, ESQ1004 BBR, EX162 EMA, EX177 Grid, Grid197 ATR, ScalpTrade v23, BlackWolf, Ben CR 2025, oh MasterGrid ATR)
- เน้น non-grid, non-martingale เพื่อหลีก HIGH correlation กับ MG
- ถ้าได้ candidate → รัน 5-EA correlation, พิจารณา drop/weight MG ถ้า HIGH ยังอยู่

---

## Rejection Log (session 10, 2026-06-18)

### EAAmongUs EURUSD H1 — REJECT
Optimize robust pick: Kmartin=1.2, Grid_Distance=100, TP=50
IS: PF=2.40 DD=1.2% RF=3.27 T=595 PASS / OOS: PF=2.24 DD=3.2% RF=1.15 T=532 FAIL
Gate fail: OOS RF=1.15 < 1.50 — martingale, no-SL, RF won't clear gate

### BaronGrid XAUUSD — REJECT
IS PF=1.20 trades=43 — robust params ไม่ transfer

### ST_EA03 MACD multi-symbol
| Symbol | IS PF | OOS PF | OOS DD | Verdict |
|---|---|---|---|---|
| EURUSD H1 | 2.20 | 1.66 | 27.7% | REJECT |
| GBPUSD H1 | 2.38 | 2.47 | 5.1% | PASS Candidate #3 |
| USDJPY H1 | 2.28 | 0.21 | 93.4% | REJECT blowup |
| EURJPY H1 | 1.99 | 1.84 | 27.5% | REJECT DD |
| XAUUSD H1 | 0.81 | — | — | Smoke REJECT |
| GBPJPY H1 | 1.43 | — | — | Smoke REJECT |

### NuiIndy locked: RSI=18, ADX_period=20, ADX_Value=35

---

## Rejection Log (session 1-9)

GSMC Gold (OOS bear), ImmortalGold (DD 230%), BaronGrid EURUSD (OOS PF=1.00),
QSpeed (OHLC artifact), EX197 GBPJPY (RF<1.50), Pivot NZDUSD, HalfTrend, Sentinel,
London Breakout (plateau=NONE), LABTPL all, Boss family (blowup),
Quantum family (artifact), Grizzy BUY (DD 85%), MooDeng family (blowup)

---

## Gate / Pipeline

- Robust gate: PF>=1.20, DD<=20%, RF>=1.50, Trades>=100
- MC gate: ruin<5%, PF 5th pct > 1.0
- IS: 2023.01.01-2026.06.01 / OOS: 2020.01.01-2023.01.01
- Grid/martingale: real DD = report x 2-3x
- Tight trailing (<20pip): MUST Model=4

## คำสั่งหลัก

```powershell
.\scripts\mt5_run.ps1 -Expert "NAME" -Symbol XX -Period H1 -Model 1 -FromDate 2023.01.01 -ToDate 2026.06.01 -SetFile "path.set" -ReportName "label"
.\scripts\mt5_optimize.ps1 -Expert "NAME" -Symbol XX -Period H1 -FromDate 2023.01.01 -ToDate 2026.06.01 -SetFile "path.set" -ReportName "OPT_label"
python scripts\select_robust_pass.py "_mt5_auto\optimizations\OPT_xxx.xml"
python scripts\extract_deals.py report.htm -o deals.csv
python "C:\Users\patip\.claude\skills\portfolio-selector\scripts\portfolio_analysis.py" monthly.csv --mode money --deposit 10000 --weights "A=0.33,B=0.34,C=0.33" -o result.json
```

## Expert Name Rules

- Root: ชื่อตรงๆ เช่น "(ST) EA03 Count MACD v1", "(NuiIndy) Dynamic RSI+ADX Style (4)"
- Subfolder: "folder\name"
- NO REPORT <30s = ชื่อผิด
- Kill MT5: Stop-Process -Name terminal64 -Force -EA SilentlyContinue
- MACD GBPUSD ใช้ default params; Matchagrid ใช้ MG_CHFJPY_v1_locked.set
