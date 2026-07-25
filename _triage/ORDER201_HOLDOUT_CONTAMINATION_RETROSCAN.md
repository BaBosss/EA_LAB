# ORDER-201 — retro-scan: which verdicts rest on a burned holdout?

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
