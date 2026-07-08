# Donchian-60 + Squeeze confluence (rev of SqueezeBreakout, user idea 2026-07-08)

User asked to combine BRK-XAU's Donchian range break with the squeeze filter. Implemented via the
SqueezeBreakout EA at RangeBars=60 + KcAtrMult=2.0 (+EMA200): enter only when a volatility squeeze
RELEASES AND price breaks a 60-bar range AND is with the 200-EMA trend. Single-position L1, real SL.

## Results (XAUUSD H1, RangeBars 60 / KcAtrMult 2.0 / Tp 3xATR)
| test | PF | trades |
|---|---|---|
| BWD 2020-22 | 1.69 | 36 |
| Holdout 2023-24 | 1.90 | 31 |
| FWD 2025-26 | 1.17 | 29 |
| Full-span | 1.41, DD 2.06% | 96 |
| MC ruin | 0% |
| **MC PF-5th (bootstrap)** | **0.966 — just under 1.0** |
| MC DD-95th | 2.73% |
| OOS split PF | 1.188 (degrade 36%) |

## Verdict: BORDERLINE — the confluence WORKED but just misses the demo bar
The user's idea was RIGHT: squeeze+Donchian confluence lifted the edge substantially — plain squeeze
was MC PF-5th 0.837 (clearly NOT_ROBUST); the confluence is 0.966 (nearly clears), with a strong
holdout (1.90) and tiny DD (2%). It's the best of the 3 weak builds. BUT PF-5th 0.966 < 1.0, while the
6 demo EAs all cleared >1.44 — adding it would lower the cohort's quality bar. Thin (96 trades) and
OOS-split degradation 36% also temper it.

**Recommendation: RESERVE / research-plus, NOT demo #7** — keep the cohort at 6 clean names; hold this
as the top reserve (one good re-opt or a stronger primary signal could push it over). The validated
concept — squeeze-release is a real confluence filter that lifts a breakout edge — is the keeper.
User may opt to add it as an experimental #7-watch if they want more names; it's defensible but the
weakest of the set.
