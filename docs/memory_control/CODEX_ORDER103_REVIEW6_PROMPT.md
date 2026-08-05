# CODEX TASK — ORDER-103 (C1-ENFORCE) INDEPENDENT REVIEW ROUND 6 (final acceptance check)

You are an independent peer engineer performing a fresh correctness/robustness review of ORDER-103 in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). This is the sixth independent review of this work. Use plain, neutral engineering language throughout (frame everything as correctness/robustness/consistency verification — avoid words that have triggered unrelated content-filtering in past rounds).

**Do NOT commit, amend, reset, rebase, or push anything.** All reproduction happens in throwaway temp repos under `$env:TEMP`. Never mutate the real repo. Do not touch commit `245f8f62c047ad843b01b1b2cfffcac3f21fc5ad` or any other commit. The shared working tree may show unrelated concurrent commits/edits from other sessions — that is expected; ignore and preserve them.

## What ORDER-103 is

C1-ENFORCE closes a write-path enforcement gap in the C1 archive-migration system. It has three fixes, all currently sitting UNCOMMITTED in the working tree as the candidate under review:

1. **Fix 1 — append-chain integrity** (`scripts/check_taskboard_archive.ps1`): the archive (`AGENT_TASKBOARD.md` H2 append log) must be a clean first-parent append chain descending from a trusted checkpoint SHA. The validator must fail closed against: rewritten/reordered prefixes, a checkpoint reachable only via a non-first-parent path (e.g. a merge's second parent — "checkpoint laundering"), archive-changing merges, pre-H2 content tampering, and a checkpoint that is not an ancestor at all.
2. **Fix 2 — fail-closed pre-commit hook** (`.githooks/pre-commit` + `scripts/check_precommit_staged.ps1`): staging a modification/deletion/rename of any of the 5 protected coordination files must invoke full staged-consistency checks and block on inconsistency, even when the archive itself is unchanged.
3. **Fix 3 — Source-A exact-identity binding** (`scripts/check_taskboard_archive.ps1`): exception closure via a Source-A binding row with documented precedence over Source-B `## C1-CLOSURE` rows, no double-counting.

The candidate spans exactly these 5 files (verify this scope holds):
`.githooks/pre-commit` · `scripts/check_taskboard_archive.ps1` · `scripts/check_precommit_staged.ps1` · `scripts/_test/run_order103_negative_tests.ps1` · `scripts/_test/run_order101_negative_tests.ps1`.

## Prior review history (context, do not take on trust)

Five prior independent review rounds are recorded in `docs/memory_control/CODEX_ORDER103_REWORK_RESULT.md` (read it). Round 5 found **zero blockers**; the two remaining non-code items (missing regression cases + temp-dir cleanup) were closed in REWORK4 (last section of that file). Your job is to independently confirm — from a genuinely fresh reproduction, not by trusting the recorded evidence — whether the candidate is now correct and complete enough to be committed.

## Your review — reproduce independently, do not trust the report

1. Read `AGENT_TASKBOARD.md` block `## ORDER-103` for the original spec and the enumerated negative cases (a)–(j) for Fix 1, hook negatives, and A/B closure precedence.
2. Read the actual candidate code in all 5 files. Trace the real logic — do not skim.
3. Re-derive at least the highest-risk properties yourself in fresh temp repos: specifically the checkpoint-laundering / non-first-parent rejection (root-of-trust), the reordered-append rejection, the mutate-then-restore rejection, and the fail-closed hook when the archive is unchanged. Construct your own scenarios; do not merely re-run the provided suite.
4. Run the provided gates and suites and confirm they match claims:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Strict` → exit 0
   - same with `-Audit` → exit 0
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_state.ps1 -Strict` → CLEAN
   - `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → run to completion, ALL PASS, and confirm no `order103_negtests_*` scratch dirs remain in `%TEMP%` before/after
   - `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` → run to completion; the only acceptable failure is the known pre-existing `cross-HEAD-zero-diff (fix 2, real repo, HEAD vs 4aebbc37)` case — any other failure is a new regression
5. Actively look for anything still wrong: gaps between what the spec requires and what the code enforces, a property that passes the suite but is actually unsound, ordering/precedence bugs in Fix 3, hook bypasses, or fail-open paths. Try to find a real defect; if you cannot after genuine effort, say so.
6. Confirm `git status --porcelain` / `git diff --numstat` at the end shows only the intended candidate edits (plus unrelated other-session files that were already there) and that no commit or history change occurred.

## Deliverable

Append a new dated section titled `## Independent review round 6 (final acceptance check) — 2026-07-14` to `docs/memory_control/CODEX_ORDER103_REWORK_RESULT.md`. Include: what you independently reproduced (with commands/output), any defects found (or explicit confirmation none were found after genuine effort), the full gate/suite output, and the final scope confirmation. End with exactly one line:

`REVIEW6 VERDICT: ACCEPT` — if the candidate is correct, complete, in-scope, and ready to commit,
or `REVIEW6 VERDICT: REWORK(<n>) <one-line summary>` — if any real defect remains.
