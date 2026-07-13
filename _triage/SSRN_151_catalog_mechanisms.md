# SSRN 151 Strategies — mechanism catalog (in-scope chapters)

แหล่ง: `D:\EA_LAB\docs\ssrn_id3453295_code2224789.pdf` (Kakushadze & Serur 2018).
บทนอกขอบเขต MT5 ที่ข้าม: Options(2), Fixed income(5), Structured(11), Convertibles(12),
Tax arb(13), Misc(14), Distressed(15), Real estate(16), Cash(17), Infrastructure(20).
FX(ch8) แกะมือแยกใน `SSRN_151strategies_PBX_ebook_2026-07-13.md`. ที่เหลือด้านล่าง =
exhaustive extract (agent, verified ครบทุก subsection).

## Stocks (ch3)
- **3.1 Price-momentum** — rank ด้วย cumulative return (T=12, skip 1m), buy top-decile/short bottom; w=1/N หรือ ∝1/σ. [cross-sectional]
- **3.2 Earnings-momentum** — rank ด้วย SUE=(E−Ẽ)/σ. [cross-sectional · needs earnings data]
- **3.3 Value** — rank B/P, buy cheap/short rich. [cross-sectional · needs fundamentals]
- **3.4 Low-vol anomaly** — buy low-σ / short high-σ (σ over 126–252d). [cross-sectional]
- **3.5 Implied volatility** — buy stocks w/ largest call-IV rise. [cross-sectional · needs option IV]
- **3.6 Multifactor** — รวมหลาย factor (value+momentum) demean+average rank. [cross-sectional]
- **3.7 Residual momentum** — momentum บน residual จาก FF3 regression. [cross-sectional · needs FF factors]
- **3.8 Pairs trading** — pair corr สูง, short rich/buy cheap by demeaned return, dollar-neutral. [basket-2]
- **3.9 Mean-reversion single cluster** — N>2 corr stocks, D=−γR̄ (demeaned). [cross-sectional]
- **3.10 Mean-reversion multi-cluster/weighted-reg** — cluster-neutral residuals ε=R−ΛQ⁻¹ΛᵀR. [cross-sectional · needs sector map]
- **3.11 Single MA** — P>MA long, P<MA short. [SINGLE ✅]
- **3.12 Two MA** — MA(T')>MA(T) long + optional stop Δ=2%. [SINGLE ✅]
- **3.13 Three MA** — MA(T1)>MA(T2)>MA(T3) filter false signals (3/10/21). [SINGLE ✅]
- **3.14 Support/Resistance** — pivot C=(H+L+C)/3, R=2C−L, S=2C−H; P>C long→R, P<C short→S. [SINGLE ✅]
- **3.15 Channel (Donchian)** — Bup=max(T), Bdown=min(T); reversion หรือ breakout + volume confirm. [SINGLE ✅]
- **3.16 Event-driven M&A** — long target/short acquirer at swap ratio. [basket · needs deal data]
- **3.17 ML single-stock KNN** — predict fwd return ด้วย KNN บน normalized MA/vol predictors; threshold z1,z2. [SINGLE ✅ · novel]
- **3.18 Stat-arb optimization** — max Sharpe weights w=γC⁻¹E, dollar-neutral via Lagrange. [cross-sectional · allocator]
- **3.19 Market-making** — buy bid/sell ask + short-horizon signal. [needs orderbook/HFT ✗]
- **3.20 Alpha combos** — รวม N alphas → mega-alpha (11-step demean/normalize/regress). [cross-sectional · needs alpha lib]

## ETFs (ch4)
- **4.1 Sector momentum rotation** — buy top-decile ETF by cum-return; **4.1.1 +MA filter**; **4.1.2 dual-momentum: long เฉพาะถ้า broad-market uptrend ไม่งั้นถือ gold/Treasury** ⭐(regime gate). [cross-sectional]
- **4.2 Alpha rotation** — rank ด้วย Jensen alpha (FF3). [cross-sectional · needs FF]
- **4.3 R-squared** — overweight low-R² (selectivity) + alpha double-sort. [cross-sectional · needs factors]
- **4.4 Mean-reversion IBS** — IBS=(C−L)/(H−L), sell top-decile/buy bottom. [SINGLE-bar signal ✅ · ถูกมาก]
- **4.5 Leveraged ETFs** — short ทั้ง LETF + inverse-LETF harvest decay. [basket · ไม่มีใน MT5 ✗]
- **4.6 Multi-asset trend** — long-only survivors (Rcum>0), w=γ·Rcum/σ² (Sharpe-opt diag). [cross-sectional · sizing]

## Indexes (ch6) — ส่วนใหญ่ arb/options ✗
- **6.2 Cash-and-carry arb** — basis spot vs futures converge. [basket-arb]
- **6.3 Dispersion trading** — long constituent straddles / short index straddle. [needs options ✗]
- **6.4 Intraday ETF arb** — 2 ETF same index, cross bid/ask. [needs orderbook ✗]
- **6.5 Index vol targeting** — w=σ*/σ risky vs risk-free, rebalance เมื่อ |Δw|/w>κ. [SINGLE ✅ · sizing technique]

## Volatility (ch7) — options/VIX, นอก MT5 spot ✗
- **7.2 VIX futures basis** — short contango/buy backwardation, D=basis/T thresholds ±0.10/±0.05. [VIX futures ✗]
- **7.3 Vol carry 2 ETNs** — short VXX/long VXZ roll-decay diff. [ETN ✗]
- **7.4 Vol risk premium** — sell straddle เมื่อ IV−RV>0; 7.4.1 +gamma hedge. [needs options ✗]
- **7.5 Vol skew risk reversal** — buy OTM call/sell OTM put. [needs options ✗]
- **7.6 Variance swaps** — long/short realized vs implied var. [needs options ✗]

## Commodities (ch9)
- **9.1 Roll yields** — long backwardation/short contango, φ=P1/P2. [cross-sectional futures]
- **9.2 Hedging pressure COT** — CFTC positioning HP signal. [cross-sectional · needs COT data]
- **9.3 Diversification** — commodity+equity low-corr, Fed-rate tactical. [multi-asset · needs Fed]
- **9.4 Value** — v=P5yr/P0, buy top/sell bottom tercile. [cross-sectional futures]
- **9.5 Skewness premium** — buy low-skew/sell high-skew quintile. [cross-sectional futures]
- **9.6 Pricing model (OU)** — dX=κ(a−X)dt+σdW mean-revert log-spot, sell rich/buy cheap vs model. [SINGLE ✅ · novel MR]

## Futures (ch10)
- **10.1 Hedging risk** — futures overlay hedge (cross-hedge/IR duration). [hedge overlay]
- **10.2 Calendar spread** — bull=buy near/sell far; fundamentals view. [same-underlying spread]
- **10.3 Contrarian MR** — buy losers/sell winners vs index Rm, w=−γ[Ri−Rm]; 10.3.1 +vol/OI filter. [cross-sectional]
- **10.4 Trend following** — w=γ·sign(R)/σ; **tanh(R/κ) smoothing กัน sign-flip** ⭐; demean variants dollar-neutral. [cross-sectional · sizing techniques SINGLE-usable]

## Crypto (ch18) — ไม่ใช่ตลาดปัจจุบันเรา แต่ build ได้
- **18.2 ANN BTC** — feed-fwd NN, input=normalized ret/EMA/EMSD/RSI multi-horizon, softmax quantile output. [SINGLE · heavy]
- **18.3 Sentiment naive Bayes** — tweet Bernoulli features → up/down class. [needs Twitter data]

## Global Macro (ch19) — ต้อง macro data ✗ ส่วนใหญ่
- **19.2 Fundamental macro momentum** — rank บน 4 state vars (cycle/trade/policy/sentiment). [needs macro]
- **19.3 Inflation hedge** — commodity alloc CA จาก headline−core CPI spread. [needs CPI]
- **19.4 Global fixed-income** — rank country bonds multifactor. [needs sovereign data]
- **19.5 Economic announcements** — 100% equity on FOMC days / Treasuries else. [needs calendar · idea: news-day gate]
