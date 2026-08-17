# ExpertMAPSAR M3 — pre-registered optimize/validate task contract

Written BEFORE any optimizer launch, per the Control Tower task contract's own requirement
("PRE-REGISTER BEFORE ANY OPTIMIZATION"). This file is the evidence manifest; nothing below may
be changed after a coarse pass has been observed.

## Candidate identity (do not rerun M2)

- Candidate: ExpertMAPSAR
- Source: `D:\Forex\20_Selected EA\Advisors\ExpertMAPSAR.mq5`
- Source SHA-256: `6c5e7b665a766e6e995b673d9b8cd1e4c40e4de885c4413ad8f7e4b8a9a45e62`
- M2 evidence commits (accepted, not rerun): `e81a33c1a5121051bc66813f422c51e6edb239bd`,
  `5471fdde3d2b0c9ddb6e5c71d6474c0f354f222d`
- Accepted MAIN baseline (H1, Model 1, 2023.01.01-2025.12.31): 100 trades, PF 9.16, net +207.47,
  Sharpe 1.11, execution validity PASS.

## Canonical base

- `origin/master` verified at `4db22b4ebe3a1eb09b6e05ca95af78a599a879c8` (matches the Control
  Tower's expected starting SHA). Local HEAD carries the two M2 evidence commits on top
  (unpushed — no push authority granted here or by this task).

## Optimizer execution authority

- Checked `D:\EA_LAB_EXECUTOR_PROTOTYPE\executor_mvp.py`: `"enabled_controlled"` mode (the only
  mode that permits any real write/stage/commit/worker-launch adapter to run) is still gated on
  `_TEST_CONTROLLED_POLICY`, which is only set by a test-only setup path — there is no live code
  path that lets that Authorization Kernel mediate ordinary work against `D:\EA_LAB`. It is a
  separate governance prototype (memory: `controlled-execution-governance-prototype`), not a gate
  on Factory optimizer execution.
- `OPTIMIZER AUTHORITY: AUTHORIZED_BY_TASK_CONTRACT` — no fresh owner grant required. Ordinary
  canonical Factory optimizer execution (`scripts\mt5_optimize.ps1`, `scripts\mt5_run.ps1`)
  proceeds under this task contract.

## Scope discipline (single-writer / path-limited, per AGENTS.md + CLAUDE.md)

- Evidence directory: `_mt5_auto\M3_WAVE5_C4_MAPSAR\**` (new files only).
- No taskboard/session-ledger row opened — this task follows the same narrow, evidence-only
  pattern the accepted M2 commits used (no shared file touched, no lane collision surface).
- Commits: path-limited to this evidence directory only, `[claude]` tag, no `git add -A`, no
  push, no `--no-verify`.
- Untouched: vendor source, ExpertMACD evidence, Template lanes, Relay, monitoring, any other
  dirty/staged file already in the working tree at task open.

## Search home

- Symbol: NZDUSD.
- TFs: H1 (primary/home, accepted) and M30 (secondary robustness TF). No other TF this campaign.

## Windows

- MAIN (search + selection): 2023.01.01-2025.12.31, Model 1. This is the ONLY search surface.
- BWD (validation only, never used to rank/tune/select/revise): 2020.01.01-2022.12.31, same
  symbol/TF/Model, run once against the locked candidate only.

## Levers (exactly 3) and frozen inputs

Swept:
1. `Inp_Signal_MA_Period`: coarse {8, 10, 12, 14, 16}
2. `Inp_Signal_MA_Shift`: coarse {0, 3, 6, 9, 12}
3. `Inp_Trailing_ParabolicSAR_Step`: coarse {0.01, 0.015, 0.02, 0.025, 0.03}

Frozen (never swept this campaign):
- `Inp_Signal_MA_Method` = 0 (MODE_SMA)
- `Inp_Signal_MA_Applied` = 1 (PRICE_CLOSE)
- `Inp_Trailing_ParabolicSAR_Maximum` = 0.20
- Money module: `CMoneyNone` (unchanged) — `MoneySizeOptimized` must not be introduced.

Coarse grid size: 5x5x5 = 125 combos per TF, 250 total across both TFs. This is <=1,000 combos
=> **complete grid** (`Optimization=1`) per `backtest-optimize-rigor` Step 2 policy — not genetic.
No range in this grid may be widened during coarse search.

## Participation floor (pre-registered, binding — CLAUDE.md 2026-08-05 ratified floor)

- Any cell eligible for plateau consideration on EITHER TF must have >=100 closed trades on MAIN.
- A high-PF cell under 100 trades is NOT eligible, regardless of PF.
- No cross-TF trade pooling to meet the floor — H1 and M30 are judged independently.

## Plateau rule (pre-registered)

- Not top-1 PF. A plateau-center cell must: MAIN PF >= 1.20, participation >= 100, positive net,
  and not collapse under a one-step neighbouring-parameter change in any swept dimension.
- Canonical method = `backtest-optimize-rigor` Step 3 (plateau read: high mean AND high
  min-neighbour; fine grid only if the coarse complete-grid zone needs sharpening, centered on the
  coarse zone, never widened beyond the original coarse bounds).

## TF selection

- H1 and M30 evaluated independently on MAIN. The chosen TF/plateau candidate must itself clear
  MAIN PF >= 1.20, participation >= 100, and plateau-not-spike. Selection is by surface robustness,
  not top PF.

## Gate values (pre-registered pass/fail, CLAUDE.md VERDICT GATE + backtest-optimize-rigor)

- MAIN gate: PF >= 1.20 (hard) on the locked plateau-center candidate.
- BWD gate: PF >= 1.00 (hard for this task's disposition; BWD-fail does not trigger a return to
  MAIN search — canonical failure disposition only, no re-optimization).
- Both gates PASS => `M3_PASS`. MAIN gate fails on every plateau candidate across both TFs =>
  `PARAMETRIC_FAIL` (2a-style dead-optimized only after the fine-search-before-verdict step, per
  CLAUDE.md tree item 2a). BWD gate fails on an otherwise-passing MAIN candidate => `M3_FAIL`
  (report as such; do not search MAIN again per this task's explicit instruction).

## Explicitly out of scope this task

- Monte Carlo / holdout (2026H1): not run.
- Model 4 (every-tick): not run.
- Product/source repair: if a genuine defect surfaces, STOP and classify `A PRODUCT DEFECT`; do
  not repair source inside this task.
- No canonical push, deployment, EA attachment, trading, DEMO/LIVE, risk/default change, owner
  attestation, or destructive cleanup.

## Fine search (conditional, pre-registered ahead of time)

- Only run if the coarse complete-grid zone on the winning TF needs sharpening before a
  plateau-center can be read cleanly (backtest-optimize-rigor Step 3).
- If run: centered on the coarse plateau, never widened beyond {8-16} / {0-12} / {0.01-0.03}.
  Exact fine ranges are pre-registered in the evidence file for that TF before the fine job
  launches, not chosen after seeing fine results.

## Year-split method

- `scripts\report_year_split.py` on the ONE continuous MAIN report for the locked candidate.
  Independent standalone per-year reruns are not verdict evidence (confirmed unreliable on this
  exact PSAR/stateful candidate by the M2 evidence file — cold-start artifact, not a strategy
  signal).
