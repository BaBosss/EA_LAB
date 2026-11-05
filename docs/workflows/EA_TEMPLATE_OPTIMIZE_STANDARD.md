# EA Template + Optimize Standard — design (overview level)

- **Date:** 2026-11-03, rule table v1 2026-11-04 · **Status:** owner-decided design. **§9 rule table v1 is the only current rule set**; §§2–7c are decision history.
- **Author:** Claude Code (Opus 5.5), with the owner. Drafted outside the repo in `D:\EA_LAB_RESET\`; committed here 2026-11-04 (lane `claude-optstd-doc-20261104`). Companion files: `EA_OPTIMIZE_RECIPE_RECEIPT_SPEC.md`, `R15_SCORE_TRIAL_1_DEV.md`.
- **Inputs:** `D:\EA_LAB_RESET\_raw\design_decisions.md` (owner answers Q1–Q5), `D:\EA_LAB_RESET\_raw\templates_found.md`, `D:\EA_LAB_RESET\_raw\grandmodular_vs_bossv2.md`.

## 1. Problem

58 deployment rows; only 18 run on the Boss V2 template. The other 40 are standalone (Claude wave-1/2, AGY `(Boss)_*_rev01`)
or third-party locked EAs. Two live template lines exist (Boss V2 and AGY GrandModular). The optimize ladder in skill
`backtest-optimize-rigor` is written once but lets each worker pick levers, ranking column and floors, so no two EAs were
optimized the same way and results cannot be compared.

## 2. Owner decisions (2026-11-03)

| Q | Decision |
|---|---|
| Q1 scope | Port every EA with source into the template, defaults = original; prove parity; then branch into our own hypotheses. Locked third-party EAs keep their binary but use the same optimize standard and the same guard. |
| Q2 rigidity | Fixed recipe per EA class on one common skeleton, plus exactly one extra diagnosis-driven lever round (written reason; approved by any reviewer who is not the author — 7a row 8). |
| Q3 order | Any EA, one at a time (7a row 2); easiest single-position EAs first is a recommendation only. Running originals are not touched. |
| Q4 template | Boss V2 (`ea_template/core`) is the only template. AGY GrandModular capabilities are extracted one module at a time, each reviewed. |
| Q5 score | One score formula built into the template for every EA; a separate formula for the escalation class that counts floating drawdown. |
| Enforcement | Approach 3: recipe as data first → a checker that refuses non-conforming results → automation layered on existing runners later. |

## 3. Components

1. **One template — Boss V2.** Each EA is a thin wrapper that selects one entry module; everything else is the shared core.
   Each wrapper exposes only the inputs it uses; the rest are locked (existing `LAB_CONST_*` mechanism).
2. **Naming.** `xx-00` = ported original with original defaults. `xx-01…` = our variants: one changed mechanism each, with a
   one-line hypothesis. A numeric-only change is a parameter set, not a variant (consistent with the existing identity model).
3. **Class recipe tables.** Four classes: trend · reversion · breakout · escalation (grid / lot progression / recovery).
   Class is derived from the modules the EA uses, not chosen by hand (any grid or lot progression ⇒ escalation).
   One data file per class: levers to sweep, ranges (ATR-relative where possible), trade floor, score formula, step order.
4. **Score built into the template.** An `OnTester()` score with the project's bars (equity DD ≤ 12 %, drawdown penalty,
   profit vs drawdown; trade count sets evidence confidence, not pass/fail — see 7a). The escalation formula also charges floating drawdown, so a configuration cannot
   score high by deferring losses (the S13 PF 12,211 case).
5. **Checker.** Refuses any optimize/backtest result whose run did not follow its class recipe: wrong levers, wrong window,
   missing step, or an extra round without a recorded reason and reviewer.
6. **One report format.** Every EA produces the same report layout, so EAs can be compared side by side.

**Locked third-party EAs:** components 3, 5 and 6 apply unchanged. Component 4 cannot be embedded, so the same score is
computed externally from the MT5 report.

## 4. Porting rule (Q1, Q3)

A port is done only when the `xx-00` wrapper reproduces the original on the same symbol, timeframe, window and model:
trade count within 2 % and net profit within 5 % (7a row 1). Port order is free (7a row 2).

## 5. GrandModular intake (Q4)

Candidate modules, each a separate reviewed change with its own cage: entries missing from Boss V2 (≈14–16, e.g. SuperTrend,
Asian-range break, MACD zero pullback, Keltner squeeze, VWAP fade, FVG, Turtle 20/55) · recovery R03 overlap close, R04 profit
shaving, R05 semivariance grid step, R06 time-decay TP + partial hedge · lot L02 delayed step, L03 tiered step · breakeven at +R ·
the in-EA score idea (with our numbers, not GrandModular's trades ≥25 / DD 15%).

## 6. Rollout (Approach 3)

1. Recipe tables + score formulas written as data.
2. Checker that refuses non-conforming results.
3. Port 2–3 easy EAs and run them through the recipe as the first end-to-end test.
4. Automate step by step on existing runners (`run_batch`, `optimize_guard.ps1`, `mt5_run.ps1`).

## 7. Out of scope here / deferred to the detail session

- Exact lever list, ranges and step order per class.
- Exact score formulas and their numbers.
- Parity tolerance for ports.
- Which 2–3 EAs go first.
- Checker interface and report layout.
- Where these files live in the repo, who executes each step, and reconciliation with canonical `origin/master` (this design was
  made on the local checkout; Boss V2 numbering differs between local and origin).

## 7a. Detail session round 1 — owner answers (2026-11-03, in chat)

| # | Question | Owner answer | Note / open conflict |
|---|---|---|---|
| 1 | Port parity tolerance | **Small deviation allowed** (option B: trade count within 2 %, net profit within 5 %, same symbol/TF/window/model) | Every mismatched trade is still listed in the parity report, so a systematic bug is visible even inside the tolerance. |
| 2 | First EAs to port | **Any EA, one at a time** | Order is free; §4 easy-first ordering becomes a recommendation, not a rule. |
| 3 | MT4 (.mq4 / fxDreema) EAs | **Port to MT5 too** | Parity for an MT4 original cannot be same-engine; tolerance rule for cross-platform ports is an open item. |
| 4 | Who proposes `xx-01` variants | **Both owner and AI.** Naming: `Boss_11-00_<entry concept>` (e.g. `Boss_11-00_SMC`); next variant `Boss_11-01_SMC_add_grid_plus_lot` | File names use underscores, no spaces. "grid plus lot" is two escalation levers in one variant — allowed only if the hypothesis is one sentence about their combination. |
| 5 | Levers and ranges per class | **Deferred** — separate optimize session | — |
| 6 | Max levers per optimize | **No fixed limit; set by the strategy and its hypothesis** | Checker still requires the genetic/full-grid rule (>1,000 combos ⇒ genetic) and a plateau, not a spike. |
| 7 | Symbol universe | **XAUUSD, BTCUSD, ETHUSD, EURUSD, GBPUSD, EURGBP, USDJPY, EURJPY, AUDCAD, NZDCAD** | VERDICT GATE "right home" names AUDNZD for reversion; not in this list. Correlated groups for the portfolio cap: BTC/ETH · EURUSD/GBPUSD/EURGBP · USDJPY/EURJPY · AUDCAD/NZDCAD. |
| 8 | Reviewer of the extra lever round | **Anyone** | Bounded by AGENTS.md: the reviewer must not be the author. |
| 9 | Drawdown limits | **Superseded by the follow-up decisions below: ≤ 12 % equity DD per EA at selection; ≤ 30 % per portfolio including correlation** | `scripts/portfolio_risk_admission.py` still uses 25 %; changing it needs a lane. |
| 10 | How escalation counts floating loss | **Deferred** | — |
| 11 | Checker on a non-conforming result | **Refuse and record** (a rejection log, not a silent drop) | — |
| 12 | One-page report fields | **Deferred**; first collect the report formats GPT, Codex and AGY produced (`D:\EA_LAB_RESET\_raw\vendor_report_formats.md`) | — |
| 13 | Who executes each part | **Deferred** | — |
| 14 | Repo location + origin reconciliation | **Claude to plan** (§7b) | — |

**Follow-up decisions (2026-11-03, in chat):**
- Portfolio DD cap = **30 %** including correlation. Changing `DEMO_BUDGET_PCT = 25.0` in `scripts/portfolio_risk_admission.py`
  (and `docs/JUDGE_DAY_RUNBOOK.md` "Sizing" step 3) is a code change for a lane; it is not done here.
- Per-EA DD = **≤ 12 % at selection** (backtest), matching the unchanged demo kill eqDD > 12 %. This replaces the 15 % in row 9.
- The `Boss_11-01_SMC_add_grid_plus_lot` name was only an example of the naming pattern. It sets no rule about how many
  mechanisms one variant may change.

**One-page report — owner changes (2026-11-04):**
- Box 2 adds a 4th window **RECENT = 2025-01-01 → today** (gold behaves very differently year to year). Open: RECENT
  contains the 2026H1 holdout. **Decided 2026-11-04: RECENT is shown only after parameters are locked.** Before the lock,
  the box shows `LOCKED`. The first RECENT run is the holdout run, so after it the 2026H1 holdout is spent and later
  evidence is demo-forward (per the VERDICT GATE window rule). RECENT is never used to choose or re-tune parameters.
- Box 3 drops the trade count as a pass/fail rule. Trade count, DD and the other checks instead feed a **grade per EA × symbol**
  (e.g. A on a currency pair, B on gold when DD runs over). Score vs letter grade is to be decided later. Open: this relaxes the
  VERDICT GATE participation floor (≥100 trades per window, owner-ratified 2026-08-05). **Decided 2026-11-04:** trade count
  sets **evidence confidence** (how far the numbers can be trusted), kept separate from the **quality grade** (how good the EA is
  on that symbol). This reuses the two axes in `EA_REPORT_SCHEMA.md` §9 (`QUALITY_GRADE`, `EVIDENCE_CONFIDENCE`). A low trade
  count no longer fails an EA on its own, but a grade of A needs confidence of at least the level to be set in the detail
  session. The VERDICT GATE text on origin still carries the old floor and needs an owner-ratified amendment in a lane.
- Add **equity + balance curves** in the MT5 style.
- Add a guard-fit box (which guard suits this EA, and by how much DD falls). Inputs: `D:\EA_LAB_RESET\_raw\guardian_and_monitor_findings.md`.

**New scope from the owner (2026-11-04):** review Unified Guardian and extend it to cover news, macro and regime; simulate DD
with and without each guard; consolidate every monitor into one web page. Findings and proposals:
`D:\EA_LAB_RESET\_raw\guardian_and_monitor_findings.md`.

**Escalation class — floating loss (Q10, decided 2026-11-04, option C):**
1. All drawdown limits use **equity DD** (open positions included), never balance DD. The 12 % per-EA cap is measured on it.
2. **Worst-basket check:** for each basket (first entry → fully flat), record its deepest floating loss and its holding time.
   The worst value of each is reported and penalised in the score.
3. **End-of-test mark-to-market:** any position still open on the last bar is treated as closed at that bar's price, so a
   loss deferred past the window end cannot be hidden (the S13 PF 12,211 case).
Penalty weights are set with the score formula in the optimize session.

**Who executes (Q13, draft 2026-11-04 — owner context: ChatGPT subscription ends in ~2 weeks; owner subscribes to TokenMe
with DeepSeek V4 Flash 0731 (1M context), Qwen 3.8 27B NVFP4 (262k), Gemma 4 31B (262k); APIs not installed yet):**

| Work | Executes | Reviews |
|---|---|---|
| Design, formulas, verdicts | Claude Opus 5.5 | GPT-6.1-Sol while available → then DeepSeek V4 Flash (different family) |
| Port an EA following the pattern | Claude Sonnet 5.5 | Opus 5.5 + parity checker |
| Hard port (grid / complex escalation) | Opus 5.5 | DeepSeek V4 Flash + parity checker |
| Template core edit | Opus 5.5 | DeepSeek V4 Flash + `tpl_regression.ps1` |
| Batch backtest / optimize runs, report parsing | Qwen 3.8 27B (DeepSeek V4 Flash if mid-run adjustment is needed) | Checker + Opus 5.5 reads |
| Guard simulation scripts | Qwen 3.8 27B | Opus 5.5 reads |
| Monitor web page | Sonnet 5.5 | Opus 5.5 |
| Final approval | Owner | — |

**Update 2026-11-04 after trials (owner):** GPT work moves to Claude. Qwen/DeepSeek take only the work that suits them
(`D:\EA_LAB_RESET\trial\TRIAL_RESULT_ROUND2_20261104.md`): copying exact values from reports and logs, running our parser scripts, and acting as
second reviewer. They never count long tables themselves (gateway 524 at ~200k tokens), and every output is checked for
existence and row count (silent give-up was seen once). The VERDICT GATE still requires a different-family reviewer for
demo → LIVE, and Claude reviewing Claude does not satisfy that. With GPT gone, that reviewer is **DeepSeek V4 Flash**, plus the
owner.

**Model allocation after 3 trial rounds (owner-approved 2026-11-04; evidence `D:\EA_LAB_RESET\trial\TRIAL_RESULT_*.md`):**

| Work | Model | Required check |
|---|---|---|
| Design, formulas, verdicts, risk code, GPT's former work | Claude Opus 5.5 | — |
| Copy exact values from reports, condense logs, run our parser scripts | Qwen 3.8 27B (TokenMe) | output file exists + row count + keys match the input list |
| Different-family reviewer #1 | DeepSeek V4 Flash (TokenMe) | reviews blind (does not see the other reviewer's answer) |
| Different-family reviewer #2 | Gemini 3.8 Flash via `agy -p` (read-only) | same |
| Reading long tables in reports (when no parser exists) | Gemini 3.8 Flash via AGY | row identity checked against the input file list (it rewrote a file name once) |
| Monitor web page, report layout, Unified Guardian fixes | AGY | Claude reviews; numbers come only from generator JSON |
| Never | any non-Claude model counting long tables via TokenMe (gateway 524 at ~200k tokens); any model as sole author of money-touching code | — |

Hermes is not adopted: its Gemini OAuth path shares the backend that rejected the Gemini CLI (`IneligibleTierError`), and AGY
already exposes the same Gemini quota.

**2-week trial plan (before relying on Qwen/DeepSeek):** after the owner installs the APIs, give each model the same 3
tasks with a known answer: (1) parse 3 MT5 reports → numbers vs ground truth; (2) review a small MQL5 diff with one seeded
bug; (3) condense a long log and list its errors. A model takes a lane only if it scores exactly on (1) and finds the bug in
(2). Use the remaining GPT-6.1-Sol window for the highest-stakes reviews first (this design doc, then the checker spec).

**Optimize details (Q5, owner answers 2026-11-04):**

| # | Topic | Decision | Note |
|---|---|---|---|
| 5.1 | Symbols | All 10 symbols, each with its own **symbol preset** (point/pip scale differs: BTCUSD vs XAUUSD vs EURUSD). Smoke all 10 with defaults; full optimize only where smoke PF ≥ 1.0 (option B). | Symbol presets belong with `factory/instrument_profiles.jsonl`. |
| 5.2 | Timeframes | Default **M15, M30, H1**. H4 and others optional, per strategy. | — |
| 5.3 | Tester model | **Model 1** for search; **Model 4 MAIN + BWD must pass before CANDIDATE** (owner, 2026-11-04, after review 7c #1; was "before demo"). A Model-1-selected set is a *frozen finalist* until then. | Matches canonical C11 (`_triage/factory_os/candidate.py:520-543`). Paid-for risk: 2026-07-17 AUDNZD PF 3–4 → M4 0.61. |
| 5.4 | Levers | Per parameter, coarse then fine (e.g. ATR distance 1.0–5.0 step 0.5, then finer around the plateau). Fixed-pip values (e.g. TP) are set per symbol preset. | Lever lists are written per EA/class during the ports, not in advance. |
| 5.5 | Units | `xx-00` keeps the original's units (pips/points) when known; later variants move distances to ATR. | — |
| 5.6 | Search | **Full grid**, no genetic shortcut (time is available). | Overrides the skill's ">1,000 combos ⇒ genetic" rule; keep coarse → fine staging so a grid stays runnable. |
| 5.7 | Plateau rule | Decided per EA, together with the owner. | — |
| 5.8 | Score formula | Set after the first trial runs. | — |

## 7b. Where it lives + reconciliation with origin (Q14 plan, 2026-11-03)

**Finding that changes the plan:** canonical `origin/master` (`ed9c85a8`, local ref, not fetched) already has most of the
building blocks. Approach 3 must extend these, not create parallel copies:

| Need (§3) | Already on origin | Plan |
|---|---|---|
| Template | `ea_template/core` + `Boss_11..18, 20, 21, 22, 24, 25` (different EAs from local Boss_19..23) | Unchanged home. New ports = `ea_template/Boss_NN-00_<Concept>.mq5`; `NN` and magic taken from `factory/magic_allocations.jsonl` on origin, never from local numbering. |
| Recipe tables | `ea_template/OPTIMIZATION_PROCEDURE_V2.md` (staged procedure, prose) · `factory/parameter_bindings.jsonl` (role per input; SAFETY = not optimizable) · `factory/instrument_profiles.jsonl` | New `factory/recipes/<class>.json` (trend · reversion · breakout · escalation) referencing the existing bindings and profiles. |
| Hypothesis per variant | `factory/hypotheses.jsonl` (11 rows; its header comment saying "no rows" is stale) | Each `xx-01…` registers one row there; existing rows and their prereg bindings are kept. |
| Score in EA | none (no `OnTester` in core) | New `ea_template/core/Score.mqh`; core edit ⇒ `tpl_regression.ps1` cage + review. |
| Checker (refuse + record) | `scripts/optimize_guard.ps1` already refuses SAFETY/inert sweeps and records into `factory/optimize_decisions.jsonl`; Codex plateau/center-freeze helper (`docs/audits/EA_LAB_OPTIMIZATION_PIPELINE_AUDIT_20260912.md`); Model-4 gate in `_triage/factory_os/candidate.py` | Extend `optimize_guard.ps1` with recipe conformance (wrong lever / window / floor / missing step / extra round without reason+reviewer). Rejections keep going to `optimize_decisions.jsonl` (answer 11 = record). |
| Port parity | `factory/parity/` + `scripts/parity_run.ps1` + `parity.py` (7 behaviour points; wrapper vs Boss parent; proven only on Model 1, one window) | Add an original-binary vs `xx-00` mode: trade count ±2 % / net ±5 % on MAIN, Model 4, plus the per-trade mismatch list (§9 R3). |
| Report | `docs/research/EA_REPORT_SCHEMA.md` + `EA_REPORT_LADDER.md` (GPT) | Keep as the full report; add a one-page front sheet + leaderboard row (`D:\EA_LAB_RESET\_raw\vendor_report_formats.md`). |
| Portfolio DD | `scripts/portfolio_risk_admission.py`: DEMO budget **25 %** fixed | Owner decided 30 % (7a follow-up); the code change is a lane task. |
| This design | — | `docs/workflows/EA_TEMPLATE_OPTIMIZE_STANDARD.md` once approved. |

**Reconciliation steps:**

1. All work happens in a lane worktree cut from `origin/master` (`D:\EA_LAB_CONTROL\w\<lane>`, Lane Registry), never in `D:\EA_LAB`.
2. Fetch origin and pin one exact SHA at lane start (this session could not fetch).
3. Local-only EAs (`Boss_19..23` untracked, `tools/unified_guardian`) enter origin only through the A10 tick sheet
   (`D:\EA_LAB_PRESERVE\20261102_local_lineage\A10_OWNER_TICK_SHEET.md`, renumber 20/21/22 → 26/27/28) — this design does not move them.
4. Build order = §6 rollout: recipes as data → checker extension → first port → score include → report front sheet.

## 7c. Independent review — GPT-6.1-Sol, 2026-11-04: REVISE (`D:\EA_LAB_RESET\_raw\REVIEW_GPT_SOL_DESIGN.md`)

Reviewed against `origin/master` `4c908957` (local ref). Claims spot-checked by the author: hypotheses 11 rows (true), C11
Model-4 MAIN+BWD gate in `_triage/factory_os/candidate.py:520-543` (true), instrument profile store empty (true).

| # | Finding | Disposition |
|---|---|---|
| 1 P1 | Model-4 only "before demo" lets Model-1 fiction reach CANDIDATE; canonical C11 needs frozen M4 MAIN+BWD for every new CANDIDATE | **Accepted by owner 2026-11-04:** M4 MAIN+BWD before CANDIDATE; Model-1-selected sets are "frozen finalists" until then. |
| 2 P1 | `parity.py` compares wrapper vs Boss parent, not port vs standalone original; aggregate ±2/±5 % can hide offsetting bugs | Accept: parity compares the **original binary** vs the `xx-00` port; ±2/±5 % stays as the owner's aggregate gate, plus a per-trade mismatch list where any systematic mismatch (entry time, side, lot, exit reason) blocks. MT4 → MT5 ports need their own contract first. |
| 3 P1 | Deepest floating loss per basket cannot be read from a deal list | Accept: escalation EAs log timestamped equity + basket state from inside the EA (template core); locked EAs need price replay of their deals; no observations ⇒ no score. End-of-test close uses bid/ask + costs. |
| 4 P2 | RECENT mixes 2025 (training) with 2026H1 (holdout) | Accept: RECENT is descriptive only; the 2026H1 holdout is reported as its own row with its own gate. |
| 5 P2 | Superseded rules still in the text | Partly done (2026-11-04 edits); a single versioned rule table follows before build. |
| 6 P2 | Score / plateau rules decided after seeing results | Accept: trial runs are labelled development-only; score, plateau rule, ranges and tie-breaks are frozen per EA before qualifying runs. |
| 7 P2 | `optimize_guard.ps1` is a preflight (and `-WarnOnly` exits 0), not result acceptance | Accept: add an acceptance receipt bound to report / build / set / window / recipe version; `-WarnOnly` and unresolved inputs cannot produce acceptance. |
| 8 P2 | Pip/point scaling: `_31_SL_Pip` is used as points in places; copying an original pip value can be ×10 off | Accept: each symbol preset pins broker specs; the port checks effective price distance, lot and money risk, not input numbers. |
| 9 P2 | Guard method A (trade-list counterfactual) used as evidence; many cells × unadjusted p-values | Accept: method A = screening only; qualifying guard evidence = method B with a pre-registered timeline and selection rule, and fire counts including stale/missing-feed cases. |
| 10 P3 | "0 rows" claim false | Fixed in 7b. |

## 9. Rule table — v1 (2026-11-04) · the only current rules

Sections 2–7c are the decision history. **Where they differ from this table, this table wins.** Any change = a new version
row at the bottom, with date and who decided. `OPEN` = not yet set; nothing may be built on an `OPEN` rule.

| ID | Area | Rule (v1) | Source |
|---|---|---|---|
| R1 | Template | Boss V2 `ea_template/core` is the only template. GrandModular parts enter one module at a time, each reviewed. | Q4 |
| R2 | Naming | `Boss_NN-00_<Concept>` = port with original defaults; `Boss_NN-01…` = variant with one hypothesis row in `factory/hypotheses.jsonl`. `NN` and magic from origin `factory/magic_allocations.jsonl`. A numeric-only change is a parameter set, not a variant. | 7a #4, 7b |
| R3 | Port parity | Original binary vs `xx-00`, same symbol / TF / window / model, Model 4, MAIN. Pass = trade count ±2 % **and** net ±5 % **and** no systematic per-trade mismatch (entry time, side, lot, exit reason). Every mismatched trade is listed. | 7a #1, 7c #2 |
| R4 | MT4 ports | Ported to MT5. **Parity contract accepted by owner 2026-11-04** (`D:\EA_LAB_RESET\_raw\open_rules_proposal.md` §R4): same broker data, MT4 every tick vs MT5 model 4, fixed spread; gates = signal parity ≥95% (same side, ±1 bar) · exit-reason mix ±5pp · exact lot sequence for escalation · trade count ±5% · no systematic mismatch; net profit reported, not gated. | 7a #3, 7c #2 |
| R5 | Port order | Any EA, one at a time. Running originals are not touched. | 7a #2 |
| R6 | Class | trend · reversion · breakout · escalation; derived from the modules used (any grid or lot progression ⇒ escalation). | §3 |
| R7 | Windows | MAIN 2023–25 · BWD 2020–22 · HOLDOUT 2026H1 (own row, own gate) · RECENT 2025-01 → today, descriptive only, shown only after lock, never used to tune. | VERDICT GATE, 7a, 7c #4 |
| R8 | Symbols | XAUUSD, BTCUSD, ETHUSD, EURUSD, GBPUSD, EURGBP, USDJPY, EURJPY, AUDCAD, NZDCAD, each with a symbol preset that pins broker specs (digits, point, tick value, contract size). | 7a #7, 5.1, 7c #8 |
| R9 | Units | `xx-00` keeps the original's units; later variants move distances to ATR. A port is checked on effective price distance, lot and money risk, not on input numbers. | 5.5, 7c #8 |
| R10 | Timeframes | M15, M30, H1 default; H4 and others optional per strategy. | 5.2 |
| R11 | Smoke | All 10 symbols on defaults; full optimize only where smoke PF ≥ 1.0. | 5.1 |
| R12 | Search | Model 1, full grid, coarse → fine per parameter. No fixed lever limit; set by the hypothesis. | 5.3, 5.4, 5.6, 7a #6 |
| R13 | Freeze before qualifying | Trial runs are development-only. Before any qualifying run, freeze per EA: ranges, score formula, plateau rule, tie-breaks. | 7c #6 |
| R14 | Plateau rule | Per EA, decided with the owner, frozen under R13. **Default (v2):** choose the frozen center by the **neighbour-smoothed** score: the mean score over the pass and every pass within one grid step on every axis. | 5.7, R15 trial 2 |
| R15 | Score formula | **F5 (v2):** score = recovery factor × R19 confidence multiplier (A 1.0 · B 0.75 · C 0.5 · D 0). A pass with equity DD > 12 % is excluded. Escalation class adds the R18 penalties; their weights stay `OPEN` until the in-EA basket log exists. Chosen by the rule trial 1 pre-registered: no variant qualified, so the fallback applied (`R15_SCORE_TRIAL_2_DEV.md`). | 5.8, trials 1–2 |
| R16 | Model 4 | Frozen finalist must pass Model 4 MAIN + BWD before CANDIDATE. | 5.3, 7c #1 (owner 2026-11-04) |
| R17 | DD limits | Equity DD (open positions included) ≤ 12 % per EA at selection; ≤ 30 % per portfolio including correlation (DEMO admission code at 30 % since `22761365`; the live sizing bar in `docs/JUDGE_DAY_RUNBOOK.md` is 30 % too, owner 2026-11-05). Demo kill eqDD > 12 % unchanged. | 7a follow-up, Q10 |
| R18 | Escalation floating loss | Worst basket depth + holding time reported and penalised. Source = timestamped equity + basket log from inside the EA (core); locked EAs = price replay of their deals; no observations ⇒ no score. Positions open at test end closed at bid/ask + costs. | Q10, 7c #3 |
| R19 | Trade count | Sets evidence confidence, separate from quality grade (`EA_REPORT_SCHEMA.md` §9). **Accepted by owner 2026-11-04:** closed trades per window A ≥100 · B 50–99 · C 20–49 · D <20; the EA takes its worst MAIN/BWD window; grade A needs confidence ≥B, grade B needs ≥C; a variant trading >50% fewer than its parent prints both counts. The VERDICT GATE carries this since 2026-11-04 (evidence-confidence row in `CLAUDE.md`, replacing the fixed ≥100 floor). | 7a report |
| R20 | Extra lever round | One diagnosis-driven round allowed: written reason, approved by any reviewer who is not the author. | Q2, 7a #8 |
| R21 | Checker | `optimize_guard.ps1` stays the preflight. Acceptance = a separate receipt bound to report / build / set / window / recipe version. `-WarnOnly` or unresolved inputs never produce acceptance. Every refusal is recorded in `factory/optimize_decisions.jsonl`. | 7a #11, 7c #7 |
| R22 | Guard evidence | Method A (trade-list counterfactual) = screening only. Qualifying evidence = method B (in-tester OFF / ON / PLACEBO, pre-registered timeline + selection rule) with fire counts, including stale/missing-feed cases. A guard that fired 0 times = `UNTESTED`. Guards are EA inputs, `OFF` by default. | 7c #9, VERDICT GATE guard row |
| R23 | Report | Full report = `EA_REPORT_SCHEMA.md`; plus a one-page front sheet (equity + balance curves, guard-fit box) and one leaderboard row per EA × symbol. | 7a report |
| R24 | Locked EAs | Keep their binary; R7–R23 apply; score computed externally from the MT5 report (and R18 via price replay). | Q1 |
| R25 | Where | Lane worktree from `origin/master` at a pinned SHA; never `D:\EA_LAB`. Local-only EAs enter only via the A10 tick sheet. | 7b |

**Open items before build:** R18 escalation penalty weights (need the in-EA equity/basket log, a core edit). Done: R15 + R14 default frozen (v2) · VERDICT GATE R19 amendment · `DEMO_BUDGET_PCT` 25 → 30 for DEMO (`22761365`); the live sizing bar in `docs/JUDGE_DAY_RUNBOOK.md` is 30% too (owner 2026-11-05).
Proposals for R4 and R19: `D:\EA_LAB_RESET\_raw\open_rules_proposal.md`. Recipe and receipt spec for R12–R21: `RECIPE_AND_RECEIPT_SPEC_DRAFT.md`.

**Governance note:** the single-Seat model was retired on 2026-11-04 (`d4db8d0a`, `AGENTS.md` §1.0). Build lanes integrate under the §1.0 integration rule.

| Version | Date | Change | Decided by |
|---|---|---|---|
| v1 | 2026-11-04 | First consolidated table after GPT-6.1-Sol review; R16 Model 4 moved before CANDIDATE. | Owner |
| v2 | 2026-11-04 | R15 frozen = F5; R14 default = neighbour-smoothed center; R19 carried into the VERDICT GATE. | Owner ("ok ทำเลย") |

## 8. Constraints carried over

VERDICT GATE and bar table unchanged · MAIN/BWD/HOLDOUT windows unchanged · `ea_template/core` edits keep their regression
and review requirements · no change to running EAs, VPS, accounts or `.set` files from this design.
