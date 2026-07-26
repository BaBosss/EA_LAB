========================================================================
EA_SUPERTREND — XAUUSD H4 — DEMO (validated; live-tracking leg)
========================================================================
Status:   DEMO — user-approved 2026-07-11, PENDING_ATTACH on demo acct 415573666.

!!! CONTAMINATED SELECTION + A MISSING FAILURE (added 2026-07-26) !!!
          Audit AUDIT_BUNDLE_EVIDENCE_G1.md sec.2.
          (1) The 18-cell grid that picked ATR10 / mult3.0 / SL2.0 scored EVERY cell on
              2023.01.01 -> 2026.07.01 -- six months inside the declared 2026H1 holdout.
              The .ini say Optimization=0 only because a shell loop drove the grid; a ranked
              grid is selection regardless of that flag.
          (2) More serious: the one clean out-of-sample window that exists for this exact
              config -- BWD 2020-2022 -- returns PF 0.88, net -91.49. That result is absent
              from a README headed "validated". A losing out-of-sample run is not a detail
              to omit; it is the result that decides.
          => not a validated leg. Do not attach on these numbers.
          Purpose = EA-SCORE criterion #7 (live tracking >=2 months) for a fully
          validated XAU edge. Runs at 0.01 lot.
EA:       EA_SUPERTREND.ex5   (bundled here)  MD5 b0885f878e0229e8cd15f9755c041f2d
Source:   EA_SUPERTREND.mq5 (lab EA; PERIOD_CURRENT, no hardcoded TF)
Symbol:   XAUUSD   TF: H4   Magic: 990020   Set: ST_XAUUSD_H4_demo_v1.set
Config:   SuperTrend ATRx3.0 (period 10) + EMA200 filter + ADX>20 gate, SL 2.0xATR,
          both-direction, flat 0.01 lot. AllowLive=true (this EA HAS a live gate).

------------------------------------------------------------------------
WHY DEPLOY (fully validated XAU edge — best single-EA numbers in the lab)
------------------------------------------------------------------------
- Smoke (M2 full): XAU H4 PF 3.32 / 50t / DD 4.8%.
- IS/OOS Model-4 (H4): IS PF 1.54 / 37t / DD 2.23% / Sharpe 1.10 ;
  OOS PF 4.49 / 18t / DD 4.94% / Sharpe 1.75 (OOS > IS = no overfit).
- MC bootstrap (IS+OOS 55t): PF_5th 1.57, DD_95th 3.26%, Ruin 0% = PASS all gates.
- CORRELATION vs the XAU book (LIVE-decision note, NOT a demo gate): 0.724 vs BRK Bars8;
  0.421 vs the deployed BRK Bars40 (ORDER-085). High-ish -> at REAL money size down so it
  doesn't just double XAU trend exposure. On DEMO: run 0.01 to collect the live-tracking data.

------------------------------------------------------------------------
CAVEATS
------------------------------------------------------------------------
- XAU-specific: validated ONLY on XAUUSD. 12 other symbols tested = 0 additive (all DEAD/artifact).
  Do NOT redeploy this EA on other symbols.
- Low trade frequency (H4 trend): ~15-20 trades/yr. A slow live signal — judge over months, not weeks.
- Same H4 chart can coexist with EA_KAUFMAN_ER (990127) — different magics, both fine.

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST
------------------------------------------------------------------------
[S1] LIVE GATE: this EA gates on AllowLive. Bundled .set has _06_AllowLive=true; CONFIRM it
     stuck after load (AllowLive=false => no orders = silent no-trade).
[S2] RECOMPILE RESET: recompiling reverts inputs to compiled defaults -> after any recompile
     re-attach + RELOAD this .set + confirm _06_Magic=990020 + _01_Multiplier=3.0 + AllowLive=true.
[S3] magic 990020 unique (checked vs DEPLOYMENTS.csv). [S4] no vendor lock.
[S5] symbol XAUUSD (match broker suffix, e.g. XAUUSDm). [S6] H4 chart. [S7] closed-bar reads.

------------------------------------------------------------------------
KILL-SWITCH + NEXT
------------------------------------------------------------------------
- Equity DD alert 5%, manual KILL 8% (MC DD_95th was 3.26% — anything past 8% = broken).
  Judge +3 months from attach (target: EA-SCORE criterion 7 satisfied).
- Attach EA_SUPERTREND on XAUUSD H4, load this .set, confirm AllowLive=true + magic 990020.
  Tell Claude the attach date -> register 990020 in DEPLOYMENTS.csv + judge date.
- Evidence: memory signal-landscape (EA_SUPERTREND block), EA_SCORECARD_AND_REGISTRY.md.
