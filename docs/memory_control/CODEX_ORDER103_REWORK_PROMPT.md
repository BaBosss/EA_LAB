# CODEX TASK — ORDER-103 (C1-ENFORCE) REWORK: close 2 confirmed blockers

You are a peer engineer implementing a REWORK in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). This is a tamper-integrity validator for an append-only markdown archive log. Read `AGENT_TASKBOARD.md` block `## ORDER-103` (the r1 spec + the "BUILD EXECUTED" record + the "Blind Codex review of build ... = REWORK(2)" record) for full context. The build is done and in the working tree (uncommitted); it passed 18/18 of its own tests but a blind review + reproduction found **2 real blockers**. Your job: fix both, add the missing negative tests, self-verify, and leave the result for review. **Do NOT commit anything.**

## The 2 confirmed blockers (both reproduced by hand)

### BLOCKER 1 (🔴 durability hole still open on the `-Strict` path — the core P0 this order exists to close)
`-Strict` blesses a mutation of a **post-split appended block's content** after a manifest regen. Reproduction (returns exit 0 = HOLE):
```
# mutate prose UNIQUE to an appended block (not shared with any split block, not a hash row):
powershell -NoProfile -Command "(Get-Content -Raw 'ARCHIVE_TASKBOARD_2026-07A.md') -replace 'canonical-id-wildcard hole','TAMPERED' | Set-Content -NoNewline 'ARCHIVE_TASKBOARD_2026-07A.md'"
powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Generate     # regen manifest to match
powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict        # <-- currently exit 0 (WRONG; must be 2)
```
Root cause: `Invoke-ArchiveChainIntegrityCheck` walks only **committed** history (checkpoint→HEAD); `Invoke-ArchiveAppendOnlyCheck` guards only the 131 **split** blocks vs baseline `4aebbc37`. So a mutation to a *post-split appended* block (e.g. `## C1-CLOSURE`, `## C1-ENFORCE-SOURCEA-BINDING`) in the **working tree** is checked by nothing during `-Strict`; regenerating the manifest makes the bijection pass. The order's acceptance explicitly requires "manifest regen after mutate → still exit 2".

**FIX:** `-Strict` AND `-Audit` must additionally verify the **current (working-tree, FILE:) archive is a valid append-extension of `HEAD:ARCHIVE_TASKBOARD_2026-07A.md`** — i.e. every H2 block present at HEAD must appear byte-identical (canonical-LF) as a prefix of the current archive's H2 block sequence, with extra trailing blocks allowed. Any mutation of an existing block (split OR appended), removal, truncation, or reorder → integrity failure (exit 2). This closes the hole: mutating an appended block changes that block's canonical-LF bytes vs its HEAD copy.
- **RECOMMENDED APPROACH = block-level canonical-LF prefix**, not raw-byte, for this HEAD→current leg. Reuse the existing normalization the superset check already uses (`Get-NormalizedTextFromBytes` / the canonical-LF block sha256 in `Get-ClassifiedBlocks`). Read `HEAD:archive` via the existing `Get-GitBlobBytes -Ref HEAD`, classify into blocks, and compare its block list to the current archive's block list as a prefix (same hashes, same order; extras only at the tail).
- The committed-chain check (checkpoint→HEAD, raw-byte blob-to-blob) **stays as is** — it's correct. You are ADDING the HEAD→current leg.
- **CRLF LANDMINE (do not skip):** the working file has `core.autocrlf=true` and may carry CRLF or mixed line endings, while `HEAD:archive` is LF. A raw-byte compare of the working file to the LF blob will falsely diverge. You MUST normalize both sides to canonical LF before comparing (that's why block-level canonical-LF is recommended — it already normalizes). Diagnose the actual on-disk endings first (`git ls-files --eol ARCHIVE_TASKBOARD_2026-07A.md`, and inspect bytes) and prove your comparison is normalization-safe.
- After the fix, the **current real working tree** (= HEAD archive + the appended `## C1-ENFORCE-SOURCEA-BINDING` block) must still make `-Strict` return **0** (the binding is a legitimate appended block). If it doesn't, you've either got a normalization bug or you've hit BLOCKER 2 — fix that too.

### BLOCKER 2 (🔴 the H2-boundary rule rejects the binding's own commit — self-DoS)
Committing the real binding block through the hook is BLOCKED:
```
# in a temp clone with core.hooksPath=.githooks, staging the archive+artifacts and committing =>
# BLOCK: "staged archive fails append-chain integrity -- archive suffix ... does not open with a new '## ' (H2) block boundary"
```
Root cause: the "new-H2-boundary" rule in `Invoke-ArchiveChainIntegrityCheck` requires the appended suffix to begin **immediately** with `## `. But the archive's append convention places a separator — a blank line and/or a `---` horizontal rule — between H2 blocks, so the real suffix begins with `\n---\n\n## …`, not `## …`. The rule therefore rejects the very block this order appends. This also means the build was **never successfully commit-tested end-to-end**.

**FIX:** relax the boundary rule so a valid appended suffix MAY be preceded by optional blank lines and/or a single `---` horizontal-rule line before the first `## ` heading. It must STILL reject a suffix that **extends the previous block** (e.g. adds a new table row `| … |` or prose with no new `## ` heading). Concretely: after normalizing, the first **non-blank, non-`---`** line of the suffix region must be a `## ` H2 heading; if it is anything else (a table row, blockquote, prose), it is extending the prior block → fail. Keep the existing negtest `fix1-suffix-extends-last-block-without-new-H2-fails` GREEN, and add a positive case `fix1-append-newblock-after-separator-passes` (suffix `\n---\n\n## NEWBLOCK\n…` → passes).
- If you adopt the block-level approach for BLOCKER 1, note the boundary concern largely dissolves (whole new blocks appended = clean; a table row added to the last block changes that block's hash = caught). But the **committed-chain raw-byte leg** and the **hook** still use the raw-byte suffix rule, so you must fix the boundary rule there regardless. Ensure BOTH the `-Strict` path and the hook (`scripts/check_precommit_staged.ps1`) accept the separator.

## Acceptance — ALL must hold (run every command; paste output into your result file)
1. `powershell -NoProfile -File scripts/check_taskboard_archive.ps1 -Strict` → **exit 0** on the current working tree (binding present). Same for `-Audit`. And `scripts/check_state.ps1 -Strict` → CLEAN.
2. **BLOCKER 1 closed:** the mutate-appended-prose + `-Generate` + `-Strict` reproduction above now returns **exit 2** (do it in a backup-and-restore wrapper or a temp copy; restore the real files afterward — the real archive must end unchanged = only the +13-line binding append vs HEAD).
3. **BLOCKER 2 closed:** in a throwaway temp clone under `$env:TEMP` with `core.hooksPath=.githooks`, staging `ARCHIVE_TASKBOARD_2026-07A.md` + the 3 regenerated artifacts (copied from the real working tree) and running `git commit` **SUCCEEDS** (hook passes). Show the commit exit=0 and the hook's PASS message.
4. Full suite `powershell -NoProfile -File scripts/_test/run_order103_negative_tests.ps1` → all pass, INCLUDING the new cases:
   - `fix1-mutate-appended-block-prose-then-regen-strict-fails` (BLOCKER 1 regression — exit 2)
   - `fix1-append-newblock-after-separator-passes` (BLOCKER 2 regression — a `---`/blank-separated new H2 append passes)
   - `fix2-real-commit-of-binding-through-hook-passes` (BLOCKER 2 end-to-end — real commit succeeds)
   Keep every previously-passing case green.
5. `powershell -NoProfile -File scripts/_test/run_order101_negative_tests.ps1` → same result as before your change (the one pre-existing `cross-HEAD-zero-diff` failure remains pre-existing and unrelated; do not "fix" it by weakening anything).
6. Archived block bytes unchanged (append-only). No files touched outside: `scripts/check_taskboard_archive.ps1`, `scripts/check_precommit_staged.ps1`, `scripts/_test/run_order103_negative_tests.ps1`, and (only if genuinely required) `.githooks/pre-commit`. Do NOT modify the appended binding block's bytes unless a normalization fix requires re-appending it identically.

## Hard constraints (ห้าม)
- Do NOT commit to the real repo. Leave all changes in the working tree for Opus review.
- Do NOT rewrite/rollback existing commits (migration commits `4aebbc37`/`0ced194`/`be45d4b`/`0e6…`/`9e0bd8a` are correct).
- Do NOT edit the bytes of any existing archived block. The archive may only grow by whole appended H2 blocks.
- Do ALL destructive/negative tests in throwaway temp repos/clones/copies under `$env:TEMP`; restore anything you touch in the real tree. Confirm at the end that `git status`/`git diff --numstat` shows ONLY the intended build+rework files and the archive is still a +13/-0 append vs HEAD.
- Do NOT touch unrelated dirty files (a concurrent session is committing ORDER-104 on master; keep your changes path-limited; if HEAD moves mid-work that's fine — the checkpoint `0ced19485c6c6ce9a23541f785ab82bae4fcad25` stays an ancestor).
- Neutral, defensive framing only in any sub-tooling — this is integrity hardening, not offensive security.

## Deliverable
Write a report to **`docs/memory_control/CODEX_ORDER103_REWORK_RESULT.md`** containing, per blocker: the code change (file:line + brief), the before/after behavior with the exact command + observed exit codes, the new tests added, and the final `-Strict`/`-Audit`/`check_state`/both-suites exit codes with console tails. State plainly anything you could not satisfy. End the file with one line: `REWORK STATUS: DONE` or `REWORK STATUS: BLOCKED (reason)`.
