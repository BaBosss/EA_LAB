# HANDOFF 2026-07-23F — XAU strategy-design session close

Start-here for the next session. This session ran a long strategy-design + testing pass (16 EAs
built/tested total across three phases) plus caught up on ORDER-170/174 status from a parallel
session.

## What this session did (chronological)

1. **Wave-1/2 status check** (07-19 EAs, already deployed/parked before this session) — no new work,
   just confirmed status via registry.
2. **Signal-scanner idea batch (3 EAs):** VwapSnapback_EUR (DEAD), AsianDriftCarry_XAU (PARKED,
   regime-capped), VolRegimeBreakout_XAU (BUILD-ON, still climbing with N).
3. **User's 5-strategy cent-scalp brief (spread-aware XAU cent account):** EmaScalp (DEAD),
   RangeFade (DEAD-OPTIMIZED — MAIN 1.26 looked great, BWD 0.38 killed it), MomentumBurst (WATCH —
   the only strategy this whole session where BWD>MAIN naked, but Model-4 real ticks knocked it
   down from BUILD-ON, BWD 1.36→0.89), AsianPingPong (WEAK), PostNewsReversion (WATCH — had a
   **silent-order-rejection bug**, LotSize 0.005 < broker minlot 0.01, fixed).
4. **2 more new ideas:** GapContinuation_XAU (DEAD — BWD 0.52 despite a flashy thin-n MAIN),
   **PivotBreakout_XAU (992017) = VALIDATED CANDIDATE, the strongest find of the whole session.**

## 🎯 Two demo-ready candidates waiting for YOUR attach (both PENDING_ATTACH on 463666728)

| EA | Magic | Evidence | Bundle |
|---|---|---|---|
| **(BRK)_LondonORB_XAU** (SS1 + trend filter) | 992003 | M4 MAIN1.16/BWD1.06/HOLD1.21, MC ruin 0% | `_vps_deploy/SS1_LONDONORB_XAU/` |
| **(TRND)_PivotBreakout_XAU** | 992017 | M4 MAIN1.16/BWD1.22/HOLD1.33, MC ruin 0% | `_vps_deploy/PIVOTBREAKOUT_XAU/` |

Both READMEs have exact input values + pre-registered judge criteria. Also still pending from
earlier in the week: **(TRND)_TsMom_XAU (S2, 992001)** bundle in `_vps_deploy/S2_TSMOM_XAU/`.

**Both candidates' only remaining gap is identical: corr vs cohort is unmeasured** — see below.

## ORDER-170 / ORDER-174 status (closed by a parallel session, confirmed this session)

- **ORDER-170** (`portfolio_risk_admission.py` defects): ✅ fully closed, blind audit round 10 = PASS.
- **ORDER-174** (corr-from-backtest mechanism): ✅ **mechanism** closed, blind audit round 4 = PASS.
  `compute_corr_with_backtest()` now exists in `scripts/portfolio_risk_admission.py`, reads corr
  from an explicit map file (`portfolio/backtest_corr_reports.csv`, columns: magic/report_path/
  notes) — NOT auto-guessed from the 4,700+ report files, live always wins over backtest when both
  exist, default-1.0 fallback and the risk formula itself untouched.
- **⚠️ The map file is still EMPTY.** Portfolio corr numbers remain the "worst-case ceiling"
  (0/946 pairs measured) until **ORDER-184** (OPEN, agent-lane mechanical task) populates it.
  **ORDER-184's own spec cites `PVM4_MAIN.htm` — the PivotBreakout Model-4 MAIN report this session
  produced — as the verified-parseable example row.** Once ORDER-184 runs, both SS1 (992003) and
  PivotBreakout (992017) should get real corr numbers "for free" without further work from either EA's
  side.

**I did NOT pick up ORDER-184 this session** — it's explicitly scoped as agent-lane/mechanical
(qwen or Sonnet + Claude review), not urgent, and this session was already deep in strategy-design
work when 170/174 closed. Next session's call whether to dispatch it or fold it into a general
maintenance pass.

## Cross-cutting finding worth remembering for future XAU strategy design

**Every momentum/reversion idea tested across this session's three phases (~13 distinct signal
designs) showed an identical split:** artificially strong on MAIN (2023-2025, a quiet/bull-favorable
regime) and capped-or-collapsing on BWD (2020-2022, whipsaw/volatile). PivotBreakout and SS1 are the
two genuine exceptions that survived Model-4 with graceful (not catastrophic) degradation — both
share a trait: **their SL is wide relative to ATR/price action**, not a tight fixed-point stop. The
one EA that looked BWD-dominant at Model-1 (MomentumBurst, tight 40pt SL) collapsed hard under
Model-4 real ticks. **Working hypothesis for next designs: SL width relative to the instrument's
natural noise floor may matter more for M1→M4 fill-survival than the entry signal itself.**

## Known infra gotchas hit again this session (already in other memory files, repeating here for visibility)

- **Shared git worktree**: two sessions' commits interleave; my content sometimes lands inside
  another session's commit message (harmless, content verified intact each time — check with
  `git log -S"<unique phrase>"` if a commit "disappears").
- **`mt5_run.ps1` without `-SetFile`** pulls ALL inputs from the terminal's per-EA tester cache —
  caused two false BWD readings mid-session. Always pass a full `.set` for anything you'll report.
- **Silent order rejection**: a fixed-lot input below the broker's `SYMBOL_VOLUME_MIN` gets rejected
  by the server with zero visible error — reads as "0 trades / no signal" in the tester. A follow-up
  audit task (`task_8b1aef11`, user-started) is checking the rest of `ea_projects/` for the same
  class.

## Registry state — all committed to master

EA_SCORECARD_AND_REGISTRY.md, EA_MASTER_INDEX.csv, portfolio/DEPLOYMENTS.csv all updated with this
session's 8 new EAs (VwapSnapback, AsianDriftCarry, VolRegimeBreakout, EmaScalp, RangeFade,
MomentumBurst, AsianPingPong, PostNewsReversion, GapContinuation, PivotBreakout — 10 total, some
listed above). Full commit trail in `git log` from `16502f7b` (first signal-scanner idea) through
`1e37a123` (PivotBreakout final).
