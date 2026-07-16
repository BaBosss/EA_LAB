# EA death taxonomy + improvement map (Claude + user review, 2026-07-16)

Data source: `_triage/RETRO_AUDIT_VERDICTS.csv` (107 dead-pile rows) + today's session findings.
Goal: separate REAL deaths (don't revive) from FIXABLE deaths (improvement opportunities), and map
each fixable cause to the rescue technique we have (or lack).

## Death-cause distribution (what actually killed EAs)

| # rows | cause | verdict class |
|---:|---|---|
| 31 | lot / martingale / escalation | MIXED — uncapped-ruin = structural; capped+SL+entry-edge = fixable |
| 29 | regime / both-window fail | **FIXABLE** (biggest recoverable bucket) |
| 12 | spread-stress death | NARROW-fixable (only marginal ones) |
| 10 | default / smoke-only | **FIXABLE** (under-swept — today's lesson) |
| 9 | optimize-confirmed ceiling | REAL death (don't revive) |
| 8 | fill / model artifact | REAL death (edge was Model-1 optimism) |
| 3 | no-source / cracked / locked | dead-for-us (can only run-as-is) |
| 5 | not-a-strategy (astro/scaffold) | not applicable |

## The two piles

### 🟥 REAL deaths — do NOT spend rescue time (25 rows)
- **optimize-confirmed ceiling (9):** swept exhaustively, ceiling <1.0 both-window or OOS collapse
  (SessionBreakout 1,200-pass 1.20/fwd 0.91). This is what a valid kill looks like.
- **fill/model artifact (8):** PF only in Model-1/2 (optimistic), gone on Model-4 real ticks. The
  "edge" was simulated-fill optimism. (Caveat: a few tight-TP ones might want a different exit.)
- **uncapped-ruin subset of martingale:** flat-lot probe PF<1 = the escalation WAS the edge → ruin.
- **no-source/cracked (3):** can't modify or verify. Run-as-is on demo only, no improvement path.

### 🟩 FIXABLE deaths — improvement opportunities (the real prize, ~50+ rows)
Ranked by size × technique-readiness:

**1. Regime / both-window fail (29 rows) — BIGGEST opportunity, technique EXISTS but unused at scale.**
Great in one regime, dead in the other (XAU_NY today: MAIN 2.0-2.4 / BWD collapse). The rescue =
`Regime.mqh` (ORDER-057: ADX trend/range + ATR storm gate) — trade only in the favorable regime, or
add the missing direction. We BUILT the regime lever but never ran the parked regime-dependent pile
back through it. **GAP: no systematic "re-run parked-regime EAs through Regime.mqh" pipeline.**

**2. Lot/martingale hiding a real entry (subset of 31) — technique exists, not systematically applied.**
CLAUDE.md rule: capped-martingale + SL + entry-edge ≠ uncapped-ruin. The discriminator = flat-lot probe
(close escalation, is PF still >1?). Many in this pile were name/lot-check DQ'd WITHOUT a flat-lot probe.
**GAP: no systematic flat-lot-probe sweep over the martingale pile** to find hidden entry edges →
rebuild on a bounded chassis (MatchaGrid/Kangaroo/JUMSTOCH-capped).

**3. Default / smoke-only (10 rows, + hidden ones) — TODAY'S LESSON, highest confidence.**
Killed on default params / 1 TF. SMC×STO proved the trap (0.63-0.89 default → 1.14-1.39 optimized on
right home). **GAP: the retro-audit "killed correctly" pile itself needs re-audit with the sharpened
gate** — some of the other categories likely contain under-swept kills mislabeled as structural.

**4. Spread-stress death (12 rows, marginal subset) — technique BUILT today, narrow.**
Pending-limit (Thread A/B) saves ~+0.05 PF/trade. Only rescues EAs whose post-spread PF ≥ ~0.95 (gap
small enough for +0.05 to cross 1.0). Deep collapses (0.5-0.7) are not rescuable. **Prune to the marginal
spread-deaths, apply pending-limit + TP-widen.**

## Improvement toolkit — what we have (mostly built THIS session)

| technique | fixes which death | status |
|---|---|---|
| **Regime.mqh gate** (ADX trend/range/storm) | regime / both-window fail (29) | built (ORDER-057), **unused at scale** |
| **flat-lot probe** | martingale-hiding-edge | have it, not systematic |
| **re-optimize on right home** | default/smoke-only (10+) | have it (today), must become default reflex |
| **pending-limit / split-retest** | spread death (marginal) | built today (Thread A/B) |
| **HP-denoise (causal HP filter)** | noisy trend-cross entries | built (ORDER-104C), reusable lever |
| **ADX filter** | counter-trend losers in reversion | built today (EmaStoRev) |
| **oscillator param optimize** | "noise" (STO 5→13) | today's lesson |

## Development GAPS — where to invest next (optimize/improvement capability)

1. **🥇 Systematic regime-gate rescue pipeline** — take the 29 parked regime-dependent EAs, run each
   through `Regime.mqh` both-window. Biggest recoverable bucket, technique already exists. = an ORDER.
2. **🥈 Flat-lot-probe sweep over the martingale pile** — separate "martingale was the edge" (dead) from
   "capped martingale hiding a real entry" (rebuildable). Cheap, mechanical, high hit-rate potential.
3. **🥉 Re-audit the "killed correctly" pile with the sharpened gate** — my own bias (today's lesson)
   means some structural-labeled kills are actually under-swept. Highest-confidence per-row wins.
4. **Walk-forward / re-optimization CADENCE** — most EAs optimized ONCE; regime drift kills them over
   time. We have a 6-month re-opt rule but no automation/tool. = a capability gap, not just a backlog.
5. **HTF / multi-TF confluence as a standard filter** — barely used (started with SMC×STO). Could lift
   the marginal both-window cells across the board.

**Meta-lesson from today:** the biggest "death cause" in the lab may be **premature judgment** (default/
smoke-only + mislabeled structural) rather than genuine no-edge. The warn-hook + gate fixes address the
going-forward risk; gaps #1-3 above address the backlog of EAs already wrongly parked.
