# Boss19 P4 H3 Unit Suitability Audit

Purpose: deterministically assess whether the accepted H3 MT5 report bytes contain source-bound unit identity sufficient for the frozen P4 DEAL/BASKET attribution contract.

This tool runs only after the immutable classifier timeline gate is accepted. It does not rebuild the timeline, optimize, spend HOLDOUT, infer baskets, or create runtime/risk/deployment authority.

The audit verifies the frozen H3 package and timeline hashes, rehashes all 36 raw reports, reconciles realized `out` deal counts to `H3_MATRIX.csv`, and inspects the Orders/Deals schemas for source-emitted linkage fields.

Current accepted report shape exposes separate opening `in` deals and realized `out` deals but no Position/opening-link identifier. Opening and closing Order IDs are disjoint. Therefore current evidence is fail-closed as `BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)`.

Forbidden substitutes for source identity: FIFO, temporal proximity, volume matching, order sequence, and P&L matching.

`BASKET` remains `UNAVAILABLE_NO_SOURCE_BASKET_ID` unless a later source-bound export carries a durable basket ID.

The canonical audit output is `_mt5_auto/p4b_boss19_regime/h3_unit_suitability.json`; its checksum sidecar is stored beside it.
