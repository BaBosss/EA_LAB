# ORDER-116 — split-entry breakout campaign — CONCLUSION (Claude 2026-07-18)

User goal: "รีด split-entry (ORDER-108 lever) ให้ครบ portfolio, ทำยาวๆ." Answer after Phases 1–2 + validation:
**split is a NARROW config-refinement lever, not a portfolio-wide upgrade or a leg-generator.**

## What split IS worth (Phase 1 — positive)
The retest-split recipe (0.02mkt/0.01pend, RetestOffset −0.15, Expiry 5) makes **XAU H1 Bars40/TP5
regime-robust**: both-window 2.40/1.96 (vs market-only 2.49/1.75 — fills the chop weak window), full
continuous 2020–2026 PF 2.26 / 149t / maxEqDD 3.92%, **MC PF_5th 1.71 / ruin 0% / DD_95th 2.4%**.
This is a genuinely more chop-robust XAU breakout than the live Bars55 config (1.99/**1.12**).
**BUT corr 0.861 vs the existing XAU-BRK leg = same-slot redundant** (user rule: high-corr = reduce-lot
/ not a 2nd full leg). → **a REPLACEMENT/UPGRADE candidate for the XAU breakout slot at the next re-opt,
not a portfolio addition.** Banked in EDGE_CATALOG.

## What split is NOT worth (Phase 2 — negative)
- **Opens no new legs.** US30 = already ORDER-095's leg (corr −0.249 passed, staged 991005) and my
  plateau check shows it's a **spike, not a plateau** (thin 24–39t) → stays WATCH. XAG (no edge, split
  DD 17%) · GBPUSD (<1 both) · NAS100 (no data) = all dead for the generic Donchian breakout.
- Split can't create edge on a no-edge base, and adds nothing to a base already balanced both-window.

## Doctrine banked (the reusable law — same as pending, D1g)
**A refinement lever (pending OR split) only helps a base that already has both-window edge AND an
ASYMMETRIC weak window (strong in one regime, weak in the other) — it fills the weak window. It cannot
create edge, cannot help a balanced base, and can hurt a no-edge base.** Always measure the base
breakout's both-window profile FIRST, then decide split.

## Residual (optional, low-prior) — Phase 3/4 not run
- **Phase 3 (retrofit LondonConso GBP / CB_GBP with split):** the one genuinely-untested portfolio piece.
  Would need building split into those EAs' code (different strategy, not the Donchian EA). Payoff only if
  that leg has an asymmetric weak window — unknown. Given Phase-2's strong negative + the build cost, this
  is a low-prior optional order, not auto-run. Cheap generic-Donchian proxy already tested (GBPUSD Phase 2
  = no edge), so any value is in London's specific session-breakout logic.
- **Phase 4 (Bars55 TP-rebalance):** ORDER-108 already showed Bars55+split doesn't help (TP8 too wide).

## Feed-back to other orders
- **ORDER-095:** US30 991005 = spike-fragile (not just thin) per plateau check — keep WATCH / small size,
  don't graduate on the current single-cell evidence.
- **EDGE_CATALOG:** add split-retest lever with the sharpened caveat (asymmetric-weak-window filler).

## Net
Campaign delivered: the recipe, one validated (redundant-slot) XAU upgrade candidate, the sharpened
doctrine, and a clean NO on "does split extend across the portfolio." Concept characterized — further
batches = diminishing returns unless user wants the Phase-3 London build.
