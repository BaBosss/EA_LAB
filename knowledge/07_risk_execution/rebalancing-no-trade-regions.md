---
card_type: PORTFOLIO_NOTE
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---
# Rebalancing can be threshold-based instead of continuously exact
`RC-SSRN4714721-001` frames portfolio rebalancing as a trade-off between tracking error and adjustment cost. With frictions, the optimal target can become a **no-trade region** rather than a point that must be restored after every price move.

## Second Brain implication
For future portfolio orchestration, represent rebalancing hypotheses with:
- target allocation or risk objective;
- acceptable deviation band;
- transaction/monitoring cost model;
- regime assumption, especially whether relative moves are expected to mean-revert;
- explicit rebalance trigger and refusal conditions.

This is portfolio research only. It does not alter current EA sizing, account risk, deployment or LIVE behavior.