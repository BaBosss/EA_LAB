# FINDYOUR8 / "ว่าด้วยการเทรด" — Strategy PDF Idea Catalog (2026-07-19)

> แหล่ง: เพจ FB **ว่าด้วยการเทรด / FINDYOUR8** (ผู้เขียน **Wongsakon ไขแสง**, TradingView "Wongsakon",
> trend-following + systematic). โหลดหนังสือแจกฟรี 20 PDF / 887 MB จาก Google Drive (folder public,
> ระบุ "ห้ามนำไปใช้เชิงพาณิชย์" = ใช้ศึกษา/แกะไอเดียได้ ห้ามขายต่อ). ไฟล์ = `_triage/findyour8_pdfs/`.
> PDF เป็นสไลด์ Canva (image-based) → render PNG (pymupdf) → fan-out subagent ตัวละระบบ สกัด logic.
> **เอกสารนี้ = "ได้ไอเดียอะไร + ต่อยอดจากไหน" ไม่ตัดสิน verdict** (ต้องผ่าน VERDICT GATE ก่อน).
> เทียบกับ [[quantcorner-findyour8-idea-catalog]] (รอบก่อน guest-capped) — รอบนี้ login เข้าถึงเนื้อเต็ม.

## ผู้เขียนคือใคร
Wongsakon — TradingView trend-follower, สอนคลาส "ว่าด้วยการเทรด 101" (27 บท), ผู้ติดตาม FB 3.7 หมื่น.
Home ตัวอย่างทุกระบบ = **BTC/crypto spot** (เลือก spot PAXG/BTC จงใจเลี่ยง swap). ปรัชญา = Kaufman/Basso
(adaptive, "robustness not perfection", survive-by-risk-math ไม่ทำนายทิศ).

---

## 9 ระบบใน folder strategic (สกัดโดย subagent — cite หน้าในผลเต็มแต่ละตัว)

### 1. 🏆 Adaptive Grid: Zero to Hero (56น.) — **ACTIONABLE-NEW ตัวท็อป**
- **แก่น:** grid mean-reversion ที่ **zone edge มาจาก Monte-Carlo block-bootstrap** ไม่ใช่เดา S/R
- **⭐ MC zone:** จำลอง **10,000 path × 60 วัน** จาก history 1,000 วัน ด้วย **24-day block bootstrap**
  (รักษา vol/momentum autocorr = "market DNA") → **P10 = ขอบล่าง, P90 = ขอบบน** ของกริด
- spacing = **0.3 × ATR(RMA30)**; #levels = (P90−P10) ÷ spacing (ตัวอย่าง BTC ≈ 75 levels)
- **lot = FLAT (linear ไม่ martingale)** ต่อ level; capped ที่ band; **hard kill −20% equity**
- sizing ladder 4 ชั้น: cash → fixed% (anti-martingale) → leverage+funding-arb → **⭐ ATR-adaptive
  `NewSize = BaseSize×BaseATR/CurATR`** (vol ขึ้น=ลดไซซ์, vol นิ่ง=อัดเพิ่ม)
- **Maker/Post-Only fee discipline** (Maker 0.02% vs Taker 0.05%; taker drag 10-15%/cycle)
- เลือก **spot PAXG/BTC เลี่ยง swap** โดยเจตนา
- **structural: ปลอดภัย** (flat lot + capped band + −20% kill = worst-case คำนวณได้ ≠ martingale)
- **reusable levers → EDGE_CATALOG:** (1) MC-P10/P90 grid zone (2) 0.3-ATR spacing (3) inverse-ATR
  anti-martingale lot (4) Maker fee discipline (5) spot-asset เลี่ยง swap
- ⚠️ single point of failure = P10/P90 in-sample; black-swan breach ต่ำกว่า P10 = band ใต้น้ำ + −20%
  kill หยาบ → ต้อง BWD 2020-22 hard-gate. ⚠️ MT5 FX/CFD คืน swap ที่เด็คเลี่ยง (BTC-long −14.67%/yr)

### 2. Dynamic Grid Update 171125 (315น.) — เสริม Adaptive Grid (ตัวเสี่ยงกว่า)
- **สำคัญ: MC+bootstrap ที่เพจเคลม ไม่มีจริงในเด็คนี้ — มีแค่ ATR** (marketing gap)
- band = **close ± 3×ATR(30 daily)**, ATR smooth ด้วย SMA เป็น vol-regime reference
- **⭐ geometric spacing:** `ratio = (P_high/P_low)^(1/N)` → step เป็น **% คงที่** (กว้างขึ้นตามราคา)
  = lever ใหม่จริง (กริดเราตอนนี้ตั้ง step แบบ naive fixed) · default N=20-30, **dynamic count**
  (ATR ขึ้น→grid น้อยลง กัน fee) · weekly re-pin
- lot flat ต่อ grid; **BUT Recovery-Zone overlay = geometric martingale 14%→28%→56%** (3 caps, 98% deploy)
- **ไม่มี hard SL/DD-kill ในกริด** — จัดการด้วย hedge (short perp/put) manual + trend filter (MACD+EMA
  ลด exposure 80%→30% ใน downtrend) · author ยอมรับ BTC −60-80% = พอร์ต DD −30-40%
- live: ~2%/เดือนจริง (screenshots) แต่ window สั้น favorable; โชว์ −5.64%/3เดือนซื่อสัตย์ (BTC −16%)
- Long-only BTC spot เดี่ยว
- **reusable lever:** geometric constant-% spacing + ATR-band zone + dynamic grid count
- ⚠️ manage-only grid ที่ enter ตอน risk-off; Recovery overlay ต้องผ่าน 4-check martingale + ENGINE-EDGE cage

### 3. Adaptive Revolution 101 / KAMA Breakout + ATR VolStop (52น.)
- **KAMA Breakout** (Kaufman) — MA ปรับความเร็วต่อเนื่องตาม Efficiency Ratio (noise regime)
- entry: Close>KAMA **AND** break Donchian(20) high → เข้าแท่งถัดไป; exit: Close<KAMA; ATR stop
- params: **KAMA(ER=30, Fast=3, Slow=60)**, Donchian 20, risk 2%; `SC=(ER·(FastSC−SlowSC)+SlowSC)²`
- sizing: 2% risk, ATR stop → lot auto-scale; SnowBall(compound) vs ZeroRisk(fixed) toggle
- backtest BTC 8h 2018-2025: PF 2.31, 105 trades, WR 35%, MaxDD 20.5% (แต่ compound mode intrabar DD 116%!)
- **⭐ novel lever = KAMA (continuous adaptive-MA)** ≠ regime-gate on/off ของเรา (`_50_Regime.mqh`) +
  ATR dual-use (stop+sizing) → **เพิ่มเป็น KAMA indicator block ใน EDGE_CATALOG** (~15 บรรทัด)
- ⚠️ single BTC long-only 8y thin (37 winners); compound inflate headline; B&H เอาชนะ; ต้อง flat-lot + right-home

### 4. Bollinger Band Breakout With Volatility Stoploss (24น.) — TradingView published
- long-only vol-breakout D1; **BB = EMA(30) ± 1.0 SD** (ไม่ใช่ SMA/2SD)
- entry: Close > Upper → เข้าแท่งถัดไป
- **⭐ VolStop = Lower BB เอง (EMA30−1SD) ของแท่งสัญญาณ, trailing ขึ้นตามแท่งใหม่** (ไม่ใช่ ATR)
  → **ตรงปัญหา SL-fragility ของแล็บ** (SL ปรับตาม vol อัตโนมัติ กว้างตอน vol สูง กัน stop เร็ว)
- exit: Close < Lower band (pending-stop intrabar หรือ conditional close-next-open)
- **sizing: `PositionSize% = RPT% × 100 / VolStop%`** (RPT default 3%); Gear-Up vs Fixed-Equity
- ไม่โชว์ PF/DD/n (author ไม่เปิดเผย); WR ~35-40% by design
- **buildable ครบเป็น MT5 breakout EA** (spec ใน result เต็ม); momentum → home = XAU/GBP/BTC trender
- ⚠️ single BTC long-only since 2018 (secular bull); RPT 3% aggressive; ไม่ใช่ martingale (มี SL) = parametric

### 5. Bollinger Band 101 (142น.) — คอร์สรวม (theory 60% + 4 ระบบทับตัวอื่น)
- **portable ideas:** (a) **volatility-normalized sizing `size% = RPT%/band-dist%`** (reusable สุด →
  LOG-lot/risk module) (b) EMA-band 1σ breakout (=ระบบ 4) (c) **BandWidth เป็น regime thermometer**
  (high=expansion, low=squeeze) (d) **ตาราง S.D.→lever:** ±1σ=breakout/trend · ±2σ=MR/DCA/grid ·
  ±3σ=ลด leverage · ±4σ=hedge (+ lookback pairing ±1/2σ→20-30d, ±3σ→60-90d, ±4σ→260-365d)
- BandWidth 6-month-low squeeze = entry-gate lever
- ยืนยัน grid System-4 = **capped martingale ×1.2/×1.5** (uncapped เกิน −4σ = black-swan hole)
- ⚠️ backtest single-BTC self-report, PF 5 แต่ Sharpe 0.16, n ต่ำ (32/39)

### 6. Closed System 101 (73น.) — bounded ATR grid (Tickmill collab)
- "Closed" = decision loop ปิด (rule ล้วน ไม่มี discretionary) — ไม่ใช่ Mudley risk+cash portfolio
- ระบบ tradeable เดียว (Ep11-12) = **bounded ATR grid บน BTC**: band ±3×ATR weekly re-compute,
  20 rung, geometric, **60% deploy / 40% cash, max 3 position, ไม่ escalate (adds pre-funded)**
- risk: fixed-frac ≤1%/trade, MaxDD cap 20%, **RoR<1% verify ด้วย MC 10k runs** (มี MC ที่นี่!), pause −10%
- **⭐ novel = grid band หายใจตาม vol (weekly ATR re-anchor) + hard 60/40 cash + 3-pos cap = non-escalating**
- return claim 2-3%/เดือน, 4-5%/2wk = **course-ad เชื่อไม่ได้** (course 5,900฿, ไม่มี equity curve/OOS)
- **reusable → EDGE_CATALOG:** non-escalating ATR-adaptive bounded-grid + weekly re-anchor + cash/pos cap
- ⚠️ weekly re-anchor อาจ ratchet loss (re-center ตอนราคาตก = rebalance เข้า downtrend); AI-filler เยอะ

### 7. DCA Strategy w/ Mean-Reversion + Bollinger blueprint (21น.) — พิมพ์เขียว
- accumulation-only: **BB EMA(200) 4h ±2SD** (≈1 เดือน; alt 30/Daily); close < lower band → ซื้อแท่งถัดไป
  + ซื้อรายเดือนวันที่ 2 (Combined mode)
- **lot FLAT 100 USD/signal ไม่ scale ตาม dip depth** (ปลอดภัย ไม่ ruin)
- **ไม่มี exit/SL/TP** — hold ตลอด (ปิดหมดวันเดียวเพื่อคำนวณ PnL เท่านั้น)
- backtest BTC 2018-2025: +645% แต่ **แพ้ B&H (713%)** = dip-timing ไม่เพิ่ม net · "127-0 win" = artifact
- **concept only:** statistical-band dip accelerator บน calendar DCA → เก็บ EDGE_CATALOG, ต้อง A/B band-trigger
  vs plain-DCA พิสูจน์ว่าเพิ่มค่าไหม; crypto spot-accumulation ไม่ใช่ P&L trader

### 8. MACD อย่างโปร (13น.) — ❌ NO EDGE (skip)
- จริงๆ = EMA 12/26 + ATR VolStop (MACD-zero-cross = EMA12/26 cross ทางคณิต) + Basic DCA
- momentum ตำรา เราฆ่าไปหลายรอบ; เก็บได้แค่ SnowBall/ZeroRisk toggle (compound vs fixed)
- underperform B&H ในโชว์ตัวเอง; single BTC long

### 9. DCA Insight (113น.) — Dynamic DCA + Core&Satellite
- 12-episode series: plain DCA → free indicator "DCA Strategy" (3 modes) → **grid-funded DCA**
- **"dynamic" จริงๆ = conditional TIMING ไม่ใช่ variable sizing** — buy amount FLAT $100 ทุก backtest
  (Ep.7 พูดเรื่อง "อัดหนักตอนถูก" แต่ไม่เคย code จริง; VCA name-drop เฉยๆ)
- trigger: BB **EMA200/4h ±2SD**, close < lower → buy ≤1×/เดือน; variant = SMA120 weekly buy-dip
- recurring: OKX bot "$10×3/day"; **fundamental stoploss** (hold จนกว่า fundamental เสีย, ไม่ sell ตามราคา)
- **⭐ novel = "grid-funded DCA / Core&Satellite" (Ep.11):** รัน grid bot (grid ~25%/yr, ~2%/เดือน cashflow)
  → หมุนกำไร grid เข้า **ETF DCA book (VOO/VOOG core)** = "free-money DCA" (capital routing overlay)
- **fee myth-buster:** fee = **0.1% × notional, ไม่ขึ้นกับจำนวน order** (split ถี่ = fee รวมเท่าเดิม);
  **เลข 0.015% ที่เพจเคลม ไม่มีในสไลด์** (สไลด์ใช้ 0.1%) → treat as unverified
- backtest: Combined +645% (แพ้ B&H 713%); daily DCA CAGR 30.66% แต่ **DD 71.37%**; "100% win" = artifact
- **genuinely new สำหรับเรา 2 อย่าง:** (1) **fee-cost model เป็น backtest input ชั้นหนึ่ง** (notional taker +
  crypto swap/funding drag ที่ backtest มองข้าม — cross-ref BTC-long swap −14.67%/yr) (2) **grid→DCA rotation**
  (portfolio plumbing: route validated grid cash เข้า low-corr accumulator ผ่าน exposure tooling ของเรา)
- ⚠️ "dynamic" oversell (flat size จริง); triggers = reversion ธรรมดา covered; grid claims Model-2-prone; course funnel

---

## 📚 อีก 11 PDF (folders 1-4) = ทฤษฎี/portfolio background — ไม่เจาะลึก (ไม่ใช่ระบบ build ได้)
> ตัดสินใจ (Opus): ไม่ render+extract เพราะเป็นทฤษฎีการลงทุน/ปรัชญา ไม่ใช่ mechanical EA + กัน context.
> ถ้าอนาคตต้องการ lever เฉพาะ (เช่น Risk-Parity weighting) ค่อยเจาะรายไฟล์.
- **1_general:** วัฏจักรตลาด (53น. market cycles) · ว่าด้วยฟิวเจอร์ (112น. futures/derivatives พื้นฐาน)
- **2_papers:** Vanguard Principles (88น. Bogle passive/index) · All Weather/Risk Parity Bridgewater
  (36น. — risk-parity weighting = มีใน IDEA SEEDS #6 quantcorner แล้ว) · The Great Monetary Inflation (15น. macro)
- **3_closedsystem:** Mudley Live by Jatuphon vol.1+2 (207+186น. — ปรัชญาเทรดสาย Mudley ไทย, discretionary
  เป็นหลัก → [[feedback-discretionary-showtrade-not-mechanical]] ระวัง encode)
- **4_portfolio:** Security Market Line 101 (50น. CAPM/beta — ไม่ตรง EA) · การจัดพอร์ทฉบับแอด (123น.) ·
  การลงทุนเทรดอย่างเป็นระบบ 101 (47น.) · รวมซีรีส์ทุ่มสุดไม่ให้หมดตัว (56น. = risk-of-ruin/sizing, overlap ข้อ 1/3/9)

## 🧭 LEAD TRIAGE — actionable-new หลัง dedup vs แล็บ (Opus)

**ธีมซ้ำที่ทุกเด็คชี้ตรงกัน = "grid zone/spacing/sizing ที่ scale ตาม volatility + สถิติ" แทน fixed naive:**

1. **🏆 MC block-bootstrap grid zone (P10/P90)** [Adaptive Grid] — lever ใหม่จริง, แล็บตั้ง grid step แบบ
   naive; นี่คือ statistical zone. Build path: offline Python MC ใน `_mt5_auto` → feed P10/P90 + 0.3ATR เป็น
   `.set`. ตรงกับ QuantCorner catalog #1 (MC+bootstrap+ATR) ที่เคยจดว่า "ยังไม่แตะ"
2. **geometric constant-% grid spacing** [Dynamic Grid] — `ratio=(hi/lo)^(1/N)`, แทน fixed-step
3. **volatility-normalized sizing `size% = RPT%/band-dist%`** [BB101 + BB-Breakout] — ตรง SL-fragility
4. **Lower-BB-as-trailing-VolStop** [BB-Breakout] — ตรงปัญหา SMCxSTO 991070 SL-fragility (Lane C)
5. **KAMA continuous adaptive-MA block** [Adaptive Revolution] — ≠ regime-gate on/off, lever ใหม่
6. **inverse-ATR anti-martingale lot** [Adaptive Grid] — `lot = base×baseATR/curATR`
7. **BandWidth-as-regime + S.D.→lever table** [BB101] — เสริม regime framework
8. **non-escalating bounded-grid + weekly ATR re-anchor + cash/pos cap** [Closed System]
9. **Maker/Post-Only fee discipline + spot-asset เลี่ยง swap** [Adaptive Grid] — cost model (crypto lane)
10. **fee-cost model เป็น backtest input ชั้นหนึ่ง** [DCA Insight] — notional taker + crypto swap/funding drag
    ที่ backtest มองข้าม (ตรง gotcha crypto lane BTC-long swap −14.67%/yr)
11. **grid→DCA rotation (Core&Satellite capital routing)** [DCA Insight] — portfolio plumbing: หมุน grid cash
    เข้า low-corr accumulator (ใช้ exposure/corr tooling ที่มี)

### 🎯 ผมแนะนำ (1 ทางเด็ดขาด): build **Adaptive Grid (MC-zone)** เป็น probe ตัวแรก
เหตุผล: (1) เป็น lever ใหม่จริงที่ QuantCorner catalog เคยจดว่า "ยังไม่แตะ" (2) spec ครบ buildable
(3) structural ปลอดภัย (flat lot + capped + −20% kill ≠ martingale) (4) fit crypto lane ที่ validate แล้ว
(TrendRider ORDER-125). Build path = offline Python MC block-bootstrap ใน `_mt5_auto` → P10/P90 + 0.3ATR
→ `.set` → grid EA บน BTC/ETH CFD. รวม lever #3 (geometric spacing) + #6 (inverse-ATR lot) + #10 (fee/swap model).
levers อื่น (Lower-BB-VolStop #4, KAMA #5, vol-normalized sizing #3) = เก็บเป็น standalone probe ต่อยอด SMCxSTO
SL-fragility + trender family. **ทั้งหมดต้องผ่าน VERDICT GATE + BWD hard-gate ก่อน verdict ใดๆ.**

---

## 📌 FB post scan (2026-07-19, login) — นอกเหนือจาก PDF

**FINDYOUR8 timeline:** = โพสต์ปักหมุด (คลาส 101 ขุดครบ) + โพสต์ส่วนตัว (ดนตรี ไม่เกี่ยว) + mirror
Blockdit (07-18 อ่านครบ 7 โพสต์). ไม่มีเนื้อ trading ใหม่เกินคลัง PDF.

**QuantCorner (facebook.com/quantcornerthailand, 1.7万):** = ชุมชน quant analyst (Discord + Meetup),
tagline "EVIDENCE OVER INTUITION", ชี้ quant-corner.com (07-18 ขุด 16 บทความครบแล้ว). โพสต์เด่น =
**event "AI BATTLE IN FINANCE" 22 ส.ค. 2026 @Glofish สาธร** — ตรง stack EA_LAB:
- **AI BATTLE: Claude Code vs Codex vs Claude Cowork** (workflow ประชันสด แก้โจทย์การเงิน)
- **"Alpha Pipeline with Loop Engineering"** (Nutdanai Wangpratham CQF): Idea→Data→Factor→Backtest
  →Evaluation→Improvement ด้วย Codex + loop — คุม Data Leakage/OOS/Transaction Cost/Risk (= LADDER+
  VERDICT GATE ของเราเป๊ะ) · **"Replicate Investment Process with AI Agent"** (Powered by Codex)
- มี **Claude Thailand Community** (Co-Founder ผศ.ดร.ธรรณพ อารีพรรค) · ลงทะเบียน forms.gle/5thUhfkmZ77KWiiZA
- 💡 relevance: นี่คือมุม "AI เทรดเอง" ที่ user สนใจ — ชุมชนไทยทำ AI-for-investing ด้วย stack เดียวกับ EA_LAB;
  น่าติดตาม/ไปงาน + อาจได้ pattern การจัด Alpha pipeline เทียบกับของเรา

**ไม่ actionable:** MACD (momentum ตำรา), DCA blueprint (แพ้ B&H, spot-accum ไม่ใช่ trader),
Recovery-Zone martingale (Dynamic Grid overlay), BB grid System-4 (uncapped เกิน −4σ).

**หมายเหตุ dedup:** momentum-class ไม่มี signal ใหม่ (KAMA = adaptive filter ไม่ใช่ signal); ทั้งหมดเป็น
**grid/DCA/vol-sizing/exit levers** — catalog นี้ให้ **lever ต่อยอด ไม่ใช่ edge signal ใหม่** (เหมือน QuantCorner).
บ้านของทุกระบบ = crypto spot; port มา MT5 FX/CFD ต้องคิด swap ที่เด็คเลี่ยง.
