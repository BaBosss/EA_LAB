# HANDOFF 2026-07-28 — lane `S-2026-07-28-BATCHQUEUE`

> **What this is:** a shift report. What was measured, what changed, what is safe to build on
> tomorrow, and the two things that are NOT what they look like. Routing at the end.
>
> **Start here on 2026-07-29:** §6 (the queue) — but read §3 first, because one of its lines
> corrects a claim that is written into a commit message and would otherwise be inherited.

---

## 1. What the session was asked to do, and what it actually became

Asked: find batch work and run it. It became, in order — close ORDER-372, fix the bug that closing
it exposed, fix the bug that *testing that fix* exposed, act on a blind Codex audit of all of it,
then finally run the batch. The batch is the smallest part of the session by time and the largest
by value; everything before it was clearing the ground so the batch would produce trustworthy
numbers.

**The through-line worth carrying:** four times this session something reported success while being
wrong — a wrapper that said FAIL while the backtest was still running, a CSV that looked like data
and held string byte-counts, a cage that went green on six broken scripts, and a lane guard that
printed "no ACTIVE lane" on the commit meant to re-arm it. In every case the artifact kept being
produced after it stopped being true.

## 2. Measured results you can build on

### ORDER-372 — CLOSED. NuiIndy `CutLoss` 30-vs-100 over 18 months

| leg | PF | trades | net | eqDD% |
|---|---|---|---|---|
| `CutLoss=30` (ratchet armed) | 0.38 | 1,470 | **−8,494.97** | **90.43** |
| `CutLoss=100` (disarmed) | **1.98** | 1,411 | **+44,208.06** | 55.16 |

ORDER-222 could not rank these because its no-cut arm rested on a −15,300 basket the tester
force-closed at the window edge. This re-run settles it: the end-of-test residual was **−8.63 and
−379.72**, under 1% of net on both arms, so the calendar decided nothing this time.

**The finding beyond confirming ORDER-222:** the cage is dominated on *both* axes — drawdown is
90.43% armed against 55.16% disarmed. Cutting 30% of the *current* balance and re-arming realises
the loss and walks the account down in steps, so it manufactures drawdown rather than bounding it.

🔴 **No live implication.** This ran at 4× shipped sizing to reach a threshold that has never fired
at real sizing, and ORDER-373 settled the account question *after* the ENGINE-EDGE rule was already
in force. Do not reopen it on this evidence.

### ORDER-541 — REVIEWED. Boss_14 GridLog across 12 untouched pairs (24 runs, Model 4, MAIN)

Full table is in the ORDER-541 block on the board. Three things matter:

1. **`grid` destroys the entry on 7 of 12 pairs** (NZDJPY 1.86→0.84, AUDCHF 3.39→0.75,
   GBPCHF 1.79→1.00). Only CHFJPY, GBPCAD and GBPNZD improve, all marginally. Boss_14 "travels
   across pairs" less well than ORDER-095 concluded — its existing homes may be the exception.
2. **Two ENGINE-EDGE-CANDIDATEs: AUDUSD (0.66→1.01) and USDCAD (0.74→1.25 at DD 8.03%).** Under
   the 2026-07-19 carve-out these are no longer auto-kills. **They have passed nothing yet** — the
   class requires BWD 2020-22 as a HARD gate and it has not been run.
3. **CHFJPY is the only clean entry-edge** with a real sample on both arms (1.30/97t → 1.33/418t).

🔴 **The order's own label rule produced two false positives.** `A ≥ 1.2 = entry-edge` labelled
**AUDCHF on 3 trades in 3 years** (PF 3.39) and GBPCHF on 25. A `thin-entry` label was added by
hand. This is fresh evidence for the `PENDING-RATIFY` note in CLAUDE.md that **n≥30 is too low for
a 3-year window** — here it was not even enforced in the screen.

## 3. 🔴 Corrections to things already written down — read before trusting them

- **A commit message of mine is wrong.** `c2fbb8d8` claims a bare `($pipeline).Count` was printing
  a 0% win rate in `basket_earun_gsmc_corr.ps1`. Measured afterwards: the `$null`-on-one-match trap
  is real for **object** pipelines but those two files hold **numbers**, and a scalar in PS 5.1 has
  a synthetic `.Count` of 1. The described failure could not have happened. The code comments were
  corrected; the commit message cannot be, hence this line.
- **ORDER-540's own method does not work.** It instructs a runner to `grep` lever names out of the
  `.ex5`. That returns MISSING for every lever including ones known present, because `.ex5` is
  packed. A sanity token ("SuperTrend", "Macd") is also absent, which is what proved the instrument
  wrong rather than the binary. **Use the fallback the same order names: a short backtest, then read
  the report's Inputs page.** For Boss_14 that listed 116 inputs and showed `StackMode=92`.
- **ORDER-141's "compile passed" has no surviving artifact.** `(EXP)_AdaptGridMC_rev01.mq5` exists;
  there is **no `.ex5` anywhere on this machine**. ORDER-546 is blocked on recompiling it first.
- **`deploy.ps1` does not know `D:\Meta 5c` exists.** It hardcodes roaming and `D:\Meta 5b`. That
  is why the 5c lane drifts, and why Boss_14 there was **21 days stale** behind `core/Execution.mqh`
  before this session recompiled and copied it by hand. Any future run in 5c must re-check this.

## 4. What changed in the tooling, and why it matters to results

Eleven runner-calling scripts could report a **previous run's numbers as fresh**, because
`mt5_run.ps1` clears a stale report only *after* its `exit 2` abort checks. Worst cases:
`gsmc_validate.ps1` scored IS/OOS by filename unconditionally, and `ab_mode_test.ps1` parsed both
A/B arms with no check at all — one aborted arm silently turned an A/B into "this run vs some
earlier run". All now gate on the runner's exit code **and** the report's mtime, via
`scripts/lib/report_freshness.ps1`.

`mt4_run.ps1` never set an exit code on success (it fell off the end), so callers read the previous
command's value. Fixed to match `mt5_run.ps1` (0 ok / 1 no report).

Two cages added and registered in `run_fast_cages.ps1`: `run_report_freshness_tests.ps1` (26
assertions) and `run_truncation_message_tests.ps1` (15). Both mutation-tested — reverting the
whitelist, planting an ungated caller, or reducing an exemption to a bare marker each make them
fail. Fast tier is 8 suites, ~5s.

## 5. 🚫 Standing prohibitions carried into tomorrow

- **Do not call AUDUSD/USDCAD candidates.** They are ENGINE-EDGE *class* pending a HARD BWD gate.
- **Do not touch the 2026H1 holdout.** SuperTrendFlip's is still clean and the pyramid PYR1 config
  is waiting to spend it once. No ORDER-54x run may cross 2025.12.31.
- **Do not copy any `Boss_*.ex5` to the VPS.** ORDER-510 is open; `OnInit` would refuse five magics
  at once including **990208, real money**.
- **Do not reopen ORDER-373** on the ORDER-372 numbers. See §2.
- **Every PF gets `trades` and `DD%` beside it.** This session produced a PF of 3.39 on three trades.

## 6. The queue, in run order

`ORDER-540` cleared Boss_14 only. **542 and 543 need the same Inputs-page probe first** — the same
check that caught a 21-day-stale binary.

| # | order | work | lane | note |
|---|---|---|---|---|
| 1 | **ORDER-543** | MacdDiv USDJPY: extend the fan **below `SwingRadius=2`** | `Meta 5b` | 431's ceiling was picked at the fan's bottom edge; cheapest high-value run |
| 2 | **ORDER-541 follow-on** | **BWD 2020-22 on AUDUSD + USDCAD**, arm B | `Meta 5c` | HARD gate; decides whether the two ENGINE-EDGE cells live |
| 3 | **ORDER-542** | STF non-FX cells #20-24 (genetic) | `Meta 5c` | 1 cell = 1 session; probe Inputs first |
| 4 | **ORDER-546** | AdaptGridMC first-ever backtest | `Meta 5` | **blocked**: recompile first, no `.ex5` exists |
| 5 | **ORDER-544** | NuiIndy ENGINE-EDGE 5-condition cage | — | mostly arithmetic; ORDER-372 feeds condition 2 |
| 6 | **ORDER-545** | pre-commit reads working tree, not the staged snapshot | — | from the Codex audit; affects 4 pre-existing suites too |

`ORDER-543` and the `541` BWD follow-on are on different lanes and different EAs, so they can run
in parallel. `542` should not — genetic saturates the box.

## 7. Paste-ready prompt for the next session

> Read `_triage/HANDOFF_2026-07-28_BATCHQUEUE.md` §3 and §5 first. Then run **ORDER-543** on lane
> `D:\Meta 5b` and the **ORDER-541 BWD follow-on** (AUDUSD + USDCAD, arm B `StackMode=92`,
> 2020.01.01–2022.12.31, Model 4) on lane `D:\Meta 5c`, in parallel. Before either, do the
> Inputs-page freshness probe on the EA that lane will run — `deploy.ps1` does not deploy to 5c and
> Boss_14 there was 21 days stale yesterday. State `trades` and `DD%` beside every PF. Do not cross
> 2025.12.31.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| NuiIndy cut-loss 30-vs-100 long-horizon ranking | DONE — ORDER-372 REVIEWED, ratchet confirmed worse on both axes |
| Boss_14 12-pair screen | DONE — ORDER-541 REVIEWED, 12/12 |
| AUDUSD + USDCAD BWD hard gate (ENGINE-EDGE class) | ORDER-541 |
| MacdDiv USDJPY fan below SwingRadius=2 | ORDER-543 |
| SuperTrendFlip non-FX cells #20-24 | ORDER-542 |
| AdaptGridMC recompile then first backtest | ORDER-546 |
| NuiIndy ENGINE-EDGE 5-condition cage | ORDER-544 |
| pre-commit judges working tree instead of staged snapshot | ORDER-545 |
| binary staleness pre-flight for 542/543 EAs | ORDER-540 |
| participation floor: n>=30 too low for a 3-year window (AUDCHF passed on 3 trades) | BACKLOG-D29 |
