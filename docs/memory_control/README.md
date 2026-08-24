# docs/memory_control/ — Memory-Controlled OS build (status + file map)

> **Generated audit + coordination machinery — NOT a new authority.** Nothing here owns a fact,
> verdict, or deployment decision; those stay with `AGENT_TASKBOARD.md` / `EA_SCORECARD_AND_REGISTRY.md`
> / `PROJECT_STATE.md` / `portfolio/DEPLOYMENTS.csv`.
>
> **Design source (single):** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20 @ `4eb839d`.
> **B0_CUTOFF_SHA:** `4eb839df09b1911cec2de18ec4a2df51cf766606`

## Build status — 2026-08-24: memory-control core complete; B1 running log open; MVP-2 gate passed

| Piece | Contract / order | Status | Key commit |
|---|---|---|---|
| MVP-0 execution harness (`run_batch.ps1`) | Contract B / ORDER-100 | ✅ REVIEWED | — |
| MVP-3 active/archive + generated index + fail-closed hook | Contract C0/C1 / ORDER-101,102,103 | ✅ REVIEWED | `c0f7b0d` |
| MVP-1-lite experiment event log + evidence manifest | Contract D / ORDER-105 | ✅ REVIEWED (8 blind rounds) | `0e13699` |
| B0 baseline + fact→owner map | Contract A / ORDER-099 | ✅ REVIEWED | — |
| **B1 observation window** (measures whether MVP helped; gates MVP-2) | ORDER-115 | 🟢 **OPEN** since 2026-07-17 | `dc566d77` |
| **MVP-2 Context Packet generator** | KOS gap-close 2026-08-24 | 🟢 **IMPLEMENTED — B1 GATE PASSED; transient/read-only constraints apply** | `501112db` |

**The event log is LIVE:** first real experiment = ORDER-091C-D1g (`exp_93d9457a`), full 8-event chain
committed. Do NOT backfill except the 3 approved canaries (ST03 · Boss_16 · ORDER-095/Boss_14), lazily.

## What each session must keep doing (standing duties)

1. **Order closes → append one row to `B1_DATASET.csv`** in the same commit (defs = `B1_COHORT.md`;
   unobserved values = `NOT_RECORDED`, never a guessed 0). B1 is a continuous running log; do not stop at 20 rows.
2. **Experiment-shaped order → emit the event chain** per `EVENT_LOG_ADOPTION.md`.
3. **MVP-2 Context Packet** may now be generated when bounded context is useful because the B1 gate fired. Packets are transient/read-only, never committed, and never replace mandatory canonical documents for money/verdict decisions.

## File map

| file | what it is |
|---|---|
| `EVENT_LOG_ADOPTION.md` | **how to use the event log** on a new experiment (commands + dogfood gotchas). Rule owner = the schemas. |
| `B1_COHORT.md` | B1 register + eligibility/metric protocol + the MVP-2 trigger gate. |
| `B1_DATASET.csv` | append-only B1 rows (header byte-identical to `B0_DATASET.csv`). |
| `experiment_events/` | the live event log: `events-YYYY-MM.jsonl`, `evidence-manifest.jsonl`, `schema/*.json`. |
| `FACT_OWNER_MAP.md` | fact → canonical owner / permitted writers / generated consumers. Base = §20.7 + `AGENTS.md` §2. |
| `../research/FACTORY_VNEXT_DESIGN_DRAFT.md` | design-frozen, non-canonical Factory vNext implementation source; current Factory authority remains elsewhere until explicit policy migration. |
| `../research/FACTORY_VNEXT_MVP_PILOT_CONTRACT.md` | frozen non-authoritative sidecar contract for the first offline Factory vNext pilot. |
| `B0_DATASET.csv` / `B0_REPORT.md` | Contract-A baseline: 20 terminal orders @ cutoff + selection/metric rules. |
| `ARCHIVE_INDEX.md` / `ARCHIVE_MANIFEST.csv` / `RECONCILE_EXCEPTIONS.md` | MVP-3 archive machinery (generated/checked by `check_taskboard_archive.ps1`). |
| `CODEX_ORDER10*_*.md` | build/review transcripts for Contracts C1-ENFORCE (103) and D (105) — history, not authority. |

## Reproduce B0

## Reproduce

Everything reads from the **pinned SHA**, never the live (trimmed) taskboard:

```
git show 4eb839df09b1911cec2de18ec4a2df51cf766606:AGENT_TASKBOARD.md
```

Line anchors in `B0_DATASET.csv` are line numbers **in that pinned blob**. Evidence commits are all
ancestors of the cutoff. See `B0_REPORT.md` for the exact selection/classification rules.

## Hard rules honored (§20.3 B0 reality clause)

- Metrics never recorded when the work ran (onboarding time, lead-attention hours, per-order context
  incidents) = `NOT_RECORDED`. **Never 0, never reconstructed from memory.**
- Only `context_rework` and `wrong_order_file_scope` are counted, because they are recoverable from
  git + taskboard history.
- **This map decides no owner conflict.** If two owners were found for one fact, the order would be
  marked BLOCKED and the conflict resolved by Opus separately — a worker never picks. (Found: 0 conflicts.)
