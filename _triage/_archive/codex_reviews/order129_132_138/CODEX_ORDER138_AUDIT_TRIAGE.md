# ORDER-138 — Codex blind-audit triage (Opus judge, 2026-07-19)

Audit: `CODEX_ORDER138_AUDIT.md` (9 findings: 4 SEV-1 / 5 SEV-2). Every finding verified
against code before judging. Fix pack = **138b** (same working set, re-verified full loop).

## ✅ FIXED (138b) — 4 findings

| # | Finding | Fix |
|---|---|---|
| F1 SEV-1 | `rc_peak_eq` not benign — foreign higher-equity legacy peak migrates in → KillDD liquidates the current account on tick 1 (cross-account kill via a second door; my spec's "benign keys" classification was wrong, Codex caught it) | Consent gate widened to **every legacy key the init would read**: active kill/halt + `rc_peak_eq` (any value) + `acct_hwm` (when acct gate on). `RiskControl.mqh` gate rewritten; `Inputs.mqh` + migration doc corrected; tests S8 (foreign peak) + S9 (halt branch, mixed-key preservation) added |
| F3 SEV-1 | Mid-reconcile `Kangaroo_PairPersist()` rewrite drops the marker first — a failed leg write destroys the only durable copy of the pair intent; both callers ignored the return | **No mid-flight rewrite**: the committed record stays on disk untouched while any leg is live (restore revalidates tickets, so a closed leg inside the old record is harmless); checked clear only when both legs are broker-confirmed gone |
| F4 SEV-1 | `Persist_Del` unchecked — a failed delete leaves `*_closeall=1`; restart later liquidates an unrelated future basket | New `Persist_DelChecked()`; both CloseBasket paths keep the latch armed + own the tick until the delete is confirmed (retry every tick; blocks new entries meanwhile = under-exposure direction) |
| F9 SEV-2 | TTL keep-alive never touches intent keys — unresolved liquidation on a quiet symbol could expire out of the GVs (~4 weeks) | Intent keys re-touched every ~60s while the liquidation retries (`exit_closeall` / `k16_closeall` / pair record). No-tick limitation documented (no ticks = no retries either) |

## ✅ FIXED via F7 (test gaps) — partial F6

- S9: active `rc_halted` no-consent branch + mixed-key "nothing migrated or deleted" atomicity.
- S8: foreign-peak fail-closed.

## ❌ REJECTED — 2 findings

- **F2 SEV-1 (closeall proceeds when arm persist fails):** deliberate degraded mode, now
  documented explicitly. Full-basket closes are SAFETY exits (money-stop / emergency-DD /
  kill) — refusing to flatten a losing basket because a GlobalVariable write failed holds
  exposure hostage to persistence. Asymmetry with #2 pair-close (which DOES abort) is
  intentional: pair-close is profit-taking, aborting costs opportunity not safety.
  Degraded mode = loud log + loss of restart-resumption only; the cage (KillDD) remains
  supreme over any residual.
- **F5 SEV-2 (ticket >2^53 double precision):** real broker tickets are ~1e9-1e10;
  2^53≈9e15 — ~6 orders of magnitude of headroom. Same encoding pre-dates 138 (132b
  `k16_pair_a/b`), not a regression. No machinery without a plausible failure mode
  (132b P3/R1-full precedent).

## ⏭ DEFERRED — F6 (fault-injection seams)

Deterministic persistence/execution fault injection in the money path = added complexity
inside the code being protected, with no known real failure mode it would catch beyond
what F1/F3/F4 fixes + S1-S9/PersistIntent scenarios already assert. Revisit if a live
incident ever implicates an untested failure path.

## F8 (doc understated pre-138 pair window) — ✅ FIXED

Migration doc now requires a pre-upgrade F3/journal check for an in-flight
`k16_pair_a/b` intent on Boss_16 instances; "window is nil" claim removed.

## Evidence (138 + 138b full loop)

- compile 0/0 ×9 wrappers + tests (zero-warning)
- unit tests 7/7 PASS — `PersistMigrate_Test` 9 scenarios · `PersistIntent_Test` (new) 6 scenarios
- regression cage 8/8 CLEAN (Boss_18 6020 trades exact) — post-138b run = final proof

---

# 138c — Codex RE-audit triage (commit `29b31b7` reviewed → `CODEX_ORDER138B_REAUDIT.md`)

Re-audit verdicts: F1/F3/F4/F8 **CLOSED** · F7/F9 partial · 2 NEW findings · F2/F6 contested.

## ✅ FIXED (138c)

| # | Finding | Fix |
|---|---|---|
| NEW-1 SEV-1 | Marker could certify an incomplete/mixed-generation pair record: restore accepted `a!=0 \|\| b!=0`; arm/clear used unchecked marker deletes → stale marker + crash mid-arm = half-pair liquidation (the exact class the marker exists to kill) | Restore requires marker **AND both legs nonzero** (armed pair always has two tickets; anything less = wiped on sight, incl. marker-only post-TTL shape). Arm refuses to write legs under a live old marker (`Persist_DelChecked` first, fail = abort liquidation). Clear deletes marker checked-first and touches legs only after it is gone — a stuck marker leaves the complete old record intact, which restores harmlessly via ticket revalidation. Tests S7/S8 added |
| NEW-2 SEV-2 | `RC_PersistHalt=false` (documented manual-unhalt route) bypassed existing persisted intents → residual returns to ordinary management, or stale intent later fires on a different basket | Existing-key handling un-gated from `RC_PersistHalt` everywhere (restore in `ExitManager_Init`/`Kangaroo_Init`, delete-after-proof in both CloseBasket paths, pair-record clear). Flag now gates only persistence of NEW intents. Only DryRun skips real intent handling |
| F2 (contested → accepted) | My safety-exit rationale didn't hold at the shared helpers — `Exit_CloseBasket`/`Kangaroo_CloseBasket` also serve profit TP / dyn target / run-trend / single-TP | Policy split via `safety` param: money-stop, emergency-DD, flatten, armed-intent resume = safety (close degraded on failed arm); TP/dyn/trend exits = discretionary (abort on non-durable arm, predicate re-fires). Tester-neutral: arm writes always succeed in the sandbox |
| F7 (partial → closed) | `legacyHwm` gate branch never exercised (needs `RC_AcctDDLimitPct>0`) | `PersistMigrate_Test.set` (RC_AcctDDLimitPct=5) + S10 (hwm-alone fail-closed + consented recovery) + S9 widened to halt+peak+hwm preservation |
| F6 (contested → partial accept) | NEW-1 was indeed an untested failure mode | NEW-1's certification rule is now covered by static-seed scenarios S7/S8 (no fault-injection seam needed). Full persistence fault-injection framework stays deferred — same 132b rationale, revisit on any live incident |

## ⏭ STILL DEFERRED / REJECTED (unchanged)

- **F9 remainder (OnTimer keep-alive for no-tick symbols):** the residual window = intent unresolved AND zero ticks for ~4 weeks AND restart after expiry — retries need ticks anyway, so the intent is only consumed when trading resumes. Documented limitation; adding a timer surface to the money path is not worth the window. Revisit if a Boss ever trades a symbol with scheduled month-long halts.
- **F5 (ticket >2^53):** re-audit itself concedes "no rollout blocker". Unchanged.
