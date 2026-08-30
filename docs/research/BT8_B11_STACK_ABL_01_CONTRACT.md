# BT8 — B11 GridTrend Stack Ablation Contract

Status: `PREREGISTERED / RESEARCH_ONLY`
Hypothesis: `HYP-B11-STACK-ABL-01`
Canonical base: `e62001c5a0163c5b65790e13010b3e56bd657714`
EA: `B11 / Boss_11_GridTrend`
Runtime: `MT5-lane3 / D:\Meta 5c`, Model 1 only.

## Known accepted evidence — do not rediscover

H02 screening showed no B11 dual-positive pair. The two diagnostic homes selected here are:
- USDJPY/H4: MAIN PF `0.97`, BWD PF `1.05`.
- XAUUSD/H4: MAIN PF `1.02`, BWD PF `0.81`.

Accepted baseline set SHA256: `5a0cdd3186e924234d4491bdf854966553214ebaaf03ca6793beaedd42ea8efa`.
Boss_11 source SHA256: `59c51ad12ecc0450c19bffa373f836a95c0c3fe6808a2029fcc946f28c29f672`.
EX5 SHA256: `2708f46cb31f6c957be360b31e0f2be5678d78280c5bd0f691313d26802c00af`.
Build receipt: `br-0035caa23680498a8f812c18c9df0abc`.

## One logical change

Parent: canonical regression default `StackMode=91` (`STACK_GRID_TREND`).
Child: `StackMode=90` (`STACK_SINGLE`).
No other input may change. Child set SHA256: `39dc0b2b3d1c181e177f7a3919f44393e2661470a3255f5fb368aed46ec704f0`.

This isolates the contribution of B11's add-on grid stack while leaving the MA direction signal, shared filters, lot/risk settings, exits, and market windows unchanged.

## Authorized cells

For each home run parent and child on both windows:
- MAIN: `2023.01.01 .. 2025.12.31`
- BWD: `2020.01.01 .. 2022.12.31`

Homes: `USDJPY/H4`, `XAUUSD/H4`. Exactly `2 homes × 2 variants × 2 windows = 8` Model-1 runs.
Same MT5 install from parent through child. Optimization `NONE`; HOLDOUT remains `UNSPENT`.

## Hypothesis and falsifier

Hypothesis: B11's weak portability is materially caused by the grid-stack layer rather than the MA direction entry alone.

Support requires the single-position child to improve robustness materially across both diagnostic homes, with particular attention to BWD and EqDD. The claim is falsified if removing the grid stack does not improve both homes coherently or simply transfers weakness between MAIN/BWD.

This is mechanism characterization only. A positive result does not authorize parameter search, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, risk/default, Grade, or KINT decisions.

## Mechanical acceptance

- 8/8 authorized reports exist and are fresh.
- Full input-surface and build/config identity PASS on every cell.
- Exact-symbol economics and leverage `1:100` verified.
- No truncated cell; source/build hashes remain reconciled.
- Produce raw compressed reports, parent-child summary, yearly split, mechanical acceptance, graph, artifact hashes, and results report.
- Harness/environment failure is not strategy failure; one bounded repair only.
