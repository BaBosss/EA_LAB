# RECOVERED PLATFORM DESIGN — distilled from GPT chats (2026-06-14)

> Source: 3 large ChatGPT design chats recovered from the 290 MB export and
> distilled via subagents. Originals (full + distilled) live in
> `D:\Forex\50_KNOWLEDGE\IDEA_BANK\_chat_archive\gpt_export_20260612\`.
> Chats: **EA_Monitor** (scoring/monitoring), **EA_PLATFORM_MASTER** (architecture/
> workflow), **EA_BUILD_ACTIVE** (build/optimize/backtest + real results).
> This file is a REFERENCE recovery of prior decisions — verify any number
> against source reports before trusting it for a live decision.

---

## 1. Platform vision

An **EA Platform**, not one monster EA. Goal: *make building a new EA ~10× faster*
via **shared infrastructure + pluggable alpha**. A new EA differs only in its
**entry/signal**; risk, money-management, TP/SL, recovery, hedge, logging,
diagnostics are all reused.

| Layer | Role |
|---|---|
| EA_CORE_V1 | MQL5 framework: modular `.mqh` + `EA_TEMPLATE` (include owner) + `EA_Lifecycle` (zero-include coordinator). Non-live, fully tested. |
| Strategy modules | Pluggable alpha engines (HalfTrend MTF, SMC, Breakout, Mean Reversion, Pivot…). |
| Validation pipeline | Build → optimize → Single Test → OOS → candidate (the skill pipeline). |
| Portfolio layer | correlation / exposure / max-portfolio-DD / risk allocation (built once 3–5 candidates exist). |
| EA_LAB / idea bank | research/evidence workspace + strategy source. |

Init / authority order (top = highest):
`Logging → Diagnostics → ConfigValidator → RiskEngine → PositionTracker → StatePersistence → RuntimeMarketDataAdapter → StrategySignal → MarketFilter → EntryGate → ExitGate → TradeIntent → ExecutionValidator → ExecutionMock → ScenarioHarness → EA_Lifecycle → EA_TEMPLATE`
Authority chain: **RiskEngine > PositionTracker > StatePersistence**. RiskEngine is supreme — no module may clear/override a halt.

---

## 2. EA Template & modular concept (the "build EA 10× faster" engine)

- **EA_TEMPLATE owns include order**; build a new EA by **changing the signal only**.
- Hard rules: `__EA_TEMPLATE_INPUTS__` before all includes; `EA_Lifecycle.mqh` has **zero `#include`** (coordinator calls `Module_*` because symbols already visible).
- **Every optional module ships gated OFF** and the optimizer must ignore disabled modules:
  - `RiskAlwaysOn = true`, `DiagnosticsAlwaysOn = true`, `RecoveryDefaultOff = true`
  - feature gates: `RecoveryEnabled / HedgeEnabled / BasketEnabled = false` by default
  - Recovery is a dropdown enum: `NONE / LIGHT / ADAPTIVE / AGGRESSIVE` (default NONE)
- This is exactly the user's "every EA has recovery/MM/TP/SL/hedge built-in, just switch modes; only entry differs" idea — **already settled = YES, gated**.

---

## 3. Scoring system (origin: EA_Monitor — this is the canonical source of the scores)

### BacktestScore v1 (0–100) — hard gate first, then graded (PF≥1.20 ≠ full marks)
| Component | Wt | Rule |
|---|--:|---|
| Profit Factor | 25 | `15 + ((PF−1.20)/1.00)×10`, cap 0–25 · PF<1.20→0/REJECT · 1.40=18 · 1.60=20 · 1.80=22 · 2.00=24 · ≥2.20=25 |
| Max DD | 25 | `25×(25−MaxDD%)/24`, cap 0–25 · ≤1%=25 · 5%=21 · 10%=16 · 15%=10 · 20%=5 · ≥25%=0 |
| Recovery Factor | 20 | `12 + ((RF−1.5)/2.5)×8`, cap 0–20 · <1.0=0 · 1.5=12 · 2.0=15 · 3.0=18 · ≥4.0=20 |
| Trade Count | 10 | per-strategy minimum (see below) |
| Expected Payoff | 10 | <0=0 · small+=2–4 · moderate=5–7 · strong & not one-big-trade=8–10 |
| Monthly Stability | 10 | few months=0–3 · 40–50%=4–5 · 50–60%=6–7 · >60% & not concentrated=8–10 |

Bands: **80–100 Tier A · 65–79 Tier B · 50–64 Watch/Optimize · <50 Reject**.
Helpers: `RF = NetProfit / MaxDD$` · `Expectancy = NetProfit/Trades` · one-big-trade = `LargestWin/NetProfit`.

### DeployScore (composite, MULTIPLICATIVE)
`DeployScore = BacktestScore × RobustnessScore × RiskControl`
→ a pretty backtest with low robustness **collapses** (overfit can't be averaged away).
RobustnessScore has **no point formula** in source — it is the qualitative Robustness Gate (a later doc with a numeric RobustnessScore formula is an *addition*, not from this chat). RESOLVE the "3 competing score systems" by treating **EA_Monitor BacktestScore v1 as canonical**.

### PASS / WATCH / REJECT
| | PF | DD% | Recovery | Score |
|---|---|---|---|---|
| PASS | ≥1.20 | ≤20 | ≥1.50 | ≥65, no strong warning |
| WATCH | 1.05–1.19 | 20–30 | 1.00–1.49 | 50–64 / suspect params |
| REJECT | <1.05 | >30 | <1.00 | NetProfit≤0 / too few trades |

Trade-count minimums: Scalping 300+ · Intraday/Session 150+ · Trend Pullback 80+ · Breakout 80+ · Mean Reversion 150+ · Swing H4/D1 40+ · Grid/Basket = count cycles.

### Overfit / live-DD guidance
- OverfitRisk = LOW/MEDIUM/HIGH. Backtest PASS but OverfitRisk=HIGH → **forbidden for demo/live** (WATCH/REJECT).
- **Live-DD rule: expect backtest DD ×2–×3 live.** Backtest 20% → live worst-case 40–60%. Never deploy a system with backtest DD ~40%. Live emergency tolerance ≤ 50–60%.
- One-big-trade: largest win >30% NetProfit = warning; top-3 >50% = strong warning. Monthly: top-3 months >60% NetProfit = MONTHLY_CONCENTRATED.

---

## 4. Validation gate chain (5 gates) & final decision
Gate1 Backtest → Gate2 Robustness → Gate3 Stress (incl Monte Carlo) → Gate4 Forward/Demo (1–3 months, live-like) → Gate5 Portfolio (correlation, exposure, max-port-DD, risk allocation).
LiveEligibility = **BLOCKED / DEMO_ONLY / LIVE_READY**.

| BT | Robust | Stress | Forward | Portfolio | Final |
|---|---|---|---|---|---|
| PASS | PASS | PASS | PASS | PASS | LIVE_READY |
| PASS | PASS | PASS | NOT_STARTED | PASS | DEMO_READY |
| PASS | WARN | PASS | NOT_STARTED | WATCH | PORTFOLIO_TEST |
| PASS | FAIL | any | any | any | BLOCKED_OVERFIT |
| WATCH | PASS | PASS | any | any | OPTIMIZE_MORE |
| REJECT | any | any | any | any | REJECTED |

---

## 5. Optimization pass framework (origin: EA_BUILD_ACTIVE)

> **Pass IDs are batch-local** — the MT5 optimizer's pass number (e.g. 1568) ≠ the workflow Pass 0/1/2/4.

| Pass | Does | Optimizes | Move-on rule |
|---|---|---|---|
| 0 | Baseline verify | nothing | EA runs & produces trades before any opt |
| 1 | Coarse ("stability first") | core entry/exit only: `SwingPeriod, MinGapPts, RiskReward, TP_USD, SLBufferPts, CooldownBarsAfterStop` | PF>1.2, DD≤20–22%, RF>1.2, Trades>200, DepositLoad≤30%, MaxLot≤0.20 |
| 2 | Refine / adaptive risk | narrow zone around Pass-1 winners: `Cooldown 20–80, StopNewEntryDD 12–18, DailyLoss 3–6` | only after Pass 1 stable |
| 4 | OOS validation (no optimize) | nothing — exact frozen .set | PF>1.05–1.15, DD not exploding |

Risk caps stay **FIXED** during opt (the "cage"): `MaxLotAbsolute=0.20, MaxDepositLoadPercent=30, MaxRecoverySteps=3, RecoveryMultiplierMax=1.3, CloseAllWhenDDPercent=25`. Optimize INSIDE the cage, never widen it. **Never co-optimize lot + recovery multiplier + DD-stop together** (overfit + fake equity). Pass 3 (grid/hedge/martingale) deferred until 1–2 stable. Target a **robust plateau, not peak profit**.

---

## 6. Backtest / OOS procedure
| Setting | Value |
|---|---|
| Model | Every tick based on real ticks |
| Forward (OOS split) | 1/3 (66% IS / 33% OOS) |
| IS / OOS | IS 2025.01→2026.05; OOS-1 2024; OOS-2 2023; OOS-3 recent |
| Opt method | Genetic (search) → confirm winner with Single Test |

- **OOS = change DATE RANGE ONLY** — params/.set/risk/logic/symbol/TF frozen. Once a candidate exists, do **manual OOS Single Test** (not MT5 Forward).
- **Freeze the .set** for OOS; `STATUS = CANDIDATE_LOCKED`.
- Run script pattern: `run_backtest.ps1 -Project <name> -Symbol <S> -Timeframe <TF> -SetFile <path>` → `reports/latest/`, `handoff/`.
- **NetProfit=0 with thousands of signals = parser/no-fill bug, not a real result.**

---

## 7. Recovered VALIDATED EAs (concrete — verify before live)

| EA / Symbol | Run / .set | PF | DD% | RF | NetProfit | Trades | Status |
|---|---|--:|--:|--:|--:|--:|---|
| **Gold SMC Continuous / XAU** (IS) | run_004, opt pass 1568, `risk_cap_v1.set` | 1.31 | 12.4 | 3.22 | 7,497 | 479 | IS-validated, CANDIDATE_LOCKED |
| **Gold SMC Continuous / XAU** (OOS) | Run004 OOS | 1.11 | 17–19 | 1.34 | — | 596 | **OOS_VALIDATED** (conservative) |
| Pivot Range / NZDUSD (GoldenEmber) | rev0 pass71/202; pass845 untested | — | — | — | +2,852 (bal) | — | validated 2026-05-20; RUN_0004/0005 backtest pending |
| EX197 / GBPJPY | pass67 | — | — | — | — | — | conservative #2 (idea bank) |

→ **You now have ~3 validated EAs** (Gold SMC, Pivot NZDUSD, EX197 GBPJPY) — enough to start the portfolio/correlation layer for the first 1–2 ports. Candidate lifecycle: `IS_VALIDATED → OOS_PENDING → OOS_PASSED → FORWARD_PENDING → LIVE_MICRO → LIVE_APPROVED`.

---

## 8. Key rules / lessons (carry forward)
- No OOS = PRELIMINARY only — never live, never final robustness until OOS passes.
- Optimize for a **robust zone, not max profit**; keep risk caps as a fixed cage.
- **Don't live a single EA** — 1 port = 2–3 *uncorrelated* EAs (check correlation, DD overlap, session/regime overlap first). Target: 10 ports × 10,000 cent × 2–3 EA.
- Tiny-live (10,000 cent, 0.01–0.02 lot, VPS) measures spread/slippage/latency/execution — **not profit**.
- Governance: SPEC ONLY / PLAN ONLY until approved; timestamped releases are source of truth; non-timestamped snapshots are not.
- ExecutionEngine (real OrderSend/CTrade) = future, needs safety review + dry-run path first.
