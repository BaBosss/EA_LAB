# ORDER-098-B — MacdDiv XAUUSD H4 — Model-4 confirmation (2026-07-18)

**EA:** `ea_projects/(EXP)_MacdDiv_Naked/` (magic 999094) ·
**Set (locked):** `_mt5_auto/ab_sets/order098b/MacdDiv_Naked_XAUUSD_H4_optPF.set`
**Mechanism:** price LL / MACD-main HL (bullish divergence, mirror bearish) · naked flat-lot 0.01 ·
SL = 3-bar extremum · TP = 200% SL. Single-position swing entry (NOT grid) → M4 due because it's a
candidate about to go to a verdict, but low fill-sensitivity expected.

## Model-4 (99% real ticks) ×3 windows

| Window | M4 PF | Trades | Net | maxDD | Model-1 PF (prior) |
|---|---|---|---|---|---|
| MAIN 2023.01–2025.12 | **1.88** | 280 | +1621.21 | 2.76% | 1.91 |
| BWD 2020.01–2022.12 | **0.97** | 240 | −44.39 | 3.91% | 1.04 |
| HOLDOUT 2026H1 | **1.28** | 39 | +356.19 | 5.05% | 1.30 |

Windows chosen to keep 2026H1 holdout pristine vs the Model-1 selection windows (MAIN=23-25, BWD=20-22).

## Read

- **No fill-artifact / no model-switch cliff.** Trade counts identical to Model-1 (280/240/39), PF moved
  ≤0.07 in every window. Real-tick sequencing does NOT flatter this EA → it is genuinely a single-position
  swing entry, not a grid hiding intra-bar fills. This PASSES the Model-4 structural test.
- **MAIN 1.88** (prior plateau, 9 neighbors 1.33–1.90) and **HOLDOUT 1.28** (untouched window) both clear
  their bars (candidate MAIN≥1.2 ✓; holdout≥1.2 ✓ → deploy track).
- **BWD 0.97** — misses the both-window ≥1.0 floor by **0.03** on real ticks (was 1.04 on M1). The 2020-22
  trend/COVID regime is the opposite of this reversion EA's home; "survive not thrive" is the bar, and on
  real ticks it goes breakeven-negative (−44 over 3 yr, DD 3.9%) rather than ≥1.0.

## Verdict (VERDICT GATE)

- STRUCTURAL? No — passes flat-lot (already flat), no M4 cliff, has source, not cracked. **Not a cheap death.**
- Class = **BUILD-ON / marginal-candidate.** Clears MAIN + holdout strongly; misses the both-window BWD
  floor by a hair on real ticks → does **not** clear the clean-DEMO bar as written.
- corr vs gold cohort = **N/A** (DEPLOYMENTS.csv empty; this would be the first gold demo — no live series to correlate).

**Recommendation to user (demo-attach is a user call per brief):** the 0.03 BWD miss is on the stress
window only; MAIN + untouched-holdout are strong and M4 confirms no artifact. Two honest options:
1. **Attach to demo now** as a marginal candidate with a tight pre-registered kill-switch (eqDD>12% ·
   3-mo PF<0.8@≥15t) — demo-forward becomes the real forward-holdout. Justified because demo is reversible
   and the only failing window is the opposite-regime stress window at breakeven, not a loss.
2. **BUILD-ON first** — expand gold-class symbol×TF (XAU other TF / XAG) to find a home that clears BWD≥1.0,
   before spending a demo slot. Slower but keeps the demo bar clean.

Not auto-packed to demo: it misses the stated both-window pass bar, so the attach decision is escalated.
