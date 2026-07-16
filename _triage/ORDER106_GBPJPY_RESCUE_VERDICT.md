# ORDER-106 — Boss_14 GridLog GBPJPY rescue (ORDER-084 queue #1) — interim verdict (Claude, 2026-07-16)

Rescue of a cell ORDER-084 flagged under-swept (defaults only, OOS 1.12 borderline). Coarse
spacing×SL surface, 36 runs Model 1, both windows, H1+H4. Raw: `_mt5_auto/order106_gbpjpy_sweep.csv`.

## Both-window read (MAIN 23-26 / BWD 20-22)

**Genuine PLATEAU = H4 @ dist2.0 × SL{3,4,6}:** MAIN 1.55-1.59 / BWD 1.06-1.07 — flat across all 3
SL values, both windows >1.0. This is the honest signal (VERDICT GATE #2 plateau, not spike).

**High-PF cells = SPIKES (rejected):**
- H4 dist4.0/sl3.0 = 1.90/1.20 but neighbors dist4.0/sl4.0 BWD 0.70, sl6.0 BWD 0.54 → isolated.
- H1 dist4.0/sl6.0 = 2.31/1.15 (highest MAIN) but H1 neighbors fail BWD (dist4/sl4 0.78, dist3/sl6 0.77).
- H1 dist3.0/sl4.0 = 1.78/1.39 but surrounded by BWD-fails (0.77-0.89) → selection-fit.

## Verdict — RESCUE JUSTIFIED, NOT DEAD. GBPJPY H4 dist2.0 = thin both-window plateau (Model-1).
The default-only 1.12 that looked marginal was **under-explored, not dead** — the sweep found a
real (modest) H4 plateau at wider spacing (dist2.0) that defaults missed. This is exactly what the
ORDER-084 retro-audit was for.

**Caveats before it's a candidate:**
1. **Grid EA → Model-1 optimistic.** The H4 dist2.0 plateau MUST survive Model-4 real-tick (running now,
   `O106_M4_GJ_H4_*`) before it means anything (VERDICT GATE #6 + grid doctrine).
2. **Thin:** 31-40 trades over 3yr on H4 = low power. BWD barely clears (1.06-1.07).
3. If Model-4 holds → finer H4 sweep around dist2.0 (dist ∈ {1.5,2.0,2.5} × basket-TP) + holdout + corr
   vs the Boss_14 demo cohort (990201-207 already live — corr gate <0.8, and GBPJPY not yet in cohort).

**Status: PARAMETRIC build-on — pending Model-4 (in flight). NOT deploy, NOT dead.** rescue queue #1 done.

---

## MODEL-4 CONFIRM (Claude, 2026-07-16) — ✅ ผ่าน, grid ไม่ collapse บน real ticks
`_mt5_auto/order106_model4_confirm.csv` (GJ_d2.0_s4.0.set, plateau center)

| window | Model 1 | **Model 4 (real ticks)** |
|---|---:|---:|
| MAIN 23-26 | 1.55 | **1.56** (55t, DD 9.23%) |
| BWD 20-22 | 1.06 | **1.11** (50t, DD 9.40%) — ดีขึ้น |
| HOLDOUT 2026H1 | — | **1.50** (10t, DD 3.75%) |

**อ่านผล:** grid EA มัก collapse ตอน Model-4 (fill จริงแพงกว่า Model-1) — **ตัวนี้ไม่** MAIN เท่าเดิม BWD ดีขึ้น
holdout บวก = plateau นี้เป็นของจริงระดับ real-tick. **rescue สำเร็จ: GBPJPY ไม่ตาย** (ORDER-084 flag ถูก).

**Caveat ที่เหลือ:** (1) thin — n=50-55 ต่อ 3yr (~18 trades/ปี) + holdout n=10 = power ต่ำ (2) DD real-tick ~9%
(สูงกว่า M1 5.3% ตามคาดของ grid) (3) risk class = capped-log grid (สูงกว่า naked MacdDiv).

**Next (queue — ไม่ deploy เอง):** GBPJPY H4 = **candidate เพิ่มเป็น leg ที่ 8 ของ Boss_14 demo cohort**
(415573666 มี 7 symbol H1 อยู่แล้ว 990201-207 — EA เดียวกัน magic ใหม่, GBPJPY H4). ด่านก่อนเสนอ user:
(a) finer sweep dist∈{1.5,2.0,2.5}×basket-TP รอบ center ยืนยัน plateau + n เพิ่ม (b) corr vs 7 legs เดิม
(gate reuse ข้าม symbol ของ EA เดียว = pairwise <0.8) → ถ้าผ่านเสนอเป็น cohort addition. = ORDER-095-style.
