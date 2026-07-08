# HANDOFF — Session 2026-07-08/09 (Opus): EA hunt → 8 demo candidates

> **For:** next EA_LAB session. Self-contained pointers; do NOT re-derive.
> **Canonical (read in order):** `PROJECT_STATE.md` §7 "SESSION 2026-07-08" block → `AGENT_TASKBOARD.md`
> **ORDER-055** (START HERE) → `_mt4_demo_deploy\README_DEPLOY.md` (attach guide). This file = the
> narrative + gotchas that aren't in those.

## Where things stand (one line)
EA hunt is DONE. **8 demo candidates validated + bundled + safety-checked.** The ONLY critical-path item
is **user attaches them** (manual, not Claude-doable). Everything Claude could prep is done + committed.

## The 8 candidates (full table + expected values = README_DEPLOY.md; verdicts = per-EA YAML)
- MT4 grids (from ORDER-036 treasure hunt): UnNomGuai@EURUSD(m1/2) · RSI-orig@EURUSD(m5888) · swb@AUDCAD(m990)
- MT5 (source in `ea_projects\`): RSI-MR@EURUSD(m990103,ROBUST) · Zeus@XAU(m990101) · BRK-XAU@XAU(m991001) ·
  SqueezeBRK@XAU(m991004,ROBUST) · Trendline@XAU(m991002,**EXPERIMENTAL** PF-5th 0.986, can drop)
- Correlation: no pair >0.60; the 4 gold EAs are mutually uncorrelated (different mechanisms). Details:
  `_mt4_demo_deploy\CORRELATION_6EA.md` (note: has the portfolio-sim + 6-EA matrix; Trendline/Squeeze added later).

## What the next session must do (see ORDER-055 for the ordered list)
1. **Wait for user's attach date** → record in `DEMO_DEPLOYMENT_PLAN.md`, set judge +3mo, schedule /ea-monitor.
2. Every ~2 weeks: user sends MT4+MT5 statements → split P&L by magic → compare README expected values.
   Watch: (a) MT4-grid no-SL tail, (b) combined gold exposure (4 XAU EAs), (c) Trendline #8 borderline.
3. Hunt is exhausted (instrument/TF/mechanism/lot-law/re-opt/FX-travel all tried) → only NEW mechanisms
   (flag/pennant/order-flow) have EV, and that's high-effort. Boss V2 robustness (ORDER-001) is the parked track.

## Hard-won lessons THIS session (all baked into skills/CLAUDE.md — do not relearn)
- **VERDICT GATE** in `CLAUDE.md` (top): no EA verdict until levers-swept/coarse-surface/both-regimes/
  reject-class/martingale-recheck/holdout+MC block is filled. Caught ~8 premature calls.
- **Basket/recovery EAs: validate on ONE continuous span, never tiled windows** (windowed lied ~10x on
  ConfluenceMartATR). Single-position EAs immune. (in backtest-optimize-rigor skill)
- **Each edge = one home** (instrument + TF + config). RSI-MR=EURUSD, gold-momentum=XAU+H1. Travel fails.
- **Tight-SL + wide-TP** is a real momentum-RR lever — it pushed SqueezeBRK 0.966→1.25 (made #7 from a reserve).
- **Silent-stop catch:** MT5 EAs need `AllowLive=true` in the .set or they trade 0 on demo (tester bypasses).
  All demo sets fixed; WILL-IT-TRADE checklist in README.
- Martingale ≠ auto-reject, but martingale-on-breakout is a mechanism mismatch (overfits). FIXED/LOG safer.

## New tools this session (in scripts/)
`mt4_lotcheck.ps1` (Size-col lot check) · `mt4_martingale_recheck.ps1` (SL/cap/law) ·
`mt5_deals_to_csv.py` + `mt4_deals_to_csv.py` (trade lists) · `corr_matrix.py` · `portfolio_sim.py` ·
`max_recovery_days.py` (basket time-underwater). All reusable for live monitoring.

## Suggested skills for the next session
- **ea-live-monitor** (`/ea-monitor`) — once statements arrive, attribute P&L by magic vs backtest expectation.
- **live-deployment-controller** — if any demo EA clears the 3-month judge, this is the go-live gate.
- **backtest-optimize-rigor** — if hunting a genuinely new mechanism; the failure catalog + VERDICT GATE apply.
- **strategy-and-risk → mql-code-generator → mql-code-reviewer** — the build pipeline for any new original EA.

## DO NOT
- Re-run the exhausted hunt avenues (indices=no data, London=no edge, FX-travel=fail, commodities=no travel).
- Trust windowed backtests for basket EAs. Deploy any config other than the validated .set. Skip the VERDICT GATE.
