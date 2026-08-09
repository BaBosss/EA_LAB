# HANDOFF — `S-2026-07-28-MAGIC511` (ORDER-511 · ORDER-520)

> shift report for the lane that reserved block **520-529**. Board rows carry the evidence;
> this file is the shift-change note only. Canonical entry = `PROJECT_STATE.md`.

## What this lane was asked to do

ORDER-511 STEP 1-3: find which template EA on account **463666728** was running on the compiled
default magic `990001`, and whether **more than one** was (the question that decides whether trade
separation is broken). STEP 4 was added mid-lane once the user ratified it.

## What it found

**One EA, not two: `Boss_17_Wave5` on `USDJPYm,H1`.** Trade separation was never broken — ownership is
symbol **and** magic (`core/Execution.mqh:24-25`) and the only other USDJPYm EA sits on a different
magic. **The October judge was not cross-contaminated.**

**But the magic was only the visible symptom.** The bundle `.set` had **never been loaded on that chart
at all**. Six fields were at compiled defaults: `_0_Magic` · `_9_MaxLevels` · `_23_TrailStart` ·
`_23_TrailStep` · `_17_Wave3MinMult` · `ExitMode`. The running strategy differed on entry, exit engine
and trail — the `M4 1.56/1.92` evidence in the inventory described a config that had never been on it.
Same family as memory `attach-verify-gate-and-binary`.

**Nothing was lost.** The unpinned leg opened **zero trades** in 10 days (deals export + account
snapshot agree), so the clock re-base cost no evidence.

## What changed on disk

- `portfolio/DEPLOYMENTS.csv` — 990303 row: `start_date` 07-18 → **2026-07-28**, `judge_date`
  10-16 → **2027-07-28** (+12mo, ORDER-235 thin bar), notes rewritten. The `magic` field was
  deliberately **left at 990303** throughout — the fix was re-pinning the chart, not rewriting the
  ~20 files that reference the magic.
- `DEMO_DEPLOYMENT_PLAN.md` — matching re-base note under the ORDER-235 thin table.
- `AGENT_TASKBOARD.md` — ORDER-511 evidence blocks; **ORDER-520 opened**.
- Nothing else. **No `.set` edited, no compile, nothing copied to the VPS.**

## What the user did on the VPS

Re-pinned the chart and deleted the four stale `Boss_*_rc_peak_eq` GVs. Confirmed landed by the new
`Boss_990303_rc_peak_eq = 99948.29 @ 2026-07-28 14:00`.

## 🔴 Three things I got wrong, all recorded on the board

1. **Inference F was refuted by the user's F3 screenshot.** I argued from a frozen `rc_peak_eq` that
   nothing could still be on the default; an EA was. I had validated the high-water-mark logic against
   **current** source while these are **pre-132** binaries — a gap I listed as a limit and then reasoned
   straight past. (Later vindicated in *mechanism*: the pre-132 source has the same logic and MT5's GV
   `Time` is last-**access**, which the `[INIT]` lines at 17:02:51 confirm exactly. The reasoning step
   that was wrong was treating a stale value as proof of absence.)
2. **The first `.set` scan lied about 31 of 37 bundles.** The files are **UTF-16LE**; a byte-level grep
   reported "no `_0_Magic`" and pointed at the wrong EA. Caught by hexdumping a file the grep called
   empty. memory `prove-the-instrument-can-see-the-file`.
3. **We checked five fields and there were six.** `ExitMode` was assumed to be at its default and never
   asked for; the Experts log settled it from the two sibling charts that *had* loaded their `.set`.
   **Diff every key in the `.set`, not the keys you believe differ.**

## Open — in priority order

1. **ORDER-511 re-verify (one screenshot, blocks REVIEWED).** The GV proves the **magic** took. The
   other five fields are unverified on the chart. Marking REVIEWED on the magic alone would repeat the
   exact failure this order documents.
2. **`EA_BREAKOUT_XAU (XAUUSDm,H1)` on 463666728 has no inventory row.** Logs
   `AllowLive=YES Bars=40 SL×1.5 TP×5.0 EMA200=ON` — **`Bars40` is the description on the `991001`
   REAL-MONEY row** (159503454) and the init line does not print its magic. Needs `_06_Magic` read.
3. **ORDER-520** — `991001` (real money) · `991004` · `990205` still carry +3mo `judge_date`s that
   ORDER-235 replaced on 2026-07-28. Three of four come due in ~10 weeks against a bar that no longer
   exists. **Do not touch the `991001` row without the user.**
4. **ORDER-510 has a second blocker this lane found.** `RiskControl_InitEx` fail-closes on any legacy
   pre-132 `Boss_<magic>_*` GV without `RC_AdoptLegacyHalt=true` (`core/RiskControl.mqh:140-155`;
   `RC_PersistHalt` defaults true). The four on 463666728 are now deleted, **but the other accounts in
   the fleet have not been checked** — same refusal, and it looks exactly like "the EA went quiet".

## Not done and deliberately so

`PivotBreakout_XAU` (992017) was never sighted in the chart list or the logs. The list was truncated
and it may simply be below the fold — **absence here is not evidence it is missing**, and it was not
worth the user's remaining quota to chase.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| One EA on the default magic, not two ⇒ trade separation intact, October judge not cross-contaminated | ORDER-511 (measured, OPEN) |
| The `.set` had never been loaded; six fields at compiled defaults | ORDER-511 (escalation block, OPEN) |
| Re-pin landed and was safe — snapshot proves the open USDJPYm position was `990120`, leg was flat | ORDER-511 (OPEN) — no orphan, no follow-up |
| Nothing halted (`[RISK]` = 0 across 3 days); `[INIT]` 17:02:51 matches the GV clock | ORDER-511 (DONE, no further work) |
| Kangaroo is attached and running (init 17:29) — it was never missing | ORDER-511 (DONE, no further work) |
| Judge clock re-based to `start 2026-07-28` / `judge 2027-07-28`, discarding nothing | `DEPLOYMENTS.csv` + `DEMO_DEPLOYMENT_PLAN.md` (DONE) |
| **Re-verify the other five fields on the chart — blocks REVIEWED** | ORDER-511 (OPEN, next action) |
| **`EA_BREAKOUT_XAU (XAUUSDm,H1)` unregistered; config matches a real-money row** | **ORDER-521 (opened here)** |
| **Thin EAs still on +3mo judge dates, incl. `991001` real money** | **ORDER-520 (opened here)** |
| Legacy pre-132 GVs fail-close `OnInit` — cleared on 463666728, **other accounts unchecked** | ORDER-510 (existing, OPEN) |
| `PivotBreakout_XAU` (992017) never sighted — list was truncated, absence is not evidence | ORDER-511 (noted, no work owed) |
| Diff **every** key in a `.set`, not the keys you believe differ | memory `attach-verify-gate-and-binary` (to be extended next session) |
