# ZABgoldpending — host-direct manual semantic probe preparation — 2026-09-25

Status: `PREPARED_WAITING_SERIALIZED_TESTER / A_OWNER_ONLY / MANUAL_START_REQUIRED / NO_PERFORMANCE_AUTHORITY`.

Lane: `ct-zabgoldpending-host-direct-manual-v1-20260924`.

This milestone prepares the already owner-approved host-direct fallback for the existing money-mode semantic question only. It does **not** establish DLL trust, performance validity, deployment authority, or permission to run while another tester owner is active.

## Accepted upstream contract

The source question remains exactly:

`Risk_Percent` versus `Fixed_Lot_Size` precedence for the opaque `ZABgoldpending.ex5`.

Accepted semantic carrier:
- Home: `XAUUSD / M5`
- Model: Model1 / 1 Minute OHLC
- window: `2023-01-01..2023-03-31` MAIN subwindow only
- deposit: USD 10,000
- leverage: 1:100
- exact EX5 SHA256: `f75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90`
- owner value: `Risk_Percent=1.0`

Only first-entry timestamp, side, requested/executed volume and init/dependency errors are admissible. PF, net, DD, balance, win rate, exits and later trade path remain forbidden evidence.

## Prepared portable bundle

External portable root:

`D:\EA_LAB_CONTROL\evidence\zabgoldpending-hostdirect-20260924\portable`

Bound artifacts:
- `terminal64.exe` SHA256 `f61ecfad618a4577df6743eb10e21cfeb2c374ea66ba8d4813c2c0ccca784d33`
- `metatester64.exe` SHA256 `dc54ac9265f693b2e469f06ddd7cc7a083f0a44f00b4a1ce199b98db3aa15e97`
- `MQL5/Experts/ZABgoldpending.ex5` SHA256 `f75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90`
- `MQL5/Profiles/Tester/ZABgoldpending.set` SHA256 `4de80df7352a0857bb8e760799582807fbf208271a1762aa34e82c1c166067b9`

The set is the exact A_OWNER surface:
- `Risk_Percent=1.0`
- `Fixed_Lot_Size=0.1`
- `tp_sl_points=400`
- `Magic_Number=123456`
- `Trailing_Start=70`
- `Trailing_Step=50`
- `Slipage=3`
- `Show_Debug_Info=true`
- `Swing_Period=7`
- `Min_Swing_Distance=50`
- `Use_Volume_Filter=true`
- `Max_Lookback=100`

No B/C set is activated by this preparation.

## Why host-direct remains gated

Historical A_OWNER execution reached the exact EX5/input surface but stopped at global initialization because DLL loading was not allowed. The no-network AppContainer follow-up proved authentication/cache isolation, then the execution platform refused the opaque DLL-enabled launch before process start.

That history remains negative/trust evidence. Copying the bundle to a host-direct portable terminal does **not** convert the opaque dependency into trusted code.

## Resource / execution gate

FB-G01 OPT01 A1 has durably released the tester resource: its Registry state is `WAITING` with blocker `RUNTIME_EXECUTION_COMPLETE_9_OF_9__POSTPROCESS_PENDING_OWNER__MT5_RELEASED`.

Main Control Tower serializes this opaque-DLL manual probe **behind MacroGate A/B**, which is the next controlled tester consumer. This ZAB lane therefore remains non-executing until MacroGate releases its separately registered runtime reservation.

Until then:
- do not open MetaEditor;
- do not start terminal64/metatester64 for ZAB;
- do not change host/global DLL settings;
- do not run A_OWNER;
- do not prepare B/C execution from outcomes.

After the serialized MacroGate runtime owner releases the tester, execution remains **manual-start only** under the existing owner-approved host-direct fallback. The operator must verify the exact portable hashes above, private tester/account identity, XAUUSD/M5/Model1/window/deposit/leverage, exact A_OWNER inputs and absence of unrelated MT5 jobs before Start.

Private account/auth material must remain outside Git.

## A_OWNER result gate

One A_OWNER attempt only.

Acceptable evidence:
- init/dependency messages;
- first entry timestamp;
- first entry side;
- requested/executed first-entry volume.

If initialization fails, DLL/dependency identity changes, first entry does not appear, or execution identity cannot be proven:
`A_OWNER_INELIGIBLE / SEMANTICS_UNRESOLVED`.

Do not run B/C.

If A_OWNER produces one mechanically valid first entry under the exact frozen identity, preserve that first-entry evidence and stop for Control-Tower reconciliation. B_FIXED_ONLY and C_RISK_ONLY remain the already-preregistered downstream comparison variants; their execution requires same-signal comparability and explicit continuation under the existing semantic contract.

## Authority ceiling

No performance interpretation, optimizer, HOLDOUT, Candidate/Grade/KINT, source reverse engineering, live deployment, chart attachment, risk/default change or trading authority follows.

`READY_FOR_TEST=false` remains true until the serialized MacroGate tester owner releases the resource and the exact execution identity is revalidated immediately before manual Start.
