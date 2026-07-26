# ORDER-138 independent static QA audit

Review baseline: `HEAD` = `851b772d22f0932bb34d8e6752c6f6f700a78479`; reviewed the tracked working-tree diff under `ea_template/` plus the untracked `ea_template/tests/PersistIntent_Test.mq5`.

## Findings

1. **SEV-1 blocking — identity-less `rc_peak_eq` can still liquidate the wrong account.**

   **File + line:** `ea_template/core/RiskControl.mqh:145,187-192,287-311`; the same unsafe classification is documented at `ea_template/PERSIST_MIGRATION_ORDER132.md:30-39`.

   **Concrete failure scenario:** The new consent gate checks only active legacy `rc_kill_pending` and `rc_halted`. Account A can leave `Boss_<magic>_rc_peak_eq=100000`, then the terminal can switch to account B with equity 10000 and reuse the same magic without either active flag. `RiskControl_InitEx(false)` automatically migrates the identity-less peak, restores 100000 as B's peak, and the first `RiskControl_CheckDD()` calculates roughly 90% DD and calls `Exec_CloseAll()` against B's matching symbol+magic. `rc_peak_eq` is therefore not benign. A foreign `acct_hwm` can likewise false-trip the account gate, although that path blocks entries rather than liquidating positions.

   **Suggested fix:** Put `rc_peak_eq`—and preferably every account-valued legacy risk key, including `acct_hwm`—behind the same explicit same-account adoption gate. With no consent, fail closed without migrating or delete/ignore only through a separately explicit contamination workflow. Update the documentation and add a test with a legacy peak materially above current equity.

2. **SEV-1 blocking — full-basket liquidation starts even when the restart intent was not persisted.**

   **File + line:** `ea_template/core/ExitManager.mqh:389-404`; `ea_template/core/Kangaroo.mqh:138-150`.

   **Concrete failure scenario:** `Persist_Set("exit_closeall", 1.0)` or `Persist_Set("k16_closeall", 1.0)` fails, but the code immediately calls `Exec_CloseAll()` anyway. If some closes succeed, another position or pending cancellation fails, and the terminal then crashes, no durable intent exists. On restart the residual exposure returns to ordinary management because the original predicate need not fire again. This is the restart window ORDER-138 #3 claims to close.

   **Suggested fix:** Require a verified durable arm before the first transactional close, or provide a second durable fallback. If safety policy intentionally closes despite persistence failure, define separate behavior for safety/emergency exits versus discretionary profit/trend exits and document that degraded mode; the current code cannot guarantee restart resumption after the logged failure.

3. **SEV-1 blocking — pair reconciliation can destroy the last durable intent, and both callers ignore the failure.**

   **File + line:** `ea_template/core/Kangaroo.mqh:58-77,349-365,424-434`.

   **Concrete failure scenario:** A committed `a+b+marker` pair exists. Ticket A closes, ticket B is rejected, and the reconciliation call now has `a=0,b=<live>`. `Kangaroo_PairPersist()` first deletes the marker, then a leg write/delete fails and returns false. The calls at lines 353 and 429 discard that return. A crash before the next tick leaves no valid marker; `Kangaroo_Init()` discards the remaining leg record, and B returns to ordinary grid management. The original complete committed record would have been safe to retain because restore revalidates the already-closed ticket.

   **Suggested fix:** Keep the last valid committed two-ticket record until both tickets are broker-confirmed gone, then perform a checked clear. Alternatively use double-buffered generations so a replacement record becomes current only after it is fully durable. Never ignore a failed persistence update while a live residual remains.

4. **SEV-1 blocking — unchecked intent deletion can later liquidate an unrelated new basket.**

   **File + line:** `ea_template/core/ExitManager.mqh:404-412`; `ea_template/core/Kangaroo.mqh:150-158`; unchecked helper `ea_template/core/Persist.mqh:69-73`.

   **Concrete failure scenario:** Broker-flat proof succeeds, the code clears the in-memory latch, but `GlobalVariableDel()` fails. `Persist_Del()` discards the boolean result, so the persisted value remains `1`. The EA can open a later basket. After a restart, the stale `exit_closeall` or `k16_closeall` is restored and closes that unrelated basket.

   **Suggested fix:** Make `Persist_Del()` return and log a checked result. Do not release the in-memory latch or permit new entries until key absence is verified and flushed; retry the durable clear on subsequent ticks. A checked write of state `0` followed by read-back is another workable protocol.

5. **SEV-2 should fix — pair tickets are not losslessly serialised.**

   **File + line:** `ea_template/core/Kangaroo.mqh:73-74,91-92`; inadequate round-trip values at `ea_template/tests/PersistIntent_Test.mq5:36-43`.

   **Concrete failure scenario:** MQL5 terminal GlobalVariable values are `double`, while position tickets are `ulong`. Integer tickets above `2^53` cannot be represented exactly as `double`. A persisted ticket can restore as a neighbouring value, fail `PositionSelectByTicket()`, and be dropped without closing the intended leg. The test values `111` and `222` cannot reveal this.

   **Suggested fix:** Encode each ticket losslessly, for example as two 32-bit halves in separate GVs, and test round trips around and above `9007199254740992` as well as the maximum supported ticket range.

6. **SEV-2 should fix — `PersistIntent_Test` does not exercise the failure paths the change is meant to harden.**

   **File + line:** `ea_template/tests/PersistIntent_Test.mq5:28-69`.

   **Concrete failure scenario:** The test seeds static keys on an already-flat account. It does not inject arm-write failure, marker invalidation failure, progress-write failure after one pair leg closes, partial `Exec_CloseAll()` failure with a live position or pending order, delete failure after flat proof, or a restart with residual broker state. A regression that closes first and persists afterward—or releases memory while a stale key survives—would still pass all six scenarios.

   **Suggested fix:** Add deterministic execution and persistence seams/fault injection. Assert operation order, retention of the last valid pair record, key retention while residual positions or pendings remain, restart restoration, retry, and checked cleanup for both chassis and K16 paths.

7. **SEV-2 should fix — `PersistMigrate_Test` does not cover the other consent branch or risk-bearing legacy values.**

   **File + line:** `ea_template/tests/PersistMigrate_Test.mq5:74-92`.

   **Concrete failure scenario:** The no-consent test covers only `rc_kill_pending`; it never tests active `rc_halted`. It also never combines an active irreversible key with `rc_peak_eq`/`acct_hwm` to prove the promised “nothing migrated or deleted” atomicity, and it does not test the no-active-flag/high-legacy-peak case from finding 1. These omissions allow both a branch regression and the cross-account false-kill path to pass.

   **Suggested fix:** Add no-consent HALT, mixed halt/kill plus peak/HWM, and foreign high-peak scenarios. Assert the false init result, clean in-memory flags, byte-for-byte preservation of all legacy keys, absence of scoped keys, and the subsequent consented recovery path.

8. **SEV-2 should fix — the upgrade guide understates the pre-138 in-flight pair risk.**

   **File + line:** `ea_template/PERSIST_MIGRATION_ORDER132.md:85-92`.

   **Concrete failure scenario:** The guide says the practical window for a pre-138 `k16_pair_a/b` intent is “nil.” An upgrade or recompile can occur while a broker rejection has left a pair liquidation in flight. Post-138 init deliberately discards those unmarked keys, returning the residual leg to normal management—the failure the persistence work is intended to prevent.

   **Suggested fix:** Add a pre-upgrade F3/journal check for `k16_pair_a/b` and require postponing deployment until the intent is absent or the basket is flat. Alternatively document and test an explicit one-time adoption procedure. Remove the unsupported “window is nil” claim.

9. **SEV-2 should fix — the documentation overstates TTL keep-alive coverage for the new intent keys.**

   **File + line:** `ea_template/PERSIST_MIGRATION_ORDER132.md:14-16`; actual refresh set at `ea_template/core/RiskControl.mqh:266-284`.

   **Concrete failure scenario:** The table presents daily TTL keep-alive as a property of post-132 persistence, but `RiskControl_PersistRefresh()` touches only `rc_state`, `rc_peak_eq`, and `acct_hwm`. It never touches `exit_closeall`, `k16_closeall`, or the pair-intent keys. An unresolved liquidation on a suspended/no-tick instrument can outlive MT5's roughly four-week GV retention and then lose its restart intent.

   **Suggested fix:** Refresh every armed intent key, preferably from a timer so a no-tick symbol is covered, and test it; otherwise narrow the documentation and explicitly describe the expiry limitation.

## Areas found sound

- In a fresh tester pass with compiled defaults, no static trade-decision neutrality defect was found for Boss_11..18. `RC_AdoptLegacyHalt=false` is additive, restore paths are inert without seeded GVs, and the successful persistence paths preserve the pre-change close decisions. The existing 8/8 numeric regression remains the empirical neutrality proof.
- The active legacy `rc_kill_pending`/`rc_halted` no-consent path itself fails before migration or deletion, and the consented path collapses those flags into scoped `rc_state` as documented.
- Scoped keys are recomputed from server, login, symbol, and magic rather than cached, so the new `Boss2_*` keys themselves do not cross account switches.
- On successful persistence operations, full-close intents are armed before the first close, restored before ordinary basket management/adds, and cleared only after `Exec_CloseAll()` proves both own positions and own pending orders are gone.
- Restored pair tickets are revalidated against current symbol and magic before any close attempt.
- DryRun avoids terminal-GV writes/deletes. Both destructive test EAs check `MQL_TESTER` before `GlobalVariablesDeleteAll("Boss")`, and `run_tests.ps1` dynamically discovers the new test and treats its final `[FAIL]` verdict as failure.
- The operator guide correctly describes the scoped key format, server hash, `rc_state` enum, new key names, default consent input, and one-time consent workflow, apart from findings 1, 8, and 9.

## Finding count

- SEV-1 blocking: 4
- SEV-2 should fix: 5
- SEV-3 minor: 0
- Total: 9
