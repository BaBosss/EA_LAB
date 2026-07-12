# docs/memory_control/ — B0 baseline + ownership audit (ORDER-099 / Contract A)

> **Generated audit output — NOT a new authority.** These files do not own any fact, verdict, or
> deployment decision. They describe the state of the taskboard/ownership at a pinned point in time so
> MVP-0/3/1 can later be measured against a baseline (B0 vs B1).
>
> **Design source:** `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20 @ `4eb839d` (Contract A = §20.8).
> **B0_CUTOFF_SHA:** `4eb839df09b1911cec2de18ec4a2df51cf766606`
> **Produced by:** ORDER-099 (Opus-seat), 2026-07-12.

## Files

| file | what it is |
|---|---|
| `FACT_OWNER_MAP.md` | fact → canonical owner / permitted writers / generated consumers / freshness check. Base = §20.7 + `AGENTS.md` §2. |
| `B0_DATASET.csv` | 20 terminal orders @ cutoff, machine-checkable. Metrics never logged historically = `NOT_RECORDED`. |
| `B0_REPORT.md` | selection rule, inclusion/exclusion list, metric method, and the reproducibility recipe. |

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
