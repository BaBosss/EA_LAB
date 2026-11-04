# R15 score formula — development-only trial 2 (2026-11-04)

**Label: DEVELOPMENT_ONLY** (R13). This trial applies the decision rule that trial 1 pre-registered (`R15_SCORE_TRIAL_1_DEV.md` §"Trial 2"):

> Freeze the R15 formula only if one variant is **never worst** and is **best on ≥ 2 of 4 classes**. Otherwise freeze F5 as
> the simplest.

## Runs

| Class | EA | Home | Grid (full, Model 1) | Passes MAIN / BWD |
|---|---|---|---|---|
| trend | Boss_15_ST03 | GBPUSD H1 | MacdFast 8–16/2 · MacdSlow 20–32/3 · TP_ATR 2–5/0.5 | 175 / 175 |
| reversion | Boss_13_MeanRev | EURUSD H1 | BB_Period 14–30/4 · BB_Dev 1.6–2.6/0.2 · SL_ATR 1.5–3.5/0.5 | 150 / 150 |
| breakout | Boss_12_Breakout | XAUUSD H1 | Bars 10–40/5 · TP_ATR 2–5/0.5 · SL_ATR 1.5–3.5/0.5 | 245 / 245 |
| escalation | Boss_14_GridLog | USDJPY H1 | DistATR 1–3/0.5 · StepATR 0.6–1.6/0.25 · LogPower 1.1–1.5/0.1 | 125 / 125 |

- **Setup:** MAIN 2023.01.01–2025.12.31 and BWD 2020.01.01–2022.12.31, identical grids. Binaries compiled from canonical
  `4d9ea6f9`, identity PASS. Full-surface sets in `D:\EA_LAB_RESET\trial\r15_t2\sets\`. XMLs are under
  `D:\EA_LAB_CONTROL\w\claude-r15-trial2-20261104\_mt5_auto\optimizations\R15T2_*`. Raw analysis is in `trial2.json`.
- `optimize_guard` ran warn-only (`-SkipOptimizeGuard`), because only Boss_14 has parameter bindings. That is acceptable
  for a development-only trial and is not acceptable for a qualifying run.
- **Variants:** F0–F6 as in trial 1, each raw and neighbour-smoothed (`_SM`). Smoothing takes the mean score over every
  pass within one grid step on every axis.

## BWD health of each grid (selection cannot beat this)

| Class | BWD PF median, all passes | Share of passes with BWD PF > 1 |
|---|---|---|
| trend | 0.99 | 40 % |
| reversion | 0.97 | 25 % |
| breakout | 0.93 | 14 % |
| escalation | **1.32** | **94 %** |

## Top-5 BWD PF by variant (the main measure)

| Variant | trend | reversion | breakout | escalation | best on | worst on |
|---|---|---|---|---|---|---|
| F0 PF | 1.001 | 0.967 | 0.955 | 1.030 | — | esc (tie) |
| F0_SM | 0.954 | 0.971 | 0.994 | **1.559** | esc (tie) | — |
| F1 net | 0.973 | **0.951 worst** | 0.931 | 1.246 | — | rev |
| F2 recovery | 0.953 | 0.989 | 0.950 | 1.030 | — | esc (tie) |
| F2_SM | 0.916 worst (tie) | 0.964 | **1.006** | 1.313 | brk (tie) | trend |
| F3 Sharpe | **1.003** | **1.002** | 0.912 worst (tie) | 1.030 | trend, rev | brk, esc |
| F3_SM | 0.989 | 0.971 | 0.947 | **1.559** | esc (tie) | — |
| F5 recovery × conf, 12 % cap | 0.953 | 0.989 | 0.950 | 1.030 | — | esc (tie) |
| F5_SM | 0.916 worst (tie) | 0.964 | **1.006** | 1.313 | brk (tie) | trend |
| F6 ln PF·√n/DD | 1.001 | 0.985 | 0.912 worst (tie) | 1.030 | — | brk, esc |

F4 equals F0 on every class: the 12 % cap and the PF > 3 clip never bound.

## Applying the pre-registered rule

- **F3 Sharpe** is the only variant best on 2 classes (trend and reversion). It is **worst on breakout** and tied-worst on
  escalation, so it fails "never worst".
- No other variant is best on ≥ 2 classes.
- ⇒ **No variant qualifies. The pre-registered fallback applies: freeze F5**, the simplest, which encodes the ratified 12 %
  DD cap and the R19 confidence.

## What the data says beyond the rule

1. **The ranking formula cannot create an edge.** On the three grids whose BWD median PF is below 1, the best top-5 average
   from any variant is about 1.00. Across 7 formulas × 2 variants, the spread is 0.09 or less.
2. **Smoothing matters where there is an edge.** On escalation (94 % of passes profitable in BWD), every smoothed variant
   beats its raw version: top-5 BWD PF 1.03 → 1.31–1.56, and DD falls. On the edgeless grids, smoothing is mixed. This
   supports keeping the plateau rule (R14) as its own step after scoring, rather than hiding it inside the score.
3. **In-sample rank barely predicts out-of-sample rank.** Spearman is −0.44 to +0.39 everywhere. The project already
   expects this, which is why BWD is a gate and not a tie-breaker.

## Decision (owner OK 2026-11-04, rule table v2)

- **R15 = F5:** score = recovery factor × R19 confidence multiplier (A 1.0 · B 0.75 · C 0.5 · D 0). The score is −∞ when
  equity DD > 12 %.
- **R14 plateau rule:** default to the neighbour-smoothed score (one grid step on every axis) when choosing the frozen
  center. It is decided per EA with the owner, as R14 already says.
- **Escalation (R18) penalty weights stay `null`.** Boss_14 has no in-EA basket log yet, so worst-basket depth cannot be
  measured. It must not be estimated from deals.
