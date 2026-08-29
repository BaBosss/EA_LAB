# Boss11-16 H02 Literal Portability Contract

`FACTORY-B11-16-H02-LITERAL-PORTABILITY-PREREGISTRATION:`

Status: OWNER-APPROVED / PROSPECTIVE / FIXED-CONFIG / RESEARCH SCREEN ONLY.
Canonical base: `d8b5a62871b4f488ec1713ef774cb69ee17c475e`.
Direct consumer: deterministic cross-symbol/cross-timeframe evidence for B11/B12/B13/B15/B16 after H01.

## Frozen hypothesis
H02 asks only whether each accepted H01 effective configuration shows literal portability when moved unchanged across a bounded market/timeframe matrix. No parameter may be retuned, normalized, rescaled, optimized, or selected from results.

Boss revisions: `B11-H01-r1`, `B12-H01-r1`, `B13-H01-r1`, `B15-H01-r1`, `B16-H01-r1`.
Symbols: `XAUUSD`, `EURUSD`, `GBPUSD`, `USDJPY`.
Timeframes: `M15`, `H1`, `H4`.
MAIN: `2023.01.01` through `2025.12.31`.
BWD: `2020.01.01` through `2022.12.31`.
Tester model: `1`; deposit: `10000`; leverage: `100`.

## Fixed-config rule
B11/B12/B13/B15 use the exact accepted H01 proposed set bytes. B16 uses the accepted FULL 173/173 tester materialization whose 135 H01 overlay assignments matched 135/135 with zero mismatch. Raw point/pip distances remain literal; no symbol-specific adjustment is allowed in H02.

The already accepted XAUUSD/H1 H01 cells are reused, not rerun, so the 120-cell matrix requires 110 new Strategy Tester runs.

## Authority ceiling
Optimization `NONE`; TUNABLE authority `NONE`; HOLDOUT 2026H1 `UNSPENT`; no candidate ranking/promotion; no DEMO/LIVE attach; no deployment/trading; no risk/default changes. A row may be marked only mechanical PASS/FAIL plus raw metrics. Any redesign, normalization, optimization, or semantic interpretation that changes the strategy is a separate later hypothesis.
