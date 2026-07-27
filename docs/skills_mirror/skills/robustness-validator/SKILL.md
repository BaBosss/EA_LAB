---
name: robustness-validator
description: >
  Monte Carlo + Walk-Forward + OOS robustness testing for EAs that passed
  backtest screening. Use when an EA has a PASS verdict (Mode A) or an
  eligible CONDITIONAL verdict (Mode B portfolio candidate), or the user asks
  to stress-test / monte-carlo / walk-forward an EA.
---

> ⚠️ **DEMOTED 2026-07-18 to a CALCULATOR, not a pipeline stage.** Its MC/WFA numbers fold into the backtest-optimize-rigor LADDER (Step 5-7). The verdict vocabulary here (PASS/CONDITIONAL/ROBUST/MARGINAL/Mode-A/Mode-B) is **RETIRED** — the CLAUDE.md VERDICT GATE is the sole verdict owner. Use this skill only to compute numbers; never as a gate or to emit a verdict. Routing owner = docs/PIPELINE.md.

# Robustness Validator

## ROLE

Two operating modes:
- **Mode A — FULL_ROBUSTNESS**: Main/standalone EA (requires backtest PASS)
- **Mode B — PORTFOLIO_CANDIDATE_REVIEW**: EA #2/#3 portfolio candidate
  (requires CONDITIONAL with eligible_for_mode_b == true)

## SECTION 0 — COMPUTATION VIA SCRIPT (MANDATORY)

All statistics in this skill MUST come from the bundled script — never from
mental estimation. Inventing a Monte Carlo result is the single most dangerous
failure mode of this pipeline.

```
python {skill_dir}/scripts/monte_carlo.py <trade_list.csv> \
    --deposit 10000 [--permutations 1000] [--bootstrap] [--oos-split 0.7] [-o out.json]
```

- Input: trade list CSV (from MT5 report export or parse_mt5_report.py --trades).
- Output JSON: PF_5th/median/95th, DD_95th, Prob_of_Ruin, PF range,
  and optional date-based IS/OOS split metrics.
- If the trade list is unavailable → REFUSE (MISSING_TRADE_CSV). Do not proceed
  on aggregate numbers alone.

## SECTION 1 — MODE SELECTION

```
MODE A: FULL_ROBUSTNESS
  Requires: backtest verdict = PASS
  Tests: Monte Carlo + WFA (if data) + OOS (if data)
  Verdicts: ROBUST / MARGINAL / NOT_ROBUST

MODE B: PORTFOLIO_CANDIDATE_REVIEW
  Requires: backtest verdict = CONDITIONAL
            AND conditional_reason.eligible_for_mode_b == true
  Tests: Monte Carlo + OOS only
  Verdicts: CANDIDATE_OK / CANDIDATE_WEAK / CANDIDATE_REJECT
  Cannot output ROBUST. Cannot route to live-deployment directly.

IF backtest verdict == PASS AND user requests Mode B:
    AUTO-REDIRECT to Mode A. PASS EAs validate standalone first.

IF backtest verdict == CONDITIONAL AND eligible_for_mode_b == false:
    REFUSE with CONDITIONAL_NOT_ELIGIBLE_FOR_MODE_B
    → return to strategy-and-risk skill.

PRECHECK candidates (from ea-optimization-orchestrator, OOS pending):
    Allowed only when explicitly labeled PRECHECK; verdict capped at MARGINAL;
    FINAL approval blocked until OOS completes.

DO NOT infer eligibility from vague text.
```

Revision loop: IF revision_loop_count >= 3 AND verdict not ROBUST/CANDIDATE_OK
→ emit redesign WARNING (does not block).

## SECTION 2 — INPUT VALIDATION

```
Mode A: IF backtest_verdict != "PASS": REFUSE UPSTREAM_NOT_PASSED
        IF trade_list_csv missing:     REFUSE MISSING_TRADE_CSV
Mode B: eligibility per Section 1; trade_list_csv required.
        Mandatory flags set automatically:
          candidate_not_standalone     = true
          requires_portfolio_selector  = true
          not_allowed_direct_live      = true
```

## SECTION 3 — TEST 1: MONTE CARLO (Both Modes)

Run via script (Section 0). 1,000 permutations trade-order shuffle;
optional bootstrap (requires ≥50 trades): MC_Score = Shuffle 60% + Bootstrap 40%,
else Shuffle 100%.

| Metric | GREEN | YELLOW | ORANGE | RED |
|---|---|---|---|---|
| PF 5th | > 1.2 | 1.0–1.2 | 0.8–1.0 | < 0.8 |
| DD 95th | < MaxDD+5% | +5–10% | +10–20% | > +20% |
| Ruin Prob | < 2% | 2–5% | 5–10% | > 10% |
| PF Range | < 0.5 | 0.5–1.0 | 1.0–1.5 | > 1.5 |

## SECTION 4 — TEST 2: WALK-FORWARD (Mode A Only)

```
Requires: wfa_window_reports OR optimization_result_csv with IS/OOS windows
IF not provided: WFA = SKIPPED_NO_DATA → caps Mode A at MARGINAL
DO NOT fake WFA from an aggregate report.

required_windows: SCALPING=6, INTRADAY=4, SWING=3, POSITION=3
IF provided windows < required: REFUSE INSUFFICIENT_WFA_WINDOWS

WFA_Score = ER(50) + OOS_Profitable%(30) + Degradation(20)
```

| Metric | GREEN | YELLOW | ORANGE | RED |
|---|---|---|---|---|
| Efficiency Ratio | > 0.80 | 0.65–0.80 | 0.50–0.65 | < 0.50 |
| OOS Windows Prof | > 70% | 55–70% | 40–55% | < 40% |
| PF Degradation | < 15% | 15–30% | 30–50% | > 50% |

## SECTION 5 — TEST 3: OOS (Both Modes)

```
Requires: oos_report OR trade_list_csv with date-based split (script --oos-split)
IF not provided: OOS = SKIPPED_NO_DATA
  Mode A: caps at MARGINAL
  Mode B: caps at CANDIDATE_WEAK (Section 7)
DO NOT use same data for IS and OOS.

OOS_Score = PF_Degrad(40) + DD_Expand(30) + Freq_Change(15) + PF_Positive(15)
```

## SECTION 6 — MODE A VERDICT

```
IF both WFA + OOS available:  MC×0.40 + WFA×0.40 + OOS×0.20
IF WFA skipped, OOS avail:    MC×0.60 + OOS×0.40  → cap MARGINAL
IF OOS skipped, WFA avail:    MC×0.50 + WFA×0.50  → cap MARGINAL
IF both skipped:              MC×1.00              → cap MARGINAL

Score ≥ 75 + no cap → ROBUST | 55–74 OR any cap → MARGINAL | < 55 → NOT_ROBUST

Hard overrides:
FORCE NOT_ROBUST: MC Ruin > 10%, OOS PF < 1.0, OOS Degradation > 50%, WFA ER < 0.50
FORCE MARGINAL:   MC DD 95th > MaxDD×1.5, WFA OOS Windows < 50%, any test SKIPPED
```

## SECTION 7 — MODE B VERDICT

```
IF OOS available:  Candidate_Score = MC×0.50 + OOS×0.50
IF OOS SKIPPED:    Candidate_Score = MC×1.00

CANDIDATE_OK     : Score >= 55 AND MC Ruin < 10% AND OOS PF > 0.9
                   AND OOS COMPUTED AND no RED metrics
CANDIDATE_WEAK   : Score 40–54 OR 1 RED OR MC Ruin 5–10% OR OOS SKIPPED
                   → proceed to portfolio-selector with WARNING
CANDIDATE_REJECT : Score < 40 OR MC Ruin > 10% OR OOS PF < 0.7 OR 2+ RED
                   → return to strategy-and-risk skill

RESIZE-FIRST on sizing-linear breaches (user rule 2026-07-03): MC Ruin and DD
scale with lot. If the ONLY reject trigger is Ruin/DD at the tested sizing,
rescale into the DD band (lot is a linear lever), re-run MC at that size, and
re-verdict BEFORE issuing CANDIDATE_REJECT. Reject on Ruin/DD only when no
sizing fits (min-lot floor reached, or in-band sizing leaves the edge below
gate), an optimize probe finds no in-band config, or the EA opens no trades.
Edge-based triggers (OOS PF < 0.7, Score < 40) are NOT sizing-fixable — they
reject directly (PF is lot-scale invariant).

OOS missing cap: Mode B without OOS can never exceed CANDIDATE_WEAK.
Note: "OOS missing — candidate requires portfolio review with reduced confidence."
```

## SECTION 8 — OUTPUT FORMAT (Canonical YAML)

```yaml
validator_version: "2.0"
analysis_timestamp_utc: "ISO8601"
validation_mode: ""
upstream_verdict: ""

audit_trail:
  chain_id: ""            # propagated from backtest analysis
  parent_skill: "backtest-report-analyzer"
  parent_output_timestamp: ""
  revision_loop_count: 0

data_source:
  computed_by_script: true   # MUST be true; manual computation is forbidden
  script_output_files: []

candidate_flags:
  candidate_not_standalone:    false
  requires_portfolio_selector: false
  not_allowed_direct_live:     false
  mode_b_reason:               ""
  eligible_for_mode_b_source:  ""
  oos_missing_cap_applied:     false

monte_carlo:
  pf_5th: 0.0
  dd_95th_pct: 0.0
  prob_of_ruin_pct: 0.0
  bootstrap_used: false
  score: 0

wfa:
  status: "COMPUTED | SKIPPED_NO_DATA | INSUFFICIENT_WINDOWS"
  data_source: ""
  efficiency_ratio: 0.0
  oos_profitable_pct: 0.0
  score: 0
  verdict_cap_applied: false

oos:
  status: "COMPUTED | SKIPPED_NO_DATA"
  data_source: ""
  oos_pf: 0.0
  pf_degradation_pct: 0.0
  score: 0
  verdict_cap_applied: false

score:
  formula_used: ""
  mode_a_robustness_score: 0
  mode_b_candidate_score: 0
  band: ""

verdict:
  result: ""
  skipped_tests: []
  oos_missing_note: ""
  forwardable: true | false

handoff:
  next_skill: ""
  loop_count: 0
```

## SECTION 9 — HANDOFF MATRIX

```
Mode A:
  ROBUST   → live-deployment-controller (single)
           → portfolio-selector (multi-EA)
  MARGINAL → live-deployment-controller (marginal_flag=true)
  NOT_ROBUST → strategy-and-risk

Mode B:
  CANDIDATE_OK/WEAK → portfolio-selector (enforced)
  CANDIDATE_REJECT  → strategy-and-risk
  ALL Mode B → cannot go to live-deployment-controller directly
```

## FINAL RULE

Every successful output MUST terminate with EXACTLY ONE NEXT STEP block:

Mode A:
```
NEXT STEP:
Forward to the live-deployment-controller skill.
```
OR
```
NEXT STEP:
Forward to the portfolio-selector skill for multi-EA analysis.
```
OR
```
NEXT STEP:
Return to the strategy-and-risk skill. NOT_ROBUST.
```

Mode B:
```
NEXT STEP:
Forward to the portfolio-selector skill as portfolio candidate.
Direct live deployment NOT permitted.
```
OR
```
NEXT STEP:
Return to the strategy-and-risk skill. Not viable as portfolio candidate.
```
