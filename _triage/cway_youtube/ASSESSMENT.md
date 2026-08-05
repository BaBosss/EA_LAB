# CWAY Investment YouTube — relevance assessment for EA_LAB (2026-07-12)

Channel @cwayinvestment · 578 videos · `channel_inventory.csv`. Thai quant/systematic-trading + risk +
macro education (NOT EA-recipe like fxDreema). Keyword buckets undercount (many titles Thai-only).

## Verdict: HIGH relevance — fills EA_LAB's exact known gaps
fxDreema gave EA *recipes* (entry→grid mechanisms). CWAY gives the *rigorous methodology* we lack. Map to lab needs:

| CWAY cluster (titles) | ~N | EA_LAB gap it fills |
|---|---|---|
| **Position Sizing / MM** — Kelly, Optimal-f, Secure-f, Fixed-Fractional/Percent/Dollar/Value | 27+ | Our lot-laws are crude (martingale/linear/log). These are the rigorous foundation. **Directly upgrades ORDER-098-C (MM-parts library).** |
| **Risk / Tail / Drawdown control** — "Trade Sizing for Drawdown & Tail Risk Control", "Rising Above Random", All-Weather | 37+ | **Our #1 unsolved problem**: ST03 crisis-tail is not reactively filterable (EDGE_CATALOG). |
| **Macro / Regime** — Big Debt Crisis, Deleveraging, Economic Machine (Dalio), "Agentic Workflow for FX Market Analysis" | 21+ | EDGE_CATALOG idea-seed #5 says a **leading macro/regime signal is "the only untested angle"** for tail control. This is exactly that. |
| **Dynamic Grid + Bayesian optimization** — "Intro to Dynamic Grid", "AI Agent + Bayesian Opt: Grid Hyperparameters", "AI Agents Evaluate a BTC Grid System" | 52* | Our grid EAs + optimization pipeline (overfit-controlled hyperparameter search). |
| **AI-agent / MQL5 workflow** — "MQL5 Robot Trading AI Agent", quant-system agents | 16+ | Meta: how they drive MQL5 building + backtest-verdict with agents (compare to our pipeline). |

(*Grid bucket inflated by generic "trading system"; true dynamic-grid ≈ the 3 named videos.)

## Recommended first pull (cheapest verifiable, fills a concrete order — NOT blanket 578)
Extraction target here = **methodology notes → apply to our chassis/MM modules**, not EA-cards.
Start with the **Position-Sizing series** (concrete formulas, English-titled, feeds ORDER-098-C):
- Kelly Criterion Position Sizing · Optimal f · Secure f · Fixed Fractional · Fixed Percent · Fixed Dollar/Value
- \+ probes: "5 Minute Paper: Trade Sizing for Drawdown & Tail Risk Control" · "Rising Above Random"
- \+ 1 macro-regime probe: "The Economic Machine" (Dalio) or "Agentic Workflow for FX Market Analysis"

~10 clips → transcribe (th) → extract formula/parameter/caveat notes → fold into ORDER-098-C MM library
+ open a new idea-seed for macro-regime tail filter (the untested angle).

## Do NOT
Blanket-transcribe 578 (concept-heavy, low per-video buildable-mechanism density vs fxDreema). Catalog from
titles first (done), transcribe only what the user points at (corpus-intake rule for concept channels).
