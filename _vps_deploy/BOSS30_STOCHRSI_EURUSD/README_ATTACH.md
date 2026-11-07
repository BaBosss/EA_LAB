# Boss_30_StochRsiGrid — EURUSD H1 — PENDING_ATTACH bundle (demo only)

Built 2026-11-07. The owner approved CANDIDATE and a demo attach the same day.

Everything below is **pre-registered**. It is written before the demo starts, so the judge cannot be graded
against a bar invented after seeing the result.

Evidence: `D:/EA_LAB_RESET/agy_import/phase2/PHASE2_EVIDENCE.md`. Scorecard row: `EA_SCORECARD_AND_REGISTRY.md`,
section "AGY GrandModular ports".

---

## 🔴 Account: a dedicated demo account is required

**Do not attach this EA to a shared account** such as `463666728` (Demo bundle 10, 18 EAs) or `415573666`.

The EA's 12 % cut is account-wide:
- It reads `(balance − equity) / balance` for the **whole account**
  (`ea_template/core/entries/Entry_StochRsiGrid.mqh`, account cut block).
- It closes **only its own** positions (`Exec_CloseAll` filters by magic).

On a shared account this breaks in two ways:
1. **Other EAs' floating losses fire Boss_30's cut.** It would close its own baskets for losses it did not make.
2. **On a large balance the cut is far weaker than the tested setting.**
   - On 100,000 USD the cut needs 12,000 USD of floating loss.
   - The worst floating loss seen in backtest, scaled to 0.05 lot, is about 640 USD (BWD 9.0 % of 10,000 at
     0.07). So 12,000 USD is roughly 19× anything observed.
   - It is not proven unreachable, because there is no per-order stop. But it is no longer the stop that was
     tested.

Either way, the forward record would not measure the configuration that was tested.

**Account spec:**

| Field | Value |
|---|---|
| Type | MT5 **demo** |
| Margin mode | **Hedging** (the EA runs independent buy and sell baskets and refuses netting accounts) |
| Currency / balance | **USD 10,000** |
| Leverage | 1:100 (the backtests ran at 1:100) |
| Other EAs | none |

---

## What to attach

- **Chart:** EURUSD **H1**. Use the broker's suffix if it has one, e.g. `EURUSDm`.
- **EA:** `Boss_30_StochRsiGrid.ex5` from this folder.
- **Set:** `Boss30_StochRsiGrid_EURUSD_demo.set` from this folder.
- **Magic:** 993001.

### The binary

This is the **exact binary that produced the Model 4 MAIN/BWD and holdout evidence**. It was taken from
`D:\Meta 5c\MQL5\Experts\AGYP1\ea_template\` and compiled 2026-11-06 22:30, after the newest source file
(22:14).

All 148 `.mq5`/`.mqh` files in that tester tree are byte-identical to `ea_template/` at `84b65b1e`
(origin/master on 2026-11-07).

`.ex5` is gitignored, so the hash below is the record:

```
SHA256 FEBFC21FF82F5D5AD39DC61658366E171258555C293255B803E2164D1AA7CA82   186,158 bytes
```

Check the hash before attaching:

```bash
powershell -NoProfile -Command "Get-FileHash '_vps_deploy/BOSS30_STOCHRSI_EURUSD/Boss_30_StochRsiGrid.ex5' -Algorithm SHA256"
```

### The .set

- It is the **full 172-input list** of the 2026H1 holdout run at lot 0.07.
- **One value is changed:** `_41_FixedLot=0.05`.
- The frozen centre is `_30_InitTP_Points=120`; every other value is the build default.

### After attaching — verify on the chart (the PivotBreakout lesson)

MT5 raises no error when a `.set` is loaded onto the wrong EA. It applies the input names that match and silently
drops the rest. So the attach is verified only after the **Inputs tab** has been read back and shows all of:

| Input | Expected |
|---|---|
| `_0_Magic` | `993001` |
| `_41_FixedLot` | `0.05` |
| `_30_InitTP_Points` | `120` |
| `_30_CutDDPct` | `12.0` |
| `_30_MaxLayers` | `5` |
| `FirstLotMode` | `41` |
| `ProtectLevel` | `2` |
| `RC_PersistHalt` | `true` |

Then add the `DEPLOYMENTS.csv` row in the same session.

---

## Why lot 0.05 per 10,000

| Evidence (Model 4) | Lot | MAIN PF / eqDD | BWD PF / eqDD | Cuts fired |
|---|---|---|---|---|
| Cut-exercising run | 0.20 | 2.57 / 14.5 % | 1.82 / 19.8 % | 1 / 2 |
| — | 0.10 | 5.82 / 8.7 % | 3.69 / **12.0 %** | 0 / 0; BWD floating reached 11.99 % |
| Deploy-intent run | 0.07 | 5.82 / 6.6 % | 3.69 / 9.0 % | 0 / 0 |
| Holdout 2026H1 | 0.07 | 2.66 / 3.0 % (80 deals, 33 baskets) | — | 0 |

The demo runs at **0.05, below the 0.07 tested.** Monthly P&L correlation with `(Boss)_RSI_MR_GridLog` EURUSD
(990103, already on demo) is **0.51 in BWD**. The two EURUSD reversion grids lost together in 2020-02 and
2022-07. The rule for correlation is to reduce lot, not cut.

At 0.05, expected eqDD is about **4.7 % MAIN / 6.4 % BWD**. This is the 0.07 figures scaled linearly; at that
size the cut never fired, so the scaling is valid.

---

## Pre-registered expectations

- **Trade rate:**
  - about **80 closed baskets a year** (480 baskets in the 6 backtest years);
  - about **1.3–1.5 baskets a week** (holdout 1.27/wk);
  - about **2.7 deals a week**.
- **Per-deal PF:**
  - MAIN 5.82, BWD 3.69, holdout 2.66.
  - Per-deal PF **overstates a grid**: 99 % of baskets win, and the losing legs sit inside winning baskets.
  - Do not read a high per-deal PF as confirmation.
- **The real risk is the account cut.** Basket Monte Carlo puts break-even at about **4 cut events per
  6 years**:
  - 3 events still make money (PF p5 1.30);
  - 6 events lose (PF 0.66).
  - At 0.20 lot the cut fired 3× in 6 years. At 0.05 it needs an excursion about 4× larger, so it should be
    rarer. That rarity is a model assumption, not an observation.

## Judge criteria (pre-registered)

**The holdout is spent.** 2026H1 was used on 2026-11-07. **The demo forward record is now the only unseen
data**, the Boss_16 precedent.

**Unit of count = closed baskets, not deals.** A basket's legs close together and are not independent trades.
Counting deals would reach the 30-trade bar about twice as fast on the same evidence.

**Metrics.** The account is dedicated to this EA, so account figures are this EA's figures.
- **Equity drawdown** = (highest account equity since attach − current equity) ÷ that highest equity.
  Peak-to-trough, read from equity, so open positions count.
- **Net** = account equity at the judge read − starting balance (10,000 USD). Equity is marked to market, so an
  open losing basket counts against it. Any deposit or withdrawal is subtracted out; none is expected.
- **Per-deal PF** = gross profit ÷ gross loss over closed deals of magic 993001, swap and commission included.

**Judge bar.** All three must hold:
- **≥ 30 closed baskets**, and at least 3 months;
- **per-deal PF ≥ 1.40**;
- **net > 0** (equity-based, as defined above).

**Judge date:** `judge_date = attach + 5.5 months`. At about 1.3–1.5 baskets a week, 30 baskets take about 5
months. A 3-month judge would see about 17 baskets.

**If fewer than 30 baskets have closed on the judge date:** that is **insufficient evidence, not a pass and not
a fail.**
- Record it as a participation shortfall against the pre-registered rate.
- The judge moves to the date the 30th basket closes, but **no later than attach + 9 months**.
- If 30 baskets are still not reached by then, the owner decides with the counts in hand.
- Kill rules stay active throughout.

**Kill.** Any one of these:
- **Equity drawdown > 15 %**, as defined above.
  - One cut costs about 12 %, so a single clean cut does not trip this.
  - Going past 15 % means the cut overshot (a price gap) or a further loss stacked on a cut. Either way the tail
    is worse than the tested one.
  - The EA's own cut uses a different formula, `(balance − equity) ÷ balance` from the current balance. The two
    are not expected to agree after a cut.
- **2 account cuts within any 12 months.**
  - Break-even is about 4 per 6 years, about 0.67 per year.
  - 2 in a year is three times that rate, so the edge is not paying for its tail.
- **3-month per-deal PF < 0.8 at ≥ 15 baskets.** This is the repo default, counted in baskets.

**One cut is not a kill, but it must be recorded.**
- Record the date, the cut %, and whether `PauseBarAfterCut` resumed trading cleanly.
- After a cut, the judge's "net positive after cut losses" condition becomes the binding one.

**Guard counts to report at judge** (the guard row of the bar table):
- how many times the 12 % cut fired (`[30] ACCOUNT CUT` lines in the Experts log);
- how many times the shared 25 % hard kill fired. It is expected never to fire, because the 15 % demo kill sits
  below it.

**What makes this informative even if it fails.** It is a grid, so record whether a losing stretch came from:
- the entry being wrong, or
- the grid carrying an adverse leg into a cut.

Only the first one kills the concept.

**Sizing after a pass.** Grid class: **permanently small-lot, never sized up on PF.** A pass opens the question
of a real-money attach at this size or smaller. It is not a reason to raise the lot.
