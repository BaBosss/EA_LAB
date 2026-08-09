# Blind audit brief #5 — the two Orders about to be executed, and three self-found fixes

**Scope of write permission, stated once so it cannot contradict itself (audit 4 hit this):** you may
create or overwrite **exactly one file**, `_triage/factory_os/CODEX_AUDIT5_2026-07-30.md`, which is your
report. **Everything else is read-only** — do not modify, stage, or commit any other path, and do not
apply any fix you recommend. If you cannot write that one file, return the report in chat instead; that
is not a failure.

You have not been shown any self-assessment of this work. If you encounter one, disregard it and measure.

Repo root: `D:\EA_LAB`. Interpreter: `tools\python312\python.exe` (no system Python). `ajv-cli` installed.

---

## 1. What happened since your last audit

Your audit-4 report is committed verbatim at `_triage/factory_os/CODEX_AUDIT4_2026-07-30.md`. Four code
findings from it were addressed in `1ad7b17d`. A self-review afterwards found three more and fixed them
in `df4ccec6`. Two Orders were then drafted in `66346985`.

**The Orders are the priority of this audit.** They are about to become work. An Order with a gameable
acceptance criterion produces work that looks passed, and this repo has paid for that class five times.

## 2. What to read

| file | what it is |
|---|---|
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md` | **the two Orders — primary subject** |
| `git show df4ccec6` | the three self-found fixes |
| `git show 1ad7b17d` | the response to your audit 4 |
| `_triage/factory_os/gen_design_contracts.py` · `run_contract_binding_tests.py` | the binding, as it now stands |
| `.githooks/pre-commit` (the `cage_staged` block) · `scripts/_test/run_fast_cages.ps1` | the trigger and the tier |
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` §4, §7.1, §10 | `ControlRoomSnapshotV5`, the slice table |
| `MASTER_BACKLOG.md` rows D30 · D31 · D32 | what is claimed closed and open |

Run things yourself; take no number in a comment, commit message or backlog row as measured.

## 3. Questions, in priority order

**Q1 — Can either Order be reported DONE without the work being done?**
Go through `ORDER-600` and `ORDER-601` acceptance item by item. For each, construct the cheapest output
that satisfies the letter of the criterion while defeating its purpose. Name every criterion that is
checkable only by a human reading prose, every one that can be satisfied by a fixture that has never
failed, and every one where "the tool returned clean" and "the tool read nothing" produce the same
result. Say which criteria you would rewrite and how.

**Q2 — Is `ORDER-601`'s proposed boundary right?**
It proposes splitting `ControlRoomSnapshotV5` into a closed `SnapshotBuilderInput` (no `all_clear`, so a
supplied value is rejected by the schema rather than by code) and the persisted document (`all_clear`
required, written only by the validator). Does that actually make "computed, never supplied" checkable?
What does it break — for `make_status.ps1`, the digest, the existing v4 file, or anything else that reads
the snapshot? Is there a simpler shape that survives the same attacks? During audit 4 you built an
instance with `sources=[]` and `all_clear=true` that ajv accepted; construct the equivalent attack
against the proposed split and say whether it survives.

**Q3 — Are the three self-found fixes real, and complete?**
They are: (a) `.githooks/pre-commit` `cage_staged` glob widened to `_triage/factory_os/*` and the design
file, after a measurement showed the tier never ran on a design-only commit; (b) CRLF/LF normalisation in
both Python entry points, after `--check` was found failing on a clean checkout with an empty diff and the
harness ABORTing; (c) `walk_fields` now raises past `MAX_NEST_DEPTH` instead of returning an empty list.
Re-measure each independently. For (a) in particular: is the glob now complete, or is there still a file
these suites depend on that no glob matches? For (b): is there any remaining path where the two entry
points disagree about the file's bytes? For (c): does raising propagate to a non-zero exit in both entry
points and through the PowerShell wrapper?

**Q4 — Should the generated tables live inside the design at all?**
The design went from 829 to 1745 lines when 27 generated blocks were injected into it, and the design's
own §7.4 is about reading it without exhausting an AI's context. The alternative under consideration is
generating one separate `_triage/factory_os/CONTRACTS.md` and leaving the design with links and rationale
only — which also removes the in-document marker protocol, where two of the defects found so far lived.
Give a recommendation with reasoning, including what is lost. Treat this as a design question, not a
style question.

**Q5 — What is the next thing that should be built, and what should not be?**
Given D30/D31/D32 and the blocked slices, rank what should happen next. Explicitly say whether anything
in the current state makes it unsafe to start executing `ORDER-601`.

## 4. Output

`_triage/factory_os/CODEX_AUDIT5_2026-07-30.md`. One-line verdict per question, then evidence. Every
finding: **file:line**, the **defect**, and a **failing case** — a concrete input, edit or output that
would slip through. A finding with no failing case is an opinion; label it one.

Close with: **GO** (execute ORDER-600 and ORDER-601 as written) · **GO WITH AMENDMENTS** (list them) ·
**NO-GO** (name the single blocker).

## 5. Two standing rules of this repo you are asked to apply

- A guard never observed failing is `UNTESTED`, not `safe`. Numbers identical to a baseline in every
  digit are evidence a check is **inert**, not that it is correct.
- "Cannot read the input" must never be reported as "nothing to enforce". Any tool here that reports
  clean because it parsed zero items is a defect.
