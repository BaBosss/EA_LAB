# TASKBOARD_DIGEST — ทุก order บรรทัดเดียว

> **GENERATED — read-only — ห้ามแก้มือ.** สร้างโดย `scripts/make_taskboard_digest.ps1`
> จาก `AGENT_TASKBOARD.md` + `ARCHIVE_TASKBOARD_2026-07A.md` · `-Check` = เช็คว่า stale ไหม (read-only)
>
> ไฟล์นี้คือ**ชั้นที่มนุษย์อ่าน** — อยากได้รายละเอียดค่อยเปิดบอร์ดตามคอลัมน์ `อยู่ที่`.
> (`docs/memory_control/ARCHIVE_INDEX.md` ชื่อคล้ายกันแต่คนละงาน — นั่นคือตาราง sha256 ของ validator)
>
> **`อยู่ที่` = ACTIVE** → ยังอยู่บน `AGENT_TASKBOARD.md` (ยังไม่ปิด หรือปิดแล้วแต่ยังไม่ได้ย้าย)
> **`อยู่ที่` = ARCHIVE** → เนื้อเต็มอยู่ใน `ARCHIVE_TASKBOARD_2026-07A.md`

- order ทั้งหมด: **263** · ยังอยู่บนบอร์ด: **43** · เข้าคลังแล้ว: **220**

| order | ปิดเมื่อ | สถานะ | เรื่อง | ผลลัพธ์ | อยู่ที่ |
|---|---|---|---|---|---|
| ORDER-001 | 2026-07-04 | REVIEWED | GBPAUD: re-optimize บน IS window (กัน in-sample bias) |  | ARCHIVE:8 |
| ORDER-002 | 2026-07-04 | REVIEWED | probe 3 symbol ที่ยังไม่เคย probe: AUDNZD / GBPJPY / NZDJPY |  | ARCHIVE:55 |
| ORDER-003 |  | SKIPPED | Monte Carlo บน GBPAUD p26 report |  | ARCHIVE:129 |
| ORDER-004 | 2026-07-04 | REVIEWED | GBPAUD p26: OOS-confirm (2025.07-2026.07) + MC |  | ARCHIVE:99 |
| ORDER-005 | 2026-07-04 | REVIEWED | IS-optimize 5 candidates: AUDNZD / GBPJPY / EURJPY / EURCAD / USDJPY |  | ARCHIVE:143 |
| ORDER-006 | 2026-07-04 | REVIEWED | fresh-start OOS ของ 5 ตัวจาก ORDER-005 (rule-based, ทำต่อจาก 005 ได้เลย) |  | ARCHIVE:206 |
| ORDER-007 | 2026-07-04 | REVIEWED | probe Boss_14 อีก 7 symbol ที่ค้างทะเบียน (กฎ: ห้ามตายก่อน optimize) |  | ARCHIVE:239 |
| ORDER-008 | 2026-07-04 | REVIEWED | Re-exam ศพเก่าที่ตายโดยไม่เคย optimize: EA_LNBREAK + NRBreakout (stage A: เตรียมข้อมูล) |  | ARCHIVE:283 |
| ORDER-008B |  | REVIEWED | probe ศพเก่า | ❌ LNBREAK = DEAD-optimized ของจริง (0/81, best 1.048) — กฎ re-exam ครบวงจร: การฆ่าเดิมถูก validate แล้ว ปิดถา… | ARCHIVE:419 |
| ORDER-009 |  | SKIPPED | MC บน OOS reports 5 ตัว |  | ARCHIVE:375 |
| ORDER-010 | 2026-07-04 | REVIEWED | full-window confirm + year-split ของ 3 ตัวที่ผ่าน OOS |  | ARCHIVE:386 |
| ORDER-011 |  | REVIEWED | A/B harness | ✅ harness ACCEPTED ใช้งานได้จริง (+รองรับ -Portable) · ข้อมูล A/B แรก: Rec81 บน Boss_11 base ขาดทุน → net ดีข… | ARCHIVE:476 |
| ORDER-012 |  | REVIEWED | อ่าน EA source ~98 ไฟล์ → ตาราง triage | งานครบ 88/88 ✅ แต่เกณฑ์ Y หลวม (61/88 รวม grid เพียบ) — Claude จะคัดจริงจาก momentum 13 + breakout 7 ก่อน; no… | ARCHIVE:541 |
| ORDER-013 |  | REVIEWED | PDF skim 289 ไฟล์ → catalog | catalog ครบ 188/188 ✅ · strategy-book 49 + worth_deep_read 67 — คัดจริง session หน้า ไม่เร่ง) | ARCHIVE:572 |
| ORDER-014 |  | REVIEWED | Model-4 (real ticks) confirm ของ DEMO cohort 3 ตัว | DEMO ยืนทั้ง 3 บน real ticks ✅ — USDJPY 1.72/107t · AUDNZD 3.37/44t (แชมป์อีกรอบ) · ⚠️ EURJPY 1.51/110t eqDD… | ARCHIVE:2080 |
| ORDER-015 |  | REVIEWED | pipeline batch #2 | 🥇 AUDCAD OOS 4.30/41t = CANDIDATE เด่น (AUD family อีกแล้ว!) · CADJPY 1.98/26t = CANDIDATE-thin · USDCAD 2.0… | ARCHIVE:656 |
| ORDER-016 | 2026-07-04 | REVIEWED | cohort-2 pipeline: full-confirm + year-split + MC ของ 5 ตัวจาก batch #2 (+NRBreakout OOS) | cohort-2 verdict — DEMO 3 ตัว: 🥇 AUDCAD (ทุกปี≥1.01, OOS 4.30, MC clean) · CADJPY-thin (2026 = -\.60 บน 13t… | ARCHIVE:709 |
| ORDER-017 | 2026-07-06 | REVIEWED | Model-4 confirm cohort-2 (3 ตัว) + สร้าง DEMO sets | ผลถูก review+ใช้จริงตั้งแต่ 07-04 (cohort-2 เข้า DEMO bench, verdict อยู่ PROJECT_STATE HANDOFF 07-04 + DEMO_… | ARCHIVE:804 |
| ORDER-018 |  | REVIEWED | เติม EA_MASTER_INDEX.csv | ✅ 125 แถว 0 ซ้ำ — UNTESTED 88 · DEAD 17 · PARKED 7 · DEMO 6 · WATCH 4 · REJECT 3 — index สมบูรณ์ ขึ้น OneDriv… | ARCHIVE:836 |
| ORDER-019 | 2026-07-04 | REVIEWED | corr matrix ของ Boss_14 family (6 ตัว demo) |  | ARCHIVE:893 |
| ORDER-020 | 2026-07-04 | REVIEWED | ขุด SELL-side จาก optimizer XML ที่มีอยู่ (hunt queue #1, ฟรี — ไม่รันอะไรใหม่) |  | ARCHIVE:941 |
| ORDER-021 | 2026-07-04 | REVIEWED | สรุป 20 treasure sources (momentum 13 + breakout 7) ให้ Claude อ่าน |  | ARCHIVE:1063 |
| ORDER-022 | 2026-07-04 | REVIEWED | Plateau-sensitivity test ของ 6 DEMO configs (ปิดจุดอ่อน optimize จาก self-review) |  | ARCHIVE:1092 |
| ORDER-023 | 2026-07-04 | REVIEWED | NZDUSD-SELL: fresh-start OOS ของ pass 29 (จาก ORDER-020 hunt) |  | ARCHIVE:1010 |
| ORDER-024 | 2026-07-05 | REVIEWED | Recovery-mode A/B บน config ที่ชนะ (AUDNZD champion) |  | ARCHIVE:1157 |
| ORDER-025 | 2026-07-05 | REVIEWED | Adaptive Recovery (mode 82): ตรวจ floating DD จริง + generalize ข้าม symbol |  | ARCHIVE:1229 |
| ORDER-026 | 2026-07-05 | REVIEWED | HedgeMode (HEDGE_LOCK) A/B บน AUDNZD |  | ARCHIVE:1320 |
| ORDER-027 | 2026-07-05 | REVIEWED | mold upgrade: `_2_BasketTP_ATRmult` (basket TP แบบ ATR-scaled, additive) |  | ARCHIVE:1344 |
| ORDER-028 | 2026-07-05 | REVIEWED | XAU GridLog: IS-optimize (axis tuning สำหรับทอง) |  | ARCHIVE:1400 |
| ORDER-029 | 2026-07-05 | REVIEWED | mold fix: `_33_SL_MaxPips` ให้ portable ข้าม instrument (bug จาก ORDER-027 scan) |  | ARCHIVE:1448 |
| ORDER-029B | 2026-07-05 | REVIEWED | implement Option B: `_33_SL_MaxATRmult` (ATR-relative SL cap, additive) |  | ARCHIVE:1604 |
| ORDER-030 | 2026-07-05 | REVIEWED | XAU: fresh-start OOS + full-window + year-split |  | ARCHIVE:1489 |
| ORDER-031 | 2026-07-05 | REVIEWED | XAU: Monte Carlo + Model-4 every-tick (ทอง+grid บังคับ) |  | ARCHIVE:1528 |
| ORDER-032 | 2026-07-05 | REVIEWED | XAG (silver) GridLog: IS-optimize (non-FX ตัวที่ 2, ขนาน XAU) |  | ARCHIVE:1570 |
| ORDER-033 | 2026-07-05 | REVIEWED | smoke-screen 4 MT5 signal EAs จาก `wait for test` (idle-compute filter) |  | ARCHIVE:1626 |
| ORDER-034 | 2026-07-05 | REVIEWED | catalog + dedup + กรอง tradeable-EA จาก `wait for test` | 1,521 candidates → 035/036 unblocked) | ARCHIVE:1678 |
| ORDER-035 | 2026-07-05 | REVIEWED | MT5 mass-smoke driver (loop worklist ex5) |  | ARCHIVE:1701 |
| ORDER-035-REVIEW |  |  | note (Claude/Opus 2026-07-05): 39 survivor — ส่วนใหญ่กับดักคุ้นเคย, คัด 3 ตัวเข้า ORDER-0… |  | ARCHIVE:1768 |
| ORDER-036 | 2026-07-26 | CLOSED | MT4 mass-smoke (1,318 ex4) | _archive_docs/ORDER-036_MT4_MASS_SMOKE.md + REVIEWED(Claude/Opus 2026-07-26) | ARCHIVE:7482 |
| ORDER-037 | 2026-07-06 | REVIEWED | artifact-check top survivors จาก mass-smoke | pun fix lot REJECT (eqDD 83% ปี 2022) · GapinFX REJECT (balDD 112% ปี 2022!) · North East Way DQ (cracked "_f… | ARCHIVE:1777 |
| ORDER-038 | 2026-07-06 | REVIEWED | pun fix lot v05: backward-OOS 2020-2022 | eqDD 83% ปี 2022, no-SL harvester ตายตามทฤษฎีเป๊ะ) | ARCHIVE:1825 |
| ORDER-039 | 2026-07-06 | REVIEWED | Scalping-EA-AsReMix: Model-4 + MC |  | ARCHIVE:1856 |
| ORDER-040 | 2026-07-06 | REVIEWED | BWD-OOS sweep ของ 036 batch-01 Tier A |  | ARCHIVE:1888 |
| ORDER-041 | 2026-07-06 | REVIEWED | ClevrFX + Fxcore100_SELL: spread-stress + SL/lock check |  | ARCHIVE:1922 |
| ORDER-042 | 2026-07-06 | REVIEWED | DealsExporter: nightly deals snapshot สำหรับ /ea-monitor |  | ARCHIVE:2125 |
| ORDER-043 | 2026-07-09 | REVIEWED/CLOSED | US30 GridLog: IS-optimize probe (optional, EV ต่ำ) |  | ARCHIVE:2033 |
| ORDER-044 | 2026-07-07 | REVIEWED | EURUSD Trading Forex Robot: full chain re-test | BWD 2020-22 PF 0.39 / -$5,840) | ARCHIVE:2054 |
| ORDER-045 |  | WAITING-USER | MT4 demo experiment #2: UnNomGuai + RSI from pips (คู่, บัญชีใหม่) |  | ACTIVE:1127 |
| ORDER-046 | 2026-07-07 | REVIEWED/CLOSED | Revival probes: กฎ "ห้าม DEAD ก่อนลอง optimize" กับ ORDER-036 dead pool |  | ARCHIVE:1998 |
| ORDER-047 | 2026-07-07 | REVIEWED/CLOSED | RSI from pips_EA: symbol/TF breadth → BWD confirm → optimize (user สั่ง 2026-07-07: "ตัวน… |  | ARCHIVE:1960 |
| ORDER-055 | 2026-07-09 |  | [NEXT SESSION START HERE] demo cohort 8 ตัว: attach + monitor | user attach exporter ×5 บน VPS + เลือกท่อ CSV (OneDrive บน VPS หรือ RDP-copy รายสัปดาห์) + จับตา Boss-TrendSw… | ACTIVE:1143 |
| ORDER-057 | 2026-07-09 | CLOSED | mold upgrade: `Regime.mqh` (market-state filter, additive) |  | ARCHIVE:5707 |
| ORDER-058 | 2026-07-09 | REVIEWED | live-monitor dashboard: ตาราง per-EA แบบเข้าใจใน 5 วิ (ต่อยอด DealsExporter) | ระดับ 🟡 ต้องใช้เตือนที่ README ประกาศ (MT4 25%/MT5 15%) ไม่ใช่สูตร 80% ล้วน · verify: synthetic CSV ผ่าน (br… | ARCHIVE:2150 |
| ORDER-059 | 2026-07-09 | REVIEWED/CLOSED | COT regime filter สำหรับ EA ทอง: exploratory ผ่าน → ต้อง validate เต็ม |  | ARCHIVE:2169 |
| ORDER-060 | 2026-07-09 | DONE+REVIEWED | MT4 OrdersExporter + ท่อ monitoring MT4 ครบวงจร |  | ARCHIVE:2185 |
| ORDER-061 | 2026-07-09 | REVIEWED/CLOSED | hunt ใหม่: (BRK)_FlagPennant @ XAUUSD H1 (กลไก next-EV จาก handoff) |  | ARCHIVE:2201 |
| ORDER-062 | 2026-07-09 | REVIEWED/CLOSED | regime-axis re-funnel ทั้ง Boss_14 family | USDJPY · 1 borderline: EURJPY · 6 ไม่เอา) | ARCHIVE:2217 |
| ORDER-063 | 2026-07-09 | REVIEWED/CLOSED | smoke เทส EA จาก Downloads 3 ตัว | GOD4+HedgingGrid untestable-locked · Degold REJECT ที่ martingale-recheck) | ARCHIVE:2285 |
| ORDER-064 | 2026-07-26 | CLOSED | ขุดไอเดียจาก Open WebUI export 93MB (คุยกับ OpenAI ของบริษัท) | ORDER-065 SuperTrendFlip = RESERVE · ORDER-066 VWAP WaveS1 = NO EDGE, ทั้งคู่ปิดแล้วใน archive) + REVIEWED(Cl… | ARCHIVE:7525 |
| ORDER-065 | 2026-07-09 | BUILT+FUNNELED | build: (TRD)_SuperTrendFlip @ XAUUSD H1 | ผ่าน 3 windows แต่ MC PF-5th 0.865 <1 = naked-signal floor เดิม) | ARCHIVE:2324 |
| ORDER-066 | 2026-07-09 | BUILT+FUNNELED | build: (VWAP)_WaveS1 distilled @ XAUUSD |  | ARCHIVE:2347 |
| ORDER-067 | 2026-07-09 | BUILT+CLOSED | Trendline rev02 + ADX-regime gate: เส้นทาง promote #8 ที่ COT ทำไม่ได้ | artifact class ใหม่เข้าตำรา) | ARCHIVE:2257 |
| ORDER-068 | 2026-07-10 | DONE | ST03 family: flat-lot probe ของ config แล็บ (9397 GBP / 9398 CAD) |  | ARCHIVE:2415 |
| ORDER-069 | 2026-07-10 | DONE | (Boss)_ZeusInspired_GridLog_rev01 บน EURUSD: coarse optimize |  | ARCHIVE:2453 |
| ORDER-070 | 2026-07-10 | DONE | Gold_Kangaroo: แกะ logic + หาข้อมูลเน็ต → spec "KangarooInspired" เข้าแม่พิมพ์ Boss V2 |  | ARCHIVE:2503 |
| ORDER-071 | 2026-07-10 | STAGE2-DONE | rev02 — ST03 entry rescue แบบขั้นบันได (supersede rev01 ด้านบน — user เพิ่มแกน exit 2026-… |  | ARCHIVE:2576 |
| ORDER-071 |  | OPEN | ST03 entry rescue: HTF trend-gate A/B บน flat-lot |  | ARCHIVE:5065 |
| ORDER-072 | 2026-07-26 | DONE | build "(Boss)_Kangaroo" = Boss_16 บนแม่พิมพ์ V2 | core\entries\Kangaroo.mqh (ไม่ใช่ core\) · ea_template\tests\run_tests.ps1 (ไม่ใช่ tests\) + REVIEWED(Claude/… | ARCHIVE:7558 |
| ORDER-073 |  | DONE | News-aware risk system (user directive 2026-07-10) — Phase 1 |  | ACTIVE:1238 |
| ORDER-074 | 2026-07-10 | DONE | fxDreema X-ray: อ่าน EA คลังเรียนของ user แบบไม่เปลือง token |  | ARCHIVE:2675 |
| ORDER-075 | 2026-07-10 | DONE | Boss_16 entry sweep v1 (BUY-first) |  | ARCHIVE:2716 |
| ORDER-075/078 |  |  | NOTE เพิ่ม (user observation 2026-07-10 ค่ำ): Boss_16 entry v1 candidate = SPIKE-FADE |  | ARCHIVE:3036 |
| ORDER-076 | 2026-07-26 | CLOSED | smoke-screen หัวกะทิ 41 ตัวจาก X-ray | 11 REJECT/PARK + 1 build-on-needs-data ((ICE) CCI = PARKED, basket 9-major ไม่รอด) · verdict = _triage/_archi… | ARCHIVE:7642 |
| ORDER-077 | 2026-07-10 | DONE | Boss_16 BUY: BWD-OOS 2020-2022 probe (กฎ both-regimes ก่อนทุ่มต่อ) |  | ARCHIVE:2807 |
| ORDER-078 | 2026-07-11 | DONE | Boss_16 BUY 21/30: validation funnel เต็ม |  | ARCHIVE:2843 |
| ORDER-079 | 2026-07-26 | DONE | Idea mining คลังคอร์ส: concept catalog (reframe จาก user 2026-07-10) |  | ARCHIVE:7655 |
| ORDER-080 | 2026-07-26 | CLOSED | วัดมูลค่า "limit-entry แทน market" บน EA เรา (แรงบันดาลใจ: บอท maker-only ของโพสต์ FB) | ตอบผ่าน ORDER-108 + 091C-D1d ไม่ต้อง build Boss_16 ซ้ำ + REVIEWED(Claude/Opus 2026-07-26) | ARCHIVE:7682 |
| ORDER-080-orig |  |  | (spec เดิม — superseded) |  | ACTIVE:1295 |
| ORDER-081 | 2026-07-11 | DONE | Crypto lane feasibility study (maker-fee scalper blueprint) |  | ARCHIVE:3006 |
| ORDER-082 | 2026-07-14 | CLOSED | Entry_Wave5: สัญญาณ Elliott ขา 5 ตาม rule ที่ user ถ่ายทอดเอง (2026-07-10) |  | ACTIVE:1307 |
| ORDER-082 |  |  | AMENDMENT (user ยืนยัน 2026-07-10 ค่ำ) |  | ACTIVE:1335 |
| ORDER-083 | 2026-07-10 | DONE | build "(Boss)_NewsGuard" watchdog EA (user เคาะ policy ครบ 2026-07-10) |  | ARCHIVE:3043 |
| ORDER-083B | 2026-07-11 | DONE | port NewsGuard เป็น MQL4 (คุมกอง no-SL บน MT4 141049900) |  | ARCHIVE:3871 |
| ORDER-083C | 2026-07-11 | DONE | P0-before-attach: NewsGuard hardening (MT5+MT4) + VPS transport |  | ARCHIVE:4120 |
| ORDER-084 | 2026-07-26 | CLOSED | Retro-audit: ไล่ verdict DEAD/REJECT/PARKED ทั้งหมดกับกฎใหม่ (user: "ตายเปล่าเยอะ") | กอง ก ~95 ฆ่าถูกกติกา · กอง ข rescue queue 5 ตัวเรียง EV · กอง ค PARKED-VERIFY(user) 2 รายการ — rescue ยกเป็น… | ARCHIVE:7687 |
| ORDER-085 | 2026-07-10 | DONE | SuperTrend XAU H4: un-park ตาม corr rule |  | ARCHIVE:3154 |
| ORDER-085B | 2026-07-11 | DONE | SuperTrend XAU H4: อุดรูสองรูสุดท้าย |  | ARCHIVE:3531 |
| ORDER-086 | 2026-07-10 | DONE | swb grid AUDCAD: เตรียม bundle demo experiment #3 (user อนุมัติ 2026-07-10) |  | ARCHIVE:3220 |
| ORDER-087 | 2026-07-10 | DONE | concept rescue batch #1: 6 smokes บน symbol-class ที่ไม่เคยลอง |  | ARCHIVE:3239 |
| ORDER-088 | 2026-07-10 | DONE | Oracle EA: ปิดเงื่อนไขค้าง "อ่าน trade list" |  | ARCHIVE:3271 |
| ORDER-089 | 2026-07-10 | DONE | EA_ZSCORE × AUDCAD: rescue-ladder เต็มตามสูตร (ตัวแรกที่ใช้กฎใหม่ครบวงจร) |  | ARCHIVE:3324 |
| ORDER-090 | 2026-07-10 | DONE-STOPPED-AT-STAGE-2 | ZSCORE AUDCAD H4: funnel เต็ม (ด่านสุดท้ายก่อน bench) |  | ARCHIVE:3450 |
| ORDER-091 |  | OPEN | MASTER PLAN: intake คลัง Forex 9 โฟลเดอร์ของ user (แผนแม่บท — ลูก 091A-D จ่ายตาม pacing) |  | ACTIVE:1374 |
| ORDER-091B | 2026-07-11 | DONE-PHASE1 | BOT MOGUL report sweep (เฟส 1: parse+rank+shortlist) |  | ARCHIVE:3614 |
| ORDER-091B | 2026-07-11 | DONE | เฟส 2 — BWD spot-kill 5 ตัว "least-bad" ของ BOT MOGUL |  | ARCHIVE:3708 |
| ORDER-091C-D1 | 2026-07-11 | DONE | JUMSTOCH_FIXEDLOT full funnel |  | ARCHIVE:4360 |
| ORDER-091C-D1b | 2026-07-11 | DONE | JUMSTOCH spread stress (gate ก่อน demo) |  | ARCHIVE:4476 |
| ORDER-091C-D1c | 2026-07-11 | DONE | JUMSTOCH ขยาย symbol×TF เต็ม (user: "symbol มีอีกเป็น 10 ให้เทส ทุก TF") |  | ARCHIVE:4523 |
| ORDER-091C-D1d | 2026-07-16 | REVIEWED | JUMSTOCH pending-limit entry variant (= ORDER-080 vehicle, user idea) | TP-widen A/B + หา reversion base ที่ near-breakeven เป็น demonstrator | ACTIVE:1399 |
| ORDER-091C-D1e |  |  | JUMSTOCH MT5 port + smoke — DONE(Claude-agent, 2026-07-11) |  | ARCHIVE:4649 |
| ORDER-091C-D1f | 2026-07-11 | DONE | OOS validate JUMSTOCH MT5 ขาใหม่ (EURGBP/NZDUSD) |  | ARCHIVE:4934 |
| ORDER-091C-D1g | 2026-07-17 | DONE + REVIEWED | JUMSTOCH pending-limit + TP-widen A/B บน confirmed-edge base (closes ORDER-080 + user 202… |  | ACTIVE:1466 |
| ORDER-092 | 2026-07-11 | DONE | P0: Floating-risk telemetry (ตาบอด floating = รูใหญ่สุดของทั้งระบบ) |  | ARCHIVE:4017 |
| ORDER-093 | 2026-07-11 | DONE | P0: Deployment truth เดียว + ซ่อม PROJECT_STATE encoding |  | ARCHIVE:4106 |
| ORDER-094 | 2026-07-11 | DONE | P1: Cage hardening (ปิดทาง stale-pass ทั้ง 4 ตัว) |  | ARCHIVE:4165 |
| ORDER-095 | 2026-07-17 | CLOSED + REVIEWED | / #4 — Boss_14 GridLog EUR-cross symbol-expand | EURCHF+EURGBP both-window Model-4 coarse = NO home (MAIN spikes only, BWD dead ทุก cell) → PARKED ทั้งคู่ ไม่… | ACTIVE:1119 |
| ORDER-095 | 2026-07-14 | OPEN | CAMPAIGN: ขยาย symbol ให้ EA ที่ deploy อยู่แล้ว (user 2026-07-11: "ขยายผลไปตัวที่ demo อ… | EA_BREAKOUT_XAU → USDJPY (PF 1.28/1.25) + US30 (1.46/1.39 WATCH-thin) demo-eligible · bundles staged _vps_dep… | ACTIVE:1501 |
| ORDER-095-A | 2026-07-11 | DONE | Boss_14_GridLog ขยาย symbol (ตัวแรก, demo flagship) |  | ARCHIVE:4733 |
| ORDER-096A | 2026-07-11 | REVIEWED | Alligator+AO naked smoke (WOBR lead 2 ตัวสุดท้าย) |  | ARCHIVE:5000 |
| ORDER-096B | 2026-07-11 | REVIEWED | ปิดเซลล์ USDJPY IchiADX (PARKED→verdict) |  | ARCHIVE:5028 |
| ORDER-096C | 2026-07-11 | DONE | commit WOBR intake artifacts |  | ARCHIVE:5048 |
| ORDER-097 | 2026-07-11 | DONE | build "(HEX)_HexaGrid" (user สั่งเขียนจากสเปคเอง 2026-07-11) — build |  | ACTIVE:1521 |
| ORDER-098 |  | OPEN | CAMPAIGN: fxDreema YouTube corpus build-on |  | ACTIVE:1580 |
| ORDER-098-A | 2026-07-16 | CLOSED | FVG-fill entry (EX009 algo) flat-lot smoke | naked FVG-fill ไม่มี edge — 22 runs ครบ BWD both-regime (0.79-0.88) + RR sweep TP{15,20,25,30,40,60}: PF ไต่ถ… | ACTIVE:1600 |
| ORDER-098-B | 2026-07-16 | CLOSED | MACD-divergence entry (EX154/EX010 algo) flat-lot smoke | 🥇 XAU H4 ผ่านครบทุกด่าน funnel — MAIN plateau 1.91 (9 neighbor ไม่มีตัวขาดทุน) · BWD 1.04 · HOLDOUT 1.30 · M… | ACTIVE:1620 |
| ORDER-098-C | 2026-07-17 | DONE + REVIEWED | FVG-fill + RSI confluence gate (fxDreema course, #098 corpus) | REJECT. build FVGFill_RSIgate (naked 098-A chassis + RSI gate, mql-review PASS, compile 0/0). RSI threshold s… | ARCHIVE:7476 |
| ORDER-098-C | 2026-07-26 | DONE | reusable MM-parts library (dynamic close_money + Fibonacci-capped lot) |  | ARCHIVE:7806 |
| ORDER-098-D | 2026-07-17 | DONE + REVIEWED | Currency-strength meter EA (fxDreema CCI-Strength lineage, #098 corpus) | 🟡 PARAMETRIC-marginal → BUILD-ON candidate. naked CurrStrength_Naked (7-pair USD-basket momentum→chart-cross… | ARCHIVE:7478 |
| ORDER-098-E | 2026-07-17 | DONE + REVIEWED | Currency-strength BUILD-ON: strongest-vs-weakest ranking + filters (#098 corpus) | ranking ไม่ยก. CurrStrength_Ranked (multi-symbol scan 8-cross + exit enum FIXED/TRAIL/PARTIAL + capped pyrami… | ARCHIVE:5531 |
| ORDER-098-F | 2026-07-17 | DONE + REVIEWED | Pairs-spread stat-arb (Jobot arbitrage idea + SL cage, #098 corpus) | 🟢 PARAMETRIC CANDIDATE (session's strongest). PairSpread_StatArb — 2-leg hedged, spread=log(A)-log(B) z-scor… | ARCHIVE:7480 |
| ORDER-098-G | 2026-07-17 | DONE/REVIEWED | Validate stat-arb candidate H4 z2.5 EURUSD/GBPUSD (#098 corpus) |  | ARCHIVE:5543 |
| ORDER-098-J | 2026-07-17 | DONE/REVIEWED | Fibonacci-pullback concept (new build) |  | ARCHIVE:5548 |
| ORDER-098-K | 2026-07-17 | DONE/REVIEWED | stat-arb maker(pending-limit) build-on |  | ACTIVE:1121 |
| ORDER-098-L | 2026-07-17 | DONE/REVIEWED | SMC×STO add OB-zone gate (Stage-1) |  | ARCHIVE:5551 |
| ORDER-098-M | 2026-07-17 | DONE/REVIEWED | Harmonic geometry (AB=CD / Gartley) naked smoke |  | ARCHIVE:5556 |
| ORDER-099 | 2026-07-12 | REVIEWED | Contract A: B0 historical baseline + fact→owner map |  | ARCHIVE:5779 |
| ORDER-100 | 2026-07-12 | REVIEWED | Contract B: MVP-0 blocking execution harness (`run_batch.ps1`) |  | ARCHIVE:5854 |
| ORDER-101 | 2026-07-13 | REVIEWED | Contract C0: active/archive READ-ONLY reconcile + freeze (no block moves) |  | ARCHIVE:5976 |
| ORDER-102 | 2026-07-26 | CLOSED | Contract C1: migration window — resolve exceptions + replace manual index + freeze archiv… |  | ARCHIVE:7824 |
| ORDER-103 | 2026-07-14 | REVIEWED/ACCEPT | Contract C1-ENFORCE: append-CHAIN tamper integrity + fail-closed staged-snapshot hook (wr… |  | ARCHIVE:6070 |
| ORDER-104 |  |  | SSRN-151 W1/W2 probe: HP-denoise + tanh + IBS — `STAGE A+B DONE + REVIEWED(Claude 2026-07… |  | ARCHIVE:5566 |
| ORDER-105 | 2026-07-17 | REVIEWED/ACCEPT | Contract D: MVP-1-lite Experiment Event Log (locked JSONL append utility + linked-event s… |  | ARCHIVE:6242 |
| ORDER-106 | 2026-07-16 | GBPJPY DONE + REVIEWED | rescue #1 จากคิว ORDER-084: Boss_14_GridLog second-symbol pool | ✅ RESCUE สำเร็จ ไม่ตาย — H4 @ dist2.0 plateau both-window + Model-4 CONFIRM (MAIN 1.56/BWD 1.11 ดีขึ้น/HOLDOU… | ARCHIVE:7495 |
| ORDER-107 | 2026-07-16 | CORRECTED + REVIEWED | SMC×STO signal Stage-0 cheap smoke (user idea 2026-07-16) | 🟩 BUILD-ON candidate ไม่ตาย (user จับถูก — default-smoke ผมรีบตัดสินผิด gate) · optimize จริง 180 passes/sym… | ARCHIVE:7509 |
| ORDER-108 | 2026-07-16 | DONE + REVIEWED | break-and-retest split-entry (market + pending-limit) บน breakout winner (user idea 2026-… | 🟩 BUILD-ON SUCCESS — build (EXP)_BRK_SplitRetest + A/B Model-4 XAU H1 · retest fill-rate ~90% · adverse-sele… | ACTIVE:1178 |
| ORDER-109 |  | MAGIC | regime-rescue #1: graft `_50_ Regime.mqh` เข้า Zeus chassis + sweep AUDJPY/AUDUSD both-wi… | 1.5=best MAIN 1.35/BWD 1.20 DD↓, 2023 ยัง -900 structural) · locked .set verified reproduces 1.35 · ⚠️README… | ARCHIVE:5645 |
| ORDER-110 | 2026-07-16 | DONE + REVIEWED | regime-rescue #2: rebuild XAU_NY (NY-session breakout) บน LabCore chassis (มี `_50_` leve… | 🟡 regime gate ไม่กู้ XAU_NY — rebuild = pure config บน Boss_12_Breakout (Entry-12 Donchian + session filter… | ARCHIVE:5672 |
| ORDER-111 | 2026-07-16 | DONE + REVIEWED | re-audit open-price-killed pile + source-catalog build-material (user เคาะ 2026-07-16) | Part A 6-marginal recheck = **ไม่มี wrongly-parked** (every-tick แย่ลงทั้ง 6, PF ตกทุกตัว, 2 ตัวโผล่ DD~99% ท… | ARCHIVE:5679 |
| ORDER-112E | 2026-07-26 | DONE | corr check: Ichimoku-XAU additive หรือ redundant? | 990069 ไม่ใช่ "reserved" แล้ว — attach + ACTIVE บน 463666728 + REVIEWED(Claude/Opus 2026-07-26) | ARCHIVE:7799 |
| ORDER-115 | 2026-07-17 | DONE + REVIEWED | B1 observation cohort START + event-log adoption guide (§20.2 step 6 @ `4eb839d`) |  | ARCHIVE:6282 |
| ORDER-116 | 2026-07-18 | CORE DONE | CAMPAIGN: split-entry breakout — รีด lever (ORDER-108 validated) ให้ครบ portfolio (user 2… |  | ACTIVE:1444 |
| ORDER-117 | 2026-07-18 | CORE DONE | CAMPAIGN: รีด EA ที่ validated แล้ว — coverage (symbol×TF) + precision-filter (user 2026-… |  | ACTIVE:1423 |
| ORDER-118 | 2026-07-26 | CLOSED-OBSOLETE | ST03 real-money CutLoss guardrail | user ถอดตระกูล ST03 ออกจากบัญชีจริง 159475669 ทั้ง 3 ตัว (9398/939721/990010 — DEPLOYMENTS.csv = REMOVED, ยืน… | ARCHIVE:7415 |
| ORDER-119 | 2026-07-19 | REVIEWED | CAMPAIGN: ST03 rescue รอบ owner-override — 3 lever ที่ยังไม่เคยแตะ (flat-lot bar ตัดสิน) | DEAD-OPTIMIZED (flat-lot MACD-reversion entry, ranger homes) — campaign ปิด, lever A/B ไม่เดิน | ACTIVE:1093 |
| ORDER-120 | 2026-07-26 | DONE | implement framework Part 4: rewrite CLAUDE.md VERDICT GATE เป็น tree + bar table | CLAUDE.md gate = decision tree (STRUCTURAL→PARAMETRIC→DEAD-OPTIMIZED/BUILD-ON/PARKED-VERIFY/CANDIDATE) + bar… | ARCHIVE:7434 |
| ORDER-121 | 2026-07-26 | DONE | implement framework Part 3: rewrite skill backtest-optimize-rigor เป็น ladder 0-9 | skill = THE OPTIMIZE LADDER Step 0-9 (windows pin MAIN rolling-36/BWD 2020-22/HOLDOUT 2026H1 · Model-4-mandat… | ARCHIVE:7444 |
| ORDER-122 | 2026-07-26 | DONE | implement framework Part 2+5: สร้าง docs/PIPELINE.md + sync FINAL RULE 9 skills + AGENTS… | docs/PIPELINE.md สร้างแล้ว (flow owner + routing table 10 boundary + skill roster). FINAL RULE sync 9 skills:… | ARCHIVE:7454 |
| ORDER-123 | 2026-07-26 | DONE | order template: เพิ่ม field บังคับ 2 ช่อง (pre-registered bars · flat-lot probe) | เพิ่ม ORDER TEMPLATE block ใน header taskboard (ใต้กติกาสถานะ) — order ทดสอบทุกใบตั้งแต่ 124+ ต้องมี bars: (p… | ARCHIVE:7467 |
| ORDER-124 | 2026-07-19 | DONE+REVIEWED | chassis chores ×3 ตาม framework Part 1 (additive, cage) | (1) Kangaroo.mqh → core/entries/ + include fix 3 จุด (2) _MG_* ×7 → Inputs.mqh ชื่อไม่เปลี่ยน (.set เดิมโหลดไ… | ARCHIVE:5456 |
| ORDER-125 | 2026-07-19 | DONE+REVIEWED | chassis lever: vertical-barrier exit (max-holding-bars force-close) | lever BUILT+Codex-hardened (default OFF byte-identical) · A/B host Boss_14 GBPJPY H4 = NO LIFT, DEAD-ON-GRID… | ARCHIVE:5466 |
| ORDER-126 | 2026-07-19 | DONE+REVIEWED | SMCxSTO 991070 SL-rescue: ATR-adaptive SL + round-number offset | NO LIFT → keep 991070 as-is. Built _09_RoundAvoidPips lever on (EXP)_EmaStoRev (default OFF byte-identical, m… | ARCHIVE:5470 |
| ORDER-127 | 2026-07-18 | REVIEWED | CAMPAIGN: RSI-as-MOMENTUM family + filter overlays (user request 2026-07-18) | naked-momentum branch = DEAD-OPTIMIZED (concept). Built (EXP)_RsiMomentum_Naked (3 modes A/B/C + EMA/MACD/BB… | ARCHIVE:5474 |
| ORDER-128 | 2026-07-26 | CLOSED | 🔴 P0: monitoring chain repair (task refused + false-green gist) | gh re-auth สำเร็จ (BaBosss keyring, scope gist/repo) + gist 287cce51 update จริง 2026-07-19 20:31 = E2E ผ่านแ… | ARCHIVE:7472 |
| ORDER-129 | 2026-07-18 | DONE + REVIEWED | template SEV-1 pack + regression-cage rebuild (Codex system review) |  | ARCHIVE:5498 |
| ORDER-130 | 2026-07-18 | DONE + REVIEWED | process-drift batch: window pin · scorecard rubric freeze · index sync · stale tables |  | ARCHIVE:5514 |
| ORDER-131 | 2026-07-19 | DONE + REVIEWED | isolate Boss_18 cage drift to exact line (residual จาก ORDER-129) | BENIGN = code-layout FP boundary sensitivity, ไม่ใช่ logic bug | ARCHIVE:5510 |
| ORDER-132 | 2026-07-19 | DONE + REVIEWED | transactional exits + persist scoping (defer pack จาก Codex ORDER-129 audit) |  | ARCHIVE:5504 |
| ORDER-135 | 2026-07-19 | REVIEWED | ST03 lever A: capped-basket ENGINE-EDGE test (กฎใหม่ 2026-07-19) | DEAD (engine ก็กู้ไม่ขึ้น) — ST03 ตระกูลปิดถาวร earned | ARCHIVE:5481 |
| ORDER-136 | 2026-07-24 | WAVE1 CLOSED | CAMPAIGN: escalation-MM overlay บน validated PF>1 cohort (user directive 2026-07-19 "เทสใ… |  | ARCHIVE:7015 |
| ORDER-137 | 2026-07-19 | DONE + REVIEWED | (EXP)_StoMultiTap: multi-tap S/R + Stoch cycle fade (Miissterkiiss/Bitnefit school) | PARKED-VERIFY(user) | ARCHIVE:5517 |
| ORDER-138 | 2026-07-19 | DONE + REVIEWED | template SEV-1 pack #2 (Codex roadmap 2026-07-19): persist/kill transactional hardening | #1-4 + 138b + 138c ครบ, Codex audit 2 รอบครบ loop → live-rollout blocker ปลด (ฝั่ง code); user ยังต้องเดิน PE… | ARCHIVE:5487 |
| ORDER-139 | 2026-07-20 | DONE + REVIEWED | Wave-2 XAU optimize ladders: S1 TrendRider H4 + SS4 SweepReversal M15 | S1 = VALIDATED CANDIDATE → DEMO-ready 992004 (plateau 6-cell a20×s{.3,.5}×c{2..3}; center a20/s0.5/c2.5 MAIN… | ARCHIVE:7388 |
| ORDER-140 | 2026-07-20 | DONE + REVIEWED | SS1 LondonORB BUILD-ON: symbol×TF expansion | ไม่มี home ใหม่ผ่าน bar — GBP 0.79 MAIN / EUR 0.88-0.89 ตาย · USDJPY M15 1.14/1.10 + XAU M30 1.13/1.08 @n~700… | ARCHIVE:5448 |
| ORDER-141 | 2026-07-20 | DONE | (EXP)_AdaptGridMC_rev01 build (FINDYOUR8 #1 MC block-bootstrap zone grid) | spec→code→compile+tests พอ) | ACTIVE:1086 |
| ORDER-142 | 2026-07-23 | REVIEWED | AdaptGridMC backtest campaign (ต่อจาก 141 build) | NOT a validated candidate — MAIN PF is a realized-path artifact, structural flaw found | ARCHIVE:5434 |
| ORDER-143 | 2026-07-26 | DONE | SS1 LondonORB lever ค้าง: partial-TP + trend-filter sweep | input _07_UseTrendFilter/_07_TrendEmaPeriod=200 + _07_PartialPct/_07_PartialAtR ถูกเพิ่มเข้า EA จริง · sweep… | ARCHIVE:7376 |
| ORDER-144 | 2026-07-26 | DONE | [codex] pre-commit staged-bytes validation (roadmap finding #12, ops-debt) |  | ARCHIVE:7380 |
| ORDER-145 | 2026-07-26 | DONE | [codex] blind audit: (EXP)_AdaptGridMC_rev01 (money-adjacent: hard-kill −20% persisted GV) |  | ARCHIVE:7384 |
| ORDER-146 | 2026-07-23 | REVIEWED | EmaStoRev (SMCxSTO) NEW-HOME sweep | DEAD-OPTIMIZED (new-home expansion) — 0/8 cells cleared ≥1.0 both-window on EURGBP/AUDNZD/EURCHF/USDCHF H1/H4… | ARCHIVE:5426 |
| ORDER-147 | 2026-07-23 | REVIEWED + HOLDOUT DONE | S1 TrendRider XAU (992004 CANDIDATE) symbol expansion | 2/3 ตาย · XAGUSD H4 = BUILD-ON (holdout ผ่านแต่ BWD ตกบน pinned config) | ARCHIVE:7350 |
| ORDER-148 | 2026-07-23 | REVIEWED | Boss_17 Wave5 symbol expansion (JPY crosses) | DEAD-OPTIMIZED (new-home expansion) — 0/8 cells cleared MAIN≥1.1 gate on GBPJPY/EURJPY/AUDJPY/CHFJPY H1/H4 (E… | ARCHIVE:5430 |
| ORDER-149 | 2026-07-23 | REVIEWED + CORRECTED | MacdDiv divergence: majors D1/H4 sweep (ต่อยอด 999094 + GBPUSD-D1 parked) | GBPUSD D1 DEAD-OPTIMIZED (earned properly now) · USDJPY D1 DEAD-OPTIMIZED (holdout-fail) — ORDER-167 ปิดทั้งค… | ARCHIVE:7363 |
| ORDER-150 | 2026-07-23 | REVIEWED | (MR)_SweepReversal_XAU (SS4, 992006) new-home ladder: ranger symbols | PARKED-VERIFY(user) — EURUSD M15 = weak pulse (PF 1.08/40t), keep for build-on | ARCHIVE:5414 |
| ORDER-151 | 2026-07-23 | DONE | (TRND)_TsMom_XAU (S2, 992001) demo-isolate bundle prep |  | ACTIVE:1076 |
| ORDER-152 | 2026-06-29 | REVIEWED | [infra] doctrine reconciliation: Codex routing + stale verdict vocabulary + doc-retiremen… | moved 6 root docs → _archive_docs/ (DEPLOY_CHECKLIST_2026-06-29 + 5 one-off analysis docs), deleted empty por… | ARCHIVE:7214 |
| ORDER-153 | 2026-07-23 | REVIEWED | [infra] `portfolio/expectations.csv` + capture-at-attach rule (PQ-03 ครึ่ง data-capture,… |  | ARCHIVE:5124 |
| ORDER-154 | 2026-07-23 | REVIEWED-WITH-DEFECTS | [infra · money-adjacent] Attach-time portfolio risk budget (admission control) |  | ARCHIVE:5139 |
| ORDER-155 | 2026-07-23 | REVIEWED | [infra] workplan rev-B: `docs/EA_CORE_TEMPLATE_WORKPLAN_FOR_CLAUDE.md` |  | ARCHIVE:5174 |
| ORDER-156 | 2026-07-23 | REVIEWED | [infra] multi-account portfolio equity combiner + monthly rollup |  | ARCHIVE:5196 |
| ORDER-157 | 2026-07-23 | REVIEWED | [infra] walk-forward automation: generalize 4 one-off scripts + summarizer จริง + re-pin… |  | ARCHIVE:5210 |
| ORDER-158 | 2026-07-23 | REVIEWED | [infra · money-adjacent] Hedge/Recovery mode A/B harness + แก้ป้าย stub ที่ขัดกับโค้ด |  | ARCHIVE:5378 |
| ORDER-159 | 2026-07-23 | REVIEWED | [infra] DD95 backfill + แก้ basket/leg double-count (ปลดล็อก ORDER-154 ให้ใช้ตัดสินใจได้จ… |  | ARCHIVE:5182 |
| ORDER-160 | 2026-07-23 | REVIEWED | [infra · core, comment-only] แก้ป้าย "(stub)" ผิดข้อเท็จจริงใน `Inputs.mqh` (RecoveryMode… |  | ARCHIVE:5404 |
| ORDER-161 | 2026-07-26 | DONE + VERIFIED-NEUTRAL | template: portable money params (cent/USD-safe) + balance-scaled lot sizing |  | ARCHIVE:7332 |
| ORDER-162 | 2026-07-23 | RESOLVED | [investigation] ~~MT5 tester engine drift~~ → **ROOT CAUSE = leverage unpinnable + margin… |  | ACTIVE:1024 |
| ORDER-163 | 2026-07-23 | REVIEWED | [template hardening, CORE-002] Clean-room dependency audit: Boss V2 ไม่พึ่ง EA_CORE V1 | 0 forbidden dependency | ARCHIVE:5352 |
| ORDER-164 | 2026-07-23 | REVIEWED | [template hardening, PARAM-001] Full parameter registry — trace ทุก input ใน `Inputs.mqh`… |  | ARCHIVE:5363 |
| ORDER-165 | 2026-07-26 | DONE | [🔴 T0 BLOCKER · tooling] pin leverage + INPUT CACHE ให้ได้จริง ก่อน re-validate | TESTER INPUT-CACHE ไม่ใช่ leverage · cage พิสูจน์ reproducible 8/8 แล้ว + REVIEWED(Claude/Opus 2026-07-26) | ARCHIVE:7316 |
| ORDER-166 | 2026-07-23 | REVIEWED | [re-validate campaign, user-approved] rerun evidence บน fully-pinned config |  | ARCHIVE:5267 |
| ORDER-167 | 2026-07-23 | REVIEWED | [funnel completion] holdout ที่ค้างของ ORDER-147/149 บน pinned config |  | ARCHIVE:7307 |
| ORDER-168 | 2026-07-23 | REVIEWED | RSI-MR (990103) full WFA re-run บน pinned config | 3/3 OOS ยัง profitable แต่ margin ไม่เท่ากัน ไม่ใช่ "invalidated" เหมาว่าตายหมด | ARCHIVE:5227 |
| ORDER-169 | 2026-07-23 | REVIEWED | SS4 SweepReversal EURUSD coarse grid (RoundStep×AdxMax) | ceiling ~1.08-1.21 บน n สุขภาพดี — ยังไม่ผ่าน deploy bar, คง PARKED-VERIFY | ARCHIVE:5261 |
| ORDER-170 | 2026-07-23 | REVIEWED | [money-adjacent] แก้ defects ใน `portfolio_risk_admission.py` |  | ARCHIVE:5320 |
| ORDER-171 | 2026-07-23 | REVIEWED | [investigation] 990120 MacroGate: gate ไม่ veto อะไรเลยตอน re-run |  | ARCHIVE:5287 |
| ORDER-172 | 2026-07-23 | REVIEWED | [cross-check] 990201/990204 full-funnel อิสระ เทียบกับ ORDER-166 |  | ARCHIVE:5295 |
| ORDER-173 | 2026-07-23 | REVIEWED | SS4 SweepReversal EURUSD last lever: SweepAtr×TpAtr (บน RoundStep=0.0030 plateau center) | ไม่มี lever ไหนปลด SS4 ได้แล้ว — ทุกแกนที่มี (RoundStep/AdxMax/SweepAtr/TpAtr/RsiHi/RsiLo) แตะครบ | ARCHIVE:5256 |
| ORDER-174 | 2026-07-23 | REVIEWED | [blocker ของตัวเลขพอร์ต] correlation จาก backtest report |  | ARCHIVE:5301 |
| ORDER-180 | 2026-07-23 | REVIEWED | TrendRider XAGUSD H4 optimize-for-silver (ต่อจาก ORDER-167 BUILD-ON, BWD-fail บน center ท… | พลิกจาก BUILD-ON (BWD 0.97) → funnel เกือบครบ, ผ่านทุกด่านที่ทำแล้ว — เหลือ sensitivity fan (2 แกน) + corr ก่… | ARCHIVE:5238 |
| ORDER-181 | 2026-07-23 | REVIEWED | TrendRider XAGUSD H4: sensitivity fan (Sep/Ch) + corr vs cohort — ปิดของค้างสุดท้ายของ OR… | fan ผ่าน 3/4 ชัดเจน (1 แกนไม่ flat แต่ไม่ flip เป็นลบ) + corr ต่ำทั้งคู่ — BUILD-ON แข็งแรงมาก เกือบ CANDIDAT… | ARCHIVE:7292 |
| ORDER-182 | 2026-07-23 | REVIEWED | RSI-MR (990103): continuous-span re-measure — WFA stitched-window methodology invalid for… | edge ยืนยันจริง (both-window PF1.37/1.37 plateau, ไม่ใช่ spike) แต่ holdout n=26 บางล้มไม่ผ่าน → BUILD-ON (ไม… | ARCHIVE:7224 |
| ORDER-183 | 2026-07-23 | REVIEWED | RSI-MR (990103) lever 2/3: RSI band × SL-width coarse grid (ต่อ ORDER-182) | เจอ plateau ที่ดีกว่าเดิมชัดเจน (RSI25/75+SL25: MAIN1.96/BWD1.56, DD ต่ำกว่า, basket-duration สั้นกว่า) แต่ h… | ARCHIVE:7242 |
| ORDER-184 | 2026-07-23 | REVIEWED | [agent lane · mechanical + Claude review] populate `portfolio/backtest_corr_reports.csv`… |  | ARCHIVE:5305 |
| ORDER-185 | 2026-07-23 | REVIEWED | RSI-MR (990103) sensitivity fan รอบ RSI25/75+SL25 (ปิด LADDER Step 5, ต่อ ORDER-183) | plateau ที่แข็งแรงที่สุดในบรรดา EA ที่เทสวันนี้ทั้งหมด — ทุก cell ผ่าน both-window ไม่มี flip ลบเลยสักตัว — ย… | ARCHIVE:7259 |
| ORDER-186 | 2026-07-23 | REVIEWED | RSI-MR (990103) full MC บน RSI25/75+SL25 (ปิด LADDER Step 7 บน center ใหม่, ปิด funnel วั… | MC ผ่าน comfortable bar ทั้งคู่ (MAIN PF-5th 1.544, BWD 1.209) ดีขึ้นชัดเจนจาก baseline (1.116) — funnel ครบท… | ARCHIVE:7278 |
| ORDER-187 | 2026-07-26 | DONE | [core/money] fail-closed first-lot sizing + Wave5 naked-order guard (Codex review 2026-07… | ไม่สะอาด — 2 high/1 med/1 low แล้ว 194c เจอ fix ไม่ครบอีก 2 + บั๊กใหม่ 1) · ⚠️ ประโยค ".set ไม่มีไฟล์พัง" ถูก… | ARCHIVE:7058 |
| ORDER-188 | 2026-07-26 | DONE | [test] positive-path cage ของ lot mode 42/43 (`scripts\mm_lotmode_test.ps1`) | ✅ เดิมคือ run 6 ไม้ที่ DD-25% ฆ่าตั้งแต่วันที่ 8 · cage ตอนนี้ 13 เคส (E2_unit_indep_hi + K0/K1_scaled_*) + R… | ARCHIVE:7069 |
| ORDER-189 | 2026-07-26 | DONE | [docs] PARAM_REGISTRY 183/183 + คู่มือ lot mode §3.6 | 183/183 → 184/184 (ตรวจแล้วสองฝั่งตรงกัน) + REVIEWED(Claude/Opus 2026-07-26) | ARCHIVE:7087 |
| ORDER-190 | 2026-07-24 | DONE | [lever/funnel] MM-OWNER-002: Boss_16/Kangaroo ให้ scale ตาม balance ได้ (opt-in) |  | ACTIVE:1003 |
| ORDER-191 | 2026-07-26 | DONE 2026-07-24 | [docs/tooling] parameter linkage matrix + ล้างหนี้ line-number ของ registry | Sonnet lane + Claude verify · b/c: commit de14b3f3 "ORDER-191(b)(c): generated parameter linkage doc + inacti… | ARCHIVE:7175 |
| ORDER-192 | 2026-07-24 | REVIEWED | [tooling] OnInit effective-config summary + optimizer active-parameter guard | [CFG] sizing block landed + follow-up fix commit a97d7f7e "effective-config summary was lying about entry 16"… | ARCHIVE:7181 |
| ORDER-192(b) | 2026-07-26 | DONE | [tooling] optimizer active-parameter guard (`scripts/optimize_guard.ps1`) |  | ARCHIVE:7134 |
| ORDER-193 | 2026-07-26 | REVIEWED | [tooling/integrity] ตรวจจับ backtest ที่ถูก hard-kill ตัดกลางคัน (truncated-run detector) | scripts/check_truncated_run.ps1 wired into mt5_run.ps1 — ทุก run เขียน sidecar .truncation_check.json อัตโนมั… | ARCHIVE:7205 |
| ORDER-193(d) | 2026-07-24 | REVIEWED | retro-scan: verdict เก่าใบไหนตั้งอยู่บน backtest ที่ถูกตัดกลางคัน |  | ARCHIVE:7115 |
| ORDER-194 | 2026-07-26 | DONE | [core/safety] hard-kill ยิงซ้ำทุก tick หลัง halt แล้ว (ไม่มี `g_rc_halted` guard ใน `Risk… |  | ARCHIVE:7187 |
| ORDER-194b | 2026-07-26 | DONE | [core/safety] แก้ 4 ข้อจาก Codex blind-audit ของ ORDER-187/194 |  | ARCHIVE:7164 |
| ORDER-194c | 2026-07-26 | DONE | [core/safety] แก้อีก 4 ข้อจาก Codex review รอบสอง (ตรวจ "ของที่เพิ่งซ่อม") |  | ARCHIVE:7103 |
| ORDER-195 | 2026-07-26 | DONE | [tooling] ขยาย `[CFG]` ให้ครอบ override pair ที่เหลือ (ปิดช่องที่ ORDER-191(c) วัดออกมาได… |  | ARCHIVE:7150 |
| ORDER-196 | 2026-07-26 | DONE | [infra] ประกาศเลิกใช้ chassis V1 (`EA_LabTemplate.mq5` + `ea_template/modules/`) |  | ARCHIVE:7144 |
| ORDER-197 | 2026-07-24 | REVIEWED | [lever] ORDER-098 continuation: PROG_FIBONACCI vs PROG_LOG_POWER lot lever on Boss_14 XAU… | NOT ADOPTED — fails the pre-registered bar (loses on MAIN), PROG_LOG_POWER stays live default | ARCHIVE:6948 |
| ORDER-198 | 2026-07-24 | REVIEWED | [ops] 18-EA judge-projected-shortfall triage: silent-skip check + judge-date policy | NO BUG FOUND — the "18 shortfall" number is largely a formula artifact, not 18 EAs actually failing | ARCHIVE:6868 |
| ORDER-199 | 2026-07-24 | REVIEWED | [lever] ORDER-137 continuation: StoMultiTap last-optimize ADX-gate (the ONE untouched lev… | REJECTED — ADX-gate makes BOTH windows worse, ladder now fully exhausted | ARCHIVE:6893 |
| ORDER-200 | 2026-07-25 | REVIEWED | [macro/tooling] MRIS crisis-model extension (bond/credit/oil/equity axes) | Phase A-D ครบ · backtest 7/7 · alert เข้ามือถือ live · fold สร้างแล้วแต่สวิตช์ปิด รอ Codex audit | ARCHIVE:6837 |
| ORDER-200 | 2026-07-24 | REVIEWED | (ประวัติ Phase A/B) | Phase-A DONE + Phase-B concept-check 4/4 PASS — ADVISORY-ONLY, live | ARCHIVE:6842 |
| ORDER-201 | 2026-07-25 | REVIEWED | [lever] HANDOFF_ST03_OPTIMIZE continuation: standalone spacing lever (`InpNearbyPip`) | BWD-fail on all 3 variants — spacing does NOT rescue, PARKED-VERIFY(user) stays, lever #1/3 of the handoff cl… | ARCHIVE:6917 |
| ORDER-202 | 2026-07-25 | REVIEWED | [audit] retro-scan: which verdicts were selected on the burned 2026H1 holdout |  | ARCHIVE:7093 |
| ORDER-203 | 2026-07-25 | FIXED + REVIEWED | [macro/bug] core MRIS classifier: `user_pin=110` ทำให้ **replay ย้อนหลังทุกใบก่อนปี 2026… |  | ARCHIVE:6810 |
| ORDER-204 | 2026-07-25 | REVIEWED | [tooling/retro] genetic retro-audit: verdict ไหนตัดสินจาก genetic run ที่ไม่มี fine-grid… |  | ARCHIVE:6761 |
| ORDER-205 | 2026-07-27 | DONE | [expand] MacdDiv_Naked H4: 3 symbol ใหม่ (conditional, เดินต้นไม้เองได้) |  | ACTIVE:517 |
| ORDER-206 | 2026-07-27 | DONE | [expand] PivotBreakout H4: 3 symbol ใหม่ (conditional) |  | ACTIVE:584 |
| ORDER-210 | 2026-07-25 | REVIEWED | [🔴 เงินจริง · funnel] `EA_BREAKOUT_XAU` 991001 re-optimize บนหน้าต่างสะอาด | 🟡 กลาง ตามบาร์ที่ล็อกไว้ล่วงหน้า → คง v2 บนเงินจริง ไม่สลับ | ARCHIVE:6297 |
| ORDER-211 | 2026-07-25 | REVIEWED | [macro/re-validate] MacroGate 990120: หลักฐานเดิมสร้างจาก classifier ที่พัง | 🔴 ถอดสถานะ "VALIDATED deploy-candidate" → ADVISORY-ONLY | ARCHIVE:6347 |
| ORDER-212 | 2026-07-25 | REVIEWED | [🔴 เงินจริง · integrity] `NuiIndy` guardrail `CutLoss=30` — หาหน้าต่างที่มันถูกวัดมา | provenance = CLEAN · แต่หลักฐานพิสูจน์คนละเรื่องกับที่ถูกอ้าง | ARCHIVE:6410 |
| ORDER-213 | 2026-07-25 | DONE | [bookkeeping · ก่อน attach] Boss_16/Kangaroo: แก้บาร์ตัดสิน demo ให้เป็นเลขสะอาด |  | ACTIVE:409 |
| ORDER-214 | 2026-07-25 | REVIEWED | [🔴 เงินจริง · integrity] Gold Reaper 4.3: lab เขียน CORE ให้ EA เงินจริงโดยที่ plateau-c… | แก้ข้อความแล้ว · funnel = ไม่คุ้มรัน อธิบายเหตุผลไว้ | ARCHIVE:6684 |
| ORDER-215 | 2026-07-26 | PART 1 DONE | [🔴 เงินจริง · integrity] MatchaGrid CHFJPY: verdict CORE อ้าง genetic run ที่ไม่มี fine-… | "bounded+SL" ถอนแล้ว — safety switch ไม่ตอบสนอง · re-measure funnel ยัง OPEN | ACTIVE:447 |
| ORDER-216 | 2026-07-25 | REVIEWED | [demo · funnel] MacdDiv XAU H4 (999094): เติม fine-grid + fan ที่ genetic pick ไม่เคยมี | 🔴 plateau เดิม = ของปลอมที่สร้างจากแกนตาย · cell จริงคือ knife-edge → ถอดสถานะ "ผ่านครบทุกด่าน" → PARKED-VER… | ARCHIVE:6714 |
| ORDER-217 | 2026-07-25 | REVIEWED | [lever/build-on] MacdDiv: เส้น MACD signal ที่ EA ไม่เคยอ่าน = lever ที่ยังไม่เคยลอง | 🟨 กลาง ตามบาร์ที่ล็อกไว้ → เก็บเป็น lever ใน EDGE_CATALOG ไม่ deploy · code เก็บไว้ (default OFF พิสูจน์ ine… | ARCHIVE:6599 |
| ORDER-218 | 2026-07-25 | DONE + REVIEWED | [ops/integrity] error sweep: เครื่องเตือนไว้แล้ว แต่ไม่มีใครอ่าน |  | ARCHIVE:6492 |
| ORDER-219 | 2026-07-26 | DONE + REVIEWED | [ops/tooling] ทำให้ detector ที่มีอยู่แล้ว "ถูกอ่าน" |  | ARCHIVE:6536 |
| ORDER-220 | 2026-07-26 | DONE + REVIEWED | [test] `MMLOT_E_unit_indep` ผ่านด้วย 6 ไม้ — รันใหม่ให้มันเป็นการทดสอบจริง |  | ARCHIVE:6572 |
| ORDER-221 | 2026-07-26 | DONE + REVIEWED | [ops/integrity] กวาด compiled artifact ที่เก่าค้างทุกจุด |  | ARCHIVE:6631 |
| ORDER-222 | 2026-07-26 | DONE + REVIEWED | [🔴 เงินจริง · test] พิสูจน์ว่า `CutLoss=30` ของ NuiIndy "ตัดได้จริง" ไม่ใช่แค่ "ไม่เกะกะ" |  | ARCHIVE:6426 |
| ORDER-230 |  | OPEN | [🔴 เงินจริง · integrity] บัญชี 463666728: currency เป็น cent หรือ USD |  | ACTIVE:189 |
| ORDER-231 | 2026-07-27 | DONE | [demo · funnel gap] 992001 TsMom_XAU: ACTIVE อยู่แต่ไม่เคยมี Monte Carlo |  | ACTIVE:200 |
| ORDER-232 |  | OPEN | [🔴 เงินจริง · disposition] MacroGate 990120: เก็บ / ย้าย AUDJPY / ถอด |  | ACTIVE:246 |
| ORDER-233 |  | OPEN | [🔴 เงินจริง · audit] `--resolve-single-leg-baskets`: flag ที่พลิกงบพอร์ต 73% → 38% |  | ACTIVE:257 |
| ORDER-234 |  | OPEN | [🔴 เงินจริง · migration] PERSIST_MIGRATION checklist: ลอยข้าม handoff 3 ใบโดยไม่มีเจ้าของ |  | ACTIVE:267 |
| ORDER-235 |  | OPEN | [policy] บาร์ 30 ไม้ใช้กับ 4 EA นี้ไม่ได้ — ต้องเคาะ ไม่ใช่เลื่อนไปเรื่อยๆ |  | ACTIVE:277 |
| ORDER-236 |  | OPEN | [lever/build-on] lever 2 ตัวที่ build เสร็จ + cage ผ่านแล้ว แต่เซลล์ไม่เคยรันสักเซลล์ |  | ACTIVE:286 |
| ORDER-237 | 2026-07-26 | REVIEWED | [integrity] "GBPJPY leg-8" = 3 magic 2 spacing คนละตัวกัน |  | ARCHIVE:7935 |
| ORDER-238 | 2026-07-27 | DONE | [tooling/integrity] `2026.06.01` ค้างใน 5 สคริปต์ที่ guard มองไม่เห็น |  | ACTIVE:297 |
| ORDER-239 |  | OPEN | [monitoring gap] RSI-MR: หางเวลาถือ basket 98-182 วัน ยาวกว่าวัน judge |  | ACTIVE:315 |
| ORDER-250 | 2026-07-27 | DONE | [🔴 demo · order-of-record หาย] SS1 LondonORB 992003: ผ่าน funnel ขึ้น demo โดยไม่มีใบสั่… |  | ACTIVE:323 |
| ORDER-251 | 2026-07-27 | DONE | [🔴 integrity · หนี้ระบบ] คลัง skill ที่เป็นเจ้าของบาร์ตัดสินทุกใบ อยู่นอก repo และไม่มี… |  | ACTIVE:366 |
| ORDER-252 | 2026-07-27 | DONE | [tooling] staleness linter: บล็อกที่ปิดแล้วยังพูดสิ่งที่ถูกหักล้างไปแล้ว |  | ACTIVE:387 |
| ORDER-260 | 2026-07-26 | REVIEWED | [🔴 tooling/integrity] validator ตี order ที่ REVIEWED แล้วเป็น NonTerminal เพราะคำว่า "h… | แก้แล้ว — anchor NonTerminal pattern ที่ต้นช่วง backtick · วัดผลจริง Terminal 47→69, Terminal+REVIEWED 7→24 (… | ARCHIVE:7901 |
| ORDER-261 | 2026-07-26 | REVIEWED | [bookkeeping] ปิดกอง B: 28 ใบรอ REVIEW + 9 ใบต้องแก้ข้อความก่อนย้าย | ปิดครบ — เขียน review ให้ 28 ใบที่หลักฐาน resolve ได้ + แก้ข้อความ 9 ใบที่ถูกหลักฐานใหม่หักล้าง (073 · 143 ·… | ARCHIVE:7923 |
| ORDER-270 | 2026-07-27 | DONE | [tooling/integrity] กรงของ validator ใช้งานไม่ได้จริง — negative suite ช้าจนไม่มีใครรัน |  | ACTIVE:126 |
| ORDER-280 | 2026-07-26 | CLAIMED | [lever] rev04 re-entry บน BTC H4 — สวีป 3 anchor | 30) | ACTIVE:85 |
| ORDER-GEN-STANDING |  | OPEN-STANDING | matrix screening (standing order, ไม่มีวัน DONE) |  | ACTIVE:648 |
| ORDER-LANEA-AB | 2026-07-18 | DONE + REVIEWED | JumStoch (Boss_18) direction×lever A/B, Model-4 both-window | DEAD-OPTIMIZED (port-level). base-gate 16 M4 runs 0.58–0.71 (no pulse) → last-optimize exit lever (base fixed… | ARCHIVE:6985 |
| ORDER-LANEC-FAN | 2026-07-18 | DONE + REVIEWED | SMC×STO EURUSD H1 sensitivity fan + Model-4 | WEAK candidate — edge-positive but SL-fragile. 26 M4 runs. center 1.39/1.19 both-window; 5/6 axes robust (Ema… | ARCHIVE:7005 |
| ORDER-LANEC-REBUILD | 2026-07-18 | DONE + REVIEWED | SMC×STO rebuild for an SL plateau (parallel to live demo 991070) | NO SWAP — keep demo 991070. 35 M4 runs (coarse SL×TP grid MAIN + plateau-center SL3.5/TP1.2 both-window+fan+h… | ARCHIVE:7400 |
