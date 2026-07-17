# CODEX TASK — ORDER-105 (Contract D) INDEPENDENT REVIEW ROUND 4 (acceptance check)

You are an independent peer engineer performing a fresh correctness/robustness/consistency review of the ORDER-105 candidate in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). Use plain, neutral QA vocabulary throughout — correctness, robustness, and consistency verification. Do not use security-flavored terms.

**Do NOT commit, amend, reset, rebase, or push anything. Never mutate the real repo, its index, or its config.** All reproduction happens in throwaway temp repos under `$env:TEMP` (GUID names, try/finally cleanup). The shared working tree contains unrelated concurrent edits from other sessions — expected; ignore and preserve them.

## Context

Round 3 of this review returned REWORK(2), both now reworked:
1. The recovery resume path compared an already-recorded recovery event only by `event_id` (plus `reason_code`/`recovery_target_month`), not the full payload, so a retry with the same `event_id` but a different payload was accepted as a resume instead of a conflict (pinned decision #15 requires a conflict for same id + different payload).
2. Two suite child-call paths (`Invoke-Utility`, `Invoke-TestGit`) launched children synchronously without a finite deadline.

The reworks: (1) the resume branch now re-timestamps the retried request with the recorded occurrence's timestamp, schema-validates, and byte-compares the canonical payload against the recorded event — a mismatch throws `event_id_conflict` (the same mechanism normal-append idempotency uses); a new negTest `resume-with-same-id-different-payload-conflicts-and-does-not-install-target` covers it. (2) a new `Invoke-BoundedProcess` helper (ProcessStartInfo + the existing `Quote-ProcessArgument` + `WaitForExit(deadline)` + kill + async pipe draining) now backs both `Invoke-Utility` and `Invoke-TestGit`.

## What to read (do not take recorded evidence on trust)

1. `docs/memory_control/CODEX_ORDER105_RESULT.md` — sections `## Independent review round 3` (the two findings) and `## Rework round 4` (claimed resolutions).
2. `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md` — binding annex, pinned decisions #1–32.
3. The candidate code: `scripts/experiment_event_log.ps1` (the Recover resume branch), `scripts/_test/run_order105_negative_tests.ps1` (the new `Invoke-BoundedProcess`, `Invoke-Utility`, `Invoke-TestGit`, and the new conflict case), both schema files, and `scripts/check_experiment_events.ps1`.
4. Design source: `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20.7–20.8.

## Independent reproduction (construct your own fixtures; do not just re-run the suite)

1. For finding 1: build a valid two-month log, corrupt the target month, register matching quarantine bytes, disable, run `Recover` with `-TestFaultPoint after_temp_flush_before_replace` to reach the interrupted state (record durable, target still corrupt). Then (a) retry with the SAME request → completes (`resumed`, target restored, no duplicate); and separately from the interrupted state (b) retry with the same `event_id` but a changed field → confirm `event_id_conflict` and that the target is NOT installed. Also confirm a normal same-id/different-payload append still conflicts (no regression).
2. For finding 2: confirm `Invoke-Utility` and `Invoke-TestGit` run children under a finite deadline and that argument passing is intact (utility calls with JSON-path arguments and git calls with repo-relative path arguments both still behave correctly). A deliberately over-long child (or a review of the timeout+kill path) should show the deadline is enforced rather than hanging.

Then confirm no regression by running the gates and matching the record:
- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1` → ALL PASS (101), zero scratch leftovers, run twice for identical case sets.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → 41/41 ALL PASS.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` (allow up to 30 min) → 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- `check_taskboard_archive.ps1 -Strict` → 0 · `-Audit` → 0 · `check_state.ps1 -Strict` → CLEAN.

Make a genuine additional pass: does the payload-identity comparison in the resume branch have any gap (e.g. a field the canonical form ignores); does `Invoke-BoundedProcess` mis-handle output capture, exit codes, or argument quoting for any existing call; is the utility/checker rule source still single (annex F08). If you find nothing after real effort, say so.

Finally confirm path-scoped `git status` shows only the ORDER-105 deliverables + the two test-suite files changed, and that no commit or history change occurred during your review (other sessions may commit concurrently; that is expected).

## Deliverable

Append a dated section `## Independent review round 4 — 2026-07-17` to `docs/memory_control/CODEX_ORDER105_RESULT.md`: what you reproduced (commands + outputs), each finding's status, any new issues, gate results, scope confirmation. Plain QA vocabulary only. End with exactly one line:

`REVIEW4 VERDICT: ACCEPT` — both resolved, no regression, annex-compliant, ready to commit,
or `REVIEW4 VERDICT: REWORK(<n>) <one-line summary>` — if any real defect remains.
