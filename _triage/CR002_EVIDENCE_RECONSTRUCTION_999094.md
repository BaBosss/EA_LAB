# CR-002 — Promotion-evidence reconstruction: 463666728|999094 MacdDiv_Naked XAU H4 (2026-07-19)

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: บันทึกการ reconstruct หลักฐาน promotion ของ candidate เดียว
> (proof-of-capability ตาม ROADMAP CR-002 gate: "promotion-evidence reconstruction พิสูจน์จริง 1 candidate
> โดย reuse evidence-manifest จาก Contract D") — ไม่ใช่ verdict ใหม่; verdict owner = `_triage/ORDER098B_MACDDIV_M4_VERDICT.md`

## เป้าหมายที่พิสูจน์

ตอบคำถาม: **"ถ้าถูกถามย้อนหลังว่า EA ตัวนี้ขึ้น demo ด้วยหลักฐานอะไร — ประกอบกลับได้ครบไหม จาก repo อย่างเดียว?"**
ผล: **ประกอบได้ครบทั้ง chain** — source → locked set → M4 reports 3 หน้าต่าง → verdict → user approval → deployment row —
ทุกชิ้น pin ด้วย sha256/blob ใน git · ชิ้นที่เคย **ไม่ durable** (raw tester reports อยู่ใน gitignored `_mt5_auto/reports/`)
ถูก copy เข้า `docs/memory_control/evidence/ORDER098B/` + commit `e8d653a1` + ลง evidence-manifest แล้ว.

## Chain of evidence (ทุกแถวตรวจซ้ำได้)

| ชิ้น | ที่อยู่ | pin | evidence-manifest id |
|---|---|---|---|
| Hypothesis/order | `AGENT_TASKBOARD.md` §ORDER-098-B (บรรทัด ~1306) | git history | — (owner ref) |
| Source | `ea_projects/(EXP)_MacdDiv_Naked/MacdDiv_Naked.mq5` | blob `ad55103d` — **byte-identical ทั้งที่ verdict commit `1402de1f` และ HEAD ปัจจุบัน** (verify: `git ls-tree 1402de1f -- "<path>"`) · last touch `d25eebe1` = ORDER-117 RSI-gate **default OFF** ซึ่งอยู่ในไฟล์ก่อน verdict แล้ว | ⛔ ลง manifest ไม่ได้ — path มีวงเล็บ `(EXP)_` นอก charset `[A-Za-z0-9._/-]` ของ schema (ดู Gaps ข้อ 2) |
| Locked set (optimize) | `_mt5_auto/ab_sets/order098b/MacdDiv_Naked_XAUUSD_H4_optPF.set` | sha256 `e8a2d212…f1683` · blob `f8e6b691` | `evd_sha256_e8a2d21296bc0cc070181ac7f979f23f998cea2494af6010ec22fee04a2f1683` |
| Deployed set (demo) | `_vps_deploy/MACDDIV_XAU/MacdDiv_XAU_H4_demo_v1.set` | sha256 `622e5edc…8af7` · blob `33bb6703` | `evd_sha256_622e5edc812b49d98f7241e4fcde5bff6826afcae4d158bdea44c838f4338af7` |
| **Set drift proof** | diff ทั้งสองไฟล์ = **2 บรรทัด operational เท่านั้น**: `_00_OptimizeMode true→false` · `_06_AllowLive false→true` — strategy params ตรงกัน 100% | ทำซ้ำ: `diff <(sort optPF.set) <(sort demo_v1.set)` | — |
| Binary ที่ approve | `_vps_deploy/MACDDIV_XAU/MacdDiv_Naked.ex5` | **sha256 `56d2fcf6f74b7e8909afb4c7ca24b41a0a5b120d3097c445adb4c104303c9c93`** (recorded ใน snapshot attestation; binary ไม่ tracked ใน git) | — (ดู Gaps ข้อ 3) |
| M4 report MAIN 2023.01–2025.12 (PF 1.88/280t) | `docs/memory_control/evidence/ORDER098B/MacdDiv_XAUH4_M4_MAIN_2023_2025.htm` | sha256 `8bedc68b…eac0` @ `598239a8` | `evd_sha256_8bedc68b81d334ba5bd19ea34a4bbce99ccc5d231d2f2dc0f394561b6b48eac0` |
| M4 report BWD 2020–2022 (PF 0.97/240t) | `…/MacdDiv_XAUH4_M4_BWD_2020_2022.htm` | sha256 `c491a362…0bbf` | `evd_sha256_c491a362cc2b6961e0eef2b81f71830072d41bba9eae8898626543a1804b0bbf` |
| M4 report HOLDOUT 2026H1 (PF 1.28/39t) | `…/MacdDiv_XAUH4_M4_HOLDOUT_2026H1.htm` | sha256 `73fb3977…6922` | `evd_sha256_73fb3977098e17bf40aa7f020a43879904d2ce6606c8966f6d37783345c06922` |
| Verdict (M4, window definitions, บาร์ที่ใช้) | `_triage/ORDER098B_MACDDIV_M4_VERDICT.md` | sha256 `efcec396…9d13d` · blob `86316640` · commit `1402de1f` | `evd_sha256_efcec396b27764d76c707dd2be3484cf384ade621ce3929cc30452d355c9d13d` |
| M1 verdict ก่อนหน้า (plateau/lineage) | `_triage/ORDER098B_MACDDIV_VERDICT.md` | git history | — (ไม่ได้ลง manifest รอบนี้ — อ้างผ่าน git พอ) |
| User approval (BWD 0.97 marginal → demo) | `portfolio/DEPLOYMENTS.csv` แถว 463666728\|999094 notes: "BWD 0.97 marginal user-approved demo" | git history ของ CSV | — (ดู Gaps ข้อ 4) |
| Deployment attestation สด | `portfolio/control_room_snapshot.json` §attestation (state=HASHED, confidence=high) | regenerate รายวัน | — |

Windows ตรง pin ปัจจุบัน: MAIN 2023.01–2025.12 · BWD 2020–2022 · HOLDOUT 2026H1 (ใช้แล้ว → demo-forward = holdout ถัดไป ตาม verdict doc).

## Gaps ที่เจอระหว่าง reconstruct (ของจริงที่ CR-002 ต้องแก้ระบบ ไม่ใช่แก้เฉพาะตัว)

1. **Raw tester reports ไม่ durable by default** — `_mt5_auto/reports/` gitignored (ถูกแล้วสำหรับ transient แต่ report ที่ตัดสิน verdict = evidence) → **fix แล้วสำหรับ 999094**; ระบบถาวรควรเพิ่มขั้น "copy verdict-deciding reports → `docs/memory_control/evidence/<ORDER>/`" เข้า workflow ปิด order
2. **Schema path charset ตัด EA dirs ที่ชื่อมีวงเล็บ** (`(EXP)_`/`(Boss)_`/`(BRK)_` = ตั้งชื่อแบบนี้เกือบทั้ง lab) → source .mq5 ลง evidence-manifest ตรงๆ ไม่ได้ ต้อง pin ผ่าน git blob แทน. ทางแก้ระยะยาว: amend schema (Codex review) หรือ convention copy-source-to-evidence
3. **.ex5 binaries ไม่ tracked ใน git** → hash อยู่ใน snapshot (regenerated) ไม่ใช่ immutable record. Mitigation ตอนนี้ = hash จารึกในไฟล์นี้ (committed) + ATTESTATION_MAP; ระยะยาวถ้าอยากแน่น: git-lfs หรือ evidence-copy ของ ex5
4. **User approval เป็น chat + CSV note** — ไม่มี signed/timestamped approval record. Event log Contract D มี event type รองรับ (DECISION_LINKED) แต่ chain เต็มของ 098B ไม่ได้ emit ตอนปิด order (ปิดก่อน EVENT_LOG_ADOPTION มีผลเต็ม) — ไม่ backfill ตามกติกา §20.3 (098B ไม่ใช่ 1 ใน 3 canaries); ตัวถัดไปที่ปิด order ใหม่ให้ emit chain ตั้งแต่ต้น

## Manifest state หลังงานนี้

`scripts/experiment_event_log.ps1 -Command Scan` = **valid** · evidence_count 7→13 (+6 รายการของ 999094) · event_count 8 (ไม่เพิ่ม — งานนี้ register evidence เท่านั้น ไม่แตะ event chain ตามกติกา no-backfill)
