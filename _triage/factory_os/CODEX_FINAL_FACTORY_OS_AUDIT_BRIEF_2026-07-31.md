# Review brief — Factory OS tranche, 2026-07-31

This is a code-quality and data-conformance review of validation scripts and the data files they
validate, all inside this repository. No external system, no third party, no security dimension.
The core question throughout is standard conformance testing: **can a file satisfy every check while
still being wrong in the way the check exists to prevent?**

Everything below is stated as facts and questions. No verdict from the author is included, and the
commit messages are not evidence — read the code.

---

## 1. Scope

| | |
|---|---|
| base commit | `d4e5716c` |
| final commit | `33292571` |
| commits | 7 |
| branch | `master` (no push, no rebase, no amend, no force) |
| tranche | 3 taskboard Orders: **ORDER-610** (executed), **ORDER-611** (executed), **ORDER-612** (specified only, not executed) |

```
33292571 ORDER-612: specify S4, and settle the identity question it was waiting on
f92e06f6 ORDER-611: every entity now rejects a crafted bad instance, 27 of 27
8a38019a ORDER-611: close S3, and state how far short it actually fell
1a92ec42 ORDER-610 follow-through: the approval mechanism self-invalidates on execution
a424e90b ORDER-610: execute the S2 Coverage transfer, in one commit, losing nothing
c18eb128 ORDER-610: the S2 Coverage transfer, written before anything moves
3cebd559 Ledger: reserve the overnight Factory OS lane, and re-derive the two summary lines
```

### Changed paths, grouped by slice

**S2 — Coverage ownership transfer (ORDER-610)**
```
A  factory/coverage.jsonl                              the new canonical store
A  _triage/factory_os/gen_coverage.py                  generator
A  _triage/factory_os/check_coverage_transfer.py       acceptance validator
A  _triage/factory_os/run_coverage_transfer_tests.py   negative fixtures
M  MASTER_BACKLOG.md                                   banner + section 2 (+4 lines, 0 deletions)
M  _triage/factory_os/run_s2a_gate.py                  one advisory branch
A  _triage/USER_TASKS_2026-07-31.md                    the owner decision this surfaced
```

**S3 — per-entity schema fixtures (ORDER-611)**
```
M  _triage/factory_os/run_schema_fixtures.py           +54 cases, isolation harness, coverage criterion
```

**Tier wiring (both)**
```
M  scripts/_test/run_contract_binding_tests.ps1        3 new entries
M  scripts/_test/run_fast_cages.ps1                    $SUITE_GUARDS declarations
M  .githooks/fast_tier_pathspec                        regenerated (54 entries)
```

**Governance**
```
M  AGENT_TASKBOARD.md                                  3 Order rows
M  docs/SESSION_LEDGER.md                              lane reservation + 2 summary lines
```

---

## 2. Commands and expected exits

Interpreter is committed in-repo at `tools\python312\python.exe`. `ajv-cli` must be on PATH.

```
tools\python312\python.exe _triage\factory_os\run_s2a_gate.py                  -> 0
tools\python312\python.exe _triage\factory_os\run_coverage_transfer_tests.py   -> 0
tools\python312\python.exe _triage\factory_os\check_coverage_transfer.py       -> 0
tools\python312\python.exe _triage\factory_os\run_schema_fixtures.py           -> 0
tools\python312\python.exe _triage\factory_os\run_s2a_migration_tests.py       -> 0
tools\python312\python.exe _triage\factory_os\run_s2a_attestation_tests.py     -> 0
tools\python312\python.exe _triage\factory_os\check_s2a_attestation.py         -> 1   (see Q1)
powershell -File scripts\_test\run_contract_binding_tests.ps1                  -> 0
powershell -File scripts\_test\run_guard_trigger_tests.ps1                     -> 0
powershell -File scripts\_test\run_fast_cages.ps1                              -> 0   (12 suites, 24.9s)
powershell -File scripts\check_state.ps1                                       -> 0   (CLEAN)
```

`check_s2a_attestation.py` exiting **1** is deliberate and is the subject of Q1.

---

## 3. The five questions this brief exists for

### Q1 — a guard was downgraded to an advisory. Is the downgrade admissible, and can it be widened?

`_triage/factory_os/check_s2a_attestation.py` reports the S2a attestation log invalid because the
owner's approval pins `MASTER_BACKLOG.md` at blob `ca909b69`, and executing the approved transfer
changed that blob. `check_coverage_transfer.py::a8_attestation_still_valid` converts that specific
failure into an advisory, and `run_s2a_gate.py` defers to
`check_coverage_transfer.py --explain-attestation` rather than re-deriving the reasoning.

Questions:
- Construct an input where the attestation is invalid for a **different** reason and the downgrade
  still fires. `attestation_failure_is_the_expected_pin()` parses lines beginning `-> `; is that
  parse defeatable by a message whose text happens to match, or by a second problem printed in a
  form that does not start with `-> `?
- `transfer_in_place` is computed as `body_is_generated and not problems`, where `problems` is the
  list accumulated **so far** in `check()`. Is any criterion evaluated after A8 that should have
  been able to veto the exemption?
- `--explain-attestation` calls `check(skip_a8=True)`. Does that create a path where the gate's
  exemption is granted using a different reading of the repository than the one the failing
  attestation used?
- Is the exemption reachable when the transfer has been reverted but the store still exists?

### Q2 — does `factory/coverage.jsonl` actually cover what `MASTER_BACKLOG.md` §2 used to?

The owner's approval was conditional: §2 must not become generated output until the store covers at
least the hand table. `check_coverage_transfer.py::a2_covers_the_hand_table` rebuilds a baseline from
pinned blob `ca909b69` via `gen_coverage.build_records()` and compares.

Questions:
- `build_records()` reads the reconciliation from the **working tree** (`RECONCILIATION_PATH`) while
  the section-2 text comes from the pinned blob. Is that a mixed-vintage read, and can it be
  exploited to make the baseline thinner than the real hand table?
- The comparison keys cells on `(cell, source_token)`. What information present in the 2026-06-27
  hand table is **not** expressed in either `source_columns` or `cells`, and would therefore be lost
  without any criterion noticing?
- `run_coverage_transfer_tests.py` ends with an inertness probe asserting the self-referential
  baseline accepts a deletion. Does that probe actually exercise the production code path, or does
  it exercise a stand-in that resembles it?

### Q3 — is condition 1 enforceable across commits, or only within one?

`a1_banner_and_body` asserts a biconditional between "section 2 is generator output" and "the top
banner carries the required phrase", reading both from the **git index** by default
(`read_input`, `git show :path`).

Questions:
- Stage only `MASTER_BACKLOG.md` and not `factory/coverage.jsonl`, or vice versa. What does the
  checker judge, and is the answer the same as what the commit would contain?
- `read_input` falls back to the working tree when a path is not in the index. Is there a state
  where one input comes from the index and the other from the working tree, and does anything
  refuse that combination rather than printing a verdict?
- The phrase check uses `normalize()`, which strips backticks and asterisks and lowercases. Can a
  line satisfy it while a human reading the rendered Markdown would not see the notice?
- Nothing in the repository parses §2 except `check_s2a_migration.py::parse_section2`. Verify that
  independently. If a second reader exists, the owner's risk assessment was made on a false premise.

### Q4 — is the per-entity schema coverage real, or is the harness passing everything?

`run_schema_fixtures.py` gained an **isolation harness**: a generated schema
`{case_entity, instance}` with one `if/then` per `$defs` entity, so exactly one contract evaluates.
54 cases, 27 entities, both directions.

Questions:
- An `if` that does not match contributes no errors. Enumerate the ways an entity's branch could
  fail to fire while its cases still report as declared. Three probes claim to close this
  (`harness-unknown-entity`, `harness-routes-to-the-named-contract`,
  `harness-control-same-entity-validates`) — are they sufficient?
- `entity_coverage()` counts a negative only when `c['says']` is non-empty. Is a `says` that matches
  a trivially-present error enough to earn coverage? Write one and see.
- The coverage control monkeypatches `schema_entities` to inject a 28th entity and expects exactly
  2 complaints. Does that prove enumeration, or only that the injected name appears twice?
- `run_batch` attributes ajv output to cases **by basename** of a temp file. Can two cases collide?
- 15 entities had no negative before this change and 5 had a positive. Confirm that count against
  `d4e5716c`, and check whether any of the 54 new cases is a positive that validates for a reason
  other than the one its name claims.

### Q5 — composition across the two slices

- `run_contract_binding_tests.ps1` now runs 8 entries in sequence. Does any entry mutate state that
  a later entry reads? `run_schema_fixtures.py` and `run_coverage_transfer_tests.py` both write temp
  files and both monkeypatch module globals in `try/finally`.
- `run_s2a_gate.py` now imports and shells out to `check_coverage_transfer.py`, which shells out to
  `check_s2a_attestation.py`. Trace the `os.chdir` handling across that chain.
- The attestation `bundle_sha256` binds six files. Confirm none of the six changed in this tranche,
  and that no new file *should* have been in the bundle.

---

## 4. Specific claims to verify or refute

Each of these is asserted somewhere in the tranche. None should be taken on trust.

1. The `MASTER_BACKLOG.md` diff is **+4 lines, 0 deletions**, and all 7 table rows are byte-identical
   to blob `ca909b69`.
2. `factory/coverage.jsonl` carries **7 records / 40 cells / 8 LIVE**, matching the reconciliation.
3. `run_coverage_transfer_tests.py` runs **18 mutations + 2 controls + 2 tool-failure cases + 6 A8
   downgrade cases + 1 inertness probe**, and every one is asserted by reason, not by exit code.
4. `run_schema_fixtures.py` runs **89 cases (35 root + 54 per-entity)** and **27/27** entities have
   both a validating case and a named negative.
5. No entity list is hand-maintained anywhere in the tranche.
6. `check_state.ps1` is CLEAN and `make_status.ps1` renders.
7. The full fast tier is **24.9s** against a **15.0s** advisory budget — already breached before this
   tranche; this tranche added ~4s (contract-binding 3.9s → 8.4s).

---

## 5. Trust boundaries, recovery, and privacy

- **Trust boundary:** `check_coverage_transfer.py` is the only place allowed to downgrade another
  checker's failure. Is that authority correctly bounded, and is it reachable from anywhere else?
- **Recovery:** every commit here is revertible in isolation. Verify that reverting `a424e90b` alone
  leaves a coherent repository, and that reverting `1a92ec42` alone leaves the gate red rather than
  silently green.
- **Partial failure:** if `ajv` is absent, `run_schema_fixtures.py` must report ERROR rather than
  counting instances as rejected. Confirm by removing `ajv` from PATH.
- **Secrets:** `factory/coverage.jsonl`, the three new `.py` files and `_triage/USER_TASKS_2026-07-31.md`
  should contain no account number, token, path outside the repo, or credential. Scan them.
- **Duplicated source of truth:** after this tranche, is coverage state stored in exactly one place?
  Check `MASTER_BACKLOG.md` §2, `factory/coverage.jsonl`,
  `_triage/factory_os/s2a_coverage_reconciliation.json`, and `portfolio/DEPLOYMENTS.csv` against each
  other and say which of them a reader should believe.

---

## 6. What did NOT happen, and should be confirmed as not having happened

- No Demo, Live, VPS or `_vps_deploy` path was touched. `git diff --name-only d4e5716c..HEAD` returns
  no `.set`, `.mq5`, `.mqh` or `.ex5`.
- No Telegram message was sent and no token was requested or stored.
- No MT5 tester lane was used. **No backtest was run in this tranche**, so no reported number depends
  on a lane.
- No magic number was allocated, renumbered or retired.
- `VISION.md`, `AGENTS.md` and the Decision log were not edited.
- No Order was marked `REVIEWED`.
- Slices **S4 through S15 were not implemented.** ORDER-612 specifies S4 and was deliberately left
  `OPEN`.

---

## 7. Explicitly out of scope for this review

- The 2026-06-27 staleness of the coverage data itself. The transfer moved ownership; it did not
  refresh content, by design and by the owner's condition.
- Whether the Factory OS design is the right design. That was audits 1–8.
- The 15.0s tier budget breach, which predates this tranche and is tracked separately.
