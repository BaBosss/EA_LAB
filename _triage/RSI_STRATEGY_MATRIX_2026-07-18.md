# RSI STRATEGY MATRIX + TEST PLAN — user request 2026-07-18

> user: "ลอง RSI strategy ให้หมด (SMA20-RSI · break-trending RSI · grid RSI) เป็น entry strategy แล้วลอง filter
> (MACD/SuperTrend/EMA/BB) เพื่อเข้าให้แม่นขึ้น". นี่คือ **แผน ไม่ใช่ verdict** — ทุก cell ต้องผ่าน signal-scanner
> smoke + VERDICT GATE ก่อนตัดสิน. เป้า = คัดว่าอันไหนคุ้มลงแรง อันไหนซ้ำของตาย.

## 0. สิ่งที่ lab รู้แล้วเรื่อง RSI (dedup — ห้าม re-hunt ของตาย)

| ของเดิม | สถานะ | บทเรียน |
|---|---|---|
| **BB+RSI naked reversion** (EUR/XAU) | ❌ DEAD (ceiling ~1.1) | reversion ต้องมี **engine** (no-SL wait / bounds) ไม่ใช่ bare signal |
| **naked indicator crossover** ทั่วไป | ❌ ceiling ~1.1 บน FX majors | สัญญาณเปล่าไม่พอ |
| **ST03 / RSI-MR reversion-grid** (RSI OB/OS → grid) | ⚠️ REMOVED/edge=escalation · ไม่ port ข้าม symbol | grid-RSI reversion = ทำแล้ว, home เดียว, ตายที่อื่น |
| **NuiIndy RSI(24)+ADX** | 🟥 edge = geometric martingale ไม่ใช่ signal (flat-lot 0.72) | RSI-new-low → BuyNow = escalation |
| **RSI-from-pips** | ✅ survivor (linear-add grid) | รอดเพราะ linear ไม่ใช่ martingale |
| **ADX trend-gate บน RSI reversion** | ❌ counterproductive (ADX lag ตัด trade ดี) | filter ที่ lag ทำร้าย reversion |

**นัยยะ:** (1) **RSI-as-reversion บน majors = เพดานเตี้ย/ทำแล้ว** — อย่าวางแผนซ้ำ. (2) ช่องที่ยังเปิด = **RSI-as-MOMENTUM**
(ตรง prior พอร์ต momentum>reversion) ซึ่ง lab **ยังไม่เคยเทสเป็นระบบ**. (3) filter มีไว้ **trim ไม่ใช่ rescue** —
EDGE_CATALOG: "อย่าหวังให้ TA filter ปลดล็อกสัญญาณตาย".

## 1. Entry archetype matrix (6 ตัว × class × home × prior)

| # | Entry archetype | กลไกเข้า | class | right-home | prior | dedup |
|---|---|---|---|---|---|---|
| A | **RSI-SMA(20) crossover** (RSI ตัด SMA20 ของตัวมันเอง) | RSI>SMA20(RSI)=long · < =short | **momentum** (RSI-momentum) | trender XAU/GBP | **MED-HIGH** | 🆕 ยังไม่เทส — smooth ตัด noise ของ raw RSI |
| B | **RSI-50 break / trend-RSI** (RSI ข้าม 50 = โมเมนตัมเปลี่ยนขั้ว) | RSI cross-up 50 = long-continuation | **momentum** | trender XAU/GBP | **HIGH** | 🆕 ตรง "RSI overbought-as-continuation" (lane 2 EX142) |
| C | **RSI-trendline / RSI-higher-high break** | RSI ทำ HH หรือ break trendline บน RSI = แรงต่อ | **momentum** | trender | MED | 🆕 แต่ detection ยุ่ง (ต้องหา pivot บน RSI) |
| D | **RSI OB/OS reversal (classic 30/70)** | RSI<30 buy · >70 sell | reversion | ranger EUR/EURGBP | **LOW** | ⚠️ ใกล้ BB+RSI dead + ST03 territory |
| E | **Grid-RSI** (RSI trigger → เปิด grid) | RSI OB/OS → seed grid + add ตามระยะ | reversion+recovery | ranger | **LOW** | ❌ = ST03/RSI-MR/NuiIndy ทำแล้ว (edge=escalation) |
| F | **RSI divergence** (price HH, RSI LH) | bearish/bullish div → reversal | reversion | ranger/XAU | MED | ⚠️ MacdDiv (MACD-div) ทำแล้ว; RSI-div = variant |

**คัดแล้ว: ลงแรงกับ momentum framings (A, B, C) ก่อน** — ตรง prior + ช่องเปิดจริง. D/E = ของตาย/ซ้ำ (เทสแบบ
minimal เพื่อปิด cell ให้เป็นทางการเท่านั้น ไม่ลงลึก). F = optional ทีหลัง.

## 2. Filter overlay layer (ทำให้ "เข้าแม่นขึ้น" — แต่เป็น trimmer ไม่ใช่ rescue)

> **กฎ (framework Part 1 rule 4):** filter = risk-trimmer default, ตัดสินด้วย **expectancy-per-trade ไม่ใช่ net/PF**
> (filter ตัด trade จน net/DD ดูดีขึ้นได้ทั้งที่ expectancy แย่ลง). ทดสอบ A/B **default OFF = byte-identical** เสมอ.
> **ห้ามคาดหวังว่า filter จะกู้สัญญาณที่ naked ตาย** — ถ้า archetype naked <1.0 both-window filter ไม่ช่วย.

| Filter | เสริมกลไกไหน | ตรรกะ | ระวัง |
|---|---|---|---|
| **EMA (fast/slow หรือ EMA200)** | A,B,C | เข้า RSI-momentum เฉพาะฝั่งที่ตรง EMA-trend (align) | EMA-align กับ RSI-50-break อาจซ้ำสัญญาณ (redundant confirm) |
| **SuperTrend** | A,B | เข้าเฉพาะเมื่อ ST เขียว(long)/แดง(short) = regime gate | ST trend-specific (lane C พบ ST ดีเฉพาะ trender) |
| **MACD (histogram/line)** | A,B,C | MACD>signal ยืนยันโมเมนตัม | naked MACD cross ceiling ~1.1 → ใช้เป็น confirm เท่านั้น |
| **BB (band position/squeeze)** | B,D | B: เข้า break เฉพาะตอนหลุด band (โมเมนตัมจริง) · D: reversion เฉพาะแตะ band นอก | BB+RSI reversion = DEAD → ใช้ BB แบบ **squeeze-breakout** (momentum) ไม่ใช่ mean-touch |

**ลำดับ filter ที่น่าลองต่อ momentum-RSI (A/B):** EMA-align (ถูก+ตรง) → SuperTrend (regime) → MACD-confirm →
BB-squeeze. **ห้าม stack เกิน 2 filter รอบแรก** (over-fit + ตัด sample จนบาง).

## 3. Prioritized smoke plan (cheapest-decisive first — pacing: 1-2 cell/รอบ)

**หลัก:** naked archetype ก่อน → ถ้า pulse (PF≥1.2 หนึ่ง cell) ค่อยเติม filter ทีละตัว (A/B default-OFF).

1. **B (RSI-50 momentum break) naked** บน **XAU H1+H4** — prior สูงสุด, gate ชัดสุด. bars: pass=1.2 / dead=<1.0 both-window / กลาง=1.0-1.2→build-on
2. **A (RSI-SMA20 crossover) naked** บน XAU H4 + GBP H4 — RSI-momentum smoothed
3. ถ้า B หรือ A pulse → **+EMA200-align filter** (A/B) วัด expectancy-per-trade delta
4. ถ้ายัง → **+SuperTrend regime gate**
5. **D (classic OB/OS) minimal smoke** บน EURUSD/EURGBP H1 — **แค่ปิด cell ให้เป็นทางการ** (คาด DEAD ใกล้ BB+RSI) ไม่ลงลึก
6. E (grid-RSI) = **ข้าม** (= ST03 ทำแล้ว) เว้นแต่ user อยากยืนยัน
7. F (RSI-div) = optional หลัง A/B จบ

**GATE รวม:** ถ้า A+B naked ไม่มี cell ไหน ≥1.0 both-window บน trender (right home) หลัง sweep entry-param
(RSI period · SMA period · 50-level offset) → RSI-momentum family = ปิด, บันทึก signal-landscape.

## 4. Vehicle
สร้าง `(EXP)_RsiMomentum_Naked.mq5` ตัวเดียว รองรับ archetype A/B/C ผ่าน enum `_01_RsiMode` (SMA-cross / 50-break /
trendline) + filter block default-OFF (EMA/ST/MACD/BB) แต่ละตัว bool — ตาม chassis-safety template (bar-open gate ·
tester-gate · digit-aware pip · magic-scope). flat-lot naked ก่อน (ยังไม่มี grid → Model 1 พอ). archetype D/E ถ้าจะเทส
ใช้ ST03/RSI-MR vehicle เดิม ไม่สร้างใหม่.

---
**สรุป decisive:** ช่องที่คุ้มจริง = **RSI-as-momentum (B RSI-50-break ก่อน, แล้ว A RSI-SMA20)** บน trender —
reversion/grid-RSI (D/E) ทำแล้ว/เพดานเตี้ย เทสแค่ปิด cell. filter = ใส่ **หลัง** naked pulse เท่านั้น, วัด expectancy
ต่อไม้, ห้ามหวังกู้สัญญาณตาย.
