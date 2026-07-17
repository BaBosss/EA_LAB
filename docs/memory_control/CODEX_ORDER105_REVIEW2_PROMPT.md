# CODEX TASK — ORDER-105 (Contract D) INDEPENDENT REVIEW ROUND 2 (acceptance check)

You are an independent peer engineer performing a fresh correctness/robustness/consistency review of the ORDER-105 build candidate in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). Use plain, neutral QA vocabulary throughout — describe everything as correctness, robustness, and consistency verification. Do not use security-flavored terms.

**Do NOT commit, amend, reset, rebase, or push anything. Never mutate the real repo, its index, or its config.** All reproduction happens in throwaway temp repos under `$env:TEMP` (GUID names, try/finally cleanup). The shared working tree contains unrelated concurrent edits from other sessions — expected; ignore and preserve them.

## Context

Round 1 of this review returned REWORK(5). The five findings were: (1) the required 0-byte evidence manifest blocked the first real event commit; (2) validation was case-insensitive where v1 requires exact lowercase/enum matching; (3) `owner_refs[].anchor` (and `reason_ref`/`trial_family`) had enough free capacity to hold an owner sentence, conflicting with the reference-only ownership rule; (4) physical recovery only worked for the latest month, so a damaged closed month had no accepted recovery path; (5) ORDER-103 hook fixtures omitted `scripts/check_verdict_kill.ps1`. All five were reworked. Your job is to independently confirm — from fresh reproduction, not by trusting the record — whether all five are correctly resolved and nothing regressed.

## What to read (do not take recorded evidence on trust)

1. `docs/memory_control/CODEX_ORDER105_RESULT.md` — sections `## Independent review round 1` (the five findings) and `## Rework round 2` (claimed resolutions).
2. `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md` — binding annex: pinned decisions #1–32.
3. The candidate code: `scripts/experiment_event_log.ps1`, `scripts/check_experiment_events.ps1`, both schema JSON files, `scripts/_test/run_order105_negative_tests.ps1`, and the two fixture edits in `scripts/_test/run_order103_negative_tests.ps1`. `.githooks/pre-commit` and `.gitattributes` are already committed.
4. Design source: `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20.7–20.8.

## Independent reproduction (construct your own fixtures; do not just re-run the suite)

For each of the five findings, build a fresh temp repo and confirm the corrected behavior directly:
1. From a committed 0-byte manifest, a utility-produced first `IDEA_CREATED` appends and passes a real hook commit (exit 0).
2. Mixed-case event type / uppercase-UUID id / wrong-case actor/role/reason_code / uppercase hash hex are each rejected with a validation status, and the target file stays byte-identical.
3. A value containing spaces or an owner sentence in `owner_refs[].anchor` is rejected by schema validation; confirm `reason_ref` and `trial_family` have bounded formats too; confirm a normal short key anchor still resolves.
4. With February as the latest month and a damaged January, an authorized recovery rewrites January (byte-preserving the valid events) and appends the recovery event to February and passes a real hook commit; an unauthorized recovery and a recovery that omits a valid January event are both rejected.
5. Neither suite's output contains a missing-`-File` diagnostic; the fixture stub for `check_verdict_kill.ps1` is present in all hook-materializing fixtures.

Then run the gates and confirm they match the record:
- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1` → ALL PASS (99), zero scratch leftovers, run twice for identical case sets.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → 41/41 ALL PASS.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` (allow up to 30 min) → 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- `check_taskboard_archive.ps1 -Strict` → 0 · `-Audit` → 0 · `check_state.ps1 -Strict` → CLEAN.

Also verify remaining soundness properties in neutral QA terms: every rejection path stays closed when a dependency or input is unexpected; the checker and utility share one rule source (no drift between the two, annex F08); no string field can carry owner-narrative content past validation; the rebuild path cannot unintentionally omit or reorder an independently valid event; month-boundary, CRLF, and empty-file edge cases behave per spec. Make a genuine effort to find any remaining incorrect behavior; if you cannot after real effort, say so explicitly.

Finally confirm `git status --porcelain` shows only the ORDER-105 deliverables + the two test-suite files changed, and that no commit or history change occurred during your review (other sessions may commit concurrently; that is expected and is not your change).

## Deliverable

Append a dated section `## Independent review round 2 — 2026-07-16` to `docs/memory_control/CODEX_ORDER105_RESULT.md`: what you reproduced (commands + outputs), each finding's status (resolved / still incorrect), any new issues, gate results, scope confirmation. Plain QA vocabulary only. End with exactly one line:

`REVIEW2 VERDICT: ACCEPT` — all five resolved, no regression, annex-compliant, ready to commit,
or `REVIEW2 VERDICT: REWORK(<n>) <one-line summary>` — if any real defect remains.
