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

## NEXT (เฟส optimize — ยังไม่ทำ รอคิว/pacing)
1. per-year split ของ 4 รันหลัก (กัน aggregate PF ซ่อนปีขาดทุน)
2. optimize ≥3 lever: ATR period/mult (entry) · exit (flip vs trail vs structure) · SL width — coarse Model 1, plateau ไม่ใช่ peak
3. เช็คว่า ThinkMarkets มี real-tick BTC ลึกพอสำหรับ Model-4 ไหม (ถ้าไม่มี = ต้องบอกตรงๆ ใน verdict)
4. pyramid A/B (Mode2/STACK_PYRAMID) → snowball MC → holdout → corr → demo bundle ตาม ladder ข้างล่าง
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
