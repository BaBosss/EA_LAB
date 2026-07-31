# Which bytes does a pre-commit guard judge? — one answer for the whole tier

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the design for how every checker in
> the fast tier chooses between index bytes and disk bytes**. Written 2026-07-31 for `ORDER-670`.
> Shapes it must not recreate: `docs/GUARD_SHAPES.md`.
>
> **rev 2** — rev 1 was attacked by an independent review (Fable, Codex quota exhausted) before any
> code was written. Ten findings; the three that changed the design are verified below by hand, and
> **rev 1's central argument was wrong twice at once**. The rev-1 text is not preserved — what it
> got wrong is stated in §7 instead, which is more useful than the paragraph that was wrong.

## 1. The measurement, before the argument

```
grep -ho "# snapshot: [a-z-]*" _triage/factory_os/*.py scripts/*.ps1 scripts/lib/*.ps1 | sort | uniq -c
     31 # snapshot: worktree
      1 # snapshot: not-a-judged-input
```

Thirty-one matches — and the honest breakdown, checked against each line rather than quoted from the
grep, is: **one is a fixture STRING** inside `run_guard_shape_lint.py`'s own self-test (not a read at
all), and **two annotate themselves as not-judged-evidence** (`gen_coverage`'s target is *"output,
not judged evidence"*; one `check_coverage_transfer` read is *"vocabulary only"*, its A2 copy being
pinned by blob). That leaves **28 declared reads of judged evidence across eight checkers, every one
of them the working tree, and not one declaring `index`** — which is the claim that matters, and it
survives the correction. Per file: `snapshot_build` 7 · `check_registries` 5 ·
`check_schema_structure` 5 · `registry` 5 · `gen_coverage` 2 · `snapshot_validator` 2 ·
`check_coverage_transfer` 1 · `run_schema_fixtures` 1. <sub>rev 2 first quoted "31 reads of judged
evidence" straight off the grep — a count stated without reading its own members, in the document's
own shape-4 section. Caught by `/scrutinize`, not by either review.</sub>

Three qualifications, because this is a declaration count and not a behaviour count:

- `check_coverage_transfer.read_input()` is **index-first already**; its `worktree` declaration sits
  on the fallback branch. It is the one place in the repo that solves this problem, and it solves it
  for one checker.
- `check_s2a_attestation.py` and `check_s2a_migration.py` carry no declarations — excluded from L1
  because they sit inside the attestation bundle. A7 there **already reads staged bytes**, because
  it was the P0 that taught us this.
- 🔴 **The grep covers `scripts/*.ps1` and returns zero, and rev 1 read that as clean. It means
  UNMEASURED.** `.githooks/pre-commit` runs **six** PowerShell guards ahead of the tier —
  `check_state` · `check_precommit_staged` · `check_order_collision` · `check_handoff_contract` ·
  `check_experiment_events` · `check_verdict_kill` — and they judge boards, the ledger and handoffs,
  which are committed evidence by any reading. `check_precommit_staged` already reads the index per
  its own header; `check_order_collision` reads the ledger from `HEAD`. So the PowerShell side is
  **partly solved, unevenly, and undeclared**. Scope decision in §6.

**The tier is a pre-commit hook. A commit contains the index.** So for every input that is evidence
about what the commit will contain, the tier currently judges a document the commit will not contain.

Not hypothetical, not new. `ORDER-615` S1: A7 judged the working tree, so staging a deletion of a
line and restoring the working copy reported **0 problems** on an append-only guard — history could
be rewritten with the gate green. Repaired in **one** checker. The same defect is structurally
available in the other thirty.

**L1 does not close it, by its own admission.** It forces a read to declare a snapshot; its header
says it "stops a checker reading bytes WITHOUT SAYING WHICH". A wrong declaration passes. The
declaration is a comment: it does not choose the bytes.

## 2. The rule — one sentence, and it assigns all 31 reads without arguing about any of them

> **A BUILDER observes the world. A CHECKER judges the commit.**

A builder produces an artifact describing *this machine now* — its inputs are the disk, and reading
them from the index would be fiction (an index blob has no mtime, and several of its sources are
written by MT5 and are not the commit's business at all). A checker answers *"are the bytes entering
history acceptable"* — its inputs are the index, and reading them from the disk is the A7 defect.

| | category | who | bytes |
|---|---|---|---|
| **A** | **committed evidence** | checkers, lints, conformance suites | the **index** in hook mode; the worktree when a human runs the suite by hand |
| **B** | **observed world** | builders and sensors | the **disk**, always, in both modes |
| **P** | **pinned** | a baseline pinned by blob sha (`gen_coverage`'s A2) | the **blob**, never either of the above |
| **C** | **synthetic root** | a fixture's temp tree | the root it was handed |

Applied: `snapshot_build` (builder) → **B**, all seven. `check_registries` ·
`check_schema_structure` · `run_schema_fixtures` · `check_coverage_transfer` ·
`run_guard_shape_lint` (checkers) → **A**. `gen_coverage` → **P** for its baseline, output for its
target. `registry.py` and `snapshot_validator.py` are **libraries**: they take the source from the
caller and are never allowed to choose (§3.3).

**The document does not carry two vintages.** The snapshot is one vintage — this machine, now —
including `reconcile()`. The commit-vintage claim *"the artifact this commit contains is valid"* is
made **by a checker** (`run_schema_fixtures`' C1 reads the committed snapshot from the index), never
by the builder that wrote it.

## 3. The design

### 3.1 One reader, three named entry points, and an explicit source

`_triage/factory_os/evidence.py`, generalising `check_coverage_transfer.read_input()`:

```python
src = EvidenceSource.for_run()      # ONE per process: index-in-hook, worktree otherwise
src.read_committed(rel)             # category A
src.read_blob(sha, rel)             # category P
observe(path)                       # category B — module-level, no source, always the disk
src.list_committed(pattern)         # category A ENUMERATION — see 3.2
```

The category is in **the function name at the call site**. The *tree* is in the source object, which
is passed exactly where `root=` is passed today — so a fixture hands a synthetic-root source and the
call site does not branch. That is what keeps §3.1's "no boolean flag at the call site" true for
functions whose callers span categories A and C.

### 3.2 🔴 Enumeration is a judged read, and rev 1 did not have it at all

`read_committed(rel)` picks the bytes of a path the checker already knows. **`glob()` picks the
paths**, and it reads the disk. Two live instances, both in the first migration target's blast
radius:

- `check_registries.check_r4()` globs `_triage/factory_os/*.py` + `scripts/*.ps1` sweeping for a
  second copy of the role vocabulary. **Attack:** `git add rogue.py` carrying the vocabulary, delete
  the worktree copy, commit ⇒ the commit contains a second vocabulary, the glob never sees it, R4 is
  green. This is A7's exact shape through a channel nothing had named.
- `snapshot_build`'s `TASKBOARD_GLOB` completeness check — same attack with a staged
  `ROGUE_TASKBOARD.md`. (Category B after §2, so it is correct there; it is listed because the
  *shape* generalises and the next checker that enumerates will be category A.)

⇒ `list_committed()` enumerates via `git ls-files --cached`, and a category-A checker may not call
`glob` on a repo path. The inverse also matters: an **untracked** scratch file under a swept
directory is enumerated from disk today and would then hit §3.3's untracked refusal — the tier would
block a commit over a file the commit does not contain. Enumerating from the index removes both
directions at once.

### 3.3 What `read_committed` refuses

Adopting the `read_input` precedent verbatim, because it was paid for twice (S1, then Spec4 — "the
fix only refused MIXED sources; worktree/worktree walked through it"):

- tracked and readable from the index ⇒ index bytes;
- **tracked but unreadable from the index ⇒ `ToolFailure`**, never a fallback;
- untracked, in hook mode ⇒ `ToolFailure`;
- absent from both ⇒ the existing refusal, which already distinguishes *absent* from *empty*.

A library (`registry.py`) that is handed no source **refuses**; it does not default. A default is how
the resolver would silently become a second decider of which bytes count.

### 3.4 🔴 How the mode arrives — rev 1's mitigation was a blacklist

Rev 1 said each checker prints its mode and the tier fails if any suite reports `worktree`. That is
**shape 2**: absence of the bad word passes, so a checker that prints nothing — crashed early, added
later, output summarised by its wrapper — is read as compliant. It is `FORBIDDEN_KEYS` again, inside
the mitigation of the design written after that lesson. And suite stdout legitimately contains the
word `worktree` (negative fixtures exercise `--worktree`), so a scan cannot tell this-run's mode from
a mode quoted inside a test.

Replaced with an allowlist and one setter:

1. **Hook-ness is an ARGUMENT, not an env var.** `.githooks/pre-commit` passes `-Hook` at **both**
   call sites — including the fail-closed branch that currently invokes the tier with no arguments
   at all. An argument cannot fail to arrive from a caller that is one file with two lines.
2. **The tier is the only setter.** Given `-Hook`, `run_fast_cages.ps1` sets `EA_LAB_EVIDENCE=index`
   for its children. The chain is tier → suite → python, not hook → tier → suite → python; there is
   one place that decides and it is the place that also verifies.
3. **Every selected suite must emit exactly one structured marker** — `##EVIDENCE-MODE## <suite>
   <mode>` — and the tier requires **one marker per selected suite, with the expected value**.
   Missing ⇒ fail. Two ⇒ fail. Wrong ⇒ fail. A fixture quoting the word `worktree` in prose cannot
   forge a marker, and a suite that forgets to emit one cannot pass by silence.

### 3.5 What happens to the L1 lint

L1 stops accepting a comment as the answer for category A: a repo-relative read in a checker that
does not go through `read_committed`/`list_committed` is reported. `observe()`, `read_blob()` and
fixtures' synthetic roots stay declaration-only — the lint cannot tell a temp tree from a repo tree
except by asking, and **it must not fire on them**, or it becomes the guard that refuses valid work
(the `optimize_guard` lesson, Decision log 2026-07-30).

## 4. What this does NOT fix — stated here so it is not discovered later as a finding

1. **A wrong `observe()` is still possible.** Calling `observe()` where `read_committed()` belongs is
   judgement, and no lint reads intent. What changes is that the choice is a **call** a reviewer can
   grep, instead of a comment nobody reads.
2. 🔴 **Index-vintage and disk-vintage hashes are incommensurable on this machine, and no criterion
   may equate them.** `core.autocrlf` is on: blobs are LF, the working tree is CRLF. `observe()`
   hashes CRLF bytes into committed snapshots today. A checker asking *"does the commit's copy of
   this source match the snapshot's `sha256`?"* **cannot be written correctly** — it would be red on
   every commit forever, or green by tautology. This sentence goes in `evidence.py`, not only here.
3. 🔴 **A hook judges a TEMPORARY index whenever the commit is partial.** `daily_monitor.ps1:126`
   runs `git commit $monitorPaths` — a pathspec commit — and this repo's most frequent committer is
   that scheduled job. Git publishes the temp index to hooks via `GIT_INDEX_FILE`; `git show :path`
   is correct **only because that variable inherits** through sh → ps1 → ps1 → python. A second,
   undesigned env chain, with exactly the fragility §3.4 distrusts. ⇒ `evidence.py` **records
   `GIT_INDEX_FILE` in its mode marker** so a run says which index it judged, and never scrubs the
   environment of its children.
4. **A concurrent writer can move the index mid-tier.** The monitor chain and a manual run can
   overlap on this machine (`snapshot_build`'s own tmp-file comment records it, reproduced). Two
   `read_committed` calls in one run can straddle two indexes — the mixed-vintage pair one level up,
   with no cross-checker analogue of the mixed-source refusal. **Detected, not prevented:** the tier
   records `HEAD` and the index mtime at start and end and refuses if either moved (T6).
5. **This does not make the hook judge the commit**, only the index. They differ if anything writes
   between the hook and the commit.
6. **Manual runs still judge the worktree**, by design ⇒ a green manual run is not evidence about a
   commit. The marker prints the mode so a reader can tell which claim they are holding.
7. 🔴 **`GIT_INDEX_FILE` is poison to any git run against a DIFFERENT repository** — discovered
   live while landing `ORDER-670` part 1, not predicted here. A partial commit publishes its temp
   index through that variable; a test fixture running `git -C <temp> add -A` inherited it, git
   resolved it against the *fixture* repo, saw all 5,135 real entries as deleted-from-worktree,
   and **removed them from the real commit's index**. Three commit attempts were blocked only
   because a diagnostic case happened to read the wreckage. Containment (both layers, with the
   `T-GIF` attack/specificity pair): `evidence._run_git` scrubs the variable for any root that is
   not this repo; fixture git helpers scrub it always. The rule generalises: **a hook-published
   env var names state of ONE repository, and any subprocess aimed at another repository must be
   stripped of it.** Suites that run git in fixture repos outside the tier (`run_order103/105`)
   carry the same hazard if ever run under a hook.

## 5. Acceptance, with the shape-5 pair on every criterion

Shape 5's mechanical half: a fix commit carries **two** assertions — the attack, and one that fails
if the new mechanism is inert or an untouched surface moved.

| | criterion | the attack (red before) | the engagement/specificity assertion |
|---|---|---|---|
| **T1** | `read_committed` reads the index in hook mode | stage a corrupt registry row, restore a clean worktree copy ⇒ **RED**. Today: green. | with nothing staged, each suite's output is byte-identical to its pre-change output **modulo the one declared marker line** — the repair must not change what a normal run says |
| **T2** | no silent fallback | tracked-but-unreadable ⇒ `ToolFailure` · untracked in hook mode ⇒ `ToolFailure` | a **worktree/worktree** pair (Spec4's escape) is refused too, not only a mixed pair |
| **T3** | enumeration comes from the index | stage `rogue.py` carrying the role vocabulary, delete the worktree copy ⇒ R4 **RED** | an **untracked** file under a swept directory does **not** fail the tier — the untracked refusal must not reach files the commit never had |
| **T4** | the marker is an allowlist | run the tier as a hook with one suite emitting **no** marker ⇒ tier fails naming that suite | a suite whose *fixture output* contains the word `worktree` still passes — prose cannot forge a marker |
| **T5** | category B is untouched | `observe()`d freshness is computed from disk mtime while the index holds different bytes ⇒ the value still describes the disk | collapse the split (make `observe` read the index) ⇒ the monitor suite goes **RED**. A split nothing tests gets collapsed by the next editor. |
| **T6** | mid-run index movement | move `HEAD`/the index between two suites ⇒ the tier refuses | a normal run does **not** trip it — a detector that fires on every commit is one that gets switched off |
| **T7** | L1 binds | a new category-A read with a correct comment but no `read_committed` call ⇒ lint **RED** | a read inside a fixture temp root, an `observe()` and a `read_blob()` are **not** flagged |

**Not acceptance, and it will be tempting to treat it as one:** "all suites still pass". They pass
today, against the wrong bytes. A green tier proves nothing unless T1 and T3 were observed red first.

## 6. Scope and sequencing

**In scope for `ORDER-670`:** `evidence.py` + the mode plumbing + T1–T7, proven against **one**
checker — `check_registries`, the smallest category-A surface (5 reads) and the one that carries the
T3 attack. Then the remaining checkers migrate **one commit each**, each carrying its own T1 attack.
Thirty-one reads converted in one commit is a change nobody can review, and reviewing badly is what
produced this order.

**Out of scope, named rather than left silent:** the six PowerShell front guards of §1. They need the
same answer and `evidence.py` gives them no entry point; two of the six are already partly correct
and nobody wrote down which. That is a **separate order** and it is filed rather than folded in —
but §1's grep must never again be quoted as evidence that they are clean.

## 7. What rev 1 got wrong, kept because the error is the useful part

Rev 1 argued at length that `snapshot_build.reconcile()` was category A, producing one document with
two vintages "deliberately", and named that as the single point a reviewer should push.

**It was wrong twice, and both halves were verified here by hand before being accepted:**

1. **It is shape 1.** The snapshot has exactly **one** verdict: `snapshot_validator.compute()` folds
   every predicate into one `reasons` list and `reconciliation_clear = not reasons`. So
   `MANDATORY_SOURCE_STALE` (disk mtime) and `ACTIONABLE_PRESENT` (board counts) would have landed in
   one boolean. That is `A2`'s crime — a pinned vintage joined to a live vintage inside one verdict —
   wearing a justification. One level down, this repo already refuses exactly that: `read_input`
   raises `ToolFailure` on a mixed pair because no verdict over it means anything.
2. **It was inert.** `reconcile()` has no hook-mode caller — production builds run from
   `control_room_snapshot.ps1` / `daily_monitor.ps1`, and every tier fixture passes
   `RECONCILIATION_NOT_DERIVED` or a temp root. The most-argued decision in the document would have
   changed the behaviour of **zero** executions, and **no acceptance row exercised it**. Shape 5's
   "the mechanism never engages", in a design written to hold the line against shape 5.

The correct split cost nothing to take: `reconcile()` returns **counts**, counts consume no mtime, so
§2's argument against reading B from the index never applied to it. Rev 1 never stated a sensor-side
cost of leaving it in B, because there is none.

<sub>The other seven findings are folded into the text above rather than listed: the enumeration hole
(§3.2), the blacklist mitigation and the hook-ness channel (§3.4), the `root`-spanning API collapse
(§3.1), the partial-commit temp index and the CRLF incommensurability (§4.2, §4.3), the unsatisfiable
byte-identity clause (T1), the pinned-blob false positive (§3.5) and the PowerShell scope claim
(§1, §6).</sub>
