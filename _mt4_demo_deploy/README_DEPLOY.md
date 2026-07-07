# MT4 DEMO EXPERIMENT — deploy bundle (2026-07-07)

สองตัวนี้คือ survivor เต็มตัวจาก ORDER-036 (1,318 ex4 → 2) — ผ่านครบ: smoke → lot-check(Size-col)
→ BWD-OOS 2020-22 → spread-stress 30pts → Model-0 every-tick backward+forward. หลักฐานเต็ม:
`ORDER-036_MT4_MASS_SMOKE.md` + `EA_SCORECARD_AND_REGISTRY.md` §MT4 MASS-SMOKE ORDER-036 survivors

## Binary lock (MD5 — ห้ามใช้ไฟล์อื่นที่ชื่อเหมือนกัน)
```
C6B6BCD443EFFC9D1098F5E8D0B5208D  UnNomGuaiV1.132.ex4
C6F31A2A3DF8F4A9D8D375D86801B9A6  RSI from pips_EA.ex4
```

## กติกาเหล็ก
1. **ใช้ compiled DEFAULTS — ห้ามแก้ input ใดๆ ยกเว้นข้อเดียวที่พิสูจน์แล้ว:**
   **UnNomGuai ให้ตั้ง `space3Orders=20`** (โหลด `UnNomGuai_cap20.set` หรือกรอกมือช่องเดียว) —
   probe 2026-07-07 พิสูจน์แล้วว่าให้ผลย้อนหลัง 3 ปี**เหมือน default ทุกเซ็นต์** (1.89/3,640/+8,527.06
   เพราะประวัติไม่เคยเกิน 9 ไม้) = validation ยกมาใช้ได้ทั้งชุด แต่ปิด tail-risk 99 ชั้นให้ฟรี ·
   RSI from pips = defaults ล้วน ห้ามแตะ
2. **บัญชี demo ใหม่ล้วนๆ** — balance 10,000 USD (match backtest deposit) · แนะ ThinkMarkets demo
   (history ที่ใช้เทสมาจาก broker ตระกูลนี้) · EURUSD ต้องไม่มี suffix (ถ้ามี suffix เช่น EURUSDm
   ให้เปิด chart ตัว suffix แล้วจดไว้ — spread โปรไฟล์ต่างกันได้)
3. **ห้ามลง MT4 demo ทับเลนเทส** (`D:\Meta4`, `D:\Meta4b` — script ฆ่า terminal สองตัวนี้เป็นประจำ)
   → ติดตั้งใหม่แบบ portable ที่ `D:\Meta4demo`
4. **ห้ามเพิ่ม EA อื่นในบัญชีนี้** — magic ที่ใช้: UnNomGuai = 1(buy)/2(sell) · RSI = 5888 (ไม่ชนกัน
   แต่ magic 1/2 ต่ำมาก ชนง่ายถ้ามีตัวที่สาม)

## ขั้นตอน attach
1. เปิด chart **EURUSD H1** สองหน้าต่าง (ตัวละ chart)
2. ลาก EA ลง chart → tab Common: ✅ Allow live trading (ไม่ต้องเปิด DLL ยกเว้น journal ฟ้อง —
   ถ้าฟ้อง DLL = หยุดแล้วรายงานก่อน อย่าเปิดให้เอง)
3. ปุ่ม AutoTrading (toolbar) ต้องเขียว · เซฟ profile กัน MT4 restart แล้ว chart หาย
4. เช็ค journal 5 นาทีแรก: ไม่มี error วนซ้ำ = ใช้ได้ (EA พวกนี้เทรดตาม signal อาจเงียบเป็นวัน — ปกติ)
5. เครื่อง/VPS เปิดตลอด · เช็คทุกเช้าจันทร์ว่า terminal ยังรัน + AutoTrading ยังเขียว (MT4 update
   ชอบ reset)

## ค่าคาดหวัง (จาก Model-0 — ใช้เทียบตอน judge)
| | UnNomGuaiV1.132 | RSI from pips_EA |
|---|---|---|
| net/เดือนโดยประมาณ (lot default, 10k) | ~$150-180 | ~$70-90 |
| เทรด/เดือน | ~80-100 | ~40-50 |
| DD สูงสุดที่เคยเห็น (M0) | 19.3% | 25.0% |
| ไม้เปิดพร้อมกันสูงสุดที่เคยเห็น | 9 | ~6 (ladder 0.01→0.06) |

## Kill-switch (เช็คทุกสัปดาห์ · judge จริง 2026-10-07)
- **หยุดทันทีไม่ต้องรอ:** UnNomGuai เปิดเกิน **12 ไม้พร้อมกัน** (ประวัติไม่เคยเกิน 9; config เปิดได้ถึง 99
  = tail-risk ที่เรารู้อยู่แล้ว) · RSI ladder ทะลุ **0.08 lot/ไม้** (ไม่เคยเกิน 0.06)
- **Alert (จับตาถี่ขึ้น):** equity DD แตะ 20% (UnNom) / 25% (RSI)
- **Kill:** DD แตะ 30% / 35% หรือ net ติดลบต่อเนื่อง 8 สัปดาห์
- ทั้งคู่ **SL=0 ทุกไม้** (internal close logic) → ถ้า VPS/เน็ตหลุดขณะมีไม้เปิด = ไม้เปลือย ต้องรีบต่อ
  กลับและเช็คทันที (จุดอ่อนเดียวกับ ClevrFX ที่จดไว้แล้ว)

## Monitoring
ใช้ skill `ea-live-monitor` แยก P&L ตาม magic (1/2 = UnNom, 5888 = RSI) เทียบตารางคาดหวังข้างบน ·
นัด judge: **2026-10-07** (3 เดือน) — เกณฑ์ผ่าน: net บวก + DD ไม่แตะ alert + พฤติกรรม lot/ไม้
ตรงกับ backtest → ค่อยคุยเรื่องบัญชีจริง lot เล็กแบบ ClevrFX track
