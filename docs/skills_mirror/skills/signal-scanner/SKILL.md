---
name: signal-scanner
description: >
  Triage a NEW trading-signal idea before committing time to build/optimize it —
  classify the signal as momentum vs reversion (the edge predictor for this
  portfolio), pick the right instrument×timeframe to test, and run the cheap
  smoke sequence that kills dead concepts fast. Use when the user has a fresh
  EA/signal idea, asks "is this worth building", wants to hunt for a new edge,
  or is deciding which symbol/TF to test a signal on. Trigger on /signal-scan.
---

# Signal Scanner

Building and optimizing an EA costs hours. Most signal ideas are dead on arrival — and you can find out in minutes. This skill is the **fast triage gate** that runs before `mql-code-generator` + `backtest-optimize-rigor`: classify the idea, place it on the right instrument, smoke it, and kill it cheap if it has no naked edge.

**Boundary vs backtest-optimize-rigor (avoid trigger overlap):** this skill is **pre-build triage** — "is this idea worth coding at all?" on default params. The moment you have a coded EA you want to *optimize, forward-test, or judge for deploy*, that's `backtest-optimize-rigor`. Phase A (classify type) and Phase C (artifact screen) there are the *rigorous* versions of what this skill does *cheaply and early*. Use this first; hand off to that.

## Core stance
- **Cheap death before expensive life.** A 2023–2026 Model-2 smoke on the right symbol tells you in minutes whether a concept has any naked edge. Do that BEFORE writing a full optimizer sweep.
- **Momentum > reversion is the standing prior for this portfolio** (empirically confirmed across 6+ builds). Treat a reversion idea as guilty until proven innocent; demand stronger smoke evidence before building it.
- **Naked edge or nothing.** Strip recovery (martingale/grid/averaging) to a single naked entry and smoke THAT. If the edge only appears with recovery on, the recovery IS the "edge" — it's a martingale, reject it. (63 MT4 EAs + 9 bucket-D ports all died this way.)
- **The instrument is part of the signal.** The same logic is alive on XAU and dead on EUR. Don't smoke a momentum signal on a ranging pair and conclude "no edge."

---

## The thesis table (confirmed 2026-06-22 — start here)

| Signal class | On XAU / GBP (trending) | On EUR (ranging) | Verdict |
|---|---|---|---|
| Breakout / open-range momentum | PF 1.77–2.08 ✅ | weaker/conditional | **proven edge class** |
| Pullback-in-trend (regression) | PF 0.81 ❌ | — | dead |
| RSI / BB mean-reversion | PF ~1.0 ❌ | PF 1.03 ❌ | dead (no naked edge) |
| MACD reversal | ceiling PF ~1.11 ❌ | — | weak |

**Proven live winners:** LondonConsoBreakout (GBP/EUR H1), EA_BREAKOUT_XAU (XAU H1) — both momentum/breakout. The idea-bank "VALIDATED" cards (Pivot Range, EX197) are STALE — no live leads there. See [[signal-landscape]], [[standalone-template-architecture]].

---

## The workflow (in order)

### Step 1 — Classify the signal **[C]**
- **Momentum/breakout** (range break, session open-range, NR-bar, channel break, MA cross-with-trend) → aligned with the proven prior, proceed with normal scrutiny.
- **Reversion/pullback** (RSI extreme, BB touch, oversold bounce, pullback-to-MA, regression-to-channel) → against the prior. Require a stronger smoke (must clearly clear PF 1.2+ naked, not 1.0-ish) before committing build time. Don't build "another reversion EA" on hope.
- **Recovery-dependent** (the idea only makes sense WITH a grid/martingale) → reject the framing; ask what the naked entry edge is. If there isn't one, stop here.

### Step 2 — Pick instrument × timeframe **[C]**
- Match the signal's nature to the instrument: momentum → trending instruments (XAU, GBP-crosses); a reversion idea (if pursued) → ranging majors.
- Pick the **home TF** from trade-frequency expectation (breakout/session → H1; scalp → M5–M15; swing → H4). Don't default to "the TF with the deepest data."
- Plan to smoke 2–3 (symbol, TF) cells, not one — the edge may live in only one cell.

### Step 3 — Naked smoke **[C designs / Q runs]**
- Author the signal in the **standalone template** (see `mql-code-generator`), recovery OFF, naked entry + ATR SL/TP, **tester-gate fix in place** (or smoke falsely shows 0 trades).
- Smoke window **2023.01.01–2026** (IS-era), **Model 2** (bar-open — fast, identical to Model 1 for bar-open EAs). Default-ish params; this is a triage, not an optimize.
- Capture per cell: PF, trade count, DD, win%. Delegate the runs to qwen (`mt5_run.ps1` loop → CSV).

### Step 4 — Smoke verdict **[C judgment]**
```
PROCEED  : at least one (symbol,TF) cell PF ≥ ~1.2 naked with a sane trade count
           (matches the type's frequency floor) and structurally sane DD
           → graduate to backtest-optimize-rigor Phase D (optimize)
           NOTE: an insane DD at smoke sizing is NOT a kill reason by itself —
           DD is lot-linear; resize first (user rule 2026-07-03). Kill reasons
           at smoke are edge-based (PF) or structural, never cap-based.
WATCH    : PF ~1.0–1.2, structurally correct (e.g. momentum on a trender) but
           below gate → ONE optimize attempt may lift it; cap the effort
DEAD     : ONLY two ways to write DEAD off a smoke —
           (1) STRUCTURAL: PF only appears with recovery on (flat-lot < 1), OR
               uncapped-ruin / cracked / no-source. These are the ONLY concept
               kills a smoke can make.
           (2) OPTIMIZE-CONFIRMED: after optimizing ≥3 levers on the RIGHT HOME,
               the ceiling still stays < 1.0 both-window (SessionBreakout lesson:
               1,200-pass ceiling 1.20, forward 0.91 — optimize confirmed death).
           A low default-param PF is NEVER a concept-kill by itself.
```
- **🔴 A low smoke PF ≠ dead concept — it means "not optimized yet."** Do NOT write DEAD/PARKED-concept off default params. This is a repeat failure mode (paid 2026-07-16: SMC×STO killed on a default-param smoke at 0.63-0.89; user pushed → optimizing StoK 5→13 + adding an ADX filter turned it into a real EURUSD both-window candidate PF 1.14-1.39, plateau + Model-4 + holdout. It was nearly killed for nothing).
- **The momentum>reversion prior raises the PASS BAR (demand PF ≥1.2 AFTER optimize), it does NOT license skipping the optimize.** A reversion idea still gets the full ladder: optimize its core params (oscillators are noisy at default — StoK 5 is not the answer) on its RIGHT HOME (ranging majors EURUSD/EURGBP/AUDNZD, NOT a trender where it fights the trend). Only an optimize-ceiling < 1.0 both-window on the right home kills it.
- **⚠️ Scope of a smoke-DEAD (user rule 2026-07-03, hardened 2026-07-16):** a smoke may kill only a STRUCTURAL concept (recovery-dependent / uncapped-ruin / cracked / no-source). It may NOT kill a signal that merely smokes ~1.0 — that is PARKED-pending-optimize, and the optimize must be on the RIGHT HOME. Proof both directions: EURJPY 0.83→2.49, EURCAD 0.65→1.82, USDJPY 1.00→1.51 (2026-07-03); SMC×STO EURUSD 0.70→1.24 BWD after opt+filter (2026-07-16). **Default-param verdicts = PARKED-pending-optimize, full stop.**

### Step 5 — Hand off **[C]**
- PROCEED/WATCH → **backtest-optimize-rigor** (Phase D optimize → Phase E forward → Phase F robustness).
- DEAD → record the death in [[signal-landscape]] so the concept isn't re-hunted, and move to the next idea.

---

## Mode 2 — Mechanism×symbol sweep (mold mode, added 2026-07-03)

The hunt axis isn't only "new entry signal" — it's also **existing mold mechanism × new symbol**
(grid/DCA/hedge/lot-progression on pairs it hasn't met). Zeus proof: the edge came from grid+LOG
mechanics on AUD pairs, not from a clever entry. Sequence (differs from the naked-smoke flow above):

1. **Vehicle = a Boss V2 mold entry** (`D:\EA_LAB\ea_template`, e.g. `Boss_14_GridLog`) — never a
   fresh standalone. New mechanism first = extend the mold (additive, default-OFF, must pass
   `scripts\tpl_regression.ps1` CLEAN).
2. **One full-window run per symbol** (2023→now, Model 1 — grid/basket EAs are NOT bar-open-pure,
   Model 2 misprices fills) at **reduced sizing** (~0.25×, e.g. `Boss14_GridLog_screen_small.set`)
   so the kill-DD cage can never halt-truncate the sample. Delegate the batch to qwen.
3. **Per-year split** every report (`scripts\report_year_split.py`) — aggregate PF hides losing
   years. Screen read: full PF ≥1.2 AND no year <1.0 = WATCH; anything else = pending-probe.
4. **Optimize probe before any kill** (54-pass ATR-relative complete set, reusable across symbols —
   e.g. `Boss14_GridLog_GBPAUD_opt1.set`). Cells with a plateau (several neighboring passes ≥1.2,
   n≥60) = CANDIDATE (in-sample); 0-pass cells = legitimately DEAD-optimized.
5. **Hand off candidates** to backtest-optimize-rigor (plateau-center → IS/OOS → MC) — optimizer
   numbers are in-sample claims, not results.

Known mechanism trait (not a bug): resting-stop entries latched once can go **dormant for years**
when price trends away from the armed level — long silent stretches in a report are the mechanism
waiting, not a data hole. Check History Quality before assuming either.

## Smoke gate vs optimize gate (don't confuse them)
| | Smoke (this skill) | Optimize (backtest-optimize-rigor) |
|---|---|---|
| Purpose | is there ANY naked edge? | lift a real edge to deployable |
| Window | IS-era 2023–2026, Model 2 | grid sweep + reserved OOS holdout |
| Params | default-ish, throwaway | swept 2–3 at a time, plateau-selected |
| Bar to proceed | PF ≥ ~1.2 in one cell | OOS PF ≥ 1.40 gate, MC stable |

## Delegation map
| Delegate to **qwen [Q]** | Keep in **Claude [C]** |
|---|---|
| Loop `mt5_run.ps1` across (symbol,TF) cells → CSV | Classify momentum vs reversion |
| Parse smoke reports → PF/trades/DD table | Pick instrument×TF |
| | Smoke verdict + tuning-gap vs dead-concept call |

## One-line reminders
- Momentum > reversion is the prior — make reversion ideas earn their build time.
- Smoke naked (recovery OFF); if edge needs recovery, it's a martingale.
- Right instrument or the smoke lies (momentum on a trender, not a ranger).
- PF ~1.0 reversion = dead concept; don't optimize it. PF 1.04 momentum-on-trender = maybe a tuning gap, optimize once.
- Record deaths in signal-landscape so concepts aren't re-hunted.

## FINAL RULE
```
NEXT STEP:
PROCEED/WATCH (coded EA) → forward to backtest-optimize-rigor (Phase D optimize).
PROCEED/WATCH (new mechanism, not yet coded) → forward to strategy-and-risk first.
DEAD → record the dead concept in the signal-landscape memory and move on.
```

> Routing between stages is owned by `docs/PIPELINE.md` — this skill owns its own stage mechanics only.
