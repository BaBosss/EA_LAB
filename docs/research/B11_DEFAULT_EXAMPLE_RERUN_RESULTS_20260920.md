# B11 Default Example Rerun — Final Results

Date: 2026-09-20
Status: EXECUTION_COMPLETE / PACKAGE_VALIDATED / PENDING_EXACT_HEAD_GPT_SCRUTINY / EXAMPLE_ONLY / NO_PROMOTION_AUTHORITY

Contract: `docs/research/B11_DEFAULT_EXAMPLE_RERUN_CONTRACT_20260920.md`
Prospective canonical contract head: `bd2d99e5c8beec809e2ab2f8cf5b94237d9803a3`
Evidence package: `factory/runs/b11_default_example_rerun_20260920/`

## 1. Purpose and lineage

This rerun repeats the prior B11 GridTrend example without changing any strategy, risk, symbol/TF, tester model, date window, deposit or leverage setting. Its direct purpose is to prove the complete EA Template conveyor after canonical MT5 report parser Repair4.

Accepted parser lineage:
- canonical parser source commit: `629d9bfaf9fa5e25c5721539ba149420c36233ca`;
- parser SHA256: `b2af79b9f694d1253137a559782db6f48a483a23a33caea7b68829f581e3b16b`;
- Repair4 GPT Scrutiny: **SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION**, findings 0;
- review SHA256: `8d25fc66054808c762fabd12bc919f6056cfd9e3305ccec81eecdaa7c5ef0826`.

B11 lineage:
- source SHA256: `59c51ad12ecc0450c19bffa373f836a95c0c3fe6808a2029fcc946f28c29f672`;
- full default-set SHA256: `5a0cdd3186e924234d4491bdf854966553214ebaaf03ca6793beaedd42ea8efa`;
- effective-config hash: `e092c814807e755d41a90c7ca4bf9dd06abc98f8145070db60f2749099848b2a`;
- fresh Build6090 receipt: `br-c9756db16758437a903c725976a5bd65`;
- fresh EX5 SHA256: `532d6bfe0ea679a5a783516646a7c75905d2f39b5fea93849a9277acb6e0ceee`;
- compile: **0 errors / 0 warnings**;
- prior Meta5b B11 EX5 SHA256: `0a6154996aaaf69de317d93dc0103408751318defc2ce2085e86e39957b95ff3`;
- test surface restored byte-for-byte after execution; Meta5b processes remaining = 0.

## 2. Frozen test contract

- example carrier: **XAUUSD/H1**, not B11 Home authority;
- Model1 / 1 Minute OHLC;
- deposit: USD 10,000;
- leverage: 1:100;
- Optimization=0;
- MAIN: 2023.01.01..2025.12.31;
- BWD: 2020.01.01..2022.12.31;
- HOLDOUT: **UNSPENT**;
- BWD ran regardless of MAIN result;
- no retune or optimization occurred.

Default entry/chassis remains FastMA=20, SlowMA=50, EMA, current TF, ATR14. The default grid-trend chassis retains fixed 0.01 first lot, no lot progression, 1.0 ATR grid step, ATR TP 3.0x, ATR SL 2.0x, Hedge OFF, and the existing protection cage. These are configuration facts for this example, not a recommended B11 Home.

## 3. Primary results

| Window | PF | Net | Trades | Equity DD maximal | History quality | Full window | Leverage |
|---|---:|---:|---:|---:|---:|---|---|
| MAIN 2023–2025 | **1.03** | **+696.95** | 2,822 | **1,878.51 / 18.63%** | 98% | PASS | MATCH 1:100 |
| BWD 2020–2022 | **0.89** | **-1,878.63** | 2,657 | **2,214.70 / 21.67%** | 99% | PASS | MATCH 1:100 |

Raw report SHA256:
- MAIN: `527391187527e1ef85b521564e4928f104db235da05e4bb1fcc548575703b72d`;
- BWD: `4eb6d4c19a7bc77b7c75878ba80c337790e8ee609ae8db5647fc05c1261ecc40`.

Corrected parser also binds:
- MAIN Symbols=1; Gross Profit=24,558.74; Gross Loss=-23,861.79; Balance DD Absolute=1,790.41; Equity DD Absolute=1,796.64; Balance DD Maximal=1,847.36 / 18.37%; Average profit/loss trade=21.32 / -14.29.
- BWD Symbols=1; Gross Profit=14,806.75; Gross Loss=-16,685.38; Balance DD Absolute=1,986.52; Equity DD Absolute=1,995.30; Balance DD Maximal=2,124.64 / 20.96%; Average profit/loss trade=14.66 / -10.13.

This resolves the prior package defect where space-separated thousands were parsed incorrectly.

## 4. Year distribution

The year split is derived from the same raw deal ledgers; no additional MT5 runs were used.

| Window | Year | PF | Net | Trades | Cycles |
|---|---:|---:|---:|---:|---:|
| MAIN | 2023 | 0.8828 | -590.76 | 952 | 225 |
| MAIN | 2024 | 0.8432 | -1,105.54 | 924 | 206 |
| MAIN | 2025 | 1.2033 | +2,393.25 | 946 | 183 |
| BWD | 2020 | 0.8850 | -715.52 | 840 | 189 |
| BWD | 2021 | 0.8304 | -847.49 | 869 | 222 |
| BWD | 2022 | 0.9422 | -315.62 | 948 | 223 |

Machine owner: `factory/runs/b11_default_example_rerun_20260920/year_split.csv`.

## 5. Grid and exposure evidence

The flat-to-nonflat-to-flat deal-ledger reconstruction reconciles report net profit, gross profit, gross loss, rounded PF and Total Trades for both windows.

| Diagnostic | MAIN | BWD |
|---|---:|---:|
| Max simultaneous positions | 3 | 3 |
| Max reconstructed basket depth | 3 | 3 |
| Max aggregate lots | 0.03 | 0.03 |
| Max entry-price span, price units | 260.97 | 159.54 |
| Full-window active-time share | 0.748601 | 0.749286 |

The nominal effective three-level lot ladder is 0.01 / 0.01 / 0.01 lots. Realized ATR-normalized spacing is not reconstructed because ATR varies through time; raw price-unit span is retained instead of inventing a normalized statistic.

## 6. Native visuals and traceability

Native MT5 assets are retained under:
- `factory/runs/b11_default_example_rerun_20260920/visuals/MAIN.png`
- `.../MAIN-holding.png`
- `.../MAIN-hst.png`
- `.../MAIN-mfemae.png`
- `.../BWD.png`
- `.../BWD-holding.png`
- `.../BWD-hst.png`
- `.../BWD-mfemae.png`
- deterministic workflow: `.../visuals/workflow.svg`.

The package also retains exact INIs, compressed raw reports, run logs, leverage/truncation sidecars, build receipt, compiler log, fresh EX5, parser outputs, year split and exposure diagnostics.

Package manifest:
- file count: **29**
- SHA256: `c1c28e9d50de0187cfb7637cbf7d3253c7eb773529e9269a594304571ea1d5fa`.

Author package validator: **PASS**.

## 7. Interpretation

The reporting/tooling objective is satisfied at author level: the same weak/negative strategy outcome is now represented consistently across raw MT5 HTML, canonical parser JSON, deal-ledger reconstruction, year split, exposure metrics and native graph assets.

Performance interpretation remains weak:
- MAIN is only PF 1.03 and aggregate-positive because 2025 offsets losses in 2023 and 2024.
- BWD is PF 0.89, net negative, and every BWD calendar year is negative.
- Therefore this fixed example configuration does not provide evidence for promotion.

Those observations do **not** establish that the whole B11 family is dead because XAUUSD/H1 was an explicitly hypothetical example carrier and no Home search/optimization contract exists in this scope.

## 8. Decision

- End-to-end rerun execution: **COMPLETE**.
- Parser/report plumbing: **AUTHOR-VALIDATED / PENDING EXACT-HEAD GPT SCRUTINY**.
- B11 family verdict: **NOT ASSIGNED**.
- Home ratification: **NO**.
- Candidate: **NO**.
- QUALITY_GRADE: **UNRATIFIED**.
- KINT: **OPEN**.
- Optimization: **NOT RUN**.
- Model4: **NOT RUN**.
- Monte Carlo: **NOT RUN**.
- HOLDOUT: **UNSPENT**.
- Runtime / deployment / DEMO / LIVE / trading: **NOT AUTHORIZED**.

Final package integration requires one independent exact-head GPT Scrutiny. A PASS closes the requested example loop as a truthful negative/weak strategy report with corrected parser provenance; it does not promote B11 or XAUUSD/H1.
