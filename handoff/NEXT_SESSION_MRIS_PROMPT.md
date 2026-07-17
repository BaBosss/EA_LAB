# Paste this to open the next session (MRIS continuation)

---

ต่องาน ORDER-073 (news/macro risk system). อ่านลำดับนี้ก่อนเริ่ม: `PROJECT_STATE.md` →
`CLAUDE.md` → `AGENTS.md` → `handoff/SESSION_2026-07-17C_MRIS_HANDOFF.md` (สรุปสิ่งที่ทำไปแล้ว)
→ `scripts/mris/README.md`. เช็ค `git log --oneline -15` หา `[codex]`/`[zcode]` + review
AGENT_TASKBOARD.md ก่อนเริ่มงานใหม่ (on-return protocol).

**สถานะที่ทำเสร็จแล้ว (commit 874347f + 3d5d1ac บน master):**
- NewsGuard (event-block) build เสร็จ + GuardConfig draft + runbook rclone — รอ **user attach เอง**
- MRIS (macro-regime layer) prototype รันได้: `& D:\EA_LAB\scripts\mris\mris_run.ps1` →
  `portfolio/mris/whisper_brief.md`. อ่านตอนนี้ = NEUTRAL + 2 loaded lines (AUDJPY ใกล้ pin 110, USDJPY 161 crowded).

**งานที่อยากให้ทำต่อ (เรียงความสำคัญ — ยืนยัน scope กับผมก่อนลงมือหนัก, ห้าม build เต็มก่อนเคาะ):**
1. **[สำคัญสุด] Web feeder เติม barometer ที่ยัง PENDING** — VIX, DXY, US10Y-JP10Y spread, copper
   (broker ไม่มี). เขียน PowerShell feeder แบบเดียวกับ `scripts/news_calendar.ps1` (fetch+cache+
   เขียนลง `portfolio/mris/barometer_snapshot.csv` schema เดิม: symbol,spot,sma200,atr20,chg5d_pct,
   data_status,source_note). เสร็จแล้ว Risk Index จะครบเส้น = "เส้นเตือนขนานกัน" ตามธีมบทความจริง.
2. **เคาะ tripwire threshold กับผม** — ค่าใน `scripts/mris/barometers.json` ตอนนี้เป็น default ของ
   Claude หมด. #073 บอกว่า **ผมเป็นคนเคาะเลขเอง** (110, ATR mult, VIX bands). ถามผมทีละตัว.
3. **ฝัง whisper brief เข้า LIVE_DASHBOARD gist** (ให้เห็นบนมือถือทุกเช้า) + ต่อเข้า daily chain
   ข้าง news_calendar. ใช้ `portfolio/mris/whisper_brief.html` (fragment พร้อม embed แล้ว).
4. **[ห้ามเริ่มจนกว่า 1+2 เสร็จ] Phase-3 MacroGate** — watchdog แบบ NewsGuard ที่ reduce-lot×0.5 +
   block-new เฉพาะ carry legs ตอน RISK_OFF (ไม่ปิด position). trigger ต้อง relative (ห้าม hardcode
   110) + **บังคับ A/B backtest บน window 2024-08-05 carry unwind + 2020-03** ก่อน attach. spec ใน
   AGENT_TASKBOARD ORDER-073 Phase-3 stub.

**กติกาสำคัญ (จาก CLAUDE.md/memory — ห้ามพลาด):** MRIS = read-only เสนอ "เฝ้าระวัง/ลด lot" ไม่ auto-trade ·
correlation/risk → reduce-lot ไม่ cut · shared worktree มีหลาย session → commit path-limited, เช็ค HEAD ก่อน stage ·
ทุกอย่างเป็น PowerShell 5.1 → เลี่ยงฝัง non-ASCII ใน .ps1 (แยกไป JSON อ่านด้วย -Encoding UTF8).

Boss = ผม (p.atipayoon@gmail.com). ตอบไทย สั้น แนะนำเด็ดขาด 1 ทาง.
