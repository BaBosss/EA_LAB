# ORDER-430 results — Boss_14 GridLog host search

Runner: batch execution, mechanical only. No verdict issued here (order Prohibitions).
Lane: `D:\Meta 5b` (portable), Model 4 real ticks. Set: `_mt5_auto/ab_sets/order430/CTRL.set`
(copied from `ea_template/sets/B14_AB_off.set`, with `_9_RegimeGateAdds=false`,
`_50_RegimeMode=0`, `StackConfirm=0`, `_9_PA_MinBodyRatio=1.0` pinned per STEP 0(a)).

STEP 0(b) confirmed on the first report (`O430_USDJPY_H1_BWD.htm`) — Inputs page
contains, verbatim: `StackConfirm=0`, `_9_RegimeGateAdds=false`, `_50_RegimeMode=0`.
Not BLOCKED.

## Table

| symbol | TF | BWD PF | BWD trades | BWD DD% | MAIN PF | MAIN trades | MAIN DD% | flag |
|---|---|---|---|---|---|---|---|---|
| USDJPY | H1 | 1.15 | 343 | 12.56 | — | — | — | BORDERLINE |
| EURJPY | H1 | 1.08 | 473 | 11.96 | — | — | — | BORDERLINE |
| AUDCAD | H1 | 2.20 | 62 | 1.70 | 0.93 | 205 | 9.02 | QUALIFIED |
| CADJPY | H1 | 1.12 | 363 | 15.58 | — | — | — | BORDERLINE |
| EURUSD | H1 | 0.84 | 163 | 10.36 | — | — | — | fail (<1.00) |
| XAUUSD | H1 | 2.29 | 52 | 1.86 | 0.95 | 237 | 4.84 | QUALIFIED |
| GBPJPY | H1 | 0.15 | 40 | 24.89 | — | — | — | TRUNCATED-CAGE-KILL(see note) |

## Notes / anomalies

- **GBPJPY BWD is not a comparable number.** `check_truncated_run.ps1` flagged it
  `[SUSPECT]` on the first pass (idle tail 1023.7 days = 93.5% of the window, entry
  deals only 30). Re-checked against the tester log
  (`D:\Meta 5b\Tester\Agent-127.0.0.1-3000\logs\20260728.log`) per the script's own
  instruction — confirmed genuine cage kill, not a machine artifact:
  `[RISK] HARD KILL: DD 25.01% >= 25.00% (profile 2) -> closing all` fired at
  `2020.03.12 07:45:59`, ~10 weeks into the 3-year BWD window. The reported PF 0.15 /
  40 trades / DD 24.89% cover only 2020.01.01–2020.03.12 (the COVID-crash opening
  stretch), not the full 2020–2022 window. Not the "no disk space in ticks
  generating function" machine trap (bars were generated fine; this is the EA's own
  ProtectLevel=2 kill switch firing) — no half-window re-split was done since the
  order's re-split instruction is specific to that other trap. No STEP 2 run
  (BWD PF is far below even BORDERLINE regardless of the truncation caveat).
- All other 6 runs completed cleanly on the first pass, no BLOCKED, no THIN(n<30).
- Two hosts QUALIFIED at BWD (AUDCAD, XAUUSD) and both got STEP 2 MAIN runs per the
  tree. Both MAIN PFs came back <1.0 (AUDCAD 0.93, XAUUSD 0.95) — recorded as data,
  no interpretation offered here.
- No lever was ever turned on. All seven runs used the identical CTRL.set file,
  changing only `-Symbol` (and window for the two MAIN runs).
