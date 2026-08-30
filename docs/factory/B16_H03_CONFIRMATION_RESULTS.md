# B16 H03 fixed-config confirmation results

`FACTORY-B16-H03-CONFIRMATION-PREREGISTRATION`
Status: **COMPLETE / RESEARCH-ONLY / NON-PROMOTIONAL**
Contract outcome: **`POSITION_ENGINE_DEPENDENT_OR_UNKNOWN`**

## Frozen identity and byte binding

This is a source-first decomposition of accepted H02 **lane 5B** bytes. No MT5 run,
optimization, HOLDOUT, tuning, rescale, source/set change, deployment, or trading
action occurred.

| Binding | MAIN | BWD |
|---|---|---|
| report | `LANEH02_5B_B16_XAUUSD_H4_MAIN_M1.htm` | `LANEH02_5B_B16_XAUUSD_H4_BWD_M1.htm` |
| report SHA256 | `aee6819ba12f929caade4cf1b70915978a3259ec2b7136a1009e077057bb0e7e` | `df63addd9975b66a9471aafe929d3b7f31377a95a93342cc6f1521728f07cff3` |
| INI SHA256 | `0e6f8e17a20d58b5d5319d3336572a0deb8b1716e572939936f0d22edbe3c322` | `775d2d4c50e33218c9526b9c5628decb1c207aeb3b584427a25e4ba3a640e172` |
| window | 2023-01-01..2025-12-31 | 2020-01-01..2022-12-31 |
| Expert / symbol / TF | `EALabTpl\Boss_16_KangarooGrid` / XAUUSD / H4 | same |
| Model / Optimization | 1 / 0 | 1 / 0 |
| deposit / currency / leverage | 10,000 / USD / 1:100 | same |
| effective TesterInputs SHA256 | `19013c650622e379551efff2cfa4ba6f860b37fff78c766b99621bd80f7e3272` | same |

The matching effective-input hash binds the complete B16-H01-r1 173/173
materialization, including its accepted 135/135 overlay assignments. H02
preregistration/source lineage remains `40b38ffafc5be5e34abc5070a57fa6049ed5b3b4` /
`cf32ba8d32a8292e8f7b5ad2ef766e3442b20125`. H02 pair matrix SHA256:
`d938d9d7b154226387cde12ef4571d179df00ee1c1a2dace2f626f873c944c47`.

The deterministic parser is `scripts/research/b16_h03/parse_h02_reports.py`.
Its source-bound output is `_mt5_auto/b16_h03/B16_H03_PARSED.json`, SHA256
`3639c9abcc8c299cf11ce1eb310ed9e721f43831870e213baafeb2e59f6a0fb6`.
Two consecutive parses yielded the same SHA256.

## Primary reconciliation

Convention: each closed `out` deal contributes `Profit + Swap + Commission`; report
`Total Trades` equals the closed out-deal count. This reproduces source totals without
synthetic trade merging.

| Cell | tickets | gross profit | gross loss | net | PF | source EqDD maximal | H02 check |
|---|---:|---:|---:|---:|---:|---:|---|
| MAIN | 79 | 937.26 | -229.48 | 707.78 | 4.0843 (4.08) | 636.50 (6.27%) | PASS: 4.08 / 79 / 6.27% |
| BWD | 148 | 1,674.76 | -1,162.07 | 512.69 | 1.4412 (1.44) | 873.12 (8.29%) | PASS: 1.44 / 148 / 8.29% |

`PRIMARY_RECONCILIATION = PASS`. Both reports are complete, identity-bound, and
remain PF > 1 at the full-window level.

## Fixed time decomposition

Completed cycles are assigned by end timestamp. GP/GL shares are closed-ticket gross
profit/loss shares of their complete window; active share is the sum of flat-to-flat
cycle durations divided by the full three-year duration.

| Bin | cycles | tickets | net | PF | GP share | GL share | active share |
|---|---:|---:|---:|---:|---:|---:|---:|
| MAIN 2023 | 18 | 37 | 277.38 | 3.28 | 42.59% | 53.07% | 3.27% |
| MAIN 2024 | 13 | 24 | 216.19 | 4.68 | 29.34% | 25.63% | 1.50% |
| MAIN 2025 | 11 | 18 | 214.21 | 5.38 | 28.07% | 21.30% | 0.39% |
| MAIN fold 1 (2023-01-01..2024-06-30) | 25 | 48 | 376.03 | 3.90 | 53.95% | 56.48% | 4.01% |
| MAIN fold 2 (2024-07-01..2025-12-31) | 17 | 31 | 331.75 | 4.32 | 46.05% | 43.52% | 1.15% |
| BWD 2020 | 20 | 35 | 213.76 | 2.08 | 24.60% | 17.07% | 1.78% |
| BWD 2021 | 22 | 64 | -84.78 | 0.90 | 45.22% | 72.47% | 7.29% |
| BWD 2022 | 28 | 49 | 383.71 | 4.16 | 30.17% | 10.47% | 3.37% |
| BWD fold 1 (2020-01-01..2021-06-30) | 32 | 59 | 501.18 | 3.32 | 42.85% | 18.62% | 3.17% |
| BWD fold 2 (2021-07-01..2022-12-31) | 38 | 89 | 11.51 | 1.01 | 57.15% | 81.38% | 9.27% |

Every required year and 18-month fold has completed-cycle participation. MAIN starts
2023-02-03 20:00:00 and ends 2025-12-30 03:49:40; BWD starts 2020-02-04 20:00:00 and
ends 2022-10-11 08:55:40.

## Direction, cycles, exposure

| Cell | direction | cycles / tickets | net / PF | GP / GL contribution |
|---|---|---:|---:|---|
| MAIN | BUY only | 42 / 79 | 707.78 / 4.08 | 100% / 100% |
| BWD | BUY only | 70 / 148 | 512.69 / 1.44 | 100% / 100% |

Cycles are source-supported flat-to-non-flat-to-flat transitions in the report's own
deal ledger; independently closed tickets were not merged. All observed entry lots
are 0.01, consistent with frozen `_16_BaseLot=0.01` and `_16_LadderMult=1.0`.

| Cell | max positions | max depth from L-comments | max lots | max entry span | cap contact | active share |
|---|---:|---:|---:|---:|---|---:|
| MAIN | 10 | 10 | 0.10 | 81.40 | YES | 3.88% |
| BWD | 8 | 8 | 0.08 | 111.44 | NO | 9.34% |

Contemporaneous ATR is absent, so ATR-normalized spans are `UNKNOWN`. Exit type is
`UNKNOWN` because exit comments do not identify it. No progressive ladder use is
observed or implied beyond the frozen flat-lot configuration.

## Concentration and DD/tail

| Cell | top profitable cycle | entries | net | GP share | top loss |
|---|---|---:|---:|---:|---|
| MAIN | #30, 2024-11-11 16:00:00..2024-11-18 18:00:40 | 7 | 63.91 | 12.26% | no net-losing cycle |
| BWD | #42, 2021-11-23 04:00:00..2021-12-16 17:02:40 | 11 | 72.06 | 7.68% | #33 net -343.59; 39.11% of gross loss |

No completed cycle breaches the >=50% single-cycle gross-profit concentration bound.
But multi-entry cycles contribute **79.80% MAIN** and **87.89% BWD** of respective
closed-ticket gross profit. Both exceed the contract's 50% position-engine condition.
MAIN also reaches depth/cap 10, though that cycle is not a >=50%-gross-profit source;
BWD reaches depth 8.

The source EqDD values are above. HTML tables provide no timestamped intratrade equity
or underwater series, so the maximum-EqDD interval and overlapping cycle(s) are
`UNKNOWN`; no image-based series was inferred. Secondary realized closed-cycle balance
DD is MAIN 0.00 and BWD 556.25 (peak 2021-06-04 15:32:40, trough
2021-08-09 04:28:40); it is not substituted for EqDD. Largest closed-ticket losses are
-38.20 MAIN and -102.13 BWD. Emergency/hard-kill attribution is `UNKNOWN`.

## Outcome and boundary

**`POSITION_ENGINE_DEPENDENT_OR_UNKNOWN`** is the sole H03 outcome. Contract
precedence applies: no mechanical failure occurred; mandatory primary diagnostics are
available; then the higher-precedence position-engine condition is met because
multi-entry cycles account for >=50% of gross profit in both windows.

`STRATEGY_QUALITY = NOT_REASSESSED_BY_H03`.

`EVIDENCE_CONFIDENCE`: high for identity, totals, ticket history, time participation,
direction, cycles, and observed depth/lots; limited for intratrade equity path, exit
classification, ATR normalization, and emergency-close attribution. MAIN's 79 trades
are evidence-confidence context only, not a universal floor or automatic failure.

Workflow pointer (explanatory only): `ea_template/Boss_16_KangarooGrid.mq5` ->
`ea_template/core/LabCore.mqh` -> `ea_template/core/entries/Entry_KangarooRSI.mqh` ->
`ea_template/core/entries/Kangaroo.mqh`.

This outcome does not meet the `CONFIRMED_DISTRIBUTED_PULSE` H04 gate. Any subsequent
mechanism/ablation work needs a new preregistered contract; H03 grants no optimization,
HOLDOUT, candidate, risk/default, deployment, DEMO, or LIVE authority.
