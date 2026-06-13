# Safe Optimization Plan

Project: Gold SMC continuous  
Status: Blocked until a valid Risk Cap v1 retest exists

## Current Decision

Do not optimize yet.

The submitted risk_cap_v1 retest is not usable because it ran like the original baseline. Risk-cap inputs were absent from the report, max lot still reached 2.56, and no risk diagnostics were exported.

## Required Pre-Optimization Retest

Run one manual Risk Cap v1 baseline test with the patched EA now deployed to the MT5 Experts folder.

Keep fixed:

- Same symbol as original baseline
- Same timeframe
- Same date range
- Same tester model
- Same spread setting
- Same starting deposit
- Same original strategy parameters
- Risk Cap v1 set: `C:\Users\patip\OneDrive\.Codex\EA_LAB\ea_projects\Gold SMC continuous\set\risk_cap_v1.set`

## Gate Metrics To Recheck

Optimization may be considered only if the retest shows:

- PF > 1.10
- Max DD <= 20% to 25%
- Max deposit load <= 30% to 40%
- Max lot <= 0.20
- Largest loss materially reduced
- Recovery steps <= 3
- Trade count remains sufficient
- Equity curve is not driven by one lucky recovery spike
- Risk diagnostics confirm cap enforcement

## Safe Optimization Dimensions

Use these only after the gate opens:

| Parameter area | Suggested range | Reason |
|---|---:|---|
| Take profit USD | 50 to 200 | Tests reward target sensitivity without changing recovery identity too much |
| Signal delay / entry spacing if available | Conservative local range only | Reduces overtrading and clustering risk |
| Cooldown bars after stop | 10 to 60 | Controls re-entry after loss cycles |
| Max recovery steps | 1 to 3 | Must remain capped; never optimize above 3 |
| Recovery multiplier max | 1.0 to 1.3 | Tests whether recovery is needed without restoring martingale behavior |
| Stop-new-entry DD percent | 10 to 15 | Earlier risk throttle |
| Close-all DD percent | 20 to 25 | Hard disaster cap |

## Parameters That Must Stay Fixed

Do not optimize these until the EA passes robustness:

- `InpMaxLotAbsolute = 0.20`
- `InpMaxDepositLoadPercent = 30.0`
- No grid expansion beyond current design
- No recovery steps above 3
- No recovery multiplier above 1.3
- No loosening of close-all DD above 25%
- No disabling daily loss control
- No disabling cooldown after closed loss

## Dangerous Parameters To Avoid

Avoid any optimization that tries to recover the original profit curve by reopening risk:

- Lot multiplier above 1.3
- Max lot above 0.20
- Recovery steps above 3
- Close-all DD above 25%
- Stop-new-entry DD above 15%
- Deposit load above 40%
- Any setting that increases position stacking without reducing DD

## Overfit Risks

The original baseline already shows recovery dependency:

- High PF with large hidden tail risk
- Very large largest loss
- Max deposit load around 92.53%
- Max lot 2.56
- Recovery cycles up to 11 entries

If optimization is allowed before proving caps, the optimizer will likely select parameter sets that restore the same dangerous recovery behavior.

## Next Action

Run a fresh manual single test with the patched EA and `risk_cap_v1.set`. The test is valid only if the HTML report includes the Risk Cap v1 inputs and the diagnostics files are exported.
