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

## 1. Core Universe v1 — which symbol × TF cells are MANDATORY

**Blocks:** `S15` (expansion) · shapes the cost of `S13` (the pilot matrix)

**Why it is yours:** Grill decision 24 makes the Core Universe compulsory, and every cell added is
*Baseline + probe × every hypothesis*. That is **direct wall-clock cost**, paid in tester hours. A
system cannot choose how much of your time to spend.

**What is needed:** a list of `symbol × timeframe` pairs, and whether `v1` is meant to be small
(pilot-sized, expandable) or the real target.

**If it stays undecided:** `S15` cannot start. The mechanism can be built and tested against a
placeholder, but **do not invent symbols to claim S15 is complete** — the design says so explicitly.

---

## 2. `AGENTS.md` §2 — the Work Receipt writer surface

**Blocks:** `S14` entirely.

**Why it is yours:** the design gives *"any agent"* a new writable surface. Today §2 permits an agent
to write **only its own taskboard order row plus new reports/CSV/sets per order**. Opening a writer
surface is a governance change, and **Claude editing `AGENTS.md` to authorise itself is forbidden
outright** — it is the same shape as writing your own approval.

**What is needed:** either an amended §2 permission table, or an explicit "no, S14 stays closed".

**If it stays undecided:** S14 does not start. The schema, a read-only importer, duplicate-detection
fixtures and a provenance projection *can* be prepared — but **no writer is activated**.

---

## 3. `PROJECT_STATE.md` §3 — the `account|magic` invariant contradicts your own ratified decision

**Blocks:** `S10` (magic allocation) being *built*, not merely activated.

**Why it is yours:** on 2026-07-30 you ratified **global magic scope** (Grill decision 56). But
`PROJECT_STATE.md` §3 still asserts uniqueness on `account|magic`. **Two canonical documents now
disagree**, and the design states the invariant must be amended by you before S10 is built.

**Measured cost you already accepted:** three magics (`990103`, `991001`, `991002`) sit on two
accounts each today, and **`991001` is on real money**. Those are recorded as `legacy_exception` and
**frozen until their judge date — never renumbered as a side effect.**

**What is needed:** the amended §3 sentence.

**If it stays undecided:** S10's machinery can be written, but activation stays blocked and the
contradiction stays live — which means any reader can cite whichever document suits them.

---

## 4. "~10,000 combinations per round" — no executable definition

**Blocks:** `S13`'s scheduler being able to report compliance at all.

**Why it is yours:** the ratified search policy says *fine complete grid ≤1,000 per zone*; the locked
requirement says *~10,000 per round*. **These do not imply each other.** A genetic coarse pass plus
**one** 125-combination fine grid satisfies "≤1,000 per zone" and misses "~10,000 per round" — and an
orchestrator could declare compliance either way. Missing: **the number of zones, a minimum total
search, and a stop rule.**

**What is needed:** three numbers, or an explicit "compliance is advisory, do not gate on it".

**If it stays undecided:** the scheduler must **report that compliance is undefined** rather than
pick numbers silently. Do not let it choose.

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

## Not on this list, and why

- **The Coverage transfer** — decided 2026-07-31, recorded in `s2a_attestations.jsonl`, executed.
- **The stale-pin acknowledgement** — decided, four times, and `ORDER-614` rev 2 exists so it stops
  being asked. See `_triage/USER_TASKS_2026-07-31.md` §1.
- **Two `PENDING-RATIFY` bar items** (the trial-count ladder, the participation floor) — real, but
  they change the **VERDICT GATE bar table**, not the Factory OS build. They live in `CLAUDE.md`
  where the bars are, and they block nothing here.
