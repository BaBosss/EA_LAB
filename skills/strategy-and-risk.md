# strategy-and-risk

Purpose: turn a trading idea into an inspectable EA specification before any code is written.

Outputs:
- Strategy rules
- Risk limits
- Allowed symbols and timeframes
- Inputs that may be optimized
- Conditions that reject the strategy

Safety:
- No live deployment decisions.
- No automatic lot-size changes.
- Every risk change must be reviewed manually.
