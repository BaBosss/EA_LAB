# (BRK)_ConfluenceMartATR_rev01 — Verdict (2026-07-08)

User request 2026-07-08: combine Donchian + trendline(triangle) breakout as confluence, add pullback
entry, add martingale x ATR recovery ("DD only 3%, has headroom"), and measure max recovery days.
Built all four (L4 risk, user-accepted, hard caps). Compiled 0/0, review-clean (hedging guard + caps).

## The trap this hit (and the gate caught)
| config (confluence, no-pullback) | BWD 2020-22 | FWD 2025-26 | **HOLDOUT 2023-24** | max recovery |
|---|---|---|---|---|
| MartMult 1.3 | 4.61 | 6.48 | **0.19 (DD 24%)** | **59 days** |
| MartMult 1.6 | 4.04 | 5.13 | **0.22 (DD 29%)** | 21 days |

The two SELECTION windows looked spectacular (PF 4-6, DD 1-4.6%). The untouched HOLDOUT collapsed to
PF 0.19-0.22, DD 24-29%, with a basket stuck underwater 59 days. Classic **thin-sample martingale
overfit**: ~30 trades/window + martingale = a handful of lucky recoveries inflate PF; on new data the
martingale digs a deep hole and loses. The clean breakout ran 3% DD — adding martingale turned that
into 24-29% DD the moment the regime didn't cooperate.

## Findings worth keeping
1. **Confluence (Donchian AND trendline) is load-bearing** — Donchian-only + martingale = DD 15-75%
   blowup; the confluence gate is what made entries rare/clean. (Real, but not enough — see below.)
2. **Pullback HURTS here** — no-pullback FWD 6.48 vs pullback 2.06. Immediate entry on confluence beat
   waiting for a retrace.
3. **Martingale + breakout is a mechanism mismatch** — martingale assumes mean-reversion, breakout
   assumes continuation. When they align it's lucky; the holdout shows it doesn't generalize.
4. **Recovery-duration tool** (`scripts/max_recovery_days.py`) — answers "how long underwater until
   TP": clean=14d max, martingale-holdout=59d. Reusable for any basket EA. This IS the martingale tail.

## UPDATE 2026-07-08 — tried ALL lot laws (user: linear/fix/log + optimize ATR, coarse->fine)
Added selectable lot law (FIXED/LINEAR/MARTINGALE/LOG). Coarse LotMode x AddAtrMult, then fine ATR
grid across 3 windows, then full-span + MC. Findings:
- FIXED-lot recovery looked FAR better than martingale on the 3 separate windows: FIXED atr1.0 gave
  BWD 7.17 / HOLDOUT 3.97 / FWD 7.64 (DD 1-3.5%). LINEAR/LOG similar. Holdout surface noisy though
  (0.8/1.0/2.0/2.5 pass; 1.2/1.5/3.0 fail = holes).
- **BUT the honest full-CONTINUOUS-span (2020-2026, one run) = PF 0.583, DD 16.5%, net -$627, MC
  PF-5th 0.32, OOS 0.27, max recovery 73 days.** The strong windowed numbers were a BOUNDARY ARTIFACT.

## 🔑 METHODOLOGY LESSON (the real deliverable here)
**For a BASKET / recovery EA, stitched-window backtests LIE.** A basket that stays open 73 days spans
window boundaries; running 3 separate windows truncates those lifecycles AND resets equity to $10k each
window so the cumulative drawdown + emergency-DD dynamics never compound. The deployment-realistic
measure is ONE continuous span (live trading never resets). Windowed said PF 4-7; continuous said 0.58.
=> Basket/grid/martingale EAs must be validated on a single continuous span + MC on that span, NOT
tiled windows. (Single-position EAs like BRK-XAU are immune — no cross-boundary baskets.)

## VERDICT: NOT VIABLE — do not demo, do not tune further
Martingale on a thin-sample breakout is overfit-prone by construction; the holdout proved it. The
"DD 3% headroom" reasoning is invalidated: that DD belonged to the clean single-position breakout, not
to the martingale version. Keep BRK-XAU (clean L1, PF-5th 1.53) as the gold-breakout demo; this L4
variant is a documented negative result. Demo cohort stays 6.
