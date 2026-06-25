# EA / Strategy Intake Queue

ที่เดียวสำหรับ drop source code + strategy ใหม่ทั้งหมด → ไหลผ่าน funnel มาตรฐานทีละตัว.
**วิธีใช้:** วางไฟล์ลง `_intake_drop/` แล้วเพิ่มแถวใน "QUEUE" ด้านล่าง (สถานะ = NEW). Claude จะไล่ทีละตัว.

## Funnel มาตรฐาน (ทุกตัวต้องผ่านตามลำดับ)
```
0. USABLE?   เช็ค expiry/license/account-lock ก่อนเสียเวลา (กฎ rigor Phase A.0)
1. CLASSIFY  ชนิด (trend/swing/scalp/grid/reversal/breakout) → home TF/symbol + param units
2. SMOKE     3 เดือนล่าสุด, Model 2, <5min, gate PF>=1.40  → ตายไว ถ้าไม่รอด
3. IS/OOS    IS 2023-2026 + OOS 2020-2023, Model 1, gate OOS PF>=1.20
4. ARTIFACT  ตาม class: tight-TP→widen TP x10 | grid/martingale→multiplier=1 | tight-TP/<20pip→Model 4 บังคับ
5. MC        bootstrap >=50 trades, gate PF-5th>=1.0 & ruin~0%  (grid: ใช้ trend-stress+every-tick แทน)
6. CORREL    เทียบกับพอร์ต 5 ตัว — ถ้า corr สูง (>0.7) กับตัวที่มี = ไม่เพิ่มค่า
7. DEMO      ผ่านครบ → deploy demo แยก, monitor >=3 เดือน
```

## กฎเหล็ก (จากบทเรียน 2026-06-22)
- **อย่าเชื่อ report เก่าบนดิสก์** — rerun ด้วย locked .set เสมอก่อนตัดสิน (เจอ stale-report 3 จุดวันนี้: breakout 253t, MG OOS ว่าง)
- TP < 20 pip = **บังคับ** Model 4 ([[feedback_model4_validation]])
- grid/martingale: MC ไม่พอ — ต้อง trend-stress + every-tick (floating DD)
- judge ที่ MAR/Recovery ที่ความเสี่ยงเท่ากัน ไม่ใช่ PF ดิบ

## DROP 2026-06-22 — triage (31 folders = ~31 strategy families, versions within)

### Bucket D — PRIORITY: signal-based, มี MT5, ยังไม่ screen (เลือกเวอร์ชันล่าสุด/folder)
| # | folder | ชนิด | mq5 | สถานะ |
|---|---|---|---|---|
| D1 | (Boss) trend ema +adx | trend+ADX filter | 13 | NEW |
| D2 | (Boss) Dynamic RSI | RSI signal | 27 | NEW |
| D3 | (Boss) RSI OBOS | RSI reversal | 11 | NEW |
| D4 | (Boss) PSAR follow Trend | PSAR trend | 6 | NEW |
| D5 | (Boss) Redbull Racing | ? | 3 | NEW |
| D6 | (Boss) RSI Scalping Gold Low Spread | scalp (tight-TP→M4) | 1 | NEW |
| D7 | (Boss) Infinix | ? | 1 | NEW |
| D8 | (Boss) supermax | ? | 1 | NEW |
| D9 | (Jobot) Billionaire News Nonfarm | news straddle (special) | 2 | NEW |

### Bucket C — LOW PRIORITY: martingale/grid (MT4 track record 0/63; live MG grid พอแล้ว)
Gold Robot Scalping Time Bomb · Gold Time bomb martingale · Grid Horizontal Fibo · Grid dynamic buy only ·
Master GRID ATR (martingale) · Price Action -Martingale +TMA · PA Fibo Martingale Hedging · PA Fibo Advance MM ·
Price action and MM · PSAR MM · grow up · (Boss) Price Action and MM

### Bucket B — น่าจะ screen แล้ว (verify ก่อน re-test เพื่อไม่เสียแรงซ้ำ)
EA MQL5 AI gen (= Boss MTF 1-11 + Adaptive Grid → memory: REJECT เกือบหมด) · Hedging Balance (= Boss Hedging REJECT)

### Bucket E — MT4-only signal (deprioritize: MT4 broker/expiry caveats + 0/63)
EA no way · EA two way · Highest lowest RSI · Redbull following

### Bucket A — ไม่ใช่ candidate (ข้าม)
Template (chassis) · Tools (indicators/utils) · 3. Fxdreema Learner (เรียน, 221 mq4) · gold trading (not work) [user ติดป้าย]

## เสร็จแล้ว / ปฏิเสธแล้ว
(ย้ายแถวลงมาที่นี่เมื่อจบ funnel)

### Bucket D — MT5 smoke COMPLETE 2026-06-22 → 0 SURVIVORS
Smoke results in `_mt5_auto\bucket_d_smoke_results.csv`. Every MT5 .ex5 failed:
| EA | result | reason |
|---|---|---|
| D1 TrendEmaAdx | 0 trades | doesn't fire on MT5 |
| D2 DynRSI | 1-3 trades | thin / non-functional as MT5 port |
| D3 RSI_OBOS | 1 trade -74% | uncalibrated MM, single catastrophic loss |
| D4 PSAR | 1 trade -80% | uncalibrated MM |
| D5 Redbull / D7 Infinix / D8 Supermax | NO_REPORT | EA hangs on MT5 |
| D6 RSI_Scalp | PF 280 / 4t | tight-TP fill artifact + thin (rigor illusion #1) |
| D9 NewsNF | 0 trades | no trigger in window / non-functional |

**Conclusion:** the MT4-origin .ex5 ports do NOT function as standalone MT5 EAs
(hang / 0-trade / catastrophic-MM / tight-TP artifact). Same family conclusion as
the 63-EA MT4 screening — martingale/grid with no naked signal edge.

**Decoded proof:** the cleanest concept (D2 Boss Dynamic RSI) was reverse-engineered
to a clean MT5 EA `(Boss)_RSI_Swing_BB_rev01` (RSI N-bar extreme + BB + MACD, no
martingale). Naked signal = break-even (XAU H4 PF 0.85, EUR H1 0.97, EUR H1 BUY-only
1.03). Confirms the original's edge was the martingale "lot plus", NOT the entry.

**Bucket D MT5 = CLOSED, no candidates.** Track B (the same EAs as MT4 .ex4 on the
MT4 terminal) optional due-diligence — low expected yield (martingale family).

### KEY TOOLING FIX (2026-06-22)
Found via RSI_Swing 0-trade: the `_06_AllowLive` safety gate blocked the Strategy
Tester from placing simulated orders → every default-param backtest = 0 trades.
Fixed in all template EAs: `allow = _06_AllowLive || MQL_TESTER`. Tester now always
simulates; demo/live still gated. This affected/affects every standalone-template EA.
