# ORDER-105 Contract D build result

## Outcome

The Contract D utility, schemas, staged checker, hook integration, LF policy, empty manifest, and negative-test harness are present in the working tree. The implementation passed the post-review functional smoke cases, including real hook commits and authorized recovery. The build cannot be reported DONE because the binding acceptance gates were not all completed green, and the independent spec review identified mandatory negative-test rows that are not yet represented by explicit cases.

No commit, amend, reset, rebase, push, staging operation, real-repository Git configuration change, or real event/evidence append was performed by Codex. All mutable test scenarios used TEMP repositories.

## File-by-file summary

- `scripts/experiment_event_log.ps1`
  - Implements `Append`, `RegisterEvidence`, `Scan`, `Disable`, `Enable`, `Recover`, and `NewEventId`.
  - Uses a repository-wide exclusive `FileStream` lock at Git's private path, bounded 50 ms plus jitter retries, a 30 second default timeout, and post-lock state validation.
  - Builds canonical UTF-8/no-BOM payload bytes before installation; uses same-directory temporary files, `Flush(true)`, and replace/move installation.
  - Enforces global IDs, linear per-experiment chains, lifecycle rules, event-ID idempotency, monthly UTC rotation, committed Git evidence, canonical-owner references, tombstones, disable/re-enable authorization, and machine-readable statuses.
  - Recovery now requires the disabled sentinel, an authorized committed reference, evidence whose raw hash and size exactly identify the corrupt monthly file, preservation in order of every independently verified event byte, a valid rebuilt snapshot, and an explicit recovery event.
- `docs/memory_control/experiment_events/schema/event-v1.schema.json`
  - Strict v1 event schema with nine allowed event types, legacy-name rejection, fixed per-event field lists, `additionalProperties: false`, declarative actor/role, artifact/trial/prior, owner, reason-code, size, and lifecycle rules.
  - `reason_ref` is restricted to structured `ORDER-`, `ADR-`, `EXP-`, or `RUN-` identifiers rather than an arbitrary prose token.
- `docs/memory_control/experiment_events/schema/evidence-v1.schema.json`
  - Strict committed-Git evidence schema with content-derived ID, full commit/blob OIDs, raw SHA-256, byte size, media type, and bounded fields.
- `docs/memory_control/experiment_events/evidence-manifest.jsonl`
  - Empty tracked-manifest convention for a repository with no registered Contract D evidence yet. Populated manifests exist only in TEMP fixtures.
- `scripts/check_experiment_events.ps1`
  - Reads raw blobs from the Git index, validates the complete staged candidate across months and references, enforces manifest/latest-month raw prefix growth, closed-month immutability, schema immutability, and delete/rename rejection.
  - Recognizes only a valid physical-recovery rewrite from corrupt HEAD; it requires exact corrupt-byte evidence and byte-preservation of independently valid HEAD events.
- `.githooks/pre-commit`
  - Preserves the existing state and ORDER-103 staged checks, then invokes the ORDER-105 checker only when an experiment event/manifest/schema path is staged. Existing PowerShell fail-closed selection remains intact.
- `.gitattributes`
  - Adds only `docs/memory_control/experiment_events/** text eol=lf`.
- `scripts/_test/run_order105_negative_tests.ps1`
  - GUID TEMP root, guarded cleanup, bounded children, held-lock barrier, concurrency, atomic-fault, schema/raw serialization, Git-object reference, monthly rotation, hook, disable, and recovery cases.
  - Standards-review corrections removed `git add -A`, added exceptional-path child/lock cleanup, and changed the ordinary-commit assertion to prove the shell-level fast path.
  - Current post-review smoke case count is 60.

## Pinned decisions implemented

1. Git-only monthly JSONL plus evidence manifest; no database, external store, narrative payload, or canonical-owner write-back.
2. Event root is `docs/memory_control/experiment_events/`.
3. Monthly name is `events-YYYY-MM.jsonl`, selected from utility UTC time after lock acquisition.
4. Logs/manifest/schemas are trackable; LF is scoped; lock/temp/disabled state is Git-private.
5. Utility, checker, and suite use the exact pinned paths.
6. Event schema is v1 integer `1`; unsupported, absent, and mixed versions fail validation.
7. Evidence schema and manifest use the pinned paths.
8. Only the nine pinned v1 event names are accepted.
9. The three legacy event names are rejected by the shared schema enum.
10. Experiment IDs are lowercase UUIDv4 with `exp_`; duplicate ideas are rejected.
11. Event IDs are lowercase UUIDv4 with `evt_`, caller-stable, and globally checked across months.
12. Evidence IDs derive from raw SHA-256 and retain one canonical Git locator.
13. Every experiment uses a linear ID plus exact-payload-hash chain; stale prior is rejected.
14. One core lifecycle is enforced; amendments/tombstones are targeted optional events.
15. Idempotency is event-ID plus byte-identical canonical payload; divergent reuse conflicts.
16. Utility timestamp is fixed-millisecond UTC `Z`; equal timestamps are allowed; clock rollback is rejected.
17. Actor-role mapping is declarative and enforced.
18. Decision/control/recovery authority is restricted to the pinned owner/lead combinations; events do not grant file permissions.
19. Canonical compact fixed-order UTF-8/no-BOM/LF JSON is used and exact payload bytes are hashed.
20. Raw SHA-256 and the five fixed artifact keys are enforced with per-event nullability; directory locators are rejected.
21. Canonical-owner objects require repo-relative path, full commit/blob OIDs, raw hash, and unique anchor.
22. Per-event reason-code enums plus structured reason references are enforced; no free-form reason field exists.
23. Per-event whitelists, strict properties, bounded arrays/strings, unique evidence arrays, and forbidden ownership/narrative fields are declarative.
24. One Git-private exclusive lock uses bounded 50 ms plus jitter retries and revalidates after acquisition.
25. Candidate bytes are installed through flushed same-volume temporary files; combined evidence registration occurs before event installation and orphan manifest entries are valid.
26. Latest-month append, older-month immutability, global validation, and cross-month prior links are enforced.
27. The index-snapshot checker and production hook path are present; ORDER-103 protection remains separate.
28. Scan reports all detected bad lines plus readable good IDs; append refuses corrupt state; authorized physical recovery is separate.
29. Tombstones target ID plus line hash, cannot target self/unknown/already tombstoned events, and continue from the current tail.
30. Disable/re-enable/recovery share the lock and Git-private sentinel. Recovery preserves independently verified bytes and records a new occurrence rather than fabricating missing metadata.
31. The exact status vocabulary is used; only `appended` and `already_appended` return zero.
32. Event line, request, string, evidence-array, owner-array, and reference sizes are bounded.

## Review findings and corrections

The required two-axis review was run against the uncommitted deliverables because the user prohibited a build commit.

- Standards review found an unconditional `git add -A`, missing exceptional cleanup around the concurrency barrier, and duplicated recovery authorization validation. All three were corrected.
- Spec review found recovery did not require disabled state, did not bind quarantine evidence to corrupt bytes, did not enforce preservation in the utility, and allowed prose-like reason references. These were corrected in the utility/checker/schema and exercised by new smoke cases.
- Spec review also identified incomplete explicit negative-test coverage. Those remaining rows are listed below; they prevent a DONE result.

## Gate and suite record

### ORDER-105 suite

- Earlier full candidate run before the final review corrections: 57 cases; all functional and scratch cases passed; only shared-repository identity failed because external `HEAD` changed during the run. This is not a final-candidate acceptance run.
- Final-candidate smoke command:
  - `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1 -DevFast`
  - Exit `1`, wall time 214.6 seconds, 60 cases.
  - 59 PASS, one FAIL: `shared-repo-head-index-worktree-config-unchanged` with `head=False index=True status=True config=True`.
  - `guid-scratch-leftovers-zero` passed.
  - The external commit during this run was `324a5e6f [claude] ORDER-091C-D1d verdict + pending-limit synthesis (both threads)` at 10:06:45.
  - All functional cases passed, including valid utility hook commit, closed-month edit/delete/rename/CRLF blocks, authorized recovery hook commit, exact quarantine evidence, disabled-state recovery, nullability mutation, fault injection, and concurrency.
- Four long/smoke attempts were invalidated only by concurrent external commits to shared `HEAD`; the F14 assertion was not weakened.
- Shared `HEAD` advanced again afterward to `4a25699b [claude] ORDER-107 REOPENED: default-smoke was not a valid concept-kill (user caught it)` at 10:19:51, confirming that the repository remained actively written by another session through final gate collection.
- Required final full suite twice with identical case sets: **not achieved**.

### Existing regression suites

- ORDER-103 command was run. It exited `1` after 454.4 seconds during fixture setup with `real hook fixture baseline commit failed` and empty Git stderr. The run did not reach its 41-case summary. Its scratch directory was cleaned. The same stub script ran directly with exit 0; one Git-Bash-launched PowerShell child was observed suspended by the Windows process layer during diagnosis and was resumed, after which a later baseline setup commit still returned 1. This gate is not green.
- ORDER-101 command was run with a 900 second bound. It continued advancing through fixtures but did not finish before tool timeout (`124`, 904 seconds), so no 25/1 summary is claimed. Only descendant processes of that run were stopped and the guarded scratch path `order101_negtests_16796` was removed. This gate is not green.

### Repository consistency gates

- `check_taskboard_archive.ps1 -Strict`: exit 0; unresolved 0; integrity failures 0; manifest/index/exceptions consistency true.
- `check_taskboard_archive.ps1 -Audit`: exit 0; unresolved 0; integrity failures 0; manifest/index/exceptions consistency true.
- `check_state.ps1 -Strict`: exit 0; `CLEAN - no drift detected`.
- PowerShell parser: zero errors for utility, checker, and ORDER-105 suite.
- Both schemas parse as JSON.

### Real hook proof

The final-candidate smoke suite performed real `git commit` operations only in TEMP clones:

- utility-produced multi-month chain: passed;
- valid latest-month prefix append: passed;
- old-month edit: blocked;
- old-month deletion: blocked;
- old-month rename: blocked;
- CRLF-only staged blob drift: blocked;
- truncation/reorder/schema/manifest inconsistency: blocked;
- authorized physical recovery: passed and was explicitly recognized by the checker.

## Honest loose ends

The following acceptance work remains:

1. Run the final full ORDER-105 suite twice during a period with no other shared-repository writes; both runs must be ALL PASS, have identical case sets/counts, and leave zero scratch directories.
2. Diagnose or rerun ORDER-103 until its 41-case summary is ALL PASS. The setup-commit exit 1 must not be treated as a passing regression result.
3. Run ORDER-101 to completion and confirm exactly 25 pass plus only the known `cross-HEAD-zero-diff` failure.
4. Add explicit annex cases for true concurrent evidence registration versus referencing event append; non-tail, forward, and cycle links; duplicate-core transition separate from generic out-of-order transition; and the full amendment/tombstone authorization matrix.
5. Add explicit cases for staged-but-uncommitted evidence; missing full commit OID; missing blob OID; symlink escape; raw-text-normalization hash mismatch; and all manifest locator mismatch dimensions independently.
6. Add diagnostic cases for truncated multibyte UTF-8 and structurally valid/schema-invalid corrupt lines, including exact line numbers and readable IDs.
7. Add explicit rollback cases for a nonterminal experiment surviving disable/rebuild, deterministic replay of preserved events, and rejection of a valid-looking recovery candidate that omits an independently valid occurrence.
8. Add a two-process PowerShell 5.1 byte-identity assertion independent of the existing autocrlf/idempotency fixture.
9. Re-run final status/numstat after all gates without concurrent work. The real repository `HEAD` changed repeatedly due other sessions during this build, although Codex made no commits.

BUILD STATUS: BLOCKED(partial: final suites and mandatory negative-test rows remain)

## Rework round 1 — 2026-07-16 (Codex partial + Claude lead takeover)

**How this round ran:** Codex applied most rework edits (F14 concurrent-writer-tolerant assertion, missing negTest rows → suite 60→84 cases, ORDER-103 fixture checker copy in 3 spots) then died on repeated `Selected model is at capacity` (server-side, not quota) after 203k tokens, before running final gates or writing this section. Claude (lead) verified the landed edits, then diagnosed and closed the remaining failures itself. Norton AV interfered twice mid-day (quarantined `check_precommit_staged.ps1` — auto-restored, hash verified against HEAD — and later `run_order103_negative_tests.ps1` mid-run; user added exclusions + restored from quarantine; the restored file was the authoritative Codex version, fix intact).

**Two real defects found and fixed by Claude after the restore (both in `scripts/_test/run_order103_negative_tests.ps1`):**
1. **Missing fixture dependency:** `check_experiment_events.ps1:19` dot-sources `scripts/experiment_event_log.ps1` (shared rule engine per annex F08); the fixture copy-sets carried the checker but not the utility → hooked commits in temp repos failed on a missing `-File` target. Reproduced in an isolated temp repo (exact line-19 error). Fix: `experiment_event_log.ps1` added to all three fixture copy-sets. The checker's missing-dependency fail-closed behavior is correct and was not changed.
2. **Latent pre-existing fixture bug exposed today:** `New-RealHookFixture` regenerates the 3 protected artifacts from the index and commits them as a baseline, assuming the regen always differs from HEAD. Since commit `883f3402` (2026-07-16) HEAD's artifacts are generator-fresh, so the regen is byte-identical, `git add` stages nothing, and the plain `git commit` exits 1 ("nothing to commit") with empty stderr — the exact mysterious `real hook fixture baseline commit failed:` both Codex and Claude hit. Fix: `--allow-empty` on the baseline commit (the fixture only needs a commit point on a consistent base). This also explains why the same fixture worked throughout the ORDER-103 build era (artifacts were stale then) and started failing only this morning.

**Final gate record (all run by Claude on the final candidate):**
- ORDER-105 suite FULL ×2: **84 cases ALL PASS both runs, case-sets byte-identical (diff of sorted case names = empty)**, zero scratch leftovers. Amended F14 shared-repo case passes under live concurrent commits from other sessions (head_scope_safe semantics).
- ORDER-103 suite: **41/41 ALL PASS** (with the two fixture fixes above).
- ORDER-101 suite: **25 PASS + exactly the known pre-existing `cross-HEAD-zero-diff` failure** — matches acceptance.
- Live gates: `check_taskboard_archive -Strict` = 0 · `-Audit` = 0 · `check_state -Strict` = CLEAN.
- Parser: 0 errors across utility/checker/both suites.
- **Independent hand-driven canary (Claude, not the suite's code path):** fresh temp repo → utility `Append` of a valid `IDEA_CREATED` → `{"status":"appended"}` exit 0 → owner_ref re-resolved via `git rev-parse <commit>:<path>` + `git cat-file` (blob OID match, anchor found in committed bytes, no narrative fields on the event) → forbidden-field probe (`verdict:"PASS"`, fresh event_id) → `{"status":"schema_invalid","details":{"message":"$ has unknown field 'verdict'"}}` exit 1, monthly file byte-count unchanged (1 line).
- Real repo hygiene: `evidence-manifest.jsonl` = 0 bytes (no real events, no backfill); working tree contains only ORDER-105 deliverables + the two 101/103 fixture-related fixes; no commits made outside lead-authored ones.

BUILD STATUS: DONE

## Independent review round 1 — 2026-07-16

This review read ORDER-105 rev01, the binding decisions #1–32 and missing-test matrix, the prior build record, and §20.7–20.8 at `4eb839d`, then traced the utility, both schemas, checker, hook, LF rule, manifest, and both test suites from the actual working tree. Claims in the prior result were not treated as evidence.

### Independent reproductions

- Real lock contention: three independent PowerShell processes attempted appends while the production lock was deliberately held. All three reported a positive wait count; the final scan returned three parseable, unique events.
- Idempotency: the initial append returned `appended`; three byte-identical retries returned `already_appended`; the same ID with a different valid payload returned `event_id_conflict` without adding another event.
- Damaged-line recovery: a committed fixture log containing one valid line plus one damaged line rejected recovery by `codex/peer_engineer`, accepted the corresponding `claude/lead_judge` recovery with exact quarantine evidence, and then passed a real hook commit with the recovery transaction recognized.
- Closed-month behavior: a real hook commit accepted utility-produced January and February files, then rejected a schema-valid edit to January with `closed month ... is immutable`.
- Ownership-content probe: an explicit `result` property was rejected as `schema_invalid`, but a full result sentence placed in the otherwise valid `owner_refs[].anchor` string was accepted and appended.
- Evidence durability: existing ignored and uncommitted files that were absent from the referenced commit both returned `reference_invalid`.
- Exact-schema probe: lowercase event type plus uppercase UUID characters, actor, role, and reason code was accepted with `appended`/exit 0, although v1 specifies lowercase IDs and exact enum values.
- Empty-manifest first-event probe: with the required committed zero-byte manifest, a utility-produced `IDEA_CREATED` staged through a real hook was rejected with `evidence manifest is not a raw-byte prefix extension of HEAD`.
- All independent fixtures used GUID directories under `$env:TEMP` and were removed.

### Defects found

1. **The required empty manifest blocks the first real event commit.** `Get-IndexBytes` yields no pipeline value for a zero-length blob, and `Test-RawPrefix` rejects a null prefix. The committed build manifest is intentionally 0 bytes, so the first otherwise-valid event cannot pass the production hook. The permanent suite seeds a non-empty manifest before its real-hook cases and does not exercise this initial state.
2. **Schema comparisons are not exact.** The custom validator uses PowerShell's case-insensitive `-match`, `-contains`, and related comparisons for regexes, enums, required/allowed names, actor-role rules, reason codes, and path rules. The independent mixed-case event was accepted. This does not meet pinned lowercase/exact-format decisions #10–12, #17, and #19–23.
3. **The ownership-content rule is incomplete.** Rejection is based mainly on property names. `owner_refs[].anchor` permits a 128-character value containing spaces, so a unique result sentence from the owner file can be copied into a valid event. Similar broad token capacity remains in `reason_ref` and `trial_family`. The accepted anchor probe conflicts with the required stable anchor/key reference and no copied result narrative.
4. **Physical recovery is limited to the latest/current month.** The utility gives the recovery event the current utility timestamp but appends it to `RecoveryMonth`; an earlier month therefore fails month/file validation. Independently, the checker rejects any changed non-latest month before calling its recovery recognizer. The same-month recovery case passes, but a damaged closed month has no accepted recovery path.
5. **ORDER-103 hook fixtures still omit one invoked production script.** The hook always invokes `scripts/check_verdict_kill.ps1`, while `New-TempHookRepo` and the historical binding overlay do not copy or stub it. Both ORDER-105 and ORDER-103 gate output contain the missing-`-File` diagnostic, yet the fixture commit passes because that warning step's return code is intentionally ignored. The requested copy-set completeness condition is therefore not met.

The checker does dot-source `experiment_event_log.ps1`, and event/schema/snapshot validation is genuinely shared for annex F08. The remaining recovery-preservation check is duplicated between utility and checker, which is a consistency risk but is not counted separately above.

### Gate results

- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1`: exit 0 in 544.9 s; `CASE COUNT: 84`; `ALL CASES PASSED`; `guid-scratch-leftovers-zero` passed; an independent TEMP enumeration also returned 0 matching leftovers.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1`: exit 0 in 370.1 s; all 41 runtime cases passed. The output nevertheless contains the missing `check_verdict_kill.ps1` diagnostic described above.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1`: the command exceeded a 1,804 s bound and returned 124 without its final case table. Its process completed shortly afterward, but the buffered final output was unavailable; therefore the recorded 25-pass plus known `cross-HEAD-zero-diff` result is not independently confirmed by this run. The exact scratch directory created by this review run was removed after the process ended.
- `check_taskboard_archive.ps1 -Strict`: exit 0; unresolved 0; integrity failures 0; generated artifacts consistent.
- `check_taskboard_archive.ps1 -Audit`: exit 0; unresolved 0; integrity failures 0; generated artifacts consistent.
- `check_state.ps1 -Strict`: exit 0; `CLEAN - no drift detected`.
- PowerShell parser errors: 0 for the utility, checker, ORDER-105 suite, and modified ORDER-103 suite. Both schemas parse as JSON. The real manifest remains 0 bytes.

### Fixture and scope assessment

`--allow-empty` is correct for `New-RealHookFixture`: it only establishes a baseline commit after regenerating artifacts and is executed before the hook is enabled. It does not relax any later ORDER-103 assertion. Adding the event checker and its dot-sourced utility fixed the two stated fixture dependencies, but the copy-sets remain incomplete because `check_verdict_kill.ps1` is still absent.

The review started at `826cc1dfb5ff6779172d9f7d7191f5e99a02fe0b`. While the long gates ran, another session advanced shared HEAD to `a5cbd1ef621d3b8d366cded47de22aefdfd0cde6` with four `[claude]` commits. This review made no commit, staging change, repository configuration change, amend, reset, rebase, or push; the index remained empty. Because of those concurrent commits, an absolute “repository history unchanged during review” assertion is not true, although no history change came from this review.

Repo-wide `git status --porcelain` continues to contain unrelated concurrent edits described in the prompt. Path-scoped status for ORDER-105 contains only `.gitattributes`, the modified ORDER-103 suite, the utility/checker/new ORDER-105 suite, the event schema/manifest directory, and this result file. The ORDER-105 hook block was already present in committed history at `cf45bf4a` before this review, so `.githooks/pre-commit` is not an uncommitted path despite the stated candidate scope.

REVIEW1 VERDICT: REWORK(5) exact schema matching, narrative exclusion, empty-manifest first commit, closed-month recovery, and hook-fixture completeness remain incorrect

## Rework round 2 — 2026-07-16 (Codex code edits + Claude gate/report takeover)

**How this round ran:** Codex applied all 5 code fixes for the review-round-1 findings, then died on `Selected model is at capacity` (server-side) after 1.24M tokens — before running the final gate suites or writing this section (same wrapper-exits-0-but-report-missing gotcha as the build round; the deliverable code did land). Claude (lead) verified the landed edits, ran every gate itself, and wrote this section. This is the last order under the "Codex builds" routing; from the next order Claude writes important code and Codex is the blind auditor only (PROJECT_STATE decision log, commit 283d341d).

**The 5 review findings — fix verified in code by Claude:**
1. **Empty-manifest first commit (finding 1):** `Get-IndexBytes`/`Get-HeadBytes` now return zero-length blobs via `Write-Output -NoEnumerate` (no empty-array pipeline collapse); `Test-RawPrefix` treats a zero-length prefix as a valid prefix. Independent hand-driven canary (not the suite path): committed 0-byte manifest → utility `Append` of first `IDEA_CREATED` = `appended`/exit 0 → **real `git commit` through the production hook = exit 0**. The exact review-blocking defect is closed.
2. **Exact case-sensitive validation (finding 2):** shared rule engine swept to `-cne`/`-ceq`/`-cmatch`/`-ccontains` (124 case-sensitive comparisons; grep for the insensitive forms in the rule paths = 0). New negTests reject mixed-case event type, uppercase-UUID IDs, wrong-case actor/role/reason_code, uppercase hash hex.
3. **Narrative capacity closed (finding 3):** schema v1 + rule engine now bound `owner_refs[].anchor` to `^[A-Za-z0-9][A-Za-z0-9#_.:\-]{0,63}$` (no spaces, ≤64), `reason_ref` to a length-capped structured prefix form, `trial_family` to a lowercase token. Independent canary: an event carrying the sentence `REJECT because PF 0.82 blowup` in `anchor` = `schema_invalid`/exit 1, monthly file byte-count unchanged. The ownership-leak path the reviewer exploited is closed.
4. **Closed-month recovery (finding 4):** `Recover` accepts any `RecoveryMonth`; it rewrites exactly the damaged (possibly closed) month with byte preservation while appending the recovery event to the current latest month (new `recovery_target_month` field), and the staged checker recognizes that one authorized two-file transaction. New negTests: authorized closed-January recovery appends to February and passes the real hook; a recovery omitting an independently valid January event is rejected; closed-month recovery still requires valid authorization + quarantine reference.
5. **Fixture completeness (finding 5):** `scripts/_test/run_order103_negative_tests.ps1` now stubs `scripts/check_verdict_kill.ps1` (`exit 0`) in all hook-materializing fixtures (grep count 3), matching the `check_state.ps1` stub pattern; no missing-`-File` diagnostic remains in either suite's output.

**Final gate record (all run by Claude on the final candidate):**
- ORDER-105 suite FULL ×2: **99 cases ALL PASS both runs, case-sets byte-identical** (was 84; +15 new negTests for findings 1–5), zero scratch leftovers.
- ORDER-103 suite: **41/41 ALL PASS**, no missing-`-File` diagnostic.
- ORDER-101 suite: **25 PASS + exactly the known pre-existing `cross-HEAD-zero-diff` failure**.
- Live gates: `check_taskboard_archive -Strict` = 0 · `-Audit` = 0 · `check_state -Strict` = CLEAN.
- Parser: 0 errors across utility/checker/both suites; both schemas parse as JSON; real `evidence-manifest.jsonl` still 0 bytes (no real events, no backfill).
- Scope: working tree = ORDER-105 deliverables + the two 101/103 fixture files only; no commits outside lead-authored ones.

BUILD STATUS: DONE

## Independent review round 2 — 2026-07-16

This review re-read the round-1 findings, the round-2 claims, pinned decisions #1–32, the candidate implementation and schemas, the modified ORDER-103 fixtures, and §20.7–20.8 at `4eb839d`. Recorded evidence was not treated as proof. All mutable reproduction used GUID-named repositories under `%TEMP%`; the real repository index and configuration were not changed.

### Independent acceptance reproductions

1. **Finding 1 — resolved.** In a fresh repository with a committed 0-byte `evidence-manifest.jsonl`, `Append` produced the first `IDEA_CREATED` with exit `0`, status `appended`. Staging only the utility-produced month and running a real hook commit returned exit `0`; the hook printed `PASS`.
2. **Finding 2 — resolved.** Six separate mutations were sent through `Append`: `Idea_Created`, an uppercase character in the UUID, `Codex`, `Peer_Engineer`, `Experiment_Initiated`, and uppercase artifact-hash hex. Every call returned exit `1`, status `schema_invalid`; the target month remained absent, which is byte-identical to its pre-call state.
3. **Finding 3 — resolved for the reported acceptance cases.** Anchors `ANCHOR IDEA` and `REJECT because PF 0.82 blowup` both returned exit `1`/`schema_invalid` without creating the month. An overlength `reason_ref` was rejected; the shared validator returned two format/length errors for a 33-character `trial_family`. A normal `ANCHOR_IDEA` reference resolved against the committed owner blob and appended with exit `0`/`appended`.
4. **Finding 4 — resolved for the requested January-to-February path.** A fresh repository was built with valid January and February events, then January was committed with a damaged line and exact quarantine bytes. `codex/peer_engineer` recovery returned exit `1`/`reference_invalid` and did not change January. After authorized disable, an empty January candidate returned exit `1`/`reference_invalid` and did not change January. Authorized recovery returned exit `0`/`appended`, reported `2026-01` to `2026-02`, preserved January exactly, retained February as a byte prefix, and passed a real hook commit with `recognized authorized recovery`.
5. **Finding 5 — resolved.** `scripts/_test/run_order103_negative_tests.ps1` contains three `check_verdict_kill.ps1` stubs, one in each hook-materializing fixture. Neither the ORDER-105 nor ORDER-103 captured output contained a missing-`-File` diagnostic.

The independent fixture harnesses removed their GUID roots (`LEFTOVER=False`). The production checker dot-sources `experiment_event_log.ps1` and reads the same staged schemas, so event/schema/reference rules have one implementation source. The requested empty-file, CRLF, month-boundary, and independently valid-event omission/reorder cases also passed the permanent suite and the hand-built January/February fixture.

### New correctness and robustness issues

1. **Normal append accepts a recovery-labelled event without the recovery preconditions.** On a valid log, a `physical_recovery` `AMENDMENT_ADDED` with `claude/lead_judge`, no evidence IDs, a normal `taskboard_order` owner, and no disabled state returned exit `0`/`appended`; a real hook commit also returned exit `0`. `Append` therefore records physical recovery without the authorization reference, quarantine evidence, damaged state, or disabled state required by the recovery contract. The split is at `scripts/experiment_event_log.ps1` lines 340–345 and 799–810; the stricter checks exist only under `Recover` at lines 812–841.
2. **A two-file closed-month recovery can stop after rewriting only the first file.** With the supported `after_temp_flush_before_replace` fault applied to the February installation, `Recover` returned exit `1`/`integrity_corrupt`, January had already been rewritten to the clean bytes, and February remained byte-identical. A retry returned exit `1`/`reference_invalid` because the snapshot was now valid. The two installations at lines 862–863 therefore do not behave as one recoverable transaction and can leave the recovery occurrence unrecorded.
3. **A final LF passes the bounded token regex.** A fresh `IDEA_CREATED` with `reason_ref` equal to `ORDER-X` followed by LF returned exit `0`/`appended`. PowerShell/.NET `$` matches before a final newline, so the schema patterns used with `-cmatch` do not enforce an absolute token end. The same pattern construction is used by `reason_ref`, `trial_family`, and `anchor`; an absolute-end rule or explicit control-character rejection is needed.

The utility/checker shared-rule arrangement is otherwise consistent, and the five round-1 defects are closed in their stated acceptance cases. I made a genuine additional pass through rejection handling, recovery ordering, reference resolution, raw-byte parsing, rotation, and hook materialization; the three issues above are the remaining reproducible incorrect behaviors found.

### Gates

- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1` run 1: exit `0`, 99 `[PASS]`, `CASE COUNT: 99`, `ALL CASES PASSED`, missing-`-File` false, ORDER-105 scratch leftovers `0`.
- The same ORDER-105 command run 2: exit `0` in 656.3 seconds, 99 `[PASS]`, `CASE COUNT: 99`, `ALL CASES PASSED`, missing-`-File` false, leftovers `0`. Both runs executed the same fixed 99-case list and produced the same case count/set.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1`: exit `0` in 420.3 seconds, 41 `[PASS]`, `ALL CASES PASSED`, missing-`-File` false, leftovers created by this run `0`.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1`: no final table was obtained. The wrapper reached the allowed 1,804-second bound and the child remained active without a summary; the review-created process tree was stopped and only its exact `order101_negtests_22360` scratch directory was removed. The recorded 25-pass plus known `cross-HEAD-zero-diff` result is therefore not independently confirmed by this round. An older unrelated `order101_negtests_24984` directory was preserved.
- `check_taskboard_archive.ps1 -Strict`: exit `0`, unresolved `0`, integrity failures `0`, generated artifacts consistent.
- `check_taskboard_archive.ps1 -Audit`: exit `0`, unresolved `0`, integrity failures `0`, generated artifacts consistent.
- `check_state.ps1 -Strict`: exit `0`, `CLEAN - no drift detected`.
- PowerShell parser errors: `0` in the utility, checker, ORDER-105 suite, and modified ORDER-103 suite. Both schemas parsed as JSON. The real evidence manifest remained 0 bytes.

### Scope and repository state

The review began at `d85cf5e8dc7f05bdf910869e067d296cf187cac6`. A concurrent `[claude]` commit advanced HEAD to `2072477fe5ad33a3eeab7999b6c9fc194934d988`; the start commit remains its ancestor. This review made no commit, amend, reset, rebase, push, staging change, or real-repository configuration change. `git diff --cached --quiet` returned `0`.

Repo-wide `git status --porcelain` contained 83 entries because the unrelated concurrent edits described in the task were present, so a repo-wide “only ORDER-105” statement is not true. Path-scoped status contained only `.gitattributes`, `scripts/_test/run_order103_negative_tests.ps1`, this result file, the experiment-event directory, the ORDER-105 suite, checker, and utility. `.githooks/pre-commit` was already committed and unchanged.

REVIEW2 VERDICT: REWORK(3) recovery preconditions are avoidable through normal append, two-file recovery can stop half-complete, and token regexes accept a final LF

## Rework round 3 — 2026-07-16 (Claude fix of review-round-2 findings; first order under the Claude-writes/Codex-audits routing)

Review round 2 returned REWORK(3) with all five round-1 findings confirmed resolved. The three new findings were fixed by Claude (the routing flipped this session: Claude writes important code, Codex is the blind auditor — PROJECT_STATE decision log 2026-07-16, commit 283d341d). All edits are in `scripts/experiment_event_log.ps1` and the ORDER-105 suite; no schema regeneration was needed.

**Finding 1 — physical_recovery reason_code was appendable without recovery preconditions.** Fix: the normal `Append` command now rejects `reason_code=physical_recovery` and any event carrying `recovery_target_month` (`scripts/experiment_event_log.ps1`, Append branch). A physical_recovery occurrence can be minted only by the `Recover` command, which enforces disabled state + control authorization + exact quarantine-byte binding. Independent hand-driven canary: a `physical_recovery` event through `Append` → `schema_invalid` "only valid through the Recover command"; a non-recovery event carrying `recovery_target_month` → `schema_invalid`; a clean normal event still appends.

**Finding 2 — two-file closed-month recovery could stop half-complete, leaving the recovery unrecorded.** Fix: (a) install order reversed so the recovery RECORD (event month) is written first and durable, then the target month is rewritten — a fault can no longer lose the occurrence; (b) a resume path: if a re-run finds the recovery event (caller-stable event_id) already present in the corrupt snapshot, it skips re-minting (which would duplicate the id) and only completes the target rewrite, returning `resumed=true`. Same-month recovery stays a single atomic install. New permanent negTest `fault-interrupted-two-file-recovery-record-durable-then-resume-completes`: `after_temp_flush_before_replace` fault → `fault=exit1, recordDurable=True, targetCorrupt=True`; re-run → `finish=exit0, resumed=True, janClean=True`, and a real hook commit passes. The pre-existing recovery cases (authorized closed-January recovery, replay determinism, omission rejection, two-month rewrite rejection) all still pass (no-regression 99→100).

**Finding 3 — token regexes accepted a trailing newline** (.NET `$` matches before a final `\n`). Fix: the shared string-validation point rejects any patterned string value containing a control character `[\x00-\x1f]`, closing the loophole for every field at once (anchor, reason_ref, trial_family, ids, hashes). Canary: `reason_ref="ORDER-105\n"` → `schema_invalid`; an anchor with an embedded newline → `schema_invalid`.

**Final gate record (all run by Claude):**
- ORDER-105 suite FULL ×2: **100 cases ALL PASS both runs, case-sets byte-identical** (99 + the new resume case), zero scratch leftovers.
- ORDER-103 suite: **41/41 ALL PASS** (re-run after the finding-2 edit). ORDER-101 suite: **25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure** (re-run after the finding-2 edit).
- Live gates: `check_taskboard_archive -Strict` = 0 · `check_state -Strict` = CLEAN. Parser: 0 errors. Real `evidence-manifest.jsonl` still 0 bytes.
- Scope unchanged: ORDER-105 deliverables + the two 101/103 fixture files; no commits outside lead-authored ones.

BUILD STATUS: DONE (pending blind review round 3)

## Independent review round 3 — 2026-07-16

This review re-read independent-review round 2, rework round 3, pinned decisions #1–32, the utility, checker, both schemas, the 100-case suite, and design source §20.7–20.8 at `4eb839d`. Recorded gate results were not treated as proof. Mutable reproduction used a separately initialized GUID-named repository under `%TEMP%`; its root and harness were removed afterward. The real repository index and local configuration were not changed.

### Independent acceptance reproductions

The direct fixture invoked the candidate in the same form as:

`powershell.exe -NoProfile -File scripts/experiment_event_log.ps1 -RepoRoot <TEMP-GUID> -Command <Append|Recover> ...`

1. **Round-2 finding 1 — resolved.** `Append` of an `AMENDMENT_ADDED` carrying `reason_code=physical_recovery` returned non-zero/`schema_invalid`. A non-recovery amendment carrying `recovery_target_month` also returned non-zero/`schema_invalid`. Mixed-case `Physical_Recovery` and mixed-case `Recovery_Target_Month` probes were rejected by schema validation, so the exact Append guard could not be bypassed by case changes. The authorized `Recover` path remained usable and completed through a real hook commit.
2. **Round-2 finding 2 — still incorrect in the new resume branch.** The requested ordering and ordinary resume behavior were reproduced: after `-TestFaultPoint after_temp_flush_before_replace`, output was non-zero, the February recovery occurrence was durable, January remained byte-different from the clean candidate, and the recovery ID occurred exactly once. Retrying the byte-identical request returned exit `0`, `status=appended`, `resumed=true`; January became byte-identical to the clean candidate, the occurrence count remained one, authorized re-enable succeeded, and a real hook commit returned exit `0` with `recognized authorized recovery transaction`. A further call after completion returned non-zero and did not add a duplicate.

   The resume identity check is incomplete. From the same interrupted state, a retry with the same `event_id` but a changed `reason_ref` returned exit `0`, `status=appended`, `resumed=true`, and restored January. At `scripts/experiment_event_log.ps1:859–869`, the stored occurrence is compared only by `event_id`, `reason_code`, and `recovery_target_month`; the retry is not schema-validated or compared as a byte-identical canonical payload. This conflicts with pinned decision #15, which requires a non-zero conflict for the same ID with a different payload. The permanent case at `scripts/_test/run_order105_negative_tests.ps1:751–765` retries only the unchanged request and does not cover this mismatch.
3. **Round-2 finding 3 — resolved.** Append probes containing LF in `reason_ref` and in an owner `anchor` returned non-zero. Direct calls through the shared schema validator rejected an embedded LF in `trial_family`; the normal short key `walk_forward` produced no validation error. The legitimate `RECOVERY_AUTH` short anchor resolved against its committed owner blob during the end-to-end recovery. Because the affected schema patterns already permit only ASCII token characters, rejecting C0 control characters does not remove a schema-legitimate patterned value.

### Additional correctness, robustness, and consistency pass

- The mismatched-resume behavior above is a real correctness issue. It also permits an old recorded recovery ID to be reused with changed request fields; the target can be installed before a later hook check rejects the absence of a new occurrence.
- Annex F08 remains consistent: `check_experiment_events.ps1` dot-sources `experiment_event_log.ps1` and consumes the staged schema objects. No second independently maintained event/schema/reference rule table was found.
- Annex F14 is not fully met. `Invoke-Utility` at `scripts/_test/run_order105_negative_tests.ps1:107–115` starts `powershell.exe` synchronously without a finite process deadline, and `Invoke-TestGit` at lines 51–55 delegates to an unbounded synchronous Git call. The separately started children use `Wait-Child`, but these two child-call paths do not. This is a remaining suite-robustness inconsistency and needs bounded process execution for every child.
- No other Append-guard workaround, double-install, skipped-target state for an unchanged retry, inappropriate control-character rejection, or utility/checker rule-source duplication was found after reviewing the changed branches and exercising the probes above.

### Gates

- `powershell.exe -NoProfile -File scripts/_test/run_order105_negative_tests.ps1`, run 1: exit `0` in 675.1 seconds; `CASE COUNT: 100`; `ALL CASES PASSED`; `guid-scratch-leftovers-zero`; no ORDER-105 scratch root remained.
- The same ORDER-105 command, run 2: exit `0` in 673.1 seconds; `CASE COUNT: 100`; `ALL CASES PASSED`; zero leftovers. The 99 detail-form final pass names extracted from each log were sequence-identical (`set_diff=0`); the remaining count is the suite's detail-less pass line, and both runner summaries reported the same fixed 100-case count.
- `powershell.exe -NoProfile -File scripts/_test/run_order103_negative_tests.ps1`: exit `0` in 423.3 seconds; 41-case suite; `ALL CASES PASSED`.
- `powershell.exe -NoProfile -File scripts/_test/run_order101_negative_tests.ps1`: no final table was obtained within the allowed 1,804-second wrapper deadline. The child continued progressing through fixture cases and exited on its own later, but its output channel was no longer available; therefore the expected 25-pass plus only `cross-HEAD-zero-diff` result is **not independently confirmed by round 3**. The exact review-created `order101_negtests_21992` directory was removed after the process ended; the older unrelated `order101_negtests_23924` directory was preserved.
- `powershell.exe -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict`: exit `0`; integrity failures `0`; manifest/index/exceptions checks clean.
- `powershell.exe -NoProfile -File scripts/check_taskboard_archive.ps1 -Audit`: exit `0`; integrity failures `0`; manifest/index/exceptions checks clean.
- `powershell.exe -NoProfile -File scripts/check_state.ps1 -Strict`: exit `0`; `CLEAN - no drift detected`.

### Scope and repository state

The review began at `d93382c7dcdbd86d261be4713b65de4d4dc03a32`. The initial index was empty and the local-config identity was recorded. Repo-wide `git status --porcelain` contained 85 entries, including many unrelated concurrent edits and untracked files described in the task, so the requested repo-wide statement that only ORDER-105 deliverables and two test-suite files are changed is not true. The ORDER-105 path-scoped entries were `.gitattributes`, `scripts/_test/run_order103_negative_tests.ps1`, this result file, `docs/memory_control/experiment_events/`, `scripts/_test/run_order105_negative_tests.ps1`, `scripts/check_experiment_events.ps1`, and `scripts/experiment_event_log.ps1`; `run_order101_negative_tests.ps1` was not modified.

This review made no commit, amend, reset, rebase, push, staging change, or repository-configuration change. Its only real-working-tree write was this requested result-section append.

REVIEW3 VERDICT: REWORK(2) recovery resume accepts a different payload for an existing event ID, and two suite child-call paths lack finite deadlines

## Rework round 4 — 2026-07-17 (Claude fix of review-round-3 findings)

Review round 3 returned REWORK(2). Both findings were in code Claude added in round 3; both fixed by Claude (Claude-writes/Codex-audits routing).

**Finding 1 — the recovery resume path compared only event_id, not the full payload**, so a retry with the same event_id but a different payload was silently accepted as a resume (violating pinned decision #15). Fix (`scripts/experiment_event_log.ps1`, resume branch): reuse the exact normal-append idempotency check — re-timestamp the retried request with the recorded occurrence's timestamp, schema-validate, and byte-compare the canonical payload to the recorded event; any difference throws `event_id_conflict`. New permanent negTest `resume-with-same-id-different-payload-conflicts-and-does-not-install-target`: a resume retry with a changed `reason_ref` → `exit≠0, status=event_id_conflict`, and the target month is left corrupt (no partial install). The unchanged retry still completes (`resumed=true`).

**Finding 2 — two suite child-call paths lacked finite deadlines** (`Invoke-Utility` and `Invoke-TestGit` ran children synchronously with no timeout, unlike the async `Wait-Child` path). Fix (`scripts/_test/run_order105_negative_tests.ps1`): added `Invoke-BoundedProcess` — a `ProcessStartInfo` + `Quote-ProcessArgument` launcher (same robust quoting as `Start-UtilityProcess`) with a `WaitForExit(deadline)` + kill and asynchronous pipe draining (so a full pipe buffer can't deadlock the wait). Both `Invoke-Utility` (utility children, `$ChildTimeoutSeconds`) and `Invoke-TestGit` (git children, incl. hook commits, `max($ChildTimeoutSeconds,120)`) now run bounded. Env is passed to the child process directly rather than mutating the parent environment. This was the highest-risk change (argument passing); the full suite re-run proves it did not break any call.

**Final gate record (all run by Claude):**
- ORDER-105 suite FULL ×2: **101 cases ALL PASS both runs, case-sets byte-identical** (99 + the two new recovery cases), zero scratch leftovers.
- ORDER-103 suite: 41/41 ALL PASS. ORDER-101 suite: 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- Live gates: `check_taskboard_archive -Strict` = 0 · `-Audit` = 0 · `check_state -Strict` = CLEAN. Parser: 0 errors. Real `evidence-manifest.jsonl` still 0 bytes.
- Scope: ORDER-105 deliverables + the two 101/103 fixture files only; no commits outside lead-authored ones.

BUILD STATUS: DONE (pending blind review round 4)

## Independent review round 4 — 2026-07-17

This review re-read independent-review round 3, rework round 4, pinned decisions #1–32, the utility, checker, both schemas, the changed test-suite paths, and design source §20.7–20.8 at `4eb839d`. Recorded evidence was not treated as proof. All mutable reproduction used GUID-named repositories under `%TEMP%`; review-created fixture roots were removed afterward. The real repository index and local Git configuration were not changed.

### Independent acceptance reproductions

The recovery fixture was a newly initialized two-month repository. It contained a January `IDEA_CREATED` and February `HYPOTHESIS_REGISTERED`, committed evidence and owner references, a damaged January log, quarantine evidence matching the damaged bytes, and an authorized disabled state. The utility was invoked as:

`powershell.exe -NoProfile -File scripts/experiment_event_log.ps1 -RepoRoot <TEMP-GUID> -Command Recover ... -TestFaultPoint after_temp_flush_before_replace`

1. **Round-3 finding 1 — partially resolved.** The injected interruption returned non-zero, left January damaged, and installed the February recovery occurrence. An unchanged retry from a copy of that interrupted state returned exit `0`, `status=appended`, `resumed=true`, and restored January byte-for-byte. A second copy retried the same `event_id` with only `reason_ref` changed: exit was non-zero, status was `event_id_conflict`, and January remained byte-identical to its interrupted damaged state. A normal `Append` using an existing idea ID with changed `reason_ref` also returned `event_id_conflict` without changing the log. The permanent suite additionally confirmed one recovery occurrence after resume.

   The full pinned behavior is still incomplete. A third copy changed the recorded recovery request's `reason_code` from `physical_recovery` to `logical_correction` while retaining the same `event_id`. It returned non-zero but status `reference_invalid`, not `event_id_conflict`; January was not installed. The request-specific checks at `scripts/experiment_event_log.ps1:851–852` run before the existing-ID branch, and the recorded-event check at lines 861–862 can also return `reference_invalid` before the canonical comparison. Pinned decision #15 says every same-ID/different-payload request is an `event_id_conflict`. The new permanent case changes only `reason_ref`, so it does not cover this ordering gap.

2. **Round-3 finding 2 — the named paths are resolved, but another suite child path remains unbounded.** A direct probe loaded the candidate `Invoke-BoundedProcess`, `Invoke-Utility`, and `Invoke-TestGit` functions. A utility JSON request path containing spaces reached the child intact and returned its expected `schema_invalid` malformed-JSON result. A Git repo-relative path containing spaces round-tripped exactly through `git add -- <path>` and `git ls-files -- <path>`. A Git failure returned exit `128` with captured output. A child writing 200,000 bytes to each of stdout and stderr returned exit `7`, and both 200,000-byte streams were captured. A child sleeping for five seconds under a one-second deadline was stopped in 1.04 seconds with the deadline diagnostic. These results confirm finite execution, argument quoting, output draining, and exit-code capture for `Invoke-Utility` and `Invoke-TestGit`.

   The additional pass found `Stage-And-Check` at `scripts/_test/run_order105_negative_tests.ps1:273–278` still launches `powershell.exe` synchronously with `& powershell.exe` and no finite deadline. It is exercised by the suite. This conflicts with annex F14's requirement that every suite child have a finite timeout. Routing this call through `Invoke-BoundedProcess` is still required.

### Additional correctness, robustness, and consistency pass

- The resume canonical form does not omit a schema field: it inserts the recorded timestamp, retains all request properties, validates the result, orders nested artifact/owner objects, and compares the exact canonical bytes. Unknown fields also reach validation and cause a conflict for an existing ID. The remaining identity issue is the earlier recovery-specific classification described above, not an ignored canonical field.
- `Invoke-BoundedProcess` preserved existing utility and Git argument shapes and captured non-zero exit/output correctly in the direct probes. No additional quoting or pipe-capture defect was found.
- Annex F08 still has one declarative rule source: `check_experiment_events.ps1` dot-sources `experiment_event_log.ps1` and validates with the staged schema objects. The verified-line preservation loop is duplicated between recovery and the checker, which is a maintenance consistency concern, but it is not a second schema/reference rule table.
- No other correctness, robustness, or consistency issue was found after the direct probes, source review, and regression runs.

### Gates

- `powershell.exe -NoProfile -File scripts/_test/run_order105_negative_tests.ps1`, run 1: exit `0` in 679.8 seconds; `CASE COUNT: 101`; `ALL CASES PASSED`; 101 named passes; `guid-scratch-leftovers-zero`; no matching scratch root remained.
- The same ORDER-105 command, run 2: exit `0` in 683.0 seconds; `CASE COUNT: 101`; `ALL CASES PASSED`; 101 named passes; zero matching leftovers. The ordered pass-name sequences from both logs were identical.
- `powershell.exe -NoProfile -File scripts/_test/run_order103_negative_tests.ps1`: exit `0` in 418.9 seconds; 41 pass lines, zero fail lines; `ALL CASES PASSED`; no matching scratch root remained.
- `powershell.exe -NoProfile -File scripts/_test/run_order101_negative_tests.ps1`: no final table was obtained within the 1,904-second outer deadline. The child continued beyond 34 minutes, so the review stopped only its own PID 17296 and removed only `order101_negtests_17296` plus its review log. The older unrelated `order101_negtests_25952` was preserved. Therefore the expected 25-pass plus only `cross-HEAD-zero-diff` result is **not independently confirmed by round 4**.
- `powershell.exe -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict`: exit `0`; integrity failures `0`; manifest/index/exceptions checks clean.
- `powershell.exe -NoProfile -File scripts/check_taskboard_archive.ps1 -Audit`: exit `0`; integrity failures `0`; manifest/index/exceptions checks clean.
- `powershell.exe -NoProfile -File scripts/check_state.ps1 -Strict`: exit `0`; `CLEAN - no drift detected`.

### Scope and repository state

The review began and ended at `d93382c7dcdbd86d261be4713b65de4d4dc03a32`; `git log <baseline>..HEAD` was empty and `git diff --cached --name-status` was empty. Path-scoped `git status --short` showed only `.gitattributes`, `scripts/_test/run_order103_negative_tests.ps1`, `scripts/_test/run_order105_negative_tests.ps1`, this result file, the event-log directory/schemas/manifest, the event utility, and the event checker. `run_order101_negative_tests.ps1` and `.githooks/pre-commit` were clean. Repo-wide status had 86 entries from unrelated concurrent work, which were ignored and preserved.

This review made no commit, amend, reset, rebase, push, staging change, branch change, or repository-configuration change. Its only real-working-tree write was this requested result-section append.

REVIEW4 VERDICT: REWORK(2) recovery does not classify every same-ID/different-payload retry as event_id_conflict, and Stage-And-Check still launches an unbounded checker child

## Rework round 5 — 2026-07-17 (Claude fix of review-round-4 findings)

Review round 4 returned REWORK(2); both were refinements of the round-4 code, fixed by Claude.

**Finding 1 — not every same-id/different-payload retry classified as `event_id_conflict`.** A resume retry that changed `reason_code` (physical_recovery→logical_correction) returned `reference_invalid`, because the recovery-request-shape validation ran before the existing-id branch. Fix (`scripts/experiment_event_log.ps1`): the existing-id detection now runs FIRST — immediately after reading the request, before any recovery-request validation. If the event_id is already recorded, classification is by byte-identity alone (schema failure or any byte difference → `event_id_conflict`); only a byte-identical retry proceeds as a resume; the recovery-request-shape validation now runs only on the fresh-event_id path. New permanent negTest `resume-with-same-id-changed-reason-code-is-conflict-not-reference-invalid`: a changed `reason_code` retry → `event_id_conflict`, target left corrupt. The changed-`reason_ref` case from round 4 still passes.

**Finding 2 — one more unbounded suite child.** `Stage-And-Check` still launched `check_experiment_events.ps1` via `& powershell.exe` with no deadline. Fix: routed through `Invoke-BoundedProcess` like the other child paths. A source scan confirms no remaining `& powershell.exe`/unbounded synchronous child in the suite.

**Final gate record (all run by Claude):**
- ORDER-105 suite FULL ×2: **102 cases ALL PASS both runs, case-sets byte-identical** (100 + the two same-id-conflict cases from rounds 4–5), zero scratch leftovers.
- ORDER-103 suite: 41/41 ALL PASS. ORDER-101 suite: 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- Live gates: `check_taskboard_archive -Strict` = 0 · `-Audit` = 0 · `check_state -Strict` = CLEAN. Parser: 0 errors. Real `evidence-manifest.jsonl` still 0 bytes.
- Scope: ORDER-105 deliverables + the two 101/103 fixture files only; no commits outside lead-authored ones.

BUILD STATUS: DONE (pending blind review round 5)

## Independent review round 5 — 2026-07-17

This review re-read independent-review round 4, rework round 5, pinned decisions #1–32, the candidate utility/checker/suite and both schemas, and §20.7–20.8 from `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md`. Recorded results were not treated as proof. Independent mutable fixtures used GUID-named repositories under `%TEMP%` and were removed in `finally` cleanup.

### Round-4 finding acceptance checks

The independent fixture created a committed two-month chain, damaged the January target, registered the exact damaged bytes as quarantine evidence, disabled logging with a committed authorization reference, and invoked:

`powershell.exe -NoProfile -File scripts/experiment_event_log.ps1 -RepoRoot <TEMP-GUID> -Command Recover ... -TestFaultPoint after_temp_flush_before_replace`

The injected interruption returned exit `1`/`integrity_corrupt`, left January damaged, and left the February recovery occurrence durable. Copies of that state produced:

- unchanged request: exit `0`, `status=appended`, `resumed=true`, January restored byte-for-byte;
- changed `reason_ref`: exit `1`, `status=event_id_conflict`, January unchanged and still damaged;
- changed `reason_code`: exit `1`, `status=event_id_conflict`, January unchanged and still damaged;
- byte-identical request matching the recorded non-recovery `HYPOTHESIS_REGISTERED` event: exit `1`, `status=reference_invalid`, no `resumed` result, January unchanged;
- fresh event ID with an otherwise recovery-shaped request containing an unknown field: exit `1`, `status=schema_invalid`, January unchanged.

Therefore round-4 finding 1 is resolved for all requested cases: existing-ID payload classification now precedes recovery-request-shape validation, a changed `reason_code` no longer diverts to `reference_invalid`, a non-recovery occurrence is not silently resumed, and a fresh ID still reaches full schema validation.

Round-4 finding 2 is also resolved. `Stage-And-Check` calls `Invoke-BoundedProcess`; that wrapper uses `WaitForExit($TimeoutSeconds*1000)` with a default 45-second deadline. PowerShell AST inspection found no direct `git`, `powershell.exe`, or `Start-Process -Wait` command in the suite. The only direct child launch is the asynchronous three-writer `Start-Process` at line 364, and each process is later bounded by `WaitForExit(600000)` with cleanup. `Invoke-TestGit`, `Invoke-Utility`, `Wait-Child`, and `Stage-And-Check` all have finite deadlines.

### New correctness and consistency findings

1. **Post-replace recovery retry is misclassified.** A second independent two-month fixture invoked Recover with `-TestFaultPoint after_replace`. The first call returned exit `1`/`integrity_corrupt`, but January was already restored and `Scan` returned exit `0`, confirming that the recovery occurrence and target replacement were complete. A byte-identical retry then returned exit `1`/`reference_invalid`. `scripts/experiment_event_log.ps1:826` rejects a valid snapshot before reading/classifying the request at lines 851–875. This conflicts with pinned decision #15's same-ID/byte-identical idempotency contract and leaves a caller unable to distinguish completed recovery from an invalid request after this supported fault point. The permanent suite covers `after_replace` for ordinary Append, not Recover.

2. **A pending recovery accepts a fresh ID that the staged checker rejects.** From the interrupted-before-replace state, a valid fresh recovery request was chained to the durable recovery occurrence and given a new event ID. Recover returned exit `0`/`appended`, installed January, and the resulting live snapshot validated with two `physical_recovery` occurrences. Staging the two months and manifest then made `check_experiment_events.ps1` exit `1`: `recovery transaction must append exactly one recovery event to the current latest month`. The utility therefore accepts a second recovery occurrence that its required staged checker will not accept. This conflicts with pinned decisions #27 and #30 and makes a utility-produced state uncommittable. The pending transaction must either require the original stable-ID resume or utility/checker behavior must be made consistent.

No additional issue was found in the bounded-process wrappers. Annex F08 remains singular: both runtime and staged checks use the versioned schema objects, and `check_experiment_events.ps1` dot-sources `experiment_event_log.ps1` and calls the shared `Invoke-ValidateEventSnapshot`; no second schema/reference rule table was found. PowerShell parser errors were `0` for the utility, checker, and ORDER-105 suite; both schema files parsed as JSON.

### Gates

- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1`, run 1: exit `0` in 688.0 seconds; `CASE COUNT: 102`; `ALL CASES PASSED`; `guid-scratch-leftovers-zero`.
- The same command, run 2: exit `0` in 688.5 seconds; the same 102-case set; `ALL CASES PASSED`; `guid-scratch-leftovers-zero`. No matching suite or independent-review scratch directory remained.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1`: exit `0` in 421.1 seconds; 41/41; `ALL CASES PASSED`.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1`: no final table within the requested 30-minute allowance; the outer command ended at 1,804.1 seconds. Only this run's process tree was stopped and only `order101_negtests_15000` was removed; the older unrelated `order101_negtests_4688` was preserved. The expected 25-pass plus only `cross-HEAD-zero-diff` result is therefore not independently confirmed by round 5.
- `powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict`: exit `0`, integrity failures `0`.
- `powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Audit`: exit `0`, integrity failures `0`.
- `powershell -NoProfile -File scripts/check_state.ps1 -Strict`: exit `0`, `CLEAN - no drift detected`.

### Scope and repository state

The review began at `d93382c7dcdbd86d261be4713b65de4d4dc03a32`. Two unrelated Claude commits occurred concurrently during the long gate runs (`f4ecdd3a` and `14a7feb5`); neither changed an ORDER-105 candidate path. Current HEAD is `14a7feb5e2b64582d2f7f31e7c5e28ec76caf4f9`. The review itself created no commit or history/config/index change; `git diff --cached --name-status` remained empty.

Path-scoped `git status --short` showed only `.gitattributes`, `scripts/_test/run_order103_negative_tests.ps1`, `scripts/_test/run_order105_negative_tests.ps1`, this result file, the event schemas/manifest directory, the event utility, and the event checker. `scripts/_test/run_order101_negative_tests.ps1` and `.githooks/pre-commit` were clean. Unrelated working-tree changes were ignored and preserved. This requested section append was the review's only real-working-tree write.

REVIEW5 VERDICT: REWORK(2) completed recovery retries are misclassified after `after_replace`, and a pending recovery accepts a second recovery occurrence that the staged checker rejects

## Rework round 6 — 2026-07-17 (Claude — recovery state-machine restructure for review-round-5 findings)

Review round 5 returned REWORK(2). Both were recovery-subsystem edge cases (the third consecutive round to find issues there), so rather than patch another case Claude restructured the `Recover` command into one explicit state machine keyed on the target month. Both findings are consequences the restructure resolves by construction.

**The state machine (`scripts/experiment_event_log.ps1`, Recover branch).** A recovery is identified by its target month; pinned #27/#30 require exactly ONE recovery occurrence per target. After reading the request, the utility finds any recovery occurrence already recorded for the target month and branches:
- **no occurrence + fresh event_id** → require integrity-corrupt state + quarantine identifying the corrupt bytes → full path (install the record to the latest month first, then the target).
- **occurrence exists, same event_id, byte-identical retry, target already restored** → **COMPLETED**: idempotent `already_appended`, no mutation (this is exactly the state an `after_replace` fault leaves — review round 5 finding 1).
- **occurrence exists, same event_id, byte-identical retry, target still corrupt** → **RESUME**: finish the target install only.
- **occurrence exists, same event_id, byte-different retry** → `event_id_conflict` (pinned #15).
- **occurrence exists, different event_id** → `event_id_conflict` — a second occurrence would be a state the staged checker rejects ("exactly one recovery event"), so the utility now rejects it too (review round 5 finding 2). The utility's accepted states are congruent with the checker's committable states.
- **no occurrence but event_id collides with any other recorded event** → `event_id_conflict`.

The target-preservation check (recovered file keeps every independently-valid event in order) was extracted into `Assert-RecoveryPreservesTarget` and is shared by the fresh and resume paths.

**New permanent negTests:** `completed-recovery-after-replace-fault-retry-is-idempotent-already-appended` (after_replace fault → complete; retry → `already_appended`, no mutation) and `second-recovery-occurrence-for-same-target-different-id-is-conflict` (new event_id for a target with a pending occurrence → `event_id_conflict`, target untouched). All prior recovery cases (fresh authorized recovery, resume, omission rejection, two-month rewrite rejection, byte preservation) still pass.

**Final gate record (all run by Claude):**
- ORDER-105 suite FULL ×2: **104 cases ALL PASS both runs, case-sets byte-identical**, zero scratch leftovers.
- ORDER-103 suite: 41/41 ALL PASS. ORDER-101 suite: 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- Live gates: `check_taskboard_archive -Strict` = 0 · `-Audit` = 0 · `check_state -Strict` = CLEAN. Parser: 0 errors. Real `evidence-manifest.jsonl` still 0 bytes.
- Scope: ORDER-105 deliverables + the two 101/103 fixture files only; no commits outside lead-authored ones.

BUILD STATUS: DONE (pending blind review round 6)

## ⛔ BLOCKED — blind review round 6 cannot run (Codex weekly quota exhausted, resets 2026-07-23 12:33)

Rework round 6 (the recovery state-machine restructure) is built, all machine gates are green, and Claude has verified each fix by hand. Blind review round 6 was launched but **Codex hit its hard ChatGPT/Codex weekly usage limit** ("You've hit your usage limit ... try again at Jul 23rd, 2026 12:33 PM") — this is the weekly quota reset, not the transient "at capacity" server error. No independent review of the round-6 restructure has run yet.

**Decision (Claude, autonomous, 2026-07-17):** do NOT commit and do NOT close the §20.8 review gate without the blind review. This order's discipline (blind review caught a real defect in every one of rounds 1–5, including in code Claude itself wrote in rounds 3–5) is exactly what protects an infra-critical, tamper-evidence deliverable. The round-6 restructure is the single largest change and has had zero independent review. Committing it now would be "self-verify only," which this project has repeatedly paid to avoid.

**State is safe:** all ORDER-105 deliverables sit uncommitted in the working tree (ORDER-105-only paths; no other session touches them). The event log is dormant — `evidence-manifest.jsonl` is 0 bytes, no real experiments logged — so nothing depends on it and any later-found defect is fix-forward with zero data at risk.

**Options for the user to choose (surfaced; user decides):**
1. Wait for Codex quota (Jul 23) → run blind review round 6 → ACCEPT (or fix + loop) → commit + close.
2. Authorize commit now on machine-gates + Claude verification, marked "blind-review-round-6 pending," and run round 6 as a follow-up when quota returns (dormant artifact makes fix-forward safe).
3. Use a different independent reviewer if one of sufficient quality is available.

Gate summary at block time: ORDER-105 104/104 ×2 (case-sets identical), ORDER-103 41/41, ORDER-101 25 + known pre-existing, `check_taskboard_archive -Strict/-Audit` = 0, `check_state -Strict` = CLEAN, 0 parser errors.

## Independent review round 6 — 2026-07-17

This review independently re-read round 5, rework round 6, pinned decisions #1–32, the restructured `Recover` branch and `Assert-RecoveryPreservesTarget`, the staged checker, recovery tests, both schemas, and §20.7–20.8 from `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md`. Recorded results were not treated as proof. Direct reproduction used GUID-named sparse repositories under `%TEMP%`, a newly constructed two-month log with two independently valid January experiments, a committed corrupt January target, exact quarantine evidence, a committed authorization reference, and the real production hook. All review-owned fixture roots were removed in `finally` cleanup.

### Direct state-machine reproduction

The fixture invoked `powershell.exe -NoProfile -File scripts/experiment_event_log.ps1 -RepoRoot <TEMP-GUID> -Command Recover ...` directly and produced these results:

- Fresh authorized recovery: exit `0`, `status=appended`; January was restored, the recovery occurrence was appended to February, and `git commit` through `.githooks/pre-commit` exited `0` with `recognized authorized recovery transaction` and the staged checker PASS message.
- `after_replace` interruption: first call exit `1`/`integrity_corrupt` after the target was restored; an identical event request with the same recovery candidate then returned exit `0`/`already_appended`, with January and February byte-identical before/after the retry. Round-5 finding 1 is resolved for the specified retry.
- `after_temp_flush_before_replace` interruption: first call exit `1`/`integrity_corrupt`, the February recovery occurrence remained present, and January remained corrupt; an identical retry returned exit `0`/`appended` with `resumed=true`, restored January, and `check_experiment_events.ps1` exited `0`.
- Same event ID with a changed `reason_ref`: exit `1`/`event_id_conflict`, with no target installation.
- Different event ID after the target already had a recovery occurrence: exit `1`/`event_id_conflict`. A separately constructed valid candidate containing two recovery occurrences made the staged checker exit `1` with `recovery transaction must append exactly one recovery event`. Round-5 finding 2 is resolved and the intended one-occurrence rule is consistent between the utility and checker.
- A fresh recovery candidate that omitted the second independently valid January event: exit `1`/`reference_invalid` with `omits or reorders`. After an interrupted recovery, the same omission candidate on the resume path produced the same status and preservation diagnostic. The fresh and resume paths therefore exercise the shared target-preservation rule consistently.

The six requested branches did not skip the required installation, create a second occurrence, or produce a state that the staged checker refused. Annex F08 also remains singular: both runtime and staged validation load the two versioned schema objects; the checker dot-sources `experiment_event_log.ps1` and calls the shared `Invoke-ValidateEventSnapshot`; no independent checker rule table was found.

### New correctness finding

1. **A completed recovery can reinstall the target under the same occurrence.** Starting from the completed `after_replace` state, the fixture retried the byte-identical event request and same event ID but supplied a different, independently valid recovery candidate. The alternate candidate preserved the two existing January events and appended a third independent valid January idea. Recover returned exit `0`/`status=appended`, changed the January bytes, and the staged checker also exited `0`. The completed-state test at `scripts/experiment_event_log.ps1:871` requires the live target to equal the candidate supplied on the retry; when a caller supplies another valid candidate, control falls into the resume path at lines 878–884 even though the live snapshot is already valid. `Assert-RecoveryPreservesTarget` permits the valid superset, so `Install-AtomicBytes` installs the target a second time. This contradicts the rework-round-6 COMPLETED branch, which requires an idempotent `already_appended` result with no mutation once the occurrence is recorded and the target is restored. The smallest correction is to treat a valid live snapshot with the matching recorded recovery payload as completed independently of the retry's `RecoveryFilePath` (or persist and compare a recovery-candidate identity if candidate identity is intended to be part of the transaction). Add a permanent case using an alternate valid target candidate after completion.

No other misclassification, preservation gap, skip, second occurrence, or utility/checker inconsistency was found after the direct branch matrix and additional completed-state pass.

### Gates

- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1`, run 1: exit `0` in 693.1 seconds; `CASE COUNT: 104`; `ALL CASES PASSED`; `guid-scratch-leftovers-zero`.
- The same command, run 2: exit `0` in 710.7 seconds; the same 104 progress-case names in the same sequence; `ALL CASES PASSED`; `guid-scratch-leftovers-zero`. No ORDER-105 suite or independent-review scratch directory remained.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1`: exit `0` in 454.4 seconds; 41/41; `ALL CASES PASSED`.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1`: no final table within the requested allowance; the wrapper timed out at 1,804.1 seconds. Only this run's process tree (root PID 25452 and its current child) was stopped, and only `%TEMP%\order101_negtests_25452` was removed. The older unrelated `%TEMP%\order101_negtests_2344` was preserved. The recorded 25-pass plus only `cross-HEAD-zero-diff` result is not independently reconfirmed by round 6.
- `powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict`: exit `0`, integrity failures `0`.
- `powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Audit`: exit `0`, integrity failures `0`, manifest/index/exceptions rebuild checks true.
- `powershell -NoProfile -File scripts/check_state.ps1 -Strict`: exit `0`, `CLEAN - no drift detected`.
- PowerShell parser errors were `0` for the utility, checker, and ORDER-105 suite; both schema files parsed as JSON.

### Scope and repository state

The review began at `874347fbe7a1bdf891c8149725d6021adaa994c8`. Three unrelated Claude commits occurred concurrently during the long gates (`fe728565`, `0845c595`, and `2ef1fe29`); none changed an ORDER-105 candidate path. Current HEAD is `2ef1fe2924513545b30945cfd8d0db4489da4096`. This review created no commit and did not change repository history, Git configuration, or the index; `git diff --cached --name-status` remained empty.

Path-scoped `git status --short` showed only `.gitattributes`, `scripts/_test/run_order103_negative_tests.ps1`, `scripts/_test/run_order105_negative_tests.ps1`, this result file, the event schemas/manifest directory, the event utility, and the event checker. `scripts/_test/run_order101_negative_tests.ps1` and `.githooks/pre-commit` were clean. Unrelated working-tree changes and the concurrent commits were preserved. This requested section append was the review's only real-working-tree write.

REVIEW6 VERDICT: REWORK(1) a completed recovery can reinstall a different valid target candidate instead of returning idempotent already_appended

## Rework round 7 — 2026-07-17 (Claude fix of review-round-6 finding)

Review round 6 confirmed the full recovery state machine (all six branches, fresh/resume preservation consistency, utility/checker congruence) and returned REWORK(1) on one remaining classification gap: the COMPLETED test compared the live target against the RETRY's candidate file, so a byte-identical event request retried with a different-but-valid `RecoveryFilePath` fell into the resume path and reinstalled an already-completed target.

**Fix (`scripts/experiment_event_log.ps1`, COMPLETED branch):** completion is now judged from the LIVE state alone — if the recovery occurrence is recorded (byte-identical request) and the live snapshot validates, the command returns idempotent `already_appended` with zero mutation, regardless of the candidate file supplied on the retry. The candidate file only matters on the resume path (target still corrupt) and the fresh path.

**New permanent negTest** `completed-recovery-retry-with-alternate-valid-candidate-still-already-appended-no-reinstall`: after a completed (after_replace-fault) recovery, a byte-identical request retried with an alternate valid candidate (the clean target plus one extra valid event) → exit 0, `already_appended`, and both monthly files byte-identical before/after (no reinstall).

**Final gate record (all run by Claude):**
- ORDER-105 suite FULL ×2: **105 cases ALL PASS both runs, case-sets byte-identical**, zero scratch leftovers.
- ORDER-103 suite: 41/41 ALL PASS. ORDER-101 suite: 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- Live gates: `check_taskboard_archive -Strict` = 0 · `check_state -Strict` = CLEAN. Parser: 0 errors. Real `evidence-manifest.jsonl` still 0 bytes.

BUILD STATUS: DONE (pending blind review round 7)

## Independent review round 7 — 2026-07-17

This review re-read independent review round 6, rework round 7, the binding annex and pinned decisions #1–32, the complete `Recover` branch, the staged checker, the recovery cases in the ORDER-105 suite, both v1 schemas, and §20.7–20.8 from `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md`. Recorded results were not treated as proof. Mutable reproduction used GUID-named repositories under `%TEMP%`; review-owned fixtures and logs were removed in `finally` cleanup.

### Independent recovery reproduction

A fresh two-month event chain was created with the candidate utility and committed through the real `.githooks/pre-commit`. Separate corrupt-target fixtures then invoked this command shape directly:

`powershell.exe -NoProfile -File scripts/experiment_event_log.ps1 -RepoRoot <TEMP-GUID> -Command Recover -Actor claude -Role lead_judge -AuthorizationRefJsonPath <auth.json> -QuarantineEvidenceId <id> -RecoveryMonth 2026-01 -RecoveryFilePath <candidate.jsonl> -EventJsonPath <request.json> -TestUtcNow <utc> [-TestFaultPoint <point>]`

Observed results:

- `after_replace`: first call exit `1`, but the live snapshot was valid and the target was restored. Retrying the byte-identical request with the same candidate returned exit `0`/`already_appended`; January, February, and the manifest retained identical length/SHA-256 identities.
- The same completed state retried with an independently validated alternate candidate (clean January plus a second valid idea event) returned exit `0`/`already_appended`; all three live files retained identical identities. The round-6 finding is resolved: the retry did not reinstall the alternate candidate.
- The alternate candidate plus a byte-different request (`reason_ref` changed) returned `event_id_conflict`; all three live files retained identical identities.
- `after_temp_flush_before_replace`: first call exit `1`, the recovery occurrence remained in February, and January remained corrupt. The byte-identical retry returned exit `0`/`appended` with `resumed=true`, restored January byte-for-byte, and a subsequent `Scan` exited `0`.
- A separate fresh authorized recovery returned `appended`, re-enable returned `appended`, and `git commit` through the real hook exited `0` with both `recognized authorized recovery transaction` and the checker PASS line.
- A separate normal same-event-ID/different-payload append case was also exercised by the permanent suite and returned the expected conflict without file mutation.

The completed/resume classification at `scripts/experiment_event_log.ps1:857-887` now uses the recorded occurrence plus byte-identical request, then classifies from the live snapshot. Candidate bytes are consulted only when the live snapshot is invalid and installation is still required. I found no remaining Recover state that mutates a completed transaction, skips an interrupted install, creates a second accepted occurrence, or produces a state inconsistent with the staged checker.

Annex F08 remains compliant: runtime and staged validation load the two versioned schema objects; `scripts/check_experiment_events.ps1` dot-sources the utility and calls the shared `Invoke-ValidateEventSnapshot`; no second event/lifecycle/actor-role rule table was found. Runtime and checker contain parallel ordered-preservation loops for their different live/index inputs, but they are currently congruent and this is not a correctness finding.

### New QA finding

1. **The required two-run ORDER-105 gate is not repeatable in this review.** Full run 1 exited `1` after 840.8 seconds: 104 cases passed and `true-concurrent-evidence-registration-versus-referencing-event-never-dangles` failed. Full run 2 exited `0` after 786.2 seconds with `CASE COUNT: 105` and `ALL CASES PASSED`. Both runs enumerated 105 case names and reported zero suite-owned scratch leftovers, but their outcomes were not identical. The case at `scripts/_test/run_order105_negative_tests.ps1:433-442` starts two child processes behind a held lock, sleeps 500 ms, and releases the lock without an attempt/ready barrier for both children; under load, a child can begin after release and report zero waits, which makes the case fail even when the final event state is valid. A focused repeat of the same race completed 10/10 with both children observing positive waits and final event count `1`, so no production ordering defect was reproduced, but it does not erase the full-suite repeatability failure. Add a two-child ready/attempt barrier before releasing the held lock, matching the synchronized three-writer case.

### Gates

- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1`, run 1: exit `1`, 840.8 s, 105 cases, one failure named above, suite-owned scratch leftovers `0`.
- Same command, run 2: exit `0`, 786.2 s, 105 cases, `ALL CASES PASSED`, suite-owned scratch leftovers `0`. Case names/count matched run 1; outcomes did not.
- Focused concurrent evidence/reference probe: 10/10 passed; register waits `1–11`, append waits `1–10`, final event count `1`; probe scratch removed.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1`: exit `0` in 499.3 s; 41/41; `ALL CASES PASSED`.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1`: no summary within the requested allowance; the wrapper timed out at about 1,904 s. No related process remained. This review's `%TEMP%\order101_negtests_4524` was removed; the older unrelated `%TEMP%\order101_negtests_5224` was preserved. The recorded 25-pass plus only `cross-HEAD-zero-diff` result was not independently reconfirmed in round 7.
- `powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict`: exit `0`, integrity failures `0`.
- `powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Audit`: exit `0`, integrity failures `0`; manifest/index/exceptions checks true.
- `powershell -NoProfile -File scripts/check_state.ps1 -Strict`: exit `0`, `CLEAN - no drift detected`.
- PowerShell parser errors: `0` for the utility, checker, and ORDER-105 suite. Both schema files parsed as JSON.

### Scope and repository state

The review began at `754f80186aa6cc316de5030a5885a6665696c10c`. Four unrelated Claude commits occurred during the long gates (`e8e6a97a`, `7ee6bbd8`, `233b285c`, `26a25aa3`); `git diff --name-only 754f801..HEAD` had no ORDER-105 candidate-path intersection. Current HEAD is `26a25aa355da524303f090b217fb5b2537d9bb97`. This review created no commit and did not change Git history, repository configuration, or the index; `git diff --cached --name-status` remained empty.

Path-scoped `git status --short` showed only `.gitattributes`, `scripts/_test/run_order103_negative_tests.ps1`, `scripts/_test/run_order105_negative_tests.ps1`, this result file, the event schemas/manifest directory, the event utility, and the event checker. `.githooks/pre-commit` and `scripts/_test/run_order101_negative_tests.ps1` were clean. Unrelated working-tree changes and concurrent commits were preserved. This section append was the review's only real-working-tree write.

REVIEW7 VERDICT: REWORK(1) the required two-run ORDER-105 gate is timing-sensitive and produced one concurrent-case failure

## Rework round 8 — 2026-07-17 (Claude fix of review-round-7 finding)

Review round 7 confirmed the round-6 recovery fix (alternate-valid-candidate retry after completion → idempotent `already_appended`, no reinstall) and found no remaining production defect. Its single finding was TEST repeatability: the case `true-concurrent-evidence-registration-versus-referencing-event-never-dangles` started its two children behind a held lock with only a fixed 500 ms sleep before release, so under machine load a slow-starting child could first attempt the lock after release and report `lock_wait_count=0`, failing the case even though the final event state was valid.

**Fix (`scripts/_test/run_order105_negative_tests.ps1` only — no production file changed):**
- The case now launches both children through a test-owned worker script with a ready/attempt file barrier, mirroring the synchronized three-writer case in the same suite: each child dot-sources the utility, writes a READY marker, waits for a GO gate file, writes an ATTEMPT marker immediately before invoking its command (`RegisterEvidence` or `Append` via `Invoke-EventUtilityMain`). The parent releases the held lock only after BOTH children have announced their lock attempt, plus the same 600 ms settle the three-writer case uses. Both children are therefore guaranteed to observe the held lock (`lock_wait_count > 0`) regardless of machine load.
- If the barrier itself fails (ready/attempt timeout), the parent kills both children in `finally` so no orphan process or scratch leftover survives.
- `Start-UtilityProcess` gained an optional `ScriptPath` parameter to launch the worker; when omitted (every existing caller), behavior is byte-for-byte the old one (utility script + implicit `-RepoRoot`).
- The case's assertions are unchanged: register exits 0, both children observe positive `lock_wait_count`, reference status ∈ {appended, reference_invalid} with retry, final scan valid with exactly 1 event.

**Production files untouched — live SHA-256 for round-8 review comparison:**
- `scripts/experiment_event_log.ps1` = `B7740BCC20ADB3795A2F807BCB6B51106DAAC4437CC4D7EA9492F5FDD6F8AA38`
- `scripts/check_experiment_events.ps1` = `5EFEBE64AAEC174137ECEF643C4215328AC96AB4E3FCCA585F47D6A48A921616`
- `docs/memory_control/experiment_events/schema/event-v1.schema.json` = `6F7DAF0854670CAF4573CD8B40566A54B9A0E778C2F60AEE9D0295947266493A`
- `docs/memory_control/experiment_events/schema/evidence-v1.schema.json` = `453BEB17B8512ED0D457E770C09DF21594BF4C22FB471172FE4FDC849556DC7E`

**Gate record (all run by Claude after the fix):**
- Suite parser errors: 0.
- ORDER-105 suite FULL ×2: **105 cases ALL PASS both runs, exit 0 both, case-name sequences byte-identical, zero scratch leftovers.** The reworked case passed both runs with real contention telemetry: register `lock_wait_count=7` (run 1) and `16` (run 2).
- ORDER-103 suite: 41/41 ALL PASS, exit 0.
- ORDER-101 suite: 25 pass + only the known pre-existing `cross-HEAD-zero-diff` failure.
- `check_taskboard_archive.ps1 -Strict` exit 0 · `-Audit` exit 0 · `check_state.ps1 -Strict` = CLEAN exit 0.
- Real `evidence-manifest.jsonl` still 0 bytes (no-backfill preserved).

BUILD STATUS: DONE (pending blind review round 8)

## Independent review round 8 — 2026-07-17

This review re-read independent review round 7, rework round 8, the binding annex and pinned decisions #1–32, the complete reworked evidence-race case, `Start-UtilityProcess`, the corresponding three-writer worker, and the utility's direct-execution guard. Recorded outcomes were not treated as proof. Mutable reproduction used GUID-named repositories under `%TEMP%`; review-owned fixtures and logs were removed after use.

### Rework assessment

- The parent holds the repository event lock before either child starts. Each worker dot-sources the utility, writes its READY marker, waits for the GO file, and writes its ATTEMPT marker immediately before `Invoke-EventUtilityMain`. The parent waits for both READY markers, creates GO, waits for both ATTEMPT markers, waits the same 600 ms used by the existing three-writer case, and only then releases the held lock. Both children therefore announce their lock attempt before release.
- The case still checks the original behavior: evidence registration exits `0`; both initial children report positive `lock_wait_count`; the referencing append either succeeds or returns `reference_invalid`; that latter ordering is retried after registration; the first and final scans both return `0`; and the final valid snapshot contains exactly one event. A successful scan resolves evidence references, so the assertion also rejects a dangling final reference.
- If either ready/attempt barrier times out or child creation fails, the `finally` block releases the held lock, terminates every started child, waits up to five seconds, and disposes each process object. The suite-level `finally` then removes its GUID scratch tree. No review-owned child or fixture remained.
- The worker invocation is equivalent for this case to the direct `-File` form it replaced. Dot-sourcing with `-RepoRoot` loads the same functions and suppresses only the utility's bottom-level automatic call (`$MyInvocation.InvocationName -cne '.'`); the worker assigns the same command parameters and calls `Invoke-EventUtilityMain` once. The synchronized three-writer case already uses this pattern.
- `Start-UtilityProcess` adds optional `ScriptPath` at the end of its parameter list. Static inspection found ten invocation lines: only the two new evidence-race children pass `ScriptPath`; all eight existing callers omit it and retain the prior utility path plus implicit `-RepoRoot` behavior. PowerShell parser errors for the suite: `0`.

### Independent focused reproduction

A standalone runner created a new GUID-named Git repository per iteration, copied the candidate utility and schemas, committed the owner/evidence fixture, held the production event lock, and launched the same two-worker ready/GO/attempt sequence. It ran ten iterations and removed every repository in `finally` cleanup.

- Result: `10/10 PASS`.
- Register waits: `7–14`; append waits: `6–14`; both were positive in every iteration.
- The two valid orderings were observed: the first scan contained either `0` events followed by a successful retry, or `1` event immediately. Every final scan returned valid with exactly `1` event.

The round-7 repeatability finding is resolved. No production ordering issue or new QA issue was found.

### Gates

- `powershell -NoProfile -File scripts/_test/run_order105_negative_tests.ps1`, run 1: exit `0` in `732.3` seconds; `105/105` PASS; `ALL CASES PASSED`; suite-owned scratch leftovers `0`; reworked race register wait `16`.
- Same command, run 2: exit `0` in `714.6` seconds; `105/105` PASS; `ALL CASES PASSED`; suite-owned scratch leftovers `0`; reworked race register wait `15`.
- The two ORDER-105 logs each contained 105 outcome lines. Direct comparison of ordered `PASS/FAIL + case name` records produced `sequence_diff=0` and `case_set_diff=0`; the case sets and outcomes were identical.
- `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1`: exit `0` in `508.4` seconds; `41/41` PASS; `ALL CASES PASSED`.
- `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1`: no summary within the requested 35-minute allowance. The bounded wrapper stopped the review-owned child at about `2104` seconds; no related child remained. Its review-owned `%TEMP%\order101_negtests_22616` scratch was removed; two older unrelated scratch directories were preserved. The recorded 25-pass plus only `cross-HEAD-zero-diff` result was therefore not independently reconfirmed in round 8.
- `powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict`: exit `0`, integrity failures `0`.
- `powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Audit`: exit `0`, integrity failures `0`; manifest, index, and exceptions checks true.
- `powershell -NoProfile -File scripts/check_state.ps1 -Strict`: exit `0`, `CLEAN - no drift detected`.

### Production identity and scope

Live SHA-256 values matched the round-8 rework record exactly:

- `scripts/experiment_event_log.ps1`: `B7740BCC20ADB3795A2F807BCB6B51106DAAC4437CC4D7EA9492F5FDD6F8AA38`
- `scripts/check_experiment_events.ps1`: `5EFEBE64AAEC174137ECEF643C4215328AC96AB4E3FCCA585F47D6A48A921616`
- `docs/memory_control/experiment_events/schema/event-v1.schema.json`: `6F7DAF0854670CAF4573CD8B40566A54B9A0E778C2F60AEE9D0295947266493A`
- `docs/memory_control/experiment_events/schema/evidence-v1.schema.json`: `453BEB17B8512ED0D457E770C09DF21594BF4C22FB471172FE4FDC849556DC7E`

Path-scoped `git status --short` showed only `.gitattributes`, the ORDER-103 and ORDER-105 test suites, this result file, the event schemas/manifest directory, the event utility, and the event checker. `.githooks/pre-commit` and the ORDER-101 suite were clean. `git diff --cached --name-status` remained empty.

The review began at `93af9e3adc65f0925a702ee61e327f8cea2d5721`. During the long gates, seven unrelated Claude commits advanced HEAD to `1b05d5a8b63ca43b0e7ac91b6efd01ee78bb5da2`; a path-limited diff showed that none changed an ORDER-105 candidate or test path. This review created no commit and did not amend, reset, rebase, push, change repository configuration, or modify the index. Concurrent working-tree changes were preserved. This section append was the review's only real-working-tree write.

REVIEW8 VERDICT: ACCEPT
