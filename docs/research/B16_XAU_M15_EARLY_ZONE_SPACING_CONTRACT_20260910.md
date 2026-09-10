# B16 XAUUSD/M15 Early-Zone Spacing — Prospective Contract — 2026-09-10

Status: `PREREGISTERED / RESEARCH_ONLY / NO OPTIMIZATION`
Hypothesis ID: `HYP-B16-XAU-M15-EARLYZONE-01`
Canonical base SHA: `17116aea956da9a169ed2799772c5fd9a30b20d2`
Runtime lineage: `D:\Meta 5c` only; same installation for parent and child.
Model: `1 / 1 Minute OHLC`; Optimization: `0`; Forward: `0`; HOLDOUT: `UNSPENT / FORBIDDEN`.
Deposit: USD 10,000; leverage: 1:100.

## Question and direct consumer

Does the accepted B16 XAUUSD/M15 two-zone position engine require the compressed early ATR spacing (`0.8`) to retain positive aggregate net in both frozen windows, or can the early zone be widened to the already-native deep-zone value (`1.4`) without losing dual-window sign?

Direct consumer: decide whether any future B16 spacing research should continue treating early/deep asymmetry as a necessary mechanism, or whether a symmetric wider-spacing direction remains admissible for a separately preregistered study.

This is a genuinely new prospective question. Canonical dedup found prior tests of `_16_AtrMultAfter: 1.4 -> 0.8` but no prior experiment setting `_16_AtrMultFirst4=1.4`. It does not reopen RSI, CountBars, exit-concentration, H08 optimization, R4 execution-fidelity, or closed depth paths.

## Frozen identities

EA: `EALabTpl\Boss_16_KangarooGrid`.
EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
Accepted build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`.
Build-receipt registry SHA256: `6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8`.
Parent set: `factory/runs/b16_earlyzone01_20260910/B16_XAU_M15_EARLYZONE01_PARENT.set`.
Parent set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.
Child set: `factory/runs/b16_earlyzone01_20260910/B16_XAU_M15_EARLYZONE01_CHILD.set`.
Child set SHA256: `551385b8a1b16141f3924315988bdf101d12a6aee2246ac1eb59ff1ba16ad88f`.

Exactly one tester-input change:
`_16_AtrMultFirst4: 0.8 -> 1.4`.

`_16_AtrMultAfter=1.4`, `_16_MinDistPips=150`, max depth, Kangaroo lot law, SingleTP, BasketTP, overlap exits, RSI/direction, ATR period, protection and every other tester input remain byte-identical to the parent.

The child value `1.4` is not chosen from MAIN/BWD outcomes. It is the already-frozen native deep-zone multiplier in the parent, so the intervention removes the early/deep spacing asymmetry without introducing a new searched numeric value.

## Accepted historical parent context — background only

Canonical accepted XAUUSD/M15 parent evidence from the prior Meta5b lineage was:
- MAIN `2023-01-01..2025-12-31`: PF `1.25`, net `+2643.64`, 1577 trades, native EqDD `11.88%`, report SHA256 `2aeb5f6c0de9a517b3a49c2ca62b75e87938edc457e7adac2317a0a7b5afb728`.
- BWD `2020-01-01..2022-12-31`: PF `1.10`, net `+1002.69`, 1463 trades, native EqDD `14.86%`, report SHA256 `27149f0074c81e70b086a31dbf722eafa2920c281f05adaaf9022dd8a8bc2644`.

Those numbers motivate the prospective question but are not the acceptance-critical control for this experiment. To obey one-install lineage, fresh parent and child cells are both rerun on `D:\Meta 5c`; all causal comparisons use only that same-install pair.
## Frozen execution matrix

Exactly four Strategy Tester cells, serial on the same `D:\Meta 5c` installation:
1. Parent MAIN: XAUUSD/M15, `2023.01.01..2025.12.31`.
2. Child MAIN: XAUUSD/M15, `2023.01.01..2025.12.31`.
3. Parent BWD: XAUUSD/M15, `2020.01.01..2022.12.31`.
4. Child BWD: XAUUSD/M15, `2020.01.01..2022.12.31`.

BWD is validation only and cannot alter the child, open a new value, select a threshold, or trigger retuning. Losing mechanically valid cells are evidence and are never rerun for reassurance.

## Prospective statement and classification

Primary statement: widening the early zone from `0.8` to `1.4` retains positive aggregate net in both frozen windows.

- If child net `<= 0` in either mechanically accepted window: `HYPOTHESIS_FALSIFIED / EARLY_COMPRESSION_SIGN_RELEVANT` for this XAUUSD/M15 frozen context.
- If child net `> 0` in both windows: `HYPOTHESIS_NOT_FALSIFIED / DUAL_WINDOW_SIGN_SURVIVES_WIDER_EARLY_ZONE`.

Secondary, non-threshold interpretation compares child vs same-install parent PF, net, native EqDD%, trades, yearly participation and realized depth. If the child has non-lower net and non-higher EqDD in both windows, record `PARETO_NONWORSE`; otherwise record the observed trade-off without inventing a score or promotion rule.

No result from this contract alone authorizes a new optimum, default, Candidate, Grade, KINT mapping, runtime change or deployment.
## Mechanical acceptance and stop rule

Each cell must bind the exact EX5/set/symbol/TF/window/model/deposit/leverage identities above, produce a fresh report, pass leverage `1:100` verification, and have explicit truncation/full-window eligibility. Parent and child must remain on the same Meta5c lineage.

If the existing accepted EX5 identity is missing/mismatched, the parent set differs from its frozen SHA, the child differs by more than the sole assignment, required XAUUSD/M15 history is unavailable, or the harness cannot produce trustworthy evidence, stop `BLOCKED_*`. At most one bounded mechanical repair is allowed; do not alter strategy inputs to repair execution.

Do not substitute Meta5/Meta5b evidence for an unexecuted Meta5c cell. Do not open HOLDOUT. Do not add a third spacing value after seeing results.

## Evidence / interpretation / decision separation

Evidence: raw reports, tester INIs, leverage/truncation sidecars, exact hashes, run receipts and deterministic parsed metrics.
Interpretation: whether the one-change child preserves sign and how its same-install trade-off differs from parent.
Decision: only whether a future separately preregistered B16 spacing direction is admissible; no promotion authority.

Authority ceiling: `RESEARCH_ONLY / NO OPTIMIZATION / NO HOLDOUT / NO CANDIDATE / NO DEMO-LIVE / NO DEPLOYMENT / NO TRADING / NO RISK-DEFAULT CHANGE / NO KINT-GRADE AUTHORITY`.
