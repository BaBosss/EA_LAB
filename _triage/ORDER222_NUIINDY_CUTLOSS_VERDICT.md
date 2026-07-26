# ORDER-222 — does NuiIndy's `CutLoss_Percent=30` actually cut?

**Verdict: it cuts. It is not insurance.** The mechanism works exactly as advertised at the level it
operates on — and that level is not the one the lab's own note claimed. `CutLoss_Percent=30` closes a
basket at **30% of the balance it currently has**, resets against the reduced balance, and can do so
again. It does not bound account drawdown, and the regime where it fires repeatedly is the regime it
was bought to protect.

Seat: Opus. Independent second read: Codex, blind (given the numbers, not the conclusion — it was
asked in ORDER-222's own prompt to argue the strongest case that I was reading the data wrong).
No live account touched. No 2026H1 spent. All runs Model 4, EURUSD H1, 2022.01.01–2023.01.01,
deposit 10,000 USD, leverage **verified 1:100 in every report**, truncation sidecar `false` on all.

---

## 1. The measurements

Risk is raised by lowering `Lot_Divided` (base lot = equity / `Lot_Divided`). It is the only lever
that moves %DD: lot scales with equity, so percentage drawdown is deposit-invariant and lowering the
deposit changes nothing. `Multiple3=1.2` was deliberately left alone — changing the escalation shape
would test a different EA.

| risk | `Lot_Divided` | `CutLoss` | PF | trades | net | eqDD | cuts fired |
|---|---|---|---|---|---|---|---|
| ×1 (**live value**) | 500,000 | 30 | 1.17 | 933 | +976.82 | **15.6%** | **0** |
| ×2 | 250,000 | 100 | 1.20 | 933 | +2,777.61 | 27.48% | n/a |
| ×2 | 250,000 | **30** | 1.17 | 954 | **+2,430.94** | 27.85% | a few |
| ×4 | 125,000 | 100 | 1.13 | 931 | +5,088.27 | 52.44% | n/a |
| ×4 | 125,000 | **30** | **0.33** | 991 | **−8,599.15** | **87.29%** | **8** |

Stage 0 also settles a question the recon raised: the two archived runs behind the recommendation
wrote `Leverage=100`, the numeric form the tester silently ignores, and came back at **1:2000**.
Re-run at a verified 1:100 the result is PF **1.17** vs the archived 1.19, 933 trades in both, eqDD
15.6% vs 15.40%. **The 20x leverage error did not corrupt that evidence** — identical trade counts
mean the strategy never came near a margin constraint at either setting.

## 2. Proof that it fires, and at what

Behavioural, not from a log line — the report has no CutLoss tag. Runs C and D share inputs except
`CutLoss_Percent` and their **first 123 deals are identical**. They diverge at deal 124:

```
2022.01.27 15:35:34   all 14 open positions close together
                      profit -3,048.48, swap -110.20
                      balance 10,521.99 -> 7,363.31   =  -30.02%
```

That signature repeats **8 times**, each one taking ≈30.0–30.6% of the balance *at that moment*:

```
10,521.99 -> 7,363.31 -> 5,214.54 -> 4,025.58 -> 3,125.71 -> 2,735.74 -> 2,145.68 -> 1,599.08 -> 1,326.67
```

**That ladder is the whole finding.** A 30% cut measured against a shrinking balance is not a floor,
it is a ratchet: eight of them leave 13% of the starting balance, which is how run D reaches **87.29%
equity drawdown while a "30" threshold is active**. Nothing about the number 30 caps the account.

Whether the threshold is basket-loss-vs-basket-start or equity-vs-current-balance **cannot be
distinguished from these reports** — only one basket is ever open at a time. It does not change the
conclusion, but it should not be asserted either way.

## 3. What is NOT proven, stated plainly

- **The C-vs-D net comparison is weakened, not clean.** Run C's only loss event is the tester's
  forced end-of-test liquidation at 2022.12.30 23:54:57 (−15,300.26, a 49.6% single-step hit), so its
  +5,088 is endpoint-sensitive: the calendar, not the market, decided when that basket resolved.
  Establishing "the cut fires" does not need C at all; ranking the two settings over a long horizon
  **would** need a window extended past 2022, and that test has not been run.
- **Nothing here measures the live account.** At the live `Lot_Divided=500,000` the cut never fires in
  this window, so at live sizing "free" remains **untested**, not confirmed.
- The ×4 rung is a stress construct. It says what the mechanism does when the threshold is reachable
  repeatedly; it does not say 2022-at-live-sizing was dangerous.
- **Tester determinism confirmed twice, which is worth recording on its own:** the ×2 pair was run
  again in stage 2 and `O222_S2_ld250000_cut100` reproduced stage 1's `O222_S1_ld250000_nocut` exactly
  — PF 1.20, 933 trades, +2,777.61, eqDD 27.48%. Codex separately found the ×4 pair byte-identical.
- Codex's correction to my own numbers, kept for the record: the D loss clusters run ≈−573 to −3,159
  including swap, not the −1,158 to −3,048 I first quoted from profit alone. And
  `O222_S2_ld125000_cut100.htm` is byte-identical to `O222_S1_ld125000_nocut.htm` apart from embedded
  image filenames — it is a reproducibility check, **not** a second independent control. (Worth noting
  against [[mql5-compile-not-byte-reproducible]]: the *tester* is deterministic for identical inputs
  even though the *compiler* is not.)

## 4. The shape of the failure is what matters

The cost of this switch is **non-linear in a way that inverts its purpose**:

| regime | what the cut does |
|---|---|
| ×1 — DD tops out at 15.6% | never fires. Costs nothing. Protects nothing. |
| ×2 — DD grazes the line at 27% | fires occasionally. Costs ~12% of profit (+2,431 vs +2,778), DD unchanged. Genuinely cheap. |
| ×4 — DD would reach 52% | fires 8×, ratchets to 13% of balance, turns **+51% into −86%**. |

So the switch is cheapest exactly where it is useless and ruinous exactly where it would be called
upon. "Free tail-insurance (DD bounded ~15%)" was true only in the sense that the DD stayed at 15%
**because the switch never engaged**. Read as a claim about protection, it is backwards.

## 5. Verdict against the pre-registered bars

ORDER-222 pre-registered: *pass = a basket closes at ~30% **and** the cutting arm is less damaged than
the non-cutting one · dead = cutting is worse ⇒ revisit the value 30, not the mechanism · middle =
fires but the outcome is close ⇒ keep it, recorded as a damage cap rather than a return enhancer.*

First half of `pass` is proven to the decimal (−30.02%). Second half fails at ×4 and mildly fails at
×2. So: **the `dead` branch — revisit the value, keep the mechanism.** Concretely:

1. **Withdraw the phrase "free tail-insurance" and the "DD bounded ~15%" claim** from EDGE_CATALOG and
   the ORDER-095 verdict. The bound was an artefact of the switch not firing. *(done in this order)*
2. **Do not remove `CutLoss_Percent`.** An uncapped-ruin martingale with nothing at all is worse than
   one with a ratcheting cut. The defect is that a %-of-current-balance cut cannot bound an account.
3. **What would actually bound the account is a floor, not a percentage** — a kill at an absolute
   equity level, fired once, that stops trading rather than re-arming against a smaller balance. This
   EA is closed-source-adjacent (source exists, 16.6k generated lines) and has no such input; a
   `MAX_Order` depth cap is the only other lever it exposes, and ORDER-095 already found that capping
   depth kills the profit engine.
4. **USER DECISION, not the lab's** — this is a user-mix account (`ATTESTATION_MAP` confidence
   `none`; we do not even have confirmed record of which `.set` is loaded on the VPS). The honest
   statement to the user is: *at your current sizing this switch has never fired and changes nothing;
   if the account ever draws down far enough for it to fire more than once, it will make the outcome
   worse, not better.* Whether that argues for a hard external equity-stop, for smaller sizing, or
   for leaving it alone is the owner's call.

**Open follow-up (cheap, not blocking):** extend the window past 2022 and re-run the ×4 pair, so the
long-horizon ranking of 30 vs 100 rests on a basket the market resolved rather than the calendar.
