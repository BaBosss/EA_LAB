# ORDER-138B independent QA re-review — commit `29b31b7`

Review target: final committed state `29b31b768e088d8341b25a268fee5326e7fe79d5`. The reviewed key files are byte-identical to that commit (`git diff 29b31b7 -- <key files>` was empty). This review judges code behavior, not the commit message or the recorded triage claims.

## Overall verdict

**The change set is NOT sound for live rollout yet.** The exact F1, F3, F4, and F8 scenarios are closed, but F7 and F9 are only partially closed. More importantly, the new pair commit-marker protocol is not actually complete-or-none when marker deletion or record re-touch fails (NEW-1, SEV-1), and the supported `RC_PersistHalt=false` mode can bypass already-persisted liquidation intents (NEW-2, SEV-2). The F2 rejection and F6 deferral should also be contested.

## Prior-finding verdicts

1. **F1 — CLOSED (original SEV-1 blocking): widened legacy-consent gate closes the foreign-peak kill path.**

   **File + line:** `ea_template/core/RiskControl.mqh:116-150,155-157,207-211`; attach enforcement at `ea_template/core/LabCore.mqh:116-120`; tests at `ea_template/tests/PersistMigrate_Test.mq5:91-109`.

   **Observed behavior:** Before any migration or legacy cleanup, `RiskControl_InitEx` detects active legacy kill/halt, any legacy `rc_peak_eq`, and `acct_hwm` when the account gate is enabled. Without consent it returns false; `LabCore` converts that to `INIT_FAILED`. Therefore a foreign high `rc_peak_eq` cannot be migrated and used by the first-tick DD calculation.

   **Failure scenario disposition:** Account B with a foreign Account-A `rc_peak_eq` now refuses attachment instead of restoring the foreign peak and liquidating B.

   **Suggested fix:** None for the production path. Complete the missing `acct_hwm` test coverage described under F7.

2. **F3 — CLOSED (original SEV-1 blocking): the exact mid-reconciliation rewrite failure is removed.**

   **File + line:** `ea_template/core/Kangaroo.mqh:350-380,442-454`.

   **Observed behavior:** After one armed pair leg closes and the other remains live, the code no longer calls `Kangaroo_PairPersist`; the original committed two-ticket record remains on disk. It is cleared only after both in-memory slots are broker-confirmed gone.

   **Failure scenario disposition:** In the original A-closed/B-rejected scenario, a failed replacement write can no longer remove the only durable record because no replacement write occurs while B is live.

   **Suggested fix:** The exact F3 path needs no further change, but NEW-1 must be fixed because initial arm/clear/restore still do not form a safe transaction under delete failure.

3. **F4 — CLOSED (original SEV-1 blocking): close-all latches now remain held until checked deletion succeeds.**

   **File + line:** `ea_template/core/Persist.mqh:78-86`; chassis path `ea_template/core/ExitManager.mqh:404-415`; Kangaroo path `ea_template/core/Kangaroo.mqh:150-161`.

   **Observed behavior:** `Persist_DelChecked` reports failure. Both close-basket paths return while leaving their in-memory latch armed if deletion fails; only a successful checked delete followed by flush permits the latch to clear.

   **Failure scenario disposition:** A transient failed delete can no longer release the current process to open a new basket while `*_closeall=1` remains on disk.

   **Suggested fix:** None for the exact F4 path. NEW-2 covers the separate configuration path that can still ignore the retained key.

4. **F7 — PARTIALLY CLOSED (original SEV-2 should fix): peak-only and HALT branches were added, but the requested account-HWM/mixed coverage is still absent.**

   **File + line:** added S8/S9 at `ea_template/tests/PersistMigrate_Test.mq5:91-109`; inadequate HWM scenario at `ea_template/tests/PersistMigrate_Test.mq5:66-73`; production HWM branch at `ea_template/core/RiskControl.mqh:75-87,136-137,207`.

   **Observed behavior:** S8 checks foreign `rc_peak_eq` alone. S9 checks active HALT plus peak and verifies refusal preserves both. However S5 directly calls `Persist_MigrateLegacy("acct_hwm")` while `RC_AcctDDLimitPct` remains its compiled default 0; it never exercises `RiskControl_InitEx`'s `legacyHwm` gate or `RiskControl_AcctGateInit`. There is no mixed kill+halt+peak+HWM preservation case, nor a consented recovery case for the peak/HWM refusal.

   **Concrete failure scenario left untested:** A future edit can remove or reorder the `legacyHwm` gate while S1-S9 continue to pass because no scenario initializes with `RC_AcctDDLimitPct>0` and legacy `acct_hwm` present.

   **Suggested fix:** Run a dedicated test build/set with `RC_AcctDDLimitPct>0`; seed kill, halt, peak, and HWM together; assert false init leaves every legacy value unchanged and creates no scoped keys; then call the consented path and assert all intended migrations/cleanup.

5. **F8 — CLOSED (original SEV-2 should fix): the pre-138 in-flight pair upgrade window is now explicitly gated.**

   **File + line:** `ea_template/PERSIST_MIGRATION_ORDER132.md:89-98`.

   **Observed behavior:** The guide now explains that pre-138 pair legs have no marker, requires checking F3/journal before upgrading Boss_16, and instructs the operator to wait for resolution or a flat basket. The prior unsupported “window is nil” claim is gone.

   **Failure scenario disposition:** An operator following the guide will not swap binaries while unmarked pre-138 pair liquidation is in flight.

   **Suggested fix:** None.

6. **F9 — PARTIALLY CLOSED (original SEV-2 should fix): ticking retries are refreshed, but the reported no-tick expiry scenario remains.**

   **File + line:** chassis re-touch at `ea_template/core/ExitManager.mqh:417-427`; Kangaroo close-all at `ea_template/core/Kangaroo.mqh:163-171`; pair re-touch at `ea_template/core/Kangaroo.mqh:366-380`; admitted limitation at `ea_template/PERSIST_MIGRATION_ORDER132.md:16`.

   **Observed behavior:** While ticks continue and liquidation remains unresolved, the single-key intents are re-set and pair keys are accessed roughly every 60 seconds. But no timer exists. The documentation itself confirms that a zero-tick symbol receives neither retry nor re-touch and that the GV may expire after roughly four weeks.

   **Concrete failure scenario still open:** A suspended symbol remains without ticks for the GV retention period, the terminal restarts before/when trading resumes, and the expired liquidation intent is absent; residual exposure returns to ordinary management. For pair state, the first retry after expiry can also recreate only the marker (NEW-1).

   **Suggested fix:** Drive persistence keep-alive from `OnTimer`, independent of market ticks, and make pair-record refresh validate/rewrite an entire durable generation rather than setting the marker after unchecked reads.

## Rejected/deferred rationale assessment

7. **F2 rejection — CONTESTED (SEV-1 blocking).**

   **File + line:** degraded arm handling at `ea_template/core/ExitManager.mqh:389-403` and `ea_template/core/Kangaroo.mqh:138-149`; non-safety callers at `ea_template/core/ExitManager.mqh:544-558` and `ea_template/core/Kangaroo.mqh:388-408`.

   **Why the rationale is unsound:** The triage says full-basket closes are safety exits, but both helpers also serve profit TP, dynamic-profit, run-trend, single-TP, net-profit, and controlled flatten exits. If the arm write fails, some closes succeed, another close/cancel fails, and the terminal crashes, the residual restarts under ordinary management. The account KillDD cage does not restore the lost exit decision and need not be tripped. The stated safety-versus-profit asymmetry is therefore not implemented at these shared helpers.

   **Suggested fix:** Pass an exit reason/policy into the close helper. Require durable arm before discretionary profit/trend exits. If emergency exits must proceed on persistence failure, give them a separately documented durable fallback or an explicit fail-safe recovery state; do not apply that degraded policy indiscriminately to every full-basket exit.

8. **F5 rejection — operationally reasonable for the current deployment, but not a type-safety proof (no rollout blocker).**

   **File + line:** lossy casts remain at `ea_template/core/Kangaroo.mqh:73-74,91-92`; tests use tiny tickets at `ea_template/tests/PersistIntent_Test.mq5:36-43`.

   **Assessment:** The repository's stated observed ticket scale leaves large practical headroom below `2^53`, and this encoding predates 138, so rejecting it as a 138 regression is reasonable. Nevertheless the code accepts `ulong` without an enforced upper bound, so the format is not lossless by construction.

   **Suggested fix:** At minimum reject/log tickets above the exact-double range and document the deployment assumption; lossless split encoding remains the robust long-term fix.

9. **F6 deferral — CONTESTED (SEV-2 should fix).**

   **File + line:** current success-only scenarios at `ea_template/tests/PersistIntent_Test.mq5:28-76`; production failure-sensitive operations at `ea_template/core/Kangaroo.mqh:58-77,434-449` and `ea_template/core/ExitManager.mqh:389-415`.

   **Why the rationale is no longer sound:** The fix pack contains a concrete untested failure mode (NEW-1) caused by an unchecked marker delete/clear. Current tests seed static complete/torn states but never fail marker deletion, one leg write, checked close-intent deletion, or a write followed by a simulated crash boundary. The claim that no known failure path warrants a seam is disproved by the committed code itself.

   **Suggested fix:** Add a narrow persistence adapter/fault hook around set/delete/flush for tests; it need not alter execution logic. Assert every crash boundary of marker invalidation, both leg writes, marker commit, clear, and close-intent delete. Add execution fault injection only where needed to prove residual-latch behavior.

## NEW findings introduced/exposed by the fix pack

10. **NEW-1 — SEV-1 blocking: the pair marker can certify an incomplete or mixed-generation record.**

   **File + line:** unchecked marker invalidation/clear at `ea_template/core/Kangaroo.mqh:58-77`; permissive restore at `ea_template/core/Kangaroo.mqh:80-103`; ignored clear results at `ea_template/core/Kangaroo.mqh:333-336,354-364,447-450`; marker-only TTL re-touch at `ea_template/core/Kangaroo.mqh:373-380`; unchecked helper at `ea_template/core/Persist.mqh:69-73`.

   **Concrete failure scenario:** A prior committed pair finishes. Clearing `k16_pair_ok` fails, while one or both leg deletes succeed/fail independently; the clear path nevertheless returns true and releases the in-memory intent. On a later pair arm, marker deletion again fails, ticket A is overwritten, and the terminal crashes before ticket B is overwritten. The old marker remains and now certifies a mixed generation (`new A + old B`) or a one-leg record. `Kangaroo_Init` accepts the marker when **either** restored leg is nonzero (`a != 0 || b != 0`) and proceeds to close whatever matching live ticket survives. This recreates the exact half-pair liquidation class the marker was intended to eliminate. Separately, after TTL expiry the retry code reads missing legs and then re-sets only `k16_pair_ok`, creating a marker-only record.

   **Suggested fix:** Use checked marker invalidation and refuse to write/release until absence is verified and flushed. Restore only when marker exists **and both leg keys exist and both tickets are nonzero**. Make clear checked and keep an in-memory cleanup latch that blocks new pairs until all three keys are confirmed absent. Prefer double-buffered records with a generation pointer committed last, so a failed delete is harmless. Add deterministic delete/write/crash-boundary tests.

11. **NEW-2 — SEV-2 should fix: `RC_PersistHalt=false` silently bypasses existing liquidation intents and can later revive them against another basket.**

   **File + line:** supported/manual-unhalt setting at `ea_template/core/Inputs.mqh:424-432` and `ea_template/core/RiskControl.mqh:194-197`; conditional restore at `ea_template/core/ExitManager.mqh:375-386` and `ea_template/core/Kangaroo.mqh:80-111`; conditional deletion at `ea_template/core/ExitManager.mqh:397-413` and `ea_template/core/Kangaroo.mqh:143-159`.

   **Concrete failure scenario:** `exit_closeall=1`, `k16_closeall=1`, or a committed pair record survives a crash mid-liquidation. The operator uses the documented manual-unhalt route `RC_PersistHalt=false` and reattaches. Both init functions ignore the existing scoped intents; residual exposure returns to ordinary management and the EA may open/add a later basket. If persistence is re-enabled, the old scoped intent is restored and can close the then-current basket, or halt state can mask it until the next unhalt.

   **Suggested fix:** Do not use the halt-persistence toggle as permission to ignore already-existing exit intents. On init, always detect scoped liquidation keys. Either resume them regardless of `RC_PersistHalt`, or fail the attach with an explicit operator cleanup/adoption procedure. If persistence for new exits is intentionally configurable, give it a separate input and make existing-key handling fail closed.

## DryRun, tester, and compiled-default review

- `DryRun` continues to avoid GV writes/deletes in the changed close paths (`ea_template/core/ExitManager.mqh:382,397,409,426`; `ea_template/core/Kangaroo.mqh:60,86,143,155,170,375`). No new path was found that lets DryRun mutate these persistence keys or send real closes (`ea_template/core/Execution.mqh:344-358,363-370`).
- Both destructive test EAs refuse non-tester attachment before `GlobalVariablesDeleteAll("Boss")` (`ea_template/tests/PersistMigrate_Test.mq5:18-28`; `ea_template/tests/PersistIntent_Test.mq5:17-25`). The test runner dynamically discovers `tests/*.mq5` and rejects compile/no-log/no-verdict/fail outcomes (`ea_template/tests/run_tests.ps1:38-76`).
- For a fresh tester sandbox and compiled defaults, the new input is inert (`RC_AdoptLegacyHalt=false` at `ea_template/core/Inputs.mqh:445`), and the new restore paths are inert without seeded GVs (`ea_template/core/ExitManager.mqh:381-386`; `ea_template/core/Kangaroo.mqh:82-111`). No static trade-decision neutrality defect was found for Boss_11..18 in that clean-state path. This does not validate the persistence failure paths discussed above.

## Required verdict summary

- F1: **CLOSED**
- F3: **CLOSED**
- F4: **CLOSED**
- F7: **PARTIALLY CLOSED**
- F8: **CLOSED**
- F9: **PARTIALLY CLOSED**
- NEW findings: **2 total — 1× SEV-1, 1× SEV-2**

