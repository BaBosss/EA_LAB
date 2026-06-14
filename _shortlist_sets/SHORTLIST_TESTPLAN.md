# SHORTLIST TEST PLAN — robust-pass .set files (2026-06-14)

> .set สร้างจาก **robust pass** (ไม่ใช่ profit-max) ของ optimizer แต่ละ batch
> โหลดเข้า MT5 → Inputs → Load → รัน **SINGLE test** (Optimization = Disabled) →
> เซฟ report (HTML) + export deals (CSV) ลง EA project inbox → บอก Claude "parse + score"

## ไฟล์ที่สร้างให้

| .set | EA ใน MT5 | Symbol | Override | Robust PF / DD% / RF | ความน่าเชื่อถือ |
|---|---|---|---|---|---|
| `EURCAD_dynamic_robust_v1.set` | Boss - 2 Smart Grid | EURCAD | **10/10** ✓ | 2.33 / 10.6 / 8.2 | ดี (param ครบ) |
| `AUDCAD_robust_v1.set` | Boss - 2 Smart Grid | AUDCAD | **10/10** ✓ | 8.19 / 9.9 / 8.7 | ดี (แต่ PF สูงเว่อร์ ดูเทรด) |
| `AUDNZD_robust_v1.set` | Boss - 2 Smart Grid | AUDNZD | **10/10** ✓ | 2.48 / 12.4 / 4.9 | ดี |
| `GEP_NZDUSD_robust_v1.set` | Boss - 6 Pivot (GoldenEmber) | NZDUSD | 6/8 ⚠️ | 2.44 / 10.6 / 4.9 | partial — เช็คค่าก่อนรัน |
| `EURCAD_robust_v1.set` | Boss - 2 Smart Grid | EURCAD | 5/9 ⚠️ | 2.48 / 10.5 / 6.3 | partial — ใช้ dynamic แทน |

## ⚠️ คำเตือนสำคัญ — พวกนี้คือ Smart Grid family
EURCAD/AUDCAD/AUDNZD = EA grid เดียวกัน (Boss - 2 Smart Grid) คนละ symbol
- **memory เคยเตือนว่า Smart Grid family overfit ง่าย/เคยโดน REJECT** — robust pass + plateau GOOD ช่วยได้ระดับนึง แต่ grid **ซ่อน tail risk** (DD ระเบิดนอก sample)
- **ห้ามเชื่อจนกว่าจะผ่าน OOS + Monte Carlo** (โดยเฉพาะ Monte Carlo prob-of-ruin — grid มักแย่ตรงนี้)
- AUDCAD PF 8.19 / 72 เทรด = PF สูงผิดปกติ + เทรดน้อย → ระวังเป็น fluke
- EURCAD/AUDCAD/AUDNZD เป็น grid เหมือนกันหมด → **correlate กันสูง** เลือกได้ ~1 ตัวต่อพอร์ต ไม่ใช่ทั้ง 3

## วิธีรันแต่ละตัว (ตามดีไซน์ที่กู้มา)
1. MT5 (`D:\Meta 5`) → Strategy Tester → เลือก EA ตามตาราง → Symbol ตามตาราง
2. Modelling: **Every tick based on real ticks** · Optimization: **Disabled**
3. Inputs → Load → เลือก .set จากโฟลเดอร์นี้
4. **IS run:** ช่วง 2-3 ปีล่าสุด (เช่น 2023.06–2026.06) → เซฟ HTML + deals CSV
5. **OOS run:** ช่วงก่อนหน้า (เช่น 2021–2023), .set เดิม เปลี่ยนแค่วันที่ → เซฟแยก
6. วางไฟล์ลง `ea_projects/<EA>/reports/inbox/` แล้วบอก Claude → เข้า pipeline (parse→score→OOS→Monte Carlo)

## ลำดับที่แนะนำให้เทสก่อน
1. **EURCAD_dynamic** (10/10, 598 เทรด, plateau กว้าง 245) = grid ตัวที่ดีสุด
2. **AUDNZD** (10/10, plateau 78) — symbol ต่าง = กระจายความเสี่ยง
3. **GEP_NZDUSD** (Pivot — คนละ strategy จาก grid = diversification จริง) แต่เช็ค partial ก่อน
