# HANDOFF → next session (2026-07-13, Opus) — 3 live threads

> อ่าน `VISION.md` → `PROJECT_STATE.md` → this file. อย่าเชื่อไฟล์นี้เหนือ repo — ขัดกันเชื่อ repo + `check_state.ps1`.
> ⚠️ **shared worktree:** session อื่น commit บน master คู่กัน (memory `shared-worktree-concurrent-writers`) — commit **path-limited**, เช็ค HEAD ก่อน stage, HEAD ขยับ = หยุด ห้าม rewrite. session นี้เจอ working-tree churn (ไฟล์หายๆโผล่ๆ ตอนอีก session checkout) — commit ผมทั้งหมด reachable-safe ยืนยันแล้ว.

## Thread A — ORDER-082 Wave5 (Entry_17) — 🟢 HOT, กำลัง validate

**สถานะ:** build เสร็จ + probe + sweep เจอ **plateau ผ่าน both-window gate**. spec-of-record = `docs/superpowers/plans/2026-07-12-entry-wave5.md` (อ่าน Task 6 + Task 6b).

- **Build (commit `bfa048f`):** `LAB_ENTRY_17` บน Boss V2 — `Boss_17_Wave5.mq5` + `core/entries/{Entry_Wave5,Wave5Swings}.mqh` + ExitManager/Inputs/Indicators/LabCore edits. compile 0/0 · regression CLEAN (11-16 byte-identical).
  - **บั๊กที่ Opus จับ+แก้ (subagent build พลาด):** labeling 3-pivot → wave1end/wave3peak คนละประเภทเสมอ = **Entry ยิงไม่ออก (zero-trade การันตี)** → แก้เป็น 4-pivot + wave2-validity + fib วัดจาก wave3 จริง.
- **Probe (default fib38.2):** XAU main PF 1.57 / BWD 0.95 · GBP 1.18 / 0.96 = marginal.
- **Sweep both-regime (XAU, 24 runs) → PLATEAU:** **fib=23.6/mult=0.618 = MAIN 1.11(271t) / BWD 1.12(217t), DD<3.4%** · adjacent (23.6,0.382)=1.09/1.07 ก็ผ่าน = plateau จริง. deep fib (38.2-61.8) = overfit ปีเทรนด์ (BWD พัง). **locked set = `_mt5_auto/ab_sets/wave5_sets/sw_F23.6_M0.618.set`**. raw = `_mt5_auto/wave5_sweep_results.csv`.

**✅ Validation batch DONE (2026-07-13, `wave5_validate_results.csv`):**
- **GBP H1** @ fib23.6: MAIN 0.94 / BWD 0.91 ✗ · **EUR H1**: 0.71 / 0.88 ✗ → **cross-symbol ตก = edge เฉพาะทอง ไม่ generalize ไป FX majors**
- **XAU H4** @ fib23.6: MAIN **1.74** (97t, win 71%) / BWD **1.01** (56t, win 57%) → **ผ่านทั้ง 2 window** = TF robustness บนทองยืน (H1 plateau + H4). H4 = window ไม่เคยใช้ select → **OOS evidence จริง**.
- **MC ยังไม่ได้** — `python not found` ใน bash context. **session หน้ารันผ่าน PowerShell:** `. scripts\use_python.ps1; python scripts\mt5_montecarlo.py _mt5_auto\reports\SW_F23.6_M0.618_MAIN.htm --deposit 10000 --iters 5000` (+ BWD).

**Verdict คมขึ้น: XAU-specific candidate, robust ข้าม TF (H1+H4), NOT cross-symbol.** ตาม BUILD-ON = ok (home-symbol EA). เหลือ = MC + demo consideration (gold — เช็ค corr กับ cohort ทอง 4 ตัวที่ deploy อยู่: Zeus/BRK/Squeeze/Trendline, gate pairwise <0.8).

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
**อัปเดต 2026-07-13 ค่ำ — VPS ทำเสร็จเกือบหมด:**
- ✅ rclone remote ต่อ OneDrive (account `b12c15b80120230d` = pattarapon personal, ตัวเดียวกับ lab client) · scheduled task 2 ตัว (`EA_LAB_pull_news` + `EA_LAB_push_snap`) รันทุก 5 นาที (`/ru SYSTEM`) · scripts ที่ `C:\rclone\{pull_news,push_snap}.cmd`
- ✅ AccountSnapshotExporter แปะแล้ว **5 บัญชี** (MT5 ×4 + MT4 141049900) → `EA_LAB_snapshot_<login>.csv` เข้า Common\Files ทุก 60 วิ
- ✅ **push ครบ 5 ไฟล์ขึ้น OneDrive** (`onedrive:EA_LAB_VPS_SYNC/vps-to-lab/snapshots`) · gotcha ที่แก้แล้ว: push_snap.cmd ห้ามมี `--exclude` คู่ `--include` (rclone filter เพี้ยน → ส่งแค่ 2/5)
- 🟡 **ค้างขั้นเดียว = OneDrive client ฝั่ง lab ยังไม่ sync `EA_LAB_VPS_SYNC` ลง `C:\Users\patip\OneDrive\` local** (folder อยู่ใน cloud ครบ แต่ client ไม่ดึงลง — ตั้ง online-only/ยังไม่ติ๊กใน Choose folders). **user จะ poke: OneDrive Settings → Account → Choose folders → ติ๊ก `EA_LAB_VPS_SYNC`** · rclone บน lab ลงไม่ได้ (proxy บล็อก download) จึงพึ่ง client
- **หมายเหตุ:** storage account เหลือ 0.1GB เพราะ user ลบ backup เอง (ไม่ใช่ account ผิด — เคยเข้าใจผิดว่า mismatch แล้ว rule out)

**👉 ต่อ dashboard เมื่อ snapshots ถึง `C:\Users\patip\OneDrive\EA_LAB_VPS_SYNC\vps-to-lab\snapshots\`:** wire `collect_live_deals.ps1 -CommonFiles <path นั้น>` → per-magic table. บัญชี 146237 ที่เคยค้าง = ไม่อยู่ใน 5 บัญชี snapshot (159503454/159475669/415573666/69424711/141049900) → เช็คว่าคืออะไร.

---

## 🌙 TOMORROW — long autonomous runs (user สั่ง 2026-07-13: "รันยาวๆ smoke, criteria ใหม่")

**สั่งรันได้เลยด้วยคำสั่งเดียว (autonomous ~1hr, ไม่ต้องคุย):**

1. **ORDER-082 Wave5 EXTENDED** — `bash _mt5_auto/wave5_extended_run.sh` → ผล `_mt5_auto/wave5_extended_results.csv` + `wave5_extended_mc.log`. ครอบ: (ก) finer plateau grid fib{20,23.6,27,30}×mult{0.5,0.618,0.75} XAU H1 both-window (ยืนยัน plateau ไม่ใช่ spike) (ข) XAG silver ที่ plateau-center (edge = gold-class หรือ XAU-only?) (ค) MC บน plateau-center. **judge criteria ใหม่:** both-window PF≥1.0 + plateau (neighbor ผ่านด้วย) + MC DD/ruin. baseline ที่ต้องชนะ: fib23.6/mult0.618 = MAIN 1.11/BWD 1.12 (XAU H1). ถ้า XAG ผ่าน = gold-class edge (ขยาย demo ได้).

2. **ORDER-076 — smoke 41 หัวกะทิจาก X-ray** (OPEN, ยังไม่แตะ) — worklist + วิธีรันอยู่ใน taskboard ORDER-076. รันด้วย mass-smoke pattern (`scripts/mass_smoke_mt5.ps1` หรือ `mt5_run.ps1` loop). **criteria ใหม่ (VERDICT GATE + flat-lot doctrine):** ห้ามตัดตายจาก 1 symbol×1 TF×default · flat-lot probe บังคับ (grid/martingale = ปิด escalation ก่อน วัด edge จริง) · PF>1 แม้ครั้งเดียว = build-on ไม่ bench.

3. **(optional) re-smoke ORDER-084 rescue candidates** — under-swept EAs (sweep <3 lever หรือ 1 TF) ใน `_triage/RETRO_AUDIT_VERDICTS.csv` กอง (ข). re-smoke ด้วย rescue-ladder (≥3 lever × ≥2 TF, both-regime). = judgment-heavy กว่า 1+2 → ทำหลัง.

**routing:** batch = qwen/agent ได้ (verifiable by numbers) · judge = Opus lead. **pace:** 1+2 ก่อน, ผลออกค่อย judge เขียน verdict (ห้าม burst จน context เต็ม).

## Commits ของ session นี้ (ทั้งหมด local, ยังไม่ push — user สั่ง "รอก่อน")
`fc31d0b` 082 Task0 gates · `bfa048f` 082 build · `9675ea7` VPS rclone · `c0b469b` 082 sweep+plateau verdict + C1-ENFORCE draft. + memory ใหม่: `vps-server2012-onedrive`.
**taskboard mirror ค้าง:** verdict 082 ยัง mirror เข้า AGENT_TASKBOARD ไม่ได้ (index ถูกอีก session churn ตอน commit) — เนื้ออยู่ครบใน plan file, re-mirror เมื่อ tree นิ่ง.
