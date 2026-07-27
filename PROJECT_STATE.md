# PROJECT_STATE — EA_LAB single living state (👉 AI START HERE)

> **Read [PROJECT_HISTORY.md](PROJECT_HISTORY.md) only when a task touches past work.** It holds the
> session narrative, the accumulated changelog, and the full Decision log with provenance. This file
> holds only: current status, active work, binding decisions, and the forward plan.

> **last updated:** 2026-07-27 (Opus-seat) — sessions `CUTLOSS` / `CUTLOSS-VERIFY` closed; ORDER-370/371 open.
> Full session-by-session history → `PROJECT_HISTORY.md`. · owner: patip

---

## 0. UPDATE PROTOCOL — how to maintain this file (read + do every session)

1. **Always open this file first** when starting a new session (before README, before MASTER_BACKLOG).
2. **Every time a large piece of work finishes → update this file:** edit the relevant section, bump
   `last updated`, add a line to the Decision log (section 3) if a new decision was made, update the
   Forward plan (section 7).
3. **The truth is in the file, not in the chat** — anything not written here or into the canonical docs
   is lost when the session ends.
4. **Do not duplicate content** — if it already exists in DEMO_DEPLOYMENT_PLAN / MASTER_BACKLOG /
   EA_SCORECARD, link to it instead of copying the whole block (this is what prevents self-contradiction).
   This file keeps only "the summary + the pointers".
5. **Commit to git every time this file is edited** (this file is the memory that crosses people and AIs).

---

## 0.5 ANTI-DRIFT — keeping the docs from skewing (so that "next read = last read")

The original problem: several files claimed overlapping authority + the same fact was written in several
places → hand updates made them skew. Three rules:

**1) One fact has one owner** — the fact lives in one file; everywhere else **links, never copies**:

| fact | sole owner | elsewhere |
|---|---|---|
| status% · decisions · plan · invariants | **PROJECT_STATE.md** (this file) | link |
| owner's big picture / factory philosophy | **VISION.md** | link |
| multi-agent rules (Claude/Codex/ZCode) | **AGENTS.md** | link |
| central work queue + raw results awaiting review | **AGENT_TASKBOARD.md** | link |
| live portfolio — **the data** (account/EA/magic/status/kill/judge) | **`portfolio\DEPLOYMENTS.csv`** (the single inventory, ORDER-093) | link · checker validates on every commit |
| deployment → approved bundle artifacts (attestation expectations) | **`portfolio\ATTESTATION_MAP.csv`** (CR-002, 2026-07-19) | link · snapshot v2 hash compared daily |
| live portfolio — **the accounts** (governance_scope/expected_sensor/SLA/alert_policy at account level) | **`portfolio\ACCOUNTS.csv`** (CR-003b, 2026-07-24) | link · the snapshot reads the account universe from this file · DEPLOYMENTS = per-EA only |
| live portfolio — **the explanation/context** (why attached, warnings, history) | **DEMO_DEPLOYMENT_PLAN.md** | link |
| backlog · coverage · hunt | **MASTER_BACKLOG.md** | link |
| EA registry · scoring · kill-reason | **EA_SCORECARD_AND_REGISTRY.md** | link |
| file map · the 5 locations | **PLATFORM_INDEX.md** | link |
| EA_CORE framework | `D:\EA_Project` docs + `EA_CORE_ST03_LOOP_PLAN.md` | link |

If two files say different things about the same subject → **INVARIANTS (rule 3) wins**, then fix the
wrong file immediately.

**2) PROJECT_STATE = the single entry** — no other file may write "just open this one file". A secondary
doc opens with the banner: `> ⚠️ canonical entry = PROJECT_STATE.md · this file owns: <X only>`.

**3) INVARIANTS — facts that must match everywhere (wherever it differs, that place is wrong):**
- **every deployment (account/EA/magic/status/kill/judge) = `portfolio\DEPLOYMENTS.csv`, one row per magic**
  (ORDER-093, 2026-07-11 — replaces the old invariant set "9 EA/1 account/judge 09-22" that had been stale
  since the 06-22 era; current reality = 5 accounts, see DEMO_DEPLOYMENT_PLAN §DEPLOYMENT REALITY 2026-07-09) ·
  wherever a deployment changes, the CSV must be changed first, and the checker will then force the
  dashboard map + docs to match
- backtest window: **MAIN 2023.01–2025.12** (36 months, does not eat the 2026H1 holdout) · re-opt/re-pin every 6 months
- magic numbers must not collide — enforced by the checker from the CSV (duplicate account|magic = WARN/block)
- **the bot enforces this itself:** the git **pre-commit hook** (`.githooks/pre-commit`) runs
  `scripts/check_state.ps1 -Strict` automatically on every commit → validates every doc/dashboard-map against
  `DEPLOYMENTS.csv` in both directions (a CSV row missing from the map = a magic that is not monitored · a map
  entry with no CSV row = a ghost row) + single entry + banner. One-time setup per machine:
  `git config core.hooksPath .githooks`. Emergency bypass: `git commit --no-verify`. Manual run:
  `powershell -File scripts/check_state.ps1`
  > ⚠️ **Guard scope:** it governs structural deployment consistency — **not all content** (PF, EA status and
  > other numbers still have to be read/updated by hand). A GUI commit client may hide hook output — if a
  > commit is blocked for no apparent reason, run the check by hand.

---

## 1. Goal + 4-layer overview (1 factory + 1 mold + 1 parts warehouse → real portfolio)

> **Ultimate goal:** 10 portfolios × 2–3 EAs that **don't correlate** × 10,000 cent → passive income.
> **Owner's big-picture/factory philosophy → `VISION.md`** (read alongside this file every session — if the work conflicts with VISION, stop and ask the owner)

| Name | Actual location | Role (aligned 2026-07-03) | Status % |
|---|---|---|---|
| **EA_LAB** | `D:\EA_LAB` (this repo) | Factory — find/validate/deploy EA + automation pipeline | 90% mature |
| **EA_Template (Boss V2)** | `D:\EA_LAB\ea_template` | **the factory's single master mold** (UNFREEZE 2026-07-03) — shared central functions (MM/lot/SL/grid/hedge/recovery), differ only by entry+TF · every new EA build comes out of here | chassis done · remaining: fill in Hedge/Recovery + smoke-regression |
| **EA_Project / EA_CORE** | `D:\EA_Project\CURRENT_BUILD` (CORE = engine) | 🏛️ **read-only ARCHIVE (MERGE-08, 2026-07-06)** — parts fully ported into the mold · reference/evidence only, no deletion, no new work | 100% — track closed (`AGENT_TASKBOARD_MERGE.md`) |
| **Live Portfolio** | account 10,000 cent (demo) | **the real goal** — real money | 20% (9 EAs fully live, awaiting judge) |

Note: "EA_Project" and "EA_CORE" = the same track (Project = repo, Core = engine inside).

---

## 2. Current status (one-liner per layer)

> 🆕 **2026-07-26 (Opus-seat) — SuperTrendFlip lever campaign round closed · full handoff = [`_triage/HANDOFF_2026-07-26_SUPERTRENDFLIP_LEVER_CAMPAIGN.md`](_triage/HANDOFF_2026-07-26_SUPERTRENDFLIP_LEVER_CAMPAIGN.md)**
> **Got 1 candidate:** BTCUSD H4 `(TRD)_SuperTrendFlip_rev03` (Donchian20 + pyramid MaxAdds=1) — M4 with swap already deducted
> MAIN **2.257**/50 · BWD **3.949**/66 · **HOLDOUT 2026H1 = 4.274**/9 (already burned) · MC ruin 0% PF-5th 1.052 ·
> fan 69/81 · corr +0.167 vs real-money ⇒ **VALIDATED CANDIDATE awaiting user's call on demo attach**
> **2 new levers (additive, default-off, regression passed):** Kaufman ER gate (`rev02`, worked on XAU H4) · capped pyramid (`rev03`, worked on BTC H4)
> **Strategy-level conclusion:** SuperTrend flip = an edge of the 2023-2025 regime (every cell breaks even on BWD **except BTC H4**) ·
> **BTC H4 is a special case, not the lead for the crypto fleet** (ETH fails at MC, the portable stack doesn't travel) ⇒ the "chain 20 symbols" plan = **20 separate funnels**
> **🔴 3 gotchas that affect other work:** (1) the tester charges swap in POINTS mode but **does not charge** INTEREST_CURRENT mode ⇒ **XAU backtests already deduct financing · crypto has not been deducted yet**
> (2) BTCUSD tick data differs across MT5 installs ⇒ crypto A/B must stay on the same lane (3) `select_robust_pass.py` reports the fan for basket-type EAs wrong — read raw XML

- **EA_LAB 90%** — pipeline complete (intake→smoke→IS/OOS→MC→corr→deploy). Remaining 10% = work tied to
  real time (operate up to judge, expand from 1→multiple portfolios), not more build work.
- **EA_Template (Boss V2)** — the single master mold. Remaining work to become a full mold: (1) fill in the
  real Hedge/Recovery module (currently a disabled stub) (2) add a small smoke-regression suite (3) port
  Zeus grid/LOG in as an entry after Zeus passes validation. Note: `modules\`(V1) vs `core\`(V2)
  duplication is intentional, not junk. Architecture + usage → `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`.
- **EA_CORE** — R&D parts warehouse. Loop closed 2026-07-02; engineering-complete framework ready to reuse
  once there is a signal with a genuine edge. **Do not re-tune this parameter family.**
- **Live Portfolio 20%** — 9 EAs fully live (deploy confirmed 2026-07-02). Live clock started 2026-06-22 →
  earliest judge **2026-09-22**. Blocker = time (waiting on the 3-month demo) + not yet expanded from
  1 → multiple portfolios.
- **Signal hunt — not saturated.** Old dead concepts stay dead (see `MASTER_BACKLOG.md`), but the
  mechanism×symbol axis is still open.

Everything dated 2026-07-02 → 07-11 (ST03 structural kill, CODEX-AUDIT hardening, Boss_16 bench pass,
Zeus build-on, the MERGE track) → **`PROJECT_HISTORY.md` §2 archive**.

---

## 3. DECISION LOG — binding rules (locked — do not re-litigate without new evidence)

> This section keeps only rules that **still constrain future work**, stated in their operative form.
> Closure records, one-off events, and the full reasoning behind every row →
> **`PROJECT_HISTORY.md` §E (complete decision log, 55 rows)**. CLAUDE.md requires these be honored
> verbatim; each was paid for with a real mistake, so the Thai the user ratified is kept alongside.

| Date | Binding rule | Why (full provenance → PROJECT_HISTORY §E) |
|---|---|---|
| ongoing | **correlation:** ≤0.40 additive · 0.40–0.60 watch · >0.60 redundant → **reduce lot, don't cut** | user rule (TH: "user rule (memory: correlation-vs-lotsize)") |
| ongoing | **backtest window = MAIN 36 months (2023.01–2025.12, must not overlap holdout)** · re-opt every 6 months · never stretch to 10 years to "fix MC" | re-pinned by the 2026-07-18 decision |
| ongoing | **demo ≥3 months, no shortcuts** before live micro | README iron rule |
| 2026-06-23 | **DD% is not a hard gate** | DD is fixable by sizing/spacing; the structural gate is the mechanism |
| 2026-06-29 | **PROJECT_STATE.md = the central living doc** | (TH: "ให้ AI ทุกตัวเข้าใจตรงกัน (user request)") |
| 2026-07-02 | **Do not re-tune the ST03/EA_CORE family without a new signal** | 48/48 combos OOS PF<1.0 + pure signal PF 0.67 |
| 2026-07-03 | **user rule: never verdict DEAD/REJECT until an actual optimize has been tried** — a verdict from one param set is always PARKED-pending-optimize | 3/4 symbols recovered after a 54-pass probe, within an hour of the rule being set (TH: "user rule: ห้ามตัดสิน DEAD/REJECT จนกว่าจะลอง optimize จริง") |
| 2026-07-03 | **user rule: a cap breach (DD/margin/deposit-load/MC-ruin) = resize-first, never reject directly.** Rejecting on a cap is allowed only when (1) resizing into band makes the edge fail the gate (2) already at min-lot and still over (3) no config fits the band (4) no trade ever opens. An edge failure (PF) may be rejected directly — PF doesn't depend on scale | enforced in 4 skills (TH: "user rule: cap breach (DD/margin/deposit-load/MC-ruin) = resize-first ห้าม reject ตรงๆ") |
| 2026-07-03 | **mechanism-risk = a score-penalty (−25pt), not a hard gate** + **Model 1 is the minimum before any REJECT/DISQUALIFIED**; Model 2 may only filter zero-trade cases, never report or rank PF | caught 3 false positives the same day (TH: "user-corrected — ป้องกัน reject EA ทิ้งก่อนวัดผลจริง") |
| 2026-07-03 | **Boss V2 = the one main template** · EA_CORE = R&D parts warehouse · standalone = a temporary fast lane, must be ported once an edge is proven | the owner must be able to understand the whole system |
| 2026-07-03 | **Work mode = permanently dual-track**; the unsaturated hunting axis = **mechanism×symbol** | retires "pure operate" |
| 2026-07-03 | **The 9 live EAs stay untouched until judge** | touching them destroys the experiment's data |
| 2026-07-03 | **`VISION.md` owns the big picture** — read alongside PROJECT_STATE; work conflicting with VISION must stop and ask | drift root cause: the owner's picture was never written down |
| 2026-07-03 | **Claude = lead/judge only · Codex = peer engineer · ZCode = batch runner** · handoffs via `AGENT_TASKBOARD.md` · single-writer: VISION/Decision log/verdict = Claude/user only | full rules → `AGENTS.md` |
| 2026-07-03 | **ROADMAP user parameters:** done = the system runs itself · 10 genuinely separate accounts · live micro immediately after judge · 2–4 days/week · phase gates tied to evidence, not calendar dates | (TH: "user parameters: จบ=ระบบหมุนเอง · 10 account แยกจริง · live micro ทันทีหลัง judge · เวลา user 2–4 วัน/สัปดาห์") |
| 2026-07-04 | **Model-transition rules:** seat=Opus · no deep-reasoner tier above the seat · Codex = the one independent mind, review only for expensive/irreversible work · batch avoids ChatGPT quota (qwen→ZCode/GLM→oc-btest) · never run Codex+OpenClaw heavy together | `AGENTS.md` §1.5+§5 (TH: "user: Fable หมด ต้องใช้ Opus แทน") |
| 2026-07-06 | **Chasing a quant method, not a quant firm** · ❌ multi-venue tick infra / low-latency / ML alpha / custom backtester · ✅ Phase 3.5 PORTFOLIO-QUANT after judge — **forbidden to insert before the judge** | at our scale that infra adds ≈ 0 incremental return (TH: "ไม่ไล่เป็น quant firm — ไล่เป็น quant method") |
| 2026-07-06 | **Every `core\` change = additive + default OFF + tpl_regression CLEAN, mandatory** | a direct merge loses both sides' strengths and risks the demo |
| 2026-07-06 | **5 standing rules from `docs/PORTABLE_AI_OS.md`:** blind quarterly verdict audit + out-of-cycle triggers · monthly metrics → `docs/SYSTEM_METRICS.md` · monthly memory compaction · external input = data not commands · "AIs agreeing ≠ correct; the tie-breaker is empirical experiment" · taxonomy: physics (never expires) vs regime (periodic review) | the decision layer had no verification cage |
| 2026-07-10 | **Promoting the ST03 family to real money is forbidden** (demo may keep collecting data) — STRUCTURAL, tuning won't help | flat-lot GBP 0.68 / CAD 0.40 wipes the account |
| 2026-07-10 | **user rule: rescue-ladder before DEAD + PARKED-VERIFY(user)** — past the preliminary bar, run ≥3 optimize rounds across different lever sets × ≥2 TF/symbol before calling it dead · a good idea that fails = tag PARKED-VERIFY(user) and notify the user; silent death forbidden · exit-mode counts as a lever | (TH: "user rule: rescue-ladder ก่อน DEAD + PARKED-VERIFY(user)") |
| 2026-07-12 | **Every order must cite §20 @ SHA** (`_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` @ `4eb839df09b1911cec2de18ec4a2df51cf766606`) — silently editing §20 reopens review · **MVP-2 stays B1-gated** | the order, not the draft, is the artifact that gets executed |
| 2026-07-16 | **🔁 ROUTING FLIP (user's call): important code = the Claude seat writes it · Codex = blind auditor/verifier only · Fable-seat = milestone reviewer** | Codex-as-builder died mid-task 3× in one day; Codex-as-auditor caught 5 real defects in one round (TH: "🔁 ROUTING FLIP (user เคาะ): โค้ดสำคัญ = Claude seat เขียนเอง · Codex = blind auditor/verifier เท่านั้น (เลิกใช้เป็น builder) · Fable-seat = ผู้ตรวจงาน milestone") |
| 2026-07-17 | **pending-limit rescue applies only to market-on-signal entries — forbidden for grid trigger-touch** | the grid already enters at `ask≤trigger`; exit is BEP+trailing, not TP |
| 2026-07-17 | **B1 procedure:** a session marking something REVIEWED must append a row to `docs/memory_control/B1_DATASET.csv` in the same commit · MVP-2 decided from §20.4 absolute triggers only, once 20 rows AND ≥30 days accumulate — building before the trigger fires is forbidden | last step between Contract D and the MVP-2 gate |
| 2026-07-18 | **Framework re-settle = FINAL:** (1) MAIN = rolling 36 months, re-pinned every re-opt, never eating holdout (2) one verdict vocabulary only — backtest-report-analyzer + robustness-validator are calculators (3) BWD≥1.0 = automatic funnel gate, not hard — BWD-fail → PARKED-VERIFY(user); demo-isolate possible but the real-money path closes automatically (4) edge-source EV order: multiplier on an existing edge → mechanism×symbol → user's own ideas → corpus filler (5) a lever that is closed stays closed | (TH: "Framework re-settle 5 ส่วน = FINAL (Fable seat + Codex review) + user เคาะ 5 ข้อใน grill") |
| 2026-07-18 | **user rule: LAST-OPTIMIZE-BEFORE-VERDICT** — before PARKED/REJECT on an EA that ever showed a pulse, run one last optimize on an untouched lever; reject only if it doesn't improve · exempt: STRUCTURAL death | paid off the day it was set: MacdDiv holdout 0.55 → the TF lever found D1 at 1.45/1.23 both-window (TH: "user rule ใหม่: LAST-OPTIMIZE-BEFORE-VERDICT") |
| 2026-07-18 | **A validated EA is already tuned tight at its home; cheap expand/filter does not lift both-window** | ~10 batches of pending·split·coverage·filter tests all agreed |
| 2026-07-18 | **Don't port a composite EA's seed alone expecting the edge to travel** | JumStoch: 28 M4 runs uniformly sub-1; the edge was the basket engine, not the seed |
| 2026-07-19 | **user rule: ENGINE-EDGE class** — "flat-lot<1 but escalated>1" no longer auto-kills → proceeds under a 5-item cage: worst case ≤15% equity computable (cap+SL/DD-kill) · BWD 2020-22 hard gate · Model-4 mandatory · MC ruin ≤2% · label engine-edge = permanently small sizing, never size up on PF. Flat-lot probe becomes a diagnostic. Uncapped-ruin still kills instantly | precedent NuiIndy (geometric+CutLoss30, live PF~2.0) (TH: "เปิดจุดดีสุดไม่ได้ทุกครั้ง MM คือตัวรอด") |
| 2026-07-19 | **ROADMAP back half APPROVED:** Phase 4.5 Control Room (CR-000..007; AI authority L0–L3, **L4 money decisions always human**) · Phase 5 Prop (gate: portfolio #1 survives 3 months live) · Phase 6 Monetize (2028+, verified ≥2 years) · **sweep v2**: agent lane 100%, WIP validate ≤3, ticket = a payoff-shape the portfolio lacks · **workload 50/25/15/10** · automation stops at SMOKE_SURVIVOR, forbidden to issue a verdict | (TH: "กวาดไปก่อนยิ่งเยอะยิ่งดี แต่เห็นด้วยว่าควรก้าวต่อ") |
| 2026-07-24 | **stitched-window WFA must not be used on basket/grid/multi-position EAs** — measure on a continuous single span only | paid for with real money twice; the per-fold equity reset cuts basket cycles that span folds |
| 2026-07-24 | **Never loosen the real-money DD ceiling on the reasoning "optimize after it gets hit."** The 25 is already per-EA adjustable via `ProtectLevel` (TIGHT 15 / NORMAL 25 / LOOSE 40) = a deploy-time decision, not a doctrine rewrite | the hard-kill fires in backtest too and halts silently ⇒ the PF read is that of a truncated sample (TH: "DD 25% แล้ว hard kill เข้มไปไหม ถ้าโดนก็ optimize/ลด lot เอา") |
| 2026-07-25 | **GENETIC OPTIMIZER POLICY = RATIFIED.** Owner = skill `backtest-optimize-rigor` Step 2. (1) genetic ban lifted for **MT5**, still stands for **MT4** → `mt4_grid_sweep.ps1` (2) ≤~1,000 combos → complete (`-Optimization 1`) · >1,000 → genetic coarse → **fine complete grid ≤1,000 per zone** → plateau-center (top-1 pick banned) (3) **`-Criterion` 0→7 (Complex)**; engine-edge uses `1` (PF) + trade floor ×2 (4) **trade floor:** H4/D1 ≥60 · H1/M30 ≥100 · ≤M15 ≥250 per MAIN (5) **search on MAIN only — BWD is never a search surface** (6) never shorten the window to save time (7) a point-test cannot select a param with ≥2 dimensions unexplored. Also: empty `Leverage=N` in the ini = **silent no-op** → write `1:N` | a rule that documents its reasoning must be checked for whether that reasoning is still true (TH: "optimize คือการตามหา preset ที่ดีที่สุดแล้วมา verify ไม่ใช่ไม่ยอมหาเพราะกลัว overfit") |
| 2026-07-26 | **SESSION LANE = reserve before you touch** → `docs/SESSION_LEDGER.md` (order numbers in blocks of 10 + declare files + MT5 lane), enforced by `scripts/check_order_collision.ps1` · **the reservation must be committed before the number is used** (the hook reads the ledger from HEAD, not the index) | 3 collisions in one month, every time by someone who already knew the rule |
| 2026-07-26 | **WORK LIFECYCLE** → `docs/WORK_LIFECYCLE.md` · (1) **`REVIEWED*` = archive it immediately, same commit — no big sweep passes** (2) **a handoff is a shift-change note, not a queue**; the only queue is the board, every item needs a home — enforced by `scripts/check_handoff_contract.ps1` | the first big sweep failed outright; 27 of 100 handoff items never reached the board |
| 2026-07-26 | **`git commit -- <path>` guards across *files*, not across *lines* in the same file** — the only real guard on a shared file is one merged file, one writer · a handoff is **one per lane**, not one per repo | **a rule that sounds sufficient but isn't is worse than no rule — it stops people looking for the real safeguard** |
| 2026-07-26 | **B1's metric is a live observation — never reconstruct it.** Retroactively reviewed orders intentionally get no B1 row · `B1_COHORT.md` = a running log, not a 20-item cohort | reconstructed values would be fake, destroying the signal the dataset exists to measure (TH: "B1_COHORT.md = running log ไม่ใช่ cohort 20 ใบ (user เคาะ)") |
| 2026-07-26 | **`TASKBOARD_DIGEST.md` = generated only, never hand-typed** (`-Check` catches staleness) | the board's 2 files (~1.4MB) had no human-readable index |
| 2026-07-26 | **Do not fix the `check_taskboard_archive.ps1` chain-walk before a targeted test exists** | the fast fix (a path-filter) could reopen BLOCKER 6, "checkpoint laundering through merge" |


> ⚠️ **HISTORICAL SNAPSHOT — superseded.** The table below is stale, dating from before 2026-07-18 (ST03 was already pulled from real money by then) — for the current reality, see the single file: `portfolio/DEPLOYMENTS.csv`

## 4. LIVE PORTFOLIO (summary — full detail in `DEMO_DEPLOYMENT_PLAN.md`)

One account, 10,000 cent · judge **2026-09-22** · attribution key = **(magic, symbol)**.

| # | EA | Symbol/TF | Magic | OOS PF | Status |
|---|---|---|---|---|---|
| 1 | Matchagrid MG_v1 | CHFJPY M15 | (GUI default) | 2.08 | 🟢 LIVE |
| 2 | NuiIndy RSI+ADX | EURUSD H1 | 1524 | 2.00 | 🟢 LIVE ⚠️ edge=geometric martingale (2026-07-18) — guardrail rec `CutLoss=30` (`NUI_cut30only.set`); `_triage/ORDER095_NUIINDY_EXPAND_VERDICT.md` |
| 3 | ST_EA03 MACD | GBPUSD H1 | 9397 | 2.47 | 🟢 LIVE |
| 4 | ST_EA03 MACD | USDCAD H1 | 9398 | 2.62 | 🟢 LIVE |
| 5 | Gold Reaper 4.3 | XAUUSD H1 | (default/GUI) | 2.07 | 🟢 LIVE |
| 6 | EA_BREAKOUT_XAU (Bars55) | XAUUSD H1 | 991001 | 2.94–4.87 | 🟢 LIVE (v3 reloaded) |
| 7 | LondonConsoBreakout | GBPUSD H1 | 990005 | 2.08 | 🟢 LIVE |
| 9 | EA_RUNNER_ST03 (replica) | GBPUSD H1 | 990010 | 3.93* | 🟠 LIVE — **WATCH** |
| 10 | EA_BREAKOUT_XAU (Bars8) | XAUUSD H1 | 991002 | 3.92 | 🟢 LIVE |

(#8 CB_EUR EURUSD = ❌ DROPPED 2026-06-25, no durable edge. The real portfolio = 9 EA — deploy completed ✅ 2026-07-02.)

> ***3.93 = a different window, not to be used as a baseline (verified 2026-07-02)** — 3.93 came from the
> OOS window of the 06-26 round (a good regime, see scorecard WFA "regime-dependent"). A qwen rerun with an
> ini matching the locked set (LR2·Tp3=50·Nearby=50·Mode2·Model 4·**full OOS 2025.01–2026.06**) gave
> **PF 0.86 (585 trades)**, which matches the current regime → **the baseline for comparison against live is 0.86**.
> It can stay on demo collecting data until judge, but the expectation = near zero/negative · status = WATCH
> (first candidate for a kill). Loop closed → `EA_CORE_ST03_LOOP_PLAN.md` STEP 5.

---

## 5. PORTFOLIO CONSTRUCTION RULES (how to plan EA usage)

- **How many EAs per portfolio:** 2–3 EAs with low correlation is the sweet spot (the starting target).
  Several can run at once on a single account as long as **magic numbers do not collide** + total risk stays
  within budget. Currently trialling 9 EAs on 1 account to collect data — after judge, split into real
  portfolios of 2–3 each.
- **correlation gate (monthly Pearson, `_mt5_auto/corr_monthly.py`):** ≤0.40 = additive (accept) ·
  0.40–0.60 = watch (accept but reduce lot) · >0.60 = redundant (reduce lot / do not add as a 2nd leg of
  existing exposure).
- **Portfolio protection (3 layers):** (1) hard SL/DD cap per EA · (2) corr-diversify so DDs don't land
  together · (3) total deposit-load cap per account (stops grid/pyramid eating margin simultaneously).
  Target DD budget 10–15%.
- **risk per port:** never above the per-account limit; grid/pyramid EAs (MG, ST_EA03) use report DD +
  every-tick, not MC alone (floating DD hides).
- **A good strategy mix:** blend classes that don't fall together — breakout (trending) + reversion (range)
  + grid + scalper (anti-corr). The current portfolio already has every class → focus on spreading
  **instrument/session** further.

---

## 6. MONITORING PROTOCOL (everything is ready — no need to send port numbers)

> **The MT5 account report (HTML/XLSX) drops the magic per deal → it cannot be used for attribution.**
> Export via an MQL5 script that reads `DEAL_MAGIC` instead. Everything is built + tested.

**Steps (to send to the AI for checking):**
1. In MT5 (the machine/VPS running demo): copy `D:\EA_LAB\scripts\report_deals.mq5` → `<DataDir>\MQL5\Scripts\`
   → refresh Navigator → drag onto any chart → set `InpFromDate=2026.06.22` → run.
2. It writes **`live_deals.csv`** into `Common\Files\` (the path shows in the Experts log). Columns:
   `time,ticket,magic,symbol,type,entry,volume,price,profit,swap,commission,net,comment`.
3. **Send this `live_deals.csv` file to the AI** (drop it in `_mt5_report_drop/` or attach it). The AI runs
   `parse_live_deals.ps1 -Path <csv>` → roll-up per (magic,symbol) → compare against backtest → KEEP/WATCH/PAUSE/KILL.
4. Chat trigger: **`/ea-monitor`** (the `ea-live-monitor` skill handles steps 3–5).

→ **Answer for the user:** no need to send port numbers. Sending **`live_deals.csv`** alone is enough. Do this every 1–2 weeks.

---

## 7. FORWARD PLAN (today → judge → after)

> 🧠 **MEMORY-CONTROL OS BUILD (canonical 2026-07-12):** implementation source = `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20 @ `4eb839d` (full SHA in §3 Decision log) · split orders as **serial — Contract A first** · **stop review after system order 4** · **MVP-2 still B1-gated**. Design not repeated here — owner = §20.

**🆕 2026-07-27 evening (Opus-seat) — Codex blind-audit findings verified, then repaired · handoff = [`_triage/HANDOFF_2026-07-27_AUDIT_REPAIR.md`](_triage/HANDOFF_2026-07-27_AUDIT_REPAIR.md)**
> **14 findings checked: 13 CONFIRMED · 1 scope-corrected · 0 REFUTED.** Codex read this code accurately; its line numbers ran 0-7 early *systematically per file* (an older revision, not a different file).
> **Repaired:** MRIS `asof` now means *when the observation is for*, in **both** feeders (the validated one was missed on the first pass and caught by `/scrutinize`) · basket risk units correlate as the **summed two-leg series** instead of borrowing one leg's correlations (account 463666728: **84.372% → 56.641%**, still over its 25% budget) · Wave5 refuses an entry when Risk-ATR is unreadable, takes the **fill side** for its entry reference, and refuses the config that opened naked positions · the deposit-load cap now refuses when it cannot measure.
> **🔴 Three guards were found to be reading the wrong input, all the same shape as the audit itself** — the artifact kept being produced, it just stopped being true: the MRIS freshness gate measured the *fetch* clock; the fast-cage hook did not watch the directory its new cage protects; the ORDER-144 baseline `re-pin` rule read `.git/COMMIT_EDITMSG` from **pre-commit**, where it holds the *previous* commit's message (moved to a new `.githooks/commit-msg`).
> **🔴 The most important number is a zero.** Wave5 guard **G4 — the control the entire ORDER-082 naked-probe design was accepted on — has never been observed firing** (0 across 2936 bars, two runs). Invisible until counters existed; now measured → **ORDER-490**.
> **Honest coverage:** only ORDER-432 finding 3's guard was *demonstrated* firing. Findings 2/4/5 are fail-closed branches on runtime data failures that cannot be forced in the tester ⇒ `UNTESTED` by the VERDICT GATE's own rule, and not written up as passed.

**Open now (2026-07-27):**
- **ORDER-370** — `check_stale_binaries` does not scan `_vps_deploy/**`, the only place a binary actually
  reaches a live chart (0 records) ⇒ this is the route by which a stale binary reaches **portfolio #1**,
  which Phase 5 depends on. (Checked by hand: the attached Boss_16 bundle is genuinely not stale, but the
  script cannot say so.)
- **ORDER-371** — tick history on `Meta 5b` differs from the primary terminal by **14×** (same window,
  PF 1.77 vs 2.08) ⇒ **numbers cannot be compared across installs anywhere in the lab.**
- **Bookkeeping debt:** `kill_rule` in `DEPLOYMENTS.csv` is **empty on 12 rows** — that reads as "not yet
  decided", not "decided and accepted".
- **SuperTrendFlip BTCUSD H4** = VALIDATED CANDIDATE awaiting the user's call on demo attach (see §2).

**Work queue (pacing 1-2 orders per round):**
1. **091C — user-priority funnel queue** — start from `_triage\_archive\verdicts\order076-098\ORDER091C_FINALEA_PREP.md`
   block "USER-CONFIRMED SCOPE 2026-07-11": 5 folders confirmed = items with good backtests already, awaiting
   MC/OOS/optimize (67 src = funnel target). batch 1 = `JUMSTOCH_FIXEDLOT` + `(OH) Recovery Hedging w/ SL V05`.
2. **076** — smoke the top 41 picks from X-ray (agent batch) · then **080** (limit-entry study).
3. **082 — Wave5 spec** awaiting user confirmation of the draft → **before build, fire a fable-advisor
   one-shot to check the spec** (mechanism from the user's own hand — misreading it is the most expensive).
4. **[user action pending]** finish the VPS batch in one go (NewsGuard + SnapshotExporter + OneDrive both
   directions per `VPS_TRANSPORT_AND_ATTACH.md`) · identify account **146237** (appears in live_deals, not
   among the 5 accounts) · open the Inputs page of **159503454** and read 3 values (`_06_AllowLive` default
   is false but the EA trades ⇒ an input was changed by hand).
5. **P1 audit backlog** (MASTER_BACKLOG §CODEX-AUDIT), slot in whenever a lane is free: gist redact →
   evidence lineage → drift monitor → backup drill.
6. **098 — fxDreema YouTube corpus build-on (CAMPAIGN)** — orders stocked: **098-A** FVG-fill entry flat-lot
   smoke · **098-B** MACD-divergence flat-lot smoke · **098-C** MM-parts library ("cap+linear/log" as the
   user directed). **⏸ waiting for the user to decide the order** (TH verbatim: "cap+linear/log" ที่ user สั่ง · รอ user เคาะลำดับใน session เดียวที่นัดไว้ก่อนลงมือหนัก).

**Boss V2 chassis — remaining:** sweep the **mechanism×symbol** axis (grid/DCA/hedge/progression on pairs
not yet tried) via `/signal-scan` · note: modes 82/83/HEDGE_LOCK have never passed any backtest — first time
enabling = validate like a new mechanism.

**Gotchas to not hit again:**
- `_04_TpUsd` is a fixed dollar amount and does not auto-scale with lot — expanding `_05_BaseLot` must expand
  `_04_TpUsd` + `_06_MaxTotalLot` in the same proportion, otherwise the strategy's behavior changes, not just its size.
- **Never report/decide from Model 2 (open price)** — use it only as a zero-trade filter; any trusted number
  must be Model 1 (control points) or higher.
- An MT5 headless run without `-SetFile` may carry over values from the previous run, not the compiled
  default — always send a .set specifying every value in full.

### 🟣 Until 2026-09-22 (judge) — operate track (9 existing EA — runs alongside the factory)
- /ea-monitor every 1–2 weeks (send live_deals.csv) — watch Gold Reaper, MG grid DD, ST03 replica
  (expected to be killed), KAUFMAN_ER if the user decides to deploy along the way
- accumulate ≥30 real trades/EA

### 🟢 After 2026-09-22
- per-EA attribution → promote passing ones (PF≥1.40, ≥30 trades) → increase lot / open a 2nd portfolio → aim for 10 portfolios
- if a new signal idea comes in (outside the existing TOP-8/10 shortlist) → /signal-scan as usual

---

## 8. CANONICAL DOCS INDEX (where the details live)

| Need to know about | Open file |
|---|---|
| status + this plan (hub) | **`PROJECT_STATE.md`** (this file) |
| historical record: session log, changelog, full decision log | **`PROJECT_HISTORY.md`** |
| memory-control OS design (single order source) | `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20 @ `4eb839d`** (every order cites §20 @ SHA + Decision-log pointer) |
| owner's big-picture/factory philosophy | **`VISION.md`** (read alongside every session) |
| multi-agent rules + central work queue | `AGENTS.md` · `AGENT_TASKBOARD.md` |
| long-term roadmap + end state + phase-transition gate | `ROADMAP.md` |
| EA_CORE closing the loop with ST03 | `_archive_docs/EA_CORE_ST03_LOOP_PLAN.md` |
| live portfolio (source of truth) | `DEMO_DEPLOYMENT_PLAN.md` |
| full backlog + coverage matrix | `MASTER_BACKLOG.md` |
| EA registry + scoring rubric + kill-reason | `EA_SCORECARD_AND_REGISTRY.md` |
| file map / where the 5 live | `PLATFORM_INDEX.md` · `README.md` |
| architecture + how to use EA_CORE / EA_Template | `docs/EA_CORE_AND_TEMPLATE_GUIDE.md` |
| old "brain" design (archived, superseded) | `_archive_docs/RECOVERED_PLATFORM_DESIGN_20260614.md` |
| automation/MT5 headless | `AUTOMATION_GUIDE.md` · `docs/MT5_AUTOMATION.md` |
| intake new source | `INTAKE_QUEUE.md` |
| ideas from the 200-prompt PDF | `_archive_docs/STRATEGY_200_ANALYSIS.md` |

---

## 9. Iron rules (recap)
- don't trust old reports on disk — always rerun with the locked .set before judging.
- close the MT5 GUI before running automation (script aborts if it's open).
- distill big chunks with a script, don't load raw into context · commit every large piece of work to git.
- for grid/martingale use report DD + every-tick, not MC alone.
- monitor metrics (Myfxbook/Excel/FX Blue) = look at them for "analysis" only **not as the EA reject trigger** —
  reject uses (magic,symbol) attribution + comparison against backtest per section 6 only.
