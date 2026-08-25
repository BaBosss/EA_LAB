---
name: live-deployment-controller
description: >
  Final deployment gate before live trading — pre-deploy checklist, position
  sizing, monitoring criteria, and kill-switch configuration. Use when the
  user wants to deploy a validated EA (or APPROVED portfolio) to a live or
  demo account, or asks about go-live readiness.
---

# Live Deployment Controller

## UNIT CONVENTION

```
- Fields ending with *_percent are values 0–100 (10.0 means 10%, NOT 0.10)
- Fields ending with _ratio or _weight are decimals 0.0–1.0
- All percent-form fields MUST be divided by 100 before use in
  multiplicative calculations.
```

## ROLE

**This skill is THE DEPLOY GATE** — judge criteria, kill-switches, and sizing,
feeding a row into `DEPLOYMENTS.csv`. Final gate check before live trading.
Issues: **DEPLOY_APPROVED / HOLD / REJECT**. No performance forecasts. No
profit guarantees.

`vps-deploy-ops` (the shipping step) requires this gate's output —
judge criteria + the DEPLOYMENTS.csv row — before anything goes to an account.

> Routing between stages is owned by `docs/PIPELINE.md` — this skill owns its own stage mechanics only.

## SECTION 1 — INPUT PATH SELECTION

### 1.1 Single EA Path
```
Requires: robustness verdict IN {ROBUST, MARGINAL}
IF NOT_ROBUST → REJECT immediately
IF candidate_not_standalone == true → REJECT immediately
   "Portfolio candidate must pass portfolio-selector first."
```

### 1.2 Multi-EA Path
```
Requires: portfolio verdict == "APPROVED" from the portfolio-selector skill
IF portfolio analysis missing but multi-EA intended → REFUSE
IF verdict == "REBALANCE" → HOLD (resubmit to portfolio-selector until APPROVED)
IF verdict IN {"REJECT", "INSUFFICIENT_EAs"} → REJECT immediately
Position sizing MUST use portfolio_composition weights.
```

Revision loop ≥ 3 without DEPLOY_APPROVED → WARNING (does not block).

## SECTION 2 — PRE-DEPLOY CHECKLIST

### 2.1 Single EA (13 items)
```
[R1] Robustness verdict = ROBUST or MARGINAL
[R2] Robustness Score >= 55
[R3] MC Ruin Probability < 10%
[R4] OOS PF > 1.0 (if OOS computed)

[A1] Live balance >= Backtest_Deposit × 0.5
[A2] Account type matches Spec Card
[A3] Leverage >= minimum
[A4] Free Margin > 3× expected max positions margin

[E1] Magic Number unique
[E2] Symbol available on broker
[E3] Lot size >= broker minimum
[E4] Stop Level compatible with SL distance

[O1] Forward test PF > 1.0 (optional, not blocking)

[R1, R2, R3, A2] FAIL → REJECT
[A1, A3, A4, E1–E4] FAIL → HOLD
```

### 2.2 Multi-EA Additional
```
[P1] portfolio verdict == "APPROVED"
[P2] combined expected DD <= account budget
[P3] all CANDIDATE EAs flagged candidate_not_standalone AND in portfolio
[P4] no EA has NOT_ROBUST verdict
[P5] no symbol > 80% exposure

[P1, P4] FAIL → REJECT
[P2, P3, P5] FAIL → HOLD
```

## CENT ACCOUNT SIZING PITFALL (check BEFORE deploying any EA to a cent account)

Cent accounts (e.g. 10,000 cent = equivalent of $100) have the same lot minimums as standard accounts (0.01). If an EA uses a balance-derived formula, the computed lot may fall BELOW the broker minimum → EA places 0 trades silently.

**Pattern to check:**
```
formula-based EA: lot = balance / Lots_divided
→ 10,000 (cent) / 10,000,000 = 0.001 → below min 0.01 → NO TRADES
Fix: Lots_divided = 100,000 → 10,000 / 100,000 = 0.1/leg ✅
```

**Checklist item [E3] must be verified on CENT balance, not standard balance:**
- Compute `balance / Lots_divided` for balance-derived EAs
- If result < broker min lot (0.01), fix Lots_divided before deploying
- Fixed-lot EAs (0.01 per trade) work on cent accounts without modification

**Real incident (2026-06-22):** ST_EA03 deployed with Lots_divided=10,000,000 on 10,000 cent → 0.001/leg → all trades blocked. Fixed to Lots_divided=100,000 → 0.1/leg × 3 positions = fine.

## SECTION 3 — POSITION SIZING

### 3.1 Single EA
```
Scale_Factor = Live_Balance / Backtest_Deposit
Live_BaseLot = Backtest_BaseLot × Scale_Factor
IF MARGINAL: Live_BaseLot ×= 0.75
Always snap to broker volume step and min/max.
```

### 3.2 Multi-EA — Portfolio Weight Based
```
total_risk_budget_percent is 0–100 → divide by 100.0.
MUST use portfolio_composition weights.

EA_Budget_i = Live_Balance × (total_risk_budget_percent / 100.0) × Weight_i
EA_Lot_i    = EA_Budget_i / (Margin_Per_Lot × MaxPositions_i)

Caps: >= broker min lot; <= portfolio max_lot per EA;
CANDIDATE EAs: 20% additional reduction (already applied in portfolio output);
MARGINAL: 25% reduction on top of weight.
```

## SECTION 4 — MONITORING CRITERIA

### EA-Level
```
ALERT_DD          = Backtest_MaxDD × 1.2
ALERT_PF          = Backtest_PF × 0.7 (30-day rolling)
ALERT_CONSEC_LOSS = Backtest_MaxConsecLoss + 2
ALERT_TRADE_FREQ  = Backtest_TradesPerMonth × 0.5
```

### Portfolio-Level (Multi-EA)
```
PORTFOLIO_DD_ALERT        = expected_dd_pct × 1.2
WORST_MONTH_LOSS_ALERT    = worst_same_month_loss_pct × 1.1
SYMBOL_CONCENTRATION      > 80% live exposure → block new orders on that symbol
CANDIDATE_WEIGHT_ENFORCED : candidate lot > max_lot → reject order
```

## SECTION 5 — KILL-SWITCH RULES

### HARD
```
[KS-1] Live DD >= EmergencyExitDD (default 70%) → CloseAll + disable
[KS-2] Free Margin < 20% of Balance → Close all
[KS-3] Single trade Lot > Live_BaseLot × 3 → Reject + alert
[KS-4] 3 consecutive TRADE_RETCODE errors → Pause 1 hour
```

### SOFT
```
[KS-5] Rolling 30-day PF < Backtest_PF × 0.6 → Pause new entries
[KS-6] Live DD >= Backtest_MaxDD × 1.2 → Pause new entries
[KS-7] CB triggered 3× in 1 week → Pause 72 hours
```

### Portfolio
```
[PKS-1] Combined live DD >= expected_dd_pct × 1.3 → Pause ALL new entries
[PKS-2] MTD combined loss > worst_same_month_loss_pct × 1.5 → Pause all + alert
[PKS-3] Live exposure > 80% single symbol → block new orders on that symbol
[PKS-4] CANDIDATE EA exceeds max_lot → block new entries for that EA
```

### Post-Kill Recovery
```
HARD (KS-1..4): 7-day mandatory cooldown → re-validate via robustness-validator
  (ROBUST required) → resume at 50% lot, scale UP to full after 2 incident-free
  weeks. No manual override.
SOFT (KS-5..7): 72-hour cooldown + manual review log.
  3 soft kills in 30 days → escalate to HARD.
PORTFOLIO:
  PKS-1: 24-hour pause → review
  PKS-2: month-end review → consider rebalancing
  PKS-3: block until concentration reduces
  PKS-4: block candidate entries; if removal leaves < 2 EAs → forward remaining
         EA to single-EA deployment and halt portfolio operation; else continue
         reduced portfolio and re-check DD overlap.
```

## SECTION 6 — DEPLOYMENT VERDICT

```
DEPLOY_APPROVED: all checklist items pass + sizing within constraints
HOLD:   fixable items fail (A/E/P2/P3/P5) OR portfolio = REBALANCE
REJECT: R1, R2, R3, A2, P1, P4 fail OR NOT_ROBUST
        OR candidate_not_standalone without portfolio approval
        OR portfolio = REJECT/INSUFFICIENT_EAs
```

## SECTION 7 — CANONICAL YAML

```yaml
controller_version: "2.0"
analysis_timestamp_utc: "ISO8601"
deployment_path: "SINGLE_EA | MULTI_EA"

audit_trail:
  chain_id: ""
  parent_skill: "robustness-validator | portfolio-selector"
  parent_output_timestamp: ""
  revision_loop_count: 0

identity:
  ea_names: []
  symbols: []
  account_type: ""
  broker: ""

checklist:
  single_ea:
    r1_robustness_verdict: true
    r2_robustness_score: true
    r3_ruin_probability: true
    r4_oos_pf_positive: true
    a1_balance_adequate: true
    a2_account_type_match: true
    a3_leverage_ok: true
    a4_free_margin_ok: true
    e1_magic_unique: true
    e2_symbol_available: true
    e3_lot_above_minimum: true
    e4_stop_level_ok: true
  multi_ea_additional:
    p1_portfolio_verdict_approved: true
    p2_combined_dd_in_budget: true
    p3_candidates_in_portfolio: true
    p4_no_not_robust_ea: true
    p5_symbol_concentration_ok: true

position_sizing:
  path: "SINGLE_EA | PORTFOLIO_WEIGHTED"
  formula_note: "EA_Budget_i = Balance × (total_risk_budget_percent / 100.0) × Weight_i"
  per_ea:
    - {ea_name: "", portfolio_weight: 0.0, live_base_lot: 0.0, max_lot: 0.0, sizing_note: ""}

monitoring_criteria:
  ea_level: {dd_alert_pct: 0.0, pf_alert: 0.0, consec_loss: 0, trade_freq_pmo: 0.0}
  portfolio_level:
    portfolio_dd_alert_pct: 0.0
    worst_month_loss_alert_pct: 0.0
    symbol_concentration_pct: 80.0
    candidate_weight_enforced: true

kill_switches:
  hard: [KS-1, KS-2, KS-3, KS-4]
  soft: [KS-5, KS-6, KS-7]
  portfolio: [PKS-1, PKS-2, PKS-3, PKS-4]

post_kill_recovery:
  hard_cooldown_days: 7
  hard_resume_lot_pct: 50
  hard_scale_up_weeks: 2
  soft_cooldown_hours: 72
  escalation_at: 3
  pks4_single_ea_fallback: false

verdict:
  result: "DEPLOY_APPROVED | HOLD | REJECT"
  blocking_items: []
  hold_items: []
  hold_reason: ""
```

## FINAL RULE

Every output MUST terminate with EXACTLY one of:

```
NEXT STEP:
EA is approved for deployment.
Forward the judge criteria + DEPLOYMENTS.csv row to vps-deploy-ops to compile,
bundle, and ship.
Configure kill-switches in MT5 before going live.
Monitor daily against criteria in this report.
```
OR
```
NEXT STEP:
Resolve HOLD items listed above and resubmit.
[If HOLD reason = REBALANCE: return to the portfolio-selector skill
 and resubmit until verdict = APPROVED.]
```
OR
```
NEXT STEP:
Deployment REJECTED.
Return to [upstream skill] to address blocking issues.
```


---

## 🔒 CHECKLIST ADDITIONS (2026-07-10 — ระบบใหม่ที่ deploy ต้องรู้จัก)

- [ ] **NewsGuard config**: เพิ่ม magic ของ EA ใหม่เข้า GuardConfig บนบัญชีนั้น (นโยบาย C/B/N ตาม
      ประเภท: no-SL → C · breakout/มี SL → B · bench เก็บ data → N) — คู่มือท้าย ORDER-083 ·
      ห้าม magic 0 เด็ดขาด
- [ ] **Dashboard cohort map**: เพิ่ม magic → ชื่อ EA + KillDD/WarnDD ใน `scripts\live_dashboard.ps1`
      ($cohort, key = "login|magic") — ไม่งั้นขึ้น "unmapped" บนมือถือ user