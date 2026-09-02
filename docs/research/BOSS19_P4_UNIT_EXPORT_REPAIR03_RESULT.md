# Boss19 P4B Unit Export Repair03 Result

Status: **PASS / RESEARCH_ONLY / BROAD36_LOCKED_PENDING_CONTROL_TOWER_ROI_GATE**

Runtime implementation head: `56b42c931022521417282c4113fd81e25a4fccb5` (independently reviewed PASS by Claude Code 2.1.223).
Re-anchored implementation head: `ddf53e35328ebe6d25d90560f0043d1840503078` on integration base `dcb5dd1dfd9b3df68a270985272b13fc5fee0890`; all five Repair03 implementation files are byte-identical to the reviewed runtime head.
Authorized runtime: `H3-C03-MAIN` only, XAUUSD H4 MAIN 2023-2025, Model 1, `D:\Meta 5`. HOLDOUT remained UNSPENT; optimization remained NONE.

## Source-provenance gate

- Raw schema separates `configured_run_magic` from `source_deal_magic`.
- Exporter reads source magic directly from `HistoryDealGetInteger(deal, DEAL_MAGIC)` at the reviewed source line 62.
- Configured run magic = `990001`; emitted source magic values = `[0, 990001]`.
- Three tester-forced close rows are auditable as source magic `0` while configured run magic remains `990001`: deals 225/226/227, positions 570/569/568.
- Source-magic provenance = `PER_DEAL_HISTORY_DEAL_MAGIC`.

## Mechanical acceptance

`113 IN / 113 OUT / 113 source positions / 113 realized units / 0 open`.
The IN, OUT and unit `DEAL_POSITION_ID` sets are exactly equal across 113 positions. Linkage remains `EXACT_DEAL_POSITION_ID_ONE_IN_ONE_OUT`; forbidden inference = false.

## Strategy parity and environment disclosure

Repair02 vs Repair03 have the same 226 deal IDs and every common source field is exact except `swap`: order/position identity, entry/exit time, volume, price, commission and source `profit` are unchanged. Source profit total is `7082.25000000` in both runs.
Broker swap changed from `-2636.74000000` to `-2575.43000000`, a `+61.31000000` delta. This exactly explains report net changing from `4445.51` to `4506.82`. Repair03 PF is `4.55` and EqDD `13.29%` versus Repair02 `4.39` / `13.34%`.
This is recorded as environment-dependent swap economics, not a strategy semantic change; execution behavior parity is exact on all non-swap source fields.

## Build/runtime identity

- source SHA-256: `dd61c78ca6680fcec64260ea200e04c2faa4824abbbeac218100a2db997f33cf`
- EX5 SHA-256: `8f68ee1cf726f27de0ec5da0f1ad4b5f88f129435f9b2bf9b27d5ba378a9abd2`
- build receipt: `br-6c63129e01ac4458a62d420c5594560f`
- set SHA-256: `671ced2169bdda6812cf1ceb70bbc5a53bcb0985563dcbce92cc64e04f81f0d2`
- H3 manifest SHA-256: `56e7b996a9c6836e5d7cedcbe3c9a212620b9fcc10c4fe3a750f44c8226cfefd`
- compile: `Result: 0 errors, 0 warnings, 2948 ms elapsed, cpu='X64 Regular'`

Broad36 remains **LOCKED**. This result grants no P4 interpretation, HOLDOUT, optimization, deployment, trading, risk/default, Grade/KINT or owner-attestation authority. Next dependency is the Main Control Tower ROI gate.
