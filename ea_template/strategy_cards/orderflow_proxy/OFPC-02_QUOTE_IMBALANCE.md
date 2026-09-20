# OFPC-02 — Quote Imbalance

Status: `PROXY_ONLY / ORDER_FREE / SOURCE_ONLY / NO_PERFORMANCE`

- Family/Variant: OFPC / OFPC-02.
- Parent: OFPC-01.
- One change: second-breakout `QUOTE_DIRECTION_IMBALANCE_PROXY` long `>=+0.20` / short `<=-0.20`, plus confirmation strictly `>0` long / `<0` short; zero move denominator refuses.
- Frozen from parent: relative activity, breakout/retest/confirmation chronology, buffer, cancellation, stop, 2R target, consumer-owned time exit.
- Claim boundary: quote-direction movement proxy, never Delta or TRUE_ORDERFLOW.
- Orders/fill: none.
- Performance/optimization/HOLDOUT: not run / not authorized.

Full contract: `docs/research/ORDERFLOW_MT5_PROXY_V1.md`.
