# Blind audit brief #4 — the design↔schema binding, and whether S2a/S3a may become Orders

**You are a read-only auditor. Do not modify, stage, or commit any file.** Report findings; do not
fix them. You have not been shown any self-assessment of this work and you should not ask for one —
if you are told elsewhere what the author concluded, disregard it and measure for yourself.

Repo root: `D:\EA_LAB`. Python interpreter, committed in-repo: `tools\python312\python.exe`
(there is no system Python on this machine). `ajv-cli` is installed globally.

---

## 1. Background you need, stated as fact, not as a claim to agree with

The Factory OS design (`_triage/EA_LAB_FACTORY_OS_DESIGN.md`) failed three blind audits on
2026-07-30. Their reports are at `_triage/factory_os/CODEX_{BLIND_AUDIT,REAUDIT,AUDIT3}_2026-07-30.md`.
Audit 3's central measurement: seven findings that earlier audits had called fixed had **regressed**,
all through one seam — the normative contract was written by hand in two places, the design prose and
`_triage/factory_os/schemas.json`, with nothing binding them. The checker built to close that seam
(`check_schema_structure.py`) was measured against those same seven findings and would have caught
**0 of 7**, because it compares storage paths and greps banned sentences while every defect was
semantic. It printed `STRUCTURE OK` on a commit where the design described `attempts[]`, a lease with
`pid`, and `launched_at`, while the schema said the opposite.

Audit 3's instruction was: generate the design's contract tables from one machine-readable manifest,
let prose carry only rationale, and do not call a finding fixed until a negative fixture for that
specific defect fails before the fix and passes after.

Work was then done against that instruction in commits `8cbb44e6` and `072c303a`. **That work is the
subject of this audit.**

## 2. What to read

| file | what it is |
|---|---|
| `_triage/factory_os/gen_design_contracts.py` | generator + `--check` mode |
| `_triage/factory_os/run_contract_binding_tests.py` | the negative-fixture harness |
| `_triage/factory_os/schemas.json` | the manifest (also the JSON Schema) |
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` | the design, now containing generated blocks |
| `scripts/_test/run_contract_binding_tests.ps1` | the pre-commit cage wrapper |
| `scripts/_test/run_fast_cages.ps1` | the tier it was added to, and that tier's budget |
| `_triage/factory_os/run_schema_fixtures.py` | the pre-existing ajv fixture suite |
| `git show 8cbb44e6` · `git show 072c303a` | the diffs, including every line removed from the design |

**Run things yourself. Do not take any number in a comment, commit message or backlog row as
measured.** At minimum:

```
tools\python312\python.exe _triage\factory_os\gen_design_contracts.py --check
tools\python312\python.exe _triage\factory_os\run_contract_binding_tests.py
tools\python312\python.exe _triage\factory_os\run_schema_fixtures.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\_test\run_fast_cages.ps1
```

## 3. The questions, in priority order

**Q1 — Is the binding real, or does it pass by construction?**
For each case in `run_contract_binding_tests.py`, state whether it *could* fail for a reason other
than the defect it names, and whether any case is **guaranteed to pass by construction** — i.e.
whether a generator will always produce a different document when its input changes, making the
assertion true regardless of whether the defect is actually covered. If some cases are tautological,
say which, and say what a non-tautological version would assert instead.

**Q2 — Where is the escape hatch?**
Construct, concretely, a way for the design and the schema to state different contracts *today*
without any of these tools going red. Consider at least: normative statements in prose outside the
generated blocks; facts carried only in `x-enforced-by` (which the schema does not check); sections
of the design with no schema backing at all (§3 state machines, §5.3–5.5, §6, §7); the `_why` vs
`note` distinction in `x-ea-lab-meta.contracts`; and content that is *absent* rather than wrong.
Give a worked example, not a category.

**Q3 — Did the conversion lose anything?**
`git show 8cbb44e6` removed a large amount of prose and replaced it with generated tables. Diff what
was removed against what the generated document now states. Name every normative fact that left the
document and did not come back. (One such loss was found and repaired in `072c303a`; treat that as
evidence the class exists, not as evidence it was the only one.)

**Q4 — Is the cage honest?**
`run_contract_binding_tests.ps1` is in the pre-commit fast tier. Does it fail closed? What happens if
`tools\python312\python.exe` is missing, if the design file is missing, if `schemas.json` is
unparseable? Re-measure the tier's total against its declared budget. Does adding it push anything
past the point where someone reaches for `--no-verify`?

**Q5 — May `S2a` and `S3a` now be written as taskboard Orders?**
Audit 3 cleared exactly these two as preparatory work: `S2a` = the Coverage ownership proposal +
migration table; `S3a` = pin the all-clear validator + write its regression fixtures. State GO or
NO-GO for each **independently**, and if NO-GO, name the single thing that blocks it. Do not clear
anything else — `S2`, `S4`, `S10`, `S14` are known-blocked and are not in scope.

**Q6 — What is still owed before the design as a whole can be built from?**
Rank what remains. Distinguish "blocks writing Orders" from "blocks building" from "can be fixed in
the slice that touches it".

## 4. Output

Write to `_triage/factory_os/CODEX_AUDIT4_2026-07-30.md`. Structure: a one-line verdict per question,
then the evidence. For every finding give the **file:line**, the **defect**, and a **failing case** —
a concrete input or edit that would slip through. A finding with no failing case is an opinion; label
it as one.

Close with a single overall verdict: **GO** (S2a/S3a may be written) or **NO-GO**, plus the shortest
list of things that would change it.

## 5. Two standing rules of this repo you are being asked to apply

- A guard that has never been observed failing is `UNTESTED`, not `safe`. Numbers identical to a
  baseline in every digit are evidence a check is **inert**, not evidence it is correct.
- "Cannot read the input" must never be reported as "nothing to enforce". If any tool here reports a
  clean run because it parsed zero items, that is a defect, and it is the defect class this repo has
  hit five times.
