# ORDER-095 batch 2 — NuiIndy RSI+ADX symbol-expansion — VERDICT: **EXPANSION REJECTED (structural martingale)**

**Date:** 2026-07-17 · **Judge:** Claude (Opus-seat) · **EA:** `(NuiIndy) Dynamic RSI+ADX Style (4)` · **Home:** EURUSD H1, magic 1524, LIVE ★★★ CORE (claimed PF 2.00)

## TL;DR
NuiIndy's live PF~2.0 is **not** an entry/harvesting edge — it is an **uncapped exponential
lot-martingale**. With the escalation neutralised the strategy loses money on its own home symbol.
Per user rule ("flat-lot check ว่า entry มี edge จริงก่อนขยาย — ห้ามขยาย martingale ที่ entry ไม่มี
edge") the symbol-expansion premise fails at the gate → **do not expand; no mold-mode candidate here.**

## What it actually is (source recovered — NOT locked)
The `.mq5` source sits in roaming Experts (`9CA16B…\MQL5\Experts`, fxDreema-generated, 16.6k lines) —
"locked" was false; full behavioural + code confirmation available.

- **Entry:** RSI(24) makes a new recent-low → BuyNow (mirror for sell), gated by ADX(14)>30 + DI
  direction = *pullback-continuation* (buy dip in an ADX-confirmed up-move).
- **Lot law (smoking gun, source lines 7710/7816/7959):** `lots = MathPow(Multiple_tier, order_count)`
  = **geometric martingale**. Tier by simultaneous-order count: Multiple1 (n≤4), Multiple2 (4–12),
  **Multiple3=1.2 (n>12)**. Multiple1=Multiple2=1.0 → tiers 1–2 flat, escalation lives entirely on the
  deep-drawdown tier: 1.2^12≈8.9x, 1.2^20≈38x, 1.2^30≈237x.
- **Risk envelope:** `MAX_Order=99999` (uncapped steps) · `CutLoss_Percent=100` (no real SL — cuts only
  at total-account loss) · grid spacing `Near_by_Pips=10` · lot base = equity/`Lot_Divided`(500000).

## Evidence — lever isolation on home EURUSD H1 (Model-4 real-tick)
| Config | Window | PF | Net | Trades | DD (eq) | Meaning |
|---|---|---|---|---|---|---|
| **Baseline** (Multiple3=1.2) | 2024–25 (1y) | **2.20** | +$2,689 | 836 | 16.6% | reproduces live PF~2.0 ✓ |
| **Flat-lot** (Multiple3=1.0, grid ON) | 2024–25 (1y) | **0.72** | −$932 | 695 | 19.5% | grid has NO harvesting edge |
| **Single-order** (MAX_Order=1, entry only) | 2023–26 (3y) | **0.90** | −$45 | 146 | 1.7% | entry has NO directional edge |

Single-order profile: 95.2% win-rate, largest win $27 vs largest loss −$288 = textbook negative-skew
(many tiny TP=10pip wins, rare large adverse ride). Classic "martingale wearing a signal costume"
(matches lab's FZ2 precedent: PF 3.05→0.36 on zeroed multiplier = REJECT).

## Verdict-gate #5 (martingale recheck) — as-shipped fails, but DD-kill rescues the LIVE risk
As shipped (CutLoss=100): SL **none** · capped steps **no** (99999) · entry edge **no** (0.72/0.90) ·
uncapped geometric **yes** → **uncapped-ruin as-shipped.** BUT a basket DD-kill converts it (see guardrail
sweep below): `CutLoss_Percent=30` bounds worst-case DD and stays profitable both-window → **not structural
death of the LIVE instance; it's a regime-dependent capped-martingale once a real stop is added.**

## Guardrail sweep (user asked to make the LIVE EA safe — 2026-07-17)
Key mechanism finding: **MAX_Order cap kills the profit engine** (deep-tier Multiple3^count recovery),
while a **basket DD-kill (CutLoss) is free tail-insurance** — it never fires inside the normal DD envelope.
Also: NuiIndy is **trend-aligned** (pullback-continuation: sells rallies in a downtrend), so 2022's EUR fall
was NOT a martingale nightmare — it traded *with* the trend. Real risk = sharp whipsaw reversal, not a
sustained trend.

| Config | 2022 stress | 2024–25 benign | note |
|---|---|---|---|
| As-shipped (uncapped, CutLoss 100) | not run (ruin exposure) | PF 2.20 / +$2,689 / DD16.6% | current live |
| cap12 + cut30 | PF 0.42 / −$2,915 / DD34% | PF 1.27 / +$365 / DD7.5% | ❌ MAX_Order cap guts profit |
| **cut30-only (uncapped orders + CutLoss=30)** | **PF 1.19 / +$1,081 / DD15.4%** | **PF 2.20 / +$2,689 / DD16.6%** | ✅ **RECOMMENDED** |

`cut30-only` on the benign year is **byte-identical to as-shipped** (DD peaked 16.6% < 30% → cut never
fired = zero profit cost), and stays profitable through the 2022 stress year with DD bounded to 15.4%.
The 30% level sits just above the normal ~16% DD envelope and below ruin → engages only on a genuine tail.
Caveat: neither test window pushed DD past 30%, so the cut's ruin-capping is *logically* sound but was not
empirically triggered here — it is a strict improvement (free in tested regimes, caps the untested tail).

**→ LIVE guardrail recommendation:** set `CutLoss_Percent=30`, keep `MAX_Order` uncapped. Set built:
`_mt5_auto/ab_sets/nuiindy_sets/NUI_cut30only.set`. Do NOT cap MAX_Order (proven to gut the edge).

## Decisions
1. **Symbol expansion (ORDER-095 batch 2 on NuiIndy) = REJECTED.** No proven entry edge to mold onto
   other symbols; expanding would multiply uncapped-ruin exposure across correlated pairs.
2. **EDGE_CATALOG correction:** NuiIndy entry is NOT a "filtered reversion edge" (prior hypothesis) —
   edge = escalation. Non-transferable. Reclassify.
3. **⚠️ LIVE-money guardrail (user chose "add guardrail" 2026-07-17) → DONE:** recommend
   `CutLoss_Percent=30` (keep MAX_Order uncapped) = free tail-insurance, both-window profitable, DD
   bounded ~15%. Converts the as-shipped uncapped-ruin exposure to a bounded capped-martingale at zero
   profit cost in tested regimes. Set: `NUI_cut30only.set`. User applies on the live terminal (magic 1524).
4. **Optional rescue (low priority, NOT this lane):** the RSI-dip-in-ADX-trend *idea* could be rebuilt
   as an original EA with a real SL + capped grid + entry-param sweep (RSI_Period/ADX_Value) — but
   single-order 0.90 says the raw entry is weak; treat as a cold lead, not a queued build.

## Artifacts
Sets: `_mt5_auto/ab_sets/nuiindy_sets/{NUI_baseline,NUI_flatlot,NUI_single}.set`
Reports: `_mt5_auto/reports/NUI_EURUSD_H1_{base_2425,flat_2425,single_2326}.htm`
Source (for reference, not committed): roaming `9CA16B…\MQL5\Experts\(NuiIndy) Dynamic RSI+ADX Style (4).mq5`
