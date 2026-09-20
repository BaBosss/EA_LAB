# OFPC-01 — Tick Activity

Status: `PROXY_ONLY / ORDER_FREE / SOURCE_ONLY / NO_PERFORMANCE`

- Family/Variant: OFPC / OFPC-01.
- Parent: OFPC-00.
- One change: second breakout bar `tick_volume >= 1.50 * median(previous20 completed M5 tick_volume)`.
- Frozen from parent: two-close breakout, frozen buffer, retest/confirmation windows, cancellation, stop, 2R target, consumer-owned time exit.
- Quote imbalance: not required.
- Claim boundary: MT5 activity proxy, never executed volume or TRUE_ORDERFLOW.
- Orders/fill: none.
- Performance/optimization/HOLDOUT: not run / not authorized.

Full contract: `docs/research/ORDERFLOW_MT5_PROXY_V1.md`.
