# B16 USDJPY/H1 BUY R4 Execution-Fidelity Results

Status: COMPLETE / RESEARCH_ONLY / `R4_EXECUTION_FIDELITY_NOT_FALSIFIED`
Working decision: retain the frozen `14/30` parent as the B16 USDJPY/H1 research reference; R4 does not trigger PARK for execution-fidelity failure.
QUALITY_GRADE: UNRATIFIED
EVIDENCE_CONFIDENCE: UNRATIFIED
Authority: no HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default, KINT, or Grade authority.

## 1. Identity and prospective contract

- Family: Boss16 KangarooGrid / `LAB_ENTRY_16`.
- Hypothesis revision: `B16-R4-r1`.
- Symbol / timeframe / side: USDJPY / H1 / BUY.
- Frozen RSI trigger: `_16_RsiPeriod=14`, `_16_RsiLow=30`.
- Exact parent set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.
- Accepted build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`.
- Exact EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
- Prospective contract: `docs/research/B16_USDJPY_H1_R4_EXECUTION_FIDELITY_CONTRACT.md`.
- Runtime exact HEAD: `dcb5dd1dfd9b3df68a270985272b13fc5fee0890`.
- Same-install lineage: `D:\Meta 5` / `MT5-lane1`.
- MAIN: 2023-01-01..2025-12-31. BWD: 2020-01-01..2022-12-31.
- HOLDOUT: UNSPENT. Optimization: NONE.

## 2. Frozen mechanics and allowed change

R4 changed only the Strategy Tester model. Parent position engine, max orders/depth, spacing, SingleTP/BasketTP/overlap exits, sizing, protection, safety, direction and all other inputs remained frozen. H07 GBPUSD depth3 was not imported as a USDJPY default. BWD remained validation-only and was never a search surface.

The accepted EX5 was provisioned into an order-owned primary-install tester path rather than overwriting the shared `EALabTpl` Boss16 binary. The runtime preflight re-hashed the copied binary to the accepted EX5 SHA before any cell launched.

Execution order was exactly:

1. Model1 MAIN control;
2. Model1 BWD control;
3. after both controls passed, Model4 MAIN;
4. Model4 BWD.

Contract bars: MAIN PF >= 1.20, net > 0, >=100 trades; BWD PF >= 1.00, net > 0, >=100 trades. All four cells also required exact identity, leverage match and non-truncation.

## 3. Acceptance-critical evidence

| Model | Window | PF | Net | Trades | EqDD | Largest closed-ticket loss | Max depth | Max aggregate lots | Result |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| Model1 | MAIN | 1.54 | +255.30 | 275 | 3.85% | -68.51 | 7 | 0.07 | PASS |
| Model1 | BWD | 1.13 | +50.22 | 267 | 2.38% | -52.57 | 5 | 0.05 | PASS |
| Model4 | MAIN | 1.38 | +187.32 | 273 | 3.91% | -68.68 | 7 | 0.07 | PASS |
| Model4 | BWD | 1.20 | +74.73 | 262 | 2.29% | -52.49 | 5 | 0.05 | PASS |

Same-install Model4 versus Model1 delta:

- MAIN: PF -0.16, net -67.98, trades -2, EqDD +0.06 pp; max depth/lots unchanged; largest loss changes only -0.17.
- BWD: PF +0.07, net +24.51, trades -5, EqDD -0.09 pp; max depth/lots unchanged; largest loss improves by 0.08.
- No model-switch sign flip occurred in either full window and no exposure/depth cliff appeared.

## 4. Calendar-year evidence

| Model | Window | Year | PF | Net | Trades |
|---|---|---:|---:|---:|---:|
| 1 | MAIN | 2023 | 2.5324 | +137.79 | 104 |
| 1 | MAIN | 2024 | 1.2411 | +55.39 | 90 |
| 1 | MAIN | 2025 | 1.4011 | +62.12 | 81 |
| 1 | BWD | 2020 | 0.7574 | -40.91 | 98 |
| 1 | BWD | 2021 | 7.1023 | +57.24 | 76 |
| 1 | BWD | 2022 | 1.1527 | +33.89 | 93 |
| 4 | MAIN | 2023 | 2.3289 | +121.08 | 104 |
| 4 | MAIN | 2024 | 1.1930 | +44.29 | 90 |
| 4 | MAIN | 2025 | 1.1288 | +21.95 | 79 |
| 4 | BWD | 2020 | 0.7921 | -35.06 | 96 |
| 4 | BWD | 2021 | 6.4087 | +50.95 | 73 |
| 4 | BWD | 2022 | 1.3009 | +58.84 | 93 |

The aggregate R4 bars pass, but 2020 remains a losing subperiod under both tester models. R4 therefore answers execution-fidelity only; it does not establish all-year or regime-wide robustness.

## 5. Evidence integrity and provenance

Deterministic evidence integrity = PASS. `evidence_integrity.json` verifies four unique preregistered cells, same executed HEAD/lane/set/EX5, report hashes matching run receipts, `Optimization=0`, `Leverage=1:100`, no HOLDOUT dates, 12 calendar-year rows, and deterministic re-analysis.

Key machine-readable owners:

- `factory/runs/b16_r4_20260902/usdjpy_buy_h1/evidence_summary.json`;
- `factory/runs/b16_r4_20260902/usdjpy_buy_h1/evidence_integrity.json`;
- `factory/runs/b16_r4_20260902/usdjpy_buy_h1/run_receipts.jsonl`;
- `factory/runs/b16_r4_20260902/usdjpy_buy_h1/runtime_preflight.json`;
- four source reports under `factory/runs/b16_r4_20260902/usdjpy_buy_h1/runtime/`.

Historical Meta5c H08 numbers were context only and were not used as acceptance-critical paired evidence.

## 6. Evidence vs interpretation vs decision

Evidence: both same-install Model1 controls pass, both Model4 windows pass the prospectively frozen bars, all four cells are mechanically eligible, and Model4 retains positive full-window sign with near-identical participation/exposure structure.

Interpretation: the frozen USDJPY/H1 BUY 14/30 parent is not falsified by the execution-fidelity question tested here. Model4 weakens MAIN economics but does not create a model-switch cliff; BWD improves modestly. The persistent 2020 loss remains a known robustness limitation outside this contract's tester-model question.

Decision: `R4_EXECUTION_FIDELITY_NOT_FALSIFIED`. Do not PARK this parent for execution-fidelity failure. Retain it as the B16 USDJPY/H1 research reference. This result does not reopen H05/H07/H08, authorize retuning, or unlock HOLDOUT/Candidate/DEMO/LIVE.

## 7. Known unknowns / authority ceiling

- Monte Carlo: NOT RUN.
- HOLDOUT: UNSPENT.
- Broker/install portability beyond this same-install R4 lineage: NOT RUN.
- `KINT-001`: OPEN.
- Numeric A/B/C/D mapping: UNRATIFIED; no grade assigned.
- No strategy/risk/default semantics changed.
- No optimization or adaptive repair was performed.

Next consumer: B16 research routing may treat execution-fidelity as not falsified for the frozen 14/30 parent, while keeping the 2020 weakness explicit. Any later Monte Carlo, HOLDOUT, Candidate, DEMO/LIVE or default-change step requires its own prospective contract and authority gate.
