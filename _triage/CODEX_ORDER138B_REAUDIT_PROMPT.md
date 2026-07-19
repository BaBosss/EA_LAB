# QA re-review request — commit 29b31b7 (Boss V2 persistence/exit hardening, final state)

A previous QA review (`D:\EA_LAB\_triage\CODEX_ORDER138_AUDIT.md`) reported 9 findings
against a working-tree version of these changes. Fixes for findings F1, F3, F4, F7, F8,
F9 were then applied, and the complete change set was committed as `29b31b7`.

Task: independently re-review the FINAL committed state.

1. `git show 29b31b7` in D:\EA_LAB for the full diff; read surrounding code as needed.
2. For each of F1, F3, F4, F7, F8, F9 from the previous report: verify whether the fix
   in the committed code actually closes the finding's failure scenario. Judge from the
   code, not from comments or commit-message claims.
3. F2 and F5 were rejected and F6 deferred, with rationale recorded in
   `D:\EA_LAB\_triage\CODEX_ORDER138_AUDIT_TRIAGE.md` — assess whether each
   rejection/deferral rationale is sound or should be contested.
4. Most important: hunt for NEW defects introduced by the fix pack itself — the widened
   consent gate in `RiskControl_InitEx`, the no-mid-flight-rewrite pair protocol in
   `Kangaroo.mqh`, the checked-delete latch-hold in both CloseBasket paths, the TTL
   re-touch lines, and the new/changed test scenarios. Consider restart/crash windows,
   account-switch scenarios, DryRun, tester-sandbox behavior, and behavior-neutrality
   for Boss_11..18 compiled defaults.

Report format: numbered findings with severity (SEV-1 blocking / SEV-2 should fix /
SEV-3 minor), exact file+line, concrete failure scenario, suggested fix. For each prior
finding give an explicit verdict: CLOSED / PARTIALLY CLOSED / NOT CLOSED. State clearly
if the change set is sound. Write the full report to
`D:\EA_LAB\_triage\CODEX_ORDER138B_REAUDIT.md`.
