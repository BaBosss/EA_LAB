# Concept extract — Auction-Market-Theory / AVWAP / TPO intraday system

**Source:** public Facebook profile of *Apiban Inthanon* ("AV Trader", AVWAP + Market Profile),
pinned index post dated 2026-07-14, plus ~55 public posts read on 2026-08-04.
**Extracted by:** Opus-seat, 2026-08-04. **Status:** CONCEPT ONLY — no evidence, no verdict.
**Spec + build plan:** [AVTPO_SPEC_AND_PLAN.md](AVTPO_SPEC_AND_PLAN.md) (chain_id `EA_AVTPO_20260804_01`).

This file records the *method* (which is not copyrightable) in EA-implementable terms.
Post text is paraphrased, not reproduced.

---

## 0. Lineage the author names himself

Peter Steidlmayer (Market Profile / TPO) · James Dalton (*Mind Over Markets*) ·
Brian Shannon (Anchored VWAP) · Chris Drysdale · Austin Silver · Trader Dale.

So this is **Auction Market Theory (AMT)** with an AVWAP overlay. It is not a proprietary
signal — it is a standard framework, which is good news: every component is public and codeable.

His own stated exam for a student is the whole system in one line:
*"can you say whether today is TREND or ROTATION, how many kinds of ROTATION there are,
and what to do in each."* Everything below serves that one classification.

---

## 1. Toolchain he actually runs

| Tool | What it gives | MT5 equivalent |
|---|---|---|
| **Black Tide Wave** (Peeradet Meecharoen, TradingView) | TPO profile, Initial Balance, VWAP/AVWAP + SD bands, K2 EMA ribbon, DOP gauge — all in one overlay | must be rebuilt; see §5 |
| **Black Tide Wave K2** | EMA-only cut of the same (ribbon + cross signal) | `iMA` — trivial |
| **Arxon MFI+** | MFI length **7**, source **hlc3**; zones Bull >55 / Undecided 45–55 / Bear <45; extremes **90 / 10** (not 80/20, because len=7 tags 80/20 constantly) | `iMFI` + threshold logic |
| **Arxon OBV+** | OBV colored by slope, OBV vs its MA, regular + hidden divergence | `iOBV` + MA + pivot divergence |

### Black Tide Wave components (verbatim from the script's own documentation)

- **TPO / Market Profile** — bracket size default **30 min**; value area default **70 %**;
  outputs **VAH · VAL · POC · Mid · Poor High/Low** (extremes with ≥2 TPOs);
  **single prints** (single-TPO rows) held until filled;
  **naked levels** — untested prior-session VAH/VAL/POC extended forward.
- **Initial Balance** — session-anchored opening range, default **60 min** (= two 30-min brackets);
  **IBR extensions** at L1 = 100 %, L2 = 200 % of IB range; IB midline.
  Per-session IBs available (Asia / London / NY).
- **VWAP** — session-anchored, with **1σ / 2σ / 3σ** bands; independent Week / Month / Year VWAPs;
  session VWAPs for Asia (09:00–15:00 Tokyo), London (08:00–16:30), NY (09:30–16:00).
  Each runs in **VWAP mode** (freezes at session close) or **AVWAP mode** (keeps accumulating).
- **K2 ribbon** — **EMA 8 over EMA 21**, filled; the **8/21 cross confirmed on bar close**
  is described by the author as *the one signal* in the whole indicator (explicitly non-repainting).
  Plus EMA 200 (trend context, with above/below badge) and optional EMA 55.
  Higher-timeframe ribbon + EMA200 can be overlaid.
- **DOP — "Degrees of Power"** — a **−6 … +6** ladder scoring where price sits relative to four
  nested structures: today's IB → today's developing VA → prior-day VA → prior-day range.
  `0` = inside today's IB and around prior value (**balance**);
  `±1…±3` = progressively outside IB and today's VA;
  `±4…±6` = breaking **yesterday's** VA and range (**imbalance**).

> **This DOP ladder is the machine-readable version of the trend-vs-rotation question.**
> It is the single most valuable thing in the whole toolchain for an EA.

The script's author is explicit that it is a **context overlay, not a strategy** — it prescribes
no entries. The entries below are the *trader's*, reconstructed from his trade write-ups.

---

## 2. How he decides ROTATION (mean reversion) vs TREND (follow)

Reconstructed from his own order commentary. All of it reduces to **acceptance vs rejection**.

### Signals that say ROTATION → trade mean reversion

| Observation | AMT reading |
|---|---|
| Developing profile takes a **"D" shape** (fat bell around POC) | value is building, auction is balanced |
| Price leaves IB, runs up to **test VAH, fails, comes back** — repeatedly | rejection at the edge; the excess is being priced |
| **Box (VA) is wide** rather than narrow | he explicitly switches to mean reversion when the box widens |
| An **expansion attempt out of the box is rejected** | big money tried to move price and was refused |
| **POC of two consecutive days overlaps** | value is unchanged ⇒ expect VA to be pulled back |
| Price **rides between session AVWAP and a VA edge** with no follow-through | rotation between references |

His literal decision language: the market "reveals the answer through the TPO" — i.e. he does
not predict the day type, he **waits for the developing profile to declare it**, typically after
the first hour (IB) is complete. *"We are not smarter than the market; we go where it reveals."*

### Signals that say TREND → trade continuation

| Observation | AMT reading |
|---|---|
| **Break of the IB edge** (he opens sell the moment gold loses IB) | imbalance out of the opening range |
| **Break of yesterday's VA** and a run to collect **single prints** left by an earlier day | unfinished auction being repaired |
| Break happens and **volume does not drop off** | initiative participation, not a fade |
| Narrow box + clean expansion | easy to time; his words: the narrower the box, the easier volume is to read |

### The no-trade case (explicit in his posts)

Attempted expansion above IB but the **VA is narrow and volatility is high** and the push is not
institutional → he sits out and waits for volume. This is a real filter, not a mood: **an
expansion without participation is neither a trend nor a fade.**

---

## 3. His actual entry template (reconstructed from trade write-ups)

The same five-step loop appears in every trade he narrates:

1. **Wait for structure to exist.** Let the session build its IB (60 min). Nothing before that.
2. **Pick the reference level** the auction is currently negotiating: VAH / VAL / IB high / IB low /
   prior-day VAH-VAL-POC / naked level / session AVWAP.
3. **Wait for the level to be tested and to fail** (rotation) *or* **to be accepted through**
   (trend). He praises students specifically for waiting through *multiple* failed VAH tests
   before entering.
4. **Trigger on the K2 (EMA 8/21) cross, confirmed on bar close**, in the direction the level
   just implied. In one gold trade the level test came ~07:00 and he took the cross that
   confirmed on the 07:20 candle.
5. **Exit at the next structural reference**, not at a fixed R: NY AVWAP near prior-day POC ·
   the opposite IB edge · the next naked level / single print · far target = the weekly VWAP.

**OBV/MFI are used as a veto, not as a trigger.** In one write-up he was stopped at breakeven,
checked OBV/MFI, saw they had not yet crossed, and *waited for buy momentum to drop* before
re-entering the same idea.

**Management ritual** (repeated constantly): enter in **two clips**, move to **breakeven early**
("move to BE and go to sleep"), take a partial at the first structure, let the rest run to the
far reference. If a level breaks against him he does not flip immediately — he **waits for the
retest** and re-enters there.

**Risk/session discipline:** 1–3 % risk per trade, ~5 % periodic target; **1–2 orders per symbol
per session**; gold traded per session (Asia / London / NY), BTC 1–2 orders/day, EUR 1.
Money-management rituals (withdraw the day's profit, restart tomorrow from a small base) are
personal cash-flow policy — **out of scope for an EA.**

---

## 4. What is mechanizable, what is not

### Mechanizable (deterministic, testable)
- Session windows, IB high/low/mid, IBR extensions L1/L2
- TPO profile → VAH / VAL / POC / value-area %, poor highs/lows, single prints
- Prior-day VA + naked (untested) levels, with a "tagged/untagged" state machine
- Session AVWAP (Asia/London/NY) + daily/weekly VWAP + σ bands
- EMA 8/21 cross, close-confirmed; EMA 55/200 context
- MFI(7, hlc3) zone state; OBV slope + OBV-vs-MA state
- **DOP −6…+6** as a pure function of the four nested structures ⇒ **regime classifier**

### NOT mechanizable — must be dropped or replaced
- Reading retail-vs-institutional participation by eye, footprint/bookmap, order blocks
- "Is he parking the chart here?" (his term for time-based acceptance) — replaceable by an
  explicit *acceptance* rule (N closes beyond a level within M bars), but it is a **substitution,
  not a transcription**
- AB=CD / harmonic counts he posts occasionally — different framework, not part of this system
- News judgement and his own discretionary stand-asides

### Two structural cautions before anyone codes this
1. **Volume.** MT5 FX/CFD gives **tick volume**, not traded volume. VWAP, OBV and MFI built on it
   measure *trade count*, not size. **TPO is time-based and therefore immune** — which is a strong
   argument for building the profile as true TPO rather than as a volume profile in MT5.
   Any volume-profile variant must declare that it is running on tick volume.
2. **Session boundaries are a silent-poison parameter.** Every level in this system (IB, VA, session
   AVWAP) is defined by a session clock. A wrong broker GMT offset shifts *every* level while the
   backtest still looks plausible — same failure class as memory `absolute-price-constant-poisons-backtests`.
   The offset must be an explicit input, pinned in the `.set`, and asserted at init.

---

## 5. Proposed EA shape — `AVTPO` (not built, not approved)

### Module A — regime classifier (must exist before any entry logic)
A DOP-equivalent score, evaluated at IB completion and refreshed per bar:

```
inside_IB                                  → balance
developing VA width vs 20-day median       → narrow = balance
today VA ∩ prior-day VA overlap %          → >60% = balance
|today POC − prior-day POC| in ATR units   → small = balance
IB range / ATR(20,D1)                      → small IB = rotation-prone, large IB = trend day
price beyond prior-day VA / prior-day range→ imbalance (DOP ±4…±6)

MODE = ROTATION  if score ≥ +T
       TREND     if score ≤ −T
       NO-TRADE  otherwise      ← the third state is mandatory, not optional
```

### Module B — ROTATION entries
- Arm when price tags VAH/IBH (or the +1σ AVWAP band) and **fails to accept**:
  ≤ K closes beyond the level inside M bars.
- Trigger: K2 cross back down, close-confirmed. Mirror for the low side.
- Veto: MFI on the wrong side of 50, or OBV slope agreeing with the breakout.
- SL beyond the level + buffer (or beyond IBR L1). TP1 = POC or session AVWAP; TP2 = opposite VA edge.
- BE after TP1.

### Module C — TREND entries
- Arm on **acceptance** beyond IB edge or prior-day VA edge: ≥ K closes beyond within M bars,
  **and** OBV slope agreeing, **and** MFI on the same side of 50.
- Trigger: entry on the **retest** of the broken level, K2 aligned.
- SL back inside the level. TP1 = next naked level / single-print zone; TP2 = IBR L1 → L2.

### Module D — hard cage (repo doctrine)
Session-window only + flat at session end · max 1–2 trades per symbol per session ·
fixed % risk, no averaging, no martingale · one SL per position, always.

### Test plan (must follow the VERDICT GATE, not this file)
- Right home: **XAUUSD M5/M15** (his primary), **BTCUSD M30**, EURUSD as the reversion control.
- MAIN 2023.01–2025.12 · BWD 2020–2022 · holdout 2026H1.
- **Model-4 is mandatory here, not optional.** Every entry in this system fires at an exact
  structural level (VAH, IB edge, AVWAP). That is precisely the tight-level fill-fiction class —
  a Model-2 pass would be worth nothing.
- Every filter in Modules B/C must report **how many times it fired**, with a base control run.
  A filter that never fires is `UNTESTED`, not "passed".

### Honest expectation
The author's edge is heavily discretionary and session-timed, and the toolchain's own author
states the indicator is context, not a strategy. The mechanical version will almost certainly be
weaker than his manual results. The realistic goal is a **BUILD-ON**: find out whether the
*regime classifier* (Module A) adds value as an overlay on EAs we already have, before spending
effort on the full entry stack.

---

## 6. The one idea worth stealing even if the EA is never built

**A day-type classifier that outputs three states — ROTATION / TREND / NO-TRADE — from
IB + value-area geometry alone.** It is cheap, deterministic, has no volume dependency if built
as TPO, and it is exactly the gate that several EAs in this repo lack: they trade one behaviour
in every regime. Testing Module A alone as a filter on an existing champion is a smaller, faster,
and more falsifiable experiment than building `AVTPO` end-to-end.

Related: memory `regime-gate-grids-not-breakouts` (a regime gate helped grids, not breakouts) —
which predicts *which* of our EAs this should be tried on first.
