# Risk Cap v1 Retest Review

Project: Gold SMC continuous  
Mode: Manual single-test retest after Risk Cap Patch v1  
Optimization status: Not optimized

## Verdict

NEEDS LOGIC FIX v2

The submitted risk_cap_v1 retest is not a valid risk-cap evaluation. The original baseline and the risk-cap report are metric-identical, and the risk-cap report does not show the new Risk Cap v1 inputs. This means MT5 almost certainly ran the old Expert Advisor binary, not the patched v27.10 build.

## Deployment Finding

The issue is not the set file. The issue is the EA binary loaded by Strategy Tester.

- Project patched EX5: `C:\Users\patip\OneDrive\.Codex\EA_LAB\ea_projects\Gold SMC continuous\Gold_SMC_Continuous_MT5.ex5`
- Manual MT5 Experts path: `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\Gold_SMC_Continuous_MT5.ex5`
- The manual retest report did not contain `InpMaxLotAbsolute`, `InpRecoveryMultiplierMax`, or `InpMaxRecoverySteps`.
- No `risk_cap_summary.txt` or `risk_cap_diagnostics.csv` was produced in MT5 Common Files.

The patched EA has now been copied and compiled into the manual MT5 Experts folder. Compile log result: 0 errors, 0 warnings.

## Original vs Submitted Risk Cap v1

| Metric | Original baseline | Submitted risk_cap_v1 | Change |
|---|---:|---:|---:|
| Net profit | 27,181.36 | 27,181.36 | 0.00 |
| Profit factor | 1.448864 | 1.448864 | 0 |
| Expected payoff | 38.50051 | 38.50051 | 0 |
| Max balance DD | 12,074.24 (28.25%) | 12,074.24 (28.25%) | 0 |
| Max equity DD | 7,868.09 (22.44%) | 7,868.09 (22.44%) | 0 |
| Recovery factor | 3.454633 | 3.454633 | 0 |
| Total trades | 706 | 706 | 0 |
| Win rate | 73.23% | 73.23% | 0 |
| Average holding | 18:26:38 | 18:26:38 | 0 |
| Largest loss | -12,074.24 | -12,074.24 | 0 |
| Max lot used | 2.56 | 2.56 | 0 |
| Lots >= 1.00 | 15 | 15 | 0 |
| Max recovery cycle entries | 11 | 11 | 0 |

## Risk Structure

Risk did not improve materially in the submitted retest because the cap logic was not present in the tested binary.

The same unsafe features remain visible:

- Max lot reached 2.56 despite the intended cap of 0.20.
- Largest loss remained -12,074.24.
- Max balance DD remained 28.25%.
- Max deposit load risk remains unresolved from the original baseline.
- Recovery chains still expanded beyond the intended cap.
- Equity quality remains dependent on recovery behavior and large-cycle survival.

## Hidden Martingale / Recovery Dependency

The submitted retest still shows recovery-chain behavior consistent with the original baseline:

- Lot escalation reached 2.56.
- At least 15 entry deals used lot size >= 1.00.
- Recovery cycles reached up to 11 entries.
- A small number of large trades dominate both upside and downside.

This is not acceptable for optimization readiness until the actual Risk Cap v1 build proves those behaviors are capped.

## Edge After Risk Caps

Not proven.

The original baseline has potential edge, with PF 1.45 and 706 trades, but the submitted retest does not show whether the edge survives after real caps. Because Risk Cap v1 was not active, the edge-after-caps question remains unanswered.

## Required Retest Checks

Before accepting the next risk_cap_v1 report, verify all of these:

- MT5 Tester Inputs show `InpMaxLotAbsolute=0.20`.
- MT5 Tester Inputs show `InpRecoveryMultiplierMax=1.3`.
- MT5 Tester Inputs show `InpMaxRecoverySteps=3`.
- HTML report input section contains the same risk-cap fields.
- Max lot in the report is <= 0.20.
- MT5 Common Files contains `risk_cap_summary.txt`.
- MT5 Common Files contains `risk_cap_diagnostics.csv`.
- The summary shows whether DD blocks, close-all triggers, cooldown blocks, and lot caps actually fired.

## Conclusion

The current risk_cap_v1 retest is invalid for optimization gating. It repeated the old baseline behavior because the old EA binary was used. Run one fresh manual single test using the deployed patched EA before making any optimization decision.
