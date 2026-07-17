# ORDER-091C-D1g VERDICT — JUMSTOCH pending-limit + TP-widen A/B (Claude, 2026-07-17)

**Scope (per pre-registered bar):** refinement-lever test on the confirmed-edge JUMSTOCH base
(D1→D1f demo-ready, flat-lot PF 1.18). Decides the demo **CONFIG** only (entry mode · TP setting) —
NOT whether JUMSTOCH lives/dies. Closes ORDER-080 (limit vs market) + the user's 2026-07-16 full
hypothesis ("EA ตายเพราะ spread → ตั้ง pending + ขยาย TP").

**Regression cage PASSED** before any A/B: new `(EXP)_JUMSTOCH_Pending` EntryMode=0/TP+0 = identical
to the original `(EXP)_JUMSTOCH_MT5` (PF 1.34 / 869t / eqDD 6.23%, EURGBP H1 2025.03–2026.07 Model 1),
and reproduces the 07-11 D1f recorded baseline exactly. → the two added levers are the ONLY behavioral
change. Both levers proven *functional* (each changed trade counts), so a null result = real, not a
dead toggle.

**Model note (pre-registered bar AMENDED, pre-result):** Model-4 does not write reports on this box
(test runs to completion — journal shows trades — but terminal+local-agent never emits the .htm;
Model-1 writes normally). Consistent with the whole JUMSTOCH line using Model-1 on 07-11. Ran Model-1
(M1-OHLC captures whether price reached a limit level intrabar = adequate for the fill question;
residual caveat = intra-minute tick ordering not simulated). Model-2 still forbidden. Logged as
`AMENDMENT_ADDED` targeting the BAR event. Raw = `_mt5_auto/D1G_AB_RESULTS.csv`.

## Result — both halves of the hypothesis = NULL / noise-level on JUMSTOCH

**A) Pending-limit entry (grid adds as resting maker limits) — NO LIFT.**

| cell | market PF | pending PF | Δ |
|---|---|---|---|
| EURGBP H1 recent (2023–26) | 1.48 / 2368t | 1.49 / 2421t | **+0.01** |
| EURGBP H1 BWD (2020–22) | 1.03 / 5248t | 1.00 / 5346t | **−0.03** |
| NZDUSD H4 recent | 1.37 / 3879t | 1.37 / 3879t | **0.00** (identical) |
| NZDUSD H4 BWD | 0.97 / 4937t | 0.97 / 4937t | **0.00** (identical) |

**Mechanism (the real finding):** JUMSTOCH's grid-add only fires when `ask ≤ trigger` — it already
*waits* for the ask to reach the grid level, so it isn't paying spread-over-trigger. Converting that
to a resting buy/sell-limit at the *same* trigger fills at the same price → no spread saved (and
marginally WORSE on gaps, since a market fill can catch a gap-through price the limit fills at par).
**The user's "grid เทรดเยอะ = ประหยัด spread ทวีคูณ" premise does not apply to this EA** — its entry is
already trigger-touch, not market-spread. Pending-limit helps only EAs whose baseline enters at *market*
on a signal (paying the full spread); JUMSTOCH doesn't.

**B) TP-widen (both TP anchors) — inert to +2, noise-level at +5.**

| window | +0 | +2 | +5 |
|---|---|---|---|
| EURGBP H1 recent | 1.48 | 1.48 (identical) | 1.50 (+0.02) |
| EURGBP H1 BWD | 1.03 | 1.03 (identical) | 1.04 (+0.01) |

**Mechanism:** JUMSTOCH exits via basket-BEP shift + trailing (Dtrailing, StartTrail 10 / Trailing 7),
not the raw per-leg TP — so widening the TP anchor is mostly bypassed. +5 clears the pre-registered
"≥ baseline both-window" bar (1.50≥1.48 · 1.04≥1.03) but the lift is +0.01–0.02 = within noise, DD
unchanged. Not a meaningful edge.

## DECISION (config only)

**Keep JUMSTOCH's validated demo config unchanged — market entry, TP as-is.** Neither lever justifies
altering a validated config (changing a validated setting for +0.01 PF = selection-fit risk, VERDICT
GATE #6). Pending = NULL (structural: no spread to save). TP+5 = park as a noise-level tweak available
at the next 6-month re-opt, not adopted now.

## Doctrine banked (reusable)

- **Pending-limit rescue applies to MARKET-entry-on-signal EAs, NOT to grid EAs that already enter at
  a trigger level.** Before proposing pending for a spread-death candidate, check HOW the baseline
  enters: market-on-signal (spread paid → pending can help) vs level-touch/limit-like (no spread to
  save). This prunes the pending-revival candidate list further than D1d's "post-spread PF ≥ 0.95".
- Combined with D1d (pending = +0.05 refinement only on a market-entry base) + D1g (null on a
  trigger-entry grid): **the pending-limit doctrine is now fully characterized. ORDER-080 CLOSED.**
- JUMSTOCH stays demo-eligible on its 07-11 validated config (this order did not touch that).
