# ORDER-109 — Zeus regime-rescue verdict (Claude, 2026-07-16)

Regime-rescue #1: graft `_50_ Regime.mqh` into the Zeus standalone chassis, sweep the two parked
regime-dependent cells (AUDJPY, AUDUSD) both-window. START-HERE #1.

## Scoping reframe (important)
START-HERE #1 framed "regime-rescue pipeline ~29 EA" as a batch. Explore proved the addressable set is
**4 cells, not 29**: ~12 regime-tagged rows are MT4 black-box (`_50_` can't be compiled in); the Boss_14
family was already regime-refunnelled in ORDER-062. Only source-available, not-yet-gated cells remain:
**Zeus AUDJPY/AUDUSD** (needs graft — standalone chassis) + **XAU_NY** (no source → ORDER-110 rebuild) +
AsReMix (black-box, dead). **Regime-rescue = a build job, not a batch.**

## Build (done)
Ported `ea_template/core/Regime.mqh` → `ea_projects/(Boss)_ZeusInspired_GridLog/Regime_Standalone.mqh`
(self-contained: declares its own `_50_*` inputs; classify/gate logic verbatim from the reviewer-approved
LabCore module; no LabCore-Inputs dependency). Grafted into Zeus: include + `Regime_Init/Deinit` +
`Regime_AllowsEntryDirection(dir)` gate **before arming the first-entry pending-stop ONLY** (grid-adds +
exits untouched — matches the LabCore first-entry convention). Compile 0/0.

**⚠️ Gotcha banked:** `D:\Meta 5b\MetaEditor64.exe` cannot resolve `<Trade\...>` includes when compiling
in-place (its roaming data-folder B084 has no Include tree). Compile ea_projects EAs with
`D:\Meta 5\MetaEditor64.exe` (roaming 9CA16B has the Include tree). Confirmed via a 3-line CTrade probe.

## No-op proof (correctness gate — PASS)
Pre-graft baseline ex5 vs grafted ex5 at `_50_RegimeMode=0`, MAIN window, base sets — **bit-identical**:

| symbol | baseline net/pf/n | graft-mode0 net/pf/n | identical |
|---|---|---|---|
| AUDJPY | 663.80 / 1.12 / 186 | 663.80 / 1.12 / 186 | ✅ |
| AUDUSD | -473.03 / 0.75 / 46 | -473.03 / 0.75/ 46 | ✅ |

Graft is inert at mode 0 → every difference in the sweep is the regime gate alone, not broken Zeus.

## Sweep (Model 1, 32 runs — `_mt5_auto/ZEUS_REGIME_AB.csv`)

**AUDJPY (base lot8x, dir=BUY) — 🟩 RESCUE (both-window lift from a failing base):**

| config | MAIN pf | BWD pf | note |
|---|---|---|---|
| base | 1.12 | **0.94** | BWD fails (the parked death) |
| m1t20 (block-range) | 1.16 | 0.94 | gate inert in BWD (2020-22 = trendy, few RANGE bars) |
| m1t25 | 1.18 | 0.74 | BWD worse |
| m1t30 | 1.17 | 0.98 | BWD still <1 |
| **m1rng25 (range-only)** | **1.38** | **1.32** | strong both — single point (no range-thr neighbours yet) |
| **m2t20 (direction-lock)** | **1.32** | **1.39** | strong both + **DD↓ both** (10.2%/10.8% vs 12.2%/16.7%) |
| m2t25 | 1.17 | 1.29 | both positive → m2t20/25 = 2-point plateau (ridge, m2t20 = peak) |
| m2t30 | 0.97 | 1.09 | MAIN fails |

Coherent rescue signature: **PF↑ and DD↓ together in both windows** — not a PF cherry-pick. Mechanism read:
Zeus is an adverse-add grid → it thrives in RANGE / direction-locked regime and bleeds in strong trend.
Gating to range-only (m1rng) or trend-direction-locked (m2) is exactly the right medicine. Leaders:
**m2t20 (1.32/1.39)** and **m1rng25 (1.38/1.32)**.

**AUDUSD (base lot10x) — 🟡 fragile / likely selection-fit:**
base fails MAIN (0.75/1.54, mirror of AUDJPY). Only **m1t20 (1.22/1.70)** lifts both — but it is a **spike**
(m1t25/m1t30 MAIN fall back to 0.86/0.87 = thr-sensitive). m2t25 (1.02/1.21) marginal. No plateau → low prior.

## Verdict
- **AUDJPY = regime-rescue CANDIDATE** (IS-selected across 2 windows → not yet validated). m2t20 direction-lock
  and m1rng25 range-only both convert a both-window-fail base into both-window-positive with lower DD.
  → plateau-confirm (m2 thr15-22, range-only thr20-30) + **Model-4 real-tick confirm** running now.
- **AUDUSD = park** (m1t20 both-positive but a fragile spike; revisit only if AUDJPY funnel pays off).
- **Regime lever validated at scale on a 3rd cell** (after ORDER-057 XAU + ORDER-062 USDJPY/EURJPY): it is a
  home-picking axis — each symbol has its own favourable-regime config, not a universal setting.

## Confirm results (`_mt5_auto/ZEUS_AUDJPY_CONFIRM.csv`) — Model-4 decides

**Plateau confirmed (Model 1):**
- direction-lock m2: t15/t18 = 1.32/1.12, t20 = 1.32/1.39, t22 = 1.25/1.46, t25 = 1.17/1.29 → both-window
  positive across t15-t25 = real plateau (t20/t22 centre). t30 drops MAIN (0.97).
- range-only m1rng: thr20 = 1.78/1.09, thr25 = 1.38/1.32, thr30 = 1.18/1.48 → all three both-positive =
  real plateau, m1rng25 = balanced centre (not the MAIN-peak thr20).

**Model-4 real ticks (the fill-optimism gate):**
| config | MAIN M4 | BWD M4 | verdict |
|---|---|---|---|
| m2t20 (direction-lock) | 1.21 | **1.01** | BWD collapses to breakeven → fill-optimistic, reject |
| **m1rng25 (range-only)** | **1.24** | **1.29** | **both hold under real ticks → CONFIRMED** |

**Model-4 range-only plateau (full — `_mt5_auto/ZEUS_AUDJPY_M4PLATEAU.csv` + confirm):**
| config | MAIN M4 pf | BWD M4 pf | DD MAIN/BWD |
|---|---|---|---|
| m1rng20 | 1.63 | 1.28 | 12.2% / 15.0% |
| m1rng25 | 1.24 | 1.29 | 16.0% / 10.2% |
| m1rng30 | 1.30 | 1.52 | 8.6% / 9.9% |

**All three thresholds hold BOTH windows on real ticks** → the range-only rescue is a wide, robust Model-4
plateau, not a lucky point. (m1rng30 has the best DD + strongest BWD; m1rng25 is the balanced centre.)

## Year-split (m1rng25, Model-4 — `_mt5_auto/ZEUS_AUDJPY_YEARSPLIT.csv`) — the aggregate hid a bad year
| year | pf | net | note |
|---|---|---|---|
| 2020 | 1.16 | +182 | ✅ |
| 2021 | 1.16 | +262 | ✅ |
| 2022 | 1.23 | +598 | ✅ (BWD = all 3 years solid) |
| **2023** | **0.64** | **-1107** | ❌ real losing year (the parked note's flagged year) |
| 2024 | 5.85 | +1420 | ⚠️ only 28 trades = thin/lucky (gate over-filtered a trend year) |
| 2025 | 1.06 | +155 | ⚠️ near breakeven |
| 2026 | 2.10 | +935 | ✅ (partial year) |

6/7 years positive, but the MAIN-window aggregate (1.24) leans on a **thin-lucky 2024 (28t) + partial 2026**
while **2023 loses (-1107) and 2025 is breakeven**. 2023 was a trending yen year → a range-only grid gets
hurt; no range-threshold fixes a fundamentally trending year (structural, not tunable).

## FINAL VERDICT — 🟡 Zeus AUDJPY + range-only regime gate = PARTIAL RESCUE (regime-dependent candidate)
Base was both-window-fail (1.12/0.94). Range-only gate (`_50_RegimeMode=1`, AllowRange=true, AllowTrend=false,
ADX_TrendMin≈25, Regime_TF=H4) delivers a **Model-4 both-window-aggregate positive across a thr20-30 plateau**
(MAIN 1.24-1.63 / BWD 1.28-1.52) — a genuine, real-tick-confirmed improvement, and **BWD (2020-22) is
all-3-years-positive**. BUT year-split kills the "clean" claim: **2023 is a real losing year (-1107, PF 0.64)**,
2025 breakeven, and the MAIN edge leans on a thin-lucky 2024 → **fails the all-years-positive bar → NOT
deploy-ready.** Direction-lock (m2) died on real ticks (m2t20 BWD 1.39→1.01); range-only is the robust form
(grid-thrives-in-range mechanism).

**Status = PARKED-VERIFY(user) / build-on lead** (user has hand-experience; parked note already flagged 2023).
It is a real regime-rescue of the range-regime years, not an all-weather leg. **Recommendation to user:** either
(a) demo-experiment WITH the 2023-caveat + small size (accept regime-dependency, like other regime cells that
went to demo), or (b) park as verified-improvement, revisit if a range-regime AUDJPY slot is wanted. Not an
auto-deploy — the losing 2023 + thin-2024 need user judgment. corr<0.8 vs cohort still to run if pursued.

**Status = regime-rescue candidate leg** (like GBPJPY ORDER-106). Pre-proposal checks remaining:
1. Model-4 plateau confirm on m1rng20/30 (running — guards against m1rng25 being a lucky single point).
2. Year-split both windows (all-years-positive bar; parked note flagged AUDJPY 2023).
3. corr < 0.8 vs the 7-8 existing Boss/demo cohort legs → then propose to user with a new magic.

**ห้าม:** deploy talk before year-split + corr · retrofit the validated demo cohort · verdict from one window.
