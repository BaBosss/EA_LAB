# OOS Acceptance Rules

Project: Gold SMC continuous  
Candidate lock: run_004 / optimizer pass 1568  
Current lifecycle status: IS_VALIDATED -> OOS_PENDING

## Rule Priority

These rules are evaluated in order:

1. Same-set validation
2. Risk-cap validation
3. Absolute pass/fail thresholds
4. Degradation vs IS
5. Portfolio/correlation readiness

Failure at a higher-priority rule blocks deployment even if lower-priority metrics look good.

## Same-Set Validation

Every OOS report must show the same input signature as `run_004`.

Hard fail if any of these happen:

- The report does not show `Gold_SMC_Continuous_MT5_RiskCapV1`.
- The report does not show the risk-cap inputs.
- Any locked input differs from the values in `oos_validation_plan.md`.
- The OOS was run as an optimization.
- The EA source or compiled binary was changed after `run_004` without restarting validation from IS.
- The `.set` file used for OOS is not the exact file archived from `run_004`.

## Absolute Acceptance Thresholds

Each completed OOS run must meet:

| Metric | Pass threshold | Hard fail threshold |
|---|---:|---:|
| Profit factor | >= 1.15 | < 1.10 |
| Equity DD | <= 15.00% preferred | > 18.00% |
| Recovery factor | >= 1.50 | < 1.00 |
| Sharpe ratio | >= 1.20 | < 0.80 |
| Net profit | > 0 | <= 0 |
| Minimum trades, OOS_1 | >= 220 | < 160 |
| Minimum trades, OOS_2 | >= 220 | < 160 |
| Minimum trades, OOS_3 | >= 75 for 2026.06.02-2026.09.30 | < 50 |

If OOS_3 does not have enough calendar time to reach 75 trades, keep the candidate in OOS_PENDING and extend the forward holdout. Do not loosen parameters to generate trades.

## Degradation vs IS

IS reference:

| Metric | IS value |
|---|---:|
| Profit factor | 1.310 |
| Recovery factor | 3.219 |
| Sharpe ratio | 3.146 |
| Equity DD | 12.38% |
| Trades | 479 |

Acceptable degradation:

| Metric | Acceptable OOS behavior |
|---|---|
| PF | May degrade to 1.15, but aggregate OOS PF should be >= 1.20 |
| Recovery | May degrade up to 50% vs IS, but must stay >= 1.50 |
| Sharpe | May degrade up to 60% vs IS, but must stay >= 1.20 |
| DD | May increase vs IS, but must stay <= 15.00% preferred and never > 18.00% |
| Trades | May be lower by period length, but trade rate should not collapse below 65% of IS trade rate |
| Profit | Monthly profit can degrade by up to 60% vs IS if PF/DD remain acceptable |

Trade-rate reference:

- IS trades: 479
- IS period: 2025.01.01 to 2026.06.01
- Approximate IS trade rate: 28 trades/month
- OOS minimum effective trade rate: about 18 trades/month

## Aggregate OOS Pass Criteria

The candidate reaches OOS_PASSED only if:

- OOS_1 passes.
- OOS_2 passes.
- OOS_3 passes, or OOS_3 remains pending only because not enough post-selection data exists.
- Aggregate OOS PF across completed OOS windows is >= 1.20.
- No completed OOS window has equity DD > 18.00%.
- At least two completed OOS windows have equity DD <= 15.00%.
- No run shows uncapped lot behavior, disabled risk caps, or hidden risk expansion.

## Watch Conditions

Mark as WATCH, not pass, if:

- PF is 1.10 to 1.15.
- Equity DD is 15.00% to 18.00%.
- Recovery is 1.00 to 1.50.
- Trade count is below pass threshold but above hard-fail threshold.
- One OOS period passes only because of one unusually large profit cluster.
- Correlation with an existing XAUUSD EA is high enough to create concentration risk.

WATCH requires another OOS/forward window. Do not move to live from WATCH.

## Hard Fail Conditions

Reject the candidate for deployment if any OOS run has:

- PF < 1.10.
- Net profit <= 0.
- Equity DD > 18.00%.
- Recovery factor < 1.00.
- Risk cap fields missing or changed.
- Max lot above `InpMaxLotAbsolute`.
- Deposit load above `InpMaxDepositLoadPercent`.
- Close-all DD cap not enforced when reached.
- Manual parameter changes.
- Optimization performed during OOS.

## Lifecycle Status Rules

| Status | Allowed action |
|---|---|
| IS_VALIDATED | Prepare OOS only |
| OOS_PENDING | Run OOS single tests only |
| OOS_PASSED | Prepare forward/demo test only |
| FORWARD_PENDING | Run forward/demo with unchanged set |
| LIVE_MICRO | Tiny live only; no risk increase |
| LIVE_APPROVED | Controlled deployment after micro-live evidence |

Status transitions:

- IS_VALIDATED -> OOS_PENDING: OOS plan and run matrix created.
- OOS_PENDING -> OOS_PASSED: OOS rules pass.
- OOS_PENDING -> REJECTED: any hard fail occurs.
- OOS_PASSED -> FORWARD_PENDING: forward/demo plan starts.
- FORWARD_PENDING -> LIVE_MICRO: forward/demo passes with unchanged set and acceptable correlation.
- LIVE_MICRO -> LIVE_APPROVED: micro-live monitoring passes without DD/risk-cap breach.

## Next Workflow After OOS

If OOS passes:

1. Build a combined OOS metrics table.
2. Extract monthly PnL from each OOS report.
3. Recompute correlation against the active EA shortlist.
4. Run a forward/demo phase with the exact same set file.
5. Move to LIVE_MICRO only after forward pass.
6. Keep risk caps fixed; do not increase risk after a good OOS result.

