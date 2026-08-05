# ORDER-091 .Final EA subtree — idea-mining VERDICT: **largely mined-out, no clear new candidate**

**Date:** 2026-07-18 · **Judge:** Claude (Opus-seat) · deterministic query of existing `_triage/FXDREEMA_XRAY.csv` (091A), no backtests

## Attach-ready axis = empty
Of **175 .Final EA rows**: `has_sl=3`, `lot_escalation=11`. The 3 with SL are SDK samples
(`OrderInfoSample`, `PositionInfoSample`, `Openai API Trade SL TP` template) — **zero real attach-ready
EAs.** Consistent with the fxDreema/course lineage (grid/martingale, no-SL) — per doctrine
[[feedback-course-files-extract-idea]] these are idea files, not structural-skips → value is on the
IDEA axis, not attach.

## Idea axis = concepts overlap lab coverage / dead pile
43 real strategies (indicators present, non-sample). Concept distribution:
`trend_follow 21 · grid_basket 21 · scalping · session_time · reversion 2 · divergence+grid 2 ·
harmonic_fib 1 · breakout 1 · zone_sr · correlation_pair 1`.

**Every populous cluster is already covered or dead in the lab:** trend_follow→breakout/SuperTrend
(covered) · grid_basket→MatchaGrid/Kangaroo/Zeus (covered) · divergence/harmonic/fib→DEAD (this
session's ORDER-098 + [[signal-landscape]]) · reversion→NuiIndy(now known martingale)/ST03 ·
correlation_pair→PAIRSPREAD stat-arb (098-F, covered) · session_time→LondonConso (covered).

The 13 "novel-ish" filtered candidates resolve to: **AI-LLM generated template EAs** (AI 8/AI 10 LLM
Trading = low-provenance generated junk) + **indicator-grids** (FrAMA, OsMA×2, Gator) + grid/hedge
(`(Oh) Grid Upper lower`, `(GPM) Almost 1 Direction`, `(Boss) Hedging Balance`) + **(NuiIndy) itself**
(already analysed this session = geometric martingale, no entry edge — cross-ref confirms the filter works).

## Decision
- **.Final EA source mining = no clear new candidate.** Concepts saturated; "novel" ones are AI-template
  junk or indicator-grids that (by this session's repeated finding) are escalation-carried, not entry-edge.
- **Marginal paced option (low priority, NOT queued hot):** the 3 indicator-grids with an *uncommon*
  primary — **FrAMA** (Fractal-Adaptive MA), **OsMA** (MACD histogram as primary), **Gator** — are the
  only entries whose signal the lab hasn't explicitly flat-lot-smoked. IF a future idle batch wants a
  cheap probe: flat-lot single-order smoke on their home class first (indicator→trender or ranger), kill
  if entry <1.0 like every other grid this session. Expected low yield.
- **Corpus intake (BOT MOGUL 091B + .Final EA) = effectively exhausted for cheap wins.** Combined with
  symbol-expansion exhaustion, the lab's real EV has shifted OFF corpus-mining → onto (a) integrating
  validated parts (098-C MM-modules into MatchaGrid/Kangaroo/JUMSTOCH chassis) and (b) the user's
  hand-flagged specific EAs, not blind corpus sweeps.

## Artifacts
Query: existing `_triage/FXDREEMA_XRAY.csv` (091A) · scratch script: `scratchpad/finalea_shortlist.py`
