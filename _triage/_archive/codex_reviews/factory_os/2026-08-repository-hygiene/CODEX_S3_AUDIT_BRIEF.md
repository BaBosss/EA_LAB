# Codex blind audit brief — Factory OS slice **S3** (schema validator + per-entity negative fixtures)

> Written 2026-08-03 by lane `S-2026-08-03-AUDITCOV`. **You are the independent brain.**
>
> This slice's built code has **never been independently audited**. Nothing here tells you what any
> previous session concluded, deliberately. Attack the claims; do not restate them.

---

## 0. Read at a PINNED commit · READ-ONLY

```bash
git show a87f7448:<path>
```

Do not edit, create, stage or commit anything. Do not write to `factory/`, `ops/` or `.git/`.
Your deliverable is a report on stdout.

## 1. What you are auditing, in one sentence

**The thing every other slice's correctness claim is resting on.** `schemas.json` is the contract
for 27 entities; this slice is the machinery that decides whether an instance actually satisfies it,
and whether each entity has a crafted bad instance that the schema genuinely rejects.

**The stake is structural rather than local.** Every other slice validates against this. A negative
fixture that stops failing is a contract that has quietly disappeared, and nothing downstream will
notice — the artifacts keep being produced, they just stop being true. This slice is also the one
place in the repo where a *guard that cannot fail* is indistinguishable from a *guard that passes*.

## 2. Read these, in this order

| | |
|---|---|
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` | **§4** (the whole schema section, especially the "how to read this" preamble at L339) · **§10** the **S3** row and its acceptance sentence |
| `_triage/factory_os/schemas.json` | the contract itself — 2,810 lines, 27 entities, a 19-branch root `oneOf`, and the `x-enforcement-status` annotations |
| `_triage/factory_os/CONTRACTS.md` | the generated normative tables |
| `AGENT_TASKBOARD.md` | rows **`ORDER-611`** and any `ORDER-6xx` touching schemas |

## 3. The artifacts

| file | what it decides |
|---|---|
| `_triage/factory_os/run_schema_fixtures.py` | the real validation: `ajv` (Draft 2020-12) over one instance per audit finding, batched into three processes, plus a **per-entity isolation harness** |
| `_triage/factory_os/check_schema_structure.py` | a **lint**, explicitly demoted — kept for root/discriminator/branch shape and the `unevaluatedProperties` inventory |
| `_triage/factory_os/gen_design_contracts.py` + `run_contract_binding_tests.py` | the design↔schema binding that replaced the lint, with 7 regressions re-applied as mutations |
| `scripts/_test/run_schema_cages.ps1` | the fast-tier wrapper |

## 4. The claims — refute these

| # | claim | where |
|---|---|---|
| C1 | **every entity rejects at least one crafted bad instance** (design §10's acceptance) | the per-entity half of `run_schema_fixtures.py` |
| C2 | the **root discriminator rejects an unknown `entity`** | the root cases |
| C3 | **`reconciliation_clear` is computed; a supplied value is rejected** | the schema + its fixture |
| C4 | **every constraint this slice claims is enforced by a validator that exists** — which is what `x-enforcement-status` makes checkable rather than aspirational | `x-enforcement-status` and whatever reads it |
| C5 | the **isolation harness** is necessary and sound: the real root is a 19-branch `oneOf` where one malformed instance yields 20 errors from unrelated branches, so per-entity cases run against a built harness instead | `build_isolation_schema` |
| C6 | `check_schema_structure.py` is **not evidence** that design and schema agree — it would have caught **0 of 7** semantic regressions; the real binding is `gen_design_contracts.py` + `run_contract_binding_tests.py` | both docstrings |
| C7 | batching to three ajv processes took the suite from 11.5s to ~2.2s **without changing what is checked** | the measurement in the header |

## 5. Where to aim

1. **C1 is the claim most worth measuring rather than reading.** Count the entities in
   `schemas.json` and count the entities that have a negative case. The header states a *prior*
   measurement (15 of 27 had none). **Re-measure it at this pin** and report the numbers. If the
   two halves are counted differently — root cases vs isolation cases — say so.
2. **A negative fixture that fails for the wrong reason is worse than none.** For each negative
   case, is it rejected by *the constraint it names*, or by something incidental — a missing
   required field, a typo'd `entity`, a wrong type on an unrelated key? The way to tell: repair the
   incidental defect and see whether it still fails. Sample the ones guarding the most-referenced
   entities, `OwnerRef` first.
3. **C5's isolation harness is the load-bearing risk of this whole slice.** It is a *derived*
   schema. If the harness is more permissive than the real root, every per-entity negative is
   measured against something the repository never validates against — and every per-entity
   positive proves nothing about a real instance. Does the harness preserve `unevaluatedProperties`,
   `$ref` targets, `required`, and the branch's own constraints? Construct an instance that passes
   the harness and fails the root, and one that does the reverse.
4. **C4's `x-enforcement-status` is an annotation, not an enforcement.** What *reads* it? If nothing
   does, the field records an intention and C4 is a claim about a claim. If something does, does it
   fail when a constraint marked enforced has no validator?
5. **The three batched ajv processes.** C7 says batching changed cost, not coverage. Verify: does a
   single ajv process short-circuit after the first failing instance, so cases after it are never
   evaluated? Does a case whose *file* fails to parse count as passed? What is the exit-code
   handling, and can a case be silently skipped?
6. **The declared-vs-observed gap.** Each case declares whether it should pass or fail. Is there
   anything that proves the declaration was ever exercised — i.e. that a case declared to fail
   actually ran and actually failed, rather than being counted as "behaved as declared" because it
   was never run at all?
7. **`ajv-cli` is an external dependency** (`npm install -g ajv-cli`). What does this suite do when
   it is absent or a different version? A validator that reports success when it could not run is
   the specific failure this project has been burned by; check the missing-tool path.
8. **C6 demotes a file that is still wired in.** `check_schema_structure.py` runs inside
   `run_contract_binding_tests.ps1`. A lint that is documented as not-evidence but sits on the
   commit path will be read as evidence by whoever sees it green. Does anything downstream treat its
   output as a pass?
9. **`unevaluatedProperties` inventory.** An entity without it accepts unknown keys silently — the
   exact shape by which a field can be added to a store and never validated. Which entities lack
   it, and is the omission declared anywhere?
10. **The root `oneOf` with 19 branches.** An instance matching **two** branches fails `oneOf` —
    correctly, but with an error message that names neither. Are there two branches that can both
    match a plausible instance? And is there an entity whose discriminator value appears in no
    branch, so it can never validate at all?

## 6. How to reproduce

```bash
tools/python312/python.exe _triage/factory_os/run_schema_fixtures.py
```
```bash
tools/python312/python.exe _triage/factory_os/check_schema_structure.py
```
```bash
tools/python312/python.exe _triage/factory_os/run_contract_binding_tests.py
```

⚠️ Two suites unrelated to S3 (`run_s2a_gate` F2, `check_coverage_transfer` A8) are **known red at
this pin** for a reason already recorded elsewhere. Not your finding.

## 7. What a finding must contain

`file:line` · the instance or condition that exposes it · the consequence stated as *which
constraint is unenforced* or *which slice's correctness claim it undermines* · and a reproducing
command where you can produce one.

Rank by severity, and keep **"this constraint is not enforced"** separate from **"this case cannot
fail"** — the second is the more expensive kind, because it reports green forever.
