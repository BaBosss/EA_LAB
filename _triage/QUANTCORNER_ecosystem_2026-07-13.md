# Triage — QuantCorner ecosystem (FB เพจ + YouTube) 2026-07-13

user แชร์ชุดลิงก์จากคอมมูนิตี้ **QuantCorner** (แหล่งเดียวกับที่ได้ไฟล์ 151). ทั้งหมด = แหล่งความรู้ quant
สำหรับต่อยอด process/workflow ของ EA_LAB (ไม่ใช่ EA ให้ลอกตรงๆ — เป็น "วิธีคิด/วิธีทำ").

## แหล่ง (references — เก็บไว้เป็นคลังเรียนรู้ต่อเนื่อง)
- **QuantCorner** — คอมมูนิตี้ Quant ไทย (17K, `quant-corner.com`, Discord, Meetup, กำลังทำหลักสูตร Quant).
  โพสต์เด่น: งาน **"AI BATTLE IN FINANCE" (22 ส.ค. 2026)** — Claude Code vs Codex vs Claude Cowork สร้าง
  alpha pipeline/workflow สดหน้างาน · session สำคัญ: *"Construct Alpha Pipeline with Loop Engine:
  Idea→Data→Factor→Backtest→Evaluation→Improvement"* (คุม Data Leakage, OOS, Transaction Cost, Risk) —
  **= pipeline เดียวกับเราเป๊ะ** (validate ว่าทิศ loop-engine ของเราตรงกระแส industry).
- **Kas Asava** — เรียน CQF, เขียน "CQF Diary" อธิบาย Stochastic Calculus/Brownian Motion/Itô/Black-Scholes
  แบบบ้านๆ. อ้าง **WQU.edu** (ป.โท Financial Engineering ฟรีออนไลน์).
- **ช่อง YouTube สาย Quant (QuantCorner แนะ):** QuantPy (Python quant) · **Hudson & Thame (mlfinlab =
  López de Prado methods)** · StatQuest (ML/stats) · 3Blue1Brown (math intuition) · polymatter · coldfusion.

## YouTube — สาระที่แกะได้ (agent, verified)

### 🎯 วิดีโอ 1 "Idea to Algorithm: Full Quant Workflow" (Quantopian/Delaney Mackenzie, 64min) — คุ้มสุด
workflow 9 ขั้น (เรียงตามที่พูด): (1) ตั้ง **economic hypothesis** ว่าโลกทำงานยังไง — หลักฐานที่มีค่าสุดคือ
data ที่ *ขัด* สมมติฐาน (2) explore/refine in-sample (3) **เทียบกับ model ที่มีอยู่** (regression ผลตอบแทน
ตัวเรากับ risk factor เดิม — residual = alpha จริง; ถ้าอธิบายได้หมด = ไม่ใช่ของใหม่) (4) รวมหลาย sub-model
*อิสระต่อกัน* (average อิสระ = ยกคุณภาพ) (5) **OOS บน data ใหม่จริง** (6) portfolio construction (ทำ*ทีหลัง* —
maximize alpha ใต้ risk constraint) (7) execution + cost (8) **backtest = เช็คว่าพอร์ต*รอด friction*ไหม
ไม่ใช่เช็คว่า signal ทายถูก** (9) paper→scale.
- **แก่น "correlation ต้องรอด":** ได้เงินก็ต่อเมื่อ signal s สัมพันธ์กับ return อนาคต — แต่ละขั้น = จุดที่ s อาจขาด:
  (a) s ไม่ correl กับ return (b) s อธิบายได้ด้วย factor เดิม (c) risk-constraint ฆ่า alpha (d) cost ฆ่า s.
- **IC / Alphalens:** วัด signal ด้วย Spearman-rank corr ระหว่าง prediction วัน T กับ return วัน T+1/T+5/T+10 →
  ดู *distribution* ของ IC รายวัน (อยาก mean สูง/std ต่ำ/บวกสม่ำเสมอ).
- **k-fold ≠ OOS** (k-fold ลด overfit แต่ไม่พอ — OOS data ใหม่จริงเท่านั้น = gold standard).
- price data อย่างเดียวเกือบไม่พอ (ถูก arb หมด) → alpha ใหม่มาจาก alternative data. default prior = idea จะ *ไม่* work.

### วิดีโอ 2 "Pod Quant" (ไทย, 66min) — taxonomy กองทุน quant (caption noisy, ชื่อเฉพาะเพี้ยน)
6 ตระกูล: (1) **Equity Long-Short** (AUM ใหญ่สุด; factor-score→rank→long top/short bottom; ย้ายไป ML tree
gradient-boost/RF; gross/net เช่น 150/50 = net 100 gross 200 = 2x) (2) **Market/Beta-Neutral** (overlay
index future short beta ให้ ≈0 → P&L = selection alpha ล้วน; vol ต่ำ 3-4% ไม่รันเดี่ยว) (3) **Global Macro**
(Bridgewater; macro indicator→rotation model 6-12ด ล่วงหน้า→long-short ผ่าน futures; risk-parity แยกต่างหาก)
(4) **Event-Driven** (index-rebalancing = scalable; crowded → เจ๊ง $900M) (5) **Stat-Arb/RV** (basket-vs-index
basis; **edge อยู่ที่ execution + ลด replication set ด้วย PCA เหลือ ~30/50 ชื่อ อธิบายได้ 95%**; vol-arb
implied-vs-realized+delta-hedge; carry; triangular) (6) **AI/ML** (ไม่ใช่ตระกูลใหม่ — แค่เปลี่ยน signal-gen
เป็น ML; Transformer→cross-sectional momentum ranking; RL สำหรับ portfolio decision; **gen-AI ที่ work จริง =
"junior analyst" รวบรวม/ย่อยข้อมูล ไม่ใช่ signal**). ปิดท้าย: เข้าใจ*หลักการ*ก่อน อย่าโดดไป tool — 3 อย่างจำเป็น:
คณิต + ภาษาโปรแกรม + portfolio-management.

### วิดีโอ 3 "Black-Scholes & Itô" (11min) — options math, relevance ต่ำ
Itô's lemma (dx²→dt ทำ 2nd-order term รอด), GBM `dS=μS·dt+σS·dZ`, delta-hedge cancel noise→riskless→BS PDE.
เราไม่เทรด options → ไม่ใช้ตรงๆ. faint: GBM = สมมติฐานที่ MC ของเราอิงอยู่ (จริงมี fat-tail/vol-cluster ที่ GBM ไม่มี).

## 💡 สิ่งที่หยิบมาต่อยอด EA_LAB ได้จริง (verdict ผม)
1. **IC/Spearman pre-backtest screen** ⭐ — เพิ่มใน `signal-scanner`: rank entry ด้วย signal strength แล้ววัด
   corr กับ N-bar-forward return *ก่อน* เผา optimize budget. กัน "spike ไม่ใช่ plateau" ตั้งแต่ต้นทาง. **ของใหม่คุ้ม.**
2. **"signal predicts?" แยกจาก "portfolio survives friction?"** — ตรง doctrine เรา (flat-lot PF = edge test แยกจาก
   cost/spread). เสริม VERDICT GATE ให้ชัดว่าเป็น 2 คำถามคนละอัน.
3. **compare-to-existing ด้วย return-regression** — reframe corr gate: EA ที่ share 70% กับตัวเดิมยังมีค่าถ้า
   incremental part รอด (นุ่มกว่ากฎ >0.8 ตัด). residual-alpha thinking.
4. **k-fold ≠ OOS** — ammunition ตรงเข้า VERDICT GATE (in-sample plateau = selection-fit).
5. **beta-neutral overlay + PCA basket reduction** — เก็บไว้เฟส multi-symbol basket (W-tier cross-sectional).
6. **AI-as-junior-analyst** — ยืนยัน delegation model เรา (qwen/Sonnet ย่อยข้อมูล, judgment ที่ orchestrator).

## next (ยังไม่ทำ — เข้าคิว)
- พิจารณายก **IC-screen** เป็น order เสริม `signal-scanner` (คู่กับ SSRN W-tier)
- QuantCorner/Discord + Hudson&Thame mlfinlab = แหล่งขุดต่อรอบหน้า (López de Prado methods ตรงกับ overfit-control เรา)
