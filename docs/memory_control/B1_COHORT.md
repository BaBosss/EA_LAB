# B1 POST-CHANGE OBSERVATION COHORT — REGISTER + PROTOCOL (ORDER-115)

> Design source = `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20.2 step 6 + §20.3 B0/B1 measurement
> contract + §20.4 MVP-2 evidence triggers @ `4eb839d`. Baseline pair = `B0_REPORT.md` / `B0_DATASET.csv`
> (ORDER-099). Dataset = `B1_DATASET.csv` (this directory, append-only rows).

## 1. Window anchor (when B1 opens)

Per §20.2 step 6, B1 = the 20 orders **after MVP-3 AND MVP-1-lite pass acceptance**. Both are now true:

| Prerequisite | Accepted | Evidence commit |
|---|---|---|
| MVP-3 (active/archive + generated view) — Contracts C0+C1+C1-ENFORCE | 2026-07-14 (ORDER-103 ACCEPT) | `c0f7b0d` |
| MVP-1-lite (experiment events + evidence manifest) — Contract D | 2026-07-17 (ORDER-105 ACCEPT) | `0e13699e` |

**B1 window opens at commit `0e13699e` (2026-07-17). Cohort = the next 20 eligible terminal orders
whose close (final DONE/REVIEWED/CLOSED mark) lands strictly AFTER `0e13699e`.** Orders closed earlier
on 2026-07-17 (e.g. the ORDER-098-x wave closed before Contract D acceptance) are NOT in B1.

## 2. Eligibility rule — identical to B0 (`B0_REPORT.md` §3)

An order is **eligible terminal** iff its status string contains one of `DONE`/`REVIEWED`/`CLOSED`,
does not contain `OPEN`/`CLAIMED`/`IN-PROGRESS`/`WAITING`/`SKIPPED`, is not an umbrella parent
(CAMPAIGN/MASTER-PLAN whose execution happens only in children), and is a real order header (not an
annotation/amendment line). Same denominator as B0; one canonical ORDER ID = one row (phases don't
duplicate). The cohort fills in close order — first 20 eligible closes after the anchor, no selection.

## 3. Metric definitions — identical to B0 (`B0_REPORT.md` §6), now recorded PROSPECTIVELY

| Field | Definition | B1 recording rule |
|---|---|---|
| `onboarding_time` | minutes from an agent/session first touching the order to first correct productive action on it | record live; if genuinely not observed → `NOT_RECORDED` (never reconstruct) |
| `context_incident` | count of context/authority misunderstandings during the order (incl. noncritical) | record live per incident, 0 allowed |
| `context_rework` | 1 if the order had to be redone because context/authority was wrong, else 0 | required (recoverable from git+taskboard if missed) |
| `wrong_order_file_scope` | 1 if work hit the wrong order/file/scope (incl. ID collision), else 0 | required (recoverable from git+taskboard if missed) |
| `lead_attention_hours` | actual hours the lead spent judging/steering this order | record live; no extrapolation |

`critical` (any factual/authority error that could change real money, live action, risk control,
verdict, or judge authority) = **stop/rollback trigger from the first occurrence** (§20.4), not a
counting metric.

## 4. Capture protocol (the part that must actually happen)

**The session that marks an order REVIEWED/CLOSED appends its row to `B1_DATASET.csv` in the same
commit (or same session).** Columns are byte-identical to `B0_DATASET.csv`:

`order_id,close_date,status_at_cutoff,cutoff_blob_line,evidence_commit,class,outcome,onboarding_time,context_incident,context_rework,wrong_order_file_scope,lead_attention_hours,notes`

B1 column semantics: `status_at_cutoff` = status at close · `cutoff_blob_line` = line of the order
header in `AGENT_TASKBOARD.md` at the close commit · `class`/`outcome` use the B0 vocabulary
(INFRA/EA-CANDIDATE/EA-REJECT/EA-PARK/RESEARCH · bench/reserve/dead/…). Unobserved values =
`NOT_RECORDED`, never a guessed number and never a fake 0.

## 5. Trigger evaluation (gate for MVP-2 — §20.4, absolute, B1-only)

Evaluate **only when BOTH: cohort has 20 rows AND ≥30 days have elapsed since the window opened**
(monthly-rate triggers need the real time denominator). MVP-2 (Context Packet generator) may be built
iff **at least one** of:

1. noncritical context/authority misunderstanding ≥2 (sum of `context_incident`)
2. context-related rework >10% (>2 of 20 rows with `context_rework=1`)
3. lead time spent fixing context misunderstandings >2 hours/month
4. wrong order/file/scope ≥2 (sum of `wrong_order_file_scope`)
5. onboarding a new agent still takes >10 minutes to identify current task/authority/prohibitions

If none trigger → keep order-brief + active view + experiment events, and **do NOT build MVP-2
because the architecture was designed** (§20.4 verbatim). If it is built, the locked MVP-2
constraints in §20.4 apply (packet never committed, never replaces mandatory docs for money/verdict,
deterministic generator, pilot = ORDER-095).

B0↔B1 improvement comparison (did MVP-0/3/1 help?) uses only fields present on both sides:
`context_rework` + `wrong_order_file_scope` (B0 reality clause §20.3). The prospective fields feed
the triggers, not the B0 comparison.

## 6. Status

- Window opened: **2026-07-17** (`0e13699e`) · rows so far: see `B1_DATASET.csv`
- Trigger evaluation due: **not before 2026-08-16** (30 days) AND 20 rows
