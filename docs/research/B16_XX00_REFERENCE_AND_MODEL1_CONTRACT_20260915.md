# B16-00 Kangaroo Owner-Ratified Reference + Fixed Model1 Contract — 2026-09-15

Status: `OWNER_RATIFIED / PREREGISTERED / RESEARCH_ONLY / FIXED_CONFIG / MODEL1_ONLY`
Canonical base: `d1d79e337808a98c01ff8c64c8a7d7c6371e3bca`
Family / logical variant: `B16 / B16-00`
Home: `USDJPY/H1`
Direct consumer: one exact B16-00 Model1 MAIN+BWD evidence package for the next Control Tower research decision.

## Owner-ratified family research reference

The owner explicitly approved the recommended B16 bundle on 2026-09-15. The ratified strategy-reference fields are:
- native mechanics: `ADVERSE_ATR_GRID + KANGAROO_LOT_LAW + OWNED_BASKET_OVERLAP_EXITS`;
- Home: `USDJPY/H1`;
- `_16_Direction=1`;
- RSI `14 / 30 / 70`;
- `_0_ATR_Period=14`, `_0_ATR_TF=PERIOD_CURRENT`;
- `_16_AtrMultFirst4=0.8`, `_16_AtrMultAfter=1.4`, `_16_MinDistPips=150`;
- `_16_LadderMult=1.0`;
- `_16_BasketTpUsdPer01=16`, `_16_OverlapMinUsd=5`, `_16_OverlapMinOrders=4`.

This is research-reference authority only. It does not make these values a DEMO/LIVE/default-risk configuration and does not alter EA source or repository defaults.

## Exact frozen configuration

Execution uses `factory/runs/b16_xx00_model1_control_20260915/B16_XX00_MODEL1_CONTROL.set`, SHA256 `B9CD05F2B728C48E1095FB0EA113486E78EE264AD9D2464B46BC9B889A56F9C9`.
The file is a byte-identical copy of the current canonical `ea_template/sets/regression/Boss_16_KangarooGrid_regression_full.set` at the canonical base. Its B16 strategy values exactly match the owner-ratified bundle above.

All remaining set keys are frozen as `TEST_CONTROL_ONLY` to make the experiment reproducible. They are not newly ratified family semantics or risk/default authority. No terminal-side default may fill an omitted key.
## Source / build identity

Wrapper: `ea_template/Boss_16_KangarooGrid.mq5`, SHA256 `E22F64302EA443C5BEC14C22FBB4787002F1C88742B9CA30D416040AFFE4E8D3` at the canonical base.
Before tester execution, a deterministic compile/build step must bind the exact current source graph, EX5 SHA256, compiler/terminal identity, and build receipt. The compile step may not edit source or config. A build mismatch, warning/error, source drift, or unbound EX5 stops before MT5 evidence.

## Frozen execution matrix

Use MT5 lane3 `D:\Meta 5c`, Model `1 / 1 Minute OHLC` only. Meta5c has no Model4 authority.
Run serially on the same installation lineage:
1. MAIN: `USDJPY/H1`, `2023.01.01..2025.12.31`.
2. BWD: `USDJPY/H1`, `2020.01.01..2022.12.31`.

Both use the same exact EX5 and set, USD 10,000, leverage 1:100, `Optimization=0`, `Forward=0`. HOLDOUT remains `UNSPENT / FORBIDDEN`.
BWD is validation/falsification only and may not select or retune any value.

## Evidence and mechanical acceptance

Each cell must bind exact source/build/EX5/set/config, terminal lane/build, symbol, TF, requested window, model, deposit, leverage and fresh report identity.
Reports must be full-window, parseable and non-truncated. Run year splits and preserve raw report/config/log receipts.
Report PF, net, closed trades, exact equity-DD field/definition, hard-kill events, yearly split, max concurrent positions, realized depth, max aggregate lots, grid span/native normalized span, and the observed lot ladder where derivable. Missing exposure fields remain `UNKNOWN / UNAVAILABLE`.

A stale/reused report, incomplete window, config/source/build mismatch, missing history, unparseable identity, runner failure, or hard mechanical defect is `BLOCKED / MECHANICAL`; it is not strategy failure.

## Prospective interpretation boundary

This experiment confirms the newly ratified B16-00 reference; it is not a blind Home-selection study because USDJPY/H1 was chosen with historical H02 evidence already known.
After both mechanically valid cells exist, report the raw MAIN/BWD evidence and compare only within this exact lane/source/config lineage. Do not invent a new universal PF/sample/Grade threshold. Current canonical verdict/research policy controls any later interpretation.
No result automatically opens optimization, Model4, HOLDOUT, Candidate, DEMO, deployment, runtime or risk/default changes.
## Stop rule / bounded repair

Stop before or during execution if continuing would require source/config/window/model/install changes, BWD-driven retuning, HOLDOUT access, or any risk/default/runtime action.
One bounded mechanical repair is allowed only for runner/parser/report-packaging/environment failure, without changing strategy source, set bytes, Home, windows or model. Rerun only the mechanically affected cell. Repeated failure after that repair closes `BLOCKED / MECHANICAL`; no third attempt or alternate install.

## Authority ceiling

`RESEARCH_ONLY / B16-00 FIXED MODEL1 MAIN+BWD ONLY / NO SOURCE MUTATION / NO CONFIG RETUNING / NO OPTIMIZATION / NO MODEL4 CLAIM / NO HOLDOUT / NO CANDIDATE / NO GRADE-KINT / NO RISK-DEFAULT CHANGE / NO RUNTIME ATTACHMENT / NO DEPLOYMENT / NO TRADING / NO DEMO-LIVE / NO LIVE`.

The next legitimate consumer after accepted evidence is Control Tower triage against existing B16 mechanism/R4 knowledge. Any new child must be a separate prospective one-change contract with its own direct question.