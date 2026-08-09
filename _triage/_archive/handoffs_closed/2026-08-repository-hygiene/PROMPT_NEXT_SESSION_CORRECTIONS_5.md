# OPENING PROMPT — the corrections lane, part 5. The nine review findings are closed; the money path is next.

> Written 2026-08-04 by lane `S-2026-08-04-CORRECT4`, which closed **all nine** findings of
> `ORDER-1310` (the independent review of the previous lane's work) and **half** of
> `ORDER-1267` #2. `_triage/PROMPT_NEXT_SESSION_CORRECTIONS.md` is still the map; parts 2-4 are
> still worth reading for the cage trap and the budget.

---

## §0 — 🔴 READ FIRST: one owner decision is waiting, and one mistake is disclosed

**❓ THE OWNER DECISION (`ORDER-1267` #2, second half).** What should the SafeProjection's
`sensor_state` SAY when the two detectors disagree? **It is measured, not hypothetical: two of the
six real accounts disagree today** (`floating_risk=FRESH` while `system_health=STALE`, accounts
ending `900` and `711`). `control_center` renders those two **CONFLICT**; the Telegram surface
renders **STALE**. Three answers, each costing something, written out on the `ORDER-1267` row with
a recommendation. **Do not guess it — it changes what a live alerting surface tells the owner.**

🔴 **THE MISTAKE, AND IT IS A NEW SHAPE OF THE OLD ONE — this is the most useful thing in this file.**
My commit `3da7e578` carries lane `S-2026-08-04-S13F`'s `ORDER-1330` row and two of their other
board hunks. Nothing of theirs is lost; the provenance is wrong. Disclosed in `d9465dce`.

> **It was NOT `git commit --amend`.** Part 4's lesson was "`--amend` drops the pathspec" and I
> obeyed it exactly: `git add -- AGENT_TASKBOARD.md`, `git commit -F … -- AGENT_TASKBOARD.md`.
> **A pathspec separates FILES, and two lanes were editing ONE file.** `git add -- <path>` stages
> that path's whole working-tree content, other lanes' uncommitted edits included. Fourth
> occurrence in this chain (`eda48dd8` · `99c73bd9` · `633a6414` · this one) and the first the
> `--amend` rule would not have prevented.
>
> **The hook told me and I read it as a note:** `[order-collision] WARN: staged path
> AGENT_TASKBOARD.md is declared by ACTIVE session S-2026-08-04-S13F -- coordinate before writing`.
> **That WARN is a STOP.**
>
> **What works on a co-edited file:** stage the intended content into the INDEX only, never
> touching the working tree — `git show HEAD:<path> > tmp` → edit `tmp` → `git hash-object -w tmp`
> → `git update-index --cacheinfo 100644,<oid>,<path>` → commit **without** a pathspec (a pathspec
> re-reads the working tree and undoes it), after checking `git diff --cached --name-only` is
> otherwise empty. The cheaper version, which I used for every later board commit and which held:
> **stage, then `git diff --cached` and READ it, before you commit.**

Not repaired by `reset --soft` or a revert: history rewrite is a standing prohibition and a second
writer was moving the branch tip.

---

## §1 — What is DONE, so you do not re-derive it

| order | state | one line |
|---|---|---|
| **`ORDER-1310`** | ✅ **ALL 9 DONE** | the review findings. Each one measured at HEAD **before** it was touched; the row carries a before/after table |
| **`ORDER-1267`** | ⚠️ **#1 + Part 2 + half of #2** `35508ce3` | an unrecognised `floating_risk` state now REFUSES. **The other half is the owner decision in §0** |
| **`ORDER-1269`** | ⚠️ #1 + #3 done by the previous lane · **#2 and #4 still OPEN** | part 4's §3 is still the right brief; **both #2 files are BUNDLE MEMBERS** |
| **`ORDER-1260`** | 🔴 **OPEN — untouched, and the largest thing left** | five defects on the **money path** |
| **`ORDER-1261`** | 🔴 OPEN — untouched | a reopened incident silenced forever |
| **`ORDER-1265`** | 🔴 OPEN — untouched | from the original nine |
| **`ORDER-1266`** | ⏳ 2 of 7 | part 3's §3 is still the right brief |

### 🎯 Four things worth carrying forward

**1. 🎯 EVERY FINDING WAS MEASURED AT HEAD BEFORE IT WAS TOUCHED, AND ONE OF THE NINE DID NOT
SURVIVE THAT.** `#4` reproduced on the pre-`#1` revision and was **already closed by `#1`** by the
time it came up. It is recorded as *closed-by* rather than as a fix, because nothing was written
for it. **A finding you repair without measuring first is a finding you can never report honestly**
— and one in nine of a good reviewer's list was already dead.

**2. 🔴 A CORRECTION TO THE REVIEW, AND THE SHAPE IS WORTH REMEMBERING.** `#9` said the case
labelled F14 "always exercises F13" and proved it with a surviving mutation. That is exactly right
about the CASE and wider than the truth about the SUITE: `F14 a SECTION post-state naming a digest
that never arrived is REFUSED`, in the controls block, kills the same mutation. **F14 was covered;
the case advertising that it covered F14 was not the thing covering it.** Measured on the pre-repair
revision. A reviewer's blast radius is a claim like any other.

**3. 🎯 THE ANSWER TO "WHICH ONE IS APPROVED" WAS ALREADY IN THE DATA.** `#1` — the exemption
accepted any reproducible section of the owner file — looked like it needed a hardcoded heading,
and the row explicitly forbade one. It did not: the destination store already declares which
section of the owner file it projects into, in its `_section` metadata record (`registry.META_KEYS`,
written by `gen_coverage.py`). **Before inventing a list, ask whether one of the two artifacts
already says it.**

**4. 🎯 A PRECISION REPAIR IS THE EASIEST KIND TO FAKE, SO EVERY ONE HERE CARRIES ITS CONTROL.**
Switching a layer off passes every negative in a "stop false-positiving" case. `SP20`'s three
controls were each written against a specific mutation, and the mutation probe killed all three
(layer-off · boundary-widened · boundary-removed). One control was rewritten mid-session because
`acct900112233` fires through the LITERAL comparison whatever the boundary rule is — it could not
tell a correct boundary from a too-wide one, which is `#9`'s disease in a case written to fix `#9`.

---

## §2 — Cage state and tier budget

**Full tier: 29 suites, `101.3s` of the PINNED `120.0s` — `18.7s` headroom.** One measurement, and
recorded as one. `$FullTierBudgetSeconds` is not raised and must not be.

⚠️ **That run reported ONE failure and it was not mine:** `run_s13_tests.ps1 references tracked path
'scripts/pilot_verify_check.py' but neither declares it nor lists it in $NOT_A_DEPENDENCY` — lane
`S-2026-08-04-S13F`'s in-flight working-tree edit. **PART 4 reads the WORKING TREE, so one lane's
uncommitted work reddens another lane's unrelated run and blocks its commit** (it blocked mine twice
before landing). That is memory `parent-cpu-and-path-limit-both-mislead`'s neighbour and it is worth
an order of its own: the append-only rule was migrated from worktree to index for the same reason.

Per-path costs after this session, measured:
- a `schemas.json` commit is now **7 suites / 29.5s** of the 90.0s per-path budget (`run_s2a_cages`
  is 7.8s of it) — `ORDER-1310` #7 put that suite on that path deliberately.
- `run_guard_trigger_tests.ps1` went `21.4s → 22.7s` with PART 4c.

**Cages added this session:** `SP20` `SP21` `SP22` `SP23` (S11) · `S12` (S12) · an `ORDER-1310 #1`
block, an `ORDER-1310 #3` block, a reverse-direction AGREEMENT case and a real F13/F14 pair
(S2a attestation) · **PART 4c** in `run_guard_trigger_tests.ps1`.

---

## §3 — What is left, and what is measured about it

**`ORDER-1260`** — five defects on the **money path**, untouched from the original nine. This is the
biggest 🔴 left and it is where the next session should go after the owner answers §0.

**`ORDER-1261`** (a reopened incident silenced forever) and **`ORDER-1265`** — untouched.

**`ORDER-1269` #2 and #4 — OPEN.** `#2`'s generated §2.1 regenerates from
`gen_s2a_migration_doc.py`, so editing the `.md` fixes nothing, and **both files are BUNDLE
MEMBERS** — editing either changes the digest and costs the owner a signature. `#4`'s front guard
(`check_attested_pin_staged.pinned_expectations()`) is still untouched.

**`ORDER-1266`** — part 3 §3 has the full brief; the `EXECUTION_KEY_FIELDS` half still arrives with
a store migration into `factory/**`.

### 🔴 FOUND WHILE WRITING THIS FILE, AND IT IS THE SAME DISEASE AS `ORDER-1310` #7 — no order opened

**`check_handoff_contract.ps1` does not see the files this project actually uses as handoffs.** Its
trigger is `_triage/HANDOFF*.md` or `_triage/SESSION_HANDOFF*.md` (its own §22). Every handoff in
this chain is `_triage/PROMPT_NEXT_SESSION_*.md`. **Measured:** committing this file printed
`[handoff-contract] no added/modified handoff staged -- pass (no-op)`. The routing block at the
bottom of this file was written to the contract and **nothing validated it**.

That is `ORDER-1310` #7 one directory over: a guard that is not on the commit path of the thing it
governs. It is *not* a one-line fix — widening the pattern subjects parts 1-4 to the contract, and
none of them carries a routing block, so the next commit touching any of them would go red. **The
repair has to add the pattern AND either back-fill routing blocks or scope the trigger to
newly-ADDED files, and it needs a measurement of which existing files would redden first.**

**No order was opened for it**, deliberately: this lane's ledger row declares *"expects to open no
new order"*, and quietly opening one out of a block reserved on that declaration is the kind of
scope drift the ledger exists to prevent. **Open it from your own block.**

**Raised by the review and deliberately NOT closed:** `SP16` asserts the split-value gap is OPEN, so
closing that gap turns the suite red. The reviewer is right that it is the wrong shape for a passing
security test. Relabelling it as an expected-gap tripwire changes what the case CLAIMS, not what it
measures, and belongs with the work that closes the gap.

---

## §4 — Standing rules that did not change

- 🚫 No EA verdict from automation — design §10 stops S13 at `EVIDENCE_COMPLETE`.
- 🚫 Do not raise `$FullTierBudgetSeconds` (pinned 120.0s).
- 🚫 Do not edit a cage to make its own FAIL go away. **Narrow it and delete its false stated
  reason, or flip it and assert the opposite — in the same commit as the fix.**
- 🚫 Do not re-add `run_enforcement_status_tests.py` to the tier before it mutates a **copy**
  (`ORDER-1283`). Check that question BEFORE wiring anything onto the commit path.
- 🚫 **Before repairing anything in `_triage/factory_os/`, ask which of the six BUNDLE MEMBERS your
  change touches** (`check_s2a_attestation.py:BUNDLE`) — and run `run_s2a_conformance.py`. Nothing
  this session touched one, so no signature is owed; that was checked after every S2a commit (68/0).
- 🚫 `MASTER_BACKLOG.md` §2 outside an owner-approved `gen_coverage --apply` · `AGENTS.md` ·
  `PROJECT_STATE.md` · `s2a_attestations.jsonl` · any `.set` migration · any magic
  allocate/renumber/retire · any history rewrite.
- 🚫 `git commit --amend` without a pathspec — **and see §0: the pathspec is not enough either.**
- **Reserve your order block and commit the reservation before using a number. Re-derive from BOTH
  tests** — every `## ORDER-<n>` across all four board files **and** every reserved block in the
  ledger. At this file's writing the highest in use is **`ORDER-1330`** (opened by `S13F`, not by
  this lane) and this lane held **`1320-1329`** — **derive it yourself rather than trusting that
  sentence.** It has been hand-repaired ten times and was stale by twenty-one blocks once.
- **A criterion is committed in its own commit, before the run that resolves it.**
- **Run the `.ps1` wrapper, not just the `.py`, before you believe a suite is green** — `.ps1`
  wrappers run under `$ErrorActionPreference='Stop'`, where any stderr from a native command is a
  thrown error.
- ⚠️ **Small trap, cost me one ugly commit subject:** `Set-Content -Encoding utf8` in Windows
  PowerShell 5.1 writes a **BOM**, and a commit message file written that way gets the BOM into the
  subject line (`15c9d523`). Write commit messages with the Write tool, or `[IO.File]::WriteAllText`
  with a BOM-less `UTF8Encoding`.

---

<!-- HANDOFF-ROUTING -->

| item | goes to |
|---|---|
| the nine review findings, all closed with before/after measurements | `ORDER-1310` |
| the owner decision on `sensor_state` when detectors disagree, plus the half that landed | `ORDER-1267` |
| five defects on the money path, untouched | `ORDER-1260` |
| a reopened incident silenced forever, untouched | `ORDER-1261` |
| the third untouched item from the original nine | `ORDER-1265` |
| the two bundle-member repairs and the front guard | `ORDER-1269` |
| the `EXECUTION_KEY_FIELDS` half and its store migration | `ORDER-1266` |
| the full-tier number, the cages added, and the disclosed provenance error | `DONE` |
| the handoff-contract guard not seeing `PROMPT_NEXT_SESSION_*.md` — open it from your own block | `DONE` |

---

Open with: **"`_triage/PROMPT_NEXT_SESSION_CORRECTIONS_5.md` ทำต่อเลย — จองบล็อกใหม่ก่อน · เคาะคำถาม ORDER-1267 #2 ให้ผมก่อน แล้วเริ่ม ORDER-1260 · อ่าน §0 เรื่องคอมมิตทับเลนอื่นก่อนแตะ AGENT_TASKBOARD.md"**
