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
- **Cheap diagnosis before expensive optimization.** Use Model 1 / 1 Minute OHLC for any numerical edge judgement. A clearly poor home can `STOP_EXPANSION / PARK` without an optimizer; do not rescue a negative base merely because optimization is available.
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
- Smoke window follows the preregistered experiment; any PF/net/DD/trade judgement uses **Model 1 / 1 Minute OHLC (`M1_M1_OHLC_RESEARCH`)** at minimum. Model 2/Open Prices is skipped unless a specific engineering diagnosis is required, and its performance numbers carry no research authority.
- Capture per cell: PF, trade count, DD, win%. Delegate the runs to qwen (`mt5_run.ps1` loop → CSV).

### Step 4 — Smoke verdict **[C judgment]**
```
PROCEED : the Model-1 base/home supplies enough preregistered evidence for the next mechanism/portability question; optimization is allowed only after it becomes a qualified survivor.
WATCH   : evidence is mixed/uncertain; define a new direct-consumer mechanism or portability question before spending optimization compute.
PARK    : the Model-1 base/home is clearly poor or no direct-consumer hypothesis survives -> STOP_EXPANSION. Do not optimize merely to rescue the home.
DEAD    : reserved for a genuinely STRUCTURAL concept failure supported by mechanism evidence (for example cracked/no-source or recovery-only framing), never just one weak default home.
```
- Historical rescues from weak defaults remain evidence against declaring a whole concept dead from one cell; they are **not** an obligation to optimize every weak home.
- Momentum/reversion priors may guide which prospective home to test, but they do not override Model-1 evidence or create optimizer authority.
- A default/base result may PARK a home without killing the mechanism family. Optimization requires a separately qualified survivor and a preregistered direct consumer.

### Step 5 — Hand off **[C]**
- PROCEED → **backtest-optimize-rigor** / mechanism-portability work under a new preregistered direct consumer; optimization is not automatic.
- WATCH/PARK → preserve the evidence and stop until a new direct-consumer hypothesis exists. Structural DEAD only → record the mechanism-level death in [[signal-landscape]].

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
3. **Per-year split** every report (`scripts
eport_year_split.py`) — aggregate PF hides losing years. Preserve the distribution; do not manufacture a filter from the bad years.
4. **Only a qualified survivor may enter optimization.** A weak Model-1 base/home is `STOP_EXPANSION / PARK`, not an optimizer rescue target. If a survivor has a preregistered optimization question, map a stable region on Model-1 MAIN and freeze a center; optimizer rows are in-sample research evidence, never Candidate status.
5. **Hand off a frozen finalist** to backtest-optimize-rigor for fixed BWD → mandatory Model-4 MAIN+BWD → only direct-question final robustness → late HOLDOUT → Candidate decision.

Known mechanism trait (not a bug): resting-stop entries latched once can go **dormant for years**
when price trends away from the armed level — long silent stretches in a report are the mechanism
waiting, not a data hole. Check History Quality before assuming either.

## Smoke gate vs optimize gate (don't confuse them)
| | Smoke (this skill) | Optimize (backtest-optimize-rigor) |
|---|---|---|
| Purpose | is there ANY naked edge? | lift a real edge to deployable |
| Window | preregistered Model-1 research window(s) | qualified-survivor Model-1 MAIN search + frozen BWD; M4 mandatory before Candidate |
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
- Poor Model-1 base/home = STOP/PARK that home unless a new independent direct-consumer hypothesis exists; do not auto-optimize to rescue it, and do not over-generalize it into concept death.
- Record deaths in signal-landscape so concepts aren't re-hunted.

## FINAL RULE
```
NEXT STEP:
PROCEED/WATCH (coded EA) → forward to backtest-optimize-rigor (Phase D optimize).
PROCEED/WATCH (new mechanism, not yet coded) → forward to strategy-and-risk first.
DEAD → record the dead concept in the signal-landscape memory and move on.
```

> Routing between stages is owned by `docs/PIPELINE.md` — this skill owns its own stage mechanics only.
