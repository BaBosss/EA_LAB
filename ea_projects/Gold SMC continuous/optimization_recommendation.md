# Optimization Recommendation - Gold SMC continuous

## Optimization Readiness

**Not ready for optimization yet.**

The baseline is profitable, but the risk engine dominates the result. Optimizing now would likely reward fragile recovery settings: larger multiplier, tighter recovery gap, aggressive basket closure, and high exposure. That would make the backtest look better while increasing blow-up risk.

Recommended gate before optimization:

- Add or enforce max recovery entries.
- Add or enforce max total lot.
- Add max floating drawdown stop.
- Add max daily loss stop.
- Add basket loss stop.
- Decide whether recovery may hedge both directions or must stay directional.
- Confirm whether `ProfitInPips` reporting is intentional.

## Parameters To Keep Fixed For First Controlled Tests

Keep these fixed initially:

| Parameter | Current | Reason |
|---|---:|---|
| `InpLotSize` | 0.01 | Keep base risk stable while testing logic. |
| `InpLotMultiplier` | 2.0 or safer cap | Do not optimize freely; dangerous risk amplifier. |
| `InpDailyTargetUSD` | 100 | Outcome target should not be curve-fit first. |
| `InpSlippage` | 3 | Execution assumption, not edge. |
| `InpMagic` | 270000 | System identifier only. |

## Parameters To Optimize First After Risk Fix

After risk guards exist, optimize the entry/spacing layer first:

| Parameter | Current | Suggested Range | Step | Notes |
|---|---:|---:|---:|---|
| `InpSwingPeriod` | 5 | 3 to 10 | 1 | Tests SMC structure sensitivity. |
| `InpMinGapPts` | 220 | 180 to 450 | 30 | Main recovery spacing control. Wider is safer. |
| `InpRiskReward` | 3.0 | 1.5 to 3.5 | 0.25 | Test whether TP geometry is too ambitious. |
| `InpSLBufferPts` | 15 | 10 to 80 | 10 | Only useful if SL/risk logic is enforced. |
| `InpTakeProfitUSD` | 100 | 30 to 200 | 10 or 20 | Basket exit sensitivity. |

## Required Risk Parameters To Add Before Optimization

These are not currently in the set file, but should exist before optimization:

| New Parameter | Suggested First Range | Purpose |
|---|---:|---|
| `InpMaxRecoveryOrders` | 3 to 6 | Prevent 8-11 order recovery chains. |
| `InpMaxLot` | 0.08 to 0.64 | Prevent 1.28/2.56 lot exposure. |
| `InpMaxBasketLoss` | 2% to 8% of balance | Stop failed baskets early. |
| `InpMaxDailyLoss` | 2% to 5% | Prevent same-day compounding. |
| `InpMaxDepositLoadPct` | 10% to 30% | Prevent margin stress; current max was 92.53%. |
| `InpSessionFilter` | London/NY windows | Avoid weak hours, especially 20-22 if confirmed. |

## Dangerous Parameters To Avoid Overfitting

Do not freely optimize these:

- `InpLotMultiplier`: major blow-up lever. Keep fixed or test only conservative values such as 1.1, 1.2, 1.3, 1.5 after caps exist.
- `InpTakeProfitUSD`: easy to curve-fit because basket exits can hide poor entries.
- `InpDailyTargetUSD`: can overfit month/session behavior.
- Very small `InpMinGapPts`: increases order clustering and margin load.
- Large max recovery depth: improves historical survival but worsens future tail risk.

## Suggested Controlled Test Sequence

1. Logic Fix Test A: current baseline plus `MaxRecoveryOrders=4`, `MaxLot=0.16`, `MaxDailyLoss=5%`.
2. Logic Fix Test B: current baseline plus `MaxRecoveryOrders=5`, `MaxLot=0.32`, `MaxBasketLoss=8%`.
3. Logic Fix Test C: no multiplier, fixed 0.01 lot, same entry logic, to measure pure signal edge.
4. Only if DD remains below 20% and net profit remains positive, start small grid optimization over `SwingPeriod`, `MinGapPts`, and `RiskReward`.

## Optimization Candidate Status

Current status: **blocked from optimization**.

The EA can become an optimization candidate after risk containment is added and a new baseline proves:

- Max DD below 20%.
- Max deposit load below 30%.
- No single loss larger than 10% of starting balance.
- No recovery chain deeper than the configured cap.
- Profit factor remains above 1.25 after caps.
- At least 200 trades remain.
