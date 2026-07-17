# CODEX TASK — ORDER-105 (Contract D) INDEPENDENT REVIEW ROUND 1 (acceptance check)

You are an independent peer engineer performing a fresh correctness/robustness review of the ORDER-105 build candidate in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). Use plain, neutral engineering language throughout (frame everything as correctness/robustness/consistency verification).

**Do NOT commit, amend, reset, rebase, or push anything. Never mutate the real repo, its index, or its config.** All reproduction happens in throwaway temp repos under `$env:TEMP` (GUID names, try/finally cleanup). The shared working tree contains unrelated concurrent edits from other sessions — expected; ignore and preserve them.

## What ORDER-105 is

Contract D (MVP-1-lite Experiment Event Log): a single locked JSONL append utility, strict linked-event schemas, a committed-Git evidence manifest, a staged-snapshot event checker wired into the production pre-commit hook, and a permanent negative-test suite. The candidate sits UNCOMMITTED in the working tree:

- `scripts/experiment_event_log.ps1` (utility: Append/RegisterEvidence/Scan/Disable/Enable/Recover/NewEventId)
- `docs/memory_control/experiment_events/schema/event-v1.schema.json` + `evidence-v1.schema.json`
- `docs/memory_control/experiment_events/evidence-manifest.jsonl` (empty — no real events allowed in this build)
- `scripts/check_experiment_events.ps1` (staged checker, dot-sources the utility as its rule engine)
- `.githooks/pre-commit` (extended: existing check_state + ORDER-103 staged check preserved, then the event checker)
- `.gitattributes` (scoped LF rule for `docs/memory_control/experiment_events/**`)
- `scripts/_test/run_order105_negative_tests.ps1` (84 cases)
- plus two integration fixes inside `scripts/_test/run_order103_negative_tests.ps1` (fixture copy-sets now carry `check_experiment_events.ps1` + `experiment_event_log.ps1`; the baseline commit uses `--allow-empty`)

## Binding sources (read, in order — do not take any recorded evidence on trust)

1. `AGENT_TASKBOARD.md` block `## ORDER-105` (rev01) — order + acceptance.
2. `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md` — the binding annex: pinned decisions #1–32, missing-negTest list, soundness matrix. The build must satisfy the ANNEX, not just the original 7 criteria.
3. `docs/memory_control/CODEX_ORDER105_RESULT.md` — build + rework history, including two fixture defects diagnosed after the build (missing dot-source dependency; `--allow-empty` baseline). Treat every claim in it as unverified until you reproduce it.
4. Design source: `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20.8 + §20.7.

## Your review — reproduce independently

1. Read the actual candidate code in all deliverables. Trace real logic — do not skim. Pay particular attention to: lock acquisition/retry/timeout and the revalidate-after-lock path; atomic install ordering (manifest before event; fault points); prefix/closed-month/recovery recognition in the staged checker; schema strictness actually matching pinned decisions #8–23 (per-event whitelists, additionalProperties=false, reason_code enum, owner-ref object shape, size caps, legacy event names rejected); and that the checker + utility genuinely share ONE rule source (annex F08) rather than two drifting copies.
2. Construct your own scenarios in fresh temp repos for the highest-risk properties (do not merely re-run the suite): a concurrent append race with the real lock; an idempotent retry vs same-ID-different-payload conflict; a damaged line then non-authorized vs authorized recovery; a closed-month edit driven through a REAL `git commit` with the hook enabled; an event carrying result-narrative content (ownership-rule inconsistency) that must fail schema validation; an evidence reference to an uncommitted/ignored file that must be rejected.
3. Run the gates yourself and confirm they match the recorded claims:
   - `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1` → ALL PASS (84), zero scratch leftovers
   - `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → 41/41 ALL PASS
   - `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` → 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure
   - `check_taskboard_archive.ps1 -Strict` → 0 · `-Audit` → 0 · `check_state.ps1 -Strict` → CLEAN
4. Judge the two ORDER-103 fixture fixes on correctness: does `--allow-empty` weaken any assertion the ORDER-103 suite makes (vs merely unblocking a baseline), and are the fixture copy-sets now complete w.r.t. every script the production hook invokes?
5. Verify remaining soundness properties in neutral QA terms: every rejection path stays closed when a dependency or input is unexpected; the hook accepts only utility-produced content for event paths; no string field can carry owner-narrative content past schema validation; the rebuild path cannot unintentionally omit an independently valid event; month-boundary and line-ending edge cases behave per spec; renamed files and schema changes are handled per spec. Make a genuine effort to find any remaining defect; if you cannot, say so explicitly.
6. Confirm final scope: `git status --porcelain` shows only the ORDER-105 deliverables + the two test-suite files changed; no commit/history change occurred during your review.

## Deliverable

Append a dated section `## Independent review round 1 — 2026-07-16` to `docs/memory_control/CODEX_ORDER105_RESULT.md`: what you reproduced (commands + outputs), defects found (or explicit none-after-genuine-effort), gate results, scope confirmation. End with exactly one line:

`REVIEW1 VERDICT: ACCEPT` — correct, complete, annex-compliant, ready to commit,
or `REVIEW1 VERDICT: REWORK(<n>) <one-line summary>` — if any real defect remains.

**Report language note:** write your appended section in plain, neutral QA vocabulary (correctness/robustness/consistency verification); avoid security-flavored terms entirely.
