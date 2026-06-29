# EA_LAB

คลังวิจัย/หลักฐาน + automation pipeline สำหรับหา-validate-deploy EA portfolio
(แยกขาดจาก `D:\EA_Project` = EA_CORE_V1 framework source).

> **เป้าหมาย:** 10 พอร์ต × 2-3 EA ที่ไม่ correlate กัน × 10,000 cent → passive income

## อ่านก่อน (canonical — source of truth)

| ไฟล์ | คือ |
|---|---|
| **`PROJECT_STATE.md`** | 👉 **AI START HERE** — living state กลาง (ภาพรวม/สถานะ%/decision/monitor/แผนต่อ) เปิดก่อนเสมอ |
| `DEPLOY_CHECKLIST_2026-06-29.md` | checklist deploy วันนี้ (ST03 replica + Bars8 + reload #6 v3) |
| `EA_CORE_ST03_LOOP_PLAN.md` | แผนปิด framework loop ด้วย ST03 edge (EA_CORE ทางเลือก 2) |
| ~~`_RESUME_HERE.md`~~ | deprecated → ใช้ `PROJECT_STATE.md` แทน |
| **`DEMO_DEPLOYMENT_PLAN.md`** | พอร์ต live ที่ deploy จริง (source of truth) + .set + magic + monitoring rule |
| **`EA_SCORECARD_AND_REGISTRY.md`** | ทะเบียน EA ทุกตัว + scoring rubric + kill-reason |
| **`INTAKE_QUEUE.md`** | funnel รับ source/strategy ใหม่ (drop ลง `_intake_drop/`) |
| **`PLATFORM_INDEX.md`** | แผนที่ไฟล์/โฟลเดอร์ทั้งหมด |
| **`docs/RECOVERED_PLATFORM_DESIGN_20260614.md`** | design "สมอง" — scoring v1, gate chain, optimize Pass 0/1/2/4 |
| **`AUTOMATION_GUIDE.md`** + `docs/MT5_AUTOMATION.md` | pipeline funnel + MT5 headless mechanics |
| **`EA_STRATEGY_GUIDE.md`** | reference strategy ทุกตัวที่เคย screen |

## โครงโฟลเดอร์

- `ea_projects/` — งานราย EA (config/reports/set_files/validated_v1)
- `scripts/` — automation (mt5_run.ps1, mt5_optimize.ps1, parse_*, score_*, grid_sweep.ps1...)
- `_mt5_auto/` — locked .set + sweep results + MC json (reports/ini/logs = gitignored, regenerable)
- `_intake_drop/` — staging รับ source ใหม่ (gitignored — ดิบ, ไหลผ่าน INTAKE_QUEUE funnel)
- `docs/` — design docs · `docs/_legacy_manual/` = Codex-era manual workflow (เก็บไว้อ้างอิง)
- `_archive_docs/` — session log / plan / index เก่าที่จบแล้ว (ย้ายออกจาก root 2026-06-25)
- `skills/` — สำเนา .md ของ pipeline skills (ตัวจริงอยู่ `C:\Users\patip\.claude\skills`)

## กฎเหล็ก
- อย่าเชื่อ report เก่าบนดิสก์ — rerun ด้วย locked .set ก่อนตัดสินเสมอ
- ปิด MT5 GUI ก่อนรัน automation (script abort ถ้าเปิดอยู่)
- ของก้อนใหญ่กลั่นด้วย script ไม่โหลดดิบเข้า context · ทุกงานใหญ่ commit git
- demo ≥3 เดือนห้ามลัด · grid/martingale ใช้ report DD + every-tick ไม่ใช่ MC อย่างเดียว
