# ORDER-103 — C1-ENFORCE: close the archive write-path tamper hole (memory-OS build, final hardening)

> Design source: `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md §20 @ 4eb839d` · handoff `docs/memory_control/C1_ENFORCE_HANDOFF.md`
> Status: **DRAFT — pending Codex design-review BEFORE build** (handoff mandate: append-chain integrity is hard design, review-before-build like C1)
> Routing: Codex design-review (this order) → Sonnet build → **Opus verify across real HEAD/commits** → blind Codex review → accept

## Why (the hole Codex final review found)

The migration (ORDER-102 C1) moved the taskboard archive index to a generated read-only `ARCHIVE_INDEX.md`, archive = append-only log, 12 exceptions closed via `## C1-CLOSURE` + `## REVIEW ORDER-071`. Codex accepted the DATA (0 history lost, git verified) but found the **enforcement** incomplete:

**`scripts/check_taskboard_archive.ps1` (1704 lines) guards tamper only for the 131 original split blocks — it does NOT guard blocks appended AFTER the split** (including `## C1-CLOSURE` itself and the ORDER-071 rev01 append). So an editor could mutate an appended block, regenerate the manifest, and the validator would "bless" it. Plus the pre-commit hook fails OPEN when PowerShell is absent.

## The 4 fixes (bounded — no new scope beyond these)

### Fix 1 🔴 Append-CHAIN integrity (replace single superset-vs-split check)
Every archive-changing commit must prove the staged archive bytes are a **raw-byte prefix-extension** of the archive blob from the parent commit. Audit walks the chain from the migration anchor through every commit that touched the archive.
- `manifest regen must NOT be able to bless a mutation of an existing appended block` — only a pure raw-suffix addition passes.
- **NegTests (must exit 2):** mutate `## C1-CLOSURE` or ORDER-071 rev01 append → fail. **PosTest (must pass):** append a brand-new raw suffix block that leaves all prior bytes byte-identical.

### Fix 2 🔴 Fail-CLOSED staged-snapshot pre-commit hook (the deferred C1a)
`.githooks/pre-commit` currently `exit 0` when PowerShell is missing (`:5-9` = fail-OPEN). Rework:
- (i) **fail-CLOSED if no PowerShell** (block the commit, don't skip)
- (ii) verify the **staged** archive is an exact byte-extension of `HEAD:<archive>`
- (iii) staged manifest/index/exceptions match the staged archive
- (iv) exact staged allowlist (only the permitted paths in an archive-changing commit)
- Tests run in a **temp repo/index, NOT the shared worktree**. `--no-verify` remains the documented policy-bypass per AGENTS.md; the hook message must **not** advertise bypass.

### Fix 3 🟡 Source-A exact binding
`check_taskboard_archive.ps1:~1089` currently closes any exception for a canonical-id via ANY `^## REVIEW ORDER-<id>` block. Bind instead to the **exact target block-id/hash** so a phase-review or a forged review cannot close a different block.

### Fix 4 🟡 hash-object atomicity
Change archive identity from `git rev-parse HEAD:ARCHIVE...` to **`git hash-object <file>` / `git rev-parse :ARCHIVE...`** (staged / working-tree content) so an archive-changing migration lands in **ONE atomic commit** (today it needs a 2-commit re-pin).

## Acceptance (numeric / test, verifiable)
- [ ] `scripts/check_taskboard_archive.ps1 -Strict` = exit 0 on current clean HEAD (no regression)
- [ ] Append-chain negTests: mutating `C1-CLOSURE` or ORDER-071 rev01 → **exit 2**; pure-suffix append → **exit 0** (tests in isolated temp repo, ≥4 cases)
- [ ] pre-commit: no-PowerShell → **non-zero (fail-closed)**; staged non-extension archive → blocked; wrong allowlist path → blocked (temp-repo tests)
- [ ] Fix 3: forged `## REVIEW ORDER-071` pointing at the wrong block-id/hash does NOT close the exception
- [ ] Fix 4: one archive-changing migration = single commit, manifest identity from staged content (`git rev-parse :<path>`), no 2-commit re-pin
- [ ] Opus re-verifies each across a REAL cross-commit walk (not one-session state), then blind Codex review before accept

## ห้าม (out of scope)
- ❌ rollback/rewrite migration commits (`be45d4b`/`0e67e1d` — HEAD ถูกแล้ว)
- ❌ start Contract D (MVP-1-lite event-log) until C1-ENFORCE closes (§20.2 #5)
- ❌ edit bytes of any archived block (append-only) · worker decides an exception (Opus only)
- ❌ touch unrelated dirty files (concurrent session on master — commit path-limited, check HEAD before stage)
- ❌ build before Codex design-review of THIS order returns
