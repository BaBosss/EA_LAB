# Boss19 P4B Source-Bound Unit Export Repair02 Result

Status: `BLOCKED(MAGIC_FIELD_NOT_SOURCE_BOUND) / RESEARCH_ONLY / BROAD_RERUN_LOCKED`

Machine-readable owner: `_mt5_auto/p4b_boss19_regime/p4b_unit_export_repair02_result.json`.
Repair02 runtime head: `40625eb5beec5d59042645a61f02a62ef53621b3`.
Preregistered contract head: `58e5ff3ce5551e3408c7b614e80654cbd2943393`.

## What passed mechanically

The reviewed Repair02 implementation compiled `0 errors / 0 warnings` and the single authorized `H3-C03-MAIN` run completed on XAUUSD H4 MAIN 2023-2025, Model 1, with HOLDOUT `UNSPENT` and optimization `NONE`.

Strategy parity remained exact: PF `4.39`, net `+4445.51`, `113` trades, EqDD `13.34%`, `4,637` bars, `4,238,991` ticks, history quality `98`, leverage `1:100`.

The source/unit mechanics also reconciled exactly: `113 IN / 113 OUT / 113 distinct positions / 113 realized units / 0 open / 0 unknown-time`; linkage basis is `EXACT_DEAL_POSITION_ID_ONE_IN_ONE_OUT`, and no forbidden inference was used.
## Why the evidence contract still blocks

Independent post-run provenance adjudication returned `BLOCK_MATERIAL_CONTRACT_DEFECT / HIGH` on exact head `40625eb5beec5d59042645a61f02a62ef53621b3`.

`P4B_WriteSelectedDeal()` writes the CSV `magic` field from configured `_0_Magic`, not from `HistoryDealGetInteger(deal, DEAL_MAGIC)`. The original source-export contract requires the listed per-row fields, including `magic`, to come from MT5 `HistoryDealGet*` properties of the emitted deal.

This does **not** invalidate the exact position-ID admission or the 113/113/113 count reconciliation. It does mean the emitted CSV cannot independently attest the actual per-deal `DEAL_MAGIC`, precisely for the tester-forced close edge case Repair02 was designed to make auditable.

The downstream builder also treats `magic` as a uniform run-identity field, conflating configured run magic with per-deal source magic. Therefore the successful count gate is insufficient for source-provenance acceptance.

Final Repair02 verdict: `BLOCKED(MAGIC_FIELD_NOT_SOURCE_BOUND)`.
## Evidence identity

- source SHA-256: `f61f43f2f2defc2959d3c956b9b1cbf195416a90f762a2e67c767a5084e53734`
- units SHA-256: `fd37938a368de093c01e1a09430dfc36375eb4112f602191b3623d1436da099e`
- report SHA-256: `1584f43442203e8aa868e119e674a61b6a457d649e3e27b8ce8ca4e05337ac11`
- reviewed diagnostic source SHA-256: `fbe3b5086b92ea1d1e3a4344430f66e2b186864bee9caabe42df2e984a2ee734`
- runtime EX5 SHA-256: `553956530f9b945a825a6a6663361ef78034610b575b97100c5a5fee6928f2b9`
- build receipt: `br-11e4a622826d4c62bcbcf1d8ad35c10b`

## Next safe action

Prospectively preregister a bounded Repair03 before changing source. Separate configured run identity from source per-deal `DEAL_MAGIC`; preserve the accepted exact `DEAL_POSITION_ID` ownership admission; update exporter/schema/builder/runner/tests consistently; independently review the exact implementation head; then rerun only `H3-C03-MAIN` and require exact strategy parity, 113/113/113, and source-property provenance.

The broad 36-cell source-bound export remains `LOCKED`. No P4 regime join, HOLDOUT, optimization, Candidate/DEMO/LIVE, deployment/runtime attachment, trading, risk/default, Grade, KINT, or owner-attestation authority is created by this result.
