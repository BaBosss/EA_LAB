# RSI from pips_EA — Reverse-Engineering (behavioral, 2026-07-07)

> วิธี: locked-ea-analyzer skill — **ไม่ decompile** (ผิดกฎหมาย + binary เชื่อไม่ได้) · อ่านจาก
> input dump + trade list + fxDreema signature + vendor pattern เท่านั้น · ทุกอย่างเป็นข้อมูลที่
> owner เข้าถึงได้ผ่าน GUI อยู่แล้ว

## ที่มา: สร้างด้วย fxDreema (no-code EA builder)
binary ฝัง string เดียวที่อ่านออก = `https://fxdreema.com` (นอกนั้น noise = compiled ปกติ ไม่ได้
เข้ารหัสพิเศษ) → EA นี้ต่อจาก block สำเร็จรูปของ fxDreema ตาม template **"Grid RSI Strategy —
Calculate Lot Size Every 900 PIP"** (ยืนยันจาก YouTube/forum ของ fxDreema เอง) → **ไม่ใช่ secret
sauce, ทำซ้ำได้ 100%, block map ตรงกับ input ที่เรากู้มา**

## Ground-truth inputs (จาก report parameter dump — ไม่ได้เดา)
`Period_=5 · Lot=0.01 · Lots_plus=0.01 · Lots_plus_at_pips=90 · TP_pips=15 · Distance_pips=30 ·
RSI_period=14 · RSI_over_s=30 · RSI_over_b=70 · MagicStart=5888` (EA_EANAME="RSI V.1")

## กลไก (อ่านจาก trade list 3 ปี BWD Model-0, 1,617 แถว)
1. **สัญญาณ = RSI(14) mean-reversion, สองทาง** — buy เมื่อ oversold (<30), sell เมื่อ overbought
   (>70) · trade balance 237 buy / 246 sell = ไม่เอนข้างเดียว · (fxDreema pattern: รอ RSI กลับมา ~50
   ก่อนเข้าไม้ใหม่ = กันเข้าถี่ตอน RSI ค้าง extreme)
2. **ไม้ฐาน 0.01 lot · virtual TP ~15 pips** (TP_pips) — ปิดเดี่ยว +$1.50/ไม้ · **SL/TP column =
   0.00000 ทุกไม้** → จัดการภายใน ไม่มี order จริงบน server (จุดอ่อน tail = disconnect = ไม้เปลือย
   เหมือน ClevrFX/UnNomGuai)
3. **Recovery grid = เพิ่มไม้เมื่อราคาสวน ~30 pips (Distance_pips)** · lot โต **เชิงเส้น +0.01/ชั้น
   (0.01→0.02→...→0.08)** — **ไม่ใช่ ×1.5-2 martingale** · `Lots_plus_at_pips=90` = จุดที่เพิ่ม lot
   step อีกทีเมื่อสวนลึกถึง 90 pips · **max exposure 3 ปี = ×6-8 ฐาน** (เทียบ EA ที่เรา reject = ×100-600)
4. **Basket exit** — ไม้ที่ ladder กันไว้ปิดพร้อมกัน (เห็น close 3-5 ไม้ timestamp เดียว) เมื่อ
   averaged basket กลับมาเป็นบวกสุทธิ

## ทำไมตัวนี้รอดทุกด่าน (ในขณะที่ grid อื่น ~1,300 ตัวตาย)
**edge จริงอยู่ที่ RSI mean-reversion entry — grid เป็นแค่ตัวช่วย recovery ที่ "อ่อน" (linear +0.01
ไม่ใช่ geometric martingale)** จึงไม่ระเบิด: DD คงที่ ~19-25% ทุกด่าน (BWD/spread/Model-0/forward) ·
ต่างจาก FZ2/2020v2/CommunityPower ที่ profit engine = martingale recovery ล้วน (พอปิด multiplier =
PF ตก <1 ทันที ตามที่ ORDER-046 พิสูจน์) · **นี่คือความต่างเชิงโครงสร้างระหว่าง "grid ที่มี edge จริง
รองรับ" กับ "grid ที่หากินจาก recovery mechanics ล้วน"**

## 🎯 ต่อยอด: original EA ใน Boss V2 (ไม่ clone — สร้างใหม่จากหลักการ ตาม legal boundary ของ skill)
Boss V2 มีชิ้นส่วนครบแล้วที่จะทำ RSI-mean-reversion variant ที่**ดีกว่าต้นฉบับ** (ปิดจุดอ่อน no-SL):
- **signal block ใหม่:** RSI(14) 30/70 + RSI-return-to-50 re-arm (แทน momentum/breakout ของ mold เดิม)
- ใช้ของเดิมที่ validate แล้ว: **GridLog** (grid spacing ATR-relative + **LOG lot** = อ่อนกว่า linear
  อีก) · **real hard SL** (ปิด tail no-SL) · **partial-close** · **RC_AcctDDLimitPct** DD gate ·
  **STACK_PYRAMID** one-exit-owner
- **risk-combination:** RSI signal + grid averaging + basket exit + **มี SL จริง + cap จริง** = L2-L3
  (ไม่มี martingale, ไม่มี hedge) = ผ่านเกณฑ์ strategy-and-risk L1-L5 (ต่างจากต้นฉบับที่ no-SL = เสี่ยงกว่า)
- **คุณค่า:** ได้ signal ตระกูลใหม่ (mean-reversion) เข้าคลัง Boss V2 ที่ตอนนี้มีแต่ grid/momentum ·
  RSI-MR corr ต่ำกับ trend-follower = additive ต่อพอร์ต (ธีม portfolio-edge-thesis: momentum×reversion)

## ขั้นถัดไป (รอ user เคาะ)
1. **ต้นฉบับ (compiled):** เดินหน้า ORDER-047 phase 2/3 (BWD multi-symbol → optimize) เพื่อใช้เป็น
   demo-experiment ตามเดิม — RE นี้ยืนยันว่ากลไกมีเหตุผล ไม่ใช่ artifact
2. **สร้างใหม่ (original):** เปิด strategy-and-risk → Spec Card "RSI-MR GridLog" → mql-code-generator →
   validate จากศูนย์ผ่าน pipeline ปกติ → ถ้าผ่าน = **โค้ดเราเอง (source ครบ optimize ได้เต็ม, deploy live
   ได้ ไม่ติดกล่องดำ)** — นี่คือ "ต่อยอดได้เยอะ" ตัวจริง

## Sources
- [fxDreema — Grid RSI Strategy (Calc Lot Size Every 900 PIP)](https://www.youtube.com/watch?v=Rzzrd-aaTn4)
- [fxDreema RSI EA tutorial (TH)](https://www.youtube.com/watch?v=U1vegLpxCTE)
- [fxDreema.com](https://fxdreema.com) (binary signature)
