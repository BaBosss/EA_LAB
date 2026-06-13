# Optimization Gate Decision

Project: Gold SMC continuous  
Gate: Risk Cap v1 baseline retest  
Decision date: 2026-06-03

## Gate Decision

Optimization is not allowed yet.

Verdict: NEEDS LOGIC FIX v2

Reason: The submitted risk_cap_v1 retest did not run the patched Risk Cap v1 EA. The report is identical to the original baseline and does not include the new risk-cap inputs.

## Evidence

- Net profit is identical: 27,181.36 vs 27,181.36.
- Profit factor is identical: 1.448864 vs 1.448864.
- Max DD is identical: 12,074.24 (28.25%) vs 12,074.24 (28.25%).
- Total trades are identical: 706 vs 706.
- Largest loss is identical: -12,074.24 vs -12,074.24.
- Max lot is identical: 2.56 vs 2.56.
- The submitted risk-cap report does not show `InpMaxLotAbsolute`.
- The submitted risk-cap report does not show `InpRecoveryMultiplierMax`.
- The submitted risk-cap report does not show `InpMaxRecoverySteps`.
- Risk diagnostics files were not exported.

## Pass Criteria For The Next Retest

A real Risk Cap v1 retest may pass the optimization gate only if:

- Risk-cap inputs are visible in the MT5 report.
- Max lot used is <= 0.20.
- Max deposit load is <= 30% to 40%.
- Max DD is <= 20% to 25%.
- Largest loss is materially lower than -12,074.24.
- PF remains > 1.10.
- Trade count remains large enough for evaluation.
- Recovery steps never exceed 3.
- No hidden lot escalation bypasses the cap.
- `risk_cap_summary.txt` and `risk_cap_diagnostics.csv` are created.

## Blockers

Current blocker: invalid retest artifact.

The blocker is deployment/configuration, not optimization and not necessarily strategy edge. The set file alone cannot activate new inputs when MT5 loads an old `.ex5`.

## Deployment Fix Applied

The patched EA was copied and compiled into:

`C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\Gold_SMC_Continuous_MT5.ex5`

Compile result:

`Result: 0 errors, 0 warnings`

## Next Manual Test

Run one manual single test only, using the same symbol, timeframe, period, model, and set as the baseline retest.

Before pressing Start, open the Inputs tab and confirm:

- `InpMaxLotAbsolute = 0.20`
- `InpMaxDepositLoadPercent = 30.0`
- `InpStopNewEntriesWhenDDPercent = 15.0`
- `InpCloseAllWhenDDPercent = 25.0`
- `InpMaxRecoverySteps = 3`
- `InpRecoveryMultiplierMax = 1.3`

After the test, export the HTML report and check that the report contains those inputs.

## Final Gate Status

Optimization gate: CLOSED

Reason: no valid Risk Cap v1 performance result exists yet.
