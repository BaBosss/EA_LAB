# OFPC-00 — Profile Price Control

Status: `PROXY_ONLY / ORDER_FREE / SOURCE_ONLY / NO_PERFORMANCE`

- Family/Variant: OFPC / OFPC-00.
- Parent: base/reference.
- Change: establishes two-close breakout, six-bar retest, three-bar confirmation, cancellation, structural stop, and 2R geometry without activity or imbalance gates.
- Context/Profile: completed M15 beyond prior completed broker-D1 `TICK_ACTIVITY_PROFILE`; never executed-volume profile.
- Buffer: frozen `0.20*ATR(14)` at first breakout close.
- Time exit: proposed 12 M5 bars after actual fill remains consumer-owned and unimplemented.
- Orders/fill: none; prospective quote is not a fill.
- Performance/optimization/HOLDOUT: not run / not authorized.

Full contract: `docs/research/ORDERFLOW_MT5_PROXY_V1.md`.
