# OFPR-01 — Tick Activity

Status: `PROXY_ONLY / ORDER_FREE / SOURCE_ONLY / NO_PERFORMANCE`

- Family/Variant: OFPR / OFPR-01.
- Parent: OFPR-00.
- One change: test-bar `tick_volume >= 1.50 * median(previous20 completed M5 tick_volume)`.
- Frozen from parent: profile/location, wick `>=0.40`, next-three trigger, cancellation, `0.20*ATR` buffer, proxy-POC target, net RR `>=1.50`.
- Quote imbalance: not required.
- Claim boundary: MT5 activity proxy, never executed volume or TRUE_ORDERFLOW.
- Orders/fill/time exit: none.
- Performance/optimization/HOLDOUT: not run / not authorized.

Full contract: `docs/research/ORDERFLOW_MT5_PROXY_V1.md`.
