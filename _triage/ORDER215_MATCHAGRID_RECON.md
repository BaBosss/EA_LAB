# ORDER-215 Part 2 — MatchaGrid (MG_v1, CHFJPY M15) Recon

> READ-ONLY recon. No backtests run, no files modified besides this report, no commit made.
> Live context: real money, account `159475669` (REAL_CENT), magic `20240001`, symbol `CHFJPYc`,
> `portfolio/DEPLOYMENTS.csv:12`. Scorecard status = `PARKED-VERIFY(user)` since ORDER-215 Part 1
> (`AGENT_TASKBOARD.md:479-494`, `EA_SCORECARD_AND_REGISTRY.md:156`, `EA_MASTER_INDEX.csv:156`).

---

## 1. The EA itself — source availability, exact `Expert=` string

**Compiled binary found (READ), no `.mq5` source found anywhere:**
- `D:\Meta 5b\MQL5\Experts\MatchaGrid.ex5`
- `D:\Meta 5b\MQL5\Experts\EA + Course\MT5 แอดทำเอง - I created by myself_\MatchaGrid.ex5`
- `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\MatchaGrid.ex5`
- `.set` template also present at `...\MQL5\Profiles\Tester\MatchaGrid.set`

**Source (`.mq5`): NOT FOUND.** Searched `D:\EA_LAB`, `D:\Meta 5b`, and the roaming Terminal tree
for `*MatchaGrid*.mq5` / `*atcha*rid*.mq5` — zero hits. This matches the project's own prior
finding, quoted verbatim from `AGENT_TASKBOARD.md:1276`:
> "`ea_projects/Matchagrid/` = **locked/vendor EA, reports only, no source** — cannot retrofit a
> module into closed-source."

So MatchaGrid is a closed/compiled vendor EA — behavioral analysis only (locked-ea-analyzer style),
not a code read.

**Exact `Expert=` string used in every `.ini` found:** `Expert=MatchaGrid` (two later files,
`MG_robust_OOS_v2.ini` and `MG_gp350_OOS_v2.ini`, use `Expert=Matchagrid` — lower-case `g`). On
Windows this is almost certainly case-insensitive for file lookup, but **any new `mt5_run.ps1 -Expert`
call should use the exact casing `MatchaGrid`** to match the majority of the history and the
compiled file name on disk.

---

## 2. Every `.set` / `.ini` for MatchaGrid — full `[Tester]` blocks

All ini files live in `D:\EA_LAB\_mt5_auto\ini\`. Leverage is written as a **bare number
(`Leverage=100`)** in every one of these on-disk `.ini` copies — the form `mt5_run.ps1` itself
now flags (ORDER-165, `scripts/mt5_run.ps1:32-40`) as silently ignored by the tester in favor of
whatever leverage the terminal's tester cache happens to hold. **However**, cross-checking the
actual generated reports (section 4 below) shows every MatchaGrid report's `Leverage:` line reads
`1:100` — i.e. whatever the cache held at the time happened to be 1:100, so this is not a proven
defect for these specific runs, just an un-asserted one (no `.leverage_check.json` sidecar exists
for any of them — see section 5).

| ini file | Symbol/Period | Model | FromDate–ToDate | Optimization | Criterion |
|---|---|---|---|---|---|
| `MG_CHFJPY_IS.ini` | CHFJPY M15 | 1 | 2023.01.01–2026.06.01 | 0 (single) | — |
| `MG_CHFJPY_OOS.ini` | CHFJPY M15 | 1 | 2020.01.01–2023.01.01 | 0 (single) | — |
| `OPT_MG_CHF_lowDD.ini` | CHFJPY M15 | 1 | 2023.01.01–2026.06.01 | **2 (genetic)** | **0** |
| `MG_p168_IS.ini` | CHFJPY M15 | 1 | 2023.01.01–2026.06.01 | 0 | — |
| `MG_minlot_IS.ini` | CHFJPY M15 | 1 | 2023.01.01–2026.06.01 | 0 | — |
| `MG_gp350_IS.ini` | CHFJPY M15 | 1 | 2023.01.01–2026.06.01 | 0 | — |
| `MG_gp350_OOS.ini` | CHFJPY M15 | 1 | 2020.01.01–2023.01.01 | 0 | — |
| `MG_robust_OOS_v2.ini` (Expert=Matchagrid) | CHFJPY M15 | 1 | 2020.01.01–2023.01.01 | 0 | — |
| `MG_gp350_OOS_v2.ini` (Expert=Matchagrid) | CHFJPY M15 | 1 | 2020.01.01–2023.01.01 | 0 | — |
| `VERIFY_MG_IS.ini` | CHFJPY M15 | 1 | 2023.01.01–2026.06.01 | 0 | — |
| `VERIFY_MG_OOS.ini` | CHFJPY M15 | 1 | 2020.01.01–2023.01.01 | 0 | — |
| `RIGOR_MG_OOS_VERIFY.ini` | CHFJPY M15 | 1 | 2020.01.01–2023.01.01 | 0 | — |
| `MG_CHFJPY_OOS_corr.ini` | CHFJPY M15 | 1 | 2020.01.01–2023.01.01 | 0 | — |
| `MG_CHFJPY_IS_lot01.ini` | CHFJPY M15 | 1 | 2023.01.01–2026.06.01 | 0 | — |

All share: `Deposit=10000`, `Currency=USD`, `Leverage=100` (bare, see caveat above), `ExecutionMode=0`,
`Visual=0`, `ReplaceReport=1`, `ShutdownTerminal=1`.

**None of these are `Model=4`.** Confirmed by grep — no `MG_CHFJPY*` or `MG_*` (true MatchaGrid,
excluding the unrelated MacroGate-ablation files that also happen to start `MG_` — see note below)
ini has `Model=4` anywhere. **This is the central gap ORDER-215 Part 2 exists to close** — grid EAs
require Model-4 before a verdict per CLAUDE.md doctrine, and it has never been run for this EA.

**Naming collision warning:** files like `MG_BRK_AUDJPY_ON.ini`, `MG_FY24_USDJPY_OFF.ini`,
`MG_HARD_USDJPY_ON.ini`, `MG_AB_*`, `MG_PROBE_*` (dated 2026-07-18) are **NOT MatchaGrid** — grepping
`_mt5_auto/reports` for `MG_` also surfaces these, which are a MacroGate on/off ablation study on a
breakout EA (BRK/FY24/HARD symbol pairs are AUDJPY/USDJPY, not CHFJPY). Excluded from this recon;
flagging so nobody re-uses them as MatchaGrid evidence by pattern-matching the prefix.

**Recent sub-window splits already exist (found under `_mt5_auto/reports/`, no matching `.ini` files
were kept for the two, but the `.htm` headers confirm the windows), Model=1, dated 2026-06-28:**
- `QWEN_MG_IS.htm` — CHFJPY M15, **2023.01.01–2025.01.01** (24 mo)
- `QWEN_MG_OOS.htm` — CHFJPY M15, **2025.01.01–2026.06.01** (17 mo)
- `QWEN_MG_half1.htm` — CHFJPY M15, **2025.01.01–2025.07.01** (6 mo)
- `QWEN_MG_M2_IS.htm` / `QWEN_MG_M2_OOS.htm` — same two windows, presumably Model comparison runs
  (per grid doctrine, `Model=2` is not admissible evidence for a grid EA — `AGENT_TASKBOARD.md:494`
  "ห้ามใช้ Model-2 เป็นหลักฐานกับ grid")

These four/five reports all run the **same locked v1 params** (`InpLotStart=0.01, InpStepAddLot=0.01,
InpStepEveryOrders=5, InpProfitTarget=14, InpGridPoints=350`) — they look like an earlier attempt at
exactly the sub-window split Model-4 will need, just at Model=1. Useful precedent for the split
proposed in section 6.

---

## 3. Parameters in the pinned `.set` — grid mechanics

**Pinned/locked file:** `D:\EA_LAB\_mt5_auto\MG_CHFJPY_v1_locked.set`
```
InpLotStart=0.01||0.01||0||0.01||N
InpStepAddLot=0.01||0.01||0||0.01||N
InpStepEveryOrders=5||5||0||5||N
InpProfitTarget=14||14||0||14||N
InpGridPoints=350||350||0||350||N
```
This `.set` only carries the **5 parameters the optimizer swept**. Reading a full report's rendered
"Inputs:" block (which MT5 prints every input, swept or not — `MG_CHFJPY_IS_lot01.htm`,
`QWEN_MG_IS.htm`, `MG_CHFJPY_OOS_corr.htm` all agree) reveals the **complete input list is larger**:

```
InpLotStart=0.01
InpStepAddLot=0.01
InpStepEveryOrders=5
InpProfitTarget=14
InpGridPoints=350
InpCutLossMode=0
InpCutLossPercent=10        (10.0 in one report — same value, formatting differs)
InpCutLossFixed=50          (50.0 in one report)
InpCutLossBuySide=true
InpCutLossSellSide=true
InpCutLossTotal=false
InpMagicPrefix=MG
InpMagicNumber=20240001
InpSlippage=10
InpEnableTrading=true
```

**Grid-mechanics mapping for the flat-lot probe / sensitivity fan:**
| Role | Input name | Current value |
|---|---|---|
| Lot start / seed size | `InpLotStart` | 0.01 |
| Lot progression / escalation step | `InpStepAddLot` | 0.01 (flat-lot probe = set this to **0**) |
| Escalation trigger (orders per step) | `InpStepEveryOrders` | 5 |
| Grid spacing | `InpGridPoints` | 350 |
| Take-profit (basket target) | `InpProfitTarget` | 14 |
| DD-kill / basket cut-loss mode | `InpCutLossMode` | **0** |
| DD-kill percent threshold | `InpCutLossPercent` | 10 |
| DD-kill fixed-$ threshold | `InpCutLossFixed` | 50 |
| DD-kill side scoping | `InpCutLossBuySide` / `InpCutLossSellSide` / `InpCutLossTotal` | true / true / false |

**No standalone per-trade stop-loss input exists** (no `InpSL`/`InpStopLoss`-named parameter found
in any report's input dump — only the basket-level `InpCutLoss*` family). EDGE_CATALOG's description
of MatchaGrid as **"bounded grid with hard SL"** (`EDGE_CATALOG.md:47`, `:122`) and the scorecard's
former wording ("grid but bounded+SL") appear to refer to this `InpCutLossMode` family, **not a
per-order SL**.

**Important finding — every report inspected has `InpCutLossMode=0`.** Every MatchaGrid report this
recon could read (`MG_CHFJPY_IS_lot01.htm`, `MG_CHFJPY_OOS_corr.htm`, `QWEN_MG_IS.htm`, `QWEN_MG_OOS.htm`,
`QWEN_MG_half1.htm`, `ea_projects\Matchagrid\CHFJPY\ReportTester-146237-CHFJPY.html`) shows
`InpCutLossMode=0`. This recon did not find any MatchaGrid report where `InpCutLossMode` was set to
a non-zero value, and the meaning of mode values (0/1/2/...) was **not documented anywhere found**
(no source, no README, no comment in a `.set`). **This is worth resolving before writing the fan** —
if mode 0 means "disabled," then every PASS/CONDITIONAL number on record for this EA, including the
"bounded + SL" framing in EDGE_CATALOG/scorecard, was produced with the DD-kill switched off, and the
grid's downside is bounded only by margin/broker stop-out, not by any EA-level guard. Recommend this
be the very first question the flat-lot/fan work resolves (grid `InpCutLossMode` values, by testing
0 vs 1 vs 2 on identical data) — not inferred, since no source exists to read it from directly.

---

## 4. Every existing MT5 `.htm` report for MatchaGrid

| Report | Symbol/TF | Window | Model | Deposit | Leverage (report) | Trades | PF | Max Equity DD% | Ends after 2025.12.31? |
|---|---|---|---|---|---|---|---|---|---|
| `MG_CHFJPY_IS.htm` | CHFJPY M15 | 2023.01.01–2026.06.01 | 1 | 10,000 | 1:100 | 4460 | 1.84 | 48.75 | **YES — holdout** |
| `MG_CHFJPY_OOS.htm` | CHFJPY M15 | 2020.01.01–2023.01.01 | 1 | 10,000 | 1:100 | 2433 | 1.83 | 64.59 | No |
| `MG_p168_IS.htm` | CHFJPY M15 | 2023.01.01–2026.06.01 | 1 | 10,000 | 1:100 | 4415 | 1.85 | 30.78 | **YES — holdout** |
| `MG_minlot_IS.htm` | CHFJPY M15 | 2023.01.01–2026.06.01 | 1 | 10,000 | 1:100 | 2935 | 2.00 | 20.97 | **YES — holdout** |
| `MG_gp350_IS.htm` (= `MG_CHFJPY_IS_lot01.htm`, same params) | CHFJPY M15 | 2023.01.01–2026.06.01 | 1 | 10,000 | 1:100 | 2373 | 1.97 | 18.01 | **YES — holdout** |
| `MG_gp350_OOS.htm` (= `MG_CHFJPY_OOS_corr.htm`, same params) | CHFJPY M15 | 2020.01.01–2023.01.01 | 1 | 10,000 | 1:100 | 1409 | 2.08 | 23.75 | No |
| `MG_robust_OOS_v2.htm` | CHFJPY M15 | 2020.01.01–2023.01.01 | 1 | 10,000 | 1:100 | (not re-parsed; same window as OOS, older param set) | — | — | No |
| `VERIFY_MG_IS.htm` / `VERIFY_MG_OOS.htm` / `RIGOR_MG_OOS_VERIFY.htm` | CHFJPY M15 | matching IS/OOS windows | 1 | 10,000 | 1:100 | (re-verification duplicates of gp350 params, not individually re-parsed this pass) | — | — | IS variants: YES |
| `QWEN_MG_IS.htm` | CHFJPY M15 | 2023.01.01–2025.01.01 | 1 | 10,000 | 1:100 | (metrics not extracted this pass; window itself is clean of holdout) | — | — | No |
| `QWEN_MG_OOS.htm` | CHFJPY M15 | 2025.01.01–2026.06.01 | 1 | 10,000 | 1:100 | — | — | — | **YES — holdout (ends 2026.06.01)** |
| `QWEN_MG_half1.htm` | CHFJPY M15 | 2025.01.01–2025.07.01 | 1 | 10,000 | 1:100 | — | — | — | No |
| `QWEN_MG_M2_IS.htm` / `QWEN_MG_M2_OOS.htm` | CHFJPY M15 | same as QWEN_MG_IS/OOS | (Model not confirmed — name implies "Model=2" comparison; **grid doctrine says Model-2 is not admissible evidence** for a grid EA) | 10,000 | 1:100 | — | — | — | OOS leg: **YES — holdout** |
| `ea_projects\Matchagrid\CHFJPY\ReportTester-146237-CHFJPY.html` | CHFJPY | window not re-extracted this pass (companion `ReportOptimizer-146237 - CHFJPY.xml` is the genetic-optimizer log, 2.3 MB, both dated 2026-06-11 17:50–17:51) | 1 | — | — | — | — | — | not checked |

**Flags:**
- **All full-length "IS" windows (2023.01.01–2026.06.01) eat 5 months of the 2026H1 holdout** — this
  is the exact defect ORDER-215 Part 1 already identified. Any clean re-measure must stop the MAIN
  window at 2025.12.31 per the CLAUDE.md pin (MAIN = 2023.01–2025.12).
- The **v1-locked config's own headline numbers** (gp350/lot01, `.set` comment in
  `MG_CHFJPY_v1_locked.set`) — "IS PF=1.97 DD=18.01%" — come from a window that **includes the
  holdout**, so that number cannot be cited as a MAIN result without a re-run.
- The clean, non-holdout confirmation leg is `MG_gp350_OOS.htm` / `MG_CHFJPY_OOS_corr.htm`:
  **2020.01.01–2023.01.01, PF 2.08, equity DD 23.75%, 1409 trades** — this matches what the scorecard
  cites and what ORDER-215 Part 1 called "genuinely OOS and clean."
  This is effectively the project's **BWD** window already, just not labeled that way.
- **Equity DD is very high across every full-length run (48–65% for the higher-escalation configs,
  18–24% for the locked v1 params)** — worth keeping front-of-mind: even the "fixed" v1 params still
  show 18-24% equity DD on 3-year single windows, well above typical demo-kill thresholds (12% eqDD
  per the bar table) before any Model-4 fill-sensitivity adjustment is applied.

---

## 5. `truncation_check.json` / `leverage_check.json` sidecars

**NOT FOUND for any true MatchaGrid CHFJPY report.** Searched `_mt5_auto/reports/` for
`MG_CHFJPY*.leverage_check.json` and `MG_CHFJPY*.truncation_check.json` — zero hits. The only
`*.leverage_check.json` / `*.truncation_check.json` sidecars whose filenames start `MG_` belong to
the unrelated MacroGate-ablation batch (`O211_MG_BRK_*`, `O211_MG_FY24_*`, all dated around ORDER-211,
2026-07-18/25) — not MatchaGrid.

This is consistent with timing: the leverage-assertion sidecar mechanism was added to
`scripts/mt5_run.ps1` under **ORDER-165 (2026-07-23)**. Every MatchaGrid report on disk predates that
(latest MatchaGrid report timestamp found: `MG_CHFJPY_IS_lot01.htm` / `MG_CHFJPY_OOS_corr.htm`,
2026-06-28). **Any new run for Part 2 will automatically get both sidecars** since it will go through
the current `mt5_run.ps1`, which now writes `Leverage=1:$Leverage` and asserts it post-run — this
recon did not find anything suggesting that mechanism itself needs re-checking here.

---

## 6. Cost estimate for a Model-4 run, and a concrete sub-window split

**Timing evidence found (inferred from file timestamps, not a log — no explicit run-duration log
exists for MatchaGrid):**
- `MG_CHFJPY_IS.ini` was written 2026-06-15 13:33:55; `MG_CHFJPY_OOS.ini` (the next run kicked off
  right after) was written 13:42:34 — an **~8m39s gap**, which brackets one Model=1, 3.5-year, M15
  single-pass run (`MG_CHFJPY_IS`, 4460 trades, 84,763 bars / 5,045,839 ticks per its parsed report).
  This is **Model=1**, not Model=4 — ticks here are M1-OHLC-generated, not real ticks, so it is not a
  usable proxy for Model=4 cost, which processes/generates far more granular tick data
  (`bars/ticks` in the IS report: 84,763 bars but 5,045,839 ticks already for Model=1 — Model=4 will
  be substantially heavier per the "no disk space"/memory-ceiling note in project memory).
- **No Model=4 run for MatchaGrid exists anywhere found** — no ini, no report, no sidecar. There is
  no direct timing data for this specific EA at Model=4.
- The closest comparable evidence in-repo is **BRK_XAU (`ORDER-210`)**: "every Model-4 run hit the
  memory-ceiling bug on windows >=18 months, so M4 had to be split into 4 sub-windows and merged by
  deal CSV, with 2 end-of-test forced closes excluded." That is the same box, same ceiling the task
  brief describes, on a similarly tick-dense M15/H1-class instrument.

**Proposed concrete split for MAIN (2023.01.01–2025.12.31, 36 months) at Model=4:**
Given the ~18-month ceiling and the precedent both from BRK_XAU (4× sub-windows) and from
MatchaGrid's own already-existing 2026-06-28 sub-window attempt (`QWEN_MG_IS` 24mo /
`QWEN_MG_OOS` 17mo / `QWEN_MG_half1` 6mo, all under 18mo except the 24-month one, which suggests
24mo may already be too close to the ceiling for M15-tick-dense Model=4):

| Sub-window | Span |
|---|---|
| MAIN-1 | 2023.01.01 – 2023.10.01 (9 mo) |
| MAIN-2 | 2023.10.01 – 2024.07.01 (9 mo) |
| MAIN-3 | 2024.07.01 – 2025.04.01 (9 mo) |
| MAIN-4 | 2025.04.01 – 2025.12.31 (9 mo) |

Four 9-month legs (comfortably under the ~18-month ceiling, matching BRK_XAU's own 4-way split
count) merged by deal CSV per the ORDER-210 method, with end-of-sub-window forced-close deals
excluded from the stitched trade list (same caveat ORDER-210 flagged: the challenger's merged trades
are "not strictly like-for-like against a continuous run" — expect the same caveat here). BWD
(2020.01.01–2022.12.31, 36 months) would need the same 4×9-month treatment if BWD is also run at
Model=4 (grid doctrine requires Model-4 as hard-gate evidence for the ENGINE-EDGE-adjacent /
grid class per CLAUDE.md verdict gate).

---

## 7. Existing claims about MatchaGrid in `_triage/*.md` and scorecard/EDGE_CATALOG

- **`EDGE_CATALOG.md:46-48`** —
  > "### MG_v1 MatchaGrid — CHFJPY M15 (CORE) 🟨
  > **Mechanism (hypothesis):** bounded grid with hard SL on a range-bound cross.
  > **Why edge:** CHFJPY oscillates in a range; the grid harvests the back-and-forth, the **bounded**"
  (label still says CORE here — **stale**, superseded by ORDER-215's PARKED-VERIFY downgrade;
  EDGE_CATALOG was not updated in the same commit as the scorecard/master-index rows were)
- **`EDGE_CATALOG.md:122`** — "generalise MatchaGrid's 'bounded+SL' to other rangers (EURGBP, EURCHF)"
  — a build-on idea premised on the same "bounded+SL" framing questioned in section 3 above.
- **`EA_SCORECARD_AND_REGISTRY.md:156`** (quoted in full above, section headline table) — current,
  post-ORDER-215 status: `PARKED-VERIFY(user)`, notes the genetic/dirty-selection vs
  clean-OOS-confirmation split, "grid bounded+SL", "ACTIVE บนเงินจริง... → owed: clean-MAIN re-measure
  + fan + flat-lot probe + Model-4 (grid ⇒ M4 บังคับ) ก่อนจะเรียก CORE ได้อีกครั้ง."
- **`EA_MASTER_INDEX.csv:156`** — same downgrade, same owed list ("clean-MAIN re-measure + sensitivity
  fan + flat-lot probe + Model-4 (grid = M4 mandatory) before CORE can be claimed again").
- **`AGENT_TASKBOARD.md:479-494`** (ORDER-215 itself) —
  > "Selection leg is fully dirty: `OPT_MG_CHF_lowDD.ini` is genetic with Criterion 0 over
  > 2023.01-2026.06, eating five months of holdout, no fine grid, no fan. But the headline 2.08
  > comes from `MG_CHFJPY_OOS.ini` over 2020.01-2023.01, which is genuinely out-of-sample and
  > clean. Selection dirty, confirmation clean = weak, not false."
  Explicit **"ห้าม" (forbidden) list**: don't touch the live account's values; don't accept
  Model-2 as evidence for this grid EA.
- **`docs/memory_control/B1_DATASET.csv` row 53 (ORDER-215)** — same summary, closes with: "Part 2
  (clean-MAIN re-measure + fan + flat-lot probe + Model-4, which grid doctrine makes mandatory) left
  OPEN and specced, not run — M15 over three years on a grid is a heavy M4 queue and the box is
  already hitting the memory ceiling" — i.e. this recon's section 6 split is exactly the debt that
  row flags as unpaid.
- **`_triage/ORDER204_GENETIC_RETRO_AUDIT.md:118-121`** —
  > "`OPT_MG_CHF_lowDD.ini` — its only citation lives in a scorecard table explicitly marked
  > `⛔ HISTORICAL, SUPERSEDED 2026-07-09`. Whether the MatchaGrid CORE verdict is still the
  > operative one for MG_v1 was not re-derived here (out of scope — this audit does not judge
  > verdicts, only traces citations)."
  (This is the audit that fed into ORDER-215; ORDER-215 itself is the "re-derive it" step it declined
  to do.)
- **`_triage/ORDER204_GENETIC_RETRO_AUDIT.md:52`** (ORDER-214, Gold Reaper, a sibling row) documents
  the **inert-axis hazard** for closed-source EAs whose sizing input is overridden internally — worth
  keeping in mind for MatchaGrid's flat-lot probe: confirm `InpStepAddLot=0` actually produces flat
  lot sizing in the Journal/trade log rather than assuming the input binds.

---

## Summary of what was READ vs INFERRED

**Read directly (facts):**
- `.ex5` locations, no `.mq5` anywhere.
- Full `[Tester]` blocks of all 14 `.ini` files.
- All 6 `.set` files' parameter values and comments.
- Full input dumps (including `InpCutLoss*` family) from 3 rendered `.htm` reports.
- Parsed-JSON metrics (PF/DD/trades/leverage) for 6 reports.
- Absence of `.leverage_check.json`/`.truncation_check.json` for true MatchaGrid reports.
- Scorecard/master-index/taskboard/B1_DATASET/EDGE_CATALOG text, quoted verbatim.
- File timestamps used for the Model=1 timing bracket and the sub-window precedent.

**Inferred / recommended (not directly evidenced, flagged as such above):**
- The meaning of `InpCutLossMode=0` (disabled vs. some other mode) — **not found anywhere**,
  recommend testing 0 vs non-zero directly rather than assuming.
- The Model=4 cost/time for MatchaGrid specifically — no direct timing data exists; the 9-month
  ×4 split is extrapolated from the BRK_XAU precedent and the task's own stated ~18-month ceiling,
  not from a MatchaGrid Model=4 log (because none exists yet).
- Whether the bare `Leverage=100` ini form actually mattered for these historical MatchaGrid runs —
  the reports show the correct `1:100` was in effect, but there's no assertion sidecar proving the
  ini itself was the cause (could be coincidental cache state) versus this being not actually a
  material risk. New runs won't have this ambiguity since `mt5_run.ps1` now writes `1:N` and asserts.
