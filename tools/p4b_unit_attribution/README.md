# Boss19 P4 H3 Unit Suitability Audit

Purpose: deterministically assess whether the accepted H3 MT5 report bytes contain source-bound unit identity sufficient for the frozen P4 DEAL/BASKET attribution contract.

This tool runs only after the immutable classifier timeline gate is accepted. It does not rebuild the timeline, optimize, spend HOLDOUT, infer baskets, or create runtime/risk/deployment authority.

The audit verifies the frozen H3 package and timeline hashes, pins `H3_MATRIX.csv` at SHA-256 `e3f3305c29a837c936a4476d100bf3e1b8b68357ab3a8faac041f9e11402faaa`, semantically cross-checks all 36 matrix rows against the SHA-pinned H3 result-package rows, rehashes all 36 raw reports, reconciles realized `out` deal counts, and inspects the Orders/Deals schemas for source-emitted linkage fields.

Current accepted report shape exposes separate opening `in` deals and realized `out` deals but no Position/opening-link identifier. Opening and closing Order IDs are disjoint. Therefore current evidence is fail-closed as `BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)`.

Forbidden substitutes for source identity: FIFO, temporal proximity, volume matching, order sequence, and P&L matching.

`BASKET` remains `UNAVAILABLE_NO_SOURCE_BASKET_ID` unless a later source-bound export carries a durable basket ID.

The canonical audit output is `_mt5_auto/p4b_boss19_regime/h3_unit_suitability.json`; its checksum sidecar is stored beside it.

## Broad36 pre-join readiness

`validate_broad36_prejoin.py` is the deterministic read-only seam between the frozen Boss19 broad36 source-bound package and independent package review / deterministic P4 regime attribution.

The primary frozen-package mode consumes the canonical package JSON, aggregate source-bound unit CSV, frozen H3 manifest, canonical execution result report, and canonical per-cell runner. It pins the accepted runtime head plus H3/set/source/EX5/build-receipt identities, verifies the exact package and aggregate hashes, requires exactly 36 unique H3 cells, reconciles every package cell to the H3 matrix, validates the full source-bound unit schema, and enforces unique `h3_run_id + source_deal_id` / source-position keys with complete entry/exit UTC timestamps.

The earlier raw-evidence-root mode remains available only as a deeper forensic validator when all 36 per-cell directories are present. It rehashes each `report.htm`, `source.csv`, and `units.csv`, reconciles run/unit manifests, and refuses missing or duplicate run manifests. Because that mode does not itself bind the exact frozen package bytes, success is `PASS_FORENSIC_RAW_EVIDENCE_VALIDATION`, sets `prejoin_schema_ready=false`, and cannot satisfy canonical pre-join acceptance. Those raw per-cell manifest bytes are not tracked inside the frozen canonical package, so frozen-package PASS explicitly reports `raw_cell_manifest_rehash = NOT_AVAILABLE_IN_CANONICAL_FROZEN_PACKAGE` rather than claiming a rehash it cannot perform.

Only frozen-package mode may emit `PASS_FROZEN_PACKAGE_PREJOIN_READINESS`. Independent package review remains mandatory before the package may enter the frozen P4 classifier timeline join. The validator does not interpret P&L, choose regimes, spend HOLDOUT, optimize, assign Candidate/Grade/KINT, change risk/defaults, deploy, attach runtime, or trade.
