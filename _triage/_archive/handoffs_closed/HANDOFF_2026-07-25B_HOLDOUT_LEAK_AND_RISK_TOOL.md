# HANDOFF 2026-07-25B — the holdout leak, and the risk tool's real numbers

**Session shape:** started as "what work is left?", turned into finding a leak that had been
running for an unknown length of time, closing it permanently, and tracing what it already
damaged. ⚠️ **A parallel session ran all day too** (ORDER-200 MRIS Phase C, ORDER-201 ST03
spacing lever) — check `git log` before building on anything from 2026-07-25.

## Start here next session

1. **`_triage/ORDER202_HOLDOUT_CONTAMINATION_RETROSCAN.md`** — the full finding, both parts.
2. `_triage/CODEX_REVIEW_QUEUE_2026-07-25.md` — three money-adjacent items batched for when
   ChatGPT quota returns (user directive: finish the work, review in one pass).
3. Taskboard ORDER-202.

## What happened

`.claude/agents/ea-screener.md` and `ea-validator.md` both ran every screen and every optimize
with a window ending **2026.06.01** — six months inside the declared 2026H1 holdout. Nothing ever
failed loudly; it was found by reading the files. A holdout is spent the first time it is touched,
so any "holdout PASS" produced through those agents was not a holdout number at all.

Same read turned up three more drifts in those two files: MC bar `ruin<5%` (project bar is ≤2%),
smoke gate `PF≥1.5` (silently dropped the whole 1.2–1.5 WATCH band), and both returning retired
PASS/REJECT vocabulary — while `score_backtest.py` still emits REJECT at PF<1.05 off ONE cell,
which is exactly the premature kill the no-DEAD-before-optimize rule was paid for.

## What it damaged (87 contaminated optimize passes out of 6,467 ini)

| | verdict |
|---|---|
| **`EA_BREAKOUT_XAU` 991001 — REAL MONEY** | 🔴 **directly contaminated.** Clean re-run: **v2** BWD 1.66 / MAIN 1.98 · **v3** BWD **1.01** (net +1.66 over 26 trades = breakeven) / MAIN 1.86. v3 is the LATER revision and wins **only** on the burned window → selected into the leak. **v2 is what clean evidence supports.** Also: ~half the net in every previously-quoted 2023.01–2026.06 figure came from 5–7 trades inside those six months. |
| `Boss_14_GridLog` — 8 demo legs | 🟢 parameter values CLEAN (came from a separate pass ending 2025.06.30; ORDER-166 was revalidation). Promotion gate did touch 2026H1 for 7 of 8 → cohort's holdout is spent. No re-optimize needed. |
| `Boss_16_Kangaroo` — PENDING_ATTACH | 🟡 **edge survives** (clean MAIN 1.46/205t, BWD 1.30/278t — clears both bars) but its pre-registered judge bar was written from inflated numbers. **Before attach: expect PF 1.46 not 1.57, ~68 trades/yr not ~90.** |
| `Boss_NRBreakout_rev01` | 🔴 the revival hook WAS the contamination. Clean MAIN 0.93 and 0.82 on the two saved sets — both losses. Registry annotated; do not re-open on "ceiling 1.31". |
| everything else (21 EAs) | 🟢 either a failing verdict on inflated numbers (contamination only flatters) or no written standing at all. |

## What is now prevented

`check_state.ps1` check #9: any **reusable definition** (`.claude/agents/*.md`, `mt5_run.ps1`,
`mt5_optimize.ps1`) assigning a `ToDate` past MAIN warns, and **blocks the commit** under
`-Strict` via pre-commit. Verified three ways — clean repo passes, re-introducing the exact
historical string produces exit 1, `HOLDOUT-OK` opts out for a deliberate holdout spend. Scope is
narrow on purpose: historical one-shot runners keep their old windows, because rewriting them
would misrepresent what past runs did.

**`$mainEnd` must be re-pinned when MAIN moves (~6 months), and the new holdout declared first.**

## Also this session — the portfolio risk tool

The "the risk number is a meaningless ceiling" belief was **out of date** — ORDER-174 wired in
backtest correlation and the pairs that actually enter the formula are nearly all measured. The
real distortions were elsewhere, in both directions:

- **understated:** 992017 / 992003 / 992001 had no expectations row at all (attached after the
  23 Jul backfill) so they were excluded from their account's estimate. Filled 992017 (DD95 8.24%)
  and 992003 (3.61%) from their own attach-bundle MC lines. **992001 stays UNKNOWN on purpose** —
  no Monte Carlo was ever run on it.
- **overstated:** a basket with only ONE known-DD95 leg gets keyed `basket::<id>`, which
  `get_corr()` can never match, so it falls back to corr 1.0 against everything. Account
  463666728 read **73.04%** where the same formula over the same measured correlations gives
  **38.36%**. Fix is built but **DEFAULT OFF** (`--resolve-single-leg-baskets`) — the 1.0 default
  is a deliberate cage-protected choice, so flipping it needs the Codex audit + user ratify.
  Cages 30/30 untouched still pass, +2 new.
- **991001 deliberately NOT mapped** into the correlation file: its only report runs v3 while two
  live records say v2 — mapping it would launder CR-002's open question into a number.

## Judge dates moved (user decision "เลื่อนวัน")

Nine rows extended, computed from the **expected** trade rate in `expectations.csv`, not the
observed one (EAs had only 7–19 days live — far too short to forecast). **Four were deliberately
NOT moved:** 991001, 991004, 990205, 990303 would need until 2028–2029 to reach 30 trades. For
them the **30-trade bar** is what does not fit, not the date — three options written into
`DEMO_DEPLOYMENT_PLAN.md`, choice left to the user because it changes a bar, not a schedule.

## Open for the user (unchanged from the session's own list)

1. 🔴 **Check `_01_BreakoutBars` for 991001 on both real accounts** — **40 = v2 (good), 55 = v3
   (the leak-selected one)**. This is the one real-money item.
2. 🔴 **CR-P0**: restore sensor `463666728`, create `69424711`, attach `AccountSnapshotExporter`.
   13–14 candidates are invisible with the October judge running.
3. Telegram bot token into `scripts/config.yaml` (alert layer built, silent until then).
4. Confirm currency on 463666728 — user says cent, `ACCOUNTS.csv` says USD. `base_equity=100000`
   is recorded; the currency column was left alone rather than guessed.
5. Verify which staged bundles are actually attached — several show ACTIVE in DEPLOYMENTS but may
   not be on a chart yet.
6. Standing policy calls: ORDER-137 fork (recommendation: shelve), NewsGuard GuardConfig,
   MacroGate attach, the thin-EA trade bar above.

## Left undone, deliberately

- **Clean coarse-genetic re-optimize of `EA_BREAKOUT_XAU`** — v2 already clears both bars on clean
  data, so this is an improvement question, not a validity one. Per the user's 2026-07-25 stance
  on optimizer method (coarse genetic first, then drill; never default to point-tests), agree the
  ranges before burning runs.
- **`NuiIndy` guardrail window unchecked** — its `CutLoss=30` recommendation cites "both-window
  profitable" with no greppable date, and it is a LIVE EA. Fell between this pass's
  deployed/non-deployed split.
- **Stale `2026.06.01` windows in order-specific scripts** (`gsmc_validate.ps1`, `order104*.ps1`,
  `qwen_batch_runner.ps1`, `mt5_batch_shortlist.ps1`, `optimize_loop.ps1`) — left as history.
  Only matters if one gets reused for new evidence.

## Gotchas worth keeping

- **Second MT5 instance works for Model-4** — `D:\Meta 5b` with `-Portable -DataDir "D:\Meta 5b"`.
  Both instances hold ThinkMarkets-Live ticks; XAUUSD 2023.01–2025.12 reports **99,472,212 ticks**
  on both, which is how comparability was verified rather than assumed. Useful when the primary
  is busy or when RAM is tight (free RAM was 1.7 GB of 32 — the known Model-4 blocker).
- **Order-number collision is real.** This work was written as ORDER-201 before noticing the
  parallel session had registered that number. Renumbered to 202; the `O201_*` report files were
  left alone on purpose.
