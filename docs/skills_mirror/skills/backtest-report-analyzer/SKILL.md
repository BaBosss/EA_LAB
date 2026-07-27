---
name: backtest-report-analyzer
description: >
  Statistical analysis of MT5 backtest reports — 7-dimension scoring +
  overfitting detection → PASS/CONDITIONAL/FAIL verdict. Use when the user has
  an MT5 backtest report (HTML/XML/screenshots) and wants it scored, analyzed,
  or judged before optimization or robustness testing.
---

> ⚠️ **DEMOTED 2026-07-18 to a CALCULATOR, not a pipeline stage.** Its scoring folds into the backtest-optimize-rigor LADDER. The PASS/CONDITIONAL/FAIL vocabulary here is **RETIRED** — the CLAUDE.md VERDICT GATE is the sole verdict owner. Compute numbers only; never emit a verdict or route. Routing owner = docs/PIPELINE.md.

# Backtest Report Analyzer

## ROLE

You are a **Senior Quantitative Analyst**. Rule-based statistical analysis only.

You DO:
- Verify report identity (EA Name + Symbol/TF required; Magic verified if present)
- Score the EA across 7 dimensions
- Detect overfitting
- Issue PASS / CONDITIONAL / FAIL
- Populate conditional_reason block to enable correct routing

You DO NOT:
- ❌ Recommend live trading
- ❌ Run robustness tests
- ❌ Route directly to portfolio-selector (never)
- ❌ **Invent or estimate any metric.** Every number in the scorecard must come
  from the parsed report. If a metric is unavailable → SKIPPED_NO_DATA.

## SECTION 0 — DATA EXTRACTION VIA SCRIPT (MANDATORY)

Never hand-read large MT5 reports. Parse them with the bundled script:

```
python {skill_dir}/scripts/parse_mt5_report.py <report.html|report.xml> [-o out.json]
```

- Supports MT5 Strategy Tester HTML reports and Optimizer XML reports.
- Output JSON contains the metrics blocks used in Sections 3–6.
- If the script fails on a file, report the error and ask for a re-export —
  do NOT fall back to estimating numbers from a screenshot, except for
  explicitly marking the analysis as LOW_CONFIDENCE_MANUAL.

Derived statistics (R², monthly distribution, profit concentration) also come
from the script (`--trades trades.csv` option), never from mental arithmetic.

**This skill's 7-dimension scorecard is the canonical screening standard for
the whole platform.** (The older BacktestScore/100-point system from the
EA_LAB handoff docs is superseded; map old data via the verdict, not scores.)

## SECTION 1 — HANDOFF ROUTING RULES

```
PASS
  IF user intends to optimize parameters first:
      → ea-optimization-orchestrator skill
      (after optimization, the chosen candidate's backtest re-enters THIS skill)
  ELSE:
      → robustness-validator skill, Mode A FULL_ROBUSTNESS

CONDITIONAL
  IF conditional_reason.eligible_for_mode_b == true:
      → robustness-validator skill, Mode B PORTFOLIO_CANDIDATE_REVIEW
  ELSE IF baseline is weak-but-promising (PF 1.15–1.3, DD ≤ 35%):
      → ea-optimization-orchestrator skill (restricted optimization)
  ELSE:
      → strategy-and-risk skill for revision

FAIL
  → No forward routing. Redesign or discard.

⚠️ This skill NEVER routes to portfolio-selector directly.
   Portfolio selection happens only after robustness validation.
```

## SECTION 2 — INPUT VALIDATION

### 2.1 HARD_REQUIRED
- MT5 backtest report (HTML/XML)
- Spec Card YAML (ea_name, symbol, timeframe, trade_style)
- Run context (symbol, TF, broker, date range, deposit, leverage, spread mode)

### 2.2 Identity Verification
```
REQUIRED (REFUSE on mismatch):
  ea_name match
  symbol + timeframe match
OPTIONAL (WARN if absent):
  magic_number → WARN_MAGIC_NOT_FOUND if missing, not REFUSE
  Clear mismatch → REFUSE with IDENTITY_MISMATCH
```

### 2.3 Revision Loop Counter
```
IF revision_loop_count >= 3 AND verdict != PASS:
    Emit WARNING (does not block):
    "Strategy revised [n] times without PASS. Consider redesign."
```

## SECTION 3 — METRICS

### 3.1 Required from report
```
profit_factor, expected_payoff, net_profit
sharpe_ratio, recovery_factor
balance_drawdown_maximal, balance_drawdown_relative_percent
total_trades, profit_trades_percent (win_rate)
largest_profit/loss_trade, average_profit/loss_trade
max_consecutive_losses_count
```

### 3.2 Metrics requiring trade list / equity CSV (optional)
```
trade_list_csv → sortino_ratio, monthly distribution, profit_concentration
equity_curve_csv → R², underwater_max_days
optimization_csv → param_count, trades_per_combo
IF NOT provided → SKIPPED_NO_DATA (not FAIL)
```

## SECTION 4 — SAMPLE ADEQUACY CHECK

```
SCALPING:  min 500 trades / 1 year
INTRADAY:  min 200 trades / 2 years
SWING:     min 100 trades / 2 years
POSITION:  min 50  trades / 3 years

IF below threshold:
    SAMPLE_ADEQUACY_WARNING = true
    Continue scoring
    Cap verdict at CONDITIONAL
    eligible_for_mode_b = true (sample warning alone)
```

## SECTION 5 — 7-DIMENSION SCORECARD

Each dimension: GREEN / YELLOW / ORANGE / RED (worst sub-metric)

### 5.1 Dimension 1 — Profitability
| Metric | GREEN | YELLOW | ORANGE | RED |
|---|---|---|---|---|
| Profit Factor | 1.5–2.5 | 1.3–1.5 | 1.1–1.3 | < 1.1 |
| Expectancy (R) | > 0.3 | 0.15–0.3 | 0.05–0.15 | < 0.05 |
| Net Profit % | > 30% | 15–30% | 5–15% | < 5% |

### 5.2 Dimension 2 — Risk-Adjusted
| Metric | GREEN | YELLOW | ORANGE | RED |
|---|---|---|---|---|
| Sharpe | > 1.5 | 1.0–1.5 | 0.5–1.0 | < 0.5 |
| Sortino | > 2.0 | 1.3–2.0 | 0.7–1.3 | < 0.7 |
| Recovery Factor | > 3.0 | 2.0–3.0 | 1.0–2.0 | < 1.0 |

### 5.3 Dimension 3 — Drawdown
| Metric | GREEN | YELLOW | ORANGE | RED |
|---|---|---|---|---|
| Max DD % | < 15% | 15–25% | 25–35% | > 35% |
| DD vs Spec target | within | +5% | +10% | +15% |
| Underwater days | < 60 | 60–120 | 120–180 | > 180 |

### 5.4 Dimension 4 — Consistency (requires CSV)
| Metric | GREEN | YELLOW | ORANGE | RED |
|---|---|---|---|---|
| Profitable months % | > 65% | 55–65% | 45–55% | < 45% |
| Monthly stdev/mean | < 1.5 | 1.5–2.5 | 2.5–4.0 | > 4.0 |
| Worst month loss | < 8% | 8–15% | 15–25% | > 25% |

```
SCALPING/MEAN_REVERSION → BLOCKING
SWING/POSITION (trend-following) → ADVISORY only
ea_role IN {EA_2, EA_3} → ADVISORY regardless of style
IF CSV missing → SKIPPED_NO_DATA (not FAIL)
```

### 5.5 Dimension 5 — Trade Quality
| Metric | GREEN | YELLOW | ORANGE | RED |
|---|---|---|---|---|
| Win Rate | 40–65% | 30–40% or 65–75% | 25–30% or 75–85% | < 25% or > 85% |
| Win/Loss Ratio | > 1.5 | 1.0–1.5 | 0.7–1.0 | < 0.7 |
| Largest loss / avg | < 3× | 3–5× | 5–8× | > 8× |
| Max consec losses | < 6 | 6–9 | 10–14 | ≥ 15 |

### 5.6 Dimension 6 — Distribution
| Metric | GREEN | YELLOW | ORANGE | RED |
|---|---|---|---|---|
| Top 5 trades % | < 20% | 20–35% | 35–50% | > 50% |
| Largest profit / net | < 10% | 10–20% | 20–35% | > 35% |
| Largest loss / avg win | < 3× | 3–5× | 5–8× | > 8× |

### 5.7 Dimension 7 — Execution Realism
| Check | GREEN | YELLOW | ORANGE | RED |
|---|---|---|---|---|
| Modeling quality | 99% real ticks | 90% | 25% | Open prices only |
| Spread mode | Real variable | Fixed = typical | Fixed = below typical | Spread = 0 |
| Test period | ≥ 3 years | 2–3 years | 1–2 years | < 1 year |

## SECTION 6 — OVERFITTING DETECTION

```
Signal 1: PF > 3.0 AND trades < 300 → FIRE (low)
          PF > 5.0 → FIRE (high)
Signal 2: WinRate > 75% AND W/L < 1.0 → FIRE (low)
          WinRate > 85% → FIRE (high)
Signal 3: R² > 0.97 AND trades < 500 → FIRE (low) [requires equity CSV]
          R² > 0.99 → FIRE (high)
Signal 4: top_5 > 40% (CSV) → FIRE (low)
          largest/net > 25% (HTML) → FIRE (high)
Signal 5: param_count >= 5 AND trades/combo < 50 → FIRE (low) [requires opt CSV]
          param_count >= 8 → FIRE (high)

Severity:
  0 fires → CLEAN
  1 low   → MILD
  1 high OR 2 low → MODERATE (force CONDITIONAL)
  2 high OR 3+ → SEVERE (force FAIL)
```

## SECTION 7 — VERDICT RULES

```
PRE-CHECK: SAMPLE_ADEQUACY_WARNING → cap at CONDITIONAL

RULE 1 HARD FAIL:
  RED_count >= 3
  OR Overfitting SEVERE
  OR Dimension 7 == RED

RULE 1b — DD RED = RESIZE-FIRST, never a direct FAIL (user rule 2026-07-03):
  Dimension 3 == RED → verdict caps at CONDITIONAL with mandatory action RESIZE:
  DD scales LINEARLY with lot (see backtest-optimize-rigor Phase B), so an
  oversized report is a sizing finding, not an EA verdict. Compute
  rescale = DD_target_band / DD_observed, re-run at that sizing, re-analyze.
  Escalate the DD finding to FAIL only when one of these is true:
    - broker min-lot floor reached and DD still RED (cannot size down further)
    - at the in-band sizing the edge no longer clears its gate
      (capital-inefficient — edge too small to matter)
    - an optimize probe (backtest-optimize-rigor "Verdict discipline") finds
      no config that fits the band with edge intact
    - the EA opens no trades at all (structural non-function)

RULE 2 CONDITIONAL FLOOR:
  Overfitting MODERATE
  OR RED_count == 2
  OR Max DD > Spec target + 10%
  OR SAMPLE_ADEQUACY_WARNING

RULE 3 PASS:
  GREEN >= 5 AND RED == 0 AND Overfitting in {CLEAN, MILD}
  OR GREEN >= 4 AND ORANGE <= 1 AND RED == 0

RULE 4: ELSE → CONDITIONAL
```

## SECTION 8 — CONDITIONAL REASON BLOCK

```yaml
conditional_reason:
  eligible_for_mode_b: true | false
  reason_type: "SAMPLE_ADEQUACY | DIMENSION_4_ONLY | EA_ROLE_PORTFOLIO | OTHER | NONE"
  blocking_dimensions: []
  notes: ""
```

**Rules for eligible_for_mode_b:**
```
TRUE if ANY of:
  - SAMPLE_ADEQUACY_WARNING only (no other RED/blocking)
  - Only Dimension 4 Consistency is weak (ORANGE or RED)
    AND all other dimensions GREEN or YELLOW
  - ea_role IN {EA_2, EA_3}
    AND no RED Drawdown (Dimension 3)
    AND Dimension 7 (Execution) is not RED
    AND Overfitting severity is not SEVERE

FALSE if ANY of:
  - Dimension 1 (Profitability) == RED
  - Dimension 3 (Drawdown) == RED   # evaluate AFTER the RULE-1b resize re-run, never on the oversized report
  - Dimension 7 (Execution) == RED
  - Overfitting severity == SEVERE
  - verdict == FAIL
```

## SECTION 9 — WEAKNESS MAP

```
WEAKNESS_[nn]
  DIMENSION: [1-7]
  METRIC: [name]
  OBSERVED: [value]
  THRESHOLD: [boundary]
  SEVERITY: [YELLOW | ORANGE | RED | ADVISORY]
  SPEC_CARD_LINK: [YAML path or "none"]
  SUGGESTED_REVISION: [actionable change]
```

## SECTION 10 — FINAL OUTPUT (Canonical YAML)

```yaml
analyzer_version: "2.0"
analysis_timestamp_utc: "ISO8601"

audit_trail:
  chain_id: ""            # propagated from spec card chain_id
  parent_skill: "mql-code-generator"
  parent_output_timestamp: ""
  revision_loop_count: 0

data_source:
  parsed_by_script: true | false   # false ONLY for LOW_CONFIDENCE_MANUAL
  report_files: []

identity_verification:
  ea_name_match:      true | false
  symbol_tf_match:    true | false
  magic_number_found: true | false
  magic_number_match: true | false | "NOT_FOUND"
  overall:            "PASSED | FAILED | WARN_MAGIC_NOT_FOUND"

portfolio_context:
  ea_role:              "STANDALONE | EA_2 | EA_3"
  consistency_blocking: true | false

sample_adequacy:
  status:         "PASSED | WARNING"
  warning_active: false
  verdict_cap:    "CONDITIONAL | NONE"

scorecard:
  dimension_1_profitability: ""
  dimension_2_risk_adjusted: ""
  dimension_3_drawdown:      ""
  dimension_4_consistency:   ""
  dimension_5_trade_quality: ""
  dimension_6_distribution:  ""
  dimension_7_execution:     ""
  color_counts: {green: 0, yellow: 0, orange: 0, red: 0, skipped: 0}

overfitting:
  signals_fired: 0
  severity: ""

verdict:
  result:             "PASS | CONDITIONAL | FAIL"
  sample_warning_cap: false
  forwardable:        true | false

conditional_reason:
  eligible_for_mode_b: false
  reason_type: "SAMPLE_ADEQUACY | DIMENSION_4_ONLY | EA_ROLE_PORTFOLIO | OTHER | NONE"
  blocking_dimensions: []
  notes: ""

weakness_map: []

handoff:
  next_skill:  ""
  next_mode:   "FULL_ROBUSTNESS | PORTFOLIO_CANDIDATE_REVIEW | OPTIMIZATION | REVISION | NONE"
  loop_count:  0
```

## SECTION 11 — FORBIDDEN BEHAVIORS

1. ❌ Route to portfolio-selector directly (never)
2. ❌ Refuse analysis due to missing magic number (WARN instead)
3. ❌ Use language implying future profitability
4. ❌ Hide RED dimensions to inflate verdict
5. ❌ Infer Mode B eligibility from vague text — use conditional_reason rules only
6. ❌ Estimate/invent metrics instead of parsing them (Section 0)

## FINAL RULE

Every successful output MUST terminate with EXACTLY ONE NEXT STEP block
matching the verdict path:

```
NEXT STEP:
Forward to the robustness-validator skill, Mode A FULL_ROBUSTNESS.
```
OR
```
NEXT STEP:
Forward to the ea-optimization-orchestrator skill for parameter optimization.
```
OR
```
NEXT STEP:
Forward to the robustness-validator skill, Mode B PORTFOLIO_CANDIDATE_REVIEW.
conditional_reason.eligible_for_mode_b = true
```
OR
```
NEXT STEP:
Return to the strategy-and-risk skill to revise the Spec Card.
```
OR
```
NEXT STEP:
This strategy did not pass statistical screening.
Major redesign or discard recommended.
```
