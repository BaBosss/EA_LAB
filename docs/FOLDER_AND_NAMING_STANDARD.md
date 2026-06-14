# FOLDER & NAMING STANDARD (proposed) — 2026-06-14

> แก้ปัญหา "ไฟล์เยอะ ชื่อมั่ว โฟลเดอร์เยอะ + งงเวอร์ชัน (risk_cap vs normal)".
> ใช้กับงานใหม่ทันที · ของเก่าค่อยๆ migrate ตอนแตะ (ไม่ rename ทุกอย่างทีเดียว)
> ต่อยอดจาก naming scheme ใน handoff 02 + RECOVERED_PLATFORM_DESIGN.

---

## 1. EA Code (ชื่อสั้นประจำตัว EA — ใช้เป็นรากของทุกชื่อ)

| EA | Code |
|---|---|
| Gold SMC Continuous (XAU) | `GSMC` |
| GoldenEmber / Boss Pivot (NZDUSD) | `GEP` |
| Matchagrid (grid) | `MGRD` |
| EX197 (GBPJPY) | `EX197` |
| EURGBP / EURCAD / AUDCAD … (ตอน promote) | `EURGBP` / `EURCAD` / … |

กฎ: 1 strategy = 1 code ตายตัว เปลี่ยนไม่ได้

## 2. เวอร์ชัน/variant (ตัวแก้ปัญหา risk_cap vs normal โดยตรง)

รูปแบบ: **`<EA_CODE>_<variant>_v<N>`**

| variant | หมายถึง |
|---|---|
| `base` | ตัวต้นฉบับ ยังไม่แก้ |
| `riskcap` | แก้ให้ DD ลด (risk cap) |
| `mm` | ปรับ money management |
| `<อื่นๆ>` | ตั้งสื่อความหมาย เช่น `wide`, `tight` |

ตัวอย่าง: `GSMC_base_v1`, `GSMC_riskcap_v1`, `GSMC_riskcap_v2`
→ ทุก .set / report / candidate ของเวอร์ชันนั้นใช้ token นี้เหมือนกัน = **เลิกงงว่าอันไหน risk_cap**

## 3. โครงโฟลเดอร์ต่อ EA (โครงเดียว ใช้ทุกตัว)

```
ea_projects/<EA_CODE>_<ชื่ออ่านง่าย>/
  00_README.md          ← identity: code, magic, symbol, TF, strategy, สถานะ, variant ล่าสุด
  RESULTS.md            ← source of truth: 1 run = 1 แถว (ตัวเลขจาก report จริง)
  source/               ← .mq5 / .ex5
  set/                  ← .set ทั้งหมด (ตั้งชื่อตามข้อ 4)
  reports/
    inbox/  raw/  parsed/  archive/
  optimization/         ← optimizer xml + analyzed
  oos/                  ← OOS / forward single tests
  robustness/           ← monte carlo, verdict
  handoff/NEXT_ACTION.md
```

ลบโฟลเดอร์ซ้ำซ้อน (backup_before_*, nested ขยะ) → ย้ายเข้า `reports/archive/` หรือลบ

## 4. ชื่อไฟล์ (หัวใจที่แก้ความมั่ว)

| ของ | รูปแบบ | ตัวอย่าง |
|---|---|---|
| **.set** | `<EA_CODE>_<variant>_v<N>.set` | `GSMC_riskcap_v1.set` |
| **RunID** | `RUN_<CODE>_<YYYYMMDD>_<NNNN>` | `RUN_GSMC_20260612_0004` |
| **report single** | `<RunID>_<variant>_<Symbol>_<TF>_<IS\|OOS>.<ext>` | `RUN_GSMC_20260612_0004_riskcap_XAUUSD_H1_IS.html` |
| **OptBatchID** | `OPT_<CODE>_<YYYYMMDD>_<NNNN>` | `OPT_GEP_20260610_0001` |
| **optimizer xml** | `<OptBatchID>_<Symbol>_<TF>.xml` | `OPT_GEP_20260610_0001_NZDUSD_H1.xml` |
| **candidate** | `CAND_<CODE>_<Symbol>_<variant>_v<N>` | `CAND_GSMC_XAUUSD_riskcap_v1` |

**กฎเหล็กข้อเดียวที่ฆ่าความมั่ว:** report จาก MT5 (เช่น `ReportTester-146237.html`) **ต้อง rename ตามนี้ทันทีตอนเข้า inbox** ไม่เก็บชื่อ auto ของ MT5

## 5. สถานะ (lifecycle เดียว ใช้ใน RESULTS / registry)

`NEW → IS_VALIDATED → OOS_PASSED → ROBUST_PASSED → PORTFOLIO_TEST → DEMO → LIVE`
(ทางตัน: `REJECTED` / `BLOCKED_OVERFIT`)

## 6. วิธี migrate (ไม่พังของเก่า)
1. งานใหม่ทุกชิ้น = ใช้มาตรฐานนี้
2. EA เก่าค่อย migrate ตอนหยิบมาทำต่อ (ทีละตัว, มี git คุม)
3. ตัวอย่างแรกที่ควร migrate: **Gold SMC** (ตอนนี้ชื่อ `run_004_ReportTester-146237.html` → `RUN_GSMC_20260612_0004_riskcap_XAUUSD_H1_IS.html`)
4. (อนาคต) script ตรวจชื่อ + auto-rename ตอน intake

## 7. กรณี Gold SMC ที่งง (ตัวอย่างปัญหาที่มาตรฐานนี้แก้)
- `EA_CORE_V1_TESTBED` XAUUSD (PF 1.38, DD 10.9%, 447 เทรด) กับ `Gold SMC` (PF 1.31, DD 12.4%, 479 เทรด) = น่าจะ EA เดียวกันคนละ variant (base vs riskcap) แต่ชื่อไม่บอก → **ต้อง re-test ใหม่ให้ชื่อชัด** แล้วลง RESULTS เป็น `GSMC_base_v?` / `GSMC_riskcap_v1` แยกกัน
