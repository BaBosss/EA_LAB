# EA_LAB remediation review + 3–6 month roadmap — Codex second opinion (2026-07-19)

Scope: static, read-only review. Fixed point for the safety-remediation diff = `dd82e57d` (`629012a0^`); primary remediation commits = `629012a0`, `8269a310`, `0dcf60e2`, `1a0dd7ff`, with current-HEAD spot checks. I did not run compilers, Strategy Tester, or trading platforms, as required by the prompt. Compile/cage numbers below are therefore **recorded evidence from the repo, not an independent rerun**.

## 1. STATE READ

1. EA_LAB is no longer primarily a research-pipeline build: the repo itself calls the pipeline mature and says cheap split/coverage/filter levers are low-yield (`PROJECT_STATE.md:204`).
2. The active operational surface is already large: read-only aggregation of `portfolio/DEPLOYMENTS.csv` gives 47 rows across 7 accounts—27 active demo, 11 active real-cent, 3 unverified, and 2 pending attach.
3. All 11 active real-cent rows currently have blank `judge_date`; several are explicitly user experiments or uncertified mixes, so “deployment exists” is not the same as “lab-controlled exposure” (`portfolio/DEPLOYMENTS.csv`).
4. The Boss V2 safety overhaul is material, not cosmetic: broker-flat kill reconciliation, pre-bar safety, transactional close state, scoped persistence, dynamic cage discovery, spread checks, and lot-step normalization exist in current code (`ea_template/core/{RiskControl,Execution,LabCore,Stack,ExitManager,Kangaroo,Persist}.mqh`).
5. The recorded verification is stronger than before: commit history/taskboard record 9 wrappers compiling 0/0, unit tests 6/6, mode-93 A/B neutrality, and cage 8/8 CLEAN (`AGENT_TASKBOARD.md:175-188`).
6. That does **not** close the original system review completely: static re-check classifies 7/19 findings fully closed, 8 partially mitigated, and 4 still deferred/open; review of the remediation diff also found four new actionable failure paths (tables below).
7. The research-evidence layer remains the promotion bottleneck: drift monitoring, effective sample size, multiple-testing discipline, immutable lineage, restore drill, credential/privacy controls, and cohort judge dates are all still unchecked P1 items (`MASTER_BACKLOG.md:286-304`).
8. The long-term roadmap already contains the right eventual capabilities—tracking-error bands, deflated gate, multi-account equity combination, and portfolio risk layer—but schedules most of them after judge (`ROADMAP.md`, Phase 3.5 and Development backlog).
9. The lab therefore has more candidates and live surface than it has trustworthy observation/provenance capacity; adding another entry family has lower marginal EV than making one candidate fully reconstructable and one cohort continuously observable.
10. Independent conclusion: the next phase should be **stabilize → observe → promote with evidence → portfolio-control → scale**, while keeping only a small, capped R&D lane alive.

### Remediation review against the 19 findings from `_triage/CODEX_SYSTEM_REVIEW_2026-07-18.md`

| # | Original finding | Status now | Static evidence / residual |
|---:|---|---|---|
| 1 | HALT persisted before broker-flat proof | **Closed** | `Exec_CloseAll()` rescans positions+pendings; `RiskControl` holds `KILL_PENDING` until flat (`Execution.mqh:340-358`, `RiskControl.mqh:198-224`). |
| 2 | Bar gate bypassed intrabar hard-kill | **Closed** | hard-kill and money stop now run before `_0_BarOpenOnly` (`LabCore.mqh:183-200`). |
| 3 | Hedge legs treated as ordinary basket legs; no netting guard | **Open — high priority** | `Hedge_PosIsHedge()` recognizes the comment only inside `Hedge.mqh:24-29`; generic `Exec_CountDir()` still counts every own position (`Execution.mqh:164-178`), and `LabCore.mqh:231-233` uses those counts. No `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING` OnInit guard was found, despite `DESIGN_V2.md:339-342`. Keep HedgeMode OFF until fixed. |
| 4 | Kangaroo could open with SL=0 | **Closed for Kangaroo** | `Kangaroo_Open()` blocks and retries when risk ATR/SL distance is unavailable (`Kangaroo.mqh`, `slD <= 0` branch). This is module-local, which is adequate for the stated Kangaroo promise. |
| 5 | Pending ladder margin/latch failure | **Partial** | per-leg tickets, retcode checks, adopt-by-price, and account-wide pending projection are present (`Stack.mqh:91-260`, `Execution.mqh:262-278`). Continuous re-budget/cancel after a completed GTC ladder remains explicitly deferred as S3; balance/leverage/other-EA changes can invalidate the original reservation (`_triage/CODEX_ORDER132_AUDIT.md:858-868`). |
| 6 | Multi-leg exits advanced state without confirmation | **Partial** | pair intent and per-tick latches improve retry behavior, but `Exec_ClosePartialFraction()` records a ticket from boolean+retcode without reselecting and proving volume actually fell (`Execution.mqh:437-451`), while partial milestones and full-close latches remain memory-only (`ExitManager.mqh:353-443`). ORDER-132’s original acceptance asked for observed volume reduction (`AGENT_TASKBOARD.md:185`). |
| 7 | Shared default magic / collision risk | **Partial** | live/demo rejects reserved default `990001` (`LabCore.mqh:75-85`), but two non-default duplicate magics can still attach; automatic attach/config attestation and magic-collision checking remain P2 (`MASTER_BACKLOG.md:301`). |
| 8 | Regression could run stale binaries and omitted Boss_17/18 | **Closed** | dynamic `Boss_*.mq5` discovery, compile-current-source, zero-expert failure, two-way baseline checks, and 8-row baseline are present (`scripts/tpl_regression.ps1:38-121`, `ea_template/regression_baseline.csv`). |
| 9 | `_0_MaxSpread` was dead | **Closed** | centralized placement-only predicate gates market and pending opens (`Execution.mqh:61-78,150,310`); units are documented as points (`Inputs.mqh`). |
| 10 | Lot normalization could exceed cap / assume 2 decimals | **Closed** | volume-step digit arithmetic and below-minimum return-zero are in `Exec_NormalizeLot()`; risk-reducing closes use uncapped `Exec_NormalizeCloseLot()` (`Execution.mqh:30-58,380-397`). |
| 11 | MAIN overlapped HOLDOUT | **Closed at authority layer** | `CLAUDE.md:9` and `PROJECT_STATE.md:52,242` now pin MAIN 2023.01–2025.12 and require `MAIN ∩ HOLDOUT = ∅`. Several old scripts/plans still contain historical windows, so a machine-readable window contract is still preferable. |
| 12 | Pre-commit validated working tree, not staged deployment bytes | **Open** | `.githooks/pre-commit` still runs `check_state.ps1 -Strict` on the working tree. `check_precommit_staged.ps1` protects exactly five archive/taskboard artifacts, not deployments/dashboard/scorecard/index/B1/template baselines. |
| 13 | Scorecard/index sync claimed hook-enforced but was not | **Partial** | ORDER-130 manually added/synchronized current rows (`EA_MASTER_INDEX.csv:127-135`), but no bidirectional index parity check was found; `CLAUDE.md:71` still says “hook-enforced.” |
| 14 | Two active verdict engines in scorecard | **Partial** | the old CORE/REBUILD bands are bannered historical (`EA_SCORECARD_AND_REGISTRY.md:31,337`), but the immediately following `HOW TO USE` still says “Band the score → verdict” (`:339-343`), and active EA-SCORE grants real-money sizing rights (`:351+`). This remains ambiguous against the single authority in `CLAUDE.md:65-74`. |
| 15 | Stale deployment assertions inside canonical entry | **Partial** | the old table is stamped historical (`PROJECT_STATE.md:247`), but earlier/current-looking prose still says “9 EA live” and uses the old 2026-09-22 cohort clock (`PROJECT_STATE.md:123-147,404-406`). The CSV pointer is correct; the surrounding onboarding narrative is not fully retired. |
| 16 | Persist scope + cashflow-sensitive HWM | **Partial** | scope is now server/login/symbol/magic with migration (`Persist.mqh:26-39`; `PERSIST_MIGRATION_ORDER132.md`), but HWM still compares absolute account equity without deposit/withdrawal adjustment (`RiskControl.mqh:64-101,184-190`). |
| 17 | B1 cohort incomplete | **Open** | `B1_DATASET.csv` has 10 rows but still omits ORDER-120..123, whose close commit `d0560ccb` is after anchor `0e13699e`; the cohort contract says first 20 eligible closes with no selection (`B1_COHORT.md:16-26,42-52`). |
| 18 | Agent-routing authority conflict | **Open** | `PROJECT_STATE.md:208` says important code is Claude-authored and Codex blind-audits only; `AGENTS.md:57,156-167` still recommends Codex as builder/default for code. |
| 19 | Template/roadmap docs stale | **Partial** | stale banners were added (`ea_template/README.md:3`, `ROADMAP.md:29`), but README still teaches tester-only/stub behavior in the main body. A warning reduces harm but is not a maintained onboarding document. |

The implementation trajectory is good: the highest-risk kill/exit/persist issues were addressed and the audit loops found real second-order defects. The remaining mistake would be to interpret “cage CLEAN” as “all deployment and governance failure modes closed.”

### New actionable findings introduced/exposed by the remediation diff

These are separate from the 19-item closure count above. They were found by an independent standards review and then spot-verified directly in current HEAD.

| Severity | Finding | Evidence and consequence |
|---|---|---|
| **SEV-1** | Ambiguous legacy migration can execute a kill on the wrong current account | `Persist_MigrateLegacy()` copies identity-less `Boss_<magic>_*` state into whichever server/login/symbol is current (`Persist.mqh:101-130`). `RiskControl_Init()` converts legacy `rc_kill_pending=1` into scoped KILL_PENDING and the next tick calls `Exec_CloseAll()` (`RiskControl.mqh:120-150,198-224`). The operator guide itself warns that stale imported state can close the current account’s matching positions (`PERSIST_MIGRATION_ORDER132.md:46-52`). An irreversible close intent with unverifiable provenance should fail initialization and require explicit migration, not auto-adopt. |
| **SEV-1** | Kangaroo pair-close persistence is not atomic | `Kangaroo_PairPersist()` writes `k16_pair_a` and `k16_pair_b` as separate unchecked GVs, then flushes (`Kangaroo.mqh:49-55`); closing begins immediately after the unchecked call (`:343-351`). One failed write or crash between writes can restore only one leg. Use a two-ticket record plus commit marker (or equivalent transactional protocol), verify+flush before the first close, and abort liquidation if durable arming fails. |
| **SEV-1** | Full-basket liquidation intent is still restart-volatile | `g_exit_closeall_pending` and `g_k16_closeall_pending` are memory-only (`ExitManager.mqh:359-370`, `Kangaroo.mqh:46-98`). A restart after partial liquidation can erase the intent after the original profit/loss/trend predicate has disappeared, returning residual exposure to ordinary management. Persist/flush the intent before the first close; clear only after broker-flat proof. |
| **P1 safety** | A deployed test EA can erase all Boss safety GlobalVariables | `PersistMigrate_Test.mq5` has no `MQL_TESTER` guard and repeatedly runs `GlobalVariablesDeleteAll("Boss")` (`:12-60`), whose prefix also matches `Boss2_*`. `deploy.ps1:25` mirrors the entire template—including tests—into the terminal Experts tree. Accidental chart execution can delete halt/kill/HWM/pair state for every Boss instance. Refuse OnInit outside tester and use test-unique keys rather than a terminal-wide prefix. |

Until these are fixed and failure-tested, **do not roll the post-132 binary onto live accounts and do not attach any file under `EALabTpl/tests` to a chart**. Existing demo migration should be treated as a canary, not proof that ambiguous legacy state is safe.

## 2. RANKED DIRECTIONS

### 1) Finish the remaining template enablement hazards

- **Category:** ops-debt
- **Why now:** the mold is already deployed/staged, while the remediation diff still contains ambiguous legacy kill migration, non-atomic pair intent, restart-volatile basket liquidation, and a destructive test EA; Hedge role identity/netting compatibility is also still wrong, duplicate custom magic remains possible, pending-ladder budget can become stale, and account HWM is not cashflow-neutral. Evidence: the new-findings table; remediation table #3/#5/#7/#16; `DESIGN_V2.md:332-342`; `MASTER_BACKLOG.md:301-302`.
- **Cheapest confirming evidence:** first add static/tester-only guards and transactional persistence tests, then run one failure-path suite plus one demo migration canary: (a) identity-less kill state must fail closed without sending closes; (b) crash/write-fail between pair tickets restores either the complete pair or no executable intent; (c) restart after partial close resumes basket liquidation; (d) test EA refuses non-tester execution; (e) Hedge ON on netting fails OnInit and hedge legs do not alter core counts; (f) duplicate custom magic alarms/blocks; (g) stale ladder budget cancels safely; (h) deposit/withdrawal is HWM-neutral. Existing 8/8 numeric cage remains the neutrality check.
- **Failure mode if skipped:** a migration or restart can close the wrong/current exposure, abandon half a liquidation, or erase persisted safety state; later advanced-mode enablement can also create cross-direction adds, stale over-budget fills, or a false account-DD stop.
- **Rough effort:** **M**. Do before ORDER-125 vertical-barrier or any Hedge/Recovery production validation; keep advanced modes OFF meanwhile.

### 2) Make terminal reality attestable and recoverable

- **Category:** ops-debt
- **Why now:** `DEPLOYMENTS.csv` contains 47 rows/7 accounts, including 3 UNVERIFIED rows and 11 active real-cent rows without judge dates. P1/P2 already calls for judge dates, attach/config/build attestation, broker reconciliation, backup drill, credential inventory, and Gist privacy (`MASTER_BACKLOG.md:288-304`). This is the actual production boundary, not the source tree.
- **Cheapest confirming evidence:** obtain seven consecutive daily snapshots from every account/terminal with zero stale gaps; every active row resolves to account+symbol+magic+binary hash+set hash+account mode+server-side SL status; run one alert drill and restore one terminal/monitor bundle onto a clean directory from backup. Redact the public dashboard sample at the same time.
- **Failure mode if skipped:** the lab can have perfect source and still monitor the wrong EA, lose the evidence/config needed to reproduce a live event, or discover during an incident that the only operator/credential/backup path is unavailable.
- **Rough effort:** **M** (mostly integration/runbook work, not new trading logic).

### 3) Build an immutable promotion evidence contract

- **Category:** ops-debt
- **Why now:** promotion statistics and evidence lineage are explicitly open P1 items (`MASTER_BACKLOG.md:289-293`); the staged-snapshot gap, index parity gap, scorecard ambiguity, and missing B1 rows show the same root problem—truth is still partly prose/manual. Judge dates in the CSV are approaching 2026-10-09/16.
- **Cheapest confirming evidence:** choose one existing demo candidate and reproduce its decision from a single manifest containing source/binary/set/report hashes, tester build, symbol/history range, pre-registered hypothesis count, MAIN/BWD/holdout ownership, WFA/PBO or a declared reason not applicable, and exact promotion rule. A second operator/session must reconstruct the same verdict inputs without searching chat. Add staged negative tests that intentionally mismatch `DEPLOYMENTS.csv`, dashboard map, scorecard/index, B1, and baseline.
- **Failure mode if skipped:** an apparently strong candidate is promoted from overwritten, selected, or internally contradictory evidence; future audits cannot distinguish a real edge from selection history.
- **Rough effort:** **M**. Start with one vertical slice, then generate views rather than hand-maintain more cross-file rules.

### 4) Turn demo forward data into live-vs-backtest tracking-error bands

- **Category:** new-capability
- **Why now:** there are 27 active demo legs, yet the open P1 item still asks for trade-rate, PF uncertainty, spread/slippage, holding time, layer depth, and MAE/MFE monitoring (`MASTER_BACKLOG.md:289`). `ROADMAP.md` defers tracking-error bands to Phase 3.5, but the data is being generated now; delaying schema/collection until judge wastes the most valuable forward sample.
- **Cheapest confirming evidence:** run a shadow-only weekly report on one high-frequency and one thin EA for four weeks. Pre-register expected trade-rate/holding/spread bands from locked backtests, then report data-quality coverage and alerts without taking automated action. Worth continuing if it catches a real data/config drift or produces stable, interpretable bands with a tolerable false-alert rate.
- **Failure mode if skipped:** judge day becomes a single noisy PF snapshot; execution/config drift is discovered after three months, and thin strategies appear “not failed” merely because they produced too little information.
- **Rough effort:** **M**. Collect first, automate decisions much later.

### 5) Add portfolio risk control only after Directions 1–4 have a working vertical slice

- **Category:** new-capability
- **Why now:** the end-state is 10 accounts × 2–3 low-correlated EAs (`VISION.md`; `ROADMAP.md:8-22`). Current deployments already concentrate multiple XAU/trend/breakout legs, while the current CSV is account-by-account rather than a reconstructed portfolio equity surface. The planned multi-account combiner, vol targeting, and portfolio DD budget are the right scaling control (`ROADMAP.md`, Phase 3.5 / Development backlog).
- **Cheapest confirming evidence:** offline replay existing deal/snapshot history into one cross-account equity series; compare equal-size versus volatility-budgeted weights and verify that the proposed portfolio breaker would have reduced worst overlapping DD without deleting most return. Require complete data coverage before crediting the result.
- **Failure mode if skipped:** ten “individually bounded” accounts can still share the same gold/USD/regime loss and breach the owner’s aggregate risk budget together.
- **Rough effort:** **L**. Design now, shadow after judge, enforce only after at least one month of reliable portfolio telemetry.

### 6) Keep strategy R&D alive, but cap it at one diversity-seeking concept per week

- **Category:** strategy-R&D
- **Why now:** VISION requires a dual track, but the repo’s own recent evidence says cheap refinements are exhausted (`PROJECT_STATE.md:204`) and mass-smoke yield is low (`ROADMAP.md` hunt queue). The marginal R&D dollar should seek a missing payoff shape, not another close cousin of existing XAU trend/grid exposure. PairSpread is already a weak demo experiment, and triangular-arbitrage/relative-value is explicitly identified as a diversification gap (`MASTER_BACKLOG.md`, BUILD-ON ideas).
- **Cheapest confirming evidence:** flat-lot/naked probe first, on one plausible home plus one regime/window, with a pre-registered stop. Continue only if the raw mechanism is >1 on both windows **and** its return timing is materially different from the current cohort; otherwise catalog the mechanism and stop before chassis/MM work.
- **Failure mode if skipped:** after ops work the bench may lack genuinely different mechanisms; if uncapped, however, R&D again consumes the validation/operations capacity that is already the bottleneck.
- **Rough effort:** **S per concept, fixed weekly budget**. Prefer relative-value, non-gold, and user-origin ideas; pause broad corpus generation.

## 3. DO-NOT-BUILD

- **Do not deploy post-132 binaries to live or attach template test EAs to charts yet:** ambiguous legacy kill migration, non-atomic intent, restart-volatile liquidation, and the unguarded GV-deleting test must close first.
- **Do not enable/validate Hedge or complex Recovery for production yet:** known role/netting and stale-budget residuals make this premature; close Direction 1 first.
- **Do not add ORDER-125 vertical-barrier or more chassis levers to the live mold yet:** every new exit state expands the transaction/restart test matrix before the existing one is closed.
- **Do not build the LLM-entry factory or another mass-corpus ingestion wave now:** 1,592+ candidates and 27 active demo legs show idea supply is not the bottleneck; observation and promotion integrity are.
- **Do not automate promotion, live sizing, or kill decisions from early PF:** first build complete telemetry and uncertainty bands; automatic action on thin samples amplifies noise.
- **Do not build MVP-2 Context Packet yet:** its own contract requires 20 B1 rows and ≥30 days; B1 is incomplete and missing eligible orders (`B1_COHORT.md`, `B1_DATASET.csv`).
- **Do not build tick/low-latency/ML-alpha infrastructure:** `ROADMAP.md` already rejects quant-firm infrastructure at this capital/operating scale; portfolio-risk methods have far higher EV.
- **Do not automate “10 accounts” as a rollout target:** automate the opening of account #2 only after account #1 has one month of reliable portfolio telemetry and a successful restore/incident drill.

## 4. DOCTRINE CHECK

**FIX-THEN-SCALE is still the right doctrine, but “FIX” should now mean operational evidence, not another long core-refactor season.** The core safety work removed several credible loss paths, yet static review still leaves four open and six partial findings. More importantly, the lab already operates a 47-row/7-account surface while P1 promotion/lineage/drift/restore controls remain unchecked. That is a larger expected-loss surface than the absence of another entry signal.

Recommended allocation for the next 8–12 weeks: **~80% operations/evidence and ~20% bounded R&D**. This is not “stop research”; it preserves VISION’s dual track while preventing R&D from consuming the scarce validation and operator-attention lanes.

Shift from FIX-THEN-SCALE to controlled scale only when all four are true:

1. Advanced template modes are either statically/failure-path safe or explicitly disabled; the open hedge/netting issue is closed.
2. Every active/unverified deployment is attested and every cohort has its own judge rule/date; one restore + alert drill succeeds.
3. One candidate’s promotion evidence is reproducible from an immutable manifest, and staged negative tests cover all canonical parity surfaces.
4. At least 30 days of complete forward telemetry produce usable tracking bands for a representative fast and thin EA.

After that gate, Direction 5 (portfolio risk layer) becomes the highest-EV build. Until then, scaling would multiply uncertainty faster than expected return.

## 5. BLIND SPOT

**The lab is underweighting information rate: a calendar judge date is not the same as a decision-capable sample.** Several deployment notes explicitly say thin (for example Wave5 USDJPY at 11–17 trades/year and Ichi/other sparse legs), while the backlog itself has not settled the minimum effective sample. A three-month demo can reach its date with almost no statistical power; “no kill trip” then risks being mistaken for positive evidence.

Test whether this is real with a one-page **judge-readiness forecast** generated from locked backtest trade rates and current forward counts: for every active demo leg, estimate trades expected by judge date, probability of reaching 15/30/100 trades, PF/win-rate confidence width, and expected additional months to a decision-capable sample. Classify each row as `decision-capable`, `risk-only observable`, or `data-collection only`. If many October rows are not decision-capable, keep the dates as operational reviews but do not treat them as promotion deadlines.
