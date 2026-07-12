# B0 HISTORICAL BASELINE — REPORT (ORDER-099 / Contract A)

> Generated audit output. Source of truth = `AGENT_TASKBOARD.md` **@ `4eb839d`** (pinned).
> Design source = `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20 @ `4eb839d`.
> `B0_CUTOFF_SHA = 4eb839df09b1911cec2de18ec4a2df51cf766606`.

## 1. Purpose

Baseline the workflow **before** any memory-control component (MVP-0/3/1) changes it, so B1 (the 20
orders after MVP-3 + MVP-1-lite pass acceptance) can be compared on identical definitions. Per §20.3,
B0 does **not** gate MVP-2 — it only measures whether MVP-0/3/1 actually improved things.

## 2. Order universe

`git show 4eb839d:AGENT_TASKBOARD.md | grep -cE '^## ORDER-'` → **110** header lines.

## 3. Selection rule (deterministic, machine-checkable)

**Cohort = the 20 most-recently-closed *eligible terminal* orders at cutoff.** This is the cohort
immediately preceding the change, which makes the B0↔B1 before/after comparison fair.

An order is **eligible terminal** iff its status string:
- **contains** one of `DONE` / `REVIEWED` / `CLOSED`, **AND**
- does **not** contain `OPEN` / `CLAIMED` / `IN-PROGRESS` / `WAITING` / `SKIPPED`, **AND**
- is **not** an umbrella parent (a CAMPAIGN / MASTER-PLAN row whose execution happens only in child
  orders), **AND**
- is a real order header, not an annotation line (`... NOTE`, `... AMENDMENT`, `... PROCESSING`,
  `... REVIEW note`).

**Ordering:** close date descending; within a date, by position in the pinned blob (later = more
recent). The cutoff day's last full working day (2026-07-11) yields 18 eligible terminal orders; the
2 remaining slots are filled by the two latest-closed 2026-07-10 orders (ORDER-089, ORDER-090 — the
ZSCORE funnel that immediately preceded the 07-11 work).

## 4. Included cohort (20) — see `B0_DATASET.csv`

By class: **INFRA/tool = 6** (083B, 083C, 092, 093, 094, 096C) · **EA-CANDIDATE/bench = 7** (078,
091C-D1, -D1b, -D1c, -D1e, -D1f, 095-A) · **EA-REJECT/dead = 5** (096A, 096B, 091B, 091B-phase2, 090)
· **EA-PARK = 2** (085B, 089). Total 20 distinct IDs, no duplicates.

## 5. Excluded (explicit)

| Reason | Orders |
|---|---|
| `SKIPPED` | ORDER-003, ORDER-009 |
| Umbrella parent (execution only in children) | ORDER-036 (split to its own batch board), ORDER-091 (MASTER PLAN), ORDER-095 (CAMPAIGN parent — child 095-A **is** included) |
| Non-terminal at cutoff (`OPEN`) | ORDER-071, ORDER-073(Ph2), ORDER-076, ORDER-080, ORDER-082, ORDER-091C-D1d, ORDER-097(funnel OPEN; build DONE) |
| Non-terminal (`CLAIMED` / `IN-PROGRESS`) | ORDER-064, ORDER-072, ORDER-079, ORDER-084 |
| Non-terminal (`WAITING-USER` / deployment-ongoing) | ORDER-045, ORDER-055 |
| Annotation lines, not orders | ORDER-035-REVIEW note, ORDER-082 AMENDMENT, ORDER-075/078 NOTE, ORDER-091C-D1c PROCESSING |
| Eligible terminal but **older than the 20 most-recent** (not selected by the cohort rule) | all remaining REVIEWED/DONE/CLOSED orders ≤ ORDER-088 and the 07-09/07-10 tail not in the top-20 (e.g. 068–077, 083, 085, 086, 087, 088, 001–067 …) |

The last row is the reason the cohort is a **window**, not "every closed order": there are ~70+
eligible terminal orders; B0 deliberately samples the 20 nearest the cutoff.

## 6. Metric method (§20.3 B0 reality clause)

| Field | Method | Value |
|---|---|---|
| `onboarding_time` | never instrumented when the work ran | `NOT_RECORDED` (all rows) |
| `context_incident` | never logged per-order | `NOT_RECORDED` (all rows) |
| `lead_attention_hours` | never tracked per-order | `NOT_RECORDED` (all rows) |
| `context_rework` | count of cohort orders re-run because of wrong **context/authority** (recoverable from git + taskboard) | **0** — the JUMSTOCH D1→D1f chain is *planned build-on expansion per doctrine, not rework*; no cohort order was redone due to a context/authority error |
| `wrong_order_file_scope` | count of cohort orders that touched the wrong order/file/scope (recoverable from git + taskboard) | **0** within the cohort |

**System-level note (outside cohort metrics, but recoverable and worth recording):** two ORDER-ID
**collisions** occurred adjacent to this window — `042→043` (collided with DealsExporter) and
`096→097` (collided with the WOBR CAMPAIGN). Neither affected a cohort order's result, so cohort
`wrong_order_file_scope = 0`, but the collision phenomenon is exactly the class of failure a canonical
active/archive board (Contract C) is meant to remove. Recorded here, not silently dropped.

Per the reality clause: the `NOT_RECORDED` fields are **not** reconstructed from memory and are **not**
zero. B0↔B1 comparison may only use fields present on both sides — at B0 that is `context_rework` and
`wrong_order_file_scope` (and any metric B1 instruments prospectively).

## 7. Evidence traceability

Requirement: ≥5/20 traces reach canonical evidence. **Achieved 16/20** with a direct evidence commit
(ancestor of cutoff) in `B0_DATASET.csv`. The other 4 (096A/096B/096C, 091B-phase2) anchor to the
WOBR closeout commits (`3acc39c2` merge / `87e83792`). Every row also carries its line anchor in the
pinned blob.

Sample deep traces:
- ORDER-093 → `c910765c` → `portfolio/DEPLOYMENTS.csv` (29 rows) + `check_state.ps1` 13-check rewrite.
- ORDER-092 → `f8a7eb9f` → floating-risk exporters + `live_dashboard.ps1` FLOATING RISK panel.
- ORDER-094 → `45df678b` → 4 cages fail-closed (CODEX-AUDIT Layer D closed).
- ORDER-091C-D1f → `0d85a525` → JUMSTOCH MT5 OOS (EURGBP H1 / NZDUSD H4) reports.
- ORDER-078 → `9e1d1acf` → Boss_16 corr check (0.077 vs BRK_FULLSPAN).

## 8. Acceptance self-check (ORDER-099)

- [x] 3 artifacts under `docs/memory_control/` (this report, `B0_DATASET.csv`, `FACT_OWNER_MAP.md`, `README.md`)
- [x] 20 distinct eligible orders, no duplicates, no umbrella-only / SKIPPED / no-execution
- [x] unresolved owner conflicts = 0 (see `FACT_OWNER_MAP.md` conflict scan)
- [x] ≥5/20 traces to canonical evidence (16/20 with commit anchors)
- [x] `context_rework` / `wrong_order_file_scope` reproducible from raw rows (rule in §3/§6 above)
- [x] all missing onboarding / lead-hour / context-incident values = `NOT_RECORDED` (no fake 0, no memory reconstruction)
- [x] canonical docs unchanged except the bootstrap pointer/order lifecycle (B0 execution is its own commit)

## 9. Reproducibility recipe

```
# universe
git show 4eb839d:AGENT_TASKBOARD.md | grep -nE '^## ORDER-'
# a row's evidence
git log 4eb839d --oneline --grep='ORDER-<id>\b'
# line anchors are line numbers in the pinned blob above
```
Same cutoff SHA + same rules → same 20 rows. The live (post-cleanup) taskboard is irrelevant to B0.
