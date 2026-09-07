# EA_LAB Workflow Concept Discussion Snapshot — 2026-09-07

Status: `DISCUSSION_SNAPSHOT / NON_AUTHORITATIVE / DO_NOT_USE_AS_POLICY`
Base ref when captured: `8eb953d36f8e92b20251e50dafab90c6e5d7f126`
Purpose: preserve the owner/assistant workflow concept discussed before repository-hygiene and Template-UX changes so the concept can be revisited after those changes.

This file does not override `PROJECT_STATE.md`, `AGENTS.md`, the active taskboard, `EA_RND_PROTOCOL.md`, `CLAUDE.md`, or any other canonical owner. Any conflict is resolved in favor of the current pushed canonical owner.

## 1. Owner-facing system concept

The intended operating model is one Control Tower coordinating bounded workers and deterministic evidence tools:

```text
OWNER / BOSS
  -> ChatGPT Main Control Tower
  -> objective / scope / acceptance / dependency DAG
  -> bounded workers + deterministic tools
  -> exact build/config identity
  -> MT5/tester/parser evidence
  -> analysis/report/diagram
  -> required independent review
  -> clean integration + impacted checks
  -> pushed origin/master = durable project truth
```

The owner should not need to manually coordinate each tool or inspect raw technical logs for routine work.
## 2. EA development and research conveyor

```text
Idea / source
  -> mechanism understanding
  -> freeze one prospective hypothesis
  -> build / compile / mechanics tests
  -> Model-1 fixed-config baseline
  -> broad Symbol x TF / portability evidence
  -> mechanism / parent-child tests
  -> qualified survivor only
  -> preregister optimization semantics + ranges
  -> WIDE / COARSE landscape
  -> REGION_SELECT
  -> MEDIUM / FINE / neighbour stability
  -> lock stable center
  -> BWD / year / regime robustness
  -> mandatory frozen-config Model-4 MAIN+BWD
  -> direct-question sensitivity / MC when required
  -> HOLDOUT late, when authorized
  -> Candidate dossier
  -> owner-approved DEMO
  -> forward monitoring
  -> owner LIVE decision
```

Corrections that must remain explicit: Model-2/Open Prices and Math Calculations are diagnostic only; BWD is falsification/robustness and not a tuning surface; HOLDOUT is protected; Model-4 MAIN+BWD is mandatory before new Candidate eligibility; deployment/runtime and LIVE remain owner hard stops.
## 3. Tool-role concept

- ChatGPT: single Main Control Tower; architecture, contracts, interpretation, dispatch, integration decisions inside approved scope.
- GitHub `origin/master`: canonical durable truth.
- Codex Primary: bounded implementation/test/integration author.
- Hermes: mechanical EA evidence factory; no strategy/verdict/risk/runtime authority.
- MT5 Strategy Tester: numerical evidence engine; Model-1 minimum for performance research, Model-4 fidelity before Candidate.
- EA Template / Boss V2: one main production mold with shared modules and per-entry builds.
- Factory/Profile/Universe sidecars: deterministic identity/config/parameter projection; fail closed; no authority by presentation alone.
- Long Job tooling: batch execution/resume/evidence identity, separating execution-complete from accepted/reviewed.
- Second Brain: research-only reusable knowledge and negative evidence.
- Report/Diagram systems: decision aids and continuity; diagrams remain visual-only.
- Gemini: different-family review only for scopes that have actually been qualified.
- DailyMonitor / RuntimeIdentity / SafeProjection: monitoring evidence pipeline, not automatic trading or deployment authority.
- Mobile Report Hub / PWA: presentation/delivery layer only; it must not become another source of truth.

## 4. EA Template concept discussed

The desired owner-facing model is:

```text
shared mold: MM + lot progression + exit + SL + stack/grid/DCA + hedge + recovery + safety
  x entry logic
  x symbol / timeframe
  x frozen or optimized parameter profile
  = one EA / variant with traceable evidence lineage
```
The mold should share reusable mechanics, but should not pretend every entry uses every shared module identically. Strategy-specific ownership or ignored inputs must be visible.

Target usability after cleanup:

1. Owner describes the strategy/mechanism in plain language.
2. System selects or scaffolds the correct Template entry and allowed components.
3. Before any run, show `requested -> effective -> ignored/locked -> reason` in plain language.
4. Generate exact build/set/config identity automatically.
5. Run the approved evidence stage without the owner coordinating scripts manually.
6. Return one owner-facing result: progress, decision, blocker, evidence identity, and next authorized action.
7. Preserve full machine evidence underneath for audit/review.

Do not solve usability by weakening fail-closed behavior, evidence requirements, or owner hard stops.

## 5. Repository-hygiene concept to revisit

The repository currently contains substantial historical/stale material. Before destructive cleanup, classify by reference/dependency and authority:
`KEEP | ARCHIVE | DELETE_CANDIDATE | UNKNOWN`.
Archive/reversible consolidation comes before deletion. Destructive non-fixture cleanup requires owner approval. Cleanup must preserve accepted evidence/provenance and must reduce startup confusion, not rewrite history.

## 6. Monitoring concept to revisit

The owner should not need to inspect raw logs. Preferred owner experience is one simple health surface plus exception alerts, with drill-down only when needed:
`overall health + freshness + accounts observed + critical blockers + changed-since-last-check`.
The current implementation state must be rechecked from actual runtime before redesign; PWA/Telegram presentation must not be treated as working merely because files exist.

## 7. Open discussion after cleanup

- Finalize Template owner-facing builder/recipe UX without creating a second configuration truth.
- Decide which legacy files are archive vs delete candidates.
- Prove one real Template EA end-to-end through build -> evidence -> report before calling the factory easy to use.
- Simplify monitoring into one owner-facing status surface and a separate exception notification route.
- Redraw the workflow diagram only after these concepts are frozen.