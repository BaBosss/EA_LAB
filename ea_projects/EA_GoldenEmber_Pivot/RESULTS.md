# EA_GoldenEmber_Pivot — RESULTS (source of truth)

ทุก run ลงตารางนี้ 1 แถว · ตัวเลขทุกตัวต้องมาจาก report จริง (ห้ามกรอกมั่ว)

## Single-test / Validation

| RunID | .set | ช่วง | NetProfit | PF | MaxDD% | Trades | สถานะ | report path |
|---|---|---|---|---|---|---|---|---|
| RUN_GEP_0001 | pass71_robust | FULL 2020–2026 | +2,852 (→12,852) | — | — | — | ผ่าน (เดิม, OpenClaw) | logs/20260520.log |
| RUN_GEP_0002 | pass71_robust | OOS 2025.07–2026.05 | +131 (→10,131) | — | — | — | ผ่าน OOS บวก | logs/20260520.log |
| RUN_GEP_0003 | pass202_safe | FULL | +2,849 | — | — | — | OOS ลบเล็กน้อย | logs/20260520.log |
| RUN_GEP_0004 | **pass845_safe_FULL** | FULL | — | — | — | — | **ยังไม่ได้รัน** ← ทำต่อ | reports/inbox/ |
| RUN_GEP_0005 | **pass845_safe_RECENT** | OOS | — | — | — | — | **ยังไม่ได้รัน** | reports/inbox/ |

## Robustness (หลังมี trade list CSV)

| จาก RunID | MC PF 5th | DD 95th% | Ruin% | OOS PF | verdict |
|---|---|---|---|---|---|
| — | — | — | — | — | ยังไม่ได้รัน monte_carlo.py |

## บันทึก
- ตัวเลข RUN_0001–0003 มาจาก validation 2026-05-20 (balance อย่างเดียว
  ยังไม่มี PF/DD/trades เพราะ MT5 CLI ไม่สร้าง XML report รอบนั้น)
- **งานถัดไป: RUN_0004/0005** ให้ได้ report เต็ม (HTML + deals) เพื่อเข้า analyzer
