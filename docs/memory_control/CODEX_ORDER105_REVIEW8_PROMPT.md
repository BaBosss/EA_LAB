# CODEX TASK — ORDER-105 (Contract D) INDEPENDENT REVIEW ROUND 8 (final acceptance check)

You are an independent peer engineer performing a fresh correctness/robustness/consistency review of the ORDER-105 candidate in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). Use plain, neutral QA vocabulary throughout. Do not use security-flavored terms.

**Do NOT commit, amend, reset, rebase, or push anything. Never mutate the real repo, its index, or its config.** All reproduction happens in throwaway temp repos under `$env:TEMP` (GUID names, try/finally cleanup). The shared working tree contains unrelated concurrent edits from other sessions — expected; ignore and preserve them.

## Context

Round 7 confirmed the round-6 recovery fix (completed-state retry with an alternate valid candidate → idempotent `already_appended`, no reinstall) and found no remaining production defect. Its single finding was a TEST repeatability issue: the case `true-concurrent-evidence-registration-versus-referencing-event-never-dangles` started its two children behind a held lock with only a fixed 500 ms sleep before release; under machine load a child could first attempt the lock after release and report `lock_wait_count=0`, failing the case even though the final event state was valid. Round 7's focused probe of the same race passed 10/10, so no production ordering defect exists.

The rework (test suite only — no production file changed): the case now uses a test-owned worker script with a ready/attempt file barrier, mirroring the synchronized three-writer case in the same suite. Each child dot-sources the utility, writes a READY marker, waits for a GO gate, writes an ATTEMPT marker immediately before invoking the command; the parent releases the held lock only after both children have announced their lock attempt (plus the same 600 ms settle the three-writer case uses). `Start-UtilityProcess` gained an optional `ScriptPath` parameter for launching the worker; default behavior for all existing callers is unchanged.

## What to read (do not take recorded evidence on trust)

1. `docs/memory_control/CODEX_ORDER105_RESULT.md` — sections `## Independent review round 7` and `## Rework round 8`.
2. `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md` — binding annex, pinned decisions #1–32 (for context; unchanged).
3. The changed file: `scripts/_test/run_order105_negative_tests.ps1` — the evidence-race case and the `Start-UtilityProcess` change.
4. Confirm the production files are UNCHANGED relative to what round 7 reviewed: `scripts/experiment_event_log.ps1`, `scripts/check_experiment_events.ps1`, both schema files (e.g., compare live SHA-256 against your own reading, or diff against any record you trust; the round-8 rework record lists their hashes).

## Independent verification

1. Read the reworked case end-to-end and judge: (a) does the barrier guarantee both children have announced a lock attempt before the parent releases the held lock; (b) does the case still verify the original contract — concurrent evidence registration versus a referencing event append never produces a dangling reference, register exits 0, both children observe positive `lock_wait_count`, final scan valid with exactly 1 event; (c) does the barrier-failure path kill the children so no orphan process or scratch leftover survives.
2. Judge whether the worker (dot-source + `Invoke-EventUtilityMain`) is equivalent for this purpose to the direct `-File` invocation it replaced, given the three-writer case already uses the same dot-source pattern.
3. Run a focused repeat of the reworked case's race shape (≥10 iterations) in a throwaway fixture: both children must observe positive lock waits and the final event count must be 1 each time.
4. Confirm no other case in the suite regressed semantically from the `Start-UtilityProcess` signature change (all existing callers pass no `ScriptPath`).

Then run the gates and confirm they match the record:
- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1` → ALL PASS (105), zero scratch leftovers, run twice for identical case sets AND identical outcomes (this repeatability is the point of round 8).
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → 41/41 ALL PASS.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` (allow up to 35 min) → 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure. If it exceeds your time allowance, record that explicitly rather than guessing.
- `check_taskboard_archive.ps1 -Strict` → 0 · `-Audit` → 0 · `check_state.ps1 -Strict` → CLEAN.

Finally confirm path-scoped `git status` shows only the ORDER-105 deliverables + the two test-suite files changed, and that no commit or history change occurred during your review.

## Deliverable

Append a dated section `## Independent review round 8 — 2026-07-17` to `docs/memory_control/CODEX_ORDER105_RESULT.md`: what you verified (commands + outputs), the finding's status, any new issues, gate results, scope confirmation. Plain QA vocabulary only. End with exactly one line:

`REVIEW8 VERDICT: ACCEPT` — resolved, no regression, annex-compliant, ready to commit,
or `REVIEW8 VERDICT: REWORK(<n>) <one-line summary>` — if any real defect remains.
