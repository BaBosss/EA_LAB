# B16 USDJPY/H1 R4 Swap-Credit Accounting Attribution

Status: `PASS / RESEARCH_ONLY / ZERO_NEW_MT5`
Hypothesis: `HYP-Q09R2-B16-SWAPCREDIT-01`.
Author base: `e3254868d482096a009e38c81c80ebae96a64207`; device: BaBoss; branch: `codex/b16-swapcredit-20260912`.
Preregistration: `docs/research/B16_USDJPY_H1_R4_SWAPCREDIT_PREREG_20260912.md`.

## Evidence

Frozen parent: Boss16 KangarooGrid / USDJPY H1 / BUY RSI 14/30 / B16-R4-r1.
All four reports belong to the same `D:\Meta 5` / `MT5-lane1` installation lineage.
MAIN: 2023-01-01..2025-12-31; BWD: 2020-01-01..2022-12-31. Currency: USD.
Source reports are independently SHA256-checked against the preregistered pins and accepted integrity/receipts.
The accepted summary, receipts and runtime preflight are hash-bound to the accepted integrity owner.
A PASS requires native-net reconciliation using Decimal cents against Profit + Swap + Commission, report net, accepted net and the existing parser.
Every deal balance, final ledger totals, ticket count and flat-to-flat episode membership must reconcile.
The only transform is `adjusted_deal_net = native_deal_net - max(swap, 0)` for realized out-deals.
Negative swap debits and every non-swap cashflow remain. Unsupported rows fail closed.

| Cell | Native net | Signed swap | Positive credits removed | Negative debits retained | Adjusted net | Tickets / cycles |
|---|---:|---:|---:|---:|---:|---:|
| M1_MAIN | 255.30 | 47.69 | 47.69 | 0.00 | 207.61 | 275 / 239 |
| M1_BWD | 50.22 | 65.20 | 65.20 | 0.00 | -14.98 | 267 / 243 |
| M4_MAIN | 187.32 | 48.75 | 48.75 | 0.00 | 138.57 | 273 / 238 |
| M4_BWD | 74.73 | 66.60 | 66.60 | 0.00 | 8.13 | 262 / 236 |

Adjustment amount is the negative of the positive-credit column; adjustment sign is NEGATIVE when credits exist and ZERO otherwise.
For eligible cells, native equity drawdown is retained as source evidence only. Adjusted EqDD is NOT CALCULATED: no adjusted equity path exists.

### Calendar-year attribution

Cashflows are assigned by source deal booking year. Cycle counts use final out-deal year.
The JSON also provides the accepted parser's episode-close-year attribution, keeping cross-year episodes intact.

| Cell | Year | Native net | Signed swap | Positive credits | Negative debits | Adjusted net | Tickets / cycles closed |
|---|---:|---:|---:|---:|---:|---:|---:|
| M1_MAIN | 2023 | 137.79 | 6.93 | 6.93 | 0.00 | 130.86 | 104 / 96 |
| M1_MAIN | 2024 | 55.39 | 13.22 | 13.22 | 0.00 | 42.17 | 90 / 75 |
| M1_MAIN | 2025 | 62.12 | 27.54 | 27.54 | 0.00 | 34.58 | 81 / 68 |
| M1_BWD | 2020 | -40.91 | 30.50 | 30.50 | 0.00 | -71.41 | 98 / 90 |
| M1_BWD | 2021 | 57.24 | 10.84 | 10.84 | 0.00 | 46.40 | 76 / 75 |
| M1_BWD | 2022 | 33.89 | 23.86 | 23.86 | 0.00 | 10.03 | 93 / 78 |
| M4_MAIN | 2023 | 121.08 | 6.93 | 6.93 | 0.00 | 114.15 | 104 / 96 |
| M4_MAIN | 2024 | 44.29 | 13.22 | 13.22 | 0.00 | 31.07 | 90 / 75 |
| M4_MAIN | 2025 | 21.95 | 28.60 | 28.60 | 0.00 | -6.65 | 79 / 67 |
| M4_BWD | 2020 | -35.06 | 30.60 | 30.60 | 0.00 | -65.66 | 96 / 87 |
| M4_BWD | 2021 | 50.95 | 10.93 | 10.93 | 0.00 | 40.02 | 73 / 72 |
| M4_BWD | 2022 | 58.84 | 25.07 | 25.07 | 0.00 | 33.77 | 93 / 77 |

### Unchanged native descriptors

| Cell | PF | Native relative EqDD % | Max depth | Max aggregate lots | Accepted active-time share | Native multi-entry gross-profit share |
|---|---:|---:|---:|---:|---:|---:|
| M1_MAIN | 1.54 | 3.85 | 7 | 0.07 | 0.216654 | 0.744896 |
| M1_BWD | 1.13 | 2.38 | 5 | 0.05 | 0.239127 | 0.681276 |
| M4_MAIN | 1.38 | 3.91 | 7 | 0.07 | 0.216884 | 0.76476 |
| M4_BWD | 1.2 | 2.29 | 5 | 0.05 | 0.241405 | 0.731543 |

For eligible cells, these descriptors retain their accepted definitions and values; they are not recomputed from adjusted cashflows.
For eligible cells, every episode in the JSON retains source deal IDs, start/end, duration, position/depth/lot/span descriptors and both accounting totals.
No price, volume, order, holding period, entry/exit, grid, sizing, risk or execution mechanism changes.

### Source identities

- M1_MAIN: `factory/runs/b16_r4_20260902/usdjpy_buy_h1/runtime/M1_MAIN/report.htm`; expected SHA256 `a329cc1fed28a98926ef38a07c05750c31d1f47dfd568dd31ac95d38fae64aa0`; observed `a329cc1fed28a98926ef38a07c05750c31d1f47dfd568dd31ac95d38fae64aa0`.
- M1_BWD: `factory/runs/b16_r4_20260902/usdjpy_buy_h1/runtime/M1_BWD/report.htm`; expected SHA256 `327e6c9be6ea8569275c7c9a066043ce22e6e6ce1e9590b5cb4b3714cc98bc2a`; observed `327e6c9be6ea8569275c7c9a066043ce22e6e6ce1e9590b5cb4b3714cc98bc2a`.
- M4_MAIN: `factory/runs/b16_r4_20260902/usdjpy_buy_h1/runtime/M4_MAIN/report.htm`; expected SHA256 `03c00a3fe1c61b43aa6d613418dd0973908c83a628ca0c101902fcf2d9984117`; observed `03c00a3fe1c61b43aa6d613418dd0973908c83a628ca0c101902fcf2d9984117`.
- M4_BWD: `factory/runs/b16_r4_20260902/usdjpy_buy_h1/runtime/M4_BWD/report.htm`; expected SHA256 `7561815ec2fa094176fa1b324a723c96a16dac8f22e74e2411d1503ab0ba85ed`; observed `7561815ec2fa094176fa1b324a723c96a16dac8f22e74e2411d1503ab0ba85ed`.

Machine-readable evidence, receipt/build/set/EX5 identities and source hashes: `factory/runs/b16_r4_offline_20260912/swapcredit/result.json`.
Accepted R4 reference: `docs/research/B16_USDJPY_H1_R4_EXECUTION_FIDELITY_RESULTS.md`.

## Interpretation

Classification: `CREDIT_INDEPENDENT_POSITIVE_NET_FALSIFIED_ON_RECORDED_LEDGER`.
Credit-independent-positive-net claim falsified: `TRUE`.
Full-window adjusted net <= 0 in: M1_BWD.
This is accounting attribution on the recorded trading path, not a zero-swap strategy, broker-swap counterfactual or new execution-fidelity test.

## Decision and limitations

Deliver this bounded diagnostic for normal review and B16 robustness triage; stop at the four frozen reports.
HOLDOUT: UNSPENT. New MT5 cells: 0. Optimization, Monte Carlo and broker portability: NOT RUN.
No alternate transformation, tuning, source-evidence rewrite, EA/core/runtime/configuration change or native EqDD recalculation.
No risk/default, runtime, deployment, trading, Candidate, Grade or KINT authority; KINT remains unresolved and no grade is assigned.
Accepted native active-time/concentration descriptors retain historical parser conventions; this task does not reinterpret them.
Lesson and next consumer are limited to observed recorded-ledger credit dependence; any follow-up experiment needs its own contract.
Author output is not an independent review, project-state update, or push authorization.

## Reproduction and gates

Use canonical portable Python through `scripts/use_python.ps1`; pass `-B` to avoid repository bytecode caches.
Run `python -B scripts/research/b16_r4_offline/test_analyze_swap_credit.py`, then
`python -B scripts/research/b16_r4_offline/analyze_swap_credit.py --write-result`.
Without `--write-result`, the analyzer emits JSON to stdout and writes no evidence files.
Required author gates: focused fixtures, four-source analyzer/reconciliation, deterministic output, py_compile, git diff --check, strict state check and normal commit hooks.
The author handoff reports actual gate outcomes; this generated report does not self-attest hook or independent-review success.
