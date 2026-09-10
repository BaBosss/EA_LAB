# B14 GridLog — Source-Native Control / Home Preregistration

Status: `PREREGISTERED / SOURCE_ONLY / RESEARCH_REFERENCE_ONLY / NO_MT5`
Date: 2026-09-10
Canonical base: `17116aea956da9a169ed2799772c5fd9a30b20d2`
Family: `B14 GridLog`
Direct consumer: a future **separately authorized** fixed-config Model1 control screen after this semantic identity is accepted.

## Purpose

Resolve the numeric/Home fields left explicit by `EA_TEMPLATE_XX00_FAMILY_RATIFICATION_V1.md` without inheriting H01, optimized, regression, DEMO, or historical winner values.

Owner-ratified family semantics remain:
`GRID_STACK + LOG_POWER_PROGRESSION + BASKET_TARGET_OWNERSHIP`.

This document does **not** construct `B14-00`, mutate EA source, run MT5, optimize, spend HOLDOUT, or grant Candidate/runtime/deployment authority.

## Source-native Home

Freeze Home = **`EURUSD / H1`**.

Reason: the standalone GridLog source itself declares `Symbol: EURUSD  TF: H1` in its source header before validation. This is a source identity, not a selection from backtest results. Historical H01 XAUUSD or later GridLog winners do not choose this Home.

## Frozen native numeric semantics

| Semantic | Frozen research reference | Grounding |
|---|---|---|
| Direction | `BUY` / `_14_Direction=1` | standalone default `_01_Direction=DIR_BUY` |
| ATR period | `14` | standalone `_01_AtrPeriod=14` |
| ATR timeframe | `PERIOD_CURRENT` | owner generic baseline; no cross-TF inheritance |
| Native arm distance | `max(ATR(shift=1) × 1.5, 20 pips)` | standalone `_03_DistAtrMult=1.5`, `_03_MinDistPips=20`; template `Entry_GridLog_DistPrice()` reads `Indi_ATR(1)` |
| Lot progression | `LOG_POWER` | owner-ratified native B14 mechanic |
| Log factor | `1.3` | standalone `_05_LogFactor=1.3` |
| Log exponent | natural log / `ln(orderN)` | standalone `_05_UseLnNotLog10=true` and `CalcLogLot()` |
| Basket target basis | fixed account-currency money target | standalone `_04_TpUsd` semantics; not H01 balance-percent |
| Basket target value | `20.0` | standalone `_04_TpUsd=20.0`, target multiplier default `1.0` |
| Exit ownership | basket target owns profit exit; no per-leg TP | required by ratified `BASKET_TARGET_OWNERSHIP` |

Native arm spacing is intentionally **not** the shared Stack-add spacing. The current template routes first-entry arming through `Entry_GridLog.mqh` and later grid adds through shared `Stack.mqh`; conflating those two layers would silently invent a family override that has not been ratified.

## Shared generic chassis semantics — kept separate

For a future executable research control, shared Stack remains the already owner-ratified generic reference unless a new one-change experiment replaces it:

- `StackMode = GRID_AGAINST`;
- Stack distance = `ATR × 2.0` on `PERIOD_CURRENT`;
- `StackConfirm = DISTANCE`.

Therefore `_14_DistAtrMult=1.5` is the **native arm** multiplier while `_9_StepATRmult=2.0` is the **shared grid-add** research reference. The values are allowed to differ by design at this stage.

Source-cadence compatibility for future materialization: `_0_BarOpenOnly=true`. `LabCore.mqh` explicitly preserves intrabar GridLog resting-level trigger checks while bar-gating open-basket management/stack behavior; this matches the standalone once-per-bar management plus intrabar pending-stop fill model.

Generic protection remains the owner-ratified `BASKET_BALANCE_STOP = 10% of current account balance`, EA-owned basket scope. Standalone per-order ATR SL and H01 `SL_NONE` are **not** promoted as B14-native.

Recovery and Hedge remain OFF in the reference control. Stronger StackConfirm, cross-timeframe ATR, alternative basket basis, partial-close behavior, and different direction are separate prospective research axes.

## Minimal future template mapping

The following mapping is the intended semantic materialization, not an executable set in this lane:

```text
_0_BarOpenOnly=true
_14_Direction=1
_0_ATR_Period=14
_0_ATR_TF=PERIOD_CURRENT
_14_DistAtrMult=1.5
_14_MinDistPips=20.0
StackMode=GRID_AGAINST
StackConfirm=DISTANCE
_9_StepUseATR=true
_9_StepATRmult=2.0
LotProg=LOG_POWER
_55_LogPowerFactor=1.3
_55_UseLnNotLog10=true
_2_BasketTP_Money=20.0
_2_BasketTP_ATRmult=0.0
_2_BasketTP_BalPct=0.0
_2_SuppressLegTP=true
_2_PartialPct1=0.0
_2_PartialPct2=0.0
SL=BASKET_BALANCE_STOP_10_PERCENT_CURRENT_BALANCE
Recovery=OFF
Hedge=OFF
```

`_9_StepATRShift`, first-lot magnitude, MaxLevels/depth cap and other risk-cage numbers are intentionally **not promoted to native semantics** here. A future executable screen contract must freeze them explicitly as test controls before launch.

Standalone source facts not adopted as family-native defaults:
- `_05_BaseLot=0.02` — sizing magnitude, not LOG-power law semantics;
- `_06_MaxPositions=6` and `_06_MaxTotalLot=0.60` — risk/depth cages;
- `_04_PartialPct1=50`, `_04_PartialPct2=75`, fractions `0.30/0.30` — partial-close behavior not included in the ratified native map;
- per-order ATR SL `4.0` capped `150 pips` — protection choice superseded for xx-00 research reference by the owner-ratified basket-balance stop.

## H01 non-inheritance check

Historical H01 is evidence only and materially differs from this source-native control: it used shared Stack ATR `1.0`, no Stack pip floor, ATR shift `0`, `_0_BarOpenOnly=false`, balance-percent basket target `1.0%`, `_2_SuppressLegTP=false`, `SLMode=NONE`, and basket balance stop `15%` field value. These values do not acquire authority through similarity of `_14_DistAtrMult=1.5` or LOG factor `1.3`.

The source-native fixed `$20` basket target is chosen from the standalone source definition, **not** from H01, later optimization, or performance ranking.

## Source-bound manifest

All hashes are SHA256 at canonical base `17116aea956da9a169ed2799772c5fd9a30b20d2`.

| Source | SHA256 |
|---|---|
| `ea_projects/(Boss)_ZeusInspired_GridLog/(Boss)_ZeusInspired_GridLog_rev01.mq5` | `b2ca630eea765c7d5af2c1689b489a0bd78ef129996cfaca7fc79f080e5864d1` |
| `ea_template/core/entries/Entry_GridLog.mqh` | `7a1fec373ce818fd09ec2761ee98aba46e33a8c1e30726fd1afd75b727ce85d7` |
| `ea_template/core/Stack.mqh` | `76f504df5b09f6b759df90f1b2a3ad63aa1fd0b668954ae730cfaf8e44fab3bb` |
| `ea_template/core/MoneyManagement.mqh` | `9f2dfc7d6781f199620dc0e83cde18784be57ec8926743ea6b7f0e94d46f2180` |
| `ea_template/core/ExitManager.mqh` | `d4383f5f7a88e8cd496654f8db4ba62ee3b3a35f2ea6e71316edc305b546066a` |
| `docs/architecture/EA_TEMPLATE_XX00_SEMANTIC_FREEZE_PACKET_20260908.md` | `d23f259241bf79b65c258925b07e5a7e9bb4a97c6aef098723ac89417e80b1c3` |
| `docs/architecture/EA_TEMPLATE_XX00_FAMILY_RATIFICATION_V1.md` | `bf0cee451aea116bb5e72e7cc22dadc055318e04853a0f5e6b4f6f6f8b7bd501` |
| `docs/architecture/EA_TEMPLATE_XX00_BACKTEST_READINESS_V1.md` | `d7db998d85951a412c34108872b8334817ac7980d23426fa06092b9069ce2ae1` |

## Acceptance / next gate

This source-only milestone passes when the Home and native numeric semantics above are internally consistent with the manifest and no H01/optimization result is used as selection authority.

After acceptance, B14 may advance only to a **separate fixed-config Model1 execution contract**. That later contract must freeze the remaining non-native test controls (including first lot, effective depth cap and shared Stack ATR shift), bind one MT5 installation lineage, use Model1 / 1 Minute OHLC minimum, and preserve MAIN/BWD with BWD non-search. HOLDOUT remains untouched.

No optimizer is authorized from this document. A weak/losing future Model1 cell is strategy evidence, not permission to change these values after seeing BWD.

## Authority ceiling

`RESEARCH_REFERENCE_ONLY / NO EA SOURCE MUTATION / NO MT5 / NO OPTIMIZATION / NO HOLDOUT / NO CANDIDATE / NO GRADE-KINT / NO RISK-DEFAULT CHANGE / NO DEPLOYMENT / NO TRADING / NO LIVE`.

Decision: `B14_NATIVE_NUMERIC_AND_HOME_SEMANTICS_FROZEN / READY_FOR_SEPARATE_MODEL1_CONTRACT_ONLY`.
