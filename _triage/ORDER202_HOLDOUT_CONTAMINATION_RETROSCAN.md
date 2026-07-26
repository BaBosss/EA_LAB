# ORDER-202 — retro-scan: which verdicts rest on a burned holdout?

> **Renumbered 2026-07-25.** This was written as ORDER-201, but a parallel session had already
> registered ORDER-201 on the taskboard for the ST03 spacing lever. The report files on disk keep
> their `O201_*` prefix on purpose — renaming artifacts after the fact would break the pointers in
> this document and in the reports themselves. Prefix = when it ran, not which order owns it.

**Opened** 2026-07-25, after finding that `.claude/agents/ea-screener.md` and `ea-validator.md`
had run every screen and every optimize with `-ToDate 2026.06.01` — six months INSIDE the
declared 2026H1 holdout (commit `c612dbe0` fixed the definitions). Fixing them stops future
leakage; it says nothing about what already happened. This scan answers that.

**Method.** Parsed all **6,467** `.ini` under `_mt5_auto` for `FromDate/ToDate/Optimization`.
Threshold set deliberately at `ToDate > 2026.01.01`, not `> 2025.12.31`: a run ending exactly
`2026.01.01` produces **zero** 2026 deals (verified on `RSIMR_L2_RSI25_75_SL25_MAIN.htm` — the
string `2026.01.01` occurs once, in the header, and the last dealt day is 2025.12.31). That
boundary convention is harmless and was NOT counted as contamination.

**Result: 87 optimize passes selected parameters on a window overlapping 2026H1.**

---

## Intersection with what is actually deployed

Most of the 87 belong to EAs that were never deployed (EA_LabTemplate probes, Boss_11/13,
LondonBO, EA_ZSCORE, BaronGrid, Kangaroo sweeps…). Two deployed families were exposed.

### Cleared — no action
`EmaStoRev` (991070), `MacdDiv_Naked` (999094), `EA_DONCHIAN` (990030) — all their optimize
passes end at `2026.01.01`, i.e. zero 2026 deals. Clean.

### Boss_14_GridLog cohort — 8 demo legs, 415573666 — **parameter values are CLEAN**
The contaminated `BOSS14_OPT_<SYM>_1.ini` (2026-07-03/04, → `2026.07.01`) were a superseded
round-1 mechanism sweep. Every deployed leg's parameters trace to
`BOSS14_OPT_<SYM>_IS.ini` — a separate pass at **`2023.01.01 → 2025.06.30`**, verified present
for all 15 symbols. ORDER-166 was a **re-validation** of an already-fixed config on clean MAIN,
not a re-selection.

Residual, and it is real: the promotion gate ("fresh-start OOS" `2025.07.01→2026.07.01`, plus
the FULL/M4CONFIRM windows) reached into 2026H1 for 7 of the 8 legs. So the *values* are clean
but the *ship/no-ship decision* consumed the holdout. **2026H1 is spent for this cohort** — its
genuine forward evidence starts at demo attach. Same disposition as the Boss_16 precedent
(demo-forward-as-holdout). No re-optimize needed. Policy note only.

### EA_BREAKOUT_XAU 991001 — **REAL MONEY, directly contaminated** — re-run done

Both the genetic search (`BRK_XAU_v2_OPT.ini`, `v3_OPT.ini`, `Optimization=2`) and every
"IS" confirm ran `2023.01.01 → 2026.06.01`. This EA's naming convention calls that window
"IS" and uses 2020–2022 as its only out-of-sample. **No ini with a clean upper bound exists
anywhere in this EA's funnel** — checked all 16 `BRK_XAU_*.ini`.

Re-ran both deployed configs on real ticks (Model 4), leverage asserted 1:100, full `.set`
pinned, on the second portable instance. Data comparability verified: the run reports
**99,472,212 ticks** for XAUUSD 2023.01–2025.12, identical to runs made on the primary
instance (`PVM4_MAIN`, `SS1M4_tp3p5_MAIN`) — same tick database, numbers are comparable.

| window | v2 (Bars40/Tp5.0/Ema200) | v3 (Bars55/Tp8.0/Ema150) |
|---|---|---|
| BWD 2020–2022 | **PF 1.66** · 33t · net 136.11 | **PF 1.01** · 26t · net **1.66** |
| MAIN 2023–2025 (clean) | **PF 1.98** · 46t · net 315.75 | **PF 1.86** · 40t · net 328.39 |
| 2026H1 (the burned window) | PF 3.62 · 7t · net 307.81 | PF 5.32 · 5t · net 407.24 |

**Reading it:**

1. **The edge survives the clean window.** v2 clears both bars comfortably (MAIN 1.98 vs the
   1.2 hard bar; BWD 1.66 vs the 1.0 soft bar). The contamination did not manufacture a fake
   edge — this is the good news, and it is the reason nothing needs to be pulled off the
   account today.
2. **But the old headline numbers were inflated by the burned window.** Over 2023.01–2026.06,
   roughly **half the total net came from 5–7 trades in those six months** (v2: 307.81 of
   623.56; v3: 407.24 of 735.63). Any figure previously quoted from a `2023.01–2026.06` run
   overstates what the EA does on data it did not see.
3. **v3 is the worse config, and it looks selected-into-the-leak.** v3 was the later revision
   (28 Jun vs 22 Jun). It **beats** v2 only on the burned window (5.32 vs 3.62) and is worse on
   **both** clean windows — MAIN 1.86 vs 1.98, and BWD **1.01 vs 1.66**, where v3's three-year
   stress-regime net is **+1.66 on 26 trades**, i.e. indistinguishable from breakeven. That is
   the classic signature of a parameter set tuned into leaked data: it wins where it peeked and
   loses where it did not.

**Consequence for CR-002.** The open question "is v2 or v3 actually on the VPS?" stops being
bookkeeping. If **v3** is live on 159503454 / 159475669, real money is running the config that
is barely above breakeven through a stress regime and was chosen with the answer sheet
visible. **v2 is the config the clean evidence supports.**

---

## Open — needs the user

1. **Confirm which `.set` is live for 991001** on both real accounts (ATTESTATION_MAP already
   flags the lineage AMBIGUOUS; compiled defaults are a third possibility). If it is v3,
   switching to v2 is the evidence-backed move — but that is a live real-money change and is
   the user's call, not mine.
2. **2026H1 is now spent** for EA_BREAKOUT_XAU and for the Boss_14 cohort. Neither can produce
   a fresh holdout number; their forward evidence is the demo/live record from attach onward.
   Worth declaring explicitly, the way Boss_16 was.

## Not done, deliberately

A clean-window **coarse-genetic re-optimize** of EA_BREAKOUT_XAU has not been run. v2 already
clears both bars on clean data, so this is an improvement question, not a validity one — and
per the user's 2026-07-25 stance on optimizer method (coarse genetic first, then drill down,
never default to point-tests), the ranges are worth agreeing before burning the runs.

Reports: `_mt5_auto/reports/O201_BRK_{v2,v3}_{BWD,MAINCLEAN,HOLDOUTONLY}_M4.htm`

---

# Part 2 — the NOT-deployed EAs (2026-07-25, same day)

Swept every written standing for the 25 contaminated non-deployed experts across
`EA_SCORECARD_AND_REGISTRY.md`, `EA_MASTER_INDEX.csv`, `EDGE_CATALOG.md`,
`AGENT_TASKBOARD.md`, `ARCHIVE_TASKBOARD_2026-07A.md`, `PROJECT_STATE.md`, `_triage/*VERDICT*`.

The sort that matters is **direction of error**: contamination inflates. So a FAILING verdict on
a contaminated window is, if anything, more solidly failing — nothing to redo. Only *passing*
or *promising* standings can have been created by the leak. Two were.

## Re-tested (both on clean MAIN 2023.01–2025.12 + BWD 2020–2022, Model 1, leverage asserted)

### Boss_16_KangarooGrid — **survives, but its judge bar was written from inflated numbers**

This one was urgent because it is **`PENDING_ATTACH(user)` right now** (ORDER-190): a
demo-scaled `.set` is built and waiting to go on a chart, and the pre-registered judge criteria
that will decide its fate were calibrated off the ORDER-078 funnel — every step of which ran
`2023.01.01 → 2026.07.01`, with a year-split row literally labelled `2026H1 … PF 1.75 / 85t`.

| window | PF | trades | eqDD |
|---|---|---|---|
| MAIN 2023–2025 (clean) | **1.46** | 205 | 7.39% |
| BWD 2020–2022 | **1.30** | 278 | 9.70% |
| *(archived contaminated headline)* | *1.57* | *285* | — |

**The edge is real** — clean MAIN 1.46 clears the 1.2 hard bar and BWD 1.30 clears the 1.0 soft
bar comfortably, which is more than most of this repo's candidates manage. Attaching it is still
the right call.

**But two pre-registered numbers must be corrected before attach, or the demo judge will be
graded against a bar the leak wrote:**
- expected PF **1.46, not 1.57**
- expected trade rate **≈68/year** (205 over 3 years), not the ~81–90/yr implied by 285 trades
  across the longer contaminated span. This one also feeds judge-readiness forecasting, which is
  exactly what set the judge dates.

The existing "demo-forward is the real holdout" designation (the Boss_16 precedent named in
CLAUDE.md) stays correct and is now better founded: 2026H1 was consumed by the funnel, so the
demo period genuinely is the first independent evidence.

### Boss_NRBreakout_rev01 — **the revival hook was the contamination**

Standing was `PARKED-final`, but with a hook that invited revival: *"ceiling ~1.31, OOS 1.37/20t
— revisit if bench dries"*. Both figures are contaminated — the plateau optimize ended
`2026.07.01`, and the "OOS" window `2025.07.01–2026.07.01` sits **inside** 2026H1 rather than
merely being selected with it.

| config | MAIN 2023–2025 clean | BWD 2020–2022 |
|---|---|---|
| `NRBreakout_OPT1_p10_ISpick.set` | **PF 0.93** / 80t / net −22.34 | 0.96 / 99t / −12.06 |
| `NRBreakout_opt1.set` | **PF 0.82** / 192t / net −197.77 | 1.02 / 192t / +16.54 |

**Every clean MAIN number is a loss.** The park was accidentally right, for the wrong reason —
it was parked on slot priority against Boss_14, when the honest reading is that the ceiling that
made it look worth reviving does not exist on data it did not see. Registry + master index
annotated so nobody re-opens this on the 1.31 figure.

Caveat kept deliberately: only the two `.set` files that exist in the repo were re-run. If the
1.31 pick was a third parameter set that was never saved, it survives only inside the optimize
XML — it is not recoverable from a `.set`, and would have to be re-derived by a clean optimize.

## Failing verdicts on contaminated evidence — noted, no rework
`Boss_15_ST03` chassis-cell (DEAD-OPTIMIZED; 0/6 and 0/9 cells, best MAIN 1.15 < 1.2) ·
`EA_ZSCORE` (killed at Stage 2 by a **clean** BWD run, PF 0.77 — the contaminated number was the
one that didn't matter) · `EA_LNBREAK` (0/81, best 1.048) · `ZeusInspired` non-XAU legs (all
terminal numbers already under gate) · `Degold_hunter` (killed on structural/artifact grounds,
nothing to do with windows). Contamination can only have flattered these.

**Standalone ST03 is clean** — today's separate spacing-lever work re-measured it on the
standard MAIN/BWD windows, so its live `PARKED-VERIFY(user)` standing does not rest on leaked
data.

## No written standing at all
Boss_11_GridTrend · Boss_12_Breakout · Boss_13_MeanRev (regression-cage entries only) ·
EA_LabTemplate (infra deprecation note only) · LondonBO · BaronGrid · MooDeng · Quantum ·
EAAmongUs · Boss/PIVOT-NZDUSD · EX197-GBPJPY. Nothing to correct.

## Left unchecked, flagged
`NuiIndy` live guardrail recommendation (`CutLoss=30`, ORDER-095 verdict 2026-07-17) cites
"both-window profitable" without a greppable date string. It is a LIVE EA, so worth confirming
its window at some point — it was outside this pass's deployed-EA scope split.

Reports: `_mt5_auto/reports/O201_B16_flat_{MAINCLEAN,BWD}_M1.htm`,
`O201_NRB{,base}_{MAINCLEAN,BWD}_M1.htm`

---

# Part 3 — closing the "left unchecked" NuiIndy item (Claude/Opus 2026-07-26)

**The window question is answered, and it is CLEAN.** Every `NuiIndy` ini under `_mt5_auto/ini`
carries `Optimization=0` — there is no optimize pass anywhere in this EA's record, so no
parameter was ever *selected* on any window and the contamination class cannot apply to it. The
guardrail runs specifically sit on **2022** (`FromDate=2022.01.01 ToDate=2023.01.01`) and **2024**
(`2024.01.01 → 2025.01.01`), both entirely outside 2026H1. The ORDER-095 phrase "both-window
profitable" is literally true: PF 1.19 (2022) and PF 2.20 (2024). **Retro-scan item closed, no leak.**

**But confirming the window surfaced a separate problem with the same evidence, so it is recorded
here rather than left implicit.**

| window | base `CutLoss=100` | `cut30only` | `cap12+cut30` |
|---|---|---|---|
| **2022** | **NO CONTROL RUN EXISTS** | PF **1.19** · 933t · net +1 080.62 | PF **0.42** · 520t · net **−2 915.09** |
| **2024** | PF 2.20 · 836t · net +2 689.34 | PF **2.20** · 836t · net **+2 689.34** | PF 1.27 · 493t · net +364.56 |

1. **`CutLoss=30` was INERT in 2024.** The cut30 run is identical to the base run to the cent —
   same PF, same net, same trade count. Verified this is a real comparison and not a mislabelled
   duplicate: the two `.ini` differ exactly where they should (`CutLoss_Percent=100.0` vs `=30`,
   `MAX_Order=99999.0` in both, same symbol/TF/window). Drawdown simply never reached 30% that
   year, so the guardrail never fired. **The 2024 run is not evidence about the guardrail.**
2. **2022 — the one window where a DD-kill could matter — has no base control.** There is no
   `NUI_EURUSD_H1_base_2022`; the report set is only the four listed above.
3. **Therefore: there is not a single window where `CutLoss=30` was measured against a control and
   shown to help.** What the evidence supports is "it does not hurt" (2024) plus a profitable live
   account. That is weaker than "validated guardrail" and the recommendation should be read that way.
   This is the same shape as the ORDER-216 fake-plateau finding: a parameter that cannot move the
   result produces reassuring-looking agreement.
4. **What IS strongly evidenced is the negative, and it confirms standing doctrine with numbers.**
   The `MAX_Order=12` cap is destructive on both windows — 2022 PF 0.42 / net −2 915 against
   cut30-only's 1.19 / +1 080, and 2024 PF 1.27 against 2.20. This is the greppable backing for the
   existing rule that NuiIndy's guardrail must be a **DD-kill, not an order-count cap** (the cap
   amputates the escalation engine that is the actual edge).

**Deliberately NOT done:** nothing was changed on the live EA, and no run was launched. NuiIndy is
a user-lane deployment (magic 1524, account 159475669) — this is an evidence-quality note, not a
verdict. **If anyone wants the guardrail actually validated**, the missing run is one control:
base `CutLoss=100` on 2022, same symbol/TF, compared against the existing `cut30only_2022`.

Reports: `_mt5_auto/reports/NUI_EURUSD_{cut30only,cap12cut30}_{2022,2425}.htm`,
`NUI_EURUSD_H1_base_2425.htm` · inis of the same names under `_mt5_auto/ini/`.
