# CODEX TASK — ORDER-105 (Contract D) INDEPENDENT REVIEW ROUND 6 (acceptance check)

You are an independent peer engineer performing a fresh correctness/robustness/consistency review of the ORDER-105 candidate in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). Use plain, neutral QA vocabulary throughout — correctness, robustness, and consistency verification. Do not use security-flavored terms.

**Do NOT commit, amend, reset, rebase, or push anything. Never mutate the real repo, its index, or its config.** All reproduction happens in throwaway temp repos under `$env:TEMP` (GUID names, try/finally cleanup). The shared working tree contains unrelated concurrent edits from other sessions — expected; ignore and preserve them.

## Context

Round 5 returned REWORK(2): (1) a completed recovery (after an `after_replace` fault) returned `reference_invalid` on a byte-identical retry instead of an idempotent success; (2) the utility accepted a second recovery occurrence (fresh event_id) for a target that already had one, a state the staged checker rejects. Both were in the recovery subsystem (the third consecutive round there), so the `Recover` command was restructured into one state machine keyed on the target month:
- no occurrence + fresh event_id → require integrity-corrupt + quarantine → full path (record to latest month first, then target);
- occurrence + same event_id + byte-identical + target restored → COMPLETED (idempotent `already_appended`, no mutation);
- occurrence + same event_id + byte-identical + target corrupt → RESUME (finish target install);
- occurrence + same event_id + byte-different → `event_id_conflict`;
- occurrence + different event_id → `event_id_conflict` (only one recovery occurrence per target, matching the staged checker);
- no occurrence but event_id collides with another recorded event → `event_id_conflict`.
The target-preservation check was extracted to `Assert-RecoveryPreservesTarget`, shared by the fresh and resume paths.

## What to read (do not take recorded evidence on trust)

1. `docs/memory_control/CODEX_ORDER105_RESULT.md` — sections `## Independent review round 5` (the two findings) and `## Rework round 6` (the restructure).
2. `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md` — binding annex, pinned decisions #1–32.
3. The candidate code: `scripts/experiment_event_log.ps1` (the whole restructured `Recover` branch + `Assert-RecoveryPreservesTarget`), `scripts/check_experiment_events.ps1` (the recovery recognizer it must stay congruent with), `scripts/_test/run_order105_negative_tests.ps1` (the recovery cases incl. the two new ones), both schema files.
4. Design source: `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20.7–20.8.

## Independent reproduction (construct your own fixtures; do not just re-run the suite)

Exercise the full recovery state machine directly in fresh temp repos (two-month log, corrupt target, quarantine, disabled). Cover every branch: a fresh authorized recovery completes and commits through the real hook; an `after_replace` fault then a byte-identical retry → idempotent `already_appended` with no mutation; an `after_temp_flush_before_replace` fault then a byte-identical retry → resume completes; a same-event_id byte-different retry → `event_id_conflict`; a different-event_id recovery for a target that already has an occurrence → `event_id_conflict` (and confirm the staged checker would also reject two occurrences); a fresh recovery whose candidate omits an independently-valid target event → rejected; the target-preservation behavior is identical on the fresh and resume paths. Also confirm the utility never produces a recovery state that the staged checker then refuses to commit (utility/checker congruence, pinned #27/#30).

Then confirm no regression by running the gates and matching the record:
- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1` → ALL PASS (104), zero scratch leftovers, run twice for identical case sets.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → 41/41 ALL PASS.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` (allow up to 30 min) → 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- `check_taskboard_archive.ps1 -Strict` → 0 · `-Audit` → 0 · `check_state.ps1 -Strict` → CLEAN.

Make a genuine additional pass for any remaining incorrect behavior in the restructured Recover branch: a state that skips or double-installs the target, a mis-classification between the six branches, a preservation gap, or a divergence between what the utility accepts and what the checker commits. Also confirm annex F08 (single rule source). If you find nothing after real effort, say so.

Finally confirm path-scoped `git status` shows only the ORDER-105 deliverables + the two test-suite files changed, and that no commit or history change occurred during your review.

## Deliverable

Append a dated section `## Independent review round 6 — 2026-07-17` to `docs/memory_control/CODEX_ORDER105_RESULT.md`: what you reproduced (commands + outputs), each finding's status, any new issues, gate results, scope confirmation. Plain QA vocabulary only. End with exactly one line:

`REVIEW6 VERDICT: ACCEPT` — recovery state machine correct, no regression, annex-compliant, ready to commit,
or `REVIEW6 VERDICT: REWORK(<n>) <one-line summary>` — if any real defect remains.
