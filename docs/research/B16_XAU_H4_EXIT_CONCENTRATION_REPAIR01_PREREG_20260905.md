# B16 XAUUSD/H4 Exit-Concentration Repair01 — Preregistration

Status: `PREREGISTERED_REPAIR01 / RESEARCH_ONLY / ZERO_NEW_MT5`
Hypothesis: `HYP-B16-XAU-H4-EXITCONC-01`
Parent preregistration: `adada829b642f8f1691f0ca37fb88c338c8087d4`
Repair scope: evidence-control source only; hypothesis, eligible child windows, metrics, falsifier, stop rule and authority ceiling are unchanged.

## Trigger

V1 stopped prospectively at `BLOCKED_CONTROL_MISMATCH` before any exit-off child concentration outcome was calculated. The permitted `DEEP_SPACING_EQUAL` proxy does not reproduce accepted XAUUSD/H4 parent MAIN headline evidence and therefore cannot serve as the control.

A canonical accepted H03 parsed parent object already exists at `_mt5_auto/b16_h03/B16_H03_PARSED.json`, SHA256 `3639c9abcc8c299cf11ce1eb310ed9e721f43831870e213baafeb2e59f6a0fb6`. It was created from the exact accepted H02 parent reports, not from any exit-off result.

Exact parent report bindings inside that object:
- MAIN report SHA256 `aee6819ba12f929caade4cf1b70915978a3259ec2b7136a1009e077057bb0e7e`;
- BWD report SHA256 `df63addd9975b66a9471aafe929d3b7f31377a95a93342cc6f1521728f07cff3`.
## Frozen Repair01 control derivation

For MAIN and BWD separately, Repair01 must first validate all of the following inside the pinned parsed parent object:
- `input.report_sha256` equals the exact accepted report SHA above;
- `identity.report` reproduces accepted parent PF/net/trades/EqDD;
- all stored reconciliation flags remain true;
- numeric year bins are exactly 2023/2024/2025 for MAIN and 2020/2021/2022 for BWD.

Only then derive the four same-window control dimensions from the stored accepted parent object using the already-frozen formulas:
1. `max_cycle_holding_duration` = maximum `cycles[].duration_seconds` divided by 86400;
2. `active_time_share` = `exposure.active_time_share_full_window`;
3. `top1_positive_cycle_gp_share` = maximum positive `cycles[].gross_profit` divided by the sum of positive cycle gross profit;
4. `zero_closed_year_count` = count of numeric year bins with `closed_ticket_count == 0`.

No alternate parent, proxy, parser, threshold, or metric definition may be introduced after Repair01 is canonical.
## Child evidence and verdict rule — unchanged

Eligible child windows remain exactly:
- `SINGLETP_OFF / XAU_H4 / MAIN`;
- `SINGLETP_OFF / XAU_H4 / BWD`;
- `BASKETTP_OFF / XAU_H4 / MAIN`.

`BASKETTP_OFF / XAU_H4 / BWD` remains mechanically ineligible hard-cage evidence at 25.00% DD and cannot satisfy or fail the verdict.

Each eligible window remains `CONCENTRATION_SHIFT` only when at least 3 of the original 4 dimensions are higher than the exact same-window accepted parent control. Overall rule remains: 3/3 -> `HYPOTHESIS_NOT_FALSIFIED / EXIT_CONCENTRATION_REPLICATED`; 1-2/3 -> `MIXED_CONCENTRATION_EVIDENCE`; 0/3 -> `HYPOTHESIS_FALSIFIED / NO_CONCENTRATION_REPLICATION`.

## Loop breaker / authority

Repair01 is the single bounded repair for this diagnostic. If the pinned H03 parent object fails any binding/reconciliation check, or Repair01 cannot produce the frozen metrics, stop `BLOCKED`; do not choose another proxy, rerun MT5, or open Repair02 automatically.

`RESEARCH_ONLY`. Optimization `NONE`; HOLDOUT `UNSPENT`; no strategy/default, Model4/Candidate, Grade/KINT, DEMO/LIVE, deployment, trading or risk authority. Repair01 must be pushed canonical before any eligible child concentration calculation is performed.
