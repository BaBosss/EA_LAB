# HANDOFF — 2026-07-25 (session close: open-order triage, 6 items)

**Scope:** user asked "เช็คมีงานอะไรต้องทำต่อบ้าง" → triaged every OPEN order + every `_triage/HANDOFF_*`,
walked all 8 decisions with the user one at a time, then executed the 6 they assigned to me.
**Commit:** `b9f0826e` (path-limited — see "shared worktree" warning below). Earlier entries
(ORDER-198/199 + header syncs) were swept into `6e806b85` by the parallel session — see same warning.

## What landed

| # | Item | Outcome |
|---|---|---|
| 1 | ORDER-198: 18-EA judge shortfall | **No bug.** The "18" is largely a formula artifact — see below |
| 2 | ORDER-190: Boss_16 scaled lot | `.set` built, **PENDING_ATTACH(user)** |
| 3 | optimize_guard wiring | Wired into `mt5_optimize.ps1`, warn+override per user's call |
| 4 | ORDER-199: StoMultiTap ADX-gate | **Negative** — hurts both windows, ladder now truly exhausted |
| 5 | ORDER-201: ST03 spacing lever | **Negative** — lever has no leverage on BWD, closes #1/3 |
| 6 | Taskboard hygiene | 5 stale headers synced (191/192/193/194/195) |

## The finding that matters most (ORDER-198)

The judge-readiness "18 projected-shortfall" number is **mostly an artifact of a generic bar**, not 18
failing EAs. `control_room_snapshot.ps1` carries two different metrics and they were being conflated:

- `needed_trades_per_week` — pure arithmetic: (30 − trades so far) × 7 ÷ days-to-judge. **Ignores what
  the EA's own backtest says its trade rate should be.** This is what produced the alarming "needs 2.6/wk".
- `rate_flag` (ON_RATE / UNDER_RATE) — compares observed rate against `expectations.csv`'s
  `trades_per_month_expected`, which comes from that EA's own validated backtest. **This is the honest one.**

Checked all 6 detailed magics against `rate_flag`: **991001 / 990203 / 990205 = ON_RATE** — trading
exactly as their backtests predicted, merely slow by design. The other three (991004 / 991002 / 990202)
show UNDER_RATE but sit at **n = 0–1 trades over 15–18 days**, which is inside pure Poisson noise at
their expected rates — not evidence of anything yet.

Also confirmed **no silent-skip bug**: read `(BRK)_SqueezeBreakout_rev01.mq5` (the 0-trade one) directly,
found both classic silent-kill guards (`_07_AllowLive` dry-run gate, min-lot rejection guard), verified
neither fires — the deployed `.set` sets `AllowLive=true` and 0.01 lots fill fine on sibling EAs.

**Policy the user ratified:** use `rate_flag=ON_RATE` instead of `n≥30` for EAs whose backtests already
say they're low-frequency. Recorded as a **precedent following RSI-MR**, not a one-off exception —
applies to every low-frequency-by-design EA going forward. Rationale: waiting for n=30 on 991001 (0.2/wk)
would take ~2.9 years; the bar was measuring the wrong thing.

**Data fixed along the way:** `expectations.csv` had `trades_per_month_expected=UNKNOWN` for the three
Boss_14 grid legs even though the very report cited in the same row carried the number. Backfilled
990202/203/205 → 3.83 / 3.56 / 1.25 per month (138t / 128t / 45t over the same 36-month MAIN window
already cited). Derived from cited evidence, not guessed — does not violate ORDER-164's no-guessing rule.
Re-ran the snapshot; `rate_flag` now computes for those rows instead of returning NA.

## Two negative lever results (both worth keeping)

**ORDER-199 — StoMultiTap ADX-gate (XAUUSD M15, Model 2, 4 runs):**

| config | MAIN | BWD |
|---|---|---|
| base (ADX off), re-verified | 1.50 / 64t | 0.57 / 80t |
| ADX-gate ON | **1.14 / 16t** | **0.36 / 20t** |

The hypothesis was that gating out strong-trend regimes would lift BWD (a reversion fade dying in the
2020-22 gold trend). It did the opposite **on both windows**, and cut trade count ~75%. The filter is
removing more winners than losers on net, not isolating chop. Base re-verify matched the 2026-07-19
numbers to rounding (1.50 vs 1.51, 0.57 vs 0.58), so this isn't a leverage-format artifact.

This was the **last untouched lever** in that EA's ladder — it is now genuinely exhausted, which closes
the "last-optimize before verdict" debt honestly. Verdict stays **PARKED-VERIFY(user)**, not dead:
MAIN never dropped below 1.0, so the BWD-fail rule applies. Remaining forks: demo-isolate 991075, or shelve.

**ORDER-201 — ST03 standalone spacing (GBPUSD H1, Model 1, 6 runs):**

| InpNearbyPip | MAIN | BWD |
|---|---|---|
| 30 | 1.20 / 1788t | 0.77 / 1753t |
| **50 (locked v2)** | **1.33 / 1766t** | **0.75 / 1702t** |
| 80 | 1.21 / 1680t | 0.82 / 1661t |

BWD moves 0.07 across a 2.7× parameter change — the lever barely touches the thing that's failing. The
locked config is still the best of the three, so there's no reason to change it. **First time v2 was ever
measured against the standard MAIN/BWD windows** (its own header only had short 2024 IS/OOS + a 2022
crisis slice). Levers #2 (per-symbol TP × exit-mode) and #3 (LotRepeat × vol-gate) remain untouched.

⚠️ **Scope trap for whoever picks this up:** `_mt5_auto/ab_sets/st03_spacing_probe/` (SP_fixed / atr10 /
atr20, built 2026-07-20) looks like it answers this lever but **targets the wrong EA** — those use chassis
param names (`_15_MacdFast`, `StackMode`, Expert=`Boss_15_ST03`), while the handoff is about the standalone
(`InpMacdFast`, `InpNearbyPip`, Expert=`EA_RUNNER_ST03`). Those runs already happened (`ST03SP_*_MAIN.htm`:
0.90 / 1.03 / 0.94) but they measure the chassis-generic-MM path that ORDER-135 already killed.
Also note the tuned-artifact worktree named in the handoff (`great-mendeleev-a35c44`) **no longer exists** —
only `ST03_optimized_v2.set` / `v1.set` survive in the main repo, and there is no `.mq5` source for
`EA_RUNNER_ST03`, only the compiled `.ex5`.

## 🔴 OPEN QUESTION the user raised at close — genetic optimization drift

User asked why this session hand-picked parameter values instead of running MT5's fast-genetic optimizer,
and said they didn't recall genetic ever being used. **Checked: it has been, extensively — and then stopped.**

- `Optimization=2` (fast genetic) appears in **66** `.ini` files; `Optimization=1` (complete) in 96
- The most recent genetic run is **2026-07-18**: `OPT_MDX_GBP_coarse.ini` → `_fine.ini` → `_fine2.ini`
  — i.e. exactly the coarse→fine workflow the user described as the right approach
- **Everything from 2026-07-19 onward is complete-sweep or hand-picked point tests.** That is a real drift,
  not a deliberate policy change, and nothing in the repo documents a decision to stop

The user is opening a **dedicated session** to set genetic-optimization policy (when coarse-genetic is
mandatory vs when point-testing is acceptable, how it composes with the two-window bar, how it interacts
with `optimize_guard.ps1`). Prompt handed over separately. **Do not pre-empt that decision here.**

My defense of the point-test choice was valid *for these two specific levers* (ORDER-201 swept a single
1-D parameter at 3 values — genetic and complete are identical work at that size) but it does **not**
explain the repo-wide drift, and I initially overstated it as if it did. Corrected on the spot.

## Tooling change: optimize_guard is now enforced

`scripts/mt5_optimize.ps1` calls `optimize_guard.ps1 -IniPath $ini` immediately after writing the `.ini`
and **before** `Start-Process` launches the terminal (so a bad sweep costs zero tester wall-clock).
Default blocks with `exit 3`; `-SkipOptimizeGuard` re-runs it in `-WarnOnly` mode — refusals still print,
never silent. Verified end-to-end on `O133_E4_LIN_BWD.ini` (a real depth-cap sweep): blocked at exit 1,
and the override path exits 0 while still printing. **This interacts with the genetic policy question above** —
whoever sets that policy should check how the guard behaves on coarse genetic sweeps.

## ⚠️ Shared-worktree collision — happened again, twice

Another Claude session was committing to the same working tree throughout. Two concrete incidents:

1. **My ORDER-198/199 taskboard entries were swept into *their* commit** (`6e806b85`, an ORDER-200 commit)
   by a broad `git add`. Content survived; attribution didn't.
2. **The `## ORDER-190` header line vanished** from `AGENT_TASKBOARD.md` mid-session, leaving its body
   orphaned under ORDER-199. Repaired in this commit with an inline HTML comment marking the repair.

Both are the exact hazard in memory `shared-worktree-concurrent-writers`. This session committed
path-limited (explicit file list, never `git add -A`). **Keep doing that.** Also: re-grep for your own
section headers before assuming an edit landed — a clean Edit result does not prove the file still has
your header five minutes later.

## Still waiting on the user (unchanged from session start)

1. **ORDER-190** — attach `ea_template/sets/Boss16_Kangaroo_XAU_21_30_scaled_demo.set` in the MT5 GUI
   (magic 990018, XAUUSD H1), then add the `DEPLOYMENTS.csv` row + re-pin baseline in one commit.
   Note: `Boss_16_KangarooGrid` has **never been deployed anywhere** — no live/demo row exists at all.
2. **ORDER-199 fork** — demo-isolate StoMultiTap 991075, or shelve. Ladder is exhausted either way.
3. **Sensor 463666728 STALE** (30.2h, holds ~13 shortfall-cohort EAs) — user is checking the MT5 instance.
4. **Unknown magic ×6** — all HISTORICAL/closed, all short non-`99xxxx` magics (`12345`, `1851`, …) so
   almost certainly not lab deployments. User parked this for later.
5. **ORDER-136 Wave3+** — user chose to pause; needs entry-porting into the chassis first (build work).
