# Second Brain Milestone — Boss19 P4 Broad36 Runner Guard

Status: **RESEARCH_ONLY / RUNNER_GUARD_CLOSED / BROAD36 ROI STILL SEPARATE**

Canonical base: `c6e9458aa276504b29d1107df107744c74d4b9da`.
Accepted guard closure: `2d333d367a93fa93c2e01c5055edbcca805463b2`.
Direct consumers: Boss19 P4/P5 routing and future worker deduplication.

## Evidence

The first broad36 ROI-contract review identified two mechanical pre-runtime defects: the runner could emit PASS with non-zero `unknown_time_unit_count`, and it did not pin every accepted Repair03 identity before MT5 launch.

The accepted runner repair now fail-closes on:

- frozen H3 manifest SHA;
- diagnostic source SHA;
- diagnostic EX5 SHA, pre-run and post-run;
- exact accepted build receipt ID;
- Repair03 build-receipt-registry SHA;
- frozen set SHA;
- `unknown_time_unit_count == 0` before PASS.

Focused unit-export regression on current canonical = **53/53 PASS**. The independent exact-head runner-guard review reported **PASS / no material findings**.

## Interpretation

The mechanical execution-precondition defect is closed. This removes one reason broad36 could not safely start, but it does not answer whether broad36 is worth running and does not create P4 regime evidence.

Runner refusal remains an instrumentation/provenance event. It must not be promoted into a strategy failure.

## Decision support

- Keep Repair03 provenance PASS as accepted one-cell evidence.
- Keep the runner-guard closure as durable pre-runtime evidence.
- Keep broad36 locked until the separate ROI gate itself is accepted.
- If ROI later passes, reuse the exact fail-closed runner and respect the existing primary MT5-lane1 ownership contract.
- If ROI declines, do not execute broad36 merely because the runner is ready.

## Authority and unknowns

No broad36 MT5 batch has been accepted from this milestone. No P4 classifier join has been executed. HOLDOUT remains UNSPENT; optimization remains NONE. Candidate/Grade/KINT/DEMO-LIVE/risk/default/deployment authority remains absent.

The active UNKNOWN is the separate accepted ROI decision and, only after an authorized batch, the resulting frozen P4 regime/unit attribution.

## Milestone scrutiny

This work was necessary because the runner-guard closure materially changes the P4 blocker map and prevents future workers from repeating a repair already accepted. It does not manufacture a new experiment, use outcome-driven tuning, or convert execution readiness into strategy evidence.
