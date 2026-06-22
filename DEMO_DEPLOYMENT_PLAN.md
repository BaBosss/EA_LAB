# Demo Deployment Plan — Portfolio v3
อัพเดท: 2026-06-22 | สถานะ: 🟢 RUNNING — ทั้ง 8 EA deploy แล้วบน 10,000 cent account เดียว

> **Live clock เริ่ม 2026-06-22** — judge ได้เร็วสุด **2026-09-22** (3 เดือน)
> ทุก EA อยู่บน **account เดียวกัน** (10,000 cent = $100 USD equivalent)

> ⚠️ **ตรวจ ST_EA03 ด่วน** — Lots_divided=10,000,000 บนบัญชี 10,000 cent
> → lot คำนวณได้ = 10,000 ÷ 10,000,000 = **0.001 ต่อ leg** ซึ่งต่ำกว่า min lot 0.01
> → EA 3 (GBPUSD) และ EA 4 (USDCAD) **อาจไม่เทรดเลย**
> ตรวจใน MT5 Experts log: ถ้าเห็น "Invalid lot" หรือ 0 trades → ต้องแก้ Lots_divided

---

## ภาพรวม EA ทั้งหมด (10,000 cent — account เดียว)

| # | EA | Symbol | TF | Set File | OOS PF | Status | หมายเหตุ |
|---|---|---|---|---|---|---|---|
| 1 | Matchagrid (MG_v1) | CHFJPY | M15 | `MG_CHFJPY_v1_locked.set` | 2.08 | 🟢 LIVE | fixed 0.01 lot ✅ |
| 2 | NuiIndy RSI+ADX | EURUSD | H1 | `NuiIndy_EURUSD_robust.set` | 2.00 | 🟢 LIVE | 10k/500k = 0.02 lot ✅ |
| 3 | ST_EA03 MACD | GBPUSD | H1 | `MACD_GBPUSD_locked.set` | 2.47 | ⚠️ VERIFY | 10k/10M = 0.001 < min → อาจไม่เทรด |
| 4 | ST_EA03 MACD | USDCAD | H1 | `MACD_USDCAD_locked.set` | 2.62 | ⚠️ VERIFY | เหมือน EA 3 |
| 5 | Gold Reaper 4.3 | XAUUSD | H1 | `GoldReaper_cent_v1.set` | 2.07 | 🟢 LIVE | StartLots=0.01 ✅ |
| 6 | EA_BREAKOUT_XAU | XAUUSD | H1 | `_vps_deploy\BRK_XAU_live_v2.set` | 1.77 | 🟢 LIVE | BUY-only 0.01 lot ✅ |
| 7 | LondonConsoBreakout | GBPUSD | H1 | `_vps_deploy\CB_GBP\CB_GBP_H1_live_v1.set` | 2.08 | 🟢 LIVE | 0.01 lot ✅ |
| 8 | LondonConsoBreakout | EURUSD | H1 | `_vps_deploy\CB_EUR\CB_EUR_H1_live_v1.set` | 1.25 | 🟢 LIVE ⚠️ | CONDITIONAL 0.01 lot |

**Promote conditions (กลุ่ม B → portfolio):**
- ≥30 real trades ผ่านไป
- PF ≥ 1.40 จาก live trades
- ไม่ถึง stop rule → promote เข้า Core พร้อมปรับขนาด

**Stop rules กลุ่ม B:**
- EA 6: ถ้า XAU กลับเป็น bear trend ยาว → review BUY-only bias
- EA 7: pause ถ้า DD > 1.5% หรือ 10 consecutive losses — เพิ่ม risk เป็น 1% หลัง 30 trades pass
- EA 8: pause ถ้า monthly DD > 1% หรือ 10 consecutive losses — **อย่าเพิ่ม lot**

---

## Account Setup

- **Account: 10,000 cent** (= $100 USD equivalent) — deploy 2026-06-22
- EA 1–5: `.set` อยู่ใน `D:\EA_LAB\_mt5_auto\`
- EA 6–8: `.set` อยู่ใน `D:\EA_LAB\_vps_deploy\` (แต่ละ subfolder)
- Leverage: ตามที่ broker กำหนด, Account type: Hedge

---

## Lot Sizing

| EA | Lot บน 10,000 cent | สถานะ |
|---|---|---|
| MG_v1 CHFJPY | 0.01 (fixed) | ✅ |
| NuiIndy EURUSD | 10k ÷ 500k = **0.02** | ✅ |
| ST_EA03 GBPUSD | 10k ÷ 10M = **0.001/leg** × 3 | ❌ ต่ำกว่า min 0.01 → ตรวจด่วน |
| ST_EA03 USDCAD | เหมือนกัน | ❌ ต่ำกว่า min 0.01 → ตรวจด่วน |
| Gold Reaper | StartLots=0.01 | ✅ |
| EA_BREAKOUT_XAU | 0.01 (fixed) | ✅ |
| CB_GBP GBPUSD | 0.01 (fixed) | ✅ |
| CB_EUR EURUSD | 0.01 (fixed) | ✅ |

**แก้ ST_EA03 ถ้า lot ต่ำกว่า min:** เปลี่ยน `Lots_divided` จาก 10,000,000 → **100,000**
→ 10k ÷ 100k = 0.1 cent lot/leg × 3 = 0.3 (conservative แต่ trade ได้)

---

## Magic Numbers (ห้ามซ้ำ)

| Magic | EA |
|---|---|
| 1524 | NuiIndy EURUSD |
| 9397 | ST_EA03 GBPUSD |
| 9398 | ST_EA03 USDCAD |
| (default) | Gold Reaper — ตรวจจาก GUI ก่อน attach |
| 990005 | LondonConsoBreakout (ทั้ง GBPUSD + EURUSD — OK เพราะ filter by _Symbol) |
| 991001 | EA_BREAKOUT_XAU |

---

## Expert Names (MT5 Navigator)

| EA | Expert name |
|---|---|
| Matchagrid | `Matchagrid` |
| NuiIndy | `(NuiIndy) Dynamic RSI+ADX Style (4)` |
| ST_EA03 | `(ST) EA03 Count MACD v1` |
| Gold Reaper | `The Gold Reaper MT5_4.3_fix_@FundedMillionAiress` |
| EA_BREAKOUT_XAU | `EA_BREAKOUT_XAU` |
| LondonConsoBreakout | `(Boss)_LondonConsoBreakout_rev01` |

---

## Monitoring Checklist (รายสัปดาห์)

### กลุ่ม A

| EA | หยุดถ้า | Action |
|---|---|---|
| MG_v1 | Live DD > 35% | Close all MG positions |
| NuiIndy | Live DD > 20% | Review params |
| MACD GBPUSD/USDCAD | PF < 1.0 ใน 30 วัน | Pause + review |
| Gold Reaper ⚠️ | DD > 25% **หรือ** PF < 1.2 ใน 30 วัน | Pause ทันที |
| ทุก EA | ไม่มี trade 2 สัปดาห์ | ตรวจ AutoTrading / connection |

### กลุ่ม B

| EA | หยุดถ้า | เพิ่ม risk ถ้า |
|---|---|---|
| EA_BREAKOUT_XAU | XAU bear trend ยาว | 30 trades, PF ≥ 1.40 |
| CB_GBP GBPUSD | DD > 1.5% หรือ 10 consec loss | 30 trades, PF ≥ 1.40 → เพิ่มเป็น 1% |
| CB_EUR EURUSD ⚠️ | Monthly DD > 1% หรือ 10 consec loss | **ไม่เพิ่ม lot** — conditional ถาวร |

---

## Timeline

| วันที่ | Milestone |
|---|---|
| 2026-06-22 | **ทั้ง 8 EA deploy แล้ว** บน 10,000 cent account เดียว |
| 2026-06-22 (เร่งด่วน) | ตรวจ ST_EA03 lot size — แก้ถ้าไม่เทรด |
| 2026-09-22 | ครบ 3 เดือน → judge ทุก EA พร้อมกัน |
| หลัง judge | EA ที่ผ่าน (PF ≥ 1.40, ≥30 trades) → เพิ่ม port หรือเพิ่ม lot |

---

## ต่อไปหลัง 3 เดือน

1. รัน per-EA attribution script (parse history by magic) → ดูว่า EA ไหนกำไร/ขาดทุน
2. ถ้ากลุ่ม A ผ่าน → live บน cent $100/port (ปรับ ST_EA03 Lots_divided ก่อน)
3. ถ้ากลุ่ม B ผ่านเงื่อนไข → merge เข้า Core portfolio
4. ถ้า MG_v1 DD สูงเกิน → พิจารณา drop + หา replacement correlation ต่ำ

---

## EA_CORE_V1 — งานต่อ

**Phases A–J: เสร็จแล้ว** (framework validated, signals v2-v4, LotSizer, ScaleExecutor v1)

**Part B ScaleExecutor (planned):** implement pending/limit order pyramid แบบ ST_EA03
- Phase I (simultaneous market open) = PF 0.84 LOSING → dead end
- Root cause: ST_EA03 ใช้ Nearby_PIP PENDING order stagger → legs fill เมื่อราคาเคลื่อน
- Next: เปลี่ยน `ScaleExecutor_v1` ให้ส่ง ORDER_TYPE_BUY_LIMIT/SELL_LIMIT แทน market
- Target: reproduce ST_EA03-level PF >> 1.11 บน GBPUSD/USDCAD H1
- ⚠️ Model 4 required (TP < 20 pip trigger)
