# Shortlist briefs — momentum (13) + breakout (7) treasure sources

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **factual extraction ของ 20 source ที่ยังไม่เคย
> screen เท่านั้น** (จาก `_triage/ea_src_triage.csv`, strategy_type ∈ {momentum, breakout}) — ห้ามให้
> คะแนน/จัดอันดับที่นี่ (ORDER-021 rule). Base dir ของทุก path: `D:\Forex\10_EA_PROJECTS\2. wait for test\`
> การตัดสิน CANDIDATE/DEAD เป็นงาน Claude ตอน screen จริงเท่านั้น ไม่ใช่ที่นี่

---

## MOMENTUM (13)

### (OH) EA\(Oh) CCI Currencies Strength ATR  Ranking Nearby  V09.mq5
- Entry: multi-symbol CCI (CCI_Indicators=1000.0) currency-strength ranking across 8 pairs (USD/EUR/GBP/JPY/CAD/AUD/NZD/CHF), H1, ATR_H1_Period=14, ATR nearby buffer 5.0 pips
- Exit/SL/TP: equity-based close — EQ_percent=5% (all symbols), 0.3%/0.5% per-symbol profit close
- Sizing: LOT_Divided=100000 (money-per-lot), max 50 trades/symbol
- Novelty vs Boss V2: multi-symbol basket + currency-strength ranking filter — not in any of the 4 axes (GridTrendMA/Breakout/MeanReversion/GridLog are all single-symbol)
- Warning: none found

### (OH) EA\(oh)  Bot V00.mq5
- Entry: EMA(12) vs EMA(26) cross, ATR(14)×2.0 entry-distance filter, volume-candle confirmation (2/3-bar)
- Exit/SL/TP: money-based trail (start 1%, step 0.1%, stop 0.5% of equity)
- Sizing: Lot_Divided=3000 (fixed money/lot), grid-step structure
- Novelty vs Boss V2: MA-cross overlaps GridTrendMA axis; the ATR-distance + volume-candle confirmation gate is the one new piece
- Warning: none found

### 2024-10\MoonKinght MASA.mq4
- Entry: DPI multi-EMA/SAR ribbon (8/13/5/13/34/89), fractal-confirmed SAR, 3-vote confirm system (ConfirmWithDPI/3rdEMA/4thEMA)
- Exit/SL/TP: dynamic SL 10 / TP 20 pips (fractal-bounded 7–15), break-even at 70%, trailing off by default
- Sizing: fixed 0.1 lot OR risk% (2%) with SL-based calc
- Novelty vs Boss V2: multi-EMA/SAR ribbon voting is not any of the 4 axes — genuinely different signal structure
- Warning: **obfuscated variable names (gi_272 etc.), commented-out wininet.dll auth code** — decompiled origin, treat source as unverifiable until behavior tested independently

### EA fxdreema other id\(Niyombot) B2 Gold Deng M15 TLM.mq5
- Entry: MA(102) vs MA(140) cross, ATR(43)×2.0, volume-candle filter (same shape as "Bot V00")
- Exit/SL/TP: money-based trail (start 15%, step 5%, stop 10%)
- Sizing: Lot_Divided=3000, grid accumulation
- Novelty vs Boss V2: nothing new — same mechanism as "(oh) Bot V00" above, different default periods only
- Warning: none found

### EA fxdreema other id\min CCI 2Currencies Strength Carry Trade Trailing .mq5
- Entry: CCI(100) two-currency strength ranking (strong=8..weak=1 across 8 currencies), carry-trade hedge filter (Hedge_Multiplier=2.0)
- Exit/SL/TP: trailing start 1500 pips, cutloss 12% equity, hedge-scale at 1200, profit close 20%
- Sizing: base 0.01 lot, hedge multiplier 2.0, grid step 2.0/1.0/0.8
- Novelty vs Boss V2: multi-currency carry-trade selector + swap-awareness — not in the 4 axes
- Warning: none found

### 2024-06\New folder\ycp zigzag vs ema  v04.mq5
- Entry: ZigZag swing detector vs EMA comparison/direction trigger
- Exit/SL/TP: fixed SL 600 pips, grid-step close thresholds (start 150/step 2.0/stop 100)
- Sizing: fixed 0.01 lot base, grid progression
- Novelty vs Boss V2: ZigZag-vs-EMA comparator — ZigZag isn't used by any current Boss V2 entry (11/12/13/14 use MA/Donchian/BB/ATR-grid only)
- Warning: none found

### 2025-11\EMA 26,50 MACD\EMA 26,50 MACD\TEMPO_EMA_MACD_Dashboard V.4.mq5
- Entry: EMA(26)/EMA(50) cross + MACD(12,26,9) sign confirm + ADX(14)>25 trend-strength filter + DI confirm
- Exit/SL/TP: fixed SL/TP in points (50000/100000 — likely 5-digit broker, ≈50/100 pips)
- Sizing: step-lot progression (start 0.01, +0.01/step every $100 balance)
- Novelty vs Boss V2: MA-cross overlaps GridTrendMA; the ADX+DI trend-strength gate stacked on MACD confirm is the new piece (Boss V2 has no ADX filter module yet)
- Warning: none found

### Dashboard\MQL4\MQL4\Experts\MACD Sample.mq4
- Entry: stock MetaQuotes MACD sample — histogram cross + OpenLevel=3 threshold, MA(26) trend filter
- Exit/SL/TP: fixed TP 50 pips, trailing 30 pips, CloseLevel=2
- Sizing: fixed 0.1 lot
- Novelty vs Boss V2: **nothing new** — this is the stock MT4 sample EA
- Warning: none found

### Dashboard\MQL4\MQL4\Experts\Moving Average.mq4
- Entry: stock MetaQuotes MA-cross sample (period 12, shift 6)
- Exit/SL/TP: close-on-reverse-signal
- Sizing: risk% (MaximumRisk=2%) with DecreaseFactor=3 on consecutive loss, fallback fixed 0.1 lot
- Novelty vs Boss V2: **nothing new** — stock MT4 sample EA, direct match to GridTrendMA concept
- Warning: none found

### Dashboard\MQL4\MQL4\Experts\XIMA_DASH.mq4
- Entry: MA-cross across many symbols via dashboard
- Exit/SL/TP: two-tier basket — small lot (0.05, SL/TP=0) + big lot (0.10, SL/TP=20 pips), per-symbol + basket target
- Sizing: fixed dual-lot (0.05 + 0.10)
- Novelty vs Boss V2: two-tier/dual-lot basket-per-symbol structure — not in current 4 axes (closest is GridLog but that's single-symbol progression, not dual fixed tiers)
- Warning: none found

### Dashboard\MQL4\MQL4\Indicators\T101 Basket Trader v2.2.mq4
- Entry: multi-pair basket (up to 14 pairs), rank-based or "market read"/"trade logic engine" mode, hedge capable
- Exit/SL/TP: basket-level TP, per-pair MinLoss4Hedge trigger, break-even trailing
- Sizing: 0.01 lot base, basket-coordinated, hedge magic numbers
- Novelty vs Boss V2: multi-pair basket + hedge-on-loss coordination across 14 symbols — not in current axes
- Warning: 2012-era EA, heavy global-variable state — likely needs rewrite rather than direct port if pursued

### wait for test\2- OK\...\UniversalMACrossEA.mq4
- Entry: EMA(10) vs EMA(80) cross, confirmed next-bar, optional reverse-signal mode
- Exit/SL/TP: fixed SL 100 / TP 200 pips, trailing 40 pips, stop-and-reverse option
- Sizing: fixed 1 lot OR risk% (10%) with micro-account toggle
- Novelty vs Boss V2: **nothing new** — textbook MA-cross template, identical to GridTrendMA concept
- Warning: none found

### wait for test\2- OK\...\UniversalMACrossEA_Martingale.mq4
- Entry: same EMA(10)/EMA(80) cross as above
- Exit/SL/TP: fixed SL 100 / TP 200 pips, trailing 40 pips
- Sizing: fixed 0.1 base lot, optional martingale ON/OFF, multiplier 2.0
- Novelty vs Boss V2: **nothing new** — same MA-cross as above with a bolt-on martingale toggle; GridLog axis already covers ATR-grid+martingale more thoroughly
- Warning: none found

---

## BREAKOUT (7)

### (OH) EA\(OH) Price Action - Trend Line -Fibo -Martingale  V20.mq5
- Entry: candle PA patterns (Doji/Engulfing/Star/Tower) at trend-line S/R, ZigZag depth=6, Fib entry levels
- Exit/SL/TP: Close_All_Percent=1% equity profit, Cut_Loss_Percent=100% cutloss
- Sizing: Lot_balance=3,000,000 money/lot calc, martingale multiple 1.2× per grid level
- Novelty vs Boss V2: PA candle-pattern gate (Doji/Engulfing/Star/Tower) + trend-line + Fib stack — not in current 4 axes (MeanReversion uses BB/RSI only, no candle-pattern recognition)
- Warning: none found

### 2026-07\Breakout Retest Pro EA Source Code (1).mq5
- Entry: swing high/low impulse break (10-bar lookback) + ATR(1.5×) impulse filter + retest zone (0.5× ATR) + 2-bar break confirm + EMA trend filter
- Exit/SL/TP: SL 1.5×ATR, TP 4.0×ATR, plus reversal-exit module (engulf/3-bar/EMA-flip/consecutive-ATR-move)
- Sizing: not fully specified in excerpt (risk% or fixed lot)
- Novelty vs Boss V2: the **retest-zone + explicit reversal-exit state machine** is the new piece — Boss V2's Entry_Breakout (12) is plain Donchian without a retest wait-state or multi-condition reversal exit
- Warning: none found

### EA fxdreema other id\(Niyombot B_3) Price Action ATR  Lot.D Group 3.mq5
- Entry: candle PA patterns (Doji/Engulfing/Star/Tower) with explicit wick/body ratio thresholds (Engulfing_Ratio=3, Star_Ratio=4), ATR(43)×2.0
- Exit/SL/TP: 3-tier money TP (10/5/1), ATR-scaled SL
- Sizing: Lot_Divided=100000
- Novelty vs Boss V2: same PA-pattern family as the V20 file above but with tighter numeric pattern gates + tiered money-TP — not in current axes
- Warning: none found

### EA fxdreema other id\EX170 - Zone Trading Strategy.mq5
- Entry: **manual user-drawn zone lines** (LineBuy/LineSell chart objects) — price break from a manually placed zone, not indicator-derived
- Exit/SL/TP: fixed SL 20 / TP 40 pips, break-even at 20 pips (+5 offset)
- Sizing: base 0.02 lot, ×2.0 pyramid multiplier on loss (trigger at -15)
- Novelty vs Boss V2: manual/discretionary zone entry — fundamentally not systematic (no indicator drives entry), so not portable as an automatable module without redefinition
- Warning: not automatable as-is (depends on manually drawn chart objects) — flag before considering a build

### 2025-08\Dark_Gold_Full\Dark_Gold_Full.mq5
- Entry: support/resistance levels (50-period auto-detect OR manual S/R input), multi-level pyramid (Level1-3), trend-mode enum
- Exit/SL/TP: max-spread filter (80 pts), max orders 10/10 buy-sell — no explicit SL/TP visible in excerpt
- Sizing: fixed 0.10 lot OR risk% (1%)
- Novelty vs Boss V2: auto-detected S/R + multi-level pyramid entries — closest existing axis is GridLog but this is S/R-anchored, not ATR-step-anchored
- Warning: SL/TP mechanism unclear from excerpt read — needs fuller read before any build decision

### wait for test\25 sep\AcceleratorBot_USDJPYH4.mq4
- Entry: ADX(14) trend-strength filter, threshold ~20, momentum-confirmed entry
- Exit/SL/TP: fixed SL 750 pips, **TP 9999 pips (placeholder-looking)**, trailing off by default
- Sizing: fixed 0.01 lot or risk% (2%) if AutoLots
- Novelty vs Boss V2: ADX-only trend-strength gate as primary filter — no ADX module currently in Boss V2
- Warning: **TP=9999 looks like an unfinished/demo placeholder, not a real exit rule** — treat entry logic as incompletely captured, re-read full source before using

### wait for test\test 3\XPERT2.mq4
- Entry: custom candle-pattern detection combined with **external file read via kernel32.dll (ReadFile/CreateFileW)**, time-window schedule, complex state machine
- Exit/SL/TP: fixed SL 500 / TP 50 points, max floating profit/loss caps (±5000), time-based close
- Sizing: fixed 0.05 lot or risk% (40% — unusually high, likely a legacy/demo default)
- Novelty vs Boss V2: file-driven external-signal architecture — not portable as a self-contained module (depends on an external data file this lab doesn't have)
- Warning: **direct kernel32.dll file I/O + obfuscated entry logic** — do not run this .mq4 unreviewed; if pursued, needs full manual read of what file it expects, not just port the visible logic
