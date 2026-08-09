# HANDOFF ORDER — ย้าย ZeusInspired_GridLog ออกจาก archive → EA_LAB

> **สำหรับ:** session ที่กำลังทำ ZeusInspired_GridLog อยู่ (เจ้าของงาน)
> **จาก:** session "Order-36 backtest analysis" (Opus-seat) + user · **วันที่:** 2026-07-08
> **หยิบไปรันได้เลย** — order นี้ self-contained ไม่ต้องอ่านบทสนทนาต้นทาง
> **สถานะ:** ✅ **เสร็จสมบูรณ์แล้ว 2026-07-08** — ย้ายครบทุกขั้นตอน: archive git rm (EA_Project commit `fbb4aed`) · ไฟล์อยู่ที่ `ea_projects/(Boss)_ZeusInspired_GridLog/` ครบ (source + .ex5 + 12 .set + reports) · path ใน scorecard/PROJECT_STATE ชี้มาที่ใหม่แล้ว · README banner อัปเดตแล้ว. **order นี้ obsolete — ไม่ต้องทำซ้ำ** (เก็บไว้เป็น audit trail เท่านั้น). ยืนยันซ้ำ session 2026-07-09.

---

## WHY (ทำไม)
EA standalone Boss ทุกตัวต้องอยู่ `D:\EA_LAB\ea_projects\<ชื่อ>\` เท่านั้น. `D:\EA_Project` = **read-only ARCHIVE** ตั้งแต่ MERGE-08 (2026-07-06) — ห้ามมีงานใหม่/compile ลงคลัง. ZeusInspired เป็น standalone ตัวสุดท้ายที่ยังค้างอยู่ในคลัง (RSI_MR_GridLog ย้ายไปแล้ว = EA_LAB commit `3436b2ad`; กติกา guide แก้แล้วที่ `docs/EA_CORE_AND_TEMPLATE_GUIDE.md §1`).

## PRE-CHECK (ก่อนเริ่ม — ต้องจริงทุกข้อ)
1. เทส ZeusInspired รอบปัจจุบันจบแล้ว ไม่มี backtest/optimize รันค้างที่อ่านไฟล์จาก `D:\EA_Project\...\TEMPLATE\`.
2. home ปลายทางมีอยู่แล้ว: `D:\EA_LAB\ea_projects\(Boss)_ZeusInspired_GridLog\` (+ `set_files\`, `reports\`, README) — EA_LAB commit `4b951abe`. ถ้าไม่มีให้ `mkdir` เอง.

## STEPS (ทำตามลำดับ)

**1. copy source สุดท้าย เข้า home** (จาก `D:\EA_Project\CURRENT_BUILD\TEMPLATE\`):
```bash
H="/d/EA_LAB/ea_projects/(Boss)_ZeusInspired_GridLog"
cp "/d/EA_Project/CURRENT_BUILD/TEMPLATE/(Boss)_ZeusInspired_GridLog_rev01.mq5" "$H/"
cp "/d/EA_Project/CURRENT_BUILD/TEMPLATE/(Boss)_ZeusInspired_GridLog_rev01.ex5" "$H/"   # ถ้ามี .ex5 ล่าสุด
cp /d/EA_Project/CURRENT_BUILD/TEMPLATE/ZeusInspired_*.set "$H/set_files/"               # 12 ไฟล์
# report .htm ที่ validate แล้ว (ถ้ามี) -> "$H/reports/"
```

**2. ลบออกจากคลัง — ⚠️ ต่างจาก RSI_MR: ไฟล์ ZeusInspired เป็น git-TRACKED ใน EA_Project (ไม่ใช่ orphan)** → ต้อง `git rm` + commit ฝั่งคลัง:
```bash
cd /d/EA_Project
git rm "CURRENT_BUILD/TEMPLATE/(Boss)_ZeusInspired_GridLog_rev01.mq5" \
       "CURRENT_BUILD/TEMPLATE/ZeusInspired_"*.set
# .ex5 ในคลังถ้ามีและ tracked ก็ git rm ด้วย; ถ้า untracked ใช้ rm เฉยๆ
git commit -m "[claude] ZeusInspired moved out of archive -> EA_LAB\ea_projects (see EA_LAB commit)"
```

**3. อัปเดต path ที่อ้างของเดิม** — grep แล้วแก้ให้ชี้มา home ใหม่:
```bash
grep -rl "EA_Project.*ZeusInspired\|TEMPLATE.*ZeusInspired" /d/EA_LAB/EA_SCORECARD_AND_REGISTRY.md /d/EA_LAB/PROJECT_STATE.md
```
แก้เป็น `D:\EA_LAB\ea_projects\(Boss)_ZeusInspired_GridLog\...`

**4. ปิดงานฝั่ง EA_LAB** — ลบแบนเนอร์ `⏳ MOVE PENDING` + บล็อก "MOVE CHECKLIST" ออกจาก `ea_projects\(Boss)_ZeusInspired_GridLog\README.md` (งานเสร็จแล้ว), แล้ว commit:
```bash
cd /d/EA_LAB
git add "ea_projects/(Boss)_ZeusInspired_GridLog/" EA_SCORECARD_AND_REGISTRY.md PROJECT_STATE.md
git commit -m "[claude] ZeusInspired relocated into EA_LAB\ea_projects (archive now clean of standalone Boss EAs)"
```

**5. compile ต่อจากนี้ที่ EA_LAB เท่านั้น:**
```powershell
& "D:\Meta 5\metaeditor64.exe" /compile:"D:\EA_LAB\ea_projects\(Boss)_ZeusInspired_GridLog\(Boss)_ZeusInspired_GridLog_rev01.mq5"
```

## ACCEPTANCE (ตรวจได้ด้วยตัวเลข — ต้องผ่านทุกข้อ)
- [ ] `ls "/d/EA_Project/CURRENT_BUILD/TEMPLATE/" | grep -i zeusinspired` → **0 ไฟล์** (คลังสะอาด)
- [ ] home มี: `(Boss)_ZeusInspired_GridLog_rev01.mq5` (1) + `set_files\*.set` (**12**) + README (ไม่มี MOVE-PENDING แล้ว)
- [ ] `git -C /d/EA_Project status --short` → ไม่มี ZeusInspired ค้าง (commit git rm แล้ว)
- [ ] scorecard/PROJECT_STATE ไม่มี path `EA_Project\...\ZeusInspired` เหลือ
- [ ] `scripts\check_state.ps1` → CLEAN

## ห้าม
- ❌ ห้ามย้ายระหว่างมี backtest/optimize ZeusInspired รันค้าง (ไฟล์หายกลางคัน = พัง)
- ❌ ห้าม compile/เขียน .ex5 กลับเข้า `D:\EA_Project` อีก (guide §1)
- ❌ ห้ามแตะ standalone (Boss)_* ตัวอื่นในคลัง (London/NR/RSI_Swing/Session/TrendRegression) — พวกนั้น commit ก่อนปิดคลัง = residents ที่ถูกต้อง ปล่อยไว้
- ❌ ห้ามแตะ .set/magic ของ EA ที่ live/demo อยู่

## FYI — details
- chain `EA_ZEUSINSPIRED_GRIDLOG_20260703_01` · Magic 990101 (GridLean) / 990102 (TightLean) · standalone L-grid+LOG
- 12 .set: AUDJPY(lot8x/10x/10x_v2/20x) · AUDUSD(lot10x/20x) · EURCAD(lot10x) · GridLean · TightLean · V1_Medium · V2_Tight · V3_VeryTight
