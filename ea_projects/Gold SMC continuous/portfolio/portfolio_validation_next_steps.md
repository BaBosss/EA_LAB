# Portfolio Validation Next Steps

Project: Gold SMC continuous  
Current candidate: `Gold_SMC_Run004_OOS_VALIDATED`

## Current Pipeline Position

`EA Idea -> Optimize -> Single Test -> OOS -> Candidate Locked -> Correlation Test -> Tiny Live -> Production Portfolio`

Current position:

`Candidate Locked + OOS Passed`

Next phase:

`Portfolio Validation`

## Portfolio Goal

Build a 2-3 EA portfolio. Gold SMC should be treated as a conservative component, not as a standalone production system.

Target portfolio shape:

| Slot | Desired behavior |
|---|---|
| EA 1 | Gold SMC: conservative MR/trend hybrid |
| EA 2 | Trend follower or session momentum |
| EA 3 | Volatility harvesting or low-correlation breakout |

## Candidate Personality

Gold SMC:

- Conservative recovery-capped component
- XAUUSD,H1
- Moderate PF
- Good trade sample
- Controlled DD after risk cap
- Needs portfolio diversification

## Do Not Do

- Do not optimize Gold SMC further.
- Do not raise lot size.
- Do not raise max lot cap.
- Do not increase recovery steps.
- Do not loosen close-all DD.
- Do not increase martingale behavior.
- Do not deploy as a single-EA portfolio.

## Correlation Test Requirements

For each candidate EA:

- Export full MT5 report as HTML and XLSX.
- Extract monthly PnL from the Deals table.
- Compute correlation against Gold SMC.
- Review overlapping DD windows.
- Reject pairs that lose money in the same regime even if raw correlation looks acceptable.

Preferred correlation:

| Relationship | Decision |
|---|---|
| Correlation < 0.30 | Good candidate pair |
| 0.30 to 0.50 | Watch; inspect DD overlap |
| > 0.50 | Avoid unless hedge behavior is proven |

## Tiny Live Gate

Tiny live is allowed only after portfolio validation.

Recommended tiny-live purpose:

- Check slippage.
- Check spread behavior.
- Check execution failures.
- Check VPS latency.
- Check overnight behavior.
- Check whether the operator can tolerate real DD.

Tiny live is not for maximizing profit.

Suggested tiny-live account:

- 10,000 cent account
- 0.01 to 0.02 lot maximum
- Same fixed risk caps
- VPS deployment
- No manual parameter changes

## Next Concrete Task

Start EA candidate 2, then compare against Gold SMC.

Candidate 2 should have a different personality:

- trend following,
- session breakout,
- volatility harvesting,
- or another symbol/timeframe with low DD overlap.

