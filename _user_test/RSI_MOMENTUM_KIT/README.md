# RSI MOMENTUM TEST KIT — สำหรับ user เทสเอง (2026-07-18)

EA เดียว รัน RSI-as-momentum ได้ 3 แบบ + filter 3 ตัว (เปิด/ปิดได้). สร้างจากคำขอ "ลอง RSI strategy ให้หมด
+ filter (MACD/SuperTrend/EMA/BB)". **แลบเทสแล้วยังไม่เจอ edge ที่ผ่านบาร์ (ดูผลด้านล่าง) — ชุดนี้เก็บไว้ให้
เทสมือเอง** เพราะ user มีสายตาที่ tester ไม่มี. ทุก .set ปรับต่อได้ในแท็บ Inputs.

## ไฟล์ในชุด
- `RsiMomentum_Naked.ex5` — ตัว EA (คอมไพล์แล้ว, tester-gate + bar-open gate + magic-scope ครบ)
- `sets/*.set` — config พร้อมโหลด 8 ตัว (ดูตารางล่าง)
- magic = 999097 · lot = 0.01 flat (ไม่มี grid/martingale) · SL = ATR จาก swing, TP = 2×SL

## วิธีเทส (MT5 Strategy Tester)
1. ก๊อป `RsiMomentum_Naked.ex5` → `<MT5 data folder>\MQL5\Experts\` แล้ว refresh Navigator
2. Strategy Tester → เลือก EA → Load ไฟล์ .set ที่อยากลอง → เลือก Symbol/TF → **Model = "1 minute OHLC"** (พอสำหรับ single-position; ไม่ต้อง every-tick)
3. ลาก tester ไปเทรดจริงต้องตั้ง `_06_AllowLive=true` (ใน backtest ไม่ต้อง — tester-gate เปิดให้เอง)

## 3 strategy (เลือกด้วย `_01_RsiMode`)

| Mode | ชื่อ | เข้าไม้ยังไง | lever หลัก |
|---|---|---|---|
| **0 = A** | RSI/SMA cross | RSI ตัดขึ้น SMA(20) ของตัวมันเอง = buy · ตัดลง = sell (RSI momentum smoothed) | `_01_SmaPeriod` · `_01_RsiPeriod` |
| **1 = B** | RSI-50 break | RSI ข้าม 50 (หรือ `_01_Level`) ขึ้น = buy-continuation · ข้ามลง = sell | `_01_Level` · `_01_RsiPeriod` |
| **2 = C** | RSI breakout | RSI ทำ new-high เหนือ `_01_Lookback` บาร์ = buy · new-low = sell | `_01_Lookback` · `_01_RsiPeriod` |

*ทั้ง 3 = RSI แบบ momentum (ไล่ตามแรง) ไม่ใช่ reversion (สวนโซน OB/OS) — reversion แลบเทสไว้ก่อนแล้วว่าเพดานเตี้ย*

## 3 filter (เปิดให้เข้าแม่นขึ้น — default ปิดหมด = byte-identical)

| Filter | input เปิด | ตรรกะ | หมายเหตุ |
|---|---|---|---|
| **EMA-align** | `_07_UseEmaFilter=true` | buy เฉพาะ close > EMA(`_07_EmaPeriod`=200) · sell เฉพาะ close < EMA | เข้าตามเทรนด์ใหญ่ |
| **MACD-confirm** | `_08_UseMacdFilter=true` | buy เฉพาะ MACD main > signal · sell เฉพาะ main < signal | ยืนยันโมเมนตัม |
| **BB-breakout** | `_09_UseBbFilter=true` | buy เฉพาะ close หลุด **บน** upper band · sell เฉพาะหลุด **ล่าง** lower band | momentum framing (ไม่ใช่แตะแล้วเด้ง) |

> **SuperTrend ยังไม่ใส่** (ต้อง custom calc — ใส่ตอนต่อยอดถ้าเจอ base ที่มีชีพจร). เปิด filter ทีละตัวก่อน, อย่า stack เกิน 2.

## config ในชุด (sets/)
| ไฟล์ | คืออะไร |
|---|---|
| `A/B/C_..._naked.set` | 3 mode เปล่าๆ default — จุดเริ่มต้น |
| `B_best-XAU-H4_P9-L55.set` | จุดที่ดีสุดที่แลบเจอบน XAU H4 (RsiPeriod9/Level55) — **แต่เป็น spike โดดๆ** |
| `A_best-GBP-H4_SMA30-P21.set` | จุดดีสุดบน GBP H4 (SMA30/P21, both-window 1.21/1.27) — **spike เช่นกัน** |
| `B_50break_+EMA/+MACD/+BB` | mode B เปิด filter ทีละตัว — ลองว่า filter ช่วยไหม |

## 📊 ผลที่แลบเทสไปแล้ว (ตรงไปตรงมา)
- **naked ทั้ง 3 mode บน XAU + GBP (H1+H4, sweep RsiPeriod/Level/SMA/Lookback) = ไม่มี plateau both-window** —
  ส่วนใหญ่ ~1.0 breakeven, ตัวที่ผ่าน both-window (XAU P9/L55, GBP SMA30/P21) เป็น **isolated spike** (เพื่อนบ้านตกหมด)
- แลบสรุป: **RSI ไม่มี edge เป็นสัญญาณเดี่ยว** — น่าจะดีกว่าถ้าใช้ RSI เป็น *filter* บนสัญญาณอื่น
- filter (EMA/MACD/BB) แลบยังไม่รัน เพราะกฎภายใน "filter ไม่กู้สัญญาณ naked ที่ breakeven" — **แต่ใส่มาให้ในชุดแล้ว เผื่อมือ user เจอมุมที่เครื่องมองไม่เห็น**
- 👉 ถ้า user เทสแล้วเจอ symbol/TF/config ที่ดูมีชีพจร (โดยเฉพาะเปิด filter แล้วต่างชัด) → ส่งกลับมา แลบ funnel ต่อ (plateau→holdout→MC) ให้

## แนะจุดเริ่มเทสมือ
1. `B_RSI-50-break_naked` บน **XAU H4** + ลองเปิด EMA200 (`B_50break_+EMA200-align`) เทียบ — เทรนด์กรองช่วยไหม
2. `C_RSI-breakout_naked` บน trender แรงๆ (XAU/GBP/US30) TF ใหญ่ (H4/D1)
3. ลองบ้านอื่นที่แลบไม่ได้แตะ (silver, indices, crypto-CFD) — RSI-momentum อาจชอบ instrument ผันผวนแรง
