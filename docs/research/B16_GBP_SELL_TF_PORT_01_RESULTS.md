# B16 GBPUSD SELL Timeframe Portability — Step 5 Results

Status: `PASS MECHANICAL / HYPOTHESIS_FALSIFIED / H4_LOCAL / RESEARCH_ONLY`
Hypothesis: `HYP-B16-GBP-SELL-TFPORT-01`
Preregistered HEAD: `97c1210010a2174486842680632bee25b2b4105a`

## Evidence

All four new Model-1 cells completed on Meta5b with exit 0, exact GBPUSD identity, leverage 1:100 MATCH, exact SELL set SHA `c0e7cfad...105de`, accepted build receipt/EX5 identity, no truncation flag and no `[RISK] HARD KILL` in the execution console. HOLDOUT remains UNSPENT; optimization remains NONE.

| Context | MAIN PF / trades / net / EqDD | BWD PF / trades / net / EqDD | Dual-window positive? |
|---|---|---|---|
| GBPUSD/H4 SELL accepted lead | 7.97 / 80 / +283.20 / 1.72% | 14.36 / 76 / +268.97 / 1.27% | YES |
| GBPUSD/H1 SELL | 0.81 / 270 / -70.55 / 3.06% | 1.65 / 268 / +240.00 / 2.57% | NO |
| GBPUSD/M15 SELL | 1.32 / 724 / +118.80 / 0.89% | 0.86 / 748 / -89.73 / 2.25% | NO |

Preregistered classification = **`H4_LOCAL`** because neither adjacent timeframe is positive in both MAIN and BWD. Therefore the primary statement is **falsified**.

## Year evidence

H1 MAIN changes sign through time: 2023 `+142.69`, 2024 `-47.02`, 2025 `-166.22`; H1 BWD remains positive in 2020/2021/2022 (`+76.44 / +93.40 / +70.16`).

M15 MAIN is `+109.28 / +29.23 / -19.71` for 2023/2024/2025; M15 BWD is negative in all three years (`-1.74 / -56.67 / -31.32`).
## Cycle / exposure diagnostics

H1 MAIN reconstructs 254 flat-to-flat cycles, max basket depth 4, max aggregate lots 0.04, active-time share 21.82%, and multi-entry positive gross-profit share 34.74%. H1 BWD reconstructs 242 cycles, depth 6, 0.06 lots, active-time share 22.57%, and multi-entry positive gross-profit share 61.94%.

M15 MAIN reconstructs 709 cycles, max depth 2, 0.02 lots, active-time share 25.86%, and multi-entry positive gross-profit share 35.13%. M15 BWD reconstructs 719 cycles, depth 4, 0.04 lots, active-time share 20.60%, and multi-entry positive gross-profit share 29.75%.

The adjacent-timeframe failures therefore are not EMPTY/non-participating cells. They contain substantial activity and materially different position-engine use.

## Interpretation

The strong GBPUSD/H4 SELL result does **not** port cleanly to H1 or M15 under the exact frozen configuration. Direction asymmetry is therefore real at H4 but timeframe-conditional; the evidence does not support treating `GBPUSD SELL` as a universal B16 family direction rule.

This negative portability result does not erase the H4 evidence. It narrows the next consumer: any optimization must be scoped specifically to `B16 / GBPUSD / SELL / H4`, not a multi-timeframe GBPUSD SELL family.

## Decision / next transition

Step 5 is complete. Do **not** open multi-TF optimization. A Step-6 Optimization Contract is justified only if the direct consumer is the already-qualified **GBPUSD/H4 SELL local profile** and its causal parameter semantics/ranges are prospectively frozen first.

If Step 6 is opened, Step 7 must use MAIN-only Fast Genetic for WIDE/COARSE region mapping, followed by REGION_SELECT → MEDIUM_REFINE → bounded complete FINE/NEIGHBOUR grid. The optimizer winner is not a Candidate; BWD/regime validation follows only after a center is locked.

Authority remains `RESEARCH_ONLY`: no HOLDOUT, H04, Candidate, DEMO/LIVE, deployment, trading, risk/default, KINT or Grade authority is created by this result.
