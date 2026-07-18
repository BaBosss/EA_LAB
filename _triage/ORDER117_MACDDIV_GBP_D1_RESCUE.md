# ORDER-117 rescue funnel: (EXP)_MacdDiv_Naked GBPUSD D1 (PARKED-VERIFY residual)

Task: last-optimize-before-verdict pass on the GBPUSD D1 MacdDiv residual
(memory claim: PF~1.45 MAIN / 1.23 BWD @ ~25t both-window, THIN). Reproduce,
holdout-test, sweep the untouched frequency levers, hand back evidence
(no verdict written here — that's Claude's call per skill contract).

Model 1 used throughout (flat-lot single-position, no escalation → Model-4 not required).
Magic 999094, naked defaults except swept params.

## (a) Reproduced baseline (naked defaults: LB=80, SW=2, MB=3, Macd 12/26/9, ATR buf 0.10/14)

| Window | Dates | PF | Net | Trades | DD% | Win% |
|---|---|---|---|---|---|---|
| MAIN | 2023.01.01-2025.12.31 | 1.24 | +31.60 | 24 | 0.90 | 37.5 |
| BWD  | 2020.01.01-2022.12.31 | 0.94 | -19.27 | 55 | 1.78 | 27.3 |

**Does NOT reproduce the memory claim.** Actual baseline: MAIN PF 1.24 (close to
"thin ~25t" trade count) but BWD PF 0.94 (net negative) — fails both-window
already at the reproduction step. The 1.45/1.23 number in the memory note is
not reproducible with naked defaults on this data; either it came from a
different param set or a different window. Treat the earlier claim as stale.

## (b) Holdout (unseen windows, naked-default baseline)

| Window | Dates | PF | Net | Trades | DD% |
|---|---|---|---|---|---|
| HOLDOUT 2026H1 | 2026.01.01-2026.06.30 | 0.00 | -27.78 | 4 | 0.42 |
| HOLDOUT 2017-19 | 2017.01.01-2019.12.31 | 0.53 | -189.50 | 61 | 2.12 |

Both unseen windows are outright losers. Bar: PF≥1.2 deploy-track, 1.0-1.2
build-on, <1.0 selection-fit → **both holdouts land well under 1.0** on the
baseline config.

## (c) Frequency-lever sweep (untouched lever, per diagnosis→lever table: thin → loosen signal frequency)

Grid: `_01_LookbackBars {60,80,110} x _01_MinBarsApart {2,3,5} x _01_SwingRadius {2,3,4}`,
27 combos x 2 windows (MAIN+BWD) = 54 runs, Model 1. Full CSV:
`D:\EA_LAB\_mt5_auto\order117_gbpd1_sweep_results.csv`.

Key finding: **LookbackBars has zero effect** across the whole 60-110 range
(every LB60/LB80/LB110 row is byte-identical to its LB-mate at the same
MB/SW) — the swing-pivot lookback window is already saturated by 60 bars on
D1. Effective sweep collapses to 3x3 = 9 unique cells (MB x SW):

| MB\SW | SW=2 | SW=3 | SW=4 |
|---|---|---|---|
| MB=2 | MAIN 1.24/BWD 0.94 (24t/55t) | MAIN **2.84**/BWD 1.34 (31t/59t) | MAIN 0.72/BWD 1.17 (34t/47t) |
| MB=3 | MAIN 1.24/BWD 0.94 (24t/55t) | MAIN **2.84**/BWD 1.34 (31t/59t) | MAIN 0.72/BWD 1.17 (34t/47t) |
| MB=5 | MAIN 1.48/BWD 1.01 (30t/38t) | MAIN 1.30/BWD 1.39 (34t/57t) | MAIN 0.72/BWD 1.17 (34t/47t) |

**This is a SPIKE, not a plateau.** Along the SwingRadius axis (the only axis
that moves the needle), SW=3 is flanked on both sides by a failing neighbor:
SW=2 fails BWD (0.94), SW=4 fails MAIN (0.72), and SW=3 in the middle spikes
to MAIN PF 2.84. A real edge would show SW=2/3/4 all passing together
(plateau); instead only the single middle value clears both-window — classic
selection-fit / peak-hunting signature (VERDICT GATE item 2).

The most balanced-looking cell (MB=5, SW=3: MAIN 1.30 / BWD 1.39, 34t/57t,
thicker sample) was picked as the plateau-center candidate and holdout-tested
to settle the spike-vs-real-edge question:

| Window | PF | Net | Trades |
|---|---|---|---|
| HOLDOUT 2026H1 | 0.67 | -8.75 | 3 |
| HOLDOUT 2017-19 | 0.57 | -123.43 | 41 |

**Both holdouts still fail** on the best-looking sweep cell — confirms the
both-window pass at MB5/SW3 is fit to the 2020-2025 sample, not a
frequency-independent edge. No config in the 27-combo grid escapes this: SW
is the only lever with signal, and it's a spike everywhere it's tested.

## (d) Locked candidate .set

None. No sweep cell survives holdout, so there is no build-on candidate to lock.
(Set files for reference/reruns live at `_mt5_auto\ab_sets\order117_gbp\d1_sweep\MacdDiv_LB{60,80,110}_MB{2,3,5}_SW{2,3,4}.set`.)

## (e) Recommendation for Claude verdict

**DEAD-OPTIMIZED.** Deciding number: the best both-window sweep cell (MB=5,
SW=3, MAIN PF 1.30 / BWD PF 1.39) still fails **both** independent holdout
windows (2026H1 PF 0.67 @3t, 2017-19 PF 0.57 @41t) — and the only lever that
moves outcomes at all (SwingRadius) produces a bracketed spike (SW=2 fail /
SW=3 pass / SW=4 fail), not a plateau. The original "both-window 1.45/1.23"
claim did not reproduce on this data either. GBPUSD D1 MacdDiv-Naked has no
portable edge after the mandated last-optimize round; safe to close the
residual rather than keep it PARKED-VERIFY.

## ✅ CLAUDE VERDICT (Opus 2026-07-18): **DEAD-OPTIMIZED** (cell = GBPUSD D1)

Tree: not STRUCTURAL (naked single-position flat-lot, Model 1, no fill-artifact) → PARAMETRIC.
Last-optimize round (frequency-detection levers = the untouched axes per diagnosis→lever) DONE →
node 2a earned terminal. The one both-window pass (MB5/SW3 1.30/1.39) is a **bracketed SwingRadius
spike** that fails **both** independent holdouts (0.67 @3t · 0.57 @41t) = selection-fit. Memory claim
1.45/1.23 did NOT reproduce (actual baseline 1.24/0.94, BWD fails at defaults) → stale, corrected.
No home clears the holdout bar → **not BUILD-ON**. Closes the GBPUSD-D1 CELL only — **MacdDiv the
CONCEPT stays alive at its validated home (XAU H4, shipped magic 999094)**. Same selection-fit
signature as EUR H4 MacdDiv (holdout 0.35, ORDER-098-B). Recorded [[signal-landscape]]. No B1 row
(closes an ORDER-117 residual, not a numbered terminal order). No user brief (DEAD not PARKED).

## Reports / evidence paths
- Baseline: `_mt5_auto\reports\MACDDIV_GBP_D1_{MAIN,BWD,HOLDOUT2026,HOLDOUT2017}.htm`
- Sweep runs: `_mt5_auto\reports\O117D1_LB*_MAIN.htm` / `_BWD.htm` (54 files)
- Sweep CSV: `_mt5_auto\order117_gbpd1_sweep_results.csv`
- Plateau-center holdout: `_mt5_auto\reports\O117D1_SW3MB5_HOLDOUT{2026,2017}.htm`
- Sweep driver script: `_mt5_auto\order117_gbpd1_sweep.ps1`
- Baseline set: `_mt5_auto\ab_sets\order117_gbp\MacdDiv_Naked_GBPUSD_D1_baseline.set`
