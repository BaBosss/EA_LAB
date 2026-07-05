# CLAUDE.md — EA_LAB

Project state, decisions, and forward plan live in [PROJECT_STATE.md](PROJECT_STATE.md) — read that first every session. This file only holds instructions for how Claude Code itself should operate in this repo.

## Model transition (Fable → Opus) — ✅ ACTIVE ตั้งแต่ 2026-07-04 (Fable โควต้าหมดจริง เร็วกว่าแผน 07-07)

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
