# OPENING PROMPT — the corrections lane, part 7. Two orders closed, and a review found nine defects inside the repairs.

> Written 2026-08-04 by lane `S-2026-08-04-CORRECT6` (block `1380-1389`), which closed
> **`ORDER-1267`**, **`ORDER-1260`** and **`ORDER-1261`** in full, settled **`ORDER-1265`**'s named
> next step, and then had all three of those repairs reviewed by an independent model.
> ⚠️ **Several lanes were ACTIVE all day — read `docs/SESSION_LEDGER.md` FIRST.**

---

## §0 — 🔴 READ FIRST: the one habit that would have prevented most of today's damage

**A read-back is not a check unless a decision can still be taken after reading it.**

I lost this twice in one session, in two different forms, and both cost real damage:

1. **The block reservation.** I ran BOTH derivation tests correctly at 10:10 and committed at
   10:59. A neighbouring lane reserved the same id and block inside that window. *Deriving your
   own answer is only as fresh as the read it runs on.*
2. **The board commit.** I put `git diff HEAD -- <path>` in the **same compound command** as the
   `git add` and the `git commit`. The three hunks — two of them another lane's — appeared in
   output that had already committed them. **Fifth occurrence in this chain, and the first where
   the check that exists to prevent it was actually run.**

**So: stage in one tool call. Read the diff. THEN commit in a different call.** Three steps, never
two. I used that shape for every commit after `1464a94f` and it caught a clean tree each time.

⚠️ **And re-check `git log -1` immediately before staging** — HEAD moved under me four times today.

---

## §1 — What is DONE

| order | state | one line |
|---|---|---|
| **`ORDER-1267`** | ✅ **DONE** `d59cdc2e` | owner ratified (a); two real accounts moved `STALE` → `CONFLICT` |
| **`ORDER-1260`** | ✅ **DONE** `df8d3ffc` | all six money-path defects |
| **`ORDER-1261`** | ✅ **DONE** `5ac83527` | five closed; **the sixth was already dead when measured** |
| **`ORDER-1265`** | ⏳ **its named next step is SETTLED** `1538ef44` | claim 2.7 CONFIRMED with five live controls |
| **`ORDER-1360`** | 🆕 OPEN, costed | the handoff contract cannot see this project's handoffs |
| **`ORDER-1380`** | 🆕 OPEN | the two review findings with no home |
| **`ORDER-1266`** | ⏳ 2 of 7, **+ an eighth handed to it** | a parameter VALUE can change while its config hash stays |
| **`ORDER-1269`** | ⚠️ #2 + #4 OPEN | **both #2 files are BUNDLE MEMBERS** |

### 🎯 Five things worth carrying forward

**1. 🔴 THE INDEPENDENT REVIEW FOUND NINE DEFECTS AND EVERY ONE WAS INSIDE A REPAIR I HAD JUST
MADE.** Not in the old code — in the new code, written the same day, with cages, by a seat that had
already run `/scrutinize` over itself. Two of them are shapes self-review structurally cannot see:

  - **My own cage walked around my own bug.** `deliver()` got the literal scan with
    `known_secrets` *defaulted*, so a caller that omitted it got a scan that could not fire — and
    my case passed the list, so it drove the repaired path and never the defaulted one. That is
    `falsifier-satisfied-by-unexercised-mechanism`, written by me, **one commit after I closed a
    finding of that exact shape.** ⇒ **Write at least one case that drives the UNFIXED path.**
  - **Two repairs undid each other.** `#5` made a torn journal line survivable; `#1` recomputed the
    incident count from the readable lines. Together: a missing `RESOLVED` line recounts to 0,
    rebuilds the original dedupe key, and re-suppresses the reopen `#1` exists to let through.
    73 cases green, because none of them drove a partial journal. ⇒ **When two repairs touch one
    data path, write the case where BOTH have fired.**

**2. 🎯 MEASURE AT HEAD FIRST — IT PAID FOR THE THIRD TIME TODAY.** `ORDER-1261` #2 says the guard
*"prints what it catches"*. It does not, and has not since `ORDER-1267` #1. Recorded as **closed-by**
rather than as a fix. (`ORDER-1310` #4 was the first; `ORDER-1265`'s failed probe was the second.)
**And two of my six `ORDER-1260` probes were wrong on their first run** — they fired `C8` and `A1`,
not the criterion under test. **Read WHICH criterion fired, never just whether the list is empty.**

**3. 🔴 A NEW VALUE IS A CHANGE TO A CONTRACT.** `UNCONFIGURED_REGRESSION` was invented and told
neither `notifier.OUTCOMES` nor the schema enum, and all 73 cases stayed green because nothing
crossed the two. The new case derives what `deliver()` can write **from its own source**.

**4. 🔴 REPLACING A TOTAL COMPARISON WITH AN ENUMERATED ONE COST ME TWICE, IN THE SAME LIST.**
`--check` lost `status` (caught by my own `/scrutinize`) and then `deployment_ref` (caught by the
review). **A narrowing nobody writes down is indistinguishable from an oversight** — the two fields
still excluded now carry their reasons in the code.

**5. 🎯 I OVERCLAIMED, AND THE FIX WAS WORDS.** A8's comment said the chain *"protects every event
that has a successor"*. It does not: `prev_hash` is public, so a writer that recomputes every link
replays clean, and a truncation breaks no link. Both measured. The honest claim — **it stops an
editor, not a rewriter** — is smaller and true, and both limits are now passing cases.

---

## §2 — Cage state and tier budget

**✅ CLEAN full tier at THIS lane's final HEAD (`499f3c0b`): 29 suites, 0 failed, `103.5s` of the
PINNED `120.0s` — `16.5s` headroom.** One measurement, on a quiet worktree with nothing staging.

⚠️ **The headroom shrank from 21.5s to 16.5s and the cause is this session's cages, not drift:**
S10 gained PART 6 + PART 7 and S12 went 67 → 77 cases. `$FullTierBudgetSeconds` is **not** raised
and must not be. **Do not run the full tier concurrently with anything that stages** — the first
three attempts today were contaminated, one by my own concurrent commit rewriting `.git/index`
under the suite and one by `HEAD MOVED DURING THIS RUN`.

✅ **The standing `run_guard_trigger_tests` PART 4b failure is CLEARED** (`2e2af151`). It had been
red since lane `S13H`'s `cbf2c98a` added `import scheduler` to `check_pilot_acceptance.py` without
declaring it — blocking every commit touching `scripts/_test/**` or that module, which is what an
`ORDER-1370` lane touches first. Fixed by declaring the path (one line, the same transitive-import
case as `check_param_surface.py`). Done by this lane rather than handed on because every lane in
the ledger reads CLOSED, so there was no writer left to coordinate with.

**Suites after this session:** S10 (+PART 6 +PART 7) · **S12 77/0** (was 67) · S11 85/0.

---

## §3 — 🔴 THE LANE QUESTION, ANSWERED WITH TODAY'S NUMBERS

`_triage/PROMPT_NEXT_SESSION_S13K.md` starts at **`ORDER-1370`**. Do the two streams collide?

**On files: barely.** S13K owns `factory/runs/pilot/**`, `scripts/pilot_*`,
`check_pilot_acceptance.py`, `run_s13_tests.py`, MT5. This lane owns `_triage/factory_os/*.py`
and their suites. **Two real intersections:**

- 🔴 **`schemas.json` + `CONTRACTS.md`.** S13K item 4 says `ORDER-1255` *"needs a lane that owns
  `schemas.json`"* — and the corrections stream edits it constantly (four entities this session).
  `CONTRACTS.md` regenerates from it, so two lanes editing means two lanes regenerating.
  **Exactly one lane may hold this file at a time.**
- 🟡 **`AGENT_TASKBOARD.md`.** Not a subject overlap — a *mechanical* one, and it is the file that
  produced **five** provenance accidents today including mine.

**On subject: one adjacency worth knowing.** S13K item 3 (`ORDER-1330`: the fingerprint's missing
component is the symbol spec) and `ORDER-1266` + its new eighth item (a parameter value can move
while `effective_config_hash` does not) are **the same question about two different fingerprints**.
Different files, but whoever decides a migration policy for one should know the other exists.

### 👉 RECOMMENDATION: separate lanes, and **not at the same time** — start with `ORDER-1370`

**Sequential, not parallel.** Today's tally for running these concurrently: **5 provenance
accidents · 1 duplicated block reservation · 2 full-tier runs invalidated · 1 commit rejected by
its own tier** (S13K's own §, `5ac83527`/`1464a94f`). None of that is subject collision — it is
all one shared worktree with two writers.

**`ORDER-1370` first, because it is the only one blocking a person.** The `ORDER-1254` owner
question cannot be restated until it lands — the BWD figure is **1.44** or **1.20** depending on
whether financing was deducted twice, and S13K forbids quoting either until `1370` decides. The
corrections stream blocks nobody.

**If they must overlap anyway:** S13K takes everything under `factory/` and `scripts/pilot_*`;
corrections keeps `_triage/factory_os/*.py` **and `schemas.json`**, so `ORDER-1255` waits. Declare
board rows by number in both ledger rows, and commit the board **once, at the end**, in three steps.

---

## §4 — What is left here

**`ORDER-1265`** — measurement done, repair not started. Its own sequencing stands: **fix the
cage's expressiveness before judging the three hypotheses**, because a kill matrix that stops only
*at* states and never *between* them cannot represent the state they live in.

**`ORDER-1266`** — 5 of 7, plus the eighth handed to it today. Decide the hash preimage before
repairing from either end.

**`ORDER-1269`** #2 and #4 — **both #2 files are BUNDLE MEMBERS**; editing either costs a signature.

**`ORDER-1360`** — three costed options, and the measurement that makes it a decision: **27 tracked
`PROMPT_NEXT_SESSION_*.md`, 8 with a routing block, 19 without**.

**`ORDER-1380`** — the two review leftovers, each with the shape of its answer written down.

**Still declared open on purpose:** `SP16` asserts the split-value gap is OPEN, so closing that gap
turns the suite red.

---

## §5 — Standing rules that did not change

- 🚫 No EA verdict from automation. 🚫 Do not raise `$FullTierBudgetSeconds` (pinned 120.0s).
- 🚫 Do not edit a cage to make its own FAIL go away. **Narrow it and delete its false stated
  reason, or flip it — in the same commit as the fix.** (`P01` failed on me twice today and was
  right both times: a new public callable must be **declared**. Declaring is not weakening.)
- 🚫 **Before repairing anything in `_triage/factory_os/`, check `check_s2a_attestation.py:BUNDLE`**
  and run `run_s2a_conformance.py`. Nothing this session touched a member — **68/0**, no signature owed.
- 🚫 `MASTER_BACKLOG.md` §2 · `AGENTS.md` · `PROJECT_STATE.md` · `s2a_attestations.jsonl` · any
  `.set` migration · any magic allocate/renumber/retire · any history rewrite.
- **Reserve your block, commit the reservation first, derive from BOTH tests — and re-read
  immediately before staging (§0).** At this writing the highest `## ORDER-<n>` is **`ORDER-1380`**
  and the highest block reserved is **`1390-1399`**. **Derive it yourself**; blocks moved three
  times today between a handoff being written and read.
- **Run the `.ps1` wrapper, not just the `.py`** — it caught two of my cases today that were green
  under bare python, both because a refusal reached **stderr** under `EAP=Stop`.
- ⚠️ `Set-Content -Encoding utf8` writes a **BOM** into a commit subject. Use the Write tool.

---

<!-- HANDOFF-ROUTING -->

| item | goes to |
|---|---|
| the owner's ratified answer (a), and the two accounts it moved | `ORDER-1267` |
| six money-path defects, with the two limits pinned as passing cases | `ORDER-1260` |
| five alerting defects, and the sixth that was already dead | `ORDER-1261` |
| claim 2.7 confirmed with five live controls; #1 and #2 re-measured | `ORDER-1265` |
| a parameter value can move while its config hash does not | `ORDER-1266` |
| the two bundle-member repairs and the front guard | `ORDER-1269` |
| the handoff-contract trigger gap, three costed options, 27/8/19 | `ORDER-1360` |
| assignment-vs-reassignment invariants, and the regression inference | `ORDER-1380` |
| nine review defects found INSIDE the repairs, all fixed and re-measured | `DONE` |
| the tier number, the cages added, and the provenance error this lane caused | `DONE` |

<sub>⚠️ This routing block is still unvalidated — `check_handoff_contract.ps1` does not trigger on
`PROMPT_NEXT_SESSION_*.md`. That is `ORDER-1360`, and this file is one more instance of it.</sub>

---

Open with: **"`_triage/PROMPT_NEXT_SESSION_CORRECTIONS_7.md` ทำต่อเลย — จองบล็อกใหม่ก่อน · stage/อ่าน/commit แยกเป็น 3 step ทุกครั้ง (§0) · เริ่ม ORDER-1265 แล้ว ORDER-1266 · เช็คก่อนว่าเลน S13 ปิดหรือยัง (§3)"**
