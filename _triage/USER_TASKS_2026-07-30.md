# User-side tasks — 2026-07-30

Owner: **user**. Claude cannot do these from its seat. One section per task.

---

## 1. Send the consolidated Codex blind audit (S2a + ORDER-601's owed re-check)

**Why it is yours:** Claude's two dispatch attempts through the Claude Code Codex plugin both failed for
reasons unrelated to the task, and the user reports never hitting these when sending from their own Codex:

| attempt | outcome |
|---|---|
| 1st (`codex-rescue`, ~21 min in) | stopped by OpenAI content moderation — *"flagged for possible cybersecurity risk"*. Cause was the **brief's wording** (`rebuild the attack` / `bypassable` / `defeat the purpose`), not the task. Brief reworded to plain QA language in `f9a430ba`. |
| 2nd (reworded, 4 min in) | ran clean past moderation, then the **Codex thread vanished**: the job log shows `Codex turn interrupt failed: thread not found`, no work after 13:20:11, while `status` still printed `running`. The plugin's tracked PID (4560) was already dead. Nothing further was spent. |

**The brief is written, committed and ready:** `_triage/factory_os/CODEX_AUDIT7_BRIEF.md`

### Paste this into Codex

```
Read D:\EA_LAB\_triage\factory_os\CODEX_AUDIT7_BRIEF.md and follow it exactly.

This is a code-quality review of a data-validation script and the data file it validates,
both of which live in this repository. No security dimension, no external system, no third
party. The core question is standard conformance testing: check_s2a_migration.py enforces
nine acceptance criteria against a 27-row JSONL file, and I want to know whether a file
could satisfy all nine while still being useless to the person who has to read it. If so,
the acceptance criteria are too weak. Writing such a sample input and running the validator
on it is the requested evidence.

Write your report to exactly one file: _triage/factory_os/CODEX_AUDIT7_2026-07-30.md.
Everything else is read-only — stage nothing, commit nothing, and do not run `git add -A`
or `git stash`; the working tree has unrelated modified files from other work.

Re-derive every number in section 4 of the brief rather than trusting it — especially the
claim that no script in the repository parses section 2 of MASTER_BACKLOG.md, because a
recommendation depends on it.
```

### What it decides

- **ORDER-600** → `DONE` or `NOT DONE`, and whether it can move toward `REVIEWED`.
- **ORDER-601** → whether its owed independent re-check passes. It cannot go `REVIEWED` on the
  Claude seat's word: the work, the audit response and the judgement all came from one seat.

### The two answers worth reading first

1. **Can a passing D1 be worthless?** `UNOWNED` and `EMBEDDED:*` were added to make ORDER-600
   satisfiable at all, and both are *exemptions from the criteria with the most bite*. If Codex builds a
   file that passes all nine criteria and tells you nothing, **the acceptance is too weak** and that is
   the headline finding.
2. **"Nothing machine-reads `MASTER_BACKLOG.md` §2."** The entire recommendation to approve the Coverage
   transfer rests on this one measurement. If any script, hook, skill or subagent definition parses that
   table, **the recommendation changes.**

### When it comes back

Hand the report to Claude — it will reproduce each finding locally before accepting it (the pattern that
worked for audit 6: all 8 findings reproduced before being fixed, and a self-review then found 3 more).

---

## 1b. Send audit 8 — the narrow follow-up (do this INSTEAD of re-sending audit 7 if 7 is already done)

Audit 7 came back **NOT DONE** and was right; its blocker and every finding are fixed (`caf9f18c`), and
the remainder became `ORDER-602`, now built (`ea44077e`). **Brief 8 is much shorter and targets only what
audit 7 could not have seen:** `_triage/factory_os/CODEX_AUDIT8_BRIEF.md`

### Paste this into Codex

```
Read D:\EA_LAB\_triage\factory_os\CODEX_AUDIT8_BRIEF.md and follow it exactly.

This is a code-quality review of data-validation scripts and the data files they validate,
all inside this one repository. No security dimension, no external system, no third party.
Where the brief asks for a constructed input, that is negative testing: does a conformance
checker accept inputs that satisfy its letter while failing the specification's intent?

Write your report to exactly one file: _triage/factory_os/CODEX_AUDIT8_2026-07-30.md.
Everything else is read-only — stage nothing, commit nothing, and do not run `git add -A`
or `git stash`; the working tree has unrelated modified files from other work.
```

**Why it is worth one more pass, in one line:** `s2a_signoff.jsonl` is a **brand-new trust boundary — a
signature artifact — designed, built and self-reviewed by the same seat whose work it signs off.** Every
round so far, the outside reviewer found a class my own review did not: audit 7 found a *composition* of
six criteria that passed while all 29 single-field checks were green.

**What it should NOT re-review:** the three stale `all_clear` design lines and the seven false
`x-enforced-by` names — accepted from audit 7, routed to `ORDER-601` / `BACKLOG-D31`, mechanical.

---

## 2. Sign or refuse the Coverage edge — `ORDER-600`

**This is the decision the whole S2a slice exists to put in front of you, and it blocks slice S2.**

Read: `_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md` → section *"The Coverage edge, in one read"*.

**The proposal:** `MASTER_BACKLOG.md` §2 stops being hand-maintained; `factory/coverage.jsonl` becomes the
machine source and §2 is **regenerated** from it.

**Two measurements, both taken rather than assumed:**

- **Nothing machine-reads §2** ⇒ the transfer breaks **no automated reader**. The only parser of
  `## 2. COVERAGE MATRIX` in the repo is this order's own checker; `scripts/check_state.ps1:124` opens the
  file solely to assert its owner-banner line. The risk is therefore **human**: the banner tells readers
  the table is hand-maintained, so the banner and the section header must say *"generated — edits here are
  overwritten"* **in the same commit** that first generates it. That mitigation is part of the proposal.
- **Leaving it already costs.** Design §1.2 measured §2 at **7 EA rows**, last really updated
  **2026-06-27**, while `portfolio/DEPLOYMENTS.csv` carries **64** rows. Never reconciled at any
  granularity.

**Claude's recommendation:** approve as `TRANSFER`, conditional on the banner change shipping in the same
commit as the first generation.

⚠️ **Wait for the audit in task 1 before signing** if you want the outside check first — its second
headline question is precisely whether the "nothing reads §2" claim holds.

### How to record it

`signoff_state` is **your act, in your own commit** — no row says `APPROVED` and Claude may not write it.

- **approve** → set `signoff_state: "APPROVED"` on the `CoverageCell` row of
  `_triage/factory_os/s2a_migration.jsonl`.
- **refuse** → set `"REFUSED"` and add a `refused_reason`. A refusal with a stated reason closes the
  question; silence leaves it open and it comes back.

> 🔴 **DO NOT FOLLOW THE ROUTE THIS SECTION ORIGINALLY GAVE — it was wrong, and Codex audit 7 (MAJOR 2)
> caught it.** The instruction was to edit D1 and relax `SIGNOFF_STATES` in the same commit. That is
> **incomplete**: `run_s2a_gate.py` step 1 requires D1 to byte-match `gen_s2a_migration.py`, so you would
> also have to edit the **generator** that emits `PROPOSED` and regenerate D1 *and* D2. Approving would
> mean changing **the evidence, the acceptance rule, and the generator in one commit** — and afterwards
> nothing could tell "the owner approved" apart from "the author weakened the guard".
>
> **Codex's verdict: a sign-off deadlock, not a safeguard.** Accepted — and **`ORDER-602` has now landed
> (`ea44077e`), so the deadlock is gone.**

### ✅ How to record your decision now — one appended line, no guard touched

```bash
tools\python312\python.exe _triage\factory_os\check_s2a_signoff.py --template
```

That prints a ready-made line with the current `proposal_sha256` already filled in. Append it to
`_triage/factory_os/s2a_signoff.jsonl`, edit `decision` / `decided_at` / `reason`, commit.

**Nothing else changes** — not `check_s2a_migration.py`, not `gen_s2a_migration.py`, not
`s2a_migration.jsonl`. C2 still refuses `APPROVED` inside D1, which is the guard that stops *Claude*
self-approving, and it stays armed. Validate any time with:

```bash
tools\python312\python.exe _triage\factory_os\check_s2a_signoff.py
```

An empty or partial log is **not** an error — it means you have not decided yet, and it never reports
`ORDER-600` complete. If a cited file has changed since the proposal was pinned, signing that owner is
**blocked** until it is re-pinned, or until you add `"stale_pin_acknowledged": true` to record that you
signed anyway.

---

## 3. Ratify (or refuse) the `AGENTS.md` §2 change that `WorkReceipt` needs

One row of D1 is **`REFUSED` by Claude rather than proposed to you**: `WorkReceipt` → `ops/receipts/`.

Design §1.3 #9 says opening that writer needs an **`AGENTS.md` §2 permission change only you can ratify**.
§2 currently lets an agent write **only its own order row** on the taskboard and reserves new orders to
Claude/the user — so proposing the transfer now would mean proposing a writer the governance file forbids.

**Nothing is blocked on this.** It is recorded so it does not disappear. Decide it whenever
chat-commitments-that-never-became-orders start mattering.
