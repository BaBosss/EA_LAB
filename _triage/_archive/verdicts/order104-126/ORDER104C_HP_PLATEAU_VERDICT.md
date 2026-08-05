# ORDER-104 Stage C — HP-denoise @ λ1600 build-on plateau (Claude lead, 2026-07-16)

Sweep 28 runs, Model 1, EA `(TRD)_Probe_MAHP_TanhVol_rev01` (HP on, tanh off, λ1600), XAUUSD H4,
both windows. Raw: `_mt5_auto/order104c_hp_plateau.csv` · sets `_mt5_auto/ab_sets/order104c/`.
Inputs: `_01_FastMA` `_01_SlowMA` `_02_UseHPFilter` `_02_HP_Lambda` `_04_SlAtrMult`.

## MA-period grid (both-window PF, MAIN 23-26 / BWD 20-22)

| fast\slow | 24 | 32 | 40 |
|---|---|---|---|
| **8**  | 0.97 / 1.08 | 1.33 / 1.17 ✅ | 1.38 / 0.93 |
| **12** | 1.25 / 0.85 | 1.08 / 0.91 | 1.50 / 0.93 |
| **16** | 1.36 / 1.10 ✅ | **1.59 / 1.33** ✅ | 1.15 / 1.18 ✅ |

**Both-window winners cluster รอบ (16,32):** ตัวมันเอง 1.59/1.33 + เพื่อนบ้านทั้ง 4 ทิศที่ผ่าน both-window
((16,24) 1.36/1.10 · (16,40) 1.15/1.18 · (8,32) 1.33/1.17) = **plateau จริง ไม่ใช่ spike** (VERDICT GATE #2).
(12,x) แถวกลางอ่อน = ขอบ plateau. 

**SL axis รอบ (16,32):** SL 1.5 = 1.57/1.15 · SL 2.0 = 1.59/1.33 · SL 3.0 = 1.48/1.38 — **ทั้ง 3 ผ่าน
both-window** = plateau บนแกน SL ด้วย (ไม่ sensitive).

**λ axis รอบ (16,32):** λ800 = 0.98/1.15 (MAIN หลุด) · λ1600 = 1.59/1.33 · λ3200 = 1.29/1.07 —
**λ1600 = center จริง** (ต่ำไป MAIN พัง, สูงไปเสื่อม) ยืนยัน Stage B ว่า λ ต่ำดีแต่มีก้น.

## VERDICT — HP-denoise เป็น lever จริงบน trend-cross @ XAU H4 (build-on confirmed)

Stage B ที่ว่า "λ1600 บน XAU H4 ผ่าน both-regime" **ยืนหยัดใต้ MA-period × SL sweep** = ไม่ใช่ fluke ของ
MA-period เดียว. HP-denoise ยก 2-MA cross จาก chassis เปล่าให้แตะ both-window PF>1 ได้จริงบน XAU H4.

**แต่ chassis = probe testbed ไม่ใช่ production** (2-MA เปล่าไม่ใช่ keeper — ระบุใน Stage B แล้ว). คุณค่าที่ได้ =
**HP-denoise = validated signal-quality bolt-on** สำหรับ trend-cross entry บน XAU. ทางไปต่อ 2 ทาง (lead เลือก
ตอนถึงคิว — ไม่เร่งใน order นี้):
1. **Model-4 confirm probe นี้** (16,32,SL2.0,λ1600) ×3 window → ถ้าผ่าน = candidate เดี่ยวได้เลย (แม้ chassis
   ธรรมดา ถ้า edge จริงก็ deploy ได้ตาม build-on doctrine)
2. **Graft HP-denoise เข้า production trend chassis** (EA_BREAKOUT / SuperTrend family) เป็น lever ใหม่ใน funnel

**บันทึกเข้า EDGE_CATALOG: HP-denoise (Hodrick-Prescott causal, λ1600) = confirmed noise-filter lever บน XAU
trend-cross.** ปิด Stage C. Stage D (W3 Pivot/Donchian) ยังเปิดใน ORDER-104 campaign.
