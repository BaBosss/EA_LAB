# Codex audit brief — S4 + S5 as they stand NOW, after the evidence-source migration

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the standing audit brief for
> slices S4 and S5 and everything that has changed underneath them since batch 1 closed.**
> Written 2026-07-31 by the Opus seat at the owner's instruction — *"เขียน handoff ให้ codex มา
> audit s4+s5 ไว้ด้วยนะ พอ quota กลับมาจะให้ codex ทำ"* — because Codex's ChatGPT quota was
> exhausted at the time. **Nothing here expires. Pick it up whenever quota returns.**

**Scope note for the reviewer.** This is ordinary software-quality review of a private research
repository's own test suites and data-validation checks. "Guard", "check", "gate" and "cage" here
mean unit tests and schema validators in a git pre-commit hook. Nothing in this repository is a
security control, an authentication system, or a network-facing service, and no finding is expected
to concern one. `signature` and `attestation` refer to the repository owner countersigning a
data-migration record in a text file.

---

## 1. The range, PINNED — do not substitute `HEAD`

```
6f297ca0..74973b71      18 commits
```

Both ends are fixed SHAs. The previous brief in this lineage wrote `..HEAD` in the same sentence
that told the reviewer to re-run the count, and by the time they did, HEAD had moved and returned a
different number — the document's defect, not a discrepancy in the repo.

**A range includes writers that are not me.** This repo has a scheduled committer
(`[auto] daily monitor snapshot`) with no session-ledger row, and it has landed mid-session before.
**CHECKED for this exact range, not assumed:** `git log --format='%an|%s' 6f297ca0..74973b71`
returns 18 commits, **all `patip`, none from the scheduled job**. Re-run that literal command
before accepting any negative claim this document makes.

⚠️ If you are reading this weeks later, HEAD will have moved a long way. Audit the pinned range —
then, separately, `git log --format='%an|%s' 74973b71..HEAD` to see what landed after it and decide
whether the findings still apply. Do not silently widen the range.

## 2. What you are auditing, and what has already been audited to death

| | slice | state |
|---|---|---|
| `ORDER-612` | **S4** snapshot v5 + fail-closed readers | `DONE — AUDITED x5` (Codex x4 + Fable) |
| `ORDER-630` | **S5** registries + ONE ParameterBinding resolver | `DONE — AUDITED x5`, **five-store acceptance NOT closed** (`factory/universe.jsonl` is owner-blocked) |
| `ORDER-670` | **the tier-wide snapshot rule** — new since those audits, and it **changed how S4 and S5 read their inputs** | `CORE DONE`, migrations 3 of 8 |
| `ORDER-675` | the session-collision guard | `DONE` |
| `ORDER-614` | rev-2 policy + conformance vectors | **DRAFTED, not built** — see §6 |

**Batch 1's 29 findings are fixed and fixtured. Do not re-report them** — the list with each
counter-example is in [`CODEX_BATCH1_REVIEW_BRIEF.md`](CODEX_BATCH1_REVIEW_BRIEF.md), which stays
valid as a "do not re-derive" index. Reading it first is a better use of the round than
rediscovering them.

**The interesting question is not "is S4/S5 correct as written" — five rounds have asked that.
It is "did ORDER-670 break, weaken, or silently change them while migrating how they read".**

## 3. What ORDER-670 changed underneath S4 and S5

The measurement that started it: **31 declared reads of judged evidence across nine checkers, all
of them the working tree, zero declaring the index** — in a tier that is a git pre-commit hook,
where the commit contains the **index**. (Of those 31 matches, one is a fixture string and two
self-annotate as non-evidence ⇒ **28 real reads**. The design's §1 carries the correction; an
earlier revision quoted 31 without reading its members, which is this repo's shape 4.)

**The rule, and it is the thing to attack:**

> **A BUILDER observes the world. A CHECKER judges the commit.**

Design: [`TIER_SNAPSHOT_DESIGN.md`](TIER_SNAPSHOT_DESIGN.md) **rev 2**. Rev 1 was attacked by an
independent review before any code was written and **its central argument was wrong twice**
(§7 of that file records exactly how). Rev 2 has not been reviewed by anyone but its author.

New module: [`evidence.py`](evidence.py) — `read_committed` / `exists_committed` /
`list_committed` (category A, index in hook mode) · `observe` (category B, the disk, always) ·
mode chosen once per process from `EA_LAB_EVIDENCE`, a typo **refused** rather than defaulted ·
one structured marker line per run, verified per-suite by the tier as an **allowlist**.

Migrated so far: `check_registries.py` (S5) · `check_schema_structure.py` ·
`run_schema_fixtures.py`'s two real-input blocks (S4's **C1**, the committed-snapshot assertion).
Tier plumbing: `.githooks/pre-commit` passes `-Hook` at **both** call sites;
`scripts/_test/run_fast_cages.ps1` is the one setter of the env and verifies arrival.

## 4. Where I think you will find something — written as questions, not defences

1. **The category call on `snapshot_build.py`.** It is a BUILDER, so all seven of its reads stay on
   the disk, including `reconcile()`, which counts orders on the taskboards and cells in the
   coverage store. Rev 1 put `reconcile()` in category A and that was refuted on two grounds
   (`snapshot_validator.compute()` folds every predicate into ONE `reasons` list, so disk-mtime and
   board-count facts would share one boolean; and it has no hook-mode caller at all). **Is the
   corrected call right?** The committed snapshot is an artifact of this machine at build time,
   while `run_schema_fixtures` C1 judges *the committed copy* of it. Two different questions, two
   different vintages, deliberately. **Is there a sequence where those two disagree in a way that
   matters — e.g. the builder writes a snapshot describing disk state, the commit contains it, and
   C1 validates a document that describes a world the commit does not?**

2. **`list_committed`'s glob semantics.** Index enumeration uses `git ls-files --cached --
   ':(glob)<pattern>'`; worktree enumeration uses Python `glob.glob`. I verified on this repo that
   `:(glob)` makes `*` stop at `/` so `scripts/*.ps1` excludes `scripts/_test/*`, matching
   `glob.glob`. **Is there a pattern where the two disagree?** A divergence means the same criterion
   sweeps different file sets in the two modes, which is a silent scope change, not a crash.

3. **`GIT_INDEX_FILE` containment.** A hook publishes its temp index through that variable.
   `evidence._run_git` **strips** it for any root that is not this repo and **honours** it for this
   repo (`normcase` on both sides after a case-sensitivity hole was found post-landing). This came
   from a live near-catastrophe: fixture repos running `git add -A` inherited the variable and
   **deleted all 5,135 entries from a real commit's temp index**; three commit attempts were
   blocked only because a diagnostic case happened to read the wreckage. **Is the containment
   complete?** Every other subprocess boundary in the tier — PowerShell suites, `subprocess` in
   other python checkers, `run_order103/105` (manual-only today) — is a candidate.

4. **The marker allowlist.** Each migrated suite must emit exactly one
   `##EVIDENCE-MODE## <suite> <mode> git_index=<...>` line and the tier requires it by name.
   **Can a suite satisfy the marker while its checkers ran in the other mode?** The marker is
   produced by a *separate* python invocation in the wrapper, not by the checker that did the work
   — that is a real seam and I know it is one. Naming it here rather than waiting for you to find
   it is the honest form, but the question stands: **is a marker emitted by a sibling process
   evidence about the process that judged?**

5. **Mode collision in suites that MUTATE real files.** `run_enforcement_status_tests.py` writes
   mutations into the worktree copy of `schemas.json` and asserts the checker refuses them. Under
   a hook the inherited mode is `index`, and an index-mode checker cannot see a worktree mutation —
   **every case would go green for the wrong reason.** Fixed by pinning that runner to `worktree`.
   **Are there other suites with the same shape that I did not find?** The general rule I applied:
   a suite testing RULES against synthetic bytes is category C and its mode must be deterministic,
   never inherited.

6. **`registry.read_store`/`load_all` still default to the worktree when handed no source.** That
   default is documented as a scheduled removal, not a choice, because `resolve()` and
   `optimize_guard.ps1` run outside hooks where worktree is correct. **Is there a path where a
   checker reaches those functions without a source and therefore judges the wrong bytes?**

7. **T7 is NOT built and is owed.** `run_guard_shape_lint.py`'s L1 still accepts a `# snapshot:`
   comment for a category-A read; binding it to the `read_committed` **call** is unbuilt. So today
   a newly-written checker can read the worktree with a correct-looking comment and nothing objects.
   **Stated as a known hole, not offered as done.**

## 5. Honest coverage of the new work — what is proven and what is not

**Proven, each observed red first, both directions:**

| | what |
|---|---|
| T1 | staged corruption behind a clean worktree copy ⇒ RED in index mode; the worktree mirror case demonstrates the pre-670 blindness live in the same suite |
| T2 | no fallback: untracked-but-on-disk refused · typo mode refused · tracked-but-unreadable refused |
| T3 | a **staged** rogue role-vocabulary file whose worktree copy was deleted ⇒ RED in the R4 sweep; an **untracked** scratch file neither flags nor fails |
| T4 | a declared evidence suite emitting no marker fails the hook tier **by name**; the same run with no evidence suite in scope is green; fixture prose containing the word `worktree` cannot forge a marker |
| T5 | `observe()` returns disk bytes while the index disagrees |
| T6 | a mid-tier index rewrite is refused (red path driven through a test-only seam so it has been **seen** firing) |
| T-GIF | the incident above, replayed: fixture git ops leave a decoy index **byte-unchanged**; the fixture used its own index; and — specificity — for THIS repo the variable is still honoured, including a case-variant spelling of the root |

**Not proven / not built, stated so a green run is not mistaken for coverage:**

- **T7** (§4.7).
- **T5's collapse-the-split red half** — "make `observe` read the index and the monitor suite must
  go RED" is written in the design's acceptance table and is **not** implemented.
- **Five checkers still un-migrated:** `registry.py`'s own resolve path · `gen_coverage` ·
  `snapshot_validator` · `run_guard_shape_lint` · `check_coverage_transfer`'s enumerations.
- **The six PowerShell guards that run BEFORE the tier** (`check_state` · `check_precommit_staged` ·
  `check_order_collision` · `check_handoff_contract` · `check_experiment_events` ·
  `check_verdict_kill`) judge boards, the ledger and handoffs — committed evidence by any reading —
  and `evidence.py` gives them no entry point. Two of the six are already partly correct and
  **nobody wrote down which**. That is `ORDER-674`, open.

## 6. ORDER-614 is DRAFTED, not built — audit the draft, do not audit it as shipped

[`ORDER614_POLICY_DRAFT.md`](ORDER614_POLICY_DRAFT.md) + [`ORDER614_VECTORS_DRAFT.jsonl`](ORDER614_VECTORS_DRAFT.jsonl):
a versioned policy (44 criteria at **predicate** granularity) and **55 hermetic conformance
vectors**, so that repairing the attestation checker stops costing the owner a signature. Rev 1 of
that design was refuted by a one-line `if False`; rev 2 is the adopted replacement and **states its
own limit**: full semantic equivalence between two implementations is not achievable without
binding the implementation or possessing a complete executable spec — vectors bound what is
*tested*, not what is *possible*.

Worth your attention: the draft's own audit found **A5/R8 is unreachable** (`reason` is in
`REQUIRED`, so a blank reason dies as R4-missing first, and the existing suite case named for A5
asserts **R4's** message — shape 3, in the criterion list since ORDER-602). **Verified against the
code by the lead** at `check_s2a_attestation.py:53/193/241`.

The one genuinely open design question, deliberately not defaulted: **does
`check_s2a_migration.py` also leave the bundle?** Dropping it binds D1's *bytes* while leaving
D1's *meaning* unbound.

## 7. Commands that should pass — run them, do not take them from here

```
tools\python312\python.exe _triage\factory_os\run_registry_tests.py
tools\python312\python.exe _triage\factory_os\run_schema_fixtures.py
tools\python312\python.exe _triage\factory_os\check_registries.py
tools\python312\python.exe _triage\factory_os\run_guard_shape_lint.py
powershell -NoProfile -File scripts\_test\run_guard_trigger_tests.ps1
powershell -NoProfile -File scripts\_test\run_contract_binding_tests.ps1
powershell -NoProfile -File scripts\check_state.ps1
```

Set `EA_LAB_EVIDENCE=index` and run the python ones again — **both modes must pass**, and the
marker line must name the mode you set. A suite that passes identically in both modes without
saying which it judged is the defect this whole order exists to remove.

<sub>**The standing instruction from batch 1 still applies and is the most useful thing you can
do:** read [`docs/GUARD_SHAPES.md`](../../docs/GUARD_SHAPES.md) first — five defect shapes behind
33 findings — and then ask **"what shape is not on that list yet"**. Shape 5 was named by the
previous independent reviewer from instances in this repo's own *repairs*, and it has since
predicted defects in commits written after it. A sixth shape would be worth more than any single
finding.</sub>
