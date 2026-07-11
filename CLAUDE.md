# CLAUDE.md — EA_LAB

Project state, decisions, and forward plan live in [PROJECT_STATE.md](PROJECT_STATE.md) — read that first every session. This file only holds instructions for how Claude Code itself should operate in this repo.

## 🚦 VERDICT GATE — ห้ามตัดสิน EA (DEAD/PARKED/REJECT หรือ DEPLOY/PASS) จนกว่าจะเติม block นี้ครบ
**(paid for with real mistakes 2026-07-08: ตัดสิน "dead" ผิด 2 ครั้งใน session เดียว เพราะ optimize
ไม่ครบขั้นตอน — user จับได้ทั้งคู่. gate นี้คือกันไม่ให้ session ไหนพลาดซ้ำ. ถ้าจะเขียน verdict แล้ว
block นี้ยังไม่ครบ = หยุด ทำให้ครบก่อน.)**

1. **Levers swept?** list ทุก lever ที่เกี่ยว — `spacing · lot-law · SL-width · TP · exit-mode · entry-threshold · symbol · TF` — mark ตัวไหน swept / ตัวไหน held. **source-available EA ที่ verdict จาก <3 lever ที่ swept = INVALID.** ("ปรับแล้ว" มักแปลว่าปรับ 1 ใน 8 — ต้องเช็คจริง · exit-mode เพิ่ม 2026-07-10: ST03 "no-edge" รอบแรกวัดใต้ scalp-exit เดียว user จับได้ · scope ชัดขึ้น 2026-07-11 หลัง Codex audit C3: กติกานี้ใช้กับ **verdict ระดับ EA/concept** — smoke ที่ตกบาร์ pre-registered = "ปิด cell" ได้โดยไม่ต้อง sweep แต่**ห้ามเขียนเป็น concept ตายสากล** · Model-2 ใช้ได้เฉพาะทิศฆ่า (optimistic bias) ห้ามใช้ทิศผ่าน)
2. **Coarse→surface?** เห็น *surface* (หลายจุด/axis) ไม่ใช่ 1-2 จุด? เป็น plateau (neighbor ไม่มีตัวขาดทุน) หรือ spike? — spike/hole = ยังไม่ผ่าน
3. **Both regimes?** เทส candidate config บน **ทั้งปีเทรนด์ (BWD 2020-22) + ปีล่าสุด พร้อมกัน**? (lever ที่ดีที่สุด window นึงมัก invert อีก window)
4. **REJECT เป็นแบบไหน?** STRUCTURAL (martingale-fat-tail / DD-blowup 90%+ / no-source / cracked) → ฆ่าได้ tune ไม่ช่วย · PARAMETRIC (แพ้ที่ window เดียว/setting เดียว) → **ต้อง sweep ก่อน reject — ขั้นต่ำเชิงตัวเลข (user rule 2026-07-10): ตัวที่ผ่านเกณฑ์เบื้องต้นแล้ว ห้ามตีตายจนกว่าจะ optimize ≥3 รอบ (ชุด lever ต่างกัน เลือกตาม strategy ของ EA นั้น) × ≥2 TF ต่อ symbol** และพิจารณา symbol อื่นที่เข้ากับ mechanism ก่อนปิด · **ตัวที่ idea ดีแต่ไม่ผ่าน = tag `PARKED-VERIFY(user)` + แจ้ง user เสมอ** (user มีประสบการณ์มือที่เครื่องมือไม่มี — หลาย EA ที่ใช้อยู่รอดมาเพราะ user เคยเทสเอง) — ห้ามปล่อยของดีตายเงียบ
5. **Martingale ไม่ใช่ auto-reject** — recheck 4 ข้อก่อนทิ้ง: **มี SL ไหม · จำกัดจำนวนไม้ (capped steps) ไหม · entry มี edge จริงไหม (flat-lot test: ปิด escalation แล้ว PF ยัง >1?) · ดื้อ (add ตลอด) หรือมีเงื่อนไข**. capped-martingale + SL + entry-edge ≠ uncapped-ruin
6. **DEPLOY/PASS เพิ่ม:** ผ่าน **holdout window ที่ไม่เคยใช้ select** + MC? plateau-center (ไม่ใช่ peak)? — in-sample plateau = selection-fit ยังไม่ใช่ validated

รายละเอียดเต็ม + ตัวอย่าง = `OPTIMIZE_PROCEDURE_AND_AUDIT.md` + skill `backtest-optimize-rigor` (owns ขั้นตอน). gate นี้ = สรุปบังคับ อ่านทุก session.

**⚖️ BUILD-ON ≠ DEPLOY (user doctrine 2026-07-11 — gate ข้างบนคุม "ขึ้นเงินจริง" ไม่ใช่ "ทิ้ง"):** EA ที่ test
**PF>1 แม้ครั้งเดียว/แม้ OOS ไม่ถึงบาร์ deploy = ของต่อยอด ไม่ใช่ bench-and-forget**. PARAMETRIC-marginal (PF>1
ใต้บาร์) → **default ไป build-on branch ก่อนเขียน verdict:** (1) ขยาย symbol×TF ให้ครบ (10+ คู่ ทุก TF — home
อาจดีกว่ามากที่อื่น) (2) **ปรับกลไก ไม่ใช่รับตามเดิม** — เช่น spread concern → เปลี่ยน market entry เป็น pending
buy/sell limit (fill แบบ maker ไม่จ่าย spread) · grid/เทรดเยอะ = ไม่ใช่ข้อเสีย (3) แกะ entry logic เก็บ EDGE_CATALOG
แม้ทั้ง EA ไม่ deploy. **เฉพาะ STRUCTURAL death (flat-lot PF<1 · uncapped-ruin · cracked) เท่านั้นที่ฆ่าทิ้งเลย** ·
deploy-gate กับ discard-gate = คนละคำถาม. รายละเอียด = memory `feedback-buildon-pf-gt-1`.
**เอาทุก home ที่ผ่านเกณฑ์ ไม่ใช่ home เดียวที่ดีสุด** (EA ตัวเดียวรันหลาย symbol ได้) · gate reuse ข้าม symbol
ของ EA เดียวกัน = **pairwise corr < 0.8** (หลวมกว่า cross-EA portfolio 0.4/0.6) · เกิน 0.8 = redundant → บอก
user เลือกเอง ไม่ auto-drop · cell ที่เฉียดบาร์ = ปรับได้ (filter/ขยาย grid spacing) ไม่ใช่ตายทันที.

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
