# B16 Mechanism Characterization — EURUSD/GBPUSD H4 Extension Contract

Status: `PREREGISTERED / EXECUTION_LOCKED_UNTIL_COMMIT`
Authority: `RESEARCH_ONLY`
Owner scope expansion: 2026-08-30 after the original 52/52 matrix completed.
Base characterization preregistration: `f5b9a2a06c13a4c5e5fe798710e00ca8e2f299f6`.
Canonical base remains `4ad1b15f26644723f2954a1416f3662b58c0b565` unless re-anchored before integration.
Runtime: `MT5-lane2 / D:\Meta 5b`, serial, Model 1, optimization 0, Forward 0, USD 10000, leverage 1:100.
HOLDOUT: `UNSPENT / FORBIDDEN`.

## Selection rule frozen before extension results

The accepted H02 pool contains only `XAUUSD`, `EURUSD`, `GBPUSD`, `USDJPY`. XAUUSD and USDJPY are already in the characterization matrix, leaving exactly EURUSD and GBPUSD as comparable new symbols.
For both remaining symbols, H4 is selected because it is the strongest B16 MAIN PF among that symbol's H02 timeframes and also holds timeframe constant with the accepted XAUUSD/H4 mechanism anchor.
This is a portability/stress extension, not candidate selection.

Accepted H02 parent screen:
- EURUSD/H4: MAIN PF 6.39 / 64 trades / EqDD 1.42%; BWD PF 0.25 / 51 trades / EqDD 8.46%.
- GBPUSD/H4: MAIN PF 2.46 / 60 trades / EqDD 1.93%; BWD PF 0.44 / 61 trades / EqDD 10.61%.
Both are full-window eligible but fail dual-window PF>1; this makes them deliberate MAIN/BWD divergence stress contexts.

## Frozen interventions and falsifiers

The exact nine one-change variants, set hashes, source meanings, statements, falsifiers and direct consumers are inherited unchanged from `docs/research/B16_MECHANISM_CHARACTERIZATION_CONTRACT.md` H1-H9:
- `DEPTH2`: MaxOrders 10->2; falsified per symbol if net <=0 in either window.
- `DEPTH4`: MaxOrders 10->4; falsified per symbol if net <=0 in either window.
- `DEPTH5`: MaxOrders 10->5; falsified per symbol if net <=0 in either window.
- `SINGLETP_OFF`: TpSingleAtrMult 0.35->0.0; beneficial-parent claim falsified only if child net is non-lower and native EqDD% non-higher in both windows.
- `BASKETTP_OFF`: BasketTpUsdPer01 16.0->0.0; same parent-tradeoff falsifier.
- `OVERLAP_OFF`: OverlapMinUsd 5.0->0.0; same parent-tradeoff falsifier.
- `PIPFLOOR_OFF`: MinDistPips 150.0->0.0; same parent-tradeoff falsifier.
- `DEEP_SPACING_EQUAL`: AtrMultAfter 1.4->0.8; same parent-tradeoff falsifier.
- `SELL_DIRECTION`: Direction 1->2; falsified per symbol if net <=0 in either window.

No value may change after this extension commit. No depth interpolation, optimization, rescue rerun or extra parameter is authorized by an observed result.

## Frozen execution matrix

Contexts: `EURUSD/H4`, `GBPUSD/H4`.
Windows: MAIN `2023.01.01..2025.12.31`; BWD `2020.01.01..2022.12.31`.
Nine variants x two symbols x two windows = **36 new Strategy Tester cells**.
All use the already committed full 173/173 one-change sets under `factory/runs/b16_characterization_20260830/sets/` and the same accepted B16 build receipt/EX5 as the main characterization matrix.

## Mechanical acceptance and stop rule

Each cell requires exact symbol/TF/dates, Model 1, optimization 0, intended set hash, FULL 173/173 surface, accepted build receipt/EX5, fresh report, leverage 1:100 MATCH, truncation/full-window eligibility, and source-byte reconciliation for any mtime-only stale warning.
A losing strategy cell is evidence and is never replayed to improve outcome. One bounded harness repair is permitted only for a pre-launch/mechanical defect.
After the 36 cells are accepted or honestly blocked, **stop symbol expansion** and continue to deterministic aggregation, cycle/exposure parsing, R2 visuals, final report, independent review and canonical integration.

## Authority ceiling

No H04 naming/unlock, optimization, HOLDOUT use, Candidate, DEMO/LIVE, deployment, trading, runtime attachment, risk/default change, KINT resolution, Grade mapping or production strategy-semantic change is authorized. Dormant flatten/ladder/balance-scaling features and all SL/emergency/cage parameters remain frozen.
