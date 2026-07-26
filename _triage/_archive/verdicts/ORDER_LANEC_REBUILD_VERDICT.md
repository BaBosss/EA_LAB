# ORDER-LANEC-REBUILD — SMC×STO SL-plateau rebuild — VERDICT (2026-07-18)

**Goal:** find a config where the SL axis is a true plateau (SL±20% all ≥1.0 both-window) to replace the demo
991070 (SL=3.0, edge-positive but SL−20% cliff). Method = fresh coarse SL×TP grid on MAIN (anti-overfit — not
re-centering on the 07-18 fan) → plateau center → both-window + fan + holdout. 35 Model-4 runs. magic 991071.

## Result = NO SWAP (pre-registered "middle") — keep demo 991070 as-is

### Coarse SL×TP surface (MAIN, PF)
```
SL\TP   0.8   1.0   1.2   1.5
2.0    0.84  0.87  1.01  0.88   ← cliff
2.5    1.07  1.23  1.34  1.26
3.0    1.21  1.39  1.42  1.33   ← peak; SL−20%=2.4 = cliff (the demo's flaw)
3.5    1.19  1.37  1.38  1.28   ← chosen plateau center (away from cliff)
4.0    1.10  1.26  1.27  1.22
```
Plateau center picked = **SL3.5/TP1.2** (not the 1.42 peak) because its ±20% land away from the SL=2.0-2.4 cliff.

### Validation (plateau center + ±20% fan, both-window + holdout)
| config | MAIN | BWD | HOLD |
|---|---|---|---|
| center SL3.5/TP1.2 | 1.38 | 1.02 | **1.09** |
| SL2.8 (−20%) | 1.38 | 1.06 | 1.36 |
| SL4.2 (+20%) | 1.31 | **0.94** | 1.18 |
| TP0.96 (−20%) | 1.35 | 1.05 | **0.94** |
| TP1.44 (+20%) | 1.25 | 1.06 | **0.99** |

### Why no swap (pre-registered bars not cleared)
1. **Holdout 1.09 < 1.2** at center; holdout soft (~0.94–1.18) across the WHOLE plateau → the 2026H1 regime is
   just weak for this EURUSD-H1 reversion edge, not a config problem (can't tune away a regime).
2. **SL still not a clean plateau** — the fragility only MOVED sides: demo cliff was SL−20%; rebuild's is
   SL+20% (4.2 → BWD 0.94). The SL edge on EURUSD H1 is inherently narrow whatever the center.
3. **Rebuild doesn't beat the demo** — demo 991070 BWD=1.19 > rebuild BWD=1.02. No decisive improvement.
   (Cannot select SL2.8 for its strong holdout 1.36 — that would be moving to a sweeter zone after seeing the
   burned holdout window; anti-overfit invariant.)

### Action
- **Keep 991070 on demo unchanged** (SL=3.0, SL-lock≥3.0 flag stays). Demo-forward = the real judge.
- Rebuild sets (magic 991071) NOT deployed. The finding: SMC×STO on EURUSD H1 is a genuinely MARGINAL reversion
  edge — narrow SL, soft in the 2026H1 regime — no config rebuild lifts it to a clean robust pass. It is what it
  is: a WEAK demo candidate whose fate the forward test decides. Further build-on (if pursued later) = try a
  different HOME (TF/symbol) not more EURUSD-H1 SL tuning (the axis is exhausted).
