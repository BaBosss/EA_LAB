---
name: backtest-optimize-rigor
description: Ordered, judgment-driven workflow for backtesting and optimizing ONE trading EA (MT4/MT5), plus the failure-mode catalog that voids most good-looking results. Treats every profitable backtest as a claim, guilty until proven innocent. Use when running, optimizing, sizing, or judging an EA backtest, choosing a .set, deciding real-edge vs artifact, or before deploying. Splits work into CLAUDE-judgment steps vs QWEN-delegated batch runs to save tokens. Trigger on /backtest-rigor and proactively whenever evaluating backtest/optimization results, choosing parameters, sizing risk, or sizing a robustness verdict.
---

# Backtest & Optimize Rigor

A profitable-looking backtest is a **claim**, not a result. High PF from a random/optimized EA is usually an artifact (tight-TP fill bug), recovery (martingale/grid), or overfit (curve-fit to one regime). This skill is (1) the ordered workflow for one EA and (2) the catalog of illusions with the single test that exposes each.

## Core stance
- **Guilty until proven innocent.** PF 2+ on a downloaded/optimized EA = investigate, not bank.
- **PF > ~3 or DD < 0.5% → suspicion, not celebration.** Real edges are modest; "too good" = artifact or under-leverage.
- **Don't reject until you UNDERSTAND it.** A failed test means "REJECT as tested (this symbol/TF/model/size)", not "worthless forever" — unless you understand the mechanism well enough to know no config saves it (e.g. PF built purely on open-price fills of a tight TP → dies on real ticks everywhere).
- **Name the missing regime.** Every backtest covers one regime; state what's absent (no crash? no strong trend? range-only?) — that's where it breaks.

## Model policy (crisp — see Step 8 of the ladder for the full statement)
- **Model 2 / Open Prices = `M2_OPEN_PRICE_DIAGNOSTIC_ONLY`.** Use only for a specific engineering diagnosis (zero-trade, broken config, branch/input firing, or order plumbing). Its PF/net/DD/trades carry no strategy-performance, ranking, selection, portability, plateau, or robustness authority; there is no routine Model-2 stage.
- **Model 1 / 1 Minute OHLC = `M1_M1_OHLC_RESEARCH`, the minimum strategy-performance evidence level.** Use it for base screens, mechanism/portability, MAIN search, optimization region mapping, frozen BWD and temporal/concentration reads.
- **Model 4 / Every tick based on real ticks = `M4_REAL_TICK_FIDELITY`, mandatory for every EA before Candidate eligibility.** Run frozen MAIN+BWD on one acceptance-critical MT5 installation lineage with exact EX5/set/build identity and no retuning. Mechanical inability blocks Candidate evidence; it is not a strategy failure.
- **⚠️ Fixed-spread blind spot** (unchanged): MT4/MT5 tester holds spread constant for the whole run — never widens on news. An EA whose live risk control leans on a `MaxSpread` filter shows worse backtest DD than live. Flag this on any REJECT of a spread-filter EA.
- <sub>proof twice same day 2026-07-03: AUDCAD PF 1.80(M2)→0.89(M1), AUDNZD 1.96(M2)→1.06(M1) — both looked like candidates off M2 alone. Cuts both ways: don't reject off a fast screen either.</sub>

---

## Verdict discipline (added 2026-07-03 — each rule was paid for the same day)

- **Do not terminally DEAD/REJECT a concept from one default cell.** The 2026-07-03 rescue history remains valid evidence against over-generalizing one weak configuration, but it no longer creates an automatic optimizer debt. A clearly poor Model-1 base/home may `STOP_EXPANSION / PARK` when no direct-consumer hypothesis survives; optimization is reserved for a qualified survivor. `DEAD-OPTIMIZED` remains a terminal classification that must be earned only when a contract actually pursues that question.
- **Backward-OOS is mandatory when IS and OOS sit inside one regime.** IS/OOS both drawn from the
  same 1–2 recent years proves regime-fit, not durability. Zeus GridLog passed IS/OOS (both 2025–26,
  retention 1.09) then died on unseen 2023–24 (one symbol barely traded, the other hit 36% DD).
  Run the earlier unseen years before any deploy decision.
- **Per-year split of one full-window run = free backward-OOS.** `D:\EA_LAB\scripts\report_year_split.py`
  breaks a single report into per-year PF/net/DD from closed deals. Aggregate PF hides losing years
  (full PF 1.12 hid a PF 0.94 losing final year). Every sweep verdict must look at the year rows.
- **Trade-order MC is an optimistic lower bound — proven.** Reshuffle-MC on 2025–26 trades said
  worst-case DD 18%; the real hostile year (2023) delivered 36% at the same size. Treat MC tails as
  "at least this bad"; the true tail needs the hostile years in the actual data.
- **Screen at reduced size so the kill-DD cage can't truncate samples.** Sizing calibrated to one
  symbol tripped the 25% kill on 4 of 5 other symbols, silently cutting their samples to ~1 year
  (looks like "stopped trading", is actually "halted"). Screen at ~0.25× (PF is lot-scale invariant),
  size up only after the edge is confirmed.
- **Optimizer output is IN-SAMPLE.** Best-pass PF from a full-window optimization is a claim, not a
  result — plateau-center pick → IS/OOS split → MC, in that order, before believing any of it.
- **Cap breach (DD / margin / deposit-load / MC-ruin) = a sizing/tuning finding, NEVER a direct
  EA reject** (user rule 2026-07-03). These metrics scale with lot; PF does not. Order of operations
  before any cap-based REJECT: (1) rescale into the DD band (linear lever) and re-measure,
  (2) optimize probe if still out of band. REJECT on a cap only when: no config fits the band with
  the edge still above gate, the broker min-lot floor is reached and it's still out of band, or the
  EA opens no trades at all. Edge-based failures (PF below gate at ANY size) reject directly —
  they're the scale-invariant part.
- **Shared sweep sets transfer across instruments ONLY on their ATR-relative axes** (2026-07-04
  self-review). Distance/SL as ATR×mult self-scale across symbols; **money-based axes (basket-TP $,
  fixed lot) do NOT** — the same $-grid means different geometry per pip value, and is flat-out
  wrong on metals/indices. Label every shared opt set with its instrument class; rebuild $-axes
  from the instrument-scale table before crossing classes. A symbol killed under a mis-scaled
  $-axis is a scale artifact, not a dead edge.
- **A coarse-grid "plateau" (3 points/axis) is a hint, not a plateau.** Before an optimizer-picked
  config goes to demo/live, run a ±20% single-axis sensitivity fan around it — INCLUDING axes the
  sweep froze (SL, max levels). Most variants holding ≥70% of baseline PF = real plateau; any
  variant flipping to a loss = ridge — rethink before promoting.

---

## The workflow (one EA, in order)

Tags: **[C]** = Claude judgment, do not delegate · **[Q]** = menial, delegate to qwen (see Delegation map).

### Phase A — Understand (before running anything) **[C]**
0. **Check the EA is USABLE first — license/expiry/account-lock.** A time-expired or demo-locked .ex4/.ex5 may still backtest beautifully and then refuse to trade live. Confirm it can actually deploy BEFORE spending hours validating (learned the hard way: an EA cleared every gate, then turned out expired = all effort wasted).
1. **Classify the strategy type** from the params: trend / swing / scalping / grid / reversal / breakout. This sets the EXPECTED trade frequency and the candidate home timeframe.
2. **Find its home TF/symbol — don't assume.** A swing EA on H1 or an M15 EA on H1 is tested wrong from the start (BRN207 literally said "TF15"). Plan to sweep TF and symbol, not just the one with the deepest data.
3. **Read the UNIT of every money/risk param:** points (→ depends on digits), money ($), or % of balance. A `TP = 1% of balance` on $10k = $100 target → unreachable at 0.01 lot. Targets must be reachable in the configured regime.
4. **Split params:** *edge* (signal periods, thresholds, TP/SL) vs *risk-shaping/danger* (lot multiplier, max orders/trades, grid distance, max lot).
5. **Trading costs (if the EA/broker has them):** note commission per lot + typical spread + slippage assumptions. Some EAs expose a commission/slippage input — set it realistically; if not present, skip. Costs bite hardest on tight-TP/high-frequency EAs and are only fully modelled at the every-tick fidelity gate (LADDER Step 5, Model-4) — until then assume the screen flatters cost-sensitive EAs.

### Phase B — Calibrate the operating regime **[C decides / Q runs]**
*(order vs Phase C / LADDER Step 0-2 is flexible — it's one way to find the answer, do whichever first)*
- DD 0.3% at 0.01 lot tells you **nothing** — the strategy is under-leveraged to near-zero risk. Make the backtest informative by sizing it to a **meaningful DD band (~10–15%)**. If backtest DD comes in tiny (e.g. 3%), push size up to reach the band. **Hard cap for live: keep max DD ≤ 20%** — a backtest band above that is over-risked for deployment.
- **Push DD with position sizing (lot / % risk) — NOT the multiplier.** The three levers are not equal:
  | Lever | effect on DD | use? |
  |---|---|---|
  | lot / %risk | **linear** scale; equity-curve shape & edge-per-risk unchanged | ✅ correct lever |
  | trade frequency (tighter distance/filter) | changes the **strategy** (more edge OR more noise+spread) | ⚠️ legit tuning, but it's a different EA → re-validate |
  | multiplier (martingale) | **non-linear, fat-tail**; 12% in a benign sample = 100% in the bad regime | ❌ trap — makes the backtest lie |
- Compute the lot needed for the DD band; if it's absurd (e.g. KRAPOOK needed ~670× → 6.7 lots on $10k), that itself is a finding: **capital-inefficient — edge too small to matter at this account size.**
- **Judge at equal risk, not by raw PF on a near-zero-risk curve.** Capture every metric that's available and useful, lead with the risk-adjusted ones:
  - **MAR / Recovery Factor** = net ÷ maxDD (primary cross-EA comparator at equal risk)
  - **Sharpe / Sortino** (return per unit volatility / downside volatility)
  - **monthly return ÷ monthly maxDD**, and **% profitable months** (consistency, not one lucky run)
  - **Profit Factor**, **expectancy** (avg $/trade), **win%** + **avg win : avg loss** ratio
  - **max consecutive losses** & **largest single loss** (tail feel)
  These are mechanical to compute from the report/trades → delegate the extraction to qwen, rank in Claude.

### Phase C — Artifact / structure screen (before optimizing — don't optimize garbage) **[C decides / Q runs]**
Run the relevant diagnostic from the catalog below. Optimizing an artifact wastes hours. Only structurally-sane EAs proceed.

### Phases D–F are replaced by THE OPTIMIZE LADDER below (Step 0-9). Phases A–C = the pre-ladder understanding that feeds Step 0.

---

## 🪜 THE OPTIMIZE LADDER (Step 0-9, ordered · one owner · this skill)

**Windows — pin once, use everywhere** (same names as the VERDICT GATE):
- **MAIN** = the most recent **36 months that do NOT touch the holdout** — it always ends before HOLDOUT begins (today = **2023.01–2025.12**), re-pinned at each 6-month re-opt. `MAIN ∩ HOLDOUT = ∅` is CLAUDE.md's iron rule; the older "≈2023.07–2026.07" text here overlapped 2026H1 and was exactly the leakage channel Codex flagged 2026-07-18.
- **BWD** = 2020.01–2022.12 (trend/stress regime).
- **HOLDOUT** = a window or symbol **never used for selection** (default 2026H1 while untouched; it burns once used → then demo-forward IS the holdout and the verdict must say so).

- **Step 0 — Preconditions (before ANY sweep):** usable check (license/expiry/lock) · classify type + candidate home TF/symbol · param units + instrument scaling (ATR-relative axes transfer across symbols; $-axes rebuilt per instrument class) · **flat-lot probe if any escalation exists** (flat PF<1 while escalated PF>1 ⇒ STRUCTURAL, stop here) · artifact screen (tight-TP ×10 widen · multiplier=1) · **pre-register the bars in the order text**: pass = X · dead = Y · middle = Z.
- **Step 1 — Lever inventory:** `spacing · lot-law · SL width · TP · exit-mode · entry-threshold · symbol · TF`. Mark each SWEPT/HELD. **An EA-level verdict from <3 swept = INVALID.** For oscillator/indicator entries, **entry-signal params are lever #1** (StoK 5→17 flipped the verdict).
- **Step 2 — Coarse (zone-finding · genetic policy, user-ratified 2026-07-25):** MAIN window ONLY — BWD is never a search surface, and the window is NEVER shortened to save wall-clock (a short window = one regime = manufactured overfit; diagnosis runs may use short windows but their results can never select). Mode is decided by **combo count** (product of every `Y`-flagged dim in the .ini):
  - **≤ ~1,000 combos → complete grid** (`Optimization=1`) — exhaustive is cheaper than genetic setup and the surface reads fully.
  - **> 1,000 combos → MT5 genetic coarse** (`Optimization=2`) → zone → **fine complete grid ≤ ~1,000 combos around the zone**. The old "never MT genetic" rule here is REPEALED for MT5 — its rationale ("can't export per-pass params") was proven false 2026-07-25 (`OPT_MDX_GBP_coarse.xml`: all 8 swept dims are per-pass columns, 2,295 rows). It survives for **MT4 only** (`mt4_optimize.ps1` genuinely lacks per-pass params — use `mt4_grid_sweep.ps1`).
  - **Genetic settings:** `-Criterion 7` (Complex — default; balance-max steers the population into spikes) · **engine-edge-class EAs pre-declared → `-Criterion 1` (PF max) + trade floor ×2** (DD is not their kill axis; their cage is the VERDICT GATE's 5 conditions). Zone = top ~10% by Result; **top-1 is never directly selectable**.
  - **Trade floor before reading any surface** (drop rows below it — small-n PF is the noise genetic loves): H4/D1 ≥60 · H1/M30 ≥100 · ≤M15/scalp ≥250 trades per 36-mo MAIN.
  - **Point-test (single runs) may only do 3 jobs:** confirm a locked .set · A/B control-vs-lever probe (1 dim, 2–3 values) · diagnosis. **Selecting params by hand-picked point-tests while ≥2 dims are unexplored is forbidden** — that is the drift this policy exists to kill.
  - **Resources:** local tester agents = **18 of 20 cores** (leave 2 for Claude/Codex/Chrome — one-time terminal agents config). Long runs are fine: est. > ~2 h → run overnight / split batches, never shrink the window. `optimize_guard.ps1` pre-flights every run (unknown non-Boss EA = warn-only; safety params always REFUSE).
  - **One-time assert (first optimize after the 2026-07-25 script changes):** XML DocumentProperties must show `Leverage 1:100` (bare `Leverage=N` was a silent no-op → runs executed at server default 1:2000) and the Result column must be on the Complex scale (~0–100), confirming `Criterion=7` maps to Complex on build 5836.
- **Step 3 — Surface read:** plateau = neighbours also profitable (high mean AND high min-neighbour) · sane trade count for the type · stable DD. Spike or hole = not passed. Fine grid around the zone → pick the **plateau CENTER, never the peak**. Watch that PF didn't rise by collapsing trades to noise. **On a genetic surface, min-neighbour/plateau stats are a biased hint** (sampling is dense only near optima) — read them to place the fine grid, but the plateau verdict comes from the fine complete grid + Step 6 fan. Optional stability read: split the fine-grid window by year — the plateau should hold every year, not average out of one hot year. **If the locked center later fails BWD (Step 4): PARK/diagnose under the preregistered contract; no re-pick or retune against BWD.** BWD is a falsification surface, not optimizer round two.
- **Step 4 — Both-window:** every shortlisted config runs **MAIN + BWD at the same settings, simultaneously** — no single-window ranking survives to the next step. **Basket/grid/recovery EAs: ONE continuous span only** (stitched windows lie ~10×; proven 2026-07-08: PF 7.17/3.97/7.64 tiled → 0.58 continuous).
- **Step 5 — Mandatory Model-4 fidelity:** frozen finalist only; run MAIN + BWD with `M4_REAL_TICK_FIDELITY` on one acceptance-critical MT5 installation, exact EX5/set/build/config identity, and no retuning from the selected M1 center. Compare PF/net/DD/trades plus relevant path/exposure diagnostics. A material model-switch cliff falsifies Candidate eligibility; a mechanical/environment failure is `BLOCKED / EVIDENCE_INCOMPLETE`, not strategy failure.
  - **Highest-sensitivity cases (emphasis only, never an exhaustive trigger):** grid/DCA/basket/multi-position, pending-ladder entries, TP < 20 pip, and any EA whose largest-loss or participation shifts hard between models. Every EA still owes the same universal pre-Candidate M4 MAIN+BWD gate.
  - M4 runs **SERIAL on tester lane 1 only**, never in parallel.
- **Step 6 — Final robustness, only with a direct question/consumer:** sensitivity fan, concentration/path analysis, MC, exposure/depth diagnostics and year splits are selected because they answer a stated risk/mechanism question, not because compute is available. Where a sensitivity fan is preregistered, vary one axis at a time around the frozen center and disclose any sign flip/ridge. MC remains an optimistic lower bound: ruin ≤2% green; 2–10% resize-first then re-measure; >10% after resize = fail; PF-5th ≥1.0 hard floor under the applicable historical contract. Year-split every full-window run (`scripts/report_year_split.py`).
- **Step 7 — HOLDOUT late:** ONE untouched finalist window/symbol only after the research/search surface, frozen BWD, mandatory M4 and applicable final-robustness questions are complete. HOLDOUT is never a search or retuning surface.
- **Step 8 — Candidate readiness / model policy:** Candidate eligibility requires the complete applicable chain. `M2_OPEN_PRICE_DIAGNOSTIC_ONLY` and Math Calculations have no strategy-performance authority; `M1_M1_OHLC_RESEARCH` is the research/search minimum; `M0_GENERATED_TICK` may be named explicitly when used; `M4_REAL_TICK_FIDELITY` MAIN+BWD is universal before Candidate. No M4 result by itself grants DEMO/LIVE/risk/deployment authority.
- **Step 9 — Enough = the preregistered direct-consumer questions are answered.** There is no universal run-count quota. Stop expansion when evidence answers the question; do not manufacture sensitivity, MC, optimization, HOLDOUT or another axis merely to keep compute busy.

**Anti-overfit invariants (one block):** never move to a sweeter zone after seeing holdout/live data · optimizer output is in-sample · a window used for selection is in-sample forever · optimistic-side fidelity can only kill, never pass · window = 3yr fixed (rolling-36), re-opt every 6 months · momentum>reversion prior RAISES the pass bar (PF≥1.2 post-optimize), never waives steps.

---

## Parameter adjustment — hypothesis-driven, never random **[C]**

| Symptom | Adjust | Why |
|---|---|---|
| too few trades | reduce distance / loosen filter | match frequency to the instrument's volatility |
| churn / too many | widen distance / add filter | |
| DD too low to read | **raise lot / %risk** | size into the meaningful band (not multiplier) |
| DD too high | reduce max orders / multiplier / widen grid (fewer stack levels) / cap max lot | control stack depth |
| PF high but suspect | **widen TP ×10** | this is an artifact CHECK, not tuning |

**Three iron rules:** (1) scale point-params to the instrument FIRST (250 pts = 0.7% range on XAU vs 31% on EUR). (2) Change one param-family at a time. (3) Coarse → zone → fine.

**Before writing "dead" / "PARKED" / "regime-dependent" — enumerate every structural lever and
confirm which you actually moved.** A verdict is only as complete as the dimensions you swept. Two
mistakes we made in one session, both caught by the user, both from concluding on a partial sweep:
(a) declared a rebuild "regime-dead" after testing one lot setting (a near-flat LOG factor) — the
proper lot law flipped the same window from PF 0.78 to 2.6-3.0; (b) then swept lot-law + symbol but
held grid-spacing (ATR mult, range 1-5) fixed at 1.0 the whole time and again nearly concluded.
Keep an explicit checklist of the levers — entry threshold, spacing, SL width, TP, lot law, symbol —
and mark each swept/held before any verdict. "I tuned it" usually means "I tuned one of six things."

**Basket / grid / martingale / any multi-position-recovery EA MUST be validated on ONE CONTINUOUS
span, never stitched windows.** A basket that stays open days-to-weeks spans window boundaries;
running separate BWD/holdout/FWD windows truncates those basket lifecycles AND resets equity to the
start deposit each window, so cumulative drawdown + emergency-DD dynamics never compound. Proven the
hard way 2026-07-08: a confluence-breakout + FIXED-recovery gave PF 7.17/3.97/7.64 across three tiled
windows but PF 0.583 (DD 16%, MC PF-5th 0.32, 73-day underwater basket) on the single continuous
2020-2026 span — the deployment-realistic measure, since live trading never resets. Windowed lied by
~10x. Rule: for any basket EA, the holdout/OOS test is a continuous run + MC on that run's trade list;
tiled-window PFs are boundary artifacts. (Single-position EAs — BRK-XAU, London — are immune: no
cross-boundary baskets, so windowed is fine for them.) Also: measure max basket-open duration
(`scripts/max_recovery_days.py`) — that time-underwater IS the recovery-EA tail the equity curve hides.

**Test candidate configs on BOTH regimes at once, not one window then the other.** The lever that
maximizes an in-sample window often *inverts* out-of-sample: deep-grid recovery that scored PF ~3 in
2020-22 dropped to 0.8 (DD 37%) in 2025-26, and the ranking flipped by symbol too (EUR/AUD won the
trend years, GBP/JPY the recent years). A config that wins one window is not "validated" — it is
regime-fit until it clears the *other* regime at the same settings. If no single setting clears both,
that inverse relationship IS the finding (and predicts an optimizer will overfit whichever window you
point it at — don't burn the sweep to re-confirm it).

## Artifact / illusion catalog (each with its test)

| Illusion | Smell | Test | If it triggers |
|---|---|---|---|
| Tight-TP open-price fill artifact | suspicious Model-2/Open-Prices behavior + tiny points-TP | use it only to diagnose the plumbing/fill hypothesis, then re-run the same question at M1/M4 fidelity | Model-2 PF is not verdict evidence; reject only if the higher-fidelity evidence falsifies the edge |
| Martingale/grid "edge" | high PF + multiplier/averaging | **set multiplier=1**, re-sweep; 0/N pass = no signal | REJECT — the EA *is* the martingale (BRN207 0/9) |
| no-SL reversion harvester — un-filterable tail | high PF + ~80% win + no SL + averaging legs; **PF<1 in EVERY real crisis** | re-run real crises; try a vol-gate AND an ADX trend-gate | tail is NOT reactively filterable — vol-gate catches only gap spikes, ADX trend-gate is *counterproductive* (it lags → cuts the good reversion trades). **Cannot size up safely → DIVERSIFY, not leverage.** hard SL also kills the edge (ST03 2026-06-26) |
| Thin sample | trades < expected-for-type | count vs strategy×TF expectation | INCONCLUSIVE, not a number to trust |
| Param not scaled to instrument | same points reused across symbols | points × point-size ÷ daily range | FIX before judging |
| DD "looks safe" (<0.5%) | tiny DD | check lot/deposit + absolute net | under-leveraged, NOT safe — size up & re-judge |
| Spiky optimize surface | few combos PF 7-13, rest garbage | look at neighbourhood not peak | OVERFIT — pick plateau, not spike |
| Model-1 fill fantasy | unnatural n (10k-100k+ trades) + great PF, pending-order scalps at tiny distances | **same cell, same window: Model 1 vs Model 4** | REJECT if M4 flips sign (Degold 2026-07-09: M1 +$344k PF 13 → M4 −$4.3k PF 0.56 — the whole edge was synthetic-bar fills) |
| Naked-signal floor (gold H1) | single-signal breakout/trend EA passes 3 windows ~1.0-1.3 | MC PF-5th lands ~0.85 every time (squeeze 0.837 · trendline 0.867 · supertrend 0.865 — 3 independent datapoints) | don't build more naked signals; start from confluence + tight-SL/wide-TP (the only combo that ever cleared: SqueezeBRK 0.837→1.25) |
| Fake fair-value anchor | VWAP/volume-profile strategy on MT5 spot-CFD | ask: is tick volume real volume here? (no) | whole VWAP family dead on our instruments until real futures volume data exists (2026-07-09, 30 cells all negative) |
| First-entry gate × entry-frequency grid | regime/filter gate added to a grid whose lot ladder depends on entry cadence | A/B trade count: if gated run trades MORE (EURUSD 189→425) dynamics broke | gate is per-home: validate per symbol (worked XAU+USDJPY, broke EURUSD) — never blanket-apply |
| Close-time conditioning survivorship | offline bucket-analysis of a trade list against a LAGGING indicator (ADX/trend state) looks spectacular (Trendline: RANGE PF 0.17 vs TREND 2.05, MC 1.011→1.208) | build the gate in-EA and A/B same windows — gate must read the indicator at ENTRY time | real gate made MC WORSE (0.973→0.861): winning trend-entries fire BEFORE the lagging indicator confirms, then push it up by close — the offline bucket was counting winners into TREND automatically. Offline conditioning with entry-time values only; lagging-indicator gates need an in-EA run before believing anything (2026-07-09) |

## Data discipline (the trap that voids everything)
- **Reserve a holdout BEFORE any selection/optimization; never touch it until the holdout (LADDER Step 7).** Once a window is used to pick or tune, it's in-sample forever.
- **Track what each window was used for.** After optimizing on A, B is only valid OOS if B was never the selection window. (This session: KRAPOOK XAU "OOS" was the original selection window → circular, no independent data left.)

## Monte Carlo — what it can / can't do
- ✅ Confirms edge is stable under reordering (PF not driven by a few outliers; PF 5th-pct > 1.0, ideally > 1.2).
- ❌ Cannot exceed the sample's worst loss → blind to regime change; on a benign sample always says "safe" (circular).
- ❌ Closed-trade MC misses **floating DD** — a grid's real risk.
→ MC necessary, not sufficient. For grids the gate is trend-stress + every-tick, not MC.

## Trade-count expectation by type (replaces a flat "≥100")
Rough sample-sufficiency floors over a multi-year window: scalper many hundreds–thousands; grid/intraday hundreds; swing 50–150; trend/position on H4-D1 can be 20–50 and still valid. Judge sample **relative to the type and TF**, not an absolute.

---

## Delegation map (save tokens — Claude thinks, qwen runs)
**Give qwen the menial batch execution; keep judgment in Claude.** Each qwen job = self-contained prompt, absolute paths, returns a compact CSV/summary that Claude then reads (see the qwen-agent skill).

| Delegate to **qwen [Q]** | Keep in **Claude [C]** |
|---|---|
| Batch backtests across symbols/TFs (loop `mt4_run.ps1`/`mt5_run.ps1` → CSV) | Classify strategy type, read param units |
| Grid sweeps (`mt4_grid_sweep.ps1` with a given grid JSON → CSV) | Choose which params to sweep + ranges |
| Parse reports → metrics CSV (`parse_*_report.py`) | Read the optimize surface (plateau vs spike) |
| Monte Carlo runs (`mt4_montecarlo.py` → summary) | Artifact diagnosis & interpretation |
| Pip/distance rescaling sets (`mt4_pipfix_set.py`) | Sizing decision & MAR judgment, final verdict |

**Qwen prompt skeleton (batch backtest):**
> Run `D:\EA_LAB\scripts\mt4_run.ps1` for EA "<name>" on symbols [<list>], TF <tf>, window <from>..<to>, Model 1, default params. For each: after the run, `python D:\EA_LAB\scripts\parse_mt4_report.py "<report>" --csv` and append the line to `<abs out.csv>`. Kill any running terminal between runs (`Get-Process terminal | Stop-Process -Force`). Report the final CSV path. Do not interpret results.

Always **verify qwen's CSV** (row count, NO_REPORTs) before trusting it.

## Tooling (D:\EA_LAB\scripts)
`mt4_run.ps1`/`mt5_run.ps1` (single test) · `mt4_grid_sweep.ps1` (labeled grid, use over MT4 genetic) · `mt4_montecarlo.py` (MT4 trades → bootstrap) · `parse_mt4_report.py`/`parse_mt5_report.py` · `mt4_pipfix_set.py` (per-instrument rescale) · `mt4_optimize.ps1` (genetic — note: no per-pass params).

**PowerShell-only toolchain (no Python on this box — use these for MT5):**
- `parse_htm.ps1 -Path <report.htm>` — parse MT5 backtest HTM (UTF-16) → PF/Trades/DD/Win%/Sharpe
- `parse_opt_xml.ps1 -Path <opt.xml> [-MinTrades N] [-SortBy PF] [-Top N]` — parse MT5 optimizer XML (SpreadsheetML, handles ss:Index gaps) → per-pass table
- `mc_from_summary.ps1` — simplified bootstrap MC from report summary stats (avg_win/avg_loss, no per-trade CSV needed; n=3000; outputs PF_5th/median/DD_95th/ruin%). Note: underestimates tail risk vs full-trade MC — use as gate check, not final verdict.
- `mt5_optimize.ps1` — headless genetic/complete optimize → XML output

**Stale-report rule:** never trust a `.htm` on disk without knowing when it was run. Always rerun with the locked `.set` before citing numbers — especially after any code fix (g_bar_checked, tester-gate). Reports from pre-fix runs will show wrong trade counts and wrong PF.

## NEXT STAGE (routing — owner = `docs/PIPELINE.md`)
When the LADDER's pre-registered bars are answered → hand the holdout+MC+M4 evidence to the **CLAUDE.md VERDICT GATE** (the decision tree + bar table). This skill owns the *method*; the GATE owns the *verdict*. Do NOT write DEAD/PARKED/CANDIDATE here — produce the evidence, route to the GATE.

## One-line reminders
- Understand it (type, home TF, param units) before you run.
- Size to a 10–15% DD band with **lot**, not multiplier. Judge by MAR/Recovery Factor.
- Reserve the holdout first; optimizing consumes a window permanently.
- Optimize on control points; confirm winners on every-tick and bring it to the user.
- Widen the TP, kill the multiplier, scale to the instrument, plateau-not-peak.
- Delegate the runs to qwen; keep the judgment.


---

## 🔒 MANDATORY ADDITIONS (2026-07-10 — จ่ายจริงจาก ORDER-068→077 + user rule)

### 1. Flat-lot probe = ด่านแรกบังคับของ EA ทุกตัวที่มี recovery/grid/martingale
รันครั้งเดียว: ปิด escalation (หา input ที่ถูก — ระวังเคส ST03: LOT_Repeat=999999 คือปิด, =1 คือทบทุกไม้)
แล้วดู PF · **PF<1 = กำไรทั้งหมดคือภาพลวงจากการทบไม้** (พิสูจน์ 3 เคสวันเดียว: ST03 0.68/0.40 ตาย ·
Kangaroo 5.71 ดีขึ้นด้วยซ้ำ = entry จริง · Zeus = ตัวรอด 1/4 เซลล์โดยดวง) · locked EA ก็ทำได้ถ้า
multiplier เป็น input · **ห้ามลงแรง optimize อะไรก่อนรู้คำตอบข้อนี้**

### 2. Pre-registered bars — ตั้งเกณฑ์ก่อนเห็นผล เสมอ
ทุก order ทดสอบต้องเขียน "ผ่าน = X / ตาย = Y / ระหว่างกลาง = ทำอะไรต่อ" **ในตัว order ก่อนรัน**
(กัน peak-hunting + กันตัวเองใจอ่อน) — แบบที่ใช้จริง: ORDER-071 (PF≥1.0 ทั้ง 2 symbol / <0.85 ทั้งคู่ปิดเคส /
กลาง = WATCH ไปต่อแบบจำกัด) · ORDER-077 (BWD<0.9 ทั้งคู่ = regime artifact)

### 3. Rescue ladder ขั้นต่ำก่อน DEAD (user rule 2026-07-10 — "ของดีห้ามตายเงียบ")
ตัวที่**ผ่านเกณฑ์เบื้องต้น** (smoke PF>1 หรือ naked ≥0.85 หรือ structure เด่น) ห้ามตีตายจนกว่า:
- **optimize ≥3 รอบ ชุด lever ต่างกัน × ≥2 TF ต่อ symbol** — ชุด lever เลือกตาม strategy ของ EA:
  | ประเภท EA | รอบ 1 | รอบ 2 | รอบ 3 |
  |---|---|---|---|
  | trend/breakout | entry-threshold/lookback | exit (TP/trail/structure-break) | filter/session |
  | reversion/grid | spacing (fix→ATR→progressive) | basket TP + exit-mode | entry level/period |
  | pattern-based | pattern params | SL/TP structure | HTF gate |
- พิจารณา **symbol อื่นที่เข้ากับ mechanism** (เช่น reversion → ranger, breakout → trender) ก่อนปิด
- ไม่ผ่านแต่ idea/structure ดี → **tag `PARKED-VERIFY(user)` + สรุปให้ user 3 บรรทัด: มันคืออะไร ·
  ตายที่ด่านไหน · ทำไมยังน่าสนใจ** — user มีประสบการณ์มือ (หลาย EA ที่ live อยู่รอดมาเพราะ user เคยเทสเอง)
- exit-mode อยู่ใน lever list เสมอ (บทเรียน ST03: "no-edge" ที่วัดใต้ exit เดียว = verdict ไม่ valid)

### 4. Diagnosis → lever (user doctrine 2026-07-10: เลือก lever จาก "อาการตาย" ไม่ใช่สูตรตายตัว)

ก่อนเลือกชุด lever ของ rescue รอบถัดไป ให้วินิจฉัยก่อนว่ามันตายเพราะอะไร แล้วจ่ายยาตามอาการ:

| อาการ | lever ที่ควรลองก่อน |
|---|---|
| PF ดีแต่ **DD สูง** | TF ใหญ่ขึ้น · ลด lot/risk ต่อไม้ · เพิ่มระยะ spacing/SL กว้างขึ้น (ไม้น้อยลงแต่คุณภาพขึ้น) |
| PF ดีแต่ **ไม้บาง/เทรดน้อย/กำไรน้อย** | TF เล็กลง · threshold หลวมลง · เพิ่ม symbol ใน class เดียวกัน |
| กำไรดีเฉพาะช่วง (**regime สงสัย**) | BWD probe ก่อนทุก lever (ถูกสุด ชี้ขาดสุด) · แล้วค่อยคิด gate |
| **กำไรกระจุก** (top-5 trades >50% ของ net) | หยุด — ตรวจ recovery-illusion ก่อน (flat-lot + concentration check) อย่าเสีย compute |
| winrate สูงแต่ RR แย่ / โดนลากบ่อย | แกน exit (trail / structure-break / time-stop) ก่อนแกน entry |
| ตายที่ M1/M0 แต่ M2 สวย | fill-sensitive — spacing/TP ใหญ่ขึ้นให้พ้น noise ระดับ tick หรือเลิก |

หลัก: **"กำไรดีแล้วตาย" ไม่ใช่จุดจบ — มันคือจุดเริ่มของการวินิจฉัย** · ทุก mechanism ที่เคยพิมพ์เงินได้
(แม้ใน regime เดียว) ให้จดเข้า idea catalog/EDGE_CATALOG ว่ามันรีดกำไรจากอะไร — fragment พวกนี้
ประกอบใหม่ได้ · pacing: rescue เป็น batch เล็ก กระจายหลายวัน ไม่ต้อง burst (เป้าเราระยะยาว)