# ORDER-132: Transactional Exits + Persist Scoping — Implementation Plan

> **For agentic workers:** Money/risk code — Opus-seat authors inline per AGENTS routing (no subagent implementation). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the four deferred Codex ORDER-129 audit findings (F2-full/F3/F4/F6): make pair-close, partial-close, and the mode-93 pending ladder transactional (broker-confirmed, retried), and scope persisted GlobalVariables by server+login+symbol+magic with a single `rc_state` enum + legacy-key migration.

**Architecture:** All changes live in `ea_template/core/` (shared chassis). Persist gets a scoped key format + checked writes + one-shot legacy migration. RiskControl replaces the two-flag halt/kill persistence with one `rc_state` enum. Execution/ExitManager/Kangaroo/Stack propagate broker close/place results instead of assuming success; unfinished work is retried per-tick from module state.

**Tech Stack:** MQL5 (MetaEditor64 `D:\Meta 5`), tester harness `ea_template/tests/run_tests.ps1`, cage `scripts/tpl_regression.ps1`.

## Global Constraints

- **No input renames** (breaks .set files). New behavior via existing inputs only — no new inputs needed.
- **Neutrality:** cage `tpl_regression.ps1` must be CLEAN (8/8); tester closes/placements always succeed, so all retry paths are dormant there. Persist key change is invisible in tester (GV sandbox per pass).
- **Boss_18 caveat:** known FP-layout sensitivity at its kill boundary (ORDER-131). If Boss_18 alone drifts a few trades at eqDD≈25%, isolate before judging — do NOT auto-re-pin.
- **DryRun never writes/deletes terminal GVs** (ORDER-129b F5 doctrine) — migration included.
- **ห้าม touch live GVs without migration doc** — doc is Task 8, ships in the same commit.
- Compile 0/0 (zero-warning enforced) ×9 wrappers + all tests.
- Mode 93 has no cage cell → dedicated A/B probe (Task 0/6) is the neutrality evidence for Stack.

---

### Task 0: Pre-change mode-93 probe (baseline numbers on HEAD)

**Files:**
- Create: `_mt5_auto/ab_sets/order132_93probe.set` (Boss_11 overrides: `StackMode=93`, `_9_PendingMode=3`, `_9_PendingLegs=3`)

- [ ] Verify tester free (`tasklist` metatester64/terminal64 empty, newest `_mt5_auto/reports` is ours)
- [ ] `ea_template/deploy.ps1 -Compile` on HEAD, then `scripts/mt5_run.ps1 -Expert EALabTpl\Boss_11_GridTrend -Symbol XAUUSD -Period H1 -FromDate 2024.01.01 -ToDate 2024.07.01 -Model 1 -ReportName O132_93probe_pre -SetFile _mt5_auto/ab_sets/order132_93probe.set`
- [ ] Record net/pf/trades/eqdd from `O132_93probe_pre.htm` (this is the A side)

### Task 1: Persist.mqh — scoped keys, checked writes, flush, legacy migration (F4)

**Files:** Modify `ea_template/core/Persist.mqh`

**Produces:** `Persist_Key(name)` → `"Boss2_<srvhash4>_<login>_<symbol>_<magic>_<name>"`; `bool Persist_Set(name,value)`; `void Persist_Flush()`; `string Persist_LegacyKey(name)`; `bool Persist_MigrateLegacy(name)` (copy legacy→scoped once, delete legacy, never under DryRun); legacy getters `Persist_HasLegacy/Persist_GetLegacy/Persist_DelLegacy`.

Key points (full code in implementation): no caching of scope (account switch reloads without resetting globals — cached scope would recreate the F4 bug); djb2 hash of `ACCOUNT_SERVER` folded to 4 hex chars keeps names < 63 chars; `Persist_Set` logs `GetLastError()` and returns false on failure.

- [ ] Implement; keep `Persist_Get/Has/Del` signatures unchanged (callers unaffected)

### Task 2: RiskControl.mqh — single `rc_state` enum + migration wiring + checked/durable writes (F6)

**Files:** Modify `ea_template/core/RiskControl.mqh`, `ea_template/core/Inputs.mqh` (un-halt doc comment only)

**Produces:** persisted names become `rc_state` (0 RUNNING / 1 KILL_PENDING / 2 HALTED), `rc_peak_eq`, `acct_hwm`. `rc_halted`/`rc_kill_pending` names retired (legacy-read only).

- [ ] `RiskControl_Init`: migrate `rc_peak_eq` scoped; read `rc_state` (fallback: derive from legacy flags, write scoped, delete legacy, flush — all `!DryRun`-gated); apply to `g_rc_kill_pending`/`g_rc_halted`; HALT log prints `Persist_Key("rc_state")` as the manual un-halt target
- [ ] `RiskControl_AcctGateInit`: `Persist_MigrateLegacy("acct_hwm")` before the existing `Persist_Has` read
- [ ] Kill trigger (`RiskControl_CheckDD`): `Persist_Set("rc_state", KILL_PENDING)` checked + `Persist_Flush()` BEFORE first `KillReconcile` (crash mid-close must resume)
- [ ] `RiskControl_KillReconcile` success: `Persist_Set("rc_state", HALTED)` + `rc_peak_eq`, both checked, then flush; log hard ERROR on any failed write
- [ ] `Inputs.mqh` RC_PersistHalt comment: un-halt = delete scoped `rc_state` GV (name printed in HALT log)

### Task 3: Partial-close confirm (F3b)

**Files:** Modify `ea_template/core/Execution.mqh`, `ea_template/core/ExitManager.mqh`

- [ ] `Exec_ClosePartialFraction` → `bool`: skipped legs (unrepresentable volume) don't fail it; an attempted `PositionClosePartial` that returns false logs retcode and fails it. DryRun → true.
- [ ] `Exit_ManagePartialClose`: `g_exit_partialN_done = true` only when the fraction call returns true; failed milestone stays armed and retries while the profit predicate holds (retry may slightly over-close mixed-success baskets — risk-reducing direction, commented)

### Task 4: Kangaroo pair-close residual retry (F3a)

**Files:** Modify `ea_template/core/Kangaroo.mqh`

- [ ] New state `ulong g_k16_pair_residual` (reset in `Kangaroo_Init`; cleared when basket flat)
- [ ] After the two `Exec_CloseTicket` calls: broker-state re-scan via `PositionSelectByTicket`; exactly-one-gone ⇒ arm residual + log ASYMMETRIC
- [ ] Top of `Kangaroo_ManageExits` (have>0): if residual armed — retry close, confirm by re-scan, clear when gone; skip NEW pair-closes while armed
- [ ] Restart note (comment + migration doc): residual state is in-memory; after restart the leg rejoins normal grid management under cage/emergency-DD

### Task 5: Stack mode-93 transactional ladder + margin budget (F2-full + SEV-1 #5)

**Files:** Modify `ea_template/core/Stack.mqh`, `ea_template/core/Execution.mqh` (add `Exec_PendingMarginProjection`)

- [ ] Per-basket state: `g_stack_ladder_own`, `g_stack_ladder_legs`, `g_stack_dir`, `g_stack_leg0_price/lot` (snapshot at arm — retries must not re-base on later fills), `bool g_stack_leg_ok[64]`, `ulong g_stack_leg_ticket[64]` (from `ResultOrder()`, tracking/log)
- [ ] Restart guard unchanged semantics: `!own && (filled!=1 || pending>0)` ⇒ latch (broker already carries a ladder this session didn't place)
- [ ] Placement loop retries only `!leg_ok[k]` legs each tick; `g_stack_ladder_placed` latches only when EVERY leg confirmed (replaces 129b any-placed patch)
- [ ] `Stack_MarginBudgetOK(dir, lot, price)`: `OrderCalcMargin` for the leg + `ACCOUNT_MARGIN` + `Exec_PendingMarginProjection()` (sum of own resting pendings' fill margin) vs `RC_MaxDepositLoadPct()` of balance; fail-closed (blocked leg waits, throttled log)

### Task 6: Tests + compile + review

**Files:** Modify `ea_template/tests/Persist_Test.mq5`; Create `ea_template/tests/PersistMigrate_Test.mq5`

- [ ] Persist_Test: add asserts — key contains login+symbol, `Persist_Set` returns true
- [ ] PersistMigrate_Test (4 scenarios): legacy HALT+peak → halted + `rc_state`=2 + legacy consumed + peak migrated · legacy kill_pending → pending + `rc_state`=1 · clean slate → running, no `rc_state` written · scoped `rc_state` wins over stale legacy. Uses `GlobalVariablesDeleteAll("Boss")` between scenarios
- [ ] Compile ×9 wrappers 0 err/0 warn (deploy.ps1 -Compile) + `run_tests.ps1` ALL PASS
- [ ] `mql-code-reviewer` skill pass on the diff
- [ ] Post-change probe: re-run Task 0 command as `O132_93probe_post` → numbers identical to pre (mode-93 neutrality evidence)

### Task 7: Cage

- [ ] `scripts/tpl_regression.ps1` → REGRESSION CLEAN 8/8 (Boss_18 drift ⇒ stop and isolate per Global Constraints)

### Task 8: Migration doc + bookkeeping + commit

**Files:** Create `ea_template/PERSIST_MIGRATION_ORDER132.md`; Modify `AGENT_TASKBOARD.md`, `docs/memory_control/B1_DATASET.csv`

- [ ] Migration doc: key format old→new, auto-migration semantics (once, deletes legacy, DryRun inert), operator pre-upgrade GV snapshot step (rollback path), demo verification checklist (attach on demo, check journal `[PERSIST] migrated` lines, Tools→Global Variables shows `Boss2_*`), account-switch warning (clear GVs before attaching a terminal that switched accounts mid-kill)
- [ ] Commit (path-limited: core/, tests/, sets probe, docs) — taskboard PROGRESS + B1 row in the REVIEWED commit later
- [ ] Codex blind audit (neutral QA prompt, no anchor) → triage → fix/defer/reject → final status

## Self-Review (done at write time)

- Spec coverage: F2-full→Task 5 · F3 pair→Task 4 · F3 partial→Task 3 · F4→Tasks 1,8 · F6→Task 2 · SEV-1 #5 margin→Task 5 · acceptance compile/cage/migration-test/Codex → Tasks 6,7,8. Registry-of-attachments from Codex F4 suggestion = YAGNI, not in taskboard spec — skipped deliberately.
- Type consistency: `Persist_Set` bool return — MQL5 discarded returns compile clean; all state names match across tasks.
