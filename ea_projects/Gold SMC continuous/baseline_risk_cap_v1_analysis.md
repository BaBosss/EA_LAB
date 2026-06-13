# Baseline Risk Cap v1 Analysis - Gold SMC continuous

## Status

**PATCHED AND COMPILED - MANUAL SINGLE TEST REQUIRED**

Risk Cap Patch v1 has been applied to the EA and compiled successfully. No optimization was run. A valid old-vs-new performance comparison requires a manual MT5 single test from the user's working MT5 tester context using `set/risk_cap_v1.set`.

## Compile Result

- Source: `Gold_SMC_Continuous_MT5.mq5`
- Version: `27.10`
- Compile result: `0 errors, 0 warnings`
- Output: `Gold_SMC_Continuous_MT5.ex5`

## Risk Caps Added

| Risk Cap | Value |
|---|---:|
| `InpMaxLotAbsolute` | 0.20 |
| `InpMaxDepositLoadPercent` | 30.0 |
| `InpMaxFloatingDDPercent` | 20.0 |
| `InpMaxDailyLossPercent` | 5.0 |
| `InpMaxRecoverySteps` | 3 |
| `InpRecoveryMultiplierMax` | 1.3 |
| `InpStopNewEntriesWhenDDPercent` | 15.0 |
| `InpCloseAllWhenDDPercent` | 25.0 |
| `InpOneRecoveryChainAtATime` | true |
| `InpBlockNewCycleAfterLoss` | true |
| `InpCooldownBarsAfterStop` | 20 |

## Enforcement Summary

- Lot size is capped and normalized before order send.
- Projected deposit load is checked before order send.
- New entries and recovery entries are blocked when floating DD reaches the stop-new-entry threshold.
- All EA positions are closed and cooldown starts when floating DD reaches the hard close threshold.
- Effective recovery multiplier is capped by `InpRecoveryMultiplierMax`.
- Recovery depth is capped by `InpMaxRecoverySteps`.
- New cycles are blocked during cooldown after a closed loss.
- Daily loss threshold closes all EA positions and starts cooldown.
- Risk diagnostics are exported on `OnDeinit`.

## Diagnostics Output

After the manual Strategy Tester run, the EA writes:

- `risk_cap_diagnostics.csv`
- `risk_cap_summary.txt`

The files are written to the MT5 common Files folder reported in the tester log by `RISK_CAP_SUMMARY`.

Tracked fields:

- `max_lot_used`
- `max_deposit_load`
- `max_floating_dd_percent`
- `recovery_steps_used`
- `number_of_times_new_entry_blocked_by_dd`
- `number_of_times_close_all_triggered`
- `number_of_times_lot_capped`
- `number_of_times_recovery_blocked`
- `daily_loss_stop_count`
- `cooldown_block_count`

## Old vs New Comparison

| Metric | Old Baseline | Risk Cap v1 |
|---|---:|---:|
| Net profit | 27,181.36 | Pending manual test |
| Profit factor | 1.45 | Pending manual test |
| Max DD | ~28% | Pending manual test |
| Max deposit load | 92.53% | Pending manual test |
| Max lot | 2.56 | capped at 0.20 by code; verify in report |
| Largest loss | -12,074.24 | Pending manual test |
| Trades | 706 | Pending manual test |
| Recovery behavior | uncontrolled multiplier recovery | capped recovery depth, capped lot, capped multiplier |
| Equity curve quality | profitable but jumpy and recovery-driven | Pending manual test |

## Decision Rule For Manual Result

If the manual risk-cap v1 run shows:

- PF remains above 1.10
- max DD is <= 20-25%
- deposit load is <= 30-40%
- max lot is <= 0.20
- largest loss is materially reduced

then verdict becomes **OPTIMIZATION CANDIDATE**.

Otherwise verdict remains **NEEDS LOGIC FIX v2**.

## Current Verdict

**PENDING MANUAL TEST**

Optimization is still blocked until the risk-cap v1 manual baseline report is imported and analyzed.
