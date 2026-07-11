# WOBR Bot Ranking — corpus intake triage (2026-07-10)

Source: `wobr.ai/bot-ranking` (= Jobotinvest/BotMogul rebrand, fxDreema lineage).
Pulled anon (public marketplace preview) from Supabase project `zdxrypcglsoaizoqinoz`:
- `wbr_bot_list_ranked` (Best-per-EA, distinct) → **2,532 rows** → `WOBR_botranking_bestperEA.csv/json`
- `Expert_Advisor` (name/realm/developer/credit_price) → **12,481 rows** → `WOBR_ea_catalog.json`
- Enriched sane cohort → `WOBR_sane_cohort_enriched.csv`

## Headline verdict: near-zero direct edge, mechanism = our own known lineage

### 1. The ranking is adverse-selected for overfit — do NOT trust it
Ranking key `new_total_ai` ("AI Score") is computed FROM the backtest → ranking top = most
curve-fit/hidden-DD looking. Whole-list stats prove it:
- **profit_factor**: median **5.95**, p90 **105.9**, max **106,951** (absurd — martingale/grid no-SL or curve-fit)
- **trades**: median **17**; **59% of presets have <30 trades** (statistically meaningless)
- **max_dd**: 439 presets show <2% DD next to triple-digit % profit = grid DD illusion
- Symbol families incl. Thai stocks (CCET/TRUE/KTC/CPALL/SAWAD) + US stocks (MSFT/AAPL/TSLA), not just FX

**No forward/live column exists per-preset.** The homepage "Alpha Survival Index" (forward survival)
is an aggregate marketing number — NOT exposed here. The moat we hoped to harvest is not in the data.

### 2. The only sane slice (158/2,532 = 6%) IS our existing anti-edge/known lineage
Filter: FX/metal · trades≥100 · PF 1.2–3.0 · DD 3–35%. Names reveal the mechanisms:
- **BB + RSI + "Log Lot" + "Pyramid" + "Adaptive Trail"** (62/158 have RSI) = the **exact fxDreema
  linear-add reversion grid** we already reverse-engineered (memory: `rsi-from-pips-mechanism`) and
  whose ceiling EDGE_CATALOG already documents ("naked BB+RSI on FX majors → structural ceiling ~PF 1.1").
  The PF 2–3 here is single-window in-sample (several share identical days=263 = same EA re-parametrized).
- **MARTINGATE_ATR / _ADX** (XAU) = uncapped martingale = EDGE_CATALOG's "martingale WAS the edge" pile.
- **SCALPION / TRENDRA / HEDGATRON** = BotMogul branded families, priced 39,599 cr.
- Symbols suffixed with date ranges ("XAUUSDm0104202512042026") = backtest optimized ON that window = in-sample fit.

### 3. Buying is blocked anyway
Cheapest preset = **19,599 credits** (fxDreema/Others); branded = 39,599. **We hold 5,634.**
No purchase is affordable, so there is no buy decision to make on this balance.

## What actually comes out of this (zero spend)
- **Confirmation, not new edge:** the marketplace top is precisely the mirage our VERDICT GATE +
  EDGE_CATALOG already reject (backtest-ranked, no-SL grid/martingale, <30-trade noise). Reinforces
  the "backtest = claim, forward = proof" discipline. Reinforces existing signal-landscape cells.
- **Two buildable NEVER-TOUCHED leads** (public mechanisms, no purchase needed):
  1. **Ichimoku + ADX trend** on EURUSD/USDJPY H1 (24 presets) — this CONTRADICTS our thesis
     (FX majors = reversion). Cheap single smoke would test whether it's a rare FX trend-edge or
     (expected) overfit that dies OOS/BWD. Good thesis-falsification probe.
  2. **Alligator + AO (Bill Williams)** on EUR/GBP H1 — untried lens in our lab, spec-able ourselves.
- **No attach-ready EA files** obtained (only .set-level metrics; EA files gated behind unaffordable price).

## Recommendation
Bank the confirmation + the two mechanism leads. Do NOT spend credits here. If we want to act,
build the Ichimoku+ADX FX-H1 probe ourselves (strategy-and-risk → mql-code-generator) as a cheap
thesis test — not as a marketplace purchase.

## FOLLOW-UP DONE (2026-07-11): built + smoked the Ichimoku+ADX probe → thesis HOLDS
Built `ea_projects\(EXP)_IchiADX_Naked\` (naked TK-cross + Kumo + ADX(14), ATR trail, magic 999092,
compiled 0/0). Naked smoke M2 2023-2026 H1:
- **EURUSD PF 0.99 (280t) · GBPUSD PF 0.88 (253t) = DEAD outright.**
- **USDJPY full PF 1.25 (226t) but IS(2023-2025.06) 1.13/195t below gate**; the life is a 31-trade
  OOS tail (PF 2.66) = small-sample noise. Matches 4× documented "USDJPY trend = regime artifact."
Conclusion: the marketplace's Ichimoku+ADX PF 2-3 presets are in-sample curve-fits — the mechanism has
no durable naked edge on FX majors. **Thesis (momentum>reversion, FX majors = reversion) CONFIRMED, not
refuted.** Recorded in signal-landscape.
- USDJPY IchiADX PARKED → **DEAD-optimized** (ORDER-096B): 5-pass IS probe ceiling PF 1.14, higher ADX worse.
- **Lead 2 Alligator+AO** (ORDER-096A, `ea_projects\(EXP)_AlligatorAO_Naked\`): GBPUSD dead (0.67/0.47);
  EURUSD H1 1.37/25t + XAUUSD H1 1.39/26t = small-sample below freq floor (conjunction fires ~25×/3yr),
  not a PROCEED. **Both hand-built leads DEAD → WOBR marketplace intake fully closed. Net spend: 0 credits.**
