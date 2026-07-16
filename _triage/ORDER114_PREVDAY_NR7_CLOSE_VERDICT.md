# ORDER-114 — PREVDAY (#9/#30) + NR7 (#105) rescue-close (2026-07-16B, Opus)

ปิด rescue queue ORDER-084 (2 รายการสุดท้าย). ทั้งคู่เคยถูกจัด "เคย iterate 2-3 รอบ, low-prior" —
รอบนี้ swept lever แกน + both-window Model-4 บน XAU (best home) เพื่อปิดให้ชัด. CSV `_mt5_auto/PREVDAY_NR7_CLOSE.csv`.

## NR7 (#105) — sweep NR_Period {4,7,10,14} × {H1,H4} × both-window = ❌ DEAD (structural)
| NR_Period | H1 MAIN/BWD | H4 MAIN/BWD |
|---|---|---|
| 4 | 1.15 / 0.90 | 1.64 / 0.92 |
| 7 | 1.28 / 0.79 | 1.36 / 0.69 |
| 10 | 1.33 / 0.79 | 1.28 / 0.67 |
| 14 | 1.28 / 0.82 | 1.43 / 0.62 |

**window-inversion 16/16** — MAIN บวกทุกตัว (1.15-1.64, ride 2023-26 gold-bull) แต่ **BWD ขาดทุนทุกตัว (0.62-0.92)**.
+ **DD มหาศาล 27-83%** (แม้ MAIN ที่ "ชนะ" ก็ DD 33-62%; flat-lot 0.10). = ไม่ใช่แค่ regime-artifact แต่ **structural
danger**. ยืนยัน prior IS/OOS ("100% NR7 proceeds = bull-run artifact") + เพิ่มมิติ DD-blowup. period lever swept ครบ →
**DEAD ปิดถาวร** (ห้าม re-hunt NR-anything).

## PREVDAY (#9/#30) — sweep BreakBuffer {0.1,0.3,0.5} × {H1,H4} × both-window = ❌ DEAD
| buffer | H1 MAIN/BWD | H4 MAIN/BWD |
|---|---|---|
| 0.1 | 1.19 / 0.93 | 1.07 / 1.06 |
| 0.3 | 1.18 / 0.97 | 1.01 / 0.96 |
| 0.5 | 1.14 / 1.05 | 0.89 / 0.99 |

**ไม่มี config แตะ 1.2 both-window.** ดีสุด = marginal both-positive (b0.1-H4 1.07/1.06 · b0.5-H1 1.14/1.05) แต่
~1.05-1.07 = churn (200-900t) + DD 22-72%. daily-H/L breakout ไม่มี edge ทน. buffer lever swept → **DEAD** ยืนยัน
prior ("no config clears 1.30 gate").

## ✅ ORDER-084 RESCUE QUEUE = ปิดสมบูรณ์
| # | EA | ผล |
|---|---|---|
| 1 | Boss_14 GBPJPY | ✅ revive → demo leg #8 |
| 2 | XAU_NY | 🟡 regime-dependent (build-on regime-gate) |
| 3 | ZSCORE | ❌ reject (reversion no edge) |
| 4 | ICHIMOKU | ✅ **revive → USDJPY basket + XAU basket (find แข็งสุด)** |
| 5 | KELTNER | ❌ reject (window-inversion, swept) |
| 6 | PREVDAY + NR7 | ❌ dead (swept, NR7 structural-DD) |

**บทเรียนรวม:** rescue-ladder discriminate จริง — 2 revive (GBPJPY·ICHIMOKU→2 baskets) / 4 dead — ทุกตัว swept
lever แกน + both-window ก่อนตัดสิน. under-swept default-kill ที่ ORDER-084 ยกมา = จัดการครบทุกใบแล้ว.
