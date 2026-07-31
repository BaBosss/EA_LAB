# Parallel-lane prompt — the operate track (runs alongside the Factory OS lane)

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the opening prompt for a lane that
> runs in parallel with Factory OS work**. Written 2026-08-01. Paste the block below as the first
> message of the new session.
>
> **Why a separate lane at all:** the Factory OS work reserves **no MT5 lane** and touches
> `_triage/factory_os/**` + `scripts/_test/**` + `scripts/check_*.ps1`. This track touches
> `portfolio/**`, `DEMO_DEPLOYMENT_PLAN.md` and the EA/backtest surface. The two overlap in exactly
> **two** files, and both are handled by the rules in the prompt.

---

```
This lane runs IN PARALLEL with a Factory OS lane. Read the collision rules first -- they are two
concrete files, not a general warning.

Read in this order:
  PROJECT_STATE.md  §2 (status) · §3 (decision log) · §7 (forward plan)
  CLAUDE.md  VERDICT GATE (the bar table -- especially the thin-EA row, 2026-07-28)
  AGENT_TASKBOARD.md — grep '## ORDER-510'
  portfolio/DEPLOYMENTS.csv  (the single inventory; §0.5 invariant 1)

COLLISION RULES, measured 2026-08-01 -- not a general caution:
  1. portfolio/DEPLOYMENTS.csv is IN the fast-tier pathspec, and
     scripts/_test/run_front_guard_evidence_tests.ps1 REFUSES TO RUN while that file is dirty
     ("index vs disk differ -- refusing to run rather than risk an ambiguous restore").
     => An uncommitted edit to it makes the OTHER lane's commits fail.
     => Edit it, commit it, in the same working session. Never leave it dirty across a break.
  2. AGENT_TASKBOARD.md is one file with many writers (ledger rule 4). Declare it in your
     `owns paths`, batch every board edit into ONE write at the end of the lane, and re-read
     `git log -1` immediately before staging.
  3. Everything else in this track (DEMO_DEPLOYMENT_PLAN.md, _mt5_auto/**, ea_template/**) is
     untouched by the Factory OS lane.
  4. MT5 lane: the Factory OS lane reserves NONE, so any lane number is free -- but declare it in
     the ledger row anyway, and Model 4 is exclusive machine-wide.

TASKS, in the order they should be done. Item 1 has a deadline nothing else here has.

  1. JUDGE-READINESS DEBT. Measured 2026-08-01 from portfolio/DEPLOYMENTS.csv:
         58 ACTIVE deployments
         11 ACTIVE rows with an EMPTY kill_rule
         18 judge dates fall within 90 days, the earliest 2026-10-09
     The bar table requires kill criteria PRE-REGISTERED AT ATTACH TIME. These 11 were not, and
     that cannot be undone -- so fill them and LABEL THEM HONESTLY as retro-registered (a column
     note or a kill_rule value that says so). A retro-registered rule is weaker evidence than a
     pre-registered one and must not be written as if it were the same thing; arriving at
     2026-10-09 with no criterion at all is worse than either.
     Default per CLAUDE.md unless a per-EA override is justified: eqDD > 12% · 3-mo PF < 0.8 at
     >= 15 trades. Thin EAs (< 0.5 closed trades/week) use the 2026-07-28 ratified row instead:
     12 months live + net positive + no kill tripped, permanently small lot.
     ACCEPTANCE: zero ACTIVE rows with an empty kill_rule; check_state stays CLEAN; every filled
     row says whether it was pre- or retro-registered.

  2. ORDER-510 -- OPEN, money path. The live VPS fleet runs binaries built BEFORE ORDER-132/138.
     Two independent lines of evidence agree (disk dates, and F3 Global Variables showing only
     pre-132 `Boss_<magic>_` keys with zero `Boss2_` keys). The trap is that updating them makes
     five EAs reset their persisted state at once.
     ⛔ HARD RULE FROM MEMORY `live-fleet-runs-pre-132-binaries`: do NOT copy any `Boss_*.ex5`
     onto the VPS until this order closes. The order is about producing a SAFE PROCEDURE, not
     about performing the update.
     Read the row before planning; do not re-derive its evidence.

  3. The "MM-parts library (cap+linear/log)" the owner directed. PROJECT_STATE §7 item 6 called
     this ORDER-098-C. IT IS NOT: the real 098-C is "FVG-fill + RSI confluence gate", closed
     REJECT 2026-07-17. 098-A closed REJECT, 098-B closed DEMO-ELIGIBLE. So this directive has
     NO ORDER NUMBER and never did. Write it an order first (docs/WORK_LIFECYCLE.md), then build.
     It is the EV-order winner among build work: a multiplier on an existing edge, which
     PROJECT_STATE §3 (2026-07-18) ranks above mechanism×symbol and above new ideas.

  4. /ea-monitor cadence -- needs the owner to export live_deals.csv (PROJECT_STATE §6). Ask for
     it; do not block on it.

WHAT NOT TO DO IN THIS LANE:
  ❌ Do not write a new EA from scratch. The funnel's bottleneck is 3-month wall-clock, not
     candidate supply -- SuperTrendFlip BTCUSD H4 rev03 is VALIDATED and still not attached.
     Adding candidates to a queue limited by the calendar moves nothing.
  ❌ Do not attach anything to demo/live yourself. That is the owner's call (L4, money).
  ❌ Do not copy binaries to the VPS (item 2's hard rule).
  ❌ Do not issue a verdict from a smoke run. Screen labels are triage; verdicts follow the
     VERDICT GATE decision tree in CLAUDE.md, and the last-optimize-before-verdict rule applies.
  ❌ Never git add -A. Commit path-limited. ~267 dirty/untracked files must stay.

Reserve a lane in docs/SESSION_LEDGER.md and COMMIT the reservation before touching anything.
Parse `## ORDER-<n>` out of all four board files yourself; do not trust the ledger's foot-of-file
summary bullets (stale nine times, BACKLOG-D29).
```

---

## Two things the owner asked about that are NOT open — checked against the boards, not recalled

| asked | actual state |
|---|---|
| **ORDER-370** (`check_stale_binaries` not scanning `_vps_deploy/**`) | **`DONE + REVIEWED` 2026-07-27**, in `ARCHIVE_TASKBOARD_2026-07A.md`. `PROJECT_STATE.md` §7 listed it under **"Open (2026-07-27)"** for five days after it closed, and that stale bullet was quoted back to the owner on 2026-08-01 as live work. Corrected in the same commit as this file. |
| **ORDER-098** | Every lettered sub-order named in `PROJECT_STATE` §7 is closed: **098-A** REJECT · **098-B** DEMO-ELIGIBLE · **098-C** (FVG-fill + RSI gate) REJECT. The **"MM-parts library"** §7 attributes to 098-C is a real user directive that **was never issued under any number** — task 3 above. |

**The general lesson, since it caused a wrong answer to the owner:** `PROJECT_STATE` §7 is a *cache*
of the boards. It has no guard, nothing regenerates it, and it drifts exactly like the ledger's summary
bullets do. **Check a claim against `AGENT_TASKBOARD.md` / `ARCHIVE_TASKBOARD_2026-07A.md` before acting
on it** — including claims made by a previous session, including mine.

## The one number that sets the priority

18 judge decisions land within 90 days, starting **2026-10-09**, and 11 ACTIVE rows have no
pre-registered kill criterion. Every other item on this list can slip a week without loss. That one
cannot: a judge date arriving with no criterion is not a weak judgement, it is the absence of one.
