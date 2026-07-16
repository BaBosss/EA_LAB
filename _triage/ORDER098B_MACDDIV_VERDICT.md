# ORDER-098-B — MACD-divergence naked entry: funnel verdict (Claude lead, 2026-07-16)

Build + smoke + genetic optimize = Codex 2026-07-15 (commits `5477a5ae` + `7e0825d0`).
BWD both-regime + plateau neighbors + holdout = agent batch 2026-07-16 (26+2 runs, Model 1).
Raw: `_mt5_auto/order098b_bwd_plateau.csv` · `order098b_macddiv_opt_summary.md` · reports `O098B_*`.

## Evidence table (center = optPF set per cell, in-sample-selected on MAIN 2023-26)

| cell | MAIN 23-26 (selection) | BWD 20-22 | HOLDOUT 2026H1 (never selected on) |
|---|---:|---:|---:|
| XAUUSD H4 | **1.91** (280t) | **1.04** (243t) | **1.30** (39t) ✅ |
| EURUSD H4 | 1.71 (272t) | 1.15 (246t) | **0.35** (42t) ❌ |
| XAUUSD H1 | 1.09 | 0.87 | — (closed at BWD) |
| EURUSD H1 | 1.17 | 0.96 | — (closed at BWD) |

**Plateau (MAIN, one-param-at-a-time neighbors, H4 only):**
- XAU H4: 9 neighbors PF 1.33-1.90, **no losing neighbor** — flat top on Slow/ATRp axes (Slow 36→48 =
  1.62-1.85; ATRp 14/26 ≈ center). Genetic peak sits mid-plateau → center selection acceptable as-is.
- EUR H4: 9 neighbors 1.24-1.70, also a plateau — but see holdout.

**MC (XAU H4 MAIN, trade-reshuffle 5000 iters, deposit 10k):** DD median 1.66% / 95th 2.66% / worst
4.76% · ruin 0.00% · P(loss) 0.0%. Caveat: reshuffle MC = optimistic lower bound (script docstring).

## VERDICT

1. **XAUUSD H4 = BUILD-ON CANDIDATE, ผ่านทุกด่านที่ Model 1 ตอบได้** — MAIN plateau จริง (ไม่ใช่ spike),
   BWD 1.04 = regime ตรงข้ามเอาตัวรอด (ไม่กำไรแต่ไม่เจ็บ, DD 3.4%), holdout 2026H1 ผ่าน 1.30, MC clean.
   **ยังไม่ demo-eligible** — เหลือด่านบังคับ: **Model-4 real-tick confirm** (3 windows) → corr check vs
   gold cohort ที่ live อยู่ 5 ตัว (Zeus/BRK/Squeeze/Trendline/Wave5 — gate pairwise <0.8) → ค่อย bundle.
2. **EURUSD H4 = HOLDOUT FAIL → PARK** — MAIN 1.71 + BWD 1.15 สวย แต่ **พังบน window ที่ไม่เคยใช้ select
   (0.35, win% 26 vs คาด 37)** = ลาย selection-fit ตาม VERDICT GATE #6 เป๊ะ. n=42 บางจึงไม่ตีตาย —
   สถานะ PARKED รอ 2026H2 data หรือเลือก plateau-center ใหม่ที่ไม่ใช่ genetic peak แล้ว re-holdout.
3. **H1 ทั้งสอง symbol = ปิด cell** (BWD 0.87-0.96 / MAIN 1.09-1.17 ใต้บาร์ — ตกเกณฑ์ pre-registered,
   ไม่ใช่ concept kill).
4. Flat-lot doctrine: EA นี้ naked flat-lot โดยสเปค (0.01 คงที่, SL = 3-bar extremum, TP 200% SL) —
   entry edge บน XAU H4 เป็นของจริงระดับ Model 1, ไม่มี escalation ปนตัวแปร.

**Next stage (queue ตาม pacing — ห้ามรันคู่ order อื่น):** Model-4 confirm XAU H4 ×3 windows → ถ้า PF ยัง
ผ่านบาร์ทั้งสาม → corr equity-curve vs gold cohort → เสนอ user เข้า demo. อย่า retune ระหว่างนี้.
