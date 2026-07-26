# AUDIT — guards that were never actually tested

**Opened** 2026-07-26. Read-only forensic sweep. **No verdicts issued here** — this is an evidence
inventory only.

**Pattern being hunted** (template found on `NuiIndy`, written up as Part 3 of
`_triage/ORDER202_HOLDOUT_CONTAMINATION_RETROSCAN.md`): a guard input is defended as "both-window
profitable", but in the window where it was measured it **never triggered**, so the run is identical
to the base and says nothing about the guard; and in the window where it *would* have triggered
there is no base control. A guard always looks harmless where it never fires.

**Method.**
- Guard inventory from `portfolio/DEPLOYMENTS.csv` + every `_vps_deploy/*/*.set`, cross-read against
  the `.mq5`/`.mqh` sources under `ea_projects\` and `ea_template\core\`.
- Evidence base: **6,624 `.ini` under `_mt5_auto/ini`** (the `.ini` is the record of what a run
  actually used, not the `.set`), grouped by `Expert=` and scanned for whether each guard input ever
  took **more than one value** for that EA. One value across every run = there is no control.
- Report metrics pulled from `_mt5_auto/reports/*.htm` (UTF-16LE; decoded before parsing).
- Where a guard is a threshold (DD/daily-loss), I also bounded it: if the **maximum equity drawdown
  observed in any report for that EA** is below the threshold, the guard provably never fired.

---

## Summary table — real money first, most serious first

| # | EA | magic | account | guard input | label | one-line evidence |
|---|---|---|---|---|---|---|
| 1 | EA_BREAKOUT_XAU | 991001 | **REAL** 159503454 + 159475669 | *(no DD/equity kill input exists at all)* | `NO-EVIDENCE` | source has **no** `EmergencyDdPct` / `DailyLossPct` / `MaxSpread` input; DEPLOYMENTS' "closedDD 10%" is a manual rule, not EA code |
| 2 | (Boss)_NewsGuard bridge | all Boss-template EAs | **REAL** ×3 accounts | `NEWSGUARD_BLOCK_<magic>` GlobalVariable veto | `NO-EVIDENCE` | veto is driven by a live watchdog EA; **no backtest ever sets the GV**, so the block path has zero test coverage in 4,990 reports |
| 3 | (BRK)_SqueezeBreakout | 991004 | **REAL** 159503454 | `_06_EmergencyDdPct=25.0`, `_06_DailyLossPct=5.0` | `NO-EVIDENCE` | **zero `.ini` exist for this Expert**; only artefact is `CORR_SQZ_XAU_MAIN` (17 trades, eqDD 1.68%) |
| 4 | (Boss)_ZeusInspired_GridLog | 990101 | **REAL** 159503454 (XAU) | `_06_EmergencyDdPct=25.0` | `NEVER-FIRED` | single value across **204** runs; max eqDD ever recorded for this EA = 16.04% (AUDJPY), 3.97% on the deployed XAU leg |
| 5 | (Boss)_ZeusInspired_GridLog | 990101 | **REAL** 159503454 | `_06_DailyLossPct=5.0` | `NO-CONTROL` | single value across **204** runs; no run at any other value, and reports do not record per-day loss |
| 6 | (Boss)_ZeusInspired_GridLog | 990101 | **REAL** 159503454 | `_06_MaxPositions=6`, `_05_DdTier1/2Pct`, `_05_DdHardCapMult` | `NO-CONTROL` | all single-valued across 204 runs (`_06_MaxTotalLot` is the only cap that was ever varied) |
| 7 | (BRK)_TrendlineBreakout | 991002 | **REAL** 159503454 | `_04_UseAdxGate` | `FIRED-AND-MEASURED` ⚠ | clean single-variable A/B exists — and the gate **loses** on 2 of 3 windows (see §7) |
| 8 | (BRK)_TrendlineBreakout | 991002 | **REAL** 159503454 | `_06_EmergencyDdPct=25.0`, `_06_DailyLossPct=5.0` | `NEVER-FIRED` | worst eqDD in its six A/B reports = **5.57%** (`TL2_FWD`); threshold is 25% |
| 9 | (Boss)_LondonConsoBreakout | 990005 / 99000512 | **REAL** 159475669 | `_01_ConsoStartHour=6`, `_01_TradeEndHour=18` | `NO-CONTROL` | single-valued across **305** runs; only `_01_ConsoEndHour` (10 vs 11) was ever varied |
| 10 | Boss-template chassis (all Boss_1x legs) | — | **REAL + DEMO** | `_0_MaxSpread` | `NEVER-FIRED` (and `DEAD-CODE` until ORDER-129) | `=0` in **613/613** ini and in every deployed `.set`; `Exec_SpreadOK()` returns `true` immediately at 0 |
| 11 | Boss-template chassis | — | **REAL + DEMO** | `TrendFilter=70` | `NEVER-FIRED` | 70 = `TFILTER_NONE` — the filter is **off** in every deployed set (617/625 runs at 70) |
| 12 | Boss_16_KangarooGrid | (BOSS16 bundle, unattached) | bundle | `_16_EmergencyDDPct=70.0` | `NEVER-FIRED` | single value across 26 runs; max observed eqDD for this EA = **25.12%** — nowhere near 70% |
| 13 | Boss_16_KangarooGrid | bundle | bundle | `RC_AcctDDLimitPct=0.0` | `NEVER-FIRED` | 0 = gate disabled (`RiskControl.mqh:93` early-returns); only non-zero values in the whole corpus are the `AcctGate_Test` unit-test inis |
| 14 | Boss_16_KangarooGrid | bundle | bundle | `_16_MaxControlledLossUsd`, `_16_OverlapMin*`, `_16_FlattenMinOrders`, `_16_MaxSlPips` | `NO-CONTROL` | every one single-valued across 26 runs; `_16_FlattenOn=false` in all 26 (flatten path untested) |
| 15 | (Boss)_RSI_MR_GridLog | 990103 | DEMO 463666728 (ex-REAL) | `_06_EmergencyDdPct=40.0` | `NEVER-FIRED` | single value across 55 runs; max eqDD ever = **8.32%**. The EA was pulled off real money for hitting **25% closed DD** — the in-EA guard at 40% could not have helped |
| 16 | (Boss)_RSI_MR_GridLog | 990103 | DEMO | `_06_DailyLossPct=5.0`, `_06_MaxPositions=8`, `_06_MaxTotalLot=1.0`, `_02_SlMaxPips=600` | `NO-CONTROL` | all single-valued (55 / 205 runs) |
| 17 | LondonORB_XAU (SS1) | 992003 | DEMO 415573666 | `_02_MaxOrAtrH1=2.5` (news-blown ceiling) | `NO-CONTROL` | single value across **53** runs, while the *floor* `_02_MinOrAtrH1` was fanned 0.5/0.8/1.2 |
| 18 | LondonORB_XAU (SS1) | 992003 | DEMO | `_07_UseTrendFilter=true` | `FIRED-AND-MEASURED` ⚠ | A/B exists but **the labelled MAIN base is a 0-trade artefact** (`SS1L_base_off_MAIN`) — see §18 |
| 19 | PivotBreakout_XAU | 992017 | DEMO 463666728 | `_03_StartGmt=0` / `_03_EndGmt=24` | `NEVER-FIRED` (open by construction) | `InSession()` returns true for all hours at 0/24; all 4 ini use 0/24 — never narrowed |
| 20 | PivotBreakout_XAU | 992017 | DEMO | `_05_EmergencyDdPct=25.0`, `_05_DailyLossPct=5.0` | `NEVER-FIRED` | single-valued; max eqDD across its reports = **10.13%** (`GPB_sl2p5_tp3_MAIN`) |
| 21 | TrendRider_XAU (W2 S1) | 992004 | DEMO 415573666 | `_03_StartGmt=7` / `_03_EndGmt=20` | `NO-CONTROL` | single-valued across 38 runs — the session window was never opened to 0/24 as a control |
| 22 | TrendRider_XAU | 992004 | DEMO | `_05_EmergencyDdPct=25.0`, `_05_DailyLossPct=5.0` | `NEVER-FIRED` | single-valued (17–38 runs); max eqDD = 11.23% (XAG holdout), 6.41% on XAG BWD |
| 23 | TsMom_XAU (S2) | 992001 | DEMO 415573666 | `_01_UseAdxGate` | `NO-CONTROL` | deployed `.set` says **`false`**, but all 12 ini for this EA say `_01_UseAdxGate=true` — no ini records the deployed configuration |
| 24 | TsMom_XAU | 992001 | DEMO | `_04_EmergencyDdPct=25.0` | `NO-EVIDENCE` | input never appears in any ini for this Expert |
| 25 | EA_SUPERTREND / EA_DONCHIAN (crypto legs) | 990025 / 990030 | DEMO | `_03_UseAdxFilter=true`, `_03_ADXthreshold=20.0` | `NO-CONTROL` | single-valued across 56 / 22+29 runs for these Experts (the `false` variants live under a *different* Expert, `EA_EMATREND`) |
| 26 | EA_SUPERTREND / EA_DONCHIAN | 990025 / 990030 | DEMO | `_05_MaxSpreadPts=0` | `NEVER-FIRED` | `=0` in 187/187 runs; source: `if(_05_MaxSpreadPts <= 0) return true;` |
| 27 | EA_BREAKOUT_XAU | 991001 | **REAL** | `_03_AtrExpandRatio=1.0` (vol gate) | `NO-CONTROL` | 220 runs at 1.0; the only `0.0` run (`BRKXAU_DIAG_ALLOPEN`) is a 25-day 2026-07 debug run that **also** flipped `_04_UseDailyEma` — two variables, not a control |
| 28 | EA_BREAKOUT_XAU | 991001 | **REAL** | `_04_UseDailyEma=true` (trend veto) | `FIRED-AND-MEASURED` (partial) | `false` runs exist (7 of 147) but all on the 25-day 2026-07 debug window — see §28 |
| 29 | EmaStoRev (SMCSTO) | 991070 | DEMO 463666728 | `_08_UseAdxFilter=true` | `NO-CONTROL` | `true` in 103/103 runs for Expert `EmaStoRev` (the `false` runs belong to `(EXP)_StoMultiTap`, a different EA) |
| 30 | (EXP)_IchiADX_Naked | 990066-990069 | DEMO | `AdxMin` | `FIRED-AND-MEASURED` | varied 20/25/30 across 73 runs |
| 31 | Boss_17_Wave5 | 990301-990303 | DEMO | `_9_MaxLevels=1` (depth cap) | `NEVER-FIRED` | 58 runs at 1 = single position; a cap of 1 can never bind on an EA that opens one position |
| 32 | Boss_14_GridLog cohort | 990201-990208 | DEMO 415573666 | `RC_MaxLevelsOverride=6` | `NEVER-FIRED` | override equals `_9_MaxLevels=6` in all 517 runs → the override never changes the effective cap |
| 33 | Boss_14_GridLog cohort | 990201-990208 | DEMO | `RC_AcctDDLimitPct` | `NO-CONTROL` | absent from the deployed `.set` (falls back to compiled default 0 = off); ini values 1.0/0.1/0.01 are cage tests, not strategy runs |
| 34 | (Boss)_ZeusInspired_GridLog | 990110 | DEMO 415573666 | `_50_RegimeMode` / `_50_AllowTrend*` / `_50_AllowRange` | `FIRED-AND-MEASURED` | pre-graft baseline `ZNOOP_AUDJPY_baseline` vs gated `ZC_m1rng25_M4_MAIN`, same symbol/TF/window — see §34 |
| 35 | Boss_12_Breakout (MacroGate leg) | 990120 | DEMO 463666728 | MacroGate `MACROGATE_BLOCK_<magic>` | already withdrawn | ORDER-211 (2026-07-25) reduced it to advisory-only — the gate's benefit had been measured through a broken classifier. Listed for completeness, not re-opened here |
| 36 | (EXP)_AdaptGridMC | unattached bundle | bundle | `_05_KillDdPct=20.0` | `NEVER-FIRED` | single value across 6 runs; max eqDD for this Expert = **1.79%** |
| 37 | PairSpread_StatArb | 990984 | DEMO 463666728 | `_01_StopZ` | `FIRED-AND-MEASURED` | varied 2.5/3.0/3.5/4.0 across 16 runs |
| 38 | (BRK)_FlagPennant, (MR)_*, (TRND)_* probes | unattached | bundle/none | `_0X_EmergencyDdPct`, `_0X_DailyLossPct` | `NO-CONTROL` | the whole strategy-EA family carries the same two inputs at 25.0/5.0 and **not one** of them was ever varied in any run |

### Counts per label

| label | count |
|---|---|
| `FIRED-AND-MEASURED` | **6** (rows 7, 18, 28, 30, 34, 37) — of which **3 are qualified** (7 = gate hurts; 18 = base is a 0-trade artefact; 28 = control window is a 25-day debug run) |
| `NEVER-FIRED` | **13** (rows 4, 8, 10, 11, 12, 13, 15, 19, 20, 22, 26, 31, 32, 36 → 14 rows, 13 distinct guards after merging 8's pair) |
| `NO-CONTROL` | **14** (rows 5, 6, 9, 14, 16, 17, 21, 23, 25, 27, 29, 33, 38 + Boss_16 group) |
| `NO-EVIDENCE` | **4** (rows 1, 2, 3, 24) |
| `DEAD-CODE` | **1** (row 10, historical: `_0_MaxSpread` was declared-but-never-read until ORDER-129 wired it in) |

---

## Per-guard detail

### §1 — EA_BREAKOUT_XAU 991001 has no drawdown guard at all · REAL MONEY, two accounts

`ea_projects/EA_BREAKOUT_XAU/EA_BREAKOUT_XAU.mq5` — grepping the whole file for
`EmergencyDd|DailyLoss|MaxSpread` returns **nothing**. Its only guard-like inputs are
`_03_AtrExpandRatio` (vol gate, line 252), `_04_UseDailyEma` (line 136/188) and `_06_AllowLive`
(line 288). There is no equity kill, no daily-loss halt, no depth cap, no spread block.

`portfolio/DEPLOYMENTS.csv` lists `kill_rule = closedDD 10%` for both 991001 rows. That rule lives in
the monitoring layer and in the operator's head — **nothing in the EA enforces it**. This is the
single largest guard gap on real money in the portfolio: not a guard that was never tested, a guard
that does not exist.

Max eqDD observed for this Expert in the covered reports: **6.15%** (`BRKSMOKE_XAGUSD`), so nothing
in the record contradicts the 10% rule — but nothing tests it either.

### §2 — NewsGuard veto · REAL MONEY, three accounts, zero test coverage

`ea_template/core/Execution.mqh:79-92` — the bridge reads GlobalVariable `NEWSGUARD_BLOCK_<magic>`
and vetoes new orders when it is ≥0.5. `(Boss)_NewsGuard` is a separate watchdog EA that sets the
variable from `EA_LAB_news_week.csv`, with its own guards `StaleMaxHours=48`, `PreNewsMin=30`,
`PostNewsMin=15`, `GuardConfig` policy string.

Nothing in the Strategy Tester ever sets that GlobalVariable. Across all 4,990 reports the veto
branch is unreachable. The memory note records NewsGuard as **attached to 3 real accounts on
2026-07-24**. Every one of its parameters (the 30/15-minute window, the 48-hour staleness fail-safe,
the C/B/N policy per magic) is untested by anything except live observation.

Note the asymmetry with MacroGate two lines below (`Execution.mqh:118-123`), which *does* carry a
`MQL_TESTER` exemption and a staleness check. The NewsGuard bridge has neither.

### §3 — (BRK)_SqueezeBreakout 991004 · REAL MONEY, no ini at all

`grep -il 'Expert=.*SqueezeBreakout' _mt5_auto/ini/*.ini` → **zero files**. The only report that
mentions a squeeze EA is `CORR_SQZ_XAU_MAIN` under Expert `O076\corrSqueeze` (XAUUSD H4
2023.01–2026.07, 17 trades, eqDD 1.68%) — a correlation run, not a robustness funnel.

Guards in `ea_projects/(BRK)_SqueezeBreakout/(BRK)_SqueezeBreakout_rev01.mq5:53-54`:
`_06_DailyLossPct=5.0`, `_06_EmergencyDdPct=25.0`, both wired at line 101-102 into the same
`CanTrade()` halt. Neither has any run behind it.

### §4-6 — Zeus 990101 XAUUSD · REAL MONEY

`ea_projects/(Boss)_ZeusInspired_GridLog/(Boss)_ZeusInspired_GridLog_rev01.mq5`:

```
122: input double _06_DailyLossPct  = 5.0;
123: input double _06_EmergencyDdPct= 25.0;    // close everything + halt new baskets past this equity DD
285:    if(dd_pct >= _06_EmergencyDdPct)  ... "RISK: emergency DD ... -> halt"
471:    if(dd_pct >= _06_EmergencyDdPct)  ... "EMERGENCY EXIT: DD %.2f%% >= %.2f%%"
```

Across **204 ini** for this Expert: `_06_EmergencyDdPct` is `25.0` in every single one.
`_06_DailyLossPct` is `5.0` in every single one. `_06_MaxPositions` is `6` in every single one.
All five `_05_DdTier*/DdHardCapMult` values are constant. The only risk input ever varied is
`_06_MaxTotalLot` (0.10 / 0.60 / 4.8 / 6.0 / 12.0) and `_02_SlMaxPips`.

Highest equity drawdown recorded anywhere for this EA:

| report | symbol/TF/window | eqDD max |
|---|---|---|
| `COMM_ZEUS_XAGUSD_FWD` | XAGUSD H1 2025.01–2026.07 | **6.45%** |
| `ZC_m1rng25_M4_MAIN` | AUDJPY H1 2023.01–2026.07 | **16.04%** |
| `ORDER166_990110_ZEUS_AUDJPY_BWD` | AUDJPY H1 2020–2023 | 13.34% |
| `CORR_ZEUS_XAU_MAIN` (the deployed symbol) | XAUUSD H1 2023.01–2026.07 | **3.97%** |

25% was never approached on any symbol, and on the deployed XAU leg the worst case is under 4%. The
kill-switch protecting a real-money grid has never been exercised in any test.

### §7 — TrendlineBreakout 991002 ADX gate · the one clean A/B, and it goes the wrong way

A genuine single-variable pair exists: `TL2*` (gate on) vs `TL2NG*` (gate off), same
Expert/symbol/TF/window, differing exactly at `_04_UseAdxGate` (`TL2NG` omits `_04_AdxMin`, which is
inert when the gate is off).

| window | gate ON | gate OFF |
|---|---|---|
| BWD 2020.01–2023.01 | PF **1.25** · 117t · net 184.22 · eqDD 1.75% | PF **1.26** · 150t · net 235.41 · eqDD 2.31% |
| 2023.01–2025.01 (labelled HOLDOUT) | PF **1.60** · 96t · net 326.42 | PF **1.40** · 120t · net 268.59 |
| 2025.01–2026.07 (labelled FWD) | PF **0.99** · 63t · net **−12.97** | PF **1.23** · 81t · net **+339.87** |

The gate helps in exactly one of three windows and turns a profitable stretch into a loss in the most
recent one. This is a *measured* guard — which makes it more actionable than the untested ones, not
less. Files: `_mt5_auto/ini/TL2{,NG}_{BWD,HOLDOUT,FWD}.ini`, reports of the same names.

Caveat carried from the known tester-cache gotcha: these ini list only 6 inputs, so
`_06_EmergencyDdPct` / `_06_DailyLossPct` in those runs came from the per-terminal cache rather than
the ini. Their values in the run are visible in the report header (`_06_DailyLossPct=5.0`,
`_06_EmergencyDdPct=25.0`) — confirmed by decoding `TL2_BWD.htm`.

### §8 — the strategy-EA family DD guard is structurally unfireable at these lot sizes

Every EA in the `(BRK)_ / (MR)_ / (TRND)_ / (TRD)_ / (VWAP)_` family carries the identical pair:

```
input double _0X_DailyLossPct   = 5.0;
input double _0X_EmergencyDdPct = 25.0;
...
if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_0X_EmergencyDdPct){ g_halted_today=true; return false; } }
```

These are single-position EAs running `_05_LotSize=0.01` on a 10,000 deposit. Worst equity drawdown
found anywhere in the family: **11.23%** (TrendRider XAG holdout), typically 1–6%. Across 348 ini
carrying `_0X_EmergencyDdPct`, the value is `25.0` in **every one**; across 396 carrying
`_0X_DailyLossPct`, it is `5.0` in all but 7 (`3.0`, cent-scalp probes S3/CENTS). The guard is
copy-pasted boilerplate that has never been engaged, and its threshold has never been chosen by
evidence.

### §10-11 — Boss chassis: two guards that are off everywhere while looking on

**`_0_MaxSpread`.** `ea_template/core/Execution.mqh:61-64` documents the history in its own comment:

> `// ORDER-129: _0_MaxSpread was a declared-but-never-read input (operator sets it believing`
> `// entries are blocked, EA opens through news/rollover widening anyway).`

That is a `DEAD-CODE` finding already caught and fixed. What is *not* recorded anywhere: the input is
`0` in **613 of 613** ini and in every deployed `.set` (`BOSS14_GBPJPY`, `BOSS16_KANGAROO_XAU`), and
`Exec_SpreadOK()` returns `true` immediately when `<= 0`. So post-fix the guard is live code that has
still never blocked a single order in any test or any deployment.

**`TrendFilter`.** `ea_template/core/Inputs.mqh:77` — `TFILTER_NONE = 70`. Every deployed Boss `.set`
carries `TrendFilter=70`, i.e. **no filter**. 617 of 625 runs are at 70; only 8 (`EALabTpl\Boss_11`,
`EA_LabTemplate`) ever used 71 (`ATR_EXPAND`). An operator reading `TrendFilter=70` on a live chart
would reasonably think a trend filter is engaged. It is not.

### §12-14 — Boss_16 Kangaroo cage: every cage bar is a single value

26 ini, and these are constant in all of them: `_16_EmergencyDDPct=70.0`, `_16_MaxOrdersPerSide=10`,
`_16_MaxLotPerOrder=1.0`, `_16_MaxSlPips=9000.0`, `_16_MinDistPips=150.0`,
`_16_MaxControlledLossUsd=400.0`, `_16_OverlapMinUsd=5.0`, `_16_OverlapMinOrders=4`,
`_16_FlattenMinOrders=6`, `RC_AcctDDLimitPct=0.0`, `RC_MaxLevelsOverride=0`, `RC_PersistHalt=true`.
Also `_16_FlattenOn=false` in all 26 — the flatten path never ran.

Highest eqDD for this Expert: **25.12%** (`BOSS16_KANG_XAU_H1_SELL`, XAUUSD H1 2023.01–2026.07).
The emergency close-all sits at 70%. `RiskControl.mqh:93` — `if(RC_AcctDDLimitPct <= 0.0) return
true;` — the account-level gate is disabled at its deployed value.

The `Inputs.mqh:277` comment claims *"cage KillDD fires first at default profile"*. Nothing in the
run record demonstrates that; no run in the corpus shows either kill firing.

### §15 — RSI_MR 990103: the guard that could not have saved it

`_06_EmergencyDdPct=40.0` in all 55 ini. Max eqDD ever recorded: **8.32%**
(`O166_RSIMR_F2OOS_PINNED` / `O168_W2_OOS_9` / `O168_W3_IS_9`, EURUSD H1). This EA was
**REMOVED from real account 159503454 on 2026-07-18 for hitting the 25% closed-DD kill trigger**
(`portfolio/DEPLOYMENTS.csv`). The in-EA guard sits 15 points above the level that actually forced
the removal, and was never tested at any level. What saved the account was the external monitoring
rule, not the input labelled as the safety net.

### §17-18 — LondonORB 992003: the ceiling is untested and the floor's control is broken

`ea_projects/(BRK)_LondonORB_XAU/(BRK)_LondonORB_XAU_rev01.mq5:192`:

```
if(width < _02_MinOrAtrH1*atrH1 || width > _02_MaxOrAtrH1*atrH1) return;   // OR-width band gate
```

Both halves of the band are guards. The **floor** was fanned (0.5 / 0.8 / 1.2 — 61 runs) and the
README records it as a fragile axis. The **ceiling** `_02_MaxOrAtrH1` is `2.5` in **53 of 53** runs —
the "not news-blown" protection has never been moved, so we do not know whether it ever excludes a
bar, nor what it costs.

The trend filter (`_07_UseTrendFilter`, default `false` at line 64, deployed `true`) does have a
labelled A/B — and half of it is void:

| run | inputs | result |
|---|---|---|
| `SS1L_base_off_MAIN` | filter absent (=off) | **PF 0.00 · 0 trades** ← artefact, not a control |
| `SS1L_trend_on_MAIN` | `_07_UseTrendFilter=true` | PF 1.22 · 499t · net 471.57 |
| `SS1L_lot02_ctrl_MAIN` | filter absent, lot 0.2 | PF 1.17 · 732t · net 1068.60 |
| `SS1L_base_off_BWD` | filter absent | PF 1.07 · 717t · net 170.07 |
| `SS1L_trend_on_BWD` | `_07_UseTrendFilter=true` | PF 1.07 · 492t · net 113.80 |

Reading it honestly: on BWD the filter removed 225 trades, left PF **unchanged at 1.07**, and cut net
profit by a third. On MAIN the only usable base is the lot-0.2 control (1.17 vs 1.22). The evidence
that this filter earns its place is thin, and the run that was *named* as its MAIN base produced zero
trades and should not be cited.

### §19 — PivotBreakout 992017: a session gate deployed wide open

`(TRND)_PivotBreakout_XAU_rev01.mq5:69`:

```
bool InSession(const int gh){ if(_03_StartGmt<=_03_EndGmt) return (gh>=_03_StartGmt && gh<_03_EndGmt); ... }
```

Deployed and tested at `_03_StartGmt=0`, `_03_EndGmt=24` → `gh>=0 && gh<24` → **true for every
hour**. The input exists, is documented as a guard, and is inert at its deployed value; all 4 ini for
this Expert use 0/24, so no narrower window was ever tried either. Same construction and same 0/24
values on `MomentumBurst_XAUc` (`_03_`) and `RangeFade_XAUc` (`_04_`).

### §23 — TsMom 992001: the deployed value appears in no run

`_vps_deploy/S2_TSMOM_XAU/S2_TsMom_XAU_deploy.set` → `_01_UseAdxGate=false`.
All 12 ini for Expert `c091c\TsMom_XAU` → `_01_UseAdxGate=true` (with `_01_AdxMin` fanned 20/25/30).
`_04_EmergencyDdPct` never appears in any ini for this EA.

So the ADX gate was optimised in the on-state and shipped in the off-state. That is defensible if the
fan showed it did not help — but the run record contains no `false` run to point at, and the
DEPLOYMENTS note ("ADX regime-gate tried and did not help") is not reproducible from the ini corpus.

### §27-28 — BRK 991001 volatility and EMA vetoes · REAL MONEY

`EA_BREAKOUT_XAU.mq5:252` — `if(atr_now <= atr_ma * _03_AtrExpandRatio) return;` At the deployed
`1.0` this requires ATR(14) above its own 20-bar mean, i.e. it is a real, frequently-binding gate.
147 ini carry it; **146 at `1.0`**. The single `0.0` run is `BRKXAU_DIAG_ALLOPEN.ini` — dated today,
window `2026.07.01 → 2026.07.26` (25 days), and it simultaneously sets `_04_UseDailyEma=false`. Two
variables changed at once on a 25-day window is not a control.

`_04_UseDailyEma` does have `false` runs (7 of 147: `BRKXAU_DIAG_V2_NOEMA`, `V3_NOEMA`, `BARS8`,
`M2_*`, `BOTHDIR`, `ALLOPEN`) — but every one of them is on that same 25-day 2026-07 window. There is
no `UseDailyEma=false` run on MAIN or BWD anywhere in the corpus. The daily-EMA veto on a live
real-money EA has never been priced on a meaningful window.

### §34 — Zeus regime gate 990110 (demo): a real control does exist

`_50_RegimeMode` was never set to `0` for the `(Boss)_ZeusInspired_GridLog_rev01` Expert — but the
**pre-graft** build (`Expert=_ZeusBaseline_pregraft`, no `_50_` inputs at all) provides the control:

| run | config | window | result |
|---|---|---|---|
| `ZNOOP_AUDJPY_baseline` | pre-graft, no regime gate | AUDJPY H1 2023.01–2026.07 | PF **1.12** · 186t · net 663.80 · eqDD 12.16% |
| `ZC_m1rng25_M4_MAIN` | `RegimeMode=1`, range-only | AUDJPY H1 2023.01–2026.07 | PF **1.24** · 134t · net 932.47 · eqDD 16.04% |

The gate removed 52 trades and raised PF — it demonstrably fires and demonstrably changes the
outcome. Two caveats to carry: the window ends `2026.07.01` (inside the 2026H1 holdout), and lot
settings between the two builds were not verified identical here.

---

## Coverage — what I could NOT assess, and why

Honest gaps. Each of these is a row I refused to pad.

1. **All MT4 real-money deployments (account 141049900).** `Zeus Gold Hedge V1.2_fix` (7777),
   `Gold_Kangaroo L1-L4` (1112-1115). No MQL4 sources in `ea_projects\`, no MT4 ini/report corpus
   comparable to `_mt5_auto/ini`. `Gold_Kangaroo` is described as "capped-mart not validated" and
   `Zeus Gold Hedge` as "no-SL grid — user experiment"; their caps and the "manual kill floating DD
   40%" rule are entirely unassessed here.
2. **All MT4 demo deployments (account 69424711).** `UnNomGuaiV1.132` ×2, `RSI from pips_EA` (5888),
   `swb grid 4.1.0.3_h` (990), `ClevrFX_EA` (magic unknown). Same reason.
3. **User-mix EAs on real account 159475669 that the lab does not certify**: `MatchaGrid` (20240001),
   `GoldReaper` legs 8001-8015, `NuiIndy` (1524). NuiIndy's `CutLoss_Percent` is the case this audit
   was modelled on and is already documented in ORDER-202 Part 3. `MatchaGrid` and `GoldReaper` are
   locked binaries — `The Gold Reaper` shows a single `MaxSpread=500.0` across 13 ini (single-valued
   ⇒ would be `NO-CONTROL`) but without source I cannot confirm what it gates, and the known
   `inert-axis-fake-plateau` finding already records `GoldReaper StartLots` as an inert axis. I did
   not attempt a source-level guard inventory on locked EAs.
4. **`ST_EA03`, `ST03 replica`, `(Boss)_RSI_MR_GridLog` 990103 on 159503454** — REMOVED rows, not
   assessed for current exposure (their `InpSessionFilter=false` / `InpUseMtfGate=false` in all 225
   `EA_RUNNER_ST03` ini would be `NEVER-FIRED`, but the deployment is gone).
5. **The eqDD ceiling figures are a lower bound.** My per-report drawdown extraction completed
   **2,842 of 4,990** reports before I stopped it (`scratchpad/dd.tsv`); it processes files in
   directory order, so coverage per EA is partial. Every "max eqDD = X%" claim above should be read
   as "at least one run reached X%, and no covered run exceeded it". None of the `NEVER-FIRED`
   conclusions rest on the ceiling alone — each also has the single-valued-input evidence.
6. **Daily-loss guards cannot be settled from reports at all.** `_0X_DailyLossPct=5.0` fires on a
   *within-day* equity decline, which the MT5 HTML report does not expose. For every EA where total
   eqDD stayed under 5% the guard provably never fired; for Zeus (16.04%), Boss_16 (25.12%),
   Boss_14 (27.02%), RSI_MR (8.32%), MacdDiv (17.01%), PairSpread (21.34%) and Donchian (22.54%) it
   is **undetermined** and would need Experts-log block counts or a deals-CSV reconstruction.
7. **Live/demo firing counts.** `portfolio/live_deals/*.csv` records closed deals only — no column
   records a blocked entry, a halted day, or a kill-switch trip. Nothing in the live record can
   confirm or deny that any guard has fired in production. This is itself a gap worth closing.

---

## The single missing run, per unsettled guard

Queue-ready. Each line is one run (or one pair) that would convert the label.

| # | EA | symbol | TF | window | run to add |
|---|---|---|---|---|---|
| 3 | (BRK)_SqueezeBreakout 991004 | XAUUSD | H1 | BWD 2020.01–2022.12 | any run at all, then a second at `_06_EmergencyDdPct=100` as base — currently zero runs exist |
| 4 | Zeus 990101 | XAUUSD | H1 | BWD 2020.01–2022.12 | base at `_06_EmergencyDdPct=100.0` vs deployed `25.0`, `_06_MaxTotalLot` at the live value — the stress window is where a DD kill would matter |
| 5 | Zeus 990101 | XAUUSD | H1 | BWD 2020.01–2022.12 | base at `_06_DailyLossPct=100.0` vs `5.0` (single variable, separate run from the above) |
| 6 | Zeus 990101 | XAUUSD | H1 | MAIN 2023.01–2025.12 | base at `_06_MaxPositions=99` vs `6` |
| 9 | LondonConso 990005 | EURUSDc | H1 | MAIN 2023.01–2025.12 | base at `_01_ConsoStartHour=0` / `_01_TradeEndHour=24` vs deployed 6/18 |
| 12 | Boss_16 Kangaroo | XAUUSD | H1 | BWD 2020.01–2022.12 | base at `_16_EmergencyDDPct=100.0` vs `70.0` — must be BWD, since MAIN never reaches 25% |
| 13 | Boss_16 Kangaroo | XAUUSD | H1 | BWD 2020.01–2022.12 | `RC_AcctDDLimitPct=20.0` vs deployed `0.0` |
| 14 | Boss_16 Kangaroo | XAUUSD | H1 | MAIN 2023.01–2025.12 | `_16_FlattenOn=true` vs `false` (the flatten path has never executed) |
| 15 | RSI_MR 990103 | EURUSDm | H1 | BWD 2020.01–2022.12 | `_06_EmergencyDdPct` at `25.0` (the level that actually killed it live) vs `40.0` |
| 17 | LondonORB 992003 | XAUUSDm | M15 | MAIN 2023.01–2025.12 **and** BWD | `_02_MaxOrAtrH1=99.0` (ceiling removed) vs `2.5` |
| 18 | LondonORB 992003 | XAUUSDm | M15 | MAIN 2023.01–2025.12 | **re-run `SS1L_base_off_MAIN`** — the existing one returned 0 trades and is unusable |
| 19 | PivotBreakout 992017 | XAUUSDm | H4 | MAIN 2023.01–2025.12 | `_03_StartGmt=7`/`_03_EndGmt=20` vs deployed 0/24 — is the wide-open setting actually best? |
| 21 | TrendRider 992004 | XAUUSD | H4 | MAIN 2023.01–2025.12 **and** BWD | `_03_StartGmt=0`/`_03_EndGmt=24` vs deployed 7/20 |
| 23 | TsMom 992001 | XAUUSDm | H4 | MAIN 2023.01–2025.12 **and** BWD | `_01_UseAdxGate=false` (the **deployed** value) — no run of the shipped config exists |
| 25 | EA_SUPERTREND 990025 / EA_DONCHIAN 990030 | BTCUSDm / ETHUSDm | H4 | MAIN 2023.01–2025.12 | `_03_UseAdxFilter=false` vs `true` |
| 27 | EA_BREAKOUT_XAU 991001 | XAUUSD | H1 | MAIN 2023.01–2025.12 **and** BWD 2020–2022 | `_03_AtrExpandRatio=0.0` with `_04_UseDailyEma` held at `true` — one variable, real window (existing `ALLOPEN` run changes two on 25 days) |
| 28 | EA_BREAKOUT_XAU 991001 | XAUUSD | H1 | MAIN 2023.01–2025.12 **and** BWD 2020–2022 | `_04_UseDailyEma=false` with `_03_AtrExpandRatio` held at `1.0` |
| 29 | EmaStoRev 991070 | EURUSDm | H1 | MAIN 2023.01–2025.12 **and** BWD | `_08_UseAdxFilter=false` vs `true` (locked config, SL≥3.0) |
| 31 | Boss_17_Wave5 990301-303 | XAUUSDm | H1 | MAIN 2023.01–2025.12 | `_9_MaxLevels=3` vs `1` — the cap is only meaningful if the EA is allowed to stack |
| 32 | Boss_14 cohort | GBPJPYm | H4 | BWD 2020.01–2022.12 | `RC_MaxLevelsOverride=3` vs `6` (=`_9_MaxLevels`, currently a no-op) |
| 33 | Boss_14 cohort | GBPJPYm | H4 | BWD 2020.01–2022.12 | `RC_AcctDDLimitPct=20.0` vs default `0.0` |
| 36 | AdaptGridMC | BTCUSDm | H1 | BWD 2020.01–2022.12 | `_05_KillDdPct=100.0` vs `20.0` — MAIN never exceeded 1.79% so BWD is the only window with a chance |
| 38 | strategy-EA family (one representative, e.g. PivotBreakout) | XAUUSDm | H4 | BWD 2020.01–2022.12 | `_0X_EmergencyDdPct=100` + `_0X_DailyLossPct=100` vs `25/5`, at a lot size where 25% is reachable (e.g. `_05_LotSize=0.5`) — one run settles the whole boilerplate family |

Two entries have **no backtest that can settle them** and need a different instrument:

- **§1 EA_BREAKOUT_XAU has no DD guard.** Nothing to A/B. This is a build decision (add an
  `_0X_EmergencyDdPct` to match the rest of the family) or an accepted exposure, not a run.
- **§2 NewsGuard.** The veto is driven by a GlobalVariable no tester sets. Settling it needs either a
  tester harness that injects `NEWSGUARD_BLOCK_<magic>` from a news CSV (the way MacroGate's
  `_MG_RegimeFile` replay works), or Experts-log block-event counting on the live terminals.
  The MacroGate CSV-replay pattern already in the repo is the obvious template.

---

# Lead-engineer review of this audit (Claude/Opus 2026-07-26)

Spot-checked the two rows with the largest consequences before acting on any of it.

## §7 TrendlineBreakout 991002 (REAL money) — CONFIRMED, and stronger than reported

The A/B is real: 6 `.ini` carry `_04_UseAdxGate`, three `false` (`TL2NG_*`) and three `true`
(`TL2_*`), same symbol/TF, three separated windows. Pulled the numbers myself:

| window | gate OFF (`TL2NG`) | gate ON (`TL2`, = the gated config) |
|---|---|---|
| 2020.01–2023.01 | PF 1.26 | PF 1.25 |
| 2023.01–2025.01 | PF 1.40 · +268.59 · 120t | **PF 1.60 · +326.42 · 96t** |
| 2025.01–2026.07 | **PF 1.23 · +339.87 · 81t** | **PF 0.99 · −12.97 · 63t** |

**Correction to the audit's wording:** it says the gate "loses 2 of 3 windows". It does not —
1.25 vs 1.26 on BWD is noise, and the gate clearly *wins* 2023–25. The accurate statement is
sharper and worse: **the gate's only clear win is the middle window, and its clear loss is the
most recent one** — the window closest to live conditions, where it turns +339.87 into −12.97.
That is a regime-dependence signature on a config running on a real cent account
(159503454, ACTIVE since 2026-07-09, `EXPERIMENTAL`, kill closedDD 8%).

Caveat kept honest: the 2025.01–2026.07 window includes 2026H1. For *selection* that would
disqualify it; for *evaluating a guard that was already chosen* it is usable, and it is the only
recent evidence there is. **Which setting is actually on the live chart is unknown** — same
attestation gap class as 991001. Added to the user's Inputs-tab read list rather than acted on.

## §3 (BRK)_SqueezeBreakout 991004 (REAL money) — reason wrong, conclusion right

The audit says "zero `.ini` exist for this Expert". That is a name-matching artifact: **120 `.ini`
exist** under `Expert=SQZ` plus one under `O076\corrSqueeze` — the build alias, not the deployed
filename. So the EA is not evidence-free.

But the guard conclusion survives, by a worse route than the audit gave: **not one of those `.ini`
contains an `EmergencyDdPct` or `DailyLossPct` line at all.** Under the known tester-cache defect,
an input absent from the `.ini` is taken from the per-terminal cache rather than the `.set` — so
those guards were never varied, never controlled, and **we do not know what values were actually
in force during any of the 120 runs.** "No evidence" understates it; the correct label is
*unknown-value*, which is the same defect that produced the fake engine-drift in ORDER-204.

## What I take from the audit as a whole

The valuable columns are `NEVER-FIRED` (13) and `NO-CONTROL` (14). Two entries deserve naming
because they are not merely unmeasured but structurally unable to protect:

- **§15 RSI_MR 990103** — `EmergencyDdPct=40` while a human pulled the EA off real money at **25%**
  closed drawdown. The guard sat 15 points above the level at which a person judged the situation
  intolerable. A kill-switch calibrated above the intervention threshold cannot ever be the thing
  that saves the account.
- **§10/§11 Boss chassis** — `_0_MaxSpread=0` in 613/613 runs and in every deployed `.set`, and
  `TrendFilter=70` = `TFILTER_NONE`. Two guards that are off everywhere, including on real money.

And the honest limit the audit states about itself, which I am keeping rather than burying:
`portfolio/live_deals/*.csv` has no column for a blocked entry or a kill trip, so **nothing in the
live record can confirm that any guard has ever fired in production.** Every "it is fine, the
guard would catch it" belief in this repo is currently unfalsifiable from the live data.
