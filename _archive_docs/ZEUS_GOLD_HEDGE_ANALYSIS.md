# Zeus Gold Hedge V1.2 — Behavioral Analysis

> อัพเดท: 2026-07-03 | สถานะ: **Phase 1-3 เสร็จ (environment/principle/web-research)** — Phase 4+ (smoke
> screen ทุก symbol, optimize, deep validate) ยังไม่เริ่ม เพราะต้องปิด MT4 GUI ที่กำลังรัน Zeus live อยู่จริง
> → **รอ user ยืนยันก่อนปิด terminal** ดู `PROJECT_STATE.md` §7 / plan
> `C:\Users\patip\.claude\plans\ea-zeus-velvety-graham.md` สำหรับ phase ที่เหลือ

---

## 0. ขอบเขต — ทำอะไร ไม่ทำอะไร

`.ex4` ตัวนี้ถูก **encrypt/obfuscate จริง** (ดึง string ASCII/UTF-16 ออกมาดูแล้วเจอ noise เอนโทรปีสูงล้วน
ไม่มี input name หรือ string literal โผล่เลย — ต่างจาก `.ex4` ทั่วไปที่ยังอ่าน string บางส่วนได้)
→ **decompile ไม่ได้ทั้งทางเทคนิคและสัญญาอนุญาต งานนี้ไม่แตะ/ไม่พยายามปลดล็อคไฟล์เลย**

วิเคราะห์ทั้งหมดด้านล่างมาจาก**พฤติกรรมที่สังเกตได้จริง**เท่านั้น: input parameter จาก preset/tester config
(plaintext, MT4 บันทึกแยกจากตัว EA เสมอ), Journal log ตอนรัน Strategy Tester (behavior จริงที่ EA แสดงออกมา),
และข้อมูลสาธารณะจากเว็บ — เท่ากับสิทธิ์ที่เจ้าของไฟล์ทุกคนเข้าถึงได้ผ่าน MT4 GUI ปกติอยู่แล้ว ไม่ใช่ reverse
engineer ตัว logic

## 1. ที่มาไฟล์ (จาก web research)

**⚠️ พบว่าไฟล์นี้หมุนเวียนอยู่บนเว็บ "EA ฟรี/ปลดล็อค" หลายเว็บ** (eafxstore.com, forexcrackedvip.com,
mql5cracked.com, unlockea.com, indicatorspot.com, mql5bot.com — ชื่อไฟล์ตรงกับที่ user มี
`Zeus Gold Hedge V1.2_fix_1420` = "for build 1420+" ตรงกับที่เว็บพวกนี้ระบุ) **ไม่ได้ขายอยู่บน MQL5
Marketplace อย่างเป็นทางการ** — บล็อกของผู้เขียนต้นฉบับบน mql5.com
([post 740351](https://www.mql5.com/en/blogs/post/740351)) เองก็ระบุว่าที่มาไฟล์คือ **Telegram channel**
ไม่ใช่ MQL5 store

**นัยสำคัญ:** ไฟล์แบบนี้ผ่านมือคนกลาง (crack/unlock) มาหลายทอด — ความเสี่ยงที่ควรรู้ไว้ (ไม่ใช่ประเด็น
กฎหมายอย่างเดียว): (1) ไม่มี vendor support/update อย่างเป็นทางการ (2) ไฟล์ผ่าน "protector" ที่ไม่รู้ที่มา
เพิ่มความเสี่ยงเรื่อง integrity ของไฟล์ที่รันบนบัญชีจริง (แม้ยังไม่มีหลักฐานว่ามีพฤติกรรมผิดปกติ)
→ เป็นเหตุผลหนึ่งที่สนับสนุนแผน Phase 9 (สร้าง EA ใหม่จากศูนย์ inspired by หลักการนี้แทนการพึ่งไฟล์นี้ต่อระยะยาว)

**Track record ที่ vendor อ้าง** (จาก eafxstore.com, ยังไม่ verify อิสระ): Myfxbook live 2024
+193.09% / DD 36.45%; backtest 2023 capital $2,000 → $4,400 (risk 35%). Recommended: XAUUSD +
major pairs, **H1**, min deposit $1,000. ตัวเลข DD 36% สอดคล้องกับที่คาดจากโครงสร้าง grid/martingale
แบบมี cap (ดู §3) — "กำไรสูงคู่ DD สูง" ไม่ใช่ free lunch

## 2. Input parameters จริง (ground truth)

จาก `MQL4\Presets\Zeus EU H1.set` (preset เดียวที่มีในเครื่อง — สำหรับ **EURUSD**, ไม่มี preset ทองแยก)
และ `tester\Zeus Gold Hedge V1.2_fix_1420.ini` (มี optimize range จากการตั้งค่าก่อนหน้า):

| Parameter | ค่า default (Zeus EU H1.set) | Optimize range เดิม (tester ini) | ความหมาย (จากพฤติกรรม) |
|---|---|---|---|
| `Magic` | 7777 | fixed | magic number |
| `lot` | 0.04 | 0.01–0.06 | lot ไม้แรกของแต่ละฝั่ง |
| `K_Lot` | 1.40 | 0.10–1.50 | ตัวคูณ lot escalation |
| `PlusLot` | 0.06 | 0.01–0.06 | ตัวบวก lot escalation |
| `DigitsLot` | 2 | fixed | ความละเอียดปัดเศษ lot (0.01) — **มาตรฐานทั่วไป ไม่ใช่สัญญาณเฉพาะทอง** |
| `FirstStep` | 30 | fixed | ระยะ pending order คู่แรก (pips) จากราคาเปิด |
| `MinDistance` / `TwoMinDistance` | 60 / 120 | 10–90 / 10–90 | ระยะขั้นต่ำ tier 1/tier 2 |
| `Step` / `TwoStep` | 30 / 90 | 10–120 / 10–120 | ระยะห่าง grid order tier 1/tier 2 |
| `StepTrallOrders` | 30 | fixed | trailing step |
| `StopProfit` | 30 | 10–50 | เป้ากำไร (pips) ปิดทั้ง basket |
| `CloseAll` | 10 | fixed | เป้ากำไร ($) ปิดทั้ง basket |
| `MaxLoss` | 100,000 | fixed | cap ขาดทุนรวม ($) — **ใหญ่มากเทียบ lot ไมโคร แทบเท่าไม่มี cap** ⚠️ |
| `MaxLossCloseAll` | 100 | fixed | cap ขาดทุน ($) ต่อ basket |
| `Maxlot` | 100 | fixed | lot สูงสุดต่อไม้ — ใหญ่มากเช่นกัน ⚠️ |
| `Totals` | 2000 | fixed | cap รวม (order count หรือ lot รวม ×100) |
| `MaxSpread` | 100 | fixed | spread สูงสุดที่ยอมเทรด |
| `NextTime` | 30 | fixed | cooldown ระหว่างไม้ (นาที?) |
| `Leverage` | 100 | fixed | leverage สมมติสำหรับคำนวณ lot |
| `EA_StartTime`/`EA_StopTime` | 00:00–24:00 | — | ช่วงเวลาเทรด |

**ไม่มี MiniGrid1/2, SmartGrid1/2 หรือ enum/dropdown ใดๆ** — เป็น flat parameter list ทั้งหมด

## 3. หลักการทำงาน (สังเกตจาก Journal log จริง วันที่ 2026-07-02, AUDUSD/EURUSD H1)

ตรงกับที่ user อธิบาย: **"Grid + Anti-grid เพื่อ hedge กัน"** — และจาก log ยืนยันว่าไม่ใช่แค่ "basket เดียว
ที่สลับทิศ" แต่เป็น **grid engine 2 ตัวที่ทำงานอิสระพร้อมกันจริง** (ฝั่ง buy กับฝั่ง sell แยกกันเปิด/ปิด basket
ของตัวเองคนละเวลา บางช่วงมี basket buy วิ่งอยู่พร้อมกับ basket sell คนละ generation)

**ลำดับการทำงาน:**
1. **เปิดคู่ pending stop straddle** — `buy stop` + `sell stop` วางคู่กันห่างราคาปัจจุบัน `FirstStep`/
   `MinDistance` pips (ตัวอย่างจริง: #1 buy stop 0.01 @0.66767, #2 sell stop 0.01 @0.66694 — วางพร้อมกัน
   เวลาเดียวกันเป๊ะ)
2. **ฝั่งไหนถูกกระตุ้นก่อน เริ่ม grid ฝั่งนั้น** — เมื่อราคาวิ่งชนไม้แรก ระบบวางไม้ถัดไปในทิศเดียวกันห่างออกไป
   `Step` pips (แล้วสลับเป็น `TwoStep` เมื่อ basket โตขึ้น เช่นเดียวกับ `MinDistance`→`TwoMinDistance`)
   ขนาด lot ไล่ขึ้นแบบผสม multiplier+additive — สังเกตจริงได้ลำดับ `0.01 → 0.03 → 0.06 → 0.08 → 0.10 →
   0.13 → 0.16 → 0.19 ...` (ไม่ใช่ geometric หรือ arithmetic บริสุทธิ์ ผสมทั้ง `K_Lot`×และ`PlusLot`+
   แล้วปัดเศษ 2 ตำแหน่ง — **สูตรที่แน่นอนต้องให้ Phase 5 optimizer fit เชิงตัวเลข ไม่ได้ reverse-fit มือ 100%**)
3. **ฝั่งตรงข้ามที่ยังไม่ trigger ยังคงอยู่ (นี่คือ "Hedge")** — ถ้าราคากลับตัวแรงพอ pending order อีกฝั่ง
   ก็ trigger เองเป็น basket ที่สอง วิ่งคู่ขนานกับ basket แรก (ยืนยันจาก log เห็น order buy และ sell
   generation ต่างกันเปิดพร้อมกันได้จริงในช่วงเวลาไล่เลี่ยกัน)
4. **ปิดทั้ง basket (ฝั่งนั้นๆ) พร้อมกันเป็นชุด** เมื่อ floating profit ถึง `CloseAll` ($) หรือ `StopProfit`
   (pips) — ยืนยันจาก log: order หลายใบปิดที่ **timestamp และราคาเดียวกันเป๊ะ** เช่น
   `close #16/#15/#14/#11` ปิดพร้อมกันที่ `2026.01.05 11:07:30 @0.66823` ทั้งหมด แล้วฝั่งนั้น reset
   กลับไปวาง pending pair ใหม่ที่ 0.01 อีกครั้ง
5. **Risk cap:** `MaxLoss`(100,000)/`Maxlot`(100)/`Totals`(2000) เป็น safety net แต่ตัวเลข default
   **ใหญ่มากเทียบ lot ไมโคร 0.01-0.06** — แทบไม่มีผลจำกัดจริงที่ scale นี้ ต้องเช็คให้ชัดใน Phase 5 ว่า
   "capped grid" นี้ cap จริงหรือ cap เชิงนาม (ถ้าใหญ่จนไม่มีความหมาย = โครงสร้างเดียวกับ **uncapped
   martingale** ที่เป็น hard-gate DISQUALIFIED ใน skill `backtest-optimize-rigor` — ต้องแก้ก่อนไว้ใจ)

## 4. เทียบกับ EA ตระกูลเดียวกันในพูลนี้

โครงสร้าง "capped grid + breakout straddle + basket close" นี้**เป็นตระกูลเดียวกับ EA ที่เคย screen/
deep-validate แล้ว REJECT ไปแล้วในพูลนี้** — Golden Elephant/Mammoth, KRAPOOK BLUE ANT,
EURUSD Trading Forex Robot (ดู `_archive_docs/MT4_SCREENING_PLAN.md`) — ทุกตัวดูดีในหน้าต่างสั้น (screen
window 1 ปี) แต่ IS period (18 เดือนก่อนหน้าที่ไม่เคยดู) เจอ DD ระเบิด (12-100%) เพราะไม้ grid ไปเจอ trend
ยาวที่ไม่มีจังหวะย่อกลับพอปิด basket ทัน **ไม่ได้แปลว่า Zeus จะพังแบบเดียวกันแน่นอน — แต่เป็นความเสี่ยง
เชิงโครงสร้างที่ต้องพิสูจน์ผ่าน IS/OOS จริงใน Phase 5-6 ไม่ใช่เชื่อผลสั้นๆ ที่เห็นตอนนี้เฉยๆ**

## 5. ข้อควรระวังสำคัญ: ผล EU ดี ≠ ผล XAU จะดี

ทั้งชื่อ EA และ vendor description ชี้ไปทาง gold เป็นหลัก แต่ **preset ที่มีอยู่จริงในเครื่องมีแค่ "Zeus EU
H1.set" (EURUSD) และ user เองยืนยันว่าผลดีจริงมาจากการรัน EU ไม่ใช่ XAU** — พารามิเตอร์ spacing/lot ที่ดี
สำหรับ EURUSD (pip size, volatility profile ต่างจากทองมาก) **ไม่มีเหตุผลให้ยกไปใช้กับทองแล้วดีเหมือนกัน**
Phase 5 ต้อง optimize แยกอิสระต่อ symbol เสมอ

## 5.5 ผล Smoke Screen จริง ทุก symbol (Phase 4, compiled default params, window 2025.01.01–2026.07.02 H1)

| symbol | trades | PF | net | maxDD% | win% | screen |
|---|---|---|---|---|---|---|
| EURCHF | 150 | 2.04 | +570.54 | 4.68 | 63.33 | **PASS** |
| CHFJPY | 624 | 1.99 | +2115.25 | 3.75 | 69.07 | **PASS** |
| EURGBP | 165 | 1.95 | +626.81 | 5.14 | 69.70 | **PASS** |
| WTI | 932 | 1.84 | +5043.71 | 44.67 | 72.21 | PASS ⚠️ (DD สูง) |
| EURUSD | 2058 | 1.54 | +10335.86 | 51.93 | 70.36 | PASS ⚠️ GRID risk (trades>2000 & DD>30%) |
| XAUUSD | 814 | 0.80 | -10419.24 | 101.76 | 70.39 | REJECT |
| AUDUSD | 1130 | 0.68 | -14114.21 | 126.63 | 69.65 | REJECT |
| GBPUSD | 492 | 0.65 | -10159.18 | 101.16 | 67.28 | REJECT |
| USDJPY | 497 | 0.63 | -8570.75 | 87.94 | 67.61 | REJECT |
| AUDCAD | 1151 | 0.59 | -9418.43 | 95.73 | 69.33 | REJECT |
| SPX500 | 601 | 0.59 | -7614.97 | 83.39 | 71.05 | REJECT |
| XAUUSDMINI | 305 | 0.42 | -17165.90 | 163.29 | 68.52 | REJECT |
| USDCAD | 106 | 0.32 | -8219.29 | 82.61 | 54.72 | REJECT |
| BNBUSD/BTCUSD/DOGEUSD/ETHUSD/NAS100/SOLUSD/USDCHF | — | — | — | — | — | NO_DATA (ไม่มี history ในเครื่องนี้) |

**Pattern ชัดเจน:** PASS ทั้งหมดเป็น **low-volatility cross pairs** (EURCHF, CHFJPY, EURGBP) + EURUSD
(คู่หลักสภาพคล่องสูงสุด) — REJECT ทั้งหมดเป็นคู่/สินทรัพย์ผันผวนสูง/เทรนด์แรง (ทอง, AUD/GBP/USD crosses,
ดัชนี) สอดคล้องกับกลไก grid ที่พึ่งราคาสวิงกลับมาปิด basket — ใช้ได้ดีในตลาด range แคบ พังในตลาดเทรนด์แรง

## 5.6 ⚠️ ทดสอบเพิ่มบน XAUUSD — ขยาย spacing 10x ก็ยังบัญชีระเบิด (ข้อมูลใหม่ สำคัญ)

ลองรัน XAUUSD ด้วย spacing กว้างขึ้น 10 เท่า (`Step 30→300, TwoStep 60→600, MinDistance 30→150,
TwoMinDistance 60→300, FirstStep 30→150`) เพื่อทดสอบสมมติฐาน "grid แน่นไปสำหรับความผันผวนทอง" —
**ผลแทบไม่ต่างจาก default เลย**: PF 0.76 (จาก 0.80), maxDD **101.82%** (จาก 101.76%), net -$10,338
(จาก -$10,419) — บัญชีระเบิดเหมือนเดิมไม่ว่าจะปรับ spacing แค่ไหน

**สรุป:** ปัญหาของ XAUUSD **ไม่ใช่แค่ spacing ตั้งผิด** (ถ้าใช่ ขยาย 10x ต้องดีขึ้นชัดเจน) แต่น่าจะเป็นเชิง
โครงสร้าง: **`StopLoss=0` — ไม่มี stop loss ต่อไม้เลยสักไม้เดียว**, ความหวังเดียวคือรอราคาสวิงกลับมาปิด basket
ที่ `CloseAll`/`MaxLossCloseAll` ($10/$100) ซึ่งบนทองที่เทรนด์แรงต่อเนื่องได้หลายวัน/สัปดาห์ — basket reset
ซ้ำแล้วขาดทุนซ้ำเรื่อยๆ (win% ยังสูง 70%+ แต่ net ติดลบหนัก = ตายทีละนิดสะสม ไม่ใช่ระเบิดทีเดียว)
**นี่คือ pattern เดียวกับ "hard-gate DISQUALIFIED" ("uncapped martingale/grid/no SL") ในเกณฑ์
`backtest-optimize-rigor` ของโปรเจกต์เอง** — ไม่ใช่แค่พารามิเตอร์ยังไม่ถูก tune แต่อาจเป็นข้อจำกัดเชิง
กลไกที่ tune ยังไงก็ไม่หาย ต้องพิสูจน์เพิ่มด้วยการ optimize ค้นหาจริงใน Phase 5 ก่อนสรุปขาด (ยังไม่ปิดเคส)
แต่ **ความคาดหวังสำหรับ XAU ควรต่ำลงมาก** เทียบกับตอนเริ่มงาน

## 5.7 ⚠️⚠️ ทดสอบด้วยค่า live จริงของ user (TP=30, lot=0.06, K_Lot=1.4, CloseAll=20, PlusLot=0.08,
MaxSpread=25, mini grid1/2=60/120, smart grid1/2=30/90) — พบข้อขัดแย้งกับประสบการณ์ live สำคัญ

User ยืนยันว่า "mini grid 1/2" = `MinDistance`/`TwoMinDistance`, "smart grid 1/2" = `Step`/`TwoStep`
(ไม่ใช่พารามิเตอร์แยก — เป็นชื่อเรียกของ user เอง) และรัน config นี้ live มา **3 เดือนแล้ว รอดหมด**

**Backtest ค่านี้เป๊ะๆ บน EURUSD H1 2025.01-2026.07 (18 เดือน):**
| Model | PF | net | maxDD% | trades | screen |
|---|---|---|---|---|---|
| Model 2 (open prices, เร็วแต่หยาบ) | 0.65 | -$10,373 | **102.36%** (stop out จริง) | 385 | REJECT |
| **Model 0 (every tick, แม่นสุด, quality 90%)** | **0.87** | **-$5,935** | **79.08%** | 1819 | REJECT |

**Model 2 overstate ความรุนแรงจริง** (ตรงกับที่เอกสาร `backtest-optimize-rigor` เตือนไว้เรื่อง "Model-2
tight-TP artifact") — ด้วย Model 0 ที่แม่นกว่า บัญชี**ไม่ระเบิดเต็มขั้น**เหมือน Model 2 ทำนาย
แต่ก็**ยังขาดทุนสุทธิและ DD สูงถึง 79%** ไม่ใช่ค่าที่ "ปลอดภัย" ตามที่ประสบการณ์ live 3 เดือนอาจให้ความรู้สึก

**เช็คจาก Journal log: จุด stop-out (Model 2) เกิดที่ simulated date `2025.03.05`** — คือช่วงต้นของ
หน้าต่าง 18 เดือน (Jan 2025) **ไม่ใช่ช่วงที่ user รัน live จริง (3 เดือนล่าสุดก่อน 2026-07-03 คือประมาณ
เม.ย.-ก.ค. 2026)** — คำอธิบายที่เข้าเรื่องที่สุด: **ช่วง regime ที่ backtest จับได้ว่าแรง (ต้นปี 2025)
เป็นช่วงที่ user ยังไม่ได้เริ่มรัน live** ไม่ใช่ว่า backtest ผิด — แปลว่า **การรอดมา 3 เดือนไม่ได้แปลว่า
config นี้ปลอดภัยสำหรับ regime ที่เลวร้ายกว่าที่ยังไม่เจอ** ควรระวังไปข้างหน้า ไม่ใช่ประเมินจากอดีตอันสั้นเพียงพอ

**ข้อสรุปสำหรับ EU:** parameter set ที่ user ใช้ live จริง **ไม่ผ่านเกณฑ์ screen (PF<1.0) และมี DD สูงเสี่ยง
มาก (79%) แม้วัดด้วย model แม่นสุด** บน window 18 เดือนนี้ — ควรพิจารณาลด risk (ดู Phase 9 spec:
real stop-loss, partial close, DD cap ต่ำกว่านี้มาก) มากกว่าจะไว้ใจ 3 เดือนที่ผ่านมาว่าเพียงพอจะสรุปว่าปลอดภัย

**⚠️ เจอ tooling gotcha เพิ่ม (สำคัญสำหรับ Phase 10 skill):** ลองรัน "compiled default" (ไม่ส่ง
`-SetFile` ให้ `mt4_run.ps1`) ซ้ำอีกครั้งด้วย Model=0 เพื่อ verify ผล PF 1.54 เดิม — **ได้ผลลัพธ์เหมือนกับ
ค่า live-actual เป๊ะทุกตัวเลข (net -5935.48, DD 79.08%)** ทั้งที่พารามิเตอร์ควรต่างกัน (lot 0.01 vs 0.06) —
แปลว่า **MT4 จำค่า parameter ล่าสุดที่เคยรันค้างไว้ในเครื่อง (state carryover) เมื่อไม่ส่ง `-SetFile` ไป**
ไม่ได้รีเซ็ตกลับไปที่ compiled default จริงเสมอไป → **ผล PF 1.54 ที่เจอตอนแรกของ session (ก่อนรัน .set
ไฟล์ใดๆ) ไม่แน่ใจแหล่งที่มาแท้จริงอีกต่อไป** — บทเรียน: **ห้ามพึ่ง "ไม่ส่ง -SetFile" เพื่อหมายถึง default
เด็ดขาด ต้องส่ง .set ที่ระบุค่าครบทุกตัวเสมอ** เพื่อผลที่ reproduce ได้แน่นอน (บันทึกไว้ใน skill
`locked-ea-analyzer` Phase 10)

**สรุปรวม EU:** จากทุก config ที่ทดสอบด้วยพารามิเตอร์ที่ระบุชัดเจนครบและวัดด้วย Model 0 (แม่นสุด) —
**ยังไม่พบ config ไหนผ่านเกณฑ์ (PF≥1.0) เลยสักตัวบน window 18 เดือนนี้** ทั้ง default ดั้งเดิมและค่า live จริง
ของ user — สอดคล้องกับข้อสรุปเดียวกับ XAU: กลไก Zeus ดั้งเดิม (ไม่มี stop loss ต่อไม้ + พึ่ง basket-recovery
ล้วน) มีความเสี่ยงเชิงโครงสร้างที่ parameter tuning เพียงอย่างเดียวแก้ไม่ได้ง่ายๆ — เหตุผลสนับสนุน Phase 9
(ออกแบบใหม่ที่มี stop loss จริง) หนักแน่นขึ้นไปอีก

## 5.8 (2026-07-03) แก้ methodology ตาม user feedback + retest XAU เต็ม ladder

User feedback 3 ข้อ (สำคัญ นำไปแก้ shared rubric ด้วย ไม่ใช่แค่ไฟล์นี้):
1. **hard-gate → score-penalty**: `EA_SCORECARD_AND_REGISTRY.md` Step 0 เดิม auto-DISQUALIFIED
   "uncapped grid/no SL" ก่อนวัดผลจริงเลย → แก้เป็น **−25pt penalty เข้า score** แทน (Step 0b) เหลือ
   hard gate จริงแค่ expired/locked-ex กับ structural non-function (deployability fact ล้วนๆ)
2. **Model 2 = proof-of-concept เท่านั้น** — เพิ่มกฎ "ห้าม REJECT/DISQUALIFIED ขาดจาก Model 2 อย่างเดียว
   ต้องยืนยันที่ Model 1 (control points) เป็นขั้นต่ำ"
3. **Fixed-spread blind spot ยืนยันแล้ว** — ทุก report ที่สร้างมามี `Spread: Current (N)` เป็นค่าคงที่
   ตลอดทั้ง backtest (ทุก Model รวม Model 0) → `MaxSpread` filter ไม่เคยมีโอกาส trip ใน backtest เลย
   ทั้งที่ live จริง spread กระชากช่วง volatile น่าจะช่วยกันไม่ให้ยิงไม้รัว — เป็นช่องว่างจริงของ MT4 tester
   ไม่ใช่ error ของงานนี้ บันทึกเป็น caveat ถาวรใน `backtest-optimize-rigor` skill แล้ว

**Re-test XAU compiled-default เต็ม ladder ตามกฎใหม่ (ก่อนหน้านี้เทสแค่ Model 2):**
| Model | PF | net | DD% | trades | หมายเหตุ |
|---|---|---|---|---|---|
| Model 2 (เดิม) | 0.80 | -$10,419 | 101.76% | 814 | proof-of-concept เท่านั้น ไม่ใช่ verdict สุดท้าย |
| Model 1 (control points) | **1.89** | **+$801,302** | 18.16%/86.76%* | 63,245 | ⚠️ **artifact ที่จับได้** — 6.5 เทรด/แท่ง H1 เป็นไปไม่ได้จริง ระวัง Model 1 บิดเบือนได้เช่นกันถ้า spacing แน่นมาก |
| **Model 0 (every tick, ยืนยันสุดท้าย)** | **1.01** | **+$4,995** | **85.59%** | 34,934 | breakeven ทางสถิติ + DD หายนะ — verdict จริง |

**บทเรียนสำคัญ:** แม้แต่ Model 1 (control points) ที่ตั้งเป็น "ขั้นต่ำ" ก็ยังโดน artifact ได้ถ้า spacing
ของ EA แน่นมากผิดปกติเทียบกับ tick resolution จริง (Step=30 point บนทองคือ ~$0.30 ซึ่งแคบกว่าที่ควร) —
กฎ "ห้าม reject จาก Model 2 อย่างเดียว" ยังต้องคู่กับ **เช็คความสมเหตุสมผลของ trade count/bar ก่อนเชื่อผลเสมอ**
ไม่ว่า model ไหน. XAU **ยังคง REJECT** แต่ตอนนี้มาจากการวัดผลเต็ม ladder จริง (score ต่ำจาก DD 85.59%
สูงเกิน + PF≈1.0 ไม่มี edge จริง) ไม่ใช่จาก hard gate ก่อนวัด — ตรงตามที่ user ขอ

*Model 1 แสดง `abs_drawdown`/`rel_drawdown_pct` ขัดกันเอง (68 vs 128,099) เป็นอีกสัญญาณ artifact

## 5.9 (2026-07-03) EA ใหม่ `(Boss)_ZeusInspired_GridLog_rev01` — ผล backtest จริงรอบแรก

**Smoke (EURUSD, ทั้ง 2 instance):** GridLean PF flip 1.10(M2)→0.93(M1) — inconclusive, sample บาง (61-63t)

**Screen ข้ามคู่เงิน (16 คู่ ไม่รวมทอง, GridLean baseline, Model 2):** ดูตาราง `ZIGL_SCREEN_RESULTS.csv`
— AUDCAD/AUDJPY เด่นสุด (PF 1.80/27t และ PF 1.21/62t)

**⚠️ Model 1 confirm — AUDCAD ตกทั้งคู่:**
| Config | Model | PF | net | DD% | Sharpe |
|---|---|---|---|---|---|
| Baseline (2.2/1.5) | 2 | 1.80 | +$110 | — | 0.90 |
| Baseline (2.2/1.5) | **1** | **0.89** | **-$53** | 1.25 | -0.31 |
| Tightened (1.5/1.0) | 2 | 1.54 | +$163 | 0.72 | 1.01 |
| Tightened (1.5/1.0) | **1** | **0.91** | **-$64** | 2.09 | -0.34 |

**✅ Model 1 confirm — AUDJPY รอด:** baseline (2.2/1.5) PF 1.21(M2)→**1.21(M1) net +$82, DD 0.93-1.08%,
Sharpe 0.68, 62 เทรดเท่ากันทั้ง 2 model** — สัญญาณดี (ไม่ขึ้นกับ model แปลว่าไม่ใช่ fill artifact)

**⚠️ พบ scaling gotcha ตอนขยาย lot ให้ DD เข้า target 10-20%:** `_04_TpUsd` เป็น**ค่าดอลลาร์คงที่**
ไม่ scale ตาม lot อัตโนมัติ — ขยาย `_05_BaseLot` ×10 อย่างเดียว (ไม่แตะ TpUsd) ทำให้ basket ปิดเร็วขึ้น
มาก (trades 62→276, PF พลิกลบ 0.95) เพราะ target เดิม ($20) ถึงง่ายขึ้นมากที่ lot ใหญ่ — **ต้อง scale
`_04_TpUsd` ตาม `_05_BaseLot` สัดส่วนเดียวกันเสมอ** ไม่งั้นไม่ใช่ strategy เดิมที่ขยาย size แต่กลายเป็น
strategy คนละแบบ (บทเรียนสำหรับ derivative EA อื่นที่มี $ TP ในอนาคตด้วย)

**AUDJPY DD-scaled ให้เข้า target 10-20% (แก้ TpUsd ให้ scale ตาม lot แล้ว):**
| BaseLot | TpUsd | PF | net (18mo) | DD (equity)% | Sharpe | trades |
|---|---|---|---|---|---|---|
| 0.02 (1x) | 20 | 1.21 | +$82 | 1.08 | 0.68 | 62 |
| 0.20 (10x) | 200 | 1.55 | +$1,215 | 7.73 | 1.41 | 61 |
| **0.40 (20x)** | **400** | **1.91** | **+$2,780** | **14.73** | **2.02** | 54 |

**AUDJPY @ 20x sizing = candidate ที่ดีที่สุดตอนนี้** อยู่กลาง target band 10-20% พอดี PF/Sharpe ดีขึ้น
ตามขนาดด้วยซ้ำ (ไม่ใช่แค่ scale เชิงเส้น) — **ยังไม่ผ่าน IS/OOS/Monte Carlo** เป็นแค่ window เดียว 18 เดือน
sample ยังบาง (54-62 เทรด) ต้องยืนยันต่อก่อนพิจารณา deploy จริง

## 5.10 (2026-07-03) IS/OOS split + correlation + ขยาย symbol screen

**IS/OOS (IS=2025.01-2025.12, OOS=2026.01-2026.07, Model 1, ที่ sizing DD-scaled แล้ว):**
| Symbol | IS PF | IS DD% | OOS PF | OOS DD% | retention (OOS/IS) | verdict |
|---|---|---|---|---|---|---|
| **AUDUSD** | 1.63 | 7.98 | **1.78** | 9.43 | **1.09** (OOS ดีกว่า IS) | **รอด — edge จริง generalize ได้** |
| AUDJPY | 1.72 | 14.73 | 1.49 | 12.99 | 0.87 | รอด (ผ่านเกณฑ์ retention≥0.8 ของโปรเจกต์) |
| EURCAD | 1.59 | 6.48 | **0.84** | 7.26 | **0.53** | **ตก OOS — net ติดลบ ถอนออกจาก candidate list** |

**บทเรียนสำคัญ:** EURCAD ดูดีทั้ง full-window test และ DD-scaling exercise (PF 1.23 ที่ 13.39% DD)
แต่**ตก IS/OOS จริง** — ยืนยันว่าต้องรัน IS/OOS ก่อนเชื่อผล full-window เดียวเสมอ (full-window อาจ
overfit ได้โดยไม่รู้ตัวถ้าไม่แยก IS/OOS) — **EURCAD ถอนออกจาก candidate list แล้ว**

**AUDUSD กลายเป็นตัวที่แข็งแรงที่สุด** (retention >1, DD สม่ำเสมอทั้ง IS/OOS <10%) แซง AUDJPY ที่เคยดูดี
ที่สุดตอน full-window (PF 1.91) — Monte Carlo ก่อนหน้านี้ก็เคยเตือนแล้วว่า AUDUSD full-window DD (12.92%)
อาจโชคช่วยจาก trade order (95th pctile MC DD 16.55%, worst 26%) แต่ IS/OOS split ยืนยันว่า edge จริงยังอยู่
แค่ DD ในทางปฏิบัติผันผวนกว่าตัวเลขเดียว — ควรมองทั้งคู่ (IS/OOS + MC) ประกอบกัน ไม่ใช่ตัวใดตัวหนึ่ง

**Monte Carlo (resample-order bootstrap, 5000 iter, สำคัญ: net/PF ไม่เปลี่ยนตามลำดับเทรด — เป็นผลรวม
คงที่ ตัวที่มีความหมายจริงคือ max DD distribution เท่านั้น):**
| Symbol (sizing) | observed DD% | MC 95th pctile DD% | MC worst DD% |
|---|---|---|---|
| AUDJPY (20x) | 14.73 | 11.22 | 18.18 |
| EURCAD (10x) | 13.39 | 11.59 | 18.79 |
| AUDUSD (20x) | 12.92 | **16.55** | **26.04** |

**ขยาย screen อีก 11 คู่เงิน — ⚠️ user แก้กฎเพิ่มเติม (2026-07-03): ห้ามรายงาน/จัดอันดับด้วย Model 2 PF
เด็ดขาด (ไม่ใช่แค่ห้าม reject) Model 2 ใช้กรองทิ้ง zero-trade/พังเท่านั้น เลขที่รายงาน user ต้อง Model 1+
เสมอ — บันทึกเข้ม `EA_SCORECARD_AND_REGISTRY.md` + `backtest-optimize-rigor` แล้ว:**
- **AUDNZD: Model 2 PF 1.96 → Model 1 PF 1.06** (ยืนยันแล้วว่าล้ม เกือบ breakeven ไม่ใช่ candidate)
- **GBPAUD: Model 2 PF 1.50 → Model 1 PF 1.51** (รอด ตัวเลขตรงกันเกือบเป๊ะ) net +$53, DD 0.56%,
  Sharpe 0.93 แต่**แค่ 12 เทรด — บางเกินจะเชื่อ** ต้องรอข้อมูลเพิ่ม
- EURAUD/CADCHF/NZDCHF: <10 เทรดทั้ง 2 model ไม่มีความหมายทางสถิติไม่ว่า model ไหน
- ที่เหลือ (GBPCAD, EURNZD, NZDCAD, AUDCHF, GBPNZD, GBPCHF) ตายทั้งคู่ ไม่ต้อง confirm ซ้ำ

## 5.11 สรุปสถานะ candidate ล่าสุด (หลัง IS/OOS + Model 1 confirm ครบ)

| Symbol | สถานะ | หลักฐาน |
|---|---|---|
| **AUDUSD** | **แข็งแรงที่สุด** | IS PF 1.63 → OOS PF 1.78 (retention 1.09, OOS ดีกว่า IS) |
| **AUDJPY** | **รอด** | IS PF 1.72 → OOS PF 1.49 (retention 0.87, ผ่านเกณฑ์ ≥0.8) |
| EURCAD | ❌ ตัดออก | ตก OOS (retention 0.53, net ติดลบ) |
| AUDCAD | ❌ ตัดออก | ตก Model 1 ทั้ง baseline และ tightened |
| AUDNZD | ❌ ตัดออก | ตก Model 1 (PF 1.96→1.06) |
| GBPAUD | ⏳ รอข้อมูลเพิ่ม | รอด Model 1 แต่แค่ 12 เทรด |
| USDJPY/EURCHF | ⏳ รอข้อมูลเพิ่ม | รอด Model 1 แต่บาง (14-18 เทรด) |
| EURJPY | 🔹 diversifier เท่านั้น | edge อ่อน (PF~1.04-1.09) แต่ corr ต่ำกับ AUDUSD/AUDJPY/EURCAD |

**Portfolio แนะนำตอนนี้:** **AUDUSD + AUDJPY** เป็นแกนหลัก (ทั้งคู่ผ่าน IS/OOS จริง) — corr ระหว่างกัน
0.554 (WATCH tier) ใช้ lot ลดลงตามกฎ correlation เดิมของโปรเจกต์ (ไม่ตัดทิ้ง แค่ลด) เสริมด้วย **EURJPY**
lot เล็กเพื่อ diversify เท่านั้น (ไม่ได้หวัง profit จากตัวมันเอง)

## 6. ต่อยอด (แผนงานที่เหลือ — ดู plan file phase 4-10)

- **Phase 4-6:** smoke screen ทุก symbol (20 ตัวที่มีจริงบน ThinkMarkets-Live 4: AUDCAD, AUDUSD,
  BNBUSD, BTCUSD, CHFJPY, DOGEUSD, ETHUSD, EURCHF, EURGBP, EURUSD, GBPUSD, NAS100, SOLUSD,
  SPX500, USDCAD, USDCHF, USDJPY, WTI, XAUUSD, XAUUSDMINI) → optimize กลุ่ม spacing/lot แยก EU/XAU
  → deep validate → ลงทะเบียน `EA_SCORECARD_AND_REGISTRY.md` — **ต้องปิด MT4 GUI ที่รัน Zeus live อยู่
  จริงก่อนรัน headless backtest ได้ (single-instance ต่อ data dir) → รอ user ยืนยันก่อนปิด**
- **Phase 8:** ทดลอง 2 instance magic แยกกัน (grid-tilt vs anti-grid-tilt) เช็ค correlation
- **Phase 9:** ออกแบบ EA ใหม่ inspired by หลักการนี้ (ไม่แตะ .ex4 เดิม) ใส่ partial-close ลด DD +
  first-lot ปรับตาม floating drawdown ผ่าน `strategy-and-risk` → `mql-code-generator`
- **Phase 10:** แปลง methodology นี้เป็น skill `locked-ea-analyzer` ให้เรียกซ้ำได้กับ EA ล็อคตัวอื่น

## Sources
- [EA Zeus Gold Hedge v1.2 blog post — mql5.com (ผู้เขียนต้นฉบับ)](https://www.mql5.com/en/blogs/post/740351)
- [Zeus Gold Hedge EA MT4 — eafxstore.com](https://eafxstore.com/product/zeus-gold-hedge-ea-mt4/)
- [Zeus Gold Hedge EA V1.2 — indicatorspot.com](https://indicatorspot.com/indicator/zeus-gold-hedge-ea-v1-2-mt4/)
- [Zeus Gold Hedge V1.2 EA MT4 NO DLL — mql5bot.com](https://mql5bot.com/product/zeus-gold-hedge-v1-2-ea-mt4-no-dll/)
- [Maximise Profits with Zeus Gold Hedge EA — forexairobot.com](https://forexairobot.com/zeus-gold-hedge-ea/)
- [Zeus Gold Hedge EA MT4 — forexcrackedvip.com](https://forexcrackedvip.com/product/zeus-gold-hedge-ea/)
- [Zeus Gold Hedge EA V1.2 MT4 — mql5cracked.com](https://mql5cracked.com/product/zeus-gold-hedge-ea/)
- [ZEUS GOLD HEDGE EA MT4 FOR BUILD 1420+ — forexrobotea.com](https://forexrobotea.com/product/zeus-gold-hedge-ea)
- [ZEUS GOLD HEDGE EA MT4 FOR BUILD 1420+ — shopforexea.com](https://shopforexea.com/product/zeus-gold-hedge-ea/)
- [Zeus Gold Hedge EA MT4 v1.2 — unlockea.com](https://unlockea.com/product/zeus-gold-hedge-mt4-ea/)
