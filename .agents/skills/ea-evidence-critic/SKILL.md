---
name: ea-evidence-critic
description: Critique the strength, limitations, and EA_LAB transferability of trading research without turning research claims into verdicts.
---

# EA Evidence Critic

Review a research card or source for:

- sample size, period, market, timeframe, and regime coverage;
- in-sample vs out-of-sample separation and walk-forward design;
- multiple testing / selection bias / overfitting;
- look-ahead, survivorship, leakage, and benchmark issues;
- transaction costs, spread, slippage, swap/funding, liquidity, and execution assumptions;
- parameter sensitivity and whether reported statistics are sufficient for the claim;
- transfer mismatch between the studied asset/venue and EA_LAB target symbol/timeframe;
- source-stated limitations and evidence that contradicts the claim.

Return `SUPPORTED`, `WEAKLY_SUPPORTED`, `CONFLICTED`, or `INSUFFICIENT_SOURCE` only as a **research-evidence assessment**, never as an EA/Factory verdict. State why and cite `source_id`.

Hard boundary: RESEARCH_ONLY. Do not modify QI verdicts/results, Factory policy, runtime, risk, deployment, or QI-2+.