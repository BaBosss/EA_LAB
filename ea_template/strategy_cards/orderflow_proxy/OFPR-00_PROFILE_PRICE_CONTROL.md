# OFPR-00 — Profile Price Control

Status: `PROXY_ONLY / ORDER_FREE / SOURCE_ONLY / NO_PERFORMANCE`

- Family/Variant: OFPR / OFPR-00.
- Parent: base/reference.
- Change: establishes reversal location, wick, trigger, cancellation, stop, proxy-POC target, and net-RR geometry without event-bar activity or imbalance.
- Context/Profile: completed M15 inside prior completed broker-D1 `TICK_ACTIVITY_PROFILE`; never executed-volume profile.
- Trigger: rejection test at VAL/VAH, wick ratio `>=0.40`, next-three completed-M5 close beyond test extreme.
- Risk geometry: `0.20*ATR(14)` frozen buffer; net RR to proxy POC `>=1.50`; prospective quote is not a fill.
- Activity/imbalance gates: none.
- Orders/fill/time exit: none.
- Performance/optimization/HOLDOUT: not run / not authorized.

Full contract: `docs/research/ORDERFLOW_MT5_PROXY_V1.md`.
