# Execution Timing and Benchmark Liquidity

> RESEARCH_ONLY. This note does not change EA_LAB execution, broker, runtime, deployment or risk policy.

## SOURCE_CLAIM — finite execution opportunity

`RC-SSRN1843305-001` studies a stylized continuous double auction with a finite opportunity to transact. Its computed equilibrium schedules become more aggressive as the session progresses, reflecting a trade-off between execution probability and price concession.

The result comes from a simplified simulation model with unit orders, no intra-session cancel/resubmit, random arrival and limited information structure. It is not an MT5 execution prescription.

## SOURCE_CLAIM — benchmark-linked liquidity

`RC-SSRN3375564-001` models traders around a benchmark-setting interval, motivated by the FX 4pm London fix. The model predicts concentrated order flow and lower price impact at benchmark time, plus temporary price movement and rebound that can arise without manipulation.

The result is benchmark- and model-specific. It does not imply a portable trading edge or justify frontrunning.

## EA_LAB_INFERENCE

Entry alpha and execution quality should be evaluated as separate layers. A future bounded execution study may measure time-to-deadline, spread, slippage, fill probability and known event/session windows before deciding whether execution aggressiveness should vary.

No production rule is derived from these papers. Runtime scheduling, order-type behavior and execution defaults remain governed by existing EA_LAB authority and hard stops.