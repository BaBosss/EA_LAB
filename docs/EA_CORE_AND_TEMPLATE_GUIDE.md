# EA_CORE & EA_TEMPLATE GUIDE — สถาปัตยกรรม + วิธีใช้งาน

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **คำอธิบายสถาปัตยกรรม + วิธีใช้งานของ
> EA_CORE (D:\EA_Project) และ EA_Template (D:\EA_LAB\ea_template) เท่านั้น** — สถานะ%/decision/แผน
> อยู่ที่ `PROJECT_STATE.md` · ผล validate + แผนปิด loop อยู่ที่ `EA_CORE_ST03_LOOP_PLAN.md`

**เขียน:** 2026-07-02 · **สำหรับ:** คน/AI ที่ต้องเข้าใจว่าสองระบบนี้คืออะไร ทำงานยังไง ใช้เมื่อไหร่

---

## 1. ภาพใหญ่ — สองระบบนี้คืออะไร ต่างกันยังไง

ทั้งคู่คือ "โครง EA สำเร็จรูป" (chassis) ที่ให้เสียบ signal เข้าไปโดยไม่ต้องเขียน risk/lot/execution ใหม่ทุกครั้ง
— **ซ้ำซ้อนกันเชิงจุดประสงค์โดยยอมรับ** (สร้างคนละรอบ คนละสไตล์วิศวกรรม). บทบาทถูก align ใหม่
2026-07-03 ตาม `VISION.md` (แม่พิมพ์เดียว · function กลางร่วมกัน · ต่างแค่ entry+TF):

| | **EA_Template (Boss V2)** | **EA_CORE_V1** |
|---|---|---|
| ที่อยู่ | `D:\EA_LAB\ea_template` | `D:\EA_Project\CURRENT_BUILD` |
| บทบาท (update 2026-07-06) | **แม่พิมพ์หลักตัวเดียวของโรงงาน** — smoke + production ออกจากที่นี่ทั้งหมด | 🏛️ **read-only ARCHIVE (MERGE-08)** — อะไหล่ถูก port เข้าแม่พิมพ์ครบแล้ว · เหลือแค่ reference/หลักฐาน · ห้ามมีงานใหม่ |
| ปรัชญา | เร็ว ง่าย dropdown ทุกอย่าง — เจ้าของเข้าใจได้ทั้งตัว | contract-first, ทุก module มี test (regression 1417 PASS / 0 FAIL) |
| ความลึก | 1 ไฟล์ .ex5 ต่อ entry, indicator built-in | module แยกชั้น: signal / executor / risk / adapter |
| Execution | market order ขาเดียว (pyramid ยังไม่มี — อะไหล่ที่รอ port คือ ScaleExecutor_v2) | ScaleExecutor_v2 = multi-leg pyramid (pending LIMIT/STOP + OCO) |
| สถานะ (ดู PROJECT_STATE) | UNFREEZE — งานค้าง: เติม Hedge/Recovery + smoke-regression | loop ปิดแล้ว (fallback) — เก็บเป็นคลังอะไหล่ |

**เมื่อไหร่ใช้ตัวไหน (aligned 2026-07-03):**
- ไอเดียใหม่ (entry ใหม่ *หรือ* กลไกใหม่×symbol) → **Boss V2** ก่อนเสมอ (ผ่าน `/signal-scan` pipeline)
- เขียน **standalone** ได้เฉพาะเมื่อแม่พิมพ์ยังแสดงกลไกนั้นไม่ได้ = **ทางด่วนชั่วคราว** — พิสูจน์ edge
  เมื่อไหร่ **ต้อง port กลับเข้า Boss V2** (เพิ่ม entry/module ให้แม่พิมพ์) + re-confirm เลขตรงเดิม
  ก่อน deploy. ห้ามปล่อย standalone เป็นถาวร (ยกเว้น EA ที่ live อยู่แล้ว — grandfather ถึง judge)
- 🏛️ **(MERGE-08, 2026-07-06) EA_CORE = read-only ARCHIVE แล้ว** — อะไหล่ถูกดูดเข้า Boss V2
  ครบ: pyramid ladder = `STACK_PYRAMID(93)` (DESIGN_V2 §3c) · portfolio guard = `RC_AcctDDLimitPct` ·
  state persist = `core\Persist.mqh` · test pattern = `ea_template\tests\` — ต้องการ execution/กลไก
  ใหม่ = เขียนที่ Boss V2 เท่านั้น อ่าน CORE เป็น reference ได้ (ห้ามลบ) แต่ห้ามมีงานใหม่เข้า
  บันทึก merge → `AGENT_TASKBOARD_MERGE.md` (CLOSED) · ชิ้นเดียวที่ยังรอเงื่อนไข = StrategySignal_v4
  → Entry_ST03 (MERGE-07 hold ถึง judge 2026-09-22)

---

## 2. EA_CORE_V1 (`D:\EA_Project\CURRENT_BUILD`)

### 2.1 โครงสร้าง directory

```
D:\EA_Project\CURRENT_BUILD\
├── CORE\        ← engine: contract .mqh + implementation _v1.mqh + test ต่อ module (~114 ไฟล์)
├── TEMPLATE\    ← ไฟล์ .mq5 จริง: EA_TEMPLATE / EA_RUNNER / EA_RUNNER_ST03(B) + standalone EA ทั้งหมด
├── DOCS\        ← spec/roadmap/playbook (11 ไฟล์)
├── TEST_RESULTS\ · ARCHIVE\
└── PROJECT_MASTER_SPEC.md   ← ทะเบียนสถานะ module (source of truth ฝั่ง code)
```

### 2.2 Phases 0–J (สร้างอะไรไปแล้วบ้าง)

| Phase | ของ | ไฟล์หลัก |
|---|---|---|
| 0 | Walking skeleton (โครง EA เปล่าที่รัน+log ได้) | `PHASE_0_WALKING_SKELETON_RECORD.md` |
| A | Signal v2: MACD + zero-line filter | `CORE\StrategySignal_v2.mqh` |
| B/D/E | Session filter · MTF gate (H4 MACD) · close-on-reverse | ฝังใน `EA_RUNNER_ST03B.mq5` |
| F | LotSizer v1 (progressive step-on-loss) | `CORE\LotSizer_v1.mqh` |
| G | Signal v3: MACD+RSI+EMA | `CORE\StrategySignal_v3.mqh` |
| H | Signal v4: MACD consecutive-bar + **edge trigger** (หัวใจ ST03) | `CORE\StrategySignal_v4.mqh` |
| I | ScaleExecutor v1 (market) → **v2 (limit-order pyramid)** | `CORE\ScaleExecutor_v2.mqh` |
| J | Signal v5: Donchian breakout + ATR-expand (ใช้ใน EA_BREAKOUT_XAU) | `CORE\StrategySignal_v5.mqh` |

### 2.3 Module สำคัญ (CORE\)

- **Signals:** `StrategySignal_v1..v5.mqh` — v4 = MACD edge-trigger (ST03 replica) · v5 = Donchian+ATR (สาย breakout XAU)
- **Execution:** `ScaleExecutor_v2.mqh` — leg0 market + legs 1..N pending (LIMIT scale-in / STOP pyramid)
  ระยะ `Nearby`, TP แยกต่อ leg, OCO. (v1 = market ล้วน, เลิกใช้ใน runner แล้ว)
- **Risk 3 ชั้น:** `RiskEngine_v1` (DD hard-kill) · `PortfolioGuardian_v1` (block entry เมื่อ DD เกิน) ·
  `EntryGate_v1`/`ExitGate_v1` (รวม signal+filter ก่อนยิง)
- **Sizing:** `LotSizer_v1.mqh`
- **Infra:** `Logging_v1` · `Diagnostics_v1` · `StatePersistence_v1` · `ConfigValidator_v1` ·
  `PositionTracker_v1` · adapters (`RuntimeMarketDataAdapter_v1`, `IndicatorDataTerminalAdapter_v1`) ·
  `ExecutionMock_v1` (dry-run) · `ScenarioHarness_v1` (test framework)

### 2.4 วิธีประกอบ EA หนึ่งตัว (contract-first pattern)

1. **contract** — `<Module>_Contract.mqh` (struct/enum/API, ไม่มี logic)
2. **implement** — `<Module>_v1.mqh` (module เดียวเป็นเจ้าของ terminal call ของ domain นั้น)
3. **test** — `<Module>_v1_Test.mq5` (EA harness ยิง assert)
4. **wire เข้า runner** — เลือก signal + executor ใน `#include` ของไฟล์ TEMPLATE\*.mq5 เช่น:

```mql5
#include "../CORE/StrategySignal_v4.mqh"   // ← สลับ signal ตรงนี้
#include "../CORE/ScaleExecutor_v2.mqh"    // ← เลือก executor
#include "../CORE/PortfolioGuardian_v1.mqh"
```

5. **compile** — ไม่มี build script กลาง ใช้ MetaEditor headless:
   `& "D:\Meta 5\MetaEditor64.exe" /compile:"...\TEMPLATE\EA_RUNNER_ST03.mq5"`
6. **backtest** — ผ่าน automation ของ EA_LAB (`D:\EA_LAB\scripts\mt5_run.ps1`, ปิด MT5 GUI ก่อน)

### 2.5 ตระกูล ST03 ใน EA_CORE (ระวังสับสน — 3 ตัวคนละอย่าง)

| ตัว | ไฟล์ | คืออะไร |
|---|---|---|
| **ST_EA03** (ต้นฉบับ) | standalone .ex5 (นอก framework) | edge จริงที่ live อยู่ (magic 9397/9398) |
| **EA_RUNNER_ST03** | `TEMPLATE\EA_RUNNER_ST03.mq5` | replica บน framework (v4 + ScaleExecutor_v2) — deploy demo magic 990010 |
| **EA_RUNNER_ST03B "TG"** | `TEMPLATE\EA_RUNNER_ST03B.mq5` | variant pyramid + session gate + MTF gate — **ตัวที่ overfit** (IS 7.08 → OOS พัง) |

.set สำคัญ: `D:\EA_LAB\_mt5_auto\ST03B_trendgate_v1.set` · `ST03_sized5_v1.set` (sized ปลอดภัย) ·
report validate อยู่ `D:\EA_LAB\_mt5_auto\reports\ST03B_TG_*.htm`

**levers หลักของ runner:** `InpLotRepeat` (จำนวน leg) · `InpTp3Pts` · `InpNearbyPip` (ระยะ ladder) ·
`InpPendingMode` (2=LIMIT/3=STOP) · `InpEdgeTrigger` · `InpMagic` — รายละเอียด+แผน diagnose overfit
→ **`EA_CORE_ST03_LOOP_PLAN.md`** (D:\EA_LAB)

### 2.6 เอกสารฝั่ง EA_Project ที่ควรรู้

- `PROJECT_MASTER_SPEC.md` — ทะเบียน module + ผล regression
- `DOCS\EA_CORE_V1_SOURCE_OF_TRUTH.md` — registry + phase gate
- `DOCS\STRATEGY_SIGNAL_PLAYBOOK.md` — วิธีเขียน signal ใหม่ + wire
- `EA_CORE_V1_FREEZE_STATUS.md` — ผล validate v4/v5 + ST03B

---

## 3. EA_Template / Boss V2 (`D:\EA_LAB\ea_template`)

### 3.1 โครงสร้าง + V1 vs V2

```
ea_template\
├── EA_LabTemplate.mq5      ← V1 เดิม (entry เลือกจาก dropdown) — legacy, เก็บอ้างอิง
├── modules\                ← module ของ V1 (ซ้ำกับ core\ โดยตั้งใจ — คนละ generation)
├── Boss_11_GridTrend.mq5   ← V2: 1 EA = 1 entry (compile-time #define LAB_ENTRY 11)
├── Boss_12_Breakout.mq5    ←     (LAB_ENTRY 12 = Donchian breakout)
├── Boss_13_MeanRev.mq5     ←     (LAB_ENTRY 13 = BB/RSI mean reversion)
├── core\                   ← module ของ V2 (ตัวจริงปัจจุบัน)
│   ├── LabCore.mqh         ← dispatcher OnInit/OnTick + #if LAB_ENTRY
│   ├── Inputs / Indicators / Execution / RiskControl / MoneyManagement / ExitManager
│   ├── Stack.mqh           ← V2 ใหม่: SINGLE / GRID_TREND / GRID_AGAINST(DCA)
│   ├── Recovery / Hedge / Basket (stub, ปิดไว้)
│   └── entries\ IEntry.mqh + Entry_{GridTrendMA,Breakout,MeanReversion}.mqh
├── sets\                   ← .set baseline + ชุด optimize ราย symbol
├── deploy.ps1              ← copy เข้า MT5 Experts + compile
└── README.md · DESIGN_V2.md · OPTIMIZE_GUIDE.md
```

> **หมายเหตุ duplication:** `modules\` (V1) กับ `core\` (V2) มีไฟล์ชื่อซ้ำกันโดยตั้งใจ —
> V1 ยังใช้ได้ผ่าน `EA_LabTemplate.mq5` แต่ **งานใหม่ทั้งหมดใช้ V2 (Boss_*.mq5 + core\)**

### 3.2 chassis ให้อะไร (ทุก entry ได้ฟรี)

- **Risk 3 ชั้น** (`RiskControl.mqh`): hard-kill DD% · caps (MaxLot / MaxDepositLoad% / MaxRecoverySteps) · adherence score
- **Exit** (`ExitManager.mqh`): TP/SL โหมด FIXED / MONEY / ATR / RUN_TREND (+Donchian/SR)
- **Lot** (`MoneyManagement.mqh`): first lot FIXED/RISK% · progression NONE/LINEAR/MULT/PLUS/LOG
- **Stack** (`Stack.mqh`): single / grid-trend / DCA ต่อ entry
- **Dry-run guard** (`InpDryRun`) + indicator built-in เท่านั้น (iMA/iATR/iHighest/iLowest — ไม่พึ่ง custom)

### 3.3 เลขรหัส V2 (อ่าน report/optimize ได้โดยไม่ต้องเปิด lookup)

หลักสิบ = แกน, ค่า enum = ตัวเลขดิบใน XML: **1x** entry (11 Grid·12 Breakout·13 MR) · **2x** TP
(21 FixPip·22 ATR·23 Trail·24 RunTrend) · **3x** SL (30 None·31 FixPip·32 Money·33 ATR·34 Donchian·35 SR) ·
**4x** first lot (41 Fixed·42 Risk%) · **5x** progression (50–54) · **6x** direction (60 Both·61 L·62 S) ·
**7x** filter (70 None·71 ATR-expand·72 MA-slope) · **8x** recovery (80–83) · **9x** stack (90–92).
input prefix ตามแกน: `Inp11_`, `Inp22_`, `Inp33_` … (รายละเอียด → `DESIGN_V2.md`)

### 3.4 วิธีเสียบ signal ใหม่ (4 ขั้น)

1. เขียน `core\entries\Entry_<ชื่อ>.mqh` — คืน struct `EntrySignal` ตาม `IEntry.mqh`
2. เพิ่ม input group ใน `core\Inputs.mqh` ใต้ `#if LAB_ENTRY==14` (เลขถัดไป)
3. เพิ่ม dispatch ใน `core\LabCore.mqh` ใต้ `#if LAB_ENTRY==14`
4. สร้าง `Boss_14_<ชื่อ>.mq5` = 2 บรรทัด: `#define LAB_ENTRY 14` + `#include "core/LabCore.mqh"` → compile

### 3.5 รอบ smoke test มาตรฐาน

```powershell
& D:\EA_LAB\ea_template\deploy.ps1 -Compile        # copy + compile เข้า MT5
# ปิด MT5 GUI ก่อน แล้ว:
& D:\EA_LAB\scripts\mt5_run.ps1 -Expert "EALabTpl\Boss_12_Breakout" `
    -Symbol XAUUSD -Model 1 -FromDate 2023.01.01 -ToDate 2026.06.01 -ReportName Tpl_smoke
& D:\EA_LAB\scripts\fetch_report.ps1 -Mode single   # ดึง PF/trades เข้า log
# ถ้ารอด → optimize หยาบ: scripts\optimize_loop.ps1 (แผน 27-combo ดู OPTIMIZE_GUIDE.md)
```

เกณฑ์ตาย/รอด + ลำดับ smoke เต็ม → skill `signal-scanner` + `MASTER_BACKLOG.md`

---

## 4. จุดต่อกับ pipeline EA_LAB (ภาพรวม flow)

```
ไอเดีย (entry ใหม่ หรือ กลไก×symbol ใหม่) ──► /signal-scan (triage + เลือก symbol×TF)
      │
      ▼
Boss V2 (แม่พิมพ์) ── smoke (Model 1) ──► ตาย = จบ (บันทึก MASTER_BACKLOG)
      │ รอด                     ▲
      ▼                         │ port กลับ + re-confirm เลข (บังคับ)
optimize หยาบ → IS/OOS → MC/WF  │
      │ PASS                    │
      ▼                         │
(ถ้าจำเป็นต้องอ้อมผ่าน standalone ชั่วคราว ──────┘)
      │
      ▼
corr gate ──► deploy demo จากแม่พิมพ์ (vps-deploy-ops) ──► /ea-monitor
```

- Boss V2 = ทั้งด่านแรกและปลายทาง production (แม่พิมพ์เดียวตาม `VISION.md`) · EA_CORE = archive
  (pyramid/portfolio-guard/persist/test-pattern อยู่ในแม่พิมพ์แล้ว — MERGE track ปิด 2026-07-06)
- standalone = ทางด่วนชั่วคราวเท่านั้น — พิสูจน์ edge แล้วต้อง port เข้าแม่พิมพ์ก่อน deploy
- ทั้งหมดใช้ automation กลางชุดเดียวกัน: `D:\EA_LAB\scripts\` + `_mt5_auto\` (กฎ: ปิด GUI, Model 4 ก่อนตัดสินจริง, window 2023–2026)
