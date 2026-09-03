# BT9 — B15 Edge-Latch Portability 02 — AUDUSD/H4 — Results

Status: `PASS_MECHANICAL / HYPOTHESIS_NOT_FALSIFIED / PORTABLE_MECHANISM_HOME_NOT_QUALIFIED / RESEARCH_ONLY`
Hypothesis ID: `HYP-B15-EDGE-PORT-02`
Preregistration commit: `1266795fc49ac88a18c6b93b0fab478718102648`
Runtime: `MT5-lane3 / D:\Meta 5c`
Model: `1`; Optimization: `NONE`; HOLDOUT: `UNSPENT`

## 1. Frozen question

Prospectively test one new B15 home, AUDUSD/H4, with exactly one intervention: `_15_EdgeTrigger=true -> false`. All other mechanics, exits, sizing and tester controls remained frozen.

Direct consumer: test whether the mechanism-first workflow can separate a portable mechanism contribution from a weak home before spending compute on optimization.

## 2. Mechanical evidence

All 4 preregistered cells PASS: exact AUDUSD/H4, exact accepted build receipt `br-58971201f0774c47bf5e6f423c47e1bc`, EX5 SHA256 `f3dd7c5f2e2c1eb5a9f30a95a120e8977aa071e86f5ea4d9929e84f74940803a`, full `157/157` surface, exact parent/child set hashes, Model 1, Optimization 0, USD 10000, leverage 1:100, 99-100% history quality, no truncation and no HOLDOUT date.

The runner emitted the already-known mtime-only `STALE` warning because the clean worktree materialization time is newer than the accepted EX5. Git-byte reconciliation from accepted build lineage `cf32ba8d` to preregistered base `ff8b8200` found `NO_RELEVANT_BYTE_CHANGES`; exact source/EX5/receipt identities match accepted BT3/BT6 evidence.

## 3. Parent versus one-change child

| Window | Parent PF | Child PF | Parent net | Child net | Parent EqDD | Child EqDD | Parent trades | Child trades |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| MAIN 2023-2025 | 0.88 | 0.82 | -75.30 | -185.01 | 1.37% | 2.39% | 216 | 334 |
| BWD 2020-2022 | 0.96 | 0.94 | -28.70 | -76.91 | 1.53% | 1.94% | 214 | 337 |

Child deltas versus parent:
- MAIN: PF `-0.06`, net `-109.71`, EqDD `+1.02 pp`, trades `+118`.
- BWD: PF `-0.02`, net `-48.21`, EqDD `+0.41 pp`, trades `+123`.

The preregistered falsifier is not met. Removing the edge latch does not improve net while holding/reducing DD in both windows; instead it increases participation while worsening net, PF and DD in both windows.

## 4. Temporal distribution

Parent AUDUSD/H4 is not failing because of one isolated year. Parent yearly net is:
- 2020 `-11.44` (57 trades, PF 0.94)
- 2021 `-22.97` (78, PF 0.90)
- 2022 `+5.71` (79, PF 1.02)
- 2023 `+32.24` (76, PF 1.14)
- 2024 `-73.59` (66, PF 0.64)
- 2025 `-33.95` (74, PF 0.84)

Four of six calendar years are net-negative. The child does not repair that pattern; it creates more trades and remains aggregate-negative in both windows. This is cross-window/home weakness, not evidence for a single year or month filter.

## 5. Interpretation

The B15 one-fire-per-MACD-run edge latch remains a useful mechanism contribution on a fourth H4 symbol: disabling it again increases repeated firing and degrades economics. Together with prior GBPUSD, USDJPY and EURUSD evidence, this strengthens the mechanism-level conclusion that the latch suppresses harmful within-state over-trading.

However, AUDUSD/H4 itself has no positive fixed-config base edge in either accepted window: parent PF is below 1 in MAIN and BWD despite >200 trades per window. A portable mechanism is therefore not sufficient to make every home viable.

This is exactly the distinction the mechanism-first workflow was intended to expose: **retain the mechanism knowledge, reject this home for parameter optimization, and do not attempt to rescue a negative base with tuning.**

`WORKFLOW_CHECK = SUPPORTED_BY_THIS_EXPERIMENT`, not universal proof. The evidence shows the workflow avoided an unnecessary optimization branch on this one new home.

## 6. Decision / scrutiny

- Mechanism verdict: `HYPOTHESIS_NOT_FALSIFIED / PORTABLE_MECHANISM_SUPPORTED`.
- Home verdict: `AUDUSD_H4_NOT_QUALIFIED_FOR_OPTIMIZATION_FROM_THIS_EVIDENCE`.
- Next action for this home: `STOP_EXPANSION / PARK`; do not tune CountBars, MACD, EdgeTrigger, exits or BWD to rescue it.
- Negative evidence is retained because it defines a portability boundary: useful mechanism, weak home.
- No hindsight exclusion of 2024/2025 or adverse subperiod is authorized.

Evidence, interpretation and decision are separated above. No Candidate/Grade/KINT, optimization, HOLDOUT, risk/default, deployment, runtime attachment, trading or LIVE authority follows.

## 7. Durable artifacts

- `factory/runs/bt9_20260903/b15_edge_port02/evidence_summary.json`
- `factory/runs/bt9_20260903/b15_edge_port02/mechanical_acceptance.json`
- `factory/runs/bt9_20260903/b15_edge_port02/parent_child.csv`
- `factory/runs/bt9_20260903/b15_edge_port02/year_split.csv`
- `factory/runs/bt9_20260903/b15_edge_port02/r2_parent_child.svg` (`VISUAL_ONLY_NO_AUTHORITY`)
- compressed raw reports, INIs, leverage/truncation sidecars and execution log under the same run root.
