# Owner decisions still pending — the durable list

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **decisions only the owner can make,
> which are not yet made** · created 2026-07-31 because the owner said *"เคาะได้เลย แต่ผมกลัวหลุดหรือ
> ตกหล่น"* — so they are written down here in full, with what breaks if they are missed.

**Nothing here blocks the next three slice batches.** Items 1-4 block the *tail*. They are recorded
now so that when they do block, the context is not being reconstructed from memory.
**Item 5 (added 2026-08-01, `ORDER-731`) is different in kind:** it blocks nothing today, and it
charges a toll every day it is undecided — roughly two refused commits a day, measured.

**Rule for whoever reads this:** these are the owner's to decide. Do not infer, do not default, do
not "proceed under a stated assumption". An owner decision recorded by anyone else is the defect
blind audit 8 raised as BLOCKER 1.

---

## 1. ✅ DECIDED 2026-08-01 — pilot FIRST, full universe on idle/overnight batches

**Owner, verbatim:** *"ทำตามข้อ 1 เพื่อแสกนดูเบื้องต้นว่าดีไม่ดี แล้วเมื่อตอนที่ว่างค่อยทำ B ทำทั้งหมดตอนรัน batch ตอนกลางคืน ตอนนอน เพื่อเก็บที่เหลือ"*

**The decision, restated so a machine can act on it:** Core Universe **v1 = the pilot**, and it is
**expandable by construction, not a final target**. The remainder of the live fleet's underlyings is
**not dropped** — it is queued as **overnight/idle batch work**, which is the right home for it
because the binding constraint is **3 MT5 lanes of wall-clock**, and wall-clock at night is free.

**v1 cells — PINNED HERE, correct them if this is not what you meant** (3 symbols × 2 TF, all three
already carry proven work so the pilot measures the mechanism rather than a cold start):
`XAUUSD H1` · `XAUUSD M15` · `EURUSD H1` · `EURUSD M15` · `GBPUSD H1` · `GBPUSD M15`.
Grounding: the live fleet runs **20 symbol strings = ~15 underlyings**, and **XAU alone is 28 of 57
positions (49 %)**, so a pilot that omitted XAU would not resemble the portfolio it is meant to
inform.

**Tier 2 (the overnight queue), for when lanes are idle:** the remaining underlyings measured in the
fleet — `USDJPY` · `CHFJPY` · `AUDNZD` · `EURJPY` · `AUDCAD` · `CADJPY` · `AUDJPY` · `GBPJPY` ·
`XAGUSD` · `US30` · `BTCUSD` · `ETHUSD`. **Order them by fleet weight, run them when nothing else
holds a lane, and never let a tier-2 cell displace a tier-1 re-run.**

⚠️ **The one thing this decision does NOT license:** claiming `S15` complete on the pilot alone.
The design forbids inventing symbols to claim completeness; the pilot proves the mechanism, the
overnight queue earns the coverage.

---

## 2. ✅ DECIDED AND APPLIED 2026-08-01 — narrow, append-only writer. **`S14` is unblocked.**

**Owner, verbatim:** *"เปิดแคบ append-only"*

**What was chosen:** an agent may **append one Work Receipt row per order** to a single JSONL, and
nothing more — no editing an existing row, no second surface, and **verdicts stay with the owner and
the Claude seat**, exactly as `AGENTS.md` §2 has them today.

✅ **APPLIED 2026-08-01 after the owner confirmed the EXACT §2 row in chat** (*"เอาตามนี้"*) — a
ratified **direction** was deliberately not treated as a ratified **sentence**, the same distinction
that governed both attestation signatures the same day, because `AGENTS.md` itself forbids Claude
widening Claude's permissions.

**What landed, in one commit:** the §2 row · `_triage/factory_os/check_work_receipts.py` (criteria
**W0-W5**: append-only as a byte-prefix over CRLF-normalised text, JSON-object rows, `order_id`
required, one receipt per order, and a **closed** decision-field list) · its cage
`run_work_receipts_tests.py` (**16 cases** — CONTROL that an append still LANDS, ATTACK on every
clause, two SPECIFICITY cases proving the closed list does not swallow ordinary work fields, and an
ENGAGEMENT mutation that neutralises the comparison and requires the attacks to go red) · the tier
wrapper + declaration + regenerated pathspec.

**The three repo guards each demanded something before letting it in, which is them working:** the
declaration cage refused until the import closure was declared (answered by *narrowing* the closure
— the checker reads HEAD with a direct git call instead of importing `check_s2a_migration`, so it is
coupled to `evidence.py` alone); then the shape lint's L0 named it as undeclared, then demanded a
category, then demanded a paired suite for **W1-W5**. **Seventh consecutive time L0 has named an
addition its own author had not declared.**

⚠️ **The limit, stated rather than left to be found:** the grant SAYS own-order-only, but nothing
mechanically enforces *whose* order a row cites — every agent commits under one git identity, which
is Codex audit 8's point about the attestation log applying here unchanged. What is enforced is the
**shape**; that gap is written into the checker's own docstring.

---

## 3. ✅ DECIDED 2026-08-01 — GLOBAL magic uniqueness, with the three collisions registered as frozen exceptions

**Owner, verbatim:** *"Global uniqueness + legacy_exception"*

This ratifies what Grill decision 56 already said on 2026-07-30 and ends the contradiction between
two canonical documents. `PROJECT_STATE.md`'s invariant bullet is amended in the same commit as this
line.

**The exceptions, measured from `portfolio/DEPLOYMENTS.csv` rather than quoted from the old text —
and the count that matters is smaller than the file used to imply:**

| magic | where it sits | live on both sides? |
|---|---|---|
| `991001` | `159475669` ACTIVE REAL_CENT **+** `159503454` ACTIVE REAL_CENT | **YES — real money on both. This is the only true live collision.** |
| `991002` | `159475669` REMOVED **+** `159503454` ACTIVE REAL_CENT | no — one side is already REMOVED |
| `990103` | `159503454` REMOVED **+** `463666728` ACTIVE DEMO | no — one side is already REMOVED |

**Frozen until their judge date. Never renumbered as a side effect** — `991001` is real money, and a
renumber would silently orphan its history.

⚠️ **What is still enforced today:** `scripts/check_state.ps1` continues to check
**`account|magic`**. Switching it to global uniqueness requires the exception list to exist in a form
the checker reads, and **that is `S10`'s work, not this decision's** — flipping it now would turn the
state check red on three rows the owner has just declared legitimate.

---

## 4. ✅ DECIDED 2026-08-01 — ADVISORY for now; the numbers are set after `S13` has run once

**Owner, verbatim:** *"Advisory ก่อน ตั้งเลขหลัง S13 รันจริง"*

`S13`'s scheduler **reports** the combination count it actually searched and **never gates on it**.
It must print the number and the words *"advisory, not a bar"* — a figure printed without that
qualifier gets read as compliance, which is the whole defect this item was raised for.

**Why not set three numbers today:** nobody yet knows how many zones a real surface produces, and a
bar set before the shape is known is a bar that can be cleared by not searching — the same family as
memory `bar-cleared-by-non-participation`, which this project has already paid for once.

**Revisit trigger, so this does not quietly become permanent:** after **the first real `S13` round**,
take the observed zone count and total from that round and set the three numbers (zones per round ·
minimum total · stop rule) against measured data.

---

## 5. ✅ RESOLVED — option 2 executed and owner-signed 2026-08-01 (`c66d5e57`); HEAD green

**Final state:** the owner ratified option 2 (*"ทำ option 2 เลย"*) and confirmed the digest through a
review-then-proceed instruction. `CoverageCell.owner_ref` pins `factory/coverage.jsonl`;
`current_owner` unchanged (R6/C7 preserved, all 7 historical records eligible); the second
whole-file pin is gone; record line 9 (bundle `d88f795b`) needs no acknowledgement; all three
gates exit 0 at HEAD. The note→record match now goes through D1's `current_owner → owner_ref.path`
mapping, proven to fire on drift and stay silent today. Residual toll = §2 edits only (the section
pin, option A). Evidence = the `ORDER-731` RESULT blocks. *History below kept for provenance.*

### (superseded 2026-08-01 by the resolution above) option A was executed, and MEASURED NOT TO WORK. Option 2 became the recommendation.

**What happened:** the owner ratified option 1 (2026-08-01, lane PINFIX2) and signed the digest in
chat at 13:32 (lane PINFIX3). It landed in `212c0555`, correctly: the record in force (line 8) pins
**§2 only** and the section machinery works. **Then the first real append (`7baadb18`, restoring
`| D33 |`) turned the S2a gate RED** — `check_s2a_attestation.py` exit 1, `check_coverage_transfer.py`
exit 1, `run_contract_binding_tests.ps1` exit 1, and a `git revert` of it was **refused** with HEAD
unmoved. Everything under `_triage/factory_os/**` and `MASTER_BACKLOG.md` is uncommittable as of
this writing.

**Why option 1 could never have worked — the costing below is wrong and this line is the fix to it.**
There are **TWO** whole-file pins on `MASTER_BACKLOG.md`, not one. Option 1 narrowed
`expected_post_state` (F11 → F14). The other is **`stale_pin_acknowledgement.current_blob`, enforced
by F5 against HEAD's whole-file blob**, and it is demanded by F2 because **D1 pins the file at
`ca909b69` while HEAD is elsewhere, so N2 derives a permanent STALE note.** The note derivation
(N1–N4) and D1 are *both bundle members*, so removing that second pin is a **second** signature —
which option 1 was never priced to include.

**Measured, which is what makes option 2 the recommendation rather than a preference:**
`factory/coverage.jsonl` took **1** commit in the last 14 days; `MASTER_BACKLOG.md` took **31**.
Moving the Coverage owner to the store removes **both** pins at once (the file stops being an owner,
so there is no `owner_ref`, no note, no F2–F5, and no post-state claim to narrow), cuts signature
pressure ~**31×**, and `check_coverage_transfer.py` continues to prove §2 matches the store — so §2's
integrity is preserved by a mechanism that does not charge a signature per backlog row.

**What is needed from you, in this order:** (a) **unblock HEAD** — either one `--no-verify` for the
revert of `7baadb18` (the same shape you approved this morning, and it puts `D33` back in git
history where `git show 78a93129:MASTER_BACKLOG.md` still finds it), or a new attestation line whose
`current_blob` is the present blob (that is a signature, and it would demonstrate the toll rather
than remove it); (b) **choose option 2 or accept the toll.** Full trace = the `ORDER-731` CORRECTION
block on the taskboard. *The original write-up is kept below for provenance.*

### (resolved) The S2a pin is a WHOLE-FILE blob on a board every lane appends to

**Blocks:** nothing today — `ORDER-731`'s front guard makes the breakage immediate and diagnosable
instead of invisible. What it does not do is make it **rare**.

**Why it is yours:** the fix is a policy change, and the policy is inside the approval.
`S2A_ATTESTATION_POLICY.md` states `F5`/`F11` as *"HEAD's blob at `expected_post_state.path`"* and
fixes `expected_post_state`'s shape at `{path, blob}`. That file is a **member of
`bundle_sha256`**, so editing it voids your record and costs a signature — which is exactly the
loop `ORDER-614` rev 2 was written to end. An agent narrowing the scope of your own approval is
the same shape as writing your own approval.

**Measured, not argued:** `MASTER_BACKLOG.md` took **30 commits in 14 days** (45 in 60) to
2026-08-01 — `git log --oneline --since='14 days ago' -- MASTER_BACKLOG.md | wc -l`. A whole-file
blob pin on that file means roughly **two owner signatures a day**, or two refused commits a day,
forever. Two independent lanes hit it within one hour on 2026-08-01 (`f4c9fd9f`, `78a93129`), the
second an hour *after* the warning was written down.

**What is needed — one of:**
1. **Narrow the pin** to what the approval was actually about: §2 of `MASTER_BACKLOG.md`, the
   generated Coverage projection, rather than the whole file. Appends to unrelated sections then
   land cleanly and cost nothing. Costs: one policy amendment + one signature, once.
2. **Move the owner** of the Coverage edge to `factory/coverage.jsonl` — which is generated and
   rarely hand-edited — so the pin sits on a stable file. Costs: a `check_s2a_migration.py` change,
   and that file **is** in the bundle, so also one signature.
3. **Keep it as is** and accept a signature per backlog row. Defensible if the answer is "backlog
   rows should be rare"; it is not what the last 14 days measured.

**If it stays undecided:** the guard holds — nothing lands broken. But every lane that wants to
append a `BACKLOG-D<n>` row is blocked at the hook and has to come to you, and the first thing
blocked is restoring **`| D33 |`**, which lane `S-2026-08-01-OPERATE`'s handoff routing table
still points at (`git show 78a93129:MASTER_BACKLOG.md | grep '^| D33 |'`).

---

## 6. ✅ DECIDED 2026-08-02 — `ExecutionKey.ini_hash` MOVES to `RunAttempt`; identity stays computable before the run

**Owner, verbatim:** *"ทำตามที่แนะนำเลย"* (on the recommendation below, presented with its
alternatives).

**The problem.** `ExecutionKey` is what `scheduler.queue` uses to decide *"has this configuration
already been run?"* (design §3.3, decision 18) — so it must be **computable before the run exists**.
But `ini_hash` is the hash of the `.ini`, and `scripts/mt5_run.ps1` writes that file at launch time.
The S9 proof runs seeded the field from a canonical rendering of the other fields, which means a
field named `ini_hash` was not the hash of an ini.

🔴 **And the literal reading is worse than awkward — it is actively wrong.** The ini `mt5_run.ps1`
writes contains `Report=$ReportName`, which **differs on every run**. Computing `ini_hash` from the
real file would therefore give two runs of an *identical configuration* two different digests, and
**criterion 3 (idempotency) could never fire at all.** The gate that exists to stop the lane being
spent twice would be permanently disarmed by the field that was supposed to help it.

**Decision — move it, do not redefine it in place:**

| | before | after |
|---|---|---|
| `ExecutionKey` | 15 fields incl. `ini_hash` | **14 fields**, all of them things that change the numbers |
| `RunAttempt` | — | new `ini_sha256`, recorded **after** the ini is written |

Identity is computable before the run; forensics ("what exactly was handed to the tester") keeps the
real bytes, per attempt, where they can actually be known.

**Precedent, and it is exact:** `schemas.json` already fixed this same shape one level up — rev 3
required `pid` on the lease, but `LEASED` happens *before* any process exists, so `pid` moved to
`process_observed`. Its own SELF-REVIEW FIX note says *"A schema that demands a fact nobody can know
yet is a schema that gets filled with a placeholder."* That is precisely what `ini_hash` was.

**Blast radius, measured rather than assumed:** `CandidatePayload.evidence` is a list of `MetricRef`,
which carries `run_id` · `lane` · `data_fingerprint` — **not** the ExecutionKey and **not**
`ini_hash`. So **no candidate digest changes**, and there is nothing to migrate. Verified against
`schemas.json` at `1d4743fb`.

⚠️ **Who does it:** `S-2026-08-02-S10CAND`, which is **ACTIVE and already declares every file the
change needs** (`scheduler.py`, `schemas.json`, `CONTRACTS.md`). It had committed **zero code** when
this was decided, so the change lands *before* anything is built on the old shape. This lane did not
touch those files — ledger rule 4.

---

## 7. ✅ DECIDED 2026-08-02 — decision 18 reads as TWO CATEGORIES, not two enum members

**Owner, verbatim:** *"ทำตามที่แนะนำเลย"*.

**The problem.** Decision 18 permits a re-run of an identical `(config, lane, data fingerprint)`
*"except after an execution or tester error"* — a description of **two categories**. The failure-class
enum has **seven** members. The first implementation read it as the literal pair
(`TESTER_ERROR`, `TERMINAL_ERROR`), and the first real wiring run showed the cost immediately: the
machine died mid-run, the configuration went to `FAILED(KILLED)` **holding no evidence at all**, and
re-queueing it was refused **forever**. A slice whose entire purpose is recovery had made a crashed
configuration permanently unrunnable — the only way out being to perturb some value until the digest
changed.

**The tell is inside the decision itself:** it continues *"...otherwise: return the cached
evidence."* A refusal with **no cached evidence to return** is not the rule being enforced, it is the
rule being applied where it does not reach.

**The ratified mapping** (`RETRYABLE_FOR_NEW_RUN` in `_triage/factory_os/scheduler.py`):

| category | classes |
|---|---|
| tester error | `TESTER_ERROR` |
| execution error | `TERMINAL_ERROR` · `TIMEOUT` · `KILLED` · `LEASE_LOST` |
| **neither — stays blocked** | `CONFIG_REJECTED` — the configuration was not honoured, which is a fact *about the configuration*; re-running the identical one is expecting a different answer, and a human should look first |

**What still bounds it:** `MAX_ATTEMPTS = 3` caps retries *inside* a run · `CONFIG_REJECTED` stays
closed · queueing a new run is a deliberate act, not an automatic loop.

Overruling this changes exactly one tuple and nothing around it.

---

## 8. ✅ DECIDED 2026-08-02 — a `FROZEN` attestation event is a MARKER, and forbids nothing

**Owner, verbatim:** *"(a) ปล่อยเป็น marker เฉยๆ"*.

**The problem.** `/scrutinize` round 4 over S10 found that `attestation.fold` computed a `frozen`
flag and `validate_event` never read it — probed: a `CANDIDATE_REASSIGNED` appended directly after a
`FROZEN` was **allowed**. A field named `frozen` in a read-model is read by the next caller as "this
is frozen, do not touch it", and there was nothing behind it.

**The options put to the owner, with their costs:**

| | rule | cost |
|---|---|---|
| **(a) chosen** | `FROZEN` is a marker in the history and forbids nothing | matches what the design actually states; adds no rule; **no dead end** |
| (b) | `FROZEN` blocks a candidate change by `claude`; only `user` may move it after | has teeth, but invents a `user` vs `claude` split the schema does not make |
| (c) | `FROZEN` blocks everything until an `UNFROZEN` event arrives | strongest; needs a new enum member, regenerated contracts and new cage cases |

**What was built:** the unread `frozen` flag was **removed** rather than enforced, which is (a)
exactly. Nothing further is owed. **The reason it was not simply enforced** is worth keeping: the
obvious guess — refuse every later candidate change — has **no way back out**, because there is no
unfreeze event type, so one `FROZEN` would make a pair permanently unmovable. A rule with no exit is
worse than no rule.

⚠️ **If this is ever revisited, (c) is the honest upgrade path** — (b) would make two actors the
schema treats identically behave differently, which is the kind of split that gets forgotten.

---

## 9. ✅ RATIFIED 2026-08-02 — the fast-tier budgets are raised, and an order is opened to earn them back

**Owner, verbatim:** *"ยืนยัน + เปิด order เร่งด้วย"*.

**What was done before the ratification, and why it could not wait:** the tier **refused this work's
own commit** at **81.1s against the 65.0s per-path budget**, 7 of 24 suites selected, **all green**.
Subtract the new slice's own suite (2.9s) entirely and the commit is **still 78.2s** — so the old
bound had already become **unsatisfiable for a commit of that shape** (a guard plus a schema), which
is a common shape in this repo. The full tier told the same story: **107.0s against 90.0s**, and
**90.4s before that lane opened**. `run_fast_cages.ps1`'s own over-budget message offers three exits
— displace a suite, make the named one faster, or *"raise the number DELIBERATELY in the same commit
that says why"* — and only the third was available to a lane that owns none of the expensive suites.

**Ratified numbers:** per-path **65.0 → 90.0** · full tier **90.0 → 120.0**, ~11% above what was
measured so growth still trips them. `run_guard_trigger_tests.ps1`'s N1 pins both on purpose, so
raising one is a two-file act by design.

**And the second half of the decision, which is the point:** raising a budget makes the bound TRUE,
not the tier FAST. **`ORDER-1130`** is opened to earn it back — three suites are 65% of the full run
(`run_contract_binding_tests` · `run_front_guard_evidence_tests` · `run_guard_trigger_tests`), and
`run_contract_binding_tests` alone drifted 27.0s → 35.8s across a single day, so the growth is
ongoing rather than settled.

---

## Not on this list, and why

- **The Coverage transfer** — decided 2026-07-31, recorded in `s2a_attestations.jsonl`, executed.
- **The stale-pin acknowledgement** — decided, four times, and `ORDER-614` rev 2 exists so it stops
  being asked. See `_triage/USER_TASKS_2026-07-31.md` §1.
- **Two `PENDING-RATIFY` bar items** (the trial-count ladder, the participation floor) — real, but
  they change the **VERDICT GATE bar table**, not the Factory OS build. They live in `CLAUDE.md`
  where the bars are, and they block nothing here.
