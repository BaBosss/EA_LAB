# OPENING PROMPT — the corrections lane, part 6. The money path is closed. What is left is smaller and mostly named.

> Written 2026-08-04 by lane `S-2026-08-04-CORRECT5B`, which closed **`ORDER-1267` in full** (the
> owner ratified answer (a)) and **`ORDER-1260` in full** (all six money-path defects), and opened
> **`ORDER-1360`**. `_triage/PROMPT_NEXT_SESSION_CORRECTIONS.md` is still the map; parts 2-5 still
> hold for the cage trap, the budget, and the co-edited-file technique.

---

## §0 — 🔴 READ FIRST: two lanes ran the same handoff at the same time, and I caused the collision

**There is no owner decision waiting.** `ORDER-1267` #2's question was put to the owner at the top
of this lane and answered: **(a)** — add `CONFLICT` to the enum and mirror `control_center`'s rule.
It is built, measured and closed. Start on work, not on a question.

🔴 **THE MISTAKE, AND IT IS A NEW SHAPE AGAIN — worth more than anything else in this file.**
Another session opened from **this same handoff chain**, reserved the session id
`S-2026-08-04-CORRECT5` and the block `1340-1349` at **10:13:32**, and I reserved *the same id and
the same block* at **10:59:47**. Two rows, one identity. Repaired in `f68f4c5b` (this lane became
`CORRECT5B` on `1360-1369`); nothing had to be renumbered because neither lane had spent a number.

> **I RAN BOTH DERIVATION TESTS AND THEY DID NOT HELP.** The standing rule says derive the block
> yourself from both tests rather than trusting the handoff's sentence. I did. **I ran them against
> a read of the ledger taken about 45 minutes before I committed** — reading files, and waiting on
> the owner's answer, all happened inside that window, and the other lane's reservation landed in
> the middle of it.
>
> **A derivation is only as fresh as the read it runs on.** The step that catches this is rule 4's
> and it is one command: `git log -1`, compared against the read, **immediately before staging**.
> Note what this means for `BACKLOG-D29` — deriving the ledger's summary lines from the tables
> would NOT have prevented this, because the staleness was in the reader, not in the line.
>
> **Practical form:** re-run `git log -1` right before every stage. If HEAD moved since you read
> the file you are about to write, **re-read and redo the edit**. This is also the cheap version of
> part 5's §0 technique, and it is what caught nothing riding along in all four of my board commits.

**The other lane is standing down** — the owner ruled in-session that this lane continues
`ORDER-1260` and that lane stops. If you find `S-2026-08-04-CORRECT5` still `ACTIVE` in the ledger
with no commits after `b3d0c2fd`, it is abandoned; mark it, do not adopt its block.

---

## §1 — What is DONE, so you do not re-derive it

| order | state | one line |
|---|---|---|
| **`ORDER-1267`** | ✅ **DONE IN FULL** `d59cdc2e` | owner ratified **(a)**. Two real accounts moved `STALE` → `CONFLICT`; the Morning Brief line moved with them |
| **`ORDER-1260`** | ✅ **DONE IN FULL** `df8d3ffc` | all six money-path defects, each reproduced at HEAD first, each with its control |
| **`ORDER-1310`** | ✅ all 9 (previous lane) | — |
| **`ORDER-1360`** | 🆕 **OPEN, costed** | the handoff contract cannot see this project's handoffs. Opened from this lane's block, with the number that makes it a decision |
| **`ORDER-1269`** | ⚠️ **#2 and #4 still OPEN** | part 4's §3 is still the right brief; **both #2 files are BUNDLE MEMBERS** |
| **`ORDER-1261`** | 🔴 OPEN — untouched | a reopened incident silenced forever. **The largest 🔴 left** |
| **`ORDER-1265`** | 🔴 OPEN — untouched | the last of the original nine |
| **`ORDER-1266`** | ⏳ 2 of 7 | part 3's §3 is still the right brief |

### 🎯 Five things worth carrying forward

**1. 🎯 THE ORDER'S OWN PREDICTION DID NOT SURVIVE THE MEASUREMENT, AND THAT IS THE POINT OF
MEASURING.** The `ORDER-1267` row said *"`SP14`'s assertion would then be FLIPPED in the same commit
as the fix"*. It needed no flip: SP14's two accounts are *both detectors FRESH* and *risk-only
BLIND*, and neither is a disagreement between two detectors that both speak. **Mirroring a rule
means mirroring its SCOPE.** A row that tells you what will break is a hypothesis, not a plan.

**2. 🎯 TWO OF SIX PROBES WERE WRONG ON THEIR FIRST RUN, AND BOTH FAILED LOUDLY RATHER THAN
QUIETLY.** `#1` fired `C8` (I mutated a payload without recomputing its digest); `#3` fired `A1` (I
used an `attest_state` the enum does not have). **A probe that fails for the wrong reason is not
evidence in either direction** — it would have read as "already fixed" if I had not looked at
*which* criterion fired. Read the refusal id, never just the emptiness.

**3. 🔴 TWO LIMITS ARE PINNED AS PASSING CASES, DELIBERATELY.** `C9` still cannot bind
`logical_symbol` to a run's broker `symbol` — that needs `LogicalSymbol.broker_map` keyed by lane,
and **no such store exists in this repo**, only schema fixtures. The `A8` chain protects every
event that **has a successor**; editing the **last** line of a log breaks no link. Both have a
green case asserting the limit, so whoever closes them finds a failing assertion rather than a
silence. **Do not read either as "covered".**

**4. 🎯 A NEW REFUSAL ON THE COMMIT PATH IS MEASURED AGAINST THE REAL FILE BEFORE IT IS ARMED.**
`ORDER-1260` #5 arms a refusal on ACTIVE inventory rows with an unreadable magic. Measured first:
64 rows, ACTIVE 58 / REMOVED 5 / UNVERIFIED 1, and the single non-numeric magic sits on the
UNVERIFIED row — so it arms on 58 rows and refuses **none** today. That is the `ORDER-1310` #6
habit and it is cheap; skipping it is how a repair becomes an outage.

**5. 🎯 A ROLL-UP WHOSE UNIVERSE IS TYPED OUT GOES STALE IN THE SAME EDIT THAT MAKES IT MATTER.**
`run_s10_tests.py`'s criterion roll-up was three hand-written counts (`C` 10, `A` 7, `M` 6), so the
new `A8` and `M7` would have been reported as ids *"the modules do not have"* while the modules
were emitting them. It now derives the universe from the three modules' sources.

---

## §2 — Cage state and tier budget

**Full tier: 29 suites, 0 failed, `98.5s` of the PINNED `120.0s` — `21.5s` headroom.** One clean
measurement. `$FullTierBudgetSeconds` is not raised and must not be.

⚠️ **The first attempt at that measurement failed and the failure was self-inflicted, which is
worth knowing before you repeat it:** `run_front_guard_evidence_tests.ps1` reported
`A6 .git/index was rewritten by this suite` — because I ran the full tier in the background **while
committing**. The suite is right; the writer was me. **Do not run the full tier concurrently with
anything that stages.**

Per-path costs after this session, measured from the hook's own selection:
- a `schemas.json` + S10 commit selects **9 suites / 39.8s** of the 90.0s per-path budget.
- `run_s10_tests.ps1` went **4.4s → 5.1s** with PART 6 (six defects, ~40 new assertions).

**Cages added this session:** `SP24` `SP25` `SP26` (S11, `ORDER-1267`) · **PART 6** in
`run_s10_tests.py` (`ORDER-1260`, all six with controls) · a new named check in `check_state.ps1`
(*every ACTIVE inventory row has a readable magic*).

---

## §3 — What is left, and what is measured about it

**`ORDER-1261`** (a reopened incident silenced forever) and **`ORDER-1265`** — **untouched, and now
the biggest 🔴 left.** Neither has been re-measured at HEAD by anyone in this chain, so **measure
before repairing** — one of `ORDER-1310`'s nine turned out to be already closed by another fix.

**`ORDER-1269` #2 and #4 — OPEN.** #2's generated §2.1 regenerates from `gen_s2a_migration_doc.py`,
so editing the `.md` fixes nothing, and **both files are BUNDLE MEMBERS** — editing either changes
the digest and costs the owner a signature. #4's front guard
(`check_attested_pin_staged.pinned_expectations()`) is still untouched.

**`ORDER-1266`** — part 3 §3 has the full brief; the `EXECUTION_KEY_FIELDS` half still arrives with
a store migration into `factory/**`.

**`ORDER-1360`** — opened here, with three costed options and the measurement that makes it a
decision rather than a one-liner: **27 tracked `PROMPT_NEXT_SESSION_*.md`, 8 with a routing block,
19 without** — including the one written this morning. Read the row before touching the regex.

**Raised by the review and still deliberately NOT closed:** `SP16` asserts the split-value gap is
OPEN, so closing that gap turns the suite red. Relabelling it as an expected-gap tripwire changes
what the case CLAIMS, not what it measures, and belongs with the work that closes the gap.

---

## §4 — Standing rules that did not change

- 🚫 No EA verdict from automation — design §10 stops S13 at `EVIDENCE_COMPLETE`.
- 🚫 Do not raise `$FullTierBudgetSeconds` (pinned 120.0s).
- 🚫 Do not edit a cage to make its own FAIL go away. **Narrow it and delete its false stated
  reason, or flip it and assert the opposite — in the same commit as the fix.** (`P01` failed on my
  first run of the `ORDER-1267` work and it was *right to*: a new public callable in the shadow-mode
  shell must be **declared**, not excused. Declaring it is not weakening it.)
- 🚫 Do not re-add `run_enforcement_status_tests.py` to the tier before it mutates a **copy**
  (`ORDER-1283`).
- 🚫 **Before repairing anything in `_triage/factory_os/`, ask which of the six BUNDLE MEMBERS your
  change touches** (`check_s2a_attestation.py:BUNDLE`) — and run `run_s2a_conformance.py`. Nothing
  this session touched one; **68/0 after the S10 commit**, so no signature is owed.
- 🚫 `MASTER_BACKLOG.md` §2 outside an owner-approved `gen_coverage --apply` · `AGENTS.md` ·
  `PROJECT_STATE.md` · `s2a_attestations.jsonl` · any `.set` migration · any magic
  allocate/renumber/retire · any history rewrite.
- 🚫 `git commit --amend` without a pathspec — **and a pathspec is not enough on a co-edited file
  (part 5 §0), and neither is deriving your block (§0 above).**
- **Reserve your order block and commit the reservation before using a number. Re-derive from BOTH
  tests — AND re-check `git log -1` immediately before you stage.** At this file's writing the
  highest `## ORDER-<n>` in use is **`ORDER-1360`** and the highest block reserved is
  **`1360-1369`** — **derive it yourself rather than trusting that sentence**, and note that this
  lane derived it correctly and still collided, which is why the freshness check is now the rule
  that matters.
- **A criterion is committed in its own commit, before the run that resolves it.**
- **Run the `.ps1` wrapper, not just the `.py`** — wrappers run under `$ErrorActionPreference='Stop'`,
  where any stderr from a native command is a thrown error.
- ⚠️ `Set-Content -Encoding utf8` in Windows PowerShell 5.1 writes a **BOM** into the commit
  subject. Write commit messages with the Write tool.

---

<!-- HANDOFF-ROUTING -->

| item | goes to |
|---|---|
| the owner's ratified answer (a) and the two accounts it moved | `ORDER-1267` |
| all six money-path defects, with the before/after table and the two pinned limits | `ORDER-1260` |
| the handoff-contract trigger gap, its three costed options and the 27/8/19 measurement | `ORDER-1360` |
| a reopened incident silenced forever, untouched | `ORDER-1261` |
| the third untouched item from the original nine | `ORDER-1265` |
| the two bundle-member repairs and the front guard | `ORDER-1269` |
| the `EXECUTION_KEY_FIELDS` half and its store migration | `ORDER-1266` |
| the full-tier number, the cages added, and the lane collision this lane caused and repaired | `DONE` |

<sub>⚠️ **This routing block is still unvalidated** — `check_handoff_contract.ps1` does not trigger on
`PROMPT_NEXT_SESSION_*.md`. That is `ORDER-1360`, and this file is one more instance of it.</sub>

---

Open with: **"`_triage/PROMPT_NEXT_SESSION_CORRECTIONS_6.md` ทำต่อเลย — จองบล็อกใหม่ก่อน แล้วเช็ค `git log -1` ซ้ำก่อน stage ทุกครั้ง (อ่าน §0) · เริ่ม ORDER-1261 แล้ว ORDER-1265 · วัดที่ HEAD ก่อนซ่อมทุกข้อ"**
