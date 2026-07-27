# EA Platform Skills

Claude Code skills for the MT5 EA development pipeline. Loaded automatically in
every Claude Code session (user-level skills).

## Pipeline

```
strategy-and-risk            idea → Master EA Spec Card (YAML)
→ mql-code-generator         spec → MQL5 code
→ backtest-report-analyzer   MT5 report → 7-dimension verdict (PASS/CONDITIONAL/FAIL)
→ ea-optimization-orchestrator   optional: optimization plan + candidate selection
→ robustness-validator       Monte Carlo / WFA / OOS → ROBUST/MARGINAL/...
→ portfolio-selector         multi-EA only: correlation + DD overlap → weights
→ live-deployment-controller final gate: checklist, sizing, kill-switches
```

## Computation scripts (no hand-calculated stats, ever)

| Script | Skill | Purpose |
|---|---|---|
| `backtest-report-analyzer/scripts/parse_mt5_report.py` | analyzer | MT5 HTML report / optimizer XML / optimizer CSV → JSON |
| `robustness-validator/scripts/monte_carlo.py` | validator | trade list CSV → shuffle/bootstrap MC, ruin prob, OOS split |
| `portfolio-selector/scripts/portfolio_analysis.py` | selector | monthly returns CSV → correlation, DD overlap, crisis months |

All scripts are stdlib-only Python 3 — no pip installs needed.

## Conventions

- Cross-references between skills use skill names only (no version pins).
- The 7-dimension scorecard in backtest-report-analyzer is the canonical
  screening standard (supersedes the old BacktestScore/100 system).
- Every skill output ends with exactly one NEXT STEP block.
- `chain_id` is generated in strategy-and-risk and propagated through every
  audit_trail downstream.

Version history lives in git — do not add version-history sections to SKILL.md.
