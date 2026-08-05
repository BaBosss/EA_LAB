# Lane C — SMC×STO (EmaStoRev) EURUSD H1 — sensitivity fan VERDICT (2026-07-18)

**EA:** `(EXP)_EmaStoRev` (magic 991070) · center = StoK13/OS30/AdxMax30/EMA50/SL3.0/TP1.0 (demo set
`_vps_deploy/SMCSTO_EURUSD/SMCSTO_EURUSD_H1_demo_v1.set`, already staged bundle-10 ACTIVE).
**Method:** ±20% single-axis fan, 6 axes, Model-4 both-window (MAIN 2023-25 / BWD 2020-22), 26 runs.

## Result = EDGE-POSITIVE but SENSITIVITY-FRAGILE on SL (WEAK candidate — flag, don't clean-pass)

**Center: MAIN 1.39 / BWD 1.19** (n 136/130) — both-window >1 ✓ (slightly under the catalog 1.50/1.24;
demo set OverBought=80 vs catalog config — same ballpark).

| axis ±20% | MAIN / BWD | read |
|---|---|---|
| EmaPeriod 40 / 60 | 1.55/1.11 · 1.23/1.12 | robust (>1 both) |
| OverSold 24 / 36 | 1.24/1.47 · 1.14/1.22 | robust |
| StoK 10 / 16 | 1.12/1.09 · 1.18/1.37 | robust |
| TpAtrMult 0.8 / 1.2 | 1.21/1.04 · 1.42/1.16 | robust |
| AdxMax 24 / 36 | 1.09/**0.91** · 1.29/1.11 | soft: AdxMax−20% → BWD 0.91 (one-window flip) |
| **SlAtrMult 2.4 / 3.6** | **0.94/0.99** · 1.35/1.10 | **FRAGILE: SL−20% flips to loss BOTH windows** |

## Verdict (VERDICT GATE / sensitivity-fan bar)
- Bar = "most variants hold ≥70% baseline AND none flips to PF<1 either window; any axis dropping <1
  both-window = fragile → NOT clean demo." **SL axis fails** (0.94/0.99 both-window at −20%). AdxMax soft.
- 5 of 6 axes robust; the edge is real at center. But the center is **not a plateau on the SL dimension** —
  it sits just above a both-window cliff. Cannot re-center to wider SL (SL3.6 looks healthier) — that would be
  moving to a sweeter zone after seeing the fan (anti-overfit invariant). SL=3.0 stays the selected value.

## Recommendation = DEMO-KEEP with SL-fragility flag (NOT a clean robust pass)
The deployed config sits at SL=3.0 = the **safe side** of the cliff (currently PF>1 both-window), so it is not
broken — but it has no downside margin on SL. Keep on demo (reversible; demo-forward = the real judge) **with**:
1. **Lock SL ≥ 3.0×ATR — never tighten.** A recompile-reset or hand-tweak below 3.0 flips it to a loss.
2. Pre-registered demo kill: eqDD>12% · 3-mo PF<0.8@≥15t (bundle-10 default) — unchanged.
3. Treat as a WEAK candidate, not the robust plateau the pre-fan note implied. If it underperforms on demo,
   the SL-cliff is the prime suspect.

Escalated to user: keep on demo with the flag, or pull from bundle-10 pending a wider-SL rebuild? (Rebuild =
re-select SL on a fresh window, not re-center on this fan.)
