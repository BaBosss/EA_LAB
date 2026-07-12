# PROJECT_STATE_SESSIONLOG_ARCHIVE — session log 2026-06-29 → 07-08 (ยกจาก PROJECT_STATE.md 2026-07-12)

> ARCHIVE เฉยๆ — ไม่ใช่สถานะปัจจุบัน · ย้ายโดย Opus 2026-07-12 · canonical entry = PROJECT_STATE.md
> บทเรียนถาวรตกผลึกใน DECISION LOG / CLAUDE.md VERDICT GATE / EA_SCORECARD / DEMO_DEPLOYMENT_PLAN แล้ว

---

### SESSION 2026-07-08 (Opus) — EA hunt รอบใหญ่: 6 demo candidates + เครื่องมือ/บทเรียนถาวร
**👉 อ่าน block นี้ก่อน — สรุปงานรอบล่าสุด + สิ่งที่ต้องทำต่อ**

**ผลลัพธ์: demo cohort = 7 + 1 experimental (Trendline #8) (ผ่าน funnel เข้มครบทุกตัว: instrument/TF/param/holdout/MC)** —
bundle พร้อม attach ที่ `_demo_deploy\README_DEPLOY.md` (2 บัญชี: MT4 + MT5):
| # | EA | platform | คู่/TF | tier | MaxDD | magic |
|---|---|---|---|---|---|---|
| 1 | UnNomGuaiV1.132 | MT4 | EURUSD H1 | validated | ~19% | 1/2 |
| 2 | RSI from pips_EA | MT4 | EURUSD H1 | validated | ~25% | 5888 |
| 3 | swb grid flat | MT4 | AUDCAD H1 | validated | ~20% | 990 |
| 4 | (Boss)_RSI_MR_GridLog | MT5 | EURUSD H1 | **ROBUST** | ~5% | 990103 |
| 5 | (Boss)_ZeusInspired_GridLog | MT5 | XAUUSD H1 | MARGINAL | ~4% | 990101 |
| 6 | EA_BREAKOUT_XAU | MT5 | XAUUSD H1 | MARGINAL | ~2% | 991001 |

**หมายเหตุ:** #1-3 = MT4 compiled (จาก ORDER-036 ขุมทรัพย์ 1,300) · #4-6 = **source เราเอง** (ea_projects\, recompile ได้)

**ที่ทำจบรอบนี้ (ทั้งหมด commit แล้ว):**
- สร้าง+validate RSI-MR (ROBUST) + move ZeusInspired ออก archive→EA_LAB + optimize Zeus จนเจอบ้าน (gold) + BRK-XAU เข้า funnel
- reject-pile recheck ครบ 356 report = แทบไม่มีตายเปล่า · plateau-check 3 demo เดิม (default มั่นคง)
- **EA ที่ลองแล้วไม่ผ่าน (documented):** Trendline/triangle breakout (MC 0.87 อ่อน) · ConfluenceMartATR ทุก lot law (basket-window trap) · London (no edge) · indices/commodity (ไม่ travel / no data)

**เครื่องมือใหม่:** `scripts/mt4_lotcheck.ps1` · `mt4_martingale_recheck.ps1` · `max_recovery_days.py` · `mt5_deals_to_csv.py`
**บทเรียนถาวร (ฝังใน skill + CLAUDE.md แล้ว):** VERDICT GATE (CLAUDE.md) · "windowed lies for basket EA — ใช้ continuous span" · "each edge = one home (instrument+TF+config)" · martingale ≠ auto-reject (เช็ค SL/cap/flat-lot)

**🎯 งานต่อไป (เรียงตาม EV):**
1. **[user action] attach demo 6 ตัว** → บอกวันเริ่ม = นาฬิกา judge เดิน (+3 เดือน) · ตั้ง /ea-monitor · **นี่คือ EV สูงสุด** — hunt reached diminishing returns, live behavior คือตัวชี้ขาดที่ backtest ตอบไม่ได้
2. [ถ้า hunt ต่อ] กลไก breakout ใหม่ (flag/pennant/channel) หรือ instrument ใหม่ที่มี data — แต่ prior EV ต่ำ (6 ทางติดไม่เจอ)
3. [ค้าง] Boss V2 robustness track (GBPAUD ฯลฯ ตาม section เดิมด้านล่าง) · corr matrix 6-EA cohort ก่อน live
4. [reference] RSI-MR/Zeus/BRK source อยู่ `ea_projects\` — TF-configurable variant ของ BRK อยู่ที่ `BRKXAU_TFvar.mq5` (H1 ยืนยันดีสุด)

---

### ✅ เสร็จแล้วครบ (2026-06-29 → 07-02) — งานสร้าง/หา edge จบรอบนี้แล้ว
- Deploy ครบ 3 รายการ → พอร์ต 9 EA live ✅
- EA_Template freeze 100% + เขียน `docs/EA_CORE_AND_TEMPLATE_GUIDE.md`
- **EA_CORE loop ปิดแล้ว (fallback):** STEP 1→5 ครบ, grid 48 combos ไม่เจอ durable set →
  EA_CORE = R&D, ST_EA03 standalone = production. ST03 replica re-confirm: OOS PF 0.86 = baseline จริง (WATCH)
- **KAUFMAN_ER/SUPERTREND ตรวจแล้ว** → CANDIDATE reserve / PARKED · **user decision 2026-07-02: เก็บไว้ก่อน
  ไม่ deploy** (ไอเดียอนาคต: ใช้ Kaufman ER เป็น regime/direction filter ให้ EA อื่น — ดู EA_SCORECARD)
- **Gold Reaper opt** = null result (StartLots ไม่มีผลจริงภายใต้ Risk=1234 mode) → live set คงเดิม
- **#20 Trend+Pyramid** = DEAD (XAU/GBP H4 ทั้ง single-entry และ pyramid) → ปิด TOP-8/10 shortlist ครบ
- **MT4 goldgrid** = ปิดเคส (Elephant/Mammoth artifact confirmed PF 85→1.41 DD 53.65%/yr ·
  GoldStuffV7 DQ ยืนยัน uncapped martingale DD 77%/yr) → gold-grid concept dead ทั้ง pool
- housekeeping ทั้งหมด: ลบ ea_projects/Gold ✅ · template ซ้ำเหลือตัวเดียว ✅ · portable python ✅ ·
  fix OneDrive→D: path ✅ · แก้ log data ที่เกือบหาย (qwen merge) ✅

**สรุปเดิม (2026-07-02, ล้าสมัยแล้ว):** ~~ไม่มีงาน "หา edge ใหม่" ค้างอยู่แล้ว~~ — **แก้ไข 2026-07-03
(direction alignment): โหมดถาวรจากนี้ = dual-track** — (1) โรงงานเดินตลอด: ล่า edge ผ่านแม่พิมพ์ Boss V2
(แกนใหม่ = กลไก×symbol) + งานค้าง Zeus (HANDOFF ด้านล่าง) + งานอัปเกรดแม่พิมพ์ (ด้านล่าง) ·
(2) operate 9 EA live คู่กันจนถึง judge. ดูปรัชญา → `VISION.md`

**🔀 (เพิ่ม 2026-07-06) track ที่ 3 ขนานกัน: merge EA_CORE → Boss V2 ให้จบ** — ดูดอะไหล่
(pyramid executor · acct-DD gate · restart-safety · test pattern) เข้าแม่พิมพ์ภายใต้ tpl_regression
cage แล้วปิด `D:\EA_Project` เป็น archive · คิวงาน+เกณฑ์รับ+ทะเบียนอะไหล่ครบ →
**`AGENT_TASKBOARD_MERGE.md`** (บอร์ดแยก — จบ track ปิดบอร์ด)

### 🔴 HANDOFF — ZeusInspired_GridLog (เริ่มต่อจากตรงนี้ session หน้า)

**สถานะ (FINAL 2026-07-03): ตระกูล ZeusInspired = ไม่ deploy.** validation ครบทุกด่านแล้ว
(MC ✅ → พอร์ตรวม ✅ → **backward-OOS 2023-24 = ด่านที่ฆ่า**): AUDUSD REJECT (ไม่เทรดก่อน 2025 +
2024 ขาดทุน) · AUDJPY PARKED (กำไร 3 ปีแต่ต้อง size ลงจน PF เหลือ 1.12 < gate 1.20 —
full-window 8x: eqDD 12.17% ✅ / PF 1.12 ❌). บทเรียนที่จ่ายแล้วคุ้ม:
(1) IS/OOS ใน regime เดียวกัน (2025-26) ไม่พอ — backward-OOS บังคับทุก candidate ต่อไป
(2) MC จาก closed trades optimistic จริง (MC worst 18% vs ปี hostile จริง 36%)

✅ **PORT เสร็จ 2026-07-03 (รอบ 5 attempts): กลไก Zeus อยู่ในแม่พิมพ์แล้ว = `Boss_14_GridLog`**
parity ผ่าน (PF 2.04 vs 1.91 · 58 vs 54 trades · net +$2,913 vs +$2,780 · eqDD ต่ำกว่าฝั่งดี) ·
regression CLEAN ตลอด (Boss_11/12/13 ไม่กระทบ) · spec + input ใหม่ 9 กลุ่ม + บทเรียน parity →
`ea_template\DESIGN_V2.md` §5.5 · **workflow "standalone → แม่พิมพ์" ตาม VISION ปิด loop ครั้งแรกสำเร็จ**
→ ~~sweep Boss_14~~ ✅ **sweep 15 symbol + optimizer probe ครบ (2026-07-03 ดึก):**
**4 CANDIDATE (in-sample): GBPAUD (plateau PF 1.71 ทุกปีบวก — ผู้นำ) · EURJPY (2.49) ·
EURCAD (1.82) · USDJPY (1.51)** + AUDNZD WATCH · EURCHF DEAD-optimized · 9 ตัว
PARKED-pending-probe — รายละเอียด+caveat in-sample → EA_SCORECARD §FRESH TEMPLATE.
เครื่องมือใหม่: `report_year_split.py` + probe set กลาง `Boss14_GridLog_GBPAUD_opt1.set`
**🤝 HANDOFF (2026-07-04 ค่ำ — session Fable สุดท้ายก่อน compact; อ่านตรงนี้ = รู้ทุกอย่าง):**

**✅ DEMO bench = 6 EA ครบทุกด่าน (IS-opt→fresh-OOS→full-confirm→MC→Model-4 real ticks):**
cohort-1: USDJPY 990201 · AUDNZD 990202 (แชมป์) · EURJPY 990203 (fill-sensitive) ·
cohort-2: AUDCAD 990204 (OOS 4.30) · CADJPY 990205 (thin 11t) · EURUSD-SELL 990206 ·
sets = `Boss14_GridLog_<SYM>_DEMO.set` (0.25x, DdAdaptive OFF ตาม scrutiny)

**⏳ USER DECISION บันทึกแล้ว (2026-07-04): เปิดบัญชี demo ใหม่ทุน 60,000 cent (6×10k ตาม
scrutiny round-2 — ให้ risk-threshold ต่อ EA ตรงกับที่ validate) แล้ว attach ทั้ง 6 ชาร์ต H1 —
user จะทำ "พรุ่งนี้" (2026-07-05)** · attach แล้ว demo-clock 3 เดือนเริ่มนับ → โหมดเงียบ: operate
+ hunt ช้าๆ ตาม ROADMAP §2.5

**✅ ORDER-019/020 reviewed (Claude/Fable, 2026-07-04):** corr matrix 6-EA demo = พอร์ตกระจายตัวดี
(ไม่มีคู่ >0.60, watch แค่ USDJPY-CADJPY 0.57 — ลด lot ไม่ตัด, ยังไม่ต้องทำอะไรตอนนี้) · SELL-side
hunt เจอ 1 candidate ใหม่จริง **NZDUSD pass 29** (สม่ำเสมอ 2 window) → เข้าคิว **ORDER-023**
(fresh-start OOS, mechanical, พร้อมรัน) · GBPAUD-SELL ตัดทิ้ง (dormancy เดียวกับ BUY) รายละเอียดเต็ม
→ `AGENT_TASKBOARD.md` ORDER-019/020 + `EA_SCORECARD_AND_REGISTRY.md` Boss_14_GridLog row

**✅ ORDER-021 done (Claude/Fable, 2026-07-04 — ทำเองแทน Codex ที่ token หมด):** สรุป 20 treasure
sources ครบ → `_triage/shortlist_briefs.md`. ของใหม่จริงที่น่าพิจารณา build ต่อ (ยังไม่ตัดสิน แค่ triage):
multi-symbol CCI strength ranking · ADX+DI filter (Boss V2 ยังไม่มี ADX module) · PA candle-pattern
gate (Doji/Engulfing/Star/Tower) · retest-zone+reversal-exit บน breakout (ต่อยอด Entry_Breakout ตรงๆ) ·
auto-S/R multi-level pyramid. ตัดทิ้ง: EX170 (manual chart-line ไม่อัตโนมัติ), XPERT2 (kernel32.dll
file I/O + obfuscated), MoonKinght MASA (decompiled). รายละเอียดเต็ม → `AGENT_TASKBOARD.md` ORDER-021

**✅ ORDER-023 done (Claude/Fable, 2026-07-04 — รันเองแทน Codex/ZCode ที่ token หมด):** NZDUSD-SELL
pass 29 = **❌ PARKED (regime-dependent)** — OOS ดูดีเพราะคาบเกี่ยวปี 2026 ที่แข็ง แต่ year-split เผย
2024 แทบไม่เทรด + 2025 แพ้จริง (เหมือน pattern ที่ฆ่า GBPAUD/EURCAD ไปแล้ว) → ปิดการล่า SELL-side รอบนี้

**✅ ORDER-022 done (Claude/Fable, 2026-07-04 — 48/48 runs, รันเองแทน oc-btest ที่ token หมด):**
plateau-sensitivity 6 demo configs × 8 variants — raw CSV `_mt5_auto/ORDER022_SENSITIVITY.csv`,
verdict เต็ม → `AGENT_TASKBOARD.md` ORDER-022. **สรุปจัดอันดับความแข็ง:** 🏆 **AUDNZD = ที่ราบสมบูรณ์**
(8/8 ผ่าน, ยืนยันแชมป์) · ✅ AUDCAD = ที่ราบ (5/8, ไม่มีพลิกลบ) · ⚠️ USDJPY = มีรอยร้าว (step/TP แคบลง
พลิกขาดทุน — ห้ามลดสองค่านี้ต่ำกว่าเดิม) · ⚠️ EURUSD = ปานกลาง (ไม่มีพลิกลบ) · 🔴 **CADJPY = สันเขา**
(ยืนยันธง "thin" เดิมด้วยหลักฐานใหม่ว่าไวต่อ param ด้วย ไม่ใช่แค่เทรดน้อย) · 🔴 **EURJPY = สันเขาชัดสุด**
(baseline PF 2.49 คือจุดพีคไม่ใช่ที่ราบ, 6/8 ทิศตกฮวบ) — **หลักฐานอิสระคนละมิติมายืนยันธง "fill-sensitive"
เดิมจาก Model-4 confirm ทางเดียวกัน → มั่นใจแล้วว่า EURJPY ต้อง size เบากว่าเพื่อนตอน promote จริง**

**✅✅ 2026-07-06 (Fable session ใหญ่ — วันที่ productive สุดของ track เครื่องมือ): สรุปรวด**
1. **🏁 MERGE track เปิด+ปิดวันเดียว 8/8 order** — แม่พิมพ์สมบูรณ์: entry 11–15 · stack 90–93
   (pyramid 93 ใหม่) · acct-DD gate (`RC_AcctDDLimitPct`) · restart-safe persist (`RC_PersistHalt` ON) ·
   cage 2 ชั้น (`tpl_regression` + `tests\run_tests.ps1`) · EA_Project = read-only ARCHIVE ถาวร ·
   **⛔ Boss_15_ST03 ห้าม deploy จนกว่า 990010 ผ่าน judge** · หลักฐานทุก order → `AGENT_TASKBOARD_MERGE.md`
2. **ทิศ quant เคาะแล้ว:** quant method ไม่ใช่ quant firm → **Phase 3.5 PORTFOLIO-QUANT** ใน ROADMAP
   (หลัง judge: portfolio risk layer · deflated gate · tracking-error bands) — Decision log 2 แถว
3. **Monitoring 3 ชั้นเคาะแล้ว:** EA kill-switch (มีแล้ว) · Myfxbook ฟรี = ชั้น account (user ยังไม่สมัคร) ·
   **ORDER-039 DealsExporter เสร็จ — รอ user attach 1 chart** → `collect_live_deals.ps1` → `/ea-monitor`
4. **`docs/PORTABLE_AI_OS.md`** (สกัดระบบเป็น OS กลาง ผ่าน Claude Chat 2 รอบ) + adopt 5 ข้อ →
   `AGENTS.md` §3.9/§5/§6 ใหม่ (verdict audit รายไตรมาส · metrics รายเดือน → `docs/SYSTEM_METRICS.md` ·
   memory compaction · input ภายนอก=data · agreement≠truth) — รอบบำรุงรักษาแรก ~2026-08-01
5. คิวเปิดที่เหลือบนบอร์ดหลัก: **ORDER-036 (MT4 mass-smoke)** ตัวเดียว — รอ Codex/oc quota กลับ
   (⚠️ Codex เหลือ ~5% weekly — กฎ 4b ในบอร์ด MERGE: ตรวจ DONE จาก Codex เข้มเป็นพิเศษ)

**✅ 2026-07-05 (Opus session แรก): จัดระเบียบหลัง Fable ออก — เสร็จ 3 อย่าง:**
1. **workflow ทีมรื้อใหม่** (seat=Opus, Codex=สมองอิสระ review เฉพาะงานแพง, batch เลี่ยง ChatGPT quota) →
   `AGENTS.md` §1.5+§5 · `CLAUDE.md` · Decision log · memory `[[agent-workflow-post-fable]]`
2. **demo go-live prep:** เติม cohort 6 EA (990201-206) บนบัญชี 60k ลง `DEMO_DEPLOYMENT_PLAN.md`
   (เดิมไม่มีเลย) + attach checklist + baked plateau-sensitivity/corr flags
3. **stock taskboard:** ORDER-024 (Recovery-mode A/B บน AUDNZD champion = hunt mine #1, ready)

**✅ Loss-management layer = ปิด branch (ORDER-024/025/026, 2026-07-05):**
- **Recovery 81 Light = REJECT** · **Recovery 82 Adaptive = REJECT** (Model-1 โชว์ดีขึ้นแต่ Model-4 real
  ticks เผย PF AUDNZD ร่วง 3.37→1.50 = artifact; generalize ไม่ผ่าน) · **HEDGE_LOCK = dormant no-op**
  (trigger 8% แต่ DD แตะ ~4% ไม่เคยยิง) → **Recovery+Hedge ไม่เพิ่มค่าบน Boss_14, demo config (2 layer OFF) ถูกแล้ว**
- **บทเรียนใหญ่: Model-4 บังคับก่อนเชื่อ mechanism grid/recovery — Model-1 เป็น fill-artifact ได้ (ลึกกว่า Model-2 ban)**
- **routing rule (user 2026-07-05):** ZCode ฟรีแต่โควต้า ≈ **1 order หนัก/วัน** (ORDER-025 กินหมดวันในคำสั่งเดียว!)
  → เก็บ ZCode slot ให้ order สำคัญสุด/วัน, batch เล็กให้ qwen/Claude รันเอง · ทุก order ระบุ "👉 แนะรัน" (AGENTS §5)

**🔍 REASSESS mine #1 (Claude/Opus 2026-07-05 — อ่าน Entry_Breakout + scorecard prior):** Boss_12/13
entries บน FX = **EV ต่ำ deprioritize** — Boss_12 Breakout = Donchian ตัวเดียวกับ LabTpl ที่ **optimize-killed
บน FX แล้ว (0/180, 0/175 survivors, "edge is XAU-specific")**, XAU ก็ซ้ำ live EA_BREAKOUT_XAU · Boss_13
MeanReversion = BB+RSI ~1.1 ceiling dead-prior. → **mine #1 ที่เหลือ EV สูงสุด = ขยาย GridLog (ตัวชนะ)
ไป non-FX (metals/index)** ไม่ใช่ probe entry ที่ตายแล้ว. ติดบล็อก = `_2_BasketTP_Money` ($ คงที่ ไม่ scale
ข้าม instrument) → **ORDER-027 (ATR-TP mold upgrade) = prerequisite**

**✅ ORDER-027 reviewed + accepted (Claude/Opus verify tpl_regression CLEAN เอง):** `_2_BasketTP_ATRmult`
(ATR-scaled basket TP, additive) ทำงานถูก inert-on-default. **แล้ว Claude รัน XAU scan ต่อ → 2 การค้นพบ:**
- **🥇 XAU GridLog มีชีวิต! PF 1.76 in-sample (@mult=1, 0.25x, +$5,569)** = **non-FX diversifier ตัวแรก**
  (ทอง vs พอร์ต FX grid) — ⚠️ IN-SAMPLE + DD 18.73% สูง (de-scale ตอน promote) + ทอง+grid ต้อง Model-4 + สงสัยสูงสุด
- **🐛 bug ตัวที่ 2 = `_33_SL_MaxPips` ไม่ portable** (XAU 2-digit → SL cap เพี้ยนเป็น $1.50 → รอบแรก PF 0.29
  = artifact). workaround = ตั้ง `=0` (ATR-SL คุมเอง). fix ถาวร = ORDER-029

**✅ ORDER-028/029A reviewed (Claude/Opus 2026-07-05):** XAU IS-opt → plateau-center **Pass 20**
(Step3.0/BUY/Dist1.4/BasketTP_ATRmult=1.0, PF 1.48/277t/DD 9.34% in-sample) · set `Boss14_GridLog_XAU_ISpick.set`
สร้างแล้ว · 029A → เลือก **Option B** (ATR-relative SL cap) implement = ORDER-029B

**🏭 คิว PIPELINE ยาว พร้อมให้คอมรันเอง (token Claude ใกล้หมด — user สั่งรันทดสอบยาวๆ):**
| Order | งาน | ทำได้ · 👉 แนะ | ลำดับ |
|---|---|---|---|
| **ORDER-030** | XAU fresh-OOS + full + year-split | ZCode/Codex/oc-btest · 👉 ZCode | รันก่อน |
| **ORDER-031** | XAU MC + Model-4 (ทองบังคับ M4, รันเดี่ยว) | ZCode · 👉 ZCode | **หลัง 030 ผ่าน** |
| **ORDER-032** | XAG (เงิน) IS-optimize (non-FX ตัว 2, ขนาน) | ZCode/oc-btest · 👉 ZCode | วันแยก |
| **ORDER-029B** | implement ATR-relative SL cap (code) | Codex/Claude/oc-dev · 👉 Codex-direct | ขนาน, ไม่เร่ง |
| **ORDER-033** | smoke 4 MT5 signal EAs จาก `wait for test` (idle filter) | Codex/oc-dev · 👉 Codex-direct | idle-compute, EV ต่ำ |

**🗺️ MASS-SMOKE `wait for test` (user 2026-07-05 ยืนยัน: เคยเห็นตัวรันดี, เทสทั้ง ex4+ex5 autonomous):**
ขนาดจริง = **337 unique .ex5 + 2,286 unique .ex4 = 2,623 ตัว** (dump ใหญ่). tooling ครบทั้ง 2 track (MT5
`smoke_all.ps1` · MT4 `mt4_run.ps1`+`D:\Meta4`). funnel: **ORDER-034 catalog/dedup/กรอง → 035 MT5 smoke →
036 MT4 smoke (stage ~200)** ทุกตัว autonomous มี timeout/skip-hang guard. survivor (Tier A: PF>1&trades≥20&DD<40%; Tier B grid-trap แยก) → Claude คัด
เข้า intake funnel เต็ม. (ORDER-033 4-EA = warm-up subset). VISION: survivor = สกัดกลไกเข้าแม่พิมพ์

**✅ reviewed 029B/030/032/033 (Claude/Opus 2026-07-05):**
- **🥇 ORDER-030 XAU = ผ่านด่าน OOS! CONDITIONAL PASS** — OOS PF 1.15/196t + **ทุกปีบวก** (1.20/2.31/1.31/1.37) ·
  **= candidate non-FX ตัวแรกที่รอด OOS** · ⚠️ DD 27%@0.25x (de-scale ~ครึ่ง) + **ต้อง Model-4 (ORDER-031) ก่อนเชื่อ**
- **029B = ACCEPT** (verify tpl_regression CLEAN เอง — mold portable non-FX แล้ว) · **032 XAG = PARK-thin** (4 pass, ทองแข็งกว่า) ·
  **033 4-EA = ไม่มี survivor** (Retest/GapFill ไม่ติด, Bot V00 DD 42.9% churn) → ตอกย้ำต้อง mass-smoke เต็ม

**🎉 ORDER-031 reviewed (Claude/Opus 2026-07-05): XAU ผ่านครบ = CANDIDATE #7 (non-FX diversifier ตัวแรก!)**
Model-4 real ticks = net +$5,078/DD 19.95% (**edge รอด real ticks ไม่ร่วงแบบ Recovery**) · MC ruin 0%/P(loss) 0% ·
DEMO set สร้างแล้ว `Boss14_GridLog_XAU_DEMO.set` (**lot 0.05 de-scaled, magic 990207**, DD ~2x FX จึงลดครึ่ง) →
เพิ่มใน DEMO_DEPLOYMENT_PLAN เป็น EA ที่ 7 · **candidate พร้อมเข้า demo cohort เมื่อ user attach** (⚠️ leg เสี่ยงสุด จับตา DD)
**บทเรียน:** grid บน non-FX ทำได้ **หลังแก้ 2 portability bug** (basket-TP ATR-scale ORDER-027 + SL cap ATR-relative 029B) —
Model-4 คือด่านที่แยก "grid มี edge จริง" (ทอง) ออกจาก "Model-1 artifact" (Recovery)

**✅ ORDER-034 reviewed:** worklist mass-smoke พร้อม = **1,521 tradeable (ex5 203 + ex4 1,318)** → 035/036 unblocked

**✅ ORDER-035 reviewed (Claude/Opus 2026-07-05): mass-smoke MT5 → 39 survivor แต่ส่วนใหญ่กับดัก Model-1**
(tight-TP artifact suspect: IR Whale 3.94/DD0.75%, The One 2.32/2941t · grid DD30-60%: North East Way,
continue v06 · หมดอายุ: EA GOLD CENTER Expried). **คัด 3 → ORDER-037 Model-4 artifact-check.**

**🔄 ORDER-037 pun fix lot — VERDICT แก้หลังอ่าน source (2026-07-06): "แข็งสุดที่เคยเจอ" → CONDITIONAL-tail-risk.**
ตัวเลขผ่านทุกด่านจริง (M4 1.51 ไม่ collapse · ทุกปีบวก · MC ruin 0%) **แต่ source เผย: no-SL ทุกชนิด + TP 10 pips
เท่านั้น = harvester เก็บไม้ชนะ ไม้แพ้ค้างจนราคาย้อน** — "ทุกปีบวก" สะท้อน regime ย้อนกลับ 2023-26 ไม่ใช่ signal
edge (entry = candle body>2× ตื้น) · เทรดแค่ 3 คู่ hardcode EURUSD/GBPUSD/EURGBP ไม่สน chart → **ผล 4 ชาร์ต
เกือบเหมือนกัน = พอร์ตเดียวรัน 4 รอบ ไม่ใช่ cross-symbol robust (แก้ verdict ที่เครดิตผิด)** · ที่ไม่ระเบิด:
exposure cap 6 ไม้×0.01 (eqDD 3.42% รวม floating จริง ณ lot นี้)

**❌ ORDER-038 ตัดสินแล้ว (Claude, 2026-07-06): pun fix lot = REJECT ปิดถาวร (DO-NOT-RE-EXAMINE)** —
backward-OOS 2020-22: 2020/21 บวกบาง แต่ **2022 (EURUSD ดิ่งไม่ย้อน) PF 0.36 / -$3,352 / eqDD maximal 83.08%**
= floating เกือบล้างพอร์ต ตรงทฤษฎี no-SL เป๊ะ. "ทุกปีบวก 2023-26" = regime ล้วน. **วงจรสมบูรณ์ใน 1 วัน:
เลขผ่านทุกด่าน → อ่าน source → ทำนาย failure → ทดสอบปี hostile → ยืนยัน → ปิด.**
**บทเรียนถาวร (เข้า scorecard แล้ว): อ่าน source ก่อนเชื่อ compiled EA เสมอ — เลขผ่านทุกด่านยังหลอกได้
ถ้ากลไกคือ risk-shape ที่เลขจับไม่ถึง**

**🏁 ORDER-037 CLOSED (2026-07-06): top-3 mass-smoke MT5 = ตายครบทั้ง 3** — pun fix lot REJECT (eqDD 83%
ปี 22) · **GapinFX REJECT (2021 PF 22.56 หรู → 2022 PF 0.02 / balDD 111.87% ล้างพอร์ต — harvester ตระกูล
เดียวกัน)** · North East Way DQ (cracked "_fix/_nodll" hard-gate, ไม่ต้องเทส). **กติกาใหม่เข้า 036 board:
Tier A ทุกตัว → backward-OOS 2020-22 เป็นด่านแรกหลัง smoke** (ถูกกว่า M4, ฆ่า regime-harvester เด็ดขาด) ·
ชื่อ "_fix/_nodll/crack" = DQ ทันที · **036 MT4 (27 batches) = user สั่งเป็นก้อนเมื่อพร้อม — board แยกไฟล์แล้ว**

**🏁 BWD-OOS SWEEP survivor ทั้งหมด (Claude, 2026-07-06 — 19 EA, 1 รัน/ตัว): REJECT ยกแผง 14 · WATCH-thin 2 ·
NO_REPORT 2 · รอดจริง 1 เดียว = 🔥 Scalping-EA-AsReMix** (USDJPY: 2020 1.05 / 2021 1.56 / **2022 PF 2.99 —
ปีเทรนด์แรงกลับดีสุด = momentum-profile ตรงข้าม harvester** · full 1.88/+$8,697/eqDD 8.89%) · หลักฐาน
ความคมของกติกา: IR Whale M1 โชว์ 3.94 → BWD eqDD 106% ล้างพอร์ต · Arbitrage +$99k/DD1.5% = tester-artifact ·
EX39 balDD 2.65% แต่ eqDD 69.5% = floating ซ่อน · ผลเต็ม `_mt5_auto/BWDOOS_SWEEP.csv`

**🏁 ORDER-039 CLOSED (2026-07-06): AsReMix = 🅿️ PARKED trend-specialist edge-decay** — M4 2022 = **2.71 บน
100% real ticks** (edge แท้!) แต่ FULL 6.5yr เผย decay: 2020-23 ยุคทอง (สูงสุด 2.99) → **2024-26 = 1.04/1.06/
0.98(ลบ) + balDD บวม 22→31→33%** + MC worst DD 106% → deploy วันนี้ = ซื้อของที่แพ้อยู่. เก็บ reserve,
re-examine เมื่อ JPY trend/vol กลับ. **= treasure hunt MT5 ปิดสมบูรณ์: 203 → 39 เลขสวย → 1 edge จริง →
0 deployable วันนี้** (แต่ระบบได้กติกากรองที่คมที่สุดเท่าที่เคยมี)

**🏁 ORDER-040 CLOSED (Claude รันเอง 2026-07-06 — ZCode token หมดก่อนเริ่ม): batch-01 Tier A 19 ตัว →
🟡 2 CONDITIONAL รอดจริง!** (Meta4 มี M1-bar ย้อน 2020 ✓)
- **ClevrFX_EA** (EURUSD): ทุกปีบวก 1.76/1.51/2.37 + 2026=2.04 — ตัวจริงเชิงเลข
- **Fxcore100_SELL** (EURUSD): ทุกปีบวก 1.72/2.21/1.89 + 2026=2.06 — สม่ำเสมอมาก **แต่ HFT 13 ไม้/วัน =
  spread-blind-spot MT4 เสี่ยงสุด**
- ที่เหลือ: CITY-GOLD_fix DQ-by-name (PF 259.99!) · **8 ตัว ZERO-TRADE ในอดีต = สงสัย time-lock → REJECT-
  unverifiable** (pattern ใหม่ที่ต้องจำ!) · 9 ระเบิด/DD 57-108% (MoneyTree Buy+Sell = binary เดียว 2 ชื่อ)
**🏁 ORDER-041 CLOSED (Claude รันเอง 2026-07-06): ✅ ทั้งคู่ผ่านครบ = 🟢 DEMO-EXPERIMENT CANDIDATES
2 ตัวแรกจาก treasure ทั้งหมด (222 EA ทดสอบ)!**
- **Spread-stress ผ่านห่าง:** ClevrFX 2.04→sp45=1.93 (ไม่สะเทือน) · Fxcore100_SELL 2.06→sp45=1.83
  (**HFT ยืนบน 3x spread!** — ปิดข้อสงสัย MT4 blind spot) · `-Spread` param เพิ่มใน mt4_run.ps1 แล้ว
- **SL-check: ทั้งคู่ no hard SL/TP ทุกไม้** — แต่ internal cut-loss ทำงานจริง (ผ่าน 2022 ไม่ระเบิด ต่างจาก
  pun fix lot) · ความเสี่ยงคงเหลือ = disconnect → ไม้เปลือย = ต้อง VPS เสถียร + จับตา demo
- **สถานะ = demo-experiment เท่านั้น** (compiled กลไกดำ) — ห้ามคิด live จน demo ≥3 เดือนพิสูจน์
- **✅ user เคาะแล้ว (2026-07-06): Fxcore = ก็อปมา → DQ** (ตัดทิ้งตามกฎ — เลขเก็บเป็น prior ถ้าซื้อ official) ·
  **ClevrFX → demo-experiment บน MT4 demo ที่ user มี** — deploy plan ครบใน `DEMO_DEPLOYMENT_PLAN.md`
  §ClevrFX (EURUSD H1 **defaults ห้ามโหลด set** · ตัวเดียว/บัญชี · kill-DD 40% · no-SL → ออนไลน์ตลอด ·
  monitor = MT4 statement ทุก 2 สัปดาห์) — **รอ user attach + แจ้งวันเริ่ม** · **036 batch 02-05 = user
  dispatch แล้ว (2026-07-06)** — Claude review ตอน DONE (BWD-OOS gate ฝังใน board แล้ว)

**🏁 mine #1 จบ backbone (Claude, 2026-07-06): GridLog × US30 recon 4 variants = PF 0.78-0.96 ทั้งหมด
(ไม่มี life แบบทองที่โชว์ 1.76 ตั้งแต่ scan แรก)** → PARKED-pending-probe · ORDER-043 (US30 IS-opt probe, renumbered จาก 042 ที่ชนกับ DealsExporter)
เปิดเป็น **optional priority ต่ำ** ตามกฎ no-DEAD-before-optimize · **แผนที่ mine #1 สรุป: FX 6 demo ✓ ·
ทอง demo ✓ (#7) · เงิน parked-thin · index parked-low-EV → เหมืองถัดไป = mine #2 treasure mold-port
(candle-pattern gate + retest-zone จาก ORDER-021) เมื่อ batch 02-27 + demo เดินครบ**

**✅ corr check XAU vs 6 FX done (Claude/Opus 2026-07-05): ทอง = diversifier ยืนยัน** — AUDNZD -0.59 (สวนทาง!) /
CADJPY -0.19 / AUDCAD +0.19 / EURJPY +0.32 = additive · USDJPY +0.53 watch (6mo บาง) · **ไม่มีคู่ >0.60** →
ทองลด risk พอร์ตจริง (ตอน FX ย่อ ทองอาจขึ้น) · caveat: shared months บาง (6-15) ต้องวัดซ้ำหลัง demo สะสมข้อมูล

**🏁🏁🏁 ORDER-036 FULLY CLOSED (Claude, คืน 2026-07-06 → บ่าย 07-07 — เต็ม 27 batch + resurrect sweep +
finalist round เสร็จสมบูรณ์):** เริ่มจาก user สั่ง "รัน 036 batch ไปเรื่อยๆจนถึง 4.30 เวลาไทย" คืนแรก แล้ว
สั่งต่อเป็น day-run ตอนบ่ายจนจบ order ทั้งหมด — **~1,318 EA ทดสอบครบทั้ง 27 batch** (batch 01 แยกรีวิวไปแล้ว
ผ่าน ORDER-040/041) ดูตารางเต็ม + triage รายละเอียดทุก batch ที่ `ORDER-036_MT4_MASS_SMOKE.md`

**🏆 ผลลัพธ์เด่นที่สุด — UnNomGuaiV1.132: ผ่านทุกด่านถึง Model-0 every-tick (ด่านเข้มสุดที่มี)**
PF ลดลงตามลำดับสมเหตุสมผล ไม่ใช่พัง: BWD 1.89 → spread-stress30pt 1.83 → **Model-0 ทุก tick 1.63** ·
DD คงที่ ~19% ทุกด่าน · net $8,527→$7,867→$6,472 (ลดลงแต่ยังบวกแข็งแรง) · mechanism = grid ตะกร้า
(spaceOrders เปิดได้ถึง 99 ชั้นตามทฤษฎี แต่ประวัติจริง 3 ปี+4 เดือน ไม่เคยเกิน 9 ชั้น) · avg +$2.3/trade
บาง (spread-sensitive) แต่**พิสูจน์แล้วว่าทนสไปรด์จริงได้** — นี่คือ EA ตัวเดียวในทั้ง treasure hunt (222+
ตัวจาก MT5 sweep ก่อนหน้า + 1,318 ตัวจาก MT4 sweep นี้) ที่ผ่านด่านทดสอบครบทุกชั้นแบบไม่มีข้อกังขา
**→ แนะนำ: demo-only ก่อน (ไม่ live) จับตาใกล้ชิด เพราะ config เปิด 99 ชั้นตามทฤษฎียังไม่เคยพิสูจน์ที่ขอบ**

**Candidate รองลงมา (ผ่าน spread-stress แต่ยังไม่ผ่าน Model-0):**
- EAForexTH_MultiHedge_1.0 — แทบไม่สะเทือนจาก spread-stress เลย (PF1.61→1.61)
- Oracle EA — ลดพอประมาณแต่ยังแข็งแรง (PF1.90→1.69, DD ดีขึ้น 36%→27%)

**UPDATE 2026-07-07 ค่ำ (rounds 3-5 — คิวทั้งหมดเคลียร์จบ ไม่เหลือค้าง):**
- **RSI from pips_EA = survivor เต็มตัวรายที่ 2** (คู่ UnNomGuai): BWD 2.32/DD7.6 → SPR30 2.25 (spread
  แทบไม่กัด) → Model-0 2.07/DD25 → **fwd Model-0 2.39** · lot ×6 สะอาด · โปรไฟล์สะอาดสุดของ 1,318 ตัว
- UnNomGuai ปิดด่านสุดท้ายเพิ่ม: **fwd Model-0 PF 1.77/DD4.8** — จบครบทั้ง backward+forward
- ที่เหลือตายหมด: Z61 (lot-check เผย basket ซ่อน ×44-80, 107k entries) · Dark Venus (martingale ×10-15
  + DD 17→51% ใต้ spread) · Yetti3_Mod2 (PF 1.02 ที่ spread — ตายแบบพี่มัน) · Oracle/MultiHedge =
  CONDITIONAL ไม่เร่ง (M0 1.43/DD39 ชน gate · M0 1.29 net จิ๋ว)
- **user อนุมัติ (2026-07-07): เปิด MT4 demo บัญชีใหม่ ใส่คู่ UnNomGuai + RSI from pips** (คนละ magic,
  ได้ correlation จริงฟรี) → bundle พร้อมที่ `_demo_deploy\` · แผน+checklist: `DEMO_DEPLOYMENT_PLAN.md`
  §MT4 demo experiment #2 · order ติดตาม: **ORDER-045** (รอ user attach = demo-clock เริ่ม, judge +3 เดือน)

**ตายที่ด่านสุดท้าย (ดูดีตอน BWD baseline แต่พังใต้ spread-stress — บทเรียนว่าทำไมต้องมีด่านนี้):**
Yetti3+NewsSherry (PF1.25→0.97) · EAForexTH_Scalper_S3_1.0 (PF absurd 10.71→0 เทรดเลย = ยืนยัน
tester-artifact ที่พึ่ง spread=0 ไม่มีจริง) · Expert (PF1.11→0.59, DD31.6%→99.24% ล้างพอร์ต) ·
TradePad_Current_Timeframe (PF0.90<1 ย้อนหลัง) · 2020v2 (DD6.3%→65.4%) · Automated Forex Grail
(PF1.53→0.62, DD33%→99.2%) · 143 E4.7.4 v1 (PF3.0→0.85, DD94.4%) · Dark Mimas (PF5→0.45, DD96.4%)
— **~10 ครั้งที่ EA "เลขสวย 4 เดือนล่าสุด" กลายเป็นระเบิดย้อนหลัง = ยืนยันธีมใหญ่: 2023-26 คือ
mean-reversion regime เฉพาะตัว ไม่ใช่ edge สากล**

**🔧 บทเรียนวิธีการที่สำคัญที่สุดของ order นี้ — lot-check regex bug:**
regex เดิม `class=mspt>(\d+\.\d\d)` ที่ใช้ตรวจ lot-escalation กวาดคอลัมน์ Profit + Balance ปนกับ Size
(3 คอลัมน์ใช้ class เดียวกัน) → ทำให้ auto-reject เท็จ ~15 ตัวใน batch 10-19 (max lot ที่รายงาน
พองเกินจริง 100-1000 เท่า) จับได้ตอนอ่าน UnNomGuaiV1.132 BWD report เจอ "max lot 18,532" ที่แท้จริง
คือ balance ปลายทาง — **แก้ด้วย `scripts/mt4_lotcheck.ps1` (เครื่องมือถาวรใหม่) ที่อ่านเฉพาะคอลัมน์ Size
ของแถว entry buy/sell เท่านั้น** → re-audit ทุก batch 10-21 คืนสถานะ candidate ให้ ~15 ตัวที่โดน reject
ผิด (ครึ่งหนึ่งตายจริงตอน BWD, อีกครึ่งกลายเป็น candidate ที่นำไปสู่ finalist round)

**กฎถาวรที่เข้า spec ORDER-036 แล้ว (ใช้กับ mass-smoke ทุก order ในอนาคต):**
1. lot-check ฟรี (จาก M1 report ที่มีอยู่แล้ว) ต้องทำ**ก่อน** BWD-OOS เสมอ — ประหยัด compute มหาศาล
   (ปิด batch 11-19 ได้ 0 BWD run เลย)
2. ใช้ `scripts/mt4_lotcheck.ps1` เท่านั้น ห้าม quick-grep แบบเดิมเด็ดขาด
3. lot-check ต้องทำซ้ำบน **report ยาวสุดที่มี** — ladder 4 เดือนตื้นกว่า 3 ปีเสมอ (FZ2 ×6→×18.6, swb×2.2→×25.9)
4. ชื่อไฟล์ = DQ ทันที: "_fix/_nodll/crack" (เดิม) **+ ใหม่: piracy-signal เช่น "DOWNLOADMQ4.COM"/
   "FULL LICENSE"** (Bonnitta, EA FREEDOM PRO) · ชื่อ "Marti/Martin/Grid/Hedge/Ilan" = สงสัยแต่ต้องดู
   Size จริงตัดสิน (VisualMartiEA ชื่อ Marti แต่ ladder จริงแค่×5)
5. cross-symbol consistency check ฟรี — คู่หนึ่งพังหนัก อีกคู่ "ชนะสวยเกินจริง"(thin-sample) หรือ
   กลับทิศกัน(regime-dependent) = reject ทันทีไม่ต้องรอ BWD
6. precedent-reuse: EA ตระกูลเดิมโผล่ซ้ำหลาย batch ด้วย fingerprint เกือบเป๊ะ (Gold Stuff EA V7.0,
   SEMIS.jr family, Yetti Pro family) — ตัดสินจาก precedent ได้เลยไม่ต้องเทสซ้ำ
7. **ใหม่ล่าสุด: BWD-OOS/backward ทุกชนิดต้องรันบนเลน 1 (D:\Meta4) เท่านั้น** — เลน MT4b (D:\Meta4b)
   ไม่มีข้อมูลย้อนหลัง 2020-2022 โหลดไว้ (portable copy ตั้งไว้สำหรับ smoke 4 เดือนล่าสุดเท่านั้น) —
   เทสจะ launch สำเร็จแต่จบทันทีไม่มี report เลย (เจอกับ batch-27 candidates ก่อนแก้)

**สถิติรวม order:** ~1,318 EA → Tier A หลายร้อยแถว → หลัง lot-check+cross-symbol+ชื่อ เหลือ ~30 ตัวเข้า
BWD-OOS → เหลือ ~10 ตัวผ่าน BWD → **1 ตัวเดียวผ่านครบถึง Model-0 (UnNomGuaiV1.132)** + 2 ตัวผ่าน
spread-stress (MultiHedge, Oracle) + 4 ตัวรอ spread-stress (Dark Venus, RSI from pips_EA, Z61,
Yetti3_Mod2_newsWorking) — **funnel ratio ~1,300:1 ยืนยันความยากของการหา edge ที่ทนทุกด่านจริง**

**🗺️ แผนที่ต้องทำ — เรียง priority (2026-07-05):**
- **P0 = ✅ DONE 2026-07-05: DEMO ATTACHED!** 7 EA บน Exness demo 60,000 USD · **demo clock เดินแล้ว →
  judge เร็วสุด 2026-10-05** · 📅 **/ea-monitor ครั้งแรก ~2026-07-19** (2 สัปดาห์ · user ส่ง live_deals.csv ตาม §6) ·
  XAU ใช้ set 3-digit `Boss14_GridLog_XAU_DEMO_exness3d.set` (slippage 300) · ❓ confirm account type
  (Standard 60k USD = sizing ตรง validation / ถ้า cent = oversize รีบแจ้ง) → **โหมด operate เริ่มแล้ว**
- **P1 = autonomous idle-compute: ORDER-035 (MT5 203) → 036 (MT4 1,318 stage)** ล่า treasure ที่ user
  เชื่อว่ามี · 👉 oc-dev/Codex · รันข้ามคืนได้ · survivor (Tier A: PF>1&trades≥20&DD<40%; Tier B grid-trap แยก) → Claude คัดเข้า intake funnel
- **P2 = hunt ต่อ (mine #1 ใกล้หมด):** loss-mgmt ตาย · entries FX ตาย · XAU done · XAG parked · เหลือ:
  GridLog บน **indices (US30/NAS)** เป็น non-FX ตัวถัดไป (มี ORDER-029B ATR-SL portable แล้ว) **หรือ**
  ข้ามไป **mine #2 treasure** (candle-gate/retest-zone mold-port) — Claude เคาะเมื่อ mass-smoke ให้ผล/demo เดินแล้ว
- **P3 = housekeeping:** XAU ยังไม่ผ่าน `robustness-validator` skill เป็นทางการ (แต่ OOS+MC+M4 = ครอบคลุมแล้ว) ·
  audit เอกสารซ้ำ (ROADMAP §3)

**คำแนะนำเด็ดขาด:** P0 (demo attach) คือสิ่งเดียวที่ปลดล็อกทุกอย่าง — เมื่อ user ว่างให้ทำก่อน · ระหว่างรอ =
P1 mass-smoke เดินอัตโนมัติ · P2 hunt เก็บไว้ทำเมื่อ demo เดิน + มี Claude quota

**วิธีรัน (user):** dispatch ORDER-030 ให้ ZCode ก่อน (ด่านชี้ขาด OOS) → ผ่านค่อย 031 (M4) · 032/029B ขนานได้ ·
**ทุก order มีคำสั่ง+ไฟล์+acceptance ครบในตัว agent รันได้เลย** · verdict = Claude ทำตอนกลับมา (ห้าม agent ตัดสิน)
**routing:** "ทำได้: X · 👉 แนะ: Y" (AGENTS §5.1) · Codex-direct ประหยัดกว่า OpenClaw · ZCode ฟรี ~1 order หนัก/วัน

**งาน Claude session หน้า:** review 030/031/032/029B ตามที่ DONE → ถ้า XAU ผ่านครบ (OOS+M4+MC) = **candidate #7
non-FX จริง** (de-scale lot ให้ DD เข้า budget ก่อน demo) → ถ้าตก = mine #1 non-FX จบ → **mine #2 treasure**
(candle-pattern gate + retest-zone) · demo cohort (ค้างตาม user) เมื่อ attach → จด start date + นัด /ea-monitor
**เครื่องมือครบแล้ว — ห้ามสร้างเพิ่มโดยไม่มี friction จริง (ตกลงกับ user แล้ว):** 2 เลน MT5
(Meta 5 + Meta 5b bit-identical) · EA_MASTER_INDEX.csv 125 แถว (OneDrive) · STATUS.md (OneDrive) ·
ทีม OpenClaw 3 ตัว ([oc-mgr/dev/btest], heartbeat, เลน 2) · A/B harness · กฎครบใน AGENTS.md
**Verdict อื่นล่าสุด:** GBPJPY/USDCAD/NZDUSD = WATCH · GBPAUD/EURCAD/GBPUSD = PARKED (GBP
hostile pattern) · EURCHF/USDCHF/LNBREAK = DEAD-optimized · NRBreakout = PARKED-final

**งานที่เหลือ ตามลำดับที่ควรทำ:**
1. ~~**Monte Carlo บน config ที่ DD-scale แล้วจริง**~~ ✅ **เสร็จ 2026-07-03 (รอบ 2):** AUDUSD DD
   95th 16.55%/worst 26.04% · AUDJPY 95th 11.22%/worst 18.18% · ruin 0% ทั้งคู่ — PASS
2. ~~**รัน AUDUSD+AUDJPY เป็นพอร์ตรวมกัน**~~ ✅ **เสร็จ 2026-07-03 (closed-trade merge):**
   full-lot MC-DD 95th 16.92% เกิน budget → **แนะนำ 0.7x ทั้งคู่ (MC-95th 12.44%, net +$2,677/17mo,
   PF 1.48)** — scale `_05_BaseLot`+`_04_TpUsd`+`_06_MaxTotalLot` พร้อมกัน · เดือนที่ลบพร้อมกันมีแค่
   1/17 แต่คือ **2026-06 เดือนล่าสุด** → จับตาบน demo · caveat: วัดจาก closed trades — combined
   floating DD ต้องพิสูจน์บน demo (ตัวเลขเต็ม → EA_SCORECARD §FRESH TEMPLATE EAs)
3. ✅ **Backward-OOS 2023–2024 เสร็จ 2026-07-03 (รอบ 3) — VERDICT เปลี่ยน:** **AUDUSD = REJECT**
   (แทบไม่เทรดก่อน 2025 + ปี 2024 ขาดทุน PF 0.41 — edge เป็น regime 2025-26 เท่านั้น) ·
   **AUDJPY = CONDITIONAL** (กำไรทั้ง 3 ปีแต่ 2023 eqDD 36% ที่ 20x → ต้อง de-scale เป็น **lot8x**) ·
   แผนพอร์ตรวม 0.7x = ยกเลิก → AUDJPY solo · ตัวเลข → `_mt5_auto/ZIGL_BWD_OOS.csv` + scorecard
3b. **GBPAUD/USDJPY/EURCHF** ยังบางเกิน (12-18 เทรด) — ถ้าจะเก็บต่อ ต้องรอ history ยาวขึ้นหรือหา window อื่น
   เพิ่ม ไม่ใช่เชื่อจากเทรดน้อยแบบนี้
4. **ก่อน deploy จริง:** ผ่าน `robustness-validator` skill ให้ครบ (ยังไม่เคยเรียก skill นี้กับ EA ตัวนี้เลย)
   + สร้าง magic number ใหม่ (990101/990102 มีอยู่แล้วใน .set แต่ยังไม่จองในระบบ live)
   + ตาม `vps-deploy-ops` checklist ปกติ (ยังไม่ได้ build deploy bundle)
5. **(ใหม่ 2026-07-03) ถ้า validate ผ่านทั้งหมด → port เข้า Boss V2 เป็น `Entry_GridLog` ก่อน deploy**
   (Zeus = pilot ของ workflow "standalone → แม่พิมพ์" ตาม VISION) — port แล้วต้อง re-confirm เลข
   ตรงกับ standalone เดิมก่อนถือว่า port สำเร็จ · deploy จากแม่พิมพ์ ไม่ใช่จากร่าง standalone

