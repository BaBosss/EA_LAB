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
