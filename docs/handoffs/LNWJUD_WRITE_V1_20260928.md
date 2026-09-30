# LNWJUD CURRENT WRITE V1 — 2026-09-28

## Scope

Owner-approved bounded extension of the accepted Current Read V2 owner-facing ChatGPT connector.

Lane: `ct-lnwjud-write-v1-20260928`.
Base canonical at lane start: `b586d4d32c04fa33a30517ab3a1a8469b238d2ac`.
Primary dirty `D:\EA_LAB` was preserved; all authoring used isolated worktrees.

Runtime:
- main channel -> `127.0.0.1:18768/mcp` -> Current Write V1.
- frozen_v1 -> `127.0.0.1:18767/mcp` -> accepted Current Read V2 fallback.
- canonical read worktree -> `D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928\canonical`.
- isolated write worktree -> `D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928\workspace`.
- write branch -> `lnwjud/write-runtime-20260928`.

## Added capability

Current Write V1 preserves the nine Current Read V2 tools and adds:
`ea_lab_write_status`, `refresh_write_workspace`, `read_workspace_file`, `edit_workspace_file`, and `workspace_diff`.

`edit_workspace_file/replace_exact` requires the current SHA256 and exactly one old-text match. Repair1 serializes gateway edits and scheduled workspace refresh with one shared external mutation lock and revalidates the SHA256 at the atomic replacement boundary. This is a connector/workspace guarantee, not a filesystem-wide CAS claim against unrelated external writers. `create_new` is text-only, extension-allowlisted, non-ignored, inside an existing real parent directory, and uses no-replace creation from fully written/fsynced bytes.
Sensitive/traversal/ADS/device-like paths, binary/non-UTF8/oversized files, `.githooks`, and direct Lane Registry script mutation are denied.

Authority ceiling: bounded isolated-worktree text mutation only. No arbitrary shell/process, Registry transition, MT5/backtest/deployment/trading/LIVE authority, and no commit/push tool. Supervisor cleanup is separately bounded to exact executable path/hash, creation identity, and expected command/profile identity.

## Runtime acceptance observed before scrutiny

- exact 14-tool local surface present.
- positive workspace read passed.
- exact replacement passed and inverse replacement restored the original file SHA256 exactly.
- stale SHA denied.
- non-unique old text denied.
- `portfolio/ACCOUNTS.csv` denied.
- traversal denied.
- disallowed new-file extension denied.
- refresh refused while workspace dirty.
- create-new probe cleaned and final workspace returned clean.
- clean FF-only workspace refresh passed.
- `origin/master == git ls-remote` at canonical capture.

Snapshot builder cache improvement reuses the canonical manifest on unchanged clean Git HEAD and reuses evidence hashes when size+mtime are unchanged.
Observed refresh runtime improved from about 164 seconds on the uncached first pass to about 36–41 seconds on warm cached passes.

Gateway stateless requests reload the sealed snapshot context. A runtime proof changed snapshot ID from `29da93e845ad13c055c104c25a5c1017` to `e0e83e53efc2fb90f23c64a6cd3a08a4` without restarting the supervisor/tunnel/write gateway; ChatGPT immediately observed the new snapshot.

Historical pre-Repair1 runtime gateway SHA256: `da7e0a132886cedd57a093f23742e0413629ee1a3492b0388b77c315f296aa79`; this remains historical runtime evidence only and is not current activation proof.

The following hashes are historical predecessor-seed claims at head `77ff2529e3e43dd4a502d0b00afcf44bfd58d571`, not current S1 claims:
- Repair1 gateway source: `0ee04a04ba1a2ee5482363fa0a7aac86ba0b8cb4a7decd7bee5a2cbb90abddb1`.
- Snapshot builder source: `8ff87aa743498754745c8e59807a8e00618164458ae25d25dc32abe7cb0d75ff`.
- Repair1 supervisor source: `fa75869c52c4e6d9148380993fbbd8a39d6e4fa383a923c64e2222d267b8c798`.
- Repair1 refresh source: `38a8bcd58b38be1c007c5b178fa594e83769171b0fb1b3e666720a05b6d59b36`.
- Repair1 Scheduled Task installer source: `43683cf4d966041dea6a65eb37d0f434d172574d271b8ca8bdd471e058433969`.

Current S1 source/doc hashes are generated from the final bytes in `tools/lnwjud/current_write_v1/CURRENT_SOURCE_SHA256.json` and checked by `verify_current_source_hashes.cjs`. The receipt covers this handoff and every source/test file in the Current Write V1 directory; it excludes only its own bytes to avoid a self-referential hash.

Transient tunnel runtime secret is deleted after successful startup. DPAPI CurrentUser vault is reused; no secret is committed.

## Startup / freshness plan

`start_write_v1.ps1` is a PowerShell supervisor with pinned executable/gateway hashes and health monitoring. Existing processes are accepted only when the executable path/hash and the complete parsed argument vector match exactly. Ready-route adoption binds each listener on ports 18767/18768 to its PID, creation time, executable path/hash, and exact gateway script both before and after route/health checks. Foreign, ambiguous, changed, or spoofed-extra-argument identities fail closed and are never force-stopped. This replaces dependence on the application-control-blocked auto EXE path.

`refresh_write_v1_snapshot.ps1` is designed for a 10-minute task cadence. It refreshes the canonical read snapshot and fast-forwards the write workspace only when clean and FF-safe; dirty/divergent workspace state is preserved.

`install_tasks.ps1` is present but MUST NOT be run during the S1 author phase. It refuses any pre-existing same-name task rather than overwriting/adopting it. If a later registration/readback fails, it rolls back only tasks created by the current installer invocation, surfaces deletion failures together with the original error, and verifies absence after each rollback deletion. Intended tasks:
- `EA_LAB_LNWJUD_WriteV1` at user logon.
- `EA_LAB_LNWJUD_WriteV1_Refresh` every 10 minutes.

## Review / integration

Initial exact-head scrutiny returned `SCRUTINY_REPAIR_REQUIRED` for three source findings: process ownership before stop/adopt, serialized/revalidated write-workspace mutation semantics, and Scheduled Task ownership/rollback. Repair1 closed the serialized/revalidated mutation finding, while its targeted recheck left process ownership and rollback verification open. Repair1 remains spent; owner authority separately opened `LNWJUD-WRITE-V1-SAFETY-CLOSURE-S1-20260929` as a prospective successor, not Repair2.

S1 adds behavioral fixtures for owned, foreign, spoofed-extra-argument, PID/creation mismatch, listener ownership/stability, exact force-stop refusal, pre-existing task refusal, rollback delete failure, and rollback absence verification. The fixtures use injected process/listener/task boundaries and perform no runtime or Scheduled Task activation. Exact-head independent GPT scrutiny remains required before integration or any task installation.

An already-open ChatGPT conversation may retain the connector tool catalog loaded at chat start. The tunnel route is already on Write V1, but fresh-chat/reload acceptance is required to prove the five new tool names are surfaced to the owner-facing client.

Scope closure does not grant commit/push, process, Registry, MT5, deployment, trading, risk/default, HOLDOUT, Candidate, or LIVE authority.

## Owner-approved Amendment A1 — source prepared, runtime not activated

Amendment A1 closes the five findings from the S1 independent review without changing the accepted Current Read V2 bundle or any historical receipt:

- process/listener discovery now completes a supported full inventory before filtering and distinguishes confirmed-empty from unavailable/denied;
- termination pins and retains the actual `System.Diagnostics.Process` OS handle across creation/executable/argv validation and terminates only through that object, so an exited process cannot retarget a reused PID;
- `source_bound_gateway_loader.cjs` validates and evaluates the same gateway buffer and exposes its startup-bound identity; route adoption checks that identity before and after readiness for both Write V1 and the unchanged V2 fallback;
- task creation/readback/rollback is bound to one invocation UUID plus exact action, trigger, principal, description and exported task-definition SHA256; a visible replacement is not deleted;
- application variables no longer collide with automatic `$PROFILE` or `$Matches`.

Task rollback uses immediate exact-identity readback followed by the Windows Task Scheduler delete-by-name API. This prevents deletion of replacements visible at readback under the authorized one-writer model, but it is not represented as an OS-atomic compare-and-delete: a non-cooperating replacement in the final readback/delete interval cannot be excluded by that API.

Runtime preparation after integration and targeted independent PASS is mechanical only: deploy `start_write_v1.ps1`, `source_bound_gateway_loader.cjs`, `refresh_write_v1_snapshot.ps1`, and `install_tasks.ps1` to `D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928`; deploy the Write gateway as `EA_LAB_CurrentWrite_V1_HTTP_Gateway.bundle.cjs`; retain the accepted V2 mapping `D:\EA_LAB_CONTROL\lnwjud-current-read-v2-20260922\EA_LAB_CurrentRead_V2_HTTP_Gateway.bundle.cjs`. The loader invocations are `<node> <loader> <V2 bundle> <V2 SHA256>` on port 18767 and `<node> <loader> <Write bundle> <Write SHA256>` on port 18768. The only intended task identities remain `EA_LAB_LNWJUD_WriteV1` (logon supervisor) and `EA_LAB_LNWJUD_WriteV1_Refresh` (10-minute refresh), created together by one invocation UUID. Do not install or start them before integration and independent PASS.

Historical A1 runtime-source hashes (final UTF-8 bytes before A1 CT intake) are:

- supervisor `start_write_v1.ps1`: `89f4c40ebde4afa3679bcf17eb3184b960f1fd902b04b99822b7d99ef9db399b`;
- source-bound loader `source_bound_gateway_loader.cjs`: `06593b76abd45e53ec691455c70b9e7486d34b487eb846510d8dd0a2cfaca505`;
- task installer `install_tasks.ps1`: `af718e9860912731e6eb7f9463b7db63d1fb14d5ca40bf02bf405b8689344426`;
- refresh writer `refresh_write_v1_snapshot.ps1`: `38a8bcd58b38be1c007c5b178fa594e83769171b0fb1b3e666720a05b6d59b36`;
- unchanged Write gateway source: `0ee04a04ba1a2ee5482363fa0a7aac86ba0b8cb4a7decd7bee5a2cbb90abddb1`;
- unchanged accepted external V2 fallback bundle pin: `c8dd4c130398c7dd192c48edeef53d836a739583df569b492a5b4b170a6958b1`.

## Owner-approved Amendment A2 — source prepared, runtime not activated

Amendment A2 fixes the production default `Route-IsReady` listener binding at exact base `88d6767178e1230e370372ddb8a8ed7974aff6e4`. Its default `ListenerLookup` now accepts and forwards `LookupPort`, `ExpectedScript`, and `ExpectedSourceSha` to `Get-ExactOwnedListenerIdentity` for both the Write route on port 18768 and the Current Read V2 route on port 18767. Missing or empty expected source SHA identity fails closed before listener discovery. Wrong expected SHA identity fails closed, while the correct expected SHA reaches the loaded-source identity check.

The deterministic A2 fixture calls `Route-IsReady` without overriding `ListenerLookup`; it replaces only the in-memory listener identity boundary and performs no network, process, credential, Scheduled Task, or runtime activation. All inherited A1, S1, Repair1, and source-bound loader fixtures remain required. The current A2 supervisor SHA256 is `d1c7a4dafad18296e9c8ec538749bf7c63599d5e1fb8ae1a1498f1ba63433eea`; the accepted external Write and V2 bundle pins are unchanged.

`CURRENT_SOURCE_SHA256.json` is the complete A2 source/doc byte manifest and remains authoritative for every file in its exact listed scope. Integration and runtime activation still require the separate Control Tower commit and targeted exact-head independent review; this author phase grants neither.
