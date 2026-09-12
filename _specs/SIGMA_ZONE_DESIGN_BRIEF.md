> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **design brief ของไอเดีย "1SD / SIGMA_ZONE" เท่านั้น** (spec เครื่อง = `_specs/SIGMA_ZONE_SpecCard.yaml`)

# SIGMA_ZONE — design brief จากบทความ "I don't trade 1SD"

**วันที่:** 2026-07-26 · **สถานะ:** DESIGN ONLY (ยังไม่มีโค้ด ยังไม่มีตัวเลข ยังไม่มี verdict)

---

## 1. บทความอ้างอะไร แล้วอันไหนจริง

| ข้ออ้าง | คำตัดสิน | เหตุผล |
|---|---|---|
| ในโซน ±1SD ราคาเป็น noise / random walk | **จริงพอจะเทสได้** | นี่เป็นข้ออ้างเชิง "ห้ามทำ" (filter) วัดได้ถูกมากบน EA ที่มี edge อยู่แล้ว |
| 68.2% ของข้อมูลอยู่ใน 1SD → 2SD คือของหายาก/panic | **ไม่จริงในตลาดจริง** | 68.2% มาจาก normal distribution. return ของ FX/XAU เป็น fat-tail + vol-cluster → การแตะ 2SD เกิดถี่กว่านั้นมาก และเกิดเป็นกระจุก (แตะแล้วแตะอีกในเทรนด์เดียว) ไม่ใช่เหตุการณ์ panic ที่หายาก |
| ที่ 2-3SD มี edge — เล่นได้ทั้ง reversion และ breakout | **ขัดกันเอง** | สองอันนี้เป็นระบบคนละตัว ตรงข้ามกันที่จุดเดียวกัน. บทความไม่บอก "ตัวแยก" → คำถามวิจัยจริงคือ *อะไรเป็นตัวแยกว่าตอนนี้ควรสวนหรือควรตาม* ไม่ใช่ "ไปเทรดที่ 2SD" |
| Smart money รอที่หาง | ไม่ใช่หลักฐาน | เป็นเรื่องเล่า ไม่ใช่สิ่งที่ backtest ได้ ตัดทิ้งจาก spec |

---

## 2. ⛔ ของที่โปรเจกต์นี้เทสไปแล้วและตายไปแล้ว (ห้ามทำซ้ำ)

**EA_ZSCORE (#100) — rescue 2026-07-16 = REJECT.** ย้ายไปบ้านที่ถูก (ranger: AUDNZD / EURGBP / EURCHF)
× threshold {2.0, 2.5, 3.0} × {H1, H4} × both-window = **36 runs ไม่มีตัวรอด**. ดีสุด EURGBP H4 t3.0 =
PF 1.04/1.12 แต่ 36-42 ไม้ + เป็น spike (t2.0/2.5 ตก) = thin-artifact.
(ที่มา: `AGENT_TASKBOARD.md` §rescue #3 · CSV `_mt5_auto/ZSCORE_RESCUE_RANGER.csv`)

**แปลว่า: "ยิงสวนที่ 2SD ด้วย z-score เปล่าๆ" = cell ที่ตายบนบ้านที่ถูกแล้ว** — ซึ่งเป็นหัวใจของอาร์มที่
บทความชอบที่สุด. ถ้าไปสร้าง EA ตามบทความตรงๆ = จ่ายเงินซื้อคำตอบเดิมรอบสอง.

**ของที่ยังไม่เคยเทสจริง (4 ช่อง — นี่คือที่ที่ EV อยู่):**
1. **1SD-gate เป็น "ตัวหักลบ"** บน EA ที่มี edge อยู่แล้ว — บทความบอกว่า "อย่าเทรดใน 1SD" ซึ่งเป็น *filter* ไม่ใช่ entry. เราไม่เคยวัดมันในฐานะ filter
2. **อาร์ม JOIN** (breakout ตอน volatility ขยายที่ขอบ) — ZSCORE เทสแต่ฝั่งสวน ไม่เคยเทสฝั่งตาม
3. **SD แบบ anchored รายวัน/เซสชัน** (σ_day × √เวลาที่ผ่าน จากราคาเปิดวัน) — คนละสิ่งกับ rolling Bollinger z และใกล้กรอบ "expected move" ของสถาบันที่บทความอ้างมากกว่า
4. **ตัวแยก FADE vs JOIN** = σ กำลังขยายหรือหด

---

## 3. ดีไซน์ที่เสนอ — 2 เฟส และเฟส A มาก่อนเสมอ

### PHASE-A (แนะนำให้ทำก่อน · ถูกมาก · ไม่ต้องเขียน EA ใหม่)
เพิ่ม filter ตัวเดียวเข้าแม่พิมพ์: **`TFILTER_SIGMA (73)` = ห้ามเปิดไม้ใหม่เมื่อ |z| < ZMin** (additive,
default OFF, ผ่าน `tpl_regression.ps1` พิสูจน์ว่า OFF = ตัวเลขเดิมเป๊ะ)
แล้ว A/B `ZMin ∈ {off, 1.0, 1.5, 2.0}` บน EA ที่ผ่าน funnel มาแล้ว 3 ตัว:
MacdDiv XAU H4 (999094) · Boss_16 Kangaroo XAU H1 · SMCxSTO EURUSD H1

**อ่านผลยังไง:** filter ที่ดีต้อง **ยก PF ขึ้นในขณะที่จำนวนไม้ลดลง**. ถ้าตัดไม้ทิ้ง 40% แล้ว PF เท่าเดิม
= ข้ออ้างของบทความไม่จริงบนพอร์ตนี้ (ไม้ในโซน 1SD ไม่ได้แย่กว่าไม้อื่น) → จบ ไม่ต้อง build เฟส B.
นี่คือการซื้อคำตอบของบทความทั้งบทความด้วยราคาที่ถูกที่สุด.

### PHASE-B (ทำก็ต่อเมื่อเฟส A ให้สัญญาณบวก หรือ user สั่งให้ build ตรงๆ)
**Boss_19 SIGMA_ZONE** — entry module ใหม่บนแม่พิมพ์ (`Entry_SigmaZone.mqh`, entry id 19)

- **กฎร่วมทุกโหมด:** |z| < `_19_ZMin` → ห้ามเปิดไม้ใหม่ (= หัวใจของบทความ)
- **MODE 2 JOIN (default):** z ทะลุ ZMin **และ σ กำลังขยาย** (ATR(0) ≥ ExpRatio × ATR_MA) **และแท่งปิดยืนนอกแบนด์** → ตามทาง · SL = ขอบ 1SD ฝั่งตรงข้าม (ราคากลับเข้าแบนด์ = thesis ตาย) · TP = trail ไม่ fix สั้น
- **MODE 1 FADE (default OFF):** เปิดได้เฉพาะรูปแบบที่ *ต่างจริง* จาก ZSCORE — ต้องมี rejection (ปิดกลับเข้าในแบนด์) หรือใช้ z_source anchored/return. ห้าม rerun แบบ rolling-BB + threshold เปล่า
- **MODE 3 AUTO:** ให้ σ-expanding เป็นตัวแยก. เทสได้หลังวัด mode 1 และ 2 เดี่ยวๆ แล้วเท่านั้น
- **บ้าน:** JOIN → XAUUSD / GBPUSD H1-H4 (trender) · FADE → EURUSD / EURGBP / AUDNZD (ranger)
- **ข้อบังคับ:** trigger แบบ close-confirmed เท่านั้น (ห้าม touch — กัน fill-artifact) · SL จริงเสมอ ·
  ไม่มี grid / martingale / hedge ในเวอร์ชันแรก (ต้องพิสูจน์ว่า *สัญญาณ* มี edge ไม่ใช่การถัว) ·
  1 ไม้ต่อฝั่ง

**เงื่อนไขฆ่าที่เขียนไว้ล่วงหน้า (ก่อนเห็นตัวเลข):** ดู `SIGMA_ZONE_SpecCard.yaml` §rejection_conditions —
ที่สำคัญสุด 2 ข้อ: (ก) ผลดีที่มาจาก threshold สูง + ไม้บาง แล้วหายเมื่อลด threshold = thin-artifact ไม่นับ
(บทเรียนตรงจาก ZSCORE) (ข) Model-4 พลิกเครื่องหมาย = DEAD-STRUCTURAL (entry ที่ขอบแบนด์ fill-sensitive
โดยธรรมชาติ → Model-4 บังคับ ไม่ใช่ทางเลือก)

---

## 3.5 ส่วนขยายตาม user 2026-07-26 — symbol×TF · bias · news/macro

### (ก) "ดีเฉพาะบาง symbol บาง TF" — ถูก และต้องบังคับให้เป็นระเบียบ ไม่ใช่ปล่อยให้เลือกทีหลัง

z-score เป็นตัวเลขที่ไม่มีหน่วย ก็จริง แต่ *พฤติกรรมหลังแตะ 2SD* ต่างกันตาม instrument ชัดเจน:
XAU/GBPJPY แตะแล้วมักไปต่อ (vol-cluster แรง) · EURGBP/AUDNZD แตะแล้วมักหด. นี่คือเหตุผลที่ต้อง
**pre-register matrix ก่อนรัน** และห้ามเลือก cell หลังเห็นตัวเลข (บทเรียน Boss_16: select หลังเห็นข้อมูล = holdout ไหม้)

| อาร์ม | symbol | TF | เหตุผล |
|---|---|---|---|
| **JOIN** (default) | XAUUSD · GBPUSD · GBPJPY · USDJPY | H1, H4 | trender/vol-cluster — 8 cell |
| **FADE** (gated) | EURUSD · EURGBP · AUDNZD | H1, H4 | ranger — 6 cell **แต่เปิดได้ต่อเมื่อต่างจริงจาก ZSCORE** (rejection confirm หรือ z_source anchored) |
| **HOLDOUT (ห้ามแตะ)** | XAGUSD ทุก TF · หน้าต่าง 2026H1 | — | สำรองไว้ยืนยันตอนท้าย ใช้ตอนไหน = ไหม้ตอนนั้น |

**วินัยเรื่องจำนวนการทดสอบ (สำคัญกว่าที่คนส่วนใหญ่คิด):** 8-14 cell × 4 ค่า ZMin = ~50 การทดสอบ
→ โดยบังเอิญล้วนๆ จะมี 1-3 cell ที่ PF > 1.2. ดังนั้น **cell เดี่ยวที่สวยไม่นับเป็นหลักฐาน** — ต้องผ่าน
(1) plateau ของ cell ข้างเคียง (symbol พี่น้อง / TF ติดกัน ต้องไปทางเดียวกัน) + (2) both-window (MAIN + BWD)
ตาม bar table เดิม. cell สวยเดี่ยวโดดๆ = จดว่า WATCH ไม่ใช่ candidate.

### (ข) Bias filter สำหรับ buy/sell — 4 ชั้น เรียงจากถูกไปแพง (ใช้ของที่มีอยู่แล้วก่อน)

| # | lever | มีอยู่แล้วไหม | ใช้ยังไงกับ SIGMA_ZONE |
|---|---|---|---|
| **B1** | `TradeDir` = LONG_ONLY / SHORT_ONLY | ✅ มีในแม่พิมพ์ | รันเป็น 2 instance แยก magic (แบบ `_18_Direction`) — ได้ทั้งการวัด asymmetry ฟรี และได้ตัวเลือก deploy ฝั่งเดียว (precedent: Boss_16 BUY-only · KAUFMAN buyonly) |
| **B2** | **HTF direction gate** (`_19_BiasTF` + `_19_BiasMode`) | ⚠️ ต้องเขียน แต่มี precedent ตรง | **นี่คือชั้นที่คาดว่าให้ผลมากสุด.** ORDER-071 salvage: H4-MACD-direction gate ลด DD 21% → 5.5% บน entry อื่น = อะไหล่ที่พิสูจน์แล้ว. modes: `0` off · `1` HTF MA slope · `2` HTF MACD sign · `3` ADX/DI จาก `Regime.mqh` (`_50_`) |
| **B3** | **z ไม่สมมาตร** (`_19_ZMinBuy` / `_19_ZMinSell`) | ต้องเขียน (ถูก — แค่แยกตัวแปร) | ตลาดไม่สมมาตร: XAU/หุ้น σ พุ่งฝั่งลง · JPY-carry ฝั่งขาย. บังคับ ZMin เท่ากันสองฝั่ง = ยัดสมมติฐานผิดเข้าไปตั้งแต่ต้น |
| **B4** | session window | ✅ มี pattern จาก entry 12 (`HourFrom/To`) | ผูกกับ z_source=2 (anchored ที่เปิดเซสชัน) อยู่แล้ว — ใช้เป็น lever เดียวกัน ไม่ต้องเพิ่มของใหม่ |

**กฎการใช้ bias ที่ไม่เหมือนกันสองอาร์ม (นี่คือ design decision จริง ไม่ใช่ toggle เฉยๆ):**
- **JOIN ต้องการ bias "เห็นด้วย"** — ทะลุ 2SD ขึ้น + HTF ขึ้น = สัญญาณ; ทะลุขึ้นแต่ HTF ลง = ปล่อยผ่าน
- **FADE ต้องการ bias "เป็นกลาง"** — ห้ามสวนตอนเทรนด์ HTF แรง (ADX สูง / slope ชัน). นี่คือคำตอบตรงๆ ของคำถาม
  ที่บทความไม่ตอบ ("เมื่อไหร่สวน เมื่อไหร่ตาม") และเป็นสมมติฐานที่ MODE 3 AUTO จะทดสอบ

**ลำดับการวัด (ห้ามสลับ):** naked ก่อน → ใส่ bias ทีละชั้น B1 → B2 → B3 → ดูว่าชั้นไหนยก PF ขณะไม้ลด.
ใส่พร้อมกันทีเดียว = ไม่รู้ว่าตัวไหนทำงาน (บทเรียนซ้ำๆ ของ repo นี้)

### (ค) News / macro — **ใช้ของเดิม ห้ามสร้างใหม่** และแยกวัดเสมอ

| ชั้น | ของที่มีอยู่ | backtest ได้ไหม | ที่ทางใน SIGMA_ZONE |
|---|---|---|---|
| **MacroGate** (ORDER-073 Phase-3, VALIDATED) | `core/MacroGate_Core.mqh` + regime CSV + GV bridge (block-new + lot-mult) | ✅ ได้ (อ่าน CSV ในเทสเตอร์) — A/B บน Boss_12 ปี 2024 = **eqDD −54..−56%** | overlay หลัง naked ผ่านแล้ว. โปรไฟล์ที่เหมาะกับ SIGMA_ZONE: **JOIN อาจไม่อยากถูกบล็อกตอน STRESS** (vol expansion คือสิ่งที่มันกิน) — ดังนั้น A/B `mg_triggerRiskOff` และ lot-mult แทน block-new เต็ม |
| **NewsGuard** (event blackout ±N นาที) | MT5 พร้อม attach · MT4 port ทำแล้ว | ❌ **ไม่ได้** — ในเทสเตอร์ไม่มี feed | **ห้ามนับเป็น edge เด็ดขาด.** เป็น overlay ตอน demo/live เท่านั้น และต้องจดในแถว DEPLOYMENTS ว่าเปิดอยู่ ไม่งั้นเทียบเลข demo กับ backtest ไม่ตรงแล้วงงเอง |

**doctrine ที่ต้องเขียนไว้ตรงนี้:** ถ้า EA "ดีเฉพาะตอนเปิด MacroGate" แปลว่า **gate คือ edge ไม่ใช่ EA** →
ทางที่ถูกคือเอา gate ไปทดสอบกับ EA ตัวอื่นในพอร์ต ไม่ใช่ประกาศว่า SIGMA_ZONE ผ่าน.
(ตรรกะเดียวกับ flat-lot probe ที่จับ martingale-เป็น-edge ได้)

### (ง) ลำดับงานที่แก้ใหม่

```
PHASE-A   1SD-gate เป็น filter บน 3 champion            <- ยังเป็นอันแรกเสมอ (ถูกสุด/ตอบบทความ)
PHASE-B0  naked JOIN บน 8 cell (4 symbol x 2 TF)        <- pre-registered matrix ห้ามเพิ่ม cell ทีหลัง
PHASE-B1  bias ทีละชั้น B1 -> B2 -> B3 บน cell ที่รอด B0
PHASE-B2  MacroGate overlay A/B (block vs lot-mult vs off)
PHASE-C   funnel เดิม: plateau -> both-window -> fan -> Model-4 -> MC -> corr -> demo (+NewsGuard ตอน attach)
```

---

## 4. คำแนะนำเดียว

**ทำ PHASE-A ก่อน — อย่าเพิ่ง build EA.** บทความมีของจริงอยู่ชิ้นเดียวคือ "ห้ามเทรดในโซน noise" และของชิ้นนั้น
เป็น *filter* ที่วัดได้ด้วยงานไม่กี่ชั่วโมงบน EA ที่เรามีอยู่แล้ว. ส่วนที่บทความขายดังที่สุด (สวนที่ 2SD)
โปรเจกต์นี้จ่ายเงินซื้อคำตอบไปแล้วว่าไม่มี edge. ถ้า filter ยก PF ของ champion ได้จริง เราได้ของฟรี
ที่ใช้กับทุก EA; ถ้าไม่ยก เราปิดบทความนี้ด้วยหลักฐาน แทนที่จะปิดด้วยความเห็น.

---

## 5. ที่เกี่ยวข้อง
- spec เครื่อง: `_specs/SIGMA_ZONE_SpecCard.yaml`
- verdict gate + bar table: `CLAUDE.md` §VERDICT GATE
- หลักฐาน ZSCORE: `AGENT_TASKBOARD.md` §กอง ข rescue #3 · `_mt5_auto/ZSCORE_RESCUE_RANGER.csv`
- entry module conventions: `ea_template/DESIGN_V2.md` §2
