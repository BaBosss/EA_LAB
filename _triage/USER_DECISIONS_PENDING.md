# Owner decisions still pending — the durable list

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **decisions only the owner can make,
> which are not yet made** · created 2026-07-31 because the owner said *"เคาะได้เลย แต่ผมกลัวหลุดหรือ
> ตกหล่น"* — so they are written down here in full, with what breaks if they are missed.

**Nothing here blocks the next three slice batches.** All four block the *tail*. They are recorded now
so that when they do block, the context is not being reconstructed from memory.

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

## Not on this list, and why

- **The Coverage transfer** — decided 2026-07-31, recorded in `s2a_attestations.jsonl`, executed.
- **The stale-pin acknowledgement** — decided, four times, and `ORDER-614` rev 2 exists so it stops
  being asked. See `_triage/USER_TASKS_2026-07-31.md` §1.
- **Two `PENDING-RATIFY` bar items** (the trial-count ladder, the participation floor) — real, but
  they change the **VERDICT GATE bar table**, not the Factory OS build. They live in `CLAUDE.md`
  where the bars are, and they block nothing here.
