# Baseline Scorecard - Gold SMC continuous

## Verdict

**NEEDS LOGIC FIX**

The EA is profitable in this single baseline, but the risk profile is too fragile for optimization. The biggest issue is recovery/multiplier exposure, not signal frequency.

## Scorecard

| Dimension | Score | Assessment |
|---|---:|---|
| Profitability | 7/10 | Net profit 27,181.36 with PF 1.45 and Sharpe 2.00. Positive but not clean because tail events dominate. |
| Trade sample | 8/10 | 706 trades is enough for baseline review. |
| Equity quality | 4/10 | Grind-up with sharp basket jumps, long stagnation, and large recovery cycles. |
| Drawdown control | 3/10 | Balance DD 28.25%; equity DD relative 27.75%. Too high before optimization. |
| Tail risk | 2/10 | Largest loss -12,074.24; max deposit load 92.53%; max lot 2.56. |
| Strategy clarity | 5/10 | SMC/FVG entry exists, but recovery engine dominates realized performance. |
| Optimization readiness | 2/10 | Not ready until hard risk caps are added and retested. |

Overall score: **4.4 / 10**

## Key Positives

- Positive net result over 2025-01-01 to 2026-06-01.
- Good sample size: 706 trades.
- Win rate 73.23%.
- Long side appears stronger than short side.
- Monthly realized P/L is positive in the reviewed sample.
- Average holding time is reasonable at 18:26:38, though outliers exist.

## Key Weaknesses

- Uses lot multiplier recovery: `InpLotMultiplier=2`.
- Orders are opened with no hard SL in the reviewed execution logic.
- Max deposit load reached 92.53%.
- Balance DD reached 28.25%.
- One loss of -12,074.24 is too large relative to starting deposit and total net profit.
- Median trade profit is only 33.70, showing many small wins versus rare very large losses.
- Recovery chains reached 11 entries and max lot 2.56.
- Hours 20-22 are weak in the sample and may need session filtering.

## Decision Gate

| Gate | Status |
|---|---|
| Enough trades for baseline? | PASS |
| Profit factor above 1.25? | PASS |
| Max DD below 20%? | FAIL |
| Tail loss controlled? | FAIL |
| No martingale-like behavior? | FAIL |
| Deposit load controlled? | FAIL |
| Ready for optimization? | FAIL |

## Final Decision

Do not optimize this version yet. Add risk containment and rerun a controlled baseline first.
