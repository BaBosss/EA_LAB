# fxDreema corpus → ranked build-on shortlist (2026-07-18 pass)

Sharpens `BUILDON_SHORTLIST.md` (2026-07-12) against the *current* EDGE_CATALOG.md state — several
things that shortlist called "highest value" are now closed. This file supersedes it as the reference
for what's still open to hunt. No compute run in this pass — pure catalog mining + doctrine cross-ref.

**⚠️ Correction to BUILDON_SHORTLIST.md's own top pick:** its A1 (FVG/ICT zone fill, EX009 et al.) is
now **DEAD CELL** — `EDGE_CATALOG.md` "DEAD CELL: naked FVG-fill entry @ EUR/XAU H1+H4 (ORDER-098-A,
2026-07-16)": 22 runs, RR sweep, both regimes, PF never >1 across 26 cells. Its A2 (MACD divergence) is
also now **covered** — `MacdDiv XAU H4` shipped/demo-attach-ready (magic 999094), and the EUR H4 variant
specifically taught the holdout-selection-fit lesson (MAIN 1.71/BWD 1.15 looked great, holdout 0.35).
Do not re-open either as "novel." The candidates below are what's left standing after that correction.

---

## 1. Top build-on candidates (ranked)

### #1 — Velocity / "Time-Bomb" impulse entry — MOMENTUM — HIGH prior
**Not covered:** landscape has never tested a *leading* microstructure trigger (price moves X pips in
Y seconds) as a standalone entry — everything else here is lagging-indicator (EMA/MACD/RSI cross).
**Mechanism:** native fxDreema block fires when price moves e.g. 10-100 pips within 5-10 seconds
(EX085: 10p/10s; EX132: 100p/5s; EX200/EX142 pair it with an engulfing/RSI confirm). Exit: fixed SL
(EX085 clean 60p SL, no grid) or ATR-scaled trailing once 2+ legs open.
**Right home:** XAUUSD, any TF with tick-level data (M1/M5) — momentum-on-trender, exactly the
portfolio's strongest prior. EX085 is explicitly flagged in the catalog as "simplest/cleanest card in
batch (fixed lot, real SL)" — cheapest possible smoke.
**Source clips:** EX085, EX132, EX200, EX142, EX043 (session-gated variant).

### #2 — RSI overbought/oversold as CONTINUATION (not naked reversal) — MOMENTUM — MED-HIGH prior
**Not covered:** naked RSI<30 reversal is dead (structural ~1.1 ceiling per EDGE_CATALOG dead pile).
This is the inverse framing — RSI crossing 70/75/80 **with** price above EMA200 = momentum continuation
(the trend is strong enough to sustain overbought), not a reversal signal. Distinct mechanism, distinct
class from the dead entry.
**Mechanism:** EX142: price>EMA200 AND RSI(14) crosses above 70/75/80 → buy (continuation, not fade);
protection = Time-Bomb flash-move cut-loss, not a static SL.
**Right home:** XAUUSD — momentum/trender fit. Session/spread caveat: EX142 tested at spread 16, note it.
**Source clips:** EX142.

### #3 — MACD histogram-momentum (increasing bars, no divergence) — MOMENTUM — MED prior
**Not covered / distinct from shipped:** the shipped MacdDiv edge is *divergence* (price/MACD
disagreement = reversion setup). This is the opposite class: MACD>0 AND histogram bars strictly
increasing (ID1>ID2>ID3>ID4) = trend-strength continuation confirm, paired with an M1 grid overlay.
Also EX112: liquidity-sweep-of-support + pullback-reclaim + MACD(4,9,4)>0 as trend confirm.
**Mechanism:** H1 MACD histogram rising → mode_buy=1 → M1 entries while mode active (EX209); or sweep
+ reclaim + MACD-confirm single-shot entry (EX112).
**Right home:** XAUUSD/GBP H1-H4 (trender). Caution: EX112's "liquidity sweep + pullback" is adjacent
to the SMC-Order-Block territory already flagged as untested-but-related in ORDER-104C — if pursuing,
check for overlap with that lane before opening a second campaign on the same underlying idea.
**Source clips:** EX209, EX112.

### #4 — Multi-EMA stacked/fan alignment + pullback continuation — MOMENTUM — MED prior
**Not covered:** distinct from naked single EMA-cross (dead). Requires 3+ EMAs in strict order
(EX162: EMA100 rising, EMA45>EMA100, EMA8>EMA45, then EMA3 crosses EMA8) — a fan/alignment filter is a
stronger trend-confirmation gate than a single cross, and matches EDGE_CATALOG's own open idea-seed
("multi-EMA stacked entry filter", listed in the QuantCorner catalog as untested).
**Mechanism:** EMA fan alignment (ascending order, all trending same direction) → wait for fast-EMA
pullback-cross as the trigger, not the initial fan formation itself. EX129/EX150 are simpler 2-3 EMA
pullback-continuation variants on XAU.
**Right home:** XAUUSD H1/H4.
**Source clips:** EX162, EX129, EX150.

### #5 — Bullish/bearish RSI divergence + EMA100 regime filter + ATR trailing — REVERSION — MED prior
**Not covered:** different from both the dead naked-RSI-oversold AND the shipped MACD-divergence —
this is RSI (not MACD) divergence, gated by an EMA100 trend filter (only take divergence signals
aligned with the higher-TF bias), with an ATR-scaled trailing exit (not fixed TP).
**Mechanism:** EX190: price above EMA100 + bullish RSI divergence (price new low, RSI higher low) +
confirming bullish candle → buy; ATR-scaled trailing stop once 2+ legs. EX081 adds a ZigZag-based
regime-selection layer on top.
**Right home:** EURUSD/EURGBP — reversion-class, needs the ranger home per doctrine (test on the
trender too as a control, expect it to fail there per prior).
**Source clips:** EX190, EX081.

### #6 — Awesome Oscillator momentum-exhaustion + reversal shape — REVERSION — MED prior
**Not covered:** no AO-based signal anywhere in the landscape; distinct indicator family from
RSI/STO/MACD (all previously tested here in some form).
**Mechanism:** EX061: bullish candle + AO forms a 3-bar momentum-exhaustion-then-reversal shape
(ID1>ID2, ID3>ID2, ID4>ID3 — a saucer/twin-peak pattern) → buy. Basket close at small floating profit.
**Right home:** EURUSD (ranger) — reversal-at-exhaustion is a reversion mechanism.
**Source clips:** EX061.

### #7 — Williams %R exit-from-extreme + EMA200 trend filter (continuation, not fade) — MOMENTUM — MED prior
**Not covered:** distinct from the RSI-continuation candidate (#2) — different oscillator, and the
mechanism is "exiting the extreme zone" (WPR crosses back above -80) rather than "entering the extreme."
**Mechanism:** EX070/EX193/EX194: price>EMA200 (trend filter) + WPR(14) crosses above -80 (exiting
oversold, i.e. pullback resuming) → buy, ATR-scaled trailing exit after 2+ legs. EX070's author reports
5yr in-sample EURUSD H1 +471% (narrator claim, unverified — treat as noise not signal).
**Right home:** XAUUSD or GBPUSD H1 — pullback-in-trend is momentum-class despite the oscillator.
**Source clips:** EX070, EX193, EX194.

### #8 — ROC (rate-of-change) trend confirm on EMA cross — MOMENTUM — LOW-MED prior
**Not covered:** ROC has not appeared elsewhere in the landscape; here it's a magnitude-of-move
confirm layered on an EMA cross (filters weak/noisy crosses the way ADX or ER already do elsewhere).
**Mechanism:** EX111: EMA(8) crosses above EMA(18) AND ROC(12)>0 → buy; grid-add 35pip continuation.
Novelty is thin (ROC>0 on an uptrend cross is nearly tautological) — treat as a cheap filter-lever more
than a new entry class; only worth a dedicated smoke if #1-#4 are exhausted.
**Right home:** XAUUSD.
**Source clips:** EX111.

---

## 2. Reusable LEVERS (bolt-on, not full strategies)

- **Self-expiring signal window** — a drawn zone/line is only valid for N bars or a pip-distance
  budget before auto-voiding (EX066, EX170, EX186: buy-zone valid ~80 pips / N bars). Reduces
  stale-signal risk on any zone-touch or line-break entry. Cheap to bolt onto any of the above.
- **Dynamic close_money scaling with basket size** — profit target grows with open-order count
  (`close = base + orders/C · base`, EX183/EX078/EX077/EX143/EX154). Fixes the "big stack needs a
  bigger target" problem on any grid/DCA chassis; complements the already-adopted basket-close-beats
  -per-leg-TP lesson in EDGE_CATALOG.
- **Equity-band lot de-escalation** — lot size drops as equity falls relative to balance in tiers
  (EX053: >90%→0.1, 80-90%→0.2, 70-80%→0.4, <70%→0.8 — note EX053's own direction is backwards,
  it *increases* lot into drawdown; invert it for a genuine risk-responsive sizing lever).
- **Bounded Fibonacci lot sequence (not doubling)** — 2,3,5,8,13,21… step multiplier, finite/wrapping
  (EX054, EX191, EX211) — a ready-made linear/log alternative to martingale ×2, matches the user's
  standing "cap + linear/log" doctrine.
- **Time-Bomb velocity cut-loss** — exit on a fast adverse impulse (X pips in Y seconds) rather than a
  lagging ATR/ADX stop (EX130, EX132, EX142) — a genuinely leading exit signal, useful anywhere a grid
  currently exits on lagging trailing-stop only.
- **Monthly/session profit-lock wrapper** — 12x month-filter blocks + counters that force-close and
  pause once a monthly profit target is hit (EX088) — a portfolio-hygiene lever, not an edge, but
  useful for capping single-EA monthly variance in a live portfolio.
- **News/session time-window filter** — explicit per-weekday two-window enable flags (EX043) —
  reusable session-gating pattern if a candidate above turns out to be session-sensitive (as
  LondonConsoBreakout already showed session-timing can BE the edge, not just a filter).

---

## 3. Explicit dead / redundant — do not re-hunt

| Catalog pattern | Maps to | Status |
|---|---|---|
| FVG/ICT zone-fill naked entry (EX009, EX196-199, EX083, EX180, EX186, EX144, EX055, EX088, EX019, EX140, etc.) | ORDER-098-A DEAD CELL, EDGE_CATALOG | Naked entry closed. Only "FVG-as-confluence-filter on a different entry" remains theoretically open, not re-tested here. |
| MACD bullish/bearish divergence (EX010, EX059, EX113, EX154, EX195, EX120) | MacdDiv XAU H4 shipped (magic 999094); EUR H4 variant = holdout-fail lesson | Covered — don't re-smoke divergence itself; #3 above is the untested *non-divergence* MACD angle. |
| SMC zone + oscillator combos generally (ICT zone + Stoch/RSI confirm, EX197/198) | SMC×STO EURUSD demo (991070) + ORDER-104C SMC/OB probe | Same family already in build-on pipeline; new SMC-flavored cards are redundant unless they isolate a genuinely different confirm indicator not yet tried. |
| Naked EMA-cross grids (EX001, EX020, EX035, EX072, EX074, EX101, ~40 more cards) | EDGE_CATALOG dead pile: "structural ceiling ~1.1" | Confirmed dead entry class — only the grid/MM parts (already in B1-B6) are mineable, never the naked cross. |
| Naked breakout/zigzag/trendline (EX087, EX108, EX125, EX152, EX036, EX024, EX094…) | EDGE_CATALOG SessionBreakout dead pile (ceiling 1.20, forward 0.91) + naked-gold-breakout MC floor 0.85 | Dead as naked entry; already-shipped BRK_XAU/SuperTrend variants supersede these. |
| Naked RSI<30/RSI>70 reversal (candle+RSI variants) | EDGE_CATALOG dead pile ~1.1 ceiling | Dead as reversal entry — #2 above is the surviving *continuation* framing, not this. |
| Bollinger-band touch reversal (EX077, EX067, EX003, EX173, EX175) | Same BB+RSI ~1.1 ceiling family | Dead — untested BB variant offers nothing the dead pile hasn't already closed. |
| Currency-strength meter | User context: "edge too thin" | Already closed, not in this catalog anyway. |
| Pairs-spread stat-arb | PairSpread demo (990984) | Already shipped from the QuantCorner sweep, unrelated corpus but flagged so it's not re-proposed from here either. |

---

## 4. Recommendation to Claude lead

1. **Smoke #1 (velocity/Time-Bomb impulse) first** — it is the only entry class here that is a
   *leading* signal rather than a lagging indicator, matches the momentum>reversion prior, has a
   clean minimal-config source card (EX085: fixed lot, real SL, no grid needed to test the naked
   entry), and nothing adjacent to it has ever been screened in this lab.
2. **Smoke #2 or #7 (RSI-continuation / WPR-continuation) second** — cheapest possible test since both
   reuse the EMA200-trend-filter scaffolding already built for other XAU candidates; either could be a
   quick reject or a quick pulse-check before committing more time.
3. Everything else (#3-#8) is worth keeping in the queue but not worth opening a build campaign on
   until #1 and one of #2/#7 report back — per the pacing-batch-small rule, 1-2 candidates per round.
