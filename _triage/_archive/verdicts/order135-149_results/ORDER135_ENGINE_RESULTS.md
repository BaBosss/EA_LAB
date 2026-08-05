# ORDER-133 — capped-basket DCA ENGINE test on best lever-C cells — RESULTS

**Role:** facts only. No verdict / no recommendation (lead judges).
**Run:** 2026-07-19 · agent lane · main tester `D:\Meta 5` (serial, tester idle-checked before every pass, no contention events).

## Setup (as executed)
- Vehicle = compiled chassis `EALabTpl\Boss_15_ST03` (roaming ex5 2026-07-19 06:34 — same binary as ORDER-119 lever C; no source touch, no recompile).
- Cells (from lever-C near-misses):
  - **Cell 1 = GBPUSD H1**, MACD `_15_MacdFast=12 _15_MacdSlow=26 _15_MacdSignal=9 _15_CountBars=3` (lever-C BWD best 1.05)
  - **Cell 2 = EURUSD H4**, MACD `_15_MacdFast=16 _15_MacdSlow=34 _15_MacdSignal=9 _15_CountBars=3` (lever-C MAIN best 1.15)
- MM block per spec: `StackMode=92` (DCA grid-against) · `FirstLotMode=41` · `_41_FixedLot=0.01` · `ProtectLevel=2` (KillDD 25% / Load 30). `StackConfirm=0` (chassis ST03 default, distance-only) pinned explicitly. Grid step = chassis default (`_9_StepUseATR=true`, 1.0 × Signal-ATR(14)).
- Sweep: `_9_MaxLevels {4,6,8}` × LotProg `{50 NONE · 51 LINEAR _51_ProgFactor=0.5 · 54 LOG _51_ProgFactor=1.0}` = 9 combos/cell.
- **Execution note (necessary deviation, documented):** `RC_MaxLevelsOverride=8` pinned in every set. Reason: `RiskControl_MaxLevels() = min(cageMax, _9_MaxLevels)` and with `ProtectLevel=2` cageMax = `RC_MaxRecSteps()` = **3** — without the override the whole {4,6,8} sweep silently clamps to depth 3 (sweep no-op). Override=8 makes effective depth = `_9_MaxLevels` exactly, while KillDD/DepositLoad still come from ProtectLevel=2 untouched (that is the documented purpose of the input, `Inputs.mqh:412-417`).
- Because LINEAR and LOG share `_51_ProgFactor` with different required values, the 9-combo grid was run as **3 optimize passes per cell-window** (one per LotProg, each sweeping `_9_MaxLevels`) = 12 passes total, Model 1, complete (deterministic) optimization, Deposit 10000 USD, Leverage 1:100.
- Windows: MAIN 2023.07.01–2026.07.01 · BWD 2020.01.01–2022.12.31 (= lever-C windows, comparable).
- All 12 XMLs exported cleanly; **every combo returned real trades (n = 407–2551, no 0-trade collision artifacts)**. Sets: `_mt5_auto/ab_sets/order133_engine/O133_*.set` · raw XML: `_mt5_auto/optimizations/O133_*.xml`.

## TOP-LINE (pre-registered gate: PF ≥ 1.0 in BOTH windows, BWD = HARD)
### → NO SURVIVORS. 0 of 9 combos in either cell clears PF ≥ 1.0 in both MAIN and BWD.
- Cell 1 GBPUSD H1: BWD > 1.0 everywhere (1.03–1.05) but **MAIN < 1.0 everywhere** (0.95–0.96).
- Cell 2 EURUSD H4: MAIN marginally > 1.0 everywhere (1.007) but **BWD = 0.81 everywhere**.
- Consequently **no Model-4 confirm runs were triggered** (gate condition never met).

## Cell 1 — GBPUSD H1 (MACD 12/26/9, cnt 3)

| LotProg | MaxLv | MAIN PF | MAIN n | MAIN net | MAIN eqDD% | BWD PF | BWD n | BWD net | BWD eqDD% | both≥1.0 |
|---|---|---|---|---|---|---|---|---|---|---|
| NONE | 4 | 0.964 | 2549 | -111.32 | 1.85 | 1.031 | 2379 | +87.88 | 1.39 | — |
| NONE | 6 | 0.963 | 2551 | -117.32 | 1.90 | 1.031 | 2379 | +87.88 | 1.39 | — |
| NONE | 8 | 0.963 | 2551 | -117.32 | 1.90 | 1.031 | 2379 | +87.88 | 1.39 | — |
| LINEAR f0.5 | 4 | 0.961 | 2549 | -149.90 | 2.66 | 1.045 | 2379 | +140.43 | 1.70 | — |
| LINEAR f0.5 | 6 | 0.954 | 2551 | -176.92 | 2.93 | 1.045 | 2379 | +140.43 | 1.70 | — |
| LINEAR f0.5 | 8 | 0.954 | 2551 | -176.92 | 2.93 | 1.045 | 2379 | +140.43 | 1.70 | — |
| LOG f1.0 | 4 | 0.961 | 2549 | -149.90 | 2.66 | 1.045 | 2379 | +140.43 | 1.70 | — |
| LOG f1.0 | 6 | 0.956 | 2551 | -166.92 | 2.83 | 1.045 | 2379 | +140.43 | 1.70 | — |
| LOG f1.0 | 8 | 0.956 | 2551 | -166.92 | 2.83 | 1.045 | 2379 | +140.43 | 1.70 | — |

Facts: DCA engine engaged (n ≈ 2.2× the lever-C single-position n=1100/1199 — adds are real trades). vs lever-C flat-lot same cell: MAIN 0.90 → 0.95–0.96 (up, still <1.0) · BWD 1.05 → 1.03–1.05 (≈flat). Progression widens both tails: BWD net +88 → +140 (NONE→LIN/LOG) while MAIN net −111 → −177. MaxLevels 6 ≡ 8 in every row → observed basket depth never exceeded 6; LIN ≡ LOG at depth ≤4 rows is arithmetic identity after 0.01 volume-step normalization (both ladders normalize to 0.01/0.01/0.02/0.02 for levels 0–3).

## Cell 2 — EURUSD H4 (MACD 16/34/9, cnt 3)

| LotProg | MaxLv | MAIN PF | MAIN n | MAIN net | MAIN eqDD% | BWD PF | BWD n | BWD net | BWD eqDD% | both≥1.0 |
|---|---|---|---|---|---|---|---|---|---|---|
| NONE | 4 | 1.007 | 407 | +3.16 | 0.72 | 0.806 | 440 | -115.70 | 1.21 | — |
| NONE | 6 | 1.007 | 407 | +3.16 | 0.72 | 0.806 | 440 | -115.70 | 1.21 | — |
| NONE | 8 | 1.007 | 407 | +3.16 | 0.72 | 0.806 | 440 | -115.70 | 1.21 | — |
| LINEAR f0.5 | 4 | 1.007 | 407 | +3.16 | 0.72 | 0.806 | 440 | -115.70 | 1.21 | — |
| LINEAR f0.5 | 6 | 1.007 | 407 | +3.16 | 0.72 | 0.806 | 440 | -115.70 | 1.21 | — |
| LINEAR f0.5 | 8 | 1.007 | 407 | +3.16 | 0.72 | 0.806 | 440 | -115.70 | 1.21 | — |
| LOG f1.0 | 4 | 1.007 | 407 | +3.16 | 0.72 | 0.806 | 440 | -115.70 | 1.21 | — |
| LOG f1.0 | 6 | 1.007 | 407 | +3.16 | 0.72 | 0.806 | 440 | -115.70 | 1.21 | — |
| LOG f1.0 | 8 | 1.007 | 407 | +3.16 | 0.72 | 0.806 | 440 | -115.70 | 1.21 | — |

Facts: **all 9 combos identical per window.** Adds do occur (n=407 vs lever-C single n=286 MAIN) but baskets never reached level 2 with a normalized lot > 0.01 (level-1 lot: LIN 0.015 and LOG 0.0169 both normalize to 0.01 on 0.01-step) and never reached depth 4 — so LotProg and MaxLevels are behaviorally inert in this cell at the default 1.0-ATR step. vs lever-C flat-lot: MAIN 1.15 → 1.007 (down), BWD 0.83 → 0.81 (≈flat).

## M4 confirm table
**No survivors → no M4 confirm runs** (gate: PF ≥ 1.0 both windows, BWD hard — never met).

## Worst-case arithmetic (reference — computed for all 9 combos since no combo survived)
Theoretical ladder at 0.01 base lot, raw formula lots (level k = 0..MaxLv−1; NONE 0.01 · LINEAR 0.01·(1+0.5k) · LOG 0.01·(1+ln(k+1))). Broker 0.01 volume-step normalization reduces actual placed lots below raw at intermediate levels (observed in results). Hard cap in all cases = ProtectLevel-2 equity kill 25% of 10k = **$2,500**; the 15% flag threshold = eqDD > 15% of deposit.

| LotProg | MaxLv | ladder lots (raw sum) | kill cap | worst observed eqDD (either window) | >15% flag |
|---|---|---|---|---|---|
| NONE | 4 | 0.040 | $2,500 | G1 1.85% / E4 1.21% | no |
| NONE | 6 | 0.060 | $2,500 | G1 1.90% / E4 1.21% | no |
| NONE | 8 | 0.080 | $2,500 | G1 1.90% / E4 1.21% | no |
| LINEAR f0.5 | 4 | 0.070 | $2,500 | G1 2.66% / E4 1.21% | no |
| LINEAR f0.5 | 6 | 0.135 | $2,500 | G1 2.93% / E4 1.21% | no |
| LINEAR f0.5 | 8 | 0.220 | $2,500 | G1 2.93% / E4 1.21% | no |
| LOG f1.0 | 4 | 0.072 | $2,500 | G1 2.66% / E4 1.21% | no |
| LOG f1.0 | 6 | 0.126 | $2,500 | G1 2.83% / E4 1.21% | no |
| LOG f1.0 | 8 | 0.186 | $2,500 | G1 2.83% / E4 1.21% | no |

No combo's observed BWD (or MAIN) eqDD comes anywhere near 15% of the 10k deposit — worst anywhere in the sweep = 2.93% (G1 LINEAR MaxLv≥6, MAIN window). The 25% kill never fired.

## Raw artifacts
- Sets: `D:\EA_LAB\_mt5_auto\ab_sets\order133_engine\` (6 files: {G1,E4} × {NONE,LIN,LOG})
- Optimizer XML: `D:\EA_LAB\_mt5_auto\optimizations\O133_{G1|E4}_{NONE|LIN|LOG}_{MAIN|BWD}.xml` (12 files, 2026-07-19)
