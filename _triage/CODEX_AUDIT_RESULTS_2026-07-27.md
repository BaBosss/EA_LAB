# Codex blind-audit results — 2026-07-27

Three audits from `_triage/CODEX_REVIEW_QUEUE_2026-07-25.md`, dispatched ~17:05 once the user confirmed
ChatGPT quota was back, all returned ~10 minutes later. Each brief carried the mechanics and the
question and **deliberately withheld the Claude-side conclusion**, so these are independent readings.

**None of the three passed.** Retrieve the full text with `/codex:result <task-id>`; the jobs also live at
`C:\Users\patip\.claude\plugins\data\codex-inline\state\EA_LAB-4f13320dbc9ad5cf\jobs\<task-id>.log`.
(They ran through the Codex CLI companion in this repo, **not** through Codex Desktop — which is why
Desktop's task list shows nothing.)

> **These are findings, not verdicts.** Codex produces evidence; the lead judges it. Two of the three
> carry pre-existing rules that survive whatever Codex said: the `--resolve-single-leg-baskets` default
> does not flip on Codex's word alone, and ORDER-200 Phase D stays gated on audit **plus** user
> ratification. An audit that says "no" does not need those rules; an audit that said "yes" would have.

---

## 1. ORDER-187 — fail-closed first-lot sizing + Wave5 naked-order guard
`task-ms327ah8-0mtnut` · Codex session `019fa307-be1e-7ae2-9cad-29f7f7a19009` · 10m 39s
**Verdict: NOT closed.** Concrete paths to unintended sizing, a naked Wave5 order reachable by valid
config, and no test in which the guard should fire.

| # | sev | finding |
|---|---|---|
| 1 | **High** | **Wave5 risk-percent sizing uses the wrong side of the spread.** Wave5 records **bid** for a long and **ask** for a short as `g_wave5_entry_ref` (`core/entries/Entry_Wave5.mqh:82`, `:114`); the actual entry uses **ask** for a long and **bid** for a short (`core/LabCore.mqh:381`). Mode 42 sizes from the recorded reference-to-SL distance (`core/ExitManager.mqh:94`, `core/MoneyManagement.mqh:215`). Long, bid 2000.00 / ask 2000.20 / SL 1990.00 → sizing uses 10.00 while true risk distance is 10.20 ⇒ **position exceeds the requested risk**, and any move between signal and `Lab_OpenOrder` widens the gap. Never tested: `TPLREG_Boss_17_Wave5.htm:63` runs `FirstLotMode=41`, not 42. |
| 2 | **High** | **A failed ATR read becomes a valid zero buffer instead of closing the path.** `CopyBuffer` failure returns `0.0` (`core/Indicators.mqh:101`) and Wave5 multiplies it without checking `riskAtr > 0` (`core/entries/Entry_Wave5.mqh:102`). First tick after attach: handles exist, Risk-ATR not yet calculated, swings and tick valid ⇒ `_17_SLbufferATR=0.5` silently becomes zero, `slPrice` equals the raw invalidation level, and `Wave5_SLValid` can approve it (`core/ExitManager.mqh:25`). **The EA opens using a value it failed to read.** |
| 3 | **High** | **The "naked-order guard" is conditional and a legal config switches it off.** `_17_UseStructLevels` is user-switchable (`core/Inputs.mqh:292`). With it false plus `SLMode=30 / FirstLotMode=41 / Stack 90 / Recovery 80 / Hedge 0`: `Exit_InitialSL` returns zero for `SL_NONE` (`core/ExitManager.mqh:138`), `Exit_StructSLMissing` returns false because structural mode is off (`:172`), and `Lab_OpenOrder` sends **`sl=0`** (`core/LabCore.mqh:383`). There is **no after-the-fact naked-position detector**, so exposure is unbounded by this guard until some unrelated exit or risk kill closes it. <br>Fair to the implementation: with `_17_UseStructLevels=true` the mechanism is genuinely **preventive, not detective** — checked before signal publication and again before `Exec_Open` (`Entry_Wave5.mqh:106`, `LabCore.mqh:384`) — that path has a zero-second exposure window. |
| 4 | Medium | **DD-adaptive sizing and the deposit-load gate fail OPEN on an unreadable balance.** Non-positive balance ⇒ multiplier returns `1.0` (`core/MoneyManagement.mqh:44`); the deposit-load calc maps it to zero load, which permits the order (`core/RiskControl.mqh:220`, `:382`). Fixed lot 0.10 + `_4_DdAdaptiveOn=true` + balance reads zero ⇒ both gates pass 0.10 through to `Exec_Open`. Positive-but-stale balances are also accepted with no freshness check in modes 42/43 (`MoneyManagement.mqh:207`, `:227`). |
| 5 | Medium | **A failed volume-step lookup invents a 0.01 step.** Non-positive `SYMBOL_VOLUME_STEP` is replaced with `0.01` (`core/Execution.mqh:30`). Intended 0.015 with a real broker step of 0.001 but a failed property read ⇒ floors to 0.01, which the broker accepts ⇒ **a smaller position than intended, silently**. No artifact exercises this. |
| 6 | Medium | **The guard has no auditable health signal and its should-fire path is untested.** The first structural rejection returns an invalid signal with a reason (`Entry_Wave5.mqh:109`) but `LabCore` discards invalid signals without logging it (`LabCore.mqh:459`), and no checked/fired counter reaches the report ⇒ **"no eligible signal", "guard rejected everything" and "guard never executed" all produce zero trades and look identical.** No saved artifact forces an invalid stop level or a signal-to-send price move. The MM harness runs Boss_12, not Wave5 (`scripts/mm_lotmode_test.ps1:47`); its only mode-42 case is the invalid config `SLMode=30` (`:93`); and it accepts **any** zero-entry report as a fail-closed pass without proving which guard fired (`:142`). |

**Verified clean (coverage, so the above is read in proportion):** invalid/undefined first-lot modes and non-positive inputs rejected at `OnInit` (`MoneyManagement.mqh:64`, `LabCore.mqh:251`) · runtime zero SL distance / tick value / balance in modes 42-43 returns zero rather than falling back to fixed lot (`:202`) · additive progression cannot manufacture a lot from a failed first lot (`:237`) · a lot below broker minimum returns zero rather than being raised to minimum (`Execution.mqh:47`) · structural Wave5 mode rejects Stack/Recovery/Hedge adds at init (`LabCore.mqh:306`) · symbol access uses `_Symbol` throughout, no hard-coded suffix bug (suffix behaviour itself still untested — the only Wave5 report uses unsuffixed `XAUUSD`) · the current Wave5 regression report has 26 trades all carrying a positive SL, **which proves only the normal path** · mode-43 positive sizing and the invalid-anchor / no-SL negative cases do have result evidence (`MMLOT_B_ratio_1x.htm`, `MMLOT_G_bad_anchor.htm`, `MMLOT_H_mode42_no_sl.htm`) · no path deliberately retries a margin rejection with a fallback lot — though market opens never persist `ResultRetcode` or verify filled volume (`Execution.mqh:147`), and no margin-rejection or partial-fill artifact exists.

---

## 2. ORDER-233 — `portfolio_risk_admission.py --resolve-single-leg-baskets`
`task-ms3274w9-ojqwj2` · Codex session `019fa307-a6c4-7672-ad78-07cfc4830a0b` · 10m 10s
**Verdict: not legitimate as the canonical admission input. Leave the default OFF.**

**Codex rejected the framing of the question, which is the most useful thing it did.** The brief offered a
binary — corr 1.0 versus a single-leg proxy — and the answer is that **both are wrong when the real thing
is available**: both second-leg reports already exist, and the scripts that produced the DD95 name the
exact pairs to combine (`_mt5_auto/ichi_basket_merge_mc.ps1:18`, `_mt5_auto/xau_basket_merge_mc.ps1:14`).

It then reconstructed the numbers read-only from commit `6f49e0b7` rather than reasoning about them:

| variant | account 463666728 |
|---|---|
| flag OFF | **73.0437%** |
| flag ON, current representative legs | **38.3556%** |
| **actual summed two-leg monthly basket series** | **37.7484%** |
| current USDJPY / alternate XAU | 33.58% |
| alternate USDJPY / current XAU | 40.96% |
| alternate / alternate | 35.56% |

So the flag lands **0.61 points conservative of the true value — by coincidence, not by identity.**
Representative-leg choice alone swings the same basket DD95 across a **7.38-point range**, which is what
disqualifies the proxy as a default. The unit mismatch is explicit: `expectations.csv:36-39` records
10.77% and 22.19% as two-leg non-separable basket results, while `backtest_corr_reports.csv:18-19` maps
each basket to one constituent leg; the flag converts basket identity to that leg's magic at
`scripts/portfolio_risk_admission.py:193` and `get_corr()` then uses the leg's correlations (`:669`).
The script already calls the broader DD95/correlation formula a screening heuristic (`:75-79`).

**On the multi-leg case left unchanged:** inconsistent as production policy, coherent only as a bounded
experiment. How many rows happen to carry a known DD95 is a *storage* property; both cases are still
multi-leg economic baskets. Under this verdict, leaving multi-leg alone is right and enabling the
single-leg proxy is not — both should use a combined series where one exists, and stay explicitly
conservative where it does not.

**Second defect, latent (no observed failure on account 463):** an incomplete `unit_keys` map silently
disables basket collapse. `:253` never validates that supplied keys cover every represented basket —
`DD95={L1:10,L2:10}` both in basket `BX` with `unit_keys={}` gives **20.0%** where canonical keys give
**10.0%**. Current internal callers happen to supply complete maps.

**What would change the verdict:** build the summed two-leg monthly series under `basket::<id>` and
correlate *that* against the portfolio. Failing that, demonstrate across rolling, stress and OOS windows
that a preselected representative keeps the estimate within a user-ratified tolerance — chosen by a
stable rule, not by which row happens to store the DD95.

---

## 3. ORDER-200 Phase A/C — MRIS crisis models
`task-ms327laa-b45mly` · Codex session `019fa307-eefa-73d3-a8dc-3976402f8dab` · 10m 14s
**Verdict: the Phase A/C evidence does not support even considering Phase D.** Useful as a concept
check. Reconsideration needs source-time-aware data, point-in-time replay, provenance-bound outputs, and
independent holdouts including a fast bank shock and the required 2024 carry-unwind episode.

| # | sev | finding |
|---|---|---|
| 1 | **Blocker** | **Stale observations are relabelled as fresh.** `scripts/mris/mris_macro_feeder.ps1:122-166` discards FRED observation dates, takes the last value, then writes `asof = (Get-Date)` and `data_status = OK`; the scorer trusts that timestamp (`scripts/mris/mris_crisis_models.ps1:31-41,63`). Live proof: `portfolio/mris/barometer_snapshot_macro.csv:6` labels HY_OAS `OK, 2026-07-27 07:37` while `portfolio/mris/webfeed_cache/BAMLH0A0HYM2.csv:796` ends at **2026-07-23**. A weekend shock reaching Monday Asian FX carries Thursday/Friday US credit data as Monday-fresh ⇒ **CREDIT_STRESS can say safe and leave entries unthrottled.** |
| 2 | High | **Absolute regime-dependent thresholds remain** — though, checked explicitly, **no raw-price pin of the `user_pin=110` kind survives**. WTI uses % vs SMA200 and 5-session momentum, SP500 uses momentum, CREDITPX uses relative trend/drop (`crisis_models.json:18,30-31,39-43`). The dangerous one is **US10Y `3.5 → 5.0`** (`:16`): an identical rapid rate shock below 3.5% scores **zero** `rate_level` points while a high-rate-regime shock takes the full weighted 20 — near the active threshold of 60 (`:7`) that flips a real yield shock from active to merely forming. Also absolute: MOVE `70→140` (`:19,32`), HY OAS `3→6` (`:28`), VIX `15→35` (`:33`). |
| 3 | High | **The FRED replay is not point-in-time.** `mris_crisis_backtest.ps1:51-68` downloads the *current* historical CSV carrying only date and value; `:96-113` treats any observation dated on or before the replay date as available. No release timestamp or vintage exists ⇒ **values published or revised later are credited to the earlier date**, so the replay can show CREDIT_STRESS warning earlier than the live system ever could — validation that is optimistic in the dangerous direction. Yahoo EOD bars are likewise collapsed to UTC dates and scored on that date (`:38-48`) with no effective-time convention proving entries could not have occurred earlier that day. |
| 4 | High | **Validation is in-sample and says so.** `crisis_models.json:4` states the anchors were seeded from historical episode reasoning, and `:26` states CREDITPX anchors were measured on COVID, inflation-2022, calm-2019, SVB and yield-spike-2023, then chosen so COVID saturates while 2022/2019 stay mid-scale — **the same episodes the replay selects and judges** (`mris_crisis_backtest.ps1:15-20`, `:205-212`). A model shaped to COVID's broad equity/volatility signature may miss a credit crisis that starts as concentrated bank funding stress. No untouched positive holdout exists. |
| 5 | High | **The replay artifacts are not bound to the audited code, and validate a different effective model.** At `d744e57a` the harness emits date plus three scores (`:158`); the CSVs on disk carry seven columns including coverage (`portfolio/mris/backtest/crisis_covid_2020.csv:1`), and all of them are **untracked** — no commit, config or run manifest ties them to the audited commit. Worse, COVID CREDIT_STRESS runs at coverage **0.65 throughout** (score 66 at `:25`); the missing HY-level and HY-widening components are 35% of the weight (`crisis_models.json:28-29`) and missing weights are renormalized away (`mris_crisis_models.ps1:118-123`), while live output now reports coverage 1 with both HY inputs present (`portfolio/mris/crisis_models_state.json:62`). **A replay 66 from the 65%-coverage variant is ≈42.9 if the missing 35% contributes zero — active in replay, forming live.** Same false-safe direction as finding 1, and it compounds with it: stale-but-`OK` calm HY inputs dilute fast-moving CREDITPX/MOVE/VIX exactly when they matter. |
| 6 | Medium | **The required 2024 test is missing, and timing is never tested.** The spec requires 2020, 2022 **and 2024 carry-unwind** replay (`_triage/ORDER200_MRIS_MACRO_EXTENSION_SPEC.md:16-18,60-62`); the harness has 2020, 2022, 2023 and calm-2019 only, and `portfolio/mris/backtest/crisis_carry_unwind_2024.csv` **does not exist**. The sensitivity test asks only whether the episode peak reaches 60 (`:167-170,192-193,205-212`) — never first-alert date, lead time or useful duration ⇒ **a model that only activates after the damaging move still passes.** In COVID it stays below 60 through March 5 and first activates March 6 (`crisis_covid_2020.csv:16`), and nothing penalizes that. |

<sub>✅ **Finding 6 verified independently and it holds.** I first flagged it as possibly contradicted, having seen `portfolio/mris/backtest/regime_carry_unwind_2024.csv` modified in `git status` — **that was my misreading, and it is worth recording because it is a one-character trap.** The directory carries two parallel families, `crisis_*` (the crisis models these audits cover) and `regime_*` (the Phase-A regime replay). `regime_carry_unwind_2024.csv` exists; **`crisis_carry_unwind_2024.csv` does not** — directory listed 2026-07-27 17:40, `crisis_*` covers only calm_2017 / calm_2019 / calm_2021 / calm_2021h1 / covid_2020 / inflation_2022 / precovid_2019q4 / svb_2023mar / yield_spike_2023. The required 2024 crisis episode is genuinely absent, exactly as Codex reported. Anyone checking this claim must read the **whole filename**, not the episode name.</sub>
