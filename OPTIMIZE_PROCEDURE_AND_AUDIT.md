# Optimization Procedure + Honest Self-Audit (2026-07-08)

User challenge (fair, after I made 2 premature "dead" calls on RSI-MR): *is my earlier optimize
work actually rigorous? Any EA killed for nothing (ตายเปล่า)? Show the procedure — coarse→fine?
relevant params or irrelevant ones?* This document answers all three, honestly.

---

## PART 1 — The procedure I'm SUPPOSED to follow (backtest-optimize-rigor skill, Phase D-F)

1. **Scale params to the instrument FIRST.** 250 points = 0.7% on XAU vs 31% on EURUSD. A distance/TP
   that's sane on one symbol is nonsense on another. Never sweep before scaling.
2. **Identify the RELEVANT levers only.** For a grid/MR EA the levers that move the P&L surface are:
   **grid spacing, lot law, SL width, TP target, entry threshold.** Cosmetic/logging/magic/deviation
   are IRRELEVANT — sweeping them wastes runs. (Relevance = does it change entry/exit/size/risk.)
3. **COARSE grid first** — wide range, few points per axis (e.g. ATR 0.5→10 in 6 steps), on ONE
   window. Goal is to find the *zone*, not the winner.
4. **Read the SURFACE, never grab top PF.** A plateau (neighbours also good, high mean AND high
   min-neighbour) = real. An isolated spike with a losing neighbour = overfit/luck. Watch trade count
   (did PF rise only by collapsing to a few trades?) and DD across the whole zone.
5. **ZONE → FINE** grid around the plateau; pick the **plateau CENTRE**, not the peak edge.
6. **Test candidates on BOTH regimes at once** (trend years + recent), not one then the other — the
   best lever for one window often inverts on the other.
7. **Forward-validate on a TRUE holdout** — a window never used for selection. In-sample plateau ≠
   validated; the centre you picked is selection-fitted until it clears untouched data.
8. **Monte Carlo** for robustness; **name the missing regime** it never saw.

## PART 2 — Did I follow it? (RSI-MR, this session — graded honestly)

| Step | Did I? | Grade |
|---|---|---|
| Scale to instrument | ATR spacing self-scales; TP in $ | ✅ |
| Relevant levers | tuned lot-law + ATR + SL + symbol (all relevant); did NOT waste runs on cosmetic | ✅ |
| Coarse first | ❌ at first I tested ONE lot setting (flat LOG) and called it dead | ❌→fixed |
| Read surface not peak | ❌ then ✅ — initially concluded from 2 points; after user push, swept ATR 0.5-10 and READ the surface (found holes at ATR 4,7; plateau at 8-10) | ❌→✅ |
| Both regimes at once | ❌ first BWD-only conclusion; ✅ after — every later sweep ran BOTH windows | ❌→✅ |
| Holdout | ⏳ NOT done yet (2023-24 reserved, pending) | pending |
| Monte Carlo | ⏳ pending | pending |

**Verdict on my own RSI-MR work:** the FIRST pass violated steps 3, 4, 6 — I concluded "dead" from a
partial, non-coarse, single-window test. That was the error you caught (twice). The CORRECTED pass
(lot-law sweep + full ATR 0.5-10 surface, both regimes, plateau-centre) follows the procedure. The
verdict flipped from "dead" to "ACTIVE-VALIDATION" precisely because the procedure, done properly,
disagreed with my shortcut. Lesson now baked into the skills so the shortcut can't recur.

## PART 3 — Were earlier EAs killed for nothing? (ORDER-036/046/047 re-audit)

Honest answer: **it depends on WHY each was rejected. Two rejection classes:**

**Class A — STRUCTURAL rejects (tuning cannot save these — sound kills):**
- Uncapped martingale / lot-escalation ≥10x (most of 036 batches 10-19). A martingale's fat tail is
  in the *mechanism*, not the parameters — no coarse→fine sweep removes a ×100 lot ladder's ruin
  risk. Proven empirically in ORDER-046: FZ2 with its multiplier ZEROED → PF 3.05 collapsed to 0.36.
  The edge WAS the martingale; there's nothing under it to optimize. ✅ sound.
- Backward-OOS blowup DD 96-99% (SEMIS.jr, DanceT, Dark Mimas, etc.) — the mechanism ruins the
  account in the trend years regardless of tuning. ✅ sound.
- Cracked/`_fix` binaries — legal DQ, not a performance call. ✅ sound.

**Class B — the LEGITIMATE limitation you're pointing at:**
- The ORDER-036/047 pool were **COMPILED black boxes (no source).** I could test them at their
  compiled defaults / a given .set, but I could NOT run a real coarse→fine parameter optimization
  (no source, and I mostly didn't have their .set files or input ranges). So for a compiled EA my
  reject means **"fails as-configured,"** NOT "no parameter set could ever save it." For the martingale
  ones that distinction is moot (Class A). For a *borderline non-martingale* compiled EA it is a real
  blind spot — I cannot rule out a better .set existed.
- **This is exactly why ORDER-046 exists:** I applied the "don't kill before trying a structural
  change" rule to the dead pool and swb@AUDCAD came back to life (PARKED-marginal → demo candidate #3).
  So the process self-corrects — but ORDER-046 only probed 4 EAs, not the whole reject pile.

**Where I could genuinely have been premature (flagged for re-exam if you want):**
- EAs rejected on a SINGLE window or a SINGLE metric without a cross-window check. The lot-check
  auto-reject (≥10x) is safe (structural). But any rejected purely on "PF<1 on one window" without a
  second window COULD be a bad-parameter or bad-regime artifact — same mistake I made on RSI-MR.
- The RSI-from-pips compiled original was called "EURUSD-specific" from ONE ATR-implicit config (its
  own fixed 30-pip) — I did not (could not, no source) sweep ITS spacing across symbols.

## PART 4 — What I'm doing about it now
1. RSI-MR: finishing the procedure properly (broad symbol×TF coarse scan running → fine on any
   both-regime cell → holdout 2023-24 → MC).
2. Offer: pick any N earlier "REJECT" EAs you doubt and I'll re-audit them against Class A/B — if
   Class B (non-structural, single-window), I re-test with a proper both-regime + .set sweep before
   the reject stands. Martingale/no-source/DD-blowup rejects (Class A) I'll show the evidence but
   won't burn compute re-running (the mechanism is the kill).
