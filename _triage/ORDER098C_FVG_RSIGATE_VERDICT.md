# ORDER-098-C — FVG-fill + RSI confluence gate verdict (Opus lead, 2026-07-17)

**Motive:** ORDER-098-A rejected NAKED FVG-fill entry (26 cells, RR/symbol/TF sweep, never PF>1) but
left "FVG-as-confluence" open. fxDreema course FVG files gate FVG with an RSI oversold/overbought
rule ("RSI<30 || RSI>70"). Built `ea_projects/(EXP)_FVGFill_RSIgate/FVGFill_RSIgate.mq5` (fork of the
098-A naked chassis + RSI gate section [03] + `ApplyRsiGate`; A/B toggle `_03_UseRsiGate`). mql-review
PASS (RSI read shift-1 = no look-ahead, fail-closed, handle lifecycle ok, gate-off = naked-identical).
Compiled 0/0 (ex5 36304 bytes).

## Results (Model-1, EURUSD/XAUUSD H1, both-window; CSV `_mt5_auto/order098c_rsigate_ab.csv`)

| gate (RSI buy/sell) | sample | outcome |
|---|---|---|
| 30/70 (course default) | ~0 trades (max 1/cell over 3yr) | FVG-fill + RSI-extreme near-mutually-exclusive on H1/H4 majors — unjudgeable |
| 40/60 | thin (35-47t) | XAU MAIN 1.23 but BWD 0.63 = single-window spike, thin. EURUSD 0.44/0.87. |
| 50/50 (midline filter) | **well-powered (350-370t both windows)** | PF **0.76-0.94 all four cells, never >1.0** |

Naked baseline (098-A, no gate): EURUSD H1 MAIN 0.97 (818t); XAUUSD H1 MAIN 0.83 (942t).

## VERDICT — REJECT: the RSI confluence gate adds no edge to FVG-fill
The well-powered 50/50 midline filter (the only threshold that keeps a judgeable sample) sits at
0.76-0.94 in **both** windows — no lift over the already-sub-1.0 naked baseline. The one PF>1 reading
(XAU 40/60 MAIN 1.23) is a thin 47-trade single-window spike with a decisively negative BWD (0.63) —
not build-on material (same standard the 098-A lead applied). VERDICT GATE satisfied: RSI-threshold
lever swept across 3 values × both-window × the 2 highest-volume cells, stacked on 098-A's RR×symbol×TF
sweep. FVG-fill has no edge naked or RSI-gated on FX/XAU majors H1/H4.

## Scope / what stays open
Closes **FVG-fill as a PRIMARY signal** (naked + RSI-gated). NOT closed: FVG used as a confluence
*filter on some OTHER validated entry* (the reverse direction) — but prior is now low; not a priority.
Course FVG variants (FollowTrend / RichShield / serie Plus) are variations on the same fill geometry
→ no fresh mechanism worth a separate build. **fxDreema FVG lineage = exhausted.**

## Artifacts
- EA: `ea_projects/(EXP)_FVGFill_RSIgate/FVGFill_RSIgate.mq5` (+ .ex5)
- Sets: `_mt5_auto/ab_sets/order098c/rsi_{40_60,50_50}.set`
- Reports: `_mt5_auto/reports/O098C_*.htm` · CSV: `_mt5_auto/order098c_rsigate_ab.csv`
