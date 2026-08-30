# Boss19 P4B Regime Attribution — Execution Result

Status: `BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION;DATA_ENVIRONMENT_MISSING_IMMUTABLE_HISTORICAL_MARKET_INPUTS)`

Base: `2998339a3b3a76a63723563a849926ee115d4855`
Timeline SHA-256: `NONE`
Authority used: research-only; HOLDOUT/optimization/runtime/risk/deploy = NONE.

## Frozen identities inspected

| Item | Value |
|---|---|
| Classifier | `BOSS19_P4_REGIME_CLASSIFIER_V1` v`1.0.0` |
| Accepted H3 head | `47c7732048406277096c1ccc31734b4122ae7285` |
| Accepted H3 package identity | `3d62d6d358831dc3897357d3d2008e9c0f1c9211716844112f8af96f79c7eeb2` |
| H3 matrix manifest SHA-256 | `56e7b996a9c6836e5d7cedcbe3c9a212620b9fcc10c4fe3a750f44c8226cfefd` |
| P4B blocker package SHA-256 | `db15fe3d2a00573cc95bf3ea06f57791bb9836e46f73c540083b7c74b3f8690e` |

## Evidence blockers

1. The 36 H3 HTML reports expose `Deal` and `Time`, and separate `in` and realized `out` rows. A realized `out` row contains neither a source `Position ID` nor an `Entry Deal` link to its opening row. Therefore a realized DEAL/position cannot be assigned the required durable opening timestamp without inventing a matching rule.
2. No report exposes a source `Basket ID`. `B19 L1`-style comments are not a complete source-emitted basket identity and were not converted into one.
3. No immutable historical market snapshot is available in the bounded local sources. The existing MRIS files are current derived snapshots/states; the legacy replay script fetches live Yahoo data, which the frozen contract excludes. Missing raw input is: eight daily macro OHLC series and 18 exact H3 Symbol×TF closed-OHLC series, including the required warmups and tester-data identity.

Accordingly, no classifier timeline was written, no H3 P&L was aggregated, and no regime-performance conclusion or visual was produced.

## Reproducible blocker evidence

- [Blocker package](/D:/EA_LAB_CONTROL/worktrees/rnd-p4b-regime-attribution-2998339a/_mt5_auto/p4b_boss19_regime/p4b_blocker_package.json)
- [Package checksum](/D:/EA_LAB_CONTROL/worktrees/rnd-p4b-regime-attribution-2998339a/_mt5_auto/p4b_boss19_regime/p4b_blocker_package.sha256)
- [H3 unit-evidence inventory](/D:/EA_LAB_CONTROL/worktrees/rnd-p4b-regime-attribution-2998339a/_mt5_auto/p4b_boss19_regime/h3_unit_evidence_inventory.json)
- [Market-input gap manifest](/D:/EA_LAB_CONTROL/worktrees/rnd-p4b-regime-attribution-2998339a/_mt5_auto/p4b_boss19_regime/market_input_gap_manifest.json)
- [Deterministic package builder](/D:/EA_LAB_CONTROL/worktrees/rnd-p4b-regime-attribution-2998339a/scripts/research/boss19_p4b/build_blocker_package.ps1)

The package validation passed: the two child manifest hashes exactly match the hashes recorded by the package; it inventories 36/36 report files, eight macro requirements, and 18 local OHLC requirements.

## Next safe action

Provide both prerequisites, without rerunning or altering H3:

1. A versioned, immutable daily OHLC snapshot for `AUDJPY`, `USDJPY`, `VIX`, `DXY`, `XAUUSD`, `BTCUSD`, `US10Y_JP10Y`, and `COPPER`, covering `2020-01-01..2025-12-31` plus at least 260 completed daily observations before the start; include provider mapping, UTC rule, retrieval timestamp, raw hashes, and missing-bar policy.
2. Exact tester-data-identity closed OHLC exports for every H3 `Symbol×TF` cell over `2020-01-01..2025-12-31`, plus at least 252 calendar days and 50 closed bars of warmup; and a unit export that links each realized closure to its durable opening timestamp (and source basket IDs if basket reporting is wanted).

Then restart P4B at `hash market inputs -> build/hash timeline -> verify H3 package -> parse units -> join`.
