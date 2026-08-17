# ExpertMAMA M3 optimize campaign — coarse-grid result: no genuine plateau, M3_FAIL

Candidate: ExpertMAMA · source SHA-256 `9d99ed8320d56651ec8b75c41a07c336b58ac265f04598ad5dd2824bcd670e51`
Binary reused from `[claude] ExpertMAMA M2 intake` (commit `4fded248`), unchanged, fresh at session start.
Lane: `D:\Meta 5` (lane 1) · Symbol GBPUSD · Model 1 · MAIN 2023.01.01–2025.12.31 · complete grid (`-Optimization 1`, per PROJECT_STATE's ≤1000-combo policy) · `-Criterion 7`

Sweep set: `sets/ExpertMAMA_coarse_opt.set` (SHA-256 `0ce639ef42a164449787c4a8844a21022847d32cea467f7194efb6101165a318`)
3 pre-registered levers, 5×5×5 = 125 cells/TF: `Inp_Signal_MA_Period` {8,10,12,14,16}, `Inp_Signal_MA_Shift` {0,3,6,9,12}, `Inp_Trailing_MA_Period` {8,10,12,14,16}. Frozen: both MA methods=SMA, both applied=CLOSE, `Inp_Trailing_MA_Shift`=0 (source default). `optimize_guard.ps1` pre-flight: 3/3 dimensions ALLOW on both runs (EA is unregistered in `docs/PARAM_REGISTRY.csv`, so checks ran warn-only — no REFUSE).

## Coarse results

| TF | cells | trades≥100 | PF≥1.2 | eligible (all 3 gates + net>0) | best plateau support |
|---|---|---|---|---|---|
| GBPUSD M30 | 125 | 39 | 40 | 38 | 5/6 (several cells) |
| GBPUSD H1  | 125 | 14 | 28 | 14 | 2/6 (one cell) |

Full parsed tables: `evidence/M3MAMA_COARSE_GBPUSD_M30_parsed.json`, `evidence/M3MAMA_COARSE_GBPUSD_H1_parsed.json`.

## 🔴 Why this is M3_FAIL, not a locked plateau center

**Symptom 1 — PF values are implausibly high and wildly non-smooth between one-step neighbours.**
Coarse M30 eligible cells range PF 1.21 → 370.94. Picking the highest-"support" cells (by my own
mechanical support-count, which only checks whether a neighbour ALSO clears the eligibility bars)
and reading their actual neighbour PF values:

```
center PF=16.53 trades=160  key=(Period=12, Shift=9, TrailPeriod=12)
    neighbor Period-1:      PF=1.76
    neighbor Period+1:      PF=2.71
    neighbor Shift-1:       PF=1.59
    neighbor Shift+1:       PF=28.23   <- one Shift step: 16.53 -> 28.23
    neighbor TrailPeriod+1: PF=25.27   <- one TrailPeriod step: 16.53 -> 25.27
```
Every "high-support" M30 cell shows the same pattern: PF swinging 5-20x from one grid step to the
next. This is not what `backtest-optimize-rigor`'s plateau-not-spike requirement means by
"meaningful neighbour support" — a genuine plateau has *similar* performance among neighbours, not
merely *also-eligible* neighbours whose actual numbers are chaotic. H1 shows the identical pattern
at smaller scale (support caps at 2/6, PF still swinging 5-16x between adjacent cells).

**Symptom 2 — direct trade-level inspection of the most extreme cell explains the mechanism.**
Reproduced GBPUSD M30 `Signal_MA_Period=8, Signal_MA_Shift=6, Trailing_MA_Period=16` (reported
PF=370.94) as a standalone run (`M3MAMA_PROBE_S8SH6T16_M30.htm`): Gross Profit +300.46, **Gross
Loss only -0.81** across 149 trades, largest loss -0.40, average loss -0.27. Every single "out"
deal in the trade list carries the comment `sl <price>` — every position closes via the trailing
stop, and the trailing stop is so tight (period-16 MA trailing behind a period-8 entry signal, no
grace period before trailing starts) that almost every trade locks in a small profit before any
real adverse excursion can develop. Sample deal: buy-in `1.20486` -> sell-out `1.20655, sl
1.20655` (closed above entry — the trailing stop had already moved into profit). This is not a
coding defect (no invalid stops, no invalid volume, no abnormal termination in the journal for this
run) and it is a real, reproducible mechanism of `CTrailingMA` at these specific lever values — but
it is exactly the **extreme fill-sensitivity profile** that Model 1 (1-minute synthesized OHLC,
not real ticks) is known to potentially misrepresent for a strategy whose entire edge lives in
sub-bar trailing-stop precision. `CLAUDE.md`'s VALIDATE stage explicitly reserves Model-4 for
"fill-sensitive" cases for exactly this reason — and Model 4 is NOT_AUTHORIZED in this task.

**Conclusion.** The coarse grid on both TFs is a scattered field of individually-lucky spikes
riding this tight-trailing-stop mechanic, not a coherent parameter-response surface. Selecting any
"high-support" cell as a plateau center and locking it would repeat this project's own paid-for
lesson (`2026-07-17`: "Model-2 manufactured a fake grid plateau... grid under Model-2 is not
evidence") in a different but structurally identical shape: a grid that LOOKS like it has neighbour
support by a naive eligibility count, but whose actual numbers show no real stability.

Per the task's own gating ("FINE SEARCH: Only if one or more genuine coarse plateau regions
exist"), fine search was NOT run — no genuine coarse plateau region exists on either TF. No set
was locked. BWD validation was not reached (it is gated behind a locked set).

## Diagnostic runs (outside the formal 250-cell coarse budget, ad hoc verification only)

1 standalone probe run (`M3MAMA_PROBE_S8SH6T16_M30`, GBPUSD M30, MAIN, Model 1) reproducing the
most extreme coarse cell for trade-level inspection. Execution validity: PASS (0 invalid stops, 0
invalid volume, 0 abnormal termination).
