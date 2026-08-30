# BT1 â€” B16 Position-Engine Ablation 01 â€” Results

Status: `PASS / HYPOTHESIS_FALSIFIED`
Hypothesis ID: `HYP-B16-PE-ABL-01`
Report level: `R2 MECHANISM`
Canonical base SHA: `b26af204faf7907fe7e78a2b5f90a5dfa8c6bc02`
Preregistration commit: `b0d8e940b04fcc5cb6fdfab456533c055a4f4258`
Runtime: `MT5-lane2 / D:\Meta 5b`
HOLDOUT: `UNSPENT`
Optimization: `NONE`
MECHANISM_VALUE: `WEAK`

## EVIDENCE â€” mechanical acceptance

Both cells are mechanically `PASS`.

- Expert: `EALabTpl\Boss_16_KangarooGrid`.
- EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
- Build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`.
- Variant set SHA256: `07670fdd3da9f7b3e0006c6035bd25422257223403d24b885e7176ae5812d736`.
- Config fingerprint: `1eb741aa9be22d130d939440a00ff9890e5907c35ff1cbfd76809ee473aeadf8`.
- Only semantic change: `_16_MaxOrdersPerSide=10 -> 1`.
- XAUUSD/H4; Model 1; Optimization 0; Forward 0; USD 10000; leverage 1:100.
- Leverage sidecars are `MATCH`; truncation sidecars are `false`; both reports are newer than their run start.
- MAIN last deal 2025-12-30; BWD last deal 2022-10-11 and passed the canonical idle-tail tolerance.
- No HOLDOUT date was used.
The runner's mtime-only stale detector printed `STALE` because the fresh linked worktree materialized source files on 2026-08-30 after the accepted EX5 build time. Deterministic Git-byte reconciliation shows `NO_RELEVANT_BYTE_CHANGES` from build ref `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125` to pushed canonical `f3f95d6964c3bdff966697439007b6c0b152aecb` for `Boss_16_KangarooGrid.mq5` and `ea_template/core`; the relevant Git blob IDs are identical. This is recorded as an mtime false-positive, not a source/binary mismatch.

## EVIDENCE â€” parent vs child

| Window | Variant | PF | Trades | Net | EqDD% | Quality | Full window | Report SHA256 |
|---|---|---:|---:|---:|---:|---|---|---|
| MAIN | accepted parent | 4.08 | 79 | 707.78 | 6.27 | 98% | yes | `aee6819ba12f929caade4cf1b70915978a3259ec2b7136a1009e077057bb0e7e` |
| MAIN | child MaxOrders=1 | 2.41 | 49 | 149.08 | 1.18 | 98% | yes | `6b284a80850fca611f1461e32b39990ed671de5ed6a26d584488d8c8da7ac281` |
| BWD | accepted parent | 1.44 | 148 | 512.69 | 8.29 | 99% | yes | `df63addd9975b66a9471aafe929d3b7f31377a95a93342cc6f1521728f07cff3` |
| BWD | child MaxOrders=1 | 0.90 | 76 | -32.09 | 2.42 | 99% | yes | `41ce438cb2d4b05b158fea84c90b492b6399aae8f6fdec52f70ede32d62686a1` |

Parent -> child deltas:
- MAIN: PF `-1.67`, net `-558.70`, EqDD `-5.09 pp`, trades `-30`.
- BWD: PF `-0.54`, net `-544.78`, EqDD `-5.87 pp`, trades `-72`.

The drawdown reduction is expected when the add/position-depth path is removed; it does not rescue the preregistered profitability hypothesis.

## EVIDENCE â€” child yearly distribution

| Window | Year | Trades | PF | Net | Closed-deal balance DD% |
|---|---:|---:|---:|---:|---:|
| MAIN | 2023 | 22 | 4.45 | 41.49 | 0.12 |
| MAIN | 2024 | 16 | 0.83 | -15.79 | 0.93 |
| MAIN | 2025 | 11 | no loss denominator | 123.38 | 0.70 |
| BWD | 2020 | 21 | 1.08 | 7.55 | 0.90 |
| BWD | 2021 | 30 | 1.03 | 2.88 | 1.06 |
| BWD | 2022 | 25 | 0.65 | -42.52 | 1.62 |

`year_split.csv` and `equity_curve.csv` are the machine-readable sources for the R2 views. For this MaxOrders=1 child, each closed position is also a single-position episode; no multi-entry basket is being hidden behind ticket counts.

R2 visual pack:
- `r2_equity_curve.svg` â€” child closed-deal equity proxy, MAIN + BWD;
- `r2_underwater.svg` â€” child closed-deal balance drawdown, MAIN + BWD;
- `r2_year_distribution.svg` â€” annual child net/trade participation;
- `r2_parent_child.svg` â€” mechanism-on/off and parent-vs-child comparison.

All visuals are `VISUAL_ONLY_NO_AUTHORITY` and are reproducible from committed machine-readable evidence plus `build_r2_bundle.py`.

## INTERPRETATION

Cell level: the entry-only child remains profitable in MAIN but loses in BWD. Its 2024 MAIN and 2022 BWD yearly rows are negative. Removing adds materially lowers exposure/DD, but also removes most of the parent's net profit in both windows.

Concept level: this prospective counterfactual strengthens the accepted H03 diagnosis that B16's XAUUSD/H4 pulse cannot be treated as an ordinary entry-edge seed. The RSI-fade entry may contain some regime-dependent information, but the evidence does not support an independently durable entry-only edge across the two frozen windows.

Reusable mechanism finding: B16's position engine is material, not merely execution scaffolding. This ablation does not identify which position-engine submechanism is responsible; overlap recovery versus ordinary adverse adds/basket behavior remains unresolved.

## DECISION

The preregistered hypothesis "entry-only component remains positive in both windows" is `FALSIFIED` because mechanically accepted BWD net is `-32.09 <= 0`.

Do not rescue or tune the losing child. Do not unlock H04. The next highest-information B16 experiment remains the separately preregistered recovery ablation `HYP-B16-REC-ABL-01`, which isolates overlap pair-close behavior while preserving the rest of the parent position engine.

Authority remains research-only; no optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default, KINT, or grade authority is created.
