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

## B. เสนอให้ retire / merge (รอ user เคาะ)

| ไฟล์ | สถานะที่พบ | เสนอ | เหตุผล |
|---|---|---|---|
| `OPTIMIZE_PROCEDURE_AND_AUDIT.md` | มี banner `⚠️ SUPERSEDED (2026-07-18)` เองอยู่แล้ว | **ย้ายเข้า `_archive_docs/`** | owner ย้ายไป skill `backtest-optimize-rigor` แล้ว · เก็บไว้ที่ root = เสี่ยงมีคนอ่านผิดฉบับ |
| `docs/RECOVERED_PLATFORM_DESIGN_20260614.md` | artifact กู้คืน date-stamped | **ตรวจว่าเนื้อถูกดูดเข้า `PLATFORM_INDEX.md`/`docs/PIPELINE.md` ครบหรือยัง → ถ้าครบ ย้าย archive** | ห้ามย้ายก่อนเช็ค — อาจมีเนื้อที่ไม่ถูก port |
| `DEPLOY_CHECKLIST_2026-06-29.md` | date-stamped, deployment plan ตัวที่ 3 | **merge เข้า `DEMO_DEPLOYMENT_PLAN.md` แล้ว archive** | anti-drift: deployment context ต้องมี owner เดียว |
| `DEPLOYMENT_PLAN.md` | ทับกับ `DEMO_DEPLOYMENT_PLAN.md` | **ตรวจว่าต่างกันจริงไหม → ถ้าเป็นรุ่นเก่า archive** | ถ้าเก็บทั้งคู่ ต้องใส่ banner ระบุว่าแต่ละไฟล์ own อะไร |
| one-off analysis ที่ root: `EA_CORE_ST03_LOOP_PLAN.md` · `MT4_GOLDGRID_RETEST_PLAN.md` · `RSI_FROM_PIPS_REVERSE_ENGINEERING.md` · `STRATEGY_200_ANALYSIS.md` · `ZEUS_GOLD_HEDGE_ANALYSIS.md` | เป็นเอกสารวิเคราะห์จบแล้ว ไม่ใช่ doc ที่ยังเดิน | **ย้าย `_archive_docs/`** (ST03 ถูกถอดจากบัญชีจริงแล้ว, goldgrid = all fail) | ลด root จาก 29 → ~24 · เนื้อยังค้นได้ + memory ชี้อยู่แล้ว |
| `portfolio/port_01/` | 5 โฟลเดอร์ว่าง มีแต่ `.gitkeep` ไม่ถูกแตะตั้งแต่ 2026-05-29 | **ลบทิ้ง** (scaffolding ที่ไม่เคยใช้) | โครงพอร์ตจริงใช้ `DEPLOYMENTS.csv` + `live_deals/` แทนไปแล้ว |
| `_archive_docs/QWEN_RUN_LOG.md` + `QWEN_RUN_LOG_updated.md` | ชื่อซ้ำคู่ | **รวมเป็นไฟล์เดียว** | อยู่ใน archive แล้ว priority ต่ำ |

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
