# RE-SETTLE FRAMEWORK — 5 parts of EA_LAB operations (Fable seat, 2026-07-18)

> Requested via `_triage/FABLE_REVIEW_PROMPT.md`. Sources read in full: CLAUDE.md (VERDICT GATE),
> PROJECT_STATE.md, VISION.md, AGENTS.md, EDGE_CATALOG.md, ea_template/ (core module tree + DESIGN_V2 +
> LabCore), backtest-optimize-rigor + OPTIMIZE_PROCEDURE_AND_AUDIT, cross-audit of 8 pipeline skills,
> SESSION_HANDOFF_2026-07-18_ADAPTGRID_PA.md. Status: **FINAL — Codex blind review applied**
> (findings: `_triage/CODEX_RESETTLE_REVIEW_2026-07-18.md`; 8 accepted+fixed, 3 Fable-related findings
> partially rejected — Codex read AGENTS.md §1.5 (2026-07-04 "quota exhausted") but the later
> CLAUDE.md/PROJECT_STATE update 2026-07-11 reserves remaining Fable for 4 one-shot cases; the real
> defect is that AGENTS.md §1.5 was never synced → added to the doc-update list).
> Each part: (a) diagnosis · (b) re-settled spec · (c) docs to lock it in.

---

## PART 1 — Template EA architecture

### (a) Current state + problems
The LabCore decomposition is **fundamentally right and should be kept**: the numbered axes
(1x entry · 2x exit · 3x SL · 4x first-lot · 5x progression · 6x direction · 7x filter · 8x recovery ·
9x stack · 50 regime · RC cage) are exactly the levers the optimize procedure sweeps — architecture
mirrors methodology, which is rare and valuable. Five real weaknesses:

1. **Decision-point blindness (the CLASS of bug behind the Regime-seed gap).** The chassis has three
   order decisions — SEED, ADD, EXIT-HOLD — but gate layers (Regime 50, Filter 7x, MacroGate,
   confirms) were historically plumbed only into SEED. `_9_RegimeGateAdds` patched one instance;
   nothing stops the next gate from repeating the gap. There is no single chokepoint all order
   decisions flow through, and no rule forcing a new gate to declare its coverage.
2. **Per-EA engine in core/:** `core/Kangaroo.mqh` is entry-16-only but sits at core root. The
   chassis/per-EA boundary is not enforced by layout. (Precedent for the right way already exists:
   `entries/Wave5Swings.mqh` lives beside its entry.)
3. **`modules/` (V1) duplicate tree** is "intentional, not garbage" — but it is an un-caged drift
   surface: tpl_regression does not cover it and a future session can edit the wrong tree.
4. **Input placement drift:** the MacroGate self-gate `input` block is declared inside `LabCore.mqh`
   (the dispatcher), not `Inputs.mqh`.
5. **Exit ownership is doctrine, not contract.** ExitManager, Recovery, Hedge, Kangaroo, Basket can
   all close positions. "One exit owner" is enforced ad hoc (STACK_PYRAMID 93 disables
   Recovery/Hedge; an init WARN exists for 93+pending) — there is no general init-time assert and no
   written legal-combination matrix.

### (b) Re-settled spec — target module map

```
LabCore.mqh        dispatcher + orchestration ONLY (OnInit/OnTick wiring + the decision-pipeline
                   call order — no inputs, no per-EA logic; the pipeline steps live in modules)
Inputs.mqh         ALL inputs (incl. MacroGate) + owner of the numbering scheme
── chassis services (EA-agnostic, always compiled)
   Indicators · Execution · Persist · Basket(accounting) · RiskControl(cage) · MoneyManagement(sizing)
── decision pipeline (every order decision flows through, in this order)
   Entry_XX (1x, compile-time)          → proposes SEED direction
   GATES  : Regime(50) · Filter(7x) · MacroGate
            → each gate DECLARES coverage {seed, add}; default = BOTH (grids are never flat)
   Stack (9x)                           → seed/add law; Stack_DecideSeed / Stack_DecideAdd = the
                                          single chokepoint gates and confirms hook into
   CONFIRMS: StackConfirm enum          → add-time quality filters: distance · CONF_PA_ENGULF ·
                                          future CONF_SMC_OB · CONF_SR_LEVEL (one module file each)
   ExitManager (2x/3x)                  → THE exit owner
   Recovery(8x) / Hedge                 → default OFF; may not co-own exits with the active owner
── per-EA
   entries/Entry_XX.mqh  (+ entries/XX_Engine.mqh when the entry needs an engine — Kangaroo moves here)
```

**Six rules for adding to the chassis (lock these):**
1. **Additive + default OFF + byte-identical when OFF.** Neutrality A/B is already practice
   (RegimeGateAdds, PA-confirm both proved it) — make it the written admission bar for every
   `core/` merge.
2. **Every gate/confirm declares decision-point coverage** (seed / add / both) in its header comment
   and DESIGN_V2 row. "Seed-only" requires a stated reason. This rule alone would have caught the
   Regime gap at review time.
3. **Chassis admission bar:** a lever enters `core/` only after (i) validated on ≥1 EA with the full
   cage — compile 0/0 · tpl_regression CLEAN · run_tests PASS · neutrality byte-identical — AND
   (ii) plausibly reusable by ≥2 entries. Otherwise it stays an `ea_projects/` probe
   (`(EXP)_`/`(TRD)_`). The PA-probe path is the model for this — with one honesty note (Codex
   catch): PA-confirm itself entered under a **stale tpl_regression baseline** (RED-benign,
   trade-counts identical — pre-existing). That exception is acceptable ONLY because the baseline
   staleness pre-dates the change and neutrality was byte-identical; once the user refreshes the
   baseline, CLEAN becomes non-negotiable again.
4. **New confirm layers = one new StackConfirm enum value + one module file** (the PriceAction.mqh
   pattern). Never inline pattern logic into Stack.mqh. SMC/S-R plug in the same seam. Confirm
   layers are **risk-trimmers by default** and are judged by **expectancy-per-trade, not net/PF**
   (2026-07-18 lesson: a filter can cut trades so net/DD "improve" while expectancy worsens).
5. **`core/` root stays per-EA-free:** move `Kangaroo.mqh` → `entries/`; ban future per-EA files at
   root. Move the MacroGate input block → Inputs.mqh. (Both mechanical, cage-verified orders.)
6. **One exit owner, asserted at OnInit — on the EXECUTED path only** (Codex refinement): the
   assert fires when two close paths **can actually run concurrently** in the active config
   (e.g. STACK_PYRAMID + Recovery ON), NOT when a dormant module merely has inputs set
   (entry-16 Kangaroo already hard-owns via `if(Kangaroo_OnTick()) return;` — ExitManager never
   executes, so that combo is legal). Write the legal exit-owner matrix into DESIGN_V2 §3c.

**Chassis vs per-EA (one sentence):** anything in the VISION formula's "function กลาง" —
MM · lot law · SL/TP · grid/DCA · hedge · recovery · gates · confirms — is chassis (numbered axis,
default OFF); the entry signal, its private engine, and its home-symbol defaults are per-EA;
anything unproven is an `ea_projects/` probe first.

**Also:** stamp `modules/` (V1) with a read-only LEGACY banner (no new work; kept for grandfathered
builds only). It stays un-caged by declaration instead of by accident.

### (c) Docs to update
- `ea_template/DESIGN_V2.md` — add "Module map + chassis admission rules" section (owner of Part 1).
- `docs/EA_CORE_AND_TEMPLATE_GUIDE.md` — sync pointer.
- Three mechanical follow-up orders (cage-verified, additive): move Kangaroo → entries/ · move
  MacroGate inputs → Inputs.mqh · add exit-owner init assert.

---

## PART 2 — Dev workflow (idea → shippable EA)

### (a) Current state + problems
Practice is healthy; the **skill docs describe TWO pipelines that never reconcile**, and neither is
what actually runs. Cross-audit findings (verified against the 8 skill files):

- **Spec pipeline** (declared in strategy-and-risk): strategy-and-risk → mql-code-generator →
  backtest-report-analyzer → ea-optimization-orchestrator → robustness-validator →
  portfolio-selector → live-deployment-controller.
- **Standalone pipeline** (declared piecemeal): signal-scanner → generator → backtest-optimize-rigor
  → mql-code-reviewer → vps-deploy-ops.
- Concrete doc bugs: generator's FINAL RULE **skips mql-code-reviewer** entirely; verdict
  vocabularies don't map (PASS/CONDITIONAL vs PROCEED/WATCH/DEAD — robustness-validator literally
  refuses input the standalone path produces); **two deploy skills with undefined ordering**
  (live-deployment-controller never routes to vps-deploy-ops; vps-deploy-ops doesn't require any
  verdict — a user could ship around the risk gate); three contradictory "default authoring vehicle"
  statements (YAML-spec / standalone-preferred / CHASSIS-FIRST 2026-07-10); portfolio-selector's
  "pair>0.7 blocks APPROVED" **contradicts the user's correlation→reduce-lot-not-cut rule**;
  trade-count floors differ (30/50/60) uncross-referenced; the OOS PF≥1.40 gate exists only in
  signal-scanner while downstream gates use 0.9–1.0.
- What actually ran for the last two weeks (MacdDiv, SMC×STO, AdaptiveGrid, JUMSTOCH…) is a third,
  better thing: signal-scan smoke → chassis/probe build → optimize-rigor funnel → VERDICT GATE →
  DEPLOYMENTS.csv + vps mechanics. **Docs should be rewritten to match practice, not vice versa.**

### (b) Re-settled spec — ONE canonical pipeline

```
IDEA
 └─ signal-scanner: classify momentum/reversion → pick RIGHT HOME (reversion→ranger · momentum→trender)
    naked smoke (M2 = zero-trade filter only → M1 numbers) · flat-lot probe if any escalation
    ├─ DEAD (structural, or right-home optimize-ceiling already known) → EDGE_CATALOG dead pile. STOP.
    └─ PROCEED / WATCH ↓
DESIGN  (only when the MECHANISM or risk shape is new): strategy-and-risk → Spec Card (L5 refuse ·
        L4 needs user sign-off). Entry-on-chassis (the default case): skip the Spec Card — write a
        taskboard order with pre-registered bars instead.
BUILD   chassis-first (Boss V2); standalone needs a stated reason (speed alone is no longer one).
        Claude seat writes the code (ROUTING FLIP 2026-07-16) · Codex = blind auditor on money/risk logic.
        CAGE (hard, in order): mql-code-reviewer PASS (on source, before compile — per the reviewer
        skill's own contract; Codex catch) → compile 0/0 → tpl_regression CLEAN (if core/ touched)
        → run_tests PASS. No stage may be skipped even under quota pressure.
TEST + OPTIMIZE   backtest-optimize-rigor ladder (Part 3 owns the method).
VALIDATE          both-window → plateau fan → holdout → MC → Model-4 if fill-sensitive → year-split.
VERDICT           CLAUDE.md VERDICT GATE, Claude/user only (Part 4 owns the tree).
PORTFOLIO         corr ladder (Part 5 numbers) — reduce-lot, never auto-cut.
DEPLOY            DEPLOYMENTS.csv row FIRST → live-deployment gate (judge criteria + kill-switch
                  pre-registered) → vps-deploy-ops bundle + S1–S7 silent-stop checklist → USER attaches.
OPERATE           ea-live-monitor every 1–2 weeks → judge date.
```

Delegation lanes (restated): qwen = batch/parse · Sonnet = mechanical-with-cage · Opus-seat =
judgment/verdict/new-risk-logic · Codex = blind audit + second opinion on expensive/irreversible
only · ZCode = 1 heavy batch/day · Fable = the 4 reserved one-shot cases via `fable-advisor`
**while quota lasts; fallback when unavailable = Opus-seat decides + mandatory Codex second
opinion** (Codex flagged a real doc conflict here: AGENTS.md §1.5 still says "quota exhausted"
2026-07-04 while CLAUDE.md/PROJECT_STATE 2026-07-11 reserve ~10% for 4 cases → sync AGENTS.md §1.5).

**Kill list (specific fixes, one answer each):**
1. **Demote backtest-report-analyzer + robustness-validator from pipeline stages to calculators.**
   Their numeric content (MC bars, WFA windows) folds into the optimize ladder; their verdict
   vocabulary (PASS/CONDITIONAL/ROBUST/MARGINAL/Mode-B) is retired — no recent verdict used it, and
   the VERDICT GATE supersedes it. One funnel, one vocabulary (Part 4's).
2. **Generator FINAL RULE → mql-code-reviewer** (not backtest-report-analyzer). Reviewer becomes a
   mandatory cage stage, not a manually-invoked extra.
3. **Delete the "standalone faster path" block in strategy-and-risk** (and the "standalone
   preferred" line in mql-code-generator). CHASSIS-FIRST 2026-07-10 is the standing default; the
   contradicting older lines are drift.
4. **Order the two deploy skills:** live-deployment-controller = the GATE (judge criteria,
   kill-switches, sizing — feeds DEPLOYMENTS.csv) → vps-deploy-ops = the SHIPPING (compile, bundle,
   S1–S7). vps-deploy-ops must state it requires the gate's output for anything going to an account.
5. **Fix portfolio-selector's corr numbers** to the user ladder: ≤0.40 additive · 0.40–0.60
   reduce-lot · >0.60 redundant→reduce-lot-not-cut (user decides drops) · same-EA-cross-symbol <0.8.

### (c) Docs to update
- **NEW `docs/PIPELINE.md`** = single owner of the flow + the Part-5 routing table. Skills own their
  stage mechanics; PIPELINE.md owns the routing between them (fits the 1-fact-1-owner anti-drift rule
  — this fact currently has no owner, which is why it forked into two).
- FINAL RULE lines in: strategy-and-risk · mql-code-generator · signal-scanner ·
  backtest-optimize-rigor · mql-code-reviewer · robustness-validator · portfolio-selector ·
  live-deployment-controller · vps-deploy-ops — each points to its true next stage per the diagram.
- AGENTS.md §1.5 — sync the Fable status to the 2026-07-11 reservation (4 one-shot cases while
  quota lasts, Opus+Codex fallback) — currently contradicts CLAUDE.md/PROJECT_STATE.
- CLAUDE.md unchanged for Part 2 (the gate is already correct).

---

## PART 3 — Optimize strategy (the ladder)

### (a) Current state + problems
The material is all present but split across CLAUDE.md gate, the rigor skill,
OPTIMIZE_PROCEDURE_AND_AUDIT.md, and EDGE_CATALOG margin notes. Three genuinely vague spots:
1. **The Model policy self-contradicts.** The rigor skill still says "use Model 2 throughout
   optimize + IS/OOS for bar-open EAs", while the 2026-07-17 lesson proved Model 2 manufactures
   fake both-window grid plateaus (AUDNZD PF 3–4 → M4 0.61/0.75). The grid carve-out currently
   lives only in signal-scanner Mode 2 and an EDGE_CATALOG note — not in the skill that owns
   optimization.
2. **"Both-window" is numerically pinned nowhere in the skills** (only CLAUDE.md names BWD
   2020-22). robustness-validator uses a completely different split (`--oos-split 0.7`).
3. **"How much is enough" is quantified for rescue (≥3 levers × ≥2 TF) but not for pass**, and MC
   bars differ across skills (PF-5th >1.2 vs ruin <2%/10% vs "MC stable").

### (b) Re-settled spec — THE OPTIMIZE LADDER (ordered, one owner)

**Windows (pin once, use everywhere):** MAIN = **the most recent 36 months, re-pinned at each
6-month re-opt** (today ≈ 2023.07–2026.07 — Codex catch: the habitual "2023.01–now" has silently
grown to 3.5 yr, violating the fixed-3-yr rule; the rolling definition restores the rule's intent
without a rule change) · BWD = 2020–2022 (trend/stress regime) · HOLDOUT = a window or symbol never
used for selection (default 2026H1 while it stays untouched; it burns once used — then demo-forward
IS the holdout and the verdict must say so).

- **Step 0 — Preconditions (before ANY sweep):** usable check (license/expiry/lock) · classify type
  + candidate home TF/symbol · param units + instrument scaling (ATR-relative axes transfer;
  $-axes rebuilt per instrument class) · **flat-lot probe if any escalation exists** (flat PF<1 while
  escalated PF>1 ⇒ STRUCTURAL, stop here) · artifact screen (tight-TP ×10 widen · multiplier=1) ·
  **pre-register the bars in the order text**: pass = X · dead = Y · middle = Z.
- **Step 1 — Lever inventory:** spacing · lot-law · SL width · TP · exit-mode · entry-threshold ·
  symbol · TF. Mark each SWEPT/HELD. An EA-level verdict from <3 swept = INVALID.
  **Entry-signal params are lever #1 for oscillator/indicator entries** (StoK 5→17 flipped the verdict).
- **Step 2 — Coarse (zone-finding):** 2–3 levers, ≤~50 combos, MAIN window, deterministic grid
  (never MT genetic for selection). Goal = find the ZONE, not the winner.
- **Step 3 — Surface read:** plateau = neighbors also profitable · high min-neighbor · sane trade
  count for the type · stable DD. Spike or hole = not passed. Fine grid around the zone → pick the
  **plateau CENTER**, never the peak.
- **Step 4 — Both-window:** every shortlisted config runs MAIN + BWD **at the same settings,
  simultaneously** — no single-window ranking survives to the next step. Basket/grid/recovery EAs:
  **one continuous span only** (stitched windows lie ~10x; proven 2026-07-08).
- **Step 5 — Sensitivity fan:** ±20% single-axis around the center **including frozen axes** (SL,
  max levels). Bar: most variants hold ≥70% of baseline PF and none flips to a loss.
- **Step 6 — Holdout:** ONE run on the untouched window/symbol. Collapse ⇒ selection-fit (the
  EUR-H4 MacdDiv 1.71/1.15→holdout 0.35 case) → back to diagnosis, or BUILD-ON if PF>1 elsewhere.
- **Step 7 — MC + year-split:** reshuffle MC = optimistic lower bound. Bars: ruin ≤2% green ·
  2–10% ⇒ resize-first then re-measure (cap breach ≠ reject) · >10% after resize = fail ·
  PF-5th ≥1.0 hard floor, ≥1.2 comfortable. Year-split every full-window run: no hidden losing
  final year; losing years must show capped damage.
- **Step 8 — Model policy (crisp):**
  - **Model 2** = zero-trade/broken-config preflight + **kill-direction only**. It may never pass,
    rank, select, or be shown as a result — **and a coarse sweep IS ranking, so coarse sweeps run
    Model 1+, full stop** (Codex BLOCKER catch: an earlier draft carried the rigor-skill's stale
    "Model 2 for bar-open optimize" exception — that line is the drift; the Model-2 ban decision
    log 2026-07-03 is the law. Delete the exception from the skill too.)
  - **Model 1** = minimum fidelity for any number that ranks, selects, or reaches the user; fine
    for single-position bar-open EAs end-to-end.
  - **Model 4 MANDATORY before any verdict/deploy for:** grid/DCA/basket/multi-position ·
    pending-ladder entries · TP < 20 pip · any EA whose largest-loss or n shifts hard between
    models (the tell-tale). M4 runs SERIAL on tester lane 1 only, never in parallel.
  - **Grid EAs: Model-2 numbers are not evidence at all** — not even "provisional" (fake-plateau
    lesson, paid 2026-07-17).
- **Step 9 — Enough = the pre-registered bars are answered.** Typical full funnel per EA×home ≈
  coarse ~50 + fine ~30 + fan ~12 + both-window ×2 + holdout ×1 + M4 ×2–3 ≈ **~100–150 runs** —
  budget it; below ~half of that, a kill verdict is probably premature (unless STRUCTURAL).

**Anti-overfit invariants (unchanged, restated as one block):** never move to a sweeter zone after
seeing holdout/live data · optimizer output is in-sample · a window used for selection is in-sample
forever · optimistic-side fidelity can only kill, never pass · window = 3yr fixed, re-opt every 6
months · momentum>reversion prior RAISES the pass bar (PF≥1.2 post-optimize), it never waives steps.

### (c) Docs to update
- `backtest-optimize-rigor` SKILL.md = **owner**: rewrite Phase D–F into this ladder; pin MAIN/BWD
  numerically; move the Model-4-mandatory table in; delete/amend the "Model 2 for optimize" line to
  the crisp Step-8 policy.
- OPTIMIZE_PROCEDURE_AND_AUDIT.md — add a superseded banner pointing to the skill (avoid 3 owners).
- CLAUDE.md gate — no structural change; update item 3 to name MAIN/BWD/HOLDOUT the same way.

---

## PART 4 — Pass / Reject / Parked decision framework

### (a) Current state + problems
The rules are right but scattered (gate + 3 memories + 2 skills), two verdict vocabularies coexist,
and deploy bars disagree across docs (OOS ≥1.40 in signal-scanner vs >1.0 in
live-deployment-controller vs judge PF≥1.40@30). Consolidate to ONE tree + ONE bar table.

### (b) Re-settled spec — the tree

```
EVIDENCE IN
│
1. STRUCTURAL?  (any one ⇒ kill NOW — the only cheap death; no optimize owed)
   · flat-lot/escalation-off PF<1 while escalated PF>1  → "martingale WAS the edge"
   · uncapped ruin: no SL AND no depth cap (maxOpen≥8) AND geometric ladder — AFTER the 4-point
     martingale recheck (SL? capped steps? flat-lot edge? conditional adds?) — capped+SL+edge ≠ ruin
   · cracked / expired / locked-no-source (legal-ops DQ)
   · pure fill-artifact: M4 flips the sign across the whole surface / tight-TP fiction
   ⇒ DEAD-STRUCTURAL → EDGE_CATALOG dead pile + scorecard kill-reason.
     (Course-file rule: extract the entry CONCEPT before discarding the vehicle.)
│
2. else PARAMETRIC — no kill allowed yet.
   Right-home first (reversion→EURUSD/EURGBP/AUDNZD-class ranger · momentum→XAU/GBP-class trender;
   failing on the WRONG home ≠ dead). Run the Part-3 ladder ≥3 levers × ≥2 TF on the right home.
   │
   ├─ 2a. ceiling < 1.0 both-window on the RIGHT home, AND the LAST-OPTIMIZE round done
   │      (mandatory final round on an untouched lever, chosen by the diagnosis→lever table,
   │       IMMEDIATELY before pulling the trigger — even if much optimizing came before)
   │      ⇒ DEAD-OPTIMIZED. Cell-level by default; CONCEPT-level only when the right-home ceiling
   │        itself was proven. Default-param smoke can only ever close a CELL.
   │
   ├─ 2b. PF>1 anywhere, but under the deploy bars
   │      ⇒ BUILD-ON (the DEFAULT, not bench-and-forget):
   │        · expand symbol×TF (take EVERY home that clears the bar, pairwise corr<0.8)
   │        · mechanism tweak before accepting as-is (e.g. pending-limit entry — but pending-rescue
   │          applies ONLY to market-on-signal entries, never grid trigger-touch; doctrine 2026-07-17)
   │        · extract the entry mechanism into EDGE_CATALOG even if the EA never deploys
   │        idea good but can't pass ⇒ PARKED-VERIFY(user): tag + 3-line brief
   │        (what it is · which gate killed it · why still interesting). Never a silent death.
   │
   └─ 2c. passes the pre-registered bars ⇒ VALIDATED CANDIDATE → deploy funnel:
          plateau-center locked .set → both-window → sensitivity fan → holdout (or declare
          demo-forward-as-holdout when selection consumed BWD — the Boss_16 precedent) →
          MC (resize-first on any cap breach) → Model-4 if fill-sensitive → corr vs cohort
          ⇒ DEMO  (DEPLOYMENTS.csv row + judge criteria pre-registered AT ATTACH TIME)
          ⇒ ≥3 months demo forward, then judge ⇒ REAL MONEY
             (irreversible gate: Codex second opinion MANDATORY, no anchoring · plus Fable-advisor
              one-shot case-3 while quota lasts — if Fable unavailable, Opus-seat decides; the
              Codex leg is the non-optional one)
```

**Bar table (one number per transition — recommendation):**

| Transition | Bar |
|---|---|
| smoke pulse (PROCEED) | one cell naked PF ≥ 1.2 at sane n for the type (WATCH = 1.0–1.2) |
| optimize pass → candidate | **both-window: MAIN ≥ 1.2 AND BWD ≥ 1.0** (survive the opposite regime, not thrive — matches MacdDiv 1.91/1.04 & SMC×STO 1.50/1.24 precedents) + plateau-not-spike |
| holdout | **PF ≥ 1.2** at sane n ⇒ deploy track · 1.0–1.2 ⇒ BUILD-ON (JUMSTOCH precedent) · <1.0 ⇒ selection-fit, back to diagnosis |
| MC | ruin ≤2% (resize-first up to 10%) · PF-5th ≥1.0 |
| Model-4 (when due) | both-window PF ≥ 1.0 retained AND largest-loss does not blow out (no model-switch cliff) |
| demo → real money | ≥3 months · judge PF ≥ 1.40 at ≥ 30 trades · no pre-registered kill tripped |
| demo kill (default, per-EA overridable at attach) | eqDD > 12% · 3-mo PF < 0.8 at ≥ 15 trades |

**Canonical verdict vocabulary (retire everything else):**
`DEAD-STRUCTURAL · DEAD-OPTIMIZED · PARKED-VERIFY(user) · BUILD-ON · CANDIDATE · DEMO · LIVE`
(PASS/CONDITIONAL/ROBUST/MARGINAL/Mode-B etc. from the old skills are retired per Part 2 kill-list #1.)

**Where BUILD-ON ≠ DEPLOY applies:** everywhere between DEAD-OPTIMIZED and DEMO — the whole middle
band is buildable material. Deploy-gate and discard-gate are different questions. Precise discard
semantics (Codex consistency catch): **STRUCTURAL death = the only CHEAP discard** (immediate, no
optimize owed — concept extraction still allowed); **DEAD-OPTIMIZED = an EARNED terminal state**
(closes the cell — or the concept only when the right-home ceiling was proven — after the full
ladder + last-optimize round); everything else must not be discarded at all.

### (c) Docs to update
- CLAUDE.md VERDICT GATE — replace the prose blocks with this tree + bar table (keep the paid-for
  history lines as compressed "why" footnotes; the gate stays the owner).
- EA_SCORECARD_AND_REGISTRY.md — adopt the canonical vocabulary; map legacy verdicts once.
- Memories `feedback-last-optimize-before-verdict` / `feedback-buildon-pf-gt-1` /
  `feedback-optimize-before-killing-reversion` — unchanged (they're the source; the tree now encodes them).

---

## PART 5 — Handoff / routing between stages

### (a) Current state + problems
The strongest boundaries are already hook-enforced (verdict → scorecard+EA_MASTER_INDEX same commit;
deploy → DEPLOYMENTS.csv + check_state two-way validation). The weak ones: backtest→optimize
(nothing forces flat-lot + pre-registered bars into the order template) · optimize→validate (locked
.set discipline exists but plateau evidence format is ad hoc) · REJECT/PARK exits (EDGE_CATALOG
updates are habit, not a gate; the new B1_DATASET.csv-row-on-REVIEWED rule is easy to forget) ·
demo-attach (user-action queue accumulates loosely in PROJECT_STATE §7).

### (b) Re-settled spec — the routing table (one row per boundary)

| # | Boundary | Artifact handed over | Gate (must be green) | Who | Written where |
|---|---|---|---|---|---|
| 1 | idea → design | signal triage: class (mom/rev), home cell, smoke plan | not already in dead pile (EDGE_CATALOG + signal-landscape check) | Claude | taskboard order **with pre-registered bars + flat-lot checkbox** |
| 2 | design → code | Spec Card (new mechanism only) or order spec | L5 refused · L4 user sign-off | Claude | taskboard |
| 3 | code → backtest | .mq5 + .ex5 + baseline .set | compile 0/0 · reviewer PASS · tpl_regression CLEAN (core/) · run_tests PASS | Claude writes · Codex blind-audits money/risk | commit `[tag]` + taskboard row |
| 4 | backtest → optimize | smoke table (Model policy) + flat-lot result | pulse bar (PF≥1.2 cell) or reasoned WATCH | qwen/ZCode run · Claude judges | taskboard raw results |
| 5 | optimize → validate | **locked plateau-center .set** + surface evidence + both-window rows | plateau-not-spike · MAIN≥1.2/BWD≥1.0 | agents run · Claude reads surface | working sweep sets = `_mt5_auto/ab_sets/<order>/` (de-facto convention — PIPELINE.md to declare it the owner + naming) · **the locked validation .set** = the exact file later handed to vps-deploy-ops (immutable once verdict written) · evidence = `_triage/ORDERxxx_*_VERDICT.md` |
| 6 | validate → verdict | holdout + MC + year-split + M4 (if due) | pre-registered bars answered | **Claude only** (VERDICT GATE) | scorecard verdict + EA_MASTER_INDEX (same commit) + EDGE_CATALOG mechanism entry + **B1_DATASET.csv row in the REVIEWED commit** |
| 7 | verdict → portfolio | trade list / monthly returns | corr ladder ≤0.40 / 0.40–0.60 reduce / >0.60 reduce-not-cut / same-EA <0.8 | Claude | scorecard + corr note |
| 8 | portfolio → deploy | vps bundle (.ex5 + locked .set + README) + judge criteria | **DEPLOYMENTS.csv row FIRST** · check_state green (magic) · S1–S7 checklist | Claude stages · **user attaches** | DEPLOYMENTS.csv → DEMO_DEPLOYMENT_PLAN (context) → dashboard (checker-forced) |
| 9 | demo → live | judge report (ea-live-monitor attribution) | 3-mo + judge bars + Fable one-shot + Codex 2nd opinion | **user decides** | Decision log + DEPLOYMENTS.csv |
| X | ANY → DEAD / PARKED exit | verdict + evidence file | STRUCTURAL vs PARAMETRIC class named (gate item 4) | Claude | scorecard kill-reason + EDGE_CATALOG (dead pile or reusable-lever entry) + PARKED-VERIFY 3-line user brief · memory ONLY for cross-session doctrine, never per-EA facts |

**Two cheap enforcement upgrades (do these; skip building more hooks for now):**
1. **Order template gains two mandatory fields:** `pre-registered bars:` and `flat-lot probe:
   done/N-A` — the taskboard order is the natural artifact both currently live outside of.
2. **Row X becomes a checklist inside the VERDICT GATE** ("before writing any verdict: scorecard? ·
   index same commit? · EDGE_CATALOG? · B1 row? · user brief if PARKED-VERIFY?") — the gate is
   already the one text every session must read; putting the write-list there costs nothing.
   (The memory-control OS already covers order lifecycle integrity — don't duplicate it.)

### (c) Docs to update
- `docs/PIPELINE.md` (new, from Part 2) — owner of this table.
- AGENT_TASKBOARD order template — add the two mandatory fields.
- CLAUDE.md VERDICT GATE — append the Row-X write-checklist (5 lines).

---

## Consolidated open-question answers (one line each)
1. **Is LabCore the right decomposition?** Yes — keep it; fix seams (coverage declarations, exit
   ownership, per-EA quarantine), don't redesign.
2. **How do new confirm layers plug in?** One StackConfirm enum + one module file, add-time by
   default, judged by expectancy-per-trade, admitted to core/ only after a probe validates them.
3. **One pipeline or two?** One (the practice pipeline). Report-analyzer/robustness-validator demote
   to calculators; their vocab retires.
4. **When is Model 4 mandatory?** Grid/DCA/basket/multi-position, pending ladders, TP<20pip, or any
   model-switch cliff in largest-loss — before any verdict or deploy. Model 2 = zero-trade preflight
   + kill-only, never ranks/selects (coarse sweeps = Model 1+); for grids not evidence at all.
5. **How much optimizing is "enough"?** Pre-registered bars answered; ≥3 levers × ≥2 TF before any
   death; last-optimize round immediately before any PARKED/REJECT trigger; ~100–150 runs is the
   normal full-funnel budget per EA×home.
6. **Deploy bars?** MAIN≥1.2 + BWD≥1.0 + holdout≥1.2 + MC ruin≤2% (resize-first) + M4-if-due +
   corr ladder; real money adds 3-mo demo + PF≥1.40@≥30.
7. **Where does build-on ≠ deploy live?** The whole band between DEAD-OPTIMIZED and DEMO; only
   STRUCTURAL discards.
