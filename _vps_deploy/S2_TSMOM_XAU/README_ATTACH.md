# S2 TsMom XAU — demo-isolate attach bundle (ORDER-151, 2026-07-23)

**EA:** `TsMom_XAU.ex5` (source `ea_projects/(TRND)_TsMom_XAU/(TRND)_TsMom_XAU_rev01.mq5`)
**Chart:** XAUUSD **D1** · **magic 992001** · set `S2_TsMom_XAU_deploy.set` (locked lb60/deadmult2, `_05_AllowLive=true`)
**Broker assumption:** check server GMT offset matches other bundles before attach (this EA has no `_03_ServerGmtOffset` input — D1 signal, session offset doesn't matter for entries).

## Evidence (locked before attach — NOT a full VERDICT-GATE funnel, see caveat below)
- Both-window sweep (`_mt5_auto/S2_TSMOM_BOTHWINDOW.csv`, lookback×deadmult ladder): **every cell** MAIN PF 2.8-4.9, BWD PF 0.52-0.77. Picked plateau-center **lb60/dm2** (not the lb100/dm2 spike-peak 4.90): MAIN PF **3.72**/26t net+1375 · BWD PF **0.70**/27t net-277.
- ADX regime-gate probe (`_mt5_auto/S2_TSMOM_ADXGATE.csv`): tried filtering entries by ADX≥20/25/30 to rescue BWD — **did not help** (BWD stayed 0.56-0.69 across all ADX thresholds). Left `_01_UseAdxGate=false` (default OFF) in this set — the gate has no measured benefit, don't turn it on without new evidence.
- Mechanism: bull-only absolute-momentum (TSMOM) — profits from sustained directional moves, loses on V-shaped reversals that an ADX trend-filter can't catch in time (lagging indicator problem, same failure class as the ST03 no-SL reversion tail — see `feedback-...` catalog).

## ⚠️ Why this is DEMO-ISOLATE, not a normal CANDIDATE attach
This EA has **NOT** cleared the VERDICT GATE funnel (no sensitivity fan, no holdout run, no MC, no M4 confirm) — the pre-registered exit from the ladder was **PARKED-VERIFY(user)**, not CANDIDATE. **BWD<1 is a KNOWN, ACCEPTED, un-fixed regime weakness at attach time** — the user chose (2026-07-23) to demo-forward the edge as-is rather than gate it behind an MRIS regime-overlay build first. This bundle exists to collect forward evidence, not because the EA passed robustness.

**Do NOT read a losing demo stretch as a fresh discovery** — it is the BWD failure mode (V-reversal after a sustained trend) showing up live, exactly as predicted by the backtest. The judge call at 3 months should explicitly check: was the losing stretch concentrated around a trend-reversal (expected, matches BWD mechanism) or spread out (unexpected, new information)? Cross-reference against the MRIS trend barometer for that period if available.

## Judge criteria (pre-registered)
- kill (repo default demo-kill bar): eqDD > **12%** OR 3-mo PF < **0.8** at ≥15 trades
- judge ≥3 months: PF ≥ **1.40** at ≥30 trades **AND** the regime-check above (no unexplained-reversal losses) → queue for MRIS-overlay build or holdout/MC before any real-money consideration. A demo PF pass alone is NOT sufficient to promote — this EA still owes the funnel steps it skipped (holdout, MC, sensitivity fan) before CANDIDATE status.

## Attach steps
1. Copy `TsMom_XAU.ex5` → target terminal `MQL5\Experts\` · attach on XAUUSD D1 chart
2. Load `S2_TsMom_XAU_deploy.set` (confirm `_05_AllowLive=true`, magic 992001)
3. Add judge_date + start_date to `portfolio/DEPLOYMENTS.csv` (magic 992001) with the actual attach date
4. Add a row to `portfolio/ATTESTATION_MAP.csv` once attached (bundle_dir=`_vps_deploy/S2_TSMOM_XAU`, ex5/set filenames above, confidence=high)

## Evidence paths
- `_mt5_auto/S2_TSMOM_BOTHWINDOW.csv` (lookback×deadmult ladder, 9 cells)
- `_mt5_auto/S2_TSMOM_ADXGATE.csv` (regime-gate rescue attempt, 6 cells, no lift)
- `_mt5_auto/ab_sets/s2_tsmom/lb60_dm2.set` (locked cell, source of this deploy set's `_01_MomLookback`/`_01_DeadAtrMult`)
- `EA_SCORECARD_AND_REGISTRY.md` WAVE-1/2 table, `(TRND)_TsMom_XAU (992001)` row
- `EA_MASTER_INDEX.csv` "(TRND)_TsMom_XAU" row
