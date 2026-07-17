# CODEX TASK — ORDER-105 BUILD REWORK ROUND 1

You are continuing the ORDER-105 build in repo **D:\EA_LAB** (Windows, PowerShell 5.1, git-bash). Neutral engineering language. Same iron rules as the build round: **no commit/amend/reset/rebase/push in the real repo; all mutable tests in GUID TEMP repos with try/finally cleanup; never touch files outside scope; preserve other sessions' concurrent edits.**

Read first: `docs/memory_control/CODEX_ORDER105_RESULT.md` (your build report), `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md` (binding annex), `AGENT_TASKBOARD.md` block `## ORDER-105` (rev01).

The lead reviewed the BLOCKED(partial) report and independently confirmed the ORDER-103 regression root cause. This round closes ALL remaining acceptance work. Lead decisions you must follow:

## 1. Fix the ORDER-103 fixture regression (root cause confirmed by lead)

`scripts/_test/run_order103_negative_tests.ps1` copies the real `.githooks/pre-commit` into temp fixture repos but its copied-script sets (the copy list around lines 533-536 and the loop around line 835, plus any other fixture that materializes the hook) do not include `scripts/check_experiment_events.ps1`, which the extended hook now invokes. Fix: add `scripts/check_experiment_events.ps1` to every fixture copy-set that installs the production hook. Do NOT make the hook tolerate a missing checker script — a missing checker must stay fail-closed (that behavior is correct and must remain).

Same check for `run_order101_negative_tests.ps1`: if any of its fixtures install the production hook, extend their copy-sets identically.

Then run `scripts/_test/run_order103_negative_tests.ps1` to full completion → the 41-case summary must be ALL PASS.

## 2. Amend the F14 shared-repository assertion (lead-approved semantics — intent unchanged, flakiness removed)

The current `shared-repo-head-index-worktree-config-unchanged` case asserts real-repo HEAD equality, which legitimately fails whenever another session commits during the run. Replace with concurrent-writer-tolerant assertions that still prove THE SUITE mutated nothing:

- Capture `HEAD_before`/`HEAD_after`. If they differ, assert `git log HEAD_before..HEAD_after --name-only` touches NO path in the ORDER-105 deliverable/scope set (`docs/memory_control/experiment_events/**`, `scripts/experiment_event_log.ps1`, `scripts/check_experiment_events.ps1`, `scripts/_test/run_order105_negative_tests.ps1`, `.githooks/pre-commit`, `.gitattributes`) — i.e. any new commits came from other writers working elsewhere.
- Assert index blob IDs (`git rev-parse :<path>`, tolerate absent-from-index) and working-tree raw hashes for the scope set are unchanged before vs after.
- Assert `git config --list --local` unchanged.
- Keep the zero-scratch-leftover and GUID-root guards exactly as they are.

## 3. Add the remaining mandatory negTest rows (your report's loose ends #4-#8, all as explicit named cases)

- True concurrent evidence registration vs referencing event append; non-tail prior, forward reference, and cycle links; duplicate-core transition as a distinct case from generic out-of-order; full amendment/tombstone authorization matrix.
- Staged-but-uncommitted evidence rejected; missing full commit OID; missing blob OID; symlink escape; hash computed from normalized text (vs raw bytes) rejected; each manifest locator mismatch dimension (path/commit/blob/sha256/size/media) as its own case.
- Diagnostic scan: truncated multibyte UTF-8 line and structurally-valid-but-schema-invalid line, both reporting exact bad line numbers and readable good IDs.
- Rollback: nonterminal experiment survives disable→rebuild→re-enable with traceability; deterministic replay of preserved events (two rebuilds byte-identical); a recovery candidate that silently omits one independently valid event is rejected.
- Two-process PowerShell 5.1 canonical-serialization byte-identity case, independent of the autocrlf/idempotency fixture.

## 4. Final acceptance runs (record everything)

- `scripts/_test/run_order105_negative_tests.ps1` FULL (no -DevFast) **twice**: both ALL PASS, identical case sets/counts, zero scratch leftovers. With the amended F14 semantics, concurrent external commits must no longer invalidate the run.
- `scripts/_test/run_order103_negative_tests.ps1`: ALL PASS (41).
- `scripts/_test/run_order101_negative_tests.ps1`: run to completion with a generous bound (it has taken ~8 minutes under load; allow up to 20). Expected: 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- `check_taskboard_archive.ps1 -Strict` → 0 · `-Audit` → 0 · `check_state.ps1 -Strict` → CLEAN.
- Final `git status --porcelain` + `git diff --numstat`: only ORDER-105 deliverables (now including the two `scripts/_test/run_order10{1,3}_negative_tests.ps1` fixture fixes) changed; no commits made by you.

## Deliverable report

Append a dated section `## Rework round 1 — 2026-07-16` to `docs/memory_control/CODEX_ORDER105_RESULT.md`: root-cause note for the fixture fix, the amended F14 case description, every new negTest case name, full gate/suite outputs, and honest remaining gaps if any. End with exactly one line:

`BUILD STATUS: DONE` — everything green,
or `BUILD STATUS: BLOCKED(<short reason>)`.
