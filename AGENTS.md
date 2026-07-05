# AGENTS.md — กติกากลางสำหรับทุก AI agent ในเครื่องนี้ (Claude Code / Codex / ZCode)

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **บทบาท + ขอบเขตสิทธิ์ + protocol การทำงานร่วมกัน
> ของ agent ทุกตัวเท่านั้น** — สถานะ/แผน/verdict อยู่ที่ PROJECT_STATE.md · คิวงานอยู่ที่ AGENT_TASKBOARD.md

**อ่านก่อนเริ่มงานทุกครั้ง (ทุก agent):** `VISION.md` → `PROJECT_STATE.md` → `AGENT_TASKBOARD.md` → ไฟล์นี้

---

## 1. บทบาท (ตาม strength — อย่าสลับเอง)

| Agent           | บทบาท                                                                       | ทำได้                                                 | ห้ามเด็ดขาด                                                                                          |
| --------------- | --------------------------------------------------------------------------- | ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Claude Code** | Lead engineer / judge — ทิศทาง, verdict, เขียน order, review งาน agent อื่น | ทุกอย่าง                                              | —                                                                                                    |
| **Codex**       | Peer engineer — execute order ที่ scope ชัด, second opinion เมื่อถูกถาม     | โค้ดตาม spec ของ order, รันทดสอบ, **รายงานตัวเลขดิบ** | ตัดสิน verdict · แก้ VISION.md · แก้ Decision log (§3) · แก้กฎใน skill/ไฟล์นี้ · เปลี่ยนทิศทางงานเอง |
| **ZCode**       | Batch runner — รัน backtest/optimize/parse ตาม order                        | รัน script ที่มีอยู่, เก็บผลเป็นตาราง/CSV             | เหมือน Codex + **ห้ามแก้ source code ทุกไฟล์**                                                       |
| **ทีม OpenClaw (สั่งจาก Telegram)** | `[oc-mgr]` manager = รับคำสั่ง/แจก/รายงาน progress · `[oc-dev]` ea_developer = เทียบเท่า Codex · `[oc-btest]` ea_backtester = เทียบเท่า ZCode | ตาม role ที่เทียบเท่า · brief ประจำตัวอยู่ใน workspace ของแต่ละตัว | เหมือน role ที่เทียบเท่า · **คนละ runtime กับ Codex Desktop/ZCode Desktop — งานไม่ขึ้นจอพวกนั้น** ดูได้จาก STATUS.md + git log (tag [oc-*]) + Telegram |

**Heartbeat (กฎ user 2026-07-04):** ทุก agent ที่ทำงานเกิน ~10 นาที ต้องรายงานความคืบหน้า
ทุก ~10-15 นาที (1 บรรทัด: ทำอะไร ~% ติดอะไร) — ทีม OpenClaw รายงานใน Telegram ผ่าน manager ·
Codex/ZCode ที่รันหน้าคอม รายงานใน console ของตัวเอง

หลักเดียวที่ครอบทุกอย่าง: **agent อื่น "ผลิตหลักฐาน" — Claude/user เป็นคน "ตัดสิน"**
เจองานที่ต้องตัดสินใจนอก order → หยุด, เขียน BLOCKED ลง taskboard พร้อมคำถาม, ไปทำ order ถัดไป

### 1.5 Model assignment + tier ladder (post-Fable, ตั้งแต่ 2026-07-04 — Fable โควต้าหมดจริง)

> Fable หมดโควต้าแล้ว (เร็วกว่าแผน 07-07). **seat lead/judge = Claude Code รันบน Opus** ตั้งแต่บัดนี้.
> role อยู่ที่ seat ไม่ใช่ model — Opus ทำหน้าที่เดิมของ Fable ทุกอย่าง (ทิศทาง/verdict/เขียน order/review).

**ยอดบันได escalation พังลงมา 1 ชั้น — ต้องเข้าใจก่อนใช้:** เดิม Opus = "deep-reasoner tier"
(ตัว escalate เมื่องานยาก) ด้วย. พอ seat = Opus แล้ว การ spawn `deep-reasoner` subagent = **สมองตัว
เดียวกัน context ใหม่** (offload context ได้ แต่ไม่ใช่ capability ที่ฉลาดกว่า). **ความหลากหลายเชิง
capability ที่แท้จริงตอนนี้มาจาก Codex (คนละ model family = GPT) ตัวเดียว** → Codex กลายเป็น
"สมองที่สองอิสระ" ที่สำคัญขึ้น ไม่ใช่ทางเลือกเสริม. **คุณค่าของ Codex ไม่ได้อยู่ที่ "เก่งเท่า Opus" แต่
อยู่ที่ "คนละค่าย = จุดบอดคนละที่"** (Opus 2 ตัวรีวิวกันเอง = พลาดจุดเดียวกัน เพราะ bias เดียวกัน) →
งาน review ใช้ **Codex ตัวเก่งสุดที่มี** (review เป็นงานนานๆ ครั้ง ไม่ต้องประหยัด model).

**tier ladder ใหม่ (ถูกสุดที่ตรวจงานได้ก่อนเสมอ — cost rule เดิมยังอยู่):**

| ชั้นงาน | ใครทำ | quota lane |
|---|---|---|
| batch run ล้วน (powershell + parse, ตรวจด้วยตัวเลข/ไฟล์) | **oc-btest (ถูกสุด) / ZCode / qwen** | **ห้ามกิน ChatGPT** — ไป GLM(ZCode) หรือ qwen |
| code ตาม pattern + มี cage (tpl_regression) | oc-dev / Codex / Sonnet(fast-worker) | ChatGPT (code คุ้มค่าเงิน) |
| money/risk logic ใหม่, architecture, root-cause | **Opus-seat เอง** (ไม่มี deep-reasoner tier แยกแล้ว) | — |
| verdict/ทิศทาง/เขียน order | **Opus-seat เท่านั้น** | — |
| second opinion งานแพง/ย้อนไม่ได้ | **Codex** (สมองอิสระตัวเดียวที่เหลือ — ใช้ประหยัด ดู §5) | ChatGPT |

**สถาปัตยกรรมการสื่อสาร (กันสับสน):** ไม่มี agent คุยกันตรงๆ — ทุกตัวสื่อสารผ่าน "กระดานกลาง"
เท่านั้น (taskboard + git commits + STATUS.md) เหมือนกะพนักงานที่ส่งงานผ่านสมุดหน้างานเล่มเดียว ·
ไม่มีใครปลุก Claude ได้ — Claude เข้ามาเมื่อ user เปิด session แล้ว review ทุก commit ที่เกิดระหว่าง
ไม่อยู่เอง · ทีม OpenClaw กับ Codex Desktop/CLI ใช้**โควต้า ChatGPT ก้อนเดียวกัน** (OAuth เดียวกัน)
— อย่ารันงานหนักสองทางพร้อมกัน · ZCode = โควต้า GLM แยกต่างหาก

## 2. สิทธิ์การเขียนไฟล์ (single-writer — กัน drift)

| ไฟล์                                                                                                             | ใครเขียนได้                                                                                                 |
| ---------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `VISION.md` · `PROJECT_STATE.md` §3 Decision log · verdict ใน `EA_SCORECARD_AND_REGISTRY.md` · `AGENTS.md` (นี่) | **Claude / user เท่านั้น**                                                                                  |
| `AGENT_TASKBOARD.md`                                                                                             | ทุก agent — แต่เขียนได้เฉพาะ **แถว order ของตัวเอง** (claim/ผล/BLOCKED) · การเพิ่ม order ใหม่ = Claude/user |
| `PROJECT_STATE.md` ส่วนอื่น (status one-liner, HANDOFF)                                                          | Claude เป็นหลัก · agent อื่นห้ามแก้ ให้เขียนผลลง taskboard แทน                                              |
| source code (`ea_template\`, `scripts\`, EA_Project)                                                             | Claude + Codex (ตาม order) · ZCode ห้าม                                                                     |
| reports/CSV/set files ใหม่                                                                                       | ทุก agent (ตาม order)                                                                                       |

## 3. กฎเหล็กทางเทคนิค (ทุก agent — ผิดข้อใดข้อหนึ่ง = งานนั้นใช้ไม่ได้)

1. **แก้ `ea_template\core\*` เมื่อไหร่ ต้องรัน `powershell -File scripts\tpl_regression.ps1` → ต้อง CLEAN** ก่อน commit
2. **MT5 มี 2 เลน (ตั้งแต่ 2026-07-04):**
   - **เลน 1 (หลัก):** `D:\Meta 5` — สำหรับ Claude/user/Codex desktop · default ของทุก script
   - **เลน 2 (agent):** `D:\Meta 5b` portable — **ทีม OpenClaw (oc-btest) ใช้เลนนี้เสมอ**:
     ต่อท้ายทุกคำสั่ง `-Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable`
   - รันคู่กันได้ (guard แยกตาม exe path) **ยกเว้น Model 4 (real ticks) ห้ามรันคู่กับอะไรทั้งนั้น**
     (เครื่องเคย freeze — ดู memory freeze-guard) · ภายในเลนเดียวกันยังรันทีละงาน · ห้าม `-Force` ·
     ห้าม kill process · EA ใหม่จะไปเลน 2 อัตโนมัติผ่าน `ea_template\deploy.ps1`
3. **ตัวเลขที่รายงาน = Model 1 ขึ้นไป** (Model 2 ใช้กรอง zero-trade เท่านั้น) · ทุก full-window run แตกปีด้วย `scripts\report_year_split.py`
4. **Verdict rules (สรุปจาก decision log — อ่านฉบับเต็มใน PROJECT_STATE §3):**
   ห้าม DEAD/REJECT ก่อน optimize probe · cap breach (DD/margin/ruin) = resize-first ห้าม reject ตรง ·
   เลข optimizer = in-sample เสมอ · backward-OOS บังคับเมื่อ IS/OOS อยู่ regime เดียว
   — agent อื่นไม่ต้องใช้กฎพวกนี้ตัดสินเอง แค่**อย่ารายงานสรุปที่ขัดกับมัน** (รายงานตัวเลขดิบพอ)
5. **Git:** commit บ่อย, ข้อความ commit ขึ้นต้นด้วย tag ตัวเอง `[codex]` / `[zcode]` / `[oc-*]` · ห้าม push/force/rebase/amend ·
   ห้าม `--no-verify` (pre-commit guard คือกันชนของทุกคน) · ทำงานบน branch ปัจจุบัน อย่าสร้าง/สลับ branch เอง ·
   **Claude commit ลงท้ายด้วย `Co-Authored-By:` ตาม seat model ปัจจุบัน** (ตั้งแต่ 2026-07-04 = `Claude Opus 4.8
   <noreply@anthropic.com>` — ไม่ใช่ Fable แล้ว; ไม่มี git config สำหรับ trailer นี้ เป็น message trailer ที่ใส่มือทุก commit)
6. Python = portable: dot-source `scripts\use_python.ps1` ก่อน (ไม่มี system python)
7. **หลัง commit ทุกครั้ง รัน `powershell -File D:\EA_LAB\scripts\make_status.ps1`** — regenerate
   STATUS.md + สำเนาขึ้น OneDrive ให้ user ดูจากมือถือ (ห้ามแก้ STATUS.md ด้วยมือ)
8. **`EA_MASTER_INDEX.csv` ต้องตรงกับ scorecard เสมอ:** ทุกครั้งที่ verdict/สถานะ EA เปลี่ยน
   (ใน EA_SCORECARD หรือ taskboard REVIEWED) — คนที่ commit การเปลี่ยนนั้น (ปกติ = Claude)
   ต้องแก้แถวใน index ใน **commit เดียวกัน** · agent อื่นเพิ่มแถว UNTESTED ใหม่ได้ตาม order
   แต่ห้ามแก้แถวที่มี status อื่น

## 4. วงจรการทำงาน (ต่อ 1 order)

```
Claude เขียน order ลง AGENT_TASKBOARD (มี: งาน · คำสั่ง/ไฟล์ · acceptance criteria · ข้อห้าม)
  → agent อื่นเปิดเครื่อง: อ่าน 4 ไฟล์บังคับ → เลือก order สถานะ OPEN ตัวบนสุดที่ตรง role
  → แก้สถานะเป็น CLAIMED(ชื่อ, เวลา) → ทำงาน → append ผลดิบใต้ order → สถานะ DONE → commit [tag]
  → Claude กลับมา: git log + taskboard → review → ตัดสิน → ย้าย verdict เข้า scorecard/PROJECT_STATE
  → สถานะ REVIEWED → เขียน order รอบถัดไป
```
- order ละ **1 งานจบในตัว** ผลตรวจได้ด้วยตัวเลข/ไฟล์ — ถ้างานใหญ่ Claude ต้องหั่นก่อน
- **order ที่มีการตีความ/จำแนก (บทเรียน ORDER-012):** เกณฑ์ต้องเป็น checklist ที่ตอบ ได้/ไม่ได้
  ทุกข้อ (เช่น "Y ต่อเมื่อ: มี entry indicator จริง AND ไม่ใช่ grid/martingale เป็นแกน AND มี SL")
  — ห้ามเขียนเกณฑ์แบบให้ agent ใช้วิจารณญาณ ("น่าสนใจ", "มี edge") เพราะจะได้ผลหลวมเสมอ
- ไม่มี order OPEN เหลือ + Claude ไม่อยู่ → **หยุด อย่าคิดงานใหม่เอง** (บันทึกข้อเสนอเป็น comment ใน taskboard ได้)

## 5. เมื่อไหร่ใช้ตัวไหน (มุมมอง user) — ปรับใหม่ post-Fable 2026-07-04

**หลักการเดียวที่ตอบทุกคำถาม: จับคู่ "ระดับสมองที่ต้องใช้" กับ "quota lane" — อย่าเอา quota แพง/หายาก
ไปทำงานที่สมองถูกกว่าทำได้.** ตอนนี้ ChatGPT quota (Codex + oc-dev + oc-btest แชร์กัน) = ก้อนหายาก
ที่หมดเร็ว · GLM (ZCode) = เลนแยก ใช้น้อย · qwen (`claude-9arm`) = เกือบฟรี.

- **งานคิด/ทิศทาง/verdict/ออกแบบ order → Opus-seat** (ชั่วโมงของ seat ควรจบที่ "order ชุดใหม่ +
  verdict ผลเก่า" ไม่ใช่รัน backtest เอง). งาน money/risk-logic ใหม่ + architecture + root-cause ที่เคย
  escalate ให้ deep-reasoner → **Opus-seat ทำเองเลย** (มันคือ tier บนสุดแล้ว ไม่มีที่ให้ escalate ต่อ).
- **batch run ล้วน (backtest/optimize/parse) → ZCode แต่โควต้าฟรี/วัน ≈ 1 order หนักเท่านั้น** (บทเรียน
  2026-07-05: ORDER-025 = 1 M4 + 2 M1 + year-split กิน ZCode หมดวันในคำสั่งเดียว!). ดังนั้น **ห้าม default
  ทุก batch ไป ZCode** — ให้ **เก็บ ZCode slot วันละ 1 ไว้ให้ order สำคัญสุด** (ตัวที่ต้อง Model-4/optimizer
  หนัก). batch เล็กๆ ที่เหลือ: **qwen** (ถ้า parse/รันเบา) หรือ **Claude รันเอง** (ไม่กี่ run เหมือน ORDER-022/023)
  หรือ **oc-btest** (ถ้า ChatGPT quota ยังเหลือ). **ทุก order ที่ Claude เขียน ต้องระบุ "👉 แนะรัน: <agent>"**
  — เลือกให้ตรงขนาด: heavy+สำคัญ→ZCode(1/วัน) · เล็ก→qwen/Claude · code→oc-dev/Codex. user override ได้เสมอ.
- **code ตาม pattern (มี cage tpl_regression) → oc-dev / Codex / Sonnet** — งาน code คุ้มค่า ChatGPT quota.
- **Claude quota หมด + มี order ค้าง → Codex** (code/ผสม) หรือ **ZCode** (รันล้วน) เหมือนเดิม.

**❓ Codex ต้องมา review ร่วมไหม → ใช่ แต่เลือกใช้ (ไม่ใช่ทุก verdict):** หลัง Fable ออก Codex = สมอง
อิสระ (คนละ family) ตัวเดียวที่เหลือ. **หลักคิด: ไม่ได้ใช้เพราะ Codex เก่งเท่า Opus — ใช้เพราะคนละค่าย
จับจุดบอดที่ Opus มองข้ามเป็นระบบได้** ("อิสระ + เก่งพอเถียง" > "เก่งเท่ากันแต่ค่ายเดียว"). งาน review ใช้
**Codex ตัวเก่งสุดที่มี** (GPT รุ่นสูงสุดที่ setup ไว้ — เป็นงานนานๆ ครั้ง ไม่ต้องประหยัด model). →
**บังคับขอ second opinion จาก Codex เฉพาะการตัดสินที่แพง/ย้อนไม่ได้:** (1) ปล่อย EA ลงเงินจริง
(promote demo→live) (2) money/risk logic ใหม่ที่ยังไม่มี cage (3) architecture เปลี่ยนแม่พิมพ์.
**verdict ประจำวัน (EA ตัวไหน demo/park/dead จาก backtest) = Opus-seat ตัดสินเดี่ยว** — Opus แข็งพอ +
มี cage/rule ครบ + ประหยัด ChatGPT quota. วิธีถาม: คำถามเดียวกับที่ Opus คิด **โดยไม่ให้ Codex ดู
คำตอบ Opus ก่อน** แล้ว Opus สังเคราะห์ (ห้ามให้ Codex เห็นคำตอบอีกฝ่าย = กัน anchoring).

**❓ oc-btest ควรลดเหลือ GPT-5.4 ไหม → ใช่ ลดให้ถูกสุดเท่าที่รัน powershell+parse ได้เสถียร:** งาน
oc-btest = zero-judgment (รัน script + อ่านตัวเลข) — ไม่ต้องใช้ reasoning เลย. รันบน model แพงคือเผา
ChatGPT quota ทิ้ง. **ทางที่ดีกว่าการแค่ลด model: ย้ายงาน batch ของ oc-btest ไป ZCode (GLM เลนแยก)
หรือ qwen ให้มากที่สุด** เพื่อ**กัน ChatGPT quota ไว้ให้ oc-dev/Codex (งาน code) อย่างเดียว**. เก็บ
oc-btest ไว้เฉพาะตอน ZCode ไม่ว่าง + ให้อยู่ model ถูกสุด.

**❓ OpenClaw ทำยังไงให้คุ้มสุด (สรุป):**
- **oc-mgr** (manager) = คงไว้ — coordination/Telegram/heartbeat, งานเบา
- **oc-dev** (code) = คงบน model เก่ง — code ต้องการ, คุ้ม ChatGPT quota
- **oc-btest** (batch) = model ถูกสุด + งานส่วนใหญ่โยนไป ZCode/qwen แทน
- **ห้ามรัน Codex Desktop/CLI + OpenClaw งานหนักพร้อมกัน** (แชร์ ChatGPT OAuth ก้อนเดียว = หมดเร็วเป็น 2 เท่า)
- ลำดับความคุ้ม batch: **qwen → ZCode(GLM) → oc-btest(ถูกสุด) → [ห้าม] Codex/oc-dev บน batch**
