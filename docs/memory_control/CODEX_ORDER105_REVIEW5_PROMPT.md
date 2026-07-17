# CODEX TASK — ORDER-105 (Contract D) INDEPENDENT REVIEW ROUND 5 (acceptance check)

You are an independent peer engineer performing a fresh correctness/robustness/consistency review of the ORDER-105 candidate in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). Use plain, neutral QA vocabulary throughout — correctness, robustness, and consistency verification. Do not use security-flavored terms.

**Do NOT commit, amend, reset, rebase, or push anything. Never mutate the real repo, its index, or its config.** All reproduction happens in throwaway temp repos under `$env:TEMP` (GUID names, try/finally cleanup). The shared working tree contains unrelated concurrent edits from other sessions — expected; ignore and preserve them.

## Context

Round 4 of this review returned REWORK(2), both now reworked:
1. In the recovery resume path, a retry with the same `event_id` but a changed `reason_code` returned `reference_invalid` instead of `event_id_conflict`, because the recovery-request-shape validation ran before the existing-id classification. Pinned decision #15 requires every same-id/different-payload retry to be `event_id_conflict`.
2. `Stage-And-Check` in the suite still launched the checker via `& powershell.exe` with no finite deadline.

The reworks: (1) the existing-id detection now runs first, immediately after reading the recovery request and before any recovery-request-shape validation; classification is by byte-identity alone (any schema failure or byte difference for an already-recorded event_id → `event_id_conflict`), and only a byte-identical retry proceeds as a resume; the recovery-request validation now runs only on the fresh-event_id path. (2) `Stage-And-Check` now routes through `Invoke-BoundedProcess`.

## What to read (do not take recorded evidence on trust)

1. `docs/memory_control/CODEX_ORDER105_RESULT.md` — sections `## Independent review round 4` (the two findings) and `## Rework round 5` (claimed resolutions).
2. `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md` — binding annex, pinned decisions #1–32.
3. The candidate code: `scripts/experiment_event_log.ps1` (the Recover branch: existing-id classification ordering vs the fresh-path recovery-request validation), `scripts/_test/run_order105_negative_tests.ps1` (`Stage-And-Check`, `Invoke-BoundedProcess`, and the two same-id conflict cases), both schema files, and `scripts/check_experiment_events.ps1`.
4. Design source: `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20.7–20.8.

## Independent reproduction (construct your own fixtures; do not just re-run the suite)

1. For finding 1: reach the interrupted recovery state (two-month log, corrupted target, quarantine, disabled, `-TestFaultPoint after_temp_flush_before_replace`). From copies of that state, retry with the same `event_id` and: (a) an unchanged request → completes as a resume; (b) a changed `reason_ref` → `event_id_conflict`, target not installed; (c) a changed `reason_code` → `event_id_conflict` (NOT `reference_invalid`), target not installed; (d) a byte-identical request whose event_id instead matches a NON-recovery recorded event → confirm it is not silently resumed. Also confirm a fresh (never-recorded) event_id still runs the full recovery-request validation and a malformed fresh recovery request is still rejected as before.
2. For finding 2: confirm `Stage-And-Check` runs its checker child under a finite deadline, and scan the suite for any remaining synchronous child launched without a deadline (`& powershell.exe`, `Start-Process -Wait` without timeout, or a direct `git` call outside the bounded wrappers). Report any you find.

Then confirm no regression by running the gates and matching the record:
- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1` → ALL PASS (102), zero scratch leftovers, run twice for identical case sets.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → 41/41 ALL PASS.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` (allow up to 30 min) → 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- `check_taskboard_archive.ps1 -Strict` → 0 · `-Audit` → 0 · `check_state.ps1 -Strict` → CLEAN.

Make a genuine additional pass for any remaining incorrect behavior in the reordered Recover branch (a state that skips the target install, double-installs, or mis-classifies), the bounded-process wrappers, or annex F08 rule-source singularity. If you find nothing after real effort, say so.

Finally confirm path-scoped `git status` shows only the ORDER-105 deliverables + the two test-suite files changed, and that no commit or history change occurred during your review.

## Deliverable

Append a dated section `## Independent review round 5 — 2026-07-17` to `docs/memory_control/CODEX_ORDER105_RESULT.md`: what you reproduced (commands + outputs), each finding's status, any new issues, gate results, scope confirmation. Plain QA vocabulary only. End with exactly one line:

`REVIEW5 VERDICT: ACCEPT` — both resolved, no regression, annex-compliant, ready to commit,
or `REVIEW5 VERDICT: REWORK(<n>) <one-line summary>` — if any real defect remains.
