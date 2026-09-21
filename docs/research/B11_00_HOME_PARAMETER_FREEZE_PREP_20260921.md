# B11-00 Home / Parameter Freeze Prep — 2026-09-21

Status: `BLOCKED_OWNER_DECISION / SOURCE_BOUND / NO_MT5 / HOLDOUT_UNSPENT`
Base canonical: `4e44e7a2e5302200f4ea88e348b762a3f8d64f7c`
Lane: `ct-b11-00-home-parameter-freeze-20260921`

This packet reduces the owner decision surface without choosing consequential values for the owner.

## Source-bound decision table

| Class | Field / statement | Current evidence |
|---|---|---|
| SOURCE FACT | Entry logic | Fast MA vs slow MA directional state at shift0; not a one-time crossover detector. |
| SOURCE FACT | Current B11 source SHA256 | `59c51ad12ecc0450c19bffa373f836a95c0c3fe6808a2029fcc946f28c29f672` |
| OWNER-RATIFIED SEMANTIC | Native map | `NONE`; historical `GRID_TREND` is not a B11-00 native exception. |
| OWNER-RATIFIED SEMANTIC | Generic position engine | `GRID_AGAINST` |
| OWNER-RATIFIED SEMANTIC | Shared stack distance | ATR x `2.0` on `PERIOD_CURRENT` |
| OWNER-RATIFIED SEMANTIC | StackConfirm | `DISTANCE` |
| OWNER-RATIFIED SEMANTIC | Generic exit | `ATR_BASED` |
| OWNER-RATIFIED SEMANTIC | Basket protection | `BASKET_BALANCE_STOP`, 10% of current account balance, EA-owned basket scope. |
| HISTORICAL CANDIDATE | MA bundle | FastMA=20, SlowMA=50, MAMethod=EMA/1, MA_TF=PERIOD_CURRENT/0 |
| HISTORICAL CANDIDATE | ATR period | ATRPeriod=14 |
| NEGATIVE EVIDENCE | H01 XAUUSD/H1 | MAIN PF 1.02 / +529.17 / 2822 trades / EqDD 19.57%; BWD PF 0.88 / -2031.99 / 2657 trades / EqDD 22.88%. Historical control only. |
| NEGATIVE EVIDENCE | H02 | No B11 dual-window-positive parent pair; XAUUSD/M15 and GBPUSD/M15 were ineligible due suspected truncation. |
| NEGATIVE EVIDENCE | BT8 | SINGLE improved PF/EqDD in USDJPY/H4 and XAUUSD/H4, but XAUUSD/H4 BWD stayed below PF 1; accepted classification `GRID_STACK_MATERIAL_WEAKNESS / ENTRY_ONLY_NOT_YET_QUALIFIED`. |
| NEGATIVE EVIDENCE | Corrected-parser example | XAUUSD/H1 example MAIN PF 1.03 and BWD PF 0.89; authority remains `EXAMPLE_ONLY_NOT_HOME`. |
| UNKNOWN | Entry freeze | No prospective owner-ratified FastMA / SlowMA / MAMethod / MA_TF found. |
| UNKNOWN | ATRPeriod | No prospective owner-ratified value found. |
| UNKNOWN | Home | No prospective owner-ratified HomeSymbol / HomeTF found. |
| UNAVOIDABLE OWNER CHOICE | Entry reference | Accept listed bundle or provide explicit custom source-valid values. |
| UNAVOIDABLE OWNER CHOICE | ATRPeriod | Provide one explicit positive integer. |
| UNAVOIDABLE OWNER CHOICE | Home | Select one explicit symbol/timeframe; historical contexts cannot choose it automatically. |

## Documentary reconciliation

- `EA_TEMPLATE_XX00_BACKTEST_READINESS_V1.md` still classifies B11 as `READY_FOR_OWNER_RATIFICATION_ONLY`.
- `EA_TEMPLATE_B11_B12_B18_OWNER_DECISION_PACK_20260912.md` states that no current evidence identifies a uniquely justified best B11 choice.
- Its B11 summary presents XAUUSD/H1, USDJPY/H4, and XAUUSD/H4 as historical-context choices with the listed MA bundle + ATR14, without ranking them.
- `EA_LAB_OWNER_DECISIONS_20260920_rev1.xlsx` exists on BaBoss but has no B11 sheet, so it supplies no B11 freeze.
- Current B11 Monitor/example evidence remains presentation/example only and cannot supply Home authority.

## Deterministic reduction result

The prospective B11-00 identity must preserve shift0 MA-state entry semantics and the already ratified generic xx-00 chassis.
Evidence does not authorize choosing SINGLE, reusing historical GRID_TREND management, or selecting Home from PF history.
No unique lawful B11-00 Home/config can be derived without owner ratification.

## Smallest exact owner decision

`B11_ENTRY = LISTED(20,50,EMA,PERIOD_CURRENT) | CUSTOM(...); B11_ATR_PERIOD = <positive integer>; B11_HOME = <SYMBOL>/<TF>`

Source-backed Home contexts already documented for quick selection: `XAUUSD/H1`, `USDJPY/H4`, `XAUUSD/H4`.
A different explicit source-supported symbol/TF may be supplied prospectively; it must not be inferred from historical PF.

## Gate status

- Home/config freeze: `BLOCKED_OWNER_DECISION`
- Model1 MAIN+BWD: `NOT_STARTED`
- Optimization: `NOT_AUTHORIZED`
- Model4: `NOT_STARTED`
- Robustness / Monte Carlo: `NOT_STARTED`
- HOLDOUT: `UNSPENT`
- Candidate / Grade / KINT: `NOT_ELIGIBLE`
- Monitor: existing read-only B11 presentation only; no new Monitor lane created.

## Next lawful action

After the owner supplies the one-line freeze, preregister exactly one fixed B11-00 Model1 MAIN+BWD pair on the chosen Home with the full effective configuration identity bound before tester execution.
Stop after that pair unless a separate prospective continuation contract becomes satisfied.
