# CODEX TASK — ORDER-103 (C1-ENFORCE) REWORK ROUND 3: fix checkpoint-laundering-via-merge, then complete the interrupted full verification

You are a peer engineer continuing ORDER-103 in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash, full read/run access). Read `AGENT_TASKBOARD.md` block `## ORDER-103`, section "### FINAL BLIND CODEX REVIEW รอบ 4 ... BLOCKER 6" near the end, for full context. A prior independent review round (a fresh Codex session, not you) confirmed 3 earlier fixes hold, then found and reproduced ONE new, more fundamental defect before its session was cut short by a content filter mid-run (this happens sometimes with certain prompt phrasing; use plain, neutral engineering language throughout your own work and output to avoid it). **Do NOT commit anything. Leave all changes in the working tree.**

## The defect: trusted checkpoint can be laundered into the chain via a merge's non-first-parent

The chain-integrity check trusts a pinned checkpoint commit as the root of the whole append-only guarantee. The review found that if the checkpoint SHA is only reachable through a merge commit's **second** (or later) parent — i.e. it is a real ancestor of HEAD by `git merge-base --is-ancestor`, but it does NOT literally appear in the output of `git rev-list --first-parent HEAD` — the chain-walking code still accepts it and constructs a walk that treats the checkpoint as if it were directly connected by a real first-parent edge to some other commit, when no such edge exists in the actual commit graph. This can report `IsClean=True` for a check that never actually verified a real, continuous line of custody.

### Reproduction (already run once; re-verify it yourself, then fix)
In a throwaway temp repo:
1. Create a root commit with an archive file (state `v0`).
2. Branch `trusted` from root; commit once more on `trusted` — call this commit `cp2` (the "trusted checkpoint").
3. Switch back to `master` (still at root); make one unrelated commit there (`main`) — so `master`'s line of history does NOT descend from `cp2` at all.
4. `git merge --no-ff trusted` into `master` — this merge commit's parents are `[main-side (first), cp2 (second)]`. Confirm with `git rev-list --parents -n 1 HEAD`.
5. Confirm `git rev-list --first-parent HEAD` does NOT include `cp2` anywhere.
6. Confirm `git merge-base --is-ancestor cp2 HEAD` succeeds (exit 0) — this is normal, correct git behavior (cp2 IS an ancestor via the merge), not itself a bug.
7. Run the chain integrity function (`Invoke-ArchiveChainIntegrityCheck` in `scripts/check_taskboard_archive.ps1`) with `-CheckpointSha cp2 -HeadRef HEAD`. Before the fix, this returns `IsClean=True` with a fabricated walk (e.g. treating `cp2` as if directly preceding some other commit it has no real parent-child relationship with).

## The fix

The chain check must require that the checkpoint SHA is **exactly present** in the literal output of `git rev-list --first-parent <HeadRef>` — not merely "an ancestor by any path." If the checkpoint is an ancestor (per `--is-ancestor`) but does NOT appear in the first-parent list, this must be treated as a **fail-closed integrity failure** with a clear, specific message along the lines of: "trusted checkpoint is reachable only via a non-first-parent path (e.g. a merge's second parent) -- rejected, possible checkpoint laundering." Do not attempt to construct any alternate walk or substitute path in this case — fail immediately and clearly. The normal case (checkpoint genuinely present in the first-parent list, e.g. the real production checkpoint `0ced19485c6c6ce9a23541f785ab82bae4fcad25` relative to the real repo's HEAD) must continue to work exactly as before — verify this explicitly after your fix.

Apply the same "checkpoint must be a literal first-parent-list member" requirement everywhere the checkpoint is used as a chain root (the working-tree extension check likely also anchors off the same checkpoint/HEAD relationship — check whether it has an analogous gap and fix it too if so).

### Regression test to add
Add a new case to `scripts/_test/run_order103_negative_tests.ps1` (following existing suite conventions — temp repos, real git operations, no mutation of the real repo) reproducing the exact scenario above: checkpoint reachable only via a merge's non-first-parent → the chain check must report NOT clean / an integrity failure, not `IsClean=True`. Also add (or confirm existing coverage for) a positive case: a checkpoint that IS genuinely in the first-parent list continues to pass normally.

## After the fix: complete the verification that got interrupted

The prior review session was cut off by a content filter before it finished running the full negative-test suites. Complete that now, using plain neutral phrasing in any of your own tool invocations or reports (avoid words like "attack", "exploit", "breach" — describe this as correctness/robustness verification, not security testing):

1. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Strict` → exit 0 on the real repo (working tree, no regression). Same for `-Audit`. `scripts/check_state.ps1 -Strict` → CLEAN.
2. `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → run to completion; report the exact pass count and confirm ALL cases pass, including your new checkpoint-laundering regression case.
3. `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` → run to completion (this one is slow, ~9 minutes observed previously — allow it to finish); report exact pass/fail count; expect 25 pass / 1 pre-existing unrelated failure (`cross-HEAD-zero-diff`), no new regressions.
4. Re-confirm the 3 previously-fixed items from the prior round still hold (hook bypass when archive unchanged, merge-second-parent archive-change rejection, pre-H2 preamble detection) — a quick re-run of their existing test cases is sufficient, you don't need to re-derive them from scratch.

## Hard constraints
- Do NOT commit. Do NOT amend/rewrite/reset the existing commit `245f8f62c047ad843b01b1b2cfffcac3f21fc5ad` or any other commit.
- Do NOT touch any file outside: `scripts/check_taskboard_archive.ps1`, `scripts/_test/run_order103_negative_tests.ps1` (and `scripts/check_precommit_staged.ps1` only if the working-tree-extension gap genuinely requires a change there too — explain why if you touch it).
- All reproductions and mutation tests run in throwaway temp repos/clones under `$env:TEMP`; never mutate the real repo. Confirm at the end that the real repo's `git status --porcelain` and `git diff --numstat` show only your intended edits.

## Deliverable
Append a new dated section to `docs/memory_control/CODEX_ORDER103_REWORK_RESULT.md` covering: the checkpoint-laundering fix (file:line, before/after reproduction with exact commands+exit codes), the new regression test, and the full suite results that complete what the interrupted round left unfinished. End with exactly one line: `REWORK3 STATUS: DONE` or `REWORK3 STATUS: BLOCKED (reason)`. Note that a further independent review round is still required before ORDER-103 can be called ACCEPT — this specific defect (root-of-trust laundering) is more fundamental than the previous round's findings, so treat it with proportionate care.
