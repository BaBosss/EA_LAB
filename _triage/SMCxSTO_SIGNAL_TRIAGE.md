# SMC × STO multi-TF scalping — signal triage (Claude, 2026-07-16, via signal-scanner)

Source: user-shared class system (FB/course lineage). Cataloged for build-when-lane-free, not run now.

## Rules (as given)
1. **M15 EMA100** = direction bias: price > EMA100 → buy-only · < EMA100 → sell-only.
2. **M5 Order Block / POI** = fresh (untouched) zone; MUST wait for price to re-enter the zone (no mid-air entry).
3. **M1 + Stochastic** = trigger: price at POI + STO crosses UP out of Oversold (buy) / DOWN out of Overbought (sell); cross must occur inside the M5 zone.
4. **Exit:** SL→breakeven when STO reaches 50 · close when STO hits the opposite extreme and crosses back.

## Step 1 — Classify: **momentum-GATED REVERSION** (core = reversion)
- M15 EMA100 gate = trend/momentum alignment (a filter, not the entry).
- The actual entry (STO cross from OS/OB at an order block) = **reversion** — buy the oversold bounce into a demand zone. "Pullback-in-trend to a zone."
- **Same family as NuiIndy RSI+ADX (the ONE reversion survivor that went live)** and the MacdDiv concept. NOT a new class.
- **Standing prior = momentum > reversion** (confirmed 6+ builds). Reversion is guilty until proven → demand PF ≥1.2 naked, not ~1.0. Thesis table: pullback-in-trend regression = 0.81 DEAD on XAU, RSI/BB-MR ~1.0 DEAD. This idea inherits that headwind.

## Step 2 — Instrument × TF: scalping = SPREAD-EXPOSED (the #1 risk here)
- M1/M5/M15 scalp with a STO-reverse exit = short holding time = **spread/cost is a large fraction of target**.
- The lab has repeatedly killed scalpers on spread-stress (Yetti3, Automated-Forex-Grail, Scalper_S3 — all spread-death).
- Home candidates: **tight-spread majors first (EURUSD, GBPUSD)** — NOT XAU M1 (gold spread will likely eat a M1 scalp). Test XAU only at M5+ if the core survives.

## Step 3 — Cheap-smoke plan (2-stage; strip the expensive SMC part FIRST)
**Doctrine: cheap death before expensive life.** The OB-zone detector + 3-TF sync is the costly build. Don't build it until the skeleton shows a pulse.

- **Stage 0 (cheapest kill test — no SMC/OB):** build a naked probe = *higher-TF EMA100 gate + same-TF Stochastic cross from extreme → 1 flat-lot order, ATR SL, exit on STO-reverse (+BE at STO50)*. Collapse 3-TF → **M15 chart with M5/M15 STO** (skip M1 to dodge the worst fill/spread noise for triage). Smoke EURUSD + GBPUSD + XAU, 2023-2026, **Model 1** (STO cross + BE-move are not bar-open-pure). Levers default: STO(5,3,3) OS/OB 20/80, EMA100, SL 1.5–2.0×ATR.
  - **Kill rule:** if the EMA-gated STO-reversion core is PF <1.0 across all 3 majors → the OB zone won't save it (a zone only *locates* the same reversion entry) → **DEAD concept, stop, record in signal-landscape.**
  - **Pulse rule:** any cell PF ≥1.1 naked → go Stage 1.
- **Stage 1 (only if Stage 0 pulses):** add the M5 Order-Block gate (fresh/untouched zone = last opposite candle before a displacement that breaks structure; state-track "untouched" via a ring buffer like the FVG detector in ORDER-098-A). Re-smoke same cells. The OB gate should *raise win% / PF* by filtering entries to zones. If OB adds nothing → the zone is decoration, keep the cheaper skeleton or park.
- If Stage 1 clears PF ≥1.2 → hand to `backtest-optimize-rigor` (optimize STO periods × OS/OB levels × SL × EMA period, both-regime, holdout+MC).

## Verdict (pre-smoke, doctrine-based): 🟨 PARKED-CONCEPT — worth a cheap 2-stage smoke, NOT a build campaign on hope
**Against:** reversion core (against prior) + M1 scalp spread-exposure = double headwind; pullback-in-trend already 0.81-dead on XAU.
**For:** (a) NuiIndy proves momentum-gated-reversion *can* live → the class isn't universally dead; (b) **SMC Order-Block entry is genuinely untested in the lab** (FVG was tested/rejected in 098-A but OB ≠ FVG); flagged as present-but-untested in ORDER-079 corpus; (c) the exit is fully mechanical (BE at STO50, close on STO-reverse) = clean and testable, no discretion.
**Decision:** catalog + queue the Stage-0 cheap smoke for a free lane. Est ~1-2 h machine for Stage 0 (build a small standalone probe + 6-12 cells). Do NOT build the full 3-TF SMC machine before Stage 0 says go.

## Hard parts to flag before any build
1. **Spread on the scalp TF** — smoke on Model 1 first, but any PROCEED must survive Model-4 real-tick + a spread-stress arithmetic pass (scalp targets are small).
2. **OB detection is subjective** — pick ONE mechanical definition (last opposite candle before displacement breaking structure) and lock it; don't chase SMC purism.
3. **"Fresh/untouched" = state tracking** — reuse the ORDER-098-A ring-buffer pattern (zone list + touched-flag + age-out).
4. **3-TF repaint discipline** — closed-bar only on each TF; STO on M1 repaints intrabar.
5. **STO-reverse exit with no fixed TP** = variable R:R — the BE-at-50 rule caps downside but the edge rides on the STO-reverse timing; test exit-mode as a lever (STO-reverse vs fixed ATR TP).

Cross-ref: [[signal-landscape]] (pullback 0.81, RSI-MR ~1.0 dead; NuiIndy reversion survivor) · [[portfolio-edge-thesis]] · EDGE_CATALOG MACD-gate-S/D concept (sibling untested reversion-at-zone idea).
