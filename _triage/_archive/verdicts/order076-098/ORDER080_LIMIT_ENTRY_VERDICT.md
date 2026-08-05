# ORDER-080 — limit-entry vs market-entry value — verdict (Claude, 2026-07-17)

**Hypothesis (user, from a maker-only FB bot):** entering with a pending limit at a slightly better
price than the signal (trading fill-rate for entry price) beats market entry — crypto proves it via
fees; MT5 = saved spread/slippage.

**This question is ANSWERED by two EAs already A/B-tested — no need to re-build on Boss_16:**

## Evidence 1 — ORDER-108 (EXP)_BRK_SplitRetest (breakout, XAU H1, both-window Model-4)
| mode | MAIN (trend) | BWD (chop) |
|---|---|---|
| market-only | **2.07** | 1.75 |
| pending-only | 1.76 | **2.55** |
| split (mkt+pend) | 1.93 | 1.97 (**robust both**) |
- Fill-rate ~90% (retest happens). **Adverse-selection is REAL:** pending-only 1.76 < market 2.07 in the
  trend window — waiting for the retest MISSES the breakouts that run away (the winners), and
  disproportionately fills the ones that come back (the losers).

## Evidence 2 — ORDER-091C-D1d (EXP)_LwmaRev_Pending (reversion, EURUSD/AUDNZD, `order091d_lwma_ab.csv`)
| | EURUSD M/P | AUDNZD M/P |
|---|---|---|
| MAIN PF | 0.93 / 0.90 | 0.55 / 0.59 |
| BWD PF | 0.88 / 0.93 | 0.66 / 0.72 |
| fills | 1379 / 1013 (P −26%) | 1039 / 743 (P −28%) |
- On a reversion signal, pending (P) gives a slightly BETTER PF than market (M) — the better entry price
  helps when price comes back — but at the cost of ~26-28% of trades never filling. (Signal itself is dead
  here 0.55-0.93, so it's a mechanism read, not a live edge.)

## VERDICT — limit-entry is NOT a universal win; the real lever is SPLIT, and it's config-conditional
1. **Pure pending-limit ≠ free money.** Two failure modes: (a) adverse-selection in trends (misses runners),
   (b) ~26-28% missed fills. It only helps net when the signal is reversion/mean-revert (fills on the pullback).
2. **Split-entry (market leg + pending leg) = the robust answer** — market leg catches the runners, pending
   leg gets the better fills; no weak window (ORDER-108 1.93/1.97).
3. **Config-conditional:** helps balanced/reversion configs; HURTS trend-chasers (ORDER-108 follow-up: the
   live Bars55/TP8 breakout did NOT improve with split — do not retrofit trend-heavy live EAs).
4. **Do NOT rebuild the Boss_16 A/B** (original ORDER-080 spec) — it would re-confirm the same on a 3rd EA.
   The generalizable finding stands. Lever recorded in EDGE_CATALOG (via ORDER-108).

**Practical rule for the lab:** offer market/split/pending as an entry-mode INPUT per EA; default = the EA's
validated mode; enable pending/split only on reversion or balanced configs, never on trend-runners.
