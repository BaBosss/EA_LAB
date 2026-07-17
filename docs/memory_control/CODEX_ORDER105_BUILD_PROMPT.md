# CODEX TASK — ORDER-105 (Contract D) BUILD

You are the implementing engineer for ORDER-105 in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). Use plain, neutral engineering language throughout (frame everything as correctness/robustness/consistency work).

**Do NOT commit, amend, reset, rebase, or push anything in the real repo.** All build output stays as working-tree files; the lead will verify and commit. All tests run in throwaway temp repos under `$env:TEMP` (GUID-named scratch dirs, `try/finally` cleanup, never mutate the real repo, index, HEAD, or git config). The shared working tree contains unrelated concurrent edits from other sessions — preserve them; never `git add -A`, never touch files outside your build scope.

## Binding inputs (read all, in this order)

1. `AGENT_TASKBOARD.md` block `## ORDER-105` (rev01, near end of file) — the order.
2. **`docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md` — the BINDING ANNEX.** The lead approved all 13 findings, the full "Decisions the builder needs pinned" list #1–32, and the complete "Missing negTests" list. Implement to the annex exactly; where the original 7 acceptance criteria and the annex differ, the annex wins (its soundness matrix is the authoritative interpretation). Do not re-open pinned decisions; if one proves unimplementable as pinned, STOP that piece and report it as BLOCKED with the exact technical reason — do not silently substitute.
3. Design source: `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20.8 + §20.7.
4. Existing machinery you must extend WITHOUT regressing: `.githooks/pre-commit`, `scripts/check_precommit_staged.ps1`, `scripts/check_taskboard_archive.ps1`, and the suites `scripts/_test/run_order103_negative_tests.ps1` (41 cases) + `run_order101_negative_tests.ps1` (25 pass / 1 known pre-existing failure `cross-HEAD-zero-diff`).

## Deliverables (working-tree files, exact paths from pinned decisions)

1. `scripts/experiment_event_log.ps1` — the single locked append utility (pinned decisions #24–26, #28–31: repo-wide exclusive FileStream lock at `git rev-parse --git-path ea-lab-experiment-events.lock`, 50 ms bounded-jitter retry / 30 s timeout, prebuilt canonical bytes, same-volume temp + `Flush(true)` + atomic replace, manifest-before-event ordering, machine-readable status set `appended|already_appended|schema_invalid|reference_invalid|event_id_conflict|stale_prior|integrity_corrupt|clock_skew|disabled|lock_timeout`, only the first two exit 0). Includes: append, evidence registration, diagnostic scan, disable/re-enable (Git-private sentinel), and the authorized physical-recovery transaction (annex F04/F13).
2. `docs/memory_control/experiment_events/schema/event-v1.schema.json` + `evidence-v1.schema.json` — strict v1 schemas (pinned #6–23: per-event whitelists, `additionalProperties:false`, `*_LINKED` + `TOMBSTONE_ADDED` enum only — legacy `RESULT_ATTACHED/REVIEW_RECORDED/DECISION_SIGNED` rejected, `reason_code` enum + `reason_ref` no prose, typed canonical-owner reference objects with commit OID + blob OID + raw SHA-256 + anchor, size caps). PowerShell 5.1 has no native JSON-Schema validator: the utility and checker must consume ONE shared declarative rule source (generate the .schema.json from it, or parse the .schema.json subset you use) — two independently maintained rule sets are not acceptable (annex F08).
3. `docs/memory_control/experiment_events/evidence-manifest.jsonl` — created empty-or-absent convention defined by you; the REAL repo gets NO real events/evidence in this build (no backfill — out of scope). All populated logs exist only inside test fixtures/temp repos.
4. `scripts/check_experiment_events.ps1` — the staged-snapshot event checker (annex F02/F12: index-candidate validation, prefix-only extension of latest month, closed-month immutability, delete/rename block, cross-month ID/chain/reference validation, CRLF drift rejection, recovery-transaction recognition).
5. `.githooks/pre-commit` — extended to call the event checker when any event-log/manifest/schema path is staged; existing check_state + check_precommit_staged behavior byte-for-byte preserved otherwise; fail-closed if PowerShell missing (keep current pattern).
6. `.gitattributes` — scoped LF rule for `docs/memory_control/experiment_events/**` (do not touch other rules; create the file if absent).
7. `scripts/_test/run_order105_negative_tests.ps1` — the full suite: the annex "Missing negTests" list (all four groups: locking/concurrency/atomicity · rotation/time/IDs/chains · schema/serialization · canonical-owner/evidence + corruption/recovery/Git-enforcement/rollback) plus the annex-corrected versions of the original acceptance 1–7 (barrier + held-lock contention proof per F09, isolated byte-identity fixtures per F10, git-object-resolved canary per F11, committed-evidence checks per F05, F14 repo-hygiene assertions: GUID scratch roots, child self-timeouts, before/after HEAD/index/worktree/config match, run-twice determinism).

## Acceptance gates you must run and record before reporting

- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1` → ALL PASS, run twice, identical case sets, zero scratch leftovers.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → still ALL PASS (41) after your hook edit.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` → still 25 pass / only the known pre-existing failure.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Strict` → exit 0; same with `-Audit` → 0; `scripts/check_state.ps1 -Strict` → CLEAN.
- In a TEMP clone: a real `git commit` of a valid utility-produced event append passes the extended hook end-to-end, and a hand-edited old month / deleted month / CRLF-drifted month is blocked (the ORDER-103 lesson: the build must prove its own hook path with a real commit, not only unit checks).
- `git status --porcelain` / `git diff --numstat` at the end: only your deliverable files changed; HEAD unchanged; no commits made.

## Deliverable report

Write the full build report to `docs/memory_control/CODEX_ORDER105_RESULT.md`: file-by-file summary, every pinned decision you implemented with any technical notes, full gate/suite outputs, honest loose ends (anything partially covered — name it explicitly; unnamed gaps count as defects in the next review round), and end with exactly one line:

`BUILD STATUS: DONE` — all deliverables built, all gates green,
or `BUILD STATUS: BLOCKED(<short reason>)` — with a precise list of what remains and why.

If you approach your session limits before finishing, prioritize: utility + schemas + event checker first, then the suite groups in the annex order, and write the report with `BUILD STATUS: BLOCKED(partial: <list>)` rather than leaving no report.
