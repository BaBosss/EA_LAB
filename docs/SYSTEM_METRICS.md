# SYSTEM_METRICS — วัดตัวระบบเอง (นับรายเดือนจาก taskboard)

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **metrics ของระบบ delegation เท่านั้น**
> (order ปิดต่อ tier, rework rate, escalation) — ที่มา: `AGENTS.md` §6 (adopt จาก PORTABLE_AI_OS 2026-07-06)
>
> **วิธีนับ (เดือนละครั้ง, Claude):** กวาด order ที่ REVIEWED ในเดือนนั้นจาก AGENT_TASKBOARD*
> ทุกบอร์ด → ต่อ order ตอบ 4 ช่อง: ใครทำ (tier) · ผ่าน cage/acceptance รอบแรกไหม · ต้อง
> escalate/rework ไหม · หมายเหตุ → เกณฑ์เตือน: **tier ถูกสุด rework >~30% = cage หยาบไป
> หรืองานประเภทนั้นไม่ควรอยู่ tier นั้น**

## 2026-07 (นับครั้งแรก — งวดถัดไป ~2026-08-01)

| Order | Tier ที่ทำ | ผ่านรอบแรก? | Escalate/Rework? | หมายเหตุ |
|---|---|---|---|---|
| MERGE-01 | Claude | ✅ | — | defaults บางเกิน → สลับเป็น pinned set (แก้ใน order เดียวกัน ไม่นับ rework) |
| MERGE-02 | Codex | ✅ | — | converge 4/4, ข้อเสนอถูก adopt 2 ข้อ |
| MERGE-04 | Claude | ✅ | — | gate-trip proof ต้องเปลี่ยน config ทดสอบ 3 รอบ (ไม่ใช่ rework ของโค้ด) |
| ORDER-038 | Claude | ✅ | — | (session คู่ขนาน) backward-OOS ฆ่า pun fix lot |

**อ่านผลงวดนี้:** ยังไม่มีสัญญาณ tier ผิด — แต่เดือนนี้งานเกือบทั้งหมดตกที่ Claude เพราะ
Codex/ZCode quota หมด (สถานการณ์พิเศษ ไม่ใช่ pattern) · เริ่มอ่านแนวโน้มได้จริงตั้งแต่งวด 2026-08
