# Pending-limit entry — synthesis of both threads (Claude, 2026-07-16)

User hypothesis (2026-07-16): "EA ที่ตายเพราะ spread → ตั้ง pending (maker, ไม่จ่าย spread) + ขยาย TP อาจดีขึ้น."
Tested on two entry families. Both EAs built in MT5 this session.

## Thread B — break-and-retest split (breakout) — 🟩 VALIDATED lever
`(EXP)_BRK_SplitRetest`, A/B Model-4 XAU H1. Full verdict `_triage/ORDER108_SPLIT_RETEST_VERDICT.md`.
- **Retest fill-rate ~90%** (breakouts retest the broken level often).
- market-only vs pending-only vs split(0.02mkt+0.01pend): split = **regime-robust** (1.93/1.97 both windows,
  no weak window), because market catches runaways + pending catches retests cheaper.
- **adverse-selection real:** pending-only < market in trends (misses the runaways) → the market leg is
  necessary → the SPLIT (user's idea) is the correct structure, not pure pending.
- **config-conditional:** helped Bars40/TP5, NOT the live Bars55/TP8 (retest leg weak there).

## Thread A — LWMA reversion pending vs market — quantifies the spread-save, base has no edge
`(EXP)_LwmaRev_Pending`, A/B Model-4 EURUSD+AUDNZD H1 both-window. Raw `_mt5_auto/order091d_lwma_ab.csv`.
- **pending fill-rate ~70-73%** (limit at a 0.5×ATR-deeper stretch misses ~28% of signals that bounce first).
- pending PF ≥ market PF in **3 of 4 cells** (+0.03 to +0.06): EUR BWD 0.88→0.93, AUDNZD MAIN 0.55→0.59,
  AUDNZD BWD 0.66→0.72; only EUR MAIN slightly worse (0.93→0.90). Consistent with per-trade spread/entry saving.
- **BUT the base LWMA reversion is negative-edge everywhere** (PF 0.55-0.93) — reversion is against the
  portfolio prior (EmaStoRev died the same way). So this vehicle **cannot demonstrate pending rescuing a
  loser into a winner** — it can only measure the per-trade improvement magnitude: **~+0.03-0.06 PF/trade.**
- net$ looks much better for pending (e.g. AUDNZD MAIN -425→-271) but that is partly just **~28% fewer trades
  = less exposure to a negative signal** — use PF (per-trade) not net$ to read the real delta.

## Combined answer to the user — pending-limit: real but modest, not free, not a resurrector
1. **YES it saves spread / improves per-trade EV** — measured ~+0.03-0.06 PF/trade on reversion; on breakout
   the retest leg fills at a maker price on ~90% of entries.
2. **NOT free — fill-rate cost:** pending misses ~28% of reversion signals / ~10% of breakout retests, and the
   missed ones can be **adverse-selected** (breakout runaways = the biggest winners). This is why the **split
   structure** (market + pending) is the smart form — it keeps the runners.
3. **NOT a resurrector:** pending is a *refinement of an existing edge* (~+0.05 PF), not a new edge. It cannot
   turn a no-edge signal (LWMA reversion 0.6-0.9) positive. So "revive a spread-killed EA with pending" works
   ONLY if the EA had a **near-breakeven-or-better edge before spread** — then +0.05 PF may push it over 1.0.
4. **TP-widen (user's 2nd half):** not yet A/B'd here — queued as a lever on the reversion vehicle (TP{+0,+2,+5})
   if a near-breakeven reversion base is found. On a negative-edge base it can't help either.

## Where this leaves the "spread-death rescue" idea (ORDER-084 gong-A)
The right test = a signal that had edge BEFORE spread and died AFTER (the true spread-death EAs: Yetti/Grail).
Most are compiled MT4 (can't add pending). For SOURCE-available ones, the transferable number is now known:
pending buys ~+0.05 PF/trade — so only spread-deaths that were within ~0.05 PF of 1.0 are plausible revives.
The deep spread-deaths (PF collapsed to 0.5-0.7 under SPR30) are NOT rescued by pending — that gap is too big.
→ prune the pending-revival candidate list to **only the marginal spread-deaths (post-spread PF ≥ ~0.95)**.

**Both EAs banked as reusable pending vehicles.** Thread B (split) = the validated, adoptable form.
