# ORDER-110 — XAU_NY regime-rescue verdict (Claude, 2026-07-16)

Regime-rescue #2: rebuild the NY-session XAU breakout on the LabCore chassis (Entry 12 Donchian, which
already carries the `_50_` regime gate + a session-hour filter), then test whether the regime gate lifts
it both-window. XAU_NY's own source is lost (compiled-only) so a graft was impossible — a config rebuild
on `Boss_12_Breakout` was the path.

## Rebuild = pure config (no new code)
Explore confirmed LabCore Entry 12 already provides: Donchian range break (`_12_Bars`, `_12_ConfirmBars`),
a GMT session-hour filter (`_12_HourFrom`/`_12_HourTo`), single-position mode (STACK_SINGLE, the Entry-12
default), ATR SL (`SLMode=33`), ATR TP (`ExitMode=22`), and the `_50_` regime gate. So the "rebuild" is a
`.set` on `EALabTpl\Boss_12_Breakout` — no code. Ran on Meta5b (portable) in parallel with Zeus on Meta5.

## Sweep (Model 1, 48 runs — `_mt5_auto/XAUNY_REGIME_AB.csv`)
Coarse: TF{H1,H4} × Bars{8,20,40} × session{NY 13-21 GMT, none} × regime{off, m1t25} × window{MAIN,BWD}.
SL ATR 2.0, TP ATR 3.0 held.

**Both-window-positive cells (MAIN & BWD both PF≥1.0) — all on H4, all with weak BWD:**

| tf/bars/session/regime | MAIN pf | BWD pf | note |
|---|---|---|---|
| H4/20/NY/**roff** | **1.47** | 1.05 | best MAIN — but naked (regime not involved) |
| H4/20/NY/m1t25 | 1.31 | 1.05 | regime **cuts** MAIN, BWD unchanged |
| H4/8/none/m1t25 | 1.27 | 1.06 | |
| H4/8/none/roff | 1.10 | 1.02 | |
| H4/40/NY/m1t25 | 1.40 | 1.00 | BWD exactly breakeven |

Everything on **H1 fails BWD** (BWD 0.80-0.97 across all H1 cells). Confirms the edge is H4-only (matches
the ORDER-084 XAU_NY rescue-#2 "H4" finding).

## Did the regime gate rescue it? — NO (the point of this ORDER)
Per-cell roff→m1t25 BWD deltas: H4/8/none 1.02→1.06, H4/20/none 0.93→0.97, H4/20/NY 1.05→1.05,
H4/40/none 0.84→0.89, H4/40/NY 0.92→1.00. The gate gives a **small, consistent BWD nudge (~+0.04-0.08 PF)
but never a robust lift**, and it trims MAIN (cuts trades). The one strong both-window cell (H4/20/NY)
passes **naked** — the regime gate is not the hero.

## Verdict — 🟡 regime gate does NOT rescue XAU_NY; marginal naked cell noted
1. **Regime-rescue = negative for this EA.** Unlike Zeus (a grid), XAU_NY is a breakout. An ADX-trend gate
   is **redundant with a breakout signal** (a break already implies momentum), so it adds little —
   consistent BWD nudge but no both-window rescue. **Meta-lesson banked: the `_50_` regime gate is an
   orthogonal filter for GRIDS (Zeus rescued, ORDER-057 XAU-grid rescued) but redundant for BREAKOUTS.**
2. **A marginal naked cell exists** — H4/Bars20/NY-session Donchian (1.47/1.05) clears both windows, but:
   (a) it's a **Bars-axis spike** (Bars8 = 1.06/0.95, Bars40 = 1.43/0.92 both fail BWD) — not a plateau;
   (b) BWD 1.05 is barely above breakeven and **Model-1 only** (not real-tick confirmed);
   (c) it is a XAU H4 momentum breakout → almost certainly **highly correlated with existing XAU legs**
   (EA_BREAKOUT_XAU, Boss_14 XAU GridLog, SqueezeBRK) → low marginal portfolio value.
3. **Not dead (BUILD-ON doctrine).** PF>1 both-window on one cell = a build-on lead, not a kill. But it is
   **low priority**: the regime angle failed, and the naked cell is likely redundant. Park as a lead;
   revisit only with a Model-4 + corr check if a XAU breakout slot is ever wanted.

**Next (only if pursued later):** Model-4 on H4/20/NY/roff · corr vs the 3 XAU legs (expect >0.6) ·
SL/TP sweep to see if BWD can be pushed off breakeven. None are priority given (1)+(2c).

**ห้าม:** call it a rescue (regime didn't do it) · deploy talk (marginal, unconfirmed, likely redundant) ·
spend more machine time before the Zeus AUDJPY candidate (a clean win) is finished.
