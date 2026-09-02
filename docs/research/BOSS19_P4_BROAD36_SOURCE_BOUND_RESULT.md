# Boss19 P4B Broad36 Source-Bound Execution Result

Status: `SOURCE_BOUND_UNIT_EVIDENCE_READY_FOR_REVIEW / RESEARCH_ONLY`
Runtime canonical head: `d55b3ffc399ae0714c456416a4b352b4fa5e472d`
Reviewed execution gate: `9067fcaa6a2f04fcfdfd7dec76d737524aae8a48`
Direct consumer: deterministic P4B regime attribution after independent package review.

## Execution result

The full frozen H3 matrix completed 36/36 serial Model-1 source-bound runs on `D:\Meta 5`.
MAIN remained `2023.01.01..2025.12.31`; BWD remained `2020.01.01..2022.12.31`.
HOLDOUT `2026H1` remained UNSPENT and optimization remained NONE.
The batch stopped for no product/runtime cell failure. One scratch orchestration defect occurred after the first cell had already passed; that Class-B harness defect was repaired outside the repository, the existing first-cell PASS evidence was revalidated and reused, and execution resumed from cell 2 without rerunning cell 1.

Every accepted cell records:
- `PASS_SOURCE_BOUND_UNIT_RUN`;
- exact `DEAL_POSITION_ID` linkage;
- `source_out_count == report_trades == realized_unit_count`;
- `open_position_count = 0`;
- `unknown_time_unit_count = 0`;
- configured run magic `990001` separated from per-deal source magic;
- source-magic provenance `PER_DEAL_HISTORY_DEAL_MAGIC`.

## Deterministic package

Aggregate realized units: **1,549** across 36 unique H3 run IDs.
All 1,549 aggregate unit rows have `time_status=COMPLETE`.
Source-magic values observed: `[0, 990001]`; 63 realized units have a close-deal source magic different from configured magic, preserving tester/source provenance instead of relabeling it.

Per-symbol realized-unit counts:
- XAUUSD: 442
- EURUSD: 198
- GBPUSD: 137
- AUDUSD: 93
- USDJPY: 368
- BTCUSD: 311

Aggregate units SHA-256: `325b6d00709c48982a5981d2d7750a6a18e99f2d77ad52b89fa8d67b50c0b699`.
Package manifest SHA-256: `1330a822ed66149ba07d693d8732ced5b9e9ce66d15f34ce8d21ef70894b760c`.
Batch summary SHA-256: `411bb305c725fda655ab963144bf229b1c2591c3bcb5db71f7d49917a33c58dd`.
Batch progress SHA-256: `25d81ca963a88c84b585125b75f22afdf585e691d790502f92478765649a5a67`.
The deterministic package builder reproduced the aggregate CSV and package JSON byte-identically on a second build.

## Frozen identity

- H3 matrix SHA-256: `56e7b996a9c6836e5d7cedcbe3c9a212620b9fcc10c4fe3a750f44c8226cfefd`.
- Fixed set SHA-256: `671ced2169bdda6812cf1ceb70bbc5a53bcb0985563dcbce92cc64e04f81f0d2`.
- Diagnostic source SHA-256: `dd61c78ca6680fcec64260ea200e04c2faa4824abbbeac218100a2db997f33cf`.
- Diagnostic EX5 SHA-256: `8f68ee1cf726f27de0ec5da0f1ad4b5f88f129435f9b2bf9b27d5ba378a9abd2`.
- Build receipt: `br-6c63129e01ac4458a62d420c5594560f`.
- Linkage basis: `EXACT_DEAL_POSITION_ID_ONE_IN_ONE_OUT`.

The new realized-unit total happens to equal the historical H3 `1,549` realized-deal count. This is an informational reconciliation match only; the broad36 contract explicitly did not require equality to the historical total.

## Authority and next gate

This result closes source-bound broad execution only. It is not a Boss19 strategy/regime verdict and does not grant optimization, HOLDOUT, Candidate, Grade/KINT, risk/default, deployment, DEMO/LIVE, or trading authority.

Before any regime join, freeze this exact package and obtain independent review of completeness, hashes, source/build identity, 36-cell scope, exact linkage/count reconciliation, and authority boundaries. Only an accepted package may become the evidence input to deterministic P4B regime attribution against the already-frozen classifier timeline.
