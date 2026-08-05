# OPENING PROMPT — finish the Codex audit coverage, while another lane holds the code

> Written 2026-08-03 by lane `S-2026-08-03-S13SIZE` after Codex audits A + B came back.
> **Read `_triage/factory_os/CODEX_AUDIT_A_B_2026-08-03.md` first** — it is the reason this session
> exists, and Part 4 is this session's work list.

---

## 🔴 THIS SESSION AUDITS. IT DOES NOT FIX. READ THIS BEFORE YOU PLAN ANYTHING.

**The owner split the work three ways on purpose (2026-08-03):**

| session | job |
|---|---|
| `S-2026-08-03-S13SCHEMA` (13C) | builds the BOX 1 items. **Told explicitly NOT to audit** |
| **this one** | **audits only** — read, judge, write findings. Fixes nothing |
| a later one | applies the corrections, using the findings both of the above produced |

**Do not collapse those roles, even when it looks efficient and even after 13C closes.** Two
reasons, and the second is the one that matters:

1. 13C owns almost every file the findings touch — `parity.py` · `factory/parity/**` ·
   `scripts/pilot_*` · `check_pilot_acceptance.py` · `run_s13_tests.py` · `schemas.json` ·
   `run_fast_cages.ps1` · `coverage.jsonl` · `MASTER_BACKLOG.md` §2 — **and it holds the MT5 lane.**
   Editing under it is the collision the ledger's rule 4 exists to prevent.
2. **An auditor that also repairs ends up grading its own repair.** That is the same principle
   `AGENTS.md` §5.2 already applies to Codex, applied one level up. §C below is a **handover list**,
   not a to-do list — write it, hand it on, do not work it.

Check `docs/SESSION_LEDGER.md` at the start anyway, to know what is live and what is finished. If
13C has CLOSED, its output becomes **another thing to audit** (see §A), not something to fix.

---

## §A — The job: seven slices have never had their built code audited

`CODEX_AUDIT_A_B_2026-08-03.md` Part 4 establishes the gap from the artifacts in
`_triage/factory_os/`:

| | slices |
|---|---|
| built code independently audited | S4 · S5 · S7 · S8 · S13 |
| **built, never audited** | **S2 · S3 · S6 · S9 · S10 · S11 · S12** |

Two carry more risk than the other five and go **first**:

- **S10** — Candidate identity, append-only Deployment attestation, **magic reservation**. This is
  the money path, and `CLAUDE.md` already requires a Codex second opinion for it.
- **S12** — Telegram Control Room. Holds a **token**; the slice's own prohibition is *"no token in
  git/log/HTML/chat"*, which is exactly the kind of rule that is easy to satisfy in the happy path
  and leak in an error path.

Then **S9** (recoverable scheduler — the resume contract), **S3** (schema validator + negative
fixtures), **S6** (preset compiler), **S11** (SafeProjection), **S2** (OwnerRef discipline).

**And when 13C closes, its output joins the queue** — the `pf_state` schema change, the 16 registered
`CoverageCell` rows, the split of the `contract_binding` wrapper, and the parity result manifest. The
manifest is the highest-value target of the whole list, because §8.6 items 3–4 will be resting on it
and finding 1.3 already showed the roll-up beneath it discards per-case verdicts.

## §B — How to run them, learned the hard way today

1. **Blind.** Give Codex the design section, the code and the committed evidence. Do **not** tell it
   what anyone concluded, and do not paraphrase a prior finding into the brief. Audits A and B
   independently re-found two real defects precisely because they could not see the answer.
2. **Pin the commit.** Another lane is writing. Every brief says *"read at `<sha>`, not HEAD, via
   `git show <sha>:<path>`"* or the auditor reviews a moving target.
3. **Read-only.** Say so in the brief **and** in the subagent prompt. A second lane is live.
4. **The subagent will return before Codex does.** `codex-rescue` hands the job to a background
   runtime and completes, so **no notification carries the result**. You must collect it yourself:
   poll `C:\Users\patip\.codex\sessions\<yyyy>\<mm>\<dd>\rollout-*.jsonl` until the file stops
   growing, then extract only the **last assistant turn** — the transcript is ~600 KB and reading it
   whole will cost more context than the finding is worth. A working collector was written today;
   re-derive it rather than reading a rollout by hand.
5. ⚠️ **Vocabulary hazard.** `scripts/_test/**` and `_triage/factory_os/run_*_tests.py` label negative
   cases **`ATTACK`** (16 occurrences in `run_parity_tests.py` alone). The owner has lost Codex quota
   to security-flavoured refusals more than once. **A clean brief is not enough — the risk is in what
   the auditor reads.** If an audit returns a refusal, that is the first thing to suspect.
6. **Verify before repeating.** Codex is a second opinion, not an oracle. Today three of its findings
   were re-measured and confirmed and twelve were recorded as *claims to check*. Keep that split.
7. **Cost.** Codex shares the ChatGPT quota. Two audits at a time, collected before dispatching more.

Write each result to `_triage/factory_os/CODEX_AUDIT_<slice>_<date>.md` — new files, no collisions —
and record confirmed defects as orders on the board.

## §C — The corrections owed. **A HANDOVER LIST — this session does not work it.**

Carry these forward, add anything §A turns up, and hand the whole list to the corrections session.
Writing to any of these files from here is the mistake this prompt exists to prevent.

1. **Correct the carried-loss claim in all six places.** It is false: the tester books a force-closed
   position as a closed deal, so it is inside `gross_loss` and inside PF. Rewrite it as
   *concentration* (99 % of one cell's gross loss came from three positions at the window edge), not
   *concealment*. Places: `pilot_carried.py` docstring · `pilot_cells.ps1` header, notes and footer ·
   the `ORDER-1230` board row §4 · `PROMPT_NEXT_SESSION_S13C.md`.
2. **Fix `_rollup_main()`** so a case that fails its direction or anchor check cannot feed the
   roll-up, and make `--rollup` enforce the lane/symbol/window/model equality that only `main()`
   checks today. **Ship the cage case first** — `run_parity_tests.py` calls `rollup()` directly and
   never `_rollup_main()`, which is why this was invisible.
3. **Either implement the three missing §8.4 cases or stop claiming §8.6 item 3.** `CONTRACTS.md`
   requires seven; four are implemented.
4. **Make financing real or rename the field.** `financing_deducted.applied: true` while
   `net_profit` is unchanged is a field that lies. The header's claim of an adjusted `net_profit` is
   false. On BTCUSD H1 the deduction flips the sign.
5. **Check `ExitMode=22` + `_2_SuppressLegTP=false`** (claim 2.3). If per-leg broker TPs were live,
   the pilot measured a hybrid architecture and several narrative claims need rewriting.
6. **Record the second falsifier limb as unmeasured.** *"worst-case single loss > 15 % equity at real
   sizing"* was never measured, so most cells are `NOT EVALUABLE`, not "met"/"not met". Max equity DD
   is not worst-case single loss.

## Standing rules that did not change

- 🚫 No EA verdict from automation — design §10 stops S13 at `EVIDENCE_COMPLETE`.
- 🚫 Do not raise `$FullTierBudgetSeconds` (five samples: 120.8–137.3s against a pinned 120.0s).
- 🚫 Do not edit a cage to make its own FAIL go away.
- 🚫 `MASTER_BACKLOG.md` §2 outside an owner-approved `gen_coverage --apply` · `AGENTS.md` ·
  `PROJECT_STATE.md` · any `.set` migration · any magic allocate/renumber/retire.
- **Reserve your order block and commit the reservation before using a number.** Re-derive from BOTH
  tests: every `## ORDER-<n>` across all four board files **and** every reserved block in the ledger.
- **A criterion is committed in its own commit, before the run that resolves it.** Today's audit
  caught this seat claiming a pre-registration the commit graph cannot support.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| Codex audits A + B, three verified findings + twelve claims | `_triage/factory_os/CODEX_AUDIT_A_B_2026-08-03.md` — DONE |
| Audit S10 (money path) and S12 (token) | new order, this session |
| Audit S9 · S3 · S6 · S11 · S2 | new order, this session |
| Audit 13C's output once it closes — parity result manifest first | new order, this session |
| Correct the carried-loss claim in six places | §C1 — **handover, corrections session** |
| Fix `_rollup_main()` discarding per-case verdicts, cage first | §C2 — **handover, corrections session** |
| Three missing §8.4 parity cases, or drop the item 3 claim | §C3 — **handover, corrections session** |
| Financing deducted for real, or rename the field | §C4 — **handover, corrections session** |
| Check `ExitMode=22` + `_2_SuppressLegTP=false` | §C5 — **handover, corrections session** |
| Record the unmeasured second falsifier limb | §C6 — **handover, corrections session** |

Open with: **"อ่านไฟล์นี้ แล้วเริ่ม — session นี้ audit อย่างเดียว ไม่แก้อะไรทั้งนั้น เริ่มที่ S10 กับ S12"**
