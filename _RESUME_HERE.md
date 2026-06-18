# RESUME HERE — อัพเดท 2026-06-18 (session 12)

อ่านไฟล์นี้ก่อนเสมอเมื่อเปิด session ใหม่

---

## Portfolio Candidates (ยืนยันแล้ว + MC COMPLETE)

| # | EA | Symbol/TF | IS PF | OOS PF | OOS DD | OOS RF | MC PF5th | MC ruin | Set File | สถานะ |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | MG_v1_locked | CHFJPY M15 | 1.97 | 2.08 | 23.8% | 1.81 | 1.755 | 0% | `_mt5_auto/MG_CHFJPY_v1_locked.set` | CONFIRMED |
| 2 | NuiIndy RSI+ADX | EURUSD H1 | 2.25 | 2.00 | 28.9% | 4.91 | **1.67** | 0% | `_mt5_auto/NuiIndy_EURUSD_robust.set` | CONFIRMED (WATCH DD) |
| 3 | ST_EA03 MACD | GBPUSD H1 | 2.38 | 2.47 | 5.1% | 4.26 | **2.06** | 0% | `_mt5_auto/MACD_GBPUSD_locked.set` | CONFIRMED — Best |
| 4 | ST_EA03 MACD | USDCAD H1 | 1.76 | 2.62 | 6.3% | 2.43 | **2.15** | 0% | `_mt5_auto/MACD_USDCAD_locked.set` | CONFIRMED |

**MC รันครบแล้ว (2026-06-18)** — `_mt5_auto/MC_NuiIndy.json`, `MC_MACD_GBPUSD.json`, `MC_MACD_USDCAD.json`
NuiIndy PF5th=1.67 (3264 trades), MACD_GBPUSD PF5th=2.06 (1150 trades), MACD_USDCAD PF5th=2.15 (918 trades)

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

### Portfolio ปิดแล้ว — 4 EAs พร้อม demo deploy
ดู `DEMO_DEPLOYMENT_PLAN.md` สำหรับขั้นตอน attach บน ThinkMarkets $10k demo

### Portfolio READY — DEPLOY DEMO ได้เลย
ดู `DEMO_DEPLOYMENT_PLAN.md` (อัปเดต 2026-06-18 รวม MC results แล้ว)

### Portfolio Candidate #5 → GBPCHF ผ่าน! (session 12)
MACD บน symbol CHF ใหม่ — IS/OOS validated:
| Symbol | IS PF/DD/RF | OOS PF/DD/RF | Verdict |
|---|---|---|---|
| **GBPCHF** | 1.74 / 7.0 / 2.30 (804t) | **2.16 / 9.5 / 2.11 (955t)** | ✅ PASS candidate #5 |
| EURCHF | 1.66 / 12.1 / **0.86** | 2.03 / 6.4 / 1.73 | ❌ IS RF<1.5 |

**CORRELATION CHECK DONE (session 12) → GBPCHF REJECT เป็นตัวเพิ่ม:**
GBPCHF vs MG_CHFJPY=+0.622 HIGH · vs MACD_USDCAD=+0.802 HIGH · vs MACD_GBPUSD=+0.583 MED · vs NuiIndy=+0.169 LOW
→ correlate สูงกับ 2/4 ตัวที่มี = เพิ่มแล้วเสี่ยงกระจุก ไม่กระจาย. **คง portfolio 4 ตัว.**
ถ้าจะหา #5 จริง: ต้อง family/instrument อื่น (gold/index, ไม่ใช่ CHF/GBP/CAD) corr ต่ำกับทั้ง 4.
deals_GBPCHF.csv อยู่ที่ `_mt5_auto/` (OOS window). Set: `MACD_GBPUSD_locked.set`.

Batch4 + smoke_new (รอบก่อน) ไม่มีตัวผ่าน: Grizzy DD85%, EX162 DD41%, Ben_CR DD69%, Ghost/DayZone 0-trade.

---

## Cent Deployment Sets (session 12) — สำหรับ live cent $100
.set ปรับสำหรับ cent account (lot scale ถูกต้องกับทุน $100):
- Port 1: `MG_CHFJPY_cent.set` · `NuiIndy_EURUSD_cent.set` · `MACD_GBPUSD_cent.set` · `MACD_USDCAD_cent.set`
- Port 2: `*_cent_p2.set` (Magic +100) · Port 3: `*_cent_p3.set` (Magic +200)
- NuiIndy cent ปรับ Lot_Divided 500k→1.1M (lot 0.02→0.01) · MACD/MG ใช้ min lot อยู่แล้ว
- ⚠️ lot บน cent = lot เดียวกับ standard แต่ทุน 100× น้อย → buffer บางมาก, MG grid คือจุดเสี่ยงสุด

---

## EA_LabTemplate V2 — BUILD เสร็จ (session 12) ✅
`ea_template/core/` chassis ใหม่ compile 0/0 → 3 .ex5: `Boss_11_GridTrend` / `Boss_12_Breakout` / `Boss_13_MeanRev`
- Expert name: `EALabTpl\Boss_NN_*` · Design: `ea_template/DESIGN_V2.md` + `OPTIMIZE_GUIDE.md`
- เลขกำกับ enum (21/22/33..), ATR 2 ตัว (signal/risk), Stack 9x + confirm 0-3, cage 0x
- Smoke ยืนยัน: Boss_12 XAUUSD 1088 trades PF 0.94 (default, ยังไม่ opt)
- **GOTCHA:** MQL5 ไม่รองรับ `#if EXPR==n` → ใช้ `#ifdef LAB_ENTRY_11`. Experts\EALabTpl = junction → compile ที่ src แล้ว copy .ex5 (ดู [[ea-lab-template]] memory)
- **Next:** optimize Boss_11/12/13 ด้วย 5 plans (OPTIMIZE_GUIDE) → `gen_plan_set.py`
- Ben_CR_2025 XAUUSD: PF=1.88 แต่ DD=69% → REJECT
ทางเลือกถ้าจะหาต่อ: MACD optimize บน symbol ใหม่ที่ยังไม่ลอง (EURGBP, AUDUSD, NZDUSD)

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

## Validation Log (session 11, 2026-06-18)

### MACD CADJPY IS/OOS — REJECT
Smoke PF=2.24 (2023-2026 IS window) looked promising vs USDCAD 1.76, but:
IS: PF=2.24 DD=11.2% RF=1.57 T=1055 PASS / OOS: PF=1.24 DD=72.9% RF=0.14 FAIL (DD, RF)
Conclusion: default MACD params are GBPUSD/USDCAD specific — don't transfer to CADJPY

### NuiIndy center params (RSI=24, ADX=12) OOS — keep locked (RSI=18, ADX=20)
Center pick had 16 neighbours in plateau vs locked 12 — centre of robust zone
OOS center:  PF=1.97 DD=29.6% RF=3.76 T=2625 WATCH
OOS locked:  PF=2.00 DD=28.9% RF=4.91 T=~2600 WATCH
Locked wins on all 3 metrics. Lesson: when the plateau is flat and broad, center ≈ robust ≈ same perf zone.
Plateau-center still valid as principle; just not a regression in this case.

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
