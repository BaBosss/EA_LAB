# Boss Recovered Port Prep + Streaming Backtest Queue — 2026-09-15

Canonical integration head: `e943c05fb4c01a3e2611df02eadffa0958d40c02`  
Authority ceiling: `PORT_PREP_ONLY / NO CODEGEN / NO MT5 / NO FAMILY ALLOCATION`

## Queue state
- `READY_FOR_MT5`: **NONE**. Every recovered family still has `mt5_ready=false`.
- 8 source-complete candidates need an explicit owner parent-revision freeze plus FamilyID/LAB_ENTRY allocation and compile/regression/review before implementation: **DF02, DF03, DF07, DF15, DF16, DF18, DF19, DF20**.
- 2 candidates require semantics/lineage prep before even that owner freeze: **DF08, DF12**.
- 10 families remain historical-closed/reject or explicit-reopen-only and must not enter the queue implicitly: **DF01, DF04, DF05, DF06, DF09, DF10, DF11, DF13, DF14, DF17**.

## Recommended first owner-freeze target
**DF02 — Gold Robot Scalping Time Bomb** is the lowest-friction documentation candidate: high-confidence MQ5 source, only 2 recovered source files, no historical closure marker, and only the standard three blockers. This is a workflow recommendation, **not** a performance ranking or parent freeze.

| ID | Family | Parent candidate | Approach | Blockers |
|---|---|---|---|---:|
| DF01 | Dynamic RSI / Highest-Lowest RSI | `(Boss) Dynamic  break and SW RSI rev 4.mq5` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 4 |
| DF02 | Gold Robot Scalping Time Bomb | `(Boss) Gold Robot Scalping Time Bomb rev1.mq5` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 3 |
| DF03 | Grid Horizontal Line / Fibonacci | `(Boss) Grid Horizontal Line Trailing by Fibo rev 4(Config lot ,TF , Hedging).mq5` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 3 |
| DF04 | Hedging Balance | `(Boss) Hedging Balance (XauM1 30,000) rev 1.mq5` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 4 |
| DF05 | Infinix | `(Boss) Infinix EA.mq5` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 3 |
| DF06 | PSAR Follow Trend | `(Boss) PSAR follow trend rev 1.2 lot plus .mq5` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 4 |
| DF07 | Price Action + Trendline + Fibonacci | `(BOSS) Price Action - Trend Line -Fibo-Advance MM .mq5` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 3 |
| DF08 | Price Action + Martingale + TMA | `(Boss)Trend ema+adx V6.15 mt4 atr nearby.mq5` | `SPLIT_SOURCE_LINEAGES_BEFORE_IMPLEMENTATION` | 4 |
| DF09 | RSI OBOS / RSI-BB | `(Boss)RSI_BB rev 3.1 (complete).mq5` | `COMPARE_EXISTING_ENTRY_FIRST_THEN_NATIVE_ENGINE_OR_CHILD` | 5 |
| DF10 | RSI Scalping Gold Low Spread | `RSI Scalping  Gold Low Spread Ver 1.5.mq5` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 3 |
| DF11 | Redbull Racing / Redbull Following | `(Boss) Redbull Racing add hedging lot_rev4.3_add lot hedging multi_fix_bug.mq5` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 4 |
| DF12 | Grow Up | `(Boss) grow up rev 1.44 dynamic lot with hedging.mq5` | `SEMANTICS_FIRST_NO_CODEGEN` | 4 |
| DF13 | Supermax | `(Boss) Supermax .mq5` | `SEMANTICS_FIRST_NO_CODEGEN` | 4 |
| DF14 | Trend EMA + ADX | `(Boss)Trend ema+adx V6.41 mt4 dynamic atr TP MM.mq5` | `COMPARE_EXISTING_ENTRY_FIRST_THEN_NATIVE_ENGINE_OR_CHILD` | 5 |
| DF15 | EA No-Way / Two-Way Grid | `EA  NO WAY  3.2 lot plus.mq4` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 3 |
| DF16 | Gold Time Bomb Martingale ATR | `(Boss) Gold Time bomb martingale rev 1 with ATR.mq4` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 3 |
| DF17 | Gold Trading Reversion | `(Boss) gold trading rev 2.mq4` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 4 |
| DF18 | Grid Dynamic Buy Only | `(Boss) Grid buy only rev1.31 add comment.mq4` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 3 |
| DF19 | Master GRID ATR Dynamic-RSI | `(Boss) ATR.mq4` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 3 |
| DF20 | PSAR MM | `(Boss) PSAR mm.mq4` | `FAMILY_NATIVE_PIPELINE_OR_EXPLICIT_ADAPTER` | 3 |

## Gate to actual tester execution
A recovered family may enter MT5 only after: exact parent revision owner-freeze → canonical FamilyID/LAB_ENTRY/implementation contract → source-parity tests → compile/regression + required review → Home/TF/settings freeze → fixed MAIN+BWD contract. No BWD retuning or HOLDOUT discovery.

## Direct consumer
EA Template planning lane / future owner-ratified bounded port contract. Until then the streaming tester queue remains empty for recovered families.
