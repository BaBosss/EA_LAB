# FXDREEMA_IDEA_CATALOG — แคตตาล็อกไอเดียจากคลังคอร์สของ user (ORDER-079)

> เอกสารนี้ = "เรียนมาได้ไอเดียอะไรบ้าง + แต่ละไอเดียต่อยอดจากจุดไหน" — **ไม่ตัดสิน risk structure**
> (เรื่องนั้นอยู่ FXDREEMA_XRAY.md ซึ่งตอบแค่ "ตัวไหน attach ได้เลย") · แหล่งจำแนก: fxDreema block labels
> (ข้อความที่ผู้สอน/ผู้เรียนเขียนเอง) + ชื่อไฟล์ + string + indicator set · 1,050 unique EAs ·
> ตัวเลือกละเอียดต่อไฟล์: `FXDREEMA_XRAY.csv` คอลัมน์ `concept` · เครื่องมือ: `scripts/fxdreema_concepts.py`
> · สถานะแล็บอ้างอิง: memory signal-landscape + EDGE_CATALOG + EA_SCORECARD (ณ 2026-07-10)

## ภาพรวม concept (primary classification)

| Concept | ไฟล์ | สถานะแล็บ | มุมต่อยอด |
|---|---:|---|---|
| Grid / averaging / basket-close | 190 (+93 รอง) | ⚙️ ความถนัดหลักของแล็บอยู่แล้ว (Boss_14/16, RSI-MR) | โครง "แก้ไม้แบบมีเบรก" ของเราเหนือกว่าที่คอร์สสอน — ใช้คลังนี้เป็นตัวอย่าง variation เท่านั้น |
| Session / time-window | 176 (+35) | ⚰️ naked ตายเกือบหมด (AsianRange, London→NY) · ✅ LondonConso (consolidation ก่อน London) validated | หมายเหตุ: ก้อนใหญ่คือ "Time filter" ประกอบ EA อื่น ไม่ใช่ session strategy แท้ |
| Mean-reversion / oscillator fade | 169 (+26) | ⚰️ naked บน FX ตายเป็นระบบ · ✅ รอดเมื่อเป็น grid+cage (RSI-MR EURUSD, Boss_16 XAU) | pattern ชัด: คอร์สสอน reversion+grid — ตรง thesis แล็บว่า reversion ต้องมีโครงช่วย |
| Trend-following (MA/ST/SAR/Ichimoku) | 129 (+8) | ⚰️ EMA-cross ตายทุก symbol · ✅ SuperTrend XAU validated (corr สูงกับ BRK) | เพดานรู้แล้ว — ของใหม่ในคลังส่วนใหญ่คือ variation เดิม |
| **Fibonacci / harmonic / geometry** | **77 (+5)** | 🆕 **ยังไม่เคยทดสอบจริงจัง** | ก้อนใหญ่สุดที่แล็บไม่เคยแตะ — แต่เชิง thesis เป็น reversion-geometry (ต้องผ่านบาร์ naked≥0.85) |
| Indicator exercise (generic) | 55 | — | แบบฝึกพื้นฐาน ไม่มี concept เฉพาะ |
| **Correlation / pair / carry / strength** | **40 (+4)** | 🆕 ยังไม่เคยทดสอบ*เป็น strategy* (แล็บใช้ corr เป็นเครื่องมือพอร์ตเท่านั้น) | มุมต่าง: เทรด**ความสัมพันธ์**แทนราคา — คลาสสัญญาณคนละโลกกับที่มี = คุณค่า diversification จริง |
| Dashboard / tool | 37 (+33) | — | เครื่องมือ ไม่ใช่ strategy |
| Scalping | 28 (+9) | ⚠️ ทดสอบไม่ได้จริงบน lane MT4 fixed-spread (บทเรียน Scalper_S3) | ต้องมี tick-quality lane ก่อน — พักไว้ |
| Candle patterns (engulf/pinbar/inside) | 16 (+2) | 🔶 บางส่วนอยู่คิว mine#2 (candle-gate ORDER-021 briefs) | ใช้เป็น **gate/confluence** ไม่ใช่สัญญาณเดี่ยว |
| S/R / supply-demand zone | 15 (+2) | 🔶 pivot NZDUSD ตาย · retest-zone อยู่ mine#2 briefs | รวมร่างกับ SMC family ได้ |
| Divergence | 14 (+5) | 🆕 ยังไม่เคยทดสอบ | เชิง thesis = leading-to-event ระวัง lagging-conditioning artifact (บทเรียน 067) |
| **Elliott / wave-count** | **9 (16 รวม zigzag-variant)** | 🆕 **ยังไม่เคยแตะเลย** | ดูลิสต์เต็มด้านล่าง — มีตามที่ user บอกจริง รวม Wave-5 เฉพาะ |
| **SMC / OB / FVG / CHoCH** | **9** | ✅ **มี precedent validated: Gold SMC (EA_Project) ผ่าน OOS** | ดูลิสต์เต็มด้านล่าง — แต้มต่อสุดในกลุ่มใหม่ |
| News / calendar | 9 (+3) | 🆕 เพิ่ง build ฝั่ง risk (ORDER-073) — ฝั่ง entry ยังไม่เคย | synergy ตรง ๆ กับ news_week.csv ที่มีแล้ว |
| Breakout | 4 (+4) | ✅ มงกุฎแล็บ (BRK-XAU H1) | คอร์สแทบไม่สอน — แล็บนำอยู่แล้ว |
| Unclassified | 73 | — | ไฟล์ evidence บาง (ชื่อ generic, ไม่มี label) |

## 🌊 Elliott Wave — ลิสต์เต็ม (ตามที่ user ยืนยันว่ามี)

ชุด (Jobot) = ซีรีส์แบบฝึกไล่ระดับ:
1. **(Jobot) Elliott Wave 123 Dont care 45ABC v1** — เทรดเฉพาะ wave 1-2-3 ไม่สนคลื่นหลัง (โครง: นับ swing ด้วย ZigZag)
2. **(Jobot) Elliott Wave 5 Zone v1 + v1 AAA** — **ตัว "ขา 5" ที่ user พูดถึง**: กำหนดโซนเป้า wave 5 แล้วเข้าตามแรงส่งท้าย impulse
3. **(Jobot) Elliott Wave 14 Correction Price Action v1** (+เวอร์ชัน (Oh)) — เล่นคลื่นพักตัว (wave 1→4 correction) ประกอบ Fibonacci (label: "Draw Fibonacci")
4. **(Jobot) Elliott Wave Complex v1.1** — โครงคลื่นซับซ้อน + label "H4 Wave" = ใช้คลื่น H4 คุม
5. **(Jobot) Elliott Wave Hidden and Divergence v.1** — confluence คลื่น × divergence
6. **(Jobot) Elliott Wave Multiples Time Frame Trading** — นับคลื่น multi-TF
- ญาติ ZigZag-structure: (Jobot) Trend Line by Zigzag (+Martingale/CSV variants), ycp zigzag vs ema

**มุมต่อยอดที่ประเมินเบื้องต้น (ยังไม่ใช่ verdict):** wave-5 entry = สัญญาณ**ต่อเนื่องของเทรนด์** (momentum-class = ตรง edge thesis ของพอร์ต ต่างจาก reversion) และ Boss V2 มี swing/ZigZag ingredient อยู่ในคลังอะไหล่ — เส้นทางทดสอบถูกสุด: แกะ rule จาก block labels ตัว Wave 5 Zone → เขียนเป็น Entry module → naked probe ตามบาร์มาตรฐาน

## 🧱 SMC — ลิสต์เต็ม 9 ไฟล์

- **FVG series: FVG FollowTrend · FVG RichShield Pro · FVG serie Plus V29.2** — ตระกูล Fair-Value-Gap (labels: "FVG (Signal", "Draw Line(FVG-B1/B2") บางตัวผสม RSI gate ("RSI<30 || RSI>70")
- **SMC V2** — Change-of-Character (labels: "Choch Buy=1 / Choch Sell=1")
- **(Rhyme) Sniper (Breakout, Reversal, Order Block)** — สามสัญญาณรวม incl OB
- **Down thery keeplast V1.0** — วาด OrderBlocks Buy/Sell เป็นฐาน entry
- **Grid Pun Lot Basic V.2** — มี "Show Order Block" ประกอบ grid
- (Jobot) Arbitage 3 Pairs Partial Imbalance — ⚠️ "imbalance" ในความหมาย arb ไม่ใช่ SMC (จัดผิดหมวด นับเป็น correlation)

**มุมต่อยอด:** แล็บมี **Gold SMC = OOS_VALIDATED** อยู่แล้ว (EA_Project, ห้าม optimize เพิ่ม) → FVG/CHoCH จากคอร์สคือ vocabulary เดียวกัน — ทางถูกสุด: เทียบ rule ในไฟล์คอร์สกับ Gold SMC ที่ validate แล้ว หาส่วนต่างที่เป็นไอเดียใหม่จริง (เช่น FVG entry ที่ Gold SMC ไม่มี) แล้วทดสอบเป็น lever เพิ่มบนฐานที่พิสูจน์แล้ว ไม่เริ่มจากศูนย์

## ลำดับความน่าลงแรง (ความเห็น Claude เรียงตาม edge thesis พอร์ต — user ตัดสิน)

1. **SMC/FVG** — precedent validated + สัญญาณ event-driven momentum
2. **Elliott wave-5** — momentum-class + user มีความรู้จากคอร์สโดยตรง (แกะ rule ด้วยกันได้เร็ว)
3. **Correlation/strength as strategy** — คลาสสัญญาณใหม่ทั้งกลุ่ม = diversification จริงถ้ารอด
4. News-entry (ต่อยอด infra 073 ที่มีแล้ว) · 5. Divergence · 6. Harmonic/fib (reversion-geometry, ท้ายคิว)
