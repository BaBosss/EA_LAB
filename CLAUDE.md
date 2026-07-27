# CLAUDE.md — EA_LAB

Project state, decisions, and forward plan live in [PROJECT_STATE.md](PROJECT_STATE.md) — read that first every session. This file only holds instructions for how Claude Code itself should operate in this repo.

## 🌐 LANGUAGE RULE

**All project documents, commit messages, and log entries are written in English. All chat replies to the user are in Thai. New doc entries must be English.**

## 🚦 VERDICT GATE — decision tree + bar table (do not issue an EA verdict until you have walked this whole tree)
**This gate owns every verdict · read it every session · if you are about to write a verdict and the tree is not complete = STOP, finish the tree first.**
The full optimize procedure = skill `backtest-optimize-rigor` (owns THE LADDER 0-9). This gate is the **decision tree** that the ladder feeds evidence into.

**Window names (one pin, used everywhere):** **MAIN** = the most recent 36 months that **do not eat HOLDOUT** — always ends before holdout begins (today = **2023.01–2025.12**), re-pin at every 6-month re-opt · **BWD** = 2020–2022 (trend/stress regime) · **HOLDOUT** = a window/symbol never used for selection (default 2026H1 until it is spent — once used it is burned; after that demo-forward = holdout, and the verdict must say so). **Iron rule: MAIN ∩ HOLDOUT = ∅** — if a MAIN re-pin would slide onto the current holdout, a new holdout must be declared first (Codex system review 2026-07-18 caught the overlap 2023.07–2026.07 vs 2026H1 = a leakage channel).

```
EVIDENCE IN
│
1. STRUCTURAL?  (any one of these ⇒ kill immediately — the only legitimate death, no optimize owed)
   · uncapped ruin: no SL AND no depth cap (maxOpen≥8) AND geometric ladder
     — check the 4 martingale questions first (SL? · capped steps? · flat-lot edge? · conditional adds?) —
       capped+SL+edge ≠ ruin
   · ⚠️ **RULE CHANGE 2026-07-19 (user ratified):** flat-lot PF<1 while escalated PF>1 = **no longer an auto-kill**
     → classify as **ENGINE-EDGE class** (the edge is in the escalation engine, not in the signal); it may proceed
     once it clears **all 5 cage conditions**: (1) worst case is computable — hard depth cap + basket-SL/DD-kill +
     state the number "a single loss costs ≤15% equity" at the real sizing (2) **BWD 2020-22 = HARD gate** (the
     engine must actually be stressed — the normal soft-gate is not enough for this class) (3) **Model-4 always
     mandatory** (4) MC ruin ≤2% at the real sizing (5) scorecard label = **engine-edge** → permanently small
     sizing, NuiIndy-style; never size up on PF. The flat-lot probe is still mandatory, but its job is to
     diagnose where the edge lives, not to sign a death certificate.
     (precedent: NuiIndy live PF~2.0 + CutLoss=30 proves this class can survive when caged)
     (TH verbatim: "flat-lot PF<1 ขณะ escalated PF>1 = ไม่ auto-kill แล้ว → จัดเข้า ENGINE-EDGE class
      เดินต่อได้เมื่อผ่านกรง 5 ข้อครบ · sizing เล็กถาวรแบบ NuiIndy ห้าม size-up ตาม PF ·
      flat-lot probe ยังบังคับรัน แต่หน้าที่ = วินิจฉัยว่า edge อยู่ไหน ไม่ใช่ใบมรณะ")
   · cracked / expired / locked-no-source (legal-ops DQ)
   · pure fill-artifact: M4 flips the sign across the whole surface / tight-TP fiction
   ⇒ DEAD-STRUCTURAL → EDGE_CATALOG dead pile + scorecard kill-reason
     (course-file rule: extract the entry CONCEPT before discarding the vehicle — [[feedback-course-files-extract-idea]])
│
2. else PARAMETRIC — you may not kill it yet.
   RIGHT HOME first (reversion→EURUSD/EURGBP/AUDNZD ranger · momentum→XAU/GBP trender;
   landing in the wrong home ≠ death). Walk the ladder ≥3 levers × ≥2 TF on the correct home.
   │
   ├─ 2a. ceiling < 1.0 both-window on the RIGHT home  AND  the final LAST-OPTIMIZE has been done
   │      (one mandatory round on a lever not yet touched, picked from the diagnosis→lever table,
   │       immediately before pulling the trigger — even if a lot of optimizing has already happened)
   │      ⇒ DEAD-OPTIMIZED. Close at CELL level by default · a CONCEPT may only die once the
   │        right-home ceiling has been proven. A default-param smoke can only ever close a CELL.
   │
   ├─ 2b. PF>1 anywhere, but still under the deploy bars
   │      ⇒ BUILD-ON (the DEFAULT — not bench-and-forget):
   │        · widen symbol×TF (take every home that clears the bar · pairwise corr<0.8)
   │        · adjust the mechanism before accepting as before (e.g. pending-limit entry — but
   │          pending-rescue is only valid for market-on-signal entries, never for grid
   │          trigger-touch; doctrine 2026-07-17)
   │        · extract the entry mechanism into EDGE_CATALOG even if the EA never deploys
   │        good idea that still does not pass ⇒ PARKED-VERIFY(user): tag + a 3-line brief
   │        (what it is · which gate killed it · why it is still interesting). It must not die silently.
   │
   └─ 2c. clears the pre-registered bars ⇒ VALIDATED CANDIDATE → deploy funnel:
          lock the plateau-center .set → both-window → sensitivity fan → holdout (or declare
          demo-forward-as-holdout once selection has already eaten BWD — Boss_16 precedent) →
          MC (resize-first on a cap breach) → Model-4 if fill-sensitive → corr vs cohort
          ⇒ DEMO  (DEPLOYMENTS.csv row + judge criteria pre-registered at attach time)
          ⇒ ≥3 months demo forward → judge ⇒ LIVE (real money)
             (irreversible: a Codex second opinion is mandatory, no anchoring · + a Fable-advisor
              one-shot case-3 while quota exists — if Fable is unavailable the Opus-seat decides,
              but the Codex leg can never be skipped)
```

**Bar table (one number per transition):**

| Transition | Bar |
|---|---|
| smoke pulse → PROCEED | one cell, naked PF ≥ **1.2** at an n appropriate to the type (WATCH = 1.0–1.2) |
| optimize pass → CANDIDATE | **MAIN ≥ 1.2** (hard) AND **BWD ≥ 1.0** (soft-gate) + a plateau, not a spike. **BWD-fail = no auto-kill → PARKED-VERIFY(user): demo-isolate may be approved, but the route to real money is closed automatically** (user Q3 2026-07-18) <br>(TH verbatim: "BWD-fail = ไม่ auto-kill → PARKED-VERIFY(user): เคาะ demo-isolate ได้ แต่ปิดทางเงินจริงอัตโนมัติ") |
| holdout | PF ≥ **1.2** at an appropriate n ⇒ deploy track · **1.0–1.2 ⇒ BUILD-ON** (JUMSTOCH precedent) · <1.0 ⇒ selection-fit, go back to diagnosis |
| MC | ruin ≤ **2%** (resize-first allowed up to 10%) · PF-5th ≥ **1.0** |
| Model-4 (when it comes due) | both-window PF ≥ **1.0** retained AND largest-loss does not explode (no model-switch cliff) |
| demo → LIVE | ≥ **3 months** · judge PF ≥ **1.40** at ≥ **30 trades** · no pre-registered kill tripped |
| demo kill (default; per-EA override allowed at attach time) | eqDD > **12%** · 3-mo PF < **0.8** at ≥ **15 trades** |
| **guard/filter/kill-switch (when it is to be counted as evidence)** | must have a **base control run** over a window where the guard *should* fire **and** must report **how many times it actually fired** · fired 0 times = **`UNTESTED`, must not be written up as passed** · numbers identical to base in every digit = evidence it is **inert**, not evidence it is **safe** |

**Canonical verdict vocabulary (retire every other term):**
`DEAD-STRUCTURAL · DEAD-OPTIMIZED · PARKED-VERIFY(user) · BUILD-ON · CANDIDATE · DEMO · LIVE`
(PASS/CONDITIONAL/ROBUST/MARGINAL/Mode-B from the old skill = retired). **Discard semantics:** STRUCTURAL = the only legitimate death (kill immediately, no optimize owed · the concept may still be extracted) · DEAD-OPTIMIZED = a terminal state that must be *earned* (close the cell/concept after a full ladder + last-optimize) · **everything else must not be discarded.**

**📋 Row-X write-checklist — check these 5 lines before writing any verdict:**
- [ ] **scorecard** (`EA_SCORECARD_AND_REGISTRY.md`) update verdict + kill-reason
- [ ] **EA_MASTER_INDEX** updated in the same commit (hook-enforced)
- [ ] **EDGE_CATALOG** — dead pile, or a reusable-lever/mechanism entry
- [ ] **B1_DATASET.csv** row in the same REVIEWED commit (definition = B1_COHORT.md)
- [ ] **user brief** if PARKED-VERIFY (3 lines: what it is / which gate killed it / why it is interesting)
- [ ] if the verdict claims any benefit from a **guard/filter** — state **how many times the guard fired** + the path of the **base control run**

<sub>**paid-for history (real lessons — never delete):** 2026-07-08 called "dead" wrongly twice in one session because the optimize was incomplete (→ tree item 2) · 2026-07-10 ST03 "no-edge" was measured under a single scalp-exit (→ exit-mode is a lever) · 2026-07-16 SMC×STO died on a default-smoke, then optimize+ADX turned it into a real EURUSD candidate (→ item 2a: a default-smoke can only close a cell; StoK 5→17 flipped the result = optimize the entry-signal as the first lever) · 2026-07-17 Model-2 manufactured a fake grid plateau, AUDNZD PF 3-4 → M4 0.61 (→ grid under Model-2 is not evidence) · 2026-07-18 last-optimize-before-verdict + BWD soft-gate (user rule). Full provenance = memory `feedback-last-optimize-before-verdict` · `feedback-buildon-pf-gt-1` · `feedback-optimize-before-killing-reversion`.
(TH verbatim: "2026-07-08 ตัด 'dead' ผิด 2 ครั้ง/session เพราะ optimize ไม่ครบ · 2026-07-10 ST03 'no-edge' วัดใต้ scalp-exit เดียว · 2026-07-16 SMC×STO ตายจาก default-smoke แล้ว optimize+ADX กลายเป็น EURUSD candidate จริง; default-smoke ปิดได้แค่ cell; StoK 5→17 พลิกผล · 2026-07-17 Model-2 ปั้น fake grid plateau AUDNZD PF 3-4→M4 0.61; grid = Model-2 ไม่ใช่หลักฐาน · 2026-07-18 last-optimize-before-verdict + BWD soft-gate")</sub>

## Model transition (Fable → Opus) — ✅ ACTIVE since 2026-07-04 (Fable quota genuinely ran out, earlier than the 07-07 plan)

**UPDATE 2026-07-23 (user ratified):** **the Fable-seat is permanently available again** — the old
1-week trial condition is over, and the "reserved for 4 cases" rule below is obsolete · whatever model
the seat currently runs on performs the full lead/judge role · if Fable disappears again → continue on
Opus · the commit trailer accepts both Fable and Opus (AGENTS.md §5) ·
**the one condition the user stressed: Fable is expensive — mechanical work must always be distributed
to cheaper tiers (qwen/Sonnet/Codex per the cost ladder); never burn Fable as batch labour.**
(TH verbatim: "เงื่อนไขเดียวที่ user ย้ำ: Fable แพง — ต้องกระจายงาน mechanical ให้ tier ถูกกว่าเสมอ
(qwen/Sonnet/Codex ตาม cost ladder) ห้ามเผา Fable เป็นแรงงาน batch")

<sub>Earlier UPDATE 2026-07-11 (obsolete — kept as history): Fable had ~10% quota left, so it was reserved for
4 cases via the `fable-advisor` skill: (1) the ST03 verdict the user optimized by hand (2) reviewing the
ORDER-082 Wave5 spec (3) the first real-money promotion of the next candidate (4) RCA of an abnormal
real-money event · full plan = `PROJECT_STATE.md` §7</sub>

**The lead/judge seat = Claude Code running on Opus.** The role belongs to the seat, not to the model —
Opus performs everything Fable used to do. Full post-transition team workflow (tier ladder + quota lane +
Codex review) = **`AGENTS.md` §1.5 + §5** (owns the multi-agent protocol — read the two together).

- Nothing project-critical lives in any model's head. Everything is in: `VISION.md` → `PROJECT_STATE.md`
  → `ROADMAP.md` → `AGENTS.md`/`AGENT_TASKBOARD.md` → skills (`C:\Users\patip\.claude\skills\`) →
  auto-memory (same directory, persists across models). Read in that order on first session.
- **The top rung of the escalation ladder is gone:** the seat is Opus, so spawning a `deep-reasoner`(Opus)
  subagent is the same brain with a fresh context (it offloads context; it is not a smarter capability).
  Work that used to be escalated to deep-reasoner (new money/risk logic, architecture, root-cause) →
  **do it yourself in the main context**. The only remaining independent brain from a different family is
  **Codex (the strongest GPT model configured here)** — its value is "a different vendor catches different
  blind spots", not "as strong as Opus" → a mandatory Codex second opinion applies **only to expensive /
  irreversible decisions** (promote demo→live · risk logic with no cage · architecture), not to every verdict.
- Honor every user rule in the Decision log verbatim (Model-2 ban, no-DEAD-before-optimize,
  cap-breach-resize-first, correlation→reduce-lot-not-cut, 3-year window). These were each paid for
  with real mistakes — do not re-litigate them without new evidence.
- The user prefers decisions presented as real-workflow scenarios with one decisive recommendation,
  in Thai, short (see memory: feedback-simple-language-decisions). Cost matters: cheapest verifiable
  tier first — **batch runs must avoid the ChatGPT quota (qwen → ZCode/GLM → oc-btest is cheapest);
  reserve ChatGPT for oc-dev/Codex code work**. Delegate batch runs, keep the main context for judgment.
  (TH verbatim: "batch run เลี่ยง ChatGPT quota (qwen → ZCode/GLM → oc-btest ถูกสุด), กัน ChatGPT ไว้ให้ oc-dev/Codex งาน code")
- If anything here conflicts with what you observe in the repo, trust the repo + pre-commit guard,
  then fix the doc — that's the anti-drift system working as designed.

## Multi-agent collaboration (Claude Code + Codex + ZCode on this machine)

Cross-agent protocol lives in **[AGENTS.md](AGENTS.md)** (roles, write permissions, iron rules) and the
work queue in **[AGENT_TASKBOARD.md](AGENT_TASKBOARD.md)**. Claude-specific duties:

- **You are lead engineer + sole judge.** Other agents produce raw evidence; verdicts, direction, and
  Decision-log/VISION/scorecard-verdict edits are yours (or the user's) alone.
- **Before your token window ends** (or at any natural pause): leave the taskboard stocked with OPEN
  orders — each one self-contained, mechanical, with numeric acceptance criteria and an explicit
  list of prohibitions. A Claude hour should end as "orders written + prior results judged", not as
  raw batch runs.
- **On-return protocol (every session start):** (1) `git log --oneline -15` — look for `[codex]`/`[zcode]`
  commits since your last one; (2) read AGENT_TASKBOARD for DONE/BLOCKED rows; (3) review their raw
  results → issue verdicts → move conclusions into scorecard/PROJECT_STATE → mark rows REVIEWED;
  (4) run `scripts/check_state.ps1` if anything looks off. Never build on unreviewed agent output.
- Don't edit rows other agents have CLAIMED; don't assume their in-flight work — check timestamps.

## Orchestration workflow

You (the orchestrator model = **Opus-seat** since 2026-07-04) plan, decompose, and synthesize — you do not do mechanical work yourself when a subagent can. **Cost rule (user directive 2026-07-03): always route to the CHEAPEST tier whose output you can still verify.** Cost order: qwen ≈ free < Sonnet < Codex ≈ you(Opus). **Transition note:** the seat is now Opus → there is no "Opus deep-reasoner tier smarter than the seat" left to escalate to (see `AGENTS.md` §1.5).

- **Qwen** (`qwen-agent` skill / claude-9arm) — zero-judgment work whose output is verifiable by numbers or a script: batch backtest runs + report parsing, reading/condensing logs, find-replace, formatting, grep-and-summarize. Brief must be self-contained; errors are cheap to catch, so cheapest model wins. **This is the lane that should absorb batch work instead of oc-btest, to protect the ChatGPT quota.**
- **Sonnet** (`fast-worker`) — mechanical work that needs in-session tools, repo conventions, or minor judgment: multi-file config/.set edits, scaffolding to match existing patterns, MQL5 changes that follow an established pattern (the `tpl_regression.ps1` cage catches behavior drift — run it after every `ea_template\core\` edit), running pipelines that may need mid-course adjustment.
- **The Opus-seat itself** — work where a mistake is expensive and no cage exists yet: new risk/money logic, architecture, root-cause. **This used to be escalated to `deep-reasoner`(Opus); now that the seat is Opus, do it in the main context** (spawn deep-reasoner only to offload context, never for a smarter brain).
- Escalate, don't default up: try the cheaper tier first when a verification cage exists; move up one tier only after it fails.
- **Codex** (`/codex:rescue --background`) = a peer engineer, an independent brain from a different family (the strongest GPT available here) — **the only second brain left after Fable stepped out** → its value is that a different vendor catches different blind spots (not that it matches Opus). An independent perspective, not a reviewer who follows your work. Don't show it the other's answer (to prevent anchoring).
- For high-stakes decisions (promote demo→live · risk logic with no cage · architecture): task **Codex** on the same problem you're deciding — **without letting it see the Opus answer first** — then synthesize yourself. Use it sparingly (Codex shares the ChatGPT quota, which runs out fast) — day-to-day verdicts can be decided solo.

### Superpowers plugin (obra) — use only the 3 skills that cross domains usefully into EA work (user directive 2026-07-10)
For writing/judging EA work, **always use the repo-specific skills as the primary tools** (`strategy-and-risk` · `mql-code-generator` · `mql-code-reviewer` · `backtest-optimize-rigor` · the VERDICT GATE above · `vps-deploy-ops`). From superpowers, pick up **only these 3, and only when they fit** — do not let the others (TDD/worktrees/branch) auto-fire and collide with the EA pipeline:
- **`brainstorming`** — when working out a new strategy/idea that has not crystallized yet (before entering `strategy-and-risk`)
- **`writing-plans`** — when planning a multi-step build/sweep that needs a clear written plan before starting
- **`verification-before-completion`** — before closing work / writing a verdict (reinforces the VERDICT GATE: prove completion with evidence, not with a claim)
Superpowers' `systematic-debugging` is **not used** — the existing `debug-mantra` already covers it.
(TH verbatim: "งานเขียน/ตัดสิน EA ให้ใช้ skill เฉพาะ repo เป็นตัวหลักเสมอ · จาก superpowers ให้หยิบมาใช้แค่ 3 ตัวนี้ ตอนที่เหมาะเท่านั้น — อย่าปล่อยตัวอื่น (TDD/worktrees/branch) auto-fire ชนกับ pipeline EA · systematic-debugging ของ superpowers ไม่ใช้ — debug-mantra เดิมคุมอยู่แล้ว")
