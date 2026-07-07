# (Boss) RSI Mean-Reversion GridLog — standalone project home

> **canonical entry = `PROJECT_STATE.md`.** This folder = the standalone Boss EA's
> live working files (source + binary + sets + reports). Design record (frozen) =
> `_specs\RSI_MR_GridLog_SpecCard.yaml` + `_specs\(Boss)_RSI_MR_GridLog_rev01.mq5`.

- **Chain:** `EA_RSI_MR_GRIDLOG_20260707_01` · **magic** 990103 · **class** L3 (grid + LOG lot, no hedge by default; dual-side needs HEDGING account — guarded in OnInit)
- **Origin:** original design inspired by the reverse-engineered principle of "RSI from pips" (ORDER-036 survivor) + user ideas (ATR spacing, EMA20 asymmetric lot, MACD/avg-RSI v2 toggles) + real SL/caps. NOT a clone — see `../../RSI_FROM_PIPS_REVERSE_ENGINEERING.md`.

## Files here
| path | what |
|---|---|
| `(Boss)_RSI_MR_GridLog_rev01.mq5` | working source (copy of the frozen `_specs` snapshot) |
| `(Boss)_RSI_MR_GridLog_rev01.ex5` | compiled binary (0 err / 0 warn) |
| `set_files\RSIMR_wideSL.set` · `RSIMR_deepgrid.set` | validation .set probes |
| `reports\RSIMR_EURUSD_*.htm` | smoke + BWD stress reports (2026-07-08) |

## Status (2026-07-08) — decision pending with user
rev01 = **mechanically sound, NOT a durable edge as designed.** Smoke EURUSD H1 2025-26
wide-SL = PF 1.43, but BWD trend-years (2020-22) LOSE regardless of SL width / grid depth
(original got ~2.3 there). The safety redesign diverged too far from the original's exact
recipe. Hand-tuning further = overfit-fishing (repo rule) → **STOPPED.** Full validation log
+ options (A shelve · B rev02 minimal-change · C full IS/OOS) are in the SpecCard header.

## Build / recompile
MetaEditor headless, compiling **in place here** (never into the `D:\EA_Project` archive):
```powershell
& "D:\Meta 5\metaeditor64.exe" /compile:"D:\EA_LAB\ea_projects\(Boss)_RSI_MR_GridLog\(Boss)_RSI_MR_GridLog_rev01.mq5"
```
Backtest via `D:\EA_LAB\scripts\mt5_run.ps1` (close MT5 GUI first).
