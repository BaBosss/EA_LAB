# ORDER-166 — Re-validation sweep: input-cache / leverage-pin fix (ORDER-165) vs original evidence

**Status: DATA ONLY — no verdicts, no keep/kill/promote/demote language below. This is a factual
before/after comparison for the orchestrator to judge.**

Ran 2026-07-23, after ORDER-165 (tester input-cache + leverage-pin fix) landed. All reruns used
`scripts/mt5_run.ps1` with `-Leverage 100` (pinned, post-run-asserted — every run below reports
"leverage verified 1:100") and `-Model 1` (fast pass, per task instructions — **original evidence
for several EAs was Model 4**; that mismatch is called out per-row, it is a real limitation of this
pass, not hidden). Symbol/period/date-window for every rerun = the window the ORIGINAL verdict was
actually validated on, sourced from the `.ini` file of the historical run wherever one still exists
in `_mt5_auto/ini/`, cross-checked against the report `.htm` in `_mt5_auto/reports/` and the prose
citation in `AGENT_TASKBOARD.md` / `ARCHIVE_TASKBOARD_2026-07A.md` / `DEMO_DEPLOYMENT_PLAN.md` /
`portfolio/DEPLOYMENTS.csv`. No number below is invented — every "original" figure is parsed
directly from an existing historical report file, cited by path.

## Coverage summary

**14/14 magics got a clean before/after comparison. 0 could-not-locate.** All 14 had a locatable
deployed `.set` (or, for 990120, a documented "compiled defaults + magic" recipe with no `.set` file
at all — reconstructed and flagged) and a citable original PF/net/trades/DD number from an existing
report or CSV. 19 tester runs total (7 single-window Boss_14 legs + 6 two-window legs ×2 windows +
1 MacroGate) all completed synchronously, foreground, no backgrounding, no hangs.

**Tally (per-magic, using the larger of its window(s)):** **MATCHES = 6** (990203, 990205, 990206,
990301, 990302, 990303) · **DIVERGES = 8** (990201, 990202, 990204, 990207, 990208, 990101, 990110,
990120) · **COULD-NOT-LOCATE = 0**.

**Large divergences (trade count or PF moved >~20%) — flagged prominently for the orchestrator:**
- **990201 USDJPY** — trades 138→337 (+144%), PF 1.51→0.98 (flips from profit to breakeven-loss). Largest divergence in the set.
- **990120 MacroGate USDJPY leg** — trade count in the rerun (333) is **identical to the original gate-OFF baseline** (333), not the original gate-ON number (235) that the deployed leg is supposed to reproduce. The report confirms `_MG_SelfGate=true` was applied. This reads as "the gate did not veto anything in this rerun" — a genuine behavioral finding, not just a numeric drift.
- **990204 AUDCAD** — trades 146→110 (-25%), PF 1.88→1.35 (-28%), net -57%.
- **990207 XAUUSD** — trades 426→571 (+34%) even though PF held exactly at 1.42 (see row for the confound: the deployed set is a *different, deliberately de-scaled* set from the one validated).
- **990208 GBPJPY leg8, BWD window** — trades 31→38 (+23%), net +472% (71.41→408.69). The MAIN window for the same magic matched closely (see row).
- **990110 Zeus AUDJPY regime** — trades +23% (MAIN) / +16% (BWD); confounded by an unavoidable Model-4→Model-1 comparison (see row) but the missing 3 regime inputs in the partial `.set` are a live suspect.
- **990101 ZeusInspired XAU** — trades 386→301 (-22%) **despite being the one FULL-surface `.set` in the whole batch** — flagged as a control case: some drift exists even with zero input-cache exposure (see row for discussion).

## Leverage note (relevant background, not new)

Several of the ORIGINAL historical reports being compared against were themselves run under the
polluted leverage described in ORDER-165 (`Leverage=` numeric form silently ignored → tester used
whatever was cached): GBPJPY sweep/M4-confirm reports, all 6 Wave5 reports, and the MacroGate A/B
reports all show `Leverage: 1:2000` in their own report body, despite their `.ini` asking for
`Leverage=100`. The Boss_14 cohort ISpick FULL-window reports (990201-207) and the ZeusInspired XAU
FULLSPAN report happened to show `1:100` — not polluted at the time they were run. This is stated
per-row below; it means for the polluted rows, part of any divergence you see could be the leverage
axis resolving correctly for the first time now, not (only) the input-cache axis.

---

## 990201 — Boss_14_GridLog, USDJPYm, account 415573666

- **Deployed `.set`:** `ea_template/sets/Boss14_GridLog_USDJPY_DEMO.set` — **88 lines / ~116-line full
  surface = PARTIAL.**
- **Original numbers + source:** PF **1.51**, net **841.72**, trades **138**, eqDD **6.15%**.
  Symbol USDJPY, H1, 2023.01.01–2026.07.01, Model 1, leverage **1:100** (not polluted).
  Source: `_mt5_auto/reports/BOSS14_USDJPY_FULL_ISPICK_M1.htm` (run cited verbatim in
  `DEMO_DEPLOYMENT_PLAN.md` row 1, "full-confirm PF 1.51" and `ARCHIVE_TASKBOARD_2026-07A.md`
  ORDER-004 2026-07-04 verdict: "USDJPY ... full 1.51/138t"). Note: the ISpick `.set` used for this
  historical run and the deployed DEMO `.set` differ only in `_0_Magic` and `_4_DdAdaptiveOn`
  (per ARCHIVE_TASKBOARD line ~807-810) — same window used here for the rerun.
- **Rerun (this pass):** PF **0.98**, net **-113.76**, trades **337**, eqDD **11.56%**.
  `_mt5_auto/reports/ORDER166_990201_USDJPY.htm`, leverage verified 1:100.
- **Delta:** PF -35% (profit→breakeven-loss) · net flips sign · trades **+144%** · eqDD +88%.
- **Flag: DIVERGES (large).**

## 990202 — Boss_14_GridLog, AUDNZDm, account 415573666

- **Deployed `.set`:** `ea_template/sets/Boss14_GridLog_AUDNZD_DEMO.set` — **88/116 lines = PARTIAL.**
- **Original:** PF **1.56**, net **1242.36**, trades **195**, eqDD **4.26%**. Symbol AUDNZD, H1,
  2023.01.01–2026.07.01, Model 1, leverage 1:100. Source: `_mt5_auto/reports/BOSS14_AUDNZD_FULL_ISPICK_M1.htm`
  (`DEMO_DEPLOYMENT_PLAN.md` "AUDNZD ... 1.56"; ARCHIVE_TASKBOARD "AUDNZD ... full 1.56/195t").
- **Rerun:** PF **1.30**, net **761.74**, trades **195**, eqDD **5.66%**.
  `_mt5_auto/reports/ORDER166_990202_AUDNZD.htm`, leverage verified 1:100.
- **Delta:** PF -17% · net -39% · **trades identical (195=195)** · eqDD +33%.
- **Flag: DIVERGES (moderate).** Trade count matching exactly while PF/net/DD move meaningfully
  points at price-history refresh over the elapsed time, not input-cache pollution (same trade
  count = same entries fired) — worth noting as a different failure mode than the cache bug.

## 990203 — Boss_14_GridLog, EURJPYm, account 415573666 (size-light)

- **Deployed `.set`:** `ea_template/sets/Boss14_GridLog_EURJPY_DEMO.set` — **88/116 lines = PARTIAL.**
- **Original:** PF **2.49**, net **2585.53**, trades **114**, eqDD **6.00%**. Symbol EURJPY, H1,
  2023.01.01–2026.07.01, Model 1, leverage 1:100. Source: `_mt5_auto/reports/BOSS14_EURJPY_FULL_ISPICK_M1.htm`
  (`DEMO_DEPLOYMENT_PLAN.md` "EURJPY ... 2.49"; ARCHIVE_TASKBOARD "EURJPY ... full 2.49/114t").
- **Rerun:** PF **2.57**, net **2974.08**, trades **107**, eqDD **5.83%**.
  `_mt5_auto/reports/ORDER166_990203_EURJPY.htm`, leverage verified 1:100.
- **Delta:** PF +3% · net +15% · trades -6% · eqDD -3%.
- **Flag: MATCHES** (small variance, well inside normal data-refresh noise).

## 990204 — Boss_14_GridLog, AUDCADm, account 415573666

- **Deployed `.set`:** `ea_template/sets/Boss14_GridLog_AUDCAD_DEMO.set` — **87/116 lines = PARTIAL.**
- **Original:** PF **1.88**, net **1491.31**, trades **146**, eqDD **6.38%**. Symbol AUDCAD, H1,
  2023.01.01–2026.07.01, Model 1, leverage 1:100. Source: `_mt5_auto/reports/BOSS14_AUDCAD_FULL_ISPICK_M1.htm`
  (`DEMO_DEPLOYMENT_PLAN.md` "AUDCAD ... 1.88"; ORDER-016 "AUDCAD ... OOS 4.30 ทุกปีบวก").
- **Rerun:** PF **1.35**, net **644.09**, trades **110**, eqDD **6.50%**.
  `_mt5_auto/reports/ORDER166_990204_AUDCAD.htm`, leverage verified 1:100.
- **Delta:** PF -28% · net -57% · trades **-25%** · eqDD +2%.
- **Flag: DIVERGES (large).**

## 990205 — Boss_14_GridLog, CADJPYm, account 415573666 (size-light, thin)

- **Deployed `.set`:** `ea_template/sets/Boss14_GridLog_CADJPY_DEMO.set` — **87/116 lines = PARTIAL.**
- **Original:** PF **1.89**, net **1010.21**, trades **77**, eqDD **3.71%**. Symbol CADJPY, H1,
  2023.01.01–2026.07.01, Model 1, leverage 1:100. Source: `_mt5_auto/reports/BOSS14_CADJPY_FULL_ISPICK_M1.htm`
  (`DEMO_DEPLOYMENT_PLAN.md` "CADJPY ... 1.89 ... thin 77t").
- **Rerun:** PF **1.96**, net **1051.31**, trades **76**, eqDD **3.65%**.
  `_mt5_auto/reports/ORDER166_990205_CADJPY.htm`, leverage verified 1:100.
- **Delta:** PF +4% · net +4% · trades -1% · eqDD -2%.
- **Flag: MATCHES.**

## 990206 — Boss_14_GridLog, EURUSDm SELL, account 415573666

- **Deployed `.set`:** `ea_template/sets/Boss14_GridLog_EURUSD_DEMO.set` — **87/116 lines = PARTIAL.**
- **Original:** PF **1.97**, net **669.10**, trades **69**, eqDD **4.39%**. Symbol EURUSD, H1,
  2023.01.01–2026.07.01, Model 1, leverage 1:100. Source: `_mt5_auto/reports/BOSS14_EURUSD_FULL_ISPICK_M1.htm`
  (`DEMO_DEPLOYMENT_PLAN.md` "EURUSD (SELL) ... 1.97").
- **Rerun:** PF **2.03**, net **694.66**, trades **70**, eqDD **4.09%**.
  `_mt5_auto/reports/ORDER166_990206_EURUSD.htm`, leverage verified 1:100.
- **Delta:** PF +3% · net +4% · trades +1% · eqDD -7%.
- **Flag: MATCHES.**

## 990207 — Boss_14_GridLog, XAUUSDm, account 415573666

- **Deployed `.set`:** `ea_template/sets/Boss14_GridLog_XAU_DEMO_exness3d.set` — **77/116 lines =
  PARTIAL** (3-digit-broker variant, de-scaled lot 0.10→0.05 — deliberately different from the
  `.set` the headline number below was validated on, see caveat).
- **Original:** PF **1.42**, net **3106.99**, trades **426**, eqDD **23.34%** (Equity DD Maximal;
  the year-split table separately reports a "Balance DD" of 15.42% for the same run — different
  metric, both cited so nothing is cherry-picked). Symbol XAUUSD, H1, 2023.01.01–2026.07.01,
  Model 1, leverage 1:100. Source: `_mt5_auto/reports/BOSS14_XAU_FULL_ISPICK_M1.htm`
  (`ARCHIVE_TASKBOARD_2026-07A.md` ORDER-030, "full 2023.01–2026.07 ... 1.42/426t"). **Caveat: this
  citation is from `Boss14_GridLog_XAU_ISpick.set` (89 lines, lot 0.10) — not the actual deployed
  `_exness3d` set (77 lines, lot 0.05, 3-digit slippage config).** Per the task's guidance, the
  deployed set is what was rerun (option a); this is the closest available original citation.
- **Rerun:** PF **1.42**, net **1549.67**, trades **571**, eqDD **14.44%**.
  `_mt5_auto/reports/ORDER166_990207_XAU.htm`, leverage verified 1:100.
- **Delta:** PF **exactly unchanged (1.42=1.42)** · net -50% (expected — deployed lot is half the
  validated lot, 0.05 vs 0.10, and PF is lot-invariant so this cross-check is actually reassuring
  on the lot-scaling axis) · **trades +34%** (not explained by the lot change; the exness3d set's
  different symbol-precision handling and missing lines are the live suspects) · eqDD -9pp.
- **Flag: DIVERGES** (on trade count, despite PF holding — flagged per task's own >~20% trade-count
  threshold; the confound with a deliberately different deployed `.set` is stated above, not hidden).

## 990208 — Boss_14_GridLog, GBPJPYm leg8, account 415573666

- **Deployed `.set`:** `_vps_deploy/BOSS14_GBPJPY/Boss14_GridLog_GBPJPY_H4_demo_leg8.set` —
  **86/116 lines = PARTIAL.**
- **Original (three citations exist, all stated):**
  - Model-1 coarse-sweep plateau point (same params: dist2.0/SL4.0/TP250): PF **1.55**, net **803.78**,
    trades **40**, eqDD **5.33%** (MAIN, 2023.01.01–2026.01.01) / PF **1.06**, net **71.41**,
    trades **31**, eqDD **8.35%** (BWD, 2020.01.01–2023.01.01). Leverage **1:2000** (polluted).
    Source: `_mt5_auto/reports/O106_GJ_d2.0_s4.0_H4_MAIN.htm` / `_BWD.htm`.
  - Model-4 confirm on the same config (cited as the headline number in `_triage/ORDER106_GBPJPY_RESCUE_VERDICT.md`
    and `DEPLOYMENTS.csv` notes): PF **1.56**, net **1057.99**, trades **55**, eqDD **9.23%** (MAIN) /
    PF **1.11**, net **209.77**, trades **50**, eqDD **9.40%** (BWD). Leverage 1:2000 (polluted).
    Source: `_mt5_auto/reports/O106_M4_GJ_H4_MAIN.htm` / `_BWD.htm`.
  - Final "verify reproduces" figure quoted against the actual deployed `.set`: "MAIN 1.43/BWD 1.11
    (net 937.5 ตรง)" — `_triage/ORDER106_GBPJPY_RESCUE_VERDICT.md` line ~72 (exact report file for
    this specific verify run not found under a distinct name; likely overwritten by a later same-named
    run — noted honestly rather than guessed).
- **Rerun (Model 1, matching the coarse-sweep citation's model):** MAIN PF **1.58**, net **831.87**,
  trades **40**, eqDD **5.29%**. BWD PF **1.32**, net **408.69**, trades **38**, eqDD **8.11%**.
  `_mt5_auto/reports/ORDER166_990208_GBPJPY_MAIN.htm` / `_BWD.htm`, leverage verified 1:100.
- **Delta vs the Model-1 coarse citation:** MAIN — PF +2%, net +3%, **trades identical (40=40)**,
  eqDD -1pp → **MATCHES well** despite the original running on polluted 1:2000 leverage and this
  rerun pinned at 1:100 (suggests leverage isn't the dominant driver for this particular leg's
  grid depth). BWD — PF +25%, net **+472%**, trades **+23%** (31→38), eqDD -0.24pp → **DIVERGES
  (large)**, same leverage caveat noted.
- **Flag: MIXED — MAIN MATCHES, BWD DIVERGES (large).** Overall magic flag: DIVERGES (BWD result
  is the one this magic's live risk profile most depends on, per its own README caveat "2020=0
  trades... BWD PF 1.11 rests on 2021-22 only").

## 990101 — (Boss)_ZeusInspired_GridLog_rev01, XAUUSD, account 159503454

- **Deployed `.set`:** `_demo_deploy/MT5/ZeusInspired_XAUUSD_H1_demo.set` — **29 lines vs a
  29-real-input full surface (37 total `input` lines, 8 group headers) = FULL SURFACE.** This is
  the one magic in the whole batch with zero missing-input exposure — a useful control case.
- **Original:** PF **1.74**, net **1471.64**, trades **386**, eqDD **4.22%**. Symbol XAUUSD, H1,
  2020.01.01–2026.07.01 (full span; this EA's evidence is cited as a "3-window range 1.38-2.16" in
  `_demo_deploy/README_DEPLOY.md` — the 3 sub-windows are BWD 2020-23 PF1.74/84t, holdout 2023-25
  PF1.38/166t, FWD 2025-26.07 PF2.16/188t; the fullspan figure used here as the single rerun window
  is their union). Leverage 1:100 (not polluted). Source: `_mt5_auto/reports/ZIGL_XAU_FULLSPAN.htm`
  (`_mt5_auto/ini/ZIGL_XAU_FULLSPAN.ini` confirms `_03_DistAtrMult=1`, matching the deployed set).
- **Rerun:** PF **1.43**, net **811.09**, trades **301**, eqDD **3.55%**.
  `_mt5_auto/reports/ORDER166_990101_ZIGL_XAU.htm`, leverage verified 1:100.
- **Delta:** PF -18% · net -45% · trades **-22%** · eqDD -16%.
- **Flag: DIVERGES (moderate-large).** **Important control finding:** this is the ONLY full-surface,
  never-cache-exposed `.set` in the batch, and it still drifted by a similar magnitude to several
  partial-set legs. Since input surface was complete and leverage matched (1:100 both times), this
  divergence is best explained by price-history refresh (~3 weeks elapsed between the original
  2026-07-03/04 run and this one) rather than the ORDER-165 cache mechanism — worth the
  orchestrator's attention as a reminder that not all drift in this sweep is cache-attributable.

## 990110 — (Boss)_ZeusInspired_GridLog_rev01 + Regime gate, AUDJPYm, account 415573666

- **Deployed `.set`:** `_vps_deploy/ZEUS_AUDJPY_REGIME/ZeusAUDJPY_regime_demo_v1.set` — **35 lines
  vs a 38-real-input full surface (29 base + 9 regime-module inputs) = PARTIAL.** Missing 3 inputs,
  all in the regime-gate module that IS this leg's entire rescue mechanism:
  `_50_Regime_TF`, `_50_ADX_Period`, `_50_StormLookback` — these come from tester cache, not from
  documented defaults.
- **Original:** MAIN (2023.01.01–2026.07.01) PF **1.35**, net **1193.09**, trades **124**, eqDD
  **13.97%**. BWD (2020.01.01–2023.01.01) PF **1.20**, net **1000.80**, trades **186**, eqDD
  **9.03%**. **Model 4**, leverage not independently re-confirmable for this exact config (the
  report file for the storm=1.5 config was overwritten by a later same-named sweep iteration;
  sibling runs in the same sweep batch show leverage 1:2000, so this run likely shared that
  pollution, not confirmed). Source: `_mt5_auto/ZEUS_AUDJPY_STORM.csv` row `storm=1.5` (matches the
  headline figure quoted in `_triage/ORDER109_ZEUS_REGIME_VERDICT.md` / `AGENT_TASKBOARD.md`
  ORDER-109: "Verified from THIS .set: PF 1.35 / net +1193 / 124t").
- **Rerun (Model 1 — task requires Model 1, original was Model 4; NOT apples-to-apples on execution
  model, stated plainly):** MAIN PF **1.95**, net **2498.28**, trades **152**, eqDD **7.16%**. BWD
  PF **1.10**, net **673.34**, trades **215**, eqDD **13.34%**.
  `_mt5_auto/reports/ORDER166_990110_ZEUS_AUDJPY_MAIN.htm` / `_BWD.htm`, leverage verified 1:100.
- **Delta:** MAIN — PF +44%, net +109%, trades **+23%** (124→152), eqDD -7pp. BWD — PF -8%, net
  -33%, trades **+16%** (186→215), eqDD +4pp.
- **Flag: DIVERGES.** Two confounds stacked here (Model 4→1 AND partial-set missing exactly the
  regime-lever inputs) so this comparison cannot isolate which one drives the trade-count change —
  but the missing 3 inputs are precisely the ones controlling WHICH bars count as "range" vs
  "trend" for the entry gate, making the partial-set explanation plausible and worth a dedicated
  Model-1-vs-Model-1 rerun with a full regime-input set if this needs to be pinned down further.

## 990301 — Boss_17_Wave5, XAUUSDm, account 463666728

- **Deployed `.set`:** `_vps_deploy/WAVE5_XAU/WAVE5_XAU_H1_demo_v1.set` — **9 lines vs a
  121-line full surface = PARTIAL (most extreme ratio in the whole batch, 8 real inputs / ~120).**
- **Original:** MAIN (2023.01.01–2026.07.01) PF **1.07**, net **165.68**, trades **271**, eqDD
  **3.56%**. BWD (2020.01.01–2023.01.01) PF **1.05**, net **70.14**, trades **215**, eqDD **1.66%**.
  **Model 4**, leverage **1:2000** (polluted). Source: `_mt5_auto/reports/W5_XAUUSD_MAIN.htm` /
  `_BWD.htm` (`_mt5_auto/ini/W5_XAUUSD_MAIN.ini` confirms `_17_EntryFib=23.6`/`_17_Wave3MinMult=0.618`/
  `_0_Magic=990301`, exactly matching the deployed set).
- **Rerun (Model 1):** MAIN PF **1.08**, net **186.60**, trades **271**, eqDD **3.41%**. BWD
  PF **1.06**, net **83.56**, trades **217**, eqDD **1.59%**.
  `_mt5_auto/reports/ORDER166_990301_W5XAU_MAIN.htm` / `_BWD.htm`, leverage verified 1:100.
- **Delta:** MAIN — PF +1%, net +13%, **trades identical (271=271)**, eqDD -0.15pp. BWD — PF +1%,
  net +19%, trades +1% (215→217), eqDD -0.07pp.
- **Flag: MATCHES.** Notable: this is the most partial `.set` in the entire batch (9/121 lines) AND
  the original ran under polluted 1:2000 leverage, yet trade counts reproduced almost exactly under
  the pinned 1:100 Model-1 rerun. Worth the orchestrator's attention as a positive counter-example
  to the general risk pattern — plausibly because `ExitMode=23`/`MaxLevels=1` (single-position, no
  grid depth) makes this EA's entry logic insensitive to most of the unlisted chassis inputs, and
  its margin exposure never gets deep enough to hit the leverage-driven margin gate described in
  ORDER-162/165.

## 990302 — Boss_17_Wave5, XAGUSDm, account 463666728

- **Deployed `.set`:** `_vps_deploy/WAVE5_XAG/WAVE5_XAG_H1_demo_v1.set` — **9/121 lines = PARTIAL.**
- **Original:** MAIN PF **1.31**, net **1040.48**, trades **216**, eqDD **5.10%**. BWD PF **1.29**,
  net **441.02**, trades **169**, eqDD **2.55%**. Windows same as 990301. Model 4, leverage
  **1:2000** (polluted). Source: `_mt5_auto/reports/W5_XAGUSD_MAIN.htm` / `_BWD.htm`.
- **Rerun (Model 1):** MAIN PF **1.33**, net **1072.23**, trades **216**, eqDD **5.08%**. BWD
  PF **1.24**, net **372.35**, trades **169**, eqDD **2.64%**.
  `_mt5_auto/reports/ORDER166_990302_W5XAG_MAIN.htm` / `_BWD.htm`, leverage verified 1:100.
- **Delta:** MAIN — PF +2%, net +3%, **trades identical (216=216)**, eqDD -0.02pp. BWD — PF -4%,
  net -16%, **trades identical (169=169)**, eqDD +0.09pp.
- **Flag: MATCHES.** Same pattern as 990301 (single-position Wave5 mechanism, minimal sensitivity
  to the unlisted chassis inputs).

## 990303 — Boss_17_Wave5, USDJPYm, account 463666728

- **Deployed `.set`:** `_vps_deploy/WAVE5_USDJPY/WAVE5_USDJPY_H1_demo_v1.set` — **9/121 lines =
  PARTIAL.**
- **Original:** MAIN PF **1.56**, net **69.48**, trades **46**, eqDD **0.28%**. BWD PF **1.92**,
  net **72.92**, trades **45**, eqDD **0.22%**. Windows same as 990301/302. Model 4, leverage
  **1:2000** (polluted). Source: `_mt5_auto/reports/W5OPT_f382_m1618_MAIN.htm` / `_BWD.htm`
  (`_17_EntryFib=38.2`/`_17_Wave3MinMult=1.618`, matching the deployed set exactly). **This is a
  strong citation match: it reproduces `DEPLOYMENTS.csv`'s own note for this magic verbatim** —
  "Wave5 USDJPY H1 (M4 1.56/1.92 all-years-positive; THIN 11-17t/yr size light)".
- **Rerun (Model 1):** MAIN PF **1.55**, net **68.57**, trades **46**, eqDD **0.29%**. BWD
  PF **1.90**, net **71.44**, trades **45**, eqDD **0.22%**.
  `_mt5_auto/reports/ORDER166_990303_W5USDJPY_MAIN.htm` / `_BWD.htm`, leverage verified 1:100.
- **Delta:** MAIN — PF -1%, net -1%, **trades identical (46=46)**, eqDD +0.01pp. BWD — PF -1%,
  net -2%, **trades identical (45=45)**, eqDD ~0.
- **Flag: MATCHES.** Best reproduction in the entire batch — essentially identical on every axis
  despite the 9-line partial set and the leverage/model mismatches against the original.

## 990120 — Boss_12_Breakout (MacroGate leg), USDJPYm, account 463666728

- **Deployed `.set`:** **None exists.** `_vps_deploy/MACROGATE_DEMOLEG/README.md` explicitly
  instructs: "set `_0_Magic = 990120`. **Leave every other input at chassis default** — the A/B
  validation used defaults." No `.set` file is bundled anywhere in `_vps_deploy/MACROGATE*`.
  **Reconstruction for this rerun:** `ea_template/sets/regression/Boss_12_Breakout_defaults.set`
  (the ORDER-165-harvested full 117-line compiled-defaults surface) + the 7 MacroGate override
  lines from the original validation ini + `_0_Magic=990120` →
  `_mt5_auto/ab_sets/ORDER166_990120_MacroGate_USDJPY.set` (full 117-line surface, not partial —
  this is the one case in the batch where "no .set" could be turned into a genuinely complete
  reconstruction because ORDER-165 had already harvested the defaults independently).
- **Original:** PF **1.01**, net **2.80**, trades **235**, eqDD **0.58%** (gate ON, hardened
  re-run). For contrast, gate OFF on the identical window: PF 0.91, net -58.36, trades **333**,
  eqDD 1.30%. Symbol USDJPY, H1, 2024.01.01–2024.12.31, Model 1 (already Model 1 — no model
  mismatch for this row), leverage **1:2000** (polluted). Source:
  `_mt5_auto/reports/MG_HARD_USDJPY_ON.htm` / `_OFF.htm`, matching
  `ea_projects/(Boss)_MacroGate/MACROGATE_AB_VERDICT.md` table exactly ("USDJPY FULL YEAR 2024 ...
  +2.80 / 1.01 / 235 / 57.73").
- **Rerun:** PF **0.90**, net **-66.89**, trades **333**, eqDD **1.32%**.
  `_mt5_auto/reports/ORDER166_990120_MacroGate.htm`, leverage verified 1:100. Report's own Inputs
  section confirms `_MG_SelfGate=true` was applied as intended.
- **Delta:** PF -11% (crosses below 1.0) · net flips from +2.80 to -66.89 · **trades +42%
  (235→333)**.
- **Flag: DIVERGES (large) — and a specific behavioral finding, not just numeric drift: the
  rerun's trade count (333) is not just different from the original ON-gate count (235), it is
  IDENTICAL to the original OFF-gate count (333) on the same window.** That pattern — gate
  confirmed enabled in the report, but trade count matching the no-gate baseline exactly — reads as
  "the regime gate did not veto any entries in this rerun," which is either a genuine behavior
  change (regime CSV content differs today vs the 2026-07-18 validation — the file is documented
  as manually refreshed weekly, so today's classification of the same 2024 calendar dates could
  differ from what was in the CSV back then) or a config-wiring issue in the reconstruction. This
  is the single most orchestrator-relevant finding in the whole sweep: it is not just "numbers
  moved," it is "the mechanism under test may not have fired."

---

## Files touched by this sweep (all uncommitted, left for review)

- `_mt5_auto/ab_sets/ORDER166_990120_MacroGate_USDJPY.set` — reconstructed full-surface set for the
  MacroGate leg (new file, described above).
- `_mt5_auto/reports/ORDER166_*.htm` (+ sibling `.png`) — 19 new tester reports, one per rerun.
- `_mt5_auto/ini/ORDER166_*.ini` — 19 new tester ini files (byproduct of `mt5_run.ps1`).
- This file.

No file under `portfolio/DEPLOYMENTS.csv`, `EA_SCORECARD_AND_REGISTRY.md`, `EA_MASTER_INDEX.csv`,
`ea_template/core/*.mqh`, `ea_template/sets/regression/*`, or the pinned scripts was modified. No
`git add`/`git commit` was run.
