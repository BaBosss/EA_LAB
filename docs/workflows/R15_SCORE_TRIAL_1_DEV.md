# R15 score formula — development-only trial 1 (2026-11-04)

**Label: DEVELOPMENT_ONLY** (R13). Nothing here freezes a formula.

**Question:** which in-sample score ranks optimizer passes so that they also hold up out of sample on the same grid?

**Method.** Join each pass across a selection-window XML and a check-window XML of the same EA and grid, matching on the
exact parameter tuple. Score every pass with 7 candidate formulas on the selection window. Then measure:
- the Spearman rank correlation between the score and check-window PF;
- the check-window PF of the top 1 and the top 5 passes.

**Scripts:** `C:\Users\patip\AppData\Local\Temp\claude\D--EA-LAB\c2a2ed17-07fb-4221-be9e-454e4d3afb49\scratchpad\r15\scan_xml.py`
and `score_trial.py`. Raw output is `trial.json` next to them. Source is the local `D:\EA_LAB\_mt5_auto` optimizer XMLs (read-only).

## Data found

- 175 optimizer XMLs. 18 share an identical grid across two windows.
- Only **2 pairs have disjoint windows with a full join**:

| Pair | Selection | Check | Joined passes |
|---|---|---|---|
| STF BTC H4 (`FAN_BTC_H4_*`) | MAIN 2023–25 | BWD 2020–22 | 81 / 81 |
| ST03 GBPUSD H1 (`OPT_ST3G_*`) | 2023–24 | 2025–26H1 | 48 / 48 |

- EA_LabTemplate XAU joined on only 42 of 130 passes.
- BaronGrid's check window **contains** its selection window, so it is not independent. It is excluded.
- The 12 Boss_14 pairs use nested windows (2023–25H1 vs 2023–26H1), so they are not independent either.

## Formulas

| ID | Formula |
|---|---|
| F0 | PF |
| F1 | net |
| F2 | recovery factor |
| F3 | Sharpe |
| F4 | (min(PF, 3) − 1) × confidence(R19 A/B/C/D = 1, .75, .5, 0); −9 if eqDD > 12 % |
| F5 | recovery × confidence; −9 if eqDD > 12 % |
| F6 | ln(PF) × √n ÷ (1 + eqDD/12); −9 if eqDD > 12 % |

## Results

| Pair | Best Spearman | Worst Spearman | Top-5 check PF range across formulas | Check PF median, all passes |
|---|---|---|---|---|
| STF BTC H4 | F0 0.31 | F1 0.10 | 3.26 – 3.73 | 3.43 |
| ST03 GBPUSD | F1 −0.05 | F2/F5 −0.32 | 0.70 – 0.72 | 0.76 |
| (EA_LabTemplate XAU, partial) | F1/F2 0.50 | F4–F6 0.37 | 0.59 – 0.62 | 0.58 |

## What this shows (and does not)

1. **The formula is not the main lever.**
   - On every pair the top-5 out-of-sample PF differs by ≤ 0.5 between formulas.
   - Where the edge is real (STF BTC), every formula picks a pass that is about as good as the median pass.
   - Where it is not (ST03), every formula picks a loser.
   - The score cannot rescue a missing edge. What decides survival is the BWD gate and the plateau rule, not the ranking column.
2. **On ST03, in-sample rank is negatively correlated with out-of-sample PF** (all formulas). This is the overfit signature
   the plateau rule exists for. Picking the in-sample best is worse than picking at random.
3. **Not shown:** a winner. Two clean pairs with 48–81 passes cannot separate formulas whose results are this close.
   None of the pairs is an escalation EA in this sample, so the R18 floating-loss penalty is untested.

## Recommendation for R15 (to confirm in trial 2)

- Keep the score simple and monotone. **F5 (recovery × R19 confidence, hard 12 % equity-DD cap)** is the provisional pick.
  - It is never worst on the clean pairs.
  - It encodes two already-ratified rules: the 12 % DD cap and R19 confidence.
  - It is explainable in one line.
- Put the selection effort in a **neighbour-smoothed score** instead: rank passes by the mean score of the pass and its
  grid neighbours (the plateau, not the spike). Trial 2 should test smoothed vs raw.
- Escalation class: F5 plus the R18 worst-basket penalty. The weights stay `null` until escalation pairs exist.

## Trial 2 — run plan (needs MT5; batch → Qwen per the cost rule)

| Class | EA (canonical Boss V2) | Home | Grid |
|---|---|---|---|
| trend | Boss_15_ST03 | GBPUSD H1 | 3 levers, ~150–300 passes |
| reversion | Boss_13_MeanRev | EURUSD H1 | same |
| breakout | Boss_12_Breakout | XAUUSD H1 | same |
| escalation | Boss_14_GridLog | USDJPY H1 | same, plus the in-EA basket log once R18 exists |

- Each grid runs **twice, identically**: MAIN 2023–25 and BWD 2020–22, Model 1, full `.set`, leverage asserted.
- Then re-run `score_trial.py` with raw and neighbour-smoothed variants. Freeze the R15 formula only if one variant is
  never worst and best on ≥ 2 of 4 classes. Otherwise freeze F5 as the simplest.
- Cost: about 8 optimizer jobs. Lane: one runtime lane plus an `mt5_optimize.ps1` batch. No core edit.
