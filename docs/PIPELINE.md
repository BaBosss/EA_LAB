# PIPELINE.md — the ONE canonical EA pipeline (idea → live)

> **canonical entry = `PROJECT_STATE.md`.** This file owns exactly ONE fact: **stage routing** — the flow
> between stages and the handoff gate at each boundary. Each skill owns its *stage mechanics*; PIPELINE.md
> owns the *routing between them*. (1-fact-1-owner anti-drift: this fact previously had no owner, so it forked
> into two contradictory pipelines across the skill docs — that fork is now closed.)
>
> Established 2026-07-18 from `_triage/FABLE_RESETTLE_FRAMEWORK_2026-07-18.md` Part 2+5 (user-approved).
> Verdict tree + bar numbers = `CLAUDE.md` VERDICT GATE. Optimize method = skill `backtest-optimize-rigor`.

## The flow (this is what actually runs — docs match practice, not vice versa)

```
IDEA
 └─ signal-scanner: classify momentum/reversion → pick RIGHT HOME (reversion→ranger · momentum→trender)
    naked smoke (M2 = zero-trade filter only → M1 numbers) · flat-lot probe if any escalation
    ├─ DEAD (structural, or right-home optimize-ceiling already known) → EDGE_CATALOG dead pile. STOP.
    └─ PROCEED / WATCH ↓
DESIGN  (only when the MECHANISM or risk shape is new): strategy-and-risk → Spec Card
        (L5 refuse · L4 needs user sign-off). Entry-on-chassis (the default case): skip the Spec Card —
        write a taskboard order with pre-registered bars instead.
BUILD   chassis-first (Boss V2); standalone needs a stated reason (speed alone is no longer one).
        Claude seat writes the code (ROUTING FLIP 2026-07-16) · Codex = blind auditor on money/risk logic.
        CAGE (hard, in order): mql-code-reviewer PASS (on SOURCE, before compile) → compile 0/0 →
        tpl_regression CLEAN (if core/ touched) → run_tests PASS. No stage skipped even under quota pressure.
TEST + OPTIMIZE   backtest-optimize-rigor LADDER Step 0-9 (owns the method).
VALIDATE          both-window → plateau fan → holdout → MC → Model-4 if fill-sensitive → year-split.
VERDICT           CLAUDE.md VERDICT GATE, Claude/user only (owns the tree + bar table).
PORTFOLIO         corr ladder — ≤0.40 additive / 0.40–0.60 reduce-lot / >0.60 reduce-not-cut / same-EA <0.8.
DEPLOY            DEPLOYMENTS.csv row FIRST → live-deployment-controller GATE (judge criteria + kill-switch
                  pre-registered) → vps-deploy-ops SHIPPING (bundle + S1–S7 silent-stop checklist) → USER attaches.
OPERATE           ea-live-monitor every 1–2 weeks → judge date.
```

## Routing table — one row per boundary (owner of these rows = this file)

| # | Boundary | Artifact handed over | Gate (must be green) | Who | Written where |
|---|---|---|---|---|---|
| 1 | idea → design | signal triage: class (mom/rev), home cell, smoke plan | not already in dead pile (EDGE_CATALOG + signal-landscape check) | Claude | taskboard order **with pre-registered bars + flat-lot checkbox** |
| 2 | design → code | Spec Card (new mechanism only) or order spec | L5 refused · L4 user sign-off | Claude | taskboard |
| 3 | code → backtest | .mq5 + .ex5 + baseline .set | compile 0/0 · **reviewer PASS (on source, before compile)** · tpl_regression CLEAN (core/) · run_tests PASS | Claude writes · Codex blind-audits money/risk | commit `[tag]` + taskboard row |
| 4 | backtest → optimize | smoke table (Model policy) + flat-lot result | pulse bar (PF≥1.2 cell) or reasoned WATCH | qwen/ZCode run · Claude judges | taskboard raw results |
| 5 | optimize → validate | **locked plateau-center .set** + surface evidence + both-window rows | plateau-not-spike · MAIN≥1.2/BWD≥1.0 | agents run · Claude reads surface | working sweep sets = `_mt5_auto/ab_sets/<order>/` · the **locked validation .set** = the exact file later handed to vps-deploy-ops (immutable once verdict written) · evidence = `_triage/ORDERxxx_*_VERDICT.md` |
| 6 | validate → verdict | holdout + MC + year-split + M4 (if due) | pre-registered bars answered | **Claude only** (VERDICT GATE) | scorecard verdict + EA_MASTER_INDEX (same commit) + EDGE_CATALOG mechanism entry + **B1_DATASET.csv row in the REVIEWED commit** |
| 7 | verdict → portfolio | trade list / monthly returns | corr ladder ≤0.40 / 0.40–0.60 reduce / >0.60 reduce-not-cut / same-EA <0.8 | Claude | scorecard + corr note |
| 8 | portfolio → deploy | vps bundle (.ex5 + locked .set + README) + judge criteria | **DEPLOYMENTS.csv row FIRST** · check_state green (magic) · S1–S7 checklist | Claude stages · **user attaches** | DEPLOYMENTS.csv → DEMO_DEPLOYMENT_PLAN (context) → dashboard (checker-forced) |
| 9 | demo → live | judge report (ea-live-monitor attribution) | 3-mo + judge bars + Fable one-shot + Codex 2nd opinion | **user decides** | Decision log + DEPLOYMENTS.csv |
| X | ANY → DEAD / PARKED exit | verdict + evidence file | STRUCTURAL vs PARAMETRIC class named (gate item 1) | Claude | scorecard kill-reason + EDGE_CATALOG (dead pile or reusable-lever) + PARKED-VERIFY 3-line user brief · memory ONLY for cross-session doctrine, never per-EA facts |

## Skill roster (each owns its stage mechanics; next-stage per this table)

| Stage | Skill | Next stage |
|---|---|---|
| triage | `signal-scanner` | design (new mechanism) or straight to build (entry-on-chassis) |
| design | `strategy-and-risk` → Spec Card | `mql-code-generator` |
| code | `mql-code-generator` → `mql-code-reviewer` (PASS before compile) | `vps-deploy`-compile / backtest |
| test+optimize | `backtest-optimize-rigor` (LADDER owner) | validate |
| verdict | CLAUDE.md VERDICT GATE | portfolio |
| portfolio | `portfolio-selector` (corr ladder) | deploy |
| deploy gate | `live-deployment-controller` (judge criteria + kill-switch) | `vps-deploy-ops` |
| ship | `vps-deploy-ops` (bundle + S1–S7) | user attaches → operate |
| operate | `ea-live-monitor` | judge date |

**Demoted to calculators (NOT pipeline stages, vocab retired):** `backtest-report-analyzer` +
`robustness-validator`. Their numeric content (MC bars, WFA windows) folds into the LADDER; their verdict
vocabulary (PASS/CONDITIONAL/ROBUST/MARGINAL/Mode-B) is **retired** — the VERDICT GATE supersedes it. One
funnel, one vocabulary: `DEAD-STRUCTURAL · DEAD-OPTIMIZED · PARKED-VERIFY(user) · BUILD-ON · CANDIDATE · DEMO · LIVE`.

## Delegation lanes
qwen = batch/parse · Sonnet = mechanical-with-cage · Opus-seat = judgment/verdict/new-risk-logic ·
Codex = blind audit + second opinion on expensive/irreversible only · ZCode = 1 heavy batch/day ·
Fable = 4 reserved one-shot cases via `fable-advisor` while quota lasts (fallback = Opus-seat decides +
mandatory Codex second opinion). See `AGENTS.md` §1.5.
