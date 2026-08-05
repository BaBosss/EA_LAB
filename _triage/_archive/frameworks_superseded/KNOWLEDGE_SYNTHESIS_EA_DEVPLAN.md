# Knowledge → EA development plan (candle/price-action precision entries) — draft 2026-07-12

Synthesis of everything gathered this week into ONE buildable direction. **Draft for the "plan in one session"
discussion — not locked.** Follows lab doctrine (VERDICT GATE, edge thesis, build-on, flat-lot probe).

## Sources assembled
1. **Bulkowski "Encyclopedia of Candlesticks"** (D:\Forex\50_KNOWLEDGE\05_Notes\candle 1-4.jpg) — candle patterns
   ranked by **measured %-accuracy + frequency rank + performance rank**, split Reversal/Continuation × Bull/Bear.
2. **fxDreema catalog** (272 EAs, `_triage/fxdreema_youtube/`) — winning FORM: candle/indicator entry → bounded grid → dynamic exit + MM parts (dynamic close_money, Fibonacci-lot).
3. **cway** — rigorous position sizing (Kelly/Optimal-f/Fixed-Fractional), tail-risk, macro-regime.
4. **abl_research** — market-filter/breadth **regime gate**, HHV breakout.
5. **secretmindset** — a few concrete combos (RSI+VWAP, pivot) — cherry-pick later.
6. **200-AI-Prompt PDF** — already triaged → `STRATEGY_200_ANALYSIS.md`.
7. **Lab validated chassis/edge**: momentum→trenders (XAU) / reversion→FX-majors; ST03 harvester, MatchaGrid
   (bounded+SL grid), Kangaroo (DD-release), JUMSTOCH (LWMA+Stoch reversion). EDGE_CATALOG + signal-landscape.

## The core design decision (recommended, with rationale)
**Candle patterns = PRECISION CONFIRMATION FILTER on an existing edge — NOT a naked entry.**
- Why: landscape proved naked patterns/indicators are weak (~PF 1.1 ceiling); patterns add edge as *confirmation*
  on a directional/reversion thesis (ST03, JUMSTOCH, XAU-momentum all work this way). Bulkowski's ~80% is
  stock/discretionary follow-through, not an FX-EA edge on its own.
- So: pick the **tradeable** Bulkowski patterns (high % AND freq-rank A/B — rare high-% patterns like "Three Stars
  in the South" 86%/freq-D are too rare to build on) and use them to *sharpen the entry timing* of a proven edge.

### Tradeable Bulkowski shortlist (high %-accuracy ∩ frequent enough)
| Pattern | Acts as | ~%acc | Freq rank | Use |
|---|---|---|---|---|
| **Engulfing (Bull/Bear)** | reversal | 79–82% | **A** | primary confirm — this is fxDreema's workhorse; Bulkowski validates it |
| **Three Outside Up/Down** | reversal | 74–75% | **A** | engulfing + confirmation candle (stricter engulfing) |
| **Belt Hold, Bullish** | reversal | 71% | **A** | single-bar reversal confirm |
| **Last Engulfing Top/Bottom** | reversal | 65–68% | **A** | exhaustion reversal |
| Three White Soldiers / Black Crows | reversal | 78–84% | C | strong-but-rarer momentum-start confirm |
| Morning/Evening (Doji) Star | reversal | 71–78% | C–D | high-quality but rarer — optional |
**⚠️ Bulkowski gotcha:** measured "actual" direction often INVERTS the theoretical (e.g. Three-Line-Strike-Bearish
acts bullish-reversal 84%). Use the *actual* column, and re-measure on OUR instruments (his data = stocks).

## Proposed architecture — 4 stackable layers (each independently testable)
```
[Regime gate]  →  [Edge trigger]  →  [Candle-precision confirm]  →  [Chassis + sizing]
 abl/cway macro     RSI/zone/            Bulkowski freq-A            MatchaGrid bounded+SL
 or market-filter   MA-displacement      engulfing family           or Kangaroo DD-release
                                                                     + Fixed-Fractional/Optimal-f (cway)
```
- **Regime gate** (abl/cway): only trade when regime matches the edge (trend-up for momentum, range for reversion).
  This is EDGE_CATALOG's #1 open gap (leading regime signal for tail control).
- **Edge trigger**: the directional/reversion thesis (e.g. reversion-to-MA like JUMSTOCH, or XAU momentum).
- **Candle confirm**: Bulkowski freq-A engulfing family → fire only when the pattern confirms → fewer, higher-quality entries.
- **Chassis + sizing**: validated bounded+SL grid or DD-release; replace martingale with Fixed-Fractional/Optimal-f.

## Phased roadmap (cheapest verifiable first — VERDICT GATE applies at every gate)
- **Phase 0 — candle-confirm as a bolt-on (cheapest, highest-leverage).** Take an EXISTING validated/candidate EA
  (JUMSTOCH reversion, or the FVG-fill from ORDER-098-A) and add a Bulkowski-engulfing confirm gate on entry.
  A/B: does the candle filter lift PF / cut DD (fewer-but-better entries)? Flat-lot. 2 symbols × 2 TF.
  → Answers "does candle precision actually help?" before building anything new.
- **Phase 1 — regime gate probe.** Add abl-style market-filter (e.g. price vs SMA200 regime, or ATR/vol regime)
  to the best Phase-0 cell. Measures the tail-control angle EDGE_CATALOG flagged untested.
- **Phase 2 — sizing upgrade.** Swap crude lot-law for Fixed-Fractional then Optimal-f (cway) on the survivor.
  Compare risk-adjusted (MC PF-5th, DD-95th), not raw PF.
- **Phase 3 — new-build only if Phase 0-2 prove the stack.** Assemble a clean EA: regime → reversion trigger →
  engulfing confirm → bounded+SL grid → fixed-fractional. Full funnel (smoke → IS/OOS → MC → both-regime).

## PriceAction MODULE spec (user design 2026-07-12) — the concrete shape of the "candle confirm" layer
A reusable template include (fits Boss V2 "แม่พิมพ์เดียว"; a shared part like the MM library, not a one-off EA).
- **Detects the tradeable Bulkowski patterns**, each tagged: direction (bull/bear) · type (reversal/continuation) · **tier (A/B/C/D)**.
- **Config `PA_MinTier`** = quality threshold to allow an entry: `A` = only tier-A patterns (rare, precise) →
  `D` = A+B+C+D (frequent, looser). One dial trades frequency ↔ precision.
- **Entry** = edge trigger + PA-confirm. Example (user): `RSI<40 AND PA-reversal(bull) → open`. Grid re-entry:
  `distance > X pip AND PA-reversal → add`.
- **`PA_LotMult` by tier** = pattern quality scales size: A→×1.5, B→×1.3, C→×1.2, D→×1.1 (tunable). Bounded by
  the template's existing position-cap + hard SL (no runaway).
- **Exit** = independent (any existing exit strategy: trailing / basket-TP / dynamic close_money). PA governs ENTRY only.

### Open design decisions (resolve in the planning session — they change behavior)
1. **Which Bulkowski column defines the tier?** Two exist: *Frequency rank* (how often it appears) vs *Performance-
   over-time rank* (how well the move sustains). Recommend: **tier = Performance rank** (drives both the min-tier gate
   AND the lot-multiplier = "better pattern, bigger size"); keep Frequency as a separate "is it frequent enough to
   bother coding" filter. Note: high-performance patterns are often LOW-frequency (Three Stars 86% = freq-D) — so a
   pure performance-tier `A`-only config may fire very rarely; decide if that's the intent or blend the two.
2. **Which patterns to actually implement?** "All" = ~100 Bulkowski patterns, most rare/multi-bar and not worth
   MQL5 detection cost. Recommend shipping **~10-15 tradeable ones** (engulfing family freq-A + soldiers/crows +
   stars) as A/B/C/D buckets; the `D` set = those 10-15, not literally all 100.
3. **Bulkowski tiers = STOCK data.** Ship them as *defaults*, but the module must allow a per-instrument tier
   override — re-measure A/B/C/D on XAU/FX before trusting (his % won't hold identically). This is a validation step.
4. **Direction must match thesis** (module tags enable this): reversal-bull confirm → reversion-long context;
   momentum-start (soldiers) → trender. The EA wires which tags it accepts.

## Guardrails (do not skip)
- Every entry gets the **flat-lot probe FIRST** (escalation off, PF>1?) — separates entry-edge from chassis-illusion.
- Candle % must be **re-measured on our instruments** (Bulkowski = stocks; XAU/FX behave differently).
- Respect edge thesis: reversal-candle confirms belong on **reversion@FX-majors**; momentum-start candles
  (soldiers/crows) on **trenders@XAU**. Don't cross them.
- One new lever at a time (candle → regime → sizing), so we can attribute what worked.

## First concrete order (proposed for the session)
Extend **ORDER-098** family: **ORDER-098-D — Bulkowski-engulfing confirm A/B on JUMSTOCH (or FVG-fill) entry,
flat-lot, EURUSD+XAU × H1/H4.** Acceptance: does engulfing-confirm lift PF or cut DD vs naked entry? Raw table.
