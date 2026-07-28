# ORDER-431 RESULTS — MacdDiv_Naked USDJPY H4 optimize

Run by: batch runner (foreground, synchronous, lane `D:\Meta 5c`, Model 1 only).
Date: 2026-07-28.

**No verdict issued below — numbers only, per Prohibitions.**

## Pre-flight fix 1 — stale lane binary (confirmed and corrected)

- Confirmed before any run: `D:\Meta 5c\MQL5\Experts\MacdDiv_Naked.ex5` was 33,770 bytes,
  mtime 2026-07-25 17:56 — 4 hours older than source `MacdDiv_Naked.mq5` (mtime 2026-07-25 21:57).
- Renamed the stale binary to `D:\Meta 5c\MQL5\Experts\MacdDiv_Naked.ex5.bak_20260728` (kept, not deleted).
- Copied the current build from
  `D:\MetaTraderData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\MacdDiv_Naked.ex5`
  (36,680 bytes, mtime 2026-07-25 22:05) into `D:\Meta 5c\MQL5\Experts\MacdDiv_Naked.ex5`. Copy only — no compile.
- **Verification method used (no GUI Inputs-page access available to this runner):** read the MT5 Tester
  journal log `D:\Meta 5c\Tester\logs\20260728.log` after the BASE run. The tester itself logged the actual
  EA inputs it loaded for `Experts\MacdDiv_Naked.ex5` (36,709 bytes loaded), and it explicitly lists, by name:
  ```
  _07_UseRsiGate=false
  _07_RsiPeriod=14
  _07_RsiBuyMax=45.0
  _07_RsiSellMin=55.0
  _08_UseMacdCross=false
  _08_CrossWithinBars=3
  ```
  Both `_07_UseRsiGate` and `_08_UseMacdCross` appear by name, confirming the copied binary contains the gate
  inputs. The sub-thresholds also came back at source defaults (RsiPeriod=14, RsiBuyMax=45.0, RsiSellMin=55.0,
  CrossWithinBars=3), not a corrupted per-terminal cache value — those three sub-params were not pinned in any
  `.set` in this order (the order only named the two boolean gates), so this is worth flagging: STEP 1 as
  written does not pin `_07_RsiPeriod` / `_07_RsiBuyMax` / `_07_RsiSellMin` / `_08_CrossWithinBars`, and this
  run got the source defaults by luck of a clean cache on this terminal, not by an explicit pin. If this lane's
  tester cache is ever touched by another EA/session before a re-run, those four values could silently drift.
- Confirmed the same tester-log check for RSIGATE and MACDCROSS runs — both list their respective gate as
  `true` with the same sub-param defaults, so the gates were genuinely exercised, not silently ignored.
- **Pre-flight fix 1 verdict: PASS — binary confirmed to contain both gate inputs. No BLOCKED condition hit.**

## Pre-flight fix 2 — pinning the two gates explicitly in every `.set`

- Source `.set` (`_vps_deploy/MACDDIV_XAU/MacdDiv_XAU_H4_demo_v1.set`) confirmed 13 lines, containing neither
  `_07_UseRsiGate` nor `_08_UseMacdCross`.
- Built `BASE.set` / `RSIGATE.set` / `MACDCROSS.set` in `_mt5_auto/ab_sets/order431/`, each adding both gate
  lines explicitly (`_07_UseRsiGate=false/true`, `_08_UseMacdCross=false/true` per arm).
- `Compare-Object` confirmation:
  - BASE vs RSIGATE: differs only on `_07_UseRsiGate` (false→true).
  - BASE vs MACDCROSS: differs only on `_08_UseMacdCross` (false→true).
  - source `.set` vs BASE: differs only by the two added pinned lines (`_07_UseRsiGate=false`, `_08_UseMacdCross=false`).
- Carried the two pinned gate lines into all four STEP 3 `SW<n>.set` fan files (all `_07_UseRsiGate=false`,
  `_08_UseMacdCross=false`, matching the STEP 3 base config). `Compare-Object` against BASE.set confirmed each
  `SW<n>.set` differs from BASE only on `_01_SwingRadius`. `SW3.set` is byte-identical to `BASE.set` (both pin
  SwingRadius=3), which the SW3 run result confirms (see below — identical PF/trades/net/DD to BASE).

## STEP 1 — baseline + two entry gates, MAIN (2023.01.01–2025.12.31)

| arm | MAIN PF | trades | net profit | DD% | flag |
|---|---|---|---|---|---|
| BASE (re-run control) | 1.08 | 250 | 37.24 | 0.80 | control |
| RSIGATE (`_07_UseRsiGate=true`) | 0.92 | 250 | -29.96 | 0.71 | no lift (PF ≤ BASE) |
| MACDCROSS (`_08_UseMacdCross=true`) | 1.53 | 28 | 52.59 | 0.27 | **THIN(n=28)** — not carried forward, whatever its PF |

Note: RSIGATE landed on exactly the same trade count as BASE (250) despite the gate condition being live
(confirmed via tester log — RSI thresholds were the real source-default values, not a stale cache). Both
arms took the source-default sub-parameters as noted above.

**TREE evaluation:**
- RSIGATE: PF 0.92 ≤ BASE 1.08 → "no lift" → go to STEP 3, no STEP 2 BWD run.
- MACDCROSS: PF 1.53 ≥ 1.2, but n=28 < 60 → **THIN(n=28)** → per the governing rule ("do not carry it
  forward, whatever its PF") this arm does not qualify for STEP 2's BWD leg and cannot be the STEP 3 fan base,
  regardless of its raw PF being the highest of the three.
- No arm triggered a STEP 2 BWD run.

## STEP 3 — `_01_SwingRadius` fan on MAIN (winner = BASE, the highest non-THIN MAIN PF from STEP 1)

| SwingRadius | MAIN PF | trades | net profit | DD% | flag |
|---|---|---|---|---|---|
| 2 | 1.18 | 321 | 101.36 | 1.67 | not THIN |
| 3 (= BASE, byte-identical .set) | 1.08 | 250 | 37.24 | 0.80 | not THIN — matches BASE exactly, sanity-check pass |
| 4 | 0.79 | 239 | -101.87 | 1.15 | not THIN |
| 5 | 1.04 | 194 | 16.27 | 0.69 | not THIN |

Fan winner by PF: SwingRadius=2 (PF 1.18, n=321).

## STEP 4 — BWD gate check

Fan winner (SwingRadius=2) MAIN PF = 1.18, which is **below** the STEP 4 threshold of ≥ 1.2. Per the order
("BWD on the fan winner, only if its MAIN PF ≥ 1.2 and it is not THIN"), STEP 4 does not trigger. No BWD run
was made for any arm or fan value in this order — none cleared the 1.2 MAIN gate while also being non-THIN.

## Files

- `.set` files: `D:\EA_LAB\_mt5_auto\ab_sets\order431\{BASE,RSIGATE,MACDCROSS,SW2,SW3,SW4,SW5}.set`
- Reports: `D:\EA_LAB\_mt5_auto\reports\O431_USDJPY_H4_{MAIN_BASE,MAIN_RSIGATE,MAIN_MACDCROSS,SW2,SW3,SW4,SW5}.htm`
- Stale binary backup: `D:\Meta 5c\MQL5\Experts\MacdDiv_Naked.ex5.bak_20260728` (not committed — outside repo).

STOP (per STEP 3 instruction — no configuration cleared the STEP 4 BWD gate).
