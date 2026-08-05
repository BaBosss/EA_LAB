# CODEX TASK — ORDER-103 (C1-ENFORCE) FINALIZE: regenerate artifacts, commit the binding block, prove BLOCKER 1 closed

You are a peer engineer finishing ORDER-103 in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). Read `AGENT_TASKBOARD.md` block `## ORDER-103` for full history, and `docs/memory_control/CODEX_ORDER103_REWORK_RESULT.md` (your own prior report) for exact context. Short version: you already fixed the H2-boundary self-DoS (BLOCKER 2, verified working) and added a `HEAD→working` canonical-LF block-prefix check (BLOCKER 1 partial fix) — that check correctly rejects mutation of any block that already exists at `HEAD`, but the one new appended block (`## C1-ENFORCE-SOURCEA-BINDING`) has never been committed, so it has no `HEAD` anchor yet and the reproduction test can't authenticate it. You correctly refused to hard-code a one-off hash or silently accept stale artifacts.

**The resolution (agreed by the user and lead engineer):** commit the binding block for real. Once it's a real HEAD-anchored block, your own `HEAD→working` check will protect it going forward (you already proved this works for `C1-CLOSURE`). Do this in 6 steps. **This is the actual first real commit ORDER-103 produces** — be careful, path-limited, and do not touch unrelated work.

## Step 0 — orientation (read-only, do first)
- `git status --porcelain` — note current HEAD and confirm the only relevant pending changes are: `.githooks/pre-commit`, `scripts/check_taskboard_archive.ps1`, `scripts/check_precommit_staged.ps1` (if present), `scripts/_test/run_order103_negative_tests.ps1`, `scripts/_test/run_order101_negative_tests.ps1`, `ARCHIVE_TASKBOARD_2026-07A.md` (+13/-0 append), and the 3 files under `docs/memory_control/` (`ARCHIVE_MANIFEST.csv`, `ARCHIVE_INDEX.md`, `RECONCILE_EXCEPTIONS.md`).
- **This is a SHARED WORKTREE** — another session may commit unrelated work concurrently. If you see unrelated dirty files (not in the list above), do NOT touch, stage, or commit them. If HEAD has moved since your last check, re-verify the trusted checkpoint `0ced19485c6c6ce9a23541f785ab82bae4fcad25` is still an ancestor of HEAD (`git merge-base --is-ancestor 0ced19485c6c6ce9a23541f785ab82bae4fcad25 HEAD`) before proceeding — if it is not, STOP and report (do not force anything).

## Step 1 — regenerate the 3 artifacts from STAGED identity, not the mixed HEAD/working identity
Root cause of the manifest/index mismatch you found: the on-disk artifacts were generated using `HEAD` blob identity for the archive combined with local (possibly CRLF-affected) working bytes — a mixed source. The hook correctly checks against the STAGED/index identity. Fix this properly:
1. Stage the current working-tree archive: `git add ARCHIVE_TASKBOARD_2026-07A.md` (this alone, nothing else yet).
2. Regenerate the manifest/index/exceptions from the **staged** content, not the working file — i.e. run the validator's `-Generate` mode using the staged blob (`git show :ARCHIVE_TASKBOARD_2026-07A.md`) as the archive source, NOT the raw working-tree `FILE:` path. If `-Generate` currently only supports `FILE:`/`HEAD:` sources, add or use a `GIT::` (staged) source spec consistent with the existing `GIT:ref:path` / `FILE:path` convention already in the script (see the param block and `Get-SourceBytes`/`Get-ArchiveContentIdentity`) — a staged ref is conventionally written `:path` in git plumbing (e.g. `git show :path`, `git rev-parse :path`); wire that in as a recognized source spec if it isn't already, rather than working around it.
3. Confirm: `git hash-object --path=ARCHIVE_TASKBOARD_2026-07A.md -- ARCHIVE_TASKBOARD_2026-07A.md` (clean-filtered working bytes) vs `git rev-parse :ARCHIVE_TASKBOARD_2026-07A.md` (staged blob, after step 1's `git add`) — these should now be the SAME oid (the `git add` normalizes CRLF→LF per `.gitattributes`/`core.autocrlf` at staging time). Use whichever one correctly represents "what will actually be committed."
4. Regenerate manifest/index/exceptions from that staged identity and overwrite the 3 files on disk.
5. `git add docs/memory_control/ARCHIVE_MANIFEST.csv docs/memory_control/ARCHIVE_INDEX.md docs/memory_control/RECONCILE_EXCEPTIONS.md`.

## Step 2 — dry-run the hook against the real staged index (no commit yet)
Run `scripts/check_precommit_staged.ps1` (or whatever the hook invokes) directly against the real repo's current index (the one you just staged in step 1) — NOT a temp clone this time, the real one. It must report PASS: chain-consistent AND artifacts match staged bytes. If it still reports a mismatch, diagnose and fix the identity/regeneration source before proceeding — do not move to Step 3 until this passes cleanly.

## Step 3 — the real atomic commit
1. Confirm staged files are EXACTLY: `ARCHIVE_TASKBOARD_2026-07A.md`, `docs/memory_control/ARCHIVE_MANIFEST.csv`, `docs/memory_control/ARCHIVE_INDEX.md`, `docs/memory_control/RECONCILE_EXCEPTIONS.md` — nothing else (`git diff --cached --stat`).
2. Commit through the real hook (do NOT use `--no-verify`): 
   ```
   git commit -m "[claude] ORDER-103 C1-ENFORCE: append Source-A exact-identity binding for ORDER-071 (Contract C1-ENFORCE Fix 3)"
   ```
3. This MUST succeed (hook passes, exit 0). If it fails, report exactly why — do not bypass.
4. Confirm afterward: `git rev-parse HEAD:ARCHIVE_TASKBOARD_2026-07A.md` equals the staged blob oid from Step 1 (atomic, single commit, no re-pin needed — this was Fix 4/Codex's original design-review item #7).

## Step 4 — prove BLOCKER 1 is now actually closed (post-commit)
Reproduce the ORIGINAL blind-review reproduction, now against the committed binding block, in a throwaway temp clone (never the real repo):
```
# clone the real repo (now with the binding committed) into $env:TEMP
# mutate prose UNIQUE to the now-committed C1-ENFORCE-SOURCEA-BINDING block, e.g.:
#   "canonical-id-wildcard hole" -> "TAMPERED"
# then:
powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Generate
powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict
# REQUIRED: strict exit = 2 (was 0 before commit; must be 2 now that the block has a HEAD anchor)
```
Update/replace the `fix1-mutate-appended-block-prose-then-regen-strict-fails` test in `scripts/_test/run_order103_negative_tests.ps1` to mutate a **committed** block (either the now-committed binding, or `C1-CLOSURE` as before — pick whichever is simplest and robust to future re-runs) and assert `strict_exit == 2`. This test must now PASS.

## Step 5 — full verification (all must be green)
1. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_taskboard_archive.ps1 -Strict` → exit 0 on the real repo (post-commit, clean state).
2. `... -Audit` → exit 0.
3. `powershell -NoProfile -File scripts/check_state.ps1 -Strict` → CLEAN.
4. `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → **ALL PASS, including the fixed mutate-then-regen case and the real-commit-through-hook case.**
5. `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` → same as before (only the pre-existing unrelated `cross-HEAD-zero-diff` failure remains).
6. `git status --porcelain` → only your intended files touched; nothing unrelated staged or committed.

## Step 6 — write the final report
Overwrite `docs/memory_control/CODEX_ORDER103_REWORK_RESULT.md` (or append a new dated section if you prefer to preserve history) with: the commit SHA you produced, before/after of both blockers with exact commands+exit codes, full suite output, and a plain statement of anything not fully closed. End with exactly one line:
`FINALIZE STATUS: DONE` or `FINALIZE STATUS: BLOCKED (reason)`.

## Hard constraints (ห้าม)
- Do NOT `--no-verify`. Do NOT force-push. Do NOT rewrite/reset/rebase any existing commit.
- Do NOT touch, stage, or commit any file outside the exact list in Step 0/Step 3.
- Do NOT edit the bytes of any existing archived block — the archive only grows by the one binding append already present, committed as-is (or with only its already-planned content, unmutated).
- If the trusted checkpoint is not an ancestor of HEAD when you check, or if unrelated concurrent changes appear mid-task (shared worktree), STOP and report — do not force through.
- All destructive/mutation tests happen in throwaway clones under `$env:TEMP`, never the real repo.
- This commit is real and visible to the team — get it right; do not commit if Step 2's dry-run hasn't passed cleanly first.

## After this
Once `FINALIZE STATUS: DONE`, the change still needs a final **blind Codex (or independent) re-review** before it's formally accepted per the project's routing (self-verification alone has missed defects on this order twice already). Note that explicitly in your report so the human knows one more independent check is expected before calling ORDER-103 fully closed.
