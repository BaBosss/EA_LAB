---
card_type: RESEARCH_CARD
card_id: RC-2026-CWAY-AIOPT-001
source_id: SRC-CWAY-AIOPT-POST-20261106
evidence_depth: AUTHOR_SUMMARY_ONLY
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---

# AI-agent Bayesian optimization + evaluation engine for a Dynamic Grid (CWAY Investment)

## SOURCE_CLAIM

The presenter describes a workflow: (1) only optimize a system that already passed basic backtests with some
consistency; (2) split in-sample/out-of-sample or walk-forward, optionally add synthetic data; (3) screen with an
AI evaluation engine against preset criteria (e.g. 4/5) and check CVaR / parameter stability; (4) run Optuna
(Bayesian) hyperparameter optimization as an agent tool over thousands of trials with **Sortino ratio** as the
objective, tuning grid zone distance, take profit and position size; (5) audit the optimized result with an
"AI Council" evaluation engine (e.g. 5/5) on expectancy, drawdown control and parameter robustness, producing a
plain-language Thai report with recommendations (stop loss, test on other assets). Money management (risk per
trade) is also tuned by Sortino; take profit is volatility-adaptive. Full claims: source note.

## Method / context

- Market / asset: Dynamic Grid system; asset not stated in the post (channel also discusses a BTC grid).
- Timeframe / horizon: not stated.
- Sample period: not stated.
- Method: Optuna Bayesian HPO, Sortino objective, rule-count evaluation engine, LLM-written audit report.
- Comparison / benchmark: claims Sortino objective beats net-profit/Sharpe objectives for stability; no numbers.

## Result

None reported in the post. The lecture video was not retrieved (network policy blocked YouTube), so any results
shown in the video are unknown.

## Limitations / caveats

Source-stated: none beyond the general overfitting warning.

Extraction/transfer limitations:
- Author summary only; no data, thresholds, criteria list, trial counts, OOS outcome or cost model.
- "Thousands of trials then pick the best" is a large multiple-testing search; the post does not say how the
  selected trial is protected from selection bias (no deflated metric, no plateau/neighbourhood rule described).
- Sortino computed on closed trades understates grid tail risk while baskets float; the post does not say whether
  Sortino/CVaR are on closed-trade or equity series.
- Optimizing position size for a higher ratio is scale-sensitive only through compounding/ruin; the post does not
  describe a ruin or depth cap.

## EA_LAB_INFERENCE

Already covered in EA_LAB (no new capability implied): ready-before-optimize gate (smoke PF bar, VERDICT GATE item 2),
MAIN/BWD/HOLDOUT separation, rule-based evaluation (bar table + confidence letters + mandatory Model-4),
independent cross-vendor review, volatility-adaptive TP, Thai summaries.

Gaps this source points at:
1. **Sortino / CVaR as reported metrics** — closed by `scripts/mt5_tail_metrics.py` (reporting only, PR #9,
   2026-11-06). First run already showed the closed-deal vs equity gap on grids (GridLog balanceDD 0.19% vs
   equityDD 1.50%) and LOW-N Sortino instability (JumStoch 19.6 on 6 months).
2. **Bayesian (Optuna) search** — a candidate replacement for MT5 genetic in ladder step 2 (zone-finding only).
   Testable hypothesis: on an EA with > 1,000 combos, Optuna reaches the same top-10% zone as MT5 genetic in fewer
   passes. Must still feed the fine complete grid + plateau-center rule; any adoption changes the ladder and needs
   owner approval.
3. **Synthetic data** — not present in EA_LAB beyond trade-order Monte Carlo. Open question only.

Conflicts with EA_LAB doctrine (do not adopt as described):
- Selecting the best of thousands of trials contradicts the plateau-center rule (`backtest-optimize-rigor` step 3)
  and `RC-SSRN2474755-001` multiple-testing hurdle.
- Using Sortino (or any single ratio) as the selection objective is not ratified; it is a reporting lens only.
- Sizing up a grid by ratio contradicts the engine-edge cage ("never size up on PF") and the lesson that Model-2
  grid plateaus were fake (AUDNZD PF 3–4 → Model-4 0.61).

Next step if the owner wants depth: retrieve the transcript on a host that can reach YouTube, then upgrade
`evidence_depth` and extract the 5 criteria and any numbers.

## Links

- Related mechanisms: `knowledge/06_validation/parameter-optimization-discipline.md`,
  `knowledge/06_validation/multiple-testing-and-selection.md`
- Contradicting cards: `RC-SSRN2474755-001` (search multiplicity raises the evidentiary hurdle)
- Existing experiment/evidence IDs: none; prior channel triage `_triage/cway_youtube/ASSESSMENT.md`
