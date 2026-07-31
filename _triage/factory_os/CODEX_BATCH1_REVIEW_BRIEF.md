# Independent review brief — batch 1 (S4 + S5), 2026-07-31

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the independent-review brief for the
> ORDER-612 / ORDER-630 batch**, plus the orders closed in the two sessions before it that have not
> yet been reviewed.
>
> **Scope note for the reviewer.** This is ordinary software-quality review of a private research
> repository's own test suites and data-validation checks. "Guard", "check" and "gate" here mean
> unit tests and schema validators in a git pre-commit hook. Nothing in this repository is a
> security control, an authentication system, or a network-facing service, and no finding is
> expected to concern one. The words `signature` and `attestation` refer to the repository owner
> countersigning a data-migration record in a text file.

**Commit range: `48973138..50ef2f41`, six commits.** ⚠️ A range includes writers that are not me:
`[auto] daily monitor snapshot` is a scheduled committer in this repo with no ledger row, and it
landed mid-session during the previous batch. **CHECKED for this range, not assumed** —
`git log --format='%an|%s' 48973138..HEAD` returns six commits, all mine, none from the scheduled
job. Re-run it before accepting any negative claim I make.

## What you are auditing

| order | slice | state |
|---|---|---|
| `ORDER-612` | **S4** snapshot v5 + fail-closed readers | `DONE — AWAITING CONSOLIDATED CODEX AUDIT` |
| `ORDER-630` | **S5** registries + ONE ParameterBinding resolver | `DONE — AWAITING CONSOLIDATED CODEX AUDIT` |
| `ORDER-610` `611` `613` `615` `616` | S2/S3, governance, guard shapes | closed in the previous session, **never audited** |

Read `docs/GUARD_SHAPES.md` first. It is the four defect shapes behind 24 findings from your two
previous audits. Both slices in this batch were written against it, which means **the interesting
question is not "did they follow the checklist" but "what shape is not on the list yet".**

## The two slices, in one paragraph each

**S4.** `scripts/control_room_snapshot.ps1` no longer writes the snapshot. It emits a
`SnapshotBuilderInput`; `_triage/factory_os/snapshot_build.py` derives every source row's evidence
from the real file on disk, derives the reconciliation counts from the taskboards and the coverage
store, computes the verdict, validates against `ControlRoomSnapshotV5`, and `os.replace()`s the
canonical path. Readers (`scripts/lib/snapshot_reader.ps1`) obtain the document through
`snapshot_validator` and never through `json.load`.

**S5.** Four registry stores under `factory/`, and ONE resolver (`_triage/factory_os/registry.py`)
that answers *"may this run optimize this parameter"* by combining `docs/PARAM_REGISTRY.csv`'s
permanent semantics with a `ParameterBinding`'s per-hypothesis role.
`scripts/optimize_guard.ps1` reads that resolver.

---

## THE GAPS I ALREADY KNOW ABOUT

This section exists because it is what made your round 2 productive last time. Everything below is
a real weakness I found and did not close, with the reason. **Re-deriving these is lower value than
finding what is not here.**

1. **`run_schema_fixtures.py` judges the WORKTREE snapshot while the fast tier is a pre-commit
   hook.** A staged-but-different `portfolio/control_room_snapshot.json` passes C1 on worktree
   bytes. The read declares `# snapshot: worktree`, so L1 is satisfied and a reviewer can see it.
   Not fixed: making the suite behave differently under a hook is its own design, and the same
   question applies to every suite in the tier.

2. **`check_s2a_migration`'s C3 says "EXISTS at HEAD" and fires on the INDEX.** Proven by
   experiment — worktree-only 0 refutations, staged 3. Reading the index is the *correct* snapshot
   for a pre-commit gate, so the check is right and the message is wrong. Not fixed: that file is
   inside the owner's attestation bundle, and a one-word message repair is not worth a signature.

3. **R3 is a deny-list and three counter-examples get past it**: a number-coded verdict, a verdict split
   across two fields, a verdict word nobody listed. The allowlist that *does* exist is the schema's
   `unevaluatedProperties: false`. The un-closable case is asserted as a fixture expecting
   NOT-caught.

4. **R4's second-copy sweep does not catch `'TUN' + 'ABLE'`**, and its scope is three globs —
   `scripts/_test/*.ps1`, `*.psm1` and MQL sources are not swept.

5. **R4 cannot prove two programs compute the same thing.** It proves the vocabulary exists in one
   file and that every declared consumer reaches it. **A consumer that calls the resolver and then
   ignores the answer is not caught.** `run_registry_tests.ps1` covers that for the one consumer
   that exists; a second consumer added later is not automatically covered.

6. **`snapshot_build.reconcile()` reads the working tree**, so it describes the tree as it is, not
   as a commit would contain it.

7. **An ABSENT snapshot file exits 3 (TOOL FAILURE) where "no document" would be more accurate.**
   No reader takes that path — `Get-VerifiedSnapshot` `Test-Path`s first and returns
   `Code=MISSING` — so only a human at the command line sees it.

8. **`factory/universe.jsonl` is NOT CREATED**, and this is the one I most want checked. Creating
   it refutes two rows of D1 (`TestUniverse: NO_CURRENT_OWNER`, `LogicalSymbol: NOT_YET_BUILT`,
   both proposing that file), and D1 is inside the owner's `bundle_sha256`. Measured: with the file
   staged the S2a gate goes red naming both; with it absent all 7 steps are green. I chose to
   record the block rather than edit D1, because editing it would spend an owner signature to hide
   a structural defect that is already recorded (`approval-pinning-self-invalidates`: every
   `disposition: TRANSFER` row self-invalidates on execution). **Tell me if that was the wrong
   call.**

9. **The fast tier is now 39.4s** (median of five clean runs: 38.1 / 38.8 / 39.4 / 39.6 / 41.1) against a **15.0s advisory**
   budget, up from 18.1s. Most of the growth is ajv startup in the monitor fixtures, which are now
   BUILT through the real pipeline rather than hand-authored. Per-path selection keeps a real
   commit at 11–28s. Recorded in `run_fast_cages.ps1` as a number somebody must decide about.

10. **Three of five registry stores carry no rows**, each with a reason in its own header. The
    mechanism is exercised against synthetic registries only. `check_registries.py` prints
    `R2 NOT_APPLICABLE cells examined this run: 0 <- 0 means R2 is UNTESTED by this run` on every
    run, so empty is never read as passed.

---

## ALREADY FOUND BY THE FIRST REVIEW ATTEMPT, AND FIXED — do not re-report

The first run of this review reached a real finding before its response was withheld by an
automated content check. The finding was visible in the partial output, was reproduced here, and
is fixed. It is listed so the second run does not spend time on it:

> *"the consumer test proves a named revision with zero bindings leaves an otherwise-allowed
> parameter allowed, while the resolver contract explicitly says an unbound parameter has
> `optimizable=None` and must not receive permission by silence."*

Correct, and the mismatch was real. `registry.resolve()` returned `optimizable=None` /
`source=UNBOUND` and `optimize_guard.ps1` **dropped that value on the floor** — so a run declared
to belong to `B14-H01-r1` swept a parameter that revision never described and nothing anywhere
said so. The resolver kept its promise and the consumer broke it one call frame later. Two repairs:

1. `optimize_guard.ps1` now emits a NOTE naming every unbound parameter under a declared revision.
   A **note, not a refusal** — whether a revision's binding set must be COMPLETE is undecided
   (`Hypothesis` has no "parameter surface is closed" field and no design row asks for one), so
   refusing would be inventing a bar. Making the silence visible needs no such decision.
2. `registry.resolve()`'s docstring said `None` prevents permission by silence. It **overclaimed**:
   it prevents the RESOLVER from granting it, not the SYSTEM. Corrected in place.

The repair then needed its own repair: the new branch fired for *every* parameter on *every*
existing call site, because the binding map is empty when no revision is declared — which would
have broken the one promise the wiring made in writing ("with no `-HypothesisRevision`, not one
line changes"). Caught by the specificity assertion in `run_registry_tests.ps1`. Both halves are
now asserted together so neither can be quoted without the other.

**Open question this leaves, and it is worth your opinion:** should an unbound parameter under a
declared revision be a REFUSAL rather than a note? That needs a "binding set is complete" concept
that does not exist yet.

## WHERE I THINK YOU WILL FIND SOMETHING

Written as questions, not as defences.

- **The C6 asymmetry.** `make_status.ps1` renders a banner and exits 0 on REFUSED/UNAVAILABLE;
  `Get-MonitorCoverage` returns a hard failure token for the same three states. I pre-registered
  that and fixtured both. **Is the asymmetry defensible, or did I talk myself into a reader that
  fails open on the path that matters?** The argument is in
  `scripts/lib/snapshot_reader.ps1`'s header.

- **`verified-sha256`.** The reader hashes its own read and compares it to the digest the validator
  published for the bytes it parsed. Is there a sequence where those two agree and the document is
  still not what was checked?

- **The `--root` / `-BindingsRoot` seams.** I argued they cannot buy permission because a binding
  only ever ADDS a refusal, so an empty root yields today's behaviour. **Is that true for every
  path, including the generator that does not exist yet?**

- **`derive_source_evidence` refuses a contradicted `read_ok`/`sha256`/`mtime` but OVERWRITES
  `age_hours`.** I argued age is a pure function of a now-pinned mtime. Is there a way to make the
  overwrite launder something?

- **`_apply_reconciliation` runs BEFORE `derive_source_evidence`** (facts_of needs the
  reconciliation to exist). Does that ordering create a window?

- **`STATUS_CATEGORY` maps 28 board verbs into 6 buckets; 20 land in `unclassified`.** The design
  fixed the six names. Did I map anything into a bucket that asserts something the board does not
  say — particularly `cancelled_by_user`?

- **The guard-shape lint itself.** `L1_FILES` gained three modules this batch. `snapshot_build.py`
  does not match `CHECKER_GLOB`, so L0 would never have demanded it — I added it by hand, which is
  exactly the failure mode L0 exists to prevent. **What else is outside the glob?**

## What is NOT in scope

`VISION.md`, `AGENTS.md`, the Decision log, any live `.set`, `_vps_deploy/`, any magic number, and
the four owner decisions in `_triage/USER_DECISIONS_PENDING.md`. Do not propose changes there.

## How to run everything

```
tools\python312\python.exe _triage/factory_os/run_schema_fixtures.py
tools\python312\python.exe _triage/factory_os/run_snapshot_s4_tests.py
tools\python312\python.exe _triage/factory_os/run_registry_tests.py
tools\python312\python.exe _triage/factory_os/check_registries.py
tools\python312\python.exe _triage/factory_os/run_s2a_gate.py
tools\python312\python.exe _triage/factory_os/run_guard_shape_lint.py --self-test
powershell -NoProfile -File scripts\_test\run_snapshot_s4_tests.ps1
powershell -NoProfile -File scripts\_test\run_registry_tests.ps1
powershell -NoProfile -File scripts\_test\run_monitor_integrity_tests.ps1
powershell -NoProfile -File scripts\_test\run_fast_cages.ps1
```

A finding is worth more if it comes with the input that produces it. Every defect that mattered in
the last three sessions was found by running a counter-example, never by reading a diff.
