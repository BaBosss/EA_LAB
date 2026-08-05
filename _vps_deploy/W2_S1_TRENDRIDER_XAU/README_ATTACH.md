# W2_S1 TrendRider XAU — demo attach bundle (ORDER-139, 2026-07-20)

**EA:** `TrendRider_XAU.ex5` (source `ea_projects/(TRND)_TrendRider_XAU/(TRND)_TrendRider_XAU_rev01.mq5`)
**Chart:** XAUUSD **H4** · **magic 992004** · set `S1_TrendRider_XAU_deploy.set` (plateau center a20/s0.5/c2.5, AllowLive=true)
**Broker assumption:** server = GMT+3 (Exness). ถ้า broker อื่นต้องแก้ `_03_ServerGmtOffset` ก่อน attach.

## Evidence (locked before attach)
- Plateau both-window (27-cell ladder): center MAIN **1.63**/112t eqDD 2.64% Sharpe 1.96 · BWD **1.03**/139t eqDD 1.71%
  — 6-cell block AdxMin20 × Sep{0.3,0.5} × Ch{2,2.5,3} ผ่าน bar ทุก cell (sensitivity fan = pass)
- HOLDOUT 2026H1: PF **1.33**/23t (≥1.2; n บาง — demo-forward = holdout ตัวถัดไป, 2026H1 ไหม้แล้วสำหรับ EA นี้)
- Model-4: MAIN **1.61** / BWD **1.01** — retained, no fill cliff
- MC (5k resample, MAIN M4): ruin 0% · DD95 4.15% · PF-5th 1.61
- Corr monthly vs cohort: BRK_FULLSPAN 0.32 · MacdDiv XAU H4 0.05 · Boss_17 Wave5 0.10 = LOW-additive
- ⚠️ BWD 1.01 = borderline (regime-marginal เหมือน MacdDiv 0.97 precedent) — demo isolate ก่อน ห้าม promote เงินจริงจาก MAIN สวยอย่างเดียว

## Judge criteria (pre-registered)
- kill: eqDD > **12%** · 3-mo PF < **0.8** ที่ ≥15 trades
- judge ≥3 เดือน: PF ≥ **1.40** ที่ ≥30 trades → เข้าคิวพิจารณาเงินจริง (ผ่าน Codex second opinion ก่อนเสมอ)

## Attach steps
1. Copy `TrendRider_XAU.ex5` → VPS `MQL5\Experts\` · attach บน XAUUSD H4 chart
2. Load `S1_TrendRider_XAU_deploy.set` (ตรวจ `_06_AllowLive=true`, magic 992004)
3. เพิ่ม judge_date + start_date ในแถว `portfolio/DEPLOYMENTS.csv` (magic 992004) วันที่ attach จริง
