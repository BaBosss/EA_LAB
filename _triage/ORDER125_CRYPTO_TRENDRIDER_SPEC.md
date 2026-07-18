# ORDER-125 (DRAFT) — BTC TrendRider: SuperTrend + Pyramid + Snowball บน BTCUSD

**Date:** 2026-07-18 · **Author:** Claude (Fable seat) · **Status:** ✅ SMOKE PASSED (Model-1 both-window, 2026-07-18) — พร้อมเข้าเฟส optimize

## ผล SMOKE (Model 1 · flat default lot · ThinkMarkets BTCUSD · History Quality 100%/85%)

| EA | TF | 2023-2026 | BWD 2020-2022 | verdict ขั้นนี้ |
|---|---|---|---|---|
| EA_SUPERTREND | H4 | **PF 1.27** (79t, DD 3.1%) | **PF 2.35** (69t, DD 1.4%) | ✅ both-window pulse ที่ default — ตัวหลัก |
| EA_DONCHIAN (Turtle) | H4 | **PF 1.20** (76t, DD 6.4%) | **PF 2.07** (50t) | ✅ both-window pulse — ตัวรอง |
| EA_SUPERTREND | D1 | 2.04 (13t) | — | thin, เก็บเป็น lever TF |
| EA_DONCHIAN | D1 | 3.78 (12t) | 5.40 (9t) | thin สวยผิดปกติ — inconclusive อย่าเชื่อจน n พอ |
| EA_SUPERTREND | H1 | ~1.0 (M2 kill-direction) | — | ไม่ไปต่อ |
| EA_BREAKOUT_XAU | H4 | 0 trades | — | param scale ติด XAU — ต้อง rescale ก่อนตัดสิน ไม่ใช่ตาย |

หมายเหตุ: ทั้งสอง window มีเทรนด์ใหญ่ (2021 bull / 2022 bear / 2024 bull) — **missing regime = chop ยาวๆ**
ต้องดู per-year split ตอน optimize · DD จิ๋วเพราะ default lot จิ๋ว = under-leveraged screen (PF lot-invariant, ตามกติกา)

## ผล MULTI-SYMBOL SCAN (2026-07-18 รอบสอง — Model 1, default, flat lot)

| Symbol | ST H4 recent | ST H4 BWD | DON H4 recent | DON H4 BWD | สถานะ |
|---|---|---|---|---|---|
| BTCUSD | 1.27 (79t) | 2.35 (69t) | 1.20 (76t) | 2.07 (50t) | ✅ ทั้งคู่ both-window |
| ETHUSD | 1.41 (85t) | 1.05 (68t) | **2.16** (67t) | **1.84** (54t) | ✅ **DON เด่นสุดในสแกน** · ST = recent-fit |
| SOLUSD | 1.34 (78t) | 2.14 (25t)⚠ | 0.93 (91t) | — | ST pulse · ⚠ history เริ่มช้า (~ปลาย 2021) BWD จริงๆ = ปีหมี 2022 |
| XRPUSD / DOGEUSD | 0 trades | | | | data มีครบ (เริ่ม ธ.ค. 2021) แต่ราคา <$3 = param scale ไม่ยิง → แก้ด้วย ATR-scaled set เฟส optimize |
| LTCUSD / ADAUSD / BCHUSD | — | | | | ❌ history download error ซ้ำ 2 รอบ (server feed) — ลองเปิดกราฟใน GUI ให้ terminal ดึงเอง หรือข้าม |

**pattern ที่เห็น: mechanism×symbol matching จริง** — SuperTrend=บ้าน BTC · Donchian=บ้าน ETH · SOL เข้ากับ ST ไม่เข้ากับ DON.
⚠ portfolio note: crypto majors corr กันเองสูง (BTC-ETH มัก >0.8) — ตอน portfolio phase ใช้ gate pairwise <0.8 ของ same-EA-cross-symbol แล้วอาจต้องเลือก/ลด lot ไม่ใช่เอาหมด.

## ✅ ผล OPTIMIZE รอบ 1 + VALIDATE (2026-07-18 รอบสาม — Model 1)

**Windows:** sweep = 2023.01–2026.01 · BWD = 2020–2022 · **holdout 2026.01–2026.07 = สงวนไว้ ไม่เคยใช้เลือกอะไร**

**ST-BTC** (sweep 45 combos complete-mode, ทุก combo กำไร = plateau แท้) → lock **`ST_BTC_c1.set`** (ATR 14 · Mult 2.5 · SL 2.25×ATR, plateau-center ไม่ใช่ peak):
sweep PF 1.91 (76t) · BWD **1.55** (84t) · holdout **2.16** (15t) · MC(BWD) PF_5th 1.04 Ruin 0%

**DON-ETH** (15 combos, ทุก combo กำไร) → lock **`DON_ETH_c1.set`** (Donch 35 · SL 2.25×ATR):
sweep PF 2.06 (68t) · BWD **1.91** (58t) · holdout **1.94** (13t)

**PYRAMID A/B (DON-ETH, `_04_MaxPyramid` 0→3, `DON_ETH_c1_pyr3.set`):**
| | naked | pyramid 3 |
|---|---|---|
| IS net/DD | 461 / 1.9% | **1,109 / 5.8%** (PF 1.90, 161t) |
| BWD net/DD | 374 / 2.1% | **1,100 / 5.2%** (PF 2.13, 135t) |
| MC pyramid | — | PF_5th **1.37** · DD_95th 2.5% · Ruin 0% |

→ **pyramid บน crypto = ขยาย edge จริง** (net ×2.4–2.9, PF ยืน, ต่างจาก XAU/GBP ที่ PF พังเหลือ ~1.0) — thesis "BTC/ETH คือบ้าน trend+pyramid" ยืนยันแล้วชั้นแรก

## NEXT — ORDER-125b: STO/PA pullback add-entry (user idea 2026-07-18, design พร้อม รอ build)

**Concept:** ตอนนี้ pyramid เพิ่มไม้แบบ breakout-STOP (ไล่ราคา) — user เสนอเพิ่มไม้แบบ **pullback-in-trend**:
เทรนด์ยืนอยู่ (SuperTrend/Donchian direction) + **Stochastic ลง oversold แล้ว cross กลับตามเทรนด์** (หรือ PA: pin bar/engulfing ที่ pullback) = add ไม้ตามเทรนด์ราคาถูกกว่า
- **Vehicle:** เพิ่ม input `_04_AddMode` ใน EA_DONCHIAN (0=STOP-pyramid เดิม · 1=STO-pullback · 2=PA-pullback) — A/B ตรงๆ กับ pyramid เดิมบน set เดียวกัน
- **Prior เตือน:** StoK default noise (บทเรียน SMC×STO: K 5→17 พลิกผล) → sweep StoK {9,14,21} ก่อนตัดสิน · candle = confirm filter ไม่ใช่ naked (doctrine PA-module)
- **บาร์:** add-mode ใหม่ต้องชนะ pyramid เดิมทั้ง net-per-DD และ PF ทั้งสอง window ถึงจะแทน — ไม่งั้นเก็บ STOP-pyramid
- ⚠️ ก่อน build: รัน `mql-code-reviewer` + tpl regression ตามปกติ · commit code เอง (Claude เขียน, Codex audit)

## ค้างในคิว validate ก่อน demo
1. per-year split (กัน PF รวมซ่อนปีขาดทุน) — ยังไม่ได้ทำ
2. **Model-4 real-tick confirm** ทั้ง 2 set (เช็ค tick depth ThinkMarkets BTC/ETH — ถ้าตื้นต้องแจ้งตรงๆ)
3. snowball A/B (FIRSTLOT_RISK) ตัดสินด้วย MC ruin
4. corr BTC-leg vs ETH-leg (คาดสูง — อาจต้องลด lot ฝั่งนึง) + corr vs live portfolio
5. demo bundle
**Origin:** user ขอ EA crypto run-trend + snowball + pyramid (มองว่า bull run ใกล้มา)

## หลักคิด (สำคัญ — อ่านก่อน dispatch)

- **EA นี้ห้าม design โดย "เชื่อว่า bull run มาแน่"** — trend-following ที่ดี = เข้าเมื่อเทรนด์ยืนยันแล้ว,
  ถ้าเทรนด์ไม่มา = แพ้เล็กจำกัด (SL ทุกไม้), ถ้ามา = pyramid+snowball ขยายกำไร. คำทำนายตลาดไม่ใช่ input ของ spec.
- **Route = MT5 broker CFD (ThinkMarkets/Exness BTCUSD) — ไม่ใช่ exchange API lane.**
  ORDER-081 (`CRYPTO_LANE_FEASIBILITY.md`) ประเมิน lane ตรง exchange = 92-168 ชม. engineering ก่อนตัดสินใจเงิน → PARK ไว้เหมือนเดิม.
  MT5 CFD route ใช้ pipeline เดิมได้ 100% (Model-2/4, both-window, MC, demo bundle).
- **ชิ้นส่วนทั้ง 3 มีอยู่แล้ว ไม่ต้อง build ใหม่:**
  1. **Entry:** `EA_SUPERTREND` / `EA_SUPERTREND_MTF` (D:\EA_Project\CURRENT_BUILD\TEMPLATE\) —
     FULLY VALIDATED บน XAU H4 (IS 1.54 / OOS 4.49 / MC pass; Mode2 pyramid PF 1.72, MC PF_5th 1.35, Ruin 0%).
     โดนบล็อกจาก portfolio เพราะ **corr 0.724 กับ XAU breakout เท่านั้น** — ไม่ใช่คุณภาพ. BTC = home ใหม่ที่แก้ block นี้พอดี.
  2. **Pyramid:** chassis Boss V2 `STACK_PYRAMID(93)` pending-STOP ladder (MERGE-03, regression CLEAN).
  3. **Snowball:** chassis `FIRSTLOT_RISK(42)` = lot จาก Risk%/SL-distance → โตตาม equity อัตโนมัติ = compounding.

## ⚠️ Prior ที่ต้องเคารพ (จากคลังเรา)

| หลักฐาน | ผล | บทเรียนที่บังคับใช้ |
|---|---|---|
| #20 Trend+Pyramid XAU/GBP H4 (2026-07-02) | DEAD — naked 0.87-1.02, pyramid 0.99-1.00 | **pyramid ขยาย edge ที่มีอยู่ ไม่สร้าง edge** → ต้องผ่าน flat-lot naked ก่อนเปิด pyramid |
| #94 Turtle+pyramid | DEAD (0 additive legs) | เหมือนกัน |
| EA_SUPERTREND multi-symbol smoke | ตายเกือบทุก FX (GBPJPY 0.55, EUR 0.67) ผ่านเฉพาะ XAU/XAG/US30 | SuperTrend เป็น **trender-home-specific** — BTC เป็น trender แรงสุดในบรรดา instrument = ตรง home ที่สุด แต่ต้องพิสูจน์ ไม่ใช่สมมติ |
| BTCUSD CFD swap | ยังไม่มีข้อมูลในเครื่อง | trend-ride ถือไม้เป็นสัปดาห์ → **swap คือ killer อันดับ 1** ต้องเทส Model-4 spec จริง + จด swap rate ตอนโหลด data |

## Spec Card (chassis-abbreviated ตาม CHASSIS-FIRST rule)

```yaml
spec_card_version: "3.0"
chain_id: "EA_BTCTREND_20260718_001"
chassis: "standalone-first-then-BossV2"   # phase 1-2 ใช้ EA_SUPERTREND_MTF ที่มีอยู่ (เร็วสุด, validate แล้ว)
                                          # ถ้าเป็น candidate จริง → port entry เข้า Boss V2 (ได้ cage/Persist ฟรี)
identity:
  ea_name: "BTC_TRENDRIDER (SuperTrend DNA)"
  symbol: "BTCUSD (ETHUSD = expansion เฟสหลัง)"
  timeframe: "H4 หลัก · D1/H1 = lever sweep"
strategy:
  entry: "SuperTrend flip ตามเทรนด์ (ATR period × multiplier = lever แรกที่ sweep — บทเรียน StoK: default อาจ noise)"
  pyramid: "STACK_PYRAMID(93) STOP-ladder ≤4 legs, spacing = ATR-based (ห้าม fixed pips — BTC vol ใหญ่)"
  lot_sizing: "Phase A = FLAT LOT (บังคับ) → Phase C = FIRSTLOT_RISK 0.5-1.0%/trade (snowball)"
  stop_loss: "ATR-based ทุกไม้ รวมไม้ pyramid · exit ownership = SuperTrend flip + trailing (basket-close > per-leg-TP ตาม lever ที่เก็บจาก Boss_18)"
risk:
  risk_level: "L2 (multi-position ทิศเดียว + SL ทุกไม้ = anti-martingale ไม่ใช่ recovery)"
  risk_per_trade_pct: 1.0
  max_positions: 4          # Turtle-style cap
  max_total_lot: "จาก margin calc ตอนรู้ contract spec จริง"
  emergency_exit_dd_pct: 70.0
  daily_loss_limit_pct: 5.0
  หมายเหตุ: "weekend: broker crypto ส่วนใหญ่เทรด 24/7 แต่ต้อง verify — ถ้า broker ปิดเสาร์อาทิตย์ = gap ข้าม SL ได้ ต้องลด cap"
```

## Test ladder (ตาม VERDICT GATE — ห้ามข้ามขั้น)

1. **DATA (ทำก่อน ไม่มีทางไปต่อถ้าไม่ผ่าน):** เปิด MT5 ThinkMarkets → ดู Market Watch ว่ามี BTCUSD ไหม → โหลด history H1/H4/D1
   → verify ความลึก (ต้องได้ ≥2023-01 ตาม 3-year rule; ได้ 2021-22 bear ด้วย = ดีมาก ใช้เป็น BWD window)
   → จด spec: contract size · spread ปกติ · **swap long/short** · margin % · เทรดเสาร์อาทิตย์ไหม.
   ถ้า ThinkMarkets ไม่มี → Exness demo (146237) มี BTCUSD.
2. **SMOKE (Model-2, flat-lot, naked ไม่มี pyramid):** EA_SUPERTREND บน BTCUSD H4/D1/H1 × both-window.
   จากนั้น optimize entry params (ATR period/mult) ก่อนตัดสิน — default-smoke ตาย ≠ concept ตาย (กติกา anti-rationalization).
   บาร์: PF≥1.2 หลัง optimize (momentum prior) + surface ไม่ใช่ spike.
3. **A/B PYRAMID:** config ผ่านขั้น 2 → เปิด Mode2/STACK_PYRAMID เทียบ naked. pyramid ต้องชนะทั้ง PF และไม่พอง DD เกิน.
   ถ้า pyramid ไม่ช่วย (ซ้ำรอย #20) → เก็บ naked ไว้ ไม่ฝืน.
4. **SNOWBALL:** เปิด FIRSTLOT_RISK เทียบ flat — ตัดสินด้วย **MC ruin + DD_95th** ไม่ใช่ net profit
   (compounding ทำ net สวยเสมอ แต่เพิ่ม ruin — ต้องดูหาง distribution).
5. **VALIDATE เต็ม:** Model-4 spec จริง (รวม swap!) · ≥3 levers swept · plateau-center · holdout ที่ไม่เคย select · MC.
6. **PORTFOLIO:** corr vs ทุก live leg (บาร์ ≤0.4 additive — คาดว่าผ่านเพราะไม่มี crypto exposure เลย) → demo bundle 3 เดือนตามระบบ.

**Effort ขั้น 1-2 ≈ ครึ่งวัน (batch ผ่าน qwen lane ตาม pacing rule 1-2 order/รอบ) — ตายก็ตายถูก.**

## ห้าม (สำหรับ agent ที่รับ order)

- ห้ามเปิด pyramid/snowball ก่อน naked flat-lot ผ่าน both-window (ลำดับ 2→3→4 ตายตัว)
- ห้ามใช้ fixed-pip spacing/SL บน BTC — ATR เท่านั้น
- ห้าม verdict จาก window เดียว / ห้ามข้าม swap ใน Model-4
- ห้ามแตะบัญชีจริง — จบที่ demo bundle เหมือนทุกตัว

NEXT STEP:
Forward this Spec Card to the mql-code-generator skill.
(เฉพาะเมื่อถึงเฟส port เข้า Boss V2 — phase 1-2 ใช้ EA_SUPERTREND_MTF ที่คอมไพล์แล้ว ไม่ต้อง gen code)
