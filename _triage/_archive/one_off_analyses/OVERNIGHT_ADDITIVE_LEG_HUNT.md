# Overnight additive-leg hunt — MacdDiv + Wave5 multi-home (2026-07-16B→17, autonomous)

Phase 1 of the overnight plan: apply the multi-home both-window Model-4 method (that found the
XAU IchiADX leg) to two naked single-config validated EAs on untested trending homes.
CSVs: `_mt5_auto/OVERNIGHT_MULTIHOME.csv` (MacdDiv), `_mt5_auto/WAVE5_MULTIHOME.csv`, `_mt5_auto/WAVE5_USDJPY_YS.csv`.

## MacdDiv_Naked (momentum divergence) — ❌ no new home (XAU-specific)
| sym | MAIN | BWD |
|---|---|---|
| XAUUSD | 1.54 | 0.97 |
| XAGUSD | 0.67 | 0.77 |
| GBPJPY | 0.82 | 1.00 |
| EURJPY | 0.96 | 0.87 |
| USDJPY | 0.95 | 1.11 |
| US30 | 0.72 | 1.26 |
No both-window ≥1.2. XAU is MAIN-only (BWD 0.97). USDJPY/US30 = window-inverted. **XAU-specific confirmed** — do not multi-home MacdDiv further.

## Boss_17_Wave5 (VWAP wave) — 🟡 1 thin new home: USDJPY
| sym | MAIN | BWD | note |
|---|---|---|---|
| XAUUSD | 1.07 | 1.05 | ref (deployed; weak on this H1 config) |
| XAGUSD | 1.31 | 1.29 | **deployed leg 990302 — confirms XAG = strong Wave5 home** |
| **USDJPY** | **1.12** | **1.50** | NEW both-window home |
| GBPJPY | 0.90 | 0.82 | dead |
| US30 | 1.71 | 0.78 | window-inverted (MAIN-only) |

**USDJPY year-split (Model-4):** 2020 1.48 · 2021 1.06 · 2022 1.73 · 2023 1.22 · 2024 1.53 · 2025 0.96
= **5/6 years non-losing** (2025 -$6 noise-level), clean profile. **BUT net is TINY** (~$5-122/yr on ~60t;
total ~$286/6yr ≈ 3% on $10k). MAIN net +$59 on 216t = $0.27/trade → **spread-fragile** (Wave5 = many small
trades; real spread likely eats it). DD tiny (0.76%).

## VERDICT
- **MacdDiv: XAU-specific, no additive leg.** Multi-home closed.
- **Wave5 USDJPY: marginal thin candidate** — real both-window + 5/6 non-losing, but edge so thin it's
  borderline vs a demo slot (spread-fragile). **USER CALL:** add as a light demo probe or skip. NOT a strong leg.
- The strong Wave5 home remains XAG (deployed) > XAU.
- **Method note:** multi-homing the OTHER naked EAs (unlike IchiADX) yields little — most lab EAs are
  genuinely symbol-specific. The IchiADX XAU win came from the PERIOD lever, not just symbol-swap.
  → higher-EV next = the 091 NEVER-TOUCHED momentum builds (iMA|iADX|iATR cluster), not more multi-home.
