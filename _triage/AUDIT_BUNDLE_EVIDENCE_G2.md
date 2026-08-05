# AUDIT — bundle README vs. actual evidence, group 2 (12 bundles)

**Scope.** The 12 `_vps_deploy` bundles NOT covered by `_triage/ORDER202_HOLDOUT_CONTAMINATION_RETROSCAN.md`.
Read-only forensic pass. No tester run, no verdict issued — evidence only.

**Method.** Parsed `Expert/Symbol/Period/Model/Optimization/FromDate/ToDate` out of all 6,600
`.ini` under `_mt5_auto\ini` into one table, matched each bundle's designated `.set` against the
`.ini` that actually produced the README's numbers, then re-read the numbers out of the
UTF-16LE `.htm` reports (`iconv -f UTF-16LE`) and the sweep CSVs.

**Boundary convention inherited from ORDER-202 (kept, not re-litigated):** `ToDate=2026.01.01`
produces zero 2026 deals and is NOT contamination. `ToDate=2026.06.01` / `2026.07.01` is inside
2026H1 and is.

**One extension I had to make, stated plainly.** The brief's test for CONTAMINATED SELECTION is
`Optimization != 0`. **Zero of these 12 bundles used the MT5 optimizer at all.** The Wave5 family
instead ran a hand-rolled grid of `Optimization=0` single passes (one `.ini` per cell), compared the
cells in a CSV, and picked a plateau centre. Mechanically the flag is 0; substantively the parameter
was chosen by ranking cells scored on a window containing 2026H1. I have labelled that
CONTAMINATED-SELECTION and said so explicitly in each section, because the flag would otherwise
launder a real selection through a technicality. The distinction the brief asks me to keep — values
clean vs. parameters chosen with the answer visible — is preserved: for Wave5 the parameters *were*
chosen with the answer visible.

---

## Summary table (most serious first)

| # | bundle | label | one-sentence justification |
|---|---|---|---|
| 1 | **WAVE5_USDJPY** | **CONTAMINATED-SELECTION** | The deployed cell (`EntryFib 38.2 / Wave3MinMult 1.618`) was picked as the winner of a 12-cell `W5OPT_*` grid whose every MAIN run ran `2023.01.01 → 2026.07.01`, so six months of the 2026H1 holdout sat inside the selection window. |
| 2 | **WAVE5_XAU** | **CONTAMINATED-SELECTION** | The "plateau-centre fib23.6/mult0.618" was selected off the `EXT_XAU_*` grid, all of whose MAIN cells ran to `2026.07.01`; separately, the only run of the exact deployed `.set` (ORDER-166) returns **1.08 / 1.06**, not the README's 1.11 / 1.11. |
| 3 | **WAVE5_XAG** | **CONTAMINATED-SELECTION** | Same defect: the "all 6 cells pass" mini-grid (`XAGMG_*`) scored MAIN on `2023.01.01 → 2026.07.01`, and the ORDER-166 re-run of the deployed `.set` gives **1.33 / 1.24** against the README's 1.35 / 1.29. |
| 4 | **CRYPTO_TRENDRIDER** | **CLAIM-MISMATCH** | Both deployed `.set` files ship `_06_AllowLive=false` — the EA cannot trade on a live chart — while `DEPLOYMENTS.csv` has carried both legs as ACTIVE since 2026-07-23; the README also labels the whole evidence block "Model-4 real ticks 99%" when the two snowball figures it quotes (2.22 / 2.52) come from **Model-1** runs. |
| 5 | **EA_BREAKOUT_US30** | **CLAIM-MISMATCH** | README headline "MAIN(2023-26) PF 1.46" was measured on a window ending `2026.07.01`; the clean-window re-run that already exists in the repo (`O159_991005`, `2023.01.01 → 2025.12.31`) gives **PF 1.21 / 32 trades** — the bundle advertises a number 0.25 PF above what clean data supports, on a leg its own README already calls thin. |
| 6 | **EXP_ADAPTGRIDMC** | **CLAIM-MISMATCH** | The bundle sits in the attach surface with **no README, no `.ex5`**, two `.set` carrying `AllowLive=false` and magic 992007 — an EA the registry records as `DEAD-STRUCTURAL (static-zone), PARKED pending redesign` with a proven-zero-trade 2026H1 holdout. |
| 7 | **EA_BREAKOUT_USDJPY** | **HOLDOUT-SPENT** | `Optimization=0` throughout and no parameters were tuned (compiled defaults), but the README's ship-decision numbers (1.28 / 102t) were measured on `2023.01.01 → 2026.07.01`, consuming 2026H1; the clean re-run is *better* (1.41 / 65t), so nothing is inflated. |
| 8 | **SS1_LONDONORB_XAU** | **CLEAN** | All selection runs stop at `2025.12.31`, the holdout was run once as a genuine holdout (`2026.01.01 → 2026.06.30`), the README discloses that 2026H1 was already partly burned at cohort level, and every quoted number reproduces exactly. |
| 9 | **PIVOTBREAKOUT_XAU** | **CLEAN** | Selection (`GPB_*`/`PVC_*` fan) ends `2025.12.31`, holdout run separately at `2026.01.01 → 2026.06.30`, and Model-4 1.16 / 1.22 / 1.33 at n=231/200/35 reproduce to the digit. |
| 10 | **W2_S1_TRENDRIDER_XAU** | **CLEAN** | 27-cell ladder and M4 confirm all end `2025.12.31`, holdout run once, and the README explicitly declares 2026H1 burned for this EA with demo-forward as the next holdout — exactly the disclosure the policy asks for. |
| 11 | **S2_TSMOM_XAU** | **CLEAN** | Every `S2SW_*`/`S2AX_*` cell runs `2023.01.01 → 2025.12.31` or `2020.01.01 → 2022.12.31`; no 2026 run exists at all, and the README states outright that the funnel is incomplete and that BWD 0.70 is a known accepted weakness. |
| 12 | **PAIRSPREAD_STATARB** | **CLEAN** | The funnel never touches 2026H1 (MAIN stops at the `2026.01.01` zero-deal boundary), the holdout is a genuinely independent 2017-2019 window, and 1.14 / 1.15 / 1.23 all reproduce from `O098G_x03_*` / `O098H_x03_HLD`. |

**Counts — CONTAMINATED-SELECTION 3 · CLAIM-MISMATCH 3 · HOLDOUT-SPENT 1 · CLEAN 5 · NO-EVIDENCE-FOUND 0.**

None of the 12 was downgraded by the 2026-07-25 evidence-integrity sweep
(`HANDOFF_2026-07-25C_EVIDENCE_INTEGRITY_SWEEP.md` §3 touches 991001, MacroGate, Gold Reaper,
MatchaGrid, MacdDiv, Boss_16 — no overlap with this group), so no README here is advertising a
verdict that was formally withdrawn. The mismatches found are of a different kind: numbers measured
on the wrong window, an evidence class mislabelled, a live gate left shut, and a bundle staged for a
dead EA.

---

## 1. WAVE5_USDJPY — CONTAMINATED-SELECTION

**Designated deployed set:** `WAVE5_USDJPY_H1_demo_v1.set` (the only `.set` in the bundle) —
`_17_EntryFib=38.2`, `_17_Wave3MinMult=1.618`, `ExitMode=23`, `_9_MaxLevels=1`, `_0_Magic=990303`.

**What the README claims.**
> `Status: DEMO-ELIGIBLE. … Found thin in the overnight multi-home (1.12/1.50), then optimize lifted
> it to a clean all-years-positive candidate.`
> `WHY: both-window Model-4 = MAIN 1.56 / BWD 1.92 (plateau, neighbors both-positive). Year-split =
> ALL 6 years positive (2020 1.56 / 2021 1.62 / 2022 2.29 / 2023 1.94 / 2024 1.70 / 2025 2.14).`
> `CAVEAT: THIN — 11-17 trades/yr (~85 total).`

The README names its windows only as "both-window" and "MAIN". It never states what MAIN's upper
bound is, and it never mentions a holdout.

**Windows the evidence actually used.** The word "optimize" in that README describes
`_mt5_auto/run_wave5_uj_opt.ps1` → 24 `.ini` (12 cells × MAIN/BWD), results in
`_mt5_auto/WAVE5_UJ_OPT.csv`:

| ini | Expert | Sym/TF | Model | Optimization | FromDate | ToDate |
|---|---|---|---|---|---|---|
| `W5OPT_f{236,382,500}_m{0618,10,1618}_MAIN.ini` (6 shown, 9 total) | `Boss_17_Wave5` | USDJPY H1 | 4 | **0** | 2023.01.01 | **2026.07.01** |
| `W5OPT_f*_m*_BWD.ini` | `Boss_17_Wave5` | USDJPY H1 | 4 | 0 | 2020.01.01 | 2023.01.01 |
| `W5_USDJPY_MAIN.ini` (the pre-optimize multi-home run) | `Boss_17_Wave5` | USDJPY H1 | 4 | 0 | 2023.01.01 | **2026.07.01** |
| `ORDER166_990303_W5USDJPY_MAIN.ini` (re-validation) | `EALabTpl\Boss_17_Wave5` | USDJPY H1 | 1 | 0 | 2023.01.01 | **2026.07.01** |
| `W5YS_USDJPY_{2020..2025}.ini` (the year-split) | `Boss_17_Wave5` | USDJPY H1 | 4 | 0 | year start | year+1 start |

**The finding.** Nine MAIN cells were run, ranked against each other, and `f382/m1618` was chosen —
and every one of those nine cells was scored on `2023.01.01 → 2026.07.01`. Six months of the
declared 2026H1 holdout were inside the ranking window. `Optimization=0` on each file only means the
grid was driven by a PowerShell loop instead of the tester's optimiser; the selection is identical
in substance. There is **no** `.ini` anywhere in this EA's funnel with a MAIN upper bound at or
before `2025.12.31` for USDJPY — I checked all 41 Wave5 `.ini`.

The year-split is the one part that is clean: `W5YS_USDJPY_2025` runs `2025.01.01 → 2026.01.01`, so
the "all 6 years positive" claim does not itself reach into 2026H1. But the year-split was run
*after* the cell was already chosen; it confirms the winner, it did not select it.

**Reproducibility.** Exact.

| README | source | measured |
|---|---|---|
| MAIN 1.56 | `W5OPT_f382_m1618_MAIN.htm` | PF **1.56**, 46t, net 69.48, eqDD 0.28% |
| BWD 1.92 | `W5OPT_f382_m1618_BWD.htm` | PF **1.92**, 45t, net 72.92, eqDD 0.22% |
| (ORDER-166 re-run, same set) | `ORDER166_990303_W5USDJPY_MAIN/BWD.htm` | 1.55 / 1.90 — agrees within Model-1-vs-4 noise |
| "~85 total" trades | 46 + 45 | 91 across both windows; consistent |

**Standing.** `DEPLOYMENTS.csv:53` — 463666728, USDJPYm, ACTIVE since 2026-07-18, judge 2026-10-16.
`EA_MASTER_INDEX.csv:129` still lists Boss_17 Wave5 as DEMO with 990301/302/303. No downgrade. The
README's status line is consistent with the registry; the defect is in the evidence beneath it, not
in the label.

**Uncertain / what would settle it.** Whether the edge survives a clean MAIN. Re-running
`f382/m1618` on `2023.01.01 → 2025.12.31` (Model 4, full pinned `.set`) would settle it in one pass;
until then the honest statement is that the deployed USDJPY config's MAIN number has never been
measured on data it did not see.

---

## 2. WAVE5_XAU — CONTAMINATED-SELECTION

**Designated deployed set:** `WAVE5_XAU_H1_demo_v1.set` — `_17_EntryFib=23.6`,
`_17_Wave3MinMult=0.618`, `_17_UseStructLevels=true`, `_17_DivergTrail=true`, `ExitMode=23`,
`_9_MaxLevels=1`, `_0_Magic=990301`.

**What the README claims.**
> `Status: DEMO-ELIGIBLE (lead-engineer PASS to demo, 2026-07-14). NOT live-certified.`
> `WHY DEPLOY (evidence — all gates cleared)`
> `- Plateau (not spike): XAU H1 both-window pass block fib23.6->30 x all mults.`
> `    plateau-center fib23.6/mult0.618 = MAIN(2023-26) PF 1.11 / BWD(2020-22) PF 1.11.`
> `- Robust across TF: XAU H4 @ fib23.6 = MAIN 1.74 / BWD 1.01 (window never used to select).`
> `- Monte Carlo (5000 iters, $10k): ruin 0.00%, P(net<0) 0.0%, DD worst 7.97% MAIN / 4.43% BWD.`
> `- Correlation vs live gold cohort: max |corr| 0.415 << 0.8`

"MAIN(2023-26)" is the closest this bundle comes to naming its window, and it is the tell: MAIN is
supposed to stop at 2025.12.

**Windows the evidence actually used.**

| ini family | count | Model | Optimization | FromDate | ToDate |
|---|---|---|---|---|---|
| `EXT_XAU_F{20,236,27,30}_M{05,0618,075}_MAIN.ini` — the plateau grid | 12 | 1 | **0** | 2023.01.01 | **2026.07.01** |
| `EXT_XAU_*_BWD.ini` | 12 | 1 | 0 | 2020.01.01 | 2022.12.31 |
| `WAVE5_XAU_MAIN.ini` (first sweep, `wave5_sweep_results.csv`) | 1 | 1 | 0 | 2023.01.01 | **2026.07.01** |
| `WAVE5V_XAU_H4_MAIN.ini` (the "H4 robustness" claim) | 1 | 1 | 0 | 2023.01.01 | **2026.07.01** |
| `ORDER166_990301_W5XAU_MAIN.ini` (re-validation of the deployed set) | 1 | 1 | 0 | 2023.01.01 | **2026.07.01** |
| `W5X_*_MAIN_M1.ini` (ORDER-148 JPY-cross expansion) | 8 | 1 | 0 | 2023.01.01 | 2025.12.31 |

Only the later ORDER-148 expansion runs use a clean MAIN — and those are the cells that *failed*
and were never deployed. Every run that supports a deployed XAU number ends `2026.07.01`.

Note also the H4 claim: the README annotates it "(window never used to select)". That is true of the
*timeframe* — H4 was not used to pick the parameter — but `WAVE5V_XAU_H4_MAIN.ini` still runs to
`2026.07.01`, so it is not an out-of-sample window in the holdout sense. The parenthetical
overstates what that row proves.

**Reproducibility — the README's headline is not the deployed set's most recent number.**

| README | source | measured |
|---|---|---|
| MAIN 1.11 / BWD 1.11 | `wave5_extended_results.csv`, row `XAUUSD,H1,23.6,0.618` | MAIN **1.11** (271t, net 253.20, DD 3.38%) / BWD **1.11** (217t, net 147.21) — reproduces |
| same config, later re-run | `ORDER166_990301_W5XAU_MAIN/BWD.htm` | MAIN **1.08** (271t, net 186.60, eqDD 3.41%) / BWD **1.06** (217t, net 83.56) |
| "plateau … fib23.6→30 x all mults" | `wave5_extended_results.csv` | Holds on MAIN, but BWD across that block is 0.94–1.16 and dips to **1.00/0.96** at fib27 and fib20 — the block passes on a 1.0 floor, thinly |
| H4 1.74 / 1.01 | `wave5_validate_results.csv` row `XAUUSD,H4` | **1.74** / **1.01** — reproduces |
| XAU H1 fib38.2 (compiled default) | `WAVE5_XAU_MAIN/BWD.htm` | 1.57 / **0.95** — the default config fails BWD; this is why fib was moved, and it is what makes the fib axis a real selection |
| MC ruin 0.00%, corr 0.415 | — | **Not located.** `_mt5_auto/wave5_mc.log` and `corr_wave5_cohort.py` exist; I did not find a stored MC JSON or corr matrix pinning these two figures. Stated plainly: I could not confirm them. |

Trade counts are identical between the two runs (271 / 217), so the 1.11→1.08 and 1.11→1.06 gap is a
Model/tick-database difference on the same trade set, not a different config. It is small, but it
runs the wrong way: the number the bundle advertises is the higher of the two, and the lower one is
the more recent.

**A second, separate risk on this bundle.** `ORDER166_990301_W5XAU_MAIN.ini` writes
`_17_EntryFib`, `_17_Wave3MinMult`, `ExitMode`, `_9_MaxLevels`, `_23_Trail*`, `_17_DivergTrail`,
`_0_Magic` — but **not** `_17_UseStructLevels`, which the deployed `.set` sets to `true`. Per the
`mt5-tester-cache-nondeterminism` finding, an input absent from the `.ini` is taken from the
per-terminal cache, not from the source default. The re-validation therefore may or may not have run
with `UseStructLevels=true`. **Uncertain.** Re-running with a FULL pinned `.set` (all inputs
written) would settle it; so would diffing the run's input dump.

**Standing.** `DEPLOYMENTS.csv:40` — ACTIVE, 463666728 XAUUSDm, since 2026-07-16, judge 2026-10-16.
`EA_MASTER_INDEX.csv:129` DEMO. No downgrade.

---

## 3. WAVE5_XAG — CONTAMINATED-SELECTION

**Designated deployed set:** `WAVE5_XAG_H1_demo_v1.set` — identical to the XAU set except
`_0_Magic=990302` (fib 23.6 / mult 0.618).

**What the README claims.**
> `Status: DEMO-ELIGIBLE (lead-engineer PASS to demo, 2026-07-14). NOT live-certified.`
> `WHY DEPLOY (evidence — XAG is the STRONGER gold home)`
> `- XAG mini-grid fib{20,23.6,27} x mult{0.5,0.618} = ALL 6 cells pass both windows:`
> `    MAIN(2023-26) PF 1.30-1.45 / BWD(2020-22) PF 1.28-1.35, trades 161-257, DD 5-6.5% / 2-3%.`
> `    plateau-center fib23.6/mult0.618 = MAIN 1.35 / BWD 1.29.`
> `- Uniform plateau, STRONGER than XAU`

**Windows the evidence actually used.**

| ini | Model | Optimization | FromDate | ToDate |
|---|---|---|---|---|
| `XAGMG_F{20,236,27}_M{05,0618}_MAIN.ini` (the 6-cell mini-grid) | 1 | **0** | 2023.01.01 | **2026.07.01** |
| `XAGMG_*_BWD.ini` | 1 | 0 | 2020.01.01 | 2022.12.31 |
| `W5_XAGUSD_MAIN.ini` / `ON_Wave5_XAGUSD_MAIN.ini` | 4 | 0 | 2023.01.01 | **2026.07.01** |
| `ORDER166_990302_W5XAG_MAIN.ini` | 1 | 0 | 2023.01.01 | **2026.07.01** |

Same shape as XAU: the "all 6 cells pass" grid that both selected the centre *and* supplied the
plateau argument was scored on a window with 2026H1 inside it. No clean-MAIN XAG run exists.

**Reproducibility.**

| README | source | measured |
|---|---|---|
| centre MAIN 1.35 / BWD 1.29 | `wave5_xag_minigrid_results.csv` row `23.6,0.618` | **1.35** / **1.29** — reproduces |
| range "MAIN 1.30-1.45 / BWD 1.28-1.35" | same CSV, 6 cells | MAIN 1.30–1.45, BWD 1.28–1.35 — reproduces exactly |
| centre, later re-run | `ORDER166_990302_W5XAG_MAIN/BWD.htm` | **1.33** (216t) / **1.24** (169t) |
| trades 161–257, DD 5–6.5% / 2–3% | same CSV | 161–257, DD 5.04–6.54% / 2.13–3.13% — reproduces |

Same pattern as XAU: the deployed set's most recent measurement (1.33/1.24) is below the advertised
one (1.35/1.29), on identical trade counts.

**Standing.** `DEPLOYMENTS.csv:41` — ACTIVE, XAGUSDm, since 2026-07-16. No downgrade.

---

## 4. CRYPTO_TRENDRIDER — CLAIM-MISMATCH

Two legs, two `.set`, two `.ex5`. Selection windows on this bundle are **clean** — it is everything
around them that is wrong.

**Designated deployed sets.** `ST_BTC_deploy.set` (EA_SUPERTREND, BTCUSD H4, magic 990025) and
`DON_ETH_deploy.set` (EA_DONCHIAN, ETHUSD H4, magic 990030).

**What the README claims.**
> `## หลักฐาน backtest (Model-4 real ticks 99%)`
> `- ST-BTC: PF 1.88 (flat) / 2.22 (snowball 1%, DD 5.6%) · both-window + holdout ผ่าน`
> `- DON-ETH pyr3: PF 1.99 (flat) / 2.52 (snowball 0.35%, DD 14.3%)`
> and a promote-gate: `ปล่อย demo ≥1 เดือน → วัด swap-adjusted PF · ต้อง >1.3 ถึงขยับเงินจริง`.

**Finding A — the deployed sets cannot trade.** Both `.set` files ship `_06_AllowLive=false`:

```
ST_BTC_deploy.set : _06_AllowLive=false   _06_Magic=990025
DON_ETH_deploy.set: _06_AllowLive=false   _06_Magic=990030
```

The gate is real. `ea_projects/CRYPTO_TRENDRIDER/EA_SUPERTREND.mq5:39` declares
`input bool _06_AllowLive = false; // tester always simulates; live gated by this` and line 201 is
`const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);`. `EA_DONCHIAN.mq5:47/163` is
identical. On a live or demo chart `MQL_TESTER` is false, so with `AllowLive=false` the EA arms
nothing, logs nothing unusual, and shows no error — the exact silent-stop failure that every other
bundle in this group has an `[S1]` checklist line about. **This README has no silent-stop checklist
at all.** Meanwhile `DEPLOYMENTS.csv:56-57` carries both legs as `ACTIVE` on 415573666 since
2026-07-23 with judge dates of 2026-10-23.

Either the attaching operator flipped the flag by hand (in which case the bundle no longer describes
what is running) or the legs have been idle for three days and the judge clock is counting an EA
that has not traded. **Uncertain which** — settled by reading the Experts log on 415573666 for
magics 990025 / 990030, or by checking whether either magic has any deal history.

**Finding B — "Model-4 real ticks 99%" is true of half the quoted numbers.** The heading covers four
figures; two of them are Model-1 runs:

| README figure | ini | Model | window | report | measured |
|---|---|---|---|---|---|
| ST-BTC 1.88 flat | `M4_ST_BTC_FULL.ini` | **4** | 2023.01.01 → **2026.07.01** | `M4_ST_BTC_FULL.htm` | PF **1.88**, 91t, 173,362,327 ticks |
| DON-ETH 1.99 flat | `M4_DON_ETH_PYR3.ini` | **4** | 2023.01.01 → **2026.07.01** | `M4_DON_ETH_PYR3.htm` | PF **1.99**, 186t, 123,732,163 ticks |
| ST-BTC 2.22 snowball, DD 5.6% | `SNOW_ST_R1.ini` | **1** | 2023.01.01 → **2026.07.01** | `SNOW_ST_R1.htm` | PF **2.22**, 91t, eqDD **5.62%**, 7,062,542 ticks |
| DON-ETH 2.52 snowball, DD 14.3% | `SNOW_DON_R035.ini` | **1** | 2023.01.01 → **2026.07.01** | `SNOW_DON_R035.htm` | PF **2.52**, 186t, eqDD **14.31%**, 7,088,135 ticks |

The tick counts settle it: 7.0M vs 173M on the same 7,503 bars. The two snowball numbers — which are
the ones that describe the **deployed** configuration (`ST_BTC_deploy.set` has `_05_RiskPct=1.0`,
`DON_ETH_deploy.set` has `_05_RiskPct=0.35`; source default is `0.0` = flat) — are Model-1. The
Model-4 numbers describe a flat-lot configuration that is **not** what ships. So the bundle's most
prominent evidence label applies to the configuration it does not deploy, and the deployed
configuration's numbers carry a weaker evidence class than advertised.

**Finding C — every quoted number spans the holdout.** All four runs above end `2026.07.01`. The
*selection* is clean: `OPT_ST_BTC_1.ini` and `OPT_DON_ETH_1.ini` are the only `Optimization != 0`
runs in this family (Opt=1, `2023.01.01 → 2026.01.01`) and both stop at the zero-deal boundary — so
parameters were **not** chosen with 2026H1 visible, and ORDER-202 already cleared `EA_DONCHIAN`
(990030) on exactly this basis. But a real holdout was also run and consumed:

| ini | Model | window | report | measured |
|---|---|---|---|---|
| `VAL_ST_BTC_HOLD.ini` | 1 | 2026.01.01 → 2026.07.01 | `VAL_ST_BTC_HOLD.htm` | PF **2.16**, 15t |
| `VAL_DON_ETH_HOLD.ini` | 1 | 2026.01.01 → 2026.07.01 | `VAL_DON_ETH_HOLD.htm` | PF **1.94**, 13t |
| `VAL_ST_BTC_BWD.ini` | 1 | 2020.01.01 → 2023.01.01 | | PF 1.55, 84t |
| `VAL_DON_ETH_BWD.ini` | 1 | 2020.01.01 → 2023.01.01 | | PF 1.91, 58t |

So "both-window + holdout ผ่าน" is substantiated — the holdout was genuinely independent and it
passed at n=15 / n=13. 2026H1 is spent for this pair and the README does not say so. That alone
would be HOLDOUT-SPENT; findings A and B are what make it CLAIM-MISMATCH.

**Finding D — no registry row.** `grep -c "990025\|990030" EA_SCORECARD_AND_REGISTRY.md` = **0**.
Neither crypto leg has a scorecard entry. `EA_MASTER_INDEX.csv:107` has an `EA_SUPERTREND v1 naked`
row, but that is the **XAUUSD H4** instrument, verdict `PARKED — แพ้ KER`, not the BTC config. Two
demo-deployed EAs with real judge dates exist only in `DEPLOYMENTS.csv`. That is a Row-X checklist
gap, not a README defect, but it means there is no registry standing for a README to contradict.

**Finding E — `VAL_ST_BTC_HOLD.ini` writes `_06_Magic=990020`, not 990025.** The README itself flags
990020 as taken by SuperTrend XAU on the same account and says to use 990025. The validation runs
carry the old magic; harmless in a tester (magic does not change fills) but it confirms the
validation predates the magic decision and was not re-run after it.

---

## 5. EA_BREAKOUT_US30 — CLAIM-MISMATCH

**Designated deployed set:** `EA_BREAKOUT_US30_demo_v1.set` (53 bytes — `BuyOnly=true`,
`AllowLive=true`, `Magic=991005`; everything else compiled defaults, as the README states).

**What the README claims.**
> `Status: DEMO-ELIGIBLE, WATCH sizing (lead-engineer PASS to demo, 2026-07-14). NOT live-certified.`
> `- Flat-lot both-window H4: MAIN(2023-26) PF 1.46 (34 trades) / BWD(2020-22) PF 1.39 (26 trades).`
> `    Strongest PF of the whole expansion batch, DD tiny (0.16-0.19%).`
> `- Correlation vs the live XAU leg: corr = -0.249 over 14 shared months`
> `- ⚠️ CAVEAT: only 26-34 total trades per window = THIN SAMPLE. … Treat as WATCH`

**Windows the evidence actually used.**

| ini | Expert | Model | Optimization | FromDate | ToDate |
|---|---|---|---|---|---|
| `O095_BRK_US30_H4_MAIN.ini` | `O076\brkxauExpand` | 1 | **0** | 2023.01.01 | **2026.07.01** |
| `O095_BRK_US30_H4_BWD.ini` | `O076\brkxauExpand` | 1 | 0 | 2020.01.01 | 2022.12.31 |
| `O159_991005_BRKXAU_US30_MAIN.ini` | `EA_BREAKOUT_XAU` | 1 | 0 | 2023.01.01 | **2025.12.31** |
| `BRKSMOKE_US30.ini` (earlier smoke, H1) | `EA_BREAKOUT_XAU` | 2 | 0 | 2023.01.01 | 2026.06.01 |

No optimizer pass exists for this leg at all — the config is compiled defaults inherited from the
XAU leg, so **no parameter was selected on any window**. That is the ORDER-202 "values are clean"
case. But:

**Reproducibility, and the mismatch.**

| README | source | measured |
|---|---|---|
| MAIN 1.46 (34 trades), DD 0.16% | `O095_BRK_US30_H4_MAIN.htm` | PF **1.46**, **34t**, net 14.97, eqDD 15.96 (**0.16%**) — reproduces exactly, on `2023.01 → 2026.07` |
| BWD 1.39 (26 trades), DD 0.19% | `O095_BRK_US30_H4_BWD.htm` | PF **1.39**, **26t**, net 10.30, eqDD 18.60 (**0.19%**) — reproduces |
| — | `O159_991005_BRKXAU_US30_MAIN.htm` (**clean MAIN**) | PF **1.21**, **32t**, net 6.23, eqDD 13.21 (0.13%) |

The clean-window number already exists in this repo — it was run under ORDER-159 — and it is
**1.21, not 1.46**. Removing the six burned months removes 2 of 34 trades and 8.74 of 14.97 net
profit: roughly **58% of the leg's entire MAIN net came from the 2026H1 window**. That is the same
signature ORDER-202 documented for 991001 v2/v3, on a leg with a quarter of the sample.

The README was written 2026-07-14 and the clean re-run happened later, so this is staleness rather
than misrepresentation. But the bundle is the attach-time surface, it still says 1.46, and 1.21 sits
exactly on the 1.2 hard bar with 32 trades — a materially different proposition from "strongest PF
of the whole expansion batch". A human reading this README at attach time is sized off a number the
repo has already superseded.

**Secondary observation — binary provenance.** The `O095_*` runs used `Expert=O076\brkxauExpand`;
the bundled binary is `EA_BREAKOUT_XAU.ex5` and the `O159_*` re-run used `Expert=EA_BREAKOUT_XAU`.
The README asserts they are the same mechanism ("same binary as the live XAU leg magic 991001"), and
the trade counts are consistent with that, but I did not verify byte-identity of the two experts.
**Uncertain**; a SHA256 comparison of `_vps_deploy/EA_BREAKOUT_US30/EA_BREAKOUT_XAU.ex5` against
whatever `O076\brkxauExpand.ex5` still exists would settle it.

**Standing.** `DEPLOYMENTS.csv:43` — ACTIVE, 463666728 US30m, since 2026-07-16, judge 2026-10-16,
comment `BRK expand US30 WATCH-thin`. Not downgraded.

---

## 6. EXP_ADAPTGRIDMC — CLAIM-MISMATCH

**Bundle contents:** `O142_BTC_MAIN.set`, `O142_ETH_MAIN.set`. **No README. No `.ex5`.** Nothing in
the folder tells an operator what this is, whether to attach it, or what evidence stands behind it.

**What the registry says.** `EA_SCORECARD_AND_REGISTRY.md:263`:
> `| (EXP)_AdaptGridMC (992007) | BTC/ETH CFD | ★☆☆ | DEAD-STRUCTURAL (static-zone design) — PARKED
> pending redesign | … MAIN PF 523(BTC)/1182(ETH, M4) looked spectacular but is a realized-path
> artifact, proven not suspected — static one-time P10/P90 zone from pre-2023 data; … 2026H1 holdout
> confirmed ZERO BTC trades (zone is dead).`

`EA_MASTER_INDEX.csv:153` agrees: `DEAD-STRUCTURAL (static-zone) -- PARKED pending walk-forward
redesign`. `DEPLOYMENTS.csv` has **no** row for 992007 — it was never attached, correctly.

**Windows the evidence used.** Clean throughout:

| ini | Model | Optimization | FromDate | ToDate | report |
|---|---|---|---|---|---|
| `O142_BTC_MAIN_M4.ini` | 4 | 0 | 2023.01.01 | 2025.12.31 | PF **523.12**, 47t |
| `O142_ETH_MAIN_M4.ini` | 4 | 0 | 2023.01.01 | 2025.12.31 | PF **1182.12**, 133t |
| `O142_BTC_HOLDOUT_M1.ini` | 1 | 0 | 2026.01.01 | 2026.06.30 | **0 trades**, PF 0.00 |
| `O142_ETH_HOLDOUT_M1.ini` | 1 | 0 | 2026.01.01 | 2026.06.30 | PF **1.27**, 24t |

No optimizer pass, no window past 2025.12.31 used for selection. The holdout was spent — and spending
it is what killed the EA, which is the holdout working as designed. Evidence integrity here is fine.

**The finding is the bundle's existence.** A folder in `_vps_deploy` is the attach surface; four of
the twelve bundles in this group are already attached from exactly this directory. This one stages
two `.set` for an EA the lab has ruled `DEAD-STRUCTURAL`, with the deposit-scale zone constants
(`_01_ZoneLo=12748.93 / _01_ZoneHi=22711.25` for BTC) that are precisely the dead mechanism — a
static zone BTC left permanently. Both `.set` also carry `_06_AllowLive=false`
(`(EXP)_AdaptGridMC_rev01.mq5:48/146` gates on it), so an accidental attach would idle rather than
trade — the one piece of luck in the arrangement.

Magic 992007 additionally collided: `EA_SCORECARD_AND_REGISTRY.md:253` records that
`(MR)_VwapSnapback_EUR` had to be renumbered to 992010 because "magic เดิม 992007 ชนกับ AdaptGridMC
ของ parallel session". So the number in these `.set` is one a parallel session was simultaneously
trying to use.

The `.set` values themselves match `O142_BTC_MAIN_M4.ini` exactly (`ZoneLo`, `ZoneHi`,
`SpacingAtrMult=0.3`, `MaxLevels=40`, `KillDdPct=20.0`, `Magic=992007`), so this is a genuine
deploy-staging artifact of the killed configuration, not a stray file.

---

## 7. EA_BREAKOUT_USDJPY — HOLDOUT-SPENT

**Designated deployed set:** `EA_BREAKOUT_USDJPY_demo_v1.set` (53 bytes — `BuyOnly=true`,
`AllowLive=true`, `Magic=991003`, rest compiled defaults).

**What the README claims.**
> `Status: DEMO-ELIGIBLE (lead-engineer PASS to demo, 2026-07-14). NOT live-certified.`
> `- Flat-lot smoke = full-config test (this EA has no escalation to strip), both-window H4:`
> `    MAIN(2023-26) PF 1.28 (102 trades) / BWD(2020-22) PF 1.25 (75 trades). DD 0.23-0.35%.`
> `- Correlation vs the live XAU leg …: corr = 0.066 (near-zero) over 19 shared months`
> `- XAG/GBP/EUR were tested in the same batch and FAILED (BWD PF 0.56-0.84)`

**Windows the evidence actually used.**

| ini | Expert | Model | Optimization | FromDate | ToDate |
|---|---|---|---|---|---|
| `O095_BRK_USDJPY_H4_MAIN.ini` | `O076\brkxauExpand` | 1 | **0** | 2023.01.01 | **2026.07.01** |
| `O095_BRK_USDJPY_H4_BWD.ini` | `O076\brkxauExpand` | 1 | 0 | 2020.01.01 | 2022.12.31 |
| `O159_991003_BRKXAU_USDJPY_MAIN.ini` | `EA_BREAKOUT_XAU` | 1 | 0 | 2023.01.01 | **2025.12.31** |
| `BRKJPY_c{0..11}_IS/OOS.ini` (earlier H1 cell sweep, superseded) | `EA_BREAKOUT_XAU` | 2 | 0 | IS 2023.01.01→2024.12.31 / OOS 2025.01.01→**2026.06.01** | |
| `BRKSMOKE_USDJPY.ini` | `EA_BREAKOUT_XAU` | 2 | 0 | 2023.01.01 | 2026.06.01 |

As with US30: no optimizer pass, compiled defaults, so no parameter was selected on any window. The
`.set` is three lines. The ship decision, however, was taken on numbers measured through 2026H1.

**Reproducibility — exact, and the clean re-run is better.**

| README | source | measured |
|---|---|---|
| MAIN 1.28 (102t), DD 0.23% | `O095_BRK_USDJPY_H4_MAIN.htm` | PF **1.28**, **102t**, net 37.86, eqDD 22.70 (**0.23%**) |
| BWD 1.25 (75t), DD 0.35% | `O095_BRK_USDJPY_H4_BWD.htm` | PF **1.25**, **75t**, net 24.72, eqDD 35.23 (**0.35%**) |
| — | `O159_991003_BRKXAU_USDJPY_MAIN.htm` (**clean MAIN**) | PF **1.41**, 65t, net 38.90 |

The clean window is *stronger* (1.41 vs 1.28), i.e. the burned months were a drag here, not a
flatterer — the opposite of the US30 leg. Nothing about this bundle's headline is inflated. The
defect is purely that 2026H1 was consumed by the ship decision and the README does not say so, so
this leg has no fresh holdout left; its forward evidence starts at attach (2026-07-16). Same
disposition as the Boss_14 cohort in ORDER-202.

**Standing.** `DEPLOYMENTS.csv:42` — ACTIVE, 463666728 USDJPYm, since 2026-07-16. Not downgraded.

**Note on `BRKJPY_c*_OOS`.** Twelve cells were run with `OOS = 2025.01.01 → 2026.06.01`. If any
parameter had been picked off those, this would be a contaminated selection. It was not — the
deployed `.set` is compiled defaults and those cells vary `BreakoutBars`, which the `.set` does not
override. I checked the `.set` (3 lines, no `_01_BreakoutBars`). Clean on that axis.

---

## 8. SS1_LONDONORB_XAU — CLEAN

**Designated deployed set:** `SS1_LondonORB_XAU_deploy.set`, described in the README as a
"FULL 25-input merge — do NOT attach with a partial set; unlisted inputs come from per-terminal
cache". That instruction is correct and is the only bundle in this group that states it.

**What the README claims.**
> `Verdict: VALIDATED CANDIDATE → demo-isolate. Full funnel passed except correlation
> (blocked by ORDER-174 …). No auto-live.`
> Evidence table (locked centre EMA200 / MinOr 0.5 / TpRR 3.5):
> `MAIN 2023.01–2025.12: M1 1.22 / M4 1.16, n=499` · `BWD 2020–2022: 1.13 / 1.06, n=492` ·
> `HOLDOUT 2026H1: 1.24 / 1.21, n=86`
> `MC … ruin 0.00%, PF-5th 1.16, DD95 3.61%, worst 5.65%`
> plus four named weaknesses including `Real-tick MAIN is 1.16, under the 1.2 deploy bar` and
> `Holdout 2026H1 is partially burned at cohort level (TrendRider used it first).`

This README names its windows with dates, states the model for each column, and volunteers its own
failures. It is the standard the rest of this group should be measured against.

**Windows the evidence actually used.** 32 `LondonORB_XAU` `.ini`, all `Optimization=0`:

| family | purpose | window |
|---|---|---|
| `SS1_mo*_tp*`, `SS1TF_ema*_mo*`, `SS1F_tp*`, `SS1L_*`, `SS1P_tp*` MAIN | selection + fan | 2023.01.01 → **2025.12.31** |
| same, BWD | selection | 2020.01.01 → 2022.12.31 |
| `SS1H_*_HOLD`, `SS1P_*_HOLD`, `SS1M4_*_HOLD` | holdout | 2026.01.01 → 2026.06.30 |
| `SS1M4_tp3p5_{MAIN,BWD,HOLD}` | Model-4 confirm | as above, Model 4 |
| `W2C_SS1_*` | cross-symbol expansion | 2023.01.01 → 2025.12.31 / 2020–2022 |

**Not one selection run reaches past 2025.12.31.** The holdout is a separate, later, single-use
window. This is the funnel shape the VERDICT GATE describes.

**Reproducibility — exact.**

| README | report | measured |
|---|---|---|
| M4 MAIN 1.16, n=499 | `SS1M4_tp3p5_MAIN.htm` | PF **1.16**, **499t**, net 368.95, eqDD 2.61%, 99,472,212 ticks |
| M4 BWD 1.06, n=492 | `SS1M4_tp3p5_BWD.htm` | PF **1.06**, **492t**, net 94.53, eqDD 1.12% |
| M4 HOLDOUT 1.21, n=86 | `SS1M4_tp3p5_HOLD.htm` | PF **1.21**, **86t**, net 239.05, eqDD 2.83% |

The 99,472,212-tick figure matches the XAUUSD 2023.01–2025.12 tick count ORDER-202 used to prove
cross-instance comparability — same tick database, numbers comparable.

**Standing — one stale registry row, not a README defect.** `EA_SCORECARD_AND_REGISTRY.md:249` still
says `VALIDATED CANDIDATE → bundle built, PENDING_ATTACH (2026-07-23)`, while `DEPLOYMENTS.csv:60`
records it ACTIVE on 415573666 since 2026-07-23 with judge 2026-10-23. The README is the accurate
one; the scorecard is behind. Worth a one-line fix but it does not affect anyone reading the bundle.

**Holdout disposition.** 2026H1 is now spent for this EA (properly — one use, as the final gate).
The README already says so and flags the cohort-level burn. Credited as clean per the brief.

---

## 9. PIVOTBREAKOUT_XAU — CLEAN

**Designated deployed set:** `PivotBreakout_XAU_deploy.set` ("FULL 15-input merge — do NOT attach
with a partial set"), XAUUSD H4, magic 992017.

**What the README claims.**
> `Verdict: VALIDATED CANDIDATE → demo-isolate. Full funnel passed on real ticks: both-window,
> holdout, MC all clear. Corr vs cohort unmeasured (ORDER-174 …) — size small until that's checked.
> No auto-live.`
> `MAIN 2023.01–2025.12: M1 1.18 / M4 1.16, n=231` · `BWD 2020–2022: 1.26 / 1.22, n=200` ·
> `HOLDOUT 2026H1: — / 1.33, n=35`
> `MC … ruin 0.00%, PF-5th 1.16, DD95 8.24%, worst 12.41%`
> plus `DD95 8.24% is noticeably higher than some other candidates` and `Holdout n=35 is on the
> thinner side`.

**Windows the evidence actually used.** 19 `PivotBreakout_XAU` `.ini`, all `Optimization=0`:

| family | purpose | window |
|---|---|---|
| `GP_PivotBreakout_{H1,H4,M15}` | TF screen | 2023.01.01 → **2025.12.31** |
| `GPB_sl{1p5,2p5}_tp{1p5,3}_{MAIN,BWD}`, `PVC_sl1p5_tp{2p5,3p5}_*` | the SlAtrMult × TpRR fan | MAIN 2023.01.01 → **2025.12.31** / BWD 2020.01.01 → 2022.12.31 |
| `PVM4_{MAIN,BWD,HOLD}` | Model-4 confirm | 2023.01.01→2025.12.31 / 2020–2022 / **2026.01.01 → 2026.06.30** |

Selection fan entirely inside clean MAIN+BWD; holdout run once, afterwards, on Model 4 only. Correct
shape.

**Reproducibility — exact.**

| README | report | measured |
|---|---|---|
| M4 MAIN 1.16, n=231 | `PVM4_MAIN.htm` | PF **1.16**, **231t**, net 646.99, eqDD 3.90%, 99,472,212 ticks |
| M4 BWD 1.22, n=200 | `PVM4_BWD.htm` | PF **1.22**, **200t**, net 509.51, eqDD 2.55% |
| M4 HOLDOUT 1.33, n=35 | `PVM4_HOLD.htm` | PF **1.33**, **35t**, net 643.29, eqDD 903.90 (**8.14%**) |

Note the holdout's 8.14% equity drawdown on 35 trades — larger than either training window's — which
is consistent with the README's own DD95 8.24% warning but is not itself surfaced in the README's
table. Not a mismatch; an omission worth knowing when sizing.

**Standing.** `EA_SCORECARD_AND_REGISTRY.md:262` — `VALIDATED CANDIDATE → ACTIVE demo, attached
2026-07-24 on 463666728`. `DEPLOYMENTS.csv:61` agrees (with the honest note that the account is
"assumed — user did not specify"). README matches registry.

**Holdout disposition.** Spent, once, properly. Not declared as spent in the README, but it is
reported as a used holdout with its result, which is the disclosure that matters.

---

## 10. W2_S1_TRENDRIDER_XAU — CLEAN

**Designated deployed set:** `S1_TrendRider_XAU_deploy.set` (plateau centre a20 / s0.5 / c2.5,
`_06_AllowLive=true`, magic 992004), XAUUSD H4.

**What the README claims.**
> `Plateau both-window (27-cell ladder): center MAIN 1.63/112t eqDD 2.64% Sharpe 1.96 · BWD 1.03/139t
> eqDD 1.71% — 6-cell block AdxMin20 × Sep{0.3,0.5} × Ch{2,2.5,3} ผ่าน bar ทุก cell`
> `HOLDOUT 2026H1: PF 1.33/23t (≥1.2; n บาง — demo-forward = holdout ตัวถัดไป, 2026H1 ไหม้แล้วสำหรับ EA นี้)`
> `Model-4: MAIN 1.61 / BWD 1.01 — retained, no fill cliff`
> `MC (5k resample, MAIN M4): ruin 0% · DD95 4.15% · PF-5th 1.61`
> `⚠️ BWD 1.01 = borderline … demo isolate ก่อน ห้าม promote เงินจริงจาก MAIN สวยอย่างเดียว`

**This is the one bundle in the group that explicitly declares demo-forward-as-holdout**, in the same
breath as reporting the holdout number. Per the brief, credited: clean on the holdout axis by
disclosure, not by luck.

**Windows the evidence actually used.** All `Optimization=0`:

| ini | purpose | Model | window |
|---|---|---|---|
| `W2B_S1_a{20,25,30}_s{0p3,0p5,0p8}_c{2,2p5,3}_MAIN.ini` (27 cells) | the ladder | 1 | 2023.01.01 → **2025.12.31** |
| same, `_BWD.ini` | | 1 | 2020.01.01 → 2022.12.31 |
| `W2D_S1_MAIN_M4.ini` / `W2D_S1_BWD_M4.ini` | Model-4 confirm | 4 | 2023.01.01→2025.12.31 / 2020–2022 |
| `W2D_S1_HOLDOUT.ini` | holdout | 1 | **2026.01.01 → 2026.06.30** |
| `W2A_S1_H{1,4}_*`, `W2_S1_TrendRider_MAIN.ini` | TF screen | 1 | 2023.01.01 → 2025.12.31 |

27-cell selection ladder entirely on clean MAIN+BWD. Holdout run once, after.

**Reproducibility — exact.**

| README | report | measured |
|---|---|---|
| centre MAIN 1.63 / 112t / eqDD 2.64% | `W2B_S1_a20_s0p5_c2p5_MAIN.htm` | PF **1.63**, **112t**, net 802.26, eqDD 288.65 (**2.64%**) |
| centre BWD 1.03 / 139t / eqDD 1.71% | `W2B_S1_a20_s0p5_c2p5_BWD.htm` | PF **1.03**, **139t**, net 32.93, eqDD 172.82 (**1.71%**) |
| M4 MAIN 1.61 | `W2D_S1_MAIN_M4.htm` | PF **1.61**, 112t, 99,472,212 ticks |
| M4 BWD 1.01 | `W2D_S1_BWD_M4.htm` | PF **1.01**, 139t, net **7.52** |
| holdout 1.33 / 23t | `W2D_S1_HOLDOUT.htm` | PF **1.33**, **23t**, net 266.42, eqDD 4.87% |

The M4 BWD net of **7.52 on 139 trades** is worth stating out loud — PF 1.01 across a three-year
stress regime is breakeven to the nearest currency unit. The README does flag "BWD 1.01 = borderline"
and forbids promoting on MAIN alone, so the disclosure is present; the net figure just makes the
thinness concrete.

**Standing.** `EA_SCORECARD_AND_REGISTRY.md:247` — `ACTIVE demo (attached 415573666, 2026-07-23)`,
numbers identical to the README. `DEPLOYMENTS.csv:58` agrees. No mismatch.

---

## 11. S2_TSMOM_XAU — CLEAN

**Designated deployed set:** `S2_TsMom_XAU_deploy.set` (locked lb60 / deadmult2,
`_05_AllowLive=true`, magic 992001), XAUUSD D1.

**What the README claims.** Notable for what it refuses to claim:
> `## ⚠️ Why this is DEMO-ISOLATE, not a normal CANDIDATE attach`
> `This EA has NOT cleared the VERDICT GATE funnel (no sensitivity fan, no holdout run, no MC, no M4
> confirm) — the pre-registered exit from the ladder was PARKED-VERIFY(user), not CANDIDATE. BWD<1 is
> a KNOWN, ACCEPTED, un-fixed regime weakness at attach time`
> `Picked plateau-center lb60/dm2 (not the lb100/dm2 spike-peak 4.90): MAIN PF 3.72/26t net+1375 ·
> BWD PF 0.70/27t net-277.`
> `ADX regime-gate probe … did not help (BWD stayed 0.56-0.69 across all ADX thresholds)`

**Windows the evidence actually used.** All `Optimization=0`, all clean:

| ini family | count | window |
|---|---|---|
| `S2SW_lb{60,100,140}_dm{1,2,3}_MAIN.ini` (the 9-cell ladder) | 9 | 2023.01.01 → **2025.12.31** |
| `S2SW_*_BWD.ini` | 9 | 2020.01.01 → 2022.12.31 |
| `S2AX_lb{60,100}_adx{20,25,30}_MAIN/BWD.ini` (ADX rescue) | 12 | same |
| `TSMOM_XAU_D1_SMOKE_{MAIN,BWD}.ini` | 2 | same |

**No 2026 run exists for this EA at all.** The holdout is untouched — which is the correct state for
an EA that never reached the holdout stage. This is the cleanest bundle in the group on the window
axis.

**Reproducibility — exact.** `_mt5_auto/S2_TSMOM_BOTHWINDOW.csv`:

| lookback | deadmult | main_pf | main_tr | bwd_pf | bwd_tr |
|---|---|---|---|---|---|
| 60 | 1 | 3.58 | 28 | 0.70 | 31 |
| **60** | **2** | **3.72** | **26** | **0.70** | **27** |
| 60 | 3 | 2.82 | 25 | 0.77 | 23 |
| 100 | 2 | **4.90** | 25 | 0.57 | 27 |

Centre = 3.72 / 0.70 as claimed; the spike-peak 4.90 the README says it declined to pick is right
there in the CSV at lb100/dm2, and it does have the worst BWD in the block. The stated reasoning is
supported by the data.

**Standing.** `EA_SCORECARD_AND_REGISTRY.md:250` — `PARKED-VERIFY(user) → bundle built,
PENDING_ATTACH`, with `⚠️ funnel not complete (no holdout/MC/fan)`. `DEPLOYMENTS.csv:59` records it
ACTIVE since 2026-07-23 (so the scorecard's PENDING_ATTACH is stale in the same way SS1's is). The
README's own framing — demo-isolate, not CANDIDATE — matches the registry verdict exactly. Nothing
is overclaimed anywhere in this bundle.

---

## 12. PAIRSPREAD_STATARB — CLEAN

**Designated deployed set:** `PAIRSPREAD_EURGBP_H4_demo_v1.set` — `EntryZ 2.5 / ExitZ 0.3 /
ZWindow 100 / StopZ 3.5`, `LotA/B 0.05`, `_06_AllowLive=true`, magic 990984. EURUSD H4 chart with
GBPUSD as leg B.

**What the README claims.**
> `Status : DEMO ONLY — CANDIDATE_WEAK (not standalone-live approved). Small-weight diversifier leg,
> data-collection on demo.`
> `both-window PF : MAIN 1.14 / BWD 1.15 (2023-26 / 2020-22)`
> `true holdout : PF 1.23 (2017-2019, never used to select)`
> `plateau : ExitZ 0.2/0.3/0.4 neighbors all hold (not a spike)`
> `Monte Carlo : ruin 0%, obs PF 1.141, OoS date-split PF 0.917`
> `caveat : bootstrap PF_5th 0.75 (< 0.8) = edge real but thin tail -> CANDIDATE_WEAK, small size,
> watch. NOT live-approved.`

**Windows the evidence actually used.** 40+ `PairSpread_StatArb` `.ini`, every one `Optimization=0`:

| family | window |
|---|---|
| `O098F_*_MAIN`, `O098G_*_MAIN`, `O098H_*_MAIN`, `O098H2_comb_MAIN` | 2023.01.01 → **2026.01.01** |
| `O098{F,G,H}_*_BWD` | 2020.01.01 → 2022.12.31 |
| `O098G_e25_HLD`, `O098H_x03_HLD`, `O098H2_comb_HLD`, `O098K_maker_HLD` | **2017.01.01 → 2019.12.31** |

`2026.01.01` is the zero-deal boundary ORDER-202 verified — this funnel **never touches 2026H1 in any
run**. Its holdout is a genuinely separate 2017-2019 window that no other EA in the book competes
for. Structurally the strongest evidence position of the twelve.

**Reproducibility — exact.**

| README | report | measured |
|---|---|---|
| MAIN 1.14 | `O098G_x03_MAIN.htm` | PF **1.14**, 126t, net 682.35, eqDD 4.02% |
| BWD 1.15 | `O098G_x03_BWD.htm` | PF **1.15**, 108t, net 614.61, eqDD **13.09%** |
| holdout 1.23 (2017-2019) | `O098H_x03_HLD.htm` | PF **1.23**, 96t, net 960.70, eqDD 5.26% |
| plateau ExitZ 0.2/0.3/0.4 | `ORDER098F_..._VERDICT.md` §098-H | 1.13/1.06 · **1.14/1.15** · 1.09/1.12 — holds |
| MC obs 1.141, ruin 0%, OoS 0.917, PF_5th 0.753 | `_mt5_auto/order098h_x03_mc.json` (per verdict doc) | quoted verbatim in the verdict; JSON not re-parsed |
| corr max +0.36 vs cohort | verdict doc §098-G corr-check | `ST03_replica +0.36`, several strongly negative — matches |

The verdict document also records something the README does **not** carry forward: the combined-config
variant (EntryZ2.0/ExitZ0.3/StopZ4.0) raised in-sample PF but regressed the holdout to 1.09 and was
rejected as OFAT-stacking overfit, and the maker-entry variant gave no lift. Both are honest negative
results that strengthen the deployed config's provenance. The README's BWD eqDD of 13.09% is also
absent from its own summary (it lists only PF); worth knowing given the 0.05+0.05 lot sizing.

**Standing.** `EA_MASTER_INDEX.csv:133` — `DEMO — CANDIDATE_WEAK, collect forward evidence`, with
`do NOT expand until demo forward proves live behavior`. `DEPLOYMENTS.csv:54` — ACTIVE since
2026-07-18. README, index and deployment row all agree, including the weakness.

---

## What I did not do, deliberately

- **No tester run.** Every number above is read out of a stored `.htm` or `.csv`. Where a clean-window
  number does not exist (Wave5 ×3), I say it does not exist rather than estimating it.
- **No `.ex5` byte-comparison.** The `O076\brkxauExpand` vs `EA_BREAKOUT_XAU` question in §5 and the
  Boss_17 template-vs-bundle question are both open; both are one SHA256 away.
- **No re-derivation of MC/correlation figures.** Wave5's `ruin 0.00% / corr 0.415` (§2) is the one
  claim in this group I could not tie to a stored artifact at all. That is a gap, not a clearance.
- **No edits to any file except this one.** No verdicts issued; the CONTAMINATED-SELECTION label is a
  statement about how three parameter sets were chosen, not a judgement on whether their edges are
  real.
