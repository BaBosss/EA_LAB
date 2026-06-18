# RESUME HERE — อัพเดท 2026-06-18 (session 13)

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

### Portfolio FINAL — 4 EAs CONFIRMED ✅
ดู `DEMO_DEPLOYMENT_PLAN.md` สำหรับ attach บน ThinkMarkets $10k demo + live cent $100
Cent sets: `*_cent.set` (Port1) / `*_cent_p2.set` (+100 Magic) / `*_cent_p3.set` (+200 Magic)

### หา #5 — สถานะล่าสุด (session 13 exhausted MACD+NuiIndy+BossV2)
**Symbols tested (MACD):** GBPCHF ✓IS/OOS แต่ HIGH corr → skip; EURGBP/EURCAD/AUDUSD/NZDUSD/GBPCAD → 0 ผ่าน OOS
**NuiIndy GBPUSD:** IS PF=2.22/RF=19 ดีมาก แต่ OOS DD=36.7% (too high) + GBPUSD corr
**BossV2 (Boss_11/12/13):** 0/8 ผ่าน — ดู rejection log ด้านล่าง

**ตัวเลือกถัดไปที่ยังไม่ลอง:**
1. `NuiIndy บน USDJPY หรือ AUDJPY H1` — JPY carry ให้ ADX trend ชัด
2. `EURCAD optimize ลึก` — IS PF=2.06 แข็งแกร่ง, OOS RF=0.94 fail นิดเดียว อาจแก้ด้วย optimize params
3. `Boss_11 deep entry sweep` — vary FastMA+SlowMA ทั้งคู่ (ปัจจุบัน FastMA=20 fixed)
4. `ยอมรับ 4 EAs` — portfolio สมดุลดีแล้ว ไม่จำเป็นต้องมี #5

### GBPCHF (validated, keep for multi-broker expansion)
IS 1.74/OOS 2.16 ผ่าน แต่ corr สูง: vs MG_CHFJPY=0.622, vs MACD_USDCAD=0.802 → ใช้เมื่อกระจาย broker
Set: `MACD_GBPUSD_locked.set` · deals: `_mt5_auto/deals_GBPCHF.csv`

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
- **Plan E design issue:** `_2_BasketTP_Money=0` default → basket exit ไม่ทำงาน; ต้องเพิ่มค่า BasketTP หรือใช้ ExitMode=22 แทน
- Ben_CR_2025 XAUUSD: PF=1.88 แต่ DD=69% → REJECT

### Boss V2 Optimize Log (session 13) — 0/7 ผ่าน
| EA | Symbol/TF | Plan | IS | OOS | Verdict |
|---|---|---|---|---|---|
| Boss_12_Breakout | XAUUSD H1 | D | 1/18 THIN | PF=0.81 | REJECT |
| Boss_11_GridTrend | XAUUSD H1 | C RUN_TREND | 0/30 | - | REJECT |
| Boss_11_GridTrend | EURUSD H4 | C RUN_TREND | 0/30 | - | REJECT |
| Boss_11_GridTrend | XAUUSD H4 | C RUN_TREND | 0/30 | - | REJECT |
| Boss_13_MeanRev | EURUSD H1 | A | 0/9 | - | REJECT |
| Boss_13_MeanRev | GBPUSD H1 | A2 wider | 2/81 THIN | PF=1.04 | REJECT |

Root cause Boss_11: EXIT_RUN_TREND (mode 24) exits ALL positions on first MA reversal bar → whipsaw kills grid.
Fix tried (C2 ATR_TP): ExitMode=22 (per-order ATR TP) + StackMode=91, XAU H4 72→192 combos → 0 survivors PF_max=1.05 → REJECT
Conclusion: GridTrendMA MA-cross signal has no edge on XAUUSD H4 IS window regardless of exit mode.
Boss_11 SUSPEND — needs deeper entry-param sweep or different instrument before re-trying.
→ ดู "ถัดไปทันที" ด้านบนสำหรับตัวเลือกถัดไป

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

## Validation Log (session 13, 2026-06-18) — MACD new symbols

### MACD new-symbol sweep — 0/5 passed
| Symbol | IS PF/DD | OOS PF/DD/RF | Verdict |
|---|---|---|---|
| EURGBP H1 | 1.94 / 1.4% | 1.16 / 14.3% / 0.49 | REJECT (OOS PF,RF) |
| AUDUSD H1 | 1.48 / 12.1% | — | Skip (IS<1.50) |
| NZDUSD H1 | 1.16 / 21.7% | — | Skip (IS<1.50, DD>20) |
| GBPCAD H1 | 1.26 / 21.2% | — | Skip (IS<1.50, DD>20) |
| EURCAD H1 | 2.06 / 4.2% | 1.49 / 18.6% / 0.94 | REJECT (OOS RF=0.94<1.50) |

Conclusion: MACD default params are GBPUSD/USDCAD specific. Cross pairs with EUR/GBP/CAD don't clear OOS gate.
Note: EURCAD IS strong (PF=2.06) but 2020-2022 COVID+energy-crisis CAD volatility kills RF in OOS.

### NuiIndy GBPUSD H1 — REJECT (DD)
IS: PF=2.22 DD=12.9% RF=19.34 T=4068 (excellent) | OOS: PF=2.05 DD=36.7% RF=7.12 T=4264
Gate fail: OOS DD=36.7% > 20% (even higher than EURUSD's 28.9% exception)
Double reject: same symbol as MACD_GBPUSD → HIGH correlation expected
PF/RF excellent — worth revisiting if portfolio expands to higher DD tolerance or separate broker.

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
