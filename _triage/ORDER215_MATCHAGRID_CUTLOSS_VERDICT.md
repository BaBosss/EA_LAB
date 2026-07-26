# ORDER-215 part 2 — does MatchaGrid's `InpCutLossMode=0` cut anything?

**Verdict: no. The safety switch does not respond to its own threshold inputs at all.** The claim
that kept MatchaGrid out of the uncapped-ruin bucket — "bounded grid + hard SL" — describes a
mechanism that is not active in the config actually running on real money (magic 20240001, account
159475669). This is a sharper finding than ORDER-222's NuiIndy result: NuiIndy's switch fired, just
in the wrong shape (a ratchet). MatchaGrid's does not fire under any tested threshold at all.

Seat: Sonnet, 2026-07-26, continuing from the ORDER-215 interim finding
(`ORDER215_MATCHAGRID_CUTLOSS_FINDING.md`) that found the two degenerate-tick reports and zero
cut-signature clusters in 3.4 years of calm data. This pass deliberately manufactures the drawdown
the calm data never reached, the same method ORDER-222 used on NuiIndy.

All runs: MatchaGrid, CHFJPY M15, 2020.01.01–2023.01.01 (the confirmed-healthy window), deposit
10,000 USD, Model 4, leverage verified 1:100 in every report, truncation sidecar `false` throughout.
Every input pinned explicitly in a full `.set` — no run in this repo's history had ever pinned the
`InpCutLoss*` family before this probe; all prior reports inherited it from whatever the terminal's
per-EA input cache happened to hold (see §1 below, and `scripts/order215_matchagrid_cutloss_probe.ps1`
header for the reproducibility gap this closes).

---

## 0. A reproducibility problem, found before the real question

Stage 0 tried to reproduce the archived `MG_CHFJPY_OOS_corr` report (PF 2.08, 1409 trades, eqDD
23.75%) from a fully-pinned `.set` on the same window. It did not reproduce: **PF 1.77, 1397 trades,
eqDD 26.53%**, same 74,778 bars but the tick count came back at 61,093,205 against the archived
report's 4,399,319 — 14x more ticks for the identical window.

This is not a CutLoss finding. It happened because the primary tester (`D:\Meta 5`) was occupied by
another session, so this run went to the parallel portable instance (`D:\Meta 5b`), whose tick-history
`Bases` folder was copied from the primary at some point in the past and has apparently diverged since
(`mt5-parallel-instance` memory already documents this as a known risk of the two-instance setup).
**Flagging this as its own integrity item, separate from the verdict below**: `Meta 5b`'s CHFJPY
history should not be trusted as equivalent to the primary's until reconciled.

It does not weaken what follows, because stages 1 and 2 only compare arms run against each other on
the *same* instance (`Meta 5b`) — internal consistency, not a match to history, is what the CutLoss
question needs.

## 1. Every prior report ran on an unpinned safety-switch cache

No `.ini` for this EA — including the one behind the scorecard's headline number — lists any
`InpCutLoss*` value in `[TesterInputs]`. Per `mt5_run.ps1`'s own documented per-terminal-cache gotcha
(ORDER-165), that means the five values recon found identically stamped across every report it
checked (`Mode=0, Percent=10, Fixed=50, BuySide=true, SellSide=true, Total=false`) came from whatever
was cached in `MQL5\Profiles\Tester\MatchaGrid.set`, not from anything the funnel actually chose or
verified. Consistent across 5 samples is suggestive, not proof it was ever set deliberately. This
probe's `.set` files pin all 15 known inputs explicitly for exactly this reason.

## 2. The risk ladder, and why a "loss cluster" is not the same as a "cut"

Tightening `InpGridPoints` from 350 (live) to 200 raised the grid to **66 simultaneous open
positions** at one point and drove equity drawdown to **63.94%** — clearing both `InpCutLossPercent=10`
and any plausible reading of `InpCutLossFixed=50` many times over, on the same window that ran calmly
at 26.53% DD with the live grid spacing.

The first pass at this ladder stopped as soon as *any* negative-sum simultaneous-close cluster
appeared, which was the wrong bar — the same mistake this probe's own header warns against for
NuiIndy-style analysis. Checked the actual balance trajectory around each cluster:

| cluster | positions | realized | balance before | **% of prior balance** |
|---|---|---|---|---|
| 2022.04.26 23:08 | 53 | −88.02 | 14,078.43 | **−0.63%** |
| 2021.11.16 11:07 | 31 | −35.26 | 13,271.76 | **−0.27%** |
| 2022.12.31 23:59 | 9 | −34.14 | 17,924.12 | **−0.19%** |
| 2021.06.17 13:29 | 25 | −24.03 | 12,911.21 | **−0.19%** |

None of these are within two orders of magnitude of a 10% or fixed-$50 cut. One of them closed with the
account balance *higher* afterward than before. These are ordinary grid churn, scaled up in dollar
terms only because a tighter grid holds more concurrent positions — exactly the artefact the interim
finding warned a naive cluster-count would produce. **No genuine cut-candidate appeared at any point in
this run**, despite DD reaching 63.94%.

## 3. The isolating test

Held risk fixed at `GridPoints=200` (DD 63.94%, the level above) and changed **only** the CutLoss
thresholds: the live values (`Percent=10, Fixed=50`) against absurdly tight ones (`Percent=1, Fixed=1`)
— about as easy as a percent/fixed cut could plausibly be built to trigger.

**The two arms are identical in every reported field**: PF 1.67, 2,961 trades, net +7,889.72, eqDD
63.94%, the same four clusters at the same timestamps with the same amounts, down to the decimal.

Changing the threshold by 10x and 50x did not change a single trade. **`InpCutLossMode=0` does not
respond to `InpCutLossPercent` or `InpCutLossFixed` at all.** This is not "the threshold was too loose
to reach" (that would show *some* sensitivity as the threshold tightened) — it is non-responsiveness,
which is the strongest evidence available without source access that mode 0 means disabled.

## 4. What this does and doesn't establish

- **Established:** on this data, at this stress level, over 2,961 trades and a 63.94% drawdown, the
  configured cut-loss mechanism never engaged, and tightening its trigger by 50x changed nothing.
  Absent EA source (closed `.ex5`, no `.mq5` anywhere per recon), "mode 0 = disabled" is the reading
  this evidence supports; "mode 0 = a real mode this test still failed to trigger" would require the
  test to show *some* sensitivity to the threshold inputs, and it showed none.
- **Not established:** what modes other than 0 do. No other `InpCutLossMode` value was tried — this
  probe deliberately tested whether the *currently deployed* mode responds to its own thresholds, not
  which value would make it responsive. That is a follow-up question for whoever owns a decision on
  this EA's live config, not a blocking gap in this verdict.
- **Not established:** whether there is any OTHER stop this EA enforces that isn't one of the 15 known
  inputs (e.g. a hardcoded internal ceiling). Recon found no `InpMax*`/depth-cap input, and this run
  reached 66 simultaneous positions with no sign of a forced closure — consistent with no depth cap
  either, but this probe cannot rule out an internal limit that simply wasn't reached at 66.
- **What is genuinely different from an uncapped martingale:** `InpStepAddLot` adds a fixed 0.01 lot
  every 5 orders — linear, not `Multiple^order_count` geometric. Per this repo's own precedent
  (`rsi-from-pips-mechanism` memory), a linear-add ladder is materially safer than geometric escalation:
  exposure grows arithmetically with a losing streak, not exponentially. That does not make "no
  stop-loss" acceptable on real money, but it changes how urgently a fix is needed relative to a
  geometric engine in the same situation.

## 5. Verdict against ORDER-215's pre-registered bars for this sub-question

The pre-registered bar for this branch (set in the interim finding) was: *dead = the probe comes back
negative under real stress, i.e. no cut event at all even when deliberately pushed.* That is exactly
what happened, at a drawdown twice the height NuiIndy's proof used and with the threshold tightened
50x. **This clears the "dead" bar for the safety-switch question specifically.**

This does **not** by itself make MatchaGrid `DEAD-STRUCTURAL` under the CLAUDE.md VERDICT GATE. The
gate's automatic-kill wording is written for a **geometric** ladder with no cap and no SL; MatchaGrid's
ladder is linear, which the same gate's own history (RSI-from-pips precedent) treats as a materially
different risk class, not an automatic structural kill. So this is filed as: **the specific safety
claim is false and withdrawn**, and the broader verdict (mechanism-risk-penalized, PARKED-VERIFY, or a
harder line) is the same kind of owner decision NuiIndy's finding produced — not something this probe
should short-circuit by itself.

## 6. Recommendation

1. **Withdraw "bounded grid + hard SL" and "InpCutLossMode=0" as a safety property**, everywhere it is
   written, the same way ORDER-222 withdrew NuiIndy's "free tail-insurance" — strike the claim, keep
   the citation trail, do not delete the history.
2. **Do not touch the live account.** No run here implies the live config is currently in danger — the
   live grid spacing (350) has never produced anything like the manufactured 63.94% DD in the 3.4
   years of clean history checked. What changes is the belief that a stop exists if it ever needed to.
3. **This is a user-mix, user-attested account** (same class as NuiIndy) — whether to add an external
   stop, switch `InpCutLossMode` to an untested value, reduce sizing, or accept the exposure as-is is
   the owner's call, not the lab's, exactly as ORDER-222 concluded.
4. **Open, not blocking:** what do other `InpCutLossMode` values do. Answering that needs either the
   vendor/source or a small sweep of mode values at the same stress rung used here — cheap, and it
   would tell the owner whether a real fix is one input away or requires a different EA.
5. **Separately:** reconcile the `Meta 5b` CHFJPY tick history against the primary terminal's before
   trusting any further comparative run across the two instances (§0).
