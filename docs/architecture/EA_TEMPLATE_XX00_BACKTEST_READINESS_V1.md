# EA Template xx-00 Backtest Readiness V1

Status: `SOURCE_BOUND / READY_FOR_OWNER_RATIFICATION_ONLY / NO_MT5 / NO_RUNTIME_AUTHORITY`
Canonical base: `e721f1da8871508b9861bf1d08d4f54585ea520d`
Date: 2026-09-09

## Purpose

This document identifies the remaining decisions required before a future executable `Bxx-00` Model1 screen can be preregistered. It does not instantiate `Bxx-00`, resolve H01 aliases, select optimized values, or authorize MT5.

Historical regression/H01 values below are candidate evidence only. Existing bytes do not become `xx-00` defaults, recommendations, Home selections, or runtime authority merely because they already exist.

## Already owner-ratified generic control

- Position engine reference: `GRID_AGAINST`.
- Shared Stack distance reference: ATR x `2.0` on `PERIOD_CURRENT`.
- StackConfirm reference: `DISTANCE`.
- Generic Exit reference: `ATR_BASED` unless an owner-ratified native exit applies.
- Basket protection reference: `BASKET_BALANCE_STOP`, 10% of current account balance, EA-owned basket scope.
- Family native classification is owned by `EA_TEMPLATE_XX00_FAMILY_RATIFICATION_V1.md`.

## Common prerequisites before any Model1 screen

Every family still needs an explicit prospective `ATRPeriod`, Home symbol, Home timeframe, and entry-family parameter values. No historical H01/Home/config/package may supply those fields implicitly.

A later screen, if separately authorized, uses MT5 Model1 / 1 Minute OHLC minimum on preregistered MAIN+BWD. Model2/Open Prices/Math Calculations remain diagnostic only. HOLDOUT remains unspent.

## Readiness matrix
| Family | Source fact | Historical candidate control evidence - not authority | Owner decisions still required | Readiness |
|---|---|---|---|---|
| B11 GridTrend | MA-trend entry seam; owner native map = `NONE`. | FastMA `20`, SlowMA `50`, MAMethod `1`, MA_TF `0`, ATRPeriod `14`. | Freeze entry values, ATRPeriod, Home symbol, Home TF. | `READY_FOR_OWNER_RATIFICATION_ONLY` |
| B12 Breakout | Breakout entry seam; owner native map = `NONE`. | Bars `20`, ConfirmBars `1`, HourFrom `0`, HourTo `0`, ATRPeriod `14`. | Freeze entry values, ATRPeriod, Home symbol, Home TF. | `READY_FOR_OWNER_RATIFICATION_ONLY` |
| B13 MeanRev | BB + RSI mean-reversion entry seam; owner native map = `NONE`. | BBPeriod `20`, BBDev `2.0`, RSIPeriod `14`, RSI_OB `70`, RSI_OS `30`, RequireBB `true`, ATRPeriod `14`. | Freeze entry values, ATRPeriod, Home symbol, Home TF. | `READY_FOR_OWNER_RATIFICATION_ONLY` |
| B14 GridLog | Native = `GRID_STACK + LOG_POWER_PROGRESSION + BASKET_TARGET_OWNERSHIP`. `Entry_GridLog` owns an arm distance `max(signal ATR * _14_DistAtrMult, _14_MinDistPips)`; this is distinct from shared Stack ATR x2. | H01: Direction `1`, DistAtrMult `1.5`, MinDistPips `20`, LogPowerFactor `1.3`, UseLn `true`, BasketTPBalPct `1.0`, ATRPeriod `14`. | Freeze native arm/grid values, log-power method/factor, basket-target basis/value, direction, ATRPeriod, Home symbol/TF. Do not inherit H01 `SL_NONE` or other risk values. | `NATIVE_NUMERIC_RATIFICATION_REQUIRED` |
| B15 ST03 | MACD consecutive-count edge-trigger entry seam; owner native map = `NONE`. | MACDFast `12`, MACDSlow `26`, MACDSignal `9`, CountBars `2`, EdgeTrigger `true`, RearmBars `0`, ATRPeriod `14`. | Freeze entry values, ATRPeriod, Home symbol, Home TF. | `READY_FOR_OWNER_RATIFICATION_ONLY` |
| B16 Kangaroo | Native = `ADVERSE_ATR_GRID + KANGAROO_LOT_LAW + OWNED_BASKET_OVERLAP_EXITS`; owned pipeline bypasses shared Stack/Exit flow. | H01 alpha/position candidates: Direction `1`, RSI `14/30/70`, ATR grid `0.8` first four / `1.4` after, MinDistPips `150`, LadderMult `1.0`, BasketTPUsdPer01 `16`, OverlapMinUsd `5`, OverlapMinOrders `4`, ATRPeriod `14`. | Freeze RSI/direction, owned grid spacing, research lot-law numeric semantics, basket/overlap exit values, ATRPeriod, Home symbol/TF. Risk/default sizing remains separate owner authority. | `NATIVE_NUMERIC_RATIFICATION_REQUIRED` |
| B17 Wave5 | Native = Wave-1 structural invalidation SL + `SINGLE_WHEN_STRUCTURAL`; structural target/Exit is not native-ratified. Current source creates both structural SL and TP and can route the structural TP through `ExitManager`. | H01: FractalDepth `3`, Wave3MinMult `0.618`, EntryFib `23.6`, SLbufferATR `0.5`, UseStructLevels `true`, DivergTrail `true`, MaxSwings `8`, RSIPeriod `14`, ATRPeriod `14`. H01 ExitMode=`TRAIL` is not `xx-00` authority. | Parameter freeze alone is insufficient. A separate semantic/implementation contract must make native structural SL compatible with generic `ATR_BASED` Exit, then entry values, ATRPeriod, Home symbol/TF can be frozen. | `BLOCKED_SEMANTIC_IMPLEMENTATION_COUPLING` |
| B18 JumStoch | LWMA displacement + Stochastic seed; owner native map = `NONE`. | Direction `1`, DirMode `1`, MAPeriod `25`, K `32`, D `12`, Slowing `12`, Lo `25`, Up `75`, ATRPeriod `14`. Historical XAUUSD/H1 evidence is H01 evidence only. | Freeze entry values, ATRPeriod, Home symbol, Home TF. | `READY_FOR_OWNER_RATIFICATION_ONLY` |

## Wave grouping

**Wave A - owner parameter/Home ratification surface:** B11, B12, B13, B15, B18. These are not MT5-ready; they only lack prospective parameter/Home decisions rather than owner-ratified native numeric reconstruction.

**Wave B - additional native resolution required:** B14, B16, B17. B14/B16 need native numeric research parameters. B17 additionally has a current implementation coupling between structural SL and structural TP/Exit behavior.

No family in either wave is `READY_FOR_MT5` in this document.
## Source-bound evidence manifest

All hashes below are SHA256 from canonical base `e721f1da8871508b9861bf1d08d4f54585ea520d`.

| Source | SHA256 |
|---|---|
| `docs/architecture/EA_TEMPLATE_XX00_FAMILY_RATIFICATION_V1.md` | `BF0CEE451AEA116BB5E72E7CC22DADC055318E04853A0F5E6B4F6F6F8B7BD501` |
| `ea_template/PRODUCT_CONCEPT.md` | `CDDA6333E4FA23F38B9F31E98C96C3130E5F6A87AEB00024BF7C1F1B0B42146D` |
| `ea_template/core/Inputs.mqh` | `D7E895E04671D58625D25512260D7AE4FCE0C1B2D90A5BABE37161B30475B963` |
| `ea_template/core/entries/Entry_GridTrendMA.mqh` | `C6F61F1574DC5956ACA79D21C14840BAEA815ADD26042F5D362781854CA6C898` |
| `ea_template/core/entries/Entry_Breakout.mqh` | `732415998F2752019764751A4A173A3F20C13524F7DD96B72248EB024BFF9F9D` |
| `ea_template/core/entries/Entry_MeanReversion.mqh` | `9ECBC3EEC81E43894CEB0B4077DDDD8C7DF95C3EB935D8183D1E67720314D26C` |
| `ea_template/core/entries/Entry_GridLog.mqh` | `7A1FEC373CE818FD09EC2761EE98ABA46E33A8C1E30726FD1AFD75B727CE85D7` |
| `ea_template/core/entries/Entry_ST03.mqh` | `440936A4A6700E72FAB56A002197F9B8F783F64A52127E53400BE4784243375D` |
| `ea_template/core/entries/Kangaroo.mqh` | `4C1B6388DD29A7B5D390338D0F553B7EA4D69F01A7D4B74F701434C32F5BF7C6` |
| `ea_template/core/entries/Entry_Wave5.mqh` | `C4E2045C728C04A561F5D8DFAD70B99120EE8C43054D817559D01D69464DBD5D` |
| `ea_template/core/entries/Entry_JumStoch.mqh` | `C396C21546CF53F1979A717EAB153BBD4DF16D294F2EF8DC076E1418D8F40AC2` |
| `ea_template/core/ExitManager.mqh` | `D4383F5F7A88E8CD496654F8DB4BA62EE3B3A35F2EA6E71316EDC305B546066A` |
| `ea_template/core/LabCore.mqh` | `C5C0B4A41D1CAA4B2F8FAE724085A7FA17EBFD938B745912409B281AAF65B2B2` |`n| `ea_template/sets/regression/Boss_11_GridTrend_defaults.set` | `5A0CDD3186E924234D4491BDF854966553214EBAAF03CA6793BEAEDD42EA8EFA` |
| `ea_template/sets/regression/Boss_12_Breakout_defaults.set` | `62FFA4E95A08A483617046694309A8082C1D07BECE39A778704F67CB389626C1` |
| `ea_template/sets/regression/Boss_13_MeanRev_defaults.set` | `65F3D4287EFFD5CF821BAC6FFF5F123EB17430608F32E9BFA5853216D053D9A6` |
| `factory/vnext/pilots/boss14_h01_first_green/proposed_B14_H01_r1.set` | `A594FCBB34264C5810DE0CFB176D8462BD28E38BD350A2DEF0498913CA13221C` |
| ea_template/sets/regression/Boss_14_GridLog_defaults.set | 3FD05B45D97540BBAC35874F8853B78DACA7C96E704C0DAB62C617171657BE2F |
| `ea_template/sets/regression/Boss_15_ST03_defaults.set` | `CA1415F1F7D855FAA51A39E79631B0AD1914CE3EE4D0B0508802D251DE239C3C` |
| `factory/vnext/pilots/boss16_h01_first_green/proposed_B16_H01_r1.set` | `54D584CE3709B2CAC478B872EDC50C6F39FE254BD50812424443CDEFB691E870` |
| ea_template/sets/regression/Boss_16_KangarooGrid_defaults.set | 4C18E345BD773D47CFDE945BFA5ED47E7BBFF3CD3D245DD0079829084EF15563 |
| `factory/vnext/pilots/boss17_h01_first_green/proposed_B17_H01_r1.set` | `E9B99B1E93DE76C56615D1EF803459D1986A3BA77CB5BA53567996B5A29CF033` |
| ea_template/sets/regression/Boss_17_Wave5_defaults.set | 9B1FA9E962A3260F6EF9F41312385DAD1AE2958F20ABD14263C048E04B47EEF2 |
| `ea_template/sets/regression/Boss_18_JumStoch_defaults.set` | `67973ADAF57211858F8BB615C4A73864ADC03FD31E6AD0D16F6A044A8882A1C1` |

## Historical conflicts that prevent silent inheritance

- B14 regression/default material and accepted H01 proposed bytes are not one identity-preserving reference. H01 carries the LOG-power/basket-target evidence, but neither source is automatically `B14-00`.
- B17 historical sources disagree on at least EntryFib (`38.2` in the regression default versus `23.6` in the H01 proposed set). Historical reuse therefore requires an explicit owner choice.
- B18 historical XAUUSD/H1 Model1 evidence belongs to H01 only; it is not a Home-selection decision for `B18-00`.

## Owner decision surface produced by this readiness pass

For **B11/B12/B13/B15/B18**, the minimum prospective decision is:

```text
Bxx_ENTRY_REFERENCE = ACCEPT_LISTED_CANDIDATE | CUSTOM(<explicit values>)
Bxx_ATR_PERIOD = <positive integer>
Bxx_HOME_SYMBOL = <explicit symbol>
Bxx_HOME_TF = <explicit timeframe>
```

For **B14/B16**, add explicit native numeric research parameters listed in the readiness matrix. For **B17**, first resolve the structural-SL / structural-TP coupling in a separate owner-visible contract; parameter ratification alone cannot make current source represent the ratified semantics.

Authority remains `RESEARCH_REFERENCE_ONLY / NO MT5 / NO OPTIMIZATION / NO HOLDOUT / NO CANDIDATE / NO DEPLOYMENT / NO TRADING / NO LIVE`.