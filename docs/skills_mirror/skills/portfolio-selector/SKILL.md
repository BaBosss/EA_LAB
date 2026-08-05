---
name: portfolio-selector
description: >
  Multi-EA portfolio composition via correlation + drawdown-overlap analysis
  with weight allocation. Use when the user wants to combine 2+ validated EAs
  into a portfolio, check EA correlation/DD overlap, or allocate risk weights
  across EAs before deployment.
---

# Portfolio Selector

## ROLE

**SKIP if single EA** → go to the live-deployment-controller skill directly.

You DO: verify EA eligibility, correlation analysis, DD overlap analysis,
crisis month + symbol concentration analysis, weight allocation, and issue
APPROVED / REBALANCE / REJECT / INSUFFICIENT_EAs.

You DO NOT:
- ❌ Approve REBALANCE for deployment (REBALANCE is NOT deploy-approved)
- ❌ Route to live without APPROVED
- ❌ Accept EAs with NOT_ROBUST or CANDIDATE_REJECT verdicts
- ❌ **Hand-compute correlation or DD overlap** — run the bundled script.

## SECTION 0 — COMPUTATION VIA SCRIPT (MANDATORY)

```
python {skill_dir}/scripts/portfolio_analysis.py returns.csv \
    [--weights "EA_A=0.4,EA_B=0.6"] [--deposit 10000] [-o out.json]
```

- Input: monthly returns CSV — columns: `month` (YYYY-MM) + one column per EA
  (monthly return % or monthly P/L; flag with `--mode pct|money`).
- Output JSON: Pearson correlation matrix, DD overlap %, severe-DD overlap %,
  worst same-month combined loss, crisis month table, combined equity DD.
- If monthly returns are unavailable for any EA → that EA cannot enter the
  portfolio analysis. Never estimate correlations.

## SECTION 1 — VERDICT DEFINITIONS

```
APPROVED:        balanced + within risk targets → live-deployment-controller
REBALANCE:       fixable via weights — NOT deploy-approved; resubmit here
REJECT:          fundamental diversification problems; revise EA selection
INSUFFICIENT_EAs: < 2 eligible EAs → live-deployment-controller single mode
```

## SECTION 2 — EA ELIGIBILITY

```
ELIGIBLE:
  ROBUST         → max weight 60% (40% if MARGINAL count >= 2)
  MARGINAL       → capped at 40%
  CANDIDATE_OK   → capped at 35%
  CANDIDATE_WEAK → capped at 25% + WARNING
INELIGIBLE: NOT_ROBUST, CANDIDATE_REJECT

IF eligible < 2 after exclusion → REDUCED_TO_SINGLE_EA
IF MARGINAL_count >= 2 → force weight cap 0.40 for ALL EAs + WARNING
```

## SECTION 3 — CORRELATION ANALYSIS

```
Pearson correlation from monthly returns (script output) — user correlation LADDER:
  ≤ 0.40           → additive, full lot 🟢
  0.40 – 0.60      → reduce-lot 🟡
  > 0.60           → redundant → reduce-lot, NOT cut (user decides any drops) 🟠/🔴
  same-EA cross-symbol threshold = < 0.8 (looser — one EA run on multiple symbols)
```
**Doctrine: high correlation → REDUCE LOT, never auto-cut. The user decides any drops, this skill never auto-drops an EA/leg.**

## SECTION 4 — DD OVERLAP ANALYSIS

Cumulative-equity method (script computes): per EA build monthly cumulative
equity, running peak, in-DD flags. DD_Overlap% = months both EAs in DD / total.
Severe threshold = EA MaxDD × 0.50.

| Level | DD_Overlap% | Severe% |
|---|---|---|
| 🟢 | < 25% | < 10% |
| 🟡 | 25–40% | 10–20% |
| 🟠 | 40–60% | 20–35% |
| 🔴 | ≥ 60% | ≥ 35% |

RED on any pair → blocks APPROVED.
If only monthly returns (no full equity sequence): confidence = PARTIAL_DATA.

## SECTION 5 — WORST SAME-MONTH LOSS

```
Worst_Same_Month_Loss = min over months of Σ(weight_i × monthly_return_i[m])
vs max_portfolio_monthly_loss_percent target:
  <= target GREEN | <= ×1.25 YELLOW | <= ×1.5 ORANGE | > ×1.5 RED (blocks APPROVED)
```

## SECTION 6 — CRISIS MONTHS & SYMBOL EXPOSURE

```
Crisis month: combined loss > target OR 2+ EAs each down > 5%
Symbol concentration: ≤40% 🟢 | >40% 🟡 | >60% 🟠 | >80% 🔴 (blocks APPROVED)
```

## SECTION 7 — WEIGHT ALLOCATION

```
MAX_SHARPE: maximize portfolio Sharpe (caps 0.10–0.60 per EA; Section 2 caps apply)
MIN_DD:     minimize combined DD
EQUAL_RISK: Weight_i = (1/MaxDD_i) / Σ(1/MaxDD_j)

Lot: EA_Lot = BaseLot × Weight × (Live_Balance / Test_Deposit)
CANDIDATE EAs: additional 20% lot reduction
```

## SECTION 8 — PORTFOLIO VERDICT RULES

```
APPROVED (ALL must pass):
  no cross-EA corr pair > 0.60 left un-lot-reduced (reduce-lot applied, not cut);
  no same-EA cross-symbol pair ≥ 0.8 left un-lot-reduced;
  no RED DD_Overlap or Severe_DD pair;
  Worst_Same_Month_Loss GREEN; symbol concentration ≤ 60%;
  combined DD ≤ portfolio target

REBALANCE (fixable, NOT deploy-approved):
  any ORANGE on DD_Overlap / symbol concentration / Worst_Month_Loss,
  OR combined DD slightly over target (< +10%)
  → adjust weights/composition and resubmit HERE. Never forward to live.

REJECT (fundamental):
  any RED on correlation / DD_Overlap / Severe_DD / Month_Loss / Symbol,
  OR combined DD > target + 15%
```

## SECTION 9 — CANONICAL YAML

```yaml
selector_version: "2.0"
analysis_timestamp_utc: "ISO8601"
method: ""
overlapping_period_months: 0

audit_trail:
  chain_id: ""
  parent_skill: "robustness-validator"
  parent_output_timestamp: ""
  revision_loop_count: 0

data_source:
  computed_by_script: true   # MUST be true
  script_output_files: []

edge_case_flags:
  reduced_to_single_ea:  false
  multiple_marginal_eas: false
  tighter_caps_applied:  false

ea_collection:
  - ea_name: ""
    verdict_from_robustness: ""
    candidate_not_standalone: false
    max_dd_pct: 0.0
    symbol: ""
    weight_cap_pct: 0.0

correlation_matrix:
  pairs: [{ea_a: "", ea_b: "", correlation: 0.0, level: ""}]
  warnings: []

dd_overlap_matrix:
  confidence: "FULL | PARTIAL_DATA"
  pairs: [{ea_a: "", ea_b: "", dd_overlap_pct: 0.0, dd_overlap_color: "",
           severe_overlap_pct: 0.0, severe_overlap_color: ""}]
  warnings: []

crisis_months:
  crisis_month_count: 0
  worst_month: {date: "", combined_loss_pct: 0.0}
  crisis_month_table: []

symbol_exposure:
  map: [{symbol: "", weight_pct: 0.0, ea_list: [], color: ""}]
  concentration_warning: ""

portfolio_composition:
  - {ea_name: "", weight: 0.0, base_lot: 0.0, max_lot: 0.0, lot_note: ""}

combined_risk:
  expected_dd_pct: 0.0
  worst_same_month_loss_pct: 0.0
  tail_risk_worst_case_pct: 0.0
  portfolio_sharpe: 0.0
  crisis_month_count: 0

verdict:
  result: "APPROVED | REBALANCE | REJECT | INSUFFICIENT_EAs"
  blocking: []
  warnings: []

handoff:
  next_skill: "live-deployment-controller"
  forward_allowed: true | false   # true only if verdict = APPROVED
```

## FINAL RULE

> Routing between stages is owned by `docs/PIPELINE.md` — this skill owns its own stage mechanics only.

Every output MUST terminate with EXACTLY ONE NEXT STEP block:

```
NEXT STEP:
Forward to the live-deployment-controller skill with portfolio composition,
combined_risk, and symbol_exposure. (Only if verdict = APPROVED)
```
OR
```
NEXT STEP:
REBALANCE required before deployment.
Adjust weights/composition and resubmit to the portfolio-selector skill.
Do NOT proceed to live-deployment-controller until APPROVED.
```
OR
```
NEXT STEP:
Portfolio REJECTED. Revise EA selection.
```
