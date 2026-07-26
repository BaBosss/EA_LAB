# AUDIT — deploy-bundle README vs. the evidence behind it (group 1)

**Scope.** Ten `_vps_deploy` bundles not covered by `_triage/ORDER202_HOLDOUT_CONTAMINATION_RETROSCAN.md`.
Read-only forensic pass, 2026-07-26. **No verdicts here — evidence only.** Nothing was re-run.

**Method.** Indexed `Expert / Symbol / Period / Model / Optimization / FromDate / ToDate` for all
6,609 non-empty `.ini` under `_mt5_auto/ini` in one pass, then joined each bundle's `.set` to the
`.ini` that carries the same inputs, then re-read the produced `.htm` (UTF-16LE → UTF-8) to confirm
the numbers the README prints. Registry standing checked against `EA_SCORECARD_AND_REGISTRY.md`,
`EA_MASTER_INDEX.csv`, `AGENT_TASKBOARD.md`, `PROJECT_STATE.md`, `portfolio/DEPLOYMENTS.csv`.

**Two classes kept apart, per the ORDER-202 convention:**
- **CONTAMINATED SELECTION** — the run that *chose* the parameters saw data after `2025.12.31`.
- **HOLDOUT SPENT** — parameters chosen on clean data, but the ship/no-ship *evaluation* consumed 2026H1.

**One extension of the ORDER-202 method, stated up front because it drives four of the labels below.**
ORDER-202 keyed contamination on the `.ini` field `Optimization != 0`. That field only catches the MT5
*optimizer*. Six of these ten bundles were parameterised by a **hand-rolled grid of `Optimization=0`
point runs** — one `.ini`+report per cell, then "pick the best cell". That is selection by any honest
reading: the same answer sheet was visible, the tester just wasn't the thing turning the crank.
Where that happened I label it CONTAMINATED-SELECTION and say explicitly that the `Optimization` flag
reads 0, so the reader can apply the stricter or looser reading themselves.

Boundary convention inherited unchanged: `ToDate=2026.01.01` produces **zero** 2026 deals and is **not**
counted as contamination (verified in ORDER-202 against `RSIMR_L2_RSI25_75_SL25_MAIN.htm`).

---

## Summary table — most serious first

| # | Bundle | Label | One-sentence justification |
|---|---|---|---|
| 1 | `BRK_XAU_Bars8` | **CLAIM-MISMATCH** | Bundle has **no README at all**; the `.set` header's two headline numbers (`IS 2.61 / OOS 3.92`) belong to **two different cells of the sweep, neither of them the shipped config**, whose real numbers are IS 1.66 / OOS 3.85. |
| 2 | `EA_SUPERTREND_XAU` | **CONTAMINATED-SELECTION** | The 18-cell grid that picked ATR10/×3.0/SL2.0 ran every cell on `2023.01.01→2026.07.01` — the whole holdout inside the selection window — and the one clean out-of-sample window that does exist (`ST085B_BWD_2020_2022`, same config, **PF 0.88, net −91.49**) appears nowhere in a README headed "fully validated XAU edge". |
| 3 | `ST03_GBPUSD` | **CLAIM-MISMATCH** | Windows are genuinely clean (2024 only), but the README still advertises `IS 8.31 / OOS 3.93 → DEPLOY SMALL` when the registry has since replaced that with **PF 0.86 on 585 trades**, marked the loop CLOSED, and the EA was pulled off the real account on 2026-07-18. |
| 4 | `ZEUS_AUDJPY_REGIME` | **CONTAMINATED-SELECTION** | Every cell of the regime-mode, ADX-threshold and storm-multiplier sweeps — and the bundle's own verification run — used MAIN = `2023.01.01→2026.07.01`, so the gate that "rescues" this EA was chosen with all six holdout months visible. |
| 5 | `ICHIADX_XAU` | **CONTAMINATED-SELECTION** | The Kumo-period lever that created this edge was selected on `→2026.07.01` MAIN windows, both headline PFs (1.57 / 2.85) are full-span `2020.01.01→2026.07.01` runs, and the EA has **no row in the scorecard or master index** to check the "DEMO-ELIGIBLE" claim against. |
| 6 | `ICHIADX_USDJPY_BASKET` | **CONTAMINATED-SELECTION** | Same period-lever selection on `→2026.07.01` (`KUMO_*_MAIN`, 8 cells), and the merged/MC evidence that the whole "thin but positive" case rests on is a 2020–2026.07 sequence that includes the holdout. |
| 7 | `CB_EUR` | **CLAIM-MISMATCH** | Numbers all reproduce exactly, but the registry says **"DROP (was #8) … no durable edge → remove from portfolio"** while the README still reads "CONDITIONAL — deploy with close monitoring". |
| 8 | `SMCSTO_EURUSD` | **HOLDOUT-SPENT** | Selection is clean (optimize ends `2026.01.01`), but 2026H1 was run and its PF 1.14 is quoted **as a passing gate** in the README's "full funnel cleared" — and the registry has since downgraded the same EA to "marginal edge, SL-fragile". |
| 9 | `CB_GBP` | **HOLDOUT-SPENT** | Selection window is clean (`CB_OPT_GBP_H1.ini`, `Optimization=1`, `2023.01.01→2025.06.01`), but the OOS1 that carries the "3/3 OOS pass" claim runs `2025.06.01→2026.06.01`, i.e. five months inside the holdout. |
| 10 | `RSI_MR_EURUSD` | **HOLDOUT-SPENT** | Cleanest of the ten — every selection run stops at the `2026.01.01` boundary — but 2026H1 was run on the winner, and the README states its failure (PF 0.76 / n=21) openly and downgrades itself to BUILD-ON accordingly. |

**Counts:** CLAIM-MISMATCH **3** · CONTAMINATED-SELECTION **4** · HOLDOUT-SPENT **3** · CLEAN **0** · NO-EVIDENCE-FOUND **0**.

No bundle came out CLEAN. Every one of the ten either selected on, or decided on, data inside 2026H1.

---

## 1. `BRK_XAU_Bars8` — CLAIM-MISMATCH

### 1.1 What the README claims
**There is no README.** The bundle holds only `EA_BREAKOUT_XAU.ex5` and
`BRKXAUH4_Bars8_demo_v1.set`. The nearest thing to a status line is the `.set`'s own comment header,
which is what a human reading this folder at attach time actually sees:

```
; EA_BREAKOUT_XAU — BRKXAUH4 Bars8 additive variant (DEMO v1)
; Validated 2026-06-27: IS M4 2023-2025.06 PF=2.61 / OOS M4 2025.06-2026.06 PF=3.92
; MC bootstrap: PF_5th=1.73, DD_95th=~2%, Ruin=0% PASS all gates
; Corr vs live Bars40 (991001): 0.21 LOW → ADDITIVE as leg #9
; Magic=991002
```

Deployed `.set` (the only one present): `_01_BreakoutBars=8`, `_02_TpAtrMult=4.0`,
`_02_SlAtrMult=1.5`, `_05_BuyOnly=true`, `_06_Magic=991002`.

### 1.2 What the evidence actually used
The funnel is a 6-cell hand grid, `BRKXAUH4_c0..c5`, `Optimization=0`, Model 4:

| cell | Bars | TpAtr | IS `2023.01.01→2025.06.01` | OOS `2025.06.01→2026.06.01` |
|---|---|---|---|---|
| **c0** | **8** | **4.0** | **PF 1.66** / 72t | **PF 3.85** / 21t |
| c1 | 8 | 6.0 | PF 1.92 / 68t | PF 3.92 / 20t |
| c2 | 12 | 4.0 | PF 1.99 / 53t | PF 3.51 / 17t |
| c3 | 12 | 6.0 | PF 2.36 / 50t | PF 2.38 / 17t |
| c4 | 20 | 4.0 | PF 2.10 / 45t | PF 3.77 / 16t |
| c5 | **20** | **6.0** | **PF 2.61** / 42t | PF 2.50 / 16t |

Confirmed twice over: from the reports themselves and from `_mt5_auto/sweeps/SMOKE_BRK_XAU_H4_tuned.csv`,
which carries the identical twelve rows.

`Optimization=0` on every cell, so this does not appear in an `Optimization != 0` scan — but a 6-cell
grid followed by "pick one" **is** a selection, and the window it was picked on
(`2025.06.01→2026.06.01`) covers **five of the six holdout months**. The IS half is clean.

Note also: the `.ini` say `Period=H4` while the deployed `.set` comment says the EA hardcodes
`PERIOD_H1` and the `-Period` flag is inert. If that comment is right, the whole "H4" sweep in fact ran
H1. Nothing here depends on which is true — the cell-to-cell comparison is internally consistent
either way — but the file naming is actively misleading and anyone re-running this must resolve it first.

### 1.3 Reproducibility of the quoted numbers — **the finding**
The deployed config is **c0**: `IS 1.66 / OOS 3.85`.

The `.set` header claims **`IS 2.61 / OOS 3.92`**.

- `IS 2.61` is **c5** — Bars **20**, Tp **6.0**. A different bar count *and* a different TP.
- `OOS 3.92` is **c1** — Bars 8, Tp **6.0**.

So the two advertised numbers come from **two different cells, and neither is the cell that shipped**.
Both figures are individually real; the pairing is not. The effect is to advertise the best IS in the
grid next to the best OOS in the grid as though they described one config — a 57% overstatement of IS
(2.61 vs 1.66) on the leg a human is about to attach.

`DEMO_DEPLOYMENT_PLAN.md` line 71 and `PROJECT_STATE.md` line 303 both propagate the `3.92`.

### 1.4 Registry standing
- `PROJECT_STATE.md` §4 row 10: `EA_BREAKOUT_XAU (Bars8) | XAUUSD H1 | 991002 | 3.92 | 🟢 LIVE`.
- `portfolio/DEPLOYMENTS.csv` assigns **991002 to `(BRK)_TrendlineBreakout`** on 159503454, ACTIVE,
  EXPERIMENTAL. There is **no DEPLOYMENTS row for a Bars8 leg on any account.**

Two documents therefore disagree about what magic 991002 is. **Uncertain**, and it matters because
these are real-account rows. What would settle it: read the Inputs tab of every EA on 159503454 and
record `_01_BreakoutBars` per magic — the same live-screenshot method that corrected the CB row on
2026-07-24. This is adjacent to the open CR-002 v2/v3 question for 991001, not the same question.

---

## 2. `EA_SUPERTREND_XAU` — CONTAMINATED-SELECTION

### 2.1 What the README claims
> `Status: DEMO — user-approved 2026-07-11, PENDING_ATTACH on demo acct 415573666.`
> `WHY DEPLOY (fully validated XAU edge — best single-EA numbers in the lab)`
> `- Smoke (M2 full): XAU H4 PF 3.32 / 50t / DD 4.8%.`
> `- IS/OOS Model-4 (H4): IS PF 1.54 / 37t / DD 2.23% / Sharpe 1.10 ; OOS PF 4.49 / 18t / DD 4.94% / Sharpe 1.75 (OOS > IS = no overfit).`
> `- MC bootstrap (IS+OOS 55t): PF_5th 1.57, DD_95th 3.26%, Ruin 0% = PASS all gates.`

Deployed `.set` (only one): `ST_XAUUSD_H4_demo_v1.set` — ATR 10, Multiplier 3.0, SL 2.0×ATR,
EMA200 + ADX>20, flat 0.01, magic 990020.

### 2.2 What the evidence actually used
There is **no MT5 optimize pass for this EA on XAUUSD anywhere** — the only `Optimization!=0` ini for
`EA_SUPERTREND` is `OPT_ST_BTC_1.ini` (BTCUSD). The XAU parameters were picked from an 18-cell hand
grid, `Optimization=0`, Model 1: `ST085B_ATR{7,10,14}_M{2.5,3.0,3.5}_SL{1.5,2.0}`.

**Every one of those 18 cells ran `FromDate=2023.01.01 ToDate=2026.07.01`** — the entire 2026H1
holdout sits inside the window the winner was chosen on. Spot-checked: ATR10/M3.0/SL2.0 → PF 2.93;
ATR10/M3.0/SL1.5 → 2.90; ATR14/M3.0/SL2.0 → 3.08. The cells are close together, which is what makes
picking among them on holdout-inclusive data consequential rather than academic.

Evaluation runs on the winner:
- `ST_v1_H4_IS_M4.ini` — Model 4, `2023.01.01→2025.06.01` — clean.
- `ST_v1_H4_OOS_M4.ini` — Model 4, `2025.06.01→2026.06.01` — **five of six holdout months**.
- `SMOKE_ST_XAU_H4.ini` — Model 2, `2023.01.01→2026.06.01` — holdout-inclusive.

### 2.3 Reproducibility — and an omission that matters more than the windows
Every quoted number reproduces exactly:

| README claim | report | verified |
|---|---|---|
| Smoke M2 3.32 / 50t / DD 4.8% | `SMOKE_ST_XAU_H4.htm` | PF 3.32, 50t, eqDD 4.80% ✅ |
| IS M4 1.54 / 37t / DD 2.23% | `ST_v1_H4_IS_M4.htm` | PF 1.54, 37t, eqDD 2.23% ✅ |
| OOS M4 4.49 / 18t / DD 4.94% | `ST_v1_H4_OOS_M4.htm` | PF 4.49, 18t, eqDD 4.94% ✅ |

**But a BWD run exists and the README does not mention it.** `ST085B_BWD_2020_2022.htm`,
`2020.01.01→2022.12.31`, Model 1:

> **PF 0.88 · 64 trades · net −91.49 · eqDD 3.27%**

I diffed `ST085B_BWD_2020_2022.ini` against `ST_v1_H4_IS_M4.ini` input-by-input: **identical** —
ATR10 / ×3.0 / SL2.0 / EMA200 on / ADX 20 / lot 0.01 / magic 990020. Same config, same symbol, same
H4. So this is the deployed leg measured on the one three-year window that is genuinely out of
sample, and it comes back **below the 1.0 soft gate on 64 trades** — a healthier sample than the
18-trade OOS the README leads with.

Caveat kept: BWD is Model 1, IS/OOS are Model 4, so this is not a like-for-like model comparison and
the gap is not solely regime. That weakens how hard the 0.88 can be pushed; it does not explain a
README that reports two windows and silently drops the third. **A Model-4 BWD run on this config would
settle it** — it does not exist in `_mt5_auto/ini` today.

Second-order: the OOS 4.49 spans 12 months of which 5 are holdout, on 18 trades. `STV1_XAU_RECONF_OOS`
(same window, Model 2) gives 5.09 on 17 trades. The "OOS > IS = no overfit" argument is carried
almost entirely by that thin, partly-burned window.

### 2.4 Registry standing — **contradicted**
- `EA_SCORECARD_AND_REGISTRY.md` L193: `EA_SUPERTREND v1 naked | XAUUSD H4 | 1.92 (33t) | 5.09 (17t) | ★★☆ | **PARKED — แพ้ KER**`.
- `EA_MASTER_INDEX.csv`: `"EA_SUPERTREND v1 naked" … "PARKED"`.
- `portfolio/DEPLOYMENTS.csv`: `463666728 … EA_SUPERTREND, 990020, XAUUSDm, ACTIVE, DD 8%, judge 2026-10-16, start 2026-07-16, "SuperTrend validated IS1.54/OOS4.49; EA-SCORE #7 track"`.

So the README and DEPLOYMENTS say validated/active; the scorecard and master index both still say
PARKED. **Uncertain which is current** — the PARKED rows are dated 2026-07-02 and the demo attach is
2026-07-16, so the likeliest reading is that the two registry files were never updated at attach
(a Row-X checklist miss). What would settle it: whoever approved the 2026-07-11 deploy confirming
whether the KER comparison that produced "PARKED — แพ้ KER" was revisited, or simply bypassed.

---

## 3. `ST03_GBPUSD` — CLAIM-MISMATCH

### 3.1 What the README claims
> `EA_RUNNER_ST03 — GBPUSD H1 — LR2 winner @ 1x. Deploy bundle (built 2026-06-26)`
> `VALIDATION (Model 4 real-tick, GBPUSD H1)`
> `  IS  2024.01-03 : PF 8.31`
> `  OOS 2024.09-11 : PF 3.93  (no degradation)`
> `  Monte Carlo (229 calm trades): PF 5th 2.92, ruin 0% (but PF-range 20.5 = wide)`
> `  VERDICT: robustness MARGINAL  ->  DEPLOY SMALL + LIVE-MONITOR first 30 trades.`

Deployed `.set`: `ST03_GBPUSD_live_v1.set` (README designates it explicitly as
"validation set + `InpAllowLiveOrders=true`", validation set = `_mt5_auto/ST03_optimized_v2.set`).

### 3.2 What the evidence actually used — **windows are clean**
- `ST03_LR2_IS.ini` — Model 4, `Optimization=0`, `2024.01.01→2024.03.01`
- `ST03_LR2_OOS.ini` — Model 4, `Optimization=0`, `2024.09.01→2024.11.01`

Both entirely clear of 2026H1. The optimize passes on this expert are
`OPT_ST03GRID` (`Optimization=2`, `2023.01.01→2025.01.01`), `OPT_ST3G_IS` (`Optimization=1`, same
window) and `OPT_ST3PROBE` (`Optimization=1`, `2024.01.01→2024.07.01`) — all clean.

One optimize pass **is** contaminated: `OPT_ST3G_OOS.ini`, `Optimization=1`,
`2025.01.01→2026.06.01`. Its mtime is 2026-07-02, six days *after* this bundle was built, and it
belongs to the STEP-3 grid that closed the loop rather than to the config that shipped. It did not
feed this bundle. Recorded because it is a genuine optimize-on-holdout that ORDER-202 did not list.

### 3.3 Reproducibility — exact
| README | report | verified |
|---|---|---|
| IS 8.31 | `_archive/reports_pre_20260626/ST03_LR2_IS.htm` (2024.01.01–2024.03.01) | PF 8.31, 122t ✅ |
| OOS 3.93 | `_archive/reports_pre_20260626/ST03_LR2_OOS.htm` (2024.09.01–2024.11.01) | PF 3.93, 107t ✅ |

(Both reports live only in `_mt5_auto/_archive/reports_pre_20260626/`, not in the live reports dir.)

### 3.4 Registry standing — **the finding**
The numbers are real and the windows are clean. What is stale is the *conclusion*:

- `EA_SCORECARD_AND_REGISTRY.md` L186: `**LR2: M4 IS 8.31 / OOS 3.93** ⚠️ **superseded 2026-07-02: full-window OOS 2025.01–2026.06 M4 = PF 0.86 (585t) + STEP3 grid 48/48 combos OOS<1.0 → LOOP CLOSED … demo 990010 = WATCH เก็บ data.**`
- `PROJECT_STATE.md` §4 footnote: *"3.93 = คนละ window, ไม่ใช้เป็น baseline (verified 2026-07-02) … baseline เทียบ live ใช้ 0.86 … สถานะ = WATCH (ตัวเก็ง kill แรก)"*.
- Verified independently: `QWEN_ST03rep_OOS.htm`, `2025.01.01→2026.06.01`, Model 4 → **PF 0.86, 585 trades, net −96.28**.
- `portfolio/DEPLOYMENTS.csv`: `159475669 … ST03 replica, 990010, GBPUSD, **REMOVED** … user REMOVED from VPS 2026-07-18`.
- `AGENT_TASKBOARD.md` ORDER-118: `CLOSED-OBSOLETE … user ถอดตระกูล ST03 ออกจากบัญชีจริง`.

The README on disk still ends with "Copy this folder to the VPS … then enable AutoTrading", quoting
8.31/3.93 as the expectation to monitor against, for an EA the lab has since re-baselined to 0.86 and
the user has physically removed from the real account. Anyone attaching from this folder would monitor
against a number the project abandoned three weeks ago.

Note the direction of the error is not contamination — the 0.86 number is the one measured on a
*holdout-spanning* window, and it is the **worse** one. Nothing here is inflated by leakage.

---

## 4. `ZEUS_AUDJPY_REGIME` — CONTAMINATED-SELECTION

### 4.1 What the README claims
> `Status: DEMO-EXPERIMENT candidate (regime-rescue #1, lead 2026-07-16). NOT live-certified. AUDJPY-SPECIFIC. ⚠️ CARRIES A KNOWN WEAK YEAR (2023) — see CAVEAT. Deploy small.`
> `- Base (no gate) both-window FAILED: MAIN 1.12 / BWD 0.94. Range-only gate flips it.`
> `- Model-4 (real ticks) both-window plateau across ADX thr 20/25/30 …: thr20 1.63/1.28 · thr25 1.24/1.29 · thr30 1.30/1.52.`
> `- This bundle = thr25 + storm1.5 (best preset from the storm sweep): MAIN 1.35 / BWD 1.20, DD 14.0%/9.0% … Verified from THIS .set: PF 1.35 / net +1193 / 124t.`

Deployed `.set`: `ZeusAUDJPY_regime_demo_v1.set` (the only one), magic 990110.

### 4.2 What the evidence actually used
Every AUDJPY `.ini` for this expert carries `Optimization=0` — again a hand grid, not the optimizer.
The MAIN window used by **every selection cell** is `2023.01.01 → 2026.07.01`:

| family | what it swept | MAIN window | BWD window |
|---|---|---|---|
| `ZREG_AUDJPY_{base,m1t20,m1t25,m1t30,m2t20,m2t25,m2t30,m1rng25}` (M1) | regime mode × ADX threshold | `2023.01.01→2026.07.01` | 2020–2023 |
| `ZM4_m1rng{20,30}`, `ZC_m1rng25_M4` (M4) | the same lever on real ticks | `2023.01.01→2026.07.01` | 2020–2023 |
| `ZST_s{0,15,25}` (M4) | **the storm multiplier** | `2023.01.01→2026.07.01` | 2020–2023 |
| `ZBUNDLE_VERIFY` (M4) | the shipped `.set` | `2023.01.01→2026.07.01` | — |
| `ORDER166_990110_ZEUS_AUDJPY_MAIN` (M1) | later pinned re-check | `2023.01.01→2026.07.01` | 2020–2023 |

So the regime mode, the ADX threshold **and** the storm multiplier were each chosen on a window
containing all six holdout months, and the bundle's own verification run was too. This EA's entire
case is that a gate rescues a both-window-failing base — and the gate was tuned with the holdout visible.

### 4.3 Reproducibility — exact, and one structural note
| README | report | verified |
|---|---|---|
| base MAIN 1.12 / BWD 0.94 | `ZREG_AUDJPY_base_{MAIN,BWD}.htm` | 1.12 (186t) / 0.94 (235t) ✅ |
| thr20 1.63/1.28 | `ZM4_m1rng20_{MAIN,BWD}.htm` | 1.63 (230t) / 1.28 (119t) ✅ |
| thr25 1.24/1.29 | `ZC_m1rng25_M4_{MAIN,BWD}.htm` | 1.24 (134t) / 1.29 (172t) ✅ |
| thr30 1.30/1.52 | `ZM4_m1rng30_{MAIN,BWD}.htm` | 1.30 (145t) / 1.52 (129t) ✅ |
| shipped: 1.35 / +1193 / 124t, DD 14.0/9.0 | `ZST_s15_{MAIN,BWD}.htm` | PF 1.35, net 1 193.09, 124t, eqDD 13.97% / PF 1.20, 9.03% ✅ |

**A structural note the README's "best preset from the storm sweep" phrasing hides.**
`ZST_s0_MAIN` (storm off) and `ZST_s25_MAIN` (storm 2.5) return **byte-identical results**:
PF 1.24 / 134 trades / net 932.47 / eqDD 16.04% — and identical to `ZC_m1rng25_M4_MAIN`, the no-storm
baseline. Per the inert-axis gotcha this is not duplicate files: it means **the storm gate does
nothing at 0 and nothing at 2.5**, and the entire improvement 1.24 → 1.35 comes from the single value
1.5, which removes 10 trades. A three-point sweep with two identical points is a **1-of-2 distinct
outcomes pick, not a plateau**. Combined with the fact that the pick was made on holdout-inclusive
data, the storm=1.5 setting is the weakest link in this bundle.

I did not find a `ZST_s20` report, so the README's "lower DD than storm2.0" comparison is
**not reproducible** — the closest file, `ZST_s25`, is the inert one.

### 4.4 Registry standing
- `EA_SCORECARD_AND_REGISTRY.md` L198: `(Boss)_ZeusInspired_GridLog_rev01 | AUDUSD H1 … CANDIDATE — AUDUSD + AUDJPY confirmed via IS/OOS, portfolio not yet deployed`.
- `EA_MASTER_INDEX.csv`: `"ZeusInspired_GridLog standalone" … AUDJPY H1 … **"PARKED"** … "full3y 8x PF 1.12"` — that PF 1.12 is the **un-gated base**, so this row tracks the pre-graft lane, not this bundle.
- `AGENT_TASKBOARD.md` L2236: `regime-parked (Zeus AUDJPY/AUDUSD …): full-funnel แล้ว`.
- `DEPLOYMENTS.csv`: `415573666 … 990110, AUDJPYm, ACTIVE, closedDD 25%, judge 2026-10-16, start 2026-07-16`.

No contradiction of the README's own "DEMO-EXPERIMENT, not live-certified" framing. The defect is
the window, not the status line.

### 4.5 One adjacent contaminated optimize, flagged not concluded
`ZEUSINS_OPT_EURUSD_1.ini` — `Optimization=1`, `2023.01.01→2026.07.01`, EURUSD H1, mtime 2026-07-10.
This is the **only** true optimizer pass on this expert and it is contaminated. It is EURUSD, and the
AUDJPY grid geometry (dist 2.2×ATR, base 0.16, 6 legs, basket TP $240) traces to the earlier `ZIGL_*`
work, so I have **not** established that it fed the AUDJPY bundle — **uncertain**. What would settle
it: diff the winning parameter row inside that optimize's XML against `ZeusAUDJPY_regime_demo_v1.set`.

---

## 5. `ICHIADX_XAU` — CONTAMINATED-SELECTION

### 5.1 What the README claims
> `Status: DEMO-ELIGIBLE — real both-window edge, 2-leg basket = 6/6 years positive, MC PF_5th 1.544 (robust, NOT thin). APPROVED for demo (user "เอาเข้าทั้งหมด").`
> `LEG A: XAUUSD H1 Magic 990068 … full-window PF 1.57 / 236t / Sharpe 3.0`
> `LEG B: XAUUSD H4 Magic 990069 … full-window PF 2.85 / 97t / Sharpe 2.76`
> `MERGED (both @0.10, chronological, Model-4 2020-2026, 333 trades): Combined PF 2.143 | net +$22,407 | TRUE max-DD 10.5% | ALL 6 years net-positive.`
> `BOTH-WINDOW Model-4 (slow periods): MAIN(2023-26) 1.66 / BWD(2020-22) 1.39. medH4 config was even higher (3.94/1.25)…`

Both `.set` in the bundle are designated deployed: `IchiADX_XAUUSD_H1_slow.set` (leg A, 20/60/120,
magic 990068) and `IchiADX_XAUUSD_H4_med.set` (leg B, 12/34/68, magic 990069). The README says leg B
is the second leg of the basket the MC number describes, so both ship.

### 5.2 What the evidence actually used
`(EXP)_IchiADX_Naked_rev00` has **78 ini and not one with `Optimization != 0`** — there is no optimizer
pass anywhere in this EA's record. Selection was entirely by hand grid.

- Period-lever selection (`KUMO_{def,fast,med,slow}_{H1,H4}_MAIN`, Model 4) —
  **`2023.01.01 → 2026.07.01`**, i.e. the "6/8 cells >1.1" plateau that chose 20/60/120 and 12/34/68
  was measured with the whole holdout inside. (Its BWD partners are clean 2020–2023.)
- XAU both-window (`MH_XAUUSD_{slowH1,medH4}_MAIN`, Model 4) — **`2023.01.01 → 2026.07.01`**.
- Headline full-span (`CORR_ICHI_XAU`, `CORR_ICHI_XAU_medH4`, Model 4) —
  **`2020.01.01 → 2026.07.01`**.
- Year-splits `XAUYS_*` stop at 2026.01.01 and are clean; the README's "6 years positive" claim is
  built from those and is the soundest part of the case.

The README is not hiding this — it literally writes `MAIN(2023-26)`. But "MAIN" in this repo is pinned
to 2023.01–2025.12 and must not touch the holdout, so a reader taking the label at face value will
believe this cleared the standard gate. It did not.

### 5.3 Reproducibility — exact
| README | report | verified |
|---|---|---|
| slow-H1 full 1.57 / 236t | `CORR_ICHI_XAU.htm` (2020.01.01–2026.07.01) | PF 1.57, 236t, net 7 038.03 ✅ |
| med-H4 full 2.85 / 97t | `CORR_ICHI_XAU_medH4.htm` (same span) | PF 2.85, 97t, net 14 159.87 ✅ |
| slow MAIN 1.66 / BWD 1.39 | `MH_XAUUSD_slowH1_{MAIN,BWD}.htm` | 1.66 (126t) / 1.39 (110t) ✅ |
| medH4 3.94 / 1.25 | `MH_XAUUSD_medH4_{MAIN,BWD}.htm` | 3.94 (47t) / 1.25 (50t) ✅ |
| merged 333 trades | 236 + 97 | arithmetic consistent ✅ |

The merged PF 2.143, max-DD 10.5% and MC PF_5th 1.544 come from `_mt5_auto/xau_basket_merge_mc.ps1`
operating on those two deal sequences. I did not re-run the script — **the MC figure is therefore
unverified**, and it inherits the holdout from its inputs regardless.

The **BWD numbers are clean and are the strongest thing in this bundle**: slow-H1 1.39 on 110 trades,
med-H4 1.25 on 50. Contamination inflates, so those are not at risk. What is at risk is the *choice*
of 20/60/120 and 12/34/68 over the other six cells.

### 5.4 Registry standing — **no row exists**
Grep of `EA_SCORECARD_AND_REGISTRY.md` for `IchiADX` / `Ichimoku` / `ICHI`: **zero hits.**
Grep of `EA_MASTER_INDEX.csv`: **zero hits.**

`DEPLOYMENTS.csv` does carry both legs (`463666728 … 990068 XAUUSDm ACTIVE DD 18% judge 2027-02-11`,
`990069` likewise), and `AGENT_TASKBOARD.md` L2290 records the bundle. So the EA is deployed and
tracked operationally but has **never been written into the registry** — meaning the README's
"DEMO-ELIGIBLE" has nothing to be checked against, and a downgrade could not be recorded even if
someone wanted to. That is the Row-X write-checklist unfulfilled, and it is why this defect survived
the 2026-07-25 sweep: the sweep corrected registry rows, and there was no row.

---

## 6. `ICHIADX_USDJPY_BASKET` — CONTAMINATED-SELECTION

### 6.1 What the README claims
> `Status: DEMO-ONLY data-collection candidate … Positive-expectancy both-window + MC-survive, but THIN (MC PF_5th 1.036) => demo cohort to collect forward data, NOT a strong live leg. *** APPROVED for demo cohort by user 2026-07-16B; pending user attach. ***`
> `MERGED equity (both @0.10, chronological, Model-4 real ticks, 2020-2026, 357 trades): Combined PF 1.339 | net +$1,955 | TRUE max-DD 6.09%`
> `MONTE CARLO (2000 resamples of the 357-trade combined sequence): PF_5th = 1.036 | DD_95th = 10.77% | Ruin = 0%.`
> `- ORDER-112 overturned "EA_ICHIMOKU DEAD 2026-06-27" … With the Kumo-PERIOD lever swept, a real both-window Model-4 plateau appears (6/8 cells >1.1).`

Both `.set` deployed: `IchiADX_USDJPY_H4_med_leg_A.set` (990066) and
`IchiADX_USDJPY_H1_slow_leg_B.set` (990067). README is explicit: *"Deploy the PAIR or not at all."*

### 6.2 What the evidence actually used
Same expert, same absence of any `Optimization != 0` pass.

- The **"6/8 cells >1.1" plateau** = `KUMO_{def,fast,med,slow}_{H1,H4}_MAIN`, Model 4,
  **`2023.01.01 → 2026.07.01`** — the selection that both this bundle and ICHIADX_XAU rest on, made
  with the full holdout visible. BWD partners (2020–2023) clean.
- Headline merged evidence: `BASKET_medH4_FULL.ini` / `BASKET_slowH1_FULL.ini`, Model 4,
  **`2020.01.01 → 2026.07.01`** — holdout inside.
- Year-splits `YS_*` stop at 2026.01.01 — clean.
- Earlier probe/IS/OOS work (`IchiADX_JPYprobe_p1..p5`, `IchiADX_USDJPY_IS`, `_OOS`) is clean:
  `2023.01.01→2025.06.01` and `2025.06.01→2026.01.01`.

### 6.3 Reproducibility
| README | report | verified |
|---|---|---|
| 357 combined trades | `BASKET_medH4_FULL.htm` 127t + `BASKET_slowH1_FULL.htm` 230t | 357 ✅ |
| leg PFs (not printed individually) | 1.44 (medH4) / 1.28 (slowH1) | recorded here for the file |
| Combined PF 1.339, net +$1,955, max-DD 6.09% | merge script `_mt5_auto/ichi_basket_merge_mc.ps1` | **not verified** — script not re-run |
| MC PF_5th 1.036, DD_95th 10.77%, ruin 0% | same script | **not verified** — script not re-run |

The two per-leg full-span runs are real and reproduce. **The two numbers the entire "thin but
positive" case turns on — combined PF 1.339 and MC PF_5th 1.036 — are script outputs I could not
confirm without running the merge**, and they are computed over a deal sequence that includes 2026H1.
At PF_5th 1.036 the margin above 1.0 is 3.6%; six months of holdout inside a 78-month span is easily
enough to be the whole margin. **Uncertain, and cheap to settle:** re-run `ichi_basket_merge_mc.ps1`
with the deal lists truncated at 2025.12.31.

### 6.4 Registry standing
As with ICHIADX_XAU: **no scorecard row, no master-index row.** `DEPLOYMENTS.csv` carries
990066 and 990067 (ACTIVE, DD 12%, judge 2027-01-23, start 2026-07-16); `AGENT_TASKBOARD.md` L2279
records the bundle. Same Row-X gap, same reason the 2026-07-25 sweep could not have caught it.

---

## 7. `CB_EUR` — CLAIM-MISMATCH

### 7.1 What the README claims
> `VPS DEPLOY — (Boss)_LondonConsoBreakout_rev01 on EURUSD H1  (2026-06-22)`
> `STATUS: ⚠️ CONDITIONAL — deploy with close monitoring (see risk note)`
> `PERFORMANCE SUMMARY:`
> `  IS  2023-2025.06 : PF 2.09, 66 trades, DD 0.13%`
> `  OOS 2025.06-2026 : PF 1.25, 33 trades`
> `  OOS 2020-2022    : PF 0.86, 90 trades  ← FAILS (EUR bear 2022 crash)`
> `  FULL 2020-2026   : PF 1.26, 189 trades`
> `COMPARE TO CB_GBP: … CB_EUR: 2/3 OOS pass, keep at 0.01 lot, review monthly`

Deployed `.set`: `CB_EUR_H1_live_v1.set` (only one), magic 990005.

### 7.2 What the evidence actually used
- **Selection is clean.** `CB_OPT_EUR_H1.ini` — `Optimization=1`, Model 2,
  **`2023.01.01 → 2025.06.01`**. Six months clear of the holdout on the upper bound.
- Evaluation: `CB_EUR_H1_IS` (2023.01.01–2025.06.01, clean) · `CB_EUR_H1_OOS2020`
  (2020.01.01–2022.12.31, clean) · **`CB_EUR_H1_OOS1` (2025.06.01–2026.06.01)** and
  `CB_EUR_H1_FULL` (2020.01.01–2026.06.01) — both reach five months into 2026H1.

Worth stating plainly: this is the **only** bundle in the group whose parameters were picked by the
actual optimizer on a window that respects the holdout. The window story here is the good one.

### 7.3 Reproducibility — exact, from archived reports
The live `_mt5_auto/reports/` directory contains **no** `CB_*` reports. They survive only in
`_mt5_auto/_archive/reports_pre_20260626/`:

| README | report | verified |
|---|---|---|
| IS 2.09 / 66t / DD 0.13% | `CB_EUR_H1_IS.htm` | PF 2.09, 66t, eqDD 0.13% ✅ |
| OOS1 1.25 / 33t | `CB_EUR_H1_OOS1.htm` | PF 1.25, 33t ✅ |
| OOS2020 0.86 / 90t | `CB_EUR_H1_OOS2020.htm` | PF 0.86, 90t ✅ |
| FULL 1.26 / 189t | `CB_EUR_H1_FULL.htm` | PF 1.26, 189t ✅ |

All four exact. Nothing overstated.

### 7.4 Registry standing — **the finding**
`EA_SCORECARD_AND_REGISTRY.md` L163:

> `| LondonConsoBreakout | EURUSD H1 | 1.25 | 0.13 | ★★★ | **DROP (was #8)** | Q2 rescue sweep (48 combo×3 win) DONE — NO combo passes all 3 at PF≥1.2; best min-PF 0.92, both OOS <1.0. No durable edge → remove from portfolio |`

`PROJECT_STATE.md` §4: *"(#8 CB_EUR EURUSD = ❌ DROPPED 2026-06-25, no durable edge…)"*.

The bundle README is dated 2026-06-22; the DROP is 2026-06-25. **A rescue sweep of 48 combinations
ran after this README was written, failed, and the leg was removed from the portfolio — and the
README on disk still says "CONDITIONAL — deploy with close monitoring" with a step-by-step VPS attach
procedure.** That is the exact defect this audit was commissioned to find: the registry moved, the
file a human reads at attach time did not.

A second, softer mismatch in the same file: the header banner above the scorecard table records
`Gold Reaper + LondonConso = แล็บ REJECT (ยังรันอยู่บน 159475669 เป็นการทดลองของ user เท่านั้น แล็บไม่รับรอง)`,
and `DEPLOYMENTS.csv` shows `(Boss)_LondonConsoBreakout_rev01, 990005, **EURUSDc**, ACTIVE` on the real
account 159475669 — *"user mix; lab does not certify"*. So a EURUSD leg of this EA is live on real
money under a user-owned decision while the lab's own standing for EURUSD is DROP. Not this bundle's
doing, but anyone reading this README would not learn it.

---

## 8. `SMCSTO_EURUSD` — HOLDOUT-SPENT

### 8.1 What the README claims
> `Status: DEMO-ELIGIBLE (lead PASS 2026-07-16). NOT live-certified. EURUSD-SPECIFIC.`
> `WHY DEPLOY (full funnel cleared — EURUSD only)`
> `- Plateau (Model-1 both-window): 6/7 one-param neighbors hold both windows …`
> `- Model-4 real ticks (center): MAIN 1.39 / BWD 1.19 / HOLDOUT 2026H1 1.14 — all 3 windows > 1.0, edge survives real ticks`

Deployed `.set`: `SMCSTO_EURUSD_H1_demo_v1.set` (only one), magic 991070.

### 8.2 What the evidence actually used
`EmaStoRev` was already **cleared by ORDER-202** and this pass confirms it independently:

- All six optimize passes (`O107opt_*`, `O107adx_*`) are `Optimization=2` with
  `2023.01.01 → **2026.01.01**` — the zero-2026-deals boundary. **Selection is clean.**
- The plateau/fan runs (`O107pl_*`) sit on MAIN `2023.01.01→2025.12.31` / BWD `2020.01.01→2022.12.31`. Clean.
- `O107m4_EUR_MAIN` `2023.01.01→2026.01.01` · `O107m4_EUR_BWD` `2020.01.01→2023.01.01` — clean.
- **`O107m4_EUR_HOLDOUT` — `2026.01.01 → 2026.07.01`.** The full holdout, deliberately run.

### 8.3 Reproducibility — exact
| README | report | verified |
|---|---|---|
| MAIN 1.39 | `O107m4_EUR_MAIN.htm` | PF 1.39, 136t ✅ |
| BWD 1.19 | `O107m4_EUR_BWD.htm` | PF 1.19, 130t ✅ |
| HOLDOUT 1.14 | `O107m4_EUR_HOLDOUT.htm` | PF 1.14, 30t ✅ |

### 8.4 Why this is HOLDOUT-SPENT rather than clean
The 2026H1 run is not incidental — the README **counts it as one of the three windows that clear the
bar** ("all 3 windows > 1.0"). The holdout was consumed *as a pass*, which is the stronger form of
spending it: an EA promoted on the strength of a holdout number cannot later use that window as
independent evidence. Its genuine forward evidence starts at the 2026-07-16 demo attach, same
disposition as Boss_16 and the Boss_14 cohort. This is a labelling/policy item, not a re-optimize.

### 8.5 Registry standing — softer mismatch, worth recording
The README says **"full funnel cleared"**. What the registry says now:

- `EA_MASTER_INDEX.csv`: `"SMCxSTO (EmaStoRev)" … **"DEMO — marginal edge, SL-fragile"** … "both-window pass at center but SL fan fragile"`.
- `DEPLOYMENTS.csv`: `991070 … "SMCSTO EURUSD ADX-filter **WEAK candidate**; fan 2026-07-18 center 1.39/1.19 both-window but **SL-FRAGILE**"`.
- `AGENT_TASKBOARD.md` ORDER-LANEC-FAN, 2026-07-18: `**WEAK candidate — edge-positive but SL-fragile.** 26 M4 runs. center 1.39/1.19 both-window; 5/6 axes robust`.

So a sensitivity fan run **two days after** the README found the SL axis fragile and the registry
downgraded the wording accordingly; the README still reads "full funnel cleared". Milder than CB_EUR
(the EA was not dropped, and the headline numbers still stand), but it is the same failure mode and
belongs on the list.

---

## 9. `CB_GBP` — HOLDOUT-SPENT

### 9.1 What the README claims
> `VPS DEPLOY — (Boss)_LondonConsoBreakout_rev01 on GBPUSD H1  (2026-06-22)`
> `STATUS: Demo/paper first — see RISK note below before going live.`
> `PERFORMANCE SUMMARY:`
> `  IS  2023-2025.06 : PF 1.96, 41 trades, DD 0.10%`
> `  OOS 2025.06-2026 : PF 2.08, 16 trades  ← thin, watch closely`
> `  OOS 2020-2022    : PF 1.25, 45 trades`
> `  MC 5th pct PF   : ~1.10  (passes gate)`
> `  - Promote to full live only after ≥30 real trades confirm PF ≥ 1.40.`

Deployed `.set`: `CB_GBP_H1_live_v1.set` (only one), magic 990005.

### 9.2 What the evidence actually used
- **Selection clean:** `CB_OPT_GBP_H1.ini` — `Optimization=1`, Model 2, `2023.01.01 → 2025.06.01`.
- `CB_GBP_H1_IS_verify` (2023.01.01–2025.06.01) and `CB_GBP_H1_OOS2020` (2020.01.01–2022.12.31) — clean.
- **`CB_GBP_H1_OOS1` — `2025.06.01 → 2026.06.01`** and `CB_GBP_H1_FULL` — `2020.01.01→2026.06.01`:
  both reach five months into the holdout.

The "3/3 OOS pass" that separates CB_GBP from the dropped CB_EUR depends on OOS1, and OOS1 is the
holdout-spanning one. It is also 16 trades.

### 9.3 Reproducibility — exact, but with a provenance wrinkle worth naming
| README | report | verified |
|---|---|---|
| IS 1.96 / 41t / DD 0.10% | `_archive/…/CB_GBP_H1_IS_verify.htm` | PF 1.96, 41t, eqDD 0.10% ✅ |
| OOS1 2.08 / 16t | `_archive/…/CB_GBP_H1_OOS1.htm` | PF 2.08, 16t ✅ |
| OOS2020 1.25 / 45t | `_archive/…/CB_GBP_H1_OOS2020.htm` | PF 1.25, 45t ✅ |
| MC 5th ~1.10 | — | **not found** — no MC artefact located for CB_GBP |

The wrinkle: there are **two** IS reports for the same window. `CB_GBP_H1_IS.htm` gives
**PF 1.19 on 68 trades**; `CB_GBP_H1_IS_verify.htm` gives **PF 1.96 on 41 trades**. Same expert, same
symbol, same `2023.01.01–2025.06.01`. Different trade counts mean different inputs, not a re-run — so
these are two configs, and the README quotes the better one. That is legitimate if `_verify` is the
config that shipped, and the name suggests it is, but the pairing is not self-documenting: a reader
grepping `CB_GBP_H1_IS` finds 1.19 and concludes the README is wrong. **Uncertain which config
`CB_GBP_H1_IS.htm` holds** — settled by diffing the `[TesterInputs]` blocks of `CB_GBP_H1_IS.ini` and
`CB_GBP_H1_IS_verify.ini` against `CB_GBP_H1_live_v1.set`, which I did not do.

### 9.4 Registry standing — consistent
`EA_SCORECARD_AND_REGISTRY.md` L162: `LondonConsoBreakout | GBPUSD H1 | 2.08 | 0.10 | ★★★ | **CANDIDATE** | 3/3 OOS; GBP concentration`.
`PROJECT_STATE.md` §4 row 7: `LondonConsoBreakout | GBPUSD H1 | 990005 | 2.08 | 🟢 LIVE`.
No downgrade to flag. Note the registry's headline `2.08` **is** the holdout-spanning OOS1 figure.

Separately, `DEPLOYMENTS.csv` records a GBPUSDc leg on real account 159475669 under magic
**99000512** (not 990005), added 2026-07-24 from a live Inputs-tab screenshot, tagged
*"user mix - lab does not certify"*. The README's flat assertion `Magic=990005 (same as CB_GBP…) NO conflict`
does not describe what is actually on that account.

---

## 10. `RSI_MR_EURUSD` — HOLDOUT-SPENT

### 10.1 What the README claims
> `RSI-MR (Boss)_RSI_MR_GridLog_rev01 -- DEMO-ISOLATE bundle. Prepared: 2026-07-23`
> `  Window          PF      Trades   DD%`
> `  MAIN 2023-25    1.96    216      4.99`
> `  BWD  2020-22    1.56    199      5.48`
> `  Flat-lot MAIN   1.33    163      1.57`
> `  Flat-lot BWD    0.82    159      4.12`
> `  HOLDOUT 2026H1: PF 0.76, n=21 trades -- FAILS the >=1.0 bar. … This is the one gate the VERDICT GATE tree does not let pass … It is NOT a validated CANDIDATE.`
> `VERDICT: BUILD-ON, not CANDIDATE.`

Deployed `.set`: `RSIMR_EURUSD_H1_demo_v1.set`, designated in the README as locked and regenerable
from `_mt5_auto/ab_sets/rsimr_fan/RSIMR_CENTER.set` (sole difference `_07_AllowLive=true`).

### 10.2 What the evidence actually used
**No `Optimization != 0` ini exists for this expert at all.** Selection was by hand grid — but, unlike
the other five hand-grid bundles here, this one **kept the holdout out of the grid**:

- Lever grid `RSIMR_L2_RSI{25,30,35}_{...}_SL{15,25,35}` — 9 cells × {MAIN, BWD}, where
  MAIN = `2023.01.01 → **2026.01.01**` (zero-2026-deals boundary) and BWD = `2020.01.01→2023.01.01`.
  **Clean selection.**
- Continuity check `RSIMR_CONT_{ESCALATED_LOG5,FLATLOT}_{MAIN,BWD}` — same clean windows.
- **`RSIMR_L2_RSI25_75_SL25_HOLDOUT` — `2026.01.01 → 2026.07.01`**, run on the winner only, after the
  fact. Same for `RSIMR_CONT_ESCALATED_LOG5_HOLDOUT`.

That is the correct shape — grid on MAIN+BWD, single confirmation run on the holdout — and it is
worth naming as the counter-example to the other bundles rather than leaving it implicit.

### 10.3 Reproducibility — exact, every figure
| README | report | verified |
|---|---|---|
| MAIN 1.96 / 216t / 4.99% | `RSIMR_L2_RSI25_75_SL25_MAIN.htm` (2023.01.01–2026.01.01) | PF 1.96, 216t, eqDD 4.99% ✅ |
| BWD 1.56 / 199t / 5.48% | `RSIMR_L2_RSI25_75_SL25_BWD.htm` | PF 1.56, 199t, eqDD 5.48% ✅ |
| HOLDOUT 0.76 / 21t | `RSIMR_L2_RSI25_75_SL25_HOLDOUT.htm` | PF 0.76, 21t, net −60.75 ✅ |
| Flat-lot MAIN 1.33 / 163t / 1.57% | `RSIMR_CONT_FLATLOT_MAIN.htm` | PF 1.33, 163t, eqDD 1.57% ✅ |
| Flat-lot BWD 0.82 / 159t / 4.12% | `RSIMR_CONT_FLATLOT_BWD.htm` | PF 0.82, 159t, eqDD 4.12% ✅ |
| prior baseline holdout 0.73 / n=26 | `RSIMR_CONT_ESCALATED_LOG5_HOLDOUT.htm` | PF 0.73, 26t ✅ |
| MC PF-5th MAIN 1.544 / BWD 1.209, ruin 0% | — | **not verified** — MC artefact not located |

### 10.4 Why HOLDOUT-SPENT and not CLEAN
2026H1 was run, twice, on two different configs, and the result determined the verdict — it is the
stated reason this is BUILD-ON rather than CANDIDATE. The window is used up either way: an EA cannot
later be promoted on a holdout it has already read. The distinction from the bundles above is that
here the holdout **argued against** the EA and the README says so in bold, so nothing is overstated
and nothing needs correcting. It is a policy label only: this EA's independent forward evidence begins
at the 2026-07-24 demo attach.

### 10.5 Registry standing — consistent, the best-documented bundle in the group
- `EA_SCORECARD_AND_REGISTRY.md` L182: `🟢 **ACTIVE demo (attached 2026-07-24, user confirmed) — 463666728 EURUSDm, judge 2026-10-24**`, with the holdout failure, the flat-lot BWD 0.82, and the 98/182-day basket-duration tail all recorded in the row.
- `EA_MASTER_INDEX.csv` L134: matching `ACTIVE demo … judge 2026-10-24`.
- `DEPLOYMENTS.csv`: two rows — the REMOVED real-account row (159503454, closed-DD 25% trip, 2026-07-18) and the ACTIVE demo-isolate row (463666728, 2026-07-24).

The README's own unresolved `[HEDGE]` flag (account margin mode unconfirmed) is a live pre-attach item
but is outside this audit's scope.

---

## Cross-cutting observations

**1. The `Optimization` flag under-counts selection by roughly 6:1 in this group.**
ORDER-202's scan found 87 contaminated optimize passes across 6,467 ini. In these ten bundles the
optimizer was used for exactly **three** configs (CB_EUR, CB_GBP, SMCSTO) — and all three respected
the holdout. Every contamination found here came from hand-rolled `Optimization=0` grids:
ST085B (18 cells), ZREG/ZM4/ZST (11+), KUMO (8), BRKXAUH4 (6). **A repeat of the ORDER-202 scan keyed
on `Optimization != 0` would return all ten of these bundles as clean.** Any future retro-scan needs
to detect *families of ini differing only in inputs, sharing one window* — the grid signature — not
just the optimizer flag.

**2. Two bundles are deployed with no registry row at all.**
`ICHIADX_XAU` and `ICHIADX_USDJPY_BASKET` are ACTIVE on 463666728 with four magics between them, and
appear in neither `EA_SCORECARD_AND_REGISTRY.md` nor `EA_MASTER_INDEX.csv`. This is why the
2026-07-25 evidence-integrity sweep could not have reached them: it corrected registry rows, and there
were none. A bundle with no row cannot be downgraded, so its README is permanently self-certifying.

**3. `2025.06.01 → 2026.06.01` is a recurring, undeclared holdout-eater.**
It appears as the designated "OOS" in CB_EUR, CB_GBP, EA_SUPERTREND_XAU and BRK_XAU_Bars8 — four of
ten. It reads as clean out-of-sample ("2025-2026") and is five-sixths of the holdout. Everything
labelled OOS on that window across the repo is suspect for the same reason.

**4. Three READMEs advertise a status the registry has since withdrawn** — CB_EUR (DROP),
ST03_GBPUSD (superseded to 0.86, removed from the real account), EA_SUPERTREND_XAU (PARKED in two
registry files while DEPLOYMENTS says ACTIVE). SMCSTO is a fourth in milder form. None of the four
bundle files carries any pointer back to the registry, so nothing on disk would ever tell a human at
attach time to go and check.

**5. One number in this group is not merely stale but wrong** — `BRK_XAU_Bars8`'s spliced
`IS 2.61 / OOS 3.92`. Every other quoted figure across all ten bundles reproduced to the decimal from
a surviving report. That is a genuinely good hit rate for provenance, and it makes the single splice
easier to trust as an isolated transcription error rather than a pattern.

## Not done, and what would close it
- **No run was launched** (read-only remit). The three numbers I could not verify are all script
  outputs: the two IchiADX merge/MC figures and the RSI-MR MC. Re-running
  `_mt5_auto/ichi_basket_merge_mc.ps1` and `xau_basket_merge_mc.ps1` with deals truncated at
  2025.12.31 would both verify them and strip the holdout out of them in one pass.
- **The EA_SUPERTREND BWD gap** is one missing run: Model-4, `2020.01.01→2022.12.31`, the deployed
  `.set`, to sit beside the Model-1 0.88 and establish whether the deficit is regime or model.
- **The BRK_XAU_Bars8 magic conflict (991002)** and the **CB_GBP dual-IS-report ambiguity** are both
  desk checks, not runs — a live Inputs-tab read and an `.ini` input diff respectively.
