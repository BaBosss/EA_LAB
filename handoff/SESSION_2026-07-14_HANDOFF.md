# HANDOFF → next session (2026-07-14, Opus) — Wave5 demo-ready + 3 orders closed

> อ่าน `VISION.md` → `PROJECT_STATE.md` → this file. อย่าเชื่อไฟล์นี้เหนือ repo — ขัดกันเชื่อ repo + `check_state.ps1`.
> ⚠️ **shared worktree:** session อื่นทำ ORDER-103 C1-ENFORCE คู่กันตลอด session นี้ (thread B ปิดแล้ว, ดูล่าง) —
> HEAD ขยับ 3 ครั้งจาก session นั้นระหว่างที่ผมทำงาน ไม่มีอะไรชนกัน (คนละไฟล์เสมอ) — commit ทั้งหมด path-limited
> เช็ค HEAD ก่อน stage ทุกครั้งตามเคย.

## HEAD ปัจจุบัน: `df2a69c4`

## Thread A — ORDER-082 Wave5 (Entry_17) — ✅ DEMO-ELIGIBLE, bundle staged, จบ

**สถานะสุดท้าย: ผ่านทุก gate, พร้อม attach จริง**
- Plateau ยืนยันครบ 2 symbol: XAU (fib23.6→30 ต่อเนื่อง, plateau-center 1.11/1.11) + XAG (6/6 cell,
  MAIN 1.30-1.45 / BWD 1.28-1.35 — **แข็งกว่า XAU**)
- MC clean: ruin 0.00%, DD worst 7.97%(XAU MAIN)/4.43%(XAU BWD)
- Robust ข้าม TF: XAU H4 MAIN 1.74 / BWD 1.01 (holdout จริง, ไม่เคยใช้ select)
- **Corr gate ผ่านสะอาด:** vs 4 live gold cohort (Zeus/Squeeze/Trendline/Breakout) max\|corr\|=0.415<<0.8
- **Demo bundle staged:** `_vps_deploy/WAVE5_XAU/` (magic 990301) + `_vps_deploy/WAVE5_XAG/` (magic 990302),
  แต่ละ folder มี ex5+locked set+README_DEPLOY.txt (provenance + silent-stop checklist)
- **⚠️ Boss V2 template ตัวนี้ไม่มี tester-gate** (ไม่มี `_06_AllowLive`) — เทรดทันทีที่ attach ไม่ต้องเปิดอะไร

**👉 เหลือ:** user ทำ VPS attach เอง (copy bundle → attach chart quiet window → load set → ยืนยัน magic ใน log)
→ เพิ่ม row DEMO_DEPLOYMENT_PLAN.md + DEPLOYMENTS.csv **ตอน attach จริง** (ยังไม่ pre-register).
Spec-of-record เต็ม = `docs/superpowers/plans/2026-07-12-entry-wave5.md` (Task 6c).

## Thread B — ORDER-103 C1-ENFORCE — ✅ ปิดแล้ว (session อื่น, ไม่ใช่งานผม)
HEAD ขยับผ่าน `c0f7b0db`→`eb06ac64`→`35a6b84c` ระหว่าง session นี้ (thread B). ACCEPT แล้ว, Contract D เปิดแล้ว
(MVP-1-lite event-log). ไม่ต้องแตะซ้ำ — แค่รู้ว่าเกิดขึ้นคู่กัน.

## Thread C — ORDER-076 mq5 smoke — ✅ ปิด
16 mq5 ใหม่จริง (mq4 53 ตัว = ORDER-036 ครอบแล้ว): 4 name-DQ + 12 smoked → **11 REJECT/PARK, 1 build-on-needs-data**
((ICE) CCI Currencies Strength — both-window PF>1 แต่ n=10 บางไป). ลอง basket ขยาย 9 majors แล้ว **ไม่รอด**
(7-13 trades/sym, identical-row artifact = EA ไม่อ่าน chart symbol อิสระ) → **ยืน PARKED ไม่ไล่ต่อ**.
Verdict = `_triage/ORDER076_MQ5_SMOKE_VERDICT.md`.

## Thread D — ORDER-095 CAMPAIGN: EA_BREAKOUT_XAU expand — ✅ ปิด, bundle staged
Flat-lot both-window H4 บน 5 candidate (XAG/GBP/EUR/JPY/US30): **2 ผ่าน** — USDJPY (PF 1.28/1.25, 75-102t)
+ US30 (PF 1.46/1.39, 26-34t **WATCH-thin**). Corr vs XAU home leg: USDJPY 0.066, US30 -0.249 ทั้งคู่<<0.8.
**Bundle staged:** `_vps_deploy/EA_BREAKOUT_USDJPY/` (magic 991003) + `_vps_deploy/EA_BREAKOUT_US30/` (magic 991005).
**⚠️ EA นี้มี tester-gate จริง** (`_06_AllowLive`, set ไว้ true ใน bundled .set แล้ว — ยืนยันใน log หลัง attach).
Verdict = `_triage/ORDER095_BREAKOUT_XAU_EXPAND_VERDICT.md`.

## Thread E — ORDER-097 HexaGrid funnel — ✅ ปิดเต็ม, STRUCTURAL DEAD
sweep spacing×SL (3 combo) ไม่ช่วย (PF ยัง<1 ทุก cell) → flat-lot combined-6-system probe (PF 0.67 MAIN/
0.15 BWD = STRUCTURAL-death criterion ตาม CLAUDE.md) → **isolate ทีละ 6 ระบบ (S1-S6) ไม่มีตัวไหนมี edge เดี่ยว**
(ดีสุด S2 = 0.80/0.76 ยังแพ้). **Verdict: park ทั้ง concept, chassis/risk-mgmt ไม่มีปัญหา ปัญหาอยู่ที่ entry
signal ทั้ง 6 ตัว.** Verdict = `_triage/ORDER097_HEX_FUNNEL_VERDICT.md`.

## Thread F — ORDER-098-A FVGFill_Naked (build ใหม่) — 🟡 PARAMETRIC, ยังไม่ปิด
Build `ea_projects/(EXP)_FVGFill_Naked/FVGFill_Naked.mq5` ใหม่ทั้งตัว (EX009/EX196 FVG-fill algo).
- self-review เจอ BLOCKER ก่อน compile (pip-formula ผิดกับ XAU) → แก้แล้ว
- **rev01** (one-shot 4-bar detection) = under-sample รุนแรง (0-5 trades) → แก้เป็น **rev02** (persistent
  gap-tracking ring buffer 20 zone, age cap 50 bar) → sample โต 263-942 trades/cell
- **ผล rev02 (1 window เท่านั้น, Model 1 2023-2026):** PF<1 ทั้ง 4 cell (0.74-0.97) แต่ win% ใกล้ breakeven
  มาก (49.8-56.7% vs breakeven จริง 57.1% ที่ RR SL20/TP15) — **EURUSD H1 เกือบเสมอทุนพอดี (PF 0.97)**
- **Verdict: PARAMETRIC ไม่ใช่ STRUCTURAL** — ยังไม่มี BWD window, ยังไม่ sweep RR/TP → **ห้ามตัดตายตอนนี้**
- Verdict เต็ม = `_triage/ORDER098A_FVGFILL_SMOKE_VERDICT.md`

**👉 งานถัดของ thread นี้ (ถ้าไล่ต่อ):** (1) BWD window 2020-22 บน 4 cell เดิม (2) sweep RR — ลอง TP กว้างขึ้น
(win% ใกล้ breakeven มาก แค่ปรับ exit อาจดันข้าม 1.0 ได้ — นี่คือเคส "ปรับ exit ไม่ใช่ redesign entry" ต่างจาก
HexaGrid ที่ตายทุก lever). ยังไม่ทำ ORDER-098-B (MACD-divergence) เลย.

## 🔧 Gotcha ใหม่ที่บันทึกไว้ (กันเสียเวลาซ้ำ)
1. **`terminal64.exe '/compile:<path>'` ค้างเปิด GUI เฉยๆ ได้** (ไม่ error ไม่จบ, เจอ 2 ครั้งติดตอนแก้ไฟล์ rev02)
   — **ใช้ `MetaEditor64.exe '/compile:<path>' '/log:<path>'` แทน** (compiler ตัวจริง, เสร็จใน ~450ms ทั้ง 2 ครั้ง)
2. **Bash `Copy-Item` ผ่าน PowerShell ต้องระวัง unix-path vs windows-path ปน** — ถ้า bash var เป็น unix path
   (`/d/EA_LAB/...`) แล้วต่อด้วย backslash literal ใน PowerShell string จะ silent-fail (ถ้ามี `>/dev/null 2>&1`
   คลุมไว้ยิ่งไม่เห็น) — ใช้ `cygpath -w "$var"` แปลงก่อนเสมอ
3. **`New-Item -ItemType Directory -Force` บาง path สร้าง reparse phantom** (`Test-Path` False ทั้งที่
   `Get-ChildItem` เห็น) — เจอกับ `Experts\CORR\` ใหม่ๆ, เลี่ยงโดยใช้ folder เดิมที่พิสูจน์แล้วว่าใช้ได้ (เช่น
   `Experts\O076\`) แทนสร้างใหม่

## Commits ของ session นี้ (ทั้งหมด local push แล้วหรือยัง — เช็คก่อน push)
`b7adf36e` 095-breakout-expand · `575c17e5`+`ce1fd93d` 097-hex-funnel · `0b4acdbc`+`86151de9` 082-demo-eligible
`dde582e5`+`df2a69c4` 098a-fvgfill. + memory ไม่ได้เขียนเพิ่ม session นี้ (ยังไม่มีอะไรเข้าเกณฑ์ save memory ใหม่ —
gotcha ทั้ง 3 ข้อบันทึกไว้ในนี้พอ, ยกเว้นถ้าเจอซ้ำอีกค่อย promote เป็น memory).
