# EA_LAB lnwjud Current Write V1

Owner-approved bounded extension of the accepted Current Read V2 direct ChatGPT surface.

## Goal

Make routine EA_LAB source/text edits possible through the EA_LAB plugin without keeping Remote Desktop Commander as the normal read/edit transport.

The accepted Current Read V2 read surface remains available as `frozen_v1`. Write V1 is additive and routes the tunnel `main` channel to the new gateway.

## Runtime layout

- `main` -> `127.0.0.1:18768/mcp` -> Current Write V1.
- `frozen_v1` -> `127.0.0.1:18767/mcp` -> accepted Current Read V2 fallback.
- canonical read worktree: `D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928\canonical`.
- isolated write worktree: `D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928\workspace`.
- write branch: `lnwjud/write-runtime-20260928`.
- the dirty primary `D:\EA_LAB` worktree is never a write target.

## Added tools

Write V1 preserves all nine Current Read V2 tools and adds:
1. `ea_lab_write_status` - exact isolated-worktree identity and dirty state.
2. `refresh_write_workspace` - fetch + fast-forward only; refuses dirty/ahead/divergent state.
3. `read_workspace_file` - bounded UTF-8 read plus current SHA256.
4. `edit_workspace_file` - `replace_exact` or `create_new`.
5. `workspace_diff` - bounded status/diff; no commit/push.

`replace_exact` uses gateway-serialized compare-and-swap semantics: the caller supplies the current SHA256 plus an `oldText` that occurs exactly once, and the SHA256 is revalidated at the replacement boundary under the shared Write V1 mutation lock before atomic replacement. The shared lock also serializes gateway refresh and the scheduled snapshot/workspace refresh. This is a connector/workspace guarantee; it does not claim a filesystem-wide CAS against unrelated external writers. `create_new` uses no-replace creation from fully written/fsynced bytes.

Sensitive repository paths, traversal, ADS/device-like paths, ignored new files, binary/non-UTF8 content, oversized files, `.githooks`, and direct Lane Registry script mutation are denied.

## Authority ceiling

Write V1 grants bounded text-file mutation only in the isolated write worktree.

It does **not** expose arbitrary shell/process execution, Lane Registry transitions, MT5, backtest execution, deployment, trading, LIVE activation, risk/default approval, commit, or push.

Normal EA_LAB governance still applies to the resulting diff: deterministic gates, required independent review, and eligible normal FF integration are separate stages.

## Freshness

`build_snapshot.py` reuses unchanged canonical/evidence hashes and produces a point-in-time read snapshot.
`refresh_write_v1_snapshot.ps1` fetches `origin/master`, requires `origin/master == git ls-remote`, updates the clean detached canonical read worktree, fast-forwards the write worktree only when clean and FF-safe, preserves dirty/divergent edits, then rebuilds the snapshot.

The gateway reloads snapshot identity for each stateless MCP request, so a successful refresh becomes visible without restarting the tunnel or gateway.

The intended task cadence is every 10 minutes. If refresh fails, the prior sealed snapshot remains the last accepted read view.

## Startup / recovery

`start_write_v1.ps1` is the PowerShell supervisor. It verifies pinned Node, tunnel-client, V2 gateway, and Write V1 gateway hashes before launch. Before adopting or stopping any pre-existing tunnel/listener, it binds the exact executable path/hash, creation identity, and complete parsed command/profile argument vector; substring matches and unused extra arguments are not accepted. Ready-route adoption binds the actual listeners on ports 18767/18768 before health checks and revalidates the same PID, creation time, executable path/hash, and exact script identity afterward. Foreign, ambiguous, changed, or spoofed identities are refused rather than stopped. It uses the existing DPAPI CurrentUser vault, removes the transient runtime secret after tunnel startup, monitors both gateway health endpoints, and exits fail-closed if an owned child or route fails.

`install_tasks.ps1` registers `EA_LAB_LNWJUD_WriteV1` at user logon and `EA_LAB_LNWJUD_WriteV1_Refresh` every 10 minutes only when both task names are absent. It refuses pre-existing same-name tasks instead of force-overwriting/adopting them and rolls back only tasks created by the current invocation if a later registration/readback fails. A rollback deletion failure is aggregated with the original failure, and every successful deletion is followed by an absence readback; partial activation is therefore fail-visible. The installer is a runtime activation step and must only be run after the exact reviewed source is accepted.

## Verification

Run `test_write_v1.cjs` locally against port 18768 only during an authorized runtime acceptance phase. During source authoring, run `test_write_v1_repair1.cjs`; it covers shared mutation-lock serialization, replacement-boundary stale-SHA refusal, no-replace create behavior, and invokes `test_write_v1_safety_s1.ps1` for behavioral process/listener/task-transaction fixtures without activation. Run `verify_current_source_hashes.cjs` to verify strict UTF-8 plus the exact final source/doc bytes recorded in `CURRENT_SOURCE_SHA256.json`.

A fresh ChatGPT conversation may be required after a tool-surface change because an already-open conversation can retain the connector tool catalog it received when the chat started.
