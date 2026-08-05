# ORDER-103 C1-ENFORCE rework result

Date: 2026-07-13
Agent: Codex peer engineer
Binding commit: `245f8f62c047ad843b01b1b2cfffcac3f21fc5ad`

## Outcome

Both requested blockers are closed in the real repository. The Source-A exact-identity binding was appended and committed through the production pre-commit hook together with artifacts regenerated from the staged archive snapshot. The committed binding now gives the validator a trusted `HEAD` identity, so a later working-tree mutation remains detectable even after `-Generate`.

The implementation, hook, and negative-test candidates remain uncommitted in the working tree for the required independent blind review. No push was performed, and unrelated dirty files were not staged or modified by this task.

## Blocker 1 — working-tree durability: CLOSED

Before the binding had a committed identity, a temp-clone mutation of the working-only block followed by regeneration could not be distinguished from a permitted append:

```text
powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Generate
exit=0
powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict
exit=0  # incorrect for the named tamper case
```

After commit `245f8f62`, the same direct temp-clone proof changed the unique committed binding phrase `canonical-id-wildcard hole` to `TAMPERED`, then ran the normal commands:

```text
powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Generate
exit=0
powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict
exit=2
reason: archive-working-prefix-broken; binding H2 differs from HEAD
```

The destructive proof ran only in a full clone under `%TEMP%`; the real archive was not mutated by the test.

## Blocker 2 — staged identity and real hook commit: CLOSED

The archive was staged first. Both clean-filter and index identities were the same:

```text
git hash-object --path=ARCHIVE_TASKBOARD_2026-07A.md -- ARCHIVE_TASKBOARD_2026-07A.md
ded1996b007275b726f1830b48619cfa1864595c

git rev-parse :ARCHIVE_TASKBOARD_2026-07A.md
ded1996b007275b726f1830b48619cfa1864595c
```

The validator was then regenerated from the staged/index snapshot, using `GIT::AGENT_TASKBOARD.md` and `GIT::ARCHIVE_TASKBOARD_2026-07A.md`. The manifest contained one unique archive pin equal to `ded1996b007275b726f1830b48619cfa1864595c`.

Exactly these four paths were staged:

```text
ARCHIVE_TASKBOARD_2026-07A.md
docs/memory_control/ARCHIVE_INDEX.md
docs/memory_control/ARCHIVE_MANIFEST.csv
docs/memory_control/RECONCILE_EXCEPTIONS.md
```

Production staged dry-run:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_precommit_staged.ps1
exit=0
[precommit-staged] staged archive is a valid checkpoint->HEAD->staged append-chain extension
[precommit-staged] PASS: staged generated artifacts are in sync
```

The real commit was made without `--no-verify`, with the exact required message:

```text
[claude] ORDER-103 C1-ENFORCE: append Source-A exact-identity binding for ORDER-071 (Contract C1-ENFORCE Fix 3)
```

The production hook passed `check_state`, archive chain validation, and staged artifact validation. Commit result:

```text
245f8f62c047ad843b01b1b2cfffcac3f21fc5ad
4 files changed: archive + three generated memory-control artifacts only
git rev-parse HEAD:ARCHIVE_TASKBOARD_2026-07A.md
ded1996b007275b726f1830b48619cfa1864595c
```

No post-commit re-pin was necessary.

## Identity-seam correction

The normal `-Audit`/`-Strict` artifact comparison now defaults to committed `HEAD` active/archive sources, avoiding dirty active-taskboard drift and raw working-tree CRLF identity differences. It still independently checks the real working archive against `HEAD` with canonical-LF H2-prefix semantics. `-Generate` retains FILE defaults unless explicit staged `GIT::` sources are supplied.

## Verification

### Live gates

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Strict
exit=0; unresolved=0; integrity=0

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Audit
exit=0; unresolved=0; integrity=0

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_state.ps1 -Strict
exit=0; CLEAN
```

### ORDER-103 suite

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/_test/run_order103_negative_tests.ps1
exit=0
22 PASS / 0 FAIL; ALL CASES PASSED
```

This includes the separator/H2 boundary cases, committed-binding mutation after regeneration, staged archive identity, exact Source-A binding validation, malformed/duplicate/mismatched binding negatives, ordinary commit pass, valid protected commit pass, stale/missing generated-artifact rejection, PowerShell-unavailable fail-closed behavior, and a reconstructed real binding commit through the production hook.

### ORDER-101 regression suite

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/_test/run_order101_negative_tests.ps1
exit=1
25 PASS / 1 FAIL
only failure: cross-HEAD-zero-diff (fix 2, real repo, HEAD vs 4aebbc37)
```

This is the pre-existing expected failure named in the task. No new ORDER-101 case failed. The first orchestration attempt hit its 180-second timeout; the full isolated rerun completed in 411.6 seconds and produced the result above.

### Git and scope

```text
HEAD=245f8f62c047ad843b01b1b2cfffcac3f21fc5ad
HEAD^=c948c60c6289d8e1d9b341224a4f34153b08cb9d
git diff --cached --name-only
# empty
git diff --check
exit=0
```

The commit contains only the four protected binding/artifact paths. The implementation files (`.githooks/pre-commit`, `scripts/check_taskboard_archive.ps1`, `scripts/check_precommit_staged.ps1`, and the ORDER-101/103 test scripts) remain working-tree candidates; they were intentionally not folded into the exact four-file binding commit. Numerous unrelated dirty/untracked files predated or were concurrent with this task and were left untouched. `make_status.ps1` was not run because it would write outside the order's exact allowed path set.

## Remaining review gate

The requested implementation and real binding transaction are complete, but final acceptance still requires the specified independent blind review of the uncommitted hook/checker/test candidate plus commit `245f8f62`. This report is evidence, not a lead verdict.

FINALIZE STATUS: DONE

## Rework round 2 — final blind review REWORK(5)

Date: 2026-07-13  
Agent: Codex peer engineer  
Fixed point: `245f8f62c047ad843b01b1b2cfffcac3f21fc5ad` (unchanged; no commit/amend/reset)

### Outcome and review gate

The three blockers and two major findings from `FINAL BLIND CODEX REVIEW ... = REWORK(5)` are closed in the working-tree candidate. This is implementation evidence, not an ACCEPT verdict. A further independent blind review round (round 4 of the gate) is still required before ORDER-103 can be called ACCEPT.

### Blocker 1 — protected-file hook bypass when archive is unchanged: CLOSED

Code:

- `scripts/check_precommit_staged.ps1:33,120-234` no longer exits after the chain check when `$archiveChanged` is false. Any of the five protected files now triggers staged active/archive classification, full candidate consistency, regeneration from the index snapshot, and comparison with all three staged artifact blobs.
- `scripts/check_precommit_staged.ps1:151-183` also rejects candidate active/archive state that would leave Strict non-clean (lost conserved order, closure integrity failure, or unresolved policy exception).
- `scripts/check_precommit_staged.ps1:199-225` compares exact Git blob identities after path clean filters, rather than normalized text, so a staged artifact-only byte/EOL mutation cannot hide behind line-ending normalization.

Before (fresh temp repos, real hook commits; RED run):

```text
# blind-review reproduction shape
git add docs/memory_control/RECONCILE_EXCEPTIONS.md
git commit -m tamper-artifact-only
fix2-artifact-only-change-blocks: commit exit=0; hook said artifact checks skipped

git add AGENT_TASKBOARD.md
git commit -m tamper-active-only
fix2-active-only-change-blocks:   commit exit=0; hook said artifact checks skipped
post-commit -Strict:              exit=2 in the blind-review reproductions
```

After (fresh temp repos, real hook commits):

```text
# suite invocation (the named cases create isolated clones and call real git commits)
powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1

# internal reproduction shape
git add docs/memory_control/RECONCILE_EXCEPTIONS.md
git commit -q -m fix2-artifact-only-change-blocks
fix2-artifact-only-change-blocks: commit exit=1
reason: BLOCK: staged artifact(s) inconsistent with staged archive+active

git add AGENT_TASKBOARD.md
git commit -q -m fix2-active-only-change-blocks
fix2-active-only-change-blocks: commit exit=1
reason: BLOCK: staged content fails its full candidate consistency check;
        unresolved cross-active-and-archive ORDER-071
```

### Blocker 2 — merge second-parent archive change invisible: CLOSED

Code:

- `scripts/check_taskboard_archive.ps1:532-544` reads all recorded parents for every commit in the first-parent walk.
- `scripts/check_taskboard_archive.ps1:629-641` implements the accepted conservative rule: a merge commit may exist, but its archive blob must be byte-identical to its first parent's archive blob. Any archive-changing merge fails closed with an explicit diagnostic because legitimate archive appends must be plain non-merge first-parent commits.

Before:

```text
side branch appends H2 -> master unrelated commit -> git merge --no-ff side
git merge --no-ff side -m merge-side-archive-change
merge exit=0
Invoke-ArchiveChainIntegrityCheck: IsClean=True   # incorrect
```

After (`fix1-merge-second-parent-archive-change-fails`):

```text
# suite invocation; the named case runs this merge in its temp clone
powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1
git merge -q --no-ff side -m fix1-merge-second-parent-archive-change-fails
merge exit=0
Invoke-ArchiveChainIntegrityCheck: IsClean=False
reason: archive changed via merge commit <sha> relative to first parent <sha>
        -- rejected (content may have arrived via a non-first-parent)
```

### Blocker 3 — pre-H2 bytes invisible: CLOSED

Code:

- `scripts/check_taskboard_archive.ps1:266-296` materializes the HEAD archive through Git checkout filters, matching the byte form expected in the working tree under `core.autocrlf`/attributes.
- `scripts/check_taskboard_archive.ps1:838-857` extracts the region before the first column-zero `## ` heading.
- `scripts/check_taskboard_archive.ps1:878-892` compares that preamble byte-for-byte, independently from parsed H2 blocks, and fails closed on prepend/mutation (including a one-byte EOL change).
- The real archive does have a preamble: 417 bytes in the committed LF blob and 424 checkout bytes under CRLF. HEAD is therefore materialized through Git checkout filters before exact comparison; a normal CRLF checkout passes, while any working preamble byte change fails. Committed-chain comparisons remain raw-byte prefix comparisons and already reject a committed preamble prepend.

Before:

```text
prepend TAMPER-PREAMBLE before first H2
powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict
exit=0; Working extension clean=True   # incorrect
```

After:

```text
working-tree temp clone: -Strict exit=2
reason: working archive pre-H2 preamble differs byte-for-byte from HEAD
        materialized through Git checkout filters

committed temp chain: IsClean=False
reason: archive is NOT a raw-byte prefix-extension of its parent
```

### Major 4 — regression gaps and vacuous mutation case: CLOSED

Added/repaired in `scripts/_test/run_order103_negative_tests.ps1`:

- `:232` `fix1-merge-second-parent-archive-change-fails`
- `:242,277` committed-chain and public-Strict pre-H2 tamper cases
- `:305` real temp-clone CRLF `-Strict` end-to-end pass (not identity-only)
- `:318-325` one-byte pre-H2 EOL mutation rejected end-to-end by `-Strict`
- `:578` repaired `fix2-staged-archive-mutation-blocks`: stages archive plus all three freshly generated, candidate-consistent artifacts and asserts the diagnostic is append-chain integrity, not missing artifacts
- `:590` `fix2-artifact-only-change-blocks`
- `:604` artifact-only EOL-byte mutation rejected by the real hook
- `:618` `fix2-active-only-change-blocks`

The suite also refreshes the reconstructed real binding candidate with artifacts from the current exact-binding generator before committing through the production hook.

### Major 5 — stale Source-A documentation: CLOSED in source/working artifact

- Header documentation now states exact appended Source-A binding semantics at `scripts/check_taskboard_archive.ps1:42-59`.
- The Contract C1 internal description and generator now consistently say Source A closes only exact `(kind, block_id, block_sha256)` rows; canonical id and `review_ref` are traceability, not wildcard authority (`scripts/check_taskboard_archive.ps1:1316-1319,2188-2193`).
- `docs/memory_control/RECONCILE_EXCEPTIONS.md:28,58` was regenerated in the working tree so live Strict/Audit remain zero-diff.
- Honest history note: the copy committed inside `245f8f62` still contains the old Source-A wildcard wording. It was not amended or rewritten. The corrected generated artifact remains uncommitted for the future commit that lands this rework.

### Full verification output

Live gates:

```text
powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict
exit=0; chain=True; working-extension=True; unresolved=0; integrity=0;
manifest=True; index=True; exceptions=True

powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Audit
exit=0; chain=True; working-extension=True; unresolved=0; integrity=0;
manifest=True; index=True; exceptions=True

powershell -NoProfile -File scripts/check_state.ps1 -Strict
exit=0; CLEAN
```

ORDER-103 suite (168.3 seconds, exit 0; 32/32 cases):

```text
[PASS] fix1-clean-append-new-H2-passes
[PASS] fix1-suffix-extends-last-block-without-new-H2-fails
[PASS] fix1-append-newblock-after-separator-passes
[PASS] fix1-mutate-earlier-block-fails
[PASS] fix1-truncate-append-fails
[PASS] fix1-checkpoint-missing-object-fails-closed
[PASS] fix1-checkpoint-ancestor-via-shared-root-passes-on-clean-branch
[PASS] fix1-shallow-clone-missing-checkpoint-fails-closed
[PASS] fix1-fresh-full-clone-passes
[PASS] fix1-detached-head-with-full-ancestry-passes
[PASS] fix1-merge-second-parent-archive-change-fails
[PASS] fix1-pre-h2-preamble-tamper-committed-chain-fails
[PASS] fix1-mutate-appended-block-prose-then-regen-strict-fails
[PASS] fix1-pre-h2-preamble-tamper-fails
[PASS] fix4-staged-identity-matches-git-rev-parse-colon-path
[PASS] fix4-crlf-real-strict-end-to-end-passes
[PASS] fix1-pre-h2-eol-byte-tamper-fails
[PASS] fix3-exact-binding-closes
[PASS] fix3-wrong-hash-stays-unresolved-stale
[PASS] fix3-wrong-kind-same-blockid-unknown-row-integrity
[PASS] fix3-duplicate-row-is-integrity
[PASS] fix3-unknown-target-is-integrity
[PASS] fix3-malformed-hash-is-integrity
[PASS] fix2-ordinary-commit-not-blocked
[PASS] fix2-valid-protected-commit-passes
[PASS] fix2-archive-changed-without-artifacts-blocks
[PASS] fix2-staged-archive-mutation-blocks
[PASS] fix2-artifact-only-change-blocks
[PASS] fix2-artifact-eol-byte-change-blocks
[PASS] fix2-active-only-change-blocks
[PASS] fix2-no-powershell-fails-closed-with-exact-diagnostic
[PASS] fix2-real-commit-of-binding-through-hook-passes
ALL CASES PASSED
```

ORDER-101 suite (536.3 seconds, exit 1 as expected):

```text
[PASS] clean-baseline
[PASS] delete-block
[PASS] mutate-byte
[PASS] archived-OPEN (policy, not integrity)
[PASS] extra-manifest-row
[PASS] dup-block_id
[PASS] corrupt-hash
[PASS] stale-index
[PASS] corrupt-committed-manifest-caught-by-normal-run (fix 1)
[PASS] stale-exceptions-caught-by-normal-run (fix 1)
[FAIL] cross-HEAD-zero-diff (fix 2, real repo, HEAD vs 4aebbc37)  # pre-existing only
[PASS] block_id-swap-caught-by-manifest-bijection (fix 3)
[PASS] partial-stage-archived (ORDER-103 Fix 3: bare REVIEW-id no longer closes)
[PASS] generated-extra-zero-matches (fix 3)
[PASS] generated-extra-two-matches (fix 3)
[PASS] reviewmismatch-does-not-close
[PASS] c1closure-correct-sha-closes-exactly-one-kind
[PASS] c1closure-stale-sha-stays-unresolved
[PASS] c1closure-unknown-row-is-integrity
[PASS] c1closure-duplicate-row-is-integrity
[PASS] archive-append-allowed
[PASS] archive-mutate-split-block
[PASS] archive-delete-split-block
[PASS] active-remove-nonorder
[PASS] active-order-lost
[PASS] active-order-moved-verbatim
25 PASS / 1 pre-existing FAIL; no new regression
```

### Scope, process, and hygiene

- HEAD remained exactly `245f8f62c047ad843b01b1b2cfffcac3f21fc5ad`; no commit, amend, reset, rebase, push, or `--no-verify` was performed.
- All destructive/mutation/merge reproductions ran under `%TEMP%`; the real archive and history were not mutated.
- The initial `git status --porcelain` snapshot had 63 entries. ORDER-103 implementation scope is exactly five paths: `.githooks/pre-commit`, `scripts/check_taskboard_archive.ps1`, `scripts/check_precommit_staged.ps1`, and both ORDER-101/103 test scripts. This round additionally updates the required report and the regenerated `RECONCILE_EXCEPTIONS.md` working artifact. The end snapshot has 65 entries: the generated artifact accounts for one newly dirty path and another unrelated entry appeared in the shared worktree concurrently. All other status entries are unrelated concurrent work and were not touched.
- Future commit note only: the eventual commit should include the required `Co-Authored-By` trailer and must be followed by `scripts/make_status.ps1`. Neither action was taken because this task explicitly forbids committing.
- Internal two-axis self-review found no hard standards violation; it prompted the byte-exact preamble/artifact hardening above and noted maintainability smells around duplicated candidate-generation/parsing code. It also noted inherited gaps relative to the original broader ORDER-103 test matrix; the current task's required new/repaired cases are all present and green, but this reinforces why the next independent blind review remains mandatory. This self-review is not that required blind review.

REWORK2 STATUS: DONE

## Rework round 3 — 2026-07-13 — literal first-parent checkpoint membership

### Root checkpoint continuity fix

The chain root now has to be a literal member of `git rev-list --first-parent
<HeadRef>`, not merely an ancestor reachable by any graph path.

- `scripts/check_taskboard_archive.ps1:519-537` now obtains the complete literal
  first-parent line for `HeadRef`, locates the exact checkpoint SHA in that output,
  and slices the chain only from the actual member. The old two-dot range plus
  manually prepended checkpoint can no longer invent a checkpoint-to-mainline step.
- `scripts/check_taskboard_archive.ps1:613-620` fails immediately when the commit is
  an any-path ancestor but absent from the first-parent line. The diagnostic is:
  `TRUSTED CHECKPOINT <sha> is reachable only via a non-first-parent path relative
  to <HeadRef> (for example, a merge's second parent) -- rejected, possible
  checkpoint laundering (fail-closed)`.
- No alternate walk is attempted after this result. The `Steps` collection is empty.
- No change was needed in `scripts/check_precommit_staged.ps1`: its staged path calls
  this same function with `-IncludeStaged`, so the membership gate is evaluated
  before the synthetic HEAD-to-STAGED step. Strict/Audit also call this function
  before their separate HEAD-to-working extension check.

### Before/after reproduction and regression

The new real-Git temp-repo regression is at
`scripts/_test/run_order103_negative_tests.ps1:221-238` and is named
`fix1-checkpoint-only-on-non-first-parent-fails-closed`. It creates root archive
state `v0`, a `trusted` branch checkpoint commit, a separate main-line commit, and a
`--no-ff` merge whose second parent is the checkpoint. All mutation operations are
under `%TEMP%`.

Fixture commands and observed Git results:

```text
git merge -q --no-ff trusted -m "merge trusted branch"
exit=0

git rev-list --parents -n 1 HEAD
exit=0; parents=[main-line first parent, trusted checkpoint second parent]

git rev-list --first-parent HEAD
exit=0; trusted checkpoint absent

git merge-base --is-ancestor <checkpoint> HEAD
exit=0; checkpoint is an ancestor by a non-first-parent path
```

Before the fix, exact suite command and result:

```text
powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1
exit=1
[FAIL] fix1-checkpoint-only-on-non-first-parent-fails-closed
merge_exit=0 any_path_ancestor=True literal_first_parent=False
chain_clean=True reason=
```

After the fix, the same exact command and case:

```text
powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1
exit=0
[PASS] fix1-checkpoint-only-on-non-first-parent-fails-closed
merge_exit=0 any_path_ancestor=True literal_first_parent=False
chain_clean=False
reason=TRUSTED CHECKPOINT <sha> is reachable only via a non-first-parent path
       relative to HEAD (for example, a merge's second parent) -- rejected,
       possible checkpoint laundering (fail-closed)
```

Positive first-parent coverage remains green through
`fix1-clean-append-new-H2-passes`,
`fix1-checkpoint-ancestor-via-shared-root-passes-on-clean-branch`,
`fix1-fresh-full-clone-passes`, and
`fix1-detached-head-with-full-ancestry-passes`. The production checkpoint was also
checked directly:

```text
git rev-list --first-parent HEAD
exit=0; contains 0ced19485c6c6ce9a23541f785ab82bae4fcad25

Invoke-ArchiveChainIntegrityCheck -CheckpointSha 0ced19485c6c6ce9a23541f785ab82bae4fcad25 -HeadRef HEAD
LITERAL_FIRST_PARENT=True IS_CLEAN=True STEPS=16 REASON=
```

### Completed verification

Live gates:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Strict
exit=0; chain=True; working-extension=True; unresolved=0; integrity=0;
manifest=True; index=True; exceptions=True

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Audit
exit=0; chain=True; working-extension=True; unresolved=0; integrity=0;
manifest=True; index=True; exceptions=True

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_state.ps1 -Strict
exit=0; CLEAN
```

ORDER-103 final suite completed in 149.3 seconds: **33 PASS / 0 FAIL**, exit 0,
`ALL CASES PASSED`. This is the prior 32-case suite plus the new checkpoint
non-first-parent regression.

The three fixes confirmed by the interrupted review remain green in that full run:

- `fix2-artifact-only-change-blocks` and `fix2-active-only-change-blocks` — protected
  changes still invoke full staged consistency even when the archive is unchanged.
- `fix1-merge-second-parent-archive-change-fails` — an archive-changing merge through
  a non-first parent is rejected.
- `fix1-pre-h2-preamble-tamper-committed-chain-fails`,
  `fix1-pre-h2-preamble-tamper-fails`, and `fix1-pre-h2-eol-byte-tamper-fails` —
  pre-H2 committed and working content remains covered.

ORDER-101 suite completed in 467.9 seconds: **25 PASS / 1 FAIL**, exit 1. The only
failure was the known, pre-existing `cross-HEAD-zero-diff (fix 2, real repo, HEAD vs
4aebbc37)` case; every other case passed and there was no new regression.

### Scope and handoff

- This round started at HEAD `245f8f62c047ad843b01b1b2cfffcac3f21fc5ad`.
  While the long suite was running, a concurrent Claude session added unrelated
  one-file commit `c4e1a7d610ff2387563b606509eb13c745b2161b` (`push_snap.cmd`
  only), so final HEAD is `c4e1a7d6`. This round itself performed no commit,
  amend, reset, rebase, push, or history rewrite; `245f8f62` remains unchanged as
  the direct parent of the concurrent commit. Strict/Audit/state and the production
  checkpoint check were rerun successfully against final HEAD.
- This round changed only `scripts/check_taskboard_archive.ps1`,
  `scripts/_test/run_order103_negative_tests.ps1`, and this explicitly required
  report. `scripts/check_precommit_staged.ps1` was inspected but not changed.
- The shared working tree already contained many unrelated modified/untracked files
  before this round. They were preserved; the final full status still lists them,
  while the scoped diff for this round's implementation paths contains only the
  membership fix and its regression.
- ORDER-103 is not ACCEPT yet. A further independent review round is still required.

REWORK3 STATUS: DONE

## Rework round 4 — 2026-07-13

### Permanent regression cases added

Added eight explicit cases to `scripts/_test/run_order103_negative_tests.ps1`:

1. `fix1-reordered-appends-fails` — commits two valid H2 appends, then swaps their
   established byte order; the chain rejects the rewritten prefix.
2. `fix1-archive-commits-separated-by-unrelated-commits-passes` — places an
   ordinary-file commit between checkpoint and archive append; the clean append passes.
3. `fix1-mutate-then-restore-still-caught` — verifies the final archive matches the
   checkpoint bytes while the chain still rejects the earlier mutating commit.
4. `fix1-checkpoint-not-ancestor-fails-closed` — uses a real local commit on a sibling
   branch; confirms the object exists, is not an ancestor by any path, and receives the
   distinct `NOT an ancestor` diagnostic rather than missing-object or non-first-parent
   diagnostics.
5. `fix2-protected-file-deleted-blocks` — a real commit staging deletion of
   `RECONCILE_EXCEPTIONS.md` is blocked with the protected-file deletion reason.
6. `fix2-protected-file-renamed-blocks` — a real `git mv` of `AGENT_TASKBOARD.md` is
   blocked; the hook's documented `--no-renames` scan observes the protected source as
   a deletion.
7. `fix2-mixed-protected-and-ordinary-staging-blocks-on-protected-only` — stages an
   ordinary file with an inconsistent protected artifact and confirms the protected
   artifact consistency message is the block reason.
8. `fix3-sourcea-and-sourceb-simultaneous-closure-precedence` — makes both sources
   close the same exact exception and confirms one reviewed result, zero unresolved,
   zero integrity failures, `ClosureSource=A-sourcea-binding`, and explicit reporting
   that Source B also matched without double-counting.

No requested case was treated as redundant. The suite now has 41 cases, up from 33.
Production validator, staged checker, and hook logic were not changed in this round.

### Scratch-directory cleanup

Wrapped the complete scratch-root lifetime in `try/finally`. Cleanup resolves and
validates the target as a child of `%TEMP%`, requires the
`order103_negtests_*` name, applies the Windows long-path prefix, clears read-only
attributes from cloned Git files, then calls `[IO.Directory]::Delete(path, $true)`.

The first cleanup verification correctly exposed a read-only Git object and returned
exit 1 even though all 41 cases had passed. After adding read-only normalization, stale
ORDER-103 scratch directories were removed with the same path checks and the full suite
was rerun from a zero-directory baseline. Final result:

```text
TEMP_BEFORE_COUNT=0
CASE_COUNT=41
SUITE=ALL CASES PASSED
ELAPSED_SECONDS=187.1
TEMP_AFTER_COUNT=0
ORDER103_EXIT=0
```

### Full verification output

Live gates:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Strict
STRICT_EXIT=0
chain=True; working-extension=True; unresolved=0; integrity=0;
manifest=True; index=True; exceptions=True

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Audit
AUDIT_EXIT=0
chain=True; working-extension=True; unresolved=0; integrity=0;
manifest=True; index=True; exceptions=True

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_state.ps1 -Strict
STATE_EXIT=0
CLEAN
```

ORDER-103 suite:

```text
powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1
41 PASS / 0 FAIL
ALL CASES PASSED
exit=0; elapsed=187.1s; TEMP order103* before=0 after=0
```

ORDER-101 regression suite:

```text
powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1
25 PASS / 1 FAIL
FAIL: cross-HEAD-zero-diff (fix 2, real repo, HEAD vs 4aebbc37)
exit=1; elapsed=468.0s
```

The ORDER-101 result matches the documented pre-existing baseline exactly; there are no
new failures. The shared working tree still contains unrelated edits and untracked files
from other sessions that were present before this round. This round changed only the
ORDER-103 test harness plus this required report, made no commit, and did not alter
commit `245f8f62c047ad843b01b1b2cfffcac3f21fc5ad` or repository history.

This closes both non-production items identified by review round 5. In my assessment,
no implementation item from that review remains before the lead's next ACCEPT review.

REWORK4 STATUS: DONE

## Independent review round 6 (final acceptance check) — 2026-07-14

### Review basis and code trace

I read the required project entry files, the complete `## ORDER-103` taskboard block,
all prior sections of this report, and every line of the five candidate files. I
reviewed the implementation as a fresh candidate rather than relying on the recorded
round-1 through round-5 conclusions.

The implementation paths are consistent with the specification:

- `Invoke-ArchiveChainIntegrityCheck` pins the trusted checkpoint, requires it to be
  an ancestor and a literal member of the first-parent chain, rejects archive-changing
  merge commits, and checks every checkpoint-to-HEAD archive revision as a raw-byte
  prefix extension with the required H2 boundary.
- `Invoke-ArchiveWorkingTreeExtensionCheck` separately binds the working archive to
  the checkout-filter-materialized HEAD archive, including exact pre-H2 bytes and
  canonical-LF H2 prefix blocks. Regenerating artifacts cannot authorize a changed
  established prefix.
- `.githooks/pre-commit` fails closed when PowerShell is unavailable and invokes both
  the global state check and `check_precommit_staged.ps1`. The staged checker recognizes
  all five protected coordination paths, rejects deletion/rename, reads candidate bytes
  and identities from the index, and compares regenerated artifacts after Git clean
  filters.
- Source A now closes only an exact `(kind, block_id, block_sha256)` row from a reviewed
  appended binding block. Malformed, duplicate, and unknown rows are integrity failures;
  stale hashes do not close. Source A has deterministic precedence over Source B, while
  the report records a simultaneous Source-B match without adding a second closure.

No correctness or robustness defect was found after the full trace and independent
reproduction. One explanatory section near the top of
`run_order101_negative_tests.ps1` still describes the old pre-ORDER-103 bare-REVIEW
behavior (`partial-stage-archived` as Strict 0). The executable case and its nearby
comment correctly require Strict 1, and the ORDER-103 exact-binding tests cover the new
behavior. This is a non-executable comment inconsistency, not an enforcement or
acceptance defect.

### Independent high-risk reproductions

These scenarios were constructed independently in new repositories under `%TEMP%`;
they did not call the supplied ORDER-103 suite.

```text
checkpoint reachable only through merge second parent
  merge_exit=0
  any_path_ancestor=True
  literal_first_parent=False
  chain_clean=False
  reason=TRUSTED CHECKPOINT <sha> is reachable only via a non-first-parent path
         relative to HEAD ... rejected, possible checkpoint laundering (fail-closed)

reordered established appends
  chain_clean=False
  reason=archive at <sha> is NOT a raw-byte prefix-extension of <prior-sha>
         -- earlier bytes were mutated (fail-closed; manifest regeneration cannot bless this)

mutate established bytes, then restore the checkpoint bytes
  final_matches_checkpoint=True
  chain_clean=False
  reason=the intermediate archive revision is NOT a raw-byte prefix-extension

real pre-commit hook; archive unchanged; only RECONCILE_EXCEPTIONS.md corrupted/staged
  generate_exit=0
  archive_unchanged=True
  commit_exit=1
  blocked=True
  diagnostic=[precommit-staged] BLOCK: staged artifact(s) inconsistent with staged archive+active:
```

The first draft of the independent driver accidentally named a PowerShell helper
`Git`, causing recursive function dispatch; that driver was discarded. The corrected
fresh scenarios above produced the stated results. All associated
`order103_review6_*` directories were subsequently removed with verified paths under
`%TEMP%`.

### Gates

Live archive gates, rerun after the suites:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Strict
STRICT_EXIT=0
Chain integrity (checkpoint->HEAD, first-parent) clean = True
Working extension (HEAD->FILE, canonical-LF H2 prefix) clean = True | appended_blocks=0
raw_detected=11; canonically_reviewed=11; unresolved=0; integrity failures=0
manifest bijection clean=True
index rebuild zero-diff=True
exceptions rebuild zero-diff=True
EXIT CODE: 0

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Audit
AUDIT_EXIT=0
Chain integrity (checkpoint->HEAD, first-parent) clean = True
Working extension (HEAD->FILE, canonical-LF H2 prefix) clean = True | appended_blocks=0
raw_detected=11; canonically_reviewed=11; unresolved=0; integrity failures=0
manifest bijection clean=True
index rebuild zero-diff=True
exceptions rebuild zero-diff=True
EXIT CODE: 0
```

The exact live state command did not return CLEAN because a concurrent, unrelated
working-tree edit added the Thai phrase meaning "one file" to the REWORK4 prose in
`AGENT_TASKBOARD.md`. The existing state checker interprets that phrase as a competing
entry claim. The phrase is absent from `HEAD:AGENT_TASKBOARD.md` and none of the five
candidate files introduces it.

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_state.ps1 -Strict
=== EA_LAB state consistency check (inventory-driven, ORDER-093) ===
[OK]   PROJECT_STATE.md exists (the entry point)
[OK]   PROJECT_STATE declares the DEPLOYMENTS.csv inventory pointer
[OK]   DEPLOYMENTS.csv parses (29 rows)
[OK]   inventory has all required columns
[OK]   no duplicate account|magic in inventory
[OK]   all 5 inventory accounts present in DEMO_DEPLOYMENT_PLAN
[OK]   all 27 inventory magics mapped in dashboard cohort
[OK]   no ghost dashboard map entries (all 27 map keys exist in inventory)
[OK]   all judge dates (2026-10-09) present in DEMO plan
[WARN] competing entry claim in: AGENT_TASKBOARD.md
[OK]   DEMO_DEPLOYMENT_PLAN.md has owner banner
[OK]   MASTER_BACKLOG.md has owner banner
[OK]   EA_SCORECARD_AND_REGISTRY.md has owner banner
=== 1 WARNING(s) - fix the drift above ===
STATE_EXIT=1
```

To separate that shared-worktree condition from ORDER-103, I made a fresh local clone
under `%TEMP%`, overlaid exactly the five candidate files, and ran the same command.
The temporary status contained exactly those five paths and the state gate was clean:

```text
TEMP_SCOPE
 M .githooks/pre-commit
 M scripts/_test/run_order101_negative_tests.ps1
 M scripts/check_taskboard_archive.ps1
?? scripts/_test/run_order103_negative_tests.ps1
?? scripts/check_precommit_staged.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_state.ps1 -Strict
[OK]   no competing single-entry claim (EN/TH)
=== CLEAN - no drift detected ===
TEMP_CHECK_STATE_EXIT=0
```

The live warning therefore does not identify candidate rework. The shared coordination
edit must nevertheless be resolved by its owning session before an actual commit can
pass the repository-wide hook.

### ORDER-103 negative suite

The supplied suite completed in 214.2 seconds. Complete case-status output:

```text
[PASS] fix1-clean-append-new-H2-passes
[PASS] fix1-suffix-extends-last-block-without-new-H2-fails
[PASS] fix1-append-newblock-after-separator-passes
[PASS] fix1-mutate-earlier-block-fails
[PASS] fix1-truncate-append-fails
[PASS] fix1-checkpoint-missing-object-fails-closed
[PASS] fix1-checkpoint-ancestor-via-shared-root-passes-on-clean-branch
[PASS] fix1-reordered-appends-fails
[PASS] fix1-archive-commits-separated-by-unrelated-commits-passes
[PASS] fix1-mutate-then-restore-still-caught
[PASS] fix1-checkpoint-not-ancestor-fails-closed
[PASS] fix1-shallow-clone-missing-checkpoint-fails-closed
[PASS] fix1-fresh-full-clone-passes
[PASS] fix1-detached-head-with-full-ancestry-passes
[PASS] fix1-checkpoint-only-on-non-first-parent-fails-closed
[PASS] fix1-merge-second-parent-archive-change-fails
[PASS] fix1-pre-h2-preamble-tamper-committed-chain-fails
[PASS] fix1-mutate-appended-block-prose-then-regen-strict-fails
[PASS] fix1-pre-h2-preamble-tamper-fails
[PASS] fix4-staged-identity-matches-git-rev-parse-colon-path
[PASS] fix4-crlf-real-strict-end-to-end-passes
[PASS] fix1-pre-h2-eol-byte-tamper-fails
[PASS] fix3-exact-binding-closes
[PASS] fix3-wrong-hash-stays-unresolved-stale
[PASS] fix3-wrong-kind-same-blockid-unknown-row-integrity
[PASS] fix3-duplicate-row-is-integrity
[PASS] fix3-unknown-target-is-integrity
[PASS] fix3-malformed-hash-is-integrity
[PASS] fix3-sourcea-and-sourceb-simultaneous-closure-precedence
[PASS] fix2-ordinary-commit-not-blocked
[PASS] fix2-valid-protected-commit-passes
[PASS] fix2-archive-changed-without-artifacts-blocks
[PASS] fix2-staged-archive-mutation-blocks
[PASS] fix2-artifact-only-change-blocks
[PASS] fix2-artifact-eol-byte-change-blocks
[PASS] fix2-active-only-change-blocks
[PASS] fix2-protected-file-deleted-blocks
[PASS] fix2-protected-file-renamed-blocks
[PASS] fix2-mixed-protected-and-ordinary-staging-blocks-on-protected-only
[PASS] fix2-no-powershell-fails-closed-with-exact-diagnostic
[PASS] fix2-real-commit-of-binding-through-hook-passes

ALL CASES PASSED
SUITE_EXIT=0
TEMP_BEFORE=0
TEMP_AFTER=0
```

The significant diagnostics matched the required mechanisms: the non-first-parent
case reported `any_path_ancestor=True`, `literal_first_parent=False`, and
`chain_clean=False`; mutate-then-restore reported `final_matches_checkpoint=True` and
still failed the chain; simultaneous A/B closure reported `reviewed=1`, `unresolved=0`,
`integrity=0`, `source=A-sourcea-binding`, and the no-double-count precedence note;
artifact-only, active-only, deletion, rename, mixed-stage, and missing-PowerShell cases
all blocked for their specified reasons.

An initial invocation was launched with an incorrectly short command timeout. Its child
suite continued normally, completed without intervention, and cleaned its scratch root
to zero. Because that invocation's output pipe was no longer available, the complete
suite above was then run from a verified zero-directory baseline.

### ORDER-101 regression suite

The first ORDER-101 attempt was interrupted when its process-specific `%TEMP%` root
disappeared while concurrent sessions were active; it stopped at a `ReadAllBytes` call
before producing a case summary. No candidate path performs that deletion, and the
condition did not reproduce after confirming no other ORDER-101 suite process was
running. The isolated rerun completed in 614.7 seconds with the documented baseline:

```text
OTHER_SUITE_PROCESSES=0
[PASS] clean-baseline                           audit expect=0 actual=0 | strict expect=0 actual=0
[PASS] delete-block                             audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] mutate-byte                              audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] archived-OPEN (policy, not integrity)    audit expect=0 actual=0 | strict expect=1 actual=1
[PASS] extra-manifest-row                       audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] dup-block_id                             audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] corrupt-hash                             audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] stale-index                              audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] corrupt-committed-manifest-caught-by-normal-run (fix 1) audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] stale-exceptions-caught-by-normal-run (fix 1) audit expect=2 actual=2 | strict expect=2 actual=2
[FAIL] cross-HEAD-zero-diff (fix 2, real repo, HEAD vs 4aebbc37) audit expect=0 actual=0 | strict expect=0 actual=0
[PASS] block_id-swap-caught-by-manifest-bijection (fix 3) audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] partial-stage-archived (ORDER-103 Fix 3: bare REVIEW-id match no longer closes without a binding record) audit expect=0 actual=0 | strict expect=1 actual=1
[PASS] generated-extra-zero-matches (fix 3)     audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] generated-extra-two-matches (fix 3)      audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] reviewmismatch-does-not-close (Source A id must match exactly) audit expect=0 actual=0 | strict expect=1 actual=1
[PASS] c1closure-correct-sha-closes-exactly-one-kind audit expect=0 actual=0 | strict expect=1 actual=1
[PASS] c1closure-stale-sha-stays-unresolved     audit expect=0 actual=0 | strict expect=1 actual=1
[PASS] c1closure-unknown-row-is-integrity       audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] c1closure-duplicate-row-is-integrity     audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] archive-append-allowed (ORDER-103 1b-ARCHIVE) audit expect=0 actual=0 | strict expect=0 actual=0
[PASS] archive-mutate-split-block (ORDER-103 1b-ARCHIVE) audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] archive-delete-split-block (ORDER-103 1b-ARCHIVE) audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] active-remove-nonorder (ORDER-103 1b-ACTIVE, allowed) audit expect=0 actual=0 | strict expect=0 actual=0
[PASS] active-order-lost (ORDER-103 1b-ACTIVE, integrity failure) audit expect=2 actual=2 | strict expect=2 actual=2
[PASS] active-order-moved-verbatim (ORDER-103, conserved, integrity clean) audit expect=0 actual=0 | strict expect=1 actual=1

ONE OR MORE CASES FAILED -- see above
SUITE_EXIT=1
```

This is 25 PASS / 1 FAIL. The only failure is the explicitly accepted pre-existing
`cross-HEAD-zero-diff` case; no new ORDER-101 regression appeared. Its process-specific
scratch directory was removed after the run.

### Final scope, history, and scratch confirmation

The review began and ended at the same HEAD:

```text
HEAD=0f60f072aca6df6af8753c60f8da41913b4ea5e1
PARENT=c4e1a7d610ff2387563b606509eb13c745b2161b
SUBJECT=[claude] stock tomorrow long-run: wave5_extended batch + VPS status + smoke queue (new criteria)
245f8f62c047ad843b01b1b2cfffcac3f21fc5ad^{commit}
=245f8f62c047ad843b01b1b2cfffcac3f21fc5ad
```

Candidate-specific final status and size:

```text
 M .githooks/pre-commit                                  30 insertions / 7 deletions
 M scripts/check_taskboard_archive.ps1                 694 insertions / 71 deletions
 M scripts/_test/run_order101_negative_tests.ps1        11 insertions / 4 deletions
?? scripts/check_precommit_staged.ps1                   237 lines
?? scripts/_test/run_order103_negative_tests.ps1        879 lines
```

This is exactly the requested five-file implementation scope. This report is the
separately required review deliverable. The full shared-tree status also contains the
unrelated modified, staged, and untracked files from other sessions, including new
portfolio/dashboard outputs that appeared during this long review; none was read as
candidate scope or modified by this review. Candidate tracked numstat remained
`30/7`, `694/71`, and `11/4` from the initial snapshot through the final snapshot.

Final scratch counts:

```text
order103_negtests_*=0
order103_review6_*=0
order101_negtests_*=0
```

This review made no commit, amend, reset, rebase, push, or history change and did not
alter commit `245f8f62c047ad843b01b1b2cfffcac3f21fc5ad`. The enforcement candidate is
correct, complete within its five-file scope, and ready for the lead to commit once the
unrelated live `AGENT_TASKBOARD.md` state warning is cleared by its owning session.

REVIEW6 VERDICT: ACCEPT
