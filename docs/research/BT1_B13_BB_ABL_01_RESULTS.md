# BT1 â€” B13 Bollinger-Gate Ablation 01 â€” Results

Status: `PASS / HYPOTHESIS_NOT_FALSIFIED`
Hypothesis ID: `HYP-B13-BB-ABL-01`
Report level: `R2 MECHANISM`
Canonical base SHA: `b26af204faf7907fe7e78a2b5f90a5dfa8c6bc02`
Preregistration commit: `0b4922237c4bbccaedde359b20c72241f4af75b5`
Runtime: `MT5-lane3 / D:\Meta 5c`
HOLDOUT: `UNSPENT`
Optimization: `NONE`
MECHANISM_VALUE: `UNCLEAR`

## EVIDENCE â€” mechanical acceptance

Both cells are mechanically `PASS`.

- Expert: `EALabTpl\Boss_13_MeanRev`.
- EX5 SHA256: `23daca942b38ccb2927d4674471b69392fc445ee306d09d959350675e5408a06`.
- Build receipt: `br-a2740eb18db349a58c3aa177b45389e6`.
- Variant set SHA256: `c21ce81236414edd35ea2d953b886d955ee398125a007f01e4cc397d01ea23ed`.
- Config fingerprint: `3ae41cf329ff437f719cad16984aa8516d325f8b78ab6528dd319df734321afa`.
- Only semantic change: `_13_RequireBB=true -> false`; canonical source defines this as RSI-only.
- XAUUSD/M15; Model 1; Optimization 0; Forward 0; USD 10000; leverage 1:100.
- Leverage sidecars are `MATCH`; truncation sidecars are `false`; both reports are newer than their run start.
- MAIN last deal 2025-12-30; BWD last deal 2022-12-30.
- No HOLDOUT date was used.
The runner's mtime-only stale detector printed `STALE` because the fresh linked worktree materialized source files on 2026-08-30 after the accepted EX5 build time. Deterministic Git-byte reconciliation shows `NO_RELEVANT_BYTE_CHANGES` from build ref `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125` to pushed canonical `f3f95d6964c3bdff966697439007b6c0b152aecb` for `Boss_13_MeanRev.mq5` and `ea_template/core`; the relevant Git blob IDs are identical. This is an mtime false-positive, not a source/binary mismatch.

## EVIDENCE â€” parent vs child

| Window | Variant | PF | Trades | Net | EqDD% | Quality | Full window | Report SHA256 |
|---|---|---:|---:|---:|---:|---|---|---|
| MAIN | accepted parent | 1.06 | 3929 | 1063.38 | 6.32 | 98% | yes | `121cd1458c7efe25e933399692a89282f534b65c14127393e9a530d22817713f` |
| MAIN | child RSI-only | 1.06 | 3994 | 1056.60 | 6.27 | 98% | yes | `af38dde3a437820a1cea450e3c422a47471538eff87c6c280e6c7e640f5083ab` |
| BWD | accepted parent | 1.02 | 3300 | 253.56 | 3.72 | 99% | yes | `684456e1890cdd470540f588958c967408360b943632d81fabfdad9fb4c22041` |
| BWD | child RSI-only | 1.03 | 3403 | 296.67 | 3.53 | 99% | yes | `2d632e4bd588818ff133f30a9d278dcd7c60429925e9a768b1765b3ed710746d` |

Parent -> child deltas:
- MAIN: PF `0.00`, net `-6.78`, EqDD `-0.05 pp`, trades `+65`.
- BWD: PF `+0.01`, net `+43.11`, EqDD `-0.19 pp`, trades `+103`.

## EVIDENCE â€” child yearly distribution

| Window | Year | Trades | PF | Net | Closed-deal balance DD% |
|---|---:|---:|---:|---:|---:|
| MAIN | 2023 | 1267 | 1.04 | 157.42 | 3.41 |
| MAIN | 2024 | 1308 | 1.08 | 398.52 | 3.00 |
| MAIN | 2025 | 1419 | 1.05 | 500.66 | 6.14 |
| BWD | 2020 | 1090 | 1.00 | 4.43 | 3.44 |
| BWD | 2021 | 1107 | 1.00 | 15.87 | 3.37 |
| BWD | 2022 | 1206 | 1.08 | 276.37 | 2.53 |

`year_split.csv` and `equity_curve.csv` are the machine-readable sources for the R2 views.

R2 visual pack:
- `r2_equity_curve.svg` â€” child closed-deal equity proxy, MAIN + BWD;
- `r2_underwater.svg` â€” child closed-deal balance drawdown, MAIN + BWD;
- `r2_year_distribution.svg` â€” annual child net/trade participation;
- `r2_parent_child.svg` â€” mechanism-on/off and parent-vs-child comparison.

All visuals are `VISUAL_ONLY_NO_AUTHORITY` and are reproducible from committed machine-readable evidence plus `build_r2_bundle.py`.

## INTERPRETATION

Cell level: removing the BB gate increases participation in both windows. MAIN net is nearly unchanged but slightly lower, with slightly lower EqDD. BWD net is higher with slightly lower EqDD. Every child calendar year remains net-positive, but 2020/2021 BWD PF is only marginally above 1; this is evidence, not a universal grade statement.

Concept level: the experiment does not demonstrate that the BB gate is indispensable, but the preregistered redundancy test also does not pass because MAIN child net is lower than parent. The evidence therefore supports `UNCLEAR`, not a winner and not an optimizer seed.

Reusable mechanism finding: the BB condition suppresses a modest number of RSI-extreme trades, but its cross-window value is mixed under the frozen parent settings. The current evidence does not justify deleting the gate or tuning RSI/BB thresholds.

## DECISION

The preregistered hypothesis "BB gate is necessary for useful selectivity" is `NOT_FALSIFIED`: the child satisfies non-higher EqDD in both windows and non-lower net in BWD, but fails the required non-lower-net condition in MAIN (`1056.60 < 1063.38`).

No automatic parameter search is unlocked. A later consumer may use the existing report ledger for read-only attribution of the additional RSI-only trades before proposing another one-change experiment.

Authority remains research-only; no optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default, KINT, or grade authority is created.
