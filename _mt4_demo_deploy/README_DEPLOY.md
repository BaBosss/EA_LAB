# MT4 Demo Experiment — Treasure-Hunt Survivors

> **ที่มา:** คัดจาก EA ~1,300 ตัว (ORDER-036/046/047) ผ่าน funnel 5 ด่าน:
> smoke → lot-check → BWD-OOS 2020-22 → spread-stress 30pts → Model-0 every-tick
> · เหลือ **3 ตัว** · หลักฐานเต็ม: `ORDER-036_MT4_MASS_SMOKE.md`, `EA_SCORECARD_AND_REGISTRY.md`

---

## บัญชี demo (ตั้งครั้งเดียว)
- บัญชีใหม่ **$10,000** · แนะ **ThinkMarkets demo** (broker ที่ใช้ validate) · type Hedge
- ลง MT4 ใหม่ **portable ที่ `D:\Meta4demo`** — ❌ ห้ามใช้ `D:\Meta4` / `D:\Meta4b` (เลนเทส script ฆ่า terminal พวกนั้นทิ้งเป็นประจำ)
- ก็อป `.ex4` ทั้ง 3 → `MQL4\Experts\` · เช็ค MD5 ตามตารางล่างถ้าไม่แน่ใจว่าไฟล์ถูกตัว
- **1 บัญชี รันได้ทั้ง 3 ตัว** (คนละ chart คนละ magic — ไม่ชนกัน)

---

## EA ทั้ง 3 ตัว

| # | EA | Chart | Set ที่ต้องโหลด | Magic | กลไกย่อ |
|---|---|---|---|---|---|
| 1 | **UnNomGuaiV1.132** | EURUSD H1 | `UnNomGuai_cap20.set` | 1 / 2 | grid ตะกร้าตื้น, ปิดยกชุด +$8 |
| 2 | **RSI from pips_EA** | EURUSD H1 | *(defaults — ไม่ต้องโหลด set)* | 5888 | RSI(14) mean-reversion + grid บวกทีละ 0.01 |
| 3 | **swb grid 4.1.0.3_h** | **AUDCAD** H1 | `swb_AUDCAD_demo.set` | 990 | BB+Stoch+RSI grid, flat lot |

**ค่าที่ผ่านการพิสูจน์ (Model-0 every-tick 2020-22 — ใช้เทียบตอน judge):**

| EA | PF | DD สูงสุด | ไม้/เดือน โดยประมาณ | net/เดือน โดยประมาณ ($10k) |
|---|---|---|---|---|
| UnNomGuaiV1.132 | 1.63 | 19% | ~90 | ~$150 |
| RSI from pips_EA | 2.07 | 25% | ~45 | ~$80 |
| swb @ AUDCAD | 1.80 | 20% | ~35 | ~$140 |

---

## ขั้นตอน attach (ต่อ EA)
1. เปิด chart ตามตาราง (symbol + H1)
2. ลาก EA ลง chart → Common tab: ✅ Allow live trading · **โหลด set ตามตาราง** (RSI ใช้ defaults ไม่ต้องโหลด)
3. ปุ่ม **AutoTrading** (toolbar) ต้องเขียว · **Save Profile** กัน MT4 restart แล้ว chart หาย
4. เช็ค Journal 5 นาทีแรก: ไม่มี error วนซ้ำ = ใช้ได้ (EA พวกนี้อาจเงียบเป็นวัน = ปกติ)
5. **จดวันที่ attach → แจ้ง Claude** = นาฬิกา demo เริ่มเดิน (judge +3 เดือน)

---

## ⚠️ กติกาเหล็ก (ทั้ง 3 ตัว)
- **ห้ามแก้ input** นอกจาก set ที่ให้ — ทุกตัว validate ด้วยค่านี้ แก้ = ผลเป็นโมฆะ
- ทั้ง 3 ตัว **ไม่มี hard SL** (จัดการภายใน) → เครื่อง/VPS **ต้องออนไลน์ตลอด** (หลุด = ไม้เปลือยบน server)
- **ห้ามเพิ่ม EA อื่นในบัญชีนี้** — magic ต่ำ (1/2) ชนง่าย
- เช็คทุกเช้าจันทร์: terminal ยังรัน + AutoTrading ยังเขียว (MT4 update ชอบ reset)

---

## 🔴 Kill-switch (เช็คทุกสัปดาห์)
**หยุดตัวนั้นทันที ไม่ต้องรอ ถ้า:**
- UnNomGuai เปิด **> 12 ไม้พร้อมกัน** (ประวัติไม่เคยเกิน 9)
- RSI ladder ทะลุ **0.08 lot/ไม้** (ไม่เคยเกิน 0.06)
- swb ladder ทะลุ **1.0 lot/ไม้** บน AUDCAD (validate ที่ ×3-4 จาก base 0.2)

**เตือน (จับตาถี่ขึ้น):** equity DD ของตัวนั้นแตะ 25%
**Kill:** DD แตะ 35% · หรือ net ตัวนั้นติดลบต่อเนื่อง 8 สัปดาห์

---

## 📊 Monitoring & Judge
- ทุก ~2 สัปดาห์: export MT4 account statement → ส่ง Claude → แยก P&L ตาม magic (1/2 · 5888 · 990) เทียบตารางค่าคาดหวัง
- **Judge: ≥3 เดือนหลัง attach + ≥30 trades/ตัว** → PF live ≥1.4 + DD ไม่แตะเตือน + พฤติกรรม lot/ไม้ตรง backtest → ค่อยคุยขั้นบัญชีจริง (lot เล็ก, track เดียวกับ ClevrFX)
- รันคู่ ClevrFX (demo experiment #1, attached 2026-07-06) — statement รอบเดียวกัน

---

## Binary lock (MD5 — กันหยิบไฟล์ผิดชื่อซ้ำ)
```
C6B6BCD443EFFC9D1098F5E8D0B5208D  UnNomGuaiV1.132.ex4
C6F31A2A3DF8F4A9D8D375D86801B9A6  RSI from pips_EA.ex4
35BFB25E93966DE1A9521A4A59313379  swb grid 4.1.0.3_h.ex4
```

## หมายเหตุกลไก (อ้างอิงเวลา judge)
- **UnNomGuai** — grid ตะกร้า ladder 0.01→0.07, ปิดยกชุดที่กำไร $8, cap 99→20 ชั้น (probe แล้วผลเท่าเดิม)
- **RSI from pips** — RSI(14) mean-reversion 30/70 สองทาง, grid บวก lot เชิงเส้น +0.01/ชั้น (ไม่ใช่ martingale), virtual TP ~15 pips · แกะกลไกเต็ม: `RSI_FROM_PIPS_REVERSE_ENGINEERING.md`
- **swb @ AUDCAD** — BB+Stoch+RSI confluence grid, flat lot (ปิด multiplier), symbol-specific (ดีเฉพาะ AUD)
