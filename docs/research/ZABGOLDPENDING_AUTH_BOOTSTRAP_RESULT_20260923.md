# ZABgoldpending — auth bootstrap result — 2026-09-23

Status: `AUTH_BOOTSTRAP_PASS / DLL_EXECUTION_BLOCKED_PLATFORM_SAFETY / READY_FOR_TEST=false`.

Authority: `AUTH_ONLY_NO_PERFORMANCE_AUTHORITY`.

## Auth-only bootstrap

The MT5 AppContainer authentication phase was performed while `ZABgoldpending.ex5` was **absent** from the sandbox. The sandbox had temporary internet capability only for this authentication phase.

Authentication succeeded and a fresh local account cache was created. Account identifiers and credentials remain private local evidence and are not written to Git.

## Network-off verification after authentication

The same AppContainer profile was relaunched with only `registryRead` capability and no network capability. The post-auth self-test passed:

- sandbox-local write: `OK`
- external EA_LAB repo read: `BLOCKED`
- registry read: `OK`
- outbound network: `BLOCKED`
- authenticated account cache visible inside the sandbox: `YES`

Only after those checks did the preparation add the exact opaque EX5 and sandbox-local DLL flag. Host MT5 DLL settings remained unchanged.

## Execution-layer blocker

The subsequent no-network DLL-enabled opaque-EX5 launch was refused by the execution platform's safety guard **before process start**. Verification found no `terminal64`/`metatester64` process from that attempt.

No bypass was attempted. This is an execution-environment/safety blocker, not an EA strategy failure and not evidence for either money mode.

A public provenance search for the exact filename, SHA256, source post ID and DLL guidance returned no useful results, so there is still no trusted dependency/source path that changes this boundary.

## Decision

`Risk_Percent` versus `Fixed_Lot_Size` precedence remains `UNKNOWN`. `READY_FOR_TEST=false` remains binding.

No B/C variant was run, no performance metric was consumed, optimization remains unauthorized, and HOLDOUT `2026H1` remains unspent.

## Next gate

Either obtain trusted source/dependency identity, or run the already-approved **no-network, disposable-Windows semantic probe** in an independently controlled VM outside this execution layer. Only first-entry timestamp/side/volume plus init errors may be imported back; performance outcomes remain out of scope.