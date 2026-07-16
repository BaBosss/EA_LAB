# Wave5 USDJPY — optimize rescue verdict (2026-07-17, Opus)

Overnight multi-home found Wave5 USDJPY as a THIN both-window cell (1.12/1.50, spread-fragile).
User asked "optimize เพิ่มได้ไหม" → swept entry levers → it UPGRADES to a clean candidate.

## Optimize: EntryFib × Wave3MinMult × both-window Model-4 (`_mt5_auto/W5OPT_stdout.log`)
| EntryFib \ Wave3 | 0.618 | 1.0 | 1.618 |
|---|---|---|---|
| 23.6 | 1.12/1.50 | 1.19/1.37 | 1.35/1.30 |
| **38.2** | 1.16/1.98 | 1.29/1.85 | **1.56/1.92** ⭐ |
| 50.0 | 1.02/1.17 | 1.11/1.04 | 1.00/0.85 (over-tight) |

Clear gradient: tighter Wave3 filter (0.618→1.618) + EntryFib 38.2 lifts PF. **Best = f382/m1618 = 1.56/1.92
both-window**, plateau (neighbors f382/m10 1.29/1.85, f236/m1618 1.35/1.30 all both-positive; f500 collapses).

## Year-split (f382/m1618, Model-4) = 🟢 ALL 6 YEARS POSITIVE
2020 1.56 · 2021 1.62 · 2022 2.29 · 2023 1.94 · 2024 1.70 · 2025 2.14 — no losing year (cleaner than the
USDJPY IchiADX basket). Comparable to the GBPJPY leg-8 bar that was approved.

## VERDICT: 🟢 DEMO-ELIGIBLE (optimize turned a thin cell into an all-years candidate)
- Both-window 1.56/1.92 + 6/6 years positive + plateau. Real edge.
- ⚠️ THIN frequency: 11-17 trades/yr (~85 total/6yr) — a few trades swing a quarter; size light, judge over months.
- Config: EntryFib 38.2 / Wave3MinMult 1.618 (stricter entry than the XAU/XAG deployed legs).
- Same EA (Boss_17_Wave5) as deployed XAU/XAG — just another chart. Magic 990303. Bundle `_vps_deploy/WAVE5_USDJPY/`.
- Answers "optimize เพิ่มได้ไหม" = YES; the naked-set was under-optimized. This is the same lesson as
  ICHIMOKU/period-lever: the entry-signal levers were never swept on this home.
