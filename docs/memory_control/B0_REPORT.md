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
091C-D1, -D1b, -D1c, -D1e, -D1f, 095-A) · **EA-REJECT/dead = 4** (096A, 096B, 091B, 090)
· **EA-PARK = 2** (085B, 089) · **RESEARCH = 1** (081). Total **20 distinct canonical ORDER IDs**, no duplicates.

The 20 = **18 eligible terminal orders closed 2026-07-11** (078, 081, 083B, 083C, 085B, 091B,
091C-D1/-D1b/-D1c/-D1e/-D1f, 092, 093, 094, 095-A, 096A, 096B, 096C) **+ the 2 latest-closed
2026-07-10 orders** (089, 090).

> **REWORK fixes (2026-07-12, two blind Codex review rounds):**
> - **Round 1:** the first cut listed `ORDER-091B` *and* `ORDER-091B เฟส 2` as two rows, but both
>   headers carry the **same canonical ID `ORDER-091B`** (phase 1 + phase 2 of one order at pinned lines
>   4113/4207) = 1 distinct order, not 2. Also fixed two mis-attributed evidence commits (see §7).
> - **Round 2:** the round-1 patch wrongly back-filled the freed slot with `ORDER-088` (2026-07-10).
>   That was still wrong: **`ORDER-081`** (Crypto lane feasibility, `DONE` 2026-07-11) is an eligible
>   terminal 07-11 order that had been overlooked, so it belongs in the "18 from 07-11". With 081
>   restored, `ORDER-088` is the **21st** most-recent and is excluded. Also fixed the `ORDER-085B`
>   review commit (see §7) and the §9 query mapping.

## 5. Excluded (explicit)

| Reason | Orders |
|---|---|
| `SKIPPED` | ORDER-003, ORDER-009 |
| Umbrella parent (execution only in children) | ORDER-036 (split to its own batch board), ORDER-091 (MASTER PLAN), ORDER-095 (CAMPAIGN parent — child 095-A **is** included) |
| Non-terminal at cutoff (`OPEN`) | ORDER-071, ORDER-073(Ph2), ORDER-076, ORDER-080, ORDER-082, ORDER-091C-D1d, ORDER-097(funnel OPEN; build DONE) |
| Non-terminal (`CLAIMED` / `IN-PROGRESS`) | ORDER-064, ORDER-072, ORDER-079, ORDER-084 |
| Non-terminal (`WAITING-USER` / deployment-ongoing) | ORDER-045, ORDER-055 |
| Annotation lines, not orders | ORDER-035-REVIEW note, ORDER-082 AMENDMENT, ORDER-075/078 NOTE, ORDER-091C-D1c PROCESSING |
| **Duplicate canonical ID (phase of an included order)** | `ORDER-091B เฟส 2` — same canonical ID as the included `ORDER-091B`; a phase is not a new distinct order (fix after Codex review) |
| Eligible terminal but **older than the 20 most-recent** (not selected by the cohort rule) | all remaining REVIEWED/DONE/CLOSED orders older than the window — including **`ORDER-088`** (DONE 2026-07-10), which is the **21st** most-recent (the two 07-10 slots go to the later 089/090); plus e.g. 068–077, 083, 085, 086, 087, 001–067 … |

The last row is the reason the cohort is a **window**, not "every closed order": there are ~70+
eligible terminal orders; B0 deliberately samples the 20 nearest the cutoff.

## 6. Metric method (§20.3 B0 reality clause)

| Field | Method | Value |
|---|---|---|
| `onboarding_time` | never instrumented when the work ran | `NOT_RECORDED` (all rows) |
| `context_incident` | never logged per-order | `NOT_RECORDED` (all rows) |
| `lead_attention_hours` | never tracked per-order | `NOT_RECORDED` (all rows) |
| `context_rework` | **reproducible query** (see §9): count cohort blocks whose text matches a rework/redo-due-to-context marker | **0** (query returns 0 hits) — the JUMSTOCH D1→D1f chain is *planned build-on expansion per doctrine, not rework* |
| `wrong_order_file_scope` | **reproducible query** (see §9): count cohort blocks whose text matches an ID-collision/renumber/wrong-scope marker | **0** (query returns 0 hits within the cohort) |

> These two are the only counted (non-`NOT_RECORDED`) fields, so per §20.8 acceptance they must be
> reproducible by a third party. The exact queries are in §9 — a reviewer runs them over the same 20
> cohort blocks at the pinned SHA and gets the same 0/0. A 0 here is a *query result*, not a judgment.

**System-level note (outside cohort metrics, but recoverable and worth recording):** two ORDER-ID
**collisions** occurred adjacent to this window — `042→043` (collided with DealsExporter) and
`096→097` (collided with the WOBR CAMPAIGN). Neither affected a cohort order's result, so cohort
`wrong_order_file_scope = 0`, but the collision phenomenon is exactly the class of failure a canonical
active/archive board (Contract C) is meant to remove. Recorded here, not silently dropped.

Per the reality clause: the `NOT_RECORDED` fields are **not** reconstructed from memory and are **not**
zero. B0↔B1 comparison may only use fields present on both sides — at B0 that is `context_rework` and
`wrong_order_file_scope` (and any metric B1 instruments prospectively).

## 7. Evidence traceability

Requirement: ≥5/20 traces reach canonical evidence. **Achieved 17/20** with a direct evidence commit
(ancestor of cutoff) in `B0_DATASET.csv`. The other 3 (096A/096B/096C) anchor to the WOBR closeout
merge (`3acc39c2`). Every row also carries its line anchor in the pinned blob.

> **REWORK fix (2026-07-12, Codex review):** two evidence commits were mis-attributed in the first cut
> and are corrected in `B0_DATASET.csv` — `ORDER-078` pointed at `9e1d1acf` (a corr-check commit; that
> was actually 085B-adjacent), now `00392e30` (`[tag] ORDER-078 done`, review `b93e4b9d`); `ORDER-085B`
> pointed at `9e1d1acf`, now `b5b1b429` (`[tag] ORDER-085B done`). **Round 2:** the 085B review commit
> was `e481e00f`, but that is the `ORDER-085` review (which *opened* 085B); the real `ORDER-085B` review
> is `ee0ae804` ("REVIEW 085B: BWD FAIL PF 0.88 … SuperTrend stays bench"). Corrected in the CSV.

Sample deep traces:
- ORDER-093 → `c910765c` → `portfolio/DEPLOYMENTS.csv` (29 rows) + `check_state.ps1` 13-check rewrite.
- ORDER-092 → `f8a7eb9f` → floating-risk exporters + `live_dashboard.ps1` FLOATING RISK panel.
- ORDER-094 → `45df678b` → 4 cages fail-closed (CODEX-AUDIT Layer D closed).
- ORDER-091C-D1f → `0d85a525` → JUMSTOCH MT5 OOS (EURGBP H1 / NZDUSD H4) reports.
- ORDER-078 → `00392e30` → Boss_16 BUY 21/30 validation funnel (4/4 steps, 0 stop-bars).

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

# wrong_order_file_scope query (ID collision / renumber / wrong scope):
git show 4eb839d:AGENT_TASKBOARD.md | grep -nE 'renumbered|ชนกับ|wrong (order|file|scope)'
#   6 hits; mapping each to the nearest preceding "## ORDER-" header (verified by running the query):
#     L2089 -> ORDER-046   L2102 -> ORDER-043   L2236 -> ORDER-042
#     L2914 -> ORDER-072   L3070 -> ORDER-075   L5530 -> ORDER-097
#   NONE of {046,043,042,072,075,097} is one of the 20 cohort IDs => cohort wrong_order_file_scope = 0
#   (caveat: this regex is a narrow detector; it evidences "no collision/renumber marker inside a
#    cohort block", not a proof of zero scope error of every conceivable kind.)

# context_rework query (redo due to wrong context/authority):
git show 4eb839d:AGENT_TASKBOARD.md | grep -nE 'rework|redo|รันซ้ำเพราะ|ทำใหม่เพราะ|context (ผิด|wrong)|authority (ผิด|wrong)'
#   -> 0 hits anywhere => cohort context_rework = 0
```
To map a marker hit to its order: it belongs to the nearest `## ORDER-` header at or above its line.
Cohort line ranges are the `cutoff_blob_line` column in `B0_DATASET.csv`. Same cutoff SHA + same rules
→ same 20 rows and same 0/0. The live (post-cleanup) taskboard is irrelevant to B0.
