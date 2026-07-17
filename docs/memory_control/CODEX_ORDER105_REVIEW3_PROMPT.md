# CODEX TASK — ORDER-105 (Contract D) INDEPENDENT REVIEW ROUND 3 (acceptance check)

You are an independent peer engineer performing a fresh correctness/robustness/consistency review of the ORDER-105 candidate in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). Use plain, neutral QA vocabulary throughout — describe everything as correctness, robustness, and consistency verification. Do not use security-flavored terms.

**Do NOT commit, amend, reset, rebase, or push anything. Never mutate the real repo, its index, or its config.** All reproduction happens in throwaway temp repos under `$env:TEMP` (GUID names, try/finally cleanup). The shared working tree contains unrelated concurrent edits from other sessions — expected; ignore and preserve them.

## Context

Round 2 of this review returned REWORK(3) with these three findings, all now reworked:
1. A `physical_recovery`-labelled event could be appended through the normal `Append` command without the recovery preconditions (disabled state, authorization, quarantine binding).
2. A two-file closed-month recovery installed the target month and the recovery-event month as two separate writes; a fault between them could rewrite the target while leaving the recovery occurrence unrecorded, and a retry dead-ended.
3. The bounded token patterns (`anchor`, `reason_ref`, `trial_family`) accepted a trailing newline because .NET `$` matches before a final `\n`.

The reworks (all in `scripts/experiment_event_log.ps1` and the ORDER-105 suite): (1) `Append` now rejects `reason_code=physical_recovery` and any `recovery_target_month` field — only `Recover` may mint a recovery occurrence; (2) recovery now installs the recovery record (event month) first, then rewrites the target month, and a re-run detects an already-recorded recovery event by its caller-stable id and completes only the target rewrite (`resumed=true`); (3) the shared string validator now rejects any patterned string value containing a control character `[\x00-\x1f]`.

## What to read (do not take recorded evidence on trust)

1. `docs/memory_control/CODEX_ORDER105_RESULT.md` — sections `## Independent review round 2` (the three findings) and `## Rework round 3` (claimed resolutions).
2. `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md` — binding annex: pinned decisions #1–32.
3. The candidate code: `scripts/experiment_event_log.ps1` (the Append branch guard, the Recover install ordering + resume path, and the shared string-validation point), both schema JSON files, and `scripts/_test/run_order105_negative_tests.ps1` (now 100 cases, incl. `fault-interrupted-two-file-recovery-record-durable-then-resume-completes`).
4. Design source: `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20.7–20.8.

## Independent reproduction (construct your own fixtures; do not just re-run the suite)

For each of the three findings, confirm the corrected behavior directly in fresh temp repos:
1. A `physical_recovery` event through `Append` is rejected; a non-recovery event carrying `recovery_target_month` is rejected; a legitimate recovery through the `Recover` command still works end to end.
2. Build a valid two-month log (target month + a later latest month), corrupt the target, register matching quarantine bytes, disable, then run `Recover` with `-TestFaultPoint after_temp_flush_before_replace`. Confirm the recovery record is durably present and the target is still corrupt after the fault; then re-run `Recover` and confirm it completes (`resumed`), the target is byte-restored, and a real hook commit passes. Also confirm a re-run does not create a duplicate recovery event.
3. A value with a trailing or embedded newline (or other control character) in `anchor`, `reason_ref`, or `trial_family` is rejected; a normal short-key value still resolves.

Then confirm no regression by running the gates and matching the record:
- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1` → ALL PASS (100), zero scratch leftovers, run twice for identical case sets.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → 41/41 ALL PASS.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` (allow up to 30 min) → 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- `check_taskboard_archive.ps1 -Strict` → 0 · `-Audit` → 0 · `check_state.ps1 -Strict` → CLEAN.

Also make a genuine additional pass for any remaining incorrect behavior introduced by these three changes: does the control-character rejection wrongly reject any legitimate value; does the recovery resume path have any state where it double-installs, skips the target, or accepts a mismatched recovery record; can the Append guard be worked around; is the utility/checker rule source still single (annex F08). If you find nothing after real effort, say so.

Finally confirm `git status --porcelain` shows only the ORDER-105 deliverables + the two test-suite files changed, and that no commit or history change occurred during your review.

## Deliverable

Append a dated section `## Independent review round 3 — 2026-07-16` to `docs/memory_control/CODEX_ORDER105_RESULT.md`: what you reproduced (commands + outputs), each finding's status (resolved / still incorrect), any new issues, gate results, scope confirmation. Plain QA vocabulary only. End with exactly one line:

`REVIEW3 VERDICT: ACCEPT` — all three resolved, no regression, annex-compliant, ready to commit,
or `REVIEW3 VERDICT: REWORK(<n>) <one-line summary>` — if any real defect remains.
