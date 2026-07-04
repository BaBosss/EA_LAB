# ROADMAP — จากวันนี้ถึง "ระบบหมุนเอง" (เขียน 2026-07-03, Claude Fable ก่อนส่งไม้ Opus)

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **ภาพสุดท้าย + เฟสงานระยะยาว + เงื่อนไขเลื่อนเฟส
> เท่านั้น** — สถานะปัจจุบัน/แผนรายสัปดาห์อยู่ PROJECT_STATE §7 · คิวงานจริงอยู่ AGENT_TASKBOARD.md
> อัปเดตไฟล์นี้เฉพาะเมื่อ "เฟสเปลี่ยน/เป้าเปลี่ยน" (Claude/user เท่านั้น)

**พารามิเตอร์จาก user (2026-07-03):** จบ = ระบบหมุนเอง user operate เบาๆ · 10 พอร์ต = 10 account
แยกจริง (10,000 cent/account) · ผ่าน judge แล้ว **live micro ทันที** · เวลา user 2–4 วัน/สัปดาห์

---

## 1. ภาพสุดท้าย (END STATE — นิยาม "จบ")

| ชิ้น | สภาพสุดท้าย |
|---|---|
| **Live** | 10 account × 2–3 EA ที่ corr ≤0.40 ระหว่างกัน × 10,000 cent → passive income · ทุก EA มี kill-switch + judge date ของตัวเอง |
| **EA_LAB** | โรงงานหมุนเป็น loop มาตรฐาน: ไอเดีย → mold → smoke+probe → IS/OOS+MC → demo ≥3 เดือน → live → monitor รายเดือน → kill/promote · ทุกขั้นมี script+cage, งานรันทั้งหมดอยู่บน taskboard ให้ Codex/ZCode |
| **EA_Template (Boss V2)** | แม่พิมพ์เดียวของโรงงาน: entry library โตเรื่อยๆ (14, 15, ...) · mechanics ครบและ**ผ่าน backtest แล้ว** (grid/DCA/LOG/hedge/recovery) · ทุกการแก้ core ผ่าน tpl_regression |
| **EA_CORE** | คลังอะไหล่ถาวร — หยิบ module เมื่อต้องการ (ตัวแรกที่คาดว่าจะถูกหยิบ: ScaleExecutor_v2 → Stack mode "pyramid") · ไม่พัฒนาเป็น chassis แข่ง |
| **EA_Project\TEMPLATE** | ที่อยู่ standalone legacy — ของใหม่ทุกตัวเกิดในแม่พิมพ์ ไม่มี standalone ใหม่ถาวร |
| **User** | operate: อ่านรายงาน monitor + ตัดสิน kill/promote + เติม order ใหญ่ — เป้าช่วง cruise ≤ 1 วัน/สัปดาห์ |

**ตัวชี้วัดว่า "ถึงแล้ว":** เปิดพอร์ตใหม่ 1 พอร์ตใช้แรง user แค่ "อนุมัติ + โอนเงิน" — ที่เหลือระบบ+AI ทำ

---

## 2. เฟสงาน (เงื่อนไขเลื่อนเฟส = gate จริง ไม่ใช่วันที่)

### Phase 0 — ปิด Fable window (ตอนนี้ → 7 ก.ค.) ✅ เกือบครบ
- [x] VISION / AGENTS / TASKBOARD / regression cage / Boss_14 + candidates / กฎ verdict ครบ 3 ข้อ
- [ ] Codex/ZCode เคลียร์ ORDER-001..003 (GBPAUD IS-opt, probe 3 symbol, MC)
- [ ] Claude (Fable หรือ Opus) review + verdict รอบแรกจาก taskboard
- **Gate → Phase 1:** taskboard loop หมุนครบ 1 รอบ (order → done → reviewed) โดยไม่มีของพัง

### Phase 1 — Boss_14 family validation (ก.ค.)
- GBPAUD: plateau-center จาก IS-opt → OOS confirm → MC → `robustness-validator` → ถ้าผ่าน = **deploy demo** (magic ใหม่ 9902xx, WATCH tier)
- EURJPY / EURCAD / USDJPY / AUDNZD: ทางเดียวกันทีละตัว (ZCode รัน, Claude ตัดสิน)
- corr matrix ภายใน family (`_mt5_auto/corr_monthly.py`) — ระวัง AUD-heavy ซ้อน exposure กับ 9 EA เดิม
- probe ที่เหลือ 9 symbol PARKED (ถูกมาก ~15 นาที/ตัว) — ปิดทะเบียนให้ครบ
- **Gate → Phase 2:** ทุก candidate มี verdict สุดท้าย + ตัวที่ผ่านขึ้น demo แล้ว

### Phase 2 — Mechanism expansion + operate (ส.ค. → judge)
- **Validate Hedge/Recovery ที่ยังไม่เคย backtest:** A/B order — EA เดิม + เปิดโหมดทีละตัว (81/82/83, HEDGE_LOCK) เทียบ PF/DD กับ baseline → โหมดไหนช่วยจริงถึงเข้า production set ได้
- **Sweep แกนใหม่:** SELL-side GridLog (optimizer เห็นสัญญาณ PF สูงแต่บาง) · Boss_11/12/13 entries × mechanics ใหม่ × symbol ที่ยังไม่แตะ — ทุกรอบใช้สูตร: set 0.25x + year-split + probe-before-kill
- port `ScaleExecutor_v2` จาก EA_CORE เป็น Stack mode — **เฉพาะเมื่อ**มี signal ผ่าน validate ที่ต้องการ pyramid จริง (อย่าสร้างเปล่า)
- **Operate 9 EA:** `/ea-monitor` ทุก 2 สัปดาห์ (user ส่ง live_deals.csv) — จับตา ST03 replica (คาด kill), MG grid DD, Gold Reaper
- **Gate → Phase 3:** ถึงวัน judge + มี candidate bench ≥3 ตัวที่ demo อยู่

### Phase 3 — Judge + พอร์ตจริงแรก (22 ก.ย. → ต.ค.)
- attribution per (magic,symbol) → kill/keep 9 EA เดิม · ตัวผ่าน (PF≥1.40, ≥30 trades) = promote pool
- **ประกอบพอร์ต #1:** 2–3 EA ดีสุดที่ corr ≤0.40 (`portfolio-selector`) → **live micro account จริงทันที** (ตาม user decision) → `live-deployment-controller` + `vps-deploy-ops` เต็มรูป
- demo account เดิม = โรงเพาะ cohort ถัดไป (EA ใหม่ทุกตัวยังต้อง demo ≥3 เดือนก่อน live — กฎเหล็กไม่เปลี่ยน)
- ตั้ง **ปฏิทิน re-opt ทุก 6 เดือน** ของทุก EA live (เริ่มนับจากวัน live ของแต่ละตัว) — ใส่ MASTER_BACKLOG
- **Gate → Phase 4:** พอร์ต #1 live ครบเดือนแรกโดย monitor loop ทำงานจริง

### Phase 4 — Scale ทีละพอร์ต (Q4 2026 → 2027+)
- **กฎเปิดพอร์ตใหม่:** เปิดได้เมื่อ bench มี 2–3 EA validated + demo-proven + corr ≤0.40 กับ*ทุกพอร์ตที่ live อยู่* — ห้ามเปิดเพราะ "อยากครบ 10" (พอร์ตคุณภาพต่ำ = ลาก DD รวม)
- จังหวะที่คาดหวัง: พอร์ตใหม่ ~ทุก 1–2 เดือนถ้าโรงงานผลิต candidate ทัน → 10 พอร์ตราว กลาง–ปลาย 2027 (ขึ้นกับ edge จริง ไม่ใช่ความขยัน — อย่า force)
- ทุนต่อพอร์ต = user เติม 10,000 cent ต่อ account ตอนเปิด · risk รวมทุกพอร์ต = ไม่มี EA ซ้ำ symbol+กลไกข้ามพอร์ตแบบ corr สูง
- automation เพิ่มตามจำเป็น: monthly report รวมทุก account, MT5 instance ที่ 2 (D:\Meta 5b) เมื่อคิว backtest แน่น

### Cruise state (ตลอดไป)
รอบเดือน: monitor ทุกพอร์ต → kill/promote → re-opt ตามปฏิทิน → โรงงานหา edge เติม bench ต่อเนื่อง (dual-track ตาม VISION) · user ≤1 วัน/สัปดาห์

---

## 2.5) HUNT QUEUE ถาวร — แหล่งไอเดีย EA ใหม่ เรียงตามลำดับขุด (ยืนยันโดย user 2026-07-04:
"หาไอเดียใหม่ทำเพิ่มเรื่อยๆ = แผนยาวของเรา" — ตรง dual-track ใน VISION)

| ลำดับ | เหมือง | ของที่มีรอแล้ว | วิธีเข้า pipeline |
|---|---|---|---|
| 1 | **แกนกลไกที่ยังไม่ sweep ในแม่พิมพ์เอง** | SELL-side GridLog เต็มรูป (EURUSD SELL ผ่านแล้ว = มีสัญญาณ!) · Boss_11/12/13 entries × mechanics ใหม่ · Hedge/Recovery A/B บน config ที่ชนะ | ถูกสุด — sweep สูตรเดิม (probe→OOS→M4) |
| 2 | **Treasure trove (คัดแล้ว)** | source 20 ตัว (momentum 13 + breakout 7 จาก `_triage/ea_src_triage.csv`) + novelty list | Claude อ่าน → กลไกน่าสนใจ = เข้าแม่พิมพ์แบบ Zeus→Boss_14 |
| 3 | **PDF strategy books** | 49 เล่ม (worth_deep_read 67 จาก `_triage/pdf_catalog.csv`) + STRATEGY_200 ที่เหลือ (#94 Turtle ฯลฯ) | อ่านสกัดกฎ → เขียน entry ใหม่ในแม่พิมพ์ |
| 4 | **ของใหม่จากกลุ่ม LINE/Telegram** | user โยนไฟล์ลง `D:\Forex\10_EA_PROJECTS\2. wait for test` ได้เรื่อยๆ | รัน `ea_inventory.py` ซ้ำ → เข้าคิว triage อัตโนมัติ |

**กติกาจังหวะ (กัน pipeline บวม):** คอขวดจริงคือกำลัง validate ไม่ใช่ไอเดีย — ป้อนเข้า smoke
**~1 concept ใหม่/สัปดาห์พอ** · funnel จริงจากข้อมูลเรา: 21 symbols → 6 demo · 50 MT4 EA → 0 ·
คาดหวังจากเหมือง = "กลไก" ไม่ใช่ "EA สำเร็จรูป" · ทุก concept ตายให้บันทึกใน scorecard เสมอ (กัน re-hunt)

## 3. Development backlog ของระบบ (delegate ได้ — Claude เขียนเป็น order เมื่อถึงคิว)

| งาน | เฟส | มอบใคร |
|---|---|---|
| **`_2_BasketTP_ATRmult`** — basket TP แบบ ATR-scaled (additive, default 0=$ เดิม) — จาก self-review 2026-07-04: $-TP ไม่ scale ข้าม instrument class · **ทำก่อน sweep non-FX ครั้งแรกเสมอ** · validate ด้วย ab_mode_test เทียบ $TP vs ATR-TP · lot% มีแล้ว (mode 42) ไม่ต้องสร้าง | ก่อน sweep metals/index | oc-dev + regression cage |
| Walk-forward automation (script รัน rolling window + สรุป) | 1 | Codex |
| Hedge/Recovery A/B validation harness | 2 | Codex ออกแบบ order, ZCode รัน |
| Portfolio equity combiner หลาย account (ต่อยอด zigl_correlation) | 3 | Codex |
| Monthly monitor report รวมทุกพอร์ต (อ่าน live_deals หลายไฟล์) | 3–4 | Codex |
| MT5 instance 2 (D:\Meta 5b) เข้า pipeline เมื่อคิวแน่น | 4 | ZCode ตาม guide memory |
| เกษียณเอกสารซ้ำซ้อน (audit ตาม anti-drift) | ว่างเมื่อไหร่ก็ได้ | Claude |

## 4. ความเสี่ยงหลัก + กันไว้แล้วยังไง

- **Edge ผลิตไม่ทันความอยากขยาย** → gate เปิดพอร์ตผูกกับ bench ไม่ใช่วันที่
- **AUD-heavy concentration** (Boss_14 family เกิดจาก AUD) → corr gate ข้ามพอร์ต + บังคับกระจายกลไก/สกุล
- **Agent อื่นทำพัง** → single-writer + cage + review-before-build (AGENTS.md)
- **Model เปลี่ยน (Fable→Opus 7 ก.ค.)** → ความรู้ทั้งหมดอยู่ในไฟล์+memory ไม่อยู่ในหัว model · ดู CLAUDE.md §Model transition
- **Regime เปลี่ยนหลัง validate** → backward-OOS บังคับ + re-opt 6 เดือน + demo ≥3 เดือนทุกตัว
