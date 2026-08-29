# HERMES_EA_LAB_PILOT

Isolated Hermes Bot Mode pilot for EA_LAB. This module is prepared and reviewed on its own branch before any canonical merge.

## Safety boundary
- Base snapshot: `a3123655a82981a3ddd2fd81aa311affb9159b6e`.
- Pilot worktree: `C:\ea_lab_tmp\hermes_ea_lab_pilot_final_20260822`.
- Never clean, reset, stash, restore, overwrite, or infer canonical bytes from dirty `D:\EA_LAB`.
- No MT4/MT5/VPS attachment, deployment, trading, LIVE/DEMO->LIVE, risk/default changes, QI-2+, force push, or history rewrite.
- Bot profiles remain fail-closed for built-in terminal, file, code-execution, computer-use, and delegation toolsets.
- `ea-researcher` gets local canonical inspection only through the task-scoped `ea_lab_safe_reader` MCP server. The server accepts only SafeWorkspace-relative paths, canonicalizes each target under that root, and exposes read/search/list/hash operations only.
- Coder/tester mutation authority is granted only by an explicit task-scoped invocation against an isolated worktree.

## Pilot roster
- `ea-researcher`: evidence gathering and bounded synthesis.
- `ea-coder`: bounded implementation worker.
- `ea-tester`: deterministic test/evidence worker.
- `ea-reviewer`: frozen-HEAD independent review worker.

## Runtime pin
Hermes Agent `0.20.5`, release tag `v2026.8.19`, peeled upstream commit `fcbd1076a93841fa88855acce810e342a5b78101`.
Python runtime: `3.11.16`.

## Task-scoped execution
Persistent profiles store `terminal.cwd: .`; they are not permanently bound to any EA_LAB worktree.
`ea-researcher` does not receive the built-in `file` or `terminal` toolset. `scripts/apply_profiles.ps1` binds its `ea_lab_safe_reader` MCP command to `${workspaceFolder}` so every observe session starts a reader rooted to the exact worktree selected by `chat --in`.
Mutation must go through `scripts/run_profile_task.ps1`, which requires an exact clean Git worktree and exact HEAD.
For `bounded-write`, only `ea-coder` may receive the task-scoped built-in `file` toolset and every changed path must match the explicit allowlist.
Hermes 0.20.5 captures local `TERMINAL_CWD` before `chat --in` is applied, so the wrapper pins both process cwd and `TERMINAL_CWD` to `SafeWorkspace` before launch.
The wrapper refuses `D:\EA_LAB` and every descendant of that protected dirty primary checkout.

## EA R&D operating role

Hermes is the deterministic/mechanical EA R&D factory under Control Tower direction. It is not an independent strategy architect or authority source.

Hermes MAY, when an exact task contract authorizes it:
- generate deterministic run manifests; execute approved local Strategy Tester/backtest jobs; orchestrate approved batch cells;
- collect/normalize reports, detect missing/failed cells, and build smoke matrices, heatmaps and year splits;
- join trades to a **frozen** regime timeline, build regime affinity, compare Parent vs Child;
- execute pre-registered coarse/region/refine/sensitivity stages and package deterministic evidence.

Hermes MAY NOT invent a strategy hypothesis, silently change parent mechanics, change risk/defaults, choose/spend HOLDOUT, deploy/attach runtime, trade, promote a candidate, choose DEMO/LIVE, widen ranges outside contract, pick top PF as winner without the selection contract, hide mechanical failures, or reinterpret harness/environment failure as strategy failure.

Canonical method: `docs/research/EA_RND_PROTOCOL.md`. Report owner: `docs/research/EA_REPORT_SCHEMA.md`. Regime owner: `docs/research/EA_REGIME_FRAMEWORK.md`.
Qualification: H0 protocol load -> H1 Golden Replay (existing evidence only, no new MT5) -> H2 2-3 pre-authorized cells -> H3 approved batch mode. Current next contract: `H1_GOLDEN_REPLAY_CONTRACT.md`.

