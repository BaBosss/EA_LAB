# HANDOFF → next session (2026-07-17, Opus, EA-lane) — rescue-close + demo-attach + build phase

> อ่าน `VISION.md` → `PROJECT_STATE.md` → this file. ขัดกันเชื่อ repo + `check_state.ps1`.
> ต่อจาก `SESSION_2026-07-16B_HANDOFF.md`. HEAD chain: `1baea7e8` → +20 [claude] commits (+auto-snapshot ทับบนสุด).

## ✅ ปิดใน session นี้ (session ยาวมาก — มหากาพย์)

### 🏁 ORDER-084 RESCUE QUEUE = CLOSED 6/6
- **ICHIMOKU (#66) = REVIVED** (คว่ำ "DEAD") — period lever ปลดล็อก → **2 basket candidate:**
  - **USDJPY basket** (med-H4 + slow-H1): PF 1.339, MC PF_5th 1.036 (thin), ruin 0% → bundle #9
  - **🥇 XAU basket** (med-H4 + slow-H1): **PF 2.14, MC PF_5th 1.544, 6/6 ปีบวก, DD 10.5%** = find แข็งสุด · corr additive (BRK 0.26) → bundle #11
- **KELTNER (#62) = REJECT-confirmed** (window-inversion + churn, swept จริง)
- **PREVDAY + NR7 = DEAD** (ORDER-114, swept; NR7 structural-DD 27-83%)
- (เดิม: GBPJPY revive · XAU_NY regime-dep · ZSCORE reject)
- **rescue archaeology จบสมบูรณ์** — regime-parked (Zeus AUDUSD/Boss_14 NZDUSD) = full-funnel'd, ทางฟื้น = `_50_` graft (separate track)

### 🎯 candidate ใหม่ + attach
- **user attach demo ครบ 2026-07-16:** 13 magic → register แล้ว (DEPLOYMENTS.csv 41 rows, judge 2026-10-16)
  - บัญชี **463666728** (Trial17 "bundle 10"): 11 single-position (Wave5×2/BRK×2/MacdDiv/SMCSTO/IchiADX×4/SuperTrend)
  - บัญชี **415573666** (Trial14): +Zeus AUDJPY 990110 + GBPJPY 990208
  - ⚠️ **463666728 ต้อง attach AccountSnapshotExporter** (user ทำแล้ว?) ไม่งั้นไม่เข้า dashboard
- **Wave5 USDJPY = candidate ใหม่ (ยังไม่ attach):** optimize (EntryFib 38.2/Wave3MinMult 1.618) → 1.56/1.92 both-window, **6/6 ปีบวก** → bundle `_vps_deploy/WAVE5_USDJPY/` magic 990303 · **รอ user attach**

### 📦 091 catalog batch 2 + build
- **5,187 .mq4 → 2,048 unique families** · parser `scripts/mq4_source_catalog.ps1` · catalog + shortlist committed
- boilerplate trap จับได้: "martingale" = 95% ทุกไฟล์ (fxDreema template) → แยก has_mart_block
- **#1 build TSD OsMA+WPR = ❌ REJECT** (structural DD 19-93% ทุก cell, marginal signal) — NEVER-TOUCHED lead #1 ตาย · WPR/Force = noise · remaining leads (iMACD|iForce, iSAR) prior ต่ำลง

### 🔧 อื่นๆ ปิด
- **#080 limit-entry = CLOSED** (ตอบผ่าน ORDER-108 split-retest + 091C-D1d): pending ≠ free win (adverse-select + 26% missed fills) · split robust แต่ config-conditional
- **#073 reimagined = macro-regime-intelligence** (ไม่ใช่ news-blocker) → prompt session ใหม่ = `_triage/MACRO_REGIME_SYSTEM_PROMPT.md` (user เปิด session แยก)

## 🧠 บทเรียนหลัก
1. **entry-signal PERIOD/lever = lever แรกเสมอ** — "ceiling" ที่วัดจาก default ไม่ใช่ ceiling จริง (ICHIMOKU→XAU+USDJPY, Wave5 UJ→optimize คว่ำ thin)
2. **corr = LIVE-money gate ไม่ใช่ demo gate** (user 2026-07-16B) — demo เอาขึ้นเทส normal lot คอนเฟิร์มก่อน, corr sizing ตอนเงินจริง → memory `feedback-correlation-lotsize` อัปเดตแล้ว
3. **multi-home naked EA อื่น = low-yield** (MacdDiv XAU-specific) — IchiADX XAU มาจาก period lever ไม่ใช่ symbol-swap
4. rescue-ladder discriminate จริง (revive 2 / kill 4 ภายใต้ treatment เดียว, ไม่ rubber-stamp)

## ⚠️ Gotchas
- **git: 132 commit unpushed · GitHub remote (BaBosss/EA_LAB) เข้าไม่ถึงจากเครื่องนี้** (ls-remote timeout = TLS-proxy/network) → push/PR ต้องทำจากเครื่อง network สะอาด หรือแก้ proxy (skill github-https-repo-auth). local repo committed ครบ = ปลอดภัย
- compile ea_projects: **PowerShell Copy-Item -LiteralPath** (bash cp พังกับวงเล็บ) → `D:\Meta 5\MetaEditor64.exe /compile` (roaming 9CA16B มี Include tree)
- portable python312 embed พัง → ใช้ PowerShell แทน (corr/parse)
- MT5 htm ใช้ space เป็น thousands-sep ("1 011") → parser ต้อง strip space (runner P() ทำแล้ว, ad-hoc grep พัง)

## 🚀 START HERE — คิว session หน้า (user เคาะแล้ว "ทำทั้งหมด")
1. **#4 095 symbol-expand** (ยังไม่เริ่ม) — best = **Boss_14 grid → ranger crosses ใหม่** (EURCHF/GBPCHF/NZDCAD/AUDCHF; grid=ranger, มี IS-pick pipeline). naked EA อื่น low-yield
2. **#098 corpus build-on** (ทำเรื่อยๆ) — fxDreema IDEA_CATALOG เลือก concept spec→build
3. **091 remaining leads** (prior ต่ำหลัง TSD reject) — build เฉพาะถ้า user รู้จัก EA ตัวดัง
4. Wave5 UJ attach (มือ user, magic 990303)
5. **แยก session: macro-regime-intelligence** (#073) = prompt พร้อมใน `_triage/MACRO_REGIME_SYSTEM_PROMPT.md`

## รอ user (mobile-answerable)
- attach Wave5 UJ 990303 เพิ่มไหม (candidate all-years-positive แต่ thin ~13t/yr)
- #4 Boss_14 ranger expansion เริ่มเลยไหม
- push/PR: จะ handle จากเครื่องอื่นหรือให้ผมลองแก้ proxy
