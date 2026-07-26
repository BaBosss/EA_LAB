# QUOTA FALLBACK PLAYBOOK — ทำอะไรต่อเมื่อ Claude quota หมด

> owner ของเอกสารนี้ = **วิธีให้เครื่องไม่ว่างตอน seat หลัก (Opus/Claude) ไม่อยู่** · กติกา agent ทั่วไป → `AGENTS.md` ·
> คิวงานจริง → `AGENT_TASKBOARD.md` · verdict → VERDICT GATE ใน `CLAUDE.md`
> สร้าง 2026-07-25 (user: "กลัวว่าเตรียม 10 batch แล้วรันหมดก็ไม่มีอะไรทำอยู่ดี — และผมไม่ได้ใช้ powershell/cmd")

## 0. ปัญหาที่แก้ (ระบุให้ตรง)

แผนสำรองแบบเดิม = "เตรียม order ไว้ล่วงหน้า N ใบ" → **ตายที่ N** เพราะ order แต่ละใบเป็น *รายการงาน*
(รันแล้วรายงาน) ไม่ใช่ *ทางแยก* (รันแล้วไปไหนต่อ). ทางแก้มี 3 ชั้น ใช้พร้อมกัน:

| ชั้น | แก้อะไร | อยู่ที่ไหน |
|---|---|---|
| **1. conditional order** (order 1 ใบ = ต้นไม้ 2-3 ชั้น) | order ใบเดียวเดินได้หลายรอบโดยไม่ต้องถาม | template §2 + header `AGENT_TASKBOARD.md` |
| **2. generator order** (standing, ท้ายคิวเสมอ) | คิว OPEN หมด → ยังมีงานพื้นฐานให้หยิบ | `ORDER-GEN-STANDING` ใน taskboard |
| **3. Telegram lane** (oc-qwen) | ทางแยกที่ต้นไม้ไม่ครอบ → ถาม user จากมือถือแทนรอ Claude | §4 |

**หลักเดียวที่คุมทั้ง 3 ชั้น: worker เดินต้นไม้ที่ *เลขถูกล็อกไว้ก่อนแล้ว* — worker ไม่เคยตัดสิน.**
เลขตัดสิน (bars) มาจาก VERDICT GATE และต้อง pre-register ก่อนรันเสมอ (กติกาเดิมตั้งแต่ ORDER-124+).

## 1. วงจรใหญ่

```
Claude (มีโควตา)           worker lane (qwen/ZCode/oc-qwen)        user (Telegram/มือถือ)
─────────────────          ────────────────────────────────        ──────────────────────
ตัดสินกอง DONE ค้าง   →
เขียน conditional order  →   เดินต้นไม้ branch A/B/C
เติม matrix ของ                 ↓ คิวว่าง
generator order          →   หยิบ cell ถัดไปจาก matrix
                                ↓ เจอเคสนอกต้นไม้
                             mark BLOCKED + ส่งคำถาม      →      เคาะ branch ตอบกลับ
                                ↓                                (เลือกจากตัวเลือกที่ order เขียนไว้)
                             เดินต่อ / ข้ามไปใบถัดไป
   ↑                            ↓
   └────── กองผลดิบ DONE รอ REVIEWED ←──────────────────────────┘
```

**ชั่วโมงสุดท้ายก่อนโควตาหมด ของ Claude ต้องจบด้วย 3 อย่างนี้เสมอ** (ไม่ใช่ "รัน backtest ให้ครบ"):
1. order ค้างทุกใบถูกตัดสิน (DONE → REVIEWED)
2. conditional order ชุดใหม่ ≥2 ใบ **ที่มีต้นไม้ครบทุก branch**
3. matrix ของ `ORDER-GEN-STANDING` ถูกเติมให้เหลืออย่างน้อย ~10 cell

## 2. CONDITIONAL ORDER — template บังคับ

order สำหรับ lane ที่ Claude ไม่อยู่ **ต้องมีทุกบรรทัดนี้** (ขาดข้อใด = worker ห้ามรับ):

```markdown
## ORDER-xxx — <ชื่อ> — `OPEN` · ทำได้: <agents> · 👉 แนะ: <default>
**bars:** pass = X · dead = Y · กลาง(WATCH/build-on) = Z        ← ล็อกก่อนเห็นผล ห้ามเติมย้อนหลัง
**flat-lot probe:** done / N-A(single-order) / pending
**STEP 1:** <คำสั่งรันที่ copy ไปวางได้ตรงๆ — path/symbol/TF/window ครบ>
**TREE (เดินเองได้ไม่ต้องถาม):**
  - ถ้า PF ≥ 1.2      → STEP 2A: <สเปกครบ — ขยาย symbol/TF อะไร ค่าไหน>
  - ถ้า 1.0 ≤ PF < 1.2 → STEP 2B: <สเปกครบ — fine grid ช่วงไหน step เท่าไหร่>
  - ถ้า PF < 1.0      → STOP lane นี้ · append ผลดิบ · ไป order ถัดไป (ห้ามสรุปว่า "ตาย")
  - ผลไม่เข้า branch ไหนเลย / รันไม่ผ่าน 2 ครั้ง → `BLOCKED(<คำถามพร้อมตัวเลือก A/B>)` + แจ้ง user
**ชั้นที่ 3 (ถ้ามี):** <จาก 2A/2B ต่ออีกชั้น — ลึกได้ ยิ่งลึกยิ่งกินเวลา Claude น้อย>
**ห้าม:** เขียน verdict · แตะ scorecard/EDGE_CATALOG/PROJECT_STATE/VISION · รายงาน Model-2 ·
        ตีความผลนอก branch ที่เขียนไว้ · เปลี่ยนค่าที่ไม่ได้ระบุใน STEP
```

**กติกาเขียนต้นไม้ (Claude):**
- ทุก branch ต้อง **สเปกครบพอที่จะรันได้ทันที** — "ลองปรับดู" ไม่ใช่ branch, "SL {2.5,3.0,3.5} step 0.5" คือ branch
- ปลายทุก branch ต้องเป็นหนึ่งใน 3 อย่าง: **STEP ถัดไป · STOP+ไปใบถัดไป · BLOCKED+ถาม** — ห้ามมีปลายเปิด
- ลึก 2-3 ชั้นกำลังดี (ชั้นที่ 4 มักเดาผิดจนเสียเปล่า)
- ถ้า branch ไหนต้องใช้วิจารณญาณ = เขียนผิดแล้ว ให้แปลงเป็นเลข หรือยกเป็น BLOCKED ไปเลย

## 3. GENERATOR ORDER — กันคิวว่าง

`ORDER-GEN-STANDING` = order ใบเดียวที่ **อยู่ท้ายคิวถาวร ไม่มีวัน DONE** — เปิดตลอด, worker หยิบได้ก็ต่อเมื่อ
**ไม่มี order OPEN อื่นเหลือแล้วเท่านั้น**. เนื้อใน = matrix ที่ Claude เติมไว้ (symbol × TF × lever × window)
พร้อม template คำสั่งรัน 1 แบบ. worker หยิบ cell บนสุดที่ยังไม่มีผล → รัน → append ผลดิบ → ทำเครื่องหมาย cell → cell ถัดไป.

- generator order **ไม่ใช่ข้อยกเว้นของกฎ "ไม่มี order OPEN + Claude ไม่อยู่ → หยุด อย่าคิดงานใหม่เอง"**
  (`AGENTS.md` §4) — มันคือ order ที่ Claude เขียนไว้ล่วงหน้าแล้ว งานทุก cell ผ่านสมอง Claude มาก่อน worker ไม่ได้คิดเอง
- ผล generator = **ผลดิบสำรวจ (screening) เท่านั้น** ห้ามใช้เป็นหลักฐาน promote อะไรทั้งสิ้น จนกว่า Claude review
- matrix หมด → worker mark `BLOCKED(matrix หมด)` + แจ้ง user แล้วหยุด (นี่คือจุดเดียวที่ยอมให้เครื่องว่างได้)

## 4. TELEGRAM LANE (oc-qwen) — สั่งจากมือถือ ไม่ต้องแตะ powershell/cmd

**ทำไมคุ้ม:** ข้อเสียเดิมของ OpenClaw = layer manager กิน ChatGPT quota ก้อนเดียวกับ oc-dev/Codex
(`AGENTS.md` §5.1). พอ agent เป็น **qwen key คนละเลน** → overhead นั้นไม่แตะ ChatGPT quota อีกต่อไป
= ได้ความสะดวก remote มาฟรี. ⇒ **oc-qwen = ค่า default ของงาน batch ตอน seat ไม่อยู่.**

**สิ่งที่ user สั่งได้จาก Telegram (ไม่ต้องเปิดคอม):**
| พิมพ์ | ได้อะไร |
|---|---|
| `next` | หยิบ order OPEN บนสุดที่ทำได้ → รัน → สรุปสั้นกลับมา |
| `status` | order ไหน CLAIMED/DONE/BLOCKED บ้าง + cell generator เหลือเท่าไหร่ |
| `branch A` / `branch B` | ตอบทางแยกที่ worker ถาม (ตัวเลือกมาจาก order ไม่ใช่ worker คิดเอง) |
| `stop` | หยุด lane ทิ้งงานค้างไว้ให้ Claude |

**เส้นแดง oc-qwen (เขียนซ้ำในทุก order · ต่อให้ user สั่งผ่าน Telegram ก็ห้าม):**
1. ❌ เขียน/แก้ **verdict** ทุกรูปแบบ — คำว่า DEAD/CANDIDATE/DEMO/BUILD-ON เป็นของ Claude เท่านั้น
2. ❌ แตะ `EA_SCORECARD_AND_REGISTRY.md` · `EA_MASTER_INDEX.csv` · `EDGE_CATALOG.md` · `PROJECT_STATE.md` ·
   `VISION.md` · `CLAUDE.md` · `AGENTS.md` · `B1_DATASET.csv` — เขียนได้ไฟล์เดียวคือ **แถว order ที่ตัว claim ใน taskboard**
3. ❌ แตะ source (`.mq5` / `ea_template\core\`) — qwen ไม่ใช่เลน code (`AGENTS.md` §5.1: ZCode/qwen ห้ามแตะ source)
4. ❌ deploy / แก้ .set ของ EA ที่รัน demo อยู่ / แตะ `_vps_deploy`
5. ❌ ตีความผลนอก branch — ตอบได้แค่ "เลขนี้เข้าช่องไหนของ bars ที่ล็อกไว้"
6. ✅ ต้องทำ: append ผลดิบ **ทั้งก้อน** (ห้ามสรุปทิ้งตัวเลข) · commit tag `[oc-qwen]` · เจอไม่เข้าช่อง = BLOCKED + ถาม

**สรุปแบบสั้นที่ worker ต้องส่งกลับ Telegram ทุกรอบ (4 บรรทัด ห้ามเกิน):**
```
ORDER-xxx STEP 1 done · PF 1.31 / trades 84 / DD 6.2%
→ เข้า branch: PF≥1.2 → STEP 2A (ขยาย GBPUSD H1)
→ กำลังรัน 2A ต่อ (ETA ~20 นาที)
ผลดิบเต็ม: taskboard ORDER-xxx (commit abc1234)
```

## 5. ON-RETURN (Claude โควตากลับมา) — ไม่เปลี่ยนจากเดิม

1. `git log --oneline -20` หา commit `[oc-qwen]`/`[qwen]`/`[zcode]`
2. อ่านแถว DONE/BLOCKED ใน taskboard — **ตัดสิน BLOCKED ก่อน** (นั่นคือจุดที่ระบบติด)
3. เดิน VERDICT GATE ให้ครบต้น → Row-X write-checklist → mark REVIEWED
4. **ก่อนหมดโควตารอบถัดไป: เขียนต้นไม้ชุดใหม่ + เติม matrix** (§1 ข้อ 3)

⚠️ อย่าสร้าง verdict จากผล generator เพียวๆ — มันคือ screening ไม่ได้ผ่าน ladder

## 5.5 CONTEXT BUDGET — qwen มี ~200k ต้องวางแผน (user Q 2026-07-25)

**หลัก: state ของงานอยู่ใน git ไม่ใช่ใน context.** ถ้าออกแบบถูก session ตายกลางทาง = งานไม่หาย
เปิดใหม่แล้วเดินต่อจาก taskboard ได้เลย. ⇒ กฎ 5 ข้อ (บังคับใน system prompt §6):

1. **1 order = 1 session** — จบ order แล้วปิด session เปิดใหม่สำหรับใบถัดไป **ห้ามสะสมหลาย order ใน context เดียว**
2. **ห้ามอ่าน `AGENT_TASKBOARD.md` ทั้งไฟล์** (~1,900 บรรทัดและโตขึ้นเรื่อยๆ = กิน context ครึ่งนึงตั้งแต่ยังไม่เริ่มงาน)
   → อ่านเฉพาะ **header บรรทัด 1-40** (กติกา+template) **+ block ของ order ตัวเองเท่านั้น**
   (`Grep "^## ORDER-xxx" -A 60` หรือ `Read offset/limit`) — block อื่นไม่เกี่ยว ห้ามโหลด
3. **ห้ามโหลด report ดิบทั้งไฟล์เข้า context** (html/xml ของ MT5 = หลายหมื่น token/ไฟล์)
   → parse ด้วย script/grep เอาเฉพาะบรรทัดตัวเลข (PF · trades · DD · net) แล้วค่อยอ่านผลที่ parse แล้ว
4. **append ผลลง taskboard + commit ทันทีที่จบแต่ละ STEP** — ห้ามเก็บผลไว้ใน context แล้วค่อยเขียนตอนจบ
   (ทำแบบหลัง = context เต็มตอนไหน ผลหายตอนนั้น)
5. **ห้าม compact แล้วทำต่อ** — compact ทำให้ลืมรายละเอียด branch ที่กำลังเดิน = ความเสี่ยงเดินผิดกิ่ง
   → context ใกล้เต็ม (~70%) ให้ **commit ผลที่มี → เขียนบรรทัด "ทำถึง STEP ไหน" ใต้ order → จบ session**
   session ใหม่อ่านบรรทัดนั้นแล้วเดินต่อได้ทันที

**สัดส่วนที่ควรเป็นในทางปฏิบัติ:** กติกา+order (~10-15k) · ผล parse แล้ว (~5k) · ที่เหลือ = ทำงาน
ถ้า session ไหนใช้เกิน ~50% ตั้งแต่ยังไม่รัน STEP 1 = อ่านเกินความจำเป็น ให้ทบทวนข้อ 2/3

## 5.6 คำศัพท์ที่ใช้ในตาราง (user ถาม 2026-07-25)

| คำ | แปลว่า | ค่าที่ใช้ในคลังนี้ |
|---|---|---|
| **window** | ช่วงเวลาที่เอาไปทดสอบ (ไม่ใช่พารามิเตอร์ของ EA) | **MAIN** = 36 เดือนล่าสุด (≈2023.07–2026.07) ใช้จูน · **BWD** = 2020–2022 ยุคคนละแบบ ใช้ตรวจว่าไม่ได้จูนเข้ากับยุคเดียว · **HOLDOUT** = ช่วงที่ไม่เคยเอามาเลือกอะไรเลย ใช้ครั้งเดียวแล้วไหม้ (นิยามเต็ม = VERDICT GATE ใน `CLAUDE.md`) |
| **lever** | "คันโยก" = สิ่งที่หมุนแล้วผลเปลี่ยน — กว้างกว่าคำว่า parameter | 2 ชั้น: **(ก) พารามิเตอร์** ใน .set (AtrPeriod, Mult, SL, TP, EMA…) · **(ข) เชิงโครงสร้าง** ที่ไม่ใช่ตัวเลข: symbol · TF · exit mode · เปิด/ปิดฟิลเตอร์ · market vs pending entry · flat-lot vs escalation |
| **cell** | 1 ช่องของ matrix = 1 ชุด (EA × symbol × TF × window) ที่รันได้จบในตัว | — |
| **plateau** | ย่านที่ค่ารอบข้างก็ยังกำไร (ทน) ตรงข้ามกับ **spike** = ยอดแหลมค่าเดียวที่ขยับนิดเดียวแล้วพัง | เลือก plateau center เสมอ ห้ามเลือก peak |

**ทำไม matrix ชุดที่ 1 ถึงดูเหมือน "แก้ทีละพารามิเตอร์":** เพราะมันไม่ใช่ optimize — มันคือ **smoke screen**
(ตอบแค่ "คู่นี้มีชีพจรไหม" ด้วยค่า default 1 ชุด ถูกและเร็ว). ตัวที่กวาดพารามิเตอร์จริงคือ **ชุดที่ 2 = genetic**
(1 cell = แสนกว่า combo). สองชั้นนี้คนละหน้าที่: ชั้นแรกคัดทิ้งของถูก ชั้นสองขุดของแพง — อย่าเอาชั้นสอง
ไปรันทุกคู่ตั้งแต่แรก (เปลืองหลายสิบชั่วโมงไปกับคู่ที่ไม่มีอะไรเลย)

## 5.7 prompt สั่งงานต่อบนคอม (วางลง Claude Code / ZCode บนเครื่อง — ใช้ซ้ำได้ทุกรอบ)

```
อ่าน 3 ไฟล์นี้ก่อน: AGENTS.md · docs/QUOTA_FALLBACK_PLAYBOOK.md ·
AGENT_TASKBOARD.md เฉพาะบรรทัด 1-40 + block ORDER-GEN-STANDING (ห้ามอ่านทั้งไฟล์)

งาน: เดิน ORDER-GEN-STANDING ตามลำดับนี้
1. MATRIX ชุดที่ 2 cell #15 (XAUUSD H4 = control) ก่อนเสมอ — ถ้า M4 MAIN ต่ำกว่า ~1.5 มาก
   ให้หยุดทั้ง matrix แล้วรายงานว่า pipeline/data มีปัญหา อย่ารันต่อ
2. control ผ่าน -> เดินชุดที่ 2 ต่อจาก cell #13 ลงมาทีละ cell
3. ชุดที่ 2 หมด (หรือ optimize ช้าเกินจนอยากได้ผลเร็ว) -> ค่อยไปชุดที่ 1

ทำทีละ cell: รัน -> parse เอาแค่ PF/trades/DD/net -> เติมช่อง "ผล" ในตาราง ->
append ผลดิบใต้ order -> commit [oc-qwen] -> cell ถัดไป

ห้าม: เขียน verdict (DEAD/CANDIDATE/DEMO) · แตะ EA_SCORECARD / EA_MASTER_INDEX / EDGE_CATALOG /
PROJECT_STATE / VISION / B1_DATASET · แตะ .mq5 หรือ ea_template\core\ · แตะ _vps_deploy หรือ .set
ของ EA ที่ demo อยู่ · กรอกผล Model-1/Model-2 ลงตาราง · เปลี่ยนค่าที่ RUN TEMPLATE ไม่ได้ระบุ ·
เพิ่ม cell เอง

ผลไม่เข้าเกณฑ์ไหนเลย หรือรันพลาด 2 ครั้ง = mark BLOCKED(คำถาม) แล้วถามผม
context ถึง ~70% = commit + เขียนว่าทำถึง cell ไหน + จบ session (ห้าม compact แล้วทำต่อ)
```

## 6. ภาคผนวก — prompt ติดตั้ง oc-qwen (ทำครั้งเดียว)

> งานนี้เป็นงาน **config ฝั่งเครื่อง ไม่ใช่งาน repo** → ต้องรันจากเครื่องที่ OpenClaw ติดตั้งอยู่ (session
> คลาวด์แตะไม่ถึง) · **agent ตัวไหนก็ได้ที่ว่าง — Claude Code local / ZCode / Codex / oc-dev** เพราะเป็น
> งานอ่าน-แก้ config ธรรมดา ไม่ใช่งานที่ต้องใช้ reasoning สูง (ตัวสำคัญคือ prompt ไม่ใช่ตัวรัน).
> ถ้า ChatGPT quota หมด → ใช้ Claude Code บนเครื่อง หรือ ZCode (GLM คนละเลน) ได้เลย ไม่ต้องรอ Codex

```
งาน: เพิ่ม agent ใหม่ชื่อ "oc-qwen" เข้า OpenClaw บนเครื่องนี้ ให้สั่งงานผ่าน Telegram ได้
     โดยใช้ qwen API key (ไม่ใช่ ChatGPT OAuth เดิม)

บริบท: OpenClaw ตอนนี้มี agent oc-mgr / oc-dev / oc-btest ซึ่งทั้งหมดแชร์ ChatGPT OAuth ก้อนเดียวกัน
       เป้าหมายคือมีเลนที่ "ไม่กิน ChatGPT quota เลย" ไว้รันงาน batch backtest ตอน quota หลักหมด

ต้องทำ:
1. อ่าน config OpenClaw ที่ติดตั้งอยู่ (ไฟล์ config + วิธี register agent + วิธีผูก provider)
   แล้วรายงานก่อนว่า: รองรับ provider แบบ OpenAI-compatible endpoint ไหม / ตั้ง base_url + api_key
   ต่อ agent แยกกันได้ไหม
2. ถ้ารองรับ → เพิ่ม agent "oc-qwen":
   - provider = qwen (endpoint OpenAI-compatible; api_key อ่านจาก env var ชื่อ QWEN_API_KEY
     ห้าม hardcode key ลงไฟล์ config และห้าม echo ค่า key ออกมาใน log/รายงาน)
   - model = รุ่น qwen ที่รัน tool-use/shell ได้เสถียรและถูกที่สุด (ระบุที่เลือกมาพร้อมเหตุผล)
   - working dir = repo EA_LAB
   - ผูกเข้ากับ Telegram bot ตัวเดิมที่ oc-mgr ใช้อยู่ ให้สั่ง oc-qwen จาก Telegram ได้
3. ถ้าไม่รองรับ → หยุด รายงานว่าติดตรงไหน + เสนอทางเลือกที่ถูกที่สุด 2 ทาง (เช่น proxy layer
   OpenAI-compatible คั่น หรือ bridge script) พร้อมข้อดีข้อเสีย — อย่าเดาแล้วแก้มั่ว
4. system prompt ของ oc-qwen ให้ใส่ตามนี้ (verbatim):
   "อ่าน AGENTS.md + AGENT_TASKBOARD.md + docs/QUOTA_FALLBACK_PLAYBOOK.md ก่อนทุกครั้ง
    ทำได้เฉพาะ order ที่มี OPEN และมี TREE ครบเท่านั้น
    เดินตาม TREE ที่เขียนไว้ ห้ามตีความผลนอก branch
    เขียนไฟล์ได้เฉพาะแถว order ที่ตัวเอง claim ใน AGENT_TASKBOARD.md
    ห้ามเขียน verdict · ห้ามแตะ EA_SCORECARD / EA_MASTER_INDEX / EDGE_CATALOG / PROJECT_STATE /
    VISION / CLAUDE.md / AGENTS.md / B1_DATASET.csv · ห้ามแตะ .mq5 หรือ ea_template\\core\\ ·
    ห้ามแตะ _vps_deploy หรือ .set ของ EA ที่ demo อยู่
    ผลไม่เข้า branch ไหน หรือรันพลาด 2 ครั้ง = mark BLOCKED(คำถาม) แล้วส่งคำถามกลับ Telegram
    commit ด้วย tag [oc-qwen] เสมอ · append ผลดิบทั้งก้อน ห้ามสรุปทิ้งตัวเลข
    CONTEXT (200k — ห้ามละเมิด): 1 order = 1 session ห้ามสะสม ·
    ห้ามอ่าน AGENT_TASKBOARD.md ทั้งไฟล์ อ่านแค่บรรทัด 1-40 + block ของ order ตัวเอง ·
    ห้ามโหลด report ดิบทั้งไฟล์ ให้ parse เอาเฉพาะบรรทัด PF/trades/DD/net ·
    commit ทุกครั้งที่จบ STEP ห้ามเก็บผลไว้ใน context ·
    context ถึง ~70% = commit + เขียนว่าทำถึง STEP ไหน + จบ session (ห้าม compact แล้วทำต่อ)"
5. ทดสอบ end-to-end: สั่งจาก Telegram ให้ oc-qwen อ่าน taskboard แล้วรายงานว่ามี order OPEN กี่ใบ
   (งาน read-only ล้วน) — ต้องได้คำตอบกลับทาง Telegram จริง

ห้าม: hardcode API key ลงไฟล์ใดๆ ที่ commit เข้า git · แก้ config ของ oc-dev/oc-btest/oc-mgr เดิม ·
      ให้ oc-qwen มีสิทธิ์ push ไป branch อื่นนอกจาก branch งานปกติ · รัน backtest จริงในรอบทดสอบนี้

ส่งกลับ: (1) รองรับ/ไม่รองรับ + config ที่แก้ (2) model ที่เลือก + เหตุผล (3) ผลทดสอบ end-to-end
        (4) ค่าใช้จ่ายโดยประมาณต่อ 1 order batch
```
