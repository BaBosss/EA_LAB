# USER-SIDE TASK PROMPT — 2026-07-28 (ORDER-400 · ORDER-230 · ORDER-410)

> ⚠️ canonical entry = `PROJECT_STATE.md` · this file owns: **the paste-ready brief for the three
> user-only tasks ranked first on 2026-07-28**. It is not a queue — all three have rows on
> `AGENT_TASKBOARD.md` and close there.

**Why these three and not the other five user items:** none of them requires a judgement call. They are
"go read a number" tasks, they take about 20 minutes together, and each one unblocks a track that
cannot move without it. The decision items (ORDER-232 MacroGate disposition · ORDER-235 the 30-trade
bar · ORDER-234 the PERSIST_MIGRATION walk · ORDER-371 the tick-history call) are deliberately **not**
in this brief — they need a block of time and a decision, and mixing them in is how all five keep
sliding together.

**Open a separate Claude Code session in `D:\EA_LAB` and paste everything between the markers.**
That session must reserve its own ledger block before touching any file — `S-2026-07-28-QUEUERUN`
holds **500-509** and owns `AGENT_TASKBOARD.md`, so the new session must **not** write to the board
until QUEUERUN closes. Writing results into `_triage/USER_TASKS_RESULTS_2026-07-28.md` avoids the
collision entirely and is what the prompt below instructs.

---

## ===== PASTE FROM HERE =====

I am the user (patip). I am doing three manual tasks on my own terminals and VPS right now, and I want
you to walk me through them one at a time and record the answers. Reply to me in Thai. Read
`PROJECT_STATE.md` and `docs/SESSION_LEDGER.md` first.

**Lane rules that apply to you:**
- Reserve your own row in `docs/SESSION_LEDGER.md` and commit it path-limited **before** touching
  anything else. Reserve order block **510-519** if you need numbers; do not use 500-509, another
  session holds it.
- **Do not write to `AGENT_TASKBOARD.md`, `EA_SCORECARD_AND_REGISTRY.md`, `EA_MASTER_INDEX.csv`, or
  `ARCHIVE_TASKBOARD_2026-07A.md`** — session `S-2026-07-28-QUEUERUN` declared those. Write every
  result into a new file `_triage/USER_TASKS_RESULTS_2026-07-28.md` instead, and say plainly at the
  end which board rows still need updating so the other lane can do it.
- Commit path-limited only (`git commit -- <path>`), never `git add -A`, never `git stash` — this
  working tree is shared with a live session.
- Do not touch `_vps_deploy/`, do not rebuild or recompile anything, do not attach or detach any EA,
  do not change any value on a live account.

### TASK 1 — ORDER-400 (1): log in `/portable` on two terminals

Two accounts are invisible to the monitoring rotation because the saved login does not live in the
folder/mode `scripts\monitor_rotation.ps1` uses. Both accounts already connect fine when I open them
by hand — that is not the problem. They need **one login while the terminal is started with the
`/portable` flag**, so the credentials land in the portable data folder the rotation reads.

- **463666728** (MT5) — currently floating-BLIND
- **69424711** (MT4) — writes `EA_LAB_mt4_orders_0.csv` but was `login=0` at rotation time

Walk me through it: tell me exactly which terminal executable to launch with `/portable`, what to
expect on screen, and how we confirm afterwards. **Confirmation is not "I clicked login"** — after I
have done both, run the monitor rotation (or the smallest command that re-reads coverage) and show me
floating coverage going **5/6 → 6/6**. If it does not, say so and stop; do not write it up as closed.

### TASK 2 — ORDER-230: read the real currency and balance on 463666728

`portfolio\ACCOUNTS.csv` says this account is **USD**. I believe it is a **cent** account. Every
money-denominated risk and drawdown figure for the ~13 EAs judging in October rests on this one field,
and a previous session already ranked a whole campaign wrong by assuming an amount instead of reading
it (memory `pin-the-magnitude-before-calling-it-urgent`).

Tell me exactly where in the MT5 terminal to read **account currency** and **balance** (I will read
them off the screen and type them back to you). Then:
- If it is **USC/cent**: tell me every file and row that currently states or implies USD, and what the
  corrected figures become. **Do not edit `portfolio\ACCOUNTS.csv` yourself** — list the exact
  rows and the exact new values in your results file, and say that the board lane must apply them.
- If it is genuinely **USD**: say so plainly, and record that my belief was wrong. That is a real
  result, not a failed task.

Also note: the user raised `base_equity` on this account from 10,000 to 100,000 on 2026-07-25. If the
account turns out to be cent, check whether that number is in the same units as the balance — a
mismatch there silently relaxes the 25% portfolio budget on this account.

### TASK 3 — ORDER-410: hash + mtime every `.ex5` on the VPS

**13 of 23 bundles in `_vps_deploy` are older than the sources they were built from**, and `.ex5` is
gitignored, so nothing on my dev machine can see what is actually running on a chart. This is STEP 1
of ORDER-410 and it is read-only.

Give me **one command I can paste into the VPS PowerShell** that walks the four terminals'
`MQL5\Experts\` (and the MT4 `MQL4\Experts\`) folders and writes a CSV with: full path · file name ·
size · **last-write time** · **SHA256**. Then tell me how to get the CSV back to you and I will send it.

**Hard prohibition, state it back to me before I run anything:** do not rebuild, re-copy, or overwrite
any `.ex5` on the VPS as part of this. Some of those EAs are attached to open positions on real money,
and replacing a binary underneath an open position is more expensive than the problem we are
diagnosing. STEP 1 is measurement only; STEP 2 and STEP 3 are a different conversation.

When the CSV comes back, compare it against the dev-side inventory and tell me, per bundle, whether
the VPS is running the same build, an older build, or something not in the repo at all. Do **not**
write a verdict on any EA from this — it is an inventory question, not a performance question.

### How to finish

Write `_triage/USER_TASKS_RESULTS_2026-07-28.md` with one section per task containing: what I actually
read/ran, the raw numbers, what changed, and **what is still open**. Close your ledger row. If a task
could not be completed, say which one and why — an honest "TASK 3 blocked, VPS RDP was down" is worth
more than a confident summary that papers over it.

## ===== PASTE TO HERE =====

---

## What each one unblocks (for the record)

| task | order | unblocks |
|---|---|---|
| 1 | ORDER-400 | floating coverage 6/6 — every real-money account visible to the daily snapshot |
| 2 | ORDER-230 | the unit of every risk/DD figure for the ~13 EAs judging in October |
| 3 | ORDER-410 | whether any of the 13 stale staged bundles is what a live chart is running |
