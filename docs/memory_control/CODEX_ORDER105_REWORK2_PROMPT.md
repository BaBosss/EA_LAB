# CODEX TASK — ORDER-105 BUILD REWORK ROUND 2 (close the 5 review findings)

You are continuing the ORDER-105 build in repo **D:\EA_LAB** (Windows, PowerShell 5.1, git-bash). Neutral engineering language; write all report text in plain QA vocabulary. Same iron rules: **no commit/amend/reset/rebase/push; all mutable tests in GUID TEMP repos with try/finally cleanup; touch only ORDER-105 scope files; preserve other sessions' concurrent edits.**

Read: `docs/memory_control/CODEX_ORDER105_RESULT.md` section `## Independent review round 1 — 2026-07-16` (the 5 findings), the binding annex `CODEX_ORDER105_DESIGNREVIEW.md`, and the current code. The lead confirmed all 5 findings and pinned the resolutions below — implement exactly these.

Note on scope bookkeeping: `.githooks/pre-commit` is now COMMITTED (another session's `cf45bf4a` carried it, and added an ignored-return-code warning step invoking `scripts/check_verdict_kill.ps1`). Do not edit the hook in this round unless a fix strictly requires it; if you must, preserve the check_verdict_kill step verbatim.

## Fix 1 — empty-manifest first-event commit must pass (review finding 1)

Root cause per review: `Get-IndexBytes` yields no pipeline value for a zero-length blob (classic PowerShell empty-array-to-pipeline collapse) and `Test-RawPrefix` rejects a null prefix. Fix both ends: zero-length index/HEAD blobs must round-trip as a valid empty byte array (use `Write-Output -NoEnumerate` or equivalent), and a zero-length prefix is a valid raw-byte prefix of any candidate. Audit every other byte-returning helper in utility + checker for the same empty-collapse hazard.
New permanent negTest: from a committed ZERO-BYTE manifest (the exact shipped state), a utility-produced first `IDEA_CREATED` staged through a REAL hook commit passes; and the same from a zero-byte monthly file boundary if applicable.

## Fix 2 — exact, case-sensitive validation everywhere (review finding 2)

Replace case-insensitive `-match`/`-contains`/`-eq` with `-cmatch`/`-ccontains`/`-ceq` (or Ordinal `[string]` comparisons) in every identity/enum/format/path check across utility + checker shared rules: event types, actors, roles, reason codes, UUID formats (lowercase enforced), evidence/experiment/event ID prefixes, hash hex (lowercase), owner_type, month filename pattern, path rules. Sweep the whole rule engine — do not patch only the probes the review listed.
New negTests: mixed-case event type, uppercase UUID characters in each ID field, wrong-case actor/role/reason_code, uppercase hash hex — each rejected `schema_invalid`, file byte-identical.

## Fix 3 — close the narrative capacity in string fields (review finding 3)

Lead-pinned formats (schema v1, enforced case-sensitively):
- `owner_refs[].anchor`: `^[A-Za-z0-9][A-Za-z0-9#_.:\-]{0,63}$` — no spaces, max 64. Anchors are stable KEYS (e.g. `ORDER-105`, `C1-ENFORCE-SOURCEA-BINDING`), not sentence excerpts. The existence check still requires the anchor string to occur in the committed owner bytes.
- `reason_ref`: keep the structured `ORDER-|ADR-|EXP-|RUN-` prefix rule, add total length ≤ 40 and charset `^[A-Z]+-[A-Za-z0-9_.\-]{1,35}$`.
- `trial_family`: `^[a-z0-9][a-z0-9_\-]{0,31}$`.
Update both schema JSON files and the shared rule engine together (single rule source).
New negTests: anchor containing a space/sentence rejected; overlong reason_ref rejected; trial_family with spaces/uppercase rejected. Update any existing fixtures that used space-bearing anchors.

## Fix 4 — authorized recovery for a damaged CLOSED month (review finding 4)

Lead-pinned semantics: `Recover` may target ANY existing month file, not only the latest. The rebuild replaces exactly the damaged month file (preserving every independently valid event byte, as now), while the recovery event itself is appended to the CURRENT latest month (utility timestamp, normal chain rules) and must carry the target month + quarantine evidence references. The staged checker must recognize, as one authorized recovery transaction: exactly one non-latest month rewritten (valid, byte-preserving per the existing recovery validation) + the recovery event appended to the latest month + consistent manifest. Everything else about closed-month immutability stays fail-closed.
New negTests: damaged January while February is latest → non-authorized recovery rejected; authorized recovery passes a REAL hook commit; a recovery that omits one independently valid January event rejected; a "recovery" that touches two months rejected.

## Fix 5 — fixture copy-set completeness for the hook's script set (review finding 5)

In `scripts/_test/run_order103_negative_tests.ps1` (all fixture spots that materialize the hook — the same 3 locations as before): stub `scripts/check_verdict_kill.ps1` with `'exit 0'` exactly like the existing `check_state.ps1` stub (it is a repo-specific warning step whose return code the hook ignores; a stub keeps fixtures deterministic). Confirm no other `-File` target of the current committed hook is missing from fixtures. Do the same completeness check for the ORDER-105 suite's own hook fixtures and stub there too if the diagnostic appears.
Acceptance: neither suite's output contains any missing-`-File` diagnostic afterward.

## Final acceptance runs (record everything; run AFTER all fixes)

- `run_order105_negative_tests.ps1` FULL twice → ALL PASS, identical case sets (report the new total), zero scratch leftovers.
- `run_order103_negative_tests.ps1` → 41/41 (or new total if you add cases there) ALL PASS, no missing-file diagnostics.
- `run_order101_negative_tests.ps1` → run to full completion (allow up to 30 minutes) → 25 pass + only the known pre-existing failure.
- `check_taskboard_archive.ps1 -Strict` → 0 · `-Audit` → 0 · `check_state.ps1 -Strict` → CLEAN.
- Path-scoped `git status` for ORDER-105 scope: only expected files changed; no commits made.

## Deliverable

Append `## Rework round 2 — 2026-07-16` to `docs/memory_control/CODEX_ORDER105_RESULT.md`: per-finding fix description with the exact code locations, new negTest names, full gate outputs, honest loose ends. Plain QA vocabulary only. End with exactly one line:

`BUILD STATUS: DONE` or `BUILD STATUS: BLOCKED(<short reason>)`.
