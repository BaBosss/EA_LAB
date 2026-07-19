# HANDOFF 2026-07-18 (Opus session) — framework rollout + RSI-momentum + verdict-discipline fixes

Commits this session: `d0560cc f26d0c01 0d12fbdb 51ca7dd8 b553648b 55ee7344 d3f5b044 a0c747ae 8fd5ad0c dd95fb0e b8107545 7c036ba8`
(path-limited; parallel session moved HEAD several times — no conflicts).

## สิ่งที่ทำจบ (committed, guards ผ่าน, state CLEAN)

### 1. Re-settle framework rollout (ORDER-120→123 DONE, Part 4c residual)
- **CLAUDE.md VERDICT GATE** → decision tree + 7-row bar table + Row-X write-checklist + rolling-36 windows.
  ⚠️ MAIN pin แก้ทีหลัง (Codex system review) = **2023.01–2025.12** (ไม่กิน holdout 2026H1) — ใช้ตามนี้.
- **skill `backtest-optimize-rigor`** → THE OPTIMIZE LADDER Step 0-9; ลบ "Model 2 throughout optimize" (Codex BLOCKER).
- **docs/PIPELINE.md** ใหม่ = flow owner + routing table 10 boundary; sync FINAL RULE 9 skills; portfolio-selector
  corr ladder; robustness-validator + report-analyzer = DEMOTED calculators; AGENTS §1.5 Fable reservation.
- **taskboard template** + 2 field บังคับ (`bars:` · `flat-lot:`) ตั้งแต่ ORDER-124+.
- **scorecard PART 0** = canonical vocab + legacy map. **ORDER-124 = ยัง blocked รอ user refresh regression baseline.**

### 2. Research lanes (user "ทำทั้งหมด")
- **MacdDiv GBPUSD D1** = DEAD-OPTIMIZED (cell). ⚠️ verdict แรก (frequency-only) **ไม่ครบ** — user challenge
  "optimize ทุกตัวที่ตีตายรึยัง" จับได้ว่าข้าม MACD entry-params (lever #1). เทสเพิ่ม: both-window ผ่านจริง
  (F16/S26 1.50/1.35) แต่ holdout ฆ่าหมด (0.00/0.47) → verdict เดิมถูก **แต่ตอนนี้ earned**. บทเรียนเข้า signal-landscape.
- **YouTube corpus** → `_triage/FXDREEMA_BUILDON_RANKED_2026-07-18.md` (proposal, ยังไม่ review เต็ม). top =
  velocity/impulse momentum (⚠️ tick-sensitive), RSI-continuation, MACD-histogram.
- **QuantCorner catalog** → dedup (pairs=ซ้ำ PairSpread) → queue **ORDER-125** (vertical-barrier exit, blocked ร่วม 124)
  + **ORDER-126** (ATR-SL/round-number rescue ให้ SMCxSTO 991070, ไม่ติด blocker).

### 3. RSI-momentum campaign (ORDER-127 REVIEWED = DEAD-OPTIMIZED concept)
- build `(EXP)_RsiMomentum_Naked` (3 mode A/B/C + EMA/MACD/BB filter default-OFF, SuperTrend deferred) · mql-review PASS · compile 0/0.
- เทส **XAU + GBP (ทั้ง 2 บ้าน momentum) × 3 mode × entry-swept × H1/H4** = ไม่มี plateau both-window ที่ไหน;
  ตัวผ่านเป็น isolated spike. → RSI ไม่มี edge naked, ใช้ได้แค่ confirm-filter. filter overlays ไม่รัน (gate: filter ไม่กู้ naked-breakeven).
- **RSI TEST KIT ให้ user เทสมือ = `_user_test/RSI_MOMENTUM_KIT/`** (ex5 + 8 .set + README). user อยากเทสเอง.

## ADDENDUM 2026-07-19 (ต่อ session เดิม, "ทำต่อให้จบ")
- **ORDER-126 = DONE (NO LIFT, keep 991070).** round-number SL-avoidance ไม่แก้ fragility — fragility = M4
  fill-sensitivity ไม่ใช่ stop-hunt (M1 บัง: 1.05/1.03 plateau vs M4 0.94/0.99 cliff, reproduce Lane C). lever
  `_09_RoundAvoid` เก็บใน EmaStoRev (default OFF, reusable). verdict `_triage/ORDER126_SMCSTO_ROUNDAVOID_VERDICT.md`.
- **ORDER-119 = DONE by parallel session** (flat-lot MACD = 0/6 both-window = DEAD-STRUCTURAL, escalation คือ edge).
- **ORDER-124 + 125 = UNBLOCKED แล้ว** (parallel session ORDER-129 re-pin baseline 2026-07-18) — **แต่ทั้งคู่แตะ
  core/ ที่ parallel session กำลังทำอยู่ (129/130/131/133) → collision risk, ควร coordinate ก่อนลงมือ ไม่ solo.**
- **next research build (non-colliding) = velocity/impulse momentum** (lane-2 proposal top pick) — ⚠️ tick-sensitive,
  ต้องออกแบบดีๆ + Model-4, ไม่ควรรีบทำตอนท้าย session. queue ไว้.

## ค้าง user (ทำแทนไม่ได้)
- ~~refresh baseline~~ ✅ ทำแล้วโดย parallel session (ORDER-129)
- NUI_cut30only.set → live magic 1524 · 8 bundle staged รอ attach (จาก session ก่อน)
- **user จะเทส RSI kit เอง** → ถ้าเจอ config มีชีพจร ส่งกลับมา funnel ต่อ

## queue เปิด
- ORDER-119 (ST03 rescue, dispatch-ready, user เลื่อน) · ORDER-124/125 (blocked baseline) · ORDER-126 (ready)
- residual: FXDREEMA proposal (velocity/impulse smoke) · ORDER-127 reversion-branch (D, low-prior, optional)

## บทเรียนถาวร session นี้
**sweep entry-signal params (lever #1) ก่อนฆ่า indicator-EA เสมอ — partial-sweep verdict อาจถูกด้วยดวง.**
user challenge จับ MacdDiv D1 ได้ → RSI รอบนี้เลยเทส right-home ครบ 2 บ้านก่อนตี concept. (เข้า signal-landscape + [[feedback-optimize-before-killing-reversion]] แล้ว)
