# KANGAROO_LOGIC_NOTES — Gold_Kangaroo.ex4 behavioral analysis (ORDER-070)

**Date:** 2026-07-10 · **Analyst:** Claude agent (locked-ea-analyzer workflow)
**Subject:** `D:\OneDrive - The Siam Cement Public Company Limited\Desktop\Metatrader\.Final EA\BOSS_EA_MT4\Gold_Kangaroo.ex4` (567,402 bytes, file date 2022-11-27)
**Method:** behavioral only — strings extraction (allowed), tester Journal analysis, web research. **ไม่มีการ decompile.**
**Evidence base:**
- Journal log: `D:\MetaTraderData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\tester\logs\20260710.log` (H1 run เริ่ม 06:38, M15 run เริ่ม 06:39)
- Reports: `_mt4_auto\reports\KANGAROO_XAU_H1_3Y.htm` (PF 4.86 · DD 11.04% · 6,242 trades) / `KANGAROO_XAU_M15_3Y.htm` (PF 2.30 · DD 22.54% · rel DD 30.07% · 15,761 trades)
- ⚠️ ทั้ง 2 report = **Model "Control points (a very crude method…)" + Modelling quality n/a** → เลขทั้งหมดเป็น smoke-grade เท่านั้น (lab gotcha: crude model บิดผล grid/basket EA ได้มาก) — ห้ามใช้เป็น verdict base

**TL;DR (ข้อเท็จจริง ไม่ใช่ verdict):** Gold_Kangaroo = fxDreema-built EA ตระกูลเดียวกับ "Silver Kangaroo EA" ($199, ~2021, แจก/crack เกลื่อนเน็ต → ไม่ exclusive) · bidirectional counter-trend grid บน XAUUSD · ladder ×1.5 มีเพดาน · SL จริงทุกไม้ · exit มี 3 กลไก โดยกลไก "basket TP 160 pips" เป็น **pip-sum แบบไม่ถ่วง lot** — เคยปิดทั้งฝั่งแบบ**ขาดทุนสุทธิจริง -$379** ระหว่าง crash 2024-11-06 (คือ TP ที่แท้ทำหน้าที่เป็น DD-release ด้วย) · สมมุติฐานเดิม 2 ข้อถูกหักล้าง: "cap 10 ไม้/ฝั่ง" (เจอ 14 ไม้ concurrent) และ "equity stop 80% ทำงาน" (ไม่เคย trigger เลยใน 2 run = unverified)

---

## 1. Web findings (URLs + what each source claims)

### Identity / product family
| Source | URL | Claim |
|---|---|---|
| Binary strings | (local extraction) | มี signature `https://fxdreema.com` ท่ามกลาง noise ที่เข้ารหัส + Journal พิมพ์ `fxDreema: Block "10000" goes OFF` → **ประกอบจาก fxDreema no-code builder** — ไม่ใช่ code เขียนมือ, ไม่ exclusive |
| The Forex Geek | https://theforexgeek.com/silver-kangaroo-ea/ | รีวิว "Silver Kangaroo EA": เทรด **XAUUSD เท่านั้น** (แม้ชื่อ silver) · TF แนะนำ M15/M30/H1 · ฝากขั้นต่ำ $1,200 (หรือ cent) · ECN spread ต่ำ · **รายการ parameter ที่ระบุ = ตรงกับ input list ของเรา 100%** (starting lot, multiplier, max martingale lot, stop loss, pip distances, max sells/buys, TP pips, equity-drawdown closure) → Gold_Kangaroo คือตระกูล/ตัวเดียวกับ Silver Kangaroo |
| ForexCracked | https://www.forexcracked.com/forex-ea/silver-kangaroo-free-forex-ea-download/ | เผยแพร่ 2021-11-29 · ราคาเดิม $199 · การตลาดอ้าง "AI entry จาก H1+M30 candle formation" · "เปิดเพิ่ม 3 ไม้ lot เท่ากัน แล้วค่อย multiply" · "**two TP strategies ตามจำนวนไม้**" · "**intelligent overlapping system to reduce DD**" · คอมเมนต์ผู้ใช้บางรายรายงาน backtest fail / demo ขาดทุน |
| fxbotreview | https://fxbotreview.com/item/gold-kangaroo/ | มีหน้า "Gold Kangaroo" โดยตรง (fetch ไม่ได้ — TLS cert หมดอายุ ณ 2026-07-10) |
| YouTube | https://www.youtube.com/watch?v=K4vTozGeqpI | "BEST ROBOT EA XAUUSD (GOLD KANGAROO EA)" — ยืนยันชื่อ Gold Kangaroo ใช้ทำตลาด XAUUSD |
| แจกซ้ำ/crack | https://mq177.com/downloads/silver-kangaroo-forex-ea/ · https://robomql.com/product/silver-kangaroo-forex-ea · https://www.optimizedforexea.com/silver-kangaroo-ea-unlimited-version-download/ · https://forexeahub.com/silver-kangaroo-ea-unlimited-version-download/ | binary ตระกูลนี้ถูกแจก "unlimited version" หลายเว็บ → เกือบแน่ว่า copy ของเรา (มาจากโฟลเดอร์คอลเลกชัน + .rar 2023-04) เป็น redistribution ไม่ใช่ของซื้อ exclusive |
| **คนละตัว — อย่าสับสน** | https://www.myfxbook.com/members/birt/KangarooEA/67781 · myfxbook TulipFX pages | "Kangaroo EA" ของ TulipFX (~2011) เทรด EURUSD/AUDUSD = **ผลิตภัณฑ์คนละตัว** ไม่เกี่ยวกัน |

### Claims ที่ขัดกับหลักฐาน tester ของเรา
1. **"AI entry"** — เป็น marketing ล้วน: binary คือ fxDreema stock blocks (สัญญาณจาก builder signature + block log line)
2. **"entry จาก H1+M30 candle formation คงที่"** — run H1 ได้ 6,242 ไม้ vs run M15 ได้ 15,761 ไม้ ใน window เดียวกัน → พฤติกรรม entry ขึ้นกับ TF ของ chart ที่แปะ EA ไม่ใช่ fixed-TF ตามโฆษณา (อย่างน้อยบางส่วน)
3. **"เปิด 3 ไม้แรก lot เท่ากันเสมอ"** — จริงเฉพาะเริ่มจากฝั่งว่าง; หลัง partial close ladder เดินต่อจาก state เดิม (ดู §3c)

---

## 2. Full input list + defaults (ground truth จาก Journal inputs line — ไม่ใช่การเดา)

Journal พิมพ์เองทุกครั้งที่โหลด (log lines 32, 12532):

| # | Input | Default | ตีความจากพฤติกรรม |
|---|---|---|---|
| 1 | `Starting_Lot` | 0.01 | lot ไม้แรก (และ 4 ไม้แรกของฝั่ง) |
| 2 | `Multiplier_Martingale` | 1.5 | ตัวคูณ ladder: 0.01→0.02→0.03→0.05→0.08→0.12→0.18→0.27→0.41→0.62→0.93 (สังเกตจริงครบทุกขั้น) |
| 3 | `Max_Lot_Martingale` | 1 | เพดาน lot/ไม้ — **ไม่เคยถูกชนใน 2 run** (สูงสุดที่เห็น 0.93) |
| 4 | `Stop_Loss_Pips` | 9000 | SL ต่อไม้ = 9000 points = $90.00 ระยะราคา gold — ยืนยันทุก order row (`sl:` = entry±90.00 เป๊ะ) |
| 5 | `Distance_in_pips_between_the_first_four_trades` | 200 | ระยะห่าง grid 4 ไม้แรก (fixed pips) |
| 6 | `NEW_distance_AFTER_four_first_trades` | 350 | ระยะห่าง grid ตั้งแต่ไม้ 5 (fixed pips) |
| 7 | `Max_Sells` | 10 | ⚠️ ไม่ใช่ hard cap ของ concurrent orders — เห็น 14 ไม้พร้อมกัน (ดู §3c) |
| 8 | `Max_Buys` | 10 | เช่นเดียวกัน |
| 9 | `TP_IN_PIPS_for_ONE_position` | 80 | TP เมื่อฝั่งนั้นมีไม้เดียว |
| 10 | `TP_IN_PIPS_for_more_than_one_position` | 160 | TP เมื่อหลายไม้ — **pip-sum ไม่ถ่วง lot** (ดู §3e — จุดอ่อนสำคัญ) |
| 11 | `Close_all_when_loss_is_greater_than_X_percent_of_equity` | 80 | equity stop — ไม่เคย trigger ใน 2 run = unverified |
| 12 | `MagicStart` | 1111 | live เห็น magic 1112–1115 → EA gen หลาย magic stream จากฐานนี้ (อธิบายไม้เปิดคู่ซ้ำราคาเดียวกัน) |

หมายเหตุ: "pip" ของ EA นี้บน gold 2-digit = 1 point = $0.01/oz (SL 9000 pips = $90 ระยะราคา, spacing 200 pips = $2.00)

---

## 3. Confirmed mechanics (พร้อมหลักฐาน Journal ต่อข้อ)

### a) Entry — market order สองฝั่งอิสระ, กลิ่น counter-trend, สัญญาณเปิดไม้แรกยังไม่รู้แน่
- Market orders เท่านั้น (ไม่มี pending: `modify #` = 0 บรรทัดทั้ง log, ไม่มี delete)
- buy กับ sell เปิดพร้อมกัน/อิสระต่อกันได้ (เช่น 2023.01.03 มี sell basket เช้า, buy basket เย็น)
- ทิศทางเข้าเป็น counter-trend: sell เปิดตอนราคาวิ่งขึ้น (2023.01.06 22:40 sell @1866.45 หลังพุ่งจาก 1839), buy เปิดตอนราคาร่วง (2023.01.03 19:40 buy @1831.87 หลังร่วงจาก 1836) — สอดคล้อง vendor claim "candle formation" แนว fade
- **บางช่วงเปิดเป็นคู่ ราคา/เวลาเดียวกัน** (2023.01.13 09:45 #28/#29 · 15:20 #30/#31 · 2024.10.30 19:06:40 #2670/#2671) → สมมุติฐาน: หลาย magic stream (1112–1115) fire สัญญาณเดียวกันพร้อมกัน — ต้องยืนยันด้วยการอ่าน magic จาก live/report ถ้าจะ implement เลียนแบบ
- สัญญาณเข้าที่แท้จริงถอดจาก log ไม่ได้ (body เข้ารหัส) → ใน spec ของเราต้องเลือก entry เองอยู่แล้ว

### b) Spacing — FIXED pips (200 แรก / 350 หลัง), ไม่ใช่ dynamic/ATR — CONFIRMED
- Grid เพิ่มไม้เฉพาะเมื่อราคาวิ่ง**สวน**ฝั่งนั้น (averaging): sell ladder 1834.74→1837.32→1839.90 (2023.01.03 06:40–06:50); buy ladder 2717.67→2713.26→2711.25→2707.62→2703.13→2696.46 (2024.11.06 15:21–15:58)
- ระยะที่เห็นจริง: ช่วง 4 ไม้แรก ≈ 201–449 points, หลังจากนั้น ≈ 291–670 points — เกิน 200/350 เพราะ Control-points model เห็น tick ห่าง (overshoot) ไม่ใช่เพราะ spacing เป็น dynamic; ค่า min ที่สังเกต (201, ~350) ตรง default เป๊ะ
- ไม่พบหลักฐานการปรับ spacing ตาม volatility ใดๆ ตลอด 3.5 ปี → fixed แน่นอน

### c) Lot ladder ×1.5 + cap — CONFIRMED (กติกา reset ละเอียดยัง UNRESOLVED)
- ขั้น ladder ที่เห็นจริงทั้ง 11 ค่า: 0.01(21,076 ไม้) 0.02(373) 0.03(179) 0.05(108) 0.08(95) 0.12(69) 0.18(44) 0.27(23) 0.41(20) 0.62(10) 0.93(6) — คูณ 1.5 แล้วปัดเข้า 0.01 step ตรงทุกขั้น
- 4 ไม้แรกของฝั่ง = Starting_Lot เสมอ (ตัวอย่าง 2024.11.06 15:21–15:37: 4×0.01 แล้วไม้ 5 = 0.02) — ตรง input name + vendor claim
- ระหว่าง ladder ลึก (crash 2024.11.06): กติกา "ไม้ใหม่ = 1.5 × max lot ที่ยังเปิดอยู่" fit 15/16 จุด — จุดที่ 16: หลัง overlap-close เคลียร์หัว ladder แล้วเหลือไม้เก่า 3 ไม้ (0.18/0.27/0.41) ไม้ใหม่ถัดมา (#2726, 18:18:20) กลับเป็น **0.01** → มี reset เมื่อ open-count ฝั่งนั้นลดต่ำ (≤3 = โซน first-four) — สูตร reset เป๊ะๆ ต้องทำ controlled test ถ้าจำเป็น (per skill: อย่า overfit จาก sample เดียว)
- `Max_Lot_Martingale=1`: ไม่เคยถึง (สูงสุด 0.93; ขั้นถัดไป 1.395 จะโดน clamp เป็น 1.0 แต่ ladder ไม่เคยลึกพอ)
- **`Max_Buys/Max_Sells=10` ไม่ใช่ hard cap concurrent:** นับจาก log ได้ **max 14 ไม้ buy พร้อมกัน (M15 2026.05.28 07:59:10) และ 14 ไม้ sell (M15 2026.05.06 15:07:30)** → คำว่า "10" น่าจะนับ per-magic-stream หรือ per-cycle ไม่ใช่รวมทั้งฝั่ง — สมมุติฐานเดิม "10 ไม้/ฝั่ง" จาก smoke วันนี้ **หักล้างแล้ว** ต้องคิด max exposure จาก 14+ ไม้
- Max exposure เชิงทฤษฎีต่อฝั่ง (ถ้า ladder เต็ม 0.01…0.93+1.0×k): มากกว่าที่เคยประเมินด้วย 10 ไม้ — ต้องคำนวณใหม่ตอนทำ risk sizing

### d) Exit แบบที่ 1 — single-position TP ≥80 pips — CONFIRMED
- ไม้เดี่ยวปิดกำไร ≥80 points เสมอ; ที่เห็นจริง 99–350 points (#17: 2023.01.06 10:20→10:27 +99 · #9: +153 · #14: +350 ใน 2.5 นาทีช่วงตลาดวิ่ง) — overshoot จาก Control-points granularity ไม่ใช่ trailing

### e) Exit แบบที่ 2 — multi-position "TP 160" = **unweighted pip-sum ทั้งฝั่ง ≥160** → อ้างอิง breakeven-average แต่**ไม่ถ่วง lot** — CONFIRMED + จุดอ่อนสำคัญ
- นิยามที่ fit ทุกตัวอย่าง lot เท่ากัน: ปิดทั้งฝั่งเมื่อ Σ(pips ต่อไม้) ≥ 160 ⇔ ราคาแตะ avg-entry ± 160/N pips (อ้างอิงจุด breakeven ของ basket, offset หดลงเมื่อ N โต)
  - หลักฐาน: basket #1–3 ปิดพร้อมกัน 2023.01.03 06:57:30 @1836.65 → pip-sum = −191+67+325 = **+201 ≥160** ✓ · basket #4–6 @1838.18 → **+261** ✓ · basket 8 ไม้ 2023.01.13 17:50 → **+544** ✓
- **จุดอ่อนที่จับได้ (decision-relevant):** pip-sum ไม่ถ่วง lot → เมื่อ ladder ลึก (ไม้ท้าย lot ใหญ่) การปิด "เข้าเป้า pips" อาจ**ขาดทุนเงินจริงสุทธิ**:
  - **2024.11.06 19:23:20** ปิด buy ทั้ง 6 ไม้ @2668.38: #2726 0.01@2665.03(+$3.35) #2727 0.02@2659.80(+$17.16) #2728 0.03@2655.56(+$38.46) #2721 0.41@2668.73(−$14.35) #2720 0.27@2675.94(−$204.12) #2719 0.18@2680.56(−$219.24) = **net ≈ −$379** ทั้งที่ pip-sum = +466 ≥160
  - การอ่านอีกแบบ: อาจเป็น overlap-close 3 คู่ (ใหม่สุดจับคู่เก่าสุด: +64/+102/+300 pips ต่อคู่) ใน tick เดียว — ไม่ว่าอ่านแบบไหน **ผลจริงคือ EA ยอม realize ขาดทุนสุทธิเพื่อ flatten ladder ลึก** = กลไก DD-release โดยพฤตินัย (นี่อาจเป็นเหตุผลจริงที่มันรอด crash — ไม่ใช่ "TP โดนตลอด" ตามหน้า report)

### f) Exit แบบที่ 3 — "overlapping" recovery: จับคู่ไม้ใหม่สุด(lot ใหญ่)+ไม้เก่าสุด(ติดลบลึก) ปิดพร้อมกันเมื่อรวมแล้วบวกเงิน — CONFIRMED (= vendor claim "intelligent overlapping system")
- หลักฐานช่วง crash 2024.11.06 (M15 run): 16:02:30 ปิดคู่ #2710(0.03, +$22.71)+#2705(0.01, −$13.64) net +$9.07 · 16:36:40 #2712+#2706 net +$7.31 · 17:04:24 #2715+#2707 net +$15.20 · 17:10:25 #2716+#2708 · 17:33:45 #2722+#2711 · 17:53:20 #2723+#2713 · 18:07:45 #2725+#2714 · 18:12:30 #2724+#2717 — pattern เดียวกันทุกคู่: newest กำไรหักล้าง oldest ขาดทุน
- ผลเชิงโครงสร้าง: ladder ถูก "กัดหัว-กัดหาง" ระหว่างทาง → exposure ไม่โตทางเดียว, DD บน report ต่ำกว่า grid ธรรมดา — threshold เงินต่อคู่เป๊ะๆ UNRESOLVED (overshoot จาก model บดบัง)

### g) Per-order SL $90 — CONFIRMED มีจริงและยิงจริง (แต่นานๆ ครั้ง)
- ทุก order row มี `sl:` = entry±90.00 ไม่มีข้อยกเว้น (22,003 opens)
- SL hit จริง 8 ครั้ง ทั้งหมดใน M15 run, H1 run = 0: `Tester: stop loss #343/#344` (2023.04.13 18:00:25) · `#13063` (2026.04.02) · `#13448` (2026.04.13) · `#13714/#13715` (2026.04.20) · `#14170/#14175` (2026.05.06)
- ข้อสังเกต scaling: SL fixed $90 ตอน gold 1800 = ~5% ของราคา แต่ตอน gold 4500+ (2026) = ~2% → SL แน่นขึ้นเองตามราคาที่สูงขึ้น (hit กระจุกใน 2026) — อีกเหตุผลที่ rebuild ควรใช้ ATR
- **แก้ hypothesis เดิม:** "SL ~$90 ต่อไม้" ยืนยัน แต่ความหมายคือ $90 ระยะราคา/oz — มูลค่าเงินต่อไม้ขึ้นกับ lot (0.01 lot = $90 loss, 0.93 lot = $8,370 loss ถ้าโดนเต็ม)

### h) Equity stop 80% — **UNVERIFIED** (ไม่เคย trigger)
- ไม่มีเหตุการณ์ปิดทุกไม้สองฝั่งพร้อมกันขาดทุนใหญ่ในทั้ง 2 run (max DD 22.5%) → พิสูจน์ไม่ได้ว่า implement ถูก/ทำงานจริง — สมมุติฐาน "มี 80% equity close-all" มาจากชื่อ input เท่านั้น ห้ามนับเป็น safety ที่ validate แล้ว

### i) สรุป report (บริบท ไม่ใช่ verdict)
- H1: PF 4.86 · net +$17,719/10k · maxDD 11.04% (rel 11.84%) · 6,242 trades · short win 85.5%
- M15: PF 2.30 · net +$28,973/10k · maxDD 22.54% (**rel 30.07%**) · 15,761 trades — ไม้ถี่ขึ้นแต่คุณภาพลด, ladder ลึกกว่า (0.93 โผล่เฉพาะ M15 run)
- ทั้งคู่ Control points + spread 19 fix → ก่อนตัดสินใดๆ ต้องรัน Model 0/every-tick ตาม lab rule (งานหน้า ไม่ใช่ของ order นี้)

---

## 4. Draft spec card — "KangarooInspired" (Boss V2 chassis module)

หลักการแปลง (ตาม order + บทเรียน locked-ea-analyzer): เก็บโครงที่ทำให้ survivor รอด = capped-ladder ×1.5 + first-N-equal + per-order SL + overlap recovery + equity stop · **เปลี่ยนอย่างเดียวที่ order สั่ง: fixed-pips spacing → ATR-mult** (มาตรฐานแม่พิมพ์) · จุดที่เป็น "จุดอ่อนที่อาจเป็นจุดแข็ง" (pip-sum TP ที่ยอมปิดติดลบ = DD-release) — เก็บพฤติกรรม "ยอม flatten ladder ลึกแบบขาดทุนควบคุม" ไว้เป็น explicit module แทนที่จะเป็น bug, แต่ทำเป็น **dollar-based** ให้วัดได้ (บทเรียน RSI-from-pips: เปลี่ยนทีละอย่าง — spacing คือ change #1, TP-accounting คือ change #2 ที่ต้อง A/B แยก)

```yaml
spec_card_version: "3.0"
chain_id: "EA_KANGAROOINSPIRED_20260710_01"
identity:
  ea_name: "(Boss)_KangarooInspired_CappedGrid_rev00"   # draft — ยังไม่ approve
  symbol: "XAUUSD"
  timeframe: "H1"            # H1 โปรไฟล์ดีสุดจาก smoke (PF 4.86 vs M15 2.30)

strategy:
  trade_style: "INTRADAY"
  entry:
    indicator: "TBD — original ถอดไม่ได้ (encrypted); เลือกจากคลัง Boss V2 แนว counter-trend/fade"
    condition: "counter-trend market entry; buy หลัง down-move / sell หลัง up-move; สองฝั่งอิสระ (แยก instance ต่อฝั่ง)"
  distance:
    mode: "ATR"              # << จุดเปลี่ยนเดียวจาก original (fixed 200/350 pips)
    min_dist_pips: 150       # floor กันช่วง ATR ต่ำผิดปกติ
    atr_mult_first4: 0.8     # แทน 200 pips (≈0.8×ATR(14,H1) เฉลี่ยยุค gold 1800-2000)
    atr_mult_after4: 1.4     # แทน 350 pips — คงสัดส่วน 200:350 ≈ 1:1.75
  lot_sizing:
    mode: "MARTINGALE"       # capped — ตาม original
    base_lot: 0.01
    multiplier: 1.5
    first_n_equal: 4         # 4 ไม้แรก = base_lot (ยืนยันจาก journal)
    max_lot_per_order: 1.0   # = Max_Lot_Martingale
  take_profit:
    mode: "FIXED"
    scope: "SINGLE + NET_ALL"      # สองกลไกตาม original
    tp_single_pips: 80             # ไม้เดี่ยว
    basket_tp_mode: "DOLLAR"       # << fix จุดอ่อน pip-sum: ใช้ net-$ ของ basket ไม่ใช่ pip-sum ไม่ถ่วง lot
    basket_tp_usd_per_01lot: 16    # เทียบเท่า 160 pips × 0.01 lot; scale ตาม total lot
  stop_loss:
    mode: "ATR"                    # original = fixed 9000 pips ($90) — ไม่ scale ตามราคา (SL hit กระจุกปี 2026)
    max_sl_pips: 9000              # hard ceiling เท่า original
    atr_mult_sl: 18.0              # ≈ $90 ที่ ATR ยุค 1800-2000; ต้อง sweep

recovery:
  overlap_close:                   # = "intelligent overlapping system" ที่ยืนยันแล้ว
    enabled: true
    rule: "pair NEWEST open order with OLDEST open order; close both when combined net-$ >= overlap_min_usd"
    overlap_min_usd: 5             # observed +$7..$15 ต่อคู่; ต้อง sweep
  ladder_flatten:                  # de-facto DD-release ที่จับได้ 2024-11-06 (−$379 close-all)
    enabled: true
    rule: "เมื่อ ladder ลึก >= 6 ไม้ อนุญาต close-all ฝั่งนั้นที่ net-$ >= -X (ขาดทุนควบคุม) เพื่อ flatten"
    max_controlled_loss_usd: 400   # อิงเหตุการณ์จริง; ต้อง sweep + A/B เทียบไม่มี module นี้
  hedging:
    enabled: false                 # bidirectional ของ original = 2 instance อิสระ ไม่ใช่ recovery-hedge
                                   # (กัน L5: Grid+Martingale+Hedge = REFUSE ตาม strategy-and-risk)

risk:
  risk_level: "L4"                 # Grid+capped-Martingale — ต้องให้ user ยอมรับเป็นลายลักษณ์อักษรก่อน implement
  risk_per_trade_pct: 1.0
  max_drawdown_target_percent: 20.0
  max_positions: 10                # ต่อฝั่ง/ต่อ instance — บังคับเป็น HARD cap จริง (original โฆษณา 10 แต่เจอ 14)
  max_total_lot: 3.4               # Σ ladder เต็ม 0.01..0.93+1.0 ≈ 3.72 → ตัดที่ 10 ไม้ = 2.79; ตั้ง 3.4 เผื่อสองฝั่ง — ต้องคำนวณละเอียดตอน sizing
  daily_loss_limit_pct: 5.0
  emergency_exit_dd_pct: 70.0      # แน่นกว่า original 80% (ซึ่ง unverified อยู่ดี)
```

**ประเด็นเปิดก่อน implement (สำหรับ user + Claude lead ตัดสิน — ไม่ใช่ verdict ของ agent):**
1. Entry signal ต้องออกแบบใหม่ทั้งก้อน (ถอดของเดิมไม่ได้) → ผ่าน `strategy-and-risk` เต็มรูป + flat-lot test (ปิด multiplier แล้ว PF ต้อง >1 ถึงจะเชื่อว่ามี entry edge ไม่ใช่ recovery mechanics — ยังไม่เคยทำกับ Kangaroo เอง เพราะ locked ปรับ multiplier ไม่ได้… จริงๆ **ปรับได้**: `Multiplier_Martingale=1` เป็น input! → แนะนำรัน flat-lot test กับตัว original ก่อนลงแรง build)
2. bidirectional = 2 instance (buy-only/sell-only) หรือ EA เดียวสองฝั่ง — กระทบ magic scheme ของ Boss V2
3. `ladder_flatten` module เก็บหรือไม่เก็บ — A/B แยกต่างหาก (นี่คือกลไกที่อาจเป็นเหตุผลรอด crash)
4. Overlap pair-close threshold เป๊ะๆ ของ original ยัง unresolved — ถ้าอยากได้ต้องรัน controlled test (every-tick, ladder บังคับ) แต่สำหรับ rebuild ค่า sweep เองได้
5. สมมุติฐาน multi-magic (1112–1115) ยังไม่ยืนยัน — อ่านจาก live report ก่อน fix แม่พิมพ์

**สถานะ:** notes ครบ 4 หัวข้อตาม ORDER-070 · ไม่มี .mq5 · ไม่มี decompile · ไม่มี verdict
