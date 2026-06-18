# EA_Lab — Optimize Guide (Instrument Scale + Strategy Plans)
> เขียน 2026-06-18 · ใช้คู่ [DESIGN_V2.md](DESIGN_V2.md) · โค้ดอ้างอิงตาม numbering V2

เป้าหมาย: ตอน test/optimize ให้ค่า **อยู่ในสเกลที่เหมาะกับสินค้า** + มี **plan หยาบๆ**
ไว้ยิงเร็วๆ เพื่อดูว่า EA ตัวนี้เข้ากับกลยุทธ์แบบไหน/สินค้าไหน

---

## หลักการ: ยึด ATR เป็นหน่วยกลาง

❌ ตั้ง TP=500pt → ดีกับ EURUSD แต่เล็กไปสำหรับ XAUUSD, ใหญ่ไปสำหรับ WTI
✅ ตั้ง TP=2×ATR → ปรับสเกลตามสินค้าอัตโนมัติ ใช้เลขเดียวข้ามทุก class

**กฎ:** ทุก plan ใช้โหมด ATR เป็นหลัก (`22` TP_ATR, `33` SL_ATR, stack step=ATR)
pip-mode (`21`/`31`) ใช้เฉพาะตอน fine-tune สินค้าเดียว

---

## ตารางที่ 1 — Instrument Scale Reference

ค่า ATR(14) H1 = ค่าประมาณ (calibrate จริงจาก report ของ broker ตัวเอง — column "ATR points" ขึ้นกับ digits)

| Class | ตัวอย่าง | Digits | ~ATR(14) H1 | ~ATR points | Lot ($100 cent) | หมายเหตุ |
|---|---|---|---|---|---|---|
| **FX major** | EURUSD GBPUSD | 5 | ~0.0010 (10pip) | ~100 | 0.01–0.02 | สเกลฐาน |
| **FX JPY** | USDJPY CHFJPY | 3 | ~0.10 (10pip) | ~100 | 0.01–0.02 | คล้าย major |
| **FX cross CHF** | GBPCHF EURCHF | 5 | ~0.0012 | ~120 | 0.01 | spread กว้างกว่า |
| **Gold** | XAUUSD | 2 | ~$3–5 | ~300–500 | **0.01** | $1/pt/lot → lot เล็ก |
| **WTI Oil** | XTIUSD | 2–3 | ~$0.30–0.50 | ~30–50 | 0.01 | ATR points น้อย ระวัง SL แคบ |
| **Crypto BTC** | BTCUSD | 2 | ~$300–600 | ใหญ่มาก | **0.01 min** | $ ต่อ pt สูง → lot ต่ำสุดเสมอ |

### กฎ lot ต่อ class (cent $100)
- Gold/WTI/Crypto: **0.01 เท่านั้น** ($ ต่อจุดสูง — lot ใหญ่ = ระเบิด)
- FX: 0.01–0.02 ได้
- ใช้ `42` Risk% (0.5–1%) ถ้าอยากให้ auto-scale lot ตาม SL distance + ทุน

### แปลง ATR↔points (ถ้าต้องตั้ง pip-mode)
```
ATR_points = ATR_price / SYMBOL_POINT
เช่น Gold ATR $4, point=0.01 → 400 points → SL 1.5×ATR ≈ 600 points
```

---

## ตารางที่ 2 — Strategy Plans (coarse, อย่างละ 3 step)

แต่ละ plan = ชุดโหมด (โค้ด V2) + key params 3 ตัว × 3 ค่า = 27 combos ยิงเร็ว
ดูว่า PF>1.3 โผล่ที่ plan ไหน/สินค้าไหน = EA เหมาะกับแบบนั้น

### Plan A — SCALP (เก็บสั้น ถี่)
| โหมด | โค้ด |
|---|---|
| Exit | `22` TP_ATR เล็ก |
| SL | `33` SL_ATR แคบ |
| Stack | `90` Single |
| Filter | `70` None |

Coarse 3-step:
```
_22_TP_ATRmult  = 0.5 || 0.5 || 0.5 || 1.5   (0.5, 1.0, 1.5)
_33_SL_ATRmult  = 1.0 || 1.0 || 0.5 || 2.0   (1.0, 1.5, 2.0)
[entry param หลัก] = 3 ค่า
```
เหมาะ: FX major/JPY, M5–M15 · สัญญาณ: เทรดถี่ PF เตี้ยแต่ DD ต่ำ

### Plan B — SWING (ถือยาว ไม้ใหญ่)
| โหมด | โค้ด |
|---|---|
| Exit | `22` TP_ATR ใหญ่ |
| SL | `33` SL_ATR กว้าง |
| Stack | `90` Single |

Coarse 3-step:
```
_22_TP_ATRmult = 4 || 4 || 2 || 8    (4, 6, 8)
_33_SL_ATRmult = 2 || 2 || 1 || 4    (2, 3, 4)
[entry param]  = 3 ค่า
```
เหมาะ: Gold, FX trend · สัญญาณ: เทรดน้อย RF สูง ถือข้ามวัน

### Plan C — TREND (ตามเทรนด์ ปล่อยกำไรวิ่ง)
| โหมด | โค้ด |
|---|---|
| Entry | `11` GridTrendMA |
| Exit | `24` RunTrend หรือ `23` Trail |
| SL | `33` SL_ATR |
| Stack | `91` GridTrend (พีระมิด) |
| Filter | `71` ATR_Expand |

Coarse 3-step:
```
_11_SlowMA      = 50 || 50 || 30 || 100   (30, 50, 100)
_33_SL_ATRmult  = 2 || 2 || 2 || 3        (2, 3)
_9_MaxLevels    = 3 || 3 || 3 || 8        (3, 5, 8)
```
เหมาะ: Gold bull, FX trending · สัญญาณ: กำไรก้อนใหญ่ตอนเทรนด์ยาว

### Plan D — BREAKOUT (ทะลุกรอบ)
| โหมด | โค้ด |
|---|---|
| Entry | `12` Breakout |
| Exit | `22` TP_ATR กลาง |
| SL | `33` SL_ATR |
| Stack | `90` Single |

Coarse 3-step:
```
_12_Bars        = 20 || 20 || 20 || 60   (20, 40, 60)
_22_TP_ATRmult  = 3 || 3 || 3 || 5       (3, 4, 5)
_33_SL_ATRmult  = 1.5 || 1.5 || 1.5 || 2 (1.5, 2.0)
```
เหมาะ: Gold, WTI, session FX · ใส่ session filter (`_12_HourFrom/To`) ถ้า FX

### Plan E — GRID (ตาข่าย/ถัวเฉลี่ย) ⚠️ เสี่ยงสุด
| โหมด | โค้ด |
|---|---|
| Exit | basket money TP (`_2_BasketTP`) |
| SL | `30` None หรือ `32` Money |
| Stack | `91` GridTrend หรือ `92` DCA |
| Progression | `50` None / `52` Mult |

Coarse 3-step:
```
_9_GridStepATR  = 1 || 1 || 0.5 || 2     (0.5, 1, 2)
_9_MaxLevels    = 3 || 3 || 3 || 8       (3, 5, 8)
_52_ProgMult    = 1.0 || 1.0 || 1.0 || 1.3 (1.0, 1.15, 1.3)
```
เหมาะ: ranging market · ⚠️ DD จริง = report×2-3, MaxLevels สูง = ระเบิด
**กฎ:** grid ต้องผ่าน Monte Carlo ruin<5% ก่อนเสมอ (เราเคย reject grid หลายตัว)

---

## วิธีใช้ guide นี้ (workflow)

1. EA ใหม่ → ยิง **Plan A-E อย่างละ coarse** บนสินค้าที่เดาว่าเหมาะ (ดูตาราง 1)
2. ดูว่า plan ไหน PF>1.3 โผล่ → นั่นคือ "ธรรมชาติ" ของ EA
3. เอา plan ที่ชนะไป fine-tune (param ละเอียดขึ้น) + ทดสอบ IS/OOS
4. ผ่าน gate → robustness → portfolio

> ประหยัด: coarse ยิงด้วย Model=1 (OHLC) ก่อน เร็ว · ตัวรอด fine-tune ด้วย Model ที่เหมาะ
> (trailing แคบ <20pip ต้อง Model=4 ตาม policy)

---

## TODO — ต่อยอดเป็น automation (ทีหลัง)
- [ ] `gen_plan_set.py` — gen .set optimize จาก (plan × instrument_class) อัตโนมัติ
      อ่านตาราง ATR → คูณ mult → เขียน .set พร้อม range
- [ ] เก็บ ATR จริงต่อ symbol จาก smoke report → calibrate ตาราง 1
- [ ] preset .set 5 ไฟล์ (PLAN_A..E base) ไว้ใน `sets/plans/`
