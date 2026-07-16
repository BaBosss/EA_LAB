# ORDER-107 — SMC×STO Stage-0 skeleton smoke — verdict (Claude, 2026-07-16)

EA `(EXP)_EmaStoRev` (HTF EMA100 gate + Stochastic-cross reversion + STO-reverse exit + BE@50, NO order
block). Cheap-death test of the user's SMC×STO concept per the pre-registered plan. Model 1, MAIN
2023-2026. Raw: `_mt5_auto/order107_emasto_smoke.csv`. Build commit `55c5e149`.

## Result — every cell PF < 1.0 (no pulse)

| symbol | M15 | H1 |
|---|---:|---:|
| EURUSD | 0.70 (1423t, win 62%) | 0.63 (235t, win 58%) |
| GBPUSD | 0.66 (1340t, win 60%) | 0.77 (220t, win 50%) |
| XAUUSD | 0.89 (1052t, win 67%) | 0.89 (180t, win 67%) |

**High win% (58-67%) but PF < 1.0 = the classic mean-reversion trap:** wins are frequent but small
(STO-reverse exit banks quick), losses are fewer but larger (2×ATR SL blown through when a move keeps
going). Net negative on all 6 cells. This is the textbook reason reversion-scalping fails — and matches
the standing portfolio prior (momentum > reversion, confirmed 6+ builds).

## Verdict — DEAD skeleton → SMC×STO concept PARKED for build (per pre-registered Stage-0 rule)
The naked EMA-gated STO-reversion core has no edge on any (symbol, TF) cell. Per the pre-registered plan
and signal-scanner doctrine: **a reversion concept smoking < 1.0 across cells = dead concept, do not
optimize it, and do not build the expensive Stage-1 machinery on hope.** The SMC Order-Block zone (Stage 1)
would only *relocate* the same reversion entries more precisely — a spatial filter cannot turn a
negative-edge core positive.

**Residual uncertainty (honest):** it is *conceivable* that reversions located specifically at fresh order
blocks have edge that random STO-cross reversions lack — that exact hypothesis is untested. But per the
cheap-death principle + the momentum prior, that thin possibility does NOT justify the multi-hour SMC/OB
build. If the user specifically wants the OB-zone hypothesis tested despite the dead skeleton, that is a
deliberate user call, not a default.

**Cheap-death value realized:** 1 EA build + 6 fast Model-1 runs killed a concept that would have taken
many hours to build as the full 3-TF SMC system. Exactly what Stage-0 is for. Concept recorded DEAD in
EDGE_CATALOG so it is not re-hunted.
