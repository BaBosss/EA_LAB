# AGENT_TASKBOARD_PQUANT — Phase 3.5 PORTFOLIO-QUANT (ออกแบบล่วงหน้าโดย Fable 2026-07-06)

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **คิวงาน + design ของ track PORTFOLIO-QUANT
> เท่านั้น** · กติกา claim/สถานะเหมือนบอร์ดหลัก (`AGENTS.md`)
>
> **สถานะบอร์ด: 🔒 LOCKED — ห้ามเริ่มทุก order ก่อนเงื่อนไข: judge day เสร็จ (ดู `docs/JUDGE_DAY_RUNBOOK.md`)
> + พอร์ต #1 live แล้ว** · เหตุที่ล็อค: demo 3 เดือน = experiment ที่แพงสุดที่กำลังรัน ห้ามแทรก ·
> design ข้างล่างเขียนจบแล้วด้วย Fable ก่อน quota หมด — ตอน unlock งานเหลือระดับ mechanical+review

## 🎯 GOAL (จาก decision 2026-07-06: quant method ไม่ใช่ quant firm)

เปลี่ยนจาก "มี EA หลายตัวที่ต่างคนต่างเสี่ยง" → "พอร์ตที่คุม risk เชิงระบบ" ด้วย 3 ชิ้น:
vol-target sizing · deflated gate · tracking-error bands — ทั้งหมดเป็น **offline advisor**
(script วิเคราะห์ → เสนอเลข → user/Claude อนุมัติ → แก้ .set) **ไม่แตะโค้ด EA ที่ live**

**DONE เมื่อ:** (1) ทุกพอร์ต live มี risk budget + lot ที่มาจากสูตร ไม่ใช่ความรู้สึก (2) เกณฑ์รับ
candidate ปรับตามจำนวนที่ทดสอบอัตโนมัติ (3) /ea-monitor ตัดสินด้วย band ตัวเลข ไม่ใช่ดุลยพินิจ

---

## PQ-01 — Portfolio risk layer (vol-target + DD budget) — `LOCKED` · ทำได้: Claude ออกแบบเสร็จแล้ว → เหลือ implement script (Codex) + review

**Design (ตรึงแล้ว — Fable 2026-07-06):**

หลักการ: ทุก EA ควรมีส่วนแบ่งความเสี่ยงเท่าเทียมตามที่ตั้งใจ ไม่ใช่ตาม lot ที่บังเอิญตั้ง —
EA ที่ swing แรงต้อง lot เล็ก EA ที่นิ่งได้ lot ใหญ่ และผลรวมต้องไม่เกินงบ DD ของพอร์ต

1. **Input ต่อ EA i (จาก deals จริง ≥3 เดือน):** `vol_i` = std ของ P&L รายสัปดาห์ (บน lot ปัจจุบัน) ·
   `corr matrix` จาก `corr_monthly.py`
2. **งบพอร์ต:** `DD_budget` = 25% ของ equity (ตรึงจาก runbook §3.3) → แปลงเป็นงบ vol รายสัปดาห์:
   `vol_budget = DD_budget / 3` (heuristic: max-DD ≈ 3× weekly vol สำหรับ strategy กลุ่มนี้ —
   PQ-01 ขั้น validate ให้เทียบกับ MC จริงแล้วปรับตัวคูณ)
3. **จัดสรร:** เป้าต่อ EA = equal risk share ปรับด้วย correlation penalty:
   `share_i = (1/N) × (1 − 0.5×avg_corr_i)` แล้ว normalize · EA ธงสันเขา (sensitivity <3/8) คูณ 0.5 อีกชั้น
4. **Output:** `lot_new_i = lot_now_i × (share_i × vol_budget / vol_i)` — clamp การเปลี่ยนต่อรอบ ±50%
   (กันสูตรเหวี่ยงจาก sample สั้น) · ปัดลงตาม broker step
5. **รอบรัน:** เดือนละครั้งหลัง metrics + ทุกครั้งที่ EA เข้า/ออกพอร์ต · ผลเป็น **ข้อเสนอ** ลงตาราง
   ให้ user อนุมัติก่อนแก้ .set เสมอ (ไม่ auto-apply)
6. **Cage ของชิ้นนี้:** golden-sample test — deals ชุดตายตัว 1 ชุด → lot ที่คำนวณต้องได้เลขเดิมทุกครั้ง
   (Pattern B ใน PORTABLE_AI_OS) + assert: ผลรวม risk share = 100%±ε · ไม่มี lot ติดลบ/เกิน RC_MaxLot

**Implement:** `scripts/portfolio_risk.py` (portable python) อ่าน `portfolio/live_deals/*.csv` + corr →
ตาราง markdown ข้อเสนอ · **Acceptance:** golden-sample ผ่าน + รันบน deals จริงได้ตาราง sane + Codex
blind review สูตร (money logic ใหม่ = บังคับตามกฎ)

---

## PQ-02 — Deflated gate (multiple-testing discipline) — `LOCKED` · ทำได้: Claude (เป็น rule ไม่มีโค้ด)

**Design (ตรึงแล้ว):** ยิ่งทดสอบมาก ตัวที่ "ผ่าน" ด้วยดวงยิ่งเยอะ — เกณฑ์ promotion ต้องแพงขึ้นตาม
จำนวนที่ลองในรอบนั้น (N = จำนวน EA×symbol configs ที่ screen มาด้วยกัน):

| N ของรอบ screen | OOS/BWD PF ขั้นต่ำเพื่อขึ้น CANDIDATE | เหตุผล |
|---|---|---|
| ≤ 50 | 1.20 (เดิม) | เท่า gate ปัจจุบัน |
| 51–500 | **1.30** | expected max ของ noise โตตาม log(N) |
| > 500 (เช่น mass-smoke 1,521) | **1.40** | ระดับที่ผู้รอดปลอมส่วนใหญ่ไปไม่ถึงใน OOS จริง |

- ใช้กับ **ด่าน promotion (OOS/BWD)** เท่านั้น — smoke gate PF>1 คงเดิม (กฎ user no-DEAD-before-optimize
  ไม่แตะ) · ทุก order แบบ screen ต้องจดค่า N ลงหัวตาราง (แหล่ง: worklist ของรอบนั้น)
- หลักฐานสนับสนุนจากระบบเราเอง: mass-smoke 222 ตัว → Tier A 32 → รอดด่านจริง 1 (0.45%) —
  survivors ที่ PF OOS <1.4 ตายหมดจริงตามตาราง
- **งานตอน unlock:** เพิ่มตารางนี้เข้า Decision log + `backtest-optimize-rigor` skill + หัว spec ORDER-036

---

## PQ-03 — Tracking-error bands ใน /ea-monitor — `LOCKED` · ทำได้: Codex (spec ตรึงแล้ว)

**Design (ตรึงแล้ว — นิยามเดียวกับ runbook §2.1 เพื่อไม่ให้มีสองสูตร):**
- input ต่อ EA: `PF_expected`, `trades/เดือน_expected` (จาก validation, จดตอน deploy ลง DEMO_DEPLOYMENT_PLAN)
- ทุกONCE monitor: คำนวณ PF ratio + trade-rate ratio → ธง:
  🟢 ปกติ = PF ratio [0.6,1.8] และ rate [0.5,2.0] · 🟡 สอบสวน = หลุดช่วงใดช่วงหนึ่ง <2 รอบติด ·
  🔴 probation/kill = PF ratio <0.6 ที่ ≥20 trades (ตามลำดับ runbook §2)
- **Implement:** ต่อยอด `/ea-monitor` skill — เพิ่มคอลัมน์ expectation + ratio + ธง ใน report ·
  expectation เก็บเป็นตาราง csv `portfolio/expectations.csv` (1 fact 1 owner — ที่เดียว)
- **Acceptance:** รันบน deals จริง → ธงตรงกับที่คำนวณมือ 3 ตัวอย่าง · ไม่มี EA ไหนไม่มี expectation row

---

## ลำดับตอน unlock

1. PQ-02 ก่อน (ครึ่งวัน, ไม่มีโค้ด) → 2. PQ-03 (Codex, มี cage เทียบมือ) → 3. PQ-01 (ใหญ่สุด —
   Claude คุมสูตร, Codex เขียน script + blind review) · ทุกชิ้นตาม additive rule: ไม่แตะ EA live,
   ทุก output เป็นข้อเสนอให้อนุมัติ
