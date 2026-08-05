> # ⛔ SUPERSEDED 2026-08-05 — do not open a session from this file.
> Everything §2 and §3 list as pending or owed was done by the lane holding block `1420-1429`,
> within hours of this being written. **Open from `_triage/PROMPT_NEXT_SESSION_OWNERQ.md` instead.**
> What changed, so this file cannot mislead:
> - **`ORDER-1411`'s verdict IS filed** — `ff80245f`, full Row-X in one commit (board, `EA_MASTER_INDEX.csv`,
>   `EA_SCORECARD_AND_REGISTRY.md`, `EDGE_CATALOG.md`, `B1_DATASET.csv`). §3's first bullet is void.
> - **All three owner questions in §2 are answered.** The participation floor is **100 closed trades per
>   window, hard, alongside `n ≥ 30`** (`390e2700`) — and it reaches backwards: `ORDER-430`'s two
>   qualifications at **52 and 62 trades are VOID**, which is what `ORDER-236`'s un-parking rested on.
> - **§1.3's mechanism is WRONG.** `TRADEDIR_BOTH = 60`, so shorts were already permitted. Direction is
>   pinned by `_14_Direction` and `Entry_GridLog.mqh:70` cannot run both directions in one instance by
>   construction. The long-only *observation* stands; it is a **second screen to run**, not a flag to
>   flip (`cbe22ff6`, owned by `ORDER-1420`).
> - **§5's block numbers are stale.** Highest `## ORDER-<n>` is **1420**, not 1411.
>
> Left otherwise intact: §0 and §1.1/1.2/1.4/1.5/1.6 are still the useful part, and §0's lesson —
> *measure at HEAD before building a repair* — is exactly what this banner exists because of. The lane
> that wrote this file came back to file a verdict that already existed.
# OPENING PROMPT — a quota-constrained session that turned into sixteen commits, two owner rulings, and a guard

> Written 2026-08-05 by lane `S-2026-08-04-QUOTA4` (block `1410-1419`). It opened to answer *"4% quota
> left, what can we do"* and ended up running ~140 backtests, opening `ORDER-1410` and `ORDER-1411`,
> and finding that a sweep can report fifteen consistent results without having swept anything.
> ⚠️ **Read `docs/SESSION_LEDGER.md` first.** At this writing **no lane is ACTIVE**.

---

## §0 — 🔴 READ FIRST: the one thing that would have prevented most of tonight's rework

**Measure at HEAD before building anything to fix what you think is broken.**

It cost me three separate times in one session:

1. I concluded audit 7 *"never ran"* from the commit that recorded its first attempt being blocked,
   and built a repair for that. It had returned the same evening (`caf9f18c`). The five rows waiting
   on it were waiting for **someone to route a returned answer**, not for an audit.
2. I re-dispatched it, and because the brief grants write permission to one filename, **Codex
   overwrote the tracked 2026-07-30 report**. Nothing was lost — restored from HEAD, blob-sha
   proven — but only because a `git diff --cached` read-back showed `373 deletions` on a file I
   believed was new.
3. I marked `ORDER-611/615/616` answered by that audit **in the commit whose message described me
   making exactly that mistake**. Neither report names those orders even once. Reverted.

**So: before you build, check whether the thing already happened. `git log --grep` and `ls` are one
command each.**

---

## §1 — What is DONE

| order | state | one line |
|---|---|---|
| **`ORDER-1302`** | 👤 owner ruled | widen **every** boundary axis down, **numeric floor per axis** — the floors themselves are NOT given |
| **`ORDER-1257`** | 👤 owner ruled | **option (b)** — replace the pinning instrument; option (a) is now *forbidden*, not merely unchosen |
| **`ORDER-236`** | evidence complete, no verdict | levers measured on **three** hosts, never passed |
| **`ORDER-1411`** | 🆕 opened + run | CELL 1 = `PARKED-VERIFY(user)` by pre-registered bar · CELL 2 = `SPIKE`, not promoted |
| **`ORDER-1410`** | 🆕 opened, **nothing repaired** | owns audit 7's findings, which had sat unrouted for five days |
| **`ORDER-600` / `601`** | re-opened | audit 7 refused both, **twice** (2026-07-30 and 2026-08-04) |
| **`ORDER-611` / `615` / `616`** | back to `AWAITING` | audit 7 is **not** their audit — candidate is `ca228686`, still standing |

### 🎯 Six things worth carrying forward

**1. 🔴 A REPORT WITH A PLAUSIBLE NUMBER IS NOT EVIDENCE THE INTENDED CONFIG RAN.** Fifteen reports,
each named for a different parameter pair, had all run the untouched baseline and all returned the
identical `PF 1.17 / 211 / net 149.01`. Reading them gives *"both axes are inert"* — the opposite of
the truth, with fifteen mutually consistent reports behind it. **Nothing caught it**; it was avoided
by an accident of filename parsing. ⇒ `scripts/check_sweep_inputs.ps1` now refuses this
mechanically. Run it on every sweep **before reading a single result**.

**2. 🎯 THE PARTICIPATION PROBLEM APPEARED FOUR TIMES IN ONE NIGHT AND IS NOW UNAVOIDABLE.**
`ORDER-430` qualified two hosts on **52 and 62 trades**; `EURJPY` clears the same gate on **498** and
was never selected. `AB` on EURJPY scores `MAIN 2.51` by trading **62% less** (184 → 70). `MDX` BWD
fails on 204 trades — a real loss, not an absence. The `PENDING-RATIFY(user)` note in `CLAUDE.md` now
has four instances behind it. **👤 It needs a number from the owner.**

**3. 🔴 THE WHOLE `Boss_14` HOST EVIDENCE IS LONG-ONLY.** `short_trades = 0` on every report checked,
`TradeDir=60` in `B14_AB_off.set`. That applies **retroactively** to `ORDER-430`'s seven-symbol screen
and to every `ORDER-236` block. On JPY crosses across both windows this is substantially a bet on yen
weakness. **Nobody has ever measured this chassis with shorts enabled.** 👤 Owner question.

**4. 🎯 THE INERT-AXIS PROBE PAID FOR ITSELF ON ITS FIRST USE.** Four of seven `MacdDiv` axes move
nothing — not PF, not drawdown, not even the trade count. A grid over all seven would have
manufactured a plateau out of axes that do nothing. **Probe before gridding, always.**

**5. 🔴 `CONF_PA_ENGULF` IS NOT INERT — ON XAUUSD IT NEVER FIRED.** Three hosts settle it: it cuts
entries 213→92 on AUDCAD and 184→117 on EURJPY, and changed nothing in any digit on XAUUSD. The
earlier "inert" reading was correctly scoped to its host and stays true; the *general* inference from
it is withdrawn.

**6. 🔴 `MacdDiv_Naked` HAS NO SL AND NO TP INPUT, AND STILL SHOWS 0.46–1.85% DRAWDOWN** — including
across a window it loses money in. **Nobody has explained this.** It is not a reassurance. Reading the
`.mq5` to find where a losing trade exits is a genuinely open question.

---

## §2 — 👤 THREE QUESTIONS WAITING ON THE OWNER

1. **Enable shorts and re-measure the `Boss_14` chassis?** Until then every host number is half the
   evidence (§1.3).
2. **A participation floor as a number** — trades-per-window, replacing or supplementing `n ≥ 30`
   (§1.2). Changing a bar requires ratification; this seat may not write one.
3. **Re-point `ORDER-236` at `EURJPY`?** It is the only host clearing both bars with real
   participation — but it qualified on the long-only screen, so question 1 comes first.

Also standing from earlier: the **seven numeric floors** `ORDER-1302` needs. The owner gave the shape
of the answer, not the numbers, and **no sweep may start without them**.

---

## §3 — What is OWED

- **`ORDER-1411`'s verdict is NOT filed.** CELL 1 is `PARKED-VERIFY(user)` by a bar committed before
  the sweep ran, but the Row-X checklist — scorecard verdict + `EA_MASTER_INDEX` in the same commit +
  `EDGE_CATALOG` + a `B1_DATASET.csv` row + the 3-line owner brief — is untouched. **Do the whole
  checklist in one commit.**
- **`ORDER-1410` repairs nothing yet.** A written useless 27-row D1 passes all nine criteria and exits
  0. 🚫 Do not close it by making checkers green — they already are.
- **`ORDER-611/615/616`** need their real audit identified (`ca228686`?) before anyone marks them.
- **`ORDER-236` CELL 2 of `ORDER-1411`** and the `ORDER-236` lever parameters themselves have never
  been swept — `_50_RegimeMode`, `_9_PA_MinBodyRatio`, other `StackConfirm` values. Required before
  `DEAD-OPTIMIZED` can be *earned*.
- **`ORDER-430`'s AUDCAD figure does not reconcile**: it recorded BWD `2.20 / 62 trades`; the same
  `.set` on the same lane measures `1.44 / 146`. Both cannot be right and `2.20` is what un-parked
  `ORDER-236`.
- **Archive sweep**: 25 rows are genuinely movable. 🚫 `ORDER-601` is **not** — `Get-StatusClass`
  matches the word *REVIEWED* inside *"awaiting a re-check before REVIEWED"* and rates it movable.
  The terminal-side vocabulary is still an unanchored substring match; the `ORDER-260` fix only
  anchored the non-terminal side.

---

## §4 — New tooling, and the rules that came out of six failed batches

- **`scripts/check_sweep_inputs.ps1`** — refuses a sweep whose reports did not vary. Proven red on
  the 15 void reports (`exit 1`), green on the valid 25, `exit 2` on an empty glob. Writing it
  reproduced two of the defect classes it exists to catch; both fixes carry their reasoning inline.
- **`docs/WORKER_BRIEF_RULES.md`** — measured, not theorised. The headline: **run count is not the
  variable.** 12 runs died while 40 survived; what kills a worker is a brief that asks it to
  reproduce raw tool output (it passes through the context twice). Append on parse. Do not delegate a
  job that is mostly waiting. Escalate to Sonnet only when a batch genuinely cannot be split.
  🚫 **`AGENTS.md` was NOT touched** — that prohibition is the handoff's, so promoting these is the
  owner's call.

---

## §5 — Standing rules that did not change

- 🚫 No EA verdict from automation. 🚫 `$FullTierBudgetSeconds` stays pinned at 120.0s.
- 🚫 `AGENTS.md` · `PROJECT_STATE.md` · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · any `.set`
  migration · any magic allocate/renumber/retire · any history rewrite.
- **Stage in one call, read the diff in another, commit in a third.** It caught the report overwrite
  tonight and it is the only reason nothing was lost.
- **Derive your block yourself immediately before staging.** Highest `## ORDER-<n>` is **`1411`**;
  highest block held by a lane row is **`1410-1419`**. Do not trust that sentence — it is stale the
  moment it is written.
- `_mt5_auto/reports/` is **gitignored** (`.gitignore:70`) — anything you put there is not tracked.

---

<!-- HANDOFF-ROUTING -->

| item | goes to |
|---|---|
| the owner's ruling on grid floors, and the seven numbers still owed | `ORDER-1302` |
| the owner's ruling to replace the pinning instrument | `ORDER-1257` |
| levers measured on three hosts, never passing; the long-only caveat | `ORDER-236` |
| CELL 1 `PARKED-VERIFY`, CELL 2 `SPIKE`, and the unfiled verdict | `ORDER-1411` |
| audit 7's findings, refused twice, nothing repaired | `ORDER-1410` |
| audit 7 is not the audit these rows await | `ORDER-611` · `ORDER-615` · `ORDER-616` |
| the AUDCAD BWD figure that does not reconcile | `ORDER-430` |
| the sweep-inputs guard and the worker-brief rules | `DONE` |
| the report overwrite, restored and proven byte-identical | `DONE` |

---

Open with: **"`_triage/PROMPT_NEXT_SESSION_QUOTA4.md` — จองบล็อกใหม่ก่อน (derive เอง) · stage/อ่าน/commit แยก 3 step · เริ่มที่ยื่น verdict ORDER-1411 ให้ครบ Row-X แล้วไป ORDER-1370 · §2 มี 3 ข้อรอผมเคาะ"**
