# CWAY Investment — AI-agent optimization of a Dynamic Grid: source note — 2026-11-06

Status: `RESEARCH_ONLY / SOURCE_INTAKE`

Purpose: record an owner-supplied social-media post (Thai) that summarizes a CWAY Investment YouTube lecture on
using AI agents to optimize and evaluate a Dynamic Grid trading system. This note is not performance evidence and
creates no strategy, optimization, verdict-bar, HOLDOUT, Candidate, risk, runtime, deployment, or trading authority.

## Sources

1. Owner-supplied post text, pasted into the EA_LAB session on 2026-11-06 (author: the CWAY channel presenter,
   answering a follower's question about how AI agents help develop trading systems).
2. Referenced lecture: `https://youtu.be/6zCpxOkk97Q` — **NOT RETRIEVED.** The cloud session's network policy
   blocks `www.youtube.com` (proxy 403 / DNS not allowed). No title, date, duration, transcript, numbers, or
   chapters from the video were read.
3. Prior channel triage: `_triage/cway_youtube/ASSESSMENT.md` (2026-07-12) — the channel was assessed HIGH
   relevance and listed "AI Agent + Bayesian Opt: Grid Hyperparameters" and "AI Agents Evaluate a BTC Grid System"
   among its titles. Whether `6zCpxOkk97Q` is one of those titles is unconfirmed.

Evidence depth: `AUTHOR_SUMMARY_ONLY` — the presenter's own written summary of the lecture, no data, no results.

## SOURCE_CLAIM (paraphrased from the post; English)

**Pre-optimization readiness**
- Only optimize a system that already shows potential and some consistency in basic backtests; do not force-tune a
  poor system into looking good.
- Split data into in-sample / out-of-sample, or use walk-forward analysis, to avoid data bias. Synthetic data can
  widen test coverage.
- Screen with an AI "Evaluation Engine" against preset criteria (example given: pass 4 of 5) before detailed tuning.
- Use risk analysis such as Conditional Value at Risk (CVaR) and parameter-stability testing before optimizing.

**Optimization**
- Hyperparameter optimization with the Optuna framework (Bayesian optimization), wrapped as a tool the AI agent calls.
- Objective: Sortino ratio, preferred over net profit or Sharpe for stability across market conditions.
- The agent receives context (parameters of a strategy that already passed backtest) and runs thousands of trials,
  tuning e.g. grid zone distance, take profit, position size. Long processing time is accepted.
- After optimization, an "AI Council" / Evaluation Engine audits the result against standard criteria
  (example: pass 5/5) and gives recommendations, e.g. stop-loss use, testing on other assets to avoid overfitting.
- Insights are summarized in plain Thai.

**Money management**
- Position size (risk per trade) is optimized by sampling a range and selecting the size with the best statistic,
  e.g. a higher Sortino ratio.
- Take profit adapted to current volatility rather than fixed.
- Drawdown control is part of the optimization goal; Sortino is the main judge for MM tuning.

**Evaluation engine dimensions**
- Expectancy (long-run profitability); risk and drawdown control ("the heart of grid trading"); robustness of
  parameters to changing markets. Output: strengths, weaknesses, overfit warnings, SL / worst-case suggestions.

## Not stated by the source

No criteria list for the 4/5 or 5/5 checks, no thresholds, no data windows, no instrument/timeframe, no trial
counts, no Sortino/CVaR values, no OOS or forward results, no cost model, no tick/model fidelity, no account of how
the selected trial was chosen among near-equal trials.
