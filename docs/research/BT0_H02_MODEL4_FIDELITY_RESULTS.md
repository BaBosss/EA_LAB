# BT0 - H02 Pulse Model-4 Execution-Fidelity Results

Status: `BLOCKED`
Blocker class: `E OWNER/EXTERNAL`
Canonical base SHA: `b26af204faf7907fe7e78a2b5f90a5dfa8c6bc02`
Execution: `0/12`
HOLDOUT: `UNSPENT`
Optimization: `NONE`

## Mechanical result

Both requested runtime preflights fail the current canonical execution contract before any Strategy Tester launch. Canonical `AGENTS.md` requires Model 4 to be serial on MT5 lane1 (`D:\Meta 5`) and prohibits Model 4 on Meta5c; the BT-20260830 owner scope explicitly forbids using `D:\Meta 5`. No report was generated and no stale report was reused.

`D:\Meta 5` had an existing `terminal64.exe` process during boot inspection and was not stopped, killed, attached to, or reused. Meta5b/Meta5c had no observed terminal process at that inspection, but process availability does not override the canonical Model-4 policy.

## Requested 12-cell output

`N/R = NOT_RUN`; `N/A = not applicable because no Model-4 report exists`.

| EA | symbol | TF | window | Model | PF | trades | net | EqDD% | quality | truncated? | full-window eligible? | report SHA256 | config identity | runtime lane |
|---|---|---|---|---:|---:|---:|---:|---:|---|---|---|---|---|---|
| B16 | XAUUSD | H4 | MAIN | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B16-H01-r1 / full tester set SHA256 7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782 / effective TesterInputs SHA256 19013c650622e379551efff2cfa4ba6f860b37fff78c766b99621bd80f7e3272` | BT-A Meta5b - BLOCKED(E) |
| B16 | XAUUSD | H4 | BWD | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B16-H01-r1 / full tester set SHA256 7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782 / effective TesterInputs SHA256 19013c650622e379551efff2cfa4ba6f860b37fff78c766b99621bd80f7e3272` | BT-A Meta5b - BLOCKED(E) |
| B16 | USDJPY | H1 | MAIN | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B16-H01-r1 / full tester set SHA256 7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782 / effective TesterInputs SHA256 19013c650622e379551efff2cfa4ba6f860b37fff78c766b99621bd80f7e3272` | BT-A Meta5b - BLOCKED(E) |
| B16 | USDJPY | H1 | BWD | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B16-H01-r1 / full tester set SHA256 7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782 / effective TesterInputs SHA256 19013c650622e379551efff2cfa4ba6f860b37fff78c766b99621bd80f7e3272` | BT-A Meta5b - BLOCKED(E) |
| B16 | XAUUSD | M15 | MAIN | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B16-H01-r1 / full tester set SHA256 7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782 / effective TesterInputs SHA256 19013c650622e379551efff2cfa4ba6f860b37fff78c766b99621bd80f7e3272` | BT-A Meta5b - BLOCKED(E) |
| B16 | XAUUSD | M15 | BWD | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B16-H01-r1 / full tester set SHA256 7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782 / effective TesterInputs SHA256 19013c650622e379551efff2cfa4ba6f860b37fff78c766b99621bd80f7e3272` | BT-A Meta5b - BLOCKED(E) |
| B15 | GBPUSD | H4 | MAIN | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B15-H01-r1 / proposed set SHA256 ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c` | BT-B Meta5c - BLOCKED(E) |
| B15 | GBPUSD | H4 | BWD | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B15-H01-r1 / proposed set SHA256 ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c` | BT-B Meta5c - BLOCKED(E) |
| B13 | XAUUSD | M15 | MAIN | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B13-H01-r1 / proposed set SHA256 65f3d4287effd5cf821bac6fff5f123eb17430608f32e9bfa5853216d053d9a6` | BT-B Meta5c - BLOCKED(E) |
| B13 | XAUUSD | M15 | BWD | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B13-H01-r1 / proposed set SHA256 65f3d4287effd5cf821bac6fff5f123eb17430608f32e9bfa5853216d053d9a6` | BT-B Meta5c - BLOCKED(E) |
| B13 | GBPUSD | H4 | MAIN | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B13-H01-r1 / proposed set SHA256 65f3d4287effd5cf821bac6fff5f123eb17430608f32e9bfa5853216d053d9a6` | BT-B Meta5c - BLOCKED(E) |
| B13 | GBPUSD | H4 | BWD | 4 | N/R | N/R | N/R | N/R | N/A | N/A | N/A | N/R | `B13-H01-r1 / proposed set SHA256 65f3d4287effd5cf821bac6fff5f123eb17430608f32e9bfa5853216d053d9a6` | BT-B Meta5c - BLOCKED(E) |

## Accepted Model-1 comparison baseline

These values are accepted H02 evidence and were not rerun.

| EA | symbol | TF | MAIN PF / trades / EqDD% | BWD PF / trades / EqDD% |
|---|---|---|---|---|
| B16 | XAUUSD | H4 | 4.08 / 79 / 6.27% | 1.44 / 148 / 8.29% |
| B16 | USDJPY | H1 | 1.53 / 275 / 3.85% | 1.11 / 267 / 2.40% |
| B16 | XAUUSD | M15 | 1.25 / 1577 / 11.88% | 1.10 / 1463 / 14.86% |
| B15 | GBPUSD | H4 | 1.10 / 214 / 0.97% | 1.07 / 218 / 1.83% |
| B13 | XAUUSD | M15 | 1.06 / 3929 / 6.32% | 1.02 / 3300 / 3.72% |
| B13 | GBPUSD | H4 | 1.05 / 256 / 1.63% | 1.02 / 272 / 2.65% |

## EVIDENCE

- Boot resolved pushed `origin/master` to the preregistered base SHA `b26af204faf7907fe7e78a2b5f90a5dfa8c6bc02`.
- Current canonical `AGENTS.md` makes Model 4 a serial lane1-only activity and explicitly says Meta5c must never run Model 4.
- BT-20260830 owner scope forbids use of `D:\Meta 5` / lane1.
- No Model-4 cell was launched; no report exists for BT0.
- Accepted H02 Model-1 numbers remain the only performance evidence for these six pairs.
- B16 H03 remains accepted as `POSITION_ENGINE_DEPENDENT_OR_UNKNOWN`; BT0 did not reassess it.

## INTERPRETATION

The execution-fidelity question remains unanswered. This is a runtime/governance compatibility blocker, not evidence that any strategy failed Model 4. The absence of a legal runtime cannot be converted into PF, quality, truncation, full-window eligibility, or strategy verdict data.

## DECISION

`BT0 = BLOCKED(E)` until a prospective owner/canonical resolution provides a legal Model-4 runtime without violating the current `D:\Meta 5` prohibition. Do not reroute to Meta5b/Meta5c, do not use `-Force`, and do not alter Model, config, dates, or strategy semantics to manufacture a runnable substitute.

No optimizer, HOLDOUT, Candidate, DEMO/LIVE, deployment, risk/default, KINT, or grade authority is created.
