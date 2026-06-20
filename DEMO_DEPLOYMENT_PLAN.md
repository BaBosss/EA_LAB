# Demo Deployment Plan — Portfolio v1
อัพเดท: 2026-06-20 | สถานะ: ✅ MC VALIDATED — READY TO DEPLOY (5 EA: 4 CONFIRMED + 1 CONDITIONAL)

---

## Portfolio Summary

| # | EA | Symbol | TF | Set File | OOS PF | OOS DD | MC PF5th | MC DD95th | MC ruin | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Matchagrid (MG_v1) | CHFJPY | M15 | `MG_CHFJPY_v1_locked.set` | 2.08 | 23.8% | 1.755 | n/a | 0% | ✅ CONFIRMED |
| 2 | NuiIndy RSI+ADX | EURUSD | H1 | `NuiIndy_EURUSD_robust.set` | 2.00 | 28.9% | **1.67** | 6.4% | 0% | ✅ CONFIRMED |
| 3 | ST_EA03 MACD | GBPUSD | H1 | `MACD_GBPUSD_locked.set` | 2.47 | 5.1% | **2.06** | 1.3% | 0% | ✅ CONFIRMED |
| 4 | ST_EA03 MACD | USDCAD | H1 | `MACD_USDCAD_locked.set` | 2.62 | 6.3% | **2.15** | 0.9% | 0% | ✅ CONFIRMED |
| 5 | Gold Reaper | XAUUSD | H1 | default params (no .set) | 1.53 | 17.3% | **1.331** | n/a | 1.9% | ⚠️ CONDITIONAL |

MC รัน 2026-06-18 — 2000 bootstrap permutations, ruin threshold DD>50%
Correlation flag: MG_v1 × MACD_GBPUSD = 0.768 HIGH (CHF/GBP correlate) — ยอมรับได้ที่ equal weight
Gold Reaper (#5): **anti-correlated กับ FX EA ทั้งหมด** (-0.357/-0.161/negative) → natural hedge. รวม 5 EA: combined max DD 6.83%, mean return 4.73%/เดือน, Gold×FX severe-DD overlap แค่ 8.3%.
Freshness check 2026.01-04: PF=7.74 DD=3.12% 110 trades — alive ในตลาดล่าสุด

> **⚠️ Gold Reaper = CONDITIONAL:** MC ruin 1.9% (ตัวเดียวที่ > 0% ในพอร์ต) + เป็น downloaded commercial EA → deploy เป็น "satellite" position ดู demo ใกล้ชิด ถ้า DD จริง > 25% หรือ PF < 1.2 ใน 30 วัน → pause ทันที

---

## Account Setup

**Demo account: ThinkMarkets**
- เปิด demo account ใหม่ที่ ThinkMarkets (แยกจาก live)
- Deposit: **$10,000 USD** (demo) — ตรงกับ backtest deposit พอดี ไม่ต้องแก้ params เพิ่ม
  - เหตุผล: MACD ใช้ Lots_divided=10,000,000 → บน $10k ได้ lot=0.001×3=0.003 ต่อ signal
  - ถ้าใช้ $1,000 → lot ต่ำกว่า minimum 0.01 ของ broker
- Leverage: 1:100 (ตามที่ backtest ใช้)
- Account type: Hedge (รองรับ multiple EAs บน symbol เดียวกัน)

---

## Lot Sizing (บน demo $10,000 — ตรงตาม backtest)

| EA | Param | Lot per signal | หมายเหตุ |
|---|---|---|---|
| MG_v1 CHFJPY | InpLotStart=0.01 | **0.01** (fixed) | grid เปิดหลายออเดอร์, equity DD = backtest×2-3 |
| NuiIndy EURUSD | Lot_Divided=500,000 | **0.02** ($10k/500k) | dynamic, scales กับ equity |
| MACD GBPUSD | Lots_divided=10,000,000 × LOT_Repeat=3 | **0.003** (0.001×3) | เล็กมาก — ตั้งใจให้ conservative |
| MACD USDCAD | เหมือน GBPUSD, MagicStart=9398 | **0.003** | MagicStart ต่างกันเพื่อไม่ชน |
| Gold Reaper XAUUSD | **default params** | ⚠️ ต้องยืนยันจาก GUI | EA ใช้ default ตอน backtest; lot/risk param ต้องอ่านจาก MT5 Navigator ก่อน attach — ดู "Gold Reaper param TODO" ด้านล่าง |

> **Gold Reaper param TODO (ก่อน attach):** Gold Reaper เป็น downloaded commercial EA — backtest รันด้วย default params ล้วน (TesterInputs ว่าง) และ headless log ไม่ echo ค่า default ออกมา จึง**อ่าน lot/risk setting ไม่ได้แบบ headless** ต้องเปิด EA ใน MT5 (drag ลง chart → Inputs tab) เพื่อยืนยัน:
> 1. Money-management mode (fixed lot หรือ risk-% ?) — ถ้า risk-% จะ scale กับ $10k เอง; ถ้า fixed lot ต้องเช็คว่าไม่ใหญ่เกินสำหรับ $10k demo
> 2. ค่า lot/risk default ที่จะใช้
> 3. Magic number default (ต้องไม่ชน 1524/9397/9398 ของ EA อื่น — ถ้าชนให้ตั้งใหม่)
> **cent set (`GoldReaper_XAUUSD_cent.set`) ยังไม่สร้าง** — รออ่าน param จาก GUI ก่อน แล้วค่อยทำตอนเตรียม live cent (หลัง demo 3 เดือน)

> **คำเตือน MG_v1:** backtest DD=23.8% → live DD est **48–71%** (grid×2-3)
> บน $10k demo: worst case DD ≈ $2,380–$7,100 — monitor ใกล้ชิด
> สำหรับ live $100 cent จริง: DD 71% = $71 — ยอมรับได้

---

## Expert Names (MT5 Strategy Tester / Attach)

ต้องยืนยันชื่อจาก MT5 Navigator:

| EA | ชื่อน่าจะเป็น | ต้องยืนยัน |
|---|---|---|
| Matchagrid | `Matchagrid` | ✅ ใช้งานได้ (ผ่าน backtest แล้ว) |
| NuiIndy RSI+ADX | `(NuiIndy) Dynamic RSI+ADX Style (4)` | ✅ ใช้งานได้ |
| ST_EA03 MACD | `(ST) EA03 Count MACD v1` | ✅ ใช้งานได้ |
| Gold Reaper | `The Gold Reaper MT5_4.3_fix_@FundedMillionAiress` | ✅ ใช้งานได้ (ผ่าน backtest แล้ว) |

---

## Deployment Steps

### 1. เปิด MT5 → เปิด demo account
```
File → Open Account → ThinkMarkets → Demo → $10,000 USD
```

### 2. Attach EA ทีละตัว

**EA 1: MG_v1 CHFJPY M15**
```
Chart: CHFJPY M15
EA: Matchagrid
Inputs: Load _mt5_auto/MG_CHFJPY_v1_locked.set
AutoTrading: ON
```

**EA 2: NuiIndy EURUSD H1**
```
Chart: EURUSD H1
EA: (NuiIndy) Dynamic RSI+ADX Style (4)
Inputs: Load _mt5_auto/NuiIndy_EURUSD_robust.set
  → Lot_Divided=500000, RSI_Period=18, ADX_period=20, ADX_Value=35, MagicStart=1524
AutoTrading: ON
```

**EA 3: MACD GBPUSD H1**
```
Chart: GBPUSD H1
EA: (ST) EA03 Count MACD v1
Inputs: Load _mt5_auto/MACD_GBPUSD_locked.set
  → Lots_divided=10000000, MACD_Count=2, LOT_Repeat=3, Nearby_PIP=10, MagicStart=9397
AutoTrading: ON
```

**EA 4: MACD USDCAD H1**
```
Chart: USDCAD H1
EA: (ST) EA03 Count MACD v1
Inputs: Load _mt5_auto/MACD_USDCAD_locked.set
  → Lots_divided=10000000, MACD_Count=2, LOT_Repeat=3, Nearby_PIP=10, MagicStart=9398
AutoTrading: ON
```

**EA 5: Gold Reaper XAUUSD H1** ⚠️ CONDITIONAL — satellite position
```
Chart: XAUUSD H1
EA: The Gold Reaper MT5_4.3_fix_@FundedMillionAiress
Inputs: DEFAULT params (ไม่มี .set)
  → ก่อน ON: เปิด Inputs tab ยืนยัน MM mode + lot/risk + Magic ไม่ชน (ดู param TODO ด้านบน)
AutoTrading: ON (หลังยืนยัน param แล้วเท่านั้น)
```

### 3. ตรวจสอบก่อน AutoTrading ON
- [ ] Chart ถูก symbol/timeframe
- [ ] .set loaded ถูกไฟล์ (EA 1-4) / Gold Reaper param ยืนยันจาก GUI แล้ว (EA 5)
- [ ] Lot size สมเหตุสมผล (0.01–0.05 range)
- [ ] Magic number ไม่ซ้ำกันระหว่าง EAs (1524 / 9397 / 9398 / Gold Reaper default)
- [ ] AutoTrading enabled (ปุ่มสีเขียวบน toolbar)

---

## Monitoring Checklist (รายสัปดาห์)

| ตรวจสอบ | เกณฑ์ | Action |
|---|---|---|
| MG_v1 DD | >35% live → หยุดชั่วคราว | Close all MG positions |
| NuiIndy DD | >20% live | Review params |
| MACD GBPUSD/USDCAD | PF < 1.0 ใน 30 วัน | Pause + review |
| Gold Reaper (⚠️) | DD > 25% live **หรือ** PF < 1.2 ใน 30 วัน | Pause ทันที (CONDITIONAL — เกณฑ์เข้มกว่าตัวอื่น) |
| ทุก EA | ไม่มี trade ใน 2 สัปดาห์ | ตรวจสอบ AutoTrading / connection |

---

## Demo Duration

**ขั้นต่ำ 3 เดือน** ก่อน live จริง — โดยเฉพาะ MG_v1 (grid) ต้องเห็น drawdown cycle จริง

---

## ต่อไปหลัง Demo

1. ถ้า 3 เดือนผ่าน → live บน cent account $100 ต่อ port
2. ถ้า MG_v1 DD สูงใน demo → พิจารณา drop + หา replacement ที่ correlation ต่ำกับ MACD
3. เป้าหมายระยะยาว: 10 ports × $100 = $1,000 total live
