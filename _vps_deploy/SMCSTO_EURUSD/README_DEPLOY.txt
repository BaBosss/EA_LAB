========================================================================
ORDER-107 SMC×STO (EmaStoRev) — DEMO DEPLOY BUNDLE — EURUSD H1
========================================================================
Status:   DEMO-ELIGIBLE (lead PASS 2026-07-16). NOT live-certified. EURUSD-SPECIFIC.
EA:       EmaStoRev.ex5  (HTF-EMA-gated + ADX-filtered Stochastic reversion; the cheap-core of
          the user's SMC×STO idea — OB zone NOT included, not needed to clear the bar)
Source:   D:\EA_LAB\ea_projects\(EXP)_EmaStoRev\(EXP)_EmaStoRev.mq5
Build:    ex5 2026-07-16, MD5 E7B8FA1B9ED99BEE1B8DD48292700A45
Symbol:   EURUSD   TF: H1   Magic: 991070   Set: SMCSTO_EURUSD_H1_demo_v1.set

Config (optimized + plateau-confirmed): EMA50 dir-gate · STO(13,3,3) OS30/OB80 · ADX(14) filter max 30
  (skip entries when trend too strong) · SL 3×ATR · TP 1×ATR · STO-reverse exit + BE at STO50.

------------------------------------------------------------------------
WHY DEPLOY (full funnel cleared — EURUSD only)
------------------------------------------------------------------------
- Plateau (Model-1 both-window): 6/7 one-param neighbors hold both windows (StoK17 1.33/1.34, OS25
  1.29/1.26, OS35 1.23/1.19, AdxMax35 1.43/1.14, SL2.5 1.30/1.12, AdxMax25 1.28/1.01). Real plateau.
- Model-4 real ticks (center): MAIN 1.39 / BWD 1.19 / HOLDOUT 2026H1 1.14 — all 3 windows > 1.0,
  edge survives real ticks (not an STO fill artifact). Win% 71-80% (low-RR high-win reversion). DD tiny.
- NOT portfolio-general: the edge is EURUSD-specific — it does NOT travel (AUDNZD/EURGBP/XAU fail BWD
  even after fresh optimize). Deploy on EURUSD ONLY.
- Modest edge (PF 1.14-1.39) but robust across MAIN/BWD/holdout/Model-4 with a real plateau.

------------------------------------------------------------------------
SILENT-STOP PRE-ATTACH CHECKLIST
------------------------------------------------------------------------
[S1] TESTER-GATE: real — `allow = _06_AllowLive || MQL_TESTER`. Bundled .set has AllowLive=true;
     CONFIRM it stuck after load (else green EA, zero trades).
[S2] RECOMPILE RESET: recompiling reverts inputs to compiled defaults (AllowLive=false, ADX off,
     STO 5,3,3). After any recompile re-attach quiet + RELOAD this .set.
[S3] LOT/MIN: fixed 0.01. [S4] no vendor lock. [S5] magic 991070 unique. [S6] EURUSD symbol string.
[S7] Bar/indicator: entry on closed H1 bars; ADX/STO/EMA read shift 1 — no repaint.

------------------------------------------------------------------------
NEXT STEP (user)
------------------------------------------------------------------------
corr vs cohort = informational (user: it's a demo experiment). Attach EmaStoRev on EURUSD H1, load
SMCSTO_EURUSD_H1_demo_v1.set, confirm AllowLive=true + magic 991070 + first trade fires. Tell Claude
the attach date -> register in DEPLOYMENTS.csv + judge +3 months.
Provenance: this candidate was nearly killed on a default-param smoke; the user's push (optimize STO
K5->13, add ADX filter) revived it. Full arc: _triage/ORDER107_SMCxSTO_STAGE0_VERDICT.md
========================================================================
