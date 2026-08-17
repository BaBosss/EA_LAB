# ExpertMAPSAR M3 — MAIN + BWD optimize/validate evidence

Candidate: ExpertMAPSAR · source SHA-256 `6c5e7b665a766e6e995b673d9b8cd1e4c40e4de885c4413ad8f7e4b8a9a45e62`
(verified identical to the compiled binary's paired .mq5 in the tester Experts folder before any
run below). Lane: `D:\Meta 5` (DataDir `9CA16B8382AE4CF692710FB36B9DA355`). Symbol NZDUSD.
Compiled Expert (unchanged since M2, recompiled same source): `M2W5C4_CANDIDATE_ExpertMAPSAR`
(flat Experts-root binary; `-Expert ExpertMAPSAR` does not resolve on this lane — the tester
only finds names present at the Experts root, and the flat `M2W5C4_CANDIDATE_...` copy is what
M2's accepted evidence and this task both actually ran).

Governed by `TASK_CONTRACT.md` (commit `57b56779`). Search surface: exactly 3 levers
(`Inp_Signal_MA_Period`, `Inp_Signal_MA_Shift`, `Inp_Trailing_ParabolicSAR_Step`), frozen inputs
unchanged (`Inp_Signal_MA_Method=0`, `Inp_Signal_MA_Applied=1`,
`Inp_Trailing_ParabolicSAR_Maximum=0.20`, money module `CMoneyNone`). No `Magic` input exists on
this candidate's 7-line surface (confirmed against `M2_WAVE5_C4_MAPSAR/sets/ExpertMAPSAR_defaults.set`).

## Coarse grid — both TFs, MAIN 2023.01.01–2025.12.31, Model 1, complete grid (5×5×5=125/TF)

Set: `sets/ExpertMAPSAR_coarse.set`. XML: `optimizations/M3W5C4_MAPSAR_H1_COARSE.xml`,
`optimizations/M3W5C4_MAPSAR_M30_COARSE.xml`.

### H1 (primary/accepted home)

- 125/125 passes returned. Only **5/125** cells clear the pre-registered participation floor
  (>=100 closed trades on MAIN): (period,shift,step) = (8,12,0.02) PF=13.00 tr=120,
  (10,12,0.02) PF=12.87 tr=123, (12,0,0.03) PF=24.96 tr=104, (10,9,0.02) PF=9.04 tr=109,
  (12,6,0.02) PF=9.16 tr=100 — the last one **is the M2-accepted baseline point**.
- One-step-neighbour check on all 5: **every one of the M2-accepted point's 6 neighbours misses
  the floor or the PF bar** (period±2, shift±3, step±0.005 all drop under 100 trades or under
  PF 1.20). The best-connected H1 pair is (8,12,0.02)↔(10,12,0.02) — mutually OK on the period
  axis only, but every shift/step neighbour of both still misses.
- **Finding: H1 has no genuine plateau under the >=100-trade floor at this resolution — the 5
  eligible cells are isolated spikes, including the M2-accepted point itself.** This is a
  material correction to the M2 read, which accepted (12,6,0.02) on trade count alone without a
  neighbour-stability check.

### M30 (secondary)

- 125/125 passes returned. **19/125** cells clear the floor+PF+net bar (full list in commit
  `d1cecb9a` log; e.g. best-PF eligible cells: (14,3,0.02) PF=6.87 tr=122, (12,3,0.02) PF=9.14
  tr=135, (16,6,0.02) PF=10.56 tr=124).
- Sub-cube check at fixed `step=0.02`, period∈{12,14,16}, shift∈{3,6}: **6/6 cells clear the
  bar** (PF range 3.59–10.56, trades 104–135) — a genuine contiguous plateau region, not a spike.
- Best-connected coarse node inside that region: period=14, shift=3, step=0.02 — 4/6 one-step
  neighbours also clear the bar (period±2 both OK, shift+3 OK, step+0.005 OK; shift-3 and
  step-0.005 miss).

**TF selection: M30**, per the contract's surface-robustness rule (prefer H1 only if it is
itself eligible and not materially less robust than M30 — H1 has zero eligible plateau
candidates at all, so M30 is selected).

## Fine grid — M30 only, pre-registered before launch (commit `d1cecb9a`)

Set: `sets/ExpertMAPSAR_fine_M30.set`. XML: `optimizations/M3W5C4_MAPSAR_M30_FINE.xml`.
Ranges (pre-registered, centered on the coarse plateau, never widened past the original coarse
bounds 8–16 / 0–12 / 0.01–0.03): `Inp_Signal_MA_Period` {12,13,14,15,16} step 1,
`Inp_Signal_MA_Shift` {2,3,4,5,6} step 1, `Inp_Trailing_ParabolicSAR_Step`
{0.015,0.0175,0.02,0.0225,0.025} step 0.0025. Complete grid, 5×5×5=125 combos.

- 125/125 passes returned. **38/125** cells clear the floor+PF+net bar — the finer resolution
  resolved a much richer surface than the coarse read suggested (the coarse grid's step=3 shift
  axis was straddling a real optimum that sits at shift=4–5, between the coarse-tested
  shift=3/shift=6 points).
- One-step-neighbour check (full results in `journal/` commit log): the strongest **interior**
  candidate (no swept dimension sitting at a tested-range edge) is **period=13, shift=4,
  step=0.0225** — PF=8.21, trades=127, net=+204.56, DD%=0.52, Sharpe=1.08, with **4/6** one-step
  neighbours also clearing the bar (period-1 OK, shift-1 OK, step-0.0025 OK, step+0.0025 OK;
  period+1 collapses to 57 trades/PF1.31, shift+1 narrowly misses the floor at 98 trades).
  Several edge-of-range candidates score a higher neighbour *ratio* (up to 4/5, since an edge
  cell has fewer neighbours to fail), but this is the best-supported genuinely-interior pick.

**Plateau verdict: PASS on M30** — not a spike; a real, checkable neighbourhood of parameter
values around period≈12–16, shift≈3–6, step≈0.02–0.025 all produce PF>=1.20 at >=100 trades with
positive net on MAIN.

## Locked candidate

`sets/ExpertMAPSAR_M3_locked_M30.set` — SHA-256
`40CCB7CCF388A075264E7121D0EC766521D6671DEF5A945149A63C2334930082`.

```
Inp_Expert_Title=ExpertMAPSAR
Inp_Signal_MA_Period=13
Inp_Signal_MA_Shift=4
Inp_Signal_MA_Method=0
Inp_Signal_MA_Applied=1
Inp_Trailing_ParabolicSAR_Step=0.0225
Inp_Trailing_ParabolicSAR_Maximum=0.2
```

No `Magic` input on this candidate's surface (unchanged from M2 baseline). No retuning after
this point, including after the BWD result below.

## MAIN locked-candidate confirm — NZDUSD M30, Model 1, 2023.01.01–2025.12.31

Report: `reports/M3W5C4_MAPSAR_M30_MAIN_LOCKED.htm`.

| metric | value |
|---|---|
| trades | 127 |
| deals | 254 |
| PF | 8.21 |
| net | +204.56 |
| recovery factor | 3.91 |
| Sharpe | 1.08 |
| balance DD | 24.04 (0.24%) |
| equity DD | 52.32 (0.52%) |
| history quality | 100% |
| invalid stops / invalid volume / not-enough-money / init-runtime errors | 0 / 0 / 0 / 0 |

Confirm run reproduces the fine-grid optimizer pass exactly (PF 8.21, trades 127, net 204.56,
DD% 0.52 both places) — the locked .set is faithfully reproducible outside the optimizer.

**Canonical year-split (`scripts/report_year_split.py` on this one continuous report):**

```
FULL   trades= 127  PF= 8.21  net=   +204.56  balDD= 0.24%
2023   trades=  77  PF=544.08  net=   +141.20  balDD= 0.00%
2024   trades=  10  PF=  inf  net=    +16.44  balDD= 0.00%
2025   trades=  40  PF= 2.67  net=    +46.92  balDD= 0.24%
```

Trade counts partition exactly to 127 (77+10+40), as required. No losing year.

**MAIN gate (PF >= 1.20, hard): CLEAR (PF 8.21). Participation (>=100 trades): CLEAR (127).**

## BWD validation — NZDUSD M30, Model 1, 2020.01.01–2022.12.31 (never searched)

Report: `reports/M3W5C4_MAPSAR_M30_BWD_LOCKED.htm`.

| metric | value |
|---|---|
| trades | 58 |
| deals | 116 |
| PF | 4.76 |
| net | +110.18 |
| recovery factor | 0.91 |
| Sharpe | 0.45 |
| balance DD | 25.04 (0.25%) |
| equity DD | 121.28 (1.21%) |
| history quality | 99% |
| invalid stops / invalid volume / not-enough-money / init-runtime errors | 0 / 0 / 0 / 0 |
| non-zero execution note | 1× "failed modify SL [Market closed]" (2020.01.13 00:00:30) — a benign tester artifact of attempting to trail a stop at an instant the market session is shown closed, not an invalid-stops/invalid-volume/failed-entry defect. No other anomaly in the run's journal segment. |

**BWD gate (PF >= 1.00, per this task's explicit contract): CLEAR (PF 4.76).**

**🔴 Participation caveat (CLAUDE.md 2026-08-05 ratified floor, "every window, every row above"):
BWD trades = 58, under the project's global >=100-closed-trades-per-window floor.** The
TASK_CONTRACT's own BWD gate text is PF-only and does not restate a trade floor for this
window, so the BWD gate as literally written in this contract is cleared — but the window does
**not** clear CLAUDE.md's separate, broader participation bar ("a window with fewer does not
clear its bar, whatever the PF says"). This is flagged explicitly, not silently absorbed into
the disposition below, per the `bar-cleared-by-non-participation` lesson.

## Overall disposition: **M3_PASS** (with a stated participation caveat on BWD)

Both of this task's pre-registered gates are cleared as written: MAIN PF 8.21 >= 1.20 (hard,
127 trades, plateau-not-spike on M30) AND BWD PF 4.76 >= 1.00 (hard-for-this-task). Execution
validity is clean on every reported run (search winner cells, locked MAIN, locked BWD). No
product defect surfaced.

This is **not** a verdict — CLAUDE.md's VERDICT GATE vocabulary (CANDIDATE / BUILD-ON / etc.) is
reserved for the owning caller. What this evidence file adds beyond "both gates pass": (1) H1,
the previously-accepted home TF, turns out to have **no genuine plateau** at all under the
project's participation floor — the M2-accepted point was an unsupported spike, and M30 is the
TF that actually carries this candidate; (2) the BWD confirmation, while numerically strong
(PF 4.76, no losing regime), rests on only 58 trades — thin enough that CLAUDE.md's own global
participation bar would not certify it standing alone, and any downstream verdict should weigh
that explicitly rather than read "M3_PASS" as an unqualified robust-BWD result.
