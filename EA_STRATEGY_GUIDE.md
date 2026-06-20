# EA Strategy Guide — Reference for Backtesting Setup
# อัพเดท: 2026-06-19 | ข้อมูลจาก: name analysis + test history

## วิธีอ่านตาราง
- **Strategy**: ประเภทกลยุทธ์หลัก
- **Entry Signal**: สัญญาณเข้าออเดอร์
- **Risk Type**: วิธีจัดการ risk (สำคัญมาก — ตัวไหน Grid/Martingale = DD จริง ×2-3x)
- **Best Symbol/TF**: จากประสบการณ์หรือชื่อ EA
- **Model**: 1=OHLC (เร็ว), 4=Real Ticks (จำเป็นถ้า SL < 20 pip)
- **Status**: CONFIRMED/REJECT/PARTIAL/UNTESTED

---

## Portfolio (Confirmed)

| EA | Strategy | Entry Signal | Risk Type | Best Symbol/TF | Model | Notes | Status |
|---|---|---|---|---|---|---|---|
| **MatchaGrid** | Grid DCA | MA trend direction | Grid (fixed step) | CHFJPY M15 | 1 | DD real ×2-3x, demo ≥ 3 mo | CONFIRMED ✅ |
| **(NuiIndy) Dynamic RSI+ADX Style (4)** | Trend Filter | RSI overbought/oversold + ADX strength filter | Fixed SL | EURUSD H1 | 1 | Locked: RSI=18, ADX_p=20, ADX_v=35 | CONFIRMED ✅ |
| **(ST) EA03 Count MACD v1** | Trend Following | MACD crossover + count signal | Fixed SL | GBPUSD H1, USDCAD H1 | 1 | Default params ใช้ได้เลย | CONFIRMED ✅ |

---

## Tested — REJECT

| EA | Strategy | Entry Signal | Risk Type | Best Symbol/TF | Model | Reason Rejected | Status |
|---|---|---|---|---|---|---|---|
| **Gold_SMC_Continuous_MT5** | SMC Basket | Smart Money Concepts (liquidity, OB) | Basket recovery (no SL per trade) | XAUUSD H1 | 1 | Regime-dependent (gold bull only), OOS 2020-2023 PF=0.90 | REJECT ❌ |
| **Immortal Gold** | Long-only Martingale | MA/momentum long bias | Martingale (no SL) | XAUUSD | 1 | OOS DD=230%, blowup | REJECT ❌ |
| **BaronGrid** | Grid | Fixed grid spacing | Grid | EURUSD | 1 | OOS PF=1.00, trades too thin (120/6yr) | REJECT ❌ |
| **EA Among Us** | Martingale | Unknown entry | Martingale, no SL (Kmartin=1.5) | EURUSD H1 | 1 | OOS RF=1.15 < gate, no SL = systemic risk | REJECT ❌ |
| **HalfTrend_MTF_EA** | Multi-TF Trend | HalfTrend indicator | Fixed SL | EURUSD H1 | 1 | Overtrading, PF=1.05 DD=38% | REJECT ❌ |
| **Sentinel KMZ_2.5_fix MT5** | Unknown | Sentinel signal | Unknown | EURUSD | 1 | DD=93%, blowup | REJECT ❌ |
| **PivotProbabilityPro** | Pivot Probability | Pivot point statistics | Fixed SL (likely) | EURUSD | 1 | PF=0.84, no edge | REJECT ❌ |
| **BB Return MT5 EA V_7.40** | Mean Reversion | Bollinger Band bounce | Fixed SL | EURUSD | 1 | Only 44 trades, statistically insignificant | REJECT ❌ |
| **EA TREND V2** | Trend Following | MA/EMA trend | Fixed SL (fixed pip) | EURUSD H1 | 1 | OOS DD=19.3% + one-big-trade; fixed pip sizing blows up volatile pairs | REJECT ❌ |
| **Multi-Timeframe Trend Following** | Multi-TF Trend | MTF MA alignment | Fixed SL | EURUSD | 1 | DD=64%, too aggressive | REJECT ❌ |
| **LondonBO** | Session Breakout | London open channel breakout | Fixed SL | GBPUSD H1 | 1 | PF=0.93 default, plateau=NONE (optimize failed) | PARTIAL ⚠️ |
| **Grizzy[BUY]v1.0** | Long-only | Unknown buy signal | Unknown | XAUUSD | 1 | DD=85%, long-only risk | REJECT ❌ |
| **(oh) MooDeng Bot** | Grid/Martingale | Unknown | Grid or Martingale | EURUSD | 1 | MooDeng family = blowup pattern | REJECT ❌ |
| **Ben_CR_2025_v1.2** | Unknown | Unknown | Unknown | XAUUSD | 1 | DD=69%, REJECT | REJECT ❌ |
| **EX197- Multi Group Scalping EA** | Group Scalping / Breakout FVG | FVG (Fair Value Gap) breakout | Unknown | GBPJPY | 1 | OOS RF < 1.50 | REJECT ❌ |
| **PORT 1/6 (rev_010/012)** | Commercial | Unknown | Unknown | Various | 1 | Commercial EAs ไม่ผ่าน OOS validation | REJECT ❌ |
| **All Boss grid variants (MQL5 EA\)** | Grid | MA trend + grid | Grid | Various | 1 | All REJECT in batch2, DD blowup | REJECT ❌ |
| **Quantum family (all)** | Various | Various | Various | Various | 4* | OHLC artifact (QSpeed), treat whole family as unreliable | REJECT ❌ |

---

## Untested — Batch 3 (รันอยู่)

| EA | Strategy (inferred) | Entry Signal (inferred) | Risk Type | Setup แนะนำ | Model | Priority | Notes |
|---|---|---|---|---|---|---|---|
| **EX162 - EMA Rising and EMA Crossover** | Trend Following | EMA alignment (rising) + crossover | Fixed SL (likely) | EURUSD H1, H4 | 1 | ⭐⭐⭐ | EMA trend = proven category (MACD ผ่าน) ถ้า IS pass → ลอง GBPUSD/USDCAD |
| **(GPM) Almost 1 Direction v1.9.3** | Directional Momentum | Trend direction bias + momentum | Fixed SL (likely) | EURUSD H1 | 1 | ⭐⭐⭐ | "Almost 1 Direction" = filter ให้ trade ทิศทางเดียว, ควรมี edge ถ้า filter ดี |
| **The Day Zone v2** | Session Breakout | Day/session zone breakout | Fixed SL | GBPUSD H1, M30 | 1 | ⭐⭐⭐ | "Day Zone" = session-based (London/NY), test GBPUSD/EURUSD — if plateau exists, optimize session hours |
| **Knight Sword EA** | Trend/Breakout | Unknown — sword = directional | Fixed SL (likely) | EURUSD H1 | 1 | ⭐⭐ | ถ้า IS ผ่าน → test GBPUSD/USDCAD ด้วย |
| **KNTPTT_KnightSword_v2** | Trend/Breakout | Same as Knight Sword (v2) | Fixed SL (likely) | EURUSD H1 | 1 | ⭐⭐ | Same family, v2 อาจ improve กว่า v1 — ถ้าทั้งคู่ผ่าน ใช้ v2 |
| **ZyFer_Noname** | Unknown | Unknown | Unknown | EURUSD H1 | 1 | ⭐⭐ | Mystery EA — ถ้า IS PF < 1.20 ตัดทิ้งเลย |
| **Black Wolf EA** | Momentum/Breakout | Unknown breakout/momentum | Unknown | EURUSD H1 | 1 | ⭐⭐ | "Wolf" = aggressive entry, ระวัง DD |
| **Boss - 6 Pivot Range Trading** | Range/Pivot | Pivot point range trade | Fixed SL | EURUSD H1 | 1 | ⭐⭐ | Range trade ≠ Boss grid — pivot = mean reversion ที่ level ชัด, ต่างจาก Boss grid ที่ rejected |
| **EA Black Dragon MT5 V13** | Unknown | Unknown | Unknown | EURUSD H1 | 1 | ⭐⭐ | Commercial EA (V13 = หลาย version), ถ้าผ่าน IS → check OOS กับ GBPUSD/USDJPY |
| **The Gold Reaper MT5** | Gold Trend/Scalp | Unknown gold-specific signal | Unknown | XAUUSD H1 | 1 | ⭐⭐ | Gold-dedicated EA, ระวัง long-only bias (gold bull 2023-2026 อาจ inflate IS) |
| **XAU_Scalper_AI_v10** | Gold Scalping | AI/ML-based signal (likely pattern) | Fixed SL (scalp) | XAUUSD M15, H1 | **4** | ⭐⭐ | Scalper = ต้องใช้ real ticks (Model=4) ถ้า SL < 20 pip; "AI" อาจ overfit |
| **Sentinel XAU_1.2_fix** | XAU-specific | Unknown sentinel signal | Unknown | XAUUSD H1 | 1 | ⭐⭐ | ต่างจาก Sentinel KMZ (ที่ DD=93%) — XAU variant อาจ tune สำหรับ gold โดยเฉพาะ |
| **Gold_SMC_FiboRecovery_MT5** | SMC + Fibonacci Recovery | Smart Money Concepts + Fibo level | Recovery (multi-position) | XAUUSD H1 | 1 | ⭐⭐ | "Recovery" = stack positions = DD ×2-3x, ดู equity DD ไม่ใช่ balance DD; GSMC แม่ rejected แล้ว แต่ตัวนี้ต่างกัน |
| **(OH) Fibo Harmonic Pattern V01A** | Pattern Trading | Fibonacci harmonic (Gartley/Butterfly) | Fixed SL at pattern | EURUSD H4, H1 | 1 | ⭐ | Harmonic pattern = หายาก, trades น้อย → ระวัง < 100 trades gate |
| **LQ Scalper** | Scalping | Unknown scalp signal | Fixed SL (tight) | EURUSD M15 | **4** | ⭐ | Scalper → Model=4 (real ticks) บังคับ; spread sensitive มาก |
| **Scalping Trading v2.3** | Scalping | Unknown scalp signal | Fixed SL (tight) | EURUSD M15 | **4** | ⭐ | เหมือน LQ Scalper — real ticks required |
| **SNOWBALL GENIUS HYBRID** | Hybrid (Trend+Recovery?) | Combined signals | Hybrid (possibly recovery) | EURUSD H1 | 1 | ⭐ | "Snowball" = compounding/DCA element likely, "Hybrid" = ผสมหลาย strategy |
| **Ghost by JOMHOD MA5** | MA-based Trend | MA5 crossover/direction | Unknown | EURUSD H1 | 1 | ⭐ | MA5 = fast MA = อาจ overtrade; test H1 ก่อน |

---

## Untested — Low Priority / Skip Recommended

| EA | Category | ทำไม Skip | ควรลองถ้า |
|---|---|---|---|
| **(Jobot) Price Action + Martingale** | Martingale | Martingale in name = reject | ไม่ควร |
| **(Jobot) Trend Line by Zigzag Martingale** | Martingale | Martingale in name | ไม่ควร |
| **(JobotX) BITCOIN STOCKs DCA** | Crypto DCA | ไม่ใช่ forex | ถ้าอยากลอง crypto |
| **(Niyombot) Price Action Close All / Vote Close All** | Utility | Panel/utility ไม่ใช่ trading EA | ไม่ควร |
| **(NuiIndy) Perfect Tri Arbitrage** | Arbitrage | 3-leg arb ไม่ทำงานใน backtester | ไม่ควร |
| **(Oh) Grid Upper lower V23** | Grid | Grid family | ไม่ควร |
| **(oh) Master GRID ATR** | Grid | Grid + ATR sizing แต่ยังเป็น grid | ไม่ควร |
| **43.Fast Shot Arbitrage** | Arbitrage | Arbitrage ไม่ทำงานใน backtester | ไม่ควร |
| **AAA#IRSI SUMPIP LOT MARTINGALE** | Martingale | Martingale in name | ไม่ควร |
| **EX177 - Grid Trading System** | Grid | Grid in name | ไม่ควร |
| **KNTPTT Grid Scalp Pro** | Grid | Grid in name | ไม่ควร |
| **KNTPTT LongTerm DCA** | DCA Martingale | DCA = martingale-like | ไม่ควร |
| **LowCortisolGrid** | Grid | Grid in name | ไม่ควร |
| **Grid Profit-2-way / Grid197 MO ATR / JanusGrid** | Grid ×3 | Grid family | ไม่ควร |
| **CloseAllPanel / Advance Dashboard** | Utility | Panel EA | ไม่ควร |
| **SakuraRebate / Lot Rebate / PUMLOT** | Utility/Rebate | Rebate or lot utility | ไม่ควร |
| **Accounting/Sanity/Symbol Diagnostics** | Utility | Framework test tools | ไม่ควร |
| **ESQ1004 BB RSI X Pyramid** | Martingale-like | "Pyramid" = เพิ่ม lot ตามทิศทาง = risk compound | ถ้าอยากลอง: ดู DD equity ระวัง |
| **FAST_Rebalance 2.2** | Rebalancing | Portfolio rebalance = ไม่ใช่ trade EA | ไม่ควร |
| **11198621 / 143 E4.7.4 / [EX-127** | Commercial (product ID) | ชื่อเป็น ID = likely commercial, pattern = REJECT | ไม่ควร |
| **CHICKEN LITTILE EA 2** | Unknown | Commercial noise | เป็น curiousity เท่านั้น |
| **BS Pofit888 / EasyMoney_V1** | Commercial | Marketing name = unlikely edge | ไม่ควร |
| **(Boss) Hedging Balance** | Hedging | Hedging = complex risk, Boss family pattern | ไม่ควร |
| **(OH) Recovery Hedging V04/V05** | Hedging+Recovery | Recovery + Hedging = DD compound | ถ้าจะลอง: ดู equity DD ×3x |
| **Perfect EA(M4) AutoHedging** | Hedging | Auto hedging = complex | ไม่ควร |
| **Advance MM Connect DL by WOBR** | Utility | MM connector, not standalone | ไม่ควร |
| **V2_15_SEMI_ORI_FINAL / Winning Pro / Winning Semi** | Commercial | "Final" naming = old commercial | ไม่ควร |
| **PuN LoT XTime-r1 / PUMLOT** | Lot sizing | Lot tool, not strategy | ไม่ควร |

---

## Setup Cheat Sheet (ใช้ก่อน backtest)

| คำถาม | คำตอบ |
|---|---|
| Model ไหนดี? | Model=1 (OHLC) สำหรับ SL ≥ 20 pip; Model=4 (Real Ticks) บังคับสำหรับ scalper และ SL < 20 pip |
| Symbol ไหน smoke ก่อน? | General EA → EURUSD H1; Gold EA → XAUUSD H1; Session EA → GBPUSD H1 |
| IS window ไหน? | 2023.01.01–2026.06.01 (bull trend, หลัง COVID); OOS = 2020.01.01–2023.01.01 (COVID + ranging) |
| Gate IS smoke? | PF ≥ 1.50, Equity DD ≤ 30%, Trades ≥ 100 |
| ถ้า IS pass → อะไรต่อ? | OOS (2020-2023) → ถ้าผ่าน → MC bootstrap → ถ้าผ่าน → correlation vs portfolio |
| Grid/Martingale → DD ยังไง? | Report DD × 2-3x = real live DD estimate |
| ถ้า trades น้อย (< 100 IS)? | ตัดทิ้ง ไม่มีนัยสำคัญทางสถิติ |
| ถ้า IS PF ดีมาก (> 3.0) แต่ trades น้อย (< 200)? | ระวัง overfit spike — ต้องดู OOS ก่อนตัดสิน |
| Recovery/Fibo Recovery → test ยังไง? | ต้องดู equity DD (ไม่ใช่ balance DD), ระวัง IS 2023-2026 เป็น trend = recovery อาจไม่ได้ถูก trigger |
| Regime test ที่สำคัญ? | Gold 2020-2022 (COVID + bear) = kill test สำหรับ XAUUSD EA |

---

*หมายเหตุ: "inferred" = ประเมินจากชื่อและ category — ยืนยันได้จาก MT5 input panel*
