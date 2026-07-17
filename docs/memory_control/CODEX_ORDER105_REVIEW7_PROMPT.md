# CODEX TASK — ORDER-105 (Contract D) INDEPENDENT REVIEW ROUND 7 (final acceptance check)

You are an independent peer engineer performing a fresh correctness/robustness/consistency review of the ORDER-105 candidate in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). Use plain, neutral QA vocabulary throughout. Do not use security-flavored terms.

**Do NOT commit, amend, reset, rebase, or push anything. Never mutate the real repo, its index, or its config.** All reproduction happens in throwaway temp repos under `$env:TEMP` (GUID names, try/finally cleanup). The shared working tree contains unrelated concurrent edits from other sessions — expected; ignore and preserve them.

## Context

Round 6 directly verified the full recovery state machine — fresh path with real hook commit, after_replace completed-retry idempotency, before-replace resume, same-id/different-payload conflict, second-occurrence conflict with checker congruence, and fresh/resume preservation consistency — and returned REWORK(1) on one classification gap: the COMPLETED test compared the live target against the retry's candidate file, so a byte-identical event request retried with a different-but-valid `RecoveryFilePath` fell into the resume path and reinstalled a completed target.

The rework: completion is now judged from the live state alone — recorded occurrence (byte-identical request) + valid live snapshot → idempotent `already_appended`, zero mutation, regardless of the retry's candidate file. A new permanent negTest covers the alternate-valid-candidate retry.

## What to read (do not take recorded evidence on trust)

1. `docs/memory_control/CODEX_ORDER105_RESULT.md` — sections `## Independent review round 6` and `## Rework round 7`.
2. `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md` — binding annex, pinned decisions #1–32.
3. The candidate code: `scripts/experiment_event_log.ps1` (the COMPLETED branch of Recover), `scripts/check_experiment_events.ps1`, `scripts/_test/run_order105_negative_tests.ps1` (105 cases), both schema files.
4. Design source: `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20.7–20.8.

## Independent reproduction

1. Reproduce the round-6 finding scenario against the fixed code: complete a recovery via the `after_replace` fault, then retry the byte-identical event request with (a) the same candidate → `already_appended`, no mutation; (b) a DIFFERENT valid candidate → `already_appended`, no mutation, no reinstall; (c) a different candidate AND a byte-different event request → `event_id_conflict`, no mutation.
2. Confirm the interrupted (before-replace) resume path still works: occurrence durable + target corrupt → byte-identical retry restores the target (`resumed=true`) — the live-state completion test must not have broken resume (the interrupted snapshot is invalid, so it must still route to resume).
3. Spot-confirm one fresh authorized recovery end-to-end through the real hook, and one same-id/different-payload conflict.
4. Make a genuine final pass over the whole Recover branch for any remaining state that mutates a completed transaction, skips a required install, or diverges from what the staged checker commits. Also confirm annex F08 (single rule source). If you find nothing after real effort, say so explicitly.

Then run the gates and confirm they match the record:
- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1` → ALL PASS (105), zero scratch leftovers, run twice for identical case sets.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → 41/41 ALL PASS.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` (allow up to 30 min) → 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- `check_taskboard_archive.ps1 -Strict` → 0 · `-Audit` → 0 · `check_state.ps1 -Strict` → CLEAN.

Finally confirm path-scoped `git status` shows only the ORDER-105 deliverables + the two test-suite files changed, and that no commit or history change occurred during your review.

## Deliverable

Append a dated section `## Independent review round 7 — 2026-07-17` to `docs/memory_control/CODEX_ORDER105_RESULT.md`: what you reproduced (commands + outputs), the finding's status, any new issues, gate results, scope confirmation. Plain QA vocabulary only. End with exactly one line:

`REVIEW7 VERDICT: ACCEPT` — resolved, no regression, annex-compliant, ready to commit,
or `REVIEW7 VERDICT: REWORK(<n>) <one-line summary>` — if any real defect remains.
