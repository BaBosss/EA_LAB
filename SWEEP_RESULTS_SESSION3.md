## Session 3 Results
| Symbol | IS PF | IS DD% | OOS PF | OOS DD% | OOS T | M4 PF | Verdict |
|--------|-------|--------|--------|---------|-------|-------|---------|
| EURCAD | 1.031 | 0.92% | N/A | N/A | N/A | N/A | REJECT |

---

## Execution Log

### STEP 1 - Optimization (IS: 2020.01.01 - 2023.12.31)
- **Script**: mt5_optimize.ps1
- **Expert**: EA_RUNNER
- **Symbol**: EURCAD H1
- **Model**: 2 (open prices, fast)
- **Optimization**: 2 (genetic)
- **Total combinations**: 8,400 (7x6x5x8x5)
- **Successful passes**: 328 (of 8,400)
- **Failed passes**: 8,072 (OnInit returned non-zero code 1)
- **Optimization time**: 11 minutes 06 seconds
- **Max PF**: 1.031 (Pass 0: Fast=21, Slow=42, Signal=9, SL=500, TP=400)
- **Avg PF**: 0.842
- **PF > 1.0**: 3 passes
- **PF > 1.2**: 0 passes
- **PF > 1.3**: 0 passes

### STEP 2 - Robust Pass Selection
- **Status**: SKIPPED (REJECT at Step 1)
- **Reason**: Only 3 passes with PF > 1.0, far below the 50-pass threshold
- **Robust passes found**: 0

### STEP 3 - Locked Set
- **Status**: SKIPPED (no robust passes to lock)

### STEP 4 - IS Backtest
- **Status**: SKIPPED (pipeline rejected at Step 1)

### STEP 5 - OOS Backtest
- **Status**: SKIPPED (pipeline rejected at Step 1)

### STEP 6 - Model 4
- **Status**: SKIPPED (pipeline rejected at Step 1)

## Verdict: REJECT

**Reason**: The EA_RUNNER MACD crossover + Zero-Line Filter strategy produces negative expectancy across virtually all parameter combinations on EURCAD H1. The best parameter set achieves PF=1.031, which is well below the required gate of PF>1.30 for IS and PF>1.30 for OOS. The EA is fundamentally not suitable for EURCAD.

**Key observations**:
- 328 out of 8,400 combinations produced valid results (most failed OnInit)
- Average PF of 0.842 indicates the EA loses money on average
- Maximum PF of 1.031 is extremely weak — barely profitable
- All valid passes had very low drawdown (< 3.63%) but this is because the EA generates minimal profit, not because of good risk management
- The strategy appears to be systematically unprofitable on EURCAD
