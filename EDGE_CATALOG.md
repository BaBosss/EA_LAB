# EDGE CATALOG — why each EA makes money (and what that teaches)

Companion to `EA_SCORECARD_AND_REGISTRY.md`. The registry says *whether* an EA is good;
this catalog says *why* it has edge, *when* it fails, and what new ideas the pattern seeds.
Confidence: ✅ = mechanism read from code/spec · 🟨 = hypothesis from type/behaviour (verify before trusting).

Created 2026-06-26.

---

## CORE THESIS OF THIS PORTFOLIO
**Edge predictor = instrument character: momentum vs reversion.**
- **Trenders (XAU/gold)** reward **momentum / breakout** — price continues.
- **FX majors (GBP/EUR/CHF crosses)** reward **short-horizon mean-reversion** — price oscillates back.
- Pick the signal to match the instrument. Mismatch = the dead pile below.

What has NEVER worked here (anti-edges):
- **Naked indicator crossovers** (MACD/BB+RSI) on FX majors → structural ceiling ~PF 1.1.
- **Uncapped martingale / grid** → the "edge" is just deferred losses; remove the doubling and the naked signal is breakeven ("martingale WAS the edge").
- **Tight-TP < spread (Model-2)** → PF is open-price fill fiction; collapses when TP×10.

---

## LIVE / CANDIDATE EAs — edge mechanism

### ST_EA03 MACD — GBPUSD/USDCAD H1 (CORE) · replica = EA_RUNNER_ST03 ✅
**Mechanism:** enter once per MACD-state run (2-bar count) → market leg + LIMIT leg 5pip below
(scale into dip) → **NO stop-loss** → close the whole OCO group when combined P/L hits +5pip →
80-bar time-stop backstop. Tiny lots.
**Why edge:** a **mean-reversion harvester**. FX majors retrace small moves on H1; a 5pip target
hits ~80% of the time. The no-SL + averaging leg is the *engine* — it waits out temporary adverse
excursions until they revert, converting would-be losers into small wins.
**Really it is:** selling mean-reversion insurance — steady 5pip premiums in calm, paid back in a
lump when price trends hard without reverting.
**Failure mode:** every real crisis PF<1 (Brexit/COVID/gilt) — the "steamroller". Negative skew
(MC PF-range 20.5). Regime-dependent (2025H1 weak). Hard SL kills it (realises the temp excursions
before they revert). **Tamed by:** vol-gate (ATR>1.5×ATR_MA(300) → sit out) — Brexit −218→+94.
**Idea seeds:** the vol-gate pattern generalises to ANY no-SL reversion harvester; the same engine
on other liquid rangers (EURUSD) may work once per-symbol tuned + gated.

### MG_v1 MatchaGrid — CHFJPY M15 (CORE) 🟨
**Mechanism (hypothesis):** bounded grid with hard SL on a range-bound cross.
**Why edge:** CHFJPY oscillates in a range; the grid harvests the back-and-forth, the **bounded
steps + SL cap the breakout tail** (this is why it passed deep-val where naked grids DQ).
**Failure mode:** a sustained CHFJPY trend that blows past the grid bounds (SL caps it, not ruin).
**Idea seeds:** "bounded + SL" is the safe way to run a range harvester — the template for taming
any grid/martingale that screened well but DQ'd on uncapped tail.

### NuiIndy RSI+ADX — EURUSD H1 (CORE) 🟨
**Mechanism (hypothesis):** RSI signal gated by ADX (trend-strength filter).
**Why edge:** ADX gate keeps RSI entries out of dead chop / aligns them with a real move — a
*filtered* reversion or pullback-continuation on the most liquid pair.
**Verify:** read the actual entry rule before extending — direction (fade vs follow) unconfirmed.

### Gold Reaper 4.3 — XAUUSD H1 (CORE ⚠️ ruin 1.9%) 🟨
**Why edge:** gold = trender → momentum/continuation edge. Watch flag = thin ruin margin.
**Idea seeds:** XAU is the momentum sandbox; reversion ideas die here (see TrendRegression).

### EA_BREAKOUT_XAU — XAUUSD H1 (CANDIDATE) ✅(type)
**Mechanism:** Donchian channel breakout + ATR-expand filter, BUY-only.
**Why edge:** gold's upward-biased volatility-expansion; breakouts follow through.
**Failure mode:** BUY-only = regime risk if gold reverses secularly; thin OOS (33t).

### LondonConsoBreakout — GBPUSD H1 (CANDIDATE) 🟨
**Why edge:** Asian-session consolidation → **London-open volatility expansion** breaks the range
directionally. Session-timing edge, not indicator edge.
**Failure mode:** GBP concentration; EURUSD variant had no durable edge (dropped).

---

## DEAD PILE — what the failures teach (anti-edges worth remembering)
| Pattern | Tested | Lesson |
|---|---|---|
| Naked MACD crossover | GBP+7 majors/crosses | structural ceiling ~1.1 — crossovers carry no edge on FX |
| BB+RSI naked reversion | EUR/XAU | same ~1.1 ceiling — reversion needs an *engine* (no-SL wait, or bounds), not a bare signal |
| TrendRegression (reversion) | XAU | reversion-on-a-trender = no edge (confirms momentum>reversion for gold) |
| SessionBreakout | XAU | 1,200-pass ceiling 1.20, forward 0.91 — breakout needs a real range to break |
| Grid/martingale (Golden Elephant, BuRengNong, Setka…) | XAU mostly | "martingale WAS the edge" — strip the doubling, signal is breakeven; DD 60–125% |
| Tight-TP (Game Changer/GMGS) | XAU | Model-2 open-price artifact; TP×10 collapses PF |

---

## IDEA SEEDS (for new strategies)
1. **Vol-gated reversion harvester on EURUSD** — ST03 engine + per-symbol TP/Nearby + the 1.5×ATR_MA(300)
   gate. EURUSD is more liquid/mean-reverting than GBPUSD in theory; failed naked, may pass gated.
2. **Bounded range harvester template** — generalise MatchaGrid's "bounded+SL" to other rangers
   (EURGBP, EURCHF) — low-vol crosses that mean-revert.
3. **London-open expansion** — extend LondonConsoBreakout's session edge to other session opens
   (NY, Tokyo) and to XAU (which trends → breakout-friendly).
4. **Momentum-only on trenders** — keep reversion OFF gold; build a clean XAU momentum/continuation
   EA (Gold Reaper-style) rather than fighting it with reversion.
5. **The universal tamer** — the ATR-long-baseline vol-gate cut ST03's worst tail at ~0 calm cost;
   bolt it onto ANY no-SL/grid harvester to convert "ruin tail" into "sit-out".
