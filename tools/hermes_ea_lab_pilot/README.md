# HERMES_EA_LAB_PILOT

Isolated Hermes Bot Mode pilot for EA_LAB. This module is prepared and reviewed on its own branch before any canonical merge.

## Safety boundary
- Base snapshot: `a3123655a82981a3ddd2fd81aa311affb9159b6e`.
- Pilot worktree: `C:\ea_lab_tmp\hermes_ea_lab_pilot_final_20260822`.
- Never clean, reset, stash, restore, overwrite, or infer canonical bytes from dirty `D:\EA_LAB`.
- No MT4/MT5/VPS attachment, deployment, trading, LIVE/DEMO->LIVE, risk/default changes, QI-2+, force push, or history rewrite.
- Bot profiles are fail-closed by default: no terminal, file, code-execution, computer-use, or delegation toolsets.
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
Mutation must go through `scripts/run_profile_task.ps1`, which requires an exact clean Git worktree and exact HEAD.
For `bounded-write`, only `ea-coder` may receive the task-scoped `file` toolset and every changed path must match the explicit allowlist.
Hermes 0.20.5 captures local `TERMINAL_CWD` before `chat --in` is applied, so the wrapper pins both process cwd and `TERMINAL_CWD` to `SafeWorkspace` before launch.
The wrapper refuses `D:\EA_LAB` and every descendant of that protected dirty primary checkout.