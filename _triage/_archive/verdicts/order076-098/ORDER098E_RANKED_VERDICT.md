# ORDER-098-E — Currency-strength ranking build-on verdict (Opus lead, 2026-07-17)

**Build-on of 098-D** (fixed-chart naked = marginal PF 1.01/1.01 EURJPY H4). `CurrStrength_Ranked.mq5`:
single-instance multi-symbol — scans an 8-cross universe each bar, trades the single most-extreme
strength-diff pair; selectable exit ENUM (FIXED_ATR / TRAILING / PARTIAL_BE) + capped-flat pyramid
(hedging-guarded, not martingale). mql-review PASS (B5 hedging-guard + partial-BE ordering fixed),
compile 0/0 (ex5 45628b).

## Results (Model-1, chart EURJPY H4, both-window; CSV `_mt5_auto/order098e_ranked.csv`)
Multi-symbol scan **confirmed working**: 701 trades spanning all 8 crosses (EURJPY GBPJPY EURGBP
EURAUD GBPAUD EURCAD CADJPY GBPCHF).

| exit mode | MAIN PF (t) | BWD PF (t) | win% M/B |
|---|---|---|---|
| FIXED_ATR | 0.88 (701) | 0.89 (515) | 37.2 / 39.6 |
| TRAILING | 0.67 (767) | 0.73 (547) | 33.4 / 31.6 |
| PARTIAL_BE | 0.85 (790) | 0.79 (553) | 38.5 / 38.9 |

098-D single-chart EURJPY H4 baseline = 1.01 / 1.01.

## VERDICT — ranking does NOT lift; currency-strength edge is marginal + non-generalizing
Portfolio ranking (0.88/0.89) comes in **below** the 098-D single-chart marginal (1.01/1.01). The
ranking selects the most-extreme strength-differential pair, but that "highest conviction" pool
includes the weak crosses (GBPJPY was 0.57 naked) → pooling **dilutes** EURJPY's faint edge rather
than concentrating it. Meaning: the 098-D 1.01/1.01 is more **EURJPY-H4-idiosyncratic** than a
general currency-strength phenomenon. Exit tricks: TRAILING hurts (0.67 — confirms the signal is
short-horizon, gives back on trail), PARTIAL_BE ≈ neutral. Win% stays 37-39% (below the RR1.5
breakeven of 40%) across all three exits.

**Concept exploration is now thorough** (2 EAs, ~40 runs): strength-diff entry swept over
threshold×3 · exit-RR×3 · TF×2 · fixed-vs-ranking · exit-mode×3 · 8 crosses. Best result anywhere =
marginal 1.01/1.01 on one cross. Currency-strength meter = **mechanically sound, faint idiosyncratic
edge, NOT a robust deployable portfolio signal.**

## Remaining build-on branch (LOWER priority — diminishing prior)
One untested lever: a **trend/regime confluence filter** on the EURJPY-H4 single-chart base (take the
strength-diff only when the pair's own trend agrees) — could cut the 60% losers to lift win% past
40%. Prior is low after ranking/exit/RR all failed to lift, but it's the one distinct lever left.
Parked as optional follow-up; the meter core `CurrencyStrength()` is reusable if revisited.

## Artifacts
- EAs: `ea_projects/(EXP)_CurrStrengthRanked/CurrStrength_Ranked.mq5`, `(EXP)_CurrencyStrength/CurrStrength_Naked.mq5`
- Sets: `_mt5_auto/ab_sets/order098e/` · Reports: `_mt5_auto/reports/O098E_*.htm` · CSV above.
