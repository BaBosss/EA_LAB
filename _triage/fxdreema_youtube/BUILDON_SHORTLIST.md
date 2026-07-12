# fxDreema YouTube corpus — Phase-3 concept catalog + build-on shortlist

Built 2026-07-12 from 320 transcripts → 272 strategy cards (`CATALOG.jsonl` / `DIGEST.txt`) + 46 admin.
**Extraction re-run with Sonnet (2026-07-12, user directive "จบจริงๆ")** superseding the first haiku pass:
318 cards, 0 malformed JSON, EX178 verified vs hand-anchor + richer. Family split held (ict-smc-zone 24→27,
misc 20→6 = cleaner classification); shortlist below unchanged and now backed by uniform Sonnet-grade cards.
Old haiku catalog kept at `CATALOG_haiku.jsonl.bak`.
Cross-referenced vs `EDGE_CATALOG.md` + memory `signal-landscape`. **This is a discussion starter, not a verdict**
(corpus-intake rule: user has hands-on knowledge these files lack). All "PF/backtest %" in cards are the
narrator's own claims — unverified, treated as guilty until a flat-lot probe + funnel proves otherwise.

## The one structural fact that frames everything
Nearly every fxDreema EA is the SAME chassis: **entry signal → linear-add/martingale grid → trailing-stop →
usually NO SL → close on cumulative $ target.** This is the ST03 family, which our lab already proved
**STRUCTURAL-DEAD when the entry has no standalone edge** (profit = uncapped escalation; flat-lot probe PF 0.4–0.68).
BUT the same lab proved the twin case **Gold/Silver Kangaroo (also fxDreema)** has REAL edge — flat-lot PF 5.71 —
because its *bidirectional-grid + overlap pair-close DD-release* carries the edge, not the escalation.

**⇒ The differentiator for EVERY card below = does the ENTRY survive the flat-lot probe (escalation OFF, PF>1)?**
That one run is mandatory before trusting any of them. We do NOT reject them first (user doctrine) — we mine the
entry signal + the MM part, and bolt the good ones onto a *validated* chassis (MatchaGrid bounded+SL / Kangaroo
DD-release / JUMSTOCH capped-SL'd reversion grid).

---

## A. NOVEL entry signals NOT in our landscape (NEVER-TOUCHED) — highest value

| # | Class | Cards | Why new / why it fits thesis |
|---|-------|-------|------------------------------|
| A1 | **FVG / ICT zone fill** | EX009, EX196–199, EX083, EX180, EX186, EX144 (24 total) | Landscape only has this as PARKED-CONCEPT (FB reel, no numbers). fxDreema gives a concrete algo: FVG = low(ID1)>high(ID3), enter when close(ID0) fills the gap + engulfing confirm. = **reversion-entry-at-zone** — matches core thesis (zone touch = reversion trigger). Several already have SL + fixed lot (EX009: SL20/TP15). |
| A2 | **MACD divergence** (NOT naked cross) | EX010, EX059, EX113, EX154, EX195, EX120 | Naked MACD-cross is dead in landscape, but *divergence* (price LL / MACD HL) is a different, untested reversion signal. EX120 adds volume confirm + low-frequency (1:3–1:5 RR). Distinct from everything we've smoked. |
| A3 | **Self-expiring zone** | EX066, EX170, EX186 | "buy zone valid for N bars / 80 pips then voids" — self-invalidating entry window, reduces stale-signal risk. Novel entry+timing hybrid. |
| A4 | **Velocity / Time-Bomb impulse** | EX132, EX200, EX085, EX043 | entry on price moving X pips in Y seconds (native FX-DMA block). A *leading* microstructure trigger — the class of signal landscape says is the only untested angle for tail control. |

## B. Reusable MM / exit parts — bolt onto a validated chassis (this IS the user's "cap + linear/log" doctrine, pre-built)

| # | Part | Cards | What it gives |
|---|------|-------|---------------|
| B1 | **Dynamic close_money** | EX183, EX078, EX077, EX143, EX154 | profit target scales with open-order count: `close = base + (orders/C)·base`. Fixes "big stack needs bigger target". Extractor-flagged key innovation. Reusable on ANY grid. |
| B2 | **Capped-hedge-on-DD** | EX127 family, EX169 (hedge at 10 orders), EX138 | grid → flip to opposite hedge when DD>X% → close-all on combined profit. This is the **MatchaGrid "bounded+SL" ∩ Kangaroo "overlap pair-close DD-release"** — our proven survival structure, ready-made. |
| B3 | **Bounded lot-sequence (linear/log, NOT doubling)** | EX191 (Fib 2,3,5,8,13), EX211 (custom + SL30/TP50), EX054, EX165 | exactly the "linear/log + cap" the user asked for. EX211 is already bounded + SL'd. Drop-in replacement for any martingale ×2. |
| B4 | **Equity-zone lot sizing** | EX053 | lot by equity band (>90%→0.1, 80-90%→0.2…) — risk-responsive de-escalation. |
| B5 | **Rebalance / overlap pair-close** | EX175, EX091, EX116, EX138 | the Kangaroo DD-release mechanism (edge CONFIRMED in landscape). fxDreema variants to study. |
| B6 | **Time-Bomb velocity cut-loss** | EX130, EX142, EX132 | exit when price drops X pips in Y sec = fast leading whipsaw stop (landscape wants leading exits; ATR/ADX lag). |

## C. Skip-building the naked signal (landscape already closed) — but the grid/MM parts above are still mineable
Naked EMA-cross grids (EX001/020/035/072/074/101…), naked breakout/zigzag (EX087/108/125/152…), naked RSI<30
oversold (EX048/050/086/…), naked MACD-cross. These entries are the ST03 trap — do NOT build the signal itself;
only harvest their B-parts. **~47 cards carry `uncapped_grid`/`uncapped_martingale`** = the escalation-illusion set.

---

## Recommended first moves (cheapest verifiable → up)
1. **A1 FVG-zone entry** is the strongest genuinely-new angle. Cheapest test: build ONE clean FVG-fill entry
   (EX009 algo) on the **JUMSTOCH capped-SL'd reversion chassis** (already our build-on vehicle), flat-lot,
   smoke on EURUSD/XAU H1+H4. If the entry has edge naked, THEN add B1 dynamic-close + B3 bounded-lot.
2. **B1 + B3 as a chassis upgrade** — retrofit dynamic close_money + Fibonacci-capped lot onto MatchaGrid /
   the Kangaroo build (KANGAROO_LOGIC_NOTES) regardless of entry — pure risk-mechanics improvement.
3. **A2 MACD-divergence** as a second new entry to smoke (reversion class, untested).

## Open question for user (needs your hands-on knowledge)
Which of these did you actually watch / test by hand? Several cards claim big backtests (EX050 "600%/5yr",
EX078 "2800%/4yr XAU", EX072 "5yr plateau") — narrator claims, but you may know which held up live vs which
blew the account. Point me at the ones your experience says are real and I'll funnel those first.
