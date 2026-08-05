# HANDOFF — Wave-2 batch night 2026-07-20 (Fable, user-approved pacing override)

## จบแล้วคืนนี้ (commits `5f015f1` → `917b21a` + PROJECT_STATE bump)
1. **ORDER-136** — ปิดอยู่แล้วโดย `2cf741d7` (session ก่อน): overlay แพ้ bar, Wave2+ gated on user. ไม่มีงานเหลือ
2. **ORDER-139 S1 TrendRider XAU H4 = VALIDATED CANDIDATE → รอ user attach** (demo 463666728, magic 992004,
   kill DD 12%): plateau 6-cell AdxMin20 · center a20/s0.5/c2.5 · MAIN 1.63/BWD 1.03 · holdout 2026H1 1.33/23t
   (**ไหม้แล้ว** — demo-forward = holdout ถัดไป) · M4 1.61/1.01 · MC ruin 0/DD95 4.15 · corr ≤0.32.
   Bundle = `_vps_deploy/W2_S1_TRENDRIDER_XAU/` (README มี judge criteria pre-registered).
   ⚠️ BWD borderline → demo isolate · ห้ามใช้เป็น DCA-overlay host (กฎ ORDER-136)
3. **ORDER-139 SS4 SweepReversal = PARKED-VERIFY(user)** — brief 3 บรรทัดใน taskboard/ท้าย handoff
4. **ORDER-140 SS1 ORB expand = null** — UJ M15 1.14/1.10 + XAU M30 1.13/1.08 (กว้างแต่บางใต้ bar) คง BUILD-ON
5. **ORDER-141 (EXP)_AdaptGridMC built** — compile 0/0 + review PASS + `adaptgrid_mc_zone.py` self-tested.
   ยังไม่ backtest (ตามคิว user)

## รอ USER
- **attach S1 992004** ตาม `_vps_deploy/W2_S1_TRENDRIDER_XAU/README_ATTACH.md` แล้วเติม judge_date/start_date ใน DEPLOYMENTS.csv
- **PARKED-VERIFY เคาะ 2 ตัว:**
  - SS4 SweepRev M15: sweep-and-reject reversion — BWD-fail ทุก cell (trend years มัน continue) — น่าสนใจเพราะ MAIN pulse จริง 1.3-1.85 + กลไก sweep-detect reusable; ทางฟื้น = ranger home (EURUSD/EURGBP/AUDNZD) หรือ shelve
  - S2 TsMom D1 (ค้างจาก 07-19): MAIN 2.8-4.9/BWD<1 — demo-isolate หรือ MRIS regime-overlay
- ค้างเดิม: PERSIST_MIGRATION checklist · Control Room sensor folder `D:\Monitor\MT5 - 463666728`

## คิวถัดไป (session หน้า)
- AdaptGridMC: export BTCUSD/ETHUSD D1 CSV จริง → gen zone → smoke + **BWD 2020-22 HARD gate** (ORDER-141 ต่อ)
- SS2 NyIgnition (WATCH 1.02/639t) = Wave-3 optimize ถ้า user เคาะ
- Wave-3 design ที่เหลือ (S6/SS5 squeeze, SS3 VWAP, S3 Asian fade)

## Gotchas คืนนี้
- classifier outage ~30 นาที: Bash/PowerShell โดนบล็อกชั่วคราว — Write/Edit/Grep/Read ใช้ได้ · workaround = Monitor sleep-timer เว้นช่วง retry
- tester ว่างตลอดคืน (ไม่มี session คู่ขนาน) — sweep 100+ run ไม่มี report-race
