# Prompt เปิด session ใหม่ (EA_LAB continuation)

> คัดลอกบล็อกด้านล่างวางใน Claude Code session ใหม่ (repo D:\EA_LAB)

---

กลับมาต่องาน EA_LAB — รัน on-return protocol ก่อน: `git log --oneline -20` (หา [codex]/[zcode]),
อ่าน `handoff/SESSION_2026-07-17_HANDOFF.md` §START HERE + `PROJECT_STATE.md`, เช็ค AGENT_TASKBOARD
DONE/BLOCKED, รัน `scripts/check_state.ps1`. ต่อ HEAD จาก handoff ล่าสุด (rescue-close + demo-attach + TSD-reject).

⚠️ อ่านก่อนตัดสิน EA: CLAUDE.md VERDICT GATE + memory [[signal-landscape]] [[feedback-correlation-lotsize]]
[[feedback-optimize-before-killing-reversion]]. บทเรียน session ก่อน 3 ข้อ:
(1) entry-signal PERIOD/lever = lever แรกเสมอ — "ceiling" ที่ default ไม่จริง (ICHIMOKU/Wave5 พิสูจน์)
(2) **corr = LIVE-money gate ไม่ใช่ demo gate** — demo เอาขึ้นเทส normal lot ก่อน, corr sizing ตอนเงินจริง
(3) multi-home naked EA อื่น low-yield (symbol-specific จริง) — เน้น period-lever + grid-expansion แทน

งาน session นี้ (user เคาะ "ทำทั้งหมด", เรียง EV):
1. **#4 095 symbol-expand** = **Boss_14 GridLog → ranger crosses ใหม่** (EURCHF/GBPCHF/NZDCAD/AUDCHF ฯลฯ —
   grid=ranger mechanism, มี IS-pick pipeline ที่ ea_template/sets/) × both-window Model-4 (grid ต้อง Model-4).
   pace 1-2 symbol/รอบ. naked EA อื่นข้าม (low-yield พิสูจน์แล้ว)
2. **#098 corpus build-on** (ทำเรื่อยๆ) — fxDreema IDEA_CATALOG (`_triage/FXDREEMA_IDEA_CATALOG.md`) เลือก concept
   ที่ user prioritize → spec (strategy-and-risk) → build (mql-code-generator) → mql-review → both-window Model-4
3. **091 remaining leads** — prior ต่ำหลัง TSD OsMA+WPR reject; build เฉพาะถ้า user รู้จัก classic EA ตัวดัง
   (`_triage/ORDER111_mq4_BUILD_SHORTLIST.md`)

รอ user: attach Wave5 UJ 990303 · #4 เริ่มไหม · git push (remote เข้าไม่ถึงจากเครื่องนี้ = TLS-proxy)

Gotchas: compile ea_projects = PowerShell Copy-Item -LiteralPath + D:\Meta 5\MetaEditor64 (roaming 9CA16B) ·
python312 embed พัง → PowerShell · MT5 htm space-thousands-sep · ห้าม burst (pace 1-2) · เก็บ main context ไว้ judge
