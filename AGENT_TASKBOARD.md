# AGENT_TASKBOARD — คิวงานกลางของทุก agent

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **คิวงาน + ผลดิบระหว่างรอ review เท่านั้น** ·
> กติกาเต็ม → `AGENTS.md` (อ่านก่อน claim) · verdict สุดท้ายไม่อยู่ที่นี่ — อยู่ที่ EA_SCORECARD/PROJECT_STATE
>
> สถานะ: `OPEN` → `CLAIMED(agent, เวลา)` → `DONE` / `BLOCKED(คำถาม)` → `REVIEWED(Claude)`
> agent อื่นแก้ได้เฉพาะแถว order ที่ตัว claim · เพิ่ม order ใหม่ = Claude/user เท่านั้น
>
> 🏁 **track merge EA_CORE → Boss V2: ปิดแล้ว (เปิด+จบ 2026-07-06)** — อะไหล่เข้าแม่พิมพ์ครบ
> (pyramid 93 · acct-DD gate · Persist · tests\) + EA_Project = read-only archive · บันทึกเต็ม →
> `AGENT_TASKBOARD_MERGE.md` (เหลือ MERGE-07 Entry_ST03 = HOLD ถึง judge — เงื่อนไขอยู่ในบอร์ดนั้น)

---

## 🗂️ ARCHIVED ORDERS INDEX — orders ปิดแล้ว (เนื้อเต็มใน `ARCHIVE_TASKBOARD_2026-07A.md`)

> ย้ายออก 2026-07-12 (Opus) ลดขนาดบอร์ด · ทุก order อยู่ครบใน git history + ไฟล์ archive · ค้นเต็ม: grep ใน ARCHIVE_TASKBOARD_2026-07A.md

| Order | เรื่อง | verdict |
|---|---|---|
| ORDER-001 | GBPAUD: re-optimize บน IS window (กัน in-sample bias) | REVIEWED(Claude/Fable, 2026-07-04 — ผ่านการสอบสวน 2 ชั้น) |
| ORDER-002 | probe 3 symbol ที่ยังไม่เคย probe: AUDNZD / GBPJPY /.. | REVIEWED(Claude, 2026-07-04) |
| ORDER-004 | GBPAUD p26: OOS-confirm (2025.07-2026.07) + MC | REVIEWED(Claude, 2026-07-04) |
| ORDER-003 | Monte Carlo บน GBPAUD p26 report | SKIPPED |
| ORDER-005 | IS-optimize 5 candidates: AUDNZD / GBPJPY / EURJPY /.. | REVIEWED(Claude/Fable, 2026-07-04 — verdict รวมอยู่ที่ ORDER-006) |
| ORDER-006 | fresh-start OOS ของ 5 ตัวจาก ORDER-005 (rule-based, .. | REVIEWED(Claude/Fable, 2026-07-04) |
| ORDER-007 | probe Boss_14 อีก 7 symbol ที่ค้างทะเบียน (กฎ: ห้ามต.. | REVIEWED(Claude/Fable, 2026-07-04) |
| ORDER-008 | Re-exam ศพเก่าที่ตายโดยไม่เคย optimize: EA_LNBREAK +.. | REVIEWED(Claude/Fable, 2026-07-04 — ranges APPROVED → ORDER-008B) |
| ORDER-009 | MC บน OOS reports 5 ตัว | SKIPPED (superseded — Claude รัน MC บน full reports ประกอบ verdict ใน .. |
| ORDER-010 | full-window confirm + year-split ของ 3 ตัวที่ผ่าน OOS | REVIEWED(Claude/Fable, 2026-07-04 — Claude รันเองหลัง Codex ติด sandbox) |
| ORDER-008B | probe ศพเก่า | REVIEWED(Claude: ❌ LNBREAK = DEAD-optimized ของจริง (0/81, best 1.048).. |
| ORDER-011 | A/B harness | REVIEWED(Claude: ✅ harness ACCEPTED ใช้งานได้จริง (+รองรับ -Portable) .. |
| 📢 NOTICE ถึง Codex/ZCode (Claude, 2026-07-04 ~.. | 📢 NOTICE ถึง Codex/ZCode (Claude, 2026-07-04 ~10:00) | — |
| ═══ TREASURE-TRIAGE series (กอง D:\Forex\10_EA.. | ═══ TREASURE-TRIAGE series (กอง D:\Forex\10_EA_PROJE.. | — |
| ORDER-012 | อ่าน EA source ~98 ไฟล์ → ตาราง triage | REVIEWED(Claude: งานครบ 88/88 ✅ แต่เกณฑ์ Y หลวม (61/88 รวม grid เพียบ).. |
| ORDER-013 | PDF skim 289 ไฟล์ → catalog | REVIEWED(Claude: catalog ครบ 188/188 ✅ · strategy-book 49 + worth_deep.. |
| ORDER-015 | pipeline batch #2 | REVIEWED(Claude: 🥇 AUDCAD OOS 4.30/41t = CANDIDATE เด่น (AUD family อี.. |
| ORDER-016 | cohort-2 pipeline: full-confirm + year-split + MC ขอ.. | REVIEWED(Claude, 2026-07-04): cohort-2 verdict — DEMO 3 ตัว: 🥇 AUDCAD .. |
| ORDER-017 | Model-4 confirm cohort-2 (3 ตัว) + สร้าง DEMO sets | REVIEWED(Claude, 2026-07-06 — เก็บตกสถานะ: ผลถูก review+ใช้จริงตั้งแต่.. |
| ORDER-018 | เติม EA_MASTER_INDEX.csv | REVIEWED(Claude: ✅ 125 แถว 0 ซ้ำ — UNTESTED 88 · DEAD 17 · PARKED 7 · .. |
| ORDER-019 | corr matrix ของ Boss_14 family (6 ตัว demo) | REVIEWED(Claude/Fable, 2026-07-04 — พอร์ตกระจายตัวดี ไม่มีคู่ redundant) |
| ORDER-020 | ขุด SELL-side จาก optimizer XML ที่มีอยู่ (hunt queu.. | REVIEWED(Claude/Fable, 2026-07-04 — 1 candidate ใหม่จริง (NZDUSD-SELL).. |
| ORDER-023 | NZDUSD-SELL: fresh-start OOS ของ pass 29 (จาก ORDER-.. | REVIEWED(Claude/Fable, 2026-07-04 — ทำเองแทน Codex/ZCode ที่ token หมด.. |
| ORDER-021 | สรุป 20 treasure sources (momentum 13 + breakout 7) .. | REVIEWED(Claude/Fable, 2026-07-04 — ทำเองแทน Codex ที่ token หมด, ใช้ .. |
| ORDER-022 | Plateau-sensitivity test ของ 6 DEMO configs (ปิดจุดอ.. | REVIEWED(Claude/Fable, 2026-07-04 — รันเองแทน oc-btest ที่ token หมด, .. |
| ORDER-024 | Recovery-mode A/B บน config ที่ชนะ (AUDNZD champion) | REVIEWED(Claude/Opus, 2026-07-05 — 81 REJECT · 82 PROMISING แต่ยังไม่ .. |
| ORDER-025 | Adaptive Recovery (mode 82): ตรวจ floating DD จริง +.. | REVIEWED(Claude/Opus, 2026-07-05 — ❌ Recovery REJECT ปิดถาวรทั้ง 81+82.. |
| ORDER-026 | HedgeMode (HEDGE_LOCK) A/B บน AUDNZD | REVIEWED(Claude/Opus, 2026-07-05 — รันเอง เพราะ ZCode โควต้าหมดวัน + ง.. |
| ORDER-027 | mold upgrade: | _2_BasketTP_ATRmult |
| ORDER-028 | XAU GridLog: IS-optimize (axis tuning สำหรับทอง) | REVIEWED(Claude/Opus, 2026-07-05 — plateau-center = Pass 20 → pipeline.. |
| ORDER-029 | mold fix: | _33_SL_MaxPips |
| 🏭 XAU GridLog VALIDATION PIPELINE (รันตามลำดับ.. | 🏭 XAU GridLog VALIDATION PIPELINE (รันตามลำดับ 030→0.. | — |
| ORDER-030 | XAU: fresh-start OOS + full-window + year-split | REVIEWED(Claude/Opus, 2026-07-05 — ✅ ผ่าน OOS gate (CONDITIONAL) → ORD.. |
| ORDER-031 | XAU: Monte Carlo + Model-4 every-tick (ทอง+grid บังค.. | REVIEWED(Claude/Opus, 2026-07-05 — 🎉 XAU ผ่านครบ = candidate #7 non-FX.. |
| ORDER-032 | XAG (silver) GridLog: IS-optimize (non-FX ตัวที่ 2, .. | REVIEWED(Claude/Opus, 2026-07-05 — 🅿️ PARK-thin, ทองแข็งกว่า) |
| ORDER-029B | implement Option B: | _33_SL_MaxATRmult |
| ORDER-033 | smoke-screen 4 MT5 signal EAs จาก | wait for test |
| 🗺️ MASS-SMOKE `wait for test` (user 2026-07-05.. | 🗺️ MASS-SMOKE | wait for test |
| ORDER-034 | catalog + dedup + กรอง tradeable-EA จาก | wait for test |
| ORDER-035 | MT5 mass-smoke driver (loop worklist ex5) | REVIEWED(Claude/Opus, 2026-07-05 — 39 survivor, ส่วนใหญ่กับดัก Model-1.. |
| ORDER-035-REVIEW | note (Claude/Opus 2026-07-05): 39 survivor | — |
| ORDER-037 | artifact-check top survivors จาก mass-smoke | REVIEWED(Claude, 2026-07-06 — ❌ ตายครบทั้ง 3: pun fix lot REJECT (eqDD.. |
| ORDER-038 | pun fix lot v05: backward-OOS 2020-2022 | REVIEWED(Claude, 2026-07-06 — ❌ REJECT ปิดถาวร: eqDD 83% ปี 2022, no-S.. |
| ORDER-039 | Scalping-EA-AsReMix: Model-4 + MC | REVIEWED(Claude, 2026-07-06 — 🅿️ PARKED trend-specialist edge-decay; Z.. |
| ORDER-040 | BWD-OOS sweep ของ 036 batch-01 Tier A | REVIEWED(Claude, 2026-07-06 — ZCode token หมดก่อนเริ่ม → Claude รันเอง.. |
| ORDER-041 | ClevrFX + Fxcore100_SELL: spread-stress + SL/lock ch.. | REVIEWED(Claude รันเอง, 2026-07-06 — ✅ ผ่านทั้งคู่ = MT4 candidates จร.. |
| ORDER-047 | RSI from pips_EA: symbol/TF breadth → BWD confirm → .. | REVIEWED/CLOSED (Claude, 2026-07-07 ค่ำ — RSI=EURUSD-only ไม่ optimize.. |
| ORDER-046 | Revival probes: กฎ "ห้าม DEAD ก่อนลอง optimize" กับ .. | REVIEWED/CLOSED (Claude, 2026-07-07 ค่ำ — 1 win ฟรี + 1 marginal-reviv.. |
| ORDER-043 | US30 GridLog: IS-optimize probe (optional, EV ต่ำ) | REVIEWED/CLOSED (Claude รันเอง, 2026-07-09 — ❌ US30 = DEAD-optimized ป.. |
| ORDER-044 | EURUSD Trading Forex Robot: full chain re-test | REVIEWED(Claude, 2026-07-07 — ❌ REJECT ปิดถาวรที่ด่านแรก: BWD 2020-22 .. |
| ORDER-014 | Model-4 (real ticks) confirm ของ DEMO cohort 3 ตัว | REVIEWED(Claude: DEMO ยืนทั้ง 3 บน real ticks ✅ — USDJPY 1.72/107t · A.. |
| ORDER-042 | DealsExporter: nightly deals snapshot สำหรับ /ea-mon.. | REVIEWED(Claude, 2026-07-06 — ✅ ทำเอง สร้าง+พิสูจน์ครบ · เหลือ user at.. |
| ORDER-058 | live-monitor dashboard: ตาราง per-EA แบบเข้าใจใน 5 ว.. | REVIEWED(Claude, 2026-07-09 — ✅ Sonnet ทำ, Claude ตรวจ+แก้ 1 จุด: ระดั.. |
| ORDER-059 | COT regime filter สำหรับ EA ทอง: exploratory ผ่าน → .. | REVIEWED/CLOSED (Claude, 2026-07-09 — ❌ REJECT เป็น gating filter · เก.. |
| ORDER-060 | MT4 OrdersExporter + ท่อ monitoring MT4 ครบวงจร | DONE+REVIEWED (Claude ทำเอง+ตรวจเอง, 2026-07-09) |
| ORDER-061 | hunt ใหม่: (BRK)_FlagPennant @ XAUUSD H1 (กลไก next-.. | REVIEWED/CLOSED (Claude, 2026-07-09 — ❌ NO EDGE, ปิดพร้อม mechanism in.. |
| ORDER-062 | regime-axis re-funnel ทั้ง Boss_14 family | REVIEWED/CLOSED (Claude, 2026-07-09 — 🎯 1 hit ชัด: USDJPY · 1 borderli.. |
| ORDER-067 | Trendline rev02 + ADX-regime gate: เส้นทาง promote #.. | BUILT+CLOSED (Claude, 2026-07-09 ดึก — ❌ gate จริงแย่กว่า offline: art.. |
| ORDER-063 | smoke เทส EA จาก Downloads 3 ตัว | REVIEWED/CLOSED (Claude, 2026-07-09 — ❌ ตายครบ 3: GOD4+HedgingGrid unt.. |
| ORDER-065 | build: (TRD)_SuperTrendFlip @ XAUUSD H1 | BUILT+FUNNELED (Claude, 2026-07-09 — 🅿️ RESERVE: ผ่าน 3 windows แต่ MC.. |
| ORDER-066 | build: (VWAP)_WaveS1 distilled @ XAUUSD | BUILT+FUNNELED (Claude, 2026-07-09 ค่ำ — ❌ NO EDGE ปิดพร้อม mechanism .. |
| ORDER-068 | ST03 family: flat-lot probe ของ config แล็บ (9397 GB.. | DONE(Claude-agent, 2026-07-10) |
| ORDER-069 | (Boss)_ZeusInspired_GridLog_rev01 บน EURUSD: coarse .. | DONE(Claude-agent, 2026-07-10) |
| ORDER-070 | Gold_Kangaroo: แกะ logic + หาข้อมูลเน็ต → spec "Kang.. | DONE(Claude-agent, 2026-07-10) |
| REVIEW ORDER-0 | 68 + ORDER-069 | REVIEWED(Claude, 2026-07-10) |
| REVIEW ORDER-0 | 70 (+flat-lot addendum) | REVIEWED(Claude, 2026-07-10) |
| ORDER-071 | rev02 | STAGE2-DONE(Claude-agent, 2026-07-10) |
| REVIEW ORDER-0 | 71 (Stage 1+2) | REVIEWED(Claude, 2026-07-10) |
| ORDER-074 | fxDreema X-ray: อ่าน EA คลังเรียนของ user แบบไม่เปลื.. | DONE(Claude-agent, 2026-07-10) |
| REVIEW ORDER-0 | 72 | REVIEWED(Claude, 2026-07-10) |
| ORDER-075 | Boss_16 entry sweep v1 (BUY-first) | DONE(Claude-agent, 2026-07-10) |
| REVIEW ORDER-0 | 74 | REVIEWED(Claude, 2026-07-10) |
| REVIEW ORDER-0 | 75 | REVIEWED(Claude, 2026-07-10) |
| ORDER-077 | Boss_16 BUY: BWD-OOS 2020-2022 probe (กฎ both-regime.. | DONE(agent, 2026-07-10) |
| REVIEW ORDER-0 | 77 | REVIEWED(Claude, 2026-07-10) |
| ORDER-078 | Boss_16 BUY 21/30: validation funnel เต็ม | DONE(Claude-agent, 2026-07-11) |
| REVIEW ORDER-0 | 78 | REVIEWED(Claude, 2026-07-11) |
| ORDER-081 | Crypto lane feasibility study (maker-fee scalper blu.. | DONE(Codex+research-subagent, 2026-07-11 — รอ Claude/user ตัดสิน go/no.. |
| ORDER-075 | /078 | — |
| ORDER-083 | build "(Boss)_NewsGuard" watchdog EA (user เคาะ poli.. | DONE(Claude-agent, 2026-07-10) |
| REVIEW ORDER-0 | 83 | REVIEWED(Claude, 2026-07-10) |
| REVIEW ORDER-0 | 84 | REVIEWED(Claude, 2026-07-10) |
| ORDER-085 | SuperTrend XAU H4: un-park ตาม corr rule | DONE(Claude-agent, 2026-07-10) |
| ORDER-086 | swb grid AUDCAD: เตรียม bundle demo experiment #3 (u.. | DONE(Claude-agent, 2026-07-10) |
| ORDER-087 | concept rescue batch #1: 6 smokes บน symbol-class ที.. | DONE(Claude-agent 2026-07-10) |
| ORDER-088 | Oracle EA: ปิดเงื่อนไขค้าง "อ่าน trade list" | DONE(Claude-agent, 2026-07-10) |
| REVIEW ORDER-0 | 87 | REVIEWED(Claude, 2026-07-10) |
| ORDER-089 | EA_ZSCORE × AUDCAD: rescue-ladder เต็มตามสูตร (ตัวแร.. | DONE(Claude-agent, 2026-07-10) |
| REVIEW ORDER-0 | 88 | REVIEWED(Claude, 2026-07-10) |
| REVIEW ORDER-0 | 89 | REVIEWED(Claude, 2026-07-10) |
| ORDER-090 | ZSCORE AUDCAD H4: funnel เต็ม (ด่านสุดท้ายก่อน bench) | DONE-STOPPED-AT-STAGE-2(Claude-agent, 2026-07-10) |
| REVIEW ORDER-0 | 85 | REVIEWED(Claude, 2026-07-10) |
| ORDER-085B | SuperTrend XAU H4: อุดรูสองรูสุดท้าย | DONE(Claude-agent, 2026-07-11) |
| REVIEW ORDER-0 | 90 | REVIEWED(Claude, 2026-07-10) |
| ORDER-091B | BOT MOGUL report sweep (เฟส 1: parse+rank+shortlist) | DONE-PHASE1(Claude-agent, 2026-07-11) |
| ORDER-091B | เฟส 2 | DONE(Claude-agent, 2026-07-11) |
| ORDER-083B | port NewsGuard เป็น MQL4 (คุมกอง no-SL บน MT4 141049.. | DONE(Claude-agent, 2026-07-11) |
| REVIEW ORDER-0 | 83B | REVIEWED(Claude, 2026-07-11) |
| REVIEW CODEX-AUDIT (`_triage\CODEX_AUDIT_FULL_.. | REVIEW CODEX-AUDIT ( | _triage\CODEX_AUDIT_FULL_2026-07-10.md |
| REVIEW ORDER-0 | 85B | REVIEWED(Claude, 2026-07-11) |
| ORDER-092 | P0: Floating-risk telemetry (ตาบอด floating = รูใหญ่.. | DONE(Claude-agent, 2026-07-11) |
| ORDER-093 | P0: Deployment truth เดียว + ซ่อม PROJECT_STATE enco.. | DONE(Claude, 2026-07-11) |
| ORDER-083C | P0-before-attach: NewsGuard hardening (MT5+MT4) + VP.. | DONE(Codex, 2026-07-11 — รอ Claude review เมื่อ quota กลับ) |
| ORDER-094 | P1: Cage hardening (ปิดทาง stale-pass ทั้ง 4 ตัว) | DONE(Claude-agent, 2026-07-11) |
| REVIEW ORDER-0 | 92 | REVIEWED(Claude, 2026-07-11) |
| REVIEW ORDER-0 | 83C | REVIEWED(Claude, 2026-07-11) |
| REVIEW ORDER-0 | 81 | REVIEWED(Claude, 2026-07-11) |
| REVIEW ORDER-0 | 94 | REVIEWED(Claude, 2026-07-11) |
| REVIEW ORDER-0 | 91A | REVIEWED(Claude, 2026-07-11) |
| REVIEW ORDER-0 | 91B | REVIEWED(Claude, 2026-07-11) |
| REVIEW ORDER-0 | 91C batch-1/2 smoke | REVIEWED(Claude, 2026-07-11) |
| ORDER-091C-D1 | JUMSTOCH_FIXEDLOT full funnel | DONE(Claude-agent, 2026-07-11) |
| REVIEW ORDER-0 | 91C-D1 | REVIEWED(Claude, 2026-07-11) |
| ORDER-091C-D1b | JUMSTOCH spread stress (gate ก่อน demo) | DONE(Claude-agent, 2026-07-11) |
| 🔄 REFRAME JUMSTOCH ตาม BUILD-ON doctrine (user.. | 🔄 REFRAME JUMSTOCH ตาม BUILD-ON doctrine (user 2026-.. | — |
| ORDER-091C-D1c | JUMSTOCH ขยาย symbol×TF เต็ม (user: "symbol มีอีกเป็.. | DONE(Claude-agent, 2026-07-11) |
| ORDER-091C-D1e | JUMSTOCH MT5 port + smoke | — |
| REVIEW ORDER-0 | 91C-D1b | REVIEWED(Claude, 2026-07-11) |
| ORDER-095-A | Boss_14_GridLog ขยาย symbol (ตัวแรก, demo flagship) | DONE(Claude-agent, 2026-07-11) |
| JUMSTOCH multi-symbol config — `DONE(Claude, 2.. | JUMSTOCH multi-symbol config | DONE(Claude, 2026-07-11) |
| REVIEW ORDER-0 | 95-A corr preview | REVIEWED(Claude, 2026-07-11) |
| 🔧 PROCESS: "MT4-good → MT5 port → smoke → opti.. | 🔧 PROCESS: "MT4-good → MT5 port → smoke → optimize" .. | — |
| Boss_14 new-vs-EXISTING corr — `DONE(Claude, 2.. | Boss_14 new-vs-EXISTING corr | DONE(Claude, 2026-07-11) |
| 🔧 PORT-PIPELINE queue + SMC/FVG cluster (lead .. | 🔧 PORT-PIPELINE queue + SMC/FVG cluster (lead prep 2.. | — |
| REVIEW ORDER-0 | 91C-D1e | REVIEWED(Claude, 2026-07-11) |
| ORDER-091C-D1f | OOS validate JUMSTOCH MT5 ขาใหม่ (EURGBP/NZDUSD) | DONE(Claude-agent, 2026-07-11) |
| REVIEW ORDER-0 | 91C-D1f + JUMSTOCH thread CLOSE | REVIEWED(Claude, 2026-07-11) |
| CAMPAIGN ORDER-096 — WOBR/BotMogul marketplace.. | CAMPAIGN ORDER-096 | — |
| ORDER-096A | Alligator+AO naked smoke (WOBR lead 2 ตัวสุดท้าย) | REVIEWED(Claude, 2026-07-11) |
| ORDER-096B | ปิดเซลล์ USDJPY IchiADX (PARKED→verdict) | REVIEWED(Claude, 2026-07-11) |
| ORDER-096C | commit WOBR intake artifacts | DONE(Claude, 2026-07-11) |

---

## ORDER-036 — MT4 mass-smoke (1,318 ex4) — `OPEN → แยกเป็น BATCH BOARD ไฟล์ตัวเอง (user 2026-07-06)` · **ทำได้: Codex · oc-dev**

**👉 spec + สถานะ + วิธีสั่งทั้งหมด = `ORDER-036_MT4_MASS_SMOKE.md`** (แยกไฟล์เพราะ 27 batches ×50 —
กัน taskboard บวม). batch assignment deterministic = `_triage/mass_smoke_mt4_batches.csv` (คอลัมน์ batch 01-27).
user สั่งเป็นก้อน เช่น "ทำ 036 batch 04-08" · batch จบ+review แล้ว archive ไป `_archive/ORDER-036_ARCHIVE.md` ·
order แม่แถวนี้**คงอยู่จนครบ 27 batch** (กันหลุดจาก board) — Claude สรุป verdict รวมที่นี่ตอนจบ

**ผล:** _(ดูตารางสถานะในไฟล์ board — สรุปรวมจะมาเขียนที่นี่เมื่อครบ)_

---

## ORDER-045 — MT4 demo experiment #2: UnNomGuai + RSI from pips (คู่, บัญชีใหม่) — `WAITING-USER (attach) → แล้วค่อยเป็น monitoring loop` · **เจ้าของ: user (attach) + Claude (judge)** _(ออก 2026-07-07 หลัง user อนุมัติ)_

**สถานะ:** ORDER-036 ปิดสมบูรณ์ (1,318 → 2 survivor: **UnNomGuaiV1.132 + RSI from pips_EA** ผ่านครบถึง
Model-0 bwd+fwd) · user อนุมัติ demo คู่บนบัญชีเดียว (2026-07-07) · **bundle พร้อม: `_demo_deploy\`**
(ex4 ×2 + `README_DEPLOY.md` มี MD5 lock, kill-switch, ค่าคาดหวัง) · แผนเต็ม: `DEMO_DEPLOYMENT_PLAN.md`
§MT4 demo experiment #2
**รอ user:** เปิดบัญชี demo ใหม่ ($10k, แนะ ThinkMarkets) → ลง MT4 portable `D:\Meta4demo` (ห้ามใช้เลนเทส)
→ attach ตาม checklist → **แจ้งวันที่ attach = demo-clock เริ่ม (judge +3 เดือน)**
**งาน agent หลัง attach (ทุก ~2 สัปดาห์ รอบเดียวกับ ClevrFX):** อ่าน statement ที่ user export → แยก P&L
ตาม magic (1/2 = UnNom · 5888 = RSI) → เทียบตารางคาดหวังใน README → เช็ค kill-switch (UnNom >12 ไม้ ·
RSI >0.06 lot · DD alert 20/25% kill 30/35%) → รายงาน · **ห้าม:** แก้ input EA · เพิ่ม EA อื่นในบัญชีนี้

**ผล:** _(รอ attach)_

---

## ORDER-055 — [NEXT SESSION START HERE] demo cohort 8 ตัว: attach + monitor — `🚀 ATTACHED 2026-07-09 คืนนี้ (โครงจริงต่างจากแผน — ทั้งหมดบน VPS, cohort MT5 ขึ้น REAL cent!) · judge ชุดนี้ = 2026-10-09 · รายละเอียด = section "DEPLOYMENT REALITY 2026-07-09" ใน DEMO_DEPLOYMENT_PLAN.md · เหลือ: user attach exporter ×5 บน VPS + เลือกท่อ CSV (OneDrive บน VPS หรือ RDP-copy รายสัปดาห์) + จับตา Boss-TrendSwing/Woodfire (มี EA ที่แล็บ REJECT ปน — Gold Reaper, LondonConso)`

**สรุป session 2026-07-08/09 (Opus): EA hunt รอบใหญ่จบ → 7 clean + 1 experimental candidate พร้อม attach.**
รายละเอียดเต็ม = `PROJECT_STATE.md` §7 "SESSION 2026-07-08" block · handoff doc = `handoff/SESSION_2026-07-09_HANDOFF.md`
bundle = `_demo_deploy\README_DEPLOY.md` (2 บัญชี MT4+MT5 · WILL-IT-TRADE checklist + kill-switch + corr + portfolio-sim ครบ).

**8 candidates (magic distinct):**
- MT4: UnNomGuai(EURUSD/1-2) · RSI-orig(EURUSD/5888) · swb(AUDCAD/990) — grid, validated
- MT5: RSI-MR(EURUSD/990103,**ROBUST**) · Zeus(XAU/990101,MARGINAL) · BRK-XAU(XAU/991001,MARGINAL) · SqueezeBRK(XAU/991004,**ROBUST**) · **Trendline(XAU/991002,EXPERIMENTAL PF-5th 0.986)**

**Claude-doable งานเสร็จหมดแล้ว (session นี้):** corr matrix 8-EA (ไม่มีคู่ >0.60, gold 3 ตัว uncorrelated) · portfolio-sim (รวม DD 1.2%, gold-pair 3.8%) · bundle verify + **AllowLive=true fix ทั้ง MT5 set (critical silent-stop catch)** · WILL-IT-TRADE checklist · tools ใหม่: corr_matrix/portfolio_sim/mt4_deals_to_csv/max_recovery_days.py

**แผนวันนี้ 2026-07-09 (user รวม session แล้ว — session นี้เป็น lead เดียว · เรียงตาม EV):**
1. **[user, ~20 นาที] attach 8 ตัว** (MT4 3 + MT5 5 ตาม `_demo_deploy\README_DEPLOY.md` WILL-IT-TRADE checklist) **+ attach DealsExporter.ex5 1 chart** (ค้างจาก ORDER-042) → บอกวันเริ่มให้ Claude · **EV สูงสุด — ทุกอย่างรอด่านนี้**

> **📋 USER CHECKLIST เย็นนี้ (2026-07-09) — ทำทีเดียวจบ:**
> ☐ 1. attach demo cohort 8 ตัว ตาม `_demo_deploy\README_DEPLOY.md` (เช็ค WILL-IT-TRADE ทุกข้อ: AllowLive=true, RSI-MR ต้องบัญชี Hedging, AutoTrading เปิด, magic ตรง)
> ☐ 2. attach `tools\DealsExporter\DealsExporter.ex5` 1 chart บน terminal demo MT5
> ☐ 3. **บัญชี VPS → ไม่ต้องแตะ VPS เลย:** เปิด MT5 instance สำรองบนเครื่องนี้ (D:\Meta 5b) → login บัญชี VPS ด้วย **investor password** (read-only) → แปะ DealsExporter 1 chart · ทำซ้ำต่อบัญชีที่อยาก track (รวม Boss-TrendSwing 159475669 ถ้าจะให้ track)
> ☐ 4. บอก Claude: วันที่ attach + รายชื่อบัญชี → Claude ลงทะเบียน DEMO_DEPLOYMENT_PLAN + ตั้ง judge date + scheduled task (collector + dashboard อัตโนมัติทุกเช้า)
> · ~~หมายเหตุ: บัญชี MT4 ใช้ DealsExporter ไม่ได้~~ **อัปเดตบ่าย: MT4 exporter มีแล้ว (ORDER-060)** —
> ☐ 5. attach `tools\DealsExporter\OrdersExporterMT4.ex4` 1 chart บน terminal demo MT4 ด้วย
> (**สำคัญ: คลิกขวา tab Account History → เลือก "All History" ก่อน** ไม่งั้น export ไม่ครบ)
2. **[Claude ทันทีที่รู้วัน attach]** บันทึก DEMO_DEPLOYMENT_PLAN + judge +3 เดือน + ตั้งรอบ /ea-monitor
3. **[Codex] ORDER-057 Stage A** — `Regime.mqh` (ADX trend/sideway + ATR storm, default OFF) → Claude review + `tpl_regression.ps1` ต้อง CLEAN → ค่อยปล่อย Stage B (ZCode, A/B both-windows)
4. **[qwen/Sonnet] ORDER-058** — live dashboard HTML per-magic (ต่อยอด DealsExporter · มีข้อมูลจริงหลัง user ทำข้อ 1)
5. [optional ถ้า quota เหลือ] COT/CME regime-data pull (ไอเดียจากโพส FB 07-09 — ยังไม่เป็น order, รอ user เคาะ) · ORDER-043 US30 probe (ZCode วันว่าง)
**หลัง attach:** statement ทุก ~2 สัปดาห์ → แยก P&L ตาม magic → เทียบค่าคาดหวัง README · จับตา (a) MT4 grid no-SL tail (b) combined gold exposure (Zeus+BRK+Squeeze+Trendline ทั้ง 4 = XAU) (c) Trendline #8 borderline → drop ถ้าไม่เข้าเป้า
**ปิดไปแล้ว:** hunt space สำรวจหมด (instrument/TF/กลไก/lot-law/re-opt/FX-travel = ตัน) — กลไกใหม่จริง (flag/pennant/order-flow) ค่อยว่ากัน · Boss V2 robustness track = parked
**ห้าม:** แก้ config ที่ validate แล้ว · เชื่อ hunt ว่า EV สูง (พิสูจน์แล้วว่าตัน)

**ผล:** bundle deploy-ready (8 EA, safety-checked). รอ user attach.

---

## เสนอ order ใหม่ (agent อื่นเขียนข้อเสนอได้ที่นี่ — Claude เป็นคนยกเป็น order จริง)

### 🟣 PROPOSAL-A (ZCode, 2026-07-04) — ✅ APPROVED → ยกเป็น ORDER-009 แล้ว (เก็บไว้เป็น reference)

**บริบท:** ตอนนี้ ORDER-005 (IS-opt) + ORDER-006 (fresh-start OOS) + ORDER-007 (probe 7) = DONE
ทั้งหมด รอ Claude review. แต่ ORDER-006 ผลิตแค่ผล OOS (PF/Net/EqDD จาก single equity path)
**ยังไม่มี Monte Carlo** — ขณะที่ ORDER-004 (GBPAUD) ใช้ MC เป็นหลักฐานประกอบ verdict
(DD 95th/worst/ruin). pipeline เดียวกันควรมี MC ครบทุก OOS-passing candidate ก่อน Claude
ตัดสิน ไม่งั้น Claude ต้องสั่งซ้ำรอบ review.

**OOS ผลที่ ORDER-006 รายงาน (จาก report ครบบน disk):**
AUDNZD 42t PF 3.02 ✅ · EURJPY 23t PF 2.15 ✅ · USDJPY 106t PF 2.77 ✅ ·
GBPJPY 23t PF 1.12 (borderline) · EURCAD 140t PF 0.67 (fail)

**งานที่ขอทำ (role ZCode แท้ — รัน `mt5_montecarlo.py` ที่มีอยู่ ไม่สร้าง/แก้ source):**
```powershell
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_AUDNZD_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_GBPJPY_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_EURJPY_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_EURCAD_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_USDJPY_OOS_M1.htm  --deposit 10000 --iters 5000
```
**Acceptance (ถ้า Claude approve):** ต่อ symbol append ตาราง `trades_used / DD median / 95th /
worst / ruin% / P(loss)` · commit `[zcode] PROPOSAL-A done`
**ข้อห้าม (ตาม role):** ไม่ตีความผล, ไม่ให้ verdict, ไม่เลือก candidate — รายงานดิบเท่านั้น.
**caveat ที่จะรายงานควบ (จาก docstring ตัว script เอง):** trade-reshuffle MC = optimistic
lower bound (grid ขาขาด cluster → real adverse อาจแย่กว่า reshuffle ใดๆ) — treat 95th/worst
เป็น "at least this bad" ไม่ใช่ ceiling.

**⚠️ ข้อควรพิจารณาของ Claude ก่อน approve:**
- OOS report บางตัวมีเทรดน้อย (GBPJPY 23t / EURJPY 23t / AUDNZD 42t) — MC บน n<30 noise มาก
  (ORDER-004 เคยเลี่ยงปัญหานี้โดยรัน MC บน full report 88t แทน OOS 23t). ทางเลือกสำหรับ Claude:
  (a) approve ทั้ง 5 + flag ว่า thin, (b) ขอให้ ZCode รัน MC บน full-window report เพิ่มเทียบ,
  (c) รันเฉพาะ USDJPY(106t)/EURCAD(140t) ที่ n เพียงพอก่อน.
- หาก Claude ตั้งใจ review ORDER-005/006 เองโดยไม่ใช้ MC (ใช้แค่ PF+regime-read) ก็ปฏิเสธ
  proposal นี้ได้เลย — ZCode จะไม่ทำ.

---

## ORDER-057 — mold upgrade: `Regime.mqh` (market-state filter, additive) — `Stage A REVIEWED(Claude, 2026-07-09 — ✅ ACCEPT · Stage B OPEN สำหรับ ZCode/oc-btest)` · **ทำได้: Codex/Claude/oc-dev** · 👉 **Codex-direct** _(ออก 2026-07-09, user สั่ง: "อยากได้ตัวระบุสภาวะตลาด trend/sideway เป็น direction ให้ EA + ปิดได้")_

**Stage A review (Claude, 2026-07-09):** โค้ด Codex ผ่านทุกข้อ — closed-bar classify (shift 1, no repaint) +
cache ต่อแท่ง regime-TF · gate เฉพาะ first-entry ทั้ง 2 path (resting-stop + market) ไม่แตะ exit/basket ·
direction convention 1=BUY/2=SELL ตรง Entry_ST03 · handle init/release ตามแบบ Indicators.mqh · mode 0 no-op
จริง (พิสูจน์: run มี module = run ไม่มี module ตรงกันทุกหลักทศนิยม) · **เหตุการณ์ระหว่าง review: cage ขึ้น
DRIFT 4 ตัว → สอบสวนด้วย control run บน HEAD สะอาด = เลขเพี้ยนเหมือนกันเป๊ะ → root cause คือ XAUUSD history
refresh (trade count เท่าเดิมทุกตัว กำไรขยับ ~1-4%) ไม่ใช่โค้ด → re-baseline บน HEAD แล้วรันซ้ำกับ module =
CLEAN 4/4 · บทเรียน: DRIFT ที่ trade count เท่าเดิม + กำไรขยับเล็กน้อย = สงสัย data-side ก่อน code-side,
พิสูจน์ด้วย control run เสมอ** · sanity A/B ของ Codex: mode 1 (block RANGE) 426→378 ไม้ = gate กัดจริง

**เก็บตกหลักฐาน (Claude, 2026-07-09 บ่าย):** เจอช่องว่าง — `mt5_run.ps1` ไม่ compile ดังนั้น control run
แรกเทียบ binary เดียวกัน (พิสูจน์แค่ history ไม่ใช่ source) → ปิดช่องด้วยการ compile เอง 2 รอบ:
source มี module (compile 0/0) vs source ก่อน module (checkout `36a6819`, compile 0/0) → regression
เลขเท่ากันเป๊ะทุกหลักทั้งคู่ = **mode-0 no-op พิสูจน์ end-to-end ระดับ source ด้วยมือ lead แล้ว** ไม่พึ่งคำ Codex

**Stage B — reassign เป็น Claude รันเอง (2026-07-09: user cancel Codex — quota หมด กลับ 2026-07-11 · ZCode n/a):**
matrix 32 runs เสร็จแล้ว → `_mt5_auto\REGIME_AB.csv` · runner = `_mt5_auto\ab_sets\regime_sets\run_regime_ab.ps1`

**Stage B VERDICT (Claude, 2026-07-09):**
- **XAU (Boss_14 chassis, ISpick): trend-only gate = ของจริงระดับ in-sample** — m1 (block RANGE):
  BWD PF 1.07→**1.88/1.88/1.82** (thr 20/25/30 = plateau ไม่ใช่ spike) net 121→799 · FWD เสียนิดเดียว
  1.42→1.39 (thr20) n 426→405 · eqDD ลดทั้งสอง window (23.35→20.05% / 8.30→7.30%) · **shape ที่ต้องการ
  เป๊ะ: เฉือนกำไรปีกระทิงนิดหน่อย แลก window อ่อนพลิกจากแทบเจ๊าเป็น 1.88**
- **AUDNZD (DEMO champion): ไม่เอา** — ทุก config ที่ช่วย BWD ทำร้าย FWD สลับกัน (m1t20: FWD 1.53↑ แต่
  BWD 0.74↓ · m1t25: BWD 1.76↑ แต่ FWD 1.27↓) ยกเว้น thr30 ที่ต้องจ่ายไม้หาย ~75% = thin · no plateau
- mode 2 (direction-lock) ≤ mode 1 ทุก cell ที่เทียบได้ → mode 1 คือตัวจริงของ lever นี้
- m1 range-only: FWD 2.05 บน n=38 / BWD 0.60 = thin+flip ทิ้ง
- **Stage C (สมมติฐาน user "COT+trend filter ใช้คู่กัน"): ทดสอบแล้ว — COT ไม่เพิ่มค่าบน ADX** — ใน
  trade ที่ผ่าน ADX gate แล้ว (n=512) ทุก COT bucket กำไรหมด (LOW 1.22 / MID 1.25 / HIGH 1.54) ตัด LOW
  = ตัดกำไร ไม่ใช่ตัดขาดทุน + year-split ยังไม่เสถียร (2024 LOW 1.93) → COT จบที่ dashboard light ตามเดิม
- **ข้อจำกัด verdict:** เลือก config จาก 2 window ที่เห็นทั้งคู่ = in-sample selection · **ห้าม retrofit
  เข้า demo cohort ที่ validate แล้ว** (กฎเดิม) · adoption ที่ถูก = `_50_` เป็น axis ใหม่ใน optimize funnel
  ของ EA ตัวถัดไป + Boss V2 track (ตอน unpark) แล้วต้องผ่าน holdout+MC ของ funnel นั้นเอง
- MC PF-5th base vs m1t20 (XAU, bootstrap-w/-replacement 5000 iters บน deals จริง — caveat grid-MC เดิม):
  FWD 0.825→0.797 (จ่ายเบี้ยปีกระทิง) · BWD 0.572→**0.849** (window อ่อนดีขึ้นชัด) · ALL 0.829→0.852 —
  สอดคล้อง story ประกันภัย, ไม่เปลี่ยน verdict (lever เข้า funnel ใหม่ ไม่ retrofit)

**ทำไม:** cohort มี EA ที่ตายเพราะ regime เปลี่ยน (NZDUSD-SELL = PARKED regime-dependent ·
Scalping-AsReMix = PARKED trend-specialist edge-decay) — ถ้ามี regime filter ในแม่พิมพ์ จะได้
lever ใหม่ให้ sweep ทั้ง family และเป็นตัว "ปิดเครื่องเมื่อสภาวะไม่ใช่" ที่ demo cohort ยังไม่มี

**Stage A — implement (Codex-direct, additive เท่านั้น):**
- ไฟล์ใหม่ `ea_template\core\Regime.mqh` — enum `REGIME_TREND_UP / REGIME_TREND_DOWN / REGIME_RANGE / REGIME_STORM`
- ตัวจับ (built-in handles เท่านั้น ตามธรรมเนียม Indicators.mqh):
  - trend/range: **iADX** บน `_50_Regime_TF` — ADX ≥ `_50_ADX_TrendMin` = trend (ทิศจาก +DI/-DI), ต่ำกว่า = RANGE
  - storm: ATR ปัจจุบัน > `_50_StormATRmult` × SMA(ATR, `_50_StormLookback`) = STORM (ทับทุกสถานะ, 0 = ปิดเช็คนี้)
- inputs ใหม่ใน `Inputs.mqh` (prefix `_50_`):
  `_50_RegimeMode` **0=OFF (default)** · 1=FILTER (เทรดเฉพาะ regime ที่อนุญาตผ่าน `_50_AllowTrendUp/_AllowTrendDown/_AllowRange`; STORM = block เสมอ) · 2=DIRECTION (อนุญาตเฉพาะฝั่งตาม trend; RANGE = block ทั้งคู่)
  · `_50_Regime_TF` (default H4) · `_50_ADX_Period` (14) · `_50_ADX_TrendMin` (25.0) · `_50_StormATRmult` (2.0) · `_50_StormLookback` (100)
- จุดเสียบ: gate **การเปิดไม้ใหม่เท่านั้น** (ก่อน entry signal ใน LabCore) — ห้ามแตะ exit/basket/recovery/ไม้ที่เปิดอยู่ · ประเมินที่ bar-open ของ `_50_Regime_TF` (bar-open gate)
**Acceptance (Stage A):** compile 0/0 · **`tpl_regression.ps1` CLEAN ที่ mode 0** (default off = พฤติกรรมเดิมทุก byte) · sanity run 1 ครั้ง: XAU GridLog p20 set + mode 1 (AllowRange=false) → trade count ต้องเปลี่ยนจาก baseline · commit `[codex] ORDER-057A done`
**ห้าม (Stage A):** แตะ ExitManager/RiskControl/Recovery logic · เปลี่ยน default พฤติกรรมใดๆ · ตัดสินว่า filter "ช่วย"

**Stage B — A/B sweep (ZCode/oc-btest, หลัง A ผ่าน review):**
- EA ทดสอบ 2 ตัว: XAU GridLog (Pass 20 set) + AUDNZD champion — รัน baseline (mode 0) vs mode 1 (3 ชุด allow) vs mode 2, บน**ทั้ง 2 window: 2023-2026 + BWD 2020-2022** (กฎ both-regimes)
- sweep `_50_ADX_TrendMin` ∈ {20, 25, 30} — รายงานดิบ PF/Trades/DD ต่อ cell, append ใต้ order นี้
**ห้าม (Stage B):** เลือก config "ดีสุด" — verdict = Claude ตาม VERDICT GATE (surface ไม่ใช่จุดเดียว)

**ผล (Codex, Stage A only; ไม่มี verdict):**
- touched: `ea_template\core\Regime.mqh` (new) · `ea_template\core\Inputs.mqh` · `ea_template\core\LabCore.mqh`
- compile: Boss_11/12/13/14/15 workspace builds = **0 errors / 0 warnings**
- regression: `powershell -File D:\EA_LAB\scripts\tpl_regression.ps1` = **CLEAN**
- sanity A/B (XAU GridLog Pass-20 full window 2023.01.01-2026.07.01, Model 1):
  baseline `_50_RegimeMode=0` = **426 trades**
  filtered `_50_RegimeMode=1`, `_50_AllowRange=false` = **378 trades**
- note: MT5 expert folders were ACL-blocked from this session, so the proof run used a temporary portable sandbox under `D:\EA_LAB\_mt5_portable_order057` with the workspace-built `.ex5` + copied XAU history; raw reports:
  `D:\EA_LAB\_mt5_auto\reports\ORDER057_XAU_BASE_SB.htm`
  `D:\EA_LAB\_mt5_auto\reports\ORDER057_XAU_FILTER_SB.htm`

---

## ORDER-064 — ขุดไอเดียจาก Open WebUI export 93MB (คุยกับ OpenAI ของบริษัท) — `IN-PROGRESS (Claude + 4 Sonnet agents, 2026-07-09)`

- **Stage 1 ✅:** `scripts\chatgpt_export_inventory.py` (รองรับทั้ง OpenAI export และ Open WebUI format) →
  45 บทสนทนา, จัดอันดับตาม MQL-keyword density → `_triage\chatgpt_inventory.csv` + top-12 แตกเป็น .txt ใน
  `_triage\chatgpt_convs\` (⚠️ ข้อมูลบริษัท — .txt/.csv **ไม่เข้า git**, เก็บ local เท่านั้น)
- **Stage 2 (กำลังรัน):** 4 Sonnet agents skim 12 ไฟล์ → catalog กลไก/โค้ด/ความใหม่เทียบ cohort
- **Stage 3 (Claude):** judge catalog → เลือก build candidates (เกณฑ์: กลไกใหม่จริง + กติกาชัด — VWAP-based
  น่าสนใจสุดเพราะ cohort ยังไม่มี) · ที่เหลืออีก 33 บทสนทนา = อ่านเฉพาะถ้า top-12 ให้ของดี

**VERDICT Stage 3 (Claude, 2026-07-09 — catalog ครบ 12/12):**
- **ขยะ/ซ้ำของที่เรามี-REJECT แล้ว (7 ไฟล์):** 024 scaffold framework · 015 recovery-hedge spec (ตระกูล REJECT
  81/82) · 041 AW-Recover clone (**ไม่มี SL ต่อไม้ทั้ง 5 เวอร์ชัน**) · 030 prompt-eng session · 036 triage PDF
  ซ้ำ STRATEGY_200_ANALYSIS · 022+009 = 11-EA ตาม**โหราศาสตร์** (โค้ดครบแต่ allocation ไม่ใช่ market logic)
- **ของจริงที่สกัดได้ — จัดอันดับ build EV:**
  1. 🥇 **SuperTrend/HalfTrend/Chandelier "ATR-band flip"** — โผล่อิสระ **5 แหล่ง** (025 HalfTrend MTF ·
     043 Smart Trail · 009 P10 · 022 P10 · STRATEGY_200 #68 top-pick) · กลไก: trailing extreme ∓ ATR×mult
     พลิกทิศ = trend-follow ที่ exit ด้วยเส้นวิ่งตาม ไม่ใช่ fixed TP · บ้านที่ควรเทส: XAU H1 (edge class
     momentum ที่พิสูจน์แล้ว) · build ถูกสุด (indicator เดียว + โครง L1 มีแล้ว) → **ORDER-065**
  2. 🥈 **VWAP Wave (010 — สเปคเต็ม 4 setup)** — VWAP+SD band แยก Balance/Discovery + Initial Balance ·
     กลไกใหม่แท้ต่อ cohort (ไม่มีตัวไหนใช้ fair-value anchor) · ต้องกลั่นเหลือ setup เดียวก่อน (S1 continuation
     หรือ S4 VWAP-bounce) — ห้าม build ตามสเปค 30 ไฟล์ (บวม+ML+Wyckoff = overfit trap) → **ORDER-066**
  3. 🥉 **Z-score pairs stat-arb EURUSD/USDCHF** (009 P5 + 022 P5 สองแหล่ง) — market-neutral = return stream
     คนละจักรวาลกับ cohort ทั้งกอง · ติดเรื่อง infra (multi-symbol tester + ไม่มี price SL ในดีไซน์เดิม = ต้อง
     ใส่ hard SL เอง) → วิจัยความเป็นไปได้ก่อน build → backlog
  4. **Graft ideas ใส่ของที่มีอยู่ (ถูกมาก):** ATR>1.2×ATR_MA เป็น squeeze-proxy ราคาถูก (032) · vote N-of-M
     gate (043/032) · asymmetric-lot MTF confluence (025 — เห็นต่างเข้าครึ่งไซส์) · time-stop 48 แท่ง (032)
  5. **Anti-pattern เก็บเข้าคลัง:** virtual SL (043) · recovery-multiplier ซ้อน martingale (043) · equity-based
     kill แทน price SL (041) · "AI/Neural" = ป้ายการตลาดของ EA ขายตลาด 90% (035 audit ชี้ Quantum Emperor
     เจ้าของเติมเงินเข้า signal ปิด DD!)
- Boring-Pips-style cross-pair reversion (035) + session-gate (022 P11) = MED เก็บ backlog ไม่เร่ง

---

## ORDER-071 — ST03 entry rescue: HTF trend-gate A/B บน flat-lot — `OPEN` (role: Claude+Sonnet build → agent runs)

**ทำไม (user directive 2026-07-10):** user เสนอเอา higher-TF มาคุมทิศ entry ของ ST03 (filter ด้วย MACD /
trend / ADX+DI) — สมมุติฐานถูกหลัก: ST03 คือ reversion-grid การบังคับให้ grid กางเฉพาะฝั่งเทรนด์ใหญ่
อาจเปลี่ยน no-edge เป็น edge ได้ · **baseline ที่ต้องชนะ: flat-lot GBP PF 0.68 / CAD 0.40 (ORDER-068)**

**เกณฑ์ตัดสินล่วงหน้า (ตั้งก่อนเห็นผล — กัน selection):** gate ตัวใดตัวหนึ่งต้องยก flat-lot PF ข้าม **1.0**
บนทั้ง GBP และ CAD (สองตลาดพร้อมกัน) จึงนับว่า "entry รอด" → ค่อยต่อ capped-recovery (โครง Kangaroo)
· ถ้าไม่มี gate ไหนข้าม = entry ตายจริง เลิกที่ signal นี้ ห้ามขุดต่อ

**วิธี (in-EA A/B เท่านั้น — ห้าม offline bucketing):** บทเรียนจ่ายจริง ORDER-067: close-time regime
conditioning = survivorship artifact (offline ADX gate สวย → in-EA จริง MC แย่ลง 0.973→0.861) ·
และ STF: AND-filter ที่ lagging สับ sample 159→27 จนไร้ความหมาย — ระวังทั้งคู่
1. build บน **Boss V2 + Entry_ST03.mqh** (ห้ามแตะไฟล์ fxDreema): เพิ่ม input gate mode =
   0 none · 1 H4 MACD direction · 2 H4 ADX>th + DI-direction · 3 H4 EMA50-slope — gate คุมทิศที่
   "อนุญาตให้เปิดตะกร้า" เท่านั้น (ไม่ปิดไม้ที่เปิดแล้ว)
2. compile 0/0 + `tpl_regression.ps1` CLEAN ก่อนรัน (แก้ core = ต้องผ่าน cage)
3. รัน flat-lot (no escalation) GBPUSD + USDCAD H1 · 2023.01.01-2026.07.01 · Model 1 · gate 0/1/2/3
   = 8 runs · report ST03GATE_*
**Acceptance:** ตาราง 8 แถว PF/net/DD/trades + แถว baseline 068 เทียบ · commit `[tag] ORDER-071 done`
**ห้าม:** ตัดสิน rescue สำเร็จ/ล้มเหลว (เกณฑ์ตายตัวด้านบน — Claude อ่านผลเอง) · ห้ามแตะ .set live ·
ห้าม optimize param อื่นไปพร้อมกัน (isolate ตัวแปรเดียว: gate)


---

## ORDER-072 — build "(Boss)_Kangaroo" = Boss_16 บนแม่พิมพ์ V2 — `CLAIMED(Claude-agent, 2026-07-10)` (role: agent build ภายใต้ spec ที่ Claude เคาะ)

**Spec decisions (Claude lead เคาะ 2026-07-10 — ปิดประเด็นเปิดทั้ง 5 ของ KANGAROO_LOGIC_NOTES §4):**
1. **Lot law: FLAT default** (ทุกไม้ = base_lot) — flat-lot probe พิสูจน์แล้วว่าดีกว่ามี ladder
   (H1 5.71 vs 4.86) · ×1.5 capped ladder ใส่เป็น input `LadderMult` default 1.0 (=ปิด) ไว้ A/B
2. **Bidirectional = 2 instance ผ่าน Direction input** (ตาม pattern Boss_14) — ไม่ทำ dual-engine
   ในตัวเดียว, magic แยกฝั่ง · ไม่ทำ multi-magic stream ของ original (artifact ไม่ใช่ feature)
3. **Entry v0 = RSI fade** (RSI(14) H1: BUY เมื่อ <th_low, SELL เมื่อ >th_high, default 30/70) —
   ใกล้เคียง counter-trend ของ original ที่สุดในคลังเรา (RSI-MR = survivor mechanism ที่ validate แล้ว)
4. **เก็บ 3 กลไก exit ตาม original แต่คิดเงินจริง:** TP เดี่ยว (ATR-mult) · basket close แบบ net-$ ·
   **overlap pair-close** (คู่ใหม่สุด+เก่าสุด ปิดเมื่อรวม ≥ $X, default 5, sweepable) — โมดูลใหม่
5. **ladder_flatten (controlled-loss release):** มีเป็น input default OFF — A/B แยกใน funnel
6. Spacing ATR (0.8/1.4 mult + floor 150p) · SL ต่อไม้ ATR-mult (ceiling $90-equiv) · HARD cap
   10 ไม้/ฝั่ง (ของจริง ไม่ใช่โฆษณาแบบ original) · emergency DD 70%

**คำสั่ง:** สร้าง `ea_template\Boss_16_KangarooGrid.mq5` + โมดูลใหม่ที่จำเป็นใน `core\` (additive,
default-off สำหรับ EA เดิม) ตาม pattern Boss_14_GridLog · compile 0/0 · **`tpl_regression.ps1` ต้อง CLEAN**
(กติกาแก้ core) · smoke XAUUSD H1 2023-2026 Model 1 บน lane "D:\Meta 5b" (กันชนกับ ORDER-071) ·
เทียบตาราง: Boss_16 flat vs original flat (PF 5.71/DD 11.5% = เป้าไล่)
**Acceptance:** compile 0/0 · regression CLEAN · ตาราง smoke เทียบ original + set ไฟล์ · commit `[tag] ORDER-072 done`
**ห้าม:** deploy/verdict · แก้ Boss_14/15 behavior · martingale default-on · แตะ .set live

### ORDER-072 result — `DONE(Claude-agent, 2026-07-10)` — build ครบ + gates ผ่านทั้ง 3 + smoke raw numbers (NO verdict)

**Build file list:**
- NEW `ea_template\Boss_16_KangarooGrid.mq5` (wrapper: `LAB_ENTRY_16` + tag)
- NEW `ea_template\core\Kangaroo.mqh` — basket engine ของ entry 16 ทั้งก้อน: adverse-only ATR grid
  (0.8/1.4 mult + floor 150p digit-aware) · FLAT lot (LadderMult>1.0 = capped ladder, first-4 = BaseLot,
  cap/order 1.0) · HARD cap 10 ไม้/ฝั่ง (refuse จริง) · per-order broker SL (18×ATR, ceiling 9000p) ·
  exit 4 กลไก **คิดเงินจริงทั้งหมด**: (1) single TP 0.35×ATR (managed close) (2) basket net-$ ≥ 16×(lots/0.01)
  (3) overlap pair-close newest+oldest ≥ $5 เมื่อ ≥4 ไม้ (4) ladder_flatten default OFF (≥6 ไม้, net ≥ -$400) ·
  emergency DD close-all 70% · **one exit owner:** LabCore short-circuit เข้า `Kangaroo_OnTick()` — ExitManager/
  Stack/Recovery/Hedge ไม่รันเลยสำหรับ build นี้; ไม่มี broker TP ต่อไม้ (precedent mode 93); cage ยังเป็นใหญ่
  (RiskControl hard-kill/deposit-load/RC_MaxLot รันก่อน/คุมทับ)
- NEW `ea_template\core\entries\Entry_KangarooRSI.mqh` — entry v0: RSI(14) fade บน chart TF, closed-bar read,
  `_16_Direction` 1=BUY(<RsiLow 30)/2=SELL(>RsiHigh 70) ตาม pattern Boss_14, เข้าที่ bar open
- EDIT (additive, `#ifdef LAB_ENTRY_16` ทั้งหมด — compile out จาก Boss_11..15): `core\Inputs.mqh` (กลุ่ม `_16_*`
  + StackMode/fallback guard) · `core\Indicators.mqh` (handle `g_hRSI16`) · `core\LabCore.mqh`
  (include + init + OnTick short-circuit) · `core\Execution.mqh` (`Exec_CloseTicket()` — build อื่นไม่เรียก)
- EDIT `ea_template\deploy.ps1` (+Boss_16 target) · `scripts\mt5_run.ps1` (+`-Leverage` param, default 100 = พฤติกรรมเดิม)
- NEW `ea_template\sets\Boss16_Kangaroo_XAU_smoke.set` (defaults ทั้งชุด เขียน explicit)

**Gate evidence:**
1. compile: `Boss_16_KangarooGrid.mq5 → Result: 0 errors, 0 warnings` (และทั้ง 7 targets 0/0)
2. `tpl_regression.ps1` = **CLEAN 4/4** — หมายเหตุ: เจอ DRIFT 4/4 ก่อน แต่ control run บน clean HEAD (stash)
   reproduce เลขเพี้ยน **bit-identical** (trades เท่าเดิมเป๊ะ 168/164/107/56, profit ±1-4%) = data-side
   XAU history refresh ตาม incident เดิม commit 6a21f040 → re-baseline บน verified clean HEAD แล้วรันกับ
   module = CLEAN (ทำตาม procedure ที่บันทึกไว้เป๊ะ) · `tests\run_tests.ps1` = **ALL TESTS PASS 3/3**
   (AcctGate/Persist/StackStep)
3. smoke lane "D:\Meta 5b" (portable): XAUUSD H1 2023.01.01–2026.07.01 Model 1 (history quality 98%),
   deposit 10000, leverage 1:2000, defaults flat-lot

**Smoke table (raw — ห้าม verdict ที่นี่):**
| Run | PF | Net $ | maxDD% (eq) | Trades | Win% |
|---|---|---|---|---|---|
| Boss_16 BUY (defaults) | 1.49 | +2,242.42 | 10.85% | 588 | 76.4% |
| Boss_16 SELL (_16_Direction=2) | 0.46 | −2,261.00 | 25.12% ← cage HARD KILL @25% วันสุดท้าย 2026.06.30 | 293 | 54.3% |
| Original Gold_Kangaroo FLAT (MT4 H1, สองฝั่งในตัวเดียว) | 5.71 | +15,216.87 | 11.53% | 6,166 | 86.4% |

Reports: `_mt5_auto\reports\BOSS16_KANG_XAU_H1_BUY.htm` / `BOSS16_KANG_XAU_H1_SELL.htm` · mechanics ยืนยันใน
journal lane2: overlap pair-close ยิงจริง 168 ครั้ง (SELL run), grid adds เดินตาม spacing, cage kill ทำงาน

**Deviations from spec (พร้อมเหตุผล):**
1. smoke = 2 runs (BUY+SELL อย่างละ 1 ครั้ง ไม่มี tuning) — EA เป็น fixed-direction ต่อ instance ตาม spec
   decision 2 แต่แถวเทียบ original เป็นสองฝั่ง → รันฝั่งละครั้งเพื่อให้ตารางเทียบได้
2. single TP = managed close ไม่ใช่ broker TP — กติกา one-exit-owner (ไม้ห้ามมี broker TP, precedent 93);
   fill = tick แรกที่เลย level ซึ่งเทียบเท่า overshoot behavior ที่เห็นใน original
3. grid-add reference = ราคา extreme ของฝั่ง (ต่ำสุด BUY / สูงสุด SELL) ไม่ใช่ไม้ล่าสุดตามเวลา — กัน
   oscillation refill หลัง overlap pair-close ตัดไม้ newest ออก; ตรง observation ว่า original เติมไม้ที่
   new low เท่านั้นช่วง crash 2024-11-06
4. emergency 70% อยู่ในโค้ดตาม spec แต่ cage KillDD (ProtectLevel 2 = 25%) ยิงก่อนเสมอที่ default —
   70% = backstop สำหรับ config ที่คลาย cage (SELL run คือหลักฐาน cage ทำงานจริงและ halt)
5. `mt5_run.ps1` เพิ่ม `-Leverage` (additive, default 100 ไม่เปลี่ยนพฤติกรรมเดิม) เพราะ order สั่ง 1:2000
   แต่ script hardcode 100
6. `regression_baseline.csv` ถูก re-capture บน clean HEAD (ดู gate 2) — ไม่ใช่การกลบ drift ของ module;
   พิสูจน์ด้วย control run ก่อนแล้ว

**ข้อสังเกต (ข้อมูล ไม่ใช่ verdict):** trades 588+293 vs original 6,166 — entry v0 RSI fade คัดเข้มกว่า entry
เข้ารหัสของ original มาก (ตัว original ยิงหลาย magic stream แทบตลอดเวลา) · ฝั่ง SELL แพ้บน XAU 2023-26
ซึ่งเป็นเทรนด์ขึ้นยักษ์ · การอ่านผล/ทางไปต่อ (entry sweep? both-instance portfolio?) = งาน Claude lead


---

## ORDER-073 — News-aware risk system (user directive 2026-07-10) — Phase 1 `DONE(Claude)` · Phase 2 `OPEN`

**เป้า user:** เห็นข่าวแรงที่เกี่ยวกับพอร์ตทุกวัน + มีตัวคุมเหนือ EA ทั้งหมด (ลด lot / ปิดไม้ / block entry
ช่วงข่าวแรง ตาม policy ต่อ strategy)

**Phase 1 (เสร็จ 2026-07-10):** `scripts\news_calendar.ps1` — ดึง ForexFactory weekly feed → filter
High-impact 8 สกุลพอร์ต → (a) `portfolio\news_today.html` ฝังใน LIVE_DASHBOARD (มือถือเห็นทุกเช้า
ผ่าน gist) (b) `portfolio\news_week.csv` = machine-readable ให้ Phase 2 · cache กัน 429 · อยู่ใน
daily 07:30 chain แล้ว · **ข้อจำกัดที่ต้องรู้: กันได้เฉพาะข่าวตามนัด — Brexit/SNB-type (gap ไม่มีนัด)
กันด้วยปฏิทินไม่ได้ = เหตุผลที่ SL/cap ต้องมีเสมอ**

**Phase 2 — NewsGuard watchdog EA (OPEN, ต้องคุย design กับ user ก่อน build):**
- EA ตัวเดียว attach 1 chart/บัญชี อ่าน `news_week.csv` (คัดลอกไป Common\Files หรือ WebRequest ดึงเอง
  บน VPS — ต้อง whitelist URL ครั้งเดียว) · นาฬิกา event เทียบ server time
- policy ต่อ magic list (input): `BLOCK_NEW` (กันไม้ใหม่ N นาทีก่อน/หลัง event — ทำได้กับ EA เราเท่านั้น
  ผ่าน GlobalVariable flag ที่ chassis อ่าน) · `CLOSE_ALL` (ปิดไม้ magic นั้นก่อน event — ทำได้กับทุก EA
  รวม locked เพราะ watchdog มีสิทธิ์ระดับบัญชี) · `NONE`
- ค่าเริ่มแนะนำ: CLOSE_ALL เฉพาะ strategy ไร้ SL/recovery (Zeus 7777, gold grids) ก่อนข่าว USD แรง
  30 นาที · BLOCK_NEW สำหรับ breakout family (ข่าวคือ noise ไม่ใช่ signal ของมัน) · Boss_14 bench
  demo = NONE (เก็บ data ให้ judge เห็นพฤติกรรมจริง)
- **ห้าม build จนกว่า user เคาะ policy ต่อบัญชี/ต่อ magic** (มันจะไปปิดไม้เงินจริง — ต้อง explicit)

## ORDER-076 — smoke-screen หัวกะทิ 41 ตัวจาก X-ray — `OPEN` (role: agent/qwen lane)

**คำสั่ง:** (1) cross-ref 41 ตัว (CSV filter has_sl=yes & lot_escalation=no) กับ EA_SCORECARD +
ผล ORDER-036 (MT4 1,318 sweep) — ตัวที่เคย screen แล้วห้ามรันซ้ำ ใช้ผลเดิม (2) ตัวใหม่จริง:
smoke ตาม filter chain มาตรฐาน (name-DQ → smoke PF>1 → BWD-OOS 2020-22 → spread-stress)
platform ตามไฟล์ · **compiled .ex4/.ex5 เท่านั้นถ้ามี — .mq4/.mq5 คอมไพล์ก่อน** (3) ตาราง verdict-ดิบ
ต่อ EA ต่อด่าน **Acceptance:** ตารางครบ 41 แถว (screened-before / smoked / DQ) + top-5 ตาม
BWD-OOS PF · commit `[tag] ORDER-076 done` **ห้าม:** verdict PASS/REJECT (Claude ตัดสิน) ·
แตะไฟล์ต้นฉบับ · แตะ 297 ตัว SL-unknown (รอ verification pass แยก ถ้าคุ้ม)


---

## ORDER-079 — Idea mining คลังคอร์ส: concept catalog (reframe จาก user 2026-07-10) — `CLAIMED(Claude-agent, 2026-07-10)`

**ทำไม (user directive):** คลัง 1,050 EA = สื่อการเรียน ไม่ใช่สินค้า — ห้ามตัดสินด้วยเกณฑ์ risk structure
(43% no-SL คือ scaffold ของแบบฝึก ไม่ใช่ความผิด) · เป้า = **สกัดไอเดีย/แนวคิด** ที่ user เรียนมา
ให้เห็นเป็นแคตตาล็อกต่อยอดได้ · user ยืนยันในคลังมี Elliott Wave (รวมแบบเฉพาะ wave 5) + SMC —
ห้ามปัดตก แนวพวกนี้แล็บมี precedent ด้วย (Gold SMC = OOS_VALIDATED ใน EA_Project)

**คำสั่ง:** สร้าง concept-mining pass ต่อยอด xray (แหล่งข้อมูลต่อไฟล์: ชื่อไฟล์/โฟลเดอร์ · **fxDreema
block labels** (คนเขียนเอง สื่อความหมายตรง) · indicator signature · comment strings) →
จัด taxonomy แนวคิด เช่น: Elliott/wave-count · SMC/order-block/liquidity/BOS · session-time ·
breakout (แบบไหน) · reversion (RSI/CCI/Stoch/BB) · trend-follow (MA/ST/SAR) · currency-strength
meter · correlation/pair · news · scalping · grid/basket variants · dashboard/tool (ไม่ใช่ EA) ·
money-management exercises → output `_triage\FXDREEMA_IDEA_CATALOG.md`:
ต่อ concept: จำนวนไฟล์ · ตัวแทน 2-3 ไฟล์ (ตัวที่ block labels สื่อสุด) · mechanism sketch จาก labels ·
**cross-ref สถานะแล็บ**: เคยทดสอบ/ตาย/validated/ยังไม่เคยแตะ (เทียบ EDGE_CATALOG.md + memory
signal-landscape ผ่านไฟล์ repo) + CSV คอลัมน์ concept เพิ่มใน FXDREEMA_XRAY.csv
**เจาะพิเศษ:** ไฟล์ Elliott/wave ทั้งหมด (grep wave/elliot/impulse/zigzag ใน name+labels) และ
SMC (order block/liquidity/FVG/BOS/CHOCH/SMC) — ลิสต์แยกครบทุกไฟล์ พร้อมสรุป logic จาก labels ต่อไฟล์
**Acceptance:** catalog ครบ + ลิสต์ Elliott/SMC เต็ม + นับ concept ใหม่ที่แล็บไม่เคยทดสอบ ·
commit `[tag] ORDER-079 done` · **ห้าม:** ตัดสินดี/ไม่ดี ต่อ concept (Claude+user คุยกัน) · risk flags
ห้ามโผล่ใน catalog (คนละเอกสารกับ XRAY)

**สถานะ:** CLAIMED -> DONE(Claude-inline, 2026-07-10) — agent ตายที่ session limit, Claude เขียน/รันสคริปต์เองต่อ (fxdreema_concepts.py + boilerplate fix รอบสอง: doji-string เคย inflate candle_pattern 224->16) · ผลเต็ม = _triage\FXDREEMA_IDEA_CATALOG.md + concept column ใน XRAY.csv + _concept_summary.json


---

## ORDER-080 — วัดมูลค่า "limit-entry แทน market" บน EA เรา (แรงบันดาลใจ: บอท maker-only ของโพสต์ FB ที่ user เอามาแกะ 2026-07-10) — `OPEN` (role: agent build+run)

**สมมุติฐาน:** เข้าไม้ด้วย pending limit ที่ราคาดีกว่า signal price เล็กน้อย (แลกกับ fill ไม่ครบ)
ให้ EV ดีกว่า market entry — โลก crypto พิสูจน์ด้วย fee; โลก MT5 = ประหยัด spread/slippage แทน
**คำสั่ง:** เพิ่ม input `EntryMode` (0=market เดิม default · 1=limit offset) + `EntryLimitOffsetPips` +
`EntryExpiryBars` ให้ **Boss_16_KangarooGrid** (additive, default = พฤติกรรมเดิม, ผ่าน regression cage)
→ A/B บน config candidate 21/30 XAU H1: market vs limit offset {3, 6, 10 pips} expiry 1 bar ·
ทั้ง IS 2023-26 และ BWD 2020-22 · Model 1 (+Model 0 confirm คู่ที่ต่างกันสุด)
**Acceptance:** ตาราง market vs 3 offset × 2 window: PF/net/trades/**fill-rate** (นับไม้หาย) ·
commit `[tag] ORDER-080 done` · **ห้าม:** เปลี่ยน lever อื่น · verdict (Claude อ่าน — สนใจ EV ต่อไม้
หลังหัก opportunity cost ของไม้ที่ไม่ fill ไม่ใช่แค่ PF)

## ORDER-082 — Entry_Wave5: สัญญาณ Elliott ขา 5 ตาม rule ที่ user ถ่ายทอดเอง (2026-07-10) — `OPEN` (role: Claude spec → agent build/probe)

**Rule จากปาก user (บันทึกตรงคำ — นี่คือ ground truth ของ spec):**
- คนส่วนใหญ่พยายามเข้า wave 3 (เทรนด์ยาวสุด) แต่รู้ตัวก็ต่อเมื่อมัน confirm แล้ว (break S/R,
  break trendline) → เข้าไม่ทัน/RR ไม่คุ้ม
- **จุดได้เปรียบ: พอรู้ว่า wave 3 เกิดแล้ว → รอ pullback (wave 4) retrace ~23–38% ของ wave 3
  → เริ่มเข้าได้ เพื่อกิน wave 5**
- **SL = ยอด wave 1** (ตาม EW rule: wave 4 ห้าม overlap โซน wave 1)
- **ออก: break ยอด wave 3 / Fibonacci expansion 100%** — บริเวณนั้นมักเกิด **RSI divergence**
  ร่วม = สัญญาณเตรียมออก/เปิด trailing

**การแปลงเป็นกลไก (draft ให้ user ยืนยันก่อน build):**
1. Swing detection: ZigZag(H1/H4) label โครง 1-2-3: wave1 = impulse แรก, wave2 = retrace ไม่หลุดจุดเริ่ม,
   wave3-confirm = ราคา break ยอด wave1 แล้ววิ่งต่อ ≥ K×|wave1| (เช่น 1.0-1.618) — "รู้หลัง confirm" ตาม user
2. Arm entry เมื่อ: หลัง wave3-peak ราคา retrace เข้าโซน **23.6–38.2% ของ wave 3** (fib จาก zigzag) →
   entry ตามทิศ wave 3 (bar-open + optional confluence: RSI ยังไม่ divergence)
3. SL = ยอด wave 1 (± ATR buffer) — โครงสร้าง ไม่ใช่ระยะสุ่ม · invalid ทันทีถ้า retrace ลึกเกิน 50%
4. TP/exit: ลำดับ (ก) แตะ 100% expansion (wave5 = wave1 length จากจุดเข้า wave4) หรือ break ยอด wave3
   แล้วเปิด ATR trailing (ข) RSI divergence ที่ high ใหม่ = บังคับ trailing แน่น
5. Naked probe ตามมาตรฐาน (1 ไม้/สัญญาณ, no grid): symbol แรก = **XAUUSD H1** (trending home) +
   GBPUSD H1 · window 2023-26 + BWD 2020-22 · บาร์ผ่าน: naked PF ≥ 1.0 ทั้ง 2 window บน symbol ใดหนึ่ง
**หมายเหตุ:** มีไฟล์คอร์ส (Jobot) Elliott Wave 5 Zone v1/AAA ให้เทียบ rule (block labels) — ใช้ตรวจว่า
การตีความข้อ 1-4 ตรงกับที่คอร์สสอนไหม ก่อน build
**ห้าม:** build ก่อน user ยืนยัน draft ข้อ 1-4 · ข้าม naked probe ไป grid/recovery


---

## ORDER-082 — AMENDMENT (user ยืนยัน 2026-07-10 ค่ำ)

- ✅ ZigZag + Fibonacci = แนวที่ user ต้องการ (ตรงกับไฟล์คอร์สด้วย) · ข้อควรระวัง build:
  **ZigZag ขาสุดท้าย repaint — ใช้เฉพาะ pivot ที่ confirm แล้วเท่านั้น** + พิจารณา ATR-adaptive
  deviation แทน fixed (ให้ swing scale ตาม volatility)
- Entry level = **input เลือกได้ {23.6, 38.2, 50, 61.8}** (user: "จุดสำคัญ ... ประมาณนี้") — sweep เป็น lever
- Invalidation = **โครงสร้าง: wave 4 ห้าม overlap โซนยอด wave 1** (แทน fixed 50% เดิม — สอดคล้อง
  SL ที่ยอด wave 1 พอดี ราคาแตะ SL = โครงพังเอง)
- สถานะ: spec ครบ พร้อม build → คิวหลัง ORDER-078/083
- **Task 0 gates CLEARED (Opus, 2026-07-12, commit `fc31d0b`):** Jobot ref = misnomer (RSI+CCI martingale ไม่มี wave logic → ไม่มี ref impl, plan = spec of record) · **fable-advisor spec-check PASS** (arch A sound + guards G1-G4) · user เคาะ: both-direction · TP วัดจากราคาเข้า (entry±\|W1\|) · **trailing ตั้งแต่แรก + RSI-divergence tighten** · แผน build 6 tasks พร้อม = `docs/superpowers/plans/2026-07-12-entry-wave5.md` → รอปล่อย Task 1-4 build

## ORDER-084 — Retro-audit: ไล่ verdict DEAD/REJECT/PARKED ทั้งหมดกับกฎใหม่ (user: "ตายเปล่าเยอะ") — `CLAIMED(Claude-agent, 2026-07-10)` ขั้น extract · ขั้น judge = Claude

**ทำไม:** กฎ rescue-ladder (optimize ≥3 รอบ lever ต่างชุด × ≥2 TF ก่อนตาย) + PARKED-VERIFY(user) +
EA-SCORE เพิ่งเกิดวันนี้ — verdict เก่าจำนวนมากตัดสินก่อนกฎนี้ · user เชื่อ (ประสบการณ์ตรง: หลายตัวที่ live
อยู่รอดเพราะมือ user เคยเทส) ว่ามีของดีตายเปล่าค้างอยู่

**ขั้น 1 — extract (mechanical, agent):** กวาดทุก verdict จาก EA_SCORECARD_AND_REGISTRY.md +
MASTER_BACKLOG.md + memory signal-landscape (อ่านผ่านไฟล์ repo ที่อ้างถึง) + AGENT_TASKBOARD
(ORDER ที่ REVIEWED) → ตาราง CSV ต่อ EA/concept: ชื่อ · verdict · วันที่ · **lever ที่ sweep จริง
(นับจากหลักฐาน ไม่ใช่คำอ้าง)** · จำนวน TF ที่ทดสอบ · จำนวน symbol · best PF ที่เคยเห็น · class
(STRUCTURAL/PARAMETRIC/artifact) · หลักฐานชี้ไปไหน
**ขั้น 2 — judge (Claude):** แยก 3 กอง — (ก) STRUCTURAL/artifact ยืนยัน = ตายจริง ไม่แตะ
(ข) **under-swept ตามกฎใหม่** (sweep <3 รอบ หรือ 1 TF) = คิว rescue เรียงตาม EV: best-PF ใกล้เกณฑ์ +
mechanism เข้ากับ symbol ที่รู้จัก (reversion→ranger · breakout/trend→XAU/GBP) (ค) idea ดีแต่เครื่องมือ
ยุคนั้นไม่ถึง = **PARKED-VERIFY(user)** สรุป 3 บรรทัด/ตัวส่ง user
**ขั้น 3 — แผน rescue:** เลือก top 5-10 จากกอง (ข) → order sweep ตามสูตร rescue-ladder
(lever ชุดตามประเภทใน backtest-optimize-rigor) — **ห้ามรันใน order นี้** แค่วางแผน+ประมาณชั่วโมงเครื่อง
**Acceptance ขั้น 1:** `_triage\RETRO_AUDIT_VERDICTS.csv` ครบทุก verdict ที่หาเจอ + สรุปนับต่อกอง ·
commit `[tag] ORDER-084 extract done` · **ห้าม:** ตัดสิน/จัดกองเอง (แค่ extract หลักฐาน) · ห้ามรัน backtest

### ORDER-084 extract SUMMARY (Claude-agent, 2026-07-10 — raw counts, no judging)
1. **Total verdict rows: 154** ใน `_triage\RETRO_AUDIT_VERDICTS.csv` (per-EA/cell/concept; aggregate-pool rows ครอบ ~2,700 EAs ที่ตายเป็นกอง: ORDER-036 1,318 ex4 · ORDER-035 203 ex5 · 63-EA screen · idea_bank 251)
2. Counts by verdict: **REJECT 52 · DEAD 33 · CANDIDATE 13 · CORE/ROBUST/DEMO 12 · NO-EDGE/closed 11 · PARKED 11 · DQ/DISQUALIFIED 10 · CONDITIONAL 3 · WATCH 3 · LEAD 2 · DROP 2 · other 2**
3. **TFs_tested == 1: 141/154 (92%)** — เกือบทั้ง lab ตัดสินจาก TF เดียว (H1 ล้วนเป็นส่วนใหญ่); มีแค่ 13 ราย ที่เห็น ≥2 TF (RSI from pips 4 TF · Boss_16 2 TF · WaveS1 2 TF · NR7/PrevDay/EMATREND/Kangaroo/NuiIndy/ST03/HalfTrend ฯลฯ)
4. **Evidence = default-only/smoke-only (เข้ม): 29 rows · รวมชั้นเดียว (BWD-only/lot-check-only/hard-gate): 44 rows** — กองนี้คือผู้สมัคร rescue-ladder โดยนิยาม (ไม่เคยเห็น lever sweep แม้แต่รอบเดียว)
5. Top-10 best_PF_seen ในกอง DEAD/PARKED/REJECT/DQ (118 rows): CITY-GOLD 259.99 (artifact) · gold-grid concept 85.14 (M2 artifact) · Degold 13.12 (M1-vs-M4 artifact) · Scalper_S3 10.71 (fixed-spread artifact) · GBPJPY1H90PCWR 8.15 (PARKED-no-data, absurd-flag) · Golden Elephant 7.77 (TP-lever artifact) · Gold Stuff V7 5.09 · Dark Mimas 5.0 (regime) · **EA_SUPERTREND XAU H4 4.49 OOS (ตัวจริง — parked เพราะ corr 0.946 กับ KER)** · COT-filter 3.96 (year-split kill)
6. หมายเหตุ: top-PF ส่วนใหญ่ = artifact ที่พิสูจน์แล้ว; PF สูงสุดที่*ไม่ใช่* artifact ในกองตาย = SuperTrend 4.49 · IR Whale 3.94(suspect) · EURUSD Forex Robot 3.89 (BWD 0.39) · FZ2 3.05 (flat-lot 0.36) · 143 E4.7.4 3.0 (BWD 0.85) · AsReMix 2.99 (PARKED regime)
7. รูปแบบที่เห็นซ้ำใน extraction (ข้อมูล ไม่ใช่คำตัดสิน): กอง mass-smoke ตายด้วย 1 symbol-pair × 1 TF × default; กอง concept 200-list ตายด้วย default smoke 1-2 cell แล้วปิด "concept DEAD ถาวร"; กองที่ sweep จริง ≥3 lever มีน้อย (~25 rows: Boss_14 family · ST03 · SessionBreakout 1200-pass · FlagPennant · WaveS1 · SuperTrendFlip · Degold · ZIGL-EURUSD 216-pass ฯลฯ)
8. Sources ที่กวาดครบ: EA_SCORECARD_AND_REGISTRY.md · MASTER_BACKLOG.md · AGENT_TASKBOARD.md (ORDER-001→083) · ORDER-036_MT4_MASS_SMOKE.md · memory signal-landscape.md · STRATEGY_200_ANALYSIS.md · PROJECT_STATE.md §07-08 (อ้างถึงจาก taskboard)
9. STRATEGY_200_ANALYSIS.md = **prior scores ไม่ใช่ verdict** (คะแนน /10 ก่อนเทส) — ไม่ได้สร้าง row ต่อ prompt; ตัวที่ถูกเทสจริง (#9/20/30/62/66/68/70/83/94/100/105/127/135) มี row จากผลเทสใน backlog/signal-landscape แล้ว
10. AGENT_TASKBOARD_MERGE.md = engineering port track ล้วน (MERGE-01..08) ไม่มี EA verdict — ไม่มี row
11. ORDER-064 (ChatGPT export mining) เป็น idea-triage ไม่ใช่ backtest verdict — ไม่ได้สร้าง row (จดไว้กันสับสน)
12. Orders 048-054 ไม่มี header ใน taskboard (เลขข้าม 047→055) — verdict ของ funnel 07-08 (SqueezeBRK ROBUST · Trendline #8 EXPERIMENTAL · ConfluenceMartATR/London/plain-squeeze ตก) สกัดจาก PROJECT_STATE §SESSION 2026-07-08 + การอ้างอิงใน ORDER-059/065/067 แทน
13. Verdict ที่มี supersede-chain ถูกยุบเหลือ row เดียว (verdict ล่าสุด + ประวัติใน evidence): ST03 family (CORE→STRUCTURAL 07-10) · 2020v2 (REJECT→revive→REJECT) · Happy thaipop (PARKED→REJECT ×16.3) · Automated Forex Grail (AUTO-REJECT→revive→REJECT-spread) · LNBREAK/NRBreakout (DEAD→re-exam ORDER-008B)
14. คอลัมน์ class_claimed = คำอ้างของ verdict เดิมเท่านั้น (STRUCTURAL/PARAMETRIC/artifact/unknown) — ยังไม่มีการจัดกอง rescue/dead/verify ตามข้อห้าม
15. ขั้น judge (กอง ก/ข/ค + แผน rescue top 5-10) = รอ Claude lead อ่าน CSV


---

## ORDER-091 — MASTER PLAN: intake คลัง Forex 9 โฟลเดอร์ของ user (แผนแม่บท — ลูก 091A-D จ่ายตาม pacing) — `OPEN`

**ที่มา (user 2026-07-10 ค่ำ พร้อม annotation ต่อโฟลเดอร์ — เก็บคำต่อคำใน chat log):** คลังใหญ่กว่า
ที่ X-ray รอบแรกกวาดมาก — coverage เช็คแล้ว: `10_EA_PROJECTS` โดนแค่ 211 path · `04_FxDreema_Learner`
7 path · ขนาดจริง: ~1,100 src + ~9,600 binaries + **~1,100 report/set แนบ** (BOT MOGUL 713 + Final EA 389)

**กฎยืนพื้นทุก wave:** pacing 1-2 order/รอบ · vendor report = claim ไม่ใช่หลักฐาน (memory
wobr-botranking: BotMogul rank = adverse-selected overfit) · ทุกตัวจบ funnel ต้องได้ EA-SCORE ·
mechanism ที่เคยพิมพ์เงิน → จด IDEA_CATALOG เสมอ · DD สูง ≠ ปัดตก → diagnosis→lever (คำ user:
".Final EA อาจ DD เยอะแต่เอาไปทำต่อได้ เชื่อผม")

**Wave 0 — 091A: ขยาย X-ray+concept ให้ครบ 9 โฟลเดอร์ — `DONE(Claude-agent, 2026-07-11)`** (mechanical, dedupe hash vs 1,050 เดิม):
`wait_Fxdreema MT5` (151 src) · `3. ready to use` (38+102) · `review EA\Jobot` (1,556 bin) ·
`BOT MOGUL` (2,905 bin) · `AI_GEN` (168 src) · `Course jobot` (375 src) · `04_FxDreema_Learner`
(221 src) · `.Final EA` (189 src + 4,514 bin) → merged catalog + ตาราง "ใหม่จริง vs ซ้ำของเดิม"

**Wave 1 (ต่อจาก 085B/083B ที่ค้างคิว):**
- **091B — BOT MOGUL report sweep:** parse 713 vendor reports → ตาราง claimed PF/DD/symbol/TF →
  คัด top ตาม claim × โครงผ่าน X-ray → **BWD-OOS spot-kill ทีละ 5** (1 รัน/ตัว ฆ่าถูกสุด) —
  ห้ามเชื่อ report แนบจนกว่า BWD เราเองผ่าน

---

## ORDER-091C-D1d — JUMSTOCH pending-limit entry variant (= ORDER-080 vehicle, user idea) — `OPEN` (role: Claude/Sonnet build → run)
**ที่มา:** user + ORDER-080 · mean-reversion เข้าหา LWMA → วาง **buy-limit ใต้ราคา / sell-limit เหนือ** ที่ระดับ
grid แทน market → fill maker ไม่จ่าย spread (grid 5-7k ไม้ = ประหยัด spread เยอะ อาจดัน PF ขึ้นชัด)
**คำสั่ง:** (1) สร้าง variant `(EXP)_JUMSTOCH_pending.mq4` (หรือ port entry เข้า Boss V2) — เปลี่ยน OrderSend market
เป็น pending limit ที่ราคา entry logic เดิม + จัดการ expire/re-place · ห้ามแตะ lot/SL/exit logic (isolate ตัวแปรเดียว)
(2) compile 0/0 (3) รันเทียบ market-vs-pending บน 2 home cell (EURUSD+AUDUSD H1) + spread จริง · ตาราง EV/ไม้
เทียบ (fill-rate ของ pending ด้วย — limit ไม่ fill ทุกไม้) · **บาร์: pending PF > market PF ที่ spread จริง = ยืนยันคุณค่า**
· **ห้าม:** เปลี่ยน lever อื่น · verdict · commit `[tag] ORDER-091C-D1d done`
**หมายเหตุ:** นี่ตอบ ORDER-080 (limit vs market) ด้วย EA จริงตัวแรก → ปิด 080 ไปในตัวถ้าได้ผล


---

## ORDER-091C-D1c PROCESSING (lead จะทำเมื่อ D1c เสร็จ — user doctrine 2026-07-11):
1. เอา **ทุก cell ที่ผ่านบาร์** (PF≥1.1 & trades≥200 & DD<25% & ไม่ data-gap) = home set ไม่ใช่เลือกตัวเดียว
2. คำนวณ **pairwise correlation ของ equity curve ระหว่าง symbol ที่ผ่าน** (corr_monthly.py logic) →
   เก็บชุดที่ corr < 0.8 = multi-symbol demo config · คู่ที่ corr > 0.8 = surface ให้ user เลือก (ไม่ auto-drop)
3. cell ที่เฉียด (PF 1.0-1.1) = **candidate build-on** (ใส่ session/vol filter หรือขยาย Range spacing) ไม่ทิ้ง →
   เข้า D1d หรือ tweak-probe แยก
4. ผลลัพธ์ = JUMSTOCH multi-symbol demo-bench set (EA เดียว หลาย symbol) + คิว build-on ต่อ (D1d pending + tweaks)


---

## ORDER-095 — CAMPAIGN: ขยาย symbol ให้ EA ที่ deploy อยู่แล้ว (user 2026-07-11: "ขยายผลไปตัวที่ demo อยู่ ได้อีกเยอะ") — `OPEN` (multi-session, pace 1 EA/batch)

**หลักการ (build-on doctrine + multi-symbol reuse):** EA ที่ deploy แล้ว = validated ที่ home เดียว · ขยายไป
symbol อื่นที่ผ่านเกณฑ์ (corr < 0.8 ระหว่างกัน) = เพิ่มไม้โดยไม่ต้องหา EA ใหม่.

**⛔ CAVEAT ชี้ขาด (lead judgment — ขยายผิดตัว = กระจายทางแพ้):** ขยายได้เฉพาะ EA ที่ **entry มี edge จริง
(flat-lot PF>1)** เท่านั้น. EA ที่ entry ไม่มี edge = ขยาย symbol ยิ่งเพิ่มวิธีเสียเงิน:
- ✅ **ขยายได้ (source + flat-lot edge ยืนยัน):** EA_BREAKOUT_XAU (breakout, real, travels) · Boss_14_GridLog
  (demo flagship, 7 symbol แล้ว) · EA_SUPERTREND (flat-lot PF 2.93 — pending demo) · CB_GBP ConsoBreakout ·
  NuiIndy Dynamic RSI+ADX (source อยู่ .Final EA)
- ❌ **ห้ามขยาย (entry ไม่มี edge — กำลังถอดอยู่แล้ว):** RSI-MR (flat-lot 0.78) · ST_EA03 family (0.68/0.40) ·
  ST03 replica — พวกนี้ถอดเพราะ entry ไม่มี edge → ขยายยิ่งผิดหลัก
- ⚠️ **compiled-only (.ex4 รันได้แก้ไม่ได้):** UnNomGuai/swb/RSI-orig (MT4 demo) = ขยายแบบ run-as-is บน symbol
  อื่น + corr check (flat-lot check = ปิด escalation input ถ้ามี) · Zeus/Kangaroo = martingale locked, Zeus เปราะ
  (stop-out gold) → ไม่ขยาย

**Methodology ต่อ EA (เหมือน JUMSTOCH D1c):** (1) flat-lot smoke บน symbol candidate ที่ยังไม่ deploy → เอาที่
entry PF>1 (2) full-config IS/OOS บนตัวที่ผ่าน (3) corr equity-curve vs leg เดิม → เก็บ corr<0.8, คู่ >0.8 บอก user
(4) เพิ่มเข้า demo config. **pace 1 EA/batch** · Boss_14 = ตัวแรก (D1c-สไตล์)

## ORDER-097 — build "(HEX)_HexaGrid" (user สั่งเขียนจากสเปคเอง 2026-07-11) — build `DONE(Claude, 2026-07-11)` · baseline `DONE(Claude, 2026-07-11)` · funnel `OPEN` (role: agent/Claude) _(renumbered 096→097: ชนกับ CAMPAIGN ORDER-096 WOBR)_

**ที่มา:** user ส่งสเปค HexaGrid เต็ม (6 ระบบอิสระ magic-scoped แชร์ grid engine ×1.33 cap 10 + SL จริงทุกไม้,
regime EMA224-slope+ADX, 7 ชั้นจัดการ+global cap) แล้วสั่ง "เขียน EA ตัวนี้ + รอรันเลย" (optimize เองไม่ได้ — คอมเต็ม).
brainstorm → standalone-port (core เดิม single-magic global-state #include ตรงไม่ได้) → user เคาะ standalone.

**สถานะ build (DONE):**
- source: `ea_projects\(HEX)_HexaGrid\(HEX)_HexaGrid_rev01.mq5` · compiled: `(HEX)_HexaGrid_rev01.ex5`
  (อยู่ในโปรเจกต์ + deploy แล้วที่ `D:\Meta 5\MQL5\Experts\HEX_HexaGrid_rev01.ex5`)
- **compile 0 errors / 0 warnings** (MetaEditor64, X64 Regular)
- ผ่าน mql-code-reviewer: ไม่มี BLOCKER · แก้ 2 HIGH (sys4 ADX-only ไม่โดน slope-gate · g_suppress_log optimize)
- **RISK CLASS L4** (capped-martingale+grid, ไม่มี rescue-hedge) — user รับทราบ (เลือก global cap 18% เอง)
- default = conservative UNOPTIMIZED (spacing ATR-adaptive multi-symbol, risk 2%/basket, mult 1.33, maxLevels 10)

**⚠️ GOTCHA ก่อนรัน (บันทึกไว้กันเสียเวลา):**
1. **ต้องบัญชี HEDGING เท่านั้น** — OnInit มี guard: ถ้า `ACCOUNT_MARGIN_MODE != RETAIL_HEDGING` = INIT_FAILED
   (netting จะ merge 6 ตะกร้าทับกัน). **เช็ค log หา `[HEX][FATAL]` ก่อนสรุป 0 trades = code bug** — ต้องมั่นใจ
   server ของ terminal ที่รัน tester เป็น hedging ก่อน
2. `_06_AllowLive=false` default แต่ tester-gate เปิดอัตโนมัติ (รัน Strategy Tester ได้เลย)
3. weekend-cut `_G_CutHourServer=12` เป็น proxy 19:30 ไทย — ปรับตาม GMT offset ของ feed ที่เทสถ้าจะเอาชั้นนี้

**คำสั่ง (baseline ก้อนแรก — both-regime, coarse Model 1 ก่อน, 1 symbol × 2 window ตาม pacing):**
```powershell
# ยืนยัน hedging ก่อน แล้วรัน 2 window (trend BWD + recent). แทน window ทีละรอบ:
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'HEX_HexaGrid_rev01' -Symbol XAUUSD -Period H1 -FromDate 2020.01.01 -ToDate 2022.12.31 -Model 1 -Deposit 10000 -Leverage 100 -ReportName HEX_BASE_XAU_BWD -Portable -Terminal 'D:\Meta 5\terminal64.exe'
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'HEX_HexaGrid_rev01' -Symbol XAUUSD -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -Deposit 10000 -Leverage 100 -ReportName HEX_BASE_XAU_REC -Portable -Terminal 'D:\Meta 5\terminal64.exe'
```
**Acceptance (raw เท่านั้น — ห้าม verdict, lead ตัดสิน):** 2 report เข้า `_mt5_auto\reports\` · ต่อ window append:
PF · net profit · trades · maxEqDD% · maxBalDD% · + **ยืนยันว่า OnInit ไม่ FATAL (มี trade เกิดจริง)** ·
สังเกตว่าระบบไหน (magic 20260707-13) มี trade บ้างจาก comment/journal · commit `[tag] ORDER-097 baseline done`

### ORDER-097 BASELINE RESULT (Claude, 2026-07-11) — raw + lead note (NOT a kill-verdict)
Runner `scripts\mt5_run.ps1 -Portable` บน `D:\Meta 5` (account 146237 = **hedging ✅**, guard ผ่าน — EA รันจริง
ไม่ FATAL). **Model 1 coarse** (control-points, optimistic สำหรับ grid), default compiled inputs (no .set),
deposit 10000, leverage 1:100, XAUUSD H1. report เขียนลง `D:\Meta 5\HEX_BASE_XAU_{REC,BWD}.htm` (portable
เขียน root — mt5_run แจ้ง "NO REPORT" เพราะหาผิดที่ แต่ไฟล์มีจริง + test "successfully finished").

| window | PF | Net$ | Trades | Bal-DD | Eq-DD | Sharpe |
|---|---:|---:|---:|---:|---:|---:|
| recent 2023.01–2026.07 | 0.97 | -2,224 | 12,403 | 56.80% | 57.95% | -0.31 |
| BWD trend 2020.01–2022.12 | 0.88 | -5,937 | 9,099 | 65.04% | 65.44% | -1.38 |

**Lead note (ยังไม่ใช่ verdict — VERDICT GATE ยังไม่ครบ: sweep 0 lever, 1 symbol, 1 TF):**
- **default config = NO EDGE ทั้งสอง regime** (PF 0.88–0.97 แม้ Model-1 optimistic → real-tick น่าจะแย่กว่า) → **ยังไม่ผ่านบาร์เข้ารอบ Model-4**
- **DD 57–65% = ตรงกับ worst-case ~60% ที่ flag ตอน build เป๊ะ** · global cap 18% คุมได้แค่ floating ชั่วขณะ ไม่กัน cumulative bleed เมื่อ edge ติดลบ
- **12k/9k trades = spacing แน่นเกิน / 6 ระบบยิงพร้อมกันถี่มาก** — สมมติฐานแรกที่ควร sweep: ขยาย `_G_SpacingATRmult`/`_G_SL_ATRmult` + ลดจำนวนระบบที่เปิดพร้อมกัน
- **ไม่ตีตาย (PARAMETRIC):** unoptimized/1-symbol/coarse → tag **build-on / PARKED-VERIFY(user)** ไม่ใช่ DEAD · แต่ห่างบาร์พอควร ไม่ใช่เฉียด
- **บล็อกจริง:** user optimize ไม่ได้ (คอมเต็ม) → funnel ที่เหลือรอพื้นที่ว่าง. ถ้าเปิดได้: sweep spacing×SL×system-count → both-regime → ถ้าโผล่ PF>1 ค่อย Model-4 real-tick → OOS → MC

**ห้าม:**
- **ห้ามตัดสิน edge จาก Model-1 pass** — grid fill-sensitive, Model-1 optimistic; ผ่าน M1 = แค่ "ผ่านเข้ารอบ Model-4"
  ไม่ใช่ candidate (VERDICT GATE #6 + doctrine grid-EA ต้อง real-tick confirm)
- ห้าม tune ก่อนเห็น baseline both-regime (VERDICT GATE #3)
- ห้ามขยาย symbol×TF เต็มก่อน baseline โชว์ชีพจร (ถ้า XAU both-window PF>1 coarse → ค่อยเปิด funnel: Model-4 real-tick
  → OOS split → MC ตาม robustness-validator · ถ้าติดลบทั้ง 2 window = กลับมาดู logic/default ก่อน ไม่ใช่ tune หนี)
- ถ้า INIT FATAL (ไม่ใช่ hedging) = **หยุด แจ้ง user** ว่าต้องเทสบนบัญชี/เทอร์มินอล hedging ห้ามแก้ guard ออก

---

## ORDER-098 — CAMPAIGN: fxDreema YouTube corpus build-on — `OPEN` (multi-session · user prioritizes ใน session เดียวก่อนลงมือหนัก)

**ที่มา (2026-07-12):** แกะช่อง @fxdreemalearner ครบ 320 คลิป → catalog กลไก 272 EA. ผล + shortlist เต็ม =
`_triage/fxdreema_youtube/BUILDON_SHORTLIST.md` (+ `CATALOG.jsonl` · `DIGEST.txt`). pipeline/สถานะ = memory
`fxdreema-youtube-corpus`. toolchain แกะคลิปเพิ่ม = `scripts/yt2text.ps1` (memory `yt-whisper-toolchain`).

**Doctrine ที่บังคับทุก sub-order (paid rules):**
- เกือบทุก EA = chassis ST03 (entry→grid→trailing→no-SL). **flat-lot probe = ด่านแรกบังคับทุก entry** —
  ปิด escalation (single order, fixed lot, SL/TP) แล้ว PF ยัง >1 ไหม. ST03-dead vs Kangaroo-edge แยกตรงนี้.
- **ห้ามตัด grid/martingale ทิ้ง** (user doctrine [[feedback-buildon-pf-gt-1]]) — ขุด entry + MM part มาแปะ
  chassis ที่ validated แล้ว (MatchaGrid bounded+SL · Kangaroo DD-release · JUMSTOCH capped-SL'd reversion grid).
- ตัวเลข % ในการ์ด = คำอ้างคนสอน **ยังไม่ verify** — guilty until flat-lot + funnel proves.
- VERDICT GATE เต็มใช้ตามปกติ (≥3 lever × ≥2 TF ก่อน reject · both-regime · holdout+MC ก่อน deploy).

**Sub-orders (A/B พร้อมรัน · C = library · user เลือกลำดับ):** 098-A FVG-fill entry · 098-B MACD-divergence entry ·
098-C reusable MM-parts. **ห้ามเริ่ม build campaign เต็มจนกว่า user เคาะลำดับใน session ที่นัดไว้** — sub-orders
ด้านล่าง stock ไว้ให้พร้อมเฉยๆ.

---

## ORDER-098-A — FVG-fill entry (EX009 algo) flat-lot smoke — `OPEN` (role: Claude/Sonnet build → agent smoke)

**ทำไม:** FVG/ICT-zone (24 การ์ด) = angle ใหม่จริงที่ยังไม่มีใน landscape (มีแค่ PARKED-CONCEPT จาก FB reel ไม่มีตัวเลข).
ทดสอบว่า **entry เปล่าๆ มี edge ไหม ก่อนแตะ grid/MM** (flat-lot probe).

**สเปค entry (จาก EX009 + EX196):**
- FVG bullish = `Low[1] > High[3]` (ช่องว่าง 3 แท่ง) · เข้าเมื่อ `Close[0]` ย้อนกลับมาปิด *ใน* ช่อง (ระหว่าง High[3]..Low[1])
  + ยืนยัน bullish engulfing (body[0] > body[1]) · mirror สำหรับ SELL (`High[1] < Low[3]`)
- **flat-lot บังคับ: single order, fixed 0.01, SL 20 pip / TP 15 pip** (ตาม EX009) — **ไม่มี grid ไม่มี martingale**
- bar-open gate + digit-aware pip + magic-scoped (ผ่าน `mql-code-reviewer` ก่อน compile)

**คำสั่ง:** build `ea_projects/(EXP)_FVGFill_Naked/` → compile headless → smoke Model 1, 2023.01-2026.01:
EURUSD H1 · EURUSD H4 · XAUUSD H1 · XAUUSD H4 (4 cells).

**Acceptance:** ตาราง 4 แถว (PF · Trades · EqDD% · Win%) append ใต้ order นี้ + path report ดิบ. commit `[tag] ORDER-098-A done`.
**ห้าม:** ใส่ grid/martingale ก่อน flat-lot PF ผ่าน · ตัดสิน dead ก่อนครบ VERDICT GATE (≥3 lever × ≥2 TF) ·
เขียน verdict (นั่นงาน lead) · Model-2 tight-TP (TP 15pip อาจ < spread บน XAU → ใช้ Model 1 + ตรวจ spread-artifact).

---

## ORDER-098-B — MACD-divergence entry (EX154/EX010 algo) flat-lot smoke — `OPEN` (role: Claude/Sonnet build → agent smoke)

**ทำไม:** MACD *divergence* (price LL / MACD HL) ≠ naked MACD-cross ที่ตายไปแล้ว = reversion signal ที่ยังไม่เคย smoke.
EX120 เสริม volume-confirm + low-freq (RR 1:3-1:5).

**สเปค entry:** bullish divergence = price ทำ lower-low แต่ MACD main ทำ higher-low (lookback N swing) · เข้า BUY ·
mirror SELL · **flat-lot single order fixed 0.01, SL = 3-bar extremum, TP = 200% SL** (จาก EX113/EX013 RR 1:2).

**คำสั่ง:** build `ea_projects/(EXP)_MacdDiv_Naked/` → compile → smoke Model 1 2023.01-2026.01:
EURUSD H1/H4 · XAUUSD H1/H4 (4 cells).

**Acceptance:** ตาราง 4 แถว (PF/Trades/EqDD%/Win%) + report path. commit `[tag] ORDER-098-B done`.
**ห้าม:** grid ก่อน flat-lot ผ่าน · verdict · reject ก่อนครบ gate.

---

## ORDER-098-C — reusable MM-parts library (dynamic close_money + Fibonacci-capped lot) — `OPEN` (role: Claude · depends: chassis เป้า)

**ทำไม:** 2 ชิ้นนี้ = "cap + linear/log" ที่ user สั่ง มีคนทำไว้แล้วในคลัง — เอาไปแปะ chassis ที่ผ่าน flat-lot (098-A/B)
หรือ retrofit บน MatchaGrid/Kangaroo/JUMSTOCH ได้เลย (pure risk-mechanics ไม่ยุ่ง entry-edge).

**สเปคที่จะสกัดเป็น module:**
- **dynamic close_money** (EX183/EX078): `close_target = base + (open_order_count / C) * base` — เป้าโตตามจำนวนไม้
- **Fibonacci-bounded lot** (EX191): sequence `0.01,0.02,0.03,0.05,0.08,0.13` cap ที่ step 13× (แทน martingale ×2) +
  reset เมื่อ flat · EX211 variant มี SL30/TP50 อยู่แล้ว = bounded+capped ต้นแบบ

**คำสั่ง:** เขียนเป็น include module (`ea_template/core/` ตาม pattern เดิม) + run `tpl_regression.ps1` cage หลังแก้ core.
**Acceptance:** module compile ผ่าน + regression cage เขียว + unit note ว่าใส่กับ chassis ไหนได้. **ยังไม่ต้อง backtest** (งาน integrate อยู่ order ถัดไปหลัง 098-A/B รู้ผล).
**ห้าม:** แก้ core โดยไม่รัน `tpl_regression.ps1` · integrate เข้า chassis จริงก่อน entry-edge ยืนยัน (จะปนตัวแปร).

---

## ORDER-099 — Contract A: B0 historical baseline + fact→owner map — `DONE · Codex REWORK ×2 → FIXED 2026-07-12 → re-review (round 3) pending` (SYSTEM ORDER 1 of ≤4 memory-control build)

> **Design source:** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20 @ `4eb839d`** (Contract A = §20.8) · pin **`B0_CUTOFF_SHA=4eb839df09b1911cec2de18ec4a2df51cf766606`**
> **ทำได้:** Claude/Opus (judgment: cohort selection · incident taxonomy · owner conclusions) · qwen/fast-worker (mechanical extraction เท่านั้น) · **👉 แนะ:** **Opus-seat** (§20 บอก Opus-only for judgment)

**ทำไม:** §20.2 workstream ที่ 1. ก่อนสร้าง harness/archive/events ต้องมี (ก) baseline B0 ของ 20 order ประวัติศาสตร์เพื่อวัดว่า MVP-0/3/1 ทำให้ดีขึ้นจริงไหม (ข) fact→canonical-owner map เพื่อกันสร้าง source-of-truth ชุดที่สอง. **นี่คือ audit output ไม่ใช่ authority ใหม่** — ไม่เปลี่ยนใครเป็นเจ้าของอะไร.

**Outputs (ทั้งหมดอยู่ใต้ dir เดียว `docs\memory_control\` — generated artifact เท่านั้น):**
1. **fact→owner map** — ต่อ fact แถวหนึ่ง: `fact · canonical_owner (ไฟล์/path) · permitted_writers · generated_consumers · freshness_check`. อ้างอิงตาราง §20.7 เป็นฐาน — ห้ามขัด.
2. **B0 raw dataset** (CSV/JSONL reproducible) ของ **20 terminal orders ณ cutoff `4eb839d`** — ต่อแถว: `ORDER_ID · source_anchor (taskboard line/commit) · evidence_commit_or_path · classification (machine-checkable) · onboarding_time · context_incident · context_rework · wrong_order_file_scope · lead_attention_hours`.
3. **B0 report สั้น** + inclusion/exclusion list ชัดเจน (เหตุผลต่อ order ที่ตัดออก).

**Selection rule (bounded, machine-checkable):** เลือก 20 order ที่ **ปิดจริง (มี execution + result) ก่อน/ณ `4eb839d`** · **ตัดออก:** umbrella/CAMPAIGN order ที่ไม่มี execution เอง · `SKIPPED` · no-execution · order ที่ไม่มี evidence. ต่อแถวต้องมี ORDER ID + source anchor + evidence commit/path + classification.

**B0 reality clause (§20.3 — บังคับ):** metric ที่ **ไม่เคยถูกบันทึกตอนงานวิ่งจริง** (onboarding time, lead-attention hours) = **`NOT_RECORDED`** — **ห้าม reconstruct จากความจำ, ห้ามใส่ 0**. metric ที่นับได้จาก git + taskboard history (rework, wrong-scope) ให้คำนวณจาก raw row และต้อง reproduce ได้.

**Acceptance (ตัวเลขล้วน — ตรวจได้ทุกข้อ ได้/ไม่ได้):**
- [ ] `docs\memory_control\` มี 3 artifact ครบ (map · B0 dataset · report)
- [ ] B0 dataset = **20 distinct eligible orders** (ไม่ซ้ำ ORDER ID · ไม่มี umbrella-only/SKIPPED/no-execution)
- [ ] **unresolved owner conflict = 0** ใน fact→owner map (ถ้าเจอ conflict → order = BLOCKED พร้อมคำถาม, **worker ห้ามเลือก owner เอง**)
- [ ] **≥5/20 traces ถึง canonical evidence จริง** (commit/path เปิดได้)
- [ ] rework / wrong-scope ทุกค่า **reproduce จาก raw row ได้** (สคริปต์/สูตรแนบ)
- [ ] onboarding/lead-hour ที่ขาด = `NOT_RECORDED` ทุกช่อง (ไม่มี 0 ปลอม, ไม่มีเลข reconstruct)
- [ ] canonical docs (`PROJECT_STATE.md`/`AGENTS.md`/scorecard/DEPLOYMENTS.csv/taskboard order เดิม) **ไม่ถูกแก้** นอกจาก bootstrap pointer/order lifecycle
- [ ] `[tag] ORDER-099 done` + ผลดิบ append ใต้ order นี้

**ห้าม (out of scope — §20.8 Contract A):**
- ❌ migrate/archive data ใดๆ (นั่นคือ Contract C) · ❌ implement harness/events/packet (Contract B/D/MVP-2)
- ❌ เปลี่ยน authority/owner/write-path จริง · ❌ แตะเงินจริง/deployment/verdict
- ❌ worker ตัดสิน owner conflict เอง → **mark BLOCKED, ให้ Opus resolve แยก**
- ❌ ใส่ metric ที่ reconstruct จากความจำ (ต้อง `NOT_RECORDED`)
- ❌ pre-open Contract B/C/D — order ถัดไปเขียนหลัง Opus review ORDER-099 เท่านั้น

**Rollback:** ลบเฉพาะ generated B0/map artifact ใน `docs\memory_control\`; design pointer ใน PROJECT_STATE คงไว้. canonical docs ต้องไม่เปลี่ยน.

**Routing/mechanics:** mechanical extraction (grep taskboard, list ORDER IDs, pull evidence paths) → qwen/fast-worker ได้ · cohort selection + incident taxonomy + ทุก owner conclusion = **Opus-seat**. ผลดิบ append ใต้ order นี้ก่อน Opus mark REVIEWED. (B0 execution/result = commit แยกจาก canonicalization commit — ห้ามรวม.)

### ผลดิบ (Opus, 2026-07-12) — executed by Opus-seat

**Artifacts** (ใต้ `docs/memory_control/` — generated audit output, ไม่ใช่ authority ใหม่):
- `FACT_OWNER_MAP.md` — 10 fact → owner/writers/consumers/freshness (ฐาน §20.7 + AGENTS.md §2) · **owner conflict = 0**
- `B0_DATASET.csv` — **20 terminal order @ `4eb839d`** (INFRA 6 · CANDIDATE 7 · REJECT 5 · PARK 2, ไม่ซ้ำ ID)
- `B0_REPORT.md` — selection rule + inclusion/exclusion list + metric method + reproducibility recipe
- `README.md` — สรุป + reproduce จาก pinned SHA

**Cohort rule:** 20 most-recently-closed eligible terminal orders @ cutoff (exclude umbrella/SKIPPED/OPEN/CLAIMED/annotation). universe = 110 headers.

**Acceptance self-check (ครบ):** 20 distinct ✓ · owner conflict 0 ✓ · **16/20 traces มี evidence commit** (เกิน ≥5/20) ✓ · `context_rework`=0 + `wrong_order_file_scope`=0 นับซ้ำได้จาก git+taskboard ✓ · onboarding/lead-hours/context-incident = `NOT_RECORDED` ทุกแถว (ไม่มี 0 ปลอม/reconstruct) ✓ · canonical docs ไม่เปลี่ยนนอกจาก order lifecycle ✓

**System note:** เจอ ORDER-ID collision 2 ครั้ง (042→043, 096→097) นอก cohort — บันทึกใน report ไม่ทิ้งเงียบ (เป็น class ปัญหาที่ Contract C ตั้งใจแก้).

**Status:** DONE + Opus self-review = ACCEPT — **แต่ Codex blind review (2026-07-12) = REWORK, ถูกต้อง 3 ข้อ (Opus verify ยืนยันทั้งหมด, self-ACCEPT ผิดจริง):**

### Codex REWORK (ORDER-099) → resolution 2026-07-12
1. **cohort 19 ไม่ใช่ 20 distinct** — `ORDER-091B` phase1 + "เฟส 2" = canonical ID เดียวกัน (header L4113+L4207) นับเป็น 2 ผิด → **FIX:** ตัด phase2, เลื่อน `ORDER-088` (DONE 07-10) เข้าแทน · CSV ยืนยัน 20 distinct, 0 dup
2. **evidence SHA ผิด 2 แถว** — 078 อ้าง `9e1d1acf` (corr-check) → จริง `00392e30` (+review `b93e4b9d`) · 085B อ้าง `9e1d1acf` → จริง `b5b1b429` (+`e481e00f`) → **FIX:** แก้ CSV + report §7
3. **rework/wrong-scope 0 ไม่ reproducible** — เดิมบอก 0 จาก inspection → **FIX:** เพิ่ม reproducible grep query ใน report §6/§9 (marker regex EN/TH) · รันแล้ว: wrong-scope hits = non-cohort (043/039/097), rework = 0 hits → cohort 0/0 ยืนยันซ้ำได้
- Codex PASS: owner-conflict=0 · B0 reality clause (NOT_RECORDED ถูก) · canonical isolation

### Codex re-review round 2 (2026-07-12) = STILL REWORK → fixed อีกชั้น (Opus verify ยืนยันถูกทั้ง 3)
- **cohort ยังผิด:** round-1 เอา `ORDER-088` (07-10) มาเติมช่องที่ว่าง — ผิด เพราะ **`ORDER-081` (Crypto lane feasibility, DONE 07-11)** เป็น order 07-11 ที่ผม**มองข้ามตั้งแต่แรก** → 18 orders ของ 07-11 ต้องมี 081 · 088 = ลำดับ 21 (ตกไป) → **FIX:** 088→081 (class RESEARCH) · CSV ยืนยัน 20 distinct
- **085B review SHA ยังผิด:** `e481e00f` = review ของ ORDER-**085** (ที่เปิด 085B) · review จริงของ 085B = **`ee0ae804`** ("REVIEW 085B: BWD FAIL PF 0.88") → **FIX:** แก้ CSV+§7
- **§9 mapping ไม่ตรงผลรันจริง:** enclosing header จริง = 046/043/042/072/075/097 (ไม่ใช่ "043/039/097" ที่เขียนไว้) → **FIX:** เขียน mapping ใหม่ให้ตรง grep จริง · cohort ยัง 0/0 (ทั้ง 6 hit = non-cohort)
- Codex spot-check evidence อื่น (083B/092/093/091C-D1c/095-A) = ผ่าน · regression (owner-conflict 0, NOT_RECORDED, canonical isolation) = ผ่าน

**Status หลังแก้ 2 รอบ:** artifact ปรับครบใน `docs/memory_control/` (commit แยก) → **DONE, รอ re-review รอบ 3**. บทเรียน: cohort selection = จุดอ่อนซ้ำ (ผิด 2 รอบ) — round 3 ต้อง re-derive 07-11 set แบบ mechanical (มี 18 distinct: ยืนยันด้วย grep '2026-07-11' + terminal filter) ก่อน sign-off.

---

## ORDER-100 — Contract B: MVP-0 blocking execution harness (`run_batch.ps1`) — `REWORK(Codex blind review 2026-07-12) — 2 blockers + 4 correctness fixes · rebuild รอ user go · ห้ามใช้รัน MT4/MT5 จริงจนกว่าจะแก้` (SYSTEM ORDER 2 of ≤4 memory-control build)

> **Design source:** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` **§20.8 Contract B @ `4eb839d`** + §20.2 seq #2 + §20.5 (reversible details delegated)
> **ทำได้:** Codex-direct (build wrapper + TDD) · qwen/fast-worker (runner inventory เฟส 1) · Claude/Opus (interface+safety = เขียนไว้ในใบนี้แล้ว) · **👉 แนะ:** **qwen** เฟส 1 (mechanical) → **Codex-direct** เฟส 2 (code+TDD)
> **Skills:** `tdd` (wrapper + append manifest) · `karpathy-guidelines` (surgical, explicit success criteria)
> **Gate note:** system order 2 จาก ≤4 · review gate อยู่หลัง order ที่ 4 · ORDER-099 = self-ACCEPT ค้าง external review (B ไม่กิน output ของ B0 → เขียนคู่ขนานได้ แต่ถ้า B0 ถูก REWORK ใบนี้ไม่กระทบ)

**ทำไม:** วัดแล้ววันนี้เอง — ของเสียที่แพงสุดไม่ใช่ context แต่คือ **agent stall + concurrent-writer collision** (session นี้โดน 2 ครั้ง: broad `git add` กวาดไฟล์ + branch switch ใต้เท้า). harness นี้ = ชั้น orchestration ที่ทำให้ batch **หยุดเป็น (blocking), เห็น fail ชัด, กันชนกันข้ามเลน, และ resume ได้** โดย **ไม่แตะ tester logic เดิม**.

**หลักการเหล็ก (Opus เขียน — ห้าม implementer เปลี่ยน):**
1. **Adapter ไม่ reimplement** — wrapper *เรียก* runner เดิม (`mt5_run.ps1`/`mt4_run.ps1`/`mt5_optimize.ps1`/`mt4_optimize.ps1`/`mass_smoke_*`) ตามเดิมทุกตัว **ห้ามเขียน tester logic ใหม่**
2. **No new kill / no new process `-Force`** — wrapper **ห้ามมี** `Stop-Process`/`taskkill`/global kill/`-Force` บน process. timeout-kill ต่อ-PID ที่ runner เดิมมีอยู่ (mt5_run:113, mt4_run:123) = ปล่อยไว้ในตัว runner **ห้ามยกมาไว้ wrapper และห้ามเพิ่มของใหม่** · (`-Force`/`New-Item -Force` บน **ไฟล์/โฟลเดอร์** = อนุญาต ไม่ใช่ process — แต่ห้ามเพิ่มบน process)
3. **ห้ามแตะ tester-safety เดิม** — GUI-already-running abort (`exit 2`) + `-Force` override ของ runner = คงเดิมเป๊ะ
4. **Lane model = ของเดิม** (AGENTS.md §3.2): MT5 lane1 `D:\Meta 5` · lane2 `D:\Meta 5b` · lane3 `D:\Meta 5c` (ห้าม Model-4) · MT4 lane1 `D:\Meta4` · lane2 `D:\Meta4b` · **Model-4 = SERIAL lane1 เท่านั้น** · ในเลนเดียว = ทีละ job

**เฟส 1 — runner inventory (deliverable, mechanical → qwen):** ตาราง `docs/memory_control/RUNNER_INVENTORY.md` ต่อ runner: `path · purpose · key params (Terminal/DataDir/Portable/Model/Report) · lane ที่ใช้ · exit-code semantics · timeout/kill เดิม`. ครอบ ≥ `mt5_run · mt4_run · mt5_optimize · mt4_optimize · mass_smoke_mt5 · mass_smoke_mt4 · mt5_batch_shortlist · qwen_batch_runner`. **adapter design เฟส 2 ต้อง derive จากตารางนี้.**

**เฟส 2 — `scripts/run_batch.ps1` (deliverable, Codex + TDD) ตาม interface contract:**
- **Input:** job manifest (list ของ job — แต่ละ job มีอย่างน้อย `id · runner · args · lane · model`). รูปแบบไฟล์ manifest (JSON/CSV/PSD1) + ชื่อ param = **delegated to Codex** (§20.5) ตราบใดที่มี field ครบ
- **Blocking:** รัน job แล้ว *รอ* ให้จบก่อนไป job ถัดที่ผูกกัน — ไม่ fire-and-forget
- **Lane-aware:** ห้าม dispatch 2 job เข้าเลนเดียวกันพร้อมกัน (block/queue ไม่ใช่ fail) · Model-4 job → serial lane1
- **Fail-visible:** job fail (runner exit ≠ 0) → **หยุด job ที่เหลือในลำดับนั้น + wrapper exit ≠ 0** + log เหตุชัด
- **Resume:** รันซ้ำด้วย manifest เดิม → รันเฉพาะ job ที่ยัง `pending/failed` · job `done` = skip (idempotent)
- **Manifest state file:** บันทึกต่อ job = `id · runner · lane · state(pending/running/done/failed) · start · end · exit_code` (append/update, กู้คืน resume ได้)

**Acceptance (ตัวเลข/ไฟล์ล้วน — ตรวจได้ทุกข้อ ด้วย mock runner ไม่ต้องเปิด MT5 จริง):**
- [ ] เฟส 1: `RUNNER_INVENTORY.md` ครบ ≥8 runner พร้อม 6 คอลัมน์
- [ ] mock success path → wrapper **exit 0** + manifest ทุก job = `done`
- [ ] mock 1 job fail → job ถัดไป **ไม่รัน** + wrapper **exit ≠ 0** + manifest job นั้น = `failed`
- [ ] interrupt กลางคัน แล้วรันซ้ำ → **รันเฉพาะ job ที่ยังไม่ done** (job done เดิมไม่รันซ้ำ = idempotent) พิสูจน์ด้วย marker/timestamp
- [ ] lane collision: 2 job lane เดียวกัน → **ไม่รันพร้อมกัน** (blocked/queued) พิสูจน์ด้วย overlap-check ใน manifest time
- [ ] `grep -rInE 'Stop-Process|taskkill|-Force' scripts/run_batch.ps1 <fixtures>` → **ไม่มี** kill/process-`-Force` ใหม่ (เฉพาะ file-op `-Force` ที่จำเป็นเท่านั้น + ต้องมี comment)
- [ ] runner เดิมทุกไฟล์ **byte-unchanged** (`git diff` ว่างสำหรับ mt5_run/mt4_run/*optimize) = wrapper adapt ไม่แก้ของเดิม
- [ ] `[tag] ORDER-100 done` + ผลดิบ (test output ทุก fixture) append ใต้ order นี้

**ห้าม (out of scope — §20.8 Contract B):**
- ❌ `Stop-Process`/`taskkill`/global kill/process-`-Force` ใหม่ · ❌ แก้พฤติกรรม tester-safety เดิม (GUI-abort/exit-2)
- ❌ reimplement tester logic (ต้องเรียก runner เดิม) · ❌ แก้ไฟล์ runner เดิม (adapt เท่านั้น)
- ❌ รัน MT5/MT4 จริงใน fixture test (ใช้ mock runner ที่ echo + exit code ตามสั่ง) · ❌ implement MVP-3/events/packet
- ❌ pre-open Contract C/D — เขียนหลัง review ORDER-100

**Rollback:** ลบ/ปิด `run_batch.ps1` + fixtures + `RUNNER_INVENTORY.md`; runner เดิมต้องทำงานเป๊ะเหมือนก่อนมี wrapper (พิสูจน์ด้วย byte-unchanged + smoke 1 run ตรง runner).

**Routing:** เฟส 1 (inventory) → qwen/fast-worker · เฟส 2 (wrapper+TDD) → Codex-direct · Opus review ผลดิบ + verify grep-no-kill + byte-unchanged ก่อน mark REVIEWED. (Contract B = commit แยก — ห้ามรวมกับ B0/canonicalization.)

### ผลดิบ (Opus lead + Sonnet-subagent build, 2026-07-12) — executed

**Build:** dispatch การ build ให้ Sonnet subagent (Claude quota ไม่เผา ChatGPT · Opus คุม commit เอง) ตาม interface+safety spec ในใบนี้เป๊ะ · Opus verify เอง (รัน test + อ่านโค้ด + grep + byte-check) ไม่เชื่อคำ subagent.

**Files (ทั้งหมดใน allowlist):**
- `scripts/run_batch.ps1` — wrapper (blocking · lane-lock advisory · fail-stop · resume · state.json)
- `scripts/_test/mock_runner.ps1` + `scripts/_test/test_run_batch.ps1` — fixtures + test driver (ไม่แตะ MT5 จริง)
- `docs/memory_control/RUNNER_INVENTORY.md` — เฟส 1 inventory ครบ 8 runner

**Opus-verified acceptance (รันเอง 5/5 PASS):**
- [x] mock success → exit 0 + ทุก job `done`
- [x] mid-job fail → job ถัดไปไม่รัน + exit 1 + job=`failed` (marker ที่ 3 หายจริง)
- [x] interrupt→resume → รันเฉพาะ not-done · job `done` marker frozen (idempotent)
- [x] lane collision → 2 job lane เดียวกันไม่ overlap (timestamp พิสูจน์) + lock created/removed
- [x] no-kill scan: 0 `Stop-Process`/`taskkill`/process-`-Force` (hit ทั้งหมด = comment หรือ file/dir op)
- [x] runner เดิม 4 ไฟล์ **byte-unchanged** (`git status --porcelain` ว่าง)
- [x] inventory ≥8 runner

**Design note (Opus):** invoke runner เดิมด้วย `& powershell -File $runner @args` + เช็ค `$LASTEXITCODE` · lane-lock ใช้ `[System.IO.File]::Open(CreateNew)` (atomic exclusive-create, ไม่มี process primitive) release ด้วย try/finally · state เขียนทุก transition = interrupt-safe · Model-4 → pre-flight guard บังคับ lane-1/serial ก่อนรัน job แรก.

**Known limitation (ยกไป iteration หน้า, ไม่ block MVP-0):** run ที่ crash ทิ้ง stale lane-lock ไว้ → resume จะ block 300s แล้ว fail-visible (ไม่เงียบ ไม่ kill). stale-lane detection = delegated item §20.5 — ทำเป็น order แยกทีหลัง.

**Status:** DONE + Opus self-review = **ACCEPT**. **ค้าง external review** (เหมือน ORDER-099) ก่อน flip `REVIEWED`.

⏸️ **STOP-POINT ก่อน system order 3 (Contract C):** Contract C = active/archive migration = แก้ **architectural write path** → §20/handoff บังคับ (ก) **maintenance window ที่ไม่มี taskboard writer** — ตอนนี้มี concurrent session เขียนอยู่ (ดู memory `shared-worktree-concurrent-writers`) = **ยังไม่ปลอดภัย** · (ข) **blind Codex review ก่อน accept**. → ไม่เขียน Contract C ต่อจนกว่า user เคาะ window + review ORDER-099/100.

### Codex blind review (ORDER-100) 2026-07-12 = REWORK — Opus verify: ยอมรับทุกข้อ (self-ACCEPT ผิด)
Official tests ยัง 5/5 PASS แต่ mock ปิด case จริงไม่หมด. ต้องแก้ก่อนใช้รัน MT4/MT5 จริง:
- **BLOCKER-1 false-green:** wrapper ตัดสินจาก `$LASTEXITCODE` อย่างเดียว (L209). **Opus verify:** `mt5_run.ps1` exit 1 ตอน NO REPORT (ok) **แต่ `mt4_run.ps1` ไม่มี `exit` บน path report → falls through = exit 0 แม้ NO REPORT** (L109-130) → false green จริงกับ mt4/optimizer/batch. **FIX:** success-detection ต้องเช็ค **artifact จริง (report/xml ถูกสร้าง)** หรือ parse `OK REPORT`/`NO REPORT` marker ต่อ-runner ไม่ใช่ exit code ล้วน
- **BLOCKER-2 lane-lock ไม่ global:** lock อยู่ใต้ `$StateDir` (L89-93) → 2 batch คนละ StateDir แต่ physical lane เดียว = lock คนละไฟล์ = ไม่กันชนจริง (Codex รัน 2 wrapper overlap ได้). **FIX:** lane-lock ไปที่ **fixed global dir keyed by physical lane/terminal** ไม่ใช่ StateDir
- **FIX-3 lane-collision test อ่อน:** test (L169) ใส่ 2 job ใน process เดียว = sequential อยู่แล้ว ถอด lock ออกก็ผ่าน → ต้อง test **2 process พร้อมกัน** lane เดียว assert no-overlap
- **FIX-4 Model-4 guard เชื่อ label:** (L81) รับ lane ลงท้าย `-1` แต่ manifest ใส่ `-Terminal Meta 5b` ได้ → ไม่ผูก physical lane 1 จริง. **FIX:** parse `-Terminal` จาก args เทียบ lane-1 install จริง
- **FIX-5 state write ไม่ atomic:** `Set-Content` ตรง (L73) → crash กลาง write = JSON ขาด resume ไม่ได้. **FIX:** write temp + atomic move
- **FIX-6 manifest dup-ID ไม่ validate:** unique ID ใน contract (L21) แต่ lookup first-match (L195) → dup = รัน runner ผิด. **FIX:** validate unique ID, abort ถ้าซ้ำ
- Codex PASS: no-kill/-Force safety · runner เดิม byte-unchanged · stale-lock 300s ยอมรับได้ (แต่ต้อง global scope ก่อน = ผูกกับ BLOCKER-2)

**Rebuild spec = 6 ข้อบน · commit แยก · re-test + re-review ก่อน accept · ห้าม flip REVIEWED จน 2 blocker ปิด. รอ user เคาะเริ่ม rebuild (routing เดิม: Codex-direct/subagent build → Opus verify).**
