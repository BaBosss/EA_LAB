# HANDOFF 2026-07-31 — Factory OS overnight tranche

Lane `S-2026-07-31-FACTORYNIGHT` · blocks **610-619** and **620-629** reserved, **612** is the highest
number used · commit range **`d4e5716c` → `33292571`** (7 commits, `master`, no push).

---

## 1. Where to start next session

**`ORDER-612` (S4 — snapshot v5 + fail-closed readers). It is fully specified and nothing blocks it.**
The design decision it was waiting on — whether a source row's identity is `path` or `name` — is
**made and recorded in the order**: it is both, `path` physical and `name` logical, because
`mandatory_sources` enumerates names and a path-keyed registry reports a missing mandatory source the
first time a file is renamed.

Read `ORDER-612`'s C4 and C6 before writing any code. C6 is the sharp one: `make_status.ps1` runs
after every commit, so a reader that fails closed on a **bad** snapshot is correct while a reader
that fails closed on a **missing** one blocks every commit in the repo.

---

## 2. What was completed

| slice | Order | state |
|---|---|---|
| **S2** Coverage ownership transfer | `ORDER-610` | `DONE — AWAITING CONSOLIDATED CODEX AUDIT` |
| **S3** per-entity schema fixtures | `ORDER-611` | `DONE — AWAITING CONSOLIDATED CODEX AUDIT` |
| **S4** snapshot v5 | `ORDER-612` | `OPEN` — specified, deliberately not started |

**S2:** `MASTER_BACKLOG.md` §2 is now a generated projection of `factory/coverage.jsonl`. The whole
diff is **+4 lines, 0 deletions** — the 7 hand rows are byte-identical, which is the owner's
"must not be thinner" condition satisfied by byte equality rather than by assertion.

**S3:** 27/27 entities now have both a case that validates and a negative that names its own failure.
Before: 12 entities had a negative, 5 had a positive, and `OwnerRef` — the pin primitive every other
entity references — had never been validated in either direction. The suite is finally wired into the
pre-commit tier.

---

## 3. Blocked — needs the owner, and only the owner

🔴 **`_triage/USER_TASKS_2026-07-31.md` §1.** Executing the approved Coverage transfer changed the
blob the owner's approval pins, so `check_s2a_attestation.py` now objects to the change it
authorized. **This is general: every approved `TRANSFER` in D1 will do it.** All three seat-side
repairs are worse than asking — writing the acknowledgement manufactures the owner's words,
re-pinning D1 voids the approval via `bundle_sha256`, and repairing the checker is impossible from
inside because it is a member of its own bundle. It is reported as a loud advisory with two costed
options, not swallowed.

Also still open from yesterday: `_triage/USER_TASKS_2026-07-30.md` §1 (dispatching the Codex audit).

---

## 4. Tests, raw

```
run_s2a_gate.py                    exit 0   (6 of 7 steps green, 1 ADVISORY -- see section 3)
run_s2a_migration_tests.py         exit 0   32 mutations
run_s2a_attestation_tests.py       exit 0
run_enforcement_status_tests.py    exit 0   5 mutations
run_schema_fixtures.py             exit 0   89 cases (35 root + 54 per-entity), 27/27 entities
run_snapshot_validator_tests.py    exit 0
run_contract_binding_tests.py      exit 0
run_coverage_transfer_tests.py     exit 0   18 mutations + 2 controls + 2 tool-failure + 6 A8 + probe
check_coverage_transfer.py         exit 0   (1 owner decision owed, printed)
check_schema_structure.py          exit 0
gen_design_contracts.py --check    exit 0
gen_s2a_migration.py --check       exit 0
check_s2a_attestation.py           exit 1   EXPECTED -- section 3
run_fast_cages.ps1                 exit 0   12 suites, 24.9s (15.0s advisory, breached before this)
run_guard_trigger_tests.ps1        exit 0   PARTS 1-5
check_state.ps1                    exit 0   CLEAN
make_status.ps1                    renders
```

**No MT5 lane was used. No backtest was run.** No `.set`, `.mq5`, `.mqh` or `.ex5` was touched; no
Demo, Live, VPS or Telegram path was touched.

---

## 5. Three things worth carrying forward

1. **The S2 transfer commit passed its own pre-commit gate and went red on the very next read.** At
   commit time `HEAD` still held the pre-transfer blob. This is the **third** instance in this
   lineage of a guard that is green at its own introducing commit — review did not catch it, running
   the gate again afterwards did. Memory: `drift-guard-regenerating-against-head`.
2. **Writing the negative case is what exposed the check, twice.** A1's first version had a branch
   that could never fire (the renderer emits the notice, so a generated body always contains it), and
   B2's pre-registered attribution scheme did not survive its first measurement (ajv reports paths
   relative to the branch being evaluated, so the `#/$defs/<Entity>/` prefix was absent on exactly
   the errors it needed to match).
3. **A generator that alters a byte outside the region it owns produces a diff nobody can read.**
   `--apply` wrote back `utf-8-sig` unconditionally and added a BOM to a file that had none.

---

## 6. Codex

`_triage/factory_os/CODEX_FINAL_FACTORY_OS_AUDIT_BRIEF_2026-07-31.md` — one consolidated pass over
the whole tranche plus the ORDER-600/601/602 re-check that was already owed. Blind and adversarial;
it carries no self-verdict. Five questions, seven claims to verify or refute.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| S4 snapshot v5 + fail-closed readers — the next frontier | ORDER-612 |
| S2 Coverage transfer — executed, awaiting independent re-check | ORDER-610 |
| S3 per-entity fixtures — executed, awaiting independent re-check | ORDER-611 |
| S2a D1/D2 + attestation — still awaiting the same re-check | ORDER-600 |
| S3a snapshot verdict validator — still awaiting the same re-check | ORDER-601 |
| ORDER-602 sign-off boundary — still awaiting the same re-check | ORDER-602 |
| The approval-self-invalidation decision — owner only | DONE |
| Consolidated Codex brief written and committed | DONE |
| The two hand-maintained ledger summary lines, repaired again | BACKLOG-D29 |
| Tier at 24.9s against a 15.0s advisory budget | BACKLOG-D32 |
