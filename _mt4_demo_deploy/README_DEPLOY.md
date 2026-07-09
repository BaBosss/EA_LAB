# Demo Experiment — Treasure-Hunt Survivors (7 + 1exp EAs, MT4 + MT5)

> **ที่มา:** 3 ตัวแรกคัดจาก EA ~1,300 (ORDER-036/046/047) · 2 ตัวหลัง = **สร้างเอง source ครบ**
> (RSI-MR + Zeus, ผ่าน holdout+MC+WFA) · หลักฐาน: `EA_SCORECARD_AND_REGISTRY.md` + verdict YAML ต่อตัว

---

## ต้องมี 2 บัญชี demo (คนละ platform)
| platform | EA | ลง terminal ที่ |
|---|---|---|
| **MT4** | #1 UnNomGuai · #2 RSI-orig · #3 swb | portable ใหม่ `D:\Meta4demo` |
| **MT5** | #4 RSI-MR · #5 Zeus · #6 BRK-XAU · #7 SqueezeBRK · #8 Trendline(exp) | portable ใหม่ `D:\Meta5demo` |

- ทั้งคู่: บัญชีใหม่ **$10,000** · type **Hedge** (RSI-MR ต้องการ hedging)
- **broker: user ใช้ Exness (ตัดสิน 2026-07-09) — ตรวจแล้วไม่ต้องแก้ set ไหน:** XAUUSD Exness = 3 ตำแหน่ง
  แต่ EA ทองทั้ง 4 ปลอดภัย (BRK/Squeeze/Trendline = ATR-mult ล้วน · Zeus ใช้ PipSize digit-aware →
  pip = $0.01 เท่ากันทุก broker) · FX pairs = 5 ตำแหน่งเท่า broker เดิม
- **⚠️ Exness ต้องเปิดชนิด Standard ไม่ใช่ Cent** — cent ใช้ symbol ห้อย `c` และ P&L = 1/100 ของตาราง
  expected values + kill-switch $ ด้านล่างจะเพี้ยนหมด (ถ้าจำเป็นต้องใช้ cent → ให้ Claude สเกลเกณฑ์ใหม่ก่อน)
- spread/feed Exness ≠ broker ที่ validate (ThinkMarkets) = watch item ของรอบ monitor แรก ไม่ใช่ blocker
- ❌ ห้ามใช้ `D:\Meta4`/`D:\Meta4b`/`D:\Meta 5`/`D:\Meta 5b` (เลนเทส script ฆ่า terminal ทิ้งประจำ)
- 1 บัญชี/platform รันหลาย EA ได้ (คนละ chart/magic)

---

## EA ทั้ง 7

| # | EA | Platform | Chart | Set | Magic | SL |
|---|---|---|---|---|---|---|
| 1 | **UnNomGuaiV1.132** | MT4 | EURUSD H1 | `UnNomGuai_cap20.set` | 1/2 | ไม่มี |
| 2 | **RSI from pips_EA** | MT4 | EURUSD H1 | *(defaults)* | 5888 | ไม่มี |
| 3 | **swb grid 4.1.0.3_h** | MT4 | AUDCAD H1 | `swb_AUDCAD_demo.set` | 990 | ไม่มี |
| 4 | **(Boss)_RSI_MR_GridLog_rev01** | MT5 | EURUSD H1 | `RSIMR_EURUSD_H1_demo.set` | 990103 | **มี (ATR)** |
| 5 | **(Boss)_ZeusInspired_GridLog_rev01** | MT5 | **XAUUSD** H1 | `ZeusInspired_XAUUSD_H1_demo.set` | 990101 | **มี (ATR)** |
| 6 | **EA_BREAKOUT_XAU** | MT5 | **XAUUSD** H1 | `EA_BREAKOUT_XAU_demo.set` | 991001 | **มี (ATR, RR 3.3)** |
| 7 | **(BRK)_SqueezeBreakout_rev01** | MT5 | **XAUUSD** H1 | `SqueezeBreakout_XAU_demo.set` | 991004 | **มี (ATR, RR 5)** |
| 8 | **(BRK)_TrendlineBreakout_rev01** (EXPERIMENTAL) | MT5 | **XAUUSD** H1 | `TrendlineBreakout_XAU_demo.set` | 991002 | **มี (ATR, RR 5.3)** |

**ค่าที่ผ่านการพิสูจน์ (ใช้เทียบตอน judge):**

| EA | PF | MaxDD | robustness | ไม้/เดือน~ |
|---|---|---|---|---|
| UnNomGuai | 1.63 (M0) | 19% | plateau-verified | ~90 |
| RSI-orig | 2.07 (M0) | 25% | plateau-verified | ~45 |
| swb @ AUDCAD | 1.80 (M0) | 20% | plateau-verified | ~35 |
| RSI-MR | 1.34-2.17 (3 window) | ~5% | **ROBUST (MC+WFA)** | ~100/yr |
| Zeus @ XAU | 1.38-2.16 (3 window) | **~4%** | MARGINAL (MC ✓, WFA อ่อน) | ~130/yr |
| BRK-XAU | 1.74-2.94 (3 window) | ~2% | MARGINAL (MC PF-5th 1.53 สูงสุด, thin) | ~13/yr (ต่ำ) |
| SqueezeBRK | 2.07-2.67 (3 window) | **~1.6%** ต่ำสุด | MARGINAL→ROBUST (MC PF-5th 1.25, WFA 3/3 OOS) | ~15/yr · **uncorrelated กับ gold ตัวอื่น (-0.09/0.17)** |
| Trendline (exp) | 1.23-1.40 (3 window) | ~4% | EXPERIMENTAL (MC PF-5th 0.986 เฉียด, sample 351 ใหญ่, OOS>IS) | ~55/yr · **corr ลบกับ BRK/RSI (-0.14/-0.18)** |

---

## 🚨 WILL-IT-TRADE checklist (กัน "attach แล้วเงียบ 0 ไม้" — เช็คก่อนทุกครั้ง)
1. **MT5 (#4-7): `.set` ต้องมี `AllowLive=true`** — set ในโฟลเดอร์นี้แก้ให้แล้ว (แต่ถ้า recompile/แก้เอง อย่าลืม) ·
   ถ้า AllowLive=false บน demo = **ไม่ส่ง order เลย เงียบสนิท** (ใน tester ไม่เจอเพราะ MQL_TESTER bypass)
2. **RSI-MR (#4) ต้องบัญชี HEDGING** — ถ้าเปิดบัญชี Netting EA จะ **INIT_FAILED** (มี guard) ไม่ยอมโหลด → บัญชี demo เลือก type **Hedge**
3. **MT4 (#1-3):** ปุ่ม **AutoTrading เขียว** + Common tab **✅ Allow live trading** (commercial EA ไม่มี input AllowLive)
4. **symbol ให้ตรง broker** — เปิด chart symbol ตามตาราง (ถ้า broker มี suffix เช่น XAUUSD.r ต้องเปิด chart ตัวนั้น; EA ใช้ _Symbol ของ chart)
5. **magic ไม่ชนกัน** — MT5: 990103/990101/991001 · MT4: 1-2/5888/990 (distinct ✓)
6. เช็ค 1 ชม.แรก: มี order เข้า หรือ Journal ขึ้น log EA (RSI-MR/Zeus/BRK พิมพ์ init line) = ทำงาน · ถ้าเงียบ → ย้อนดูข้อ 1-4

## ขั้นตอน attach (ต่อ EA)
1. เปิด chart ตามตาราง (symbol + H1)
2. ลาก EA ลง chart → ✅ Allow live trading · **โหลด set ตามตาราง** (RSI-orig ใช้ defaults)
3. **AutoTrading เขียว** · **Save Profile** (กัน restart แล้ว chart หาย)
4. เช็ค Journal 5 นาที: ไม่มี error วนซ้ำ (EA อาจเงียบเป็นวัน = ปกติ) · **MT5: Zeus/RSI-MR ต้อง bar-open ถึงเทรด**
5. **จดวันที่ attach → แจ้ง Claude** = นาฬิกา demo เริ่ม (judge +3 เดือน)

---

## ⚠️ กติกาเหล็ก
- **ห้ามแก้ input** นอกจาก set ที่ให้ — validate ด้วยค่านี้ แก้ = โมฆะ
- **#1-3 (MT4) ไม่มี hard SL** → เครื่อง/VPS **ต้องออนไลน์ตลอด** (หลุด = ไม้เปลือย) · #4-7 (MT5) มี SL แต่ก็ควรออนไลน์
- MT4: ห้ามเพิ่ม EA อื่นในบัญชี (magic 1/2 ชนง่าย)
- เช็คทุกเช้าจันทร์: terminal รัน + AutoTrading เขียว (update ชอบ reset)

---

## 🔴 Kill-switch (เช็คทุกสัปดาห์ — หยุดตัวนั้นทันที)
- UnNomGuai เปิด **>12 ไม้พร้อมกัน** (ไม่เคยเกิน 9)
- RSI-orig ladder ทะลุ **0.08 lot/ไม้** (ไม่เคยเกิน 0.06)
- swb ladder ทะลุ **1.0 lot/ไม้** @ AUDCAD
- RSI-MR เปิด **>8 ไม้** หรือ lot/ไม้ ทะลุที่ LOG5 ควรเป็น (cap 8 ไม้ในโค้ดแล้ว)
- Zeus เปิด **>6 ไม้** (cap 6 ในโค้ด) หรือ DD เกิน 15% (backtest ไม่เคยเกิน ~4%)
- BRK-XAU / SqueezeBRK: single-position (ควรมีไม้เดียว) — ถ้าเห็น >1 ไม้เปิดพร้อมกัน = ผิดปกติ · DD เกิน 10%
- Trendline (#8 exp): single-position, RR 5.3 — weakest ของกอง (PF-5th 0.986) → kill เข้มกว่า: DD>8% หรือ net ลบ 6 สัปดาห์

**เตือน:** equity DD ตัวนั้นแตะ 25% (MT4) / 15% (MT5, เพราะ backtest DD ต่ำมาก)
**Kill:** DD แตะ 35% (MT4) / 25% (MT5) · หรือ net ลบต่อเนื่อง 8 สัปดาห์

---

## 📊 Monitoring & Judge
- ทุก ~2 สัปดาห์: export statement **ทั้ง MT4 + MT5** → ส่ง Claude → แยก P&L ตาม magic เทียบตารางค่าคาดหวัง
- **Judge: ≥3 เดือน + ≥30 trades/ตัว** → PF live ≥1.4 + DD ไม่แตะเตือน + พฤติกรรมตรง backtest → ค่อยคุยขั้น live (lot เล็ก)
- รันคู่ ClevrFX (demo #1, attached 2026-07-06)

---

## Binary lock (MD5)
```
C6B6BCD443EFFC9D1098F5E8D0B5208D  UnNomGuaiV1.132.ex4
C6F31A2A3DF8F4A9D8D375D86801B9A6  RSI from pips_EA.ex4
35BFB25E93966DE1A9521A4A59313379  swb grid 4.1.0.3_h.ex4
```
(MT5 .ex5 ของ #4-7 = build จาก source ใน `ea_projects\` — recompile ได้ ไม่ต้อง lock)

## หมายเหตุกลไก
- **UnNomGuai** — grid ตะกร้า 0.01→0.07, ปิดยกชุด +$8, cap 20 ชั้น · EURUSD-only
- **RSI-orig** — RSI(14) MR สองทาง + grid linear +0.01, virtual TP ~15pip · EURUSD-only · `RSI_FROM_PIPS_REVERSE_ENGINEERING.md`
- **swb** — BB+Stoch+RSI grid flat-lot · AUDCAD-only
- **RSI-MR** (source เรา) — RSI MR + ATR grid + LOG lot + real SL · edge=recovery(capped) · EURUSD-only · `ea_projects\(Boss)_RSI_MR_GridLog\`
- **Zeus** (source เรา) — pending-stop **breakout** + ATR grid + LOG lot + real SL · edge=momentum (DD จิ๋วสุดในกอง) · **GOLD-only** · `ea_projects\(Boss)_ZeusInspired_GridLog\`
- **BRK-XAU** — Donchian 40-bar **breakout** + EMA200 filter, single-position real SL (RR 3.3), **ไม่มี grid = ปลอดภัยสุด** · edge=momentum, DD ~2% ต่ำสุด, ความถี่ต่ำ ~13/yr (thin) · **GOLD-only** · `ea_projects\EA_BREAKOUT_XAU\` · kill: DD>10% หรือ >2 ไม้เปิดพร้อมกัน (ควรเป็น single)
- **SqueezeBRK** (source เรา) — volatility-squeeze release (BB บีบใน Keltner) + Donchian-60 break + EMA200, single-position real SL (RR 5) · edge=momentum ที่จับ "vol บีบแล้วระเบิด" · **GOLD-only แต่ uncorrelated กับ Zeus/BRK (-0.09/0.17) = diversify gold** · DD ~1.6% ต่ำสุดในกอง · `ea_projects\(BRK)_SqueezeBreakout\`
| Trendline (exp) | 1.23-1.40 (3 window) | ~4% | EXPERIMENTAL (MC PF-5th 0.986 เฉียด, sample 351 ใหญ่, OOS>IS) | ~55/yr · **corr ลบกับ BRK/RSI (-0.14/-0.18)** |
- **หมายเหตุ gold (3 ตัว: Zeus/BRK/Squeeze):** corr ต่ำ-ลบทั้งหมด (จับคนละ move) → รันทั้ง 3 บนบัญชี MT5 เดียวได้ ไม่ต้องลด lot · แต่ทั้ง 3 = XAUUSD → ถ้า gold มี gap/หยุดเทรด กระทบพร้อมกัน = จับตา combined gold exposure
- **Trendline (#8 EXPERIMENTAL)** (source เรา) — diagonal trendline (2-pivot) + triangle-convergence + EMA200 break, single-position RR 5.3 · edge=momentum ที่จับ "ทะลุเส้นทแยง" (ต่างจาก Donchian/squeeze แนวนอน) · **GOLD-only แต่ corr ลบกับ BRK/RSI = diversifier ดี** · ⚠️ borderline (PF-5th 0.986 ต่ำกว่าเกณฑ์นิดเดียว, sample 351 ใหญ่ทำให้เชื่อได้) — user เพิ่มเพื่อ low-corr breadth · drop ได้ถ้า demo ไม่เข้าเป้า · `ea_projects\(BRK)_TrendlineBreakout\`
- **FX travel = ตัน (2026-07-08):** trendline+squeeze บน EURUSD/GBPUSD ตกทุก window (gold-specific) → ไม่มี low-corr candidate เพิ่มจากคู่ FX · corr diversity ที่ได้มาจากกลไกต่างบน gold (Donchian/squeeze/diagonal) เท่านั้น
