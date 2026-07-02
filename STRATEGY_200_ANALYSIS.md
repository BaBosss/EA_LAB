# 200 EA Prompt — วิเคราะห์ทีละตัว
ที่มา: `strategy_idea_bank/200 AI Prompt สำหรับสร้าง EA MQL4,MQL5.pdf` (207 หน้า) · วิเคราะห์ 2026-06-27

> **คะแนนเป็น "prior ระดับ concept" อิงหลักฐานที่พอร์ตพิสูจน์แล้ว — ยังไม่ใช่ผล backtest.**
> ทุกตัวต้อง generate code → `/signal-scan` smoke ก่อน ถึงจะรู้จริง. คะแนนนี้ไว้ "จัดลำดับว่าควรลองตัวไหนก่อน"

## Rubric (อิงสิ่งที่ lab พิสูจน์มาแล้ว)
- **8-9** = trend-follow/breakout/momentum สะอาด + ride trend บน **trender** (XAU/GBP/JPY/index) — ตรง edge ที่ proven
- **6-7** = breakout/trend มี filter ดี หรือ session-based / cross-asset diversifier (novel)
- **5** = statistical reversion (z-score/VWAP band) — novel ยังไม่เคยลอง / pattern ที่ code ได้แน่น
- **3-4** = indicator-cross เปล่า (EMA/MACD/RSI cross) → **เพดาน ~1.1 พิสูจน์แล้วว่าตาย** / oscillator reversion
- **2** = candlestick/harmonic/Elliott pattern เดี่ยว (code robust ยาก, สัญญาณ subjective)
- **1-3 + ⛔** = martingale/grid/hedge/recovery เป็นแกน (โครงสร้าง ruin, lab 0/63)
- **T (technique)** = ไม่ใช่ signal เดี่ยว = module บริหารเงิน/ความเสี่ยง → เอาไป graft ใส่ EA อื่น ไม่ใช่สร้างเดี่ยว

**ตัวย่อ MG/H/R:** MG=martingale, H=hedge, R=recovery/grid. "❌" = ไม่มี (ดี). "opt" = เป็น option ปิดไว้ default. "CORE" = เป็นแกนกลยุทธ์ (อันตราย)

---

## EA 1–50

| # | ชื่อ | ประเภท | /10 | symbol เหมาะ | MG/H/R | ตลาดที่เหมาะ | หมายเหตุ / แนะนำ |
|---|---|---|---|---|---|---|---|
| 1 | EMA 20/50 Cross | trend (MA cross) | 3 | trender | ❌ (cutloss) | trending | MA-cross เปล่า = เพดาน ~1.1 (พิสูจน์แล้ว). ข้าม เว้นแต่เป็น baseline |
| 2 | RSI14 + Trailing 30pip | reversal (osc) | 3 | EUR/GBP | opt MG x1.5 ⚠️ | range | RSI revert + มี option martingale. naked RSI ตาย. ข้าม |
| 3 | MACD (0-line cross) | trend (MACD) | 3 | trender | ❌ | trending | = MACD cross ที่ lab พิสูจน์ตายทุก symbol ยกเว้น GBPUSD. ข้าม |
| 4 | Bollinger Bands bounce | reversal (range) | 3 | EUR/range | opt grid ⚠️ | sideway | BB+RSI revert = เพดาน ~1.0 พิสูจน์แล้ว. ข้าม |
| 5 | EMA100 filter + Stochastic | trend+osc pullback | 4 | XAU/GBPJPY | opt grid | trending | EMA trend gate + stoch entry — ดีกว่า cross เปล่านิด แต่ stoch=osc. ลองได้ถ้าว่าง |
| 6 | RSI Divergence (H1→M15) | reversal (divergence) | 4 | EUR/GBP | opt grid≤2 | range/reversal | MTF divergence มี structure confirm — สะอาดกว่า RSI เปล่า แต่ divergence code ยาก |
| 7 | **BB Squeeze Breakout** | **breakout (vol)** | **6** | **XAU/GBP** | opt off | low-vol→expansion | vol-contraction→breakout + ADX gate = ตรง thesis. **น่าลอง** (คล้าย NR7) |
| 8 | MACD Histo Divergence + EMA50 | trend+divergence | 4 | trender | opt grid | trending | divergence + trend filter. code ยาก, prior กลาง |
| 9 | Breakout prev-day H/L | **breakout (session)** | **6** | **GBP/XAU** | ❌ | trending/London | daily breakout + stop orders = ตรง thesis, ทำง่าย. **น่าลอง** |
| 10 | Pin Bar + EMA50 | candlestick reversal | 2 | — | ❌ | reversal | pin-bar เดี่ยว = subjective, ตาย. ข้าม |
| 11 | Engulfing entry | candlestick | 2 | — | ❌ | reversal | pattern เดี่ยว. ข้าม |
| 12 | Fibonacci | retracement | 2 | — | ❌ | trending | fib เดี่ยว = subjective. ข้าม |
| 13 | S/R Breakout | breakout | 5 | trender | opt | trending | S/R auto-detect ดี แต่ S/R นิยามยาก. กลาง |
| 14 | Double top/bottom | pattern reversal | 2 | — | ❌ | reversal | pattern เดี่ยว, code robust ยาก. ข้าม |
| 15 | Trendline Breakout | breakout | 3 | trender | ❌ | trending | trendline auto = subjective. low |
| 16 | Grid trading | grid | 1 ⛔ | — | R CORE | sideway | grid แกน = lab 0/63. ข้าม |
| 17 | Martingale | martingale | 1 ⛔ | — | MG CORE | — | DQ โครงสร้าง. ข้าม |
| 18 | Equity-Based Hedging | hedge | 2 ⛔ | — | H CORE | — | hedge แกน. ข้าม |
| 19 | ATR Dynamic Trailing | **T (exit)** | T | ทุกตัว | ❌ | — | **technique ดี** — graft เป็น exit ใส่ breakout. ไม่ใช่ EA เดี่ยว |
| 20 | **Trend-Following + Pyramiding** | **trend+pyramid** | **8** | **XAU/GBP** | ❌ (pyramid=กำไร) | strong trend | pyramid บนเทรนด์ = DNA ที่ validate (ST03). **อันดับต้นๆ** |
| 21 | EMA cross H1 | trend (MA) | 3 | trender | ❌ | trending | = #1 ซ้ำ. ข้าม |
| 22 | RSI14 D1 confirm + H4 | MTF trend+osc | 4 | trender | opt | trending | MTF RSI — กลาง |
| 23 | Pair Trading/Stat-Arb | stat-arb | 5 | EUR/GBP pair | H (by design) | range/mean-rev | stat-arb = edge คนละแบบ (uncorrelated) แต่ implement ยาก + เป็น hedge โดยธรรมชาติ |
| 24 | Trend-follow + pullback | trend pullback | 6 | XAU/GBP | opt | trending | เข้า pullback ในเทรนด์ = ดี ถ้า trend filter แน่น. น่าลอง |
| 25 | Basket trading | basket | 3 | majors | opt grid | — | basket equity TP — บริหารหลายไม้, ไม่ใช่ edge ใหม่ |
| 26 | MACD+RSI+EMA filter | multi-filter trend | 4 | trender | opt | trending | filter ซ้อน 3 ตัว — lab พบ filter ไม่ยก edge (v3). low-mid |
| 27 | BB breakout + Stoch confirm | breakout+osc | 5 | XAU/GBP | opt | trending | BB breakout (ดี) แต่ stoch confirm ตัด momentum. กลาง |
| 28 | EMA50 cross + Fib entry | trend+fib | 3 | trender | ❌ | trending | fib เข้า = subjective. low |
| 29 | RSI OB/OS + MACD div | reversal combo | 3 | EUR | opt | range | osc reversal combo. low |
| 30 | **Breakout prev H/L + ATR trail + partial** | **breakout** | **7** | **XAU/GBP** | ❌ | trending | breakout + ATR trail + partial close = โครงดี ครบ. **น่าลอง** |
| 31 | WMA 20/60 + RSI filter | trend (MA) | 3 | trender | ❌ | trending | MA cross variant. low |
| 32 | Ichimoku Kinko Hyo | trend (ichimoku) | 5 | XAU/GBPJPY | opt | trending | ichimoku = trend system ครบ; kumo breakout น่าสน (ดู #66). mid |
| 33 | ADX>25 + EMA50 cross | **trend+ADX gate** | **6** | **XAU/GBP** | opt | strong trend | ADX gate = กรอง trend แรงจริง (ตรง concept ที่ผมแนะนำ). **น่าลอง** |
| 34 | PSAR + MACD confirm | trend | 4 | trender | opt | trending | PSAR trend; PSAR trail น่าเอาไป graft (#19-like). mid-low |
| 35 | enter-on-threshold | generic | 2 | — | — | — | กว้างเกิน ไม่ใช่กลยุทธ์ชัด. ข้าม |
| 36 | Momentum(14) cross 100 | momentum | 4 | trender | opt | trending | momentum osc cross — mid-low |
| 37 | OBV Divergence + EMA100 | volume divergence | 4 | trender | opt | trending | OBV volume — FX volume ปลอม (tick vol). ระวัง. mid-low |
| 38 | **ATR breakout system** | **breakout (vol)** | **7** | **XAU/GBP** | opt | trending | ATR-based breakout = ตรง EA_BREAKOUT_XAU ที่ proven. **น่าลอง** |
| 39 | Inside Bar breakout | breakout (pattern) | 5 | XAU/GBP | ❌ | trending/expansion | IB breakout + mother-bar SL = NR-family. mid, ลองได้ |
| 40 | Morning/Evening Star | candlestick | 2 | — | ❌ | reversal | pattern เดี่ยว. ข้าม |
| 41 | Hammer/Shooting Star | candlestick | 2 | — | ❌ | reversal | pattern เดี่ยว. ข้าม |
| 42 | Triple top/bottom | pattern | 2 | — | ❌ | reversal | pattern เดี่ยว. ข้าม |
| 43 | **Rectangle Consolidation Breakout** | **breakout (range)** | **6** | **XAU/GBP** | opt | range→breakout | กรอบ sideway → breakout = ตรง thesis. น่าลอง |
| 44 | Wedge breakout | breakout (pattern) | 4 | trender | ❌ | trending | wedge auto = subjective. mid-low |
| 45 | Elliott Wave | pattern (wave) | 1 | — | ❌ | — | Elliott = subjective สุด, code robust ไม่ได้. ข้าม |
| 46 | Grid hedge system | grid+hedge | 1 ⛔ | — | R+H CORE | — | DQ. ข้าม |
| 47 | Anti-Martingale | sizing (pyramid) | T | trender | (pyramid) | trending | anti-MG = เพิ่มไม้ตอนกำไร = pyramid. technique ดี graft เข้า trend EA |
| 48 | Percent Risk 2% | T (sizing) | T | ทุกตัว | ❌ | — | money-mgmt module. graft. ไม่ใช่ EA |
| 49 | Time-based partial close | T (exit) | T | ทุกตัว | ❌ | — | exit module. graft |
| 50 | Equity Protection | T (risk) | T | ทุกตัว | ❌ | — | equity guard module. graft (= kill-switch) |

## EA 51–100

| # | ชื่อ | ประเภท | /10 | symbol เหมาะ | MG/H/R | ตลาดที่เหมาะ | หมายเหตุ / แนะนำ |
|---|---|---|---|---|---|---|---|
| 51 | Daily EMA 200 | trend filter | 3 | trender | ❌ | trending | filter เดี่ยว ไม่ใช่ระบบครบ. low (ใช้เป็น bias) |
| 52 | H4 RSI confirm + M5 scalp BB | scalp | 3 | EUR | opt | range | M5 scalp + spread = ยาก. low |
| 53 | **EUR↔XAU inverse correlation** | **cross-asset** | **6** | EUR+XAU | (pair) | divergent | edge เชิงโครงสร้าง uncorrelated. novel diversifier. implement ปานกลาง |
| 54 | leading indicator | vague | 2 | — | — | — | กว้างเกิน. ข้าม |
| 55 | Multi-TF Fibonacci | retracement | 3 | trender | ❌ | trending | fib MTF — subjective. low |
| 56 | MACD cross + BB bounce + trail | trend+revert mix | 4 | EUR/GBP | opt | mixed | ผสม momentum+reversion งงทิศ. mid-low |
| 57 | RSI oversold + PSAR reversal | reversal | 3 | EUR | opt | range | osc reversal. low |
| 58 | **Ichimoku Kumo breakout + ATR** | **trend breakout** | **6** | XAU/GBPJPY | opt | trending | kumo breakout = trend rider ครบ. น่าลอง |
| 59 | EMA20 cross + Stoch + Hedging | trend + hedge | 3 ⛔ | — | H CORE | — | มี hedge แกน. ข้าม |
| 60 | **PA breakout + CCI filter + scaling in** | **breakout+scale** | **6** | XAU/GBP | (scale=pyramid) | trending | breakout + scale-in (pyramid). น่าลอง |
| 61 | Heiken Ashi + EMA50 + swing SL | trend | 5 | XAU/GBPJPY | opt | trending | HA smooth trend — ลด noise. mid, ลองได้ |
| 62 | **Keltner breakout + ATR trail** | **breakout (channel)** | **7** | **XAU/GBP** | opt | trending | channel breakout + ATR trail = ตรง thesis. **น่าลอง** |
| 63 | Alligator + Fractals breakout | trend breakout | 5 | XAU/GBPJPY | opt | trending | BW system — mid |
| 64 | Williams %R OB/OS | osc reversal | 3 | EUR | opt | range | = RSI-class reversal. low |
| 65 | Envelopes bounce | range revert | 3 | EUR | opt | sideway | = BB bounce. low |
| 66 | **Ichimoku Kumo breakout + ADX** | **trend breakout** | **7** | XAU/GBPJPY | opt | strong trend | kumo + ADX gate = trend rider แน่น. **น่าลอง** |
| 67 | Renko logic (offline) | exotic | 3 | trender | ❌ | trending | Renko ใน MT = synthetic, backtest เพี้ยน. low |
| 68 | **SuperTrend (ATR10×3) trend-follow** | **trend-follow** | **8** | **XAU/GBP** | ❌ | strong trend | ATR trend-rider สะอาด — พอร์ตไม่มี pure trend-follow. **TOP pick** |
| 69 | London session breakout 07-10 | breakout (session) | 6 | GBP | ❌ | London | = CB ที่มีแล้ว (GBPUSD). ของซ้ำ แต่ confirm ได้ |
| 70 | **Asian range breakout** | **breakout (session)** | **6** | GBP/AUD/JPY | ❌ | Asia→London | Asia range → breakout. pair กับ CB ได้. น่าลอง |
| 71 | False Breakout (fade) | reversal | 5 | range | opt | sideway | fade breakout = สวน thesis แต่ novel (stop-hunt). mid |
| 72 | Gap Trading | gap fill | 4 | indices/XAU | ❌ | Mon gap | weekend gap niche. mid-low |
| 73 | Three Soldiers/Crows | candlestick momo | 3 | trender | ❌ | trending | pattern เดี่ยว. low |
| 74 | Doji reversal + EMA200 | candlestick | 2 | — | ❌ | reversal | pattern. ข้าม |
| 75 | Supply/Demand zone + pending | SMC | 5 | XAU/GBP | opt | trending | zone auto-detect ยากแต่นิยม. mid |
| 76 | Kelly sizing | T (sizing) | T | ทุกตัว | ❌ | — | money-mgmt. graft (ระวัง Kelly aggressive) |
| 77 | Volatility sizing (ATR) | T (sizing) | T | ทุกตัว | ❌ | — | **module ดี** — เราใช้แนวนี้กับ ST03 sizing แล้ว. graft |
| 78 | Equity-based Martingale | martingale | 1 ⛔ | — | MG CORE | — | DQ. ข้าม |
| 79 | Time-based exit 23:59 | T (exit) | T | intraday | ❌ | — | exit module. graft |
| 80 | Drawdown Recovery Mode | T (risk) | T | ทุกตัว | ❌ (stop/resume) | — | DD stop+resume guard = kill-switch. graft ดี |
| 81 | **Triple-TF Confirm (D1/H1/M15)** | **MTF trend** | **6** | XAU/GBP | opt | trending | MTF alignment โครงดี. น่าลอง |
| 82 | Scalp EURUSD M1 + D1 trend | scalp | 3 | EUR | opt | trending | M1 spread กิน. low |
| 83 | **XAU เทรดเฉพาะ NY session** | **session (XAU)** | **7** | **XAU** | opt | NY/trending | XAU=trender proven + session ยังไม่แตะ. **น่าลอง** |
| 84 | USDJPY signal → EURJPY mirror | cross-asset | 5 | JPY pairs | opt | trending | lead/lag JPY. novel, mid |
| 85 | **WTI ↔ USDCAD correlation** | **cross-asset** | **6** | WTI/USDCAD | (pair) | trending | commodity-currency corr. novel diversifier. mid-high |
| 86 | Basket majors + equity TP/SL | basket | 3 | majors | opt grid | — | basket mgmt ไม่ใช่ edge. low |
| 87 | EMA20 + BB squeeze + ATR | breakout (vol) | 5 | XAU/GBP | opt | low-vol→exp | = #7 variant. mid |
| 88 | Stochastic cross + Volume spike | osc+vol | 3 | — | opt | — | FX tick-volume ปลอม. low |
| 89 | MACD histo div + engulfing | combo | 3 | trender | opt | trending | divergence+candle. low-mid |
| 90 | News filter trading | T (event) | T | ทุกตัว | ❌ | news | หยุดเทรดรอบข่าว = filter module. graft |
| 91 | **Hull MA cross + ADX + ATR** | **trend+ADX** | **6** | **XAU/GBP** | opt | strong trend | HMA responsive + ADX gate. น่าลอง |
| 92 | **T3 MA trend + RSI pullback + BE** | **trend pullback** | **6** | XAU/GBP | opt | trending | trend + pullback entry โครงดี. น่าลอง |
| 93 | DEMA cross + Chandelier Exit | trend | 6 | XAU/GBP | opt | trending | chandelier trail = exit ดี ride trend. น่าลอง |
| 94 | **Donchian 55 Turtle + pyramid ≤4** | **breakout+pyramid** | **8** | **XAU/GBP** | ❌ (pyramid) | strong trend | Turtle = breakout+pyramid คลาสสิก. **TOP pick** |
| 95 | KAMA trend + Stochastic | adaptive trend | 6 | XAU/GBP | opt | trending | KAMA adaptive = ลด whipsaw. น่าลอง |
| 96 | PPO cross + EMA200 | trend | 4 | trender | opt | trending | = MACD-class normalized. mid-low |
| 97 | **VWAP ±σ revert/breakout** | **hybrid regime** | **6** | EUR/XAU | opt | both | revert ในกรอบ/breakout นอกกรอบ = regime-adaptive. novel. น่าลอง |
| 98 | Pivot Camarilla breakout | pivot breakout | 5 | indices/FX | opt | trending | pivot L3/H3 breakout. mid |
| 99 | **ADR bands fade/breakout** | **hybrid vol** | **6** | XAU/GBP | opt | both | ADR 20d: fade 100% / breakout 120%. novel hybrid. น่าลอง |
| 100 | **Z-score mean reversion \|Z\|>2** | **stat reversion** | **6** | EUR/EURGBP | ❌ | range | reversion เชิงสถิติ สะอาดกว่า RSI. ถ้าจะเพิ่ม reversion leg ลองตัวนี้ก่อน. **น่าลอง** |

## EA 101–150

| # | ชื่อ | ประเภท | /10 | symbol เหมาะ | MG/H/R | ตลาดที่เหมาะ | หมายเหตุ / แนะนำ |
|---|---|---|---|---|---|---|---|
| 101 | BOS + Retest Order Block | SMC | 5 | XAU/GBP | opt | trending | break-of-structure + OB retest. นิยม, code ยาก. mid |
| 102 | Liquidity Sweep fakeout + EMA50 | SMC reversal | 5 | XAU/GBP | opt | trending | sweep→reversal. mid |
| 103 | Multi-candle momentum (3 ติด) | momentum | 5 | trender | ❌ | trending | 3 แท่งทางเดียว = momentum ง่าย. ลองได้ |
| 104 | IOI pattern + ATR SL | pattern | 4 | trender | ❌ | expansion | inside-outside-inside. mid-low |
| 105 | **NR7 breakout + London/NY overlap** | **breakout+session** | **7** | **XAU/GBP** | ❌ | overlap | narrow-range→breakout + session = ตรง thesis. **น่าลอง** |
| 106 | **Multi-session: Asia range→London breakout** | **breakout+session** | **6** | GBP/JPY | ❌ | London | น่าลอง (= แนวเดียว CB ขยาย session) |
| 107 | Triple-MTF: D1/H4 MACD/M15 breakout | MTF breakout | 6 | XAU/GBP | opt | trending | MTF + breakout entry. น่าลอง |
| 108 | Pairs EUR vs GBP mean-rev hedge | stat-arb | 5 | EUR/GBP | H (by design) | range | pairs revert. uncorrelated edge แต่ hedge + ยาก. mid |
| 109 | **Cross-asset lead/lag DXY→EUR** | **cross-asset** | **7** | EUR (DXY signal) | ❌ | trending | DXY นำ EUR = edge โครงสร้าง ไม่ใช่ indicator ซ้ำ. **น่าลอง (diversifier)** |
| 110 | XAU scalp M1 + H1 RSI + spread | scalp | 3 | XAU | opt | trending | M1 + spread กิน 5pip. low |
| 111 | **GBPJPY momentum + slippage + news** | **momentum** | **6** | **GBPJPY** | ❌ | trending | GBPJPY = trender แรง, momentum ตรง thesis. น่าลอง |
| 112 | Basket 5 pairs corr>0.7 | basket | 2 | majors | opt | — | เปิด 5 คู่ corr>0.7 = กระจุกความเสี่ยง (แย่). ข้าม |
| 113 | Fixed-fractional 1% + partial + trail | T (risk+exit) | T | ทุกตัว | ❌ | — | money+exit module. graft |
| 114 | Dynamic sizing VIX proxy | T (sizing) | T | ทุกตัว | ❌ | — | sizing ตาม vol. graft |
| 115 | Equity curve filter (>SMA20) | T (meta) | T | ทุกตัว | ❌ | — | meta-overlay น่าสน: ปิดระบบตอน equity curve ตก. graft |
| 116 | Stealth stop (virtual SL/TP) | T (exec) | T | ทุกตัว | ❌ | — | ซ่อน SL/TP จากโบรก. execution module |
| 117 | Time Stop 8h | T (exit) | T | intraday | ❌ | — | exit module. graft |
| 118 | Breakeven+ | T (exit) | T | ทุกตัว | ❌ | — | BE module. graft |
| 119 | Hedge each-order | hedge | 2 ⛔ | — | H CORE | — | DQ. ข้าม |
| 120 | Hedge total portfolio | hedge | 2 ⛔ | — | H CORE | — | DQ. ข้าม |
| 121 | TEMA cross + spread + ATR | trend (MA) | 4 | trender | opt | trending | TEMA cross variant. mid-low |
| 122 | TRIX cross zero + EMA200 | trend | 4 | trender | opt | trending | = MACD-class. mid-low |
| 123 | Schaff Trend Cycle + NY session | trend (osc) | 5 | XAU/GBP | opt | NY trend | STC = faster MACD + session. mid |
| 124 | QQE cross + BE | trend (osc) | 4 | trender | opt | trending | QQE smoothed RSI cross. mid-low |
| 125 | Fisher Transform + ADX>18 | trend | 5 | XAU/GBP | opt | trending | fisher + ADX gate. mid |
| 126 | RSI Laguerre mean-revert | stat reversion | 4 | EUR | ❌ | range | smoother RSI revert. mid-low |
| 127 | **Kaufman ER trend + SuperTrend stop** | **adaptive trend** | **7** | **XAU/GBP** | ❌ | strong trend | ER regime gate + SuperTrend = trend rider แน่น. **น่าลอง** |
| 128 | RVI cross + BB midline | osc | 3 | EUR | opt | range | osc. low |
| 129 | **Fractal breakout + ATR band** | **breakout** | **6** | XAU/GBP | opt | trending | fractal high+0.5ATR breakout. น่าลอง |
| 130 | Pivot Floor intraday | pivot | 4 | FX/indices | opt | intraday | floor pivot. mid-low |
| 131 | Order-block rejection + wick + EMA50 | SMC | 5 | XAU/GBP | opt | trending | OB + wick ratio. mid |
| 132 | Range Rotation VWAP ±1σ | reversion | 5 | EUR/XAU | ❌ | range | VWAP revert. mid |
| 133 | Stop-hunt sweep reversal | reversal | 5 | XAU/GBP | opt | range/sweep | sweep→reverse. mid |
| 134 | AB=CD harmonic + Fib | harmonic | 2 | — | ❌ | reversal | harmonic = subjective. ข้าม |
| 135 | **Vol contraction NRB/IB → expansion + OCO** | **breakout (vol)** | **7** | **XAU/GBP** | ❌ | low-vol→exp | vol-squeeze breakout + OCO (= ST03 OCO เรามี). **น่าลอง** |
| 136 | Session Handoff (Asia/London/NY) | session multi | 6 | GBP/XAU | opt | session | = "London→NY" idea. น่าลอง |
| 137 | D1 Kumo + H4 MACD + M15 TEMA | MTF | 5 | XAU/GBP | opt | trending | MTF combo. mid |
| 138 | EURUSD lead → GBPUSD corr>0.75 | cross-asset | 5 | EUR/GBP | opt | trending | lead/lag. mid |
| 139 | **Gold↔USDCHF inverse** | **cross-asset** | **6** | XAU/USDCHF | (pair) | divergent | inverse signal. novel diversifier. mid-high |
| 140 | Index filter | T (filter) | T | FX | ❌ | — | ใช้ index เป็น bias filter. graft |
| 141 | Crypto proxy hours | niche | 3 | crypto | opt | — | crypto session. low (ไม่ตรงพอร์ต) |
| 142 | Basket mean-reversion | basket revert | 3 | majors | opt | range | basket revert. low |
| 143 | CPPI position sizing | T (sizing) | T | ทุกตัว | ❌ | — | sizing module. graft |
| 144 | Volatility Parity | T (sizing) | T | portfolio | ❌ | — | risk-parity allocation = ใช้ระดับพอร์ต. graft |
| 145 | Adaptive Trailing | T (exit) | T | ทุกตัว | ❌ | — | trail module. graft |
| 146 | Tiered partial close | T (exit) | T | ทุกตัว | ❌ | — | = ST03 tiered TP. graft |
| 147 | Daily Loss Limit | T (risk) | T | ทุกตัว | ❌ | — | risk guard. graft |
| 148 | Weekend protection | T (risk) | T | ทุกตัว | ❌ | — | ปิดก่อน weekend. graft |
| 149 | Stealth TP/SL + slippage cap | T (exec) | T | ทุกตัว | ❌ | — | execution module. graft |
| 150 | Hedge config switch | hedge | 2 ⛔ | — | H opt | — | hedge option. ข้ามเป็นแกน |

## EA 151–200

| # | ชื่อ | ประเภท | /10 | symbol เหมาะ | MG/H/R | ตลาดที่เหมาะ | หมายเหตุ / แนะนำ |
|---|---|---|---|---|---|---|---|
| 151 | Jurik MA | trend (MA) | 5 | XAU/GBP | opt | trending | JMA = MA ลื่น ลด lag. mid (ลองเป็น filter) |
| 152 | Ehlers Fisher + RSI confluence | trend/reversal | 5 | XAU/GBP | opt | trending | fisher confluence. mid |
| 153 | Adaptive MA (AMA20) | trend | 5 | XAU/GBP | opt | trending | = KAMA-class adaptive. mid |
| 154 | RVI cross + EMA200 | trend (osc) | 4 | trender | opt | trending | RVI = MACD-class. mid-low |
| 155 | CMO(14) | momentum osc | 4 | trender | opt | trending | momentum osc. mid-low |
| 156 | Connors RSI(3,2,100) + BB exit | short reversion | 5 | EUR/indices | ❌ | range | ConnorsRSI = short-term mean-rev ที่มีชื่อ. mid (ลองได้ถ้าเพิ่ม reversion) |
| 157 | Market Facilitation Index + vol | volume (BW) | 3 | — | opt | — | FX tick-vol ปลอม. low |
| 158 | **Smoothed HA + SuperTrend exit** | **trend-follow** | **6** | XAU/GBP | ❌ | strong trend | HA trend + SuperTrend = trend rider ลด noise. น่าลอง |
| 159 | MACD + BB squeeze + volume | breakout | 4 | XAU/GBP | opt | low-vol→exp | vol-spike confirm = FX vol ปลอม. mid-low |
| 160 | ATR(14) volatility filter | T (filter) | T | ทุกตัว | ❌ | — | vol regime filter. graft (กรองตลาดนิ่ง/ผันผวน) |
| 161 | **Breakout weekly H/L + partial** | **breakout** | **6** | XAU/GBP | ❌ | trending | weekly breakout = TF สูง สัญญาณน้อยแต่แน่น. น่าลอง |
| 162 | Monthly pivot + engulfing | pivot | 4 | FX | opt | trending | monthly pivot. mid-low |
| 163 | FVG fill + EMA50 | SMC | 5 | XAU/GBP | opt | trending | fair-value-gap. นิยม, code ยาก. mid |
| 164 | ICT Breaker Block + session | SMC | 5 | XAU/GBP | opt | trending | ICT concept. mid |
| 165 | Swing Failure Pattern (SFP) | reversal | 5 | XAU/GBP | opt | range/sweep | SFP = stop-hunt reversal. mid |
| 166 | Liquidity void fill + RSI | SMC | 4 | XAU/GBP | opt | trending | imbalance fill. mid-low |
| 167 | Multi-candle Absorption Bar | pattern | 3 | — | ❌ | — | absorption = subjective. low |
| 168 | **Inside Day Breakout + opp-extreme stop** | **breakout** | **6** | XAU/GBP | ❌ | expansion | inside-day → breakout = NR-family โครงดี. น่าลอง |
| 169 | Multi-TF Orderblock Alignment | SMC | 5 | XAU/GBP | opt | trending | OB MTF. mid |
| 170 | Weekend gap strategy | gap | 4 | indices/XAU | ❌ | Mon gap | = #72. mid-low |
| 171 | H4 EMA trend + M15 BB bounce | trend+revert | 4 | EUR/GBP | opt | mixed | momentum+revert ผสม. mid-low |
| 172 | D1 Ichimoku + M5 scalp | scalp | 3 | EUR | opt | trending | M5 scalp. low |
| 173 | Cross-pair leading signal | cross-asset | 5 | majors | opt | trending | lead/lag generic. mid |
| 174 | **Commodity–currency correlation** | **cross-asset** | **6** | WTI/CAD, XAU/AUD | (pair) | trending | corr trade. novel diversifier. mid-high |
| 175 | EA Oil (WTI) breakout filter | breakout (oil) | 5 | WTI | opt | trending | oil breakout (smoke เดิม thin). mid — ต้อง tune bars ต่อ oil |
| 176 | **SPX500 direction filter → USDJPY** | **cross-asset (risk-on/off)** | **6** | USDJPY | ❌ | trending | risk-on/off proxy → JPY. novel diversifier. น่าลอง |
| 177 | Basket momentum | basket | 4 | majors | opt | trending | basket momo. mid-low |
| 178 | Inverse correlation hedge | hedge | 3 | pairs | H CORE | — | hedge-based. low |
| 179 | Crypto filter | niche | 3 | crypto | opt | — | ไม่ตรงพอร์ต. low |
| 180 | **Volatility Regime Switch** | **T (meta)** | T+ | ทุกตัว | ❌ | — | สลับโหมด trend/range ตาม vol = overlay ทรงพลัง. graft เข้า EA ที่มี 2 โหมด |
| 181 | EMA20 + MACD div + RSI filter | combo | 3 | trender | opt | trending | filter ซ้อน. low-mid |
| 182 | Ichimoku Kumo breakout + BB squeeze | breakout | 6 | XAU/GBPJPY | opt | trending | kumo + squeeze. น่าลอง |
| 183 | Triple MA (20/50/200) | trend | 4 | trender | opt | trending | MA ribbon. mid-low |
| 184 | **SuperTrend + VWAP confluence** | **trend-follow** | **6** | XAU/GBP | ❌ | trending | SuperTrend + VWAP = trend rider แน่น. น่าลอง |
| 185 | **ATR Channel Breakout + Vol spike** | **breakout (channel)** | **6** | XAU/GBP | opt | trending | ATR channel breakout (vol-spike=FX ปลอม ตัดออก). น่าลอง |
| 186 | ADX>25 + PSAR entry | trend | 5 | XAU/GBP | opt | strong trend | ADX gate + PSAR. mid |
| 187 | RSI>70/<30 + Engulfing | reversal | 3 | EUR | opt | range | osc+candle reversal. low |
| 188 | MACD histo peak fade + pivot | reversal | 3 | trender | opt | range | fade momentum. low-mid |
| 189 | Stochastic cross + EMA100 | trend+osc | 4 | XAU/GBP | opt | trending | = #5/#10. mid-low |
| 190 | CCI ±200 + divergence | reversal | 3 | EUR | opt | range | CCI extreme. low |
| 191 | Order Block Retest + Liq Sweep | SMC | 5 | XAU/GBP | opt | trending | = #101 combo. mid |
| 192 | FVG fill + candle rejection | SMC | 5 | XAU/GBP | opt | trending | = #163. mid |
| 193 | **Breakout NR4/NR7 + ATR stop** | **breakout (vol)** | **7** | **XAU/GBP** | ❌ | low-vol→exp | NR breakout เพียวๆ + ATR = ตรง thesis. **น่าลอง** |
| 194 | Inside-Outside bar combo breakout | breakout | 5 | XAU/GBP | ❌ | expansion | IO combo. mid |
| 195 | Three-Line Strike + EMA50 | candlestick | 3 | trender | ❌ | trending | pattern. low |
| 196 | Session bias | session multi | 6 | GBP/XAU | opt | session | = #136/203. น่าลอง |
| 197 | **Monthly key level breakout + retest** | **breakout** | **6** | XAU/GBP | ❌ | trending | key-level breakout + retest confirm. น่าลอง |
| 198 | Stop hunt fakeout reversal | reversal | 5 | XAU/GBP | opt | sweep | = #133/165. mid |
| 199 | Supply-demand imbalance + RSI | SMC | 4 | XAU/GBP | opt | trending | S/D + RSI. mid-low |
| 200 | Multi-pattern AI hybrid | kitchen-sink | 3 | — | opt | — | ผสมทุกอย่าง = overfit สูง, debug ยาก. low |

---

## สรุป: shortlist เรียงตามคะแนน (สิ่งที่ควรลองก่อน)

### 🥇 8/10 — TOP (trend-rider/pyramid ที่พอร์ตยังไม่มี) — **ปิดครบทั้ง 3 แล้ว 2026-07-02**
- **#20 Trend-Following + Pyramiding** → **DEAD** (XAU/GBP H4, single 0.87–1.02 / pyramid 0.99–1.00 — pyramid ไม่ช่วยเลย)
- **#68 SuperTrend (ATR10×3)** → tested XAU H4 (IS 1.92/OOS 5.09), **PARKED** (corr 0.946 vs Kaufman ER ที่ดีกว่า)
- **#94 Donchian 55 Turtle + pyramid** → **DEAD** (0 additive legs, ดู MASTER_BACKLOG)
- ⚠️ เหตุผลเดิมที่เขียนไว้ผิด: "กลไก pyramid เรา validate แล้ว (ST03)" — **หักล้างแล้ว 2026-07-02**
  (EA_CORE loop ปิดด้วย fallback, coarse grid 48/48 combos OOS PF<1.0 — pyramid executor ของ ST03
  ไม่มี durable edge, ดู `EA_CORE_ST03_LOOP_PLAN.md`). อย่าใช้ประโยคนี้อ้างอิงต่อ.

### 🥈 7/10 — breakout/trend แน่น (ลองรอบสอง)
- #30 Breakout prev H/L + ATR trail · #38 ATR breakout · #62 Keltner breakout · #66 Ichimoku Kumo+ADX ·
  #83 XAU NY session · #105 NR7+session · #109 DXY→EUR (diversifier) · #127 Kaufman ER+SuperTrend ·
  #135 Vol contraction→OCO · #193 NR4/NR7 breakout

### 🥉 6/10 — น่าสน (มี filter/session/cross-asset/novel)
- #7 BB squeeze · #9 prev-day breakout · #33 ADX+EMA · #43 Rectangle breakout · #53 EUR↔XAU inverse ·
  #70 Asian range · #85 WTI↔CAD · #91 HMA+ADX · #92 T3+pullback · #97 VWAP hybrid · #99 ADR bands ·
  #100 Z-score reversion · #111 GBPJPY momentum · #176 SPX→USDJPY · #161 weekly breakout · #184 SuperTrend+VWAP

### 🔧 Technique (T) — ไม่ใช่ EA เดี่ยว แต่ graft เข้า EA ที่ work ได้
- exit: #19 ATR trail · #93 Chandelier · #145 adaptive trail · #146 tiered partial (=ST03)
- risk: #48 %risk · #77 vol-sizing (ใช้แล้ว) · #80 DD recovery · #147 daily loss · #50 equity protect
- meta: **#115 equity-curve filter · #180 vol-regime switch** (overlay ทรงพลัง)

### ⛔ ข้าม (martingale/grid/hedge แกน — lab 0/63)
- #16,17,18,46,59,78,119,120,150,178 + candlestick/harmonic เดี่ยว (#10,11,14,40,41,42,45,134)

### ⚠️ กับดักที่ต้องระวัง (อย่าหลงคะแนนสูง)
- ~70% เป็น **indicator-cross/osc variant** (EMA/MACD/RSI/Stoch) = เพดาน ~1.1 ที่ lab **พิสูจน์ตายแล้ว** → ผมให้ 3-4
- volume-based (#37,88,157,159,185 vol-spike) = FX tick-volume **ปลอม** ระวัง
- SMC/ICT (#101,163,164,191,192...) = นิยมแต่ code robust ยาก + สัญญาณ subjective → 5 (ต้องพิสูจน์)

**ขั้นต่อไป:** หยิบ top 8/10 มาทีละตัว → `mql-code-generator` (จาก prompt ใน PDF) → `/signal-scan` smoke → ตัวรอดเข้า funnel. แนะนำเริ่ม **#68 SuperTrend** (สร้างง่าย, edge ชัด, เติมช่องว่าง trend-follower)
</content>
