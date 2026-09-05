# B16 XAUUSD/H4 Exit-Concentration Diagnostic — Preregistration

Status: `PREREGISTERED / RESEARCH_ONLY / ZERO_NEW_MT5`
Hypothesis ID: `HYP-B16-XAU-H4-EXITCONC-01`
Canonical base before preregistration: `244c15d5c01dfdf31b3ce11daf578897b0376376`
Family: `Boss_16_KangarooGrid`; Symbol/TF: `XAUUSD/H4`
Optimization: `NONE`; HOLDOUT: `UNSPENT`; new Strategy Tester runs: `NONE`.

## Observation before this diagnostic

Accepted R2 evidence already shows that disabling Single TP or Basket TP can materially change aggregate XAUUSD/H4 economics. The accepted USDJPY/H1 read-only exit diagnostic later showed that similar aggregate improvements there were accompanied by extreme holding/cycle/profit concentration. No XAUUSD/H4 concentration diagnostic has yet been accepted.

This task does not choose or change an exit parameter. It asks only whether the existing XAUUSD/H4 exit-off evidence changes the realized path toward concentration when measured with the already-accepted USDJPY/H1 method.

## Frozen evidence inputs

Reuse only tracked bytes under `factory/runs/b16_characterization_20260830/`:

- `SINGLETP_OFF / XAU_H4 / MAIN` report SHA256 `6d21c76cf14303a137ccb2054e0204174e94b13a8ac0497591369db3a693fd0e`;
- `SINGLETP_OFF / XAU_H4 / BWD` report SHA256 `0687487caed64405460479d9aab64cf542ef84ede4ef4202c1039586e5875002`;
- `BASKETTP_OFF / XAU_H4 / MAIN` report SHA256 `d30337e734dfe9c5d9a42582dc533deceaf032b25aec2f9f64a158d5e2e3e063`;
- `BASKETTP_OFF / XAU_H4 / BWD` is retained as mechanically ineligible hard-cage evidence (`25.00% DD` at market time `2022.07.13 15:41:40`) and cannot support the full-window concentration verdict;
- `DEEP_SPACING_EQUAL / XAU_H4 / MAIN+BWD` may be used only as a matched-output behavior control after deterministic headline reconciliation against accepted parent aggregate evidence.
Accepted parent aggregate reference from `aggregate/parent_contexts.json`: MAIN PF 4.08 / net +707.78 / 79 trades / EqDD 6.27%; BWD PF 1.44 / net +512.69 / 148 trades / EqDD 8.29%.

Parent raw report bytes are not asserted available. `DEEP_SPACING_EQUAL` is not a parent substitute unless its direct parse reproduces the accepted parent headline net/PF/trades/EqDD for that window. Any mismatch is `CONTROL_MISMATCH / STOP`; do not fabricate parent cycle statistics.

## Frozen method

Reuse `scripts/research/b16_h03/parse_h02_reports.py` and the calculation definitions already accepted in `factory/runs/b16_exitdiag_20260831/usdjpy_h1/analyze_exitdiag.py`:

- flat-to-nonflat-to-flat cycle count and duration;
- active-time share over the full window;
- max basket depth;
- positive-cycle gross-profit concentration (`top1_gp_share`, `top3_gp_share`);
- per-calendar-year closed tickets, cycles, net, and active-time share;
- report headline net/PF/trades/EqDD with raw MT5 PF preserved when gross loss is zero.

No alternative parser, cycle pairing rule, threshold search, or output exclusion may be chosen after the XAUUSD/H4 results are calculated.

## Preregistered question and falsifier

Hypothesis: the eligible XAUUSD/H4 exit-off paths are materially more concentrated than the matched-output control, consistent with exits controlling holding duration and distribution rather than merely reducing aggregate return.

For each eligible exit-off window, compare exactly four concentration dimensions to the same-window reconciled control:

1. maximum cycle holding duration is higher;
2. active-time share is higher;
3. top-1 positive-cycle gross-profit share is higher;
4. count of calendar years with zero closed tickets is higher.
A window is `CONCENTRATION_SHIFT` only if at least 3 of these 4 dimensions are higher than the reconciled control. This is a direction-of-change diagnostic, not a universal magnitude threshold.

Overall classification is frozen before calculation:

- all 3 eligible exit-off windows are `CONCENTRATION_SHIFT` -> `HYPOTHESIS_NOT_FALSIFIED / EXIT_CONCENTRATION_REPLICATED`;
- 1 or 2 of 3 -> `MIXED_CONCENTRATION_EVIDENCE`;
- 0 of 3 -> `HYPOTHESIS_FALSIFIED / NO_CONCENTRATION_REPLICATION`;
- missing/unparseable evidence or control reconciliation failure -> mechanical/evidence BLOCKED, not strategy evidence.

`BASKETTP_OFF/BWD` remains recorded but mechanically ineligible and cannot be used to satisfy or fail the 3-window classification.

## Stop rule and direct consumer

Run the deterministic parser once on the frozen bytes, build machine-readable diagnostics, interpret against the rule above, and stop. No MT5 rerun, no additional exit variant, no parameter search, no BWD retuning, and no HOLDOUT use.

Direct consumer: decide only whether a **future separately preregistered XAUUSD/H4 exit-redesign question is worth opening**. Even `HYPOTHESIS_NOT_FALSIFIED` does not authorize exit redesign; it instead raises the evidence bar by requiring any future redesign to preserve participation/concentration as an explicit guardrail. A falsified result also does not authorize changing exits; it merely removes this concentration argument.

## Authority ceiling

`RESEARCH_ONLY`. No strategy default, optimization, Model4/Candidate, Grade/KINT, HOLDOUT, DEMO/LIVE, deployment, trading, or risk/default authority. This preregistration must be canonical before XAUUSD/H4 concentration outputs are calculated.
