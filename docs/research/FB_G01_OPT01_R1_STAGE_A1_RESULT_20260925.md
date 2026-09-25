# FB-G01 OPT01-R1 Stage A1 - Coarse Spacing Result

Status: **COMPLETE / COARSE_SPACING_REGION_NOT_ESTABLISHED / A2 NOT AUTHORIZED**
Date: 2026-09-25
Lane: `ct-fb-g01-opt01-r1-stage-a1-20260925`

## Identity

- Exact source head used: `f043a8a430d17288be80be5ff084730b89432f83`.
- Accepted FB-G01 source head: `8da04fc789ca55e6c673d41899e9136cfa72a75e`.
- Build receipt: `br-5427f03ea8684ea7a842c0efa6a5ca95`.
- EX5 SHA256: `80f0356b13c522730e746ac97693aea491df55acaee42b61d681943a3cdd2b8a`.
- Home/model: XAUUSD / H1 / MT5 Model1 (1 Minute OHLC).
- MAIN: 2023-01-01..2025-12-31.
- Full input surface: 160/160; each cell is bound by its exact full-surface `.set` SHA256.
- Tester report build: 6182; history quality: 98%; leverage: 1:100.

No runtime effective-config hash marker is present in the preserved per-cell agent segments. This closeout does not invent one. Configuration identity is bound by the exact full-surface set bytes/SHA256 plus source/build receipt and EX5 identity.

## Complete A1 lattice

| Cell | GridPct | ATR mult | PF | Net | Trades | EqDD% | Hard kill | Full window | Qualified |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| GP010_ATR025 | 0.10 | 0.25 | 0.57 | -1653.66 | 41 | 22.09 | 0 | true | false |
| GP010_ATR075 | 0.10 | 0.75 | 0.27 | -2103.43 | 59 | 25.03 | 1 | false | false |
| GP010_ATR125 | 0.10 | 1.25 | 0.59 | -1350.91 | 146 | 25.03 | 1 | false | false |
| GP030_ATR025 | 0.30 | 0.25 | 0.16 | -2298.97 | 30 | 25.08 | 1 | false | false |
| GP030_ATR075 | 0.30 | 0.75 | 0.16 | -2297.49 | 30 | 25.08 | 1 | false | false |
| GP030_ATR125 | 0.30 | 1.25 | 0.37 | -1768.90 | 99 | 25.05 | 1 | false | false |
| GP050_ATR025 | 0.50 | 0.25 | 0.38 | -1712.02 | 98 | 25.05 | 1 | false | false |
| GP050_ATR075 | 0.50 | 0.75 | 0.38 | -1712.02 | 98 | 25.05 | 1 | false | false |
| GP050_ATR125 | 0.50 | 1.25 | 0.37 | -1730.54 | 96 | 25.00 | 1 | false | false |

All **9/9 cells completed**. Every cell has net profit below zero. Exactly one cell (`GP010_ATR025`) traded through the full MAIN window without a hard kill, but its net is -1653.66, so it still fails the preregistered qualification rule. The other eight cells record a shared hard-risk kill and are also net negative.

## Deterministic selector

- Strategy-qualified cells: **0**.
- Admissible adjacent 2x2 blocks: **0**.
- Disposition: **`COARSE_SPACING_REGION_NOT_ESTABLISHED`**.

No single-cell fallback is permitted. `GP010_ATR125` is not selected for having the highest PF in this batch, and `GP010_ATR025` is not selected for being full-window. No range widening or post-result retuning is authorized by OPT01-R1.

## Not run / authority ceiling

- Stage A2: **NOT AUTHORIZED / NOT RUN**.
- BWD: **NOT RUN**.
- HOLDOUT: **UNSPENT**.
- Model4: NOT RUN.
- No Candidate/Grade/KINT, deployment, runtime attachment, trading or performance promotion.
- This Stage-A1 failure stops the **OPT01-R1 coarse geometry path only**. It does not establish a family-wide DEAD/REJECT/PARK conclusion.

## Historical execution record

The initial pre-MT5 harness failure and recovery1 failure remain preserved as historical negative evidence. The authoritative execution is `ct-fb-g01-opt01-r1-stage-a1-run-recovery2-20260925`, which completed with worker exit 0 and postcondition exit 0. No A1 cell is rerun in this closeout.

## Durable evidence

- `factory/runs/fb-g01-opt01-r1-20260925/stage-a1/BATCH_RESULT.json`
- `factory/runs/fb-g01-opt01-r1-20260925/stage-a1/RESULT.json`
- `factory/runs/fb-g01-opt01-r1-20260925/stage-a1/SELECTOR_RESULT.json`
- `factory/runs/fb-g01-opt01-r1-20260925/stage-a1/VALIDATION.json`
- `factory/runs/fb-g01-opt01-r1-20260925/stage-a1/MANIFEST.json`
- `factory/runs/fb-g01-opt01-r1-20260925/stage-a1/cells/` raw reports, sidecars, metrics, logs and graphs
- `factory/runs/fb-g01-opt01-r1-20260925/stage-a1/sets/` exact full-surface cell sets

Next consumer: owner/Control Tower must define a **new prospective research direction** if FB-G01 is to continue. This OPT01-R1 geometry contract stops here.