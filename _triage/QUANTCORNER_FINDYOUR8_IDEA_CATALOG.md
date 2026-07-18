# QUANTCORNER_FINDYOUR8_IDEA_CATALOG — เก็บไอเดียจาก quant-corner.com + Blockdit/FB "ว่าด้วยการเทรด" (findyour8)

> เอกสารนี้ = "อ่านมาได้ไอเดียอะไรบ้าง + แต่ละไอเดียต่อยอดจากจุดไหน" — **ไม่ตัดสิน risk/verdict**
> (ต้องผ่าน VERDICT GATE ใน CLAUDE.md ก่อนถึงจะเขียน verdict ใดๆ) · แหล่ง: user ให้ 3 ลิงก์มาสำรวจ
> 2026-07-18 — quant-corner.com (เว็บบทความ, อ่านครบทุก category), blockdit.com/findyour8
> (อ่านครบ 7/7 โพสต์), facebook.com/FINDYOUR8 + facebook.com/quantcornerthailand
> (**guest-access capped ที่ 1 โพสต์/เพจ — Facebook ต้อง login ถึงจะเห็นประวัติเต็ม, ไม่ได้ login ให้
> เพราะเป็น prohibited action** — ถ้า user เจอโพสต์เพิ่มเติมตอน login เอง ส่ง link/ข้อความมาต่อได้)

## ภาพรวมแหล่งข้อมูล

| แหล่ง | ขอบเขตที่อ่านได้ | จำนวนที่ครอบคลุม |
|---|---|---|
| quant-corner.com | เว็บบทความ Quant/Options เชิงวิชาการ, ทุก category (14 หมวด) + Quant Tool Gallery | ~16 บทความ ครบทั้งเว็บ (เว็บเล็ก) |
| blockdit.com/findyour8 ("ว่าด้วยการเทรด") | Trading journal เชิง retail/practical, เจ้าของเดียวกับ FB FINDYOUR8 | ครบ 7/7 โพสต์ (ไม่มีซีรีส์/วิดีโอ/พอดแคสต์เพิ่ม) |
| facebook.com/FINDYOUR8 | mirror ของ Blockdit + โพสต์เฉพาะ FB (รูปภาพ) | guest เห็นแค่โพสต์ล่าสุด 1 อัน + คอมเมนต์บางส่วน |
| facebook.com/quantcornerthailand | เพจ FB ของ QuantCorner | guest เห็นแค่ "updated profile picture" ไม่มีโพสต์เนื้อหา |

## ตารางไอเดียเต็ม (เรียงตามความเกี่ยวข้องกับ mechanism EA_LAB ปัจจุบัน)

| # | ไอเดีย/หลักการ | แหล่ง | เอาไปต่อยอด EA_LAB ยังไง | Lever ที่เกี่ยว | ความเกี่ยวข้อง |
|---|---|---|---|---|---|
| 1 | **Pairs Trading (stat-arb spread mean-reversion)** — เทรด spread ระหว่าง correlated instruments 2 ตัว แทนเทรดราคาตรงๆ | quant-corner.com (Quant Tool Gallery) + ซ้ำใน Hedge Funds "Relative Value" | **concept ใหม่ทั้งหมด** ที่ยังไม่เคยมีในพอร์ต — สอดคล้องกับ FXDREEMA_IDEA_CATALOG ข้อ "Correlation/pair/carry/strength = 🆕 ยังไม่เคยทดสอบเป็น strategy" (แล็บใช้ corr เป็นเครื่องมือพอร์ตอย่างเดียว) ต้องมี cointegration/z-score check ก่อนสร้าง เช่น EURUSD-GBPUSD, Gold-Silver | entry-threshold (สัญญาณใหม่), symbol (คู่แทนเดี่ยว) | **สูงสุด** — 2 แหล่งพูดตรงกัน + เติมช่องว่างที่มีอยู่แล้วในแผนเดิม |
| 2 | **Vertical barrier exit (Triple Barrier Method)** — ปิดสถานะด้วย max-holding-bars ถ้าไม่โดน TP/SL ก่อน | quant-corner.com (Triple Barrier Method) | หลาย EA ในพอร์ตมี TP/SL (horizontal barriers) แต่ไม่มี **time-based force-close** — เพิ่มเป็น exit-mode lever ใหม่สำหรับ EA ที่ค้าง position นานผิดปกติ (เช่น grid ที่ไม่ escalate แต่ก็ไม่ปิด) | exit-mode | สูง — lever ที่ยังไม่เคยแตะตรงตาม LAST-OPTIMIZE-BEFORE-VERDICT rule |
| 3 | **ATR-adaptive SL + หลีกเลี่ยง round-number SL (stop-hunt awareness)** — SL วางล่วงหน้าที่ level คนหมู่มากใช้ (round number) มักโดน "ล่าสภาพคล่อง" ราคาแตะแล้วเด้งกลับ | Blockdit (ทำไมไม่วางStoploss ล่วงหน้า) | SL-width แบบ ATR-adaptive + สุ่ม offset เล็กน้อยจาก round-number level — ตรงกับปัญหา SL-fragility ที่เจอใน Lane C SMCxSTO (991070) พอดี | SL-width, exit-mode | สูง — ตรงกับปัญหาจริงที่เพิ่งเจอ session ก่อนหน้า |
| 4 | **Multi-EMA stacked filter (Steve Burns style)** — EMA5/10/20/50/100/200 ทำหน้าที่ต่างกัน (short-trend/momentum/dynamic S-R/long-trend/hurdle/last-defense) ซ้อนกันแทนเส้นเดียว | Blockdit (Steve Burns EMA) | entry-threshold ใหม่สำหรับ trender family (XAU/GBP) — entry ผ่านเมื่อ EMA หลายเส้นเรียงทิศเดียวกัน ไม่ใช่แค่ EMA เดียว | entry-threshold | สูง — ตรงกับ trender home ที่มีอยู่ |
| 5 | **Granger causality / transfer entropy เป็น pre-filter คัดเลือก indicator** — เช็คว่า indicator "เป็นเหตุ" จริงต่อราคา (ไม่ใช่แค่ correlate) ก่อนเอาไป optimize | quant-corner.com (Understanding Causality) | ใช้เป็นตัวคัด indicator/barometer **ก่อน**เข้า sweep — ประหยัด optimize cycle เพราะตัดตัวที่ไม่มี causal lead ทิ้งตั้งแต่ต้น เช่น เช็ค MacroGate barometer ตัวไหนมี Granger-lead ต่อราคาจริง | entry-threshold (pre-filter), governance | กลาง-สูง — เป็น tool ใหม่ ไม่ใช่ signal โดยตรง แต่ลด waste ได้จริง |
| 6 | **Risk Parity weight allocation** — จัดสัดส่วนพอร์ตด้วย equal risk contribution (ใช้ leverage ถ่วงความเสี่ยงให้เท่ากันข้าม asset) แทนสัดส่วนคงที่ | quant-corner.com (Risk Parity Portfolio) | portfolio-selector ตอนนี้ gate ด้วย corr<0.4/0.6 อย่างเดียว ยังไม่มีสูตรถ่วง lot ตาม risk-parity ระหว่าง EA/symbol — เพิ่มเป็นขั้นตอนหลัง corr-gate | (portfolio weight, ไม่ใช่ EA-level lever) | กลาง — ใช้ตอนจัดพอร์ตรวม ไม่ใช่ตอนออกแบบ EA เดี่ยว |
| 7 | **Risk-Based Position Sizing สูตร** — `Position % = Risk per Trade × 100 / Volatility Stoploss %` | Blockdit (5 แนวคิดป้องกันความเสี่ยง) | ยืนยันสูตร vol-adaptive lot sizing ที่ EDGE_CATALOG มีอยู่แล้ว (vol-gate tamer) — ใช้เช็คว่า lot-law ปัจจุบันตรง pattern นี้หรือยัง | lot-law | กลาง — confirm ของเดิม ไม่ใช่ lever ใหม่ |
| 8 | **OHLC multi-feed High/Low ไม่ execute ได้จริง** — ข้อมูล H/L จาก feed รวมหลายตลาด (เช่น Yahoo) อาจไม่ตรงกับราคาที่ broker เดียวเทรดได้จริง | quant-corner.com (Backtester pitfalls) | caveat เพิ่มสำหรับ backtest-optimize-rigor — เช็คว่า MT5 tester ใช้ tick data ที่ตรงกับ broker จริงในช่วงที่ backtest หรือไม่ โดยเฉพาะ symbol ที่ tick history ไม่ครบ (มี gotcha คล้าย MT4 history gap ที่เจอมาก่อน) | (methodology, ไม่ใช่ EA lever) | กลาง — เสริมความรอบคอบขั้น data-quality |
| 9 | **Major Events Affecting Asset Dashboard (event-driven macro filter)** | quant-corner.com (Quant Tool Gallery) | เสริม MacroGate ที่ validate แล้ว (ORDER-073) — ยังไม่มี lever ใหม่ชัดเจน แค่ยืนยันทิศทาง event-driven regime filter ที่ทำอยู่ถูกทาง | (governance, ยืนยันของเดิม) | ต่ำ-กลาง |
| 10 | **Hedging Mode / Ticket-by-Ticket ≠ FIFO netting** — โบรก crypto/บางโบรก FX แสดง floating พอร์ตติดลบทั้งที่ปิดไม้กำไรจริง เพราะไม้อื่นยังลอย | FB (findyour8 — เทรดกริดคริปโต) | **QA/reporting caveat**: อ่านผล backtest/live ของ EA แบบ grid/DCA (Boss V2 ฯลฯ) ต้องแยก per-ticket P&L ออกจาก portfolio floating ก่อนตัดสิน DD/verdict | (วิธีอ่านผล ไม่ใช่ lever) | กลาง — ป้องกันอ่านผลผิด ไม่ใช่ EA ใหม่ |
| 11 | Law of Small Numbers (coin-flip 10/30/100 ครั้ง) | Blockdit (Mini-Series Ep1) | ยืนยัน VERDICT GATE เดิม (ห้ามตัดสินจาก sample น้อย) — ไม่ใช่ lever ใหม่ | (governance, ซ้ำ doctrine) | ต่ำ |
| 12 | CANSLIM (7 ปัจจัยเลือกหุ้นเติบโต: earnings, new product, institutional sponsorship, market direction ฯลฯ) | Blockdit | ใช้ได้แค่ "M = Market Direction" ↔ Regime-Gate ที่มีอยู่แล้ว ส่วนที่เหลือ (EPS, fundamental) ใช้กับ FX/Gold ไม่ได้เพราะไม่มีข้อมูล fundamental รายตัว | (ไม่มี lever ใหม่) | ต่ำ — ระบบหุ้น ไม่ตรง mechanism |
| 13 | Hedge Fund strategy types อีก 7 ประเภท (event-driven, distressed debt, quant/algo, merger arb, fixed income, multi-strategy, EM) | quant-corner.com (เจาะลึกกลยุทธ์ Hedge Funds) | แค่ list ชื่อกองทุน ไม่มีกลไกละเอียดพอเอาไปสร้าง ส่วนใหญ่ต้องใช้ instrument ที่ retail MT5 เข้าไม่ถึง (corporate bonds, M&A arb) | — | ต่ำมาก |
| 14 | Delta Hedging Actual-vs-Implied Vol, Monte Carlo Option Pricing (Black-Scholes) | quant-corner.com | คนละ instrument class (Options, ไม่มี infra ใน MT4/MT5 retail) — borrow ได้แค่แนวคิดเปรียบเทียบ realized-vol กับ forecast-vol ไปปรับ ATR/SL | — | ต่ำมาก |
| 15 | Sentiment Analysis on FED Minutes (NLP) | quant-corner.com (Quant Tool Gallery) | ต้องมี external NLP feed — ไม่มี infra รองรับตอนนี้ เก็บไว้เป็นไอเดียระยะยาวถ้าจะทำ MacroGate v2 | — | ต่ำ (infra ไม่พร้อม) |

## ลำดับความน่าลงแรง (เรียงตาม edge thesis พอร์ต — user ตัดสินสุดท้าย)

1. **Pairs Trading / stat-arb spread reversion** — concept ใหม่ทั้งกลุ่ม + ยืนยันซ้ำ 2 แหล่ง + ตรงกับ
   "correlation-as-strategy" gap ที่ FXDREEMA_IDEA_CATALOG ระบุไว้แล้วว่ายังไม่เคยทดสอบ
2. **ATR-adaptive SL + round-number avoidance** — rescue-lever ที่ตรงปัญหาจริงของ Lane C SMCxSTO
   (SL-fragility) พร้อมทดสอบได้ทันที ไม่ต้องสร้าง EA ใหม่
3. **Vertical-barrier exit (max-holding force-close)** — lever ใหม่ที่ประยุกต์ได้กับ EA ที่มีอยู่แล้ว
   หลายตัวโดยไม่ต้องสร้างใหม่
4. **Multi-EMA stacked entry filter** — เสริม trender family ที่มีอยู่
5. **Granger causality pre-filter** — tool ประกอบการคัด indicator ก่อน optimize (ประหยัดรอบ)
6. Risk Parity weight allocation — ใช้ตอนจัดพอร์ตรวม ไม่เร่งด่วนเท่า EA-level lever

ที่เหลือ (CANSLIM, Options/Delta-hedge, Hedge-fund strategy list, Sentiment NLP) เก็บไว้เป็นความรู้พื้นหลัง
ไม่ต้อง build เพราะไม่ตรง mechanism ปัจจุบันหรือ infra ไม่พร้อม
