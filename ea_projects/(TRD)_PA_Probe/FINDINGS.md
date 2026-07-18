# PA-confirm probe — findings (2026-07-18)

Phase 0 of the PriceAction-module plan. Question from the user: does candle price-action
CONFIRM improve grid/entry quality, and can pattern quality drive lot? Built a controlled
probe (`(TRD)_PA_Probe`, flat-lot, single-position, ATR-SL/RR-TP) to isolate what PA does.

## Phase 0 — PA as an entry filter (tendency, Model 2, 2019-2026)
PA is always a strong FILTER (cuts 43-86% of trades) and always slashes DD — but most of that
DD drop is just less exposure, not better signal. The true lens = **expectancy/trade**:
| context | Δexpectancy (off→on) | read |
|---|---|---|
| CONT XAU H1 | −1.47 → +3.18 | PA helps (noisy trend needs confirm) |
| CONT XAU H4 | +2.13 → −8.46 | PA hurts (clean signal, over-filtered) |
| CONT GBP H1 | −2.01 → −1.48 | marginal |
| REV EUR H1 | −1.82 → −2.98 | PA hurts (early reversal = wasted) |
| REV AUDNZD H1 | −2.6 → −3.84 | PA hurts |
| REV EURGBP H1 | −0.94 → +0.49 | PA helps (tight ranger) |
Trap: EUR-REV net/DD "improved" while win% and expectancy got WORSE — never judge PA on
net/PF alone. (User's point, confirmed.)

## Step 1 — do the "PA helps" contexts hold BOTH windows? NO.
Split the two positive contexts into UP(19-22)+DN(23-26):
- XAU-H1-cont PA-on: exp **−1.83 (UP) / +8.71 (DN)** — positive in ONE window only = window-fit.
- EURGBP-rev PA-on: exp **−1.38 (UP) / −1.04 (DN)** — negative both.
→ **PA as a NAKED entry filter does not create a both-window edge.** Same window-fit trap as
the AdaptiveGrid AUDNZD Model-2 plateau. A confirm layer cannot manufacture a standalone edge.

## Step 2 — PA-confirm on grid ADDS of an EXISTING basket (the user's real ask) — WORKS (defensively)
Wired `CONF_PA_ENGULF` (StackConfirm=4) into the chassis (`Stack_ConfirmOK` + `core/PriceAction.mqh`),
additive/default-off. A/B on Boss_14 GridLog AUDNZD, **Model 4 real ticks, both-window**:
| window | OFF distance | ON PA-engulf |
|---|---|---|
| UP 19-22 | PF 0.75 / net −711 / DD 9.6% | PF 1.00 / +4 / DD 4.7% |
| DN 23-26 | PF 1.25 / +425 / DD 5.1% | PF 1.15 / +94 / DD 2.8% |
| **both** | **net −286 / DD 9.6%** | **net +98 / DD 4.7%** |
PA-confirm on adds flipped the both-window total from net-negative to net-positive and halved
worst-window DD (trades cut ~60%). It is a **risk-trimmer / bleed-stopper**, not a profit engine:
gives back upside in the good window, kills the bleed in the bad one. This is the "จุดที่ได้เปรียบ"
(advantaged add point) the user described — validated on real ticks.

## Verdict + doctrine
- PA-confirm's value = IMPROVE an existing basket's add-timing (defensive, robustifying), NOT a
  standalone signal edge (Step 1 failed both-window). Confirm/MM layers multiply or protect an
  existing edge; they don't create one.
- Delivered as an opt-in chassis lever `StackConfirm=CONF_PA_ENGULF` (cage green, neutrality
  byte-identical). Base Boss_14 AUDNZD edge is thin on Model 4, so any tier-lot MM on top would
  amplify a thin edge — buildable (PF>1 both-window now) but marginal; temper expectations.

## Not built yet (next, per user vision)
- `PA_LotMult by tier` (pattern quality → size) = the MM layer; only meaningful where PA raises
  expectancy. Combine with Fixed-Fractional / Optimal-f (dev-plan Phase 2).
- SMC / S&R as additional confluence layers (repo evidence: naked FVG dead, SMC×STO candidate —
  use as confluence, not naked). Same both-window + Model-4 gate applies.
