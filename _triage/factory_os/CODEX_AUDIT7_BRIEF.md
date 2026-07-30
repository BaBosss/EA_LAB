# Blind audit brief #7 — S2a's migration table, and whether the amendments that made it satisfiable also weakened it

> **Note on wording (2026-07-30).** The first version of this brief was written in adversarial
> penetration-testing language ("rebuild the attack", "bypass", "defeat the purpose"). A Codex run on it
> was stopped by a content-moderation filter as possible cybersecurity work. Nothing about the task
> changed — this is **ordinary negative testing of a data validator inside this repo**: does a
> conformance checker accept inputs that satisfy its letter while failing the specification's intent?
> The brief now says that in plain QA terms. There is no security component, no external system, and no
> third party involved: subject and validator are both files in this repository.

**Scope of write permission, stated once so it cannot contradict itself:** you may create or overwrite
**exactly one file**, `_triage/factory_os/CODEX_AUDIT7_2026-07-30.md`, which is your report. **Everything
else is read-only** — do not modify, stage, or commit any other path, and do not apply any fix you
recommend. If you cannot write that one file, return the report in chat; that is not a failure.

⚠️ **This working tree has many unrelated modified and untracked files** (MT5 CSV output, `.obsidian/`,
portfolio CSVs) from other work. **Do not `git add -A`, do not `git stash`, do not `git checkout --`
anything.** Stage nothing. `AGENT_TASKBOARD.md` and `docs/SESSION_LEDGER.md` are declared by the live
lane `S-2026-07-30-S2AD1D2`; read them freely, write neither.

Repo root: `D:\EA_LAB`. Interpreter: `tools\python312\python.exe` (no system Python). `ajv-cli` installed.

**On anchoring — read this twice.** The commit messages for `03e98667`, `34acbd54`, `a1f854f6`,
`de240b33` and `59a27f97` are long, and they argue their own case at length. You will hit them
immediately and they will try to convince you. **Treat every sentence in them as a claim to falsify, not
as a finding.** They repeatedly assert something was "measured" — **re-measure it**. They assert three
defect classes were closed — **check whether a variant of each survives.** Two of those commits exist
only because the *previous* commit's self-review missed something, which is direct evidence that this
seat's self-assessment on this slice is not reliable.

Every judgement in this artifact came from **one seat** — the work, two rounds of acceptance amendment,
and the verdict. That is precisely why you are being asked.

---

## 1. What this is

`ORDER-600` (slice S2a) produces a **proposal about ownership**, not a change to it: for each of the 27
entities in `_triage/factory_os/schemas.json`, where that fact lives today, where the design proposes it
should live, and what breaks either way. It ends at the backlog owner's desk.

Its history matters because it is a history of the acceptance being **unsatisfiable**:

| rev | what changed |
|---|---|
| rev 1 | rejected in review #5 as too weak: 24 rows naming `schemas.json`, a constant in every hash field, nothing actually proposed |
| rev 2 | amended against review #5 (`2d166a34`) |
| rev 4 | `b56be960` — three clauses could not all hold; `current_owner` rules relaxed, `EMBEDDED:` introduced |
| **rev 5** | `03e98667` — **two more clauses could not hold**; `UNOWNED` introduced, D1's path corrected |

**Read `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md` first** (the ORDER-600 section, including both
amendment blocks). That is the spec. Then the artifacts.

## 2. What to read

| file | what it is |
|---|---|
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md` | **the acceptance — the spec everything below is measured against** |
| `_triage/factory_os/s2a_migration.jsonl` | **D1**, 27 rows, the primary subject |
| `_triage/factory_os/s2a_coverage_reconciliation.json` | D1's C8 companion (the two coverage numbers + mapping) |
| `_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md` | **D2**, generated from D1 — the document the owner reads |
| `_triage/factory_os/check_s2a_migration.py` | **D3**, the checker: 9 criteria + `--self-test` + the advisory |
| `_triage/factory_os/gen_s2a_migration.py` | D1's generator — the mechanical/judgement split lives here |
| `_triage/factory_os/gen_s2a_migration_doc.py` | D2's generator |
| `_triage/factory_os/run_s2a_migration_tests.py` | the test suite: mutations of the real D1 + 3 further parts |
| `_triage/factory_os/run_s2a_gate.py` | the aggregator wired into the pre-commit tier |
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` §1.1–1.3 | the ownership tables D1's judgement columns are built on |
| `MASTER_BACKLOG.md` §2 | the coverage matrix the headline row proposes to move |

Runnable, all expected green:
```
tools\python312\python.exe _triage\factory_os\run_s2a_gate.py
tools\python312\python.exe _triage\factory_os\check_s2a_migration.py
tools\python312\python.exe _triage\factory_os\check_s2a_migration.py --self-test
tools\python312\python.exe _triage\factory_os\run_s2a_migration_tests.py
```

## 3. The primary question — false-negative testing of the checker

A checker is only worth its refusals. Review #5 rejected rev 1 by writing, for each criterion, the
**cheapest input that satisfied the wording while carrying no useful content** — a 27-row file that was
formally valid and told the owner nothing. The rev-1 checker accepted it. **Repeat that exercise against
the checker as it stands**, as straightforward negative testing.

Two amendments were made specifically to make the order satisfiable, and each is an **exemption from the
criterion that was doing the most work**. Exemptions are where a formally-valid-but-empty file tends to
reappear:

- **`UNOWNED`** as a legal `current_owner` (rev 5), for entities with neither a file nor a parent.
- **`EMBEDDED:<Parent>`** and the wildcard **`EMBEDDED:*`** (rev 4 / rev 5), exempt from `owner_ref` pinning.

**Goal: produce a D1 that passes all nine criteria and would be useless to its reader.** If you can, the
acceptance is too weak and that is the headline finding. Candidate angles — not exhaustive, and do not
assume any of them is already handled:
1. How many of the 27 rows can legally become `UNOWNED`? What prevents all of them? **Test it by writing
   the file and running the checker**, rather than reasoning from the source.
2. `EMBEDDED:*` requires ≥2 parents "verified against the `$ref` graph". Can a row name a parent that
   references it for an unrelated reason, and so claim a pinning exemption it should not get?
3. The `owner_ref` pinning rule was tightened in `a1f854f6` after two ways around it were found. **Is
   there a third?** Look for a route other than the two that were closed.
4. C7 requires the Coverage edge row and forbids an all-`KEEP` table. What is the minimum number of
   non-`KEEP` rows that satisfies it, and is a table with exactly that minimum still a proposal?
5. C6 ("one signer per `current_owner`") — the generator assigns signers *from a dict keyed by owner*, so
   ask whether C6 can fail against any generated file at all, and therefore whether it checks anything.

## 4. Numbers to re-measure rather than believe

Each of these is asserted somewhere in D1, D2, a commit message or the board row. **Re-derive them
independently.** Any disagreement is a finding.

| claim | where it is asserted |
|---|---|
| 27 entities; **9** embedded in a parent, **14** with a real artifact at HEAD, **4** with neither | rev-5 block, D2, board row |
| §2 has **7** EA rows and **8** LIVE cells; D1 emits **40** cells total | `s2a_coverage_reconciliation.json`, D2 |
| the 32 non-LIVE cells are a complete and correct enumeration of §2's last column | `gen_s2a_migration.py` `OTHER` dict — **hand-curated, so most likely to be wrong** |
| **"nothing machine-reads `MASTER_BACKLOG.md` §2"** — the load-bearing claim of the whole proposal | `CoverageCell.breaks_if_moved`, D2 |
| `scripts/check_state.ps1:124` reads that file *only* to assert its owner banner | same |
| every `owner_ref` resolves and re-hashes correctly | C4 |
| fast tier 15.4s → 17.3s standalone, 15.7s in-hook, vs a 15.0s advisory budget | `run_contract_binding_tests.ps1` header |

The §2 claim deserves the most scrutiny: **the entire recommendation to approve the transfer rests on
it.** If any script, hook, skill, subagent definition or dashboard parses that table, the row's breakage
analysis is wrong and the recommendation should change.

## 5. The human-review checklist the checker explicitly cannot judge

`ORDER-600` states this and the checker prints it: a green run means the table is well-formed and its
hashes are real, **not** that the breakage analysis is any good. Per `TRANSFER` row (there are 12):

- [ ] `breaks_if_moved` names a **specific reader or writer** (file + what it reads), not a category.
- [ ] `breaks_if_not_moved` states a concrete failure happening or about to, with a date or trigger.
- [ ] `reverse_steps` are executable steps, not "revert the commit".
- [ ] `evidence_lost` names what cannot be reconstructed after `retention_window`.

**Check the citations, not the prose quality.** Several rows cite specific files and line numbers
(`scripts/check_state.ps1:124`, `scripts/check_block_staleness.ps1:57`, `RiskControl.mqh:142`) and
several cite repo memories and past ORDER numbers as evidence that a failure is real. **Open them.** A
citation that does not say what the row claims it says is a finding, and it is the weakness this artifact
is most exposed to, because 12 rows of judgement prose were written in one sitting.

## 6. Specific things I want an outside opinion on

1. **Can the owner actually approve?** `signoff_state = APPROVED` is defined as the owner's act in their
   own commit — but C2 **refuses** `APPROVED` outright, so the owner cannot record approval without
   editing the checker in the same commit. D2 states this and calls the relaxation "deliberately not
   pre-built". **Is that a sound design or a deadlock dressed up as a safeguard?** Propose the shape you
   would use.
2. **Is `UNOWNED` the right primitive at all**, or should those 4 entities have been out of scope for a
   *migration* table (nothing to migrate), with the set-equality criterion narrowed instead?
3. **`pin_vintage_notes()` is an ADVISORY, not a failure.** A pinned owner can change and everything stays
   green. The argument for advisory: failing would force a re-pin on every unrelated edit. **Is advisory
   the right severity, given the row's own citations can rot?**
4. **Memoization inside a checker.** `_REVPARSE_MEMO`, `_BLOB_MEMO`, `_TRACKED_MEMO`, `_PARENTS_MEMO`,
   `_ENTITIES_MEMO` were added for speed, justified as sound because git objects are content-addressed.
   **Look for a case where a cached value makes a check answer a different question than intended** — the
   test suite runs all criteria 25+ times in one process, which is exactly where a stale cache hides.
5. **Is the `run_s2a_gate.py` aggregator a good idea**, or does bundling five checks behind one exit code
   lose information the tier needs?

## 7. Also in scope — ORDER-601, whose re-check is still owed

`ORDER-601` (S3a, the snapshot validator) sits at `DONE` and has never been independently re-checked
since review #6's findings were fixed. Its fix commits are `161d2033`, `a7960e08`, `b8b332fc`,
`8a5dac5f`. **Review #6 returned NOT DONE and was right**; all 8 findings were then reproduced and fixed,
and a self-review found three more. Confirm the fixes hold and look for variants that survived:

- the headline finding in #6 was the **NAME**, not the arithmetic: `all_clear` → `reconciliation_clear`,
  because a snapshot with a `NO_SENSOR` fleet sensor and missing kill/judge controls verified `true`
  *correctly*. **Is the renamed field now honestly scoped, or does D2/the design still imply fleet health?**
- named and deliberately unfixed, all routed to S4 — confirm they are still true rather than quietly
  regressed: `verify_snapshot` proves **internal consistency, not authenticity** (`read_ok`, `age_hours`,
  `path`, `sha256`, `mtime` are builder claims taken at face value); **no reader calls `load_verified()`**
  (`x-enforced-by` says `BUILT_NOT_WIRED`); the real snapshot **still fails the V5 schema**
  (`run_schema_fixtures.py` prints the measured gap).
- `x-enforced-by` still names **7 validators that do not exist** (`hypothesis_validator`,
  `coverage_validator`, `candidate_validator`, `attestation_validator`, `receipt_validator`,
  `finding_validator`, `projection_validator`). You proposed splitting
  `x-enforcement-status: PLANNED | BUILT | WIRED`. **Is that still the right fix, and is it now more
  urgent given S2a adds another checker to the inventory?**

## 8. Report format

Write `_triage/factory_os/CODEX_AUDIT7_2026-07-30.md`:

1. **Verdict on ORDER-600: DONE / NOT DONE** — against the rev-5 acceptance as written, per criterion.
2. **Verdict on ORDER-601's re-check: REVIEWED-able / NOT** — it cannot go `REVIEWED` on this seat's word.
3. **Findings, severity-ordered.** For each: what is wrong, the evidence (path/line/command output), the
   consequence, and the minimal fix. **Separate "I reproduced this" from "I suspect this."**
4. **If you produced a passing-but-useless D1, include it** — the input is worth more than the prose.
5. **What you checked and found sound**, so the coverage of this audit is legible.
6. **Anything the brief steered you away from** that you think matters. Previous reviews found their best
   material outside the questions asked; review #6's headline finding was a naming problem nobody asked
   about.

Do not soften. A NOT DONE that is right is worth far more than a DONE that is polite — review #6's NOT
DONE was correct and is the reason this slice is in a defensible state at all.
