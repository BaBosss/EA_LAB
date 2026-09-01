# B16 USDJPY/H1 BUY H08 OPT01 Results

Status: COMPLETE / RESEARCH_ONLY / MAIN_PLATEAU_FOUND / CENTER_REJECTED_BWD
Working verdict: PARK — selected H08 center is not adopted; accepted 14/30 parent remains the research reference.
QUALITY_GRADE: UNRATIFIED
EVIDENCE_CONFIDENCE: UNRATIFIED
BUILD_POTENTIAL: EXHAUSTED for this preregistered H08 RSI-entry lattice only.
Authority: no Candidate, HOLDOUT, DEMO/LIVE, deployment, trading, risk/default, KINT or Grade authority.

## 1. Identity and contract

- Family: Boss16 KangarooGrid / `LAB_ENTRY_16`.
- Hypothesis revision: `B16-H08-r1`.
- Symbol/timeframe: USDJPY/H1.
- Entry direction: BUY (`_16_Direction=1`).
- MAIN search/confirmation: 2023-01-01..2025-12-31, Model 1.
- BWD validation: 2020-01-01..2022-12-31, Model 1.
- HOLDOUT: UNSPENT.
- Build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`.
- Source SHA256 from accepted build receipt: `e22f64302ea443c5bec14c22fbb4787002f1c88742b9ca30d416040affe4e8d3`.
- EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
- Exact parent full-surface set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.
- Locked 14/35 fixed set SHA256: `c936bc4d79a85aa481e249a1c7c316bdfdfd34f30c170f4e930e16bf1104ac84`.

## 2. Mechanics kept frozen

Source-defined BUY entry arms when RSI on the last closed bar is below `_16_RsiLow`; RSI period is `_16_RsiPeriod`. H08 changed only these two entry inputs on the MAIN search surface. Position engine, spacing, exits, sizing, protection and safety stayed frozen.

Frozen material mechanics include `_16_MaxOrdersPerSide=10`, `_16_AtrMultFirst4=0.8`, `_16_AtrMultAfter=1.4`, `_16_LadderMult=1.0`, `_16_TpSingleAtrMult=0.35`, `_16_BasketTpUsdPer01=16.0`, `_16_OverlapMinUsd=5.0`, and the existing loss/protection cage. The accepted exit-concentration diagnostic remains controlling evidence: SingleTP/BasketTP-off paths were not adopted and current exits remain frozen.

## 3. Prospective optimization contract

Only two TUNABLE dimensions were allowed:

| Parameter | Lattice | Baseline |
|---|---|---:|
| `_16_RsiPeriod` | {7, 14, 21, 28} | 14 |
| `_16_RsiLow` | {20, 25, 30, 35, 40} | 30 |

Optimizer guard result: ALLOW 2 / REFUSE 0. The exact 20-cell MAIN lattice was complete and reproduced the accepted 14/30 baseline at PF 1.527489, net +252.53, 275 trades, optimizer EqDD 3.8549%.

Plateau eligibility required an interior center plus four orthogonal neighbours to be mechanically accepted, MAIN net > 0, and at least 100 closed trades in each of the five cells. Three centers were eligible: 14/30, 14/35, and 21/35. The preregistered max-min selector chose 14/35 with five-cell minimum net +169.42 and minimum trades 275.

The selected center was locked before BWD. No range expansion, medium refine, fine refine, additional parameter dimension, or BWD retuning was allowed.

## 4. Fixed validation evidence

| Window | PF | Net | Trades | EqDD | Cycles | Max depth | Result |
|---|---:|---:|---:|---:|---:|---:|---|
| MAIN | 1.68 | +415.62 | 420 | 4.78% | 372 | 7 | PASS |
| BWD | 0.66 | -229.49 | 230 | 3.91% | 198 | 6 | FAIL |

The fixed MAIN run reproduces the optimizer-selected 14/35 cell: net and trade count match exactly; PF/EqDD match within the MT5 report display rounding used by the fixed report.

Against the accepted 14/30 parent headline, 14/35 MAIN changes net +163.09, trades +145 and PF +0.15, while EqDD rises +0.93 pp. BWD changes net -273.59, trades -37 and PF -0.45, while EqDD rises +1.51 pp. The parent BWD headline remains PF 1.11 / net +44.10 / 267 trades / EqDD 2.40%.

Calendar-year center evidence:

| Window | Year | PF | Net | Trades |
|---|---:|---:|---:|---:|
| MAIN | 2023 | 3.6087 | +220.38 | 174 |
| MAIN | 2024 | 1.0606 | +24.10 | 131 |
| MAIN | 2025 | 2.2962 | +171.14 | 115 |
| BWD | 2020 | 0.2447 | -127.01 | 28 |
| BWD | 2021 | 1.2118 | +21.62 | 94 |
| BWD | 2022 | 0.6908 | -124.10 | 108 |

## 5. Evidence vs interpretation vs decision

Evidence: the preregistered MAIN plateau claim is NOT FALSIFIED. A participation-qualified interior plateau exists and 14/35 is the deterministic selected center. Mechanical acceptance is PASS: optimizer grid 20/20, guard 2/0, fixed validation 2/2 mechanically valid, leverage 1:100 matched, truncation 0/2, and HOLDOUT remained unspent.

Interpretation: the MAIN improvement does not transport backward. The selected center materially degrades BWD economics and fails the preregistered BWD validation PF bar despite adequate trade count. The BWD failure is strategy evidence, not a harness failure. Realized depth 7 MAIN / 6 BWD also confirms the selected center remains position-engine dependent.

Decision: `DO_NOT_ADOPT_CENTER_RETAIN_PARENT_RESEARCH_REFERENCE`. Close H08 with `SEARCH_STATUS=CLOSED_NO_RETUNING`. Do not use BWD to choose another pair from the same lattice and do not reopen the range after seeing BWD.

## 6. Robustness / known unknowns

- Model 4: NOT RUN.
- Monte Carlo: NOT RUN.
- HOLDOUT: UNSPENT.
- Broker/execution portability beyond the accepted Model-1 lineage: NOT RUN for this H08 center.
- `KINT-001`: OPEN.
- Numeric A/B/C/D grade mapping: UNRATIFIED; no grade is assigned.

## 7. Traceability and next consumer

Machine-readable evidence is under `factory/runs/b16_h08_20260831/usdjpy_buy_h1/`. Key files: `selection.json`, `center_lock.json`, `validation_summary.json`, `validation_year_split.csv`, `parent_center_comparison.csv`, `mechanical_acceptance.json`, and the raw fixed validation reports. Visuals `h08_main_surface.svg` and `h08_parent_center_compare.svg` are `VISUAL_ONLY_NO_AUTHORITY`.

H08 itself has no further adaptive consumer. The accepted 14/30 USDJPY/H1 parent remains the stronger B16 continuation reference because it retains positive MAIN+BWD headline behavior with higher participation than the GBPUSD/H4 lead. Any robustness-finalist use of that parent, Model-4 request, Monte Carlo, or HOLDOUT spend requires the next prospective contract and applicable runtime/authority gate; H08 does not grant those transitions automatically.
