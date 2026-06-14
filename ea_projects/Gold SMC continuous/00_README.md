# GSMC — Gold SMC Continuous

> migrated to FOLDER_AND_NAMING_STANDARD 2026-06-14

| field | value |
|---|---|
| **EA Code** | `GSMC` |
| **Strategy** | SMC continuous (mean-reversion on XAU) |
| **Symbol / TF** | XAUUSD / H1 |
| **Status** | CONDITIONALLY ROBUST → PORTFOLIO_TEST (not LIVE_READY) |

## ⚠️ Variants (ตัวที่เคยงง — เคลียร์แล้ว)
| variant | EA .ex5 ใน MT5 | คือ |
|---|---|---|
| `GSMC_base` | `Gold_SMC_Continuous_MT5.ex5` | ต้นฉบับ — **ยังไม่ได้เทสสะอาด (ต้องทำใหม่)** |
| `GSMC_riskcap_v1` | `Gold_SMC_Continuous_MT5_RiskCapV1.ex5` | แก้ให้ DD ลด — **ตัวที่ validated** |
| (เลิกใช้) | `Gold_SMC_FiboRecovery_MT5.ex5` | สาย recovery แยก |

`.set` หลัก: `risk_cap_v1.set` (= `GSMC_riskcap_v1.set` ตามมาตรฐานใหม่)

## ผลที่ validated แล้ว (GSMC_riskcap_v1)
| Run | ช่วง | PF | DD% | RF | Trades | สถานะ |
|---|---|--:|--:|--:|--:|---|
| run_004 IS | 2025.01–2026.06 | 1.31 | 12.4 | 3.22 | 479 | IS PASS (score 70.7) |
| run_004 OOS | (forward) | 1.11 | 17.5 | 1.34 | 596 | **OOS_VALIDATED** (conservative) |
| Monte Carlo | — | — | DD95 39.5% | — | ruin 2.5%, PF5th 1.065 (thin) |

หมายเหตุ: report ใน `EA_CORE_V1_TESTBED` (PF 1.38/447t) = **GSMC_riskcap ตัวเดียวกัน** คนละ run → นับเป็น EA เดียว (ไม่ใช่ 2)

## ไฟล์สำคัญ
- source: `Gold_SMC_Continuous_MT5_RiskCapV1.mq5/.ex5`
- verdict เต็ม: `portfolio/candidates/Gold_SMC_Run004_OOS_VALIDATED/ROBUSTNESS_VERDICT.md`

## งานต่อ
1. เทส `GSMC_base` ให้สะอาด → เทียบ base vs riskcap
2. ผ่าน demo ≥3 เดือน ก่อน live
3. correlation กับ EA สาย/symbol อื่นก่อนจัดพอร์ต (XAU correlate กับทองตัวอื่น)
