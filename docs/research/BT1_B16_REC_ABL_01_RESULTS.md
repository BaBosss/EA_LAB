# BT1 â€” B16 Recovery Ablation 01 â€” Results

Status: `PASS / HYPOTHESIS_NOT_FALSIFIED`
Hypothesis ID: `HYP-B16-REC-ABL-01`
Report level: `R2 MECHANISM`
Canonical base SHA: `f3f95d6964c3bdff966697439007b6c0b152aecb`
Preregistration commit: `35484a46182e9ae070781417f56676e3fcef6d1b`
Runtime: `MT5-lane2 / D:\Meta 5b`
HOLDOUT: `UNSPENT`
Optimization: `NONE`
MECHANISM_VALUE: `UNCLEAR` â€” material effect, opposite sign across MAIN and BWD

## EVIDENCE â€” mechanical acceptance

Both authorized cells are mechanically `PASS`; there was one run per cell and no evidentiary retry.

- Expert: `EALabTpl\Boss_16_KangarooGrid`.
- EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
- Build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`.
- Child set SHA256: `a029dec80b7c4d800992595415cb5f06f6f403321a93caa8c9e51b00e21bb213`.
- Config fingerprint: `1eb741aa9be22d130d939440a00ff9890e5907c35ff1cbfd76809ee473aeadf8`.
- Only semantic change: `_16_OverlapMinUsd=5.0 -> 0.0`.
- XAUUSD/H4; Model 1; Optimization 0; Forward 0; USD 10000; leverage 1:100.
- Leverage sidecars are `MATCH`; truncation sidecars are `false`; both reports are fresh relative to run start and full-window eligible.
- No HOLDOUT date was used.

The runner printed `STALE` from mtime only. Deterministic Git reconciliation proves no relevant source change from build/source ref `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125` through experiment base `f3f95d6964c3bdff966697439007b6c0b152aecb` and post-run canonical `4c4de3636ef9ae79d250f4171e0ebc0f3355a163`: `Boss_16_KangarooGrid.mq5`, `core/entries/Kangaroo.mqh`, `core/Inputs.mqh`, `core/LabCore.mqh`, and the entire `ea_template/core` tree have identical Git object IDs. `source_byte_reconciliation.txt` records the exact identities. The two post-run canonical commits add Research Pod/Capability Scout surfaces only. The mtime line is therefore an environment false-positive, not source/binary drift.

## EVIDENCE â€” parent vs disabled-overlap child

| Window | Variant | PF | Trades | Net | EqDD% | Quality | Report SHA256 |
|---|---|---:|---:|---:|---:|---|---|
| MAIN | accepted parent | 4.08 | 79 | 707.78 | 6.27 | 98% | `aee6819ba12f929caade4cf1b70915978a3259ec2b7136a1009e077057bb0e7e` |
| MAIN | overlap disabled | 0.51 | 72 | -924.01 | 22.28 | 98% | `f401bd17d564a984209df4dda069011a3fb98bcf3910ebd32ad2862e5467501e` |
| BWD | accepted parent | 1.44 | 148 | 512.69 | 8.29 | 99% | `df63addd9975b66a9471aafe929d3b7f31377a95a93342cc6f1521728f07cff3` |
| BWD | overlap disabled | 1.94 | 141 | 890.51 | 7.70 | 99% | `d819e6b76824961a37a7702c640abe3794485bd2bcfc0b2a1d6a2ec55f57997e` |

Parent -> child deltas:
- MAIN: PF `-3.57`, net `-1631.79`, EqDD `+16.01 pp`, trades `-7`.
- BWD: PF `+0.50`, net `+377.82`, EqDD `-0.59 pp`, trades `-7`.

The sign reverses across windows. Removing overlap is strongly harmful in MAIN but beneficial in aggregate BWD.

## EVIDENCE â€” cycles and yearly distribution

The canonical H03 parser was reused without modification. `cycle_decomposition.json` reconciles report net/gross/PF/ticket counts exactly and reconstructs flat-to-nonflat-to-flat cycles from the report deal ledger.

- Parent H03: MAIN `42 cycles / 79 tickets`; BWD `70 / 148`.
- Disabled-overlap child: MAIN `33 cycles / 72 tickets`; BWD `70 / 141`.
- Child maximum depth: MAIN `10`, BWD `9`; multi-entry cycles still provide `81.60%` MAIN and `88.96%` BWD of gross profit.
- Parent H03 multi-entry gross-profit shares were `79.80%` MAIN and `87.89%` BWD.
- Report history cannot identify exit type: `exit_type = UNKNOWN_FROM_REPORT_HISTORY`. No overlap/pair-close event count is inferred from ticket ordering or P/L.

| Window | Year | Trades | PF | Net | Closed-deal balance DD% |
|---|---:|---:|---:|---:|---:|
| MAIN | 2023 | 31 | 0.22 | -1368.42 | 16.43 |
| MAIN | 2024 | 23 | 2.42 | 170.80 | 14.05 |
| MAIN | 2025 | 18 | 15.73 | 273.61 | 12.00 |
| BWD | 2020 | 35 | 3.31 | 319.84 | 0.90 |
| BWD | 2021 | 52 | 0.93 | -51.53 | 5.32 |
| BWD | 2022 | 54 | 8.19 | 622.20 | 3.11 |

The MAIN failure is concentrated in 2023 rather than a uniform loss across every year; BWD also contains a losing 2021 despite its stronger aggregate result. These rows are descriptive evidence, not a new regime classifier.

R2 machine-readable/visual pack:
- `evidence_summary.json`, `cycle_decomposition.json`, `equity_curve.csv`, `year_split.csv`;
- `r2_equity_curve.svg`, `r2_underwater.svg`, `r2_year_distribution.svg`, `r2_parent_child.svg`;
- deterministic compressed raw HTML, exact INIs, leverage/truncation sidecars, execution log, and source-byte reconciliation.

All visuals are `VISUAL_ONLY_NO_AUTHORITY` and are reproducible from the committed evidence.

## INTERPRETATION

Cell level: the overlap branch is not cosmetic. Disabling it transforms MAIN from a strong positive parent into a material loss with much larger EqDD, while BWD improves in net, PF, and EqDD. The mechanism therefore has a large but window-dependent effect.

Concept level: this does **not** establish a globally beneficial overlap rule. It supports keeping overlap as a material component of the current B16 parent research lineage, while warning that its value may depend on market path/regime. The result is consistent with H03's `POSITION_ENGINE_DEPENDENT_OR_UNKNOWN` diagnosis and does not isolate a standalone entry edge.

Reusable mechanism finding: pair-close recovery can materially alter both realized P/L and drawdown without changing entry/add/max-depth configuration. Its contribution cannot be summarized by one unconditional sign from these two frozen windows.

`MECHANISM_VALUE = UNCLEAR`: material enough to preserve and study, but contradictory across windows and not ready for default redesign or parameter-range work.

## DECISION

The preregistered hypothesis `overlap pair-close is beneficial` is `NOT_FALSIFIED`. The falsification condition required the disabled child to have non-lower net **and** non-higher EqDD in **both** MAIN and BWD. The child fails both comparisons in MAIN (`-924.01 < 707.78`; `22.28% > 6.27%`).

BWD's improvement is retained as contradicting evidence; it is not averaged away and does not authorize a new setting.

No further B16 experiment is auto-opened from this result. A new child requires a separately preregistered, one-change hypothesis with a direct consumer. H04 stays locked.

Authority remains research-only; no recovery default change, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default, KINT, or Grade authority is created.
