# HANDOFF → next session (2026-07-13, Opus) — 3 live threads

> อ่าน `VISION.md` → `PROJECT_STATE.md` → this file. อย่าเชื่อไฟล์นี้เหนือ repo — ขัดกันเชื่อ repo + `check_state.ps1`.
> ⚠️ **shared worktree:** session อื่น commit บน master คู่กัน (memory `shared-worktree-concurrent-writers`) — commit **path-limited**, เช็ค HEAD ก่อน stage, HEAD ขยับ = หยุด ห้าม rewrite. session นี้เจอ working-tree churn (ไฟล์หายๆโผล่ๆ ตอนอีก session checkout) — commit ผมทั้งหมด reachable-safe ยืนยันแล้ว.

## Thread A — ORDER-082 Wave5 (Entry_17) — 🟢 HOT, กำลัง validate

**สถานะ:** build เสร็จ + probe + sweep เจอ **plateau ผ่าน both-window gate**. spec-of-record = `docs/superpowers/plans/2026-07-12-entry-wave5.md` (อ่าน Task 6 + Task 6b).

- **Build (commit `bfa048f`):** `LAB_ENTRY_17` บน Boss V2 — `Boss_17_Wave5.mq5` + `core/entries/{Entry_Wave5,Wave5Swings}.mqh` + ExitManager/Inputs/Indicators/LabCore edits. compile 0/0 · regression CLEAN (11-16 byte-identical).
  - **บั๊กที่ Opus จับ+แก้ (subagent build พลาด):** labeling 3-pivot → wave1end/wave3peak คนละประเภทเสมอ = **Entry ยิงไม่ออก (zero-trade การันตี)** → แก้เป็น 4-pivot + wave2-validity + fib วัดจาก wave3 จริง.
- **Probe (default fib38.2):** XAU main PF 1.57 / BWD 0.95 · GBP 1.18 / 0.96 = marginal.
- **Sweep both-regime (XAU, 24 runs) → PLATEAU:** **fib=23.6/mult=0.618 = MAIN 1.11(271t) / BWD 1.12(217t), DD<3.4%** · adjacent (23.6,0.382)=1.09/1.07 ก็ผ่าน = plateau จริง. deep fib (38.2-61.8) = overfit ปีเทรนด์ (BWD พัง). **locked set = `_mt5_auto/ab_sets/wave5_sets/sw_F23.6_M0.618.set`**. raw = `_mt5_auto/wave5_sweep_results.csv`.

**⏳ กำลังรัน (background batch, launched 2026-07-13):** cross-symbol OOS (GBP,EUR @ fib23.6) + XAU H4 (TF robustness) + MC บน plateau-center. **ผล → `_mt5_auto/wave5_validate_results.csv` + `wave5_mc.log`**.

**👉 งานถัดของ thread นี้ (judge เมื่อ batch เสร็จ):**
1. อ่าน `wave5_validate_results.csv` — GBP/EUR @ fib23.6 ผ่าน both-window ไหม? (cross-symbol = OOS จริง, ไม่เคยใช้ select) · XAU H4 ยืนไหม?
2. อ่าน `wave5_mc.log` — MC DD 95th/worst/ruin% บน plateau-center (caveat: grid-MC = optimistic lower bound, แต่ Wave5 = naked single ไม่ใช่ grid → MC เชื่อได้กว่าปกติ)
3. **VERDICT GATE #6 ที่ยังค้าง:** 2 window ที่ sweep = ใช้ *select* config แล้ว = in-sample. ต้องมี **holdout ที่ไม่เคยใช้ select** — cross-symbol (GBP/EUR) ทำหน้าที่นี้บางส่วน · ถ้าอยาก strict = แบ่ง window ย่อยที่ไม่แตะตอน select.
4. ถ้าผ่าน → build-on ต่อ (ตาม doctrine): ทดสอบ mult อื่นรอบ fib23.6, both-direction sanity, แล้วค่อยพิจารณา demo. ถ้า cross-symbol ตก = XAU-only candidate (ยัง build-on ได้).

**ห้าม:** ตีตาย (มี plateau ผ่าน gate แล้ว = ALIVE ชัด) · retrofit เข้า cohort ที่ deploy อยู่.

## Thread B — ORDER-101/103 C1-ENFORCE (memory-OS final hardening) — 🔴 BLOCKED (Codex down)

**สถานะ:** อีก session เดิน memory-OS build ครบ 4 order (099-102) + ผ่าน mandatory review gate + เขียน handoff `docs/memory_control/C1_ENFORCE_HANDOFF.md`. เหลือ order สุดท้าย = **C1-ENFORCE** (ปิด write-path tamper hole, 4 fix).

- **Opus session นี้ร่าง order แล้ว:** `docs/memory_control/C1_ENFORCE_ORDER_DRAFT.md` (ORDER-103, 4 fix จาก handoff: append-chain integrity · fail-closed hook · exact block-id binding · hash-object atomicity).
- **🔴 BLOCKER:** handoff บังคับ **Codex design-review ก่อน build + blind Codex review ก่อน accept** (security-critical; บทเรียน build = self-review เดี่ยวหลุดทุกใบ). **Codex ยิงไม่ได้** — backend error `gpt-5.6-sol requires a newer version of Codex CLI/app`.
- **user directive (2026-07-13):** งานอัปเกรด Codex CLI + ทางเลือก build-without-Codex = **มอบ session อื่น**. session นี้โฟกัส thread A.

**👉 งานถัดของ thread นี้:** (1) อัปเกรด Codex CLI (user/other session — `/codex:setup` ดู) → (2) Codex design-review `C1_ENFORCE_ORDER_DRAFT.md` → (3) Sonnet build → Opus verify ข้าม HEAD/commit จริง → blind Codex review → accept. **ห้าม build ก่อน Codex design-review กลับ** (handoff mandate). **ห้าม start Contract D จนกว่า C1-ENFORCE ปิด.**

## Thread C — VPS rclone transport (ORDER-045/083C) — 🟡 รอ user ที่เครื่อง VPS

**สถานะ:** VPS = Windows Server 2012 R2 → OneDrive client ลงไม่ได้ (crash, OS เก่า) → ใช้ **rclone** (memory `vps-server2012-onedrive`). remote ต่อ OneDrive สำเร็จแล้ว + โฟลเดอร์ `EA_LAB_VPS_SYNC/{lab-to-vps/news,vps-to-lab/snapshots}` สร้างครบ. scripts = `ea_projects/(Boss)_NewsGuard/vps_rclone/{pull_news,push_snap}.cmd` (commit `9675ea7`).

**👉 เหลือ user ทำบน VPS (4 ขั้น, path Common\Files = `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files`):**
1. `mkdir C:\rclone\logs` + copy rclone.exe + rclone.conf ไป `C:\rclone\`
2. สร้าง `C:\rclone\{pull_news,push_snap}.cmd` (เนื้อจาก repo)
3. test รันไม่ error
4. `schtasks /create ... /ru SYSTEM /sc minute /mo 5` ×2
**เหลือฝั่ง lab:** OneDrive client เขียน news + อ่าน snapshot · แปะ AccountSnapshotExporter บน MT5 VPS.

## Commits ของ session นี้ (ทั้งหมด local, ยังไม่ push — user สั่ง "รอก่อน")
`fc31d0b` 082 Task0 gates · `bfa048f` 082 build · `9675ea7` VPS rclone · `c0b469b` 082 sweep+plateau verdict + C1-ENFORCE draft. + memory ใหม่: `vps-server2012-onedrive`.
**taskboard mirror ค้าง:** verdict 082 ยัง mirror เข้า AGENT_TASKBOARD ไม่ได้ (index ถูกอีก session churn ตอน commit) — เนื้ออยู่ครบใน plan file, re-mirror เมื่อ tree นิ่ง.
