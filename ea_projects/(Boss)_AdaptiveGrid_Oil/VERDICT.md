# AdaptiveGrid_Oil — VERDICT (2026-07-17)

**chain_id:** EA_ADAPTGRID_OIL_20260717_01 · **status:** `PARKED-VERIFY(user)` — buildable, NOT a deploy candidate
**Origin:** independent build of a Facebook post's "Adaptive Grid Trading System" (WTI oil, mean-reversion grid, claimed PF 5x / DD −16% / 2019–2026).

## One-line verdict
The concept builds and runs, and a real mechanism insight fell out of it (add-gating), but **it has no
robust, portable edge**. Oil = spike/hole surface. Cross-market = doesn't transfer + near-ruin DD on
volatile symbols. Per-symbol optimization (Phase 6) surfaced an apparent winner — **AUDNZD showed a
clean Model-2 both-window plateau (PF 3–4, DD 7–14%)** — but the **Model-4 real-tick truth test
demolished it (PF 0.61/0.75)**: it was fill fiction, not edge. Marketed PF 5x not reproducible.

## ⚠️ The most important lesson (Phase 6–8)
**Model 2 (1-min OHLC) can manufacture a PF 3–4 both-window "plateau" on a grid EA that is pure fill
fiction.** AUDNZD d1.0/t1.2 looked like a textbook validated edge on Model 2 (both windows PF 3–4,
DD 7–14%, win 86%, plateau flat in spacing). On Model 4 (99% real ticks, verified) the same config
lost: PF 0.61 (up) / 0.75 (down), maxLoss −138 → −631. **Always confirm grid EAs on Model 4 before
believing any Model-2 result. Tell: largest-loss jumps hard when you switch models.** Credit: the user
forced the per-symbol optimization that surfaced this — without it the concept looked flatly dead on
the WTI-config screen; with it, it looked alive; only real ticks settled it.

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

## Cross-market screen (Phase 5 — config A dynamic, H1, 2021–2026)
Was oil the wrong home? No. The concept fails to transfer AND exposes a structural risk flaw:
| symbol | PF | net | eqDD% | note |
|---|---|---|---|---|
| BTCUSD | 1.00 | +300 | **76** | breakeven, near-ruin DD |
| ETHUSD | 0.34 | −5971 | 64 | dead |
| SOLUSD | 1.90 | +119 | 1.45 | artifact (trivial net, thin data) |
| EURUSD | 1.20 | +1632 | 35 | only mild positive (FX-major = mean-reversion home, per portfolio thesis) |
| GBPUSD | 0.88 | −2109 | 54 | loss |
| USDJPY | 0.67 | −7828 | **92** | near account wipeout |
| AUDUSD | 0.62 | −5282 | 63 | loss |
| XAUUSD | 1.01 | +1494 | **88** | breakeven, near-ruin DD |
| NAS100 | 0.69 | −3284 | 53 | loss |

**🔴 STRUCTURAL FLAW exposed:** DD reached 76–92% despite a 25% circuit breaker, because the breaker
checks on **bar-open (H1)** — on volatile instruments (BTC/XAU/JPY) a fast intra-bar excursion blows a
no-per-order-SL grid past 25% before the next bar closes. Safe-ish only on low-vol oil (~22–33%).
**→ per-order SL is NOT optional on anything volatile; the bar-gated breaker alone is unsafe.**
Only EURUSD transferred mildly positive — the one lead worth a *separate* build-on if pursued, but the
oil-proven fragility (spike/hole) makes a robust EURUSD result unlikely without real work.

## Per-symbol optimization (Phase 6–8 — answering "did you optimize each symbol?")
The cross-market screen (Phase 5) used ONE WTI-tuned config — a screen, not optimization. Proper
per-symbol Dist×TP sweeps then ran:
- **AUDNZD (Model 2):** flat plateau — PF 6.4–8.4 @ tp1.2–1.8 across ALL dist, DD 14%. Both-window
  split also passed (UP PF 3.96 / DN 3.19, DD 7–14%). Looked like a real ranger edge (correct home).
- **AUDNZD (Model 4 real ticks):** COLLAPSES — UP PF 0.61 / DN 0.75, maxLoss −631. Fill fiction.
- **EURUSD (Model 2):** plateau @ tp1.8 (PF ~4.4 full) but both-window split FAILS — DN 2023–26 PF 0.34,
  DD 85% (window-fit, carried entirely by the up-years).
- **Sister rangers both-window (Model 2):** none pass cleanly — AUDCAD UP 0.78/DN 0.22; NZDCAD UP 3.19/
  DN 1.03; EURCHF UP 0.72/DN 5.01 (inverts). And Model 2 flatters grids, so even these overstate.
- **BTCUSD:** PF 1.2–1.3 achievable but DD 73–99% (no-SL grid on crypto) — unsafe, not a home.

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
