# TDD RED evidence
Observed before implementation on 2026-08-25 Asia/Bangkok.
Command: tools/traycer_ea_lab_pilot/tests/run_tests.ps1
Observed failure: Import-Module could not load tools/traycer_ea_lab_pilot/TraycerPilot.psm1 because the module did not yet exist.
This was the genuine pre-implementation RED condition; implementation followed only after this failure was observed.

## Bounded repair RED — runtime evidence minimization
Observed before the repair on 2026-08-25 Asia/Bangkok.
Check: reject noisy host internals from runtime evidence.
Observed failure: output contained `hostId`, `attemptId`, and `bootstrapLogTail`.
Repair: runtime probe now emits only the bounded fields needed for acceptance and auth-state diagnosis.
