# Blind audit brief #6 — the snapshot validator, and whether the contract binding survived being moved

**Scope of write permission, stated once so it cannot contradict itself:** you may create or overwrite
**exactly one file**, `_triage/factory_os/CODEX_AUDIT6_2026-07-30.md`, which is your report. **Everything
else is read-only** — do not modify, stage, or commit any other path, and do not apply any fix you
recommend. If you cannot write that one file, return the report in chat; that is not a failure.

⚠️ **`AGENT_TASKBOARD.md` is held by another live lane** (`S-2026-07-30-SENSFAN`) with ~90 uncommitted
lines in the working tree, under a user instruction to hold all commits. **Do not read-modify-write it,
do not `git add -A`, do not `git stash`.** This working tree has concurrent writers.

Repo root: `D:\EA_LAB`. Interpreter: `tools\python312\python.exe` (no system Python). `ajv-cli` installed.

**On self-assessment.** Unlike previous briefs I cannot claim you have not been shown one: the commit
messages for `4a4d6003`, `87af43fd` and `d8920e57` are long and argue their own case, and you will hit
them immediately. **Treat every sentence in them as a claim to falsify, not as a finding.** Several of
them assert something was "measured" — re-measure it. One of them asserts a defect class was closed;
your job is to find the variant that survives.

---

## 1. What was built since audit 5

Audit 5 returned GO WITH AMENDMENTS on two draft Orders. `ORDER-601 part 2` has now been executed, and
one standing recommendation from your Q4 was carried out.

| commit | what it claims |
|---|---|
| `4a4d6003` | `snapshot_validator.py` — 13 predicates, `verify_snapshot` recomputes the verdict on read and refuses a mismatch; computation suite with a mutation table; V5 root closed; source row widened for the real v4 `{path,sha256,mtime}`; ajv 28 → 35 |
| `87af43fd` | the 30 generated contract tables moved **out of the design** into `_triage/factory_os/CONTRACTS.md`; design 1807 → 1166 lines; `validate_links` added as the replacement obligation |
| `d8920e57` | a self-review (`/scrutinize`) of the two above, claiming five defects found and fixed, plus a lint that had been crashing since `c8d03d4b` |
| `f203059e` | `MASTER_BACKLOG.md` rows D30/D31 updated to match |

**The audit-5 attack that drove all of this:** a hand-authored persisted snapshot with `sources: []` and
`all_clear: true`. It is structurally valid against every schema here, because JSON Schema cannot prove
authorship. The claimed defence is recomputation at the trust boundary.

## 2. What to read

| file | what it is |
|---|---|
| `_triage/factory_os/snapshot_validator.py` | **primary subject** — the 13 predicates, the refusals, `verify_snapshot` |
| `_triage/factory_os/run_snapshot_validator_tests.py` | its suite + the mutation harness (`--prove-harness` is a self-test) |
| `_triage/factory_os/SNAPSHOT_VALIDATOR_MUTATION_TABLE.md` | the generated deliverable |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md` | **ORDER-601's acceptance list — the spec this was built against** |
| `_triage/factory_os/gen_design_contracts.py` | now also holds `validate_links` |
| `_triage/factory_os/CONTRACTS.md` · `_triage/EA_LAB_FACTORY_OS_DESIGN.md` §4 | the relocation |
| `_triage/factory_os/run_schema_fixtures.py` | ajv suite; note the new `says` mechanism and the ajv-gate check |
| `_triage/factory_os/check_schema_structure.py` | the lint that was dead; now wired |
| `scripts/_test/run_contract_binding_tests.ps1` · `run_fast_cages.ps1` | four python scripts in one wrapper, and the budget |
| `scripts/control_room_snapshot.ps1` (`FileMeta`, ~L56 and L372-390) | **the real v4 writer** — the thing all of this is eventually for |

Run everything yourself. Take no number in a comment, commit message, backlog row or ledger row as
measured. Five commands reproduce the claimed state:

```
tools\python312\python.exe _triage\factory_os\gen_design_contracts.py --check
tools\python312\python.exe _triage\factory_os\run_contract_binding_tests.py
tools\python312\python.exe _triage\factory_os\run_schema_fixtures.py
tools\python312\python.exe _triage\factory_os\run_snapshot_validator_tests.py
tools\python312\python.exe _triage\factory_os\run_snapshot_validator_tests.py --prove-harness
```

## 3. Questions, in priority order

**Q1 — Are the thirteen predicates the RIGHT thirteen? Construct a snapshot that is `all_clear: true`
and should not be.**
This is the deepest open question and the mutation table explicitly does not answer it: it proves each
predicate is load-bearing *against this suite*, never that the set is sufficient. `all_clear` is going to
mean "the control room is trustworthy" to a human deciding whether to act on it. Read the real writer
(`control_room_snapshot.ps1`) and `ControlRoomSnapshotV5`, then find the fleet condition that is genuinely
alarming and that all thirteen predicates ignore. Candidates worth checking, not a closed list:
`system_health` rows, `unknown_magics` (note `unknown_magics_unclassified` exists precisely because a
collector can write an unreadable `last_seen`), `attestation` gaps, `floating_risk` rows whose state is not
FRESH, `judge_readiness` rate flags. **The evidence object is only about counting orders and coverage
cells — is that the right evidence for the word `all_clear`?** If the name overclaims what is checked,
say so and say what it should be called.

**Q2 — Break the recompute-on-read defence. Build a persisted document that `verify_snapshot` accepts and
a careful human would call a lie.**
Your audit-5 instance is now refused; find its successor. The extraction path is `facts_of()`, and the
same function is used for the builder input and the persisted document — look for facts the verdict is
NOT derived from, because anything outside `facts_of` can be edited freely without changing the
recomputed verdict. `summary`, `deployments.gaps`, and the top-level domains are all in the document and
none of them reach `compute()`. Is "the verdict matches its own evidence" a meaningfully weaker claim than
"the document is honest"? Also check: `verify_snapshot` recomputes `fresh` per row — does it recompute
everything else it should?

**Q3 — Is the mutation table gameable? Can a wrong validator produce a green table?**
`red_set_without()` disables one predicate and reasserts every fixture; the harness demands the red set
EQUAL the fixtures' declared `depends_on`. Attack it: (a) can a predicate be written so its removal
reddens the right fixture while the predicate itself is wrong (e.g. fires on the correct instance for the
wrong reason)? (b) `depends_on` is hand-declared per fixture — what stops a wrong declaration being
"fixed" by editing the declaration rather than the fixture? (c) `--prove-harness` plants a predicate no
fixture exercises and asserts the analysis names it; is that the only failure mode a mutation harness
has? (d) the three checks the table admits it cannot cover — `assert_decidable`, `derive_fresh`, and
`verify_snapshot` — are they covered by anything that can fail?

**Q4 — Did moving the tables out of the design weaken the binding, and is `validate_links` a real
replacement or a formality?**
Before `87af43fd`, "the design states this contract" was true by construction. Now it is `validate_links`.
Look at what the migration actually produced in the design: **30 link lines with identical boilerplate
text.** Ask whether the check now verifies anything more than "a link exists", and whether a document can
satisfy it while telling a reader nothing about the entity. Then the harder half: the 7 regressions are
still caught 7/7 — verify that independently by re-applying a mutation yourself — but is there a NEW
regression channel that the old inline layout would have caught and this one does not? Consider that
`--check` compares CONTRACTS.md against generated output, so any hand edit is reverted; what about the
design prose that now surrounds nothing?

**Q5 — The `NO_SCHEMA_CHECK` sentinel.**
`build_snapshot` and `verify_snapshot` take a required `schema_validator` argument which may be the
sentinel. The whole pre-commit computation suite passes the sentinel on every fixture. `d8920e57` claims
this was already the source of one real hole (a supplied `all_clear` inside the evidence, accepted and
ignored) and closed it with a recursive forbidden-key scan. **Find the next thing the sentinel path lets
through.** Is a required-but-skippable gate better or worse than no gate, given that the only enforced
suite skips it? Would you delete the sentinel and make the suite pay for ajv, or delete the gate?

**Q6 — Is `load_verified` vacuous, and does `x-enforced-by` still overclaim?**
`load_verified` is the stated single door for readers, and nothing calls it — wiring readers is S4.
`x-enforced-by` on several entities names validators that do not exist at all. Two questions: is a schema
annotation naming an unbuilt validator a documentation defect or a governance one, and what should
`x-enforced-by` say for the ones that are aspirational? Also check whether `snapshot_validator` is now
doing what its own `x-enforced-by` strings promise, per entity.

**Q7 — The budget, and whether this tier is now the thing that gets bypassed.**
The fast tier is measured at 14.1-14.3s against a 15.0s budget with 12 suites, one of which
(`run_contract_binding_tests.ps1`) now runs FOUR python scripts. `run_optimize_guard_tests.ps1` alone is
5.8s. The stated reason for the budget is that a slow hook gets `--no-verify`'d. Is 15s still the right
number, is the "fold it into an existing wrapper" move a genuine saving or a way of hiding cost from the
per-suite table, and what happens to the next cage? Note `run_schema_fixtures.py` (35 ajv cases) is NOT
in the hook tier at all — so the 35 cases everyone quotes are enforced by nothing automatic. Is that the
right split?

**Q8 — S4's real blocker.**
`run_schema_fixtures.py` prints the measured v4→v5 gap: root missing `entity`/`verdict`, meta missing
`build_id`/`mandatory_sources`/`reconciliation`, row missing `name`/`mandatory`/`read_ok`/`fresh` — the
real rows are `{path, sha256, mtime, age_hours}` and carry no name. Note also that `FileMeta` returns
`$null` for a missing file and the pipeline filters it out, so **a missing source silently vanishes from
the array** — which is the defect `mandatory_sources` exists to catch. Is the registry the right fix, or
should the writer stop dropping the row? And which field should be the source identity, `path` or `name`?
Give a recommendation; that decision is currently parked as "belongs with the readers".

## 4. What a useful report looks like

Ordered by severity, each finding with: the defect, the **instance or command that demonstrates it**, and
what you would change. A finding I can reproduce in one command is worth more than three I have to
reconstruct. If a claim in a commit message is false, quote it and show the measurement.

**Say plainly if the answer to Q1 is "the predicate set is fine".** Two of the last three audits found a
P0 in the thing that had just been declared done, so a clean answer to Q1 is information — but only if you
tried to break it and say how.

End with a one-line verdict on whether `ORDER-601` should be closed as DONE, and on whether the
relocation in `87af43fd` should stand, be amended, or be reverted.
