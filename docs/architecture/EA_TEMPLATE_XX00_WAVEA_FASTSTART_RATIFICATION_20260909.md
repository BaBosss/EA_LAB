# EA Template xx-00 Wave-A Fast-Start Ratification - 2026-09-09

Status: `OWNER_RATIFIED / RESEARCH_SCREEN_CONTROL_ONLY / NO_RUNTIME_DEFAULT_AUTHORITY`
Canonical parent: `95238bb0c2b3f2b8c0689ad411a864f8b3e9cba5`

## Owner decision

The owner authorized the proposed fast-start path and asked the Control Tower to proceed without further routine confirmation.

Generic xx-00 semantics remain unchanged: `GRID_AGAINST`, shared Stack distance ATR x `2.0` on `PERIOD_CURRENT`, `DISTANCE` StackConfirm, `ATR_BASED` Exit, and EA-owned `BASKET_BALANCE_STOP` at 10% of current account balance.

## B13 MeanRev reference

- Home: `XAUUSD / M15`.
- Entry: BB period `20`, BB deviation `2.0`, RSI period `14`, RSI OB `70`, RSI OS `30`, RequireBB=`true`.
- ATRPeriod: `14` on current test timeframe.
- Derived screen-set SHA256: `889ACCB0A703521C03B7526055F3D4EB97259F4DA25DC954A3DF859DD1C5FAFE`.
- Physical baseline source: `Boss_13_MeanRev_defaults.set`, SHA256 `65F3D4287EFFD5CF821BAC6FFF5F123EB17430608F32E9BFA5853216D053D9A6`.

## B15 ST03 reference

- Home: `GBPUSD / H4`.
- Entry: MACD `12/26/9`, CountBars `2`, EdgeTrigger=`true`, RearmBars=`0`.
- ATRPeriod: `14` on current test timeframe.- Derived screen-set SHA256: `405956B20848E1D346654C2EB67140A5BB5A1A71386EC44460C88187B84CAD52`.
- Physical baseline source: `Boss_15_ST03_defaults.set`, SHA256 `CA1415F1F7D855FAA51A39E79631B0AD1914CE3EE4D0B0508802D251DE239C3C`.

## Screen-only chassis controls

The derived sets use the existing regression set only as a physical snapshot. Unchanged inputs are `PRESERVE_SNAPSHOT / TEST_CONTROL_ONLY`, not new xx-00 semantics or runtime defaults.

Explicit screen controls: ExitMode=`22` (`ATR_TP`), TP ATR multiplier=`3.0` as a test control, SLMode=`32` with balance-percent=`10.0`, fixed lot=`0.01`, no lot progression, Recovery OFF, Hedge OFF, StackMode=`92`, StackConfirm=`0`, ATR step=`2.0`, MinPips=`0`, ATR shift=`0`, MaxLevels=`5`, ATR TF=`PERIOD_CURRENT`.

The TP multiplier, fixed lot and MaxLevels are frozen experiment controls only. They are not promoted to universal strategy/risk defaults by this decision.

## Authority ceiling

This ratification authorizes the separately preregistered Model1 research screen only. It does not authorize optimization, HOLDOUT, Model4, Candidate/Grade/KINT, runtime/deployment/trading/LIVE, or a production risk/default change.