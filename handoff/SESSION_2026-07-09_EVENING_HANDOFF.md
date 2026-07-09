# HANDOFF — Session 2026-07-09 บ่าย-ค่ำ (Fable seat): regime lever + idea mining + 3 builds

> **For:** next session. Self-contained pointers; do NOT re-derive. รายละเอียดทุก verdict อยู่ใน
> AGENT_TASKBOARD.md (ORDER-057..066) — ไฟล์นี้คือแผนที่ + บทเรียน ไม่ duplicate เนื้อหา.
> เช้าวันเดียวกันมีอีกไฟล์: `SESSION_2026-07-09_HANDOFF.md` (8-EA cohort พร้อม attach).

## Where things stand (one line)
Cohort 8 ตัวรอ user attach (checklist 5 ข้อใน ORDER-055) · regime lever `_50_` เข้าแม่พิมพ์แล้ว +
ได้บ้าน 2 หลัง (XAU, USDJPY-CANDIDATE) · hunt ใหม่ 3 ตัววันนี้ = RESERVE 1 / ตาย 2 พร้อมสำนวนครบ

## จบแล้ววันนี้ (14+ commits — ดู `git log --oneline --since=2026-07-09`)
- **ORDER-057 ✅** Regime.mqh (ADX trend/range + ATR storm, mode0=off default) — Codex build,
  Claude พิสูจน์ no-op ระดับ source เอง (compile ทั้งสองแบบ เทียบเลขเป๊ะ) · cage re-baselined
  (history refresh ไม่ใช่โค้ด — บทเรียน: trade-count-เท่า-กำไรขยับนิด = data-side, control run เสมอ)
- **ORDER-058 ✅** live_dashboard.ps1 (per-magic HTML, MT5+MT4 dual format) — รอข้อมูลจริงหลัง attach
- **ORDER-059 ❌** COT gate REJECT (year-split พลิก + MC แย่ลง) — เก็บ cot_pull.ps1 เป็นไฟ context เท่านั้น
- **ORDER-060 ✅** OrdersExporterMT4.mq4 + collector + dashboard รองรับ MT4 (ต้องตั้ง All History)
- **ORDER-043 ❌** US30 DEAD-optimized (IS 13-pass plateau → OOS 1.03 + BWD 0.86 = regime artifact)
- **ORDER-061 ❌** FlagPennant NO EDGE — insight: flag เกิดหลัง impulse กินโมเมนตัมแล้ว TP กว้าง = ตาย
- **ORDER-062 🎯** regime family sweep: **USDJPY = hit** (BWD 1.07→1.65 plateau, MC 0.946→1.203
  = CANDIDATE เข้า Boss V2 bench, set `FAM_USDJPY_m1t25.set`) · EURJPY reserve · **EURUSD = คำเตือน:
  gate ไม้แรก + grid ที่พึ่ง entry ถี่ = dynamics พัง** · lever เลือกบ้าน ไม่ universal
- **ORDER-063 ❌** Downloads 3 ตัวตายครบ — Degold: martingale-recheck ตก 4/4 + **M1 vs M4 artifact
  พิสูจน์เด็ดขาด (M1 +$344k / M4 −$4.3k cell เดียวกัน)** · หลักการที่เก็บ: basket-trailing-from-avg
  → mold-lever backlog · **Family2.2.ex5 = DQ-SECURITY (DLL+WebRequest ไป ea.sytes.net — ห้ามแตะ)**
- **ORDER-064 ✅** JSON 93MB → 12 catalogs → ranked: SuperTrend(1) VWAP(2) Z-pairs(3) + graft ideas
- **ORDER-065 🅿️** SuperTrendFlip RESERVE — ผ่าน 3 windows (atr22/m4: 1.02/1.11/1.32) แต่ MC PF-5th
  0.865 = **จุดข้อมูลที่ 3 ของ naked-signal floor ~0.85 บนทอง** · เส้นทางกู้ = confluence+RR (สูตร SqueezeBRK)
- **ORDER-066 ❌** VWAP WaveS1 NO EDGE (ลบทุก cell BWD ทั้ง 30 cells) — **insight ปิดทั้ง family:
  tick volume บน CFD ≠ volume จริง → VWAP anchor เป็นของปลอมบน instrument ที่เรามี**

## งาน session หน้า (EV order)
1. **[user] attach!** — checklist 5 ข้อ (ORDER-055) ยังเป็นคอขวดเดียวของทั้งระบบ →
   แล้ว Claude: ลงทะเบียน DEMO_DEPLOYMENT_PLAN + judge +3mo + scheduled task (collector+dashboard)
2. **SuperTrendFlip rescue** (ORDER-065): เติม Donchian/squeeze confluence + tight-SL/wide-TP re-opt
   → ถ้า MC ข้าม 1.0 → corr เทียบ Zeus/BRK/SqueezeBRK (family เดียวกัน corr สูง = จบ)
3. **Boss V2 track**: USDJPY m1t25 CANDIDATE รอ bench · Codex กลับ 11 ก.ค. → basket-trailing lever
   (จาก Degold) เป็นงาน mold ชิ้นถัดไป (additive + cage)
4. Z-score pairs feasibility (backlog) · เหมือง JSON เหลือ 33 convs (อ่านเฉพาะถ้าอยากได้ lead เพิ่ม)

## บทเรียนใหม่วันนี้ (ยังไม่อยู่ใน skill — ควร bank เข้า backtest-optimize-rigor)
- **Model-1 trap ตรวจง่าย:** n ผิดธรรมชาติ (หมื่น-แสนไม้) + PF สวย = ต้อง M1-vs-M4 same-window ก่อนเชื่อ
- **Naked-signal floor บนทอง H1 = PF-5th ~0.85** (squeeze 0.837 / trendline 0.867 / supertrend 0.865)
  — อย่าเสียเวลา build สัญญาณเดี่ยวเพิ่ม ให้เริ่มจาก confluence เลย
- **VWAP/volume-based กลยุทธ์ = ตายตั้งแต่ instrument** บน MT5 spot-CFD (tick volume ปลอม)
- **Regime gate ห้ามใช้กับ grid ที่พึ่ง entry ถี่** (EURUSD พัง: ไม้ระเบิด 189→425)
