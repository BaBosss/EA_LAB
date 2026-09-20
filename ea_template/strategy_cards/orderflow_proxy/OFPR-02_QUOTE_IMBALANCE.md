# OFPR-02 — Quote Imbalance

Status: `PROXY_ONLY / ORDER_FREE / SOURCE_ONLY / NO_PERFORMANCE`

- Family/Variant: OFPR / OFPR-02.
- Parent: OFPR-01.
- One change: test-bar `QUOTE_DIRECTION_IMBALANCE_PROXY`; long `<=-0.20`, short `>=+0.20`; zero move denominator refuses.
- Frozen from parent: relative M5 tick activity, profile/location, wick, next-three trigger, cancellation, buffer, proxy-POC target, net RR.
- Claim boundary: quote-direction movement proxy, never Delta or TRUE_ORDERFLOW.
- Orders/fill/time exit: none.
- Performance/optimization/HOLDOUT: not run / not authorized.

Full contract: `docs/research/ORDERFLOW_MT5_PROXY_V1.md`.
