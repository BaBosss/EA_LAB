# AdaptiveGrid_Oil — VERDICT (2026-07-17)

**chain_id:** EA_ADAPTGRID_OIL_20260717_01 · **status:** `PARKED-VERIFY(user)` — buildable, NOT a deploy candidate
**Origin:** independent build of a Facebook post's "Adaptive Grid Trading System" (WTI oil, mean-reversion grid, claimed PF 5x / DD −16% / 2019–2026).

## One-line verdict
The concept builds and runs, and a real mechanism insight fell out of it (add-gating), but **it has no
robust, portable edge**: fixed-direction P&L is just window drift-capture, the spacing×TP surface is
spike/hole (no plateau), and no single config survives across symbol **and** timeframe. The marketed
PF 5x is not reproducible — it was almost certainly short-only curve-fit to oil's down years.

## VERDICT GATE block (all filled)
1. **Levers swept:** entry-threshold (SlopeThresh ×5) · filter-mode (permissive/agree) · gate-adds (on/off) ·
   dir-mode (fixed/dynamic) · filter-speed (EMA 50/100/200 × LR 20/40) · **spacing DistAtrMult ×4** ·
   **TP BasketTpAtrMult ×3**. Held by design: lot-law (FIXED = L3), exit-mode (VWAP basket), per-order SL
   (optional, off). → far exceeds the ≥3-lever minimum.
2. **Coarse→surface:** spacing×TP surface is **spike/hole, NOT a plateau** — one-step lever moves flip
   +4048 → −113 → +3545 → −7448. Best cells (PF 2.62 @ d1.5/t0.7, PF 3.12 @ d2/t1) sit next to losers → overfit spikes, not selectable.
3. **Both regimes:** tested UP (2019–22) + DN (2023–26) + FULL (2019–26) continuous. Fixed direction inverts
   across windows; dynamic is +PF1.38 full-span but whipsaws (DN2326 alone −1216).
4. **REJECT type:** **PARAMETRIC / fragility**, not structural. NOT killed — PF>1 exists in places, so per
   BUILD-ON≠DEPLOY it is preserved as buildable and handed to the user (they may have oil-grid hand-experience).
5. **Martingale check:** N/A — FIXED lot, no escalation (L3 clean).
6. **Deploy gate:** **FAILS** — no plateau to select; cross-symbol/TF collapse (below). Holdout+MC not run
   because running MC on an overfit spike would be theatre (gate: in-sample spike ≠ eligible).

## Key evidence
**Direction = drift capture (rev01, WTI H1, Model 2):**
| window | oil | BUY | SELL |
|---|---|---|---|
| 2019–22 up | | PF 1.10 | PF 0.53 |
| 2023–26 down | | PF 0.59 | PF 3.17 |

**Trend filter was inert (rev01):** it gated only the SEED, but a grid is almost never flat → SlopeThresh
had ~0 effect (SELL/UP bled ~−4150 at every threshold 0.01–0.15).

**Add-gating fix (rev02, FilterMode=AGREE + GateAdds) — the one genuine win:**
| cell | rev01 | rev02 AGREE+GateAdds |
|---|---|---|
| BUY/UP | PF 1.2, DD 40%, maxLoss −312 | **PF 1.96, DD 20.7%, maxLoss −92** |
| BUY/UP (thr0.10) | — | **PF 2.09, DD 11.3%** |

**Dynamic single-instance (rev03):** FULL 2019–26 PF 1.38 / +1631 / DD 22% — real but modest, whipsaws on
counter-trend pullbacks.

**Spacing×TP surface (rev03 dynamic, FULL 2019–26):** spike/hole, no plateau (see table in §2).

**Cross-TF/symbol robustness (the decisive fragility test):**
| config | WTI H1 | WTI H4 | BRENT H1 | BRENT H4 |
|---|---|---|---|---|
| A (dist1.0/tp1.0) | PF 1.38 | PF 1.38 | **0.59** | **0.35** |
| B (dist1.0/tp1.5) | PF 1.59 | **0.38** | PF 1.37 | **0.35** |

No config is portable across symbol **and** timeframe → the positive cells are noise, not edge.

## Reusable insight (→ EDGE_CATALOG)
**Add-gating a grid** (stop adding legs once the trend has turned against the basket) structurally
cuts counter-trend bleed: with-trend DD 40%→11–20%, maxLoss −312→−92. The rev01 lesson — **gating only
the first seed is useless for a grid, because a grid is almost never flat; you must gate the ADDS.**

## Deliverables
- `(Boss)_AdaptiveGrid_Oil_rev03.mq5` (.ex5) — dynamic-direction, all levers as inputs, L3 caps + circuit breaker. Compiles 0/0.
- rev01/rev02 kept for lineage. Sweep CSVs in `reports/phase{1,2,3,3b,4}_*.csv`.

## If the user wants to pursue anyway (build-on branch)
- Only WTI H1/H4 config A held; treat as WTI-specific, hand-verify before any demo.
- Untested levers that *might* help: pending-limit seeding (save spread), per-order SL variant (`_06_UsePerOrderSl=true`),
  a non-slope regime detector (slope filter proved inert/whipsawy; ADX or Donchian regime might gate cleaner).
- Do NOT select the PF 2.6–3.1 spikes — they are overfit holes.
