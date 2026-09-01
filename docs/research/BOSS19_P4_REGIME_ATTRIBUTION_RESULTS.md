# Boss19 P4B Regime Attribution — Execution Result

Status: `BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)`

Latest execution base: `21598402def732a9112fd0b189c2bca217875b26`
Timeline SHA-256: `5f3a0f8d1accd25cb6cc08ad1c6e291aed6d238d620269102151016dbfaf569d`
Authority used: research-only; HOLDOUT/optimization/runtime/risk/deploy = NONE.

## Frozen identity gate

Before any H3 outcome/deal content was opened, the repaired deterministic gate verified:

- accepted H3 result-package SHA-256 = `3d62d6d358831dc3897357d3d2008e9c0f1c9211716844112f8af96f79c7eeb2`;
- H3 manifest SHA-256 = `56e7b996a9c6836e5d7cedcbe3c9a212620b9fcc10c4fe3a750f44c8226cfefd`;
- manifest shape = exactly 36 unique cells covering the frozen 6 symbols × 3 TF × MAIN/BWD grid;
- every manifest row is Model 1, HOLDOUT=NO, Optimization=NO;
- all 36 named H3 report files exist and were hash-inventoried without parsing their outcome/deal content.

Identity-gate SHA-256: `c434940e11153925f434504e71f878ecd1f84b9cf644d8b1a8aeb2b6030a0602`.

## Macro prerequisite update - 2026-08-30

The eight-series macro side of the market-input prerequisite is now satisfied without opening H3 outcome/deal content. Canonical capture tooling is commit `b26af204faf7907fe7e78a2b5f90a5dfa8c6bc02`; independent Claude Code exact-head review returned PASS/HIGH. Final pinned local evidence is `D:\EA_LAB_CONTROL\evidence\boss19_p4b_macro_20260830_b26_final\macro_manifest.json`, SHA-256 `7268f3d71c33fd882823570fb35791b5fc956b27fa7829b7cb7ddfc2c803f01a`.

That manifest binds all 8 frozen P4A mappings, all raw and normalized file hashes, provider mappings, retrieval/source mode, row counts and coverage. Every series has at least 502 pre-2020 completed observations, every last normalized date is `2025-12-31`, and manifest `producer_script_sha256 = a083eb85c5fabd1e63dbfecc3cfb08e7030229b69d75945e3f669626355e3d3c`, exactly matching the committed `b26` producer. One-off adversarial checks also observed the script fail closed for (1) BTC data crossing to `2026-01-01`, and (2) only 23 pre-2020 observations. The earlier first capture that crossed the HOLDOUT boundary remains quarantined and is not evidence input.

## Current blocker

The historical market-data prerequisite is resolved. The exact reviewed timeline is pinned at SHA-256 `5f3a0f8d1accd25cb6cc08ad1c6e291aed6d238d620269102151016dbfaf569d`; its manifest SHA-256 is `858f4d02d1ae30511dd1f38ffab347c85c06a4a25df4bedf901dc169c2847916`, with 1,242,682 rows across all 18 Symbol x TF cells. FinalA/FinalB rebuilt byte-identically and the independent rereview of timeline head `0f2cc63d7ca86a8a3a476faf122141aafb513f5b` returned PASS.

Only after that gate was locked, the accepted H3 outcome/deal bytes were opened. A deterministic audit rehashed all 36 raw H3 reports against `H3_MATRIX.csv` and found 1,549 opening `in` deals and 1,549 realized `out` deals; every realized count reconciles exactly to the H3 trade count. The report schema exposes `Time, Deal, Symbol, Type, Direction, Volume, Price, Order, Commission, Swap, Profit, Balance, Comment`, but no source-emitted Position/opening-link field. Opening and closing Order IDs are disjoint across all 36 reports (`overlap = 0`). Therefore an exit deal cannot be tied to its durable opening timestamp without inventing FIFO, temporal-proximity, volume, order-sequence, or P&L matching.

Per the frozen contract this is `BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)`. `BASKET` is also `UNAVAILABLE_NO_SOURCE_BASKET_ID`. This is an evidence-shape blocker only, not a Boss19 strategy failure or regime conclusion. No regime-performance attribution is published. HOLDOUT remains UNSPENT; optimization/runtime/risk/deployment authority remains NONE.

## Reproducible blocker evidence

Current post-timeline unit gate:

- [H3 unit-suitability audit](../../_mt5_auto/p4b_boss19_regime/h3_unit_suitability.json) — SHA-256 `604c81751fc3db2f83c5372ed07a4a5f6f1c5a67836e88c56da7123354d2824d`
- [Unit-suitability checksum](../../_mt5_auto/p4b_boss19_regime/h3_unit_suitability.sha256)
- [Deterministic unit-audit tool](../../tools/p4b_unit_attribution/audit_h3_unit_suitability.py)

Historical pre-timeline blocker artifacts remain preserved below:

- [H3 identity gate](../../_mt5_auto/p4b_boss19_regime/h3_identity_gate.json)
- [Market-input gap manifest](../../_mt5_auto/p4b_boss19_regime/market_input_gap_manifest.json)
- [Blocker package](../../_mt5_auto/p4b_boss19_regime/p4b_blocker_package.json)
- [Package checksum](../../_mt5_auto/p4b_boss19_regime/p4b_blocker_package.sha256)
- [Deterministic blocker builder](../../scripts/research/boss19_p4b/build_blocker_package.ps1)

Market-gap SHA-256: `6aaf19b1255b0add966cbdaaff7026ea04dad6c30388b5e7c4db072f7b63be23`.
Blocker-package SHA-256: `d228abb57f761762e186df1b96411250cca15c2bd46857151543d8c763c43299`.
Builder SHA-256: `902a5ef4ba279dae93b492393ad2c2c59d68a5439c7c1800c6a3eb9c2f198833`.

Two consecutive blocker-builder runs reproduced the same blocker-package SHA-256.

## Next safe action

Do not perform regime attribution from the current H3 HTML reports. The next admissible evidence upgrade is a source-bound timestamped H3 unit export that carries a durable realized-deal/position identity linked to its opening timestamp (and, separately, a source-emitted basket ID if basket-level attribution is desired). Re-enter P4B only after that new unit source is hash-pinned and independently reviewed.

Do not reconstruct entry linkage with FIFO, temporal proximity, volume matching, order sequence, or P&L. Do not spend HOLDOUT, optimize, promote, change risk/defaults, or attach runtime as a side effect of this blocker.
