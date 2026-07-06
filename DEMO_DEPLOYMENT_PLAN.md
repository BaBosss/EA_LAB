# Demo Deployment Plan — Portfolio v3

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · ไฟล์นี้ owns: **live portfolio** (EA/magic/lot/judge/monitor) เท่านั้น
อัพเดท: 2026-07-05 | สถานะ: 🟢 RUNNING — **9 EA** บน account 10,000 cent (judge 2026-09-22) +
🟢 **Boss_14 cohort 7 EA** บน Exness demo (60,000 USD) — ✅ **ATTACHED 2026-07-05, clock เดินแล้ว** (ดูsection ล่าง)

> **Live clock เริ่ม 2026-06-22** — judge ได้เร็วสุด **2026-09-22** (3 เดือน)
> ทุก EA อยู่บน **account เดียวกัน** (10,000 cent = $100 USD equivalent)

> ✅ **ST_EA03 lot fix DONE (2026-06-22)** — Lots_divided แก้ 10M → 100,000 แล้ว

---

## ภาพรวม EA ทั้งหมด (10,000 cent — account เดียว)

| # | EA | Symbol | TF | Set File | OOS PF | Status | หมายเหตุ |
|---|---|---|---|---|---|---|---|
| 1 | Matchagrid (MG_v1) | CHFJPY | M15 | `MG_CHFJPY_v1_locked.set` | 2.08 | 🟢 LIVE | fixed 0.01 lot ✅ |
| 2 | NuiIndy RSI+ADX | EURUSD | H1 | `NuiIndy_EURUSD_robust.set` | 2.00 | 🟢 LIVE | 10k/500k = 0.02 lot ✅ |
| 3 | ST_EA03 MACD | GBPUSD | H1 | `MACD_GBPUSD_locked.set` | 2.47 | 🟢 LIVE | Lots_divided แก้ → 100,000 (0.1 lot/leg) ✅ |
| 4 | ST_EA03 MACD | USDCAD | H1 | `MACD_USDCAD_locked.set` | 2.62 | 🟢 LIVE | เหมือน EA 3 ✅ |
| 5 | Gold Reaper 4.3 | XAUUSD | H1 | `GoldReaper_cent_v1.set` | 2.07 | 🟢 LIVE | StartLots=0.01 ✅ |
| 6 | EA_BREAKOUT_XAU | XAUUSD | H1 | `_vps_deploy\BRK_XAU_live_v3.set` | 2.94-4.87 | 🟡 RELOAD | **v3 upgrade** Bars=55, TP×8, EMA150. Reload EA in MT5 GUI (F7→load v3.set→OK). IS PF=2.10/Sharpe=3.47, Neighbors=12. |
| 7 | LondonConsoBreakout | GBPUSD | H1 | `_vps_deploy\CB_GBP\CB_GBP_H1_live_v1.set` | 2.08 | 🟢 LIVE | 0.01 lot ✅ |
| 8 | LondonConsoBreakout | EURUSD | H1 | `_vps_deploy\CB_EUR\CB_EUR_H1_live_v1.set` | 1.25 | ❌ DROP (2026-06-25) | Q2 rescue sweep พบ no durable edge (OOS ทั้งคู่ <1.0) → ถอดออกจาก demo. Portfolio จริง = 7 ตัว |
| 9 | EA_RUNNER_ST03 (LR2 replica) | GBPUSD | H1 | `_vps_deploy\ST03_GBPUSD\ST03_GBPUSD_live_v1.set` | 3.93 | 🟡 DEPLOY MON 2026-06-29 (DEMO) | bundle staged + verified 2026-06-26. magic 990010, AllowLiveOrders=true. corr −0.24 vs live ST_EA03 = LOW. |
| 10 | EA_BREAKOUT_XAU (Bars8) | XAUUSD | H1 | `_vps_deploy\BRK_XAU_Bars8\BRKXAUH4_Bars8_demo_v1.set` | 3.92 | 🟡 DEPLOY (DEMO) | Additive leg: corr 0.21 vs live Bars55 (#6). MC PASS (PF_5th 1.73, ruin 0%). Magic=991002. Same chart as #6 (different magic, coexist OK). |

**Promote conditions (กลุ่ม B → portfolio):**
- ≥30 real trades ผ่านไป
- PF ≥ 1.40 จาก live trades
- ไม่ถึง stop rule → promote เข้า Core พร้อมปรับขนาด

**Stop rules กลุ่ม B:**
- EA 6: ถ้า XAU กลับเป็น bear trend ยาว → review BUY-only bias
- EA 7: pause ถ้า DD > 1.5% หรือ 10 consecutive losses — เพิ่ม risk เป็น 1% หลัง 30 trades pass
- EA 8: pause ถ้า monthly DD > 1% หรือ 10 consecutive losses — **อย่าเพิ่ม lot**

---

## 🟢 Boss_14 GridLog cohort — Exness demo (60,000 USD, 7 EA) — ✅ LIVE 2026-07-05

> **บัญชีคนละก้อนกับ 9 EA ข้างบน** (Exness demo, 60,000 USD, 7 EA) · ทุกตัว = **EA เดียวกัน
> `EALabTpl\Boss_14_GridLog`** ต่างแค่ symbol/set/magic · TF = **H1 ทุกตัว**
> · ✅ **ATTACHED 2026-07-05 → demo clock เริ่มนับ → judge เร็วสุด 2026-10-05** (3 เดือน)
> · 📅 **/ea-monitor ครั้งแรก ~2026-07-19** (2 สัปดาห์ · ส่ง live_deals.csv ตาม §6)
> · ⚠️ **XAUUSD 3-digit (Exness) → ใช้ set `Boss14_GridLog_XAU_DEMO_exness3d.set`** (slippage 300, ต่างจาก
>   backtest 2-digit — core ATR-relative เหมือนเดิม) · 6 FX ใช้ `*_DEMO.set` เดิมได้ (ATR-relative)
> · ❓ **CONFIRM account type:** user บอก "60,000 USD" → ถ้า **Standard 60k USD** = ~$8.5k/EA ≈ validation
>   deposit $10k (sizing ตรง ✅) · ถ้าเป็น **cent account** lots (0.10 FX / 0.05 XAU) จะ oversize มาก → รีบแจ้ง Claude

| # | Symbol | Magic | Set File (`ea_template\sets\`) | full-confirm PF | หลักฐาน/ธง |
|---|---|---|---|---|---|
| 1 | USDJPY | 990201 | `Boss14_GridLog_USDJPY_DEMO.set` | 1.51 | OOS 2.77/106t แน่นสุด · ⚠️ plateau มีรอยร้าว: **ห้าม tune step/TP ต่ำกว่าค่านี้** (พลิกขาดทุน) |
| 2 | AUDNZD | 990202 | `Boss14_GridLog_AUDNZD_DEMO.set` | 1.56 | 🏆 ที่ราบสมบูรณ์ (sensitivity 8/8) + ทุกปีบวก = แข็งสุดในคอฮอร์ต |
| 3 | EURJPY | 990203 | `Boss14_GridLog_EURJPY_DEMO.set` | 2.49 | 🔴 **สันเขา (sensitivity 1/8) + fill-sensitive** (M4 eqDD 10%) → **size เบากว่าเพื่อนตอน promote** |
| 4 | AUDCAD | 990204 | `Boss14_GridLog_AUDCAD_DEMO.set` | 1.88 | OOS 4.30 ทุกปีบวก · ที่ราบ (sensitivity 5/8) |
| 5 | CADJPY | 990205 | `Boss14_GridLog_CADJPY_DEMO.set` | 1.89 | 🔴 **สันเขา (sensitivity 2/8) + thin 77t** → **size เบากว่าเพื่อน + จับตาพิเศษ** |
| 6 | EURUSD (SELL) | 990206 | `Boss14_GridLog_EURUSD_DEMO.set` | 1.97 | ฝั่ง SELL (diversity) · ที่ราบปานกลาง |
| 7 | **XAUUSD (ทอง)** | 990207 | **`Boss14_GridLog_XAU_DEMO_exness3d.set`** (3-digit, slippage 300) | 1.42 (OOS 1.15) | 🆕 **non-FX diversifier** (2026-07-05) — ผ่านครบ pipeline (IS-opt→OOS ทุกปีบวก→MC ruin0%→**Model-4 +$5078 edge รอด real ticks**) · **lot 0.05 (de-scaled ครึ่ง เพราะ DD ~2x FX)** · ⚠️ **leg เสี่ยงสุด จับตา DD พิเศษ** · SL cap off (ATR-SL คุม) · **corr ยืนยัน diversifier: AUDNZD -0.59 / CADJPY -0.19 / AUDCAD +0.19 / EURJPY +0.32 = additive · USDJPY +0.53 watch (6mo บาง จับตา) · ไม่มีคู่ >0.60** |

**Config ร่วม:** ทุก set = 0.25x (0.10 lot base) · `_4_DdAdaptiveOn=false` (ปิดเพราะบัญชีแชร์ DD จะปน) ·
sizing นี้ = **วัดพฤติกรรม ไม่ใช่ผลตอบแทน** — ตัวเลข MC worst 6-9% เป็นที่ 0.25x เท่านั้น (live 3-4x → ~25-35%)

**Attach checklist (user ทำใน MT5 ของบัญชี 60k):**
1. เปิด **7 ชาร์ต** **H1** — USDJPY · AUDNZD · EURJPY · AUDCAD · CADJPY · EURUSD · **XAUUSD** (#7 ทอง, lot 0.05)
2. ลาก `Boss_14_GridLog` (จาก Navigator, expert = `EALabTpl\Boss_14_GridLog`) ลงแต่ละชาร์ต
3. แต่ละชาร์ต: F7 → Load → เลือก set ตามตาราง (symbol ให้ตรงชาร์ต!) → OK · เปิด AutoTrading
4. เช็ค magic ในแต่ละ set ไม่ซ้ำกัน (990201-206) + ต่างจาก 9 EA เดิม (คนละบัญชีอยู่แล้ว ปลอดภัย)
5. จดวันที่ attach จริง → แจ้ง Claude เพื่อ set demo-clock + นัด `/ea-monitor` ครั้งแรก ~2 สัปดาห์

**Promote conditions (หลัง demo ≥3 เดือน):** ≥30 real trades · PF ≥ 1.40 จาก live · ไม่ถึง stop rule ·
**ตอน promote ขึ้น lot: EURJPY + CADJPY size เบากว่าเพื่อน (สันเขา), USDJPY คงค่า step/TP เดิม** (จาก
plateau-sensitivity ORDER-022) · corr matrix (ORDER-019): ไม่มีคู่ >0.60, watch USDJPY-CADJPY 0.57 → ลด lot ตัวใดตัวหนึ่ง

**Stop rules:** ตัวไหน eqDD account-wide > 25% (PROTECT_NORMAL KillDD) EA จะ close+halt เอง ·
manual pause ถ้า EA ตัวใด DD ผิดปกติเทียบ backtest (ดูจาก /ea-monitor)

---

## 🆕 ClevrFX_EA — MT4 demo experiment (อนุมัติ 2026-07-06, รอ user attach)

> **ตัวแรกจาก treasure hunt (222 EA) ที่ผ่านครบทุกด่าน** — BWD-OOS ทุกปีบวก (1.76/1.51/2.37) + 2026=2.04 ·
> spread-stress 3x ไม่สะเทือน (sp45=1.93) · ไม่ระเบิดปี hostile · **compiled กลไกดำ → สถานะ demo-experiment
> เท่านั้น** (Fxcore100 คู่กัน = DQ pirated — ตัวเลขเก็บเป็น prior ถ้าซื้อ official ในอนาคต)

**Deploy checklist (user, บน MT4 demo ที่มีอยู่):**
1. **บัญชี:** แนะนำ ClevrFX **ตัวเดียวบนบัญชี** (attribution ตรง + วัด kill-DD ระดับบัญชีได้) · balance
   ใกล้ $10k = เทียบ validation ตรงสุด (ต่างได้ — ดู DD% ไม่ใช่ $)
2. ก็อป `D:\Forex\10_EA_PROJECTS\2. wait for test\.EA OK\ClevrFX\ClevrFX_EA.ex4` → `MQL4\Experts\` → refresh Navigator
3. **Chart: EURUSD H1 · attach ด้วย compiled defaults (ห้ามโหลด .set!)** — เรา validate ที่ default/H1
   (vendor preset = M5-cap500 ≠ config ที่ validate)
4. เปิด AutoTrading → **จดวันที่ attach → แจ้ง Claude** (demo-clock ≥3 เดือน)
5. ⚠️ **no hard SL บนไม้ — เครื่อง/VPS ต้องออนไลน์ตลอด** (disconnect = ไม้เปลือยไม่มี SL บน server)

**Kill-switch:** equity DD บัญชี >40% (= worst year backtest) → detach ทันที · **Monitor:** ~2 สัปดาห์/ครั้ง
export MT4 account statement ส่ง Claude (MT4 ไม่ใช้ /ea-monitor MT5 pipeline — ใช้ statement แทน) ·
**Judge:** ≥3 เดือน + ≥30 trades (ได้ในเดือนเดียว ~1 ไม้/วัน) → PF live ≥1.4 = คุยขั้นต่อ

---

## Account Setup

- **Account: 10,000 cent** (= $100 USD equivalent) — deploy 2026-06-22
- EA 1–5: `.set` อยู่ใน `D:\EA_LAB\_mt5_auto\`
- EA 6–8: `.set` อยู่ใน `D:\EA_LAB\_vps_deploy\` (แต่ละ subfolder)
- Leverage: ตามที่ broker กำหนด, Account type: Hedge

---

## Lot Sizing

| EA | Lot บน 10,000 cent | สถานะ |
|---|---|---|
| MG_v1 CHFJPY | 0.01 (fixed) | ✅ |
| NuiIndy EURUSD | 10k ÷ 500k = **0.02** | ✅ |
| ST_EA03 GBPUSD | 10k ÷ 100k = **0.1/leg** × 3 = 0.3 | ✅ แก้แล้ว |
| ST_EA03 USDCAD | เหมือนกัน | ✅ แก้แล้ว |
| Gold Reaper | StartLots=0.01 | ✅ |
| EA_BREAKOUT_XAU | 0.01 (fixed) | ✅ |
| CB_GBP GBPUSD | 0.01 (fixed) | ✅ |
| CB_EUR EURUSD | 0.01 (fixed) | ✅ |

ST_EA03 แก้แล้ว 2026-06-22: `Lots_divided` 10,000,000 → **100,000** → 0.1 lot/leg × 3 legs = 0.3 total ✅

---

## Magic Numbers (ห้ามซ้ำ)

| Magic | EA |
|---|---|
| 1524 | NuiIndy EURUSD |
| 9397 | ST_EA03 GBPUSD |
| 9398 | ST_EA03 USDCAD |
| (default) | Gold Reaper — ตรวจจาก GUI ก่อน attach |
| 990005 | LondonConsoBreakout (ทั้ง GBPUSD + EURUSD — OK เพราะ filter by _Symbol) |
| 991001 | EA_BREAKOUT_XAU (Bars55, live — v3 set) |
| 991002 | EA_BREAKOUT_XAU (Bars8 additive, DEMO) |
| 990010 | EA_RUNNER_ST03 GBPUSD (LR2 replica — separate account from ST_EA03 EA3) |

---

## Expert Names (MT5 Navigator)

| EA | Expert name |
|---|---|
| Matchagrid | `Matchagrid` |
| NuiIndy | `(NuiIndy) Dynamic RSI+ADX Style (4)` |
| ST_EA03 | `(ST) EA03 Count MACD v1` |
| Gold Reaper | `The Gold Reaper MT5_4.3_fix_@FundedMillionAiress` |
| EA_BREAKOUT_XAU | `EA_BREAKOUT_XAU` |
| LondonConsoBreakout | `(Boss)_LondonConsoBreakout_rev01` |

---

## Monitoring Checklist (รายสัปดาห์)

### กลุ่ม A

| EA | หยุดถ้า | Action |
|---|---|---|
| MG_v1 | Live DD > 35% | Close all MG positions |
| NuiIndy | Live DD > 20% | Review params |
| MACD GBPUSD/USDCAD | PF < 1.0 ใน 30 วัน | Pause + review |
| Gold Reaper ⚠️ | DD > 25% **หรือ** PF < 1.2 ใน 30 วัน | Pause ทันที |
| ทุก EA | ไม่มี trade 2 สัปดาห์ | ตรวจ AutoTrading / connection |

### กลุ่ม B

| EA | หยุดถ้า | เพิ่ม risk ถ้า |
|---|---|---|
| EA_BREAKOUT_XAU (Bars55, #6) | XAU bear trend ยาว | 30 trades, PF ≥ 1.40 |
| EA_BREAKOUT_XAU (Bars8, #9) | XAU bear trend ยาว หรือ corr vs #6 > 0.60 live | 30 trades, PF ≥ 1.40 |
| CB_GBP GBPUSD | DD > 1.5% หรือ 10 consec loss | 30 trades, PF ≥ 1.40 → เพิ่มเป็น 1% |
| ~~CB_EUR EURUSD~~ | **DROPPED 2026-06-25** | Q2 rescue sweep (48 combo × 3 win) ไม่เจอ durable edge — OOS ทั้งคู่ <1.0. GBPUSD-only confirmed. ถอด EA ออกจาก EURUSD chart ใน MT5 GUI |

---

## Timeline

| วันที่ | Milestone |
|---|---|
| 2026-06-22 | **ทั้ง 8 EA deploy แล้ว** บน 10,000 cent account เดียว |
| 2026-06-22 | ST_EA03 lot fix — Lots_divided แก้ → 100,000 ✅ |
| 2026-06-28 | EA #6 v3 set ready — reload EA_BREAKOUT_XAU with BRK_XAU_live_v3.set (Bars=55, TP×8, EMA150) |
| 2026-09-22 | ครบ 3 เดือน → judge ทุก EA พร้อมกัน |
| หลัง judge | EA ที่ผ่าน (PF ≥ 1.40, ≥30 trades) → เพิ่ม port หรือเพิ่ม lot |

---

## ต่อไปหลัง 3 เดือน

1. รัน per-EA attribution script (parse history by magic) → ดูว่า EA ไหนกำไร/ขาดทุน
2. ถ้ากลุ่ม A ผ่าน → live บน cent $100/port (ปรับ ST_EA03 Lots_divided ก่อน)
3. ถ้ากลุ่ม B ผ่านเงื่อนไข → merge เข้า Core portfolio
4. ถ้า MG_v1 DD สูงเกิน → พิจารณา drop + หา replacement correlation ต่ำ

---

## EA_CORE_V1 — งานต่อ

**Phases A–J: เสร็จแล้ว** (framework validated, signals v2-v4, LotSizer, ScaleExecutor v1)

**Part B ScaleExecutor (planned):** implement pending/limit order pyramid แบบ ST_EA03
- Phase I (simultaneous market open) = PF 0.84 LOSING → dead end
- Root cause: ST_EA03 ใช้ Nearby_PIP PENDING order stagger → legs fill เมื่อราคาเคลื่อน
- Next: เปลี่ยน `ScaleExecutor_v1` ให้ส่ง ORDER_TYPE_BUY_LIMIT/SELL_LIMIT แทน market
- Target: reproduce ST_EA03-level PF >> 1.11 บน GBPUSD/USDCAD H1
- ⚠️ Model 4 required (TP < 20 pip trigger)
