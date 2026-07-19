# CLAUDE.md — EA_LAB

Project state, decisions, and forward plan live in [PROJECT_STATE.md](PROJECT_STATE.md) — read that first every session. This file only holds instructions for how Claude Code itself should operate in this repo.

## 🚦 VERDICT GATE — decision tree + bar table (ห้ามตัดสิน EA จนกว่าจะเดินครบ tree นี้)
**gate นี้ = owner ของ verdict ทั้งหมด · อ่านทุก session · ถ้าจะเขียน verdict แล้ว tree ยังไม่ครบ = หยุด เดินให้ครบก่อน.**
ขั้นตอน optimize เต็ม = skill `backtest-optimize-rigor` (owns THE LADDER 0-9). gate นี้ = **ต้นไม้ตัดสิน** ที่ ladder ป้อนหลักฐานเข้ามา.

**Window names (pin เดียวใช้ทุกที่):** **MAIN** = 36 เดือนล่าสุดที่**ไม่กิน HOLDOUT** — จบก่อน holdout เริ่มเสมอ (วันนี้ = **2023.01–2025.12**) re-pin ทุก re-opt 6 เดือน · **BWD** = 2020–2022 (trend/stress regime) · **HOLDOUT** = window/symbol ที่ไม่เคยใช้ select (default 2026H1 จนกว่าจะถูกใช้ — ใช้แล้วไหม้; หลังจากนั้น demo-forward = holdout และ verdict ต้องระบุ). **กฎเหล็ก: MAIN ∩ HOLDOUT = ∅** — ถ้า re-pin MAIN เลื่อนไปทับ holdout ปัจจุบัน ต้องประกาศ holdout ใหม่ก่อน (Codex system review 2026-07-18 จับ overlap 2023.07–2026.07 vs 2026H1 = ช่อง leakage).

```
EVIDENCE IN
│
1. STRUCTURAL?  (เจอข้อใดข้อหนึ่ง ⇒ ฆ่าทันที — ความตายถูกอย่างเดียว ไม่ต้อง optimize)
   · uncapped ruin: ไม่มี SL AND ไม่มี depth cap (maxOpen≥8) AND geometric ladder
     — เช็ค 4 ข้อ martingale ก่อน (SL? · capped steps? · flat-lot edge? · conditional adds?) —
       capped+SL+edge ≠ ruin
   · ⚠️ **แก้กฎ 2026-07-19 (user ratified):** flat-lot PF<1 ขณะ escalated PF>1 = **ไม่ auto-kill แล้ว**
     → จัดเข้า **ENGINE-EDGE class** (edge อยู่ที่ escalation engine ไม่ใช่สัญญาณ) เดินต่อได้เมื่อผ่าน
     **กรง 5 ข้อครบ**: (1) worst-case คำนวณได้ — hard depth cap + basket-SL/DD-kill + ระบุเลข
     "แพ้ครั้งเดียวเสีย ≤15% equity" ที่ sizing จริง (2) **BWD 2020-22 = HARD gate** (engine ต้องโดน
     stress จริง — soft-gate ปกติไม่พอสำหรับ class นี้) (3) **Model-4 บังคับเสมอ** (4) MC ruin ≤2%
     ที่ sizing จริง (5) scorecard label = **engine-edge** → sizing เล็กถาวรแบบ NuiIndy ห้าม size-up
     ตาม PF. flat-lot probe ยังบังคับรัน แต่หน้าที่ = วินิจฉัยว่า edge อยู่ไหน ไม่ใช่ใบมรณะ.
     (precedent: NuiIndy live PF~2.0 + CutLoss=30 พิสูจน์ class นี้รอดได้ถ้ามีกรง)
   · cracked / expired / locked-no-source (legal-ops DQ)
   · pure fill-artifact: M4 พลิกเครื่องหมายทั้ง surface / tight-TP fiction
   ⇒ DEAD-STRUCTURAL → EDGE_CATALOG dead pile + scorecard kill-reason
     (course-file rule: แกะ entry CONCEPT ก่อนทิ้ง vehicle — [[feedback-course-files-extract-idea]])
│
2. else PARAMETRIC — ยังฆ่าไม่ได้.
   RIGHT HOME ก่อน (reversion→EURUSD/EURGBP/AUDNZD ranger · momentum→XAU/GBP trender;
   ตกที่บ้านผิด ≠ ตาย). เดิน ladder ≥3 lever × ≥2 TF บนบ้านที่ถูก.
   │
   ├─ 2a. ceiling < 1.0 both-window บน RIGHT home  AND  ทำ LAST-OPTIMIZE รอบสุดท้ายแล้ว
   │      (บังคับ 1 รอบบน lever ที่ยังไม่แตะ เลือกจาก diagnosis→lever table ทันทีก่อนลั่นไก
   │       แม้ optimize มาเยอะแล้ว)
   │      ⇒ DEAD-OPTIMIZED. ปิดระดับ CELL เป็น default · CONCEPT ตายได้เฉพาะเมื่อพิสูจน์ right-home
   │        ceiling แล้ว. default-param smoke ปิดได้แค่ CELL เท่านั้น เสมอ.
   │
   ├─ 2b. PF>1 ที่ไหนก็ได้ แต่ยังใต้ deploy bars
   │      ⇒ BUILD-ON (DEFAULT ไม่ใช่ bench-and-forget):
   │        · ขยาย symbol×TF (เอาทุก home ที่ผ่านบาร์ · pairwise corr<0.8)
   │        · ปรับกลไกก่อนรับตามเดิม (เช่น pending-limit entry — แต่ pending-rescue ใช้ได้เฉพาะ
   │          market-on-signal entry ห้ามใช้กับ grid trigger-touch; doctrine 2026-07-17)
   │        · แกะ entry mechanism เข้า EDGE_CATALOG แม้ EA ไม่ deploy
   │        idea ดีแต่ยังไม่ผ่าน ⇒ PARKED-VERIFY(user): tag + brief 3 บรรทัด
   │        (มันคืออะไร · gate ไหนฆ่า · ทำไมยังน่าสนใจ). ห้ามตายเงียบ.
   │
   └─ 2c. ผ่าน pre-registered bars ⇒ VALIDATED CANDIDATE → deploy funnel:
          lock plateau-center .set → both-window → sensitivity fan → holdout (หรือประกาศ
          demo-forward-as-holdout เมื่อ selection กิน BWD ไปแล้ว — Boss_16 precedent) →
          MC (resize-first เมื่อ cap breach) → Model-4 ถ้า fill-sensitive → corr vs cohort
          ⇒ DEMO  (DEPLOYMENTS.csv row + judge criteria pre-register ตอน attach)
          ⇒ ≥3 เดือน demo forward → judge ⇒ LIVE (เงินจริง)
             (irreversible: Codex second opinion บังคับ ห้าม anchor · + Fable-advisor one-shot
              case-3 ระหว่างมี quota — Fable ไม่ว่าง = Opus-seat ตัดสิน แต่ leg Codex ไม่มีทางข้าม)
```

**Bar table (หนึ่งเลขต่อ transition):**

| Transition | Bar |
|---|---|
| smoke pulse → PROCEED | หนึ่ง cell naked PF ≥ **1.2** ที่ n เหมาะกับ type (WATCH = 1.0–1.2) |
| optimize pass → CANDIDATE | **MAIN ≥ 1.2** (hard) AND **BWD ≥ 1.0** (soft-gate) + plateau ไม่ใช่ spike. **BWD-fail = ไม่ auto-kill → PARKED-VERIFY(user): เคาะ demo-isolate ได้ แต่ปิดทางเงินจริงอัตโนมัติ** (user Q3 2026-07-18) |
| holdout | PF ≥ **1.2** ที่ n เหมาะ ⇒ deploy track · **1.0–1.2 ⇒ BUILD-ON** (JUMSTOCH precedent) · <1.0 ⇒ selection-fit กลับไป diagnosis |
| MC | ruin ≤ **2%** (resize-first ได้ถึง 10%) · PF-5th ≥ **1.0** |
| Model-4 (เมื่อถึงคิว) | both-window PF ≥ **1.0** retained AND largest-loss ไม่ระเบิด (ไม่มี model-switch cliff) |
| demo → LIVE | ≥ **3 เดือน** · judge PF ≥ **1.40** ที่ ≥ **30 trades** · ไม่มี pre-registered kill trip |
| demo kill (default, override ต่อ-EA ตอน attach ได้) | eqDD > **12%** · 3-mo PF < **0.8** ที่ ≥ **15 trades** |

**Canonical verdict vocabulary (retire ทุกคำอื่น):**
`DEAD-STRUCTURAL · DEAD-OPTIMIZED · PARKED-VERIFY(user) · BUILD-ON · CANDIDATE · DEMO · LIVE`
(PASS/CONDITIONAL/ROBUST/MARGINAL/Mode-B จาก skill เก่า = retired). **discard semantics:** STRUCTURAL = ความตายถูกอย่างเดียว (ฆ่าทันที ไม่ owe optimize · แกะ concept ได้) · DEAD-OPTIMIZED = terminal ที่ต้อง *earn* (ปิด cell/concept หลัง ladder เต็ม + last-optimize) · **ที่เหลือทั้งหมดห้ามทิ้ง**.

**📋 Row-X write-checklist — ก่อนเขียน verdict ใดๆ ต้องเช็ค 5 บรรทัดนี้:**
- [ ] **scorecard** (`EA_SCORECARD_AND_REGISTRY.md`) update verdict + kill-reason
- [ ] **EA_MASTER_INDEX** update ใน commit เดียวกัน (hook-enforced)
- [ ] **EDGE_CATALOG** — dead pile หรือ reusable-lever/mechanism entry
- [ ] **B1_DATASET.csv** row ใน REVIEWED commit เดียวกัน (นิยาม = B1_COHORT.md)
- [ ] **user brief** ถ้า PARKED-VERIFY (3 บรรทัด: อะไร/gate ไหนฆ่า/ทำไมน่าสนใจ)

<sub>**paid-for history (บทเรียนจริง — ห้ามลบ):** 2026-07-08 ตัด "dead" ผิด 2 ครั้ง/session เพราะ optimize ไม่ครบ (→ tree ข้อ 2) · 2026-07-10 ST03 "no-edge" วัดใต้ scalp-exit เดียว (→ exit-mode เป็น lever) · 2026-07-16 SMC×STO ตายจาก default-smoke แล้ว optimize+ADX กลายเป็น EURUSD candidate จริง (→ ข้อ 2a: default-smoke ปิดได้แค่ cell; StoK 5→17 พลิกผล = optimize entry-signal เป็น lever แรก) · 2026-07-17 Model-2 ปั้น fake grid plateau AUDNZD PF 3-4→M4 0.61 (→ grid = Model-2 ไม่ใช่หลักฐาน) · 2026-07-18 last-optimize-before-verdict + BWD soft-gate (user rule). ที่มาเต็ม = memory `feedback-last-optimize-before-verdict` · `feedback-buildon-pf-gt-1` · `feedback-optimize-before-killing-reversion`.</sub>

## Model transition (Fable → Opus) — ✅ ACTIVE ตั้งแต่ 2026-07-04 (Fable โควต้าหมดจริง เร็วกว่าแผน 07-07)

**UPDATE 2026-07-11 (Fable-seat วันเดียวก่อนโควต้าเหลือ ~10%):** Opus กลับเป็น seat หลักตั้งแต่ session
ถัดไป · **Fable ที่เหลือ = จองให้ 4 กรณีนี้เท่านั้น ผ่าน skill `fable-advisor` (one-shot brief — ห้ามเผาเป็น
session เต็ม):** (1) verdict ผล ST03 ที่ user optimize มือ (2) ตรวจ spec ORDER-082 Wave5 ก่อน build
(3) การ promote เงินจริงครั้งแรกของ candidate ตัวถัดไป (4) RCA เหตุการณ์เงินจริงผิดปกติ · งานอื่นทุกอย่าง =
Opus + Codex + agent lanes ตามเดิม · แผนงานเต็ม = `PROJECT_STATE.md` §7 PLAN 2026-07-12+

**seat lead/judge = Claude Code รันบน Opus แล้ว.** role อยู่ที่ seat ไม่ใช่ model — Opus ทำหน้าที่เดิม
ของ Fable ทุกอย่าง. รายละเอียด workflow ทีมหลัง transition (tier ladder + quota lane + Codex review) =
**`AGENTS.md` §1.5 + §5** (owns เรื่อง multi-agent protocol — อ่านคู่กัน).

- Nothing project-critical lives in any model's head. Everything is in: `VISION.md` → `PROJECT_STATE.md`
  → `ROADMAP.md` → `AGENTS.md`/`AGENT_TASKBOARD.md` → skills (`C:\Users\patip\.claude\skills\`) →
  auto-memory (same directory, persists across models). Read in that order on first session.
- **ยอดบันได escalation พังลง 1 ชั้น:** seat = Opus แล้ว → spawn `deep-reasoner`(Opus) subagent =
  สมองตัวเดียวกัน context ใหม่ (offload context ได้ ไม่ใช่ capability ที่ฉลาดกว่า). งานที่เคย escalate ให้
  deep-reasoner (money/risk logic ใหม่, architecture, root-cause) → **ทำเองใน main context**. สมองอิสระ
  คนละ family ที่เหลือ = **Codex (GPT รุ่นเก่งสุดที่ setup ไว้)** — คุณค่าอยู่ที่ "คนละค่าย จับจุดบอดคนละที่"
  ไม่ใช่ "เก่งเท่า Opus" → บังคับขอ second opinion จาก Codex **เฉพาะการตัดสินที่แพง/ย้อนไม่ได้**
  (promote demo→live · risk logic ที่ไม่มี cage · architecture) ไม่ใช่ทุก verdict.
- Honor every user rule in the Decision log verbatim (Model-2 ban, no-DEAD-before-optimize,
  cap-breach-resize-first, correlation→reduce-lot-not-cut, 3-year window). These were each paid for
  with real mistakes — do not re-litigate them without new evidence.
- The user prefers decisions presented as real-workflow scenarios with one decisive recommendation,
  in Thai, short (see memory: feedback-simple-language-decisions). Cost matters: cheapest verifiable
  tier first — **batch run เลี่ยง ChatGPT quota (qwen → ZCode/GLM → oc-btest ถูกสุด), กัน ChatGPT ไว้ให้
  oc-dev/Codex งาน code**. delegate batch runs, keep the main context for judgment.
- If anything here conflicts with what you observe in the repo, trust the repo + pre-commit guard,
  then fix the doc — that's the anti-drift system working as designed.

## Multi-agent collaboration (Claude Code + Codex + ZCode on this machine)

Cross-agent protocol lives in **[AGENTS.md](AGENTS.md)** (roles, write permissions, iron rules) and the
work queue in **[AGENT_TASKBOARD.md](AGENT_TASKBOARD.md)**. Claude-specific duties:

- **You are lead engineer + sole judge.** Other agents produce raw evidence; verdicts, direction, and
  Decision-log/VISION/scorecard-verdict edits are yours (or the user's) alone.
- **Before your token window ends** (or at any natural pause): leave the taskboard stocked with OPEN
  orders — each one self-contained, mechanical, with numeric acceptance criteria and explicit ห้าม.
  A Claude hour should end as "orders written + prior results judged", not as raw batch runs.
- **On-return protocol (every session start):** (1) `git log --oneline -15` — look for `[codex]`/`[zcode]`
  commits since your last one; (2) read AGENT_TASKBOARD for DONE/BLOCKED rows; (3) review their raw
  results → issue verdicts → move conclusions into scorecard/PROJECT_STATE → mark rows REVIEWED;
  (4) run `scripts/check_state.ps1` if anything looks off. Never build on unreviewed agent output.
- Don't edit rows other agents have CLAIMED; don't assume their in-flight work — check timestamps.

## Orchestration workflow

You (the orchestrator model = **Opus-seat** ตั้งแต่ 2026-07-04) plan, decompose, and synthesize — you do not do mechanical work yourself when a subagent can. **Cost rule (user directive 2026-07-03): always route to the CHEAPEST tier whose output you can still verify.** Cost order: qwen ≈ free < Sonnet < Codex ≈ you(Opus). **หมายเหตุ transition:** Opus = seat แล้ว → ไม่มี "Opus deep-reasoner tier ที่ฉลาดกว่า seat" ให้ escalate ขึ้นอีก (ดู `AGENTS.md` §1.5).

- **Qwen** (`qwen-agent` skill / claude-9arm) — zero-judgment work whose output is verifiable by numbers or a script: batch backtest runs + report parsing, reading/condensing logs, find-replace, formatting, grep-and-summarize. Brief must be self-contained; errors are cheap to catch, so cheapest model wins. **นี่คือเลนที่ควรรับงาน batch แทน oc-btest เพื่อกัน ChatGPT quota.**
- **Sonnet** (`fast-worker`) — mechanical work that needs in-session tools, repo conventions, or minor judgment: multi-file config/.set edits, scaffolding to match existing patterns, MQL5 changes that follow an established pattern (the `tpl_regression.ps1` cage catches behavior drift — run it after every `ea_template\core\` edit), running pipelines that may need mid-course adjustment.
- **Opus-seat เอง** — งานที่ mistake แพงและยังไม่มี cage: new risk/money logic, architecture, root-cause. **เดิม escalate ให้ `deep-reasoner`(Opus) — ตอนนี้ seat = Opus แล้ว จึงทำเองใน main context** (spawn deep-reasoner ได้เพื่อ offload context เฉยๆ ไม่ใช่เพื่อสมองที่ฉลาดกว่า).
- Escalate, don't default up: try the cheaper tier first when a verification cage exists; move up one tier only after it fails.
- **Codex** (`/codex:rescue --background`) = peer engineer สมองอิสระคนละ family (GPT รุ่นเก่งสุดที่มี) — **สมองที่สองตัวเดียวที่เหลือหลัง Fable ออก** → คุณค่า = คนละค่ายจับจุดบอดคนละที่ (ไม่ใช่เก่งเท่า Opus). independent perspective ไม่ใช่ reviewer ตามงาน. Don't show it the other's answer (กัน anchoring).
- For high-stakes decisions (promote demo→live · risk logic ไม่มี cage · architecture): task **Codex** on the same problem you're deciding — **โดยไม่ให้ดูคำตอบ Opus ก่อน** — then synthesize yourself. ใช้ประหยัด (Codex แชร์ ChatGPT quota ที่หมดเร็ว) — verdict ประจำวันตัดสินเดี่ยวได้.

### Superpowers plugin (obra) — ใช้เฉพาะ 3 skill ที่ข้าม domain มาช่วยงาน EA ได้ (user directive 2026-07-10)
งานเขียน/ตัดสิน EA ให้ใช้ **skill เฉพาะ repo เป็นตัวหลักเสมอ** (`strategy-and-risk` · `mql-code-generator` · `mql-code-reviewer` · `backtest-optimize-rigor` · VERDICT GATE ด้านบน · `vps-deploy-ops`). จาก superpowers ให้หยิบมาใช้ **แค่ 3 ตัวนี้ ตอนที่เหมาะเท่านั้น** — อย่าปล่อยตัวอื่น (TDD/worktrees/branch) auto-fire ชนกับ pipeline EA:
- **`brainstorming`** — ตอนคิดกลยุทธ์/ไอเดียใหม่ที่ยังไม่ตกผลึก (ก่อนเข้า `strategy-and-risk`)
- **`writing-plans`** — ตอนวางแผน build/sweep หลายขั้นที่ต้องเขียนแผนชัดก่อนลงมือ
- **`verification-before-completion`** — ก่อนปิดงาน/เขียน verdict (เสริม VERDICT GATE: ต้องพิสูจน์ว่าเสร็จจริงด้วยหลักฐาน ไม่ใช่คำอ้าง)
`systematic-debugging` ของ superpowers **ไม่ใช้** — `debug-mantra` เดิมคุมอยู่แล้ว.
