# QA review — FABLE_RESETTLE_FRAMEWORK_2026-07-18

Scope: report-only review against the requested repository documents, source tree, and named Claude skills. Quotes below preserve the source wording; a finding marked UNVERIFIED is deliberately not treated as a factual contradiction.

## 1. Template architecture

### 1.1 Admission-bar evidence overstates the current PA-confirm cage result

- Severity: MAJOR
- Framework claim: “Chassis admission bar: a lever enters `core/` only after (i) validated on ≥1 EA with the full cage — compile 0/0 · tpl_regression CLEAN · run_tests PASS · neutrality byte-identical … Otherwise it stays an `ea_projects/` probe (`(EXP)_`/`(TRD)_`). This is exactly the PA-probe path — canonize it as THE path for new levers.”
- Contradicting evidence: `D:\EA_LAB\_triage\SESSION_HANDOFF_2026-07-18_ADAPTGRID_PA.md`: “Cage green (run_tests ALL PASS; neutrality byte-identical OLD-vs-NEW when StackConfirm≠4).” The same source says: “tpl_regression baseline still stale (pre-existing, benign) — user to refresh when ticks settle.” This does not support describing the PA path as having achieved `tpl_regression CLEAN`.
- Suggested fix: State that PA-confirm passed compile/tests/neutrality but has a pending regression-baseline exception; do not cite it as a complete-cage precedent until CLEAN is observed.

### 1.2 Proposed Kangaroo/ExitManager assert would reject an input combination whose code paths do not co-own exits

- Severity: MAJOR
- Framework claim: “One exit owner, asserted at OnInit: fail-fast (or hard-WARN) on illegal combos (e.g. STACK_PYRAMID + Recovery ON, Kangaroo + ExitManager partial-close).”
- Contradicting evidence: `D:\EA_LAB\ea_template\core\LabCore.mqh`: “entry 16 (KangarooGrid, ORDER-072): Kangaroo.mqh owns the ENTIRE pipeline … - one exit owner.” Immediately below, the actual control flow is `if(Kangaroo_OnTick()) return;`. `D:\EA_LAB\ea_template\core\ExitManager.mqh` says `Exit_ManagePartialClose()` is called from `Exit_ManageBasket()`, which is below that return in `LabCore.mqh`. Therefore an Entry-16 run does not execute ExitManager partial-close at all.
- Suggested fix: Assert only combinations whose close paths can execute concurrently; do not reject Kangaroo merely because dormant ExitManager input values are present.

### 1.3 “Dispatcher ONLY” is not covered by the three stated mechanical orders

- Severity: MINOR
- Framework claim: “LabCore.mqh dispatcher ONLY (OnInit/OnTick/OnDeinit wiring — no inputs, no strategy logic)” and “Three mechanical follow-up orders … move Kangaroo → entries/ · move MacroGate inputs → Inputs.mqh · add exit-owner init assert.”
- Contradicting evidence: `D:\EA_LAB\ea_template\core\LabCore.mqh` contains executable strategy decisions, including: “if(Regime_BlocksFlatEntry()) return;”, “EntrySignal sig = Entry_Evaluate();”, and “if(!Stack_DecideAdd(dir, have, sig)) return;”. Moving the two named files/inputs and adding an assert cannot make this file dispatcher-only.
- Suggested fix: Either retain “dispatcher plus orchestration” as the target description or add a separately scoped refactor with regression acceptance criteria.

## 2. Dev workflow

### 2.1 The proposed workflow reverses the review-before-compile ordering

- Severity: MAJOR
- Framework claim: “CAGE (hard, in order): compile 0/0 → mql-code-reviewer PASS → tpl_regression CLEAN (if core/ touched) → run_tests PASS.”
- Contradicting evidence: `C:\Users\patip\.claude\skills\mql-code-reviewer\SKILL.md`: “This skill is the **MQL5-specific gate** — run it on EA source before compile/smoke/deploy.” Its FINAL RULE is: “PASS → forward to vps-deploy-ops to compile and bundle.”
- Suggested fix: Put `mql-code-reviewer PASS` before compilation, then retain the compile/regression/test cage in the applicable order.

### 2.2 Fable remains in a delegation lane although the current operations rules say its quota is exhausted

- Severity: MAJOR
- Framework claim: “Delegation lanes (restated, unchanged): … Fable = 4 reserved one-shot cases.”
- Contradicting evidence: `D:\EA_LAB\AGENTS.md`: “Fable หมดโควต้าแล้ว … seat lead/judge = Claude Code รันบน Opus ตั้งแต่บัดนี้.” The authoritative current role table likewise defines the lead/judge as Claude Code/Opus, not a Fable lane.
- Suggested fix: Remove Fable from the active routing diagram and name the currently available lead/judge and independent-review path.

## 3. Optimize methodology

### 3.1 Model 2 is again permitted to select a coarse sweep

- Severity: BLOCKER
- Framework claim: “Model 2 = zero-trade/config filter + kill-direction only (may kill, may never pass, rank, or be shown as a result). For pure bar-open single-position EAs it may drive the coarse sweep, but any number reported or selected on = Model 1+.”
- Contradicting evidence: `D:\EA_LAB\PROJECT_STATE.md`: “Model 2 (open price) ห้ามใช้รายงาน/จัดอันดับ PF เด็ดขาด — ใช้กรอง zero-trade เท่านั้น”. `D:\EA_LAB\AGENTS.md` states the same rule operationally: “ตัวเลขที่รายงาน = Model 1 ขึ้นไป (Model 2 ใช้กรอง zero-trade เท่านั้น)”. A coarse optimizer necessarily ranks/selects configurations by its result, so it is not a zero-trade filter.
- Suggested fix: Restrict Model 2 to zero-trade/broken-config elimination; run every coarse/fine surface used to choose a zone on Model 1+.

### 3.2 MAIN window contradicts the fixed three-year rule

- Severity: BLOCKER
- Framework claim: “Windows (pin once, use everywhere): MAIN = 2023.01–now (3-yr rule).”
- Contradicting evidence: `D:\EA_LAB\PROJECT_STATE.md`: “backtest window = 3 ปี (2023–2026) · re-opt ทุก 6 เดือน”. As of the framework date (2026-07-18), 2023.01–now is roughly three years and six months, not the stated three-year window.
- Suggested fix: Pin MAIN to an exact rolling three-year start/end (or explicitly obtain a standing-rule change before using a longer span).

## 4. Verdict framework

### 4.1 The framework says only structural cases discard, but its own tree discards optimized cases

- Severity: MAJOR
- Framework claim: “⇒ DEAD-OPTIMIZED. Cell-level by default; CONCEPT-level only when the right-home ceiling itself was proven.”
- Contradicting evidence: `D:\EA_LAB\_triage\FABLE_RESETTLE_FRAMEWORK_2026-07-18.md`: “only STRUCTURAL death discards.” These two statements assign incompatible discard status to `DEAD-OPTIMIZED`.
- Suggested fix: Define whether DEAD-OPTIMIZED is a discard, a closed cell, or a retained catalogued concept, and use that definition consistently in the tree and closing doctrine.

### 4.2 The demo-to-live irreversible gate relies on the retired Fable advisor

- Severity: MAJOR
- Framework claim: “≥3 months demo forward, then judge → REAL MONEY (irreversible gate: Fable-advisor one-shot case-3 + Codex second opinion, no anchoring)”.
- Contradicting evidence: `D:\EA_LAB\AGENTS.md`: “Fable หมดโควต้าแล้ว … seat lead/judge = Claude Code รันบน Opus ตั้งแต่บัดนี้.”
- Suggested fix: Replace the unavailable Fable dependency with the active authorized judge and explicitly retain the required independent Codex review.

## 5. Handoff routing

### 5.1 `ab_sets/` is introduced without a verified owner or existing locked-set convention

- Severity: MINOR
- Framework claim: “optimize → validate … Written where: `ab_sets/` + `_triage/ORDERxxx_*_VERDICT.md`.”
- Contradicting evidence: `D:\EA_LAB\scripts\tpl_regression.ps1` uses the existing frozen-set paths `ea_template\sets\Boss14_regression_smoke.set` and `ea_template\sets\Boss16_Kangaroo_XAU_smoke.set`. For deployment, `C:\Users\patip\.claude\skills\vps-deploy-ops\SKILL.md` says: “The `.set` must be the **exact locked set the validation used**” and defines the actual bundle convention under `D:\EA_LAB\_vps_deploy\`. No listed source establishes `ab_sets/` as a path, owner, or retention convention.
- Suggested fix: Use an established set location or define `ab_sets/`’s owner, naming, immutability, and deployment handoff before routing artifacts there.

## 6. Cross-cutting issues

### 6.1 The framework’s stated Model-2 policy is internally self-contradictory

- Severity: MAJOR
- Framework claim: “Model 2 = zero-trade/config filter + kill-direction only (may kill, may never pass, rank, or be shown as a result).”
- Contradicting evidence: `D:\EA_LAB\_triage\FABLE_RESETTLE_FRAMEWORK_2026-07-18.md`: “For pure bar-open single-position EAs it may drive the coarse sweep.” A coarse sweep’s function is to compare/rank configurations to find a zone, so this is incompatible with “may never … rank”.
- Suggested fix: Delete the coarse-sweep exception or redefine it as a non-ranking zero-trade preflight only.

### 6.2 Fable is referenced in two operationally required paths after being retired

- Severity: MAJOR
- Framework claim: “Fable = 4 reserved one-shot cases.”
- Contradicting evidence: `D:\EA_LAB\AGENTS.md`: “Fable หมดโควต้าแล้ว … seat lead/judge = Claude Code รันบน Opus ตั้งแต่บัดนี้.”
- Suggested fix: Make one active-model-routing decision for all five parts; do not leave unavailable Fable steps as required gates.

## Summary

| Severity | Count |
|---|---:|
| BLOCKER | 2 |
| MAJOR | 8 |
| MINOR | 2 |

BLOCKER and MAJOR items:

- MAJOR — PA-confirm is cited as a complete-cage admission precedent despite the documented stale tpl_regression baseline.
- MAJOR — The proposed Kangaroo/ExitManager assert would reject a combination whose runtime paths do not co-own exits.
- MAJOR — The workflow places compile before the required MQL code review.
- MAJOR — Active delegation still reserves Fable although the authoritative rules say its quota is exhausted.
- BLOCKER — Model 2 is allowed to drive a coarse selection sweep despite the zero-trade-only ban.
- BLOCKER — `2023.01–now` is labeled a three-year MAIN window although it exceeds three years on the document date.
- MAJOR — `DEAD-OPTIMIZED` is defined while the same framework says only structural death discards.
- MAJOR — Demo-to-live requires a retired Fable-advisor step.
- MAJOR — The Model-2 rule both forbids ranking and permits a ranking coarse sweep.
- MAJOR — Fable is left as a required routing dependency in more than one part after retirement.
