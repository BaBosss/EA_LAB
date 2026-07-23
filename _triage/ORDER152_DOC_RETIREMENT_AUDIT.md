# ORDER-152(c) — Doc retirement audit + disposition proposal

> เขียน 2026-07-23 (Opus-seat) · **เสนอเท่านั้น — ยังไม่ลบ/ย้ายอะไรทั้งสิ้น** ตาม ห้าม ของ ORDER-152
> ขอบเขต: `*.md` ที่ root + `docs/` + `_archive_docs/` · เกณฑ์ = anti-drift §0.5 ของ PROJECT_STATE ("1 fact มี owner เดียว")

## สรุปขนาด

| ที่ | จำนวน |
|---|---|
| `.md` ที่ repo root | 29 |
| `.md` ใน `docs/` | 10 (+ `_legacy_manual/`, `memory_control/`, `superpowers/`) |
| ไฟล์ใน `_archive_docs/` | 20 |

## A. ปิดจบแล้วในใบนี้ (ไม่ต้องทำอะไรต่อ)

| ไฟล์ | ปัญหา | ทำอะไรไป |
|---|---|---|
| `AGENTS.md` §1.5 + §5.1 | ระบุ default งาน code = Codex-direct ขัดกับ Decision log 2026-07-16 (Claude-author + Codex audit-only) | ✅ แก้แล้ว — แยกเป็น core/money code (Claude เขียน) vs tooling (Codex/Sonnet เขียนได้) + เพิ่ม §5.2 อธิบายเส้นแบ่งและเหตุผล |
| `ea_template/OPTIMIZATION_PROCEDURE_V2.md` | ยัง DRAFT + ใช้ศัพท์ verdict ที่ retire แล้ว (`DEAD`/`PARKED`/`SYMBOL_LOCAL`) ชนกับ VERDICT GATE | ✅ แก้แล้ว — banner "ไฟล์นี้ไม่ own verdict" + §13.0 ตาราง map stage-label → canonical vocabulary + ชี้ ENGINE-EDGE / M4-on-grid ที่บทนี้ขาด |

## B. เสนอให้ retire / merge — ✅ EXECUTED 2026-07-23 (session ORDER-152(c) continuation, path-limited commit)

| ไฟล์ | สถานะที่พบ | เสนอ | ผลจริง |
|---|---|---|---|
| `OPTIMIZE_PROCEDURE_AND_AUDIT.md` | มี banner `⚠️ SUPERSEDED (2026-07-18)` เองอยู่แล้ว | ย้ายเข้า `_archive_docs/` | ⏸ ยังไม่ทำรอบนี้ (out of scope ของรอบนี้ — เหลือถ้ามีรอบถัดไป) |
| `docs/RECOVERED_PLATFORM_DESIGN_20260614.md` | artifact กู้คืน date-stamped | ตรวจว่าเนื้อถูกดูดเข้า `PLATFORM_INDEX.md`/`docs/PIPELINE.md` ครบหรือยัง | ⏸ ยังไม่ทำรอบนี้ (ต้องเช็คเนื้อละเอียด — เหลือถ้ามีรอบถัดไป) |
| `DEPLOY_CHECKLIST_2026-06-29.md` | date-stamped, deployment plan ตัวที่ 3, README เองระบุ "ephemeral — ลบได้หลัง deploy เสร็จ" | merge เข้า `DEMO_DEPLOYMENT_PLAN.md` แล้ว archive | ✅ **เช็คแล้ว — เนื้อ (3 magic 990010/991001/991002 + set path + verify step) ถูก capture ครบใน `DEMO_DEPLOYMENT_PLAN.md` §ARCHIVE (บรรทัด 70-71, 215-221) อยู่แล้วตั้งแต่ก่อนหน้า ไม่ต้อง merge เพิ่ม** → ย้าย `_archive_docs/DEPLOY_CHECKLIST_2026-06-29.md` + แก้ path reference ใน PROJECT_STATE.md/README.md |
| `DEPLOYMENT_PLAN.md` | ทับกับ `DEMO_DEPLOYMENT_PLAN.md` | ตรวจว่าต่างกันจริงไหม → ถ้าเป็นรุ่นเก่า archive | ✅ **ตรวจแล้ว — ไม่ใช่รุ่นเก่าซ้ำกัน** เป็น plan คนละเรื่อง (EA_RUNNER_v1 standalone magic 5001 + GSMC/MatchaGrid basket, ไม่อยู่ใน 9-EA demo portfolio) ไฟล์มี banner ระบุ scope แยกอยู่แล้ว ("แยกคนละเรื่องกับ 9-EA demo portfolio") → **เก็บไว้ตามเดิม ไม่ย้าย** (ย้ายไปอยู่กลุ่ม D แทน) |
| one-off analysis ที่ root: `EA_CORE_ST03_LOOP_PLAN.md` · `MT4_GOLDGRID_RETEST_PLAN.md` · `RSI_FROM_PIPS_REVERSE_ENGINEERING.md` · `STRATEGY_200_ANALYSIS.md` · `ZEUS_GOLD_HEDGE_ANALYSIS.md` | เป็นเอกสารวิเคราะห์จบแล้ว ไม่ใช่ doc ที่ยังเดิน | ย้าย `_archive_docs/` | ✅ ย้ายครบ 5 ไฟล์ + แก้ path reference ใน PROJECT_STATE.md/README.md/MASTER_BACKLOG.md (เฉพาะ hub doc ที่ไม่มี concurrent-session edit ค้าง — `docs/EA_CORE_AND_TEMPLATE_GUIDE.md` ข้ามไว้เพราะ session อื่นกำลังแก้ไฟล์นั้นอยู่) |
| `portfolio/port_01/` | 5 โฟลเดอร์ว่าง มีแต่ `.gitkeep` ไม่ถูกแตะตั้งแต่ 2026-05-29 | ลบทิ้ง | ✅ ลบแล้ว (`git rm -r`) |
| `_archive_docs/QWEN_RUN_LOG.md` + `QWEN_RUN_LOG_updated.md` | ชื่อซ้ำคู่ | รวมเป็นไฟล์เดียว | ✅ **ตรวจแล้ว — `QWEN_RUN_LOG_updated.md` (84 บรรทัด) เป็น subset ล้วนของ `QWEN_RUN_LOG.md` (189 บรรทัด, ทุกบรรทัดตรงกัน 100%)** ทั้งที่ชื่อ "_updated" แต่จริงๆเก่ากว่า/สั้นกว่า (จบที่ 2026-06-29 20:00 vs อีกไฟล์จบ 2026-06-30 08:34) → ลบ `_updated` ทิ้ง ไม่มีเนื้อหาหาย |

**เช็คหลังย้าย/ลบทุกไฟล์:** `powershell -File scripts/check_state.ps1 -Strict` → CLEAN.

## C. 🔴 ไม่ใช่แค่รก — เสี่ยงจริง (เสนอให้จัดการก่อนข้ออื่น)

**`.claude/worktrees/great-mendeleev-a35c44/` = สำเนา repo ทั้งก้อนค้างอยู่** (มี root docs + `_mt5_auto/` + `scripts/set_from_robust.py` ครบ)

ทำไมนี่ต่างจากไฟล์รกทั่วไป: memory `shared-worktree-concurrent-writers` บันทึกไว้แล้วว่าเคยเจอ **2 session แชร์ working tree เดียวกันแล้วกวาดงานกันเอง** · worktree ค้างที่มีสำเนา doc/script ครบ = (1) grep/inventory ทุกครั้งจะเจอผลซ้ำจาก tree เก่า (inventory รอบนี้ก็เจอ — ต้องกรองออกมือ) (2) แก้ผิดต้นฉบับได้ (3) กิน disk

**เสนอ:** ตรวจว่ามี commit ค้างใน worktree นั้นไหม (`git worktree list` + `git -C <path> status`) → ถ้าสะอาด ให้ `git worktree remove` · **ถ้ามีงานค้าง ต้องรายงาน user ก่อน ห้ามลบ**

## D. เก็บไว้ตามเดิม (ไม่ใช่ของซ้ำ — เข้าใจผิดง่าย)

| ไฟล์ | ทำไมเก็บ |
|---|---|
| `AGENT_TASKBOARD_MERGE.md` · `AGENT_TASKBOARD_PQUANT.md` · `ARCHIVE_TASKBOARD_2026-07A.md` | ไม่ใช่ taskboard ซ้ำ — เป็น **track แยกที่มีสถานะต่างกัน** (MERGE=CLOSED, PQUANT=LOCKED รอ judge, ARCHIVE=ของเก่า) · แต่ละไฟล์มี banner ระบุขอบเขตแล้ว |
| `PROJECT_STATE_SESSIONLOG_ARCHIVE.md` | ตั้งใจแยกเพื่อลดขนาด AI-START-HERE (2026-07-12) |
| `STATUS.md` / `STATUS.html` | generated artifact (`make_status.ps1`) ไม่ใช่ doc ที่คนเขียน |
| `ea_template/modules/` (V1) คู่กับ `core/` (V2) | PROJECT_STATE ระบุชัด "ซ้ำโดยตั้งใจ ไม่ใช่ขยะ" |

## ขั้นถัดไป

1. user เคาะ B + C (C ก่อน — เป็นความเสี่ยงไม่ใช่ความรก)
2. การย้าย/ลบจริง = **order แยก** (ใบนี้ ห้าม แตะไฟล์) และต้องรัน `scripts/check_state.ps1 -Strict` หลังย้ายทุกครั้ง เพราะ checker ผูกกับ path ของ doc
