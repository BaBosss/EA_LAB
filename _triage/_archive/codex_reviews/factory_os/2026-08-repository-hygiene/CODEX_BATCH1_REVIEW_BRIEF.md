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

**Commit range: `48973138..d92549a4`, ELEVEN commits. Both ends are PINNED SHAs — do not
substitute `HEAD`.** The previous version of this line wrote `48973138..HEAD` in the same sentence
that told you to re-run it, and by the time you did, HEAD had moved and returned 9 where the text
said 6. That was the document's defect, not a discrepancy in the repo. A range in a review brief is
a claim about a fixed set of commits and must be written as one.

⚠️ A range includes writers that are not me. `[auto] daily monitor snapshot` is a scheduled
committer in this repo with no ledger row and it has landed mid-session before. **CHECKED for this
exact range, not assumed** — `git log --format='%an|%s' 48973138..d92549a4` returns eleven commits,
all `patip`, none from the scheduled job. Re-run that literal command before accepting any negative
claim I make.

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

## THE GAPS I ALREADY KNOW ABOUT — 9, and only 3 are engineering work

MEASURED just now, not recalled. Each line says who can close it, because "still open" and "still
my job" are different facts and the list is useless if it conflates them.

**Permanently unclosable — stated as limits IN the guard, not tracked as work (2)**

1. **R3 is a deny-list.** A number-coded verdict, a verdict split across two fields, and a verdict
   word nobody listed all get past it. The allowlist that *does* exist is the schema's
   `unevaluatedProperties: false`, and R5 is what binds each store to one such entity. The
   unclosable case is asserted as a fixture that EXPECTS not-caught.
2. **R4's second-copy sweep does not catch `'TUN' + 'ABLE'`**, and its scope is three globs —
   `scripts/_test/*.ps1`, `*.psm1` and MQL sources are not swept. No regex closes concatenation.

**Owner-owned — I may not close these (3)**

3. **`factory/universe.jsonl` is not created.** Creating it refutes two D1 rows and D1 is inside
   the owner's `bundle_sha256`. Measured: staged ⇒ the S2a gate goes red naming both; absent ⇒ 7/7
   green. **This is the decision I most want checked** — I recorded the block rather than editing
   D1, on the grounds that editing it spends an owner signature to hide a structural defect that
   is already recorded (`approval-pinning-self-invalidates`).
4. **`check_s2a_migration`'s C3 says "EXISTS at HEAD" and fires on the INDEX.** The check is right
   and the message is wrong; the file is inside the bundle, so a one-word repair costs a signature.
5. **Four of five registry stores carry no rows.** Each says why in its own header. The mechanism
   is exercised against synthetic registries; `check_registries` prints `0 means UNTESTED by this
   run` rather than a clean line.

**Real, and mine (3) — deliberately NOT started before this review**

6. **`run_schema_fixtures` judges the WORKTREE snapshot while the fast tier is a pre-commit hook.**
   A staged-but-different snapshot passes C1 on worktree bytes.
7. **`reconcile()` reads the working tree too** — same root as 6. Both are the same question asked
   of the whole tier, not of one line, so they want one design rather than two patches.
8. **R4's sweep scope** could widen to the globs named in 2.

**No practical impact (1)**

9. An ABSENT snapshot exits 3 (TOOL) where "no document" is more accurate. No reader takes that
   path — `Get-VerifiedSnapshot` `Test-Path`s first and returns `Code=MISSING`.

**Also recorded, and it needs a decision rather than a fix:** the fast tier is **39.4s** (median of
five clean runs: 38.1 / 38.8 / 39.4 / 39.6 / 41.1) against a **15.0s advisory** budget. Most of the
growth is ajv startup in fixtures that are now BUILT through the real pipeline instead of
hand-authored, which is the cost of the tests being real. Per-path selection keeps a normal commit
at 11–29s.

## ALREADY FOUND AND FIXED IN ROUNDS 1–3 — do not re-report

**Seventeen findings from three prior review rounds are fixed and fixtured.** Re-reporting them
costs a round. Each is listed with the counter-example that produced it, so you can tell in one
read whether the repair actually holds — which is a better use of the round than re-deriving them.

### Round 3 (7 findings, all reproduced before acceptance)

| | what it was | how it is closed |
|---|---|---|
| **P0** | `_stat_evidence` hashed bytes through one `open()`, closed it, then `os.path.getmtime(PATH)` — hash of OLD bytes with mtime of NEW | one handle: `os.fstat(fh.fileno())` |
| **P1** | R3 scanned rows only, so `{"_comment":"note","verdict":"DEAD-STRUCTURAL"}` gave zero problems | metadata records scanned too |
| **P1** | `_comment` on a real coverage row ERASED it (1 cell → 0/0/0 universe) | ONE `registry.classify_record`; a record that is both note and data is REFUSED |
| **P1** | R5 accepted required values set to `null` + an unknown field; ajv rejected the same object | live rows validated against their entity in `run_schema_fixtures.py`, where ajv already runs |
| **P1** | L0 globbed `check_*.py` only — 11 `scripts/check_*.ps1` were invisible to a completeness claim | both globs; `L1_NOT_PARSED` declares each with its reason |
| **P2** | `build_id` ignored freshness — age 1h and 31h gave one id across two different verdicts | `mtime` + `fresh` hashed; `age_hours` deliberately not |
| **P2** | inline code in a title read as the status — **11 live rows** misclassified | first span whose verb is a KNOWN status, old behaviour as fallback |

### Round 2 (10 findings)

Reader still returned different bytes than it verified (the repair for a two-read defect was itself
a two-read defect) · L2's `[A-E]` regex found zero criteria in a checker emitting `R1–R6`, so the
declared pair was inert · R5 compared the discriminator string only · a `_comment` key hid a whole
row · **`-BindingsRoot` bought permission** — `--root` REPLACED the store, so canonical `LOCKED`
gave REFUSE and an empty root gave ALLOW; it passes `--overlay-root` now and canonical wins every
key it defines · `build_id` ignored the reconciliation · a wrong-shape coverage row was silently
counted as an empty universe · `canonicalize` left a partial mutation and ignored its own `--root` ·
`CANCELLED(agent)` landed in `cancelled_by_user` · one commit missing its trailer.

### Round 1 (1 finding)

`registry.resolve()` returned `optimizable=None` / `source=UNBOUND` and `optimize_guard` dropped it,
so a run declared to belong to a revision swept a parameter that revision never described and
nothing said so. It emits a NOTE now — **not** a refusal, because whether a revision's binding set
must be COMPLETE is undecided. **The open question stands and your opinion on it is wanted.**

---

## ORIGINAL ROUND-1 DETAIL, kept because the repair pattern is the interesting part

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
