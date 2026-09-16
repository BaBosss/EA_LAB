# Arxon MFI+ Work Package C Component Implementation

Date: 2026-09-16
Status: `IMPLEMENTED_SOURCE_ONLY / NO_MT5_RUN / NO_TRADING_WIRING`

## Scope

Implemented an isolated, order-free MQL5 Arxon MFI+ provider matching the B1 semantic freeze. The provider consumes caller-supplied chronological completed `high/low/close/volume` arrays plus source-bar and confirmation timestamps. It does not create indicator handles, read broker/account/order state, send trades, define a trading direction, or attach to `LabCore`.

Changed files:

- `ea_template/components/arxon/ArxonMFIProvider.mqh`
- `ea_template/tests/ArxonMFIProvider_Test.mq5`
- `docs/research/ARXON_MFI_C_COMPONENT_IMPLEMENTATION_20260916.md`

## Implemented Semantics

- Reference length is fixed to `7`.
- Warmup is conservative: 8 completed bars are required for the first valid value.
- Typical price is `hlc3`.
- Equality of adjacent typical prices contributes to neither positive nor negative flow.
- `negative_sum == 0 && positive_sum > 0` returns `100`.
- `positive_sum == 0 && negative_sum > 0` returns `0`.
- Both sums zero is invalid with `ZERO_FLOW_UNDEFINED`.
- Volume provenance is explicit: `REAL` and `TICK` are valid, `UNKNOWN` is invalid.
- Valid states are `BULL` for `MFI > 55`, `BEAR` for `MFI < 45`, otherwise `NEUTRAL`.
- Extremes are `OVERBOUGHT` for `MFI > 90`, `OVERSOLD` for `MFI < 10`, otherwise `NONE`.
- Invalid output is distinct from Neutral and carries deterministic invalid reasons.
- `source_bar_time` and `confirmed_at` are copied from caller-supplied arrays for the evaluated completed bar.

No `first_action_at`, strength, confidence, probability, trade direction, EA default, parent, home, role, input registry entry, FamilyID, or `LAB_ENTRY` is invented.

## Checks Actually Run

- `git diff --check` passed before staging for tracked changes.
- `git diff --no-index --check -- NUL <new-file>` emitted no whitespace errors for each new file.
- Static text scan over the provider and harness found no `iMFI`, `CTrade`, `OrderSend`, `OnTick`, `TimeCurrent`, account, position, order, symbol-info, or `<Trade\Trade.mqh>` API usage.
- Static text scan for invented B1-forbidden semantics found only benign `NONFINITE_INPUT` / "same input" text, not `first_action_at`, strength, confidence, probability, direction mapping, `LAB_ENTRY`, `LabCore`, or registry wiring.
- MetaEditor compile acceptance was run on an evidence-directory copy of the exact provider+harness source: `D:\EA_LAB_CONTROL\evidence\arxon-mfi-c-20260916\ArxonMFIProvider_Test_compile.log` reports `0 errors, 0 warnings`. No deploy or Tester was used.
- No MT5 Tester run, runtime attach, live chart attach, harness execution PASS, or runtime PASS is claimed here.

## Known Gaps

- Exact protected-Pine/same-feed parity remains pending.
- Volume-basis selection for any broker/home remains unset.
- Work Package D remains blocked by parent, role, direction, and home semantics.
- This implementation is not evidence for performance, optimization, Candidate status, HOLDOUT use, deployment, runtime activation, risk/default changes, or trading.
