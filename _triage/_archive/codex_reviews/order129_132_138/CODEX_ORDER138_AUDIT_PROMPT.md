# QA review request — Boss V2 template persistence/exit changes (2026-07-19)

Perform an independent static QA review of the most recent uncommitted changes in the
working tree under `D:\EA_LAB\ea_template\` (use `git diff` against HEAD to see them).

Files changed:
- `ea_template/core/Inputs.mqh`
- `ea_template/core/RiskControl.mqh`
- `ea_template/core/LabCore.mqh`
- `ea_template/core/Kangaroo.mqh`
- `ea_template/core/ExitManager.mqh`
- `ea_template/tests/PersistMigrate_Test.mq5`
- `ea_template/tests/PersistIntent_Test.mq5` (new)
- `ea_template/PERSIST_MIGRATION_ORDER132.md`

Scope of review — examine the diff plus enough surrounding code to judge it in context:

1. Correctness of the state machines and persistence protocols touched (initialization,
   restore, arming, clearing, failure paths, restart/crash windows, account-switch
   scenarios, tester vs live vs DryRun behavior).
2. Any way the changes could alter default backtest behavior for Boss_11..18 with
   compiled defaults (behavior-neutrality is a hard requirement).
3. Any new failure mode introduced by the changes themselves (order of writes, partial
   failures, stale state, log truthfulness, edge cases in MQL5 semantics).
4. The test coverage: do the two test files actually assert the behaviors that matter?
   Any scenario that can slip through?
5. The operator documentation: is `PERSIST_MIGRATION_ORDER132.md` accurate and complete
   against the code as now written?

Report findings as a numbered list, each with: severity (SEV-1 blocking / SEV-2 should
fix / SEV-3 minor), the exact file+line, the concrete failure scenario, and a suggested
fix. If an area is sound, say so explicitly. Do not assume intent from comments alone —
verify against the code.

Write the full report to `D:\EA_LAB\_triage\CODEX_ORDER138_AUDIT.md`.
