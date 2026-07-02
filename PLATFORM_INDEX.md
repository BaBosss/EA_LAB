# PLATFORM_INDEX — แผนที่ 5 ที่อยู่ทางกายภาพ

> อัปเดต 2026-06-14 · ตรวจ 2026-06-25 · กฎ: **D:\ เป็นหลัก · OneDrive = backup · D:\EA_LAB อยู่ใน git**
>
> ⚠️ **ไฟล์นี้ = แผนที่ "ที่อยู่ 5 ก้อน" (section 1) เป็นค่าหลักที่ยังถูกต้อง.**
> สถานะ EA / cleanup-task ด้านล่าง (section 3, 5) เป็น **log เก่า 06-14** — ของจริงดูที่:
> สถานะ portfolio → `DEMO_DEPLOYMENT_PLAN.md` · ทะเบียน EA → `EA_SCORECARD_AND_REGISTRY.md` ·
> โครง EA_LAB ภายใน → `README.md`. (เช่น GSMC ใน section 3 ถูก **DISQUALIFIED** ไปแล้ว)

---

## 1. ที่อยู่ทั้งหมด (5 ก้อน)

| # | ที่อยู่ | คือ | สถานะ |
|---|---|---|---|
| 1 | **`D:\EA_Project\CURRENT_BUILD`** | EA_CORE_V1 — MQL5 framework (source) | governed, 1317 PASS, metadata-only (ยังไม่เทรดจริง) |
| 2 | **`D:\EA_LAB`** | คลังวิจัย/หลักฐาน + automation + ต่อ EA แต่ละตัว | **canonical** · git tracked |
| 3 | **`D:\Forex`** | idea bank + คลัง optimization + ความรู้ + chat ที่กู้มา | archive/แหล่งอ้างอิง |
| 4 | **`C:\Users\patip\.claude\skills`** | 7 skill pipeline = สมองให้คะแนน/ตัดสิน + script python | ติดตั้งแล้ว |
| 5 | `C:\Users\patip\OneDrive\.Codex` | backup ของ EA_LAB + ของที่ยังไม่ก็อป | backup only |

**ราก D:\EA_Project** → `CURRENT_BUILD` (source), `RELEASES` (snapshot timestamped = source of truth), `claude_review_handoff_pack_full` (handoff)
**ราก D:\Forex** → `10_EA_PROJECTS`, `20_Selected EA`, `30_OPTIMIZATION` (report จริงทั้งหมด), `50_KNOWLEDGE\IDEA_BANK` (20 cards + chat ที่กู้มาใน `_chat_archive\gpt_export_20260612`)

---

## 2. โครงข้างใน D:\EA_LAB (หลังจัดบ้าน 2026-06-14)

| โฟลเดอร์ | คือ |
|---|---|
| root *.md | canonical = `PROJECT_STATE`(entry) · `DEMO_DEPLOYMENT_PLAN` · `MASTER_BACKLOG` · `EA_SCORECARD_AND_REGISTRY` · `INTAKE_QUEUE` · `README` · `PLATFORM_INDEX`(นี่). เก่า/deprecated → `_archive_docs/` (2026-06-29: _RESUME_HERE, QWEN_WORK_PLAN). RUN_REGISTRY.* = gitignored (auto-gen, deprecated) |
| `ea_projects/` | งานจริงต่อ EA — ดูข้อ 3 |
| `docs/` | เอกสารดีไซน์ทั้งหมด · **`RECOVERED_PLATFORM_DESIGN_20260614.md` = สมองที่กู้มา (อ่านอันนี้)** · `EA_CORE_AND_TEMPLATE_GUIDE.md` = สถาปัตยกรรม+วิธีใช้ EA_CORE/EA_Template (2026-07-02) · `_legacy_manual/` = doc เก่าตกยุค |
| `scripts/` | automation (collect_mt5_reports, export_reports, import_manual_run...) ⚠️ **path ยังชี้ OneDrive ต้องแก้** |
| `skills/` | สำเนา .md ของ skill (ตัวจริงอยู่ที่ `.claude\skills`) |
| `portfolio/` | candidate/portfolio (EA_CANDIDATE_MASTER.xlsx) — ✅ รวม central_results เข้ามาแล้ว 2026-06-29 |
| `_mt5_report_drop/` | inbox วาง report MT5 (oos/optimization/single/_needs_project) |
| `ACTIVE/` `ARCHIVE/` `SYSTEM/` `handoff/` | โครงเดิมจาก OneDrive lab (projects, manifests, rules) |
| `strategy_idea_bank/` | STRATEGY_IDEA_BANK.xlsx (idea bank ตัวเต็มอยู่ D:\Forex) |
| `templates/` `logs/` `_conventions/` | เบ็ดเตล็ด |

*`EA_LAB_MASTER_SPEC.md` บางส่วนตกยุค (เขียน "no parser / Codex WAIT") — ยึด PLATFORM_INDEX + RECOVERED_PLATFORM_DESIGN แทน

---

## 3. EA ที่มีอยู่ (`ea_projects/`) + ตัวที่ validated แล้ว

| โปรเจกต์ | คือ | สถานะ |
|---|---|---|
| **Gold SMC continuous** | XAU mean-reversion (source .mq5/.ex5 + risk_cap_v1) | ✅ **OOS_VALIDATED** PF 1.31→1.11, DD 12→18% |
| **EA_GoldenEmber_Pivot** | NZDUSD pivot-range | ✅ validated (RUN_0004/0005 backtest ค้าง) |
| EA_CORE_V1_TESTBED | ที่เก็บ report ของ EA_CORE_V1 | report XAUUSD รอ parse |
| Matchagrid | grid EA | preliminary |
| `_TEMPLATE_EA_PROJECT` | เทมเพลตโปรเจกต์ (เหลือตัวเดียว — `_template` ถูกลบ/รวมไปแล้ว, ตรวจ 2026-07-02) | ✅ ใช้ตัวนี้ |
| `Gold` | โฟลเดอร์ขยะ (ว่างซ้อน) | ลบทิ้งได้ |

**EA validated ตอนนี้มี 3 ตัว:** Gold SMC (XAU), Pivot (NZDUSD), EX197 (GBPJPY, อยู่ idea bank) → พอเริ่มทำ portfolio port แรกได้

---

## 4. Workflow โดยย่อ (รายละเอียดเต็มใน `docs/RECOVERED_PLATFORM_DESIGN_20260614.md`)

```
ไอเดีย → build EA (จาก template) → backtest → optimize (Pass 0/1/2) → Single Test ยืนยัน
       → OOS (เปลี่ยนแค่ช่วงวันที่ freeze .set) → robustness (Monte Carlo)
       → candidate → portfolio (correlation 2-3 EA/port) → demo ≥3 เดือน → live micro
```
- **ระบบคะแนน canonical** = BacktestScore v1 (EA_Monitor) · `DeployScore = BT × Robust × RiskControl`
- **เป้า:** 10 port × 10,000 cent × 2-3 EA ที่ไม่ correlate กัน

---

## 5. งานที่ยังค้าง (cleanup / next)

| งาน | ระดับ |
|---|---|
| แก้ path ใน `scripts/` จาก OneDrive → D:\EA_LAB (ไม่งั้น automation พัง) | ต้องทำก่อนใช้ automation |
| ~~รวม template ซ้ำ (`_template` + `_TEMPLATE_EA_PROJECT`)~~ | ✅ เหลือตัวเดียวแล้ว (ตรวจ 2026-07-02) |
| ~~ลบโฟลเดอร์ขยะ `ea_projects/Gold`~~ | ✅ ลบแล้ว 2026-07-02 (ที่จริงเป็น compile log หลงทาง ไม่ใช่โฟลเดอร์) |
| ~~รวม `central_results` + `portfolio`~~ | ✅ done 2026-06-29 |
| ก็อป `.Codex\Optimize` (305 MB คลัง report) → `D:\Forex\30_OPTIMIZATION` | ตัดสินทีหลัง |
| ทำ PROJECT_MASTER_SPEC (EA_Project) อัปเดต baseline 1317 | EA_CORE track |

---

## 6. บทบาท / กฎทำงาน
- **Claude = คนสร้างหลัก** (ทุกชั้น) · **Codex = ผู้รีวิวอิสระ/module แยกขาด** (สั่งจาก Claude ไม่ได้)
- ความจริงอยู่ในไฟล์เสมอ · ของก้อนใหญ่กลั่นด้วย script ก่อน ไม่โหลดดิบ
- D:\EA_LAB commit git ทุกงานใหญ่ · OneDrive sync เป็น backup
