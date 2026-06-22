# Demo Deployment Plan — Portfolio v2
อัพเดท: 2026-06-22 | สถานะ: 🟢 RUNNING — AutoTrading เปิดแล้ว 2026-06-22

> **Demo clock เริ่ม 2026-06-22** — promote to live ได้เร็วสุด **2026-09-22** (3 เดือน)
> VPS candidates (EA 6-8) deploy คืน 2026-06-22 — แยกจาก demo ThinkMarkets

---

## ภาพรวม EA ทั้งหมด

### กลุ่ม A — Portfolio Core (ThinkMarkets Demo $10,000)
*5 EA confirmed, รันอยู่ตั้งแต่ 2026-06-22*

| # | EA | Symbol | TF | Set File | OOS PF | OOS DD | MC PF5th | Status |
|---|---|---|---|---|---|---|---|---|
| 1 | Matchagrid (MG_v1) | CHFJPY | M15 | `MG_CHFJPY_v1_locked.set` | 2.08 | 23.8% | 1.755 | ✅ CONFIRMED / LIVE |
| 2 | NuiIndy RSI+ADX | EURUSD | H1 | `NuiIndy_EURUSD_robust.set` | 2.00 | 28.9% | 1.67 | ✅ CONFIRMED / LIVE |
| 3 | ST_EA03 MACD | GBPUSD | H1 | `MACD_GBPUSD_locked.set` | 2.47 | 5.1% | 2.06 | ✅ CONFIRMED / LIVE |
| 4 | ST_EA03 MACD | USDCAD | H1 | `MACD_USDCAD_locked.set` | 2.62 | 6.3% | 2.15 | ✅ CONFIRMED / LIVE |
| 5 | Gold Reaper 4.3 | XAUUSD | H1 | `GoldReaper_cent_v1.set` | 2.07 | 24.2% | 1.331 | ✅ CONFIRMED / LIVE ⚠️ |

⚠️ Gold Reaper: MC ruin 1.9% (ตัวเดียวในพอร์ตที่ > 0%) — pause ถ้า live DD > 25% หรือ PF < 1.2 ใน 30 วัน

### กลุ่ม B — Candidates on VPS (แยกต่างหาก — deploy คืน 2026-06-22)
*3 EA ใหม่ บน VPS แยก — รอ ≥30 real trades ก่อน judge*

| # | EA | Symbol | TF | Set File | OOS PF | Status | Risk rule |
|---|---|---|---|---|---|---|---|
| 6 | EA_BREAKOUT_XAU | XAUUSD | H1 | `BRK_XAU_live_v2.set` | 1.77 (M4) | 🟡 VPS pending | BUY-only, monitor regime |
| 7 | LondonConsoBreakout | GBPUSD | H1 | `CB_GBP_H1_live_v1.set` | 2.08 | 🟡 VPS pending | 0.5% risk — GBP concentration |
| 8 | LondonConsoBreakout | EURUSD | H1 | `CB_EUR_H1_live_v1.set` | 1.25 | 🟡 VPS pending ⚠️ | CONDITIONAL — EUR bear risk |

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

### กลุ่ม A — ThinkMarkets Demo
- Deposit: **$10,000 USD** — ตรงกับ backtest deposit (lot sizing ถูกต้องโดยอัตโนมัติ)
- Leverage: 1:100, Account type: Hedge

### กลุ่ม B — VPS (แยกต่างหาก)
- Bundle อยู่ใน `D:\EA_LAB\_vps_deploy\`
- Deploy steps ดู README ใน folder แต่ละตัว

---

## Lot Sizing

### กลุ่ม A — $10,000 USD demo

| EA | Lot per signal | หมายเหตุ |
|---|---|---|
| MG_v1 CHFJPY | 0.01 (fixed) | grid DD backtest×2-3 บน live |
| NuiIndy EURUSD | 0.02 ($10k/500k) | dynamic, scales กับ equity |
| MACD GBPUSD | 0.003 (0.001×3 legs) | conservative ตั้งใจ |
| MACD USDCAD | 0.003 | เหมือนกัน |
| Gold Reaper | StartLots=0.01 | cent set |

### กลุ่ม B — VPS
- EA 6, 7, 8: ทั้งหมด LotSize=0.01 (fixed, standalone)

### ⚠️ Cent account (10,000 cent = $100) — ถ้าจะย้ายไป live
- ST_EA03 (EA 3, 4): Lots_divided=10,000,000 → บน 10k cent = 0.001/leg = ต่ำกว่า min lot ❌
- **ต้องปรับ**: เปลี่ยน Lots_divided เป็น **100,000** → ได้ 0.1 cent lot/leg (conservative)
- EA อื่น (fixed 0.01): ใช้ได้บน cent โดยตรง ✅

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
| 2026-06-22 | Demo กลุ่ม A เริ่ม (AutoTrading ON) |
| 2026-06-22 (คืน) | VPS กลุ่ม B deploy |
| 2026-09-22 | กลุ่ม A ครบ 3 เดือน → judge live |
| 2026-09-22+ | กลุ่ม B judge (ถ้า ≥30 trades ถึงแล้ว) |
| หลัง judge | Live บน cent account $100/port, เป้า 10 ports |

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
