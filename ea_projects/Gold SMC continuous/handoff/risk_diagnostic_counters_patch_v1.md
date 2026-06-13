# Risk Diagnostic Counters Patch v1

Project: Gold SMC continuous  
EA: `Gold_SMC_Continuous_MT5_RiskCapV1`  
Version: 27.12  
Scope: diagnostics only

## Status

COMPILE PASS

Compile result:

`Result: 0 errors, 0 warnings`

Compile log:

`Gold_SMC_Continuous_MT5_RiskCapV1_diagnostic_counters_compile.log`

## Files Changed

- `Gold_SMC_Continuous_MT5_RiskCapV1.mq5`
- `Gold_SMC_Continuous_MT5_RiskCapV1.ex5`
- `handoff/risk_diagnostic_counters_patch_v1.md`

The patched EX5 was also deployed to the MT5 Experts folder:

`C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\Gold_SMC_Continuous_MT5_RiskCapV1.ex5`

## Counters Fixed

Event counters now increment only when the EA transitions into a state.

Active tick counters separately track how long that state persisted.

Code comment added:

`Event counters count transition into a state. Active tick counters count how long the state persisted.`

## Old Names vs New Names

| Old ambiguous counter | New event counter | New duration counter |
|---|---|---|
| `number_of_times_close_all_triggered` | `close_all_event_count` | `close_all_active_ticks` |
| `number_of_times_new_entry_blocked_by_dd` | `stop_new_entries_event_count` | `stop_new_entries_active_ticks` |
| `daily_loss_stop_count` | `daily_loss_stop_event_count` | `daily_loss_active_ticks` |
| `cooldown_block_count` | `cooldown_event_count` | `cooldown_active_ticks` |
| `number_of_times_recovery_blocked` | `recovery_block_event_count` | not exported |
| `number_of_times_lot_capped` | `lot_cap_event_count` | not exported |

## Export Schema Updated

Updated files produced by EA after a test:

- `risk_cap_summary.txt`
- `risk_cap_diagnostics.csv`

New CSV columns:

- `max_lot_used`
- `max_deposit_load`
- `max_floating_dd_percent`
- `recovery_steps_used`
- `close_all_event_count`
- `stop_new_entries_event_count`
- `daily_loss_stop_event_count`
- `cooldown_event_count`
- `recovery_block_event_count`
- `lot_cap_event_count`
- `close_all_active_ticks`
- `stop_new_entries_active_ticks`
- `daily_loss_active_ticks`
- `cooldown_active_ticks`

## Manual Retest

Manual retest is required to validate the new diagnostic schema because EA_LAB production runs currently use manual MT5 run import for this project.

Use the same baseline setup as run_002:

- Expert: `Gold_SMC_Continuous_MT5_RiskCapV1`
- Symbol: XAUUSD
- Timeframe: H1
- Period: 2025-01-01 to 2026-06-01
- Set: Risk Cap v1
- No optimization

Expected result:

Event counters should be small, while active tick counters may be large if a state persists.
