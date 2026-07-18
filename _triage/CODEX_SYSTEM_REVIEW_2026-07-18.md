# CODEX SYSTEM REVIEW — EA_LAB + EA Template (2026-07-18)

> Scope: independent, read-only audit of the process layer and Boss V2 code layer requested by
> `_triage/CODEX_SYSTEM_REVIEW_PROMPT_2026-07-18.md`. No compiler, backtest, or trading platform was run.
> `scripts/check_state.ps1 -Strict` was run read-only and returned CLEAN. Code coverage included all
> `ea_template/core/*.mqh`, all `core/entries/`, Boss_11 through Boss_18, template docs, deploy/regression
> scripts, baseline, and template tests. Legacy `ea_template/modules/` and external watchdog internals were
> outside the requested V2-core scope.

## 1. SYSTEM SUMMARY

1. EA_LAB is a solo-operated research factory that turns trading ideas into MT5 EAs and deployment decisions.
2. `PROJECT_STATE.md` is intended to be the single entry point; specialist facts have named owner files.
3. A taskboard and role protocol separate judgment (Claude/user) from code/batch evidence production.
4. The research funnel uses smoke, optimization, backward regime, holdout, Monte Carlo, Model-4, correlation, and demo gates.
5. Boss V2 is the production mold: compile-time entry modules share execution, money, exit, stack, recovery, hedge, and risk modules.
6. New-order traffic is centralized in `Execution.mqh`, scoped by symbol and magic, with optional macro/news vetoes.
7. Protection is intended to combine per-order/basket stops, lot/depth/load caps, equity-DD hard kill, and persisted halt state.
8. Numeric regression and small module smoke tests are intended to cage every core change before deployment.
9. Live deployment truth is intended to live in `portfolio/DEPLOYMENTS.csv`, with dashboard and documentation checked at commit time.
10. The design is disciplined and unusually evidence-aware, but several transactional and authority gaps make the safety claims stronger than the implementation.

## 2. FINDINGS

### [SEV-1] | code | Hard-kill persists HALT before proving every position and pending order is gone

- **Evidence:** `ea_template/core/Execution.mqh:217-226` ignores failed pending deletes; `Execution.mqh:257-267` discards every `PositionClose` result and returns no completion status. `ea_template/core/RiskControl.mqh:151-167` calls `Exec_CloseAll()`, immediately sets `g_rc_halted=true`, and persists `rc_halted=1`. `ea_template/core/LabCore.mqh:186-188` then stops management when halted.
- **Concrete failure scenario (HYPOTHESIS):** a close or delete fails during a liquidity gap, market closure, or broker rejection. If DD later falls below the kill threshold, `RiskControl_CheckDD()` no longer calls close, while `RiskControl_IsHalted()` keeps returning early. A residual position can remain unmanaged, and a residual GTC pending can fill after the EA has declared itself permanently halted.
- **Suggested fix:** make close-all a reconciliation state machine (`KILL_PENDING → FLAT_VERIFIED → HALTED`). Verify zero own positions and zero own pendings, inspect/log retcodes, retry every tick independent of current DD, alert on timeout, and persist HALTED only after broker state is flat.
- **Falsification pass:** the kill path does retry while DD remains above the threshold because `CheckDD` runs before `IsHalted`; therefore this is not always one-shot. The defect remains for residual exposure after DD drops below the threshold and for pending-delete failure.

### [SEV-1] | code | `_0_BarOpenOnly` bypasses the hard-kill and all basket management for the rest of the bar

- **Evidence:** `ea_template/core/LabCore.mqh:166-182` returns immediately on same-bar ticks when a basket is open; the hard-kill is only reached later at `LabCore.mqh:186-188`. The documented order says risk must be first at `ea_template/DESIGN_V2.md:209-217`. Production/demo Boss_14 sets enable the hazardous branch, e.g. `ea_template/sets/Boss14_GridLog_EURJPY_DEMO.set:20` and `_vps_deploy/BOSS14_GBPJPY/Boss14_GridLog_GBPJPY_H4_demo_leg8.set:20` set `_0_BarOpenOnly=true`.
- **Concrete failure scenario:** on an H4 Boss_14 chart, equity can cross the 15/25/40% kill threshold just after bar open, but the EA will not evaluate the hard-kill, basket money stop, partial exits, recovery, or hedge again for almost four hours.
- **Suggested fix:** run account/magic reconciliation and `RiskControl_CheckDD()` before every bar-open early return. Bar-gate only signal generation and strategy management that is intentionally bar-based; never gate safety exits.
- **Falsification pass:** Boss_16 bypasses this generic branch and runs its hard-kill first in `Kangaroo.mqh:275-295`; the finding is restricted to generic Boss builds using `_0_BarOpenOnly`, notably Boss_14.

### [SEV-1] | code | Hedge legs are only role-aware inside `Hedge.mqh`; the rest of the chassis treats them as ordinary basket legs

- **Evidence:** `ea_template/core/Hedge.mqh:24-53` excludes the `" H"` comment only in hedge-specific helpers. Generic counts in `ea_template/core/Execution.mqh:127-141` include every own position. `ea_template/core/LabCore.mqh:207-228` uses those counts and chooses BUY whenever any BUY exists. Documentation promises the hedge is not counted as directional exposure at `ea_template/DESIGN_V2.md:334-342`. `LabCore.mqh:73-118` has no account-mode validation despite the documented hedging-account-only limitation.
- **Concrete failure scenario (HYPOTHESIS):** a SELL grid opens a BUY hedge; generic logic now sees both directions, chooses BUY, and may add grid exposure in the hedge direction. On a netting account, the “hedge” order instead reduces or reverses the original position.
- **Suggested fix:** give every order an explicit durable role (`CORE`, `HEDGE`, `RECOVERY`, `PENDING`) and make all counts/exits role-aware. Fail `OnInit` when HedgeMode is enabled on a non-hedging account; prohibit unsupported HedgeMode/StackMode combinations.

### [SEV-1] | code | Kangaroo can open a supposedly protected order with `SL=0` when risk ATR is unavailable

- **Evidence:** `ea_template/core/Kangaroo.mqh:70-83` returns zero when risk ATR is unavailable; `Kangaroo.mqh:128-138` converts that into `sl=0` and still calls `Exec_Open`. Boss_16 is a current candidate in `PROJECT_STATE.md:150-160`.
- **Concrete failure scenario (HYPOTHESIS):** immediately after attach/restart or while the higher risk timeframe is not synchronized, the entry signal is ready but the risk-ATR buffer is not. The first live order is accepted without the per-order SL that the strategy design assumes.
- **Suggested fix:** fail closed until SL distance is positive and broker-valid; centralize stop validation in `Exec_Open`; add a restart/no-history test that proves no order can open without its promised stop.

### [SEV-1] | code | Pending pyramid ladders can exceed the deposit-load cage at fill time and become permanently incomplete

- **Evidence:** `ea_template/core/Stack.mqh:120-136` checks deposit load once, places all GTC legs in a loop, ignores each placement result, then sets `g_stack_ladder_placed=true`. `ea_template/core/Execution.mqh:246-249` sends ordinary broker-side GTC pending orders; no later fill-time margin gate exists in the EA.
- **Concrete failure scenario (HYPOTHESIS):** load is below the cap at placement, then several legs fill together on a gap. Margin jumps above the configured cage before the EA can react. If one placement was rejected, the ladder is still latched complete and the missing leg is never retried until flat/restart.
- **Suggested fix:** pre-calculate aggregate worst-case margin with `OrderCalcMargin`, reserve budget for every pending, track tickets/results per leg, and use `OnTradeTransaction` to cancel remaining orders when projected load breaches the cap.

### [SEV-1] | code | Multi-leg “controlled exits” are not transactionally confirmed

- **Evidence:** `ea_template/core/Kangaroo.mqh:217-232` ignores both `Exec_CloseTicket` results during newest+oldest pair close. `ea_template/core/Execution.mqh:291-307` ignores partial-close results, while `ea_template/core/ExitManager.mqh:401-409` marks each partial milestone done unconditionally.
- **Concrete failure scenario (HYPOTHESIS):** the profitable newest leg closes but the deep losing oldest leg fails; the strategy has realized the cushion and retained the tail risk it intended to remove. A failed partial close is marked done and is not retried while the milestone remains active.
- **Suggested fix:** confirm resulting position volumes/deals before advancing exit state; if a two-leg close partially succeeds, retry or compensate according to an explicit policy. Persist/restore in-flight exit state across restart.

### [SEV-1] | code | Every Boss wrapper ships with the same live-capable default magic and no collision guard

- **Evidence:** `ea_template/core/Inputs.mqh:449-453` defines `_0_Magic=990001` for all wrappers. Position ownership is only symbol+magic at `ea_template/core/Execution.mqh:21-27`. No collision validation exists in `LabCore.mqh:73-118`.
- **Concrete failure scenario (HYPOTHESIS):** two Boss EAs are attached to the same symbol with compiled defaults or a stale/missing `.set`; each counts, stacks, partially closes, and hard-kills the other’s positions.
- **Suggested fix:** assign unique compile-time defaults per Boss, reject a reserved/default magic in live mode, and perform an attach-time registry/collision preflight. Consider a durable strategy-instance identifier in addition to magic+symbol.
- **Falsification pass:** sampled deployment sets use unique magics (for example Wave5 990301–990303 and Boss_14 leg 990208), so no current collision was proven. The unsafe compiled-default path and absence of a fail-closed guard remain.

### [SEV-2] | code | The required regression cage can test stale binaries and does not cover Boss_17 or Boss_18

- **Evidence:** `scripts/tpl_regression.ps1:30-38` lists only Boss_11–16 and `tpl_regression.ps1:54-64` runs installed Experts without deploying/compiling current source. `ea_template/regression_baseline.csv:2-7` contains only 11–16. `ea_template/deploy.ps1:31-39` compiles 11–16 and 18 but omits Boss_17. Core was last changed after the baseline (`git log`: core `1402de1f`, 2026-07-18; baseline `d28d08a1`, 2026-07-11).
- **Concrete failure scenario:** an agent edits `core/`, runs the mandatory regression command directly, and gets CLEAN from the previously installed `.ex5`; later deploy compiles most wrappers but leaves an old Boss_17 binary in place. Conditional paths for 17/18 have no numeric baseline.
- **Suggested fix:** have regression mirror source, delete old binaries, compile every `Boss_*.mq5` discovered dynamically, bind each report to the just-built binary/source hash, and add pinned baselines for 17/18. Add the cage itself to pre-commit when `ea_template/core/**` changes.

### [SEV-2] | code | `_0_MaxSpread` is a dead safety input

- **Evidence:** it is declared at `ea_template/core/Inputs.mqh:449-453`; repository search finds no other V2-core reference. Market and pending opens at `ea_template/core/Execution.mqh:111-124` and `Execution.mqh:232-254` have no spread check.
- **Concrete failure scenario:** an operator sets a non-zero maximum spread believing entries/adds will be blocked, but the EA opens through news/rollover widening at an uneconomic price.
- **Suggested fix:** enforce one central spread predicate in both market and pending open paths; log throttled rejections and unit-test boundary values.

### [SEV-2] | code | Lot normalization can violate `RC_MaxLot` and assumes all brokers use two volume decimals

- **Evidence:** `ea_template/core/Execution.mqh:30-40` clamps to `RC_MaxLot`, then raises the result to broker minimum, and finally uses `NormalizeDouble(lot,2)` regardless of `SYMBOL_VOLUME_STEP`.
- **Concrete failure scenario:** `RC_MaxLot=0.005` with broker minimum 0.01 sends 0.01, exceeding the claimed hard ceiling. A 0.001-step symbol can be rounded to an invalid or larger two-decimal volume. The same routine also sizes partial closes.
- **Suggested fix:** normalize with integer step arithmetic and digits derived from `SYMBOL_VOLUME_STEP`; if the safe cap/request is below minimum, return zero and alert; re-check min/max/cap after rounding.

### [SEV-2] | process | Canonical MAIN and HOLDOUT windows overlap

- **Evidence:** the locked decision says MAIN must not consume holdout and gives `2023.01–2025.12` at `PROJECT_STATE.md:201`. `CLAUDE.md:9` instead defines MAIN as approximately `2023.07–2026.07` and HOLDOUT as `2026H1` on the same line. `PROJECT_STATE.md:52,242` still repeats the superseded `2023–2026` convention. ORDER-121 required the non-overlapping convention at `AGENT_TASKBOARD.md:118-125`.
- **Concrete failure scenario (HYPOTHESIS):** an operator selects parameters on data through July 2026, then reports 2026H1 as untouched holdout, inflating apparent robustness through leakage.
- **Suggested fix:** put half-open window intervals in one machine-readable config and make every runner/verdict validator reject intersections.
- **Falsification pass:** `_triage/ORDER098B_MACDDIV_M4_VERDICT.md:13-17` used disjoint MAIN 2023.01–2025.12 and HOLDOUT 2026H1, so that recent verdict is not shown contaminated. The canonical instruction remains unsafe for future work.

### [SEV-2] | process | Pre-commit validates deployment consistency from the working tree, not the staged snapshot

- **Evidence:** `.githooks/pre-commit:23` runs `check_state.ps1 -Strict`; `scripts/check_state.ps1:51-53` reads ordinary filesystem CSV bytes. The staged checker protects exactly five taskboard/archive files at `scripts/check_precommit_staged.ps1:8-16`, excluding deployments, dashboard map, scorecard, index, B1, and template baselines. The hook is installed (`.git/config:8`).
- **Concrete failure scenario (HYPOTHESIS):** stage a broken `DEPLOYMENTS.csv`, restore only the working-tree copy, then commit. `check_state` sees the clean working tree and the staged checker no-ops; the broken inventory lands.
- **Suggested fix:** materialize every relevant staged blob into a temporary snapshot and run all consistency checks against that snapshot.

### [SEV-2] | process | Scorecard/index synchronization is claimed as hook-enforced but is neither checked nor current

- **Evidence:** `AGENTS.md:117-119` requires same-commit synchronization and `CLAUDE.md:71` says “hook-enforced.” `scripts/check_state.ps1:10-22` lists eight checks but none compares the files; repository search finds no other checker for `EA_MASTER_INDEX`. The index has no Boss_15/16/17/18, MacdDiv, SMC, PairSpread, or RSI_MR row. `EA_MASTER_INDEX.csv:8` still records Boss_14 GBPJPY as WATCH from 2026-07-04, while the taskboard records it as a demo-ready leg at `AGENT_TASKBOARD.md:362`.
- **Concrete failure scenario (HYPOTHESIS):** an agent uses the master index to select work and re-tests, rejects, or deploys against a verdict that changed elsewhere.
- **Suggested fix:** generate the index from structured canonical records, or enforce staged, bidirectional row/status/date parity. Do not call the invariant hook-enforced until the hook proves it.
- **Observed check result:** `scripts/check_state.ps1 -Strict` returned CLEAN despite this drift, confirming the gap is outside its present surface.

### [SEV-2] | process | The scorecard exposes two incompatible active verdict engines

- **Evidence:** the canonical vocabulary and structural-death mapping are declared at `EA_SCORECARD_AND_REGISTRY.md:10-27` and `CLAUDE.md:14-23`. Yet `EA_SCORECARD_AND_REGISTRY.md:31-59` says uncapped martingale/grid is only a −25 score penalty, and `EA_SCORECARD_AND_REGISTRY.md:133-141` still maps scores to CORE/REBUILD/DEAD/PARKED, including “CORE → deploy at full risk.” `EA_SCORECARD_AND_REGISTRY.md:335-339` still instructs readers to use those gates/bands.
- **Concrete failure scenario (HYPOTHESIS):** a high-PF uncapped martingale is penalized but still scores CORE and is routed toward full-risk deployment, contradicting the current DEAD-STRUCTURAL tree.
- **Suggested fix:** freeze the old rubric as historical/intake-only; make HOW TO USE state that scoring produces evidence only and can never grant deployment rights outside the CLAUDE verdict tree.

### [SEV-2] | process | Current deployment truth is duplicated and stale inside the canonical entry

- **Evidence:** `portfolio/DEPLOYMENTS.csv` is the declared owner at `PROJECT_STATE.md:35,48-51`. `PROJECT_STATE.md:3` says three ST03 instances were removed, but `PROJECT_STATE.md:247-263` still describes one account and lists ST03 rows as LIVE/WATCH. `scripts/check_state.ps1:46-48` only checks that the pointer string exists; its documented checks do not compare duplicated PROJECT_STATE rows. The read-only strict checker reported 45 rows across seven accounts and CLEAN.
- **Concrete failure scenario (HYPOTHESIS):** a fresh operator follows PROJECT_STATE’s visible live table instead of the linked CSV and monitors or judges removed exposure while missing current accounts.
- **Suggested fix:** remove hand-maintained current deployment tables from prose owners and generate summaries directly from `DEPLOYMENTS.csv`; retain old tables only under explicit historical headings.

### [SEV-2] | code | Persisted risk state is scoped only by magic and equity HWM is not cashflow-neutral

- **Evidence:** `ea_template/core/Persist.mqh:13-29` keys state as `Boss_<magic>_<name>` without account, server, or symbol. `ea_template/core/RiskControl.mqh:97-123,136-166` persists absolute account-equity peaks and computes DD from them; there is no deposit/withdrawal adjustment.
- **Concrete failure scenario (HYPOTHESIS):** switching accounts in the same terminal or reusing a magic inherits another account/symbol’s halt/HWM. A legitimate withdrawal larger than the protect threshold appears as drawdown, closes the EA, and persists a permanent halt.
- **Suggested fix:** scope keys by server+login+symbol+magic+strategy version; make HWM cashflow-neutral from balance deals; test deposit, withdrawal, account switch, restart, and version migration.

### [SEV-3] | process | B1 measurement is incomplete and therefore cannot support its future go/no-go trigger

- **Evidence:** `docs/memory_control/B1_COHORT.md:16-26` defines the first 20 eligible post-anchor terminal orders with no selection, and `B1_COHORT.md:42-52` requires capture at close. `AGENT_TASKBOARD.md:108,118,128,141` marks ORDER-120..123 DONE after the anchor, but `docs/memory_control/B1_DATASET.csv:2-6` contains only five rows and omits all four. The dataset’s ORDER-115 row points to `dc566d77`, while the taskboard closure landed separately in `17528d90` (git history).
- **Concrete failure scenario (HYPOTHESIS):** omitted orders alter incident/rework rates and the MVP-2 decision; an evidence commit that does not contain closure prevents reconstruction.
- **Suggested fix:** derive the eligible close sequence deterministically from git/taskboard history, hook-enforce row completeness, and append missed rows with `NOT_RECORDED` rather than silently skipping them.

### [SEV-3] | process | Agent routing authority conflicts with the July-16 blind-auditor separation

- **Evidence:** `PROJECT_STATE.md:208` says Codex is now blind auditor/verifier only. `AGENTS.md:57,155-167` still authorizes and recommends Codex as a code builder, while `PROJECT_STATE.md:352-353` also assigns heavy builds to Codex.
- **Concrete failure scenario (HYPOTHESIS):** Codex authors critical code and is later treated as the independent review leg, weakening the two-model separation the routing flip was meant to create.
- **Suggested fix:** make AGENTS the single routing authority and distinguish ordinary caged pattern edits from important code that requires Claude-author/Codex-blind-audit.

### [SEV-4] | process | Template and roadmap onboarding documents are materially stale

- **Evidence:** `ea_template/README.md:5,17-18,49-50` says tester-only, Recovery/Hedge stubs, and no demo/live even though V2 contains implemented modules and staged deployments. `ROADMAP.md:29-47` still presents old Phase 0/1 work and “operate 9 EA.” `EDGE_CATALOG.md:224` and `EDGE_CATALOG.md:240` duplicate the HP-denoise heading, with mismatched content under the first.
- **Concrete failure scenario (HYPOTHESIS):** a new agent follows the README or roadmap, skips current safety requirements, or repeats completed work.
- **Suggested fix:** add generated “current phase/current capability” blocks, mark historical plans unambiguously, and lint duplicate headings.

## 3. ARCHITECTURE ASSESSMENT

1. **Strength:** the compile-time entry seam plus shared deep modules matches the owner’s “one chassis, many EAs” vision.
2. **Strength:** centralized execution, symbol+magic scoping, separated signal/risk ATR, and default-off advanced mechanisms are good boundaries.
3. **Strength:** persisted halt/HWM, deployment inventory, staged archive protection, and numerical regression show unusually strong safety intent.
4. **Weakness:** order lifecycle is modeled as synchronous function calls, not confirmed broker transactions; this is the main live-money fragility.
5. **Weakness:** role identity relies on mutable comments and generic counts, so hedge/recovery/strategy ownership is not compositional.
6. **Weakness:** the configuration surface permits unsafe combinations without `OnInit` validation (account mode, magic, spread, SL availability).
7. **Weakness:** safety and strategy cadence are coupled; `_0_BarOpenOnly` can gate protection along with signal logic.
8. **Weakness:** regression tests numeric happy paths but not rejection, partial fill, restart, cashflow, stale binary, or residual-order failure semantics.
9. **Weakness:** process authority is duplicated in prose and CSV without end-to-end generated views or staged enforcement.
10. **Verdict:** the chassis is conceptually sound, but it is not yet a safe generic live-real-money mold until transaction reconciliation and cage integrity are fixed.

## 4. PROCESS-VS-REALITY DRIFT

- “RiskControl first every tick” in `DESIGN_V2.md:209-217` disagrees with the same-bar early return in `LabCore.mqh:166-188`.
- “Regression catches every core change” in `AGENTS.md:80` is not enforced by pre-commit and can run stale installed binaries; Boss_17/18 are absent from baseline.
- MAIN must exclude HOLDOUT (`PROJECT_STATE.md:201`), while `CLAUDE.md:9` overlaps them.
- `EA_MASTER_INDEX` is described as scorecard-synchronized and hook-enforced, but new Boss/candidate rows are missing and no checker exists.
- `PROJECT_STATE.md` declares `DEPLOYMENTS.csv` as owner but retains a stale one-account/nine-EA current table.
- The scorecard declares seven canonical verdicts but still publishes an actionable legacy engine that can issue CORE/full-risk.
- B1 declares an unselected first-20 cohort but omits post-anchor terminal orders.
- README says tester-only/stubs while Recovery/Hedge and multiple demo bundles exist.
- The installed hook path and current inventory/dashboard bidirectional map are real strengths; `check_state -Strict` passed its intended, narrower checks.

## 5. TOP-3 RECOMMENDATIONS

1. **Make risk exits transactionally fail-closed:** move hard-kill before all cadence gates and implement broker-state reconciliation until positions and pendings are proven flat — this removes the clearest path to silent unmanaged real-money exposure.
2. **Turn the template cage into a build-and-failure cage:** compile current source for every Boss, bind reports to binary hashes, add Boss_17/18, and test close failure, missing ATR/SL, hedge roles, pending margin, magic collision, cashflow, and restart — current numeric regression cannot catch the highest-risk defects.
3. **Machine-enforce one process truth from staged bytes:** centralize non-overlapping windows, generate index/deployment summaries, validate scorecard/index/B1 parity, and run all checks against the Git index — this prevents clean-looking commits from carrying contradictory research evidence.

