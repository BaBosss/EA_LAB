# Boss11-16 H01 Fixed-Baseline Results — 2026-08-29

Status: COMPLETE / MECHANICAL PASS / STRATEGY EVIDENCE RECORDED
Authority: NON_AUTHORITATIVE_SIDECAR
Canonical Factory source: `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125`

## Frozen tester contract

- Logical/actual symbol: `XAUUSD` / `XAUUSD`
- Timeframe: `H1`
- Model: `1`
- Deposit / leverage: `10000` / `1:100`
- MAIN: `2023.01.01..2025.12.31`
- BWD: `2020.01.01..2022.12.31`
- Meta5b lane: B16 then B12
- Meta5c lane: B11 then B13 then B15
- HOLDOUT 2026H1: UNSPENT
- Optimization: NONE

## Clean full-window evidence

| H01 | MAIN PF | MAIN trades | MAIN net | MAIN eqDD | BWD PF | BWD trades | BWD net | BWD eqDD |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| B11 | 1.02 | 2822 | 529.17 | 19.57% | 0.88 | 2657 | -2031.99 | 22.88% |
| B12 | 0.95 | 965 | -399.07 | 7.72% | 0.92 | 929 | -446.56 | 6.25% |
| B13 | 0.91 | 1257 | -1018.16 | 13.49% | 0.90 | 1126 | -690.74 | 9.26% |
| B15 | 0.99 | 778 | -94.81 | 7.44% | 0.89 | 731 | -490.77 | 7.81% |
| B16 | 1.49 | 426 | 1433.64 | 10.95% | 0.96 | 505 | -216.70 | 21.11% |

All ten cells passed build/config identity, exact-symbol preflight, fresh-report checks, and truncation/full-window eligibility. History quality was 98% MAIN and 99% BWD for every family.

B16 required a tester-only full-surface materialization because its frozen regression baseline contains 134 physical assignments while the current build exposes 173 inputs. Canonical `gen_default_preset.py` materialized compile defaults without changing the 135 effective overlay assignments used by the first-green package: preserved 135/135, mismatch 0. Full tester set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.

## Interpretation / routing

Mechanical acceptance is PASS: the evidence is attributable and full-window eligible. This does not mean strategy promotion. Every H01 has BWD PF below 1.0; B12/B13/B15 are also below 1.0 on MAIN. B11 has only a marginal MAIN PF 1.02 and B16 has the strongest MAIN pulse at PF 1.49, but both fail BWD profitability. Therefore this fixed-baseline batch creates no automatic optimization, candidate selection, HOLDOUT, DEMO/LIVE, risk/default, or deployment continuation.

B14 and B17 remain reference molds only. B18 remains PARKED/fail-closed until the owner chooses `_18_DirMode=1` versus `2`; this result batch does not make that semantic decision.

## Evidence locations

- `D:\EA_LAB_CONTROL\handoffs\LANE_H_H01_RESULTS_5B_cf32ba8d_CLEAN.jsonl`
- `D:\EA_LAB_CONTROL\handoffs\LANE_H_H01_RESULTS_5C_cf32ba8d_CLEAN.jsonl`
- Reports: reviewed `cf32ba8d` worktree `_mt5_auto/reports/LANEH5B_*_CLEAN.htm` and `LANEH5C_*_CLEAN.htm`
