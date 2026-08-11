# EA LAB Factory OS + Control Center — Master Design Package

> **Status: DESIGN ONLY. Not a canonical decision, not an Order, not implemented.**
> Nothing in this file changes a rule. Where it proposes changing one, it says so explicitly and routes
> the change to the owner who may make it (`PROJECT_STATE.md` §3 Decision log = user/Claude only).
>
> **canonical entry = `PROJECT_STATE.md`** · this file owns exactly one thing: **the target architecture
> for unifying the EA factory and the operations Control Room into one system**, plus the migration to it.
> It creates **no new owner** for any fact that already has one.
>
> Produced 2026-07-30 by the Opus seat, session lane `S-2026-07-30-DESIGN1`, per
> `Codex grill me\0. START HERE - EA LAB CLAUDE MASTER.md` Stage 1.
> **Next step is Stage 2: an independent blind Codex audit** (§13). No Order may be written from this
> document until that audit is answered — master file Stage 1 and Stage 3.
>
> Inputs reconciled: the Grill's 78 locked decisions (`5. Grill me EA lab and EA template.txt`), the
> Control Room handoff (`EA_LAB_CONTROL_ROOM_HANDOFF_2026-07-29.md`, 22 sections + 30 acceptance
> scenarios), the two Codex reviews, and the current workspace at commit `b430280b`.
> The old Parameter-UX Grill prompt was used **as a completeness checklist only** and was not re-run.

---

## 0. What problem this actually solves

Every capability the factory needs already exists somewhere. That is precisely the problem: the lab has
a pipeline (`docs/PIPELINE.md`), a parameter registry (184 rows), a verdict gate, a deployment inventory,
an event log, a control-room snapshot, a dashboard, a taskboard, an archive, and eleven separate guard
scripts — and **no single place where a person can see what has been tried, what is running, what is
owed, and what to do next.** The coupling between those parts is a human reading eight files in the right
order and remembering the rules that connect them.

The measured cost of that is not hypothetical. In the eight days before this document was written the
repo shipped four defects of one shape — a detector that kept running and quietly stopped reporting
(`ORDER-260` substring match · `ORDER-341` advisory label outranking the blocking one · `ORDER-390`
nested backticks · `ORDER-370` a pipeline `.Count` that is `$null` for exactly one result) — and each was
found by a human looking, not by a system. `docs/SESSION_LEDGER.md` carries three corrections **in one
day** to a hand-maintained summary line, each written by someone who had just repaired the previous one.
`MASTER_BACKLOG.md` §2 still describes a 7-EA portfolio; `DEPLOYMENTS.csv` has 64 rows.

So the design goal is not "a dashboard". It is: **make the connections between existing owners
mechanical, and make every claim the system displays traceable to the one file that owns it.**

**Two things this design refuses to do**, because both are how the previous attempts drifted:

1. **It does not create a second source of truth for anything.** Not for orders, verdicts, deployments,
   parameters, or totals. Where a fact has an owner, the Control Center *projects* it. Where a fact has
   no owner today — **two unambiguously, three partly (§1.3)** — this design names exactly one new owner
   and says who writes it. A fact that already has an owner is carried only as a pinned `OwnerRef`.
2. **It does not let automation reach a verdict.** Automation runs to `EVIDENCE_COMPLETE` and stops
   (Grill decision 20, `PROJECT_STATE` §3 2026-07-19). Mechanical gates and next-actions are computed;
   the verdict and the money decision stay with the user and the Claude seat.

---

## 1. (A) Current-state map and source-of-truth ownership

### 1.1 Reused as-is — these are owners, and this design keeps them owners

| Fact | Canonical owner today | Factory OS role |
|---|---|---|
| status · binding decisions · forward plan | `PROJECT_STATE.md` (§3 = user/Claude only) | read-only projection; the Control Center never writes it |
| owner's big picture | `VISION.md` | read-only; conflict with it = stop and ask (existing rule) |
| agent roles / write permissions / lane rules | `AGENTS.md` | the scheduler *enforces* §3.2 mechanically instead of by discipline (§6.4) |
| formal Order queue + raw results | `AGENT_TASKBOARD.md` + `ARCHIVE_TASKBOARD_2026-07A.md` | stays the Order queue in Phase 1 (handoff §2). Work Receipts sit *beside* it, never replace it |
| stage routing idea→live | `docs/PIPELINE.md` | the Hypothesis and Coverage state machines are this table made executable; the table stays the owner |
| verdict tree + bar table | `CLAUDE.md` VERDICT GATE | the only place bars live. The OS *evaluates* bars, never redefines one |
| optimize method (LADDER 0–9) | skill `backtest-optimize-rigor` | the orchestrator sequences it; it does not restate the method |
| EA registry · scoring · kill-reason | `EA_SCORECARD_AND_REGISTRY.md` + `EA_MASTER_INDEX.csv` | Candidate/Deployment link *to* scorecard rows; verdict text never duplicated |
| deployment inventory (per magic) | `portfolio/DEPLOYMENTS.csv` | Deployment entity is a *view* over this + the new attestation fields; CSV stays the write path |
| account universe / governance scope | `portfolio/ACCOUNTS.csv` | the only account universe. (Stage 0B is repairing readers that ignore it) |
| deployment→bundle attestation | `portfolio/ATTESTATION_MAP.csv` | reused directly by Candidate/Deployment identity (§5.6) |
| parameter definitions | `docs/PARAM_REGISTRY.csv` (184 rows / 170 identifiers, `param_registry_check` CLEAN) | **extended, not replaced** (§4.2) |
| parameter precedence | `docs/PARAM_LINKAGE.md` "Override pairs" (11 pairs) | machine-read already by `optimize_guard.ps1`; becomes the precedence source for the wrapper generator |
| build-inert findings | `_triage/PARAM_INACTIVE_AUDIT.md` §2 (13 rows) | feeds the compile-time allowlist (§5.3) |
| experiment occurrences + hashes | `scripts/experiment_event_log.ps1` + monthly JSONL + schemas | **the Run/Evidence audit trail. No new event store is created** (§4.5) |
| artifact ownership + write contracts | `_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` §20.7 @ `4eb839d` | this design **extends** §20.7's table; it does not fork it (§1.5) |
| session lane reservation | `docs/SESSION_LEDGER.md` | becomes the lane-lease source the scheduler reads (§6.4) |
| live snapshot projection | `scripts/control_room_snapshot.ps1` → `portfolio/control_room_snapshot.json` (schema v3) | **this is already the single-projection pattern the handoff asks for.** Extend it; do not write a second one |

### 1.2 Stale, duplicated, or to retire

| Thing | Evidence | Disposition |
|---|---|---|
| `MASTER_BACKLOG.md` §2 COVERAGE MATRIX | 7 EAs, last real update 2026-06-27; `DEPLOYMENTS.csv` has 64 rows | **generated** from Coverage Cells; the prose above it stays hand-written |
| `docs/SESSION_LEDGER.md` "เลขที่ใช้ไปแล้ว" summary block | corrected 3× in one day, self-contradictory once; filed as `BACKLOG-D29` | **derive from the tables or delete.** The OS derives it |
| `STATUS.md` / `STATUS.html` | observed stale and disagreeing with fresher sources (handoff §3) | becomes a projection of the one snapshot; keep the file path for compatibility |
| `TASKBOARD_DIGEST.md` | already generate-only (`PROJECT_STATE` §3 2026-07-26) but independently counted | becomes a projection; its counts must come from the snapshot |
| `_triage/HANDOFF_*.md` (15 non-archived at handoff time) | handoff §7: "do not keep creating independent handoff truths" | **generated view of open Work Receipts.** Existing files imported once, provenance retained, never re-parsed |
| `scripts/live_dashboard.ps1` global `$BaseEquity = 10000` | one denominator for six accounts; `ACCOUNTS.csv` records 100000 for `463666728` and blank for five | Stage 0B is repairing it. The OS must never reintroduce a dashboard-local constant |
| `optimize_guard` classification semantics | repaired 2026-07-30 (`024127e3`): `OVERRIDE` no longer read as dead | the wrapper generator consumes the *repaired* semantics; see §5.4 |
| `docs/PARAM_REGISTRY.csv` `OptimizeStage` / `SafeRange` | **verified 2026-07-30: 177/184 and 181/184 are `UNKNOWN`** | fill for the Operator surface only, per Boss, as a discovery task (§4.2) |

### 1.3 What is genuinely unowned — **corrected 2026-07-30 after the blind audit**

> 🔴 **Rev 1 of this section claimed eleven facts had no owner. That was the load-bearing claim of the
> whole design, and it did not survive the audit.** Codex walked all eleven against the workspace and
> found most of them already owned — and, worse, found that the rev-1 schemas stored **mutable copies**
> of those facts, which is precisely what `PROJECT_STATE.md` §0.5 forbids ("links, never copies") and what
> §20.7 restricts to occurrence metadata and references. The corrected table is below. The rule that
> replaces the old one: **a Factory OS artifact may hold a fact it does not own only as an `OwnerRef`
> pinned at commit + blob + sha256.**

| # | Fact | Verdict after audit | Owner, and what the Factory OS may hold |
|---|---|---|---|
| 1 | Hypothesis + revisions | **partly owned** | causal claim, falsifier and acceptance already live in taskboard pre-registration. `factory/hypotheses.jsonl` holds only the machine-read fields (id, revision, architecture digest, module set, coupling) + `preregistration_ref`. It must not restate the claim. |
| 2 | Test Universe | ✅ **genuinely unowned** | `factory/universe.jsonl`. No canonical artifact exists for a versioned mandatory symbol×TF set. |
| 3 | Coverage cell state | **owned** — `MASTER_BACKLOG.md` §2 declares it | cells become the machine source and **`MASTER_BACKLOG` §2 is regenerated from them**; the ownership move is an explicit migration row, not a silent second copy. |
| 4 | Instrument Profile | **partly owned** | baseline semantics + starting values are `OPTIMIZATION_PROCEDURE_V2` §4. New: only the broker/lane mapping layer, plus a `content_hash` so a Candidate pins profile *content*, not a mutable id. |
| 5 | Run / Attempt | **split** | the experiment event log owns the occurrence timeline. **Only the scheduler recovery checkpoint is new** — that is what `factory/runs/` owns, and nothing else. |
| 6 | Evidence index | **owned** — `docs/memory_control/experiment_events/evidence-manifest.jsonl` exists, with its own schema | no new index. Register through the existing utility. Only the *blob store location* is arguably new. |
| 7 | Candidate | **partly new** | the immutable bundle identity is new; the locked `.set`, the scorecard standing, the evidence and the attestation all have owners and are referenced. |
| 8 | Magic allocation | **owned** — assigned magics are in `DEPLOYMENTS.csv`, uniqueness is checked by `check_state.ps1`, session ranges by `SESSION_LEDGER.md` | the allocator becomes a **reservation log** that references Deployment. It must not copy deployment status. |
| 9 | Work Receipt | **new only for chat commitments that are not yet Orders** | where an `ORDER-*` exists, the taskboard owns title/status/owner/acceptance and the Receipt references it. ⚠️ **opening this writer needs an `AGENTS.md` §2 permission change the user must ratify first** — see §11. |
| 10 | System Finding | **new only for stable identity + lifecycle** | detector state is owned by the snapshot and is referenced. |
| 11 | Idea Tank | **owned** — `INTAKE_QUEUE.md` opens by declaring itself the single place for every new source/strategy drop | **no `ops/ideas.csv`.** Add stable ID + exact-URL dedupe **as columns on the existing owner**; the Factory OS holds only a read projection. |

**Net: two facts are unambiguously unowned (Test Universe, scheduler recovery checkpoint), and three are
partly new (candidate bundle identity, finding lifecycle, chat-commitment receipts).** The other six are
extensions of, or references into, existing owners.

**Naming rule:** artifacts under `factory/` or `ops/` are canonical only for the rows marked new above;
everything else there is a projection. Generated projections go to `build/` and are never edited.

### 1.4 The reconciliation of the two designs (this is the decision the master file asks for)

The Control Room handoff and the Factory Grill overlap on TODAY, monitoring, roles, incidents, and UI.
They must not become two dashboards. **Resolution:**

```
                    ONE Control Center shell
     (one identity scheme · one freshness rule · one finding lifecycle
      · one audit trail · one permission model · one snapshot builder)
                              |
        +---------------------+---------------------+
        |                                           |
  OPERATIONS domain                          FACTORY domain
  (Control Room Phase 1, read-only)          (later capability slices)
  TODAY · WORK · LIVE · SYSTEM · IDEA        BOSS · HYPOTHESIS · COVERAGE
                                             RUNS · BENCH · DEPLOYMENT
        |                                           |
        +---------------------+---------------------+
                              |
              ONE snapshot builder, N source adapters
        normalize -> exact dedupe -> reconcile -> validate
                              |
              ONE validated snapshot (schema_version, build_id,
              generated_at, per-source freshness, discovered/
              categorized/duplicate/conflict/unclassified counts)
                              |
     +-----------+------------+------------+-----------+
     |           |            |            |           |
  online      local full   Telegram    STATUS/digest  TODAY_CONTEXT
  safe page    page                    compatibility  (for the AI)
```

Three consequences, stated so the audit can attack them:

- **`control_room_snapshot.json` is the ancestor of this snapshot, not a competitor.** It already carries
  `meta.schema/version/generated_at/git_head/sources` and documents its versions as additive. The Factory
  domain arrives as **additional top-level keys** on the same document (v4, v5…), read by the same builder.
  Building a second projection would recreate the exact drift the handoff §4 forbids.
- **Factory actions are never hidden inside Phase 1.** Phase 1 may read, normalize, dedupe, classify,
  render, notify. It may not claim, dispatch, approve, cancel, close, reprioritize, or start an agent
  (handoff §2, §20). A Factory *view* may ship in Phase 1; a Factory *action* may not.
- **The reconciliation equation is one rule for both domains — but it is NOT a global health verdict.**
  ⚠️ **Corrected 2026-07-30 after Codex audit 6.** This bullet used to be titled "`ALL CLEAR` is one rule
  for both domains", and the validator built to it named its output `all_clear`. Audit 6 then constructed a
  snapshot with a **`NO_SENSOR` fleet sensor, a `BLIND` floating-risk sensor, missing kill/judge controls, an
  `UNCLASSIFIED` unknown magic and missing attestation** — and it verified **true**, correctly, because the
  equation below says nothing about any of those. The verdict is now called **`reconciliation_clear`** and
  the schema states what it excludes. Making a genuinely global `ALL CLEAR` requires health contracts for
  `system_health`, `floating_risk`, `deployments.gaps`, `unknown_magics`, `attestation` and
  `judge_readiness` — all `array of arbitrary object` today — and that is **S4** work, not a rename.
  The equation itself is unchanged and still applies to Factory data:
  `discovered = categorized` and `categorized = actionable + running + waiting + review/audit + completed + cancelled_by_user`.
  For coverage: `cells_in_universe = tested + untested + not_applicable(with reason)`. Fail either and the
  page shows `UNKNOWN — ตรวจไม่ครบ` with `sources N/M · uncategorized N · conflicts N`. **Never translate
  silence into healthy** — and never translate *"I could not read the input"* into *"there is nothing to
  report"*, which is the specific defect Stage 0B is repairing in `daily_monitor.ps1` right now.

### 1.5 Extension of `§20.7` (not a fork)

| New artifact | Canonical owner + write path | What it may hold, and what it must reference |
|---|---|---|
| Hypothesis registry | `factory/hypotheses.jsonl`, single writer = Claude/user | machine-read fields only. **Causal claim, falsifier and acceptance stay in the taskboard pre-registration** and are reached via `preregistration_ref` |
| Parameter bindings | `factory/parameter_bindings.jsonl`, writer = Claude | role/surface/locked value **per hypothesis revision**; permanent semantics stay in `docs/PARAM_REGISTRY.csv` via `definition_ref` |
| Coverage cells | `factory/coverage.jsonl`, state by the runner, `NOT_APPLICABLE` + reason by Claude only | metrics are `MetricRef`s with their own lane/fingerprint. **`MASTER_BACKLOG` §2 is regenerated from these — an ownership transfer its owner signs off in S2, not an assertion made here** |
| Run journal | `factory/runs/<run_id>.jsonl`, scheduler only, **one transition per line** | scheduler recovery state only. The experiment timeline stays in the event log |
| Instrument profiles | `factory/instrument_profiles.jsonl`, writer = Claude | broker/lane mapping layer only; baseline semantics stay in `OPTIMIZATION_PROCEDURE_V2` §4 via `semantics_ref`; pinned by `content_hash`, never by id |
| Candidate manifests | `factory/candidates/<candidate_id>.json`, written once at verdict, immutable | `candidate_digest` over the payload; verdict text stays in the scorecard via `scorecard_ref` |
| Safe projection | `build/safe_projection.json` — **derived, never hand-written** | the only artifact Telegram and the online page may read |
| Magic allocations | `factory/magic_allocations.jsonl` | reservation only. **Deployment status stays in `DEPLOYMENTS.csv`** via `deployment_ref` |
| Work Receipts | `ops/receipts/*.jsonl` — ⚠️ **blocked on the `AGENTS.md` §2 writer change (§11.8)** | for work that already has an `ORDER-*`, title/status/owner/acceptance stay in the taskboard via `order_ref`; the Receipt holds only receipt-specific metadata |
| Findings | `ops/findings.jsonl` | stable identity + lifecycle only; detector state stays in the snapshot via a pinned reference |
| Ideas | **`INTAKE_QUEUE.md` (existing owner)** — gains stable-ID and URL-dedupe columns | `ops/` holds no idea file. `IdeaRef` is a read projection with `intake_ref` |

The rules of §20.7 carry over unchanged: **occurrence metadata + hashes + owner references only; no
result or verdict prose in any of them.** Rev 1 broke this by storing mutable copies; the mechanism that
enforces it now is `OwnerRef` — path + commit + blob + raw sha256 — as the *only* way to carry a foreign fact.

---

## 2. (B) Domain model

```
BossFamily (Boss_11..18)
   └─ Hypothesis            B14-H01              "a causal claim about why this makes money"
        └─ HypothesisRevision  B14-H01-r2        immutable; new revision when the claim or architecture changes
             ├─ ThinWrapper   (generated .mq5 + allowlist header + .ex5)
             ├─ ParameterBinding  → ParameterDefinition (docs/PARAM_REGISTRY.csv, extended)
             └─ CoverageCell  (HypothesisRevision × LogicalSymbol × TF)
                   ├─ TrialFamily        accumulates trial_count across every search on this cell
                   │     └─ Run → Attempt   (lane lease · data fingerprint · resumable)
                   │           └─ EvidenceBundle  (content-addressed; indexed in the event log)
                   └─ CellState  (see §3.4)

Candidate  = HypothesisRevision + exact parameter set + LogicalSymbol + TF
             + InstrumentProfile + ExitProfile + SizingProfile + SafetyProfile + ExecutionProfile
             + EvidenceBundle refs + binary hash + lane + data fingerprint      [IMMUTABLE]
   └─ Deployment (account + magic + status + kill_rule + judge date)  → portfolio/DEPLOYMENTS.csv
        ├─ Incident        (raised by detectors; a Finding with money exposure)
        └─ JudgeDecision   (user/Claude only; lands in scorecard + Decision log)

TestUniverse (versioned)  →  { LogicalSymbol } × { TF }
LogicalSymbol             →  broker symbol per lane (XAUUSD | GOLD | XAUUSDm; DE40 traded as GER40)
InstrumentProfile         →  AssetClass → SymbolOverride → Broker/LaneMapping
```

**Identity rules (from the locked decisions, made concrete):**

| Entity | ID format | Mint a new one when |
|---|---|---|
| Hypothesis | `B<boss>-H<nn>` — `B14-H01` | the **architecture or causal claim** changes (decision 5) |
| HypothesisRevision | `B14-H01-r<n>` | parameter *roles* change, a module is added/removed, or the parent core changes in a way that alters this wrapper's behaviour |
| — **never** mints a new hypothesis | | a numeric parameter value, a symbol, or a timeframe (decision 4) |
| CoverageCell | `B14-H01-r2/XAUUSD/H4` | — |
| TrialFamily | `TF-<cell>-<lever-set>` | a new lever family is searched on that cell |
| Run | `RUN-<yyyymmdd>-<seq>`; Attempt `RUN-…#<k>` | — |
| Candidate | `CAND-<first 12 hex of sha256(canonical payload)>` — **the payload, which does not contain the id**, never the whole manifest | any payload field changes ⇒ different id (immutability by construction) |
| Deployment | existing `account|magic` key | — |
| Receipt | `WRK-<yyyymmdd>-<nnn>` (handoff §7) | — |
| Finding | `FND-<detector>-<stable-key>` | — |
| Idea | `IDEA-<nnnn>` | — |

**Why `Candidate` is content-addressed rather than sequential:** decisions 38/39 require immutability and
require that a core change produce a *new* revision rather than silently updating a deployment. If the id
is a hash of the manifest, "someone edited a candidate" is not a policy that can be violated — it is a
different id, and the deployment still points at the old one until a human moves it.

---

## 3. (C) State machines and refusal gates

Refusal gates are written as **what the system refuses**, because a gate expressed as "should" is not a gate.

### 3.1 Hypothesis lifecycle
```
DRAFT → REGISTERED → WRAPPER_GENERATED → PARITY_PASSED → EVIDENCE_IN_PROGRESS
      → EVIDENCE_COMPLETE → (human) VERDICT → CANDIDATE | BUILD-ON | PARKED-VERIFY | DEAD-*
```
- **REFUSE** `REGISTERED` without a written causal claim and at least one falsifying observation.
- **REFUSE** `WRAPPER_GENERATED` if any bound parameter is missing `Active when`, `Context`, or
  `Causal question` in the registry (`OPTIMIZATION_PROCEDURE_V2` §3, existing rule).
- **REFUSE** `EVIDENCE_COMPLETE → VERDICT` by any non-human actor. Automation stops at
  `EVIDENCE_COMPLETE` (decision 20) and emits `AWAITING_VERDICT`.
- **REFUSE** `DEAD-OPTIMIZED` unless the ladder and the last-optimize-before-verdict are both recorded
  against this hypothesis (`CLAUDE.md` gate 2a; `PROJECT_STATE` §3 2026-07-18).

### 3.2 Experimental → Certifiable
```
EXPERIMENTAL ──(module promoted to Stable Core + parity + regression CLEAN)──> CERTIFIABLE
```
- **REFUSE** VPS/Demo/Live attach for anything `EXPERIMENTAL` (decision 33).
- **REFUSE** using experimental evidence as promotion evidence (decision 33) — the Candidate manifest
  records the module set, so this is checkable, not a promise.
- New capability starts `EXPERIMENTAL` (decision 34); provisional parameters are allowed there only.

### 3.3 Run / recovery
```
QUEUED → LEASED(lane) → RUNNING → {COMPLETED | FAILED | ABANDONED} → EVIDENCE_REGISTERED
```
- **REFUSE** `LEASED` without a free lane lease for that specific install (`AGENTS.md` §3.2).
- **REFUSE** `COMPLETED` unless a **fresh** report exists — reusing the repo's proven
  `Test-ReportIsFresh` guard (`scripts/lib/report_freshness.ps1`), which exists because "the `.htm`
  exists, so this run wrote it" produced wrong numbers before.
- **REFUSE** a re-run of an identical (config, lane, data fingerprint) except after an execution or
  tester error (decision 18). Otherwise: return the cached evidence. This is what makes the scheduler
  idempotent rather than merely restartable.
- Attempt `k+1` inherits the Run id; the manifest keeps every attempt (decision 65).

### 3.4 Coverage cell
```
UNTESTED → BASELINE_RUN → PROBE_RUN → { PULSE | NO_PULSE } → [rescue ladder] → EVIDENCE_COMPLETE
NOT_APPLICABLE (technical impossibility only, with a written reason)
```
- Every supported cell must get a real **Baseline + small optimize probe** (decision 13) — a cell may not
  be labelled from a neighbouring cell's result.
- **REFUSE** `NOT_APPLICABLE` for any reason other than technical impossibility (decision 14), and refuse
  it without a reason string. *(Known real cases: `Boss_14` on a symbol the broker does not quote on that
  lane; a TF the entry hardcodes — the `EA_BREAKOUT_XAU` precedent where `PERIOD_H1` was hardcoded so
  `-Period` changed nothing, `MASTER_BACKLOG` §3.)*
- `PULSE` routes to the **full rescue ladder** with ≥4 causal lever families (decisions 15, 16).
- **REFUSE** closing a cell whose best result sits on a grid boundary — expand the range first
  (decision 19; memory `grid-answer-outside-the-grid`, where a "regime bet" conclusion was drawn from a
  2.0–4.0 ATR grid whose real optimum was at 1.0).

### 3.5 Candidate
```
PROPOSED → EVIDENCE_LINKED → VERDICT(human) → BENCHED → { ADMITTED_TO_DEMO | HELD }
```
- **REFUSE** a Candidate that does not pin **lane + data fingerprint** (decision 42).
- **REFUSE** any comparison between two Candidates whose lanes differ (decision 43; `AGENTS.md` §3.2 —
  measured 14× tick-count difference between installs on an identical EA/set/window).
- Bench is unbounded; **Demo requires an admission gate** (decision 52).
- **REFUSE** demo admission for grid/martingale/no-SL/risky hypotheses onto a shared account — separate
  account first (decision 54), and the account must have sensor + attestation onboarded (decision 55).

### 3.6 Deployment / monitor / judge
```
STAGED → ATTACHED(user) → COLLECTING → JUDGE_DUE → JUDGED → { PROMOTED | KEPT | PAUSED | KILLED }
```
- **REFUSE** auto-updating a live deployment when the core changes — new revision, human moves it
  (decision 39). This is the direct mechanisation of the `live-fleet-runs-pre-132-binaries` memory.
- Kill-switch and judge criteria are pre-registered at attach time (existing `PIPELINE.md` row 8).
- The Control Center may **open an incident and alert**; it may not take a money or deployment action
  (decision 59).

### 3.7 Champion–Challenger
```
CHAMPION (deployed) + CHALLENGER (new revision) → both evidenced on the same lane and fingerprint
   → human decision → promote challenger = new Deployment revision; champion is retired, never overwritten
```
- **REFUSE** writing over a champion's Candidate manifest (decision 40).

---

## 4. (D) Machine-readable schemas

> ⚙️ **How to read this section (BACKLOG-D31, 2026-07-30 · tables relocated the same day).**
> Every normative contract is **generated from `_triage/factory_os/schemas.json`** by
> `_triage/factory_os/gen_design_contracts.py` into **[`factory_os/CONTRACTS.md`](factory_os/CONTRACTS.md)**,
> and this section **links** to it. Prose here carries **rationale only** — why a field exists, what it
> cost to learn — and has no authority over what the contract *is*. This is not a stylistic preference:
> across three blind audits, **seven findings regressed through exactly one seam**, the design prose and
> the schema each stating a contract by hand with nothing binding them. One of those regressions recurred
> *inside the commit that installed the checker meant to prevent it*, and the checker printed
> `STRUCTURE OK`.
>
> **Why the tables are no longer inline.** Injecting all 30 of them grew this document from 829 to 1807
> lines, while §7.4 is about being readable without exhausting an agent's context; and it put generated
> output inside a hand-written narrative, which is where both marker defects lived. Moving them out cost
> one property that used to hold for free — "the design states this contract" — so that is now **checked**:
> `--check` refuses if this document fails to link any contract, links one that does not exist, or carries
> a link whose name and destination disagree. There are negative fixtures for all three.
>
> To change a contract: **edit the schema and run the generator.** Editing `CONTRACTS.md` by hand is
> overwritten without mercy; editing a table that is no longer here is not possible, which was part of
> the point.

Full field/type/validation definitions live in the single appendix `_triage/factory_os/schemas.json`
(one file, `$defs` per entity — deliberately one file to avoid document sprawl), rendered for reading in
[`factory_os/CONTRACTS.md`](factory_os/CONTRACTS.md). The design-level rules:

**Storage and ownership, every entity in one place:**

→ **contract [`__STORAGE__`](factory_os/CONTRACTS.md#__storage__)** — fields, types, required-set and validation rules.

**Storage format:** every new registry is **JSONL, one object per line**, each carrying its `entity`
discriminator. Not CSV. CSV yields strings for everything and has no round-trip rule for lists or nulls,
which is a defect the audit found in rev 1 where typed schemas named CSV owners. If hand-editability is
preferred later, the CSV encoding grammar and round-trip fixtures must be specified first — §11.9.

### 4.1 Hypothesis registry

→ **contract [`Hypothesis`](factory_os/CONTRACTS.md#hypothesis)** — fields, types, required-set and validation rules.

→ **contract [`ModuleUse`](factory_os/CONTRACTS.md#moduleuse)** — fields, types, required-set and validation rules.

→ **contract [`OwnerRef`](factory_os/CONTRACTS.md#ownerref)** — fields, types, required-set and validation rules.

*Rationale:*
- **The causal claim, falsifier and acceptance criteria are NOT stored here.** They are owned by the
  taskboard pre-registration and reached through `preregistration_ref` (an `OwnerRef` pinned at
  commit + blob + sha256). Rev 1 copied them, which is what the anti-drift rule forbids. A hypothesis
  still cannot be `REGISTERED` without a falsifier — that is checked *at the owner*, not by duplicating it.
- `architecture_digest` = hash of (entry, exit owner, stack owner, lot owner, recovery, hedge, regime) —
  this is what decides mechanically whether a change needs a new revision.
- `module_set` is a list of `{token, module_version, stability}`. **`stability` is what stops
  EXPERIMENTAL evidence reaching a promotion path**, so it is per module, not per hypothesis.

### 4.2 Parameter semantics vs parameter binding — **two files, one resolver**
Rev 1 put `role` on the global parameter definition. That is wrong: locked-ness is **per hypothesis** —
the same input can be `LOCKED` in `B14-H01` and `TUNABLE` in `B14-H02`, and marking it globally would make
`optimize_guard` refuse it on every Boss.

**Permanent semantics — `docs/PARAM_REGISTRY.csv` (extend, do not fork):**

→ **contract [`META_parameter_registry_columns`](factory_os/CONTRACTS.md#meta_parameter_registry_columns)** — fields, types, required-set and validation rules.

**Per-hypothesis binding:**

→ **contract [`ParameterBinding`](factory_os/CONTRACTS.md#parameterbinding)** — fields, types, required-set and validation rules.

*Rationale:*
- **The wrapper generator and `optimize_guard` must read one resolver.** If they read different tables
  they will disagree the moment a binding changes, which is the class of defect the repaired guard came
  from.
- `unit_true` exists because the chassis currently holds **two meanings of "pip" at once**:
  `Stack_PipSize()` implements true pips (10× point on 3/5-digit symbols) while `ExitManager` multiplies
  `_21_TP_Pip`/`_31_SL_Pip` straight by `_Point`. The registry records what the **code** does, not what
  the name claims.
- **Measured: `OptimizeStage` is `UNKNOWN` on 177/184 rows and `SafeRange` on 181/184.** The registry can
  say what a parameter does but **not** which round should optimize it or over what range, so it cannot
  yet generate an optimize plan. Filling it is a discovery task **per Boss, Operator surface first**; the
  acceptance bar is zero `UNKNOWN` on the Operator surface of Boss 11–18, not all 184 rows.
- Existing columns keep their meaning so `param_registry_check.ps1` (CLEAN: 170 identifiers / 184 rows)
  keeps working across the change.

### 4.3 Test Universe and Instrument Profile

→ **contract [`TestUniverse`](factory_os/CONTRACTS.md#testuniverse)** — fields, types, required-set and validation rules.

→ **contract [`LogicalSymbol`](factory_os/CONTRACTS.md#logicalsymbol)** — fields, types, required-set and validation rules.

→ **contract [`InstrumentProfile`](factory_os/CONTRACTS.md#instrumentprofile)** — fields, types, required-set and validation rules.

*Rationale:*
- Universe is **versioned** (decision 25); a Candidate records which universe version it was searched in.
- `LogicalSymbol` is separate from the broker string (decision 26). Real cases already in the repo:
  `DE40` traded as `GER40`; `USDJPYm`/`EURUSDm` suffixed symbols on two accounts.
- InstrumentProfile layers exactly as `OPTIMIZATION_PROCEDURE_V2` §4 specifies:
  **AssetClass → SymbolOverride → Broker/LaneMapping** (decision 27), classes
  `FX_MAJOR · FX_JPY · GOLD · SILVER · CRYPTO · INDEX · ENERGY`.
- A profile carries **no signal optimization** — that separation is what makes profile reuse legitimate.
- A profile is pinned by **`content_hash` + `profile_version`, never by its mutable string id**, so that
  editing values under an unchanged id cannot leave a Candidate looking valid.

### 4.4 Coverage cells

→ **contract [`CoverageCell`](factory_os/CONTRACTS.md#coveragecell)** — fields, types, required-set and validation rules.

→ **contract [`MetricRef`](factory_os/CONTRACTS.md#metricref)** — fields, types, required-set and validation rules.

*Rationale:*
- **There is no flat `lane` or `data_fingerprint` on the cell, and no bare `best_pf_main`/`best_pf_bwd`** —
  read the two tables above, not this sentence. Every measurement is a `MetricRef` carrying **its own**
  window, lane, fingerprint and model. Rev 1 put one lane beside MAIN and BWD together — impossible, since the
  fingerprint includes the window, and it would have let a MAIN from lane 5c and a BWD from lane 1 render
  as a same-lane pair.
- A PF is **unrepresentable without its trade count and drawdown**, by construction: the two hosts that
  cleared BWD did so on 52 and 62 trades at under 2% drawdown while every host that failed took 343–473
  (memory `bar-cleared-by-non-participation`).
- `MASTER_BACKLOG.md` §2 owns the coverage matrix today. These cells become the machine source and §2 is
  **regenerated** from them — but that is an **ownership transfer that its owner must sign off in the S2
  migration table**, not something this file may assert unilaterally.

### 4.5 Run journal, evidence, candidate manifest
→ **contract [`RunTransition`](factory_os/CONTRACTS.md#runtransition)** — fields, types, required-set and validation rules.

→ **contract [`RunAttempt`](factory_os/CONTRACTS.md#runattempt)** — fields, types, required-set and validation rules.

→ **contract [`RunJournal`](factory_os/CONTRACTS.md#runjournal)** — fields, types, required-set and validation rules.

→ **contract [`ExecutionKey`](factory_os/CONTRACTS.md#executionkey)** — fields, types, required-set and validation rules.

→ **contract [`EvidenceRef`](factory_os/CONTRACTS.md#evidenceref)** — fields, types, required-set and validation rules.

→ **contract [`CandidatePayload`](factory_os/CONTRACTS.md#candidatepayload)** — fields, types, required-set and validation rules.

→ **contract [`CandidateManifest`](factory_os/CONTRACTS.md#candidatemanifest)** — fields, types, required-set and validation rules.

*Rationale:*
- **Why one transition per line.** `LEASED` reserves the lane *before any process exists*, so a lease
  cannot carry a pid; "died before spawn" and "spawned then died" have to be two different records or the
  scheduler cannot tell a crash from a slow start. The tables above say what the fields are.
  <sub>*This is the paragraph that proved the first binding checker insufficient: after that checker was
  installed, this text still described `attempts[]`, a lease with `pid`, and `launched_at`, while the
  schema said the opposite — and the checker reported `STRUCTURE OK`, because it compared storage paths
  and banned phrases, not field semantics. It is now generated, which is the only reason it cannot say
  that again (BACKLOG-D31).*</sub>
- **Why `ExecutionKey` is so wide.** Rev 1 omitted deposit, currency and leverage, so a 10,000/1:100 run
  and a 100,000/1:200 run had identical keys and the scheduler would have served the wrong cached
  evidence. Which fields are required is stated in the table, not here.
- **Evidence is registered through the existing event-log utility** (`RegisterEvidence`,
  `evd_sha256_<raw sha256>`, committed Git artifacts only) into the **existing**
  `docs/memory_control/experiment_events/evidence-manifest.jsonl`. No parallel evidence store exists.
  Inherited constraints: `.ex5` binaries are gitignored and need `git add -f`; the path pattern forbids
  parentheses and spaces, which the repo's `(EXP)_Name` convention violates; tick history has no
  committable artifact so `data` uses a committed **provenance descriptor** (`EVENT_LOG_ADOPTION.md` §6).
- **Candidate identity — one definition, and it is in the two tables above.** `candidate_digest` is a
  sha256 over the canonical serialization of `payload`; the payload **does not contain the id** — rev 1
  required the id inside the object whose hash it was defined to be, which has no normal construction and
  would have led to the check being disabled. The validator recomputes the digest on every read.
  ✅ **Canonical serialization is no longer owed (ORDER-1100, S10).** It is `scheduler.canonical()` —
  sorted keys, no spaces, no ASCII escaping — preceded by `scheduler.normalize_numbers()`, which
  collapses an integral float to an int at any depth. `candidate.py` **imports both**; it defines no
  serialization of its own, and `run_s10_tests.py` proves the dependency by swapping each one out and
  demanding the digest move. The normalization is not decoration: a probe during S9 produced **two
  ExecutionKey digests for one deposit** from `10000` versus `10000.0`, which is this paragraph's
  warning happening one entity along. What is this module's own is the FIELD SELECTION — the payload
  is a closed set of fifteen fields and both a missing and an unknown one are refused, because a
  digest over a shape that is not the contract is a digest of something else.

### 4.6 Magic allocation

→ **contract [`MagicAllocation`](factory_os/CONTRACTS.md#magicallocation)** — fields, types, required-set and validation rules.

*Rationale:*
- **Scope = GLOBAL for every new allocation** (user decision 2026-07-30, Grill decision 56). Never reused
  once `RETIRED` — a reused magic silently re-attributes historical deals.
- **Deployment status is not stored here.** `DEPLOYMENTS.csv` owns it; this row references it.
- **Legacy exceptions are a closed set, not a category.** The three real collisions — `990103`, `991001`,
  `991002`, each on two accounts, `991001` on real money — are imported once as
  `LEGACY_ACCOUNT_SCOPED`, frozen to their judge dates, never renumbered as a side effect. **After the
  import cutover, minting a new legacy exception is refused.**
- ✅ **DONE (ORDER-1100, S10, 2026-08-02).** The user amended the invariant on 2026-08-01
  (`PROJECT_STATE.md` §0.5): scope is GLOBAL, and this checker was to flip "only when S10 gives it an
  exception list to read". `factory/magic_allocations.jsonl` is that list — one row per distinct magic
  in the inventory, imported at one cutover commit, of which **exactly three** are
  `LEGACY_ACCOUNT_SCOPED` (`990103` · `991001`, the one on real money · `991002`). The three are an
  owner-declared closed set and are named here on purpose; the ROW COUNT is a measurement and is
  printed by `gen_magic_allocations.py --check` rather than copied into this sentence. `check_state.ps1` now asks `scripts/lib/magic_guard.ps1`, which asks
  `_triage/factory_os/magic.py` — one implementation of the rule, handed **judged bytes** rather than a
  repo path, because a child process reading the working tree would rebuild ORDER-674's A7. The
  `account|magic` check stays as the backstop: global uniqueness implies it, so it costs nothing.
  The list is checked **in both directions** — every real collision must be declared, and every
  declared exception must be a real collision, or the exception list becomes an off switch.

### 4.7 Entities whose rationale lives in §7 (operations surface)
These are contracts of the Control Center, not of the factory registries, and §7 explains *why* each one
exists. Their **fields live in [`factory_os/CONTRACTS.md`](factory_os/CONTRACTS.md)**, linked below — the
generator refuses to run if any `$defs` entity has no generated block there, and `--check` additionally
refuses if this document stops linking one, so an entity cannot drift by simply not being written down.
<sub>(This paragraph said "their fields are here" and "no generated block anywhere in this document" until
2026-07-30; both were left stale by the relocation and caught by Codex audit 6.)</sub>

→ **contract [`DeploymentAttestationEvent`](factory_os/CONTRACTS.md#deploymentattestationevent)** — fields, types, required-set and validation rules.

→ **contract [`WorkReceipt`](factory_os/CONTRACTS.md#workreceipt)** — fields, types, required-set and validation rules.

→ **contract [`SystemFinding`](factory_os/CONTRACTS.md#systemfinding)** — fields, types, required-set and validation rules.

→ **contract [`IdeaRef`](factory_os/CONTRACTS.md#idearef)** — fields, types, required-set and validation rules.

*The builder/persisted boundary (ORDER-601): the evidence and the verdict are different objects, and
the builder side is closed and has no place to put an answer.*

→ **contract [`SnapshotBuilderInput`](factory_os/CONTRACTS.md#snapshotbuilderinput)** — fields, types, required-set and validation rules.

→ **contract [`ReconciliationEvidence`](factory_os/CONTRACTS.md#reconciliationevidence)** — fields, types, required-set and validation rules.

→ **contract [`SnapshotVerdict`](factory_os/CONTRACTS.md#snapshotverdict)** — fields, types, required-set and validation rules.

→ **contract [`ControlRoomSnapshotV5`](factory_os/CONTRACTS.md#controlroomsnapshotv5)** — fields, types, required-set and validation rules.

→ **contract [`SnapshotMeta`](factory_os/CONTRACTS.md#snapshotmeta)** — fields, types, required-set and validation rules.

→ **contract [`RuntimeIdentityObserved`](factory_os/CONTRACTS.md#runtimeidentityobserved)** — EA-emitted account, magic, build, config, symbol, timeframe and epoch evidence.

→ **contract [`RuntimeIdentityRecord`](factory_os/CONTRACTS.md#runtimeidentityrecord)** — collected identity evidence plus the canonical validation outcome.

→ **contract [`RuntimeIdentitySummary`](factory_os/CONTRACTS.md#runtimeidentitysummary)** — fail-closed fleet summary consumed by monitoring.

→ **contract [`SafeProjection`](factory_os/CONTRACTS.md#safeprojection)** — fields, types, required-set and validation rules.

### 4.8 Attribution key
`Deployment ID + Account + Magic + Symbol + Candidate/Variant identity` (decision 57). The current key is
`(magic, symbol)`, which cannot distinguish two revisions of the same EA on one account — exactly the
Champion–Challenger case §3.7 introduces.

---

## 5. (E) Thin Wrapper architecture

### 5.1 The good news from current state
`Boss_14_GridLog.mq5` is **12 lines**: two `#define`s and `#include "core/LabCore.mqh"`. The Boss family is
already a thin-wrapper pattern; the generator does not have to invent it, only to extend it with a
hypothesis token and a compile-time allowlist. This is the single largest reuse in this design.

### 5.2 Generated artifact
```mql5
//  GENERATED - do not edit. Source: factory/hypotheses.jsonl B14-H01-r2 @ <commit>
#define LAB_ENTRY_14
#define LAB_ENTRY_TAG "14_GridLog"
#define LAB_HYP  "B14-H01-r2"
#include "generated/B14_H01_r2_allowlist.mqh"   // capability tokens + locked constants
#include "../core/LabCore.mqh"
```
- **No trading logic in a wrapper, ever** (decision 7). The generator emits only `#define`s and includes;
  a wrapper containing a statement is a generator bug and the parity test must fail on it.
- Wrappers are **deletable and regenerable** from the registry (decision 8). `build/` is regenerated;
  the registry is the source.

### 5.3 Compile-time active-parameter allowlist
- The allowlist header defines one capability token per module the hypothesis actually uses
  (`LAB_CAP_STACK`, `LAB_CAP_RECOVERY`, `LAB_CAP_HEDGE`, `LAB_CAP_REGIME`, `LAB_CAP_MACROGATE`, …).
- `Inputs.mqh` declares each input inside its capability token. Inputs outside the wrapper's capability
  set become `const` **at their canonical default**, so the code that reads them still compiles.
- **Hard constraint already documented in the file:** MQL5's preprocessor has **no `#if EXPR==n` and no
  `#elif`** — `Inputs.mqh:11` says so and the file already nests eight `#ifndef LAB_ENTRY_nn` guards to
  emulate a default. The generator must therefore emit **token `#ifdef` only**. Any design that assumes
  expression conditionals is wrong on this platform.
- Current state, **corrected 2026-07-30**: `Inputs.mqh` holds **184 real `input`/`sinput` declarations**
  plus **25 `input group` section headers** (209 lines begin with `input`/`sinput`, and rev 1 of this
  document reported that 209 as the parameter count — it was counting the section headings), behind
  **26 preprocessor guards** (17 `#ifdef` + 9 `#ifndef`, not 28).
  Visible inputs per Boss, excluding group headers:
  **11→113 · 12→117 · 13→119 · 14→116 · 15→119 · 16→135 · 17→121 · 18→121.**
  > 🔴 Rev 1 claimed a static walk gave 128–153 against 113–135 from the real Inputs page, called the ~15
  > gap unexplained, and filed it as a discovery task. **There was never a gap.** The walk was counting
  > the 25 group headers; removing them reproduces the Inputs-page range exactly, and Boss_14's 116 matches
  > the figure already recorded in `_triage/_archive/handoffs_closed/2026-08-repository-hygiene/HANDOFF_2026-07-28_BATCHQUEUE.md`. A counting bug was written
  > up as a known unknown, which is worse than the bug.
  Target after the change: **Operator ≤ 40** per Boss.

### 5.4 Locked/inactive declaration and the guard that must agree with it
Three states must stay consistent or the optimizer will be told two different stories:
| State | In the wrapper | In the registry | `optimize_guard` verdict |
|---|---|---|---|
| active tunable | `input` | `role=TUNABLE`, `surface=OPERATOR` | ALLOW |
| precedence member | `input` | `role=TUNABLE`, `precedence_owner` set | ALLOW unless superseded **in this run** |
| locked by hypothesis | `const` (not an input) | `role=LOCKED` | REFUSE — not sweepable, and not even present |
| safety | `sinput` | `role=SAFETY` | REFUSE always |
| inert on this build | absent | `role=INACTIVE` | REFUSE |
- The "precedence member" row is exactly the P0 repaired on 2026-07-30: `classification=OVERRIDE` means
  *member of a precedence chain*, not *dead*, and whether it is dead is decided **per run** from the
  sibling values. The generator and the guard must read the same table, or they will disagree the moment
  someone adds a pair.
- Safety uses `sinput` so it is settable but **not optimizable by the optimizer at all** — a stronger
  guarantee than a script refusing, because it removes the dimension rather than declining to sweep it.

### 5.5 Parent–Variant parity contract (decision 35 — the load-bearing test)

> 🔴 **Rev 1 defined parity as trade-list identity alone. The audit is right that this is insufficient**,
> and its counter-example is the one that matters: a wrapper and its parent can both open **zero** trades
> — identical empty trade lists, parity "passes" — while the wrapper actually failed `OnInit` because a
> generated `const` was wrong, or wrote a different persistent risk key. The two builds would then behave
> completely differently the moment they were deployed. An empty list is the easiest way to match.

A Thin Wrapper is valid **iff**, on one lane, one data fingerprint, one window and one model, the wrapper
and the **parent Boss configured with the wrapper's effective config** agree on **all seven** of:

1. **init result** — both attach, or both refuse for the same reason (`OnInit` return + reason code);
2. **`[CFG]` effective-config fingerprint** — identical `effective_config_hash`, including locked constants;
3. **the full order-request/result trace** — every request, every retcode, including *rejected* attempts,
   not merely the fills that survived;
4. **trade list** — count, entry/exit times, volumes, prices;
5. **pending orders and open positions at end of run**;
6. **terminal-side effects** — GlobalVariables written, persistence keys, files touched;
7. **errors and safety alerts raised**.

And the case set must contain **both directions**:
- a **must-trade case** — a config where the strategy provably opens trades, so an empty run cannot pass;
- a **deliberate-refusal case** — a config that must fail the attach (e.g. `_42_RiskPct` mis-paired with an
  `SLMode` that yields no distance, which `MM-SAFETY-001` fails at `OnInit`) — proving parity distinguishes
  *refused* from *silent*.

- Trade-list identity, not summary identity. PF/net/DD matching while trade lists differ is two different
  strategies that happen to agree on one window, and this repo has already been fooled by an aggregate
  that looked stable (`inert-axis-fake-plateau`).
- Parity runs **before** any evidence from that wrapper counts. Evidence produced by an unparified
  wrapper is void.
- Parity is per revision and re-run whenever `core/` changes — which is the same trigger as
  `tpl_regression.ps1`, so the two cages share a lane pin and should share a runner.
- **The known trap this must survive:** `tpl_regression` was compiling into lane 1 and measuring lane 5c
  as recently as yesterday. Parity must assert *the binary it measured is the binary it built*, which the
  repaired `tpl_regression` now does behaviourally.

### 5.6 Effective configuration fingerprint
`effective_config_hash` = hash over every input the build actually exposes **plus every locked constant**.
Emitted by the EA at `OnInit` (extending the existing `[CFG]` line) and recorded in the Job manifest.
This is what makes "the `.set` on the chart is the `.set` we validated" a check instead of a hope — the
memory `attach-verify-gate-and-binary` records a bundle whose own `.set` set `AllowLive=false` and killed
the crypto legs silently for three days, and `proving-a-set-was-loaded-on-a-chart` records that a diff
table lied in two directions.

### 5.7 Preset compiler (Codex's item 7, folded in)
`canonical defaults → instrument profile → account unit (USD/Cent) → architecture/hypothesis →
optimize ranges → full-surface .set + effective-config manifest`
- **REFUSE** unknown keys. **REFUSE** partial sets. A partial `.set` is how unlisted inputs get silently
  filled from the per-terminal tester cache — the documented root cause of the ORDER-165 8/8 false drift.
- Every generated `.set` is full-surface and deterministic; the manifest names lane, symbol, TF, model
  and window alongside it.

---

## 6. (F) Testing and optimization orchestration

### 6.1 Per-cell obligation
Baseline single run **+** small optimize probe for every supported cell (decision 13). Pulse routes into
the full rescue ladder (≥4 causal lever families, decision 16). The ladder itself is owned by
`backtest-optimize-rigor`; the orchestrator sequences and records, it does not restate.

### 6.2 Search policy (already ratified — reused verbatim, not re-decided)
`PROJECT_STATE` §3 2026-07-25 GENETIC OPTIMIZER POLICY: ≤~1,000 combos complete · >1,000 genetic coarse →
**fine complete grid ≤1,000 per zone** → plateau-center (top-1 pick banned) · `Criterion` 0→7 (Complex),
engine-edge uses PF + double trade floor · trade floors H4/D1 ≥60, H1/M30 ≥100, ≤M15 ≥250 per MAIN ·
**search on MAIN only — BWD is never a search surface** · never shorten the window to save time.
Grill decision 17's "~10,000 combinations per round" is the **round** budget across zones; it does not
override the ≤1,000-per-complete-grid rule. *Flagged for the audit as a possible contradiction: if the
two are read as competing numbers, the ratified policy wins.*

### 6.3 Boundary and plateau
Best result on a grid boundary ⇒ **expand the range and re-run** (decision 19), refuse to close the cell.
Probe for inert axes *before* the fine grid (memory `inert-axis-fake-plateau`: three found so far) —
a plateau on an axis with no effect is not robustness, it is a dial connected to nothing.

### 6.4 Lane affinity and data fingerprint (the mechanisation of `AGENTS.md` §3.2)
- `data_fingerprint` = hash(lane id · symbol · tf · from · to · model · bars · ticks · server ·
  `Bases\` state marker). Recorded on every Run.
- **Every A/B, fan, or before/after pair runs end-to-end in one lane.** The scheduler refuses to schedule
  a comparison whose members hold different lane ids — today this is a rule people remember; here it is
  a rejected job.
- Lane leases come from `docs/SESSION_LEDGER.md` + a lease file. Model 4 is exclusive machine-wide.
  Lane `5c` has no tick cache and is refused for Model 4 outright.
- A result that does not reproduce on another install is **expected**, not nondeterminism, and must not
  be written up as a bug.

### 6.5 Recoverable, idempotent scheduler (= §20.8 Contract B, realized)
Wrapper around the **existing** runner (`mt5_run.ps1` / `mt5_optimize.ps1`) — not a replacement:
lane-aware, fail-visible, resume manifest, no global process kill, no `-Force`, no change to tester safety.
- Crash/restart resumes from the manifest; a completed attempt is never re-run (decision 65).
- Re-running an identical config is refused except after execution/tester error (decision 18).
- Freshness proof required before an attempt counts as `COMPLETED` (§3.3).

### 6.6 Sizing–Exit coupling
Every hypothesis carries `coupling_class`:
- `SCALE_INVARIANT` — edge and sizing may be optimized separately (decision 46).
- `COUPLED` — money TP, balance-% TP, grid/martingale: **joint matrix required** (decisions 47, 48),
  because the exit target is denominated in the same units the sizing changes.
- Sizing modes are named honestly: `RISK_PCT_WITH_SL` **fails closed** when SL or tick value cannot be
  measured (decision 50), and `LOT_PER_BALANCE_ANCHOR` **may never be called "Risk %"** (decision 51).
  *(The chassis already implements the fail-closed half: `_42_RiskPct` mis-paired with `SLMode` fails the
  attach at `OnInit` — `MM-SAFETY-001`, the silent fallback to `_41_FixedLot` is gone.)*
- Reminder that belongs next to this: `_04_TpUsd` is a fixed dollar amount that does **not** scale with
  lot, so expanding `_05_BaseLot` without expanding it changes the strategy, not just its size.

### 6.7 Trial counting and discovery risk
`trial_count` accumulates per TrialFamily and per cell; every Candidate records the total number of
configurations that were ever scored on its way to being selected (decisions 44, 45).
**The number that converts trial count into required confirmation does not exist yet.** A proposal is in
§11 as an unresolved decision, because changing what confirmation is required is a change to the bar
table, and the bar table is the user's to ratify (`PROJECT_STATE` §3, ORDER-235 precedent).

---

## 7. (G) Control Center information architecture

**Shell:** mobile-first, dark-first, Thai user-facing labels, stable English state codes and IDs, never
colour alone (icon + text), no giant default tables, three depths everywhere — **Beginner → Standard →
Advanced/Raw**. The first screen never shows 100+ parameters.

### 7.1 Operations domain (Control Room Phase 1 — read-only)

**`TODAY` (landing).** Order fixed by the handoff §12 and not negotiable, because the order *is* the
product: ① snapshot health (`ALL CLEAR` / `UNKNOWN` / critical) ② `ควรเริ่มตอนนี้` ③ `ต้องการคุณ`
④ `ติดขัด / session อาจหลุด` ⑤ `รอ Review / Audit / Handoff` ⑥ `พร้อมทำ` ⑦ `กำลังรอ` ⑧ `เพิ่งเสร็จ`.
- Priority is deterministic and every row shows **why it is where it is**: real-money incident → user
  decision → started-but-stuck → blocking other work → due monitor/judge/reopt/audit → ready → ideas.
- `ควรเริ่มตอนนี้` is a **section, not a single item** — show the whole actionable top band.
- Every red/orange actionable row is shown even beyond seven; only lower-priority ready work is capped
  at 5–7 with an explicit hidden count and expand-all. **No hard cap on tasks or ideas.**
- A user-decision row must carry the question, the options, Claude's recommendation, and the consequence
  of not deciding — otherwise it renders `รอ Claude เตรียม decision brief` rather than dumping a vague
  question on the user.

**`WORK`** — full lifecycle: `CAPTURED · READY · IN_PROGRESS · WAITING · BLOCKED · HANDOFF ·
DONE_PENDING_REVIEW · AUDIT_REQUIRED · AUDIT_IN_PROGRESS · REWORK · REVIEWED · CANCELLED_BY_USER ·
STATE_CONFLICT`.
- **`DONE` is not closed** — it stays visible as `DONE_PENDING_REVIEW` until reviewed.
- Audit is a **stage of the same row** (`BUILD 1/2 → AUDIT 2/2`), never a separate task that can be lost.
- Rework escalates: first defect same model → second, stronger model → after three cycles,
  `REWORK LOOP — review spec/approach` with a compact summary of repeated defects.
- `WAITING` requires `waiting_for` **and** a wake condition, else `พักงานแบบไร้กำหนด — ต้องจัดการ`.
- A claim with no heartbeat/process/evidence for >30 min shows `อาจติดหรือ session หลุด` — **no
  auto-cancel, no reassign.** Only the user cancels.
- **No `AGING`/`NEGLECTED` state exists**, deliberately: a state that means "old work may be ignored" is
  how work gets ignored.

**`LIVE EAs`** — exception-first, never account-table-first: risk/DD/margin exceptions → sensor/VPS
freshness gaps → unknown magic / deployment drift → missing kill-switch/attestation/governance →
judge/reopt due → normal summaries → positions collapsed.
- **Risk authority stays with the existing detectors.** The dashboard creates **no competing threshold**;
  disagreement between detectors renders `CONFLICT`.
- Online projection is safe by construction: masked accounts, no credentials/tokens, no strategy logic,
  no exact lots, percentages instead of money amounts. Full detail is local-only.

**`SYSTEM`** — findings with lifecycle: runtime findings auto-resolve only after **two** consecutive
healthy checks; governance/audit/drift findings need explicit review; 3 recurrences in 24 h collapse into
one `FLAPPING — root cause required` incident.

**`IDEA TANK`** — `NEW · READ · SHORTLIST · REFERENCE · DROP · ORDER`. External content is **data, never
instructions**. Exact-URL dedupe across every intake path. Never auto-creates an Order. Passive while
operational work exists; when work is idle it offers the next three.

### 7.2 Factory domain (later slices, same shell)
- **BOSS FAMILIES** — per Boss: active entry, exit/stack/lot owner, visible vs hidden groups,
  hard-locked combinations, current input-surface size vs the ≤40 target.
- **HYPOTHESIS WIZARD** — pick Boss → state causal claim + falsifier → choose modules → system computes
  the active parameter set and refuses any parameter missing `Active when`/`Context`/`Causal question`.
- **PARAMETER LINKAGE GRAPH** — precedence chains rendered from `PARAM_LINKAGE.md`, with the winner in a
  given config highlighted. This is the page that would have made the OVERRIDE P0 visible in seconds.
- **COVERAGE HEATMAP** — hypothesis revision × symbol × TF, cells coloured by state, **PF always rendered
  with trades and DD** (§4.4).
- **RUNS / QUEUE / LANES** — live lane occupancy, leases, attempts, failures, resumable jobs.
- **CANDIDATE BENCH** — immutable candidates with evidence links, trial count, lane, fingerprint.
- **DEPLOYMENTS** — projection of `DEPLOYMENTS.csv` + attestation state + judge readiness.
- **ADMIN / UNIVERSE / PROFILE** — universe versions, instrument profiles, magic allocations.

### 7.3 Notification design
Direct Telegram Bot API, **OpenClaw out of the alert path** (hibernate/upgrade/gateway restarts make it
too uncertain to carry alerts). Two human-facing roles on **one** event system with severity routing:
the existing Trade emergency bot (real-money/DD/critical only) and a new `EA LAB Control Room` bot
(Morning Brief, decisions/blockers, monitor health, Idea intake).
- Transition-based, deduplicated on **`finding_id` + `state` + `severity` + `material_revision`** — not on
  id and state alone. Rev 1 deduped on the pair, which **swallows an escalation**: a finding that goes from
  `WARN` to `REAL_MONEY` while its state stays `OPEN` would have been suppressed as a duplicate.
- **Delivery is receipted per channel.** A delivery ledger records `(event, channel, receipt)`, so "was
  this actually delivered" is answerable and a replay after an outage does not re-alert what already
  landed. Without it, dedupe is a claim about sending, not about arriving.
- **Two entities carry this, and S12 built both.** The thing that crosses the seam to a channel, and
  the record of what happened to it. The first is allowlist-only because its `text` is free-form and
  is therefore the one field on which a careless renderer can put an account number on the wire; the
  second carries a channel *name* and never a chat id, because a chat id is a delivery credential.
  → **contract [`AlertEvent`](factory_os/CONTRACTS.md#alertevent)** — fields, types, required-set and validation rules.
  → **contract [`AlertDelivery`](factory_os/CONTRACTS.md#alertdelivery)** — fields, types, required-set and validation rules.
- **`material_revision` cannot come from the projection, and that is a structural fact rather than an
  oversight.** The `SafeProjection` carries `public_id`/`severity`/`state` and nothing else, so the
  dedupe key this section mandates is computed **local-side**, from an append-only finding journal,
  before anything is handed to the sender. The internal `finding_id` stays in that journal.
- `OPEN → HEALTHY_1_OF_2 → OPEN` must **not** emit a recovery message — an intermediate healthy check is
  not a recovery, and treating it as one produces exactly the flapping spam the two-check rule exists to
  stop. `FLAPPING` gets a **bounded reminder** rather than permanent silence, so a state that never
  changes cannot go unreported forever.
- One alert, then silence until the dedupe key changes; one recovery message when genuinely healthy.
- Workstation offline (heartbeat > 45 min) renders neutral `WORKSTATION OFFLINE / UNKNOWN` with last-sync
  time. **Never guess** hibernate vs crash vs network. Never nag about a known offline state.
- Telegram and Dashboard are pinned to **the same `build_id` and the same event/finding ids**, or they
  will drift — but they do **not** read the same document. The Dashboard's local view reads the full
  snapshot; **Telegram and the online page read only the `SafeProjection`**, and the sender has no path
  to the full snapshot at all. Rev 2 of this file said "the same snapshot", which would have reinstated
  the leak §7.1 exists to prevent.
- Tokens never enter git, logs, generated HTML, handoffs, or chat.

### 7.4 Context efficiency (how the AI reads this without eating its own context)
Deterministic scripts enumerate everything; a compact index holds ids + essential fields; a small
`TODAY_CONTEXT` is generated from the full index with a header stating
`discovered / categorized / conflicts / omitted-detail` counts; the AI loads full evidence only for
named ids. A display cap is allowed **only** when the hidden count and drill-down stay explicit.
This is not a nicety — `AGENT_TASKBOARD.md` is **628 KB**, which has already killed a worker's context
twice (memory `taskstop-does-not-kill-qwen-child`).

---

## 8. (H) Pilot: Boss_14 GridLog, B14-H01 and B14-H02

### 8.1 The two hypotheses
| | **B14-H01** | **B14-H02** |
|---|---|---|
| Claim | On a ranging instrument, a distribution of ATR-spaced grid entries with LOG-power lot progression and a basket money target extracts more from mean reversion than a single entry does, **after cost**, and the escalation is what produces the edge | Replacing unbounded adverse exposure with an **opposite-direction lock** on basket-DD breach preserves the grid's edge while bounding the worst case |
| Architecture | GridLog + martingale progression + **no broker SL** | GridLog + `HEDGE_LOCK` |
| Falsifier | flat-lot variant PF ≥ escalated PF (edge is in the signal, not the engine) **or** worst-case single loss > 15% equity at real sizing | hedged variant's both-window PF < unhedged at equal measured DD |
| Coupling class | `COUPLED` (money-denominated basket TP + progression) | `COUPLED` |
| Class label | **ENGINE-EDGE** | ENGINE-EDGE until measured otherwise |

### 8.2 Two gates the pilot must pass before it is allowed to be interesting
1. **H01 is the exact shape `CLAUDE.md` puts in a cage.** "No broker SL + martingale" is not automatically
   structural death (the rule changed 2026-07-19), but it may only proceed under **all five** cage
   conditions: computable worst case (hard depth cap + basket-SL/DD-kill, stated as a number — "one loss
   costs ≤15% equity at real sizing") · **BWD 2020-22 as a HARD gate**, not the usual soft gate ·
   **Model-4 mandatory** · MC ruin ≤2% at real sizing · label `engine-edge` ⇒ permanently small sizing,
   never sized up on PF. **The flat-lot probe is mandatory** — as a diagnostic of *where the edge lives*,
   not as a death certificate. Decision 31 says the same thing from the other side: no-SL does not mean
   no emergency DD, no max lot, no max levels.
2. **`HEDGE_LOCK` has never passed any backtest.** `PROJECT_STATE` §7 records that modes 82/83/HEDGE_LOCK
   have never passed one, so **enabling it the first time is validating a new mechanism**, not toggling a
   flag. H02 therefore starts `EXPERIMENTAL` and cannot produce promotion evidence until its module is
   promoted to Stable Core (§3.2).

### 8.3 Pilot cells and their real-world traps
Universe: `XAUUSD · EURUSD · USDJPY · BTCUSD` × `H1 · H4` = 8 cells × 2 hypotheses = **16 cells**
(decision 72). Each cell owes a Baseline + small probe (decision 13).
- **BTCUSD must be pinned to one lane for its whole life.** Tick history differs across installs
  (measured 14× on an identical EA/set/window); only the primary install has BTC history back to 2020.
- **BTCUSD swap is not charged by the tester.** The tester charges `POINTS`-mode swap (XAUUSD verified
  −29.25) but **not** `INTEREST_CURRENT` (BTCUSD, −14.67 %/yr). Crypto cells must deduct financing
  post-hoc from measured holding time, or every crypto number in the pilot is optimistic by a known,
  large amount.
- XAUUSD is the regression cage's own symbol; pilot runs must not collide with `tpl_regression` on lane 1.
- `Boss_14` compiled defaults barely trade on the regression window (4 trades) — the pilot uses its own
  windows (MAIN 2023.01–2025.12, BWD 2020–2022) and must not borrow the cage's.

### 8.4 Parity cases (all must pass before any cell's evidence counts)

→ **contract [`META_parity_cases`](factory_os/CONTRACTS.md#meta_parity_cases)** — fields, types, required-set and validation rules.

*Rationale:* the second audit found this list asserted as "five cases" while it had already grown to
seven — a count and a list that disagreed, in one section, with nothing able to notice. It is generated
now, so **the count is the list**. Case 5's `.ex5` caveat is not pedantry: MQL5 compilation is not
byte-reproducible (memory `mql5-compile-not-byte-reproducible`), so a hash comparison there would fail
forever and get switched off.

### 8.5 Failure and rescue branches
`NO_PULSE` on a cell → rescue ladder R0–R4 (implementation/linkage audit → re-optimize related params →
adjacent architecture → symbol transfer → alternate profile/TF), ≥4 lever families, then
last-optimize-before-verdict, then a human verdict. Boundary hits expand the grid instead of concluding.

### 8.6 Pilot acceptance checklist (the pass/fail for the whole Stage-4 pilot)
- [ ] `factory/hypotheses.jsonl` holds B14-H01/H02, each with a `preregistration_ref` resolving to a
      taskboard order that carries the causal claim **and** the falsifier — the registry must not copy them
- [ ] wrappers generate from the registry, contain zero logic, and regenerate byte-identically
- [ ] **all parity cases in §8.4 pass on all seven points of §5.5**, on one lane, lane named in the output
- [ ] the must-trade case actually traded, and the deliberate-refusal case actually refused on both sides
      — a parity run where nothing traded and nothing refused is **not** a pass
- [ ] Operator surface of the wrapper ≤ 40 inputs, **zero inert visible inputs**, zero numeric pseudo-enums
- [ ] `optimize_guard` ALLOWs every intended sweep dimension and REFUSEs every safety/locked one — with
      the guard **observed refusing at least one real case** (a guard never seen firing is `UNTESTED`)
- [ ] 16/16 cells reach Baseline + probe, or carry a written `NOT_APPLICABLE` reason
- [ ] every cell's PF is displayed with its trade count and drawdown
- [ ] every run carries lane + data fingerprint; no cross-install comparison exists anywhere in the output
- [ ] crypto cells have financing deducted post-hoc, and say so
- [ ] the scheduler resumes a killed batch without re-running a completed attempt
- [ ] `EVIDENCE_COMPLETE` is reached with **no verdict issued by automation**
- [ ] H01 either satisfies all five ENGINE-EDGE cage conditions or is not advanced
- [ ] `tpl_regression` CLEAN and `param_registry_check` CLEAN at the end, on one lane end-to-end

---

## 9. (I) Migration and rollback

**Freeze first.** Everything currently collecting Demo/Live evidence is frozen until its judge date
(decision 69) — 64 deployment rows, 5 judge-capable, real money on `991001`/`990208`. No migration
touches a chart. **No bulk migration before the pilot passes** (decision 78).

Two rules govern the whole table, because rev 1's rollbacks did not actually restore anything:
**(a) shadow state is never canonical state** — everything imported stays in a shadow namespace that is
dual-read against its owner until an explicit **cutover gate**; **(b) after cutover, rollback is a reverse
projection with a retention plan, never a delete.** A delete is only a valid rollback while nothing has
been written that exists solely in the new system.

| Stage | Action | Rollback | Cutover gate |
|---|---|---|---|
| M0 | Build `factory/` + `ops/` owners empty, with validators; change nothing else | delete the directories — valid, nothing is authoritative yet | — |
| M1 | Import coverage cells from taskboard/scorecard history as **`UNVERIFIED_IMPORT`** (a real state in the enum), never as evidence | drop the file — valid, `MASTER_BACKLOG` §2 is still the owner | §2 owner signs off before cells become the source |
| M2 | Legacy handoff import → shadow Receipts, exact-dedupe, provenance to every original, originals untouched | **before cutover:** drop. **After:** export every Receipt that has no `HANDOFF_*.md` ancestor, then drop — those are commitments that exist nowhere else, and deleting them destroys work rather than reverting a change | totals reconcile against the handoff files, and the `AGENTS.md` §2 writer change is ratified (§11.8) |
| M3 | Control Room shadow: new snapshot built beside the old, totals compared, **user-facing URL unchanged** | stop building it — valid, nothing user-facing changed | totals agree for N consecutive builds |
| M4 | Switch the user-facing URL | repoint to the old page **only while the old page's sources are still being maintained** — otherwise repointing hides the new state instead of restoring the old, and looks like recovery. Keeping the old generator alive is therefore a *condition of this gate*, not an afterthought | all 30 acceptance scenarios pass, incl. the `SafeProjection` leak fixtures |
| M4b | **Event/notification delivery** goes live | replay from the delivery ledger; suppress re-delivery of events already receipted | one alert, one recovery, no duplicates, proven on fixtures |
| M5 | Pilot only: Boss_14 wrappers generated; parent Boss untouched and still compiling | delete `build/`; parent unchanged | parity green on all seven points |
| M6 | Standalone EAs with proven edge ported one at a time as Boss hypotheses + parity (decision 70) | keep the standalone; it was never removed | per-EA parity |
| M7 | **Artifact store restore drill** — restore from backup into a scratch location and verify hashes | n/a (this *is* the rollback test) | drill passes before any candidate binary is retained only in the store |

**Artifact store:** content-addressed, outside git for blobs, with the manifest and hashes **in** git
(decision 66/67). Backup and restore must be **drilled**, not assumed — an untested backup is a story
about a backup. Retention: candidate binary + `.set` + evidence kept permanently (decision 68).

**Rollback for the Control Center itself:** build to a temporary output, validate, then atomically replace
last-known-good. A failed build **retains last-known-good and labels it `STALE / BUILD FAILED`**. A
partially generated "current" page is never published.

<sub>*(The rollback column above was rewritten on 2026-07-30. Rev 1 said "delete the directory", "delete the
receipts" and "repoint the old page" for stages where none of those restore anything once the system has
been used, and had no rollback at all for event delivery or the artifact store. The audit called the first
attempt at fixing this `MOVED-evasive` — because I had left the wrong table standing and added a note
underneath saying it was wrong. The table is the contract; the note was not.)*</sub>

---

## 10. (J) Implementation slices

Vertical, each independently verifiable, each with a cage that can fail. Dependency order is top to bottom.
**No taskboard Order may be written from this list until the blind audit is answered.**

> 🔴 **Reordered 2026-07-30.** The audit found the rev-1 order unbuildable: S7 (wrapper generator) needed
> the hypothesis registry that S8 created; S10 (preset compiler) came *after* a parity test that needs the
> full effective config the compiler produces; S11 depended on Candidate semantics that were still broken;
> and S2 proposed introducing "snapshot schema v4" when **HEAD is already v4**, so it would have collided.
> New order: **schema/ownership → registries/bindings → preset resolver → wrapper/parity → scheduler →
> Candidate/Deployment → pilot.**

| # | Slice | Acceptance cage | Prohibitions | Owner (`AGENTS.md`) |
|---|---|---|---|---|
| S1 | Monitoring integrity foundation (**= Stage 0B, DONE 2026-07-30**) | fixture tests green/warn/red/stale/blind + accounts with different base equity; each guard **observed firing** | no new risk threshold; no dashboard-local constants | Claude writes · Codex audits |
| S2 | **Ownership migration table + `OwnerRef` discipline** (new, from audit P0-2) | every Factory artifact holds owned facts only as pinned `OwnerRef`; owner-by-owner sign-off recorded; zero mutable copies | may not demote any owner without its owner's approval | **Claude writes** |
| S3 | Schema validator + per-entity **negative** fixtures | every entity rejects at least one crafted bad instance; root discriminator rejects an unknown `entity`; **`reconciliation_clear`** **computed**, a supplied value rejected | every constraint this slice claims is enforced by a validator that exists — see `x-enforcement-status`, which is what makes that claim checkable rather than aspirational | Codex/Sonnet |
| S4 | Snapshot **v5** + reconciliation + compatibility outputs made fail-closed | seeded N discovered ⇒ exactly N categorized or explicit `UNKNOWN`; missing/unreadable mandatory source ⇒ no `ALL CLEAR`; `make_status.ps1` and the digest read the validated snapshot and refuse to render on a failed build | not v4 (taken); no independently calculated totals anywhere | Codex/Sonnet |
| S5 | Registries + **ParameterBinding** resolver (universe, profiles, hypotheses, coverage) | round-trip; `NOT_APPLICABLE` refused without a reason; `MASTER_BACKLOG` §2 generated and matching; generator and `optimize_guard` provably read **one** resolver | no verdict field in any of these files | Codex/Sonnet · Claude reviews |
| S6 | Preset compiler + effective-config fingerprint | unknown key refused; partial set refused; generated `.set` full-surface and deterministic; `[CFG]` emits the fingerprint | must not read the terminal cache | Codex/Sonnet |
| S7 | Parameter registry extension + Operator/Research surface, **Boss_14 only** | `param_registry_check` CLEAN; zero `UNKNOWN` on Boss_14's Operator surface; old `.set` migrates or **fails loudly** | no key renames; no strategy/default behaviour change | **Claude writes** · Codex blind-audits |
| S8 | Thin Wrapper generator + **7-point parity harness** (§5.5) | all parity cases incl. must-trade and deliberate-refusal; wrapper contains zero logic; regenerates byte-identical `.mq5` | no wrapper edited by hand; no generation beyond the pilot | **Claude writes** · Codex audits |
| S9 | Recoverable scheduler (§20.8 Contract B) | kill at **every** state in §3.3 ⇒ resume re-runs zero completed attempts, double-launches nothing, duplicates no event; lane-lock test; cross-lane comparison **refused** | no process kill, no `-Force`, no tester-safety change | **Claude writes** · Codex audits |
| S10 | Candidate identity + append-only Deployment attestation + magic reservation | candidate digest recomputed and compared on read; no non-`OBSERVED` attestation event without a human authorization ref; `check_state.ps1` stays green; legacy magic exceptions preserved | no auto-update of any deployment; no renumbering of a live magic | **Claude writes** |
| S11 | Control Center shell + TODAY/WORK/LIVE/SYSTEM in **shadow mode** | all 30 handoff acceptance scenarios; **`SafeProjection` DTO**: forbidden-key recursive scan + synthetic secret/account fixtures | no dispatch, claim, or closure from the UI; Telegram must not be able to read the full snapshot | Codex/Sonnet |
| S12 | Direct Telegram Control Room + Morning Brief | alerts work with OpenClaw stopped; dedupe key includes severity + material revision; per-channel delivery ledger; one recovery message; escalation is never swallowed | no token in git/log/HTML/chat; OpenClaw not in the path | Codex/Sonnet |
| S13 | Boss_14 H01/H02 pilot matrix end-to-end | §8.6 checklist | automation stops at `EVIDENCE_COMPLETE` | mixed; batch to qwen/ZCode |
| S14 | Work Receipts + legacy handoff import (**gated on an `AGENTS.md` §2 permission change**) | duplicate Order+Receipt+handoff+commit renders as **one** row with all provenance; similar titles do **not** auto-merge | ❌ must not start until the user ratifies the new writer surface | Codex/Sonnet |
| S15 | Expand Core Universe + other Boss families | pilot passed first | no bulk migration before that | mixed |

Batch execution goes to qwen/ZCode (decision 77). Core/money/EA code is written by the Claude seat and
blind-audited by Codex (decisions 75, 76; `AGENTS.md` §5.2).

---

## 11. Genuinely unresolved decisions (the only ones)

Everything else in this document follows from a locked decision or an existing rule. These do not, and
several are the user's alone because they change a bar, change a governance rule, or spend wall-clock.

> ✅ **DECIDED 2026-07-30 (user):** magic uniqueness moves to **global scope** (Grill decision 56). I
> flagged the cost first — three magics (`990103`, `991001`, `991002`) are on two accounts each today and
> `991001` is on real money — and the user confirmed. Consequences now written into the design: global
> scope applies to **new** allocations; the three existing collisions are recorded as `legacy_exception`
> and **frozen until their judge date**, never renumbered as a side effect. Renumbering a live magic, if
> ever wanted, is its own order.
> ✅ **CLOSED 2026-08-02 (ORDER-1100, S10).** The invariant was amended by the user on 2026-08-01
> (`PROJECT_STATE.md` §0.5) and the checker has now flipped, in that order — the exception list
> (`factory/magic_allocations.jsonl`) had to exist first, because flipping the rule before it existed
> would have reddened three rows the owner had just declared legitimate. Nothing here is owed.

1. **Trial-count → required-confirmation ladder.** §6.7 records trial count but nothing consumes it.
   Proposal to react to: ≤50 trials ⇒ current bars · 51–500 ⇒ **plus** one independent confirmation
   (second symbol **or** holdout) · >500 ⇒ **plus** Model-4 and a second instrument.
   **This changes the bar table ⇒ user ratification required** (ORDER-235 precedent). Not adopted here.
2. **The `PENDING-RATIFY` participation floor.** `CLAUDE.md` already records that `n ≥ 30` screens out
   *having no trades*, not *having too few to interpret* — hosts cleared BWD on 52–62 trades at <2% DD
   while failing hosts took 343–473. The Factory OS makes trades-per-window computable per cell for the
   first time. **The number is still the user's to set.**
3. ✅ **DECIDED 2026-08-01 (user) — Inputs.mqh token-guard rollout = PER-BOSS, starting with Boss_14.**
   <sub>TH verbatim: *"ทำตามที่นายแนะนำ 2 ข้อเลย"* — ratifying the recommendation as written below.</sub>
   Considered: per-Boss (safe, slow, two conventions coexist for weeks) vs all-eight at once (fast, one
   convention, risks all eight builds together). **Chosen: per-Boss starting with Boss_14**, because
   `tpl_regression.ps1` gives per-EA drift detection, so a broken Boss is one row and not eight.
   **What this decision now binds:**
   - Boss_14 is the first and only build converted until its parity + regression evidence is green; the
     next Boss is a separate step, not a continuation of the same commit.
   - **Two conventions coexisting is EXPECTED, not drift** — no guard may treat "some builds converted,
     some not" as a failure while the rollout is in progress. A guard that cannot express *partially
     rolled out* will be satisfied by rolling back, which is the opposite of the intent.
   - The rollout order is recorded before the first conversion, and a build is only counted converted
     when `tpl_regression` is CLEAN **on the lane that compiled it** (the lane-mismatch trap, §5.5).
4. ✅ **DECIDED 2026-08-01 (user) — old `.set` policy = FAIL-LOUD plus a separate migration tool.**
   Considered: fail-loud on unknown/removed keys (safe, breaks stored sets) vs migrate-with-report
   (convenient, can silently mis-migrate). **Chosen: fail-loud, and migration is its own explicit tool** —
   `.set` files are how live configuration reaches a chart, and this repo has already lost three days to a
   bundled `.set` that silently set `AllowLive=false`.
   **What this decision now binds:**
   - An unknown or removed key in a `.set` is a **refusal that names the key**, never a skipped line and
     never a default substituted underneath. Silence here is the exact failure mode being bought out.
   - The migration tool **writes a new file and never edits in place**, and reports every key it changed,
     dropped, or could not map — a migration whose report is empty must be provably a no-op.
   - The `2,177` tracked `.set` files are **not** bulk-migrated. They fail loudly when used, and are
     migrated on demand. A bulk pass is a silent rewrite of live configuration by another name.
   - This does not soften `preset.py`'s existing rule (§5.7): a **partial** `.set` is still refused
     outright, separately from the unknown-key rule.
5. **Artifact store location and backup.** Blobs outside git (content-addressed dir + drilled restore) vs
   git-lfs. Affects cost and the backup drill, and there is a P2 backup-drill item already in the backlog.
6. **Core Universe v1 membership.** Which symbol×TF cells are *mandatory* (decision 24 says Core Universe
   is compulsory). Every added cell is Baseline + probe × every hypothesis, so this is a direct wall-clock
   cost the user should set, not the system.

7. **The "~10,000 combinations per round" budget has no executable definition** *(raised by the audit;
   rev 1 claimed this was reconciled and it was not)*. The ratified policy says fine complete grid ≤1,000
   per zone; the locked requirement says ~10,000 per round. Rev 1 asserted the first governs the second.
   The audit's counter-example stands: a genetic coarse pass plus **one** 125-combination fine grid
   satisfies "≤1,000 per zone" and misses "~10,000 per round" — and an orchestrator could declare
   compliance either way. What is missing is the number of zones, a minimum total search, and a stop rule.
   **The owner of that requirement must define it; I will not pick the numbers.**
8. **`AGENTS.md` §2 permission change for Work Receipt writers.** The design gives "any agent" a new
   writable surface, but today an agent may write only its own taskboard order row plus new
   reports/CSV/sets per order. Either the permission table is amended by the user first, or S14 does not
   start. Implementation must never edit `AGENTS.md` to authorize itself.
9. **CSV vs JSONL as the canonical storage for the new registries.** The audit is right that rev 1's
   schemas used typed arrays and booleans while naming CSV owners, and CSV yields strings with no
   round-trip rule for lists or nulls. Rev 2 moved these to `.jsonl`. If the user prefers CSV for
   hand-editability, the encoding grammar and round-trip fixtures have to be specified instead.

**Deliberately not reopened:** the 78 locked Grill decisions, the VERDICT GATE bars, the Model-2 ban, the
3-year MAIN window, cap-breach-resize-first, correlation→reduce-lot, and the cross-install comparison ban.

---

## 12. Summary answers the master file asks for

**What is reused:** the entire Boss thin-wrapper pattern (a Boss `.mq5` is already 12 lines), the parameter
registry and its `param_registry_check` cage, the linkage/override table, the build-inert audit, the
repaired `optimize_guard`, `tpl_regression` with its now-explicit lane pin, `mt5_run`/`mt5_optimize`, the
report-freshness guard, the experiment event log and its evidence registry, `control_room_snapshot.json`
as the projection ancestor, `DEPLOYMENTS.csv`/`ACCOUNTS.csv`/`ATTESTATION_MAP.csv`, `check_state.ps1`,
the fast-cage tier, the session ledger as a lane-lease source, and `PIPELINE.md` as stage routing.

**What must be built:** the **two genuinely unowned facts** of §1.3 (versioned Test Universe, scheduler
recovery checkpoint) plus the **three partly-new** ones (candidate bundle identity, finding lifecycle,
chat-commitment receipts); the `OwnerRef` discipline and the ownership migration table; the wrapper
generator and the seven-point parity harness; the recoverable scheduler; the preset compiler; the
effective-config fingerprint; the Control Center shell and its two domains; the `SafeProjection` DTO; and
the direct Telegram path with a per-channel delivery ledger. **The other six "new facts" of rev 1 turned
out to have owners and are references, not builds.**

**Source-of-truth map:** §1.1 (kept), §1.2 (retired/demoted), §1.3 (what is actually unowned), §1.5 (the
§20.7 extension).

**Unresolved implementation questions:** §11 — **nine**, four of them user-only (trial ladder,
participation floor, ~10k round budget, `AGENTS.md` §2 permission), plus the magic-invariant amendment
recorded as decided-but-blocking.

**Pilot acceptance checklist:** §8.6.

**What Codex must blind-audit:** §13.

---

## 13. Stage 2 — the blind audit brief

Codex receives **this document and the workspace, and nothing else**. It must not be shown any Claude
self-assessment of this design (anti-anchoring, `AGENTS.md` §5). At minimum it must attack:

1. **Duplicate source of truth.** Does any entity in §2 or §4 restate a fact §1.1 already owns? The most
   likely offenders: Coverage vs `MASTER_BACKLOG` §2, Candidate vs the scorecard, Deployment vs
   `DEPLOYMENTS.csv`, Run vs the event log.
2. **False `ALL CLEAR` and stale/offline paths.** Can the reconciliation equation pass while a source is
   silently missing? Can a Factory view render green from a stale snapshot? Does "could not read the
   input" stay distinguishable from "nothing to report" everywhere, including the Factory domain?
3. **Generated-wrapper safety and parity.** Is trade-list identity sufficient? What behaviour could differ
   between wrapper and parent that an identical trade list would hide? Does the `const`-instead-of-`input`
   transformation change anything besides the surface?
4. **Parameter linkage and provisional/certifiable boundaries.** Can an `EXPERIMENTAL` module's evidence
   reach a promotion path? Can a locked parameter be optimized through any route — a `.set`, an `.ini`, a
   default, or the terminal cache?
5. **Lane and data provenance.** Is there any path by which two numbers from different installs can be
   compared or aggregated — including inside a chart, an average, or a heatmap cell?
6. **Job recovery and idempotency.** Kill the machine at each state in §3.3: what is lost, what is
   double-counted, what silently re-runs? Does the freshness proof survive a resume?
7. **Candidate/Deployment immutability.** Find a way to mutate a candidate or auto-advance a deployment.
   Does the content-addressed id actually cover every field that changes behaviour?
8. **Permissions, privacy, alert dedupe.** Can the online projection leak an account number, a lot size, a
   money amount, a token, or strategy logic? Can a single state change produce two alerts, or a flapping
   state produce silence?
9. **Vertical-slice testability and rollback.** Is each slice in §10 independently verifiable, and does
   each rollback actually restore the prior state — or only appear to?
10. **The claims in this document.** Specifically: that a Boss wrapper is already thin; that MQL5 has no
    expression conditionals; that 177/184 and 181/184 registry rows are `UNKNOWN`; that the static and
    Inputs-page counts of visible inputs disagree by ~15; and §6.2's assertion that the ratified
    ≤1,000-per-complete-grid rule governs over the Grill's "~10,000 combinations per round".

**Known weak points, stated in advance so the audit does not have to find them first:** §6.7's trial
ladder has no numbers; §9's artifact store has no location decided; the Control Center's local-vs-published
split (decision 10 says local web app, today's mechanism is a published gist) is designed only at the level
of "safe projection vs full projection".

<sub>*Rev 1 also listed the §5.3 input-count discrepancy here. It was not a weak point, it was a counting
bug — see §5.3. Listing a bug as a known unknown is how it survives an audit, and it nearly did.*</sub>

---

## 14. Audit response — every finding, and what changed

The blind audit (`_triage/_archive/codex_reviews/factory_os/2026-08-repository-hygiene/CODEX_BLIND_AUDIT_2026-07-30.md`, verdict **NO-GO**) returned
**22 findings: 2 P0 and 20 P1**, across the design, the appendix, and two existing scripts.
*(I described it as "20" in conversation before counting the three in its own "other findings" section —
the number is 22.)*

Every factual correction it made about this document was re-measured here before being accepted, and all
of them held. Nothing was accepted on the auditor's authority alone.

| # | Finding | Status | Where it landed |
|---|---|---|---|
| 1 | **P0** appendix root validates almost anything | **FIXED** | schemas rev 2: discriminated union on `entity`, `unevaluatedProperties:false` throughout, structural checker committed |
| 2 | **P0** "eleven unowned facts" false; forks §20.7 | **FIXED** | §1.3 rewritten — 2 genuinely unowned, 3 partly new, 6 references; `OwnerRef` is now the only way to carry a fact you do not own |
| 3 | `ALL CLEAR` not enforceable by the schema | **FIXED, NARROWLY** — the field is now **`reconciliation_clear`**, not a global all-clear | `reconciliation_clear` computed and a supplied value rejected; mandatory-source registry separate from discovered; category + coverage totals encoded; `read_ok` **and** `fresh` both required. ⚠️ It is **reconciliation only** — it deliberately excludes `system_health`, `floating_risk`, `deployments.gaps`, `unknown_magics`, `attestation` and `judge_readiness`, so a snapshot with a `NO_SENSOR` fleet sensor can be `reconciliation_clear: true` **correctly**. A *global* fleet verdict needs health contracts for those six and is **S4**, not this row. |
| 4 | `make_status.ps1` still has an "unreadable = nothing found" path | **ACCEPTED, code owed** | S4 — compatibility outputs must read the validated snapshot and refuse to render on a failed build |
| 5 | Candidate hash self-referential | **FIXED** | `CandidatePayload` (hashed, no id) + `CandidateManifest` (digest + payload); validator recomputes |
| 6 | Candidate hash misses behaviour + evidence lineage | **FIXED** | payload gained module set with stability, profile **content** hashes, source/allowlist/generator hashes, effective config, per-window evidence |
| 7 | Run/Attempt not crash-safe | **FIXED** | append-only journal; lease owner/expiry/PID; `launched_at` before launch; exit code on receipt; `failure_class`; event id |
| 8 | Idempotency key does not cover the real config | **FIXED** | `ExecutionKey` requires deposit, currency, leverage, all four hashes, fingerprint, lane |
| 9 | EXPERIMENTAL evidence can reach a Candidate | **FIXED** | `experimental` required (not defaulted); `ModuleUse.stability`; validator resolves evidence→run→module set |
| 10 | Parameter role at the wrong level | **FIXED** | new `ParameterBinding` per hypothesis revision; registry keeps permanent semantics; generator and guard share one resolver |
| 11 | Lane provenance permits cross-install aggregation | **FIXED** | `MetricRef` — every metric carries its own run, lane, fingerprint, model; MAIN and BWD can no longer share one lane field |
| 12 | Trade-list identity insufficient for parity | **FIXED** | §5.5 is now 7 points + must-trade and deliberate-refusal cases |
| 13 | Deployment immutability only a promise | **FIXED** | append-only `DeploymentAttestationEvent`; any non-`OBSERVED` event requires a human authorization ref |
| 14 | Magic allocator contradicts the ratified invariant | **FIXED** | global scope adopted; legacy collisions frozen to judge; the invariant was amended by the user 2026-08-01 and `check_state.ps1` flipped to the global rule on 2026-08-02 (ORDER-1100) **once the exception list existed to read** — that order was the whole constraint |
| 15 | "Safe projection by construction" has no construction | **FIXED** | `SafeProjection` allowlist DTO: masked account, DD **band** not number, no money/lots/logic; forbidden-key scan + secret fixtures in S11 |
| 16 | Alert dedupe has no delivery state | **PARTIAL** | severity + `material_revision` in the dedupe key now; **per-channel delivery ledger and FLAPPING reminder policy owed in S12** |
| 17 | Slice dependency order unusable; v4 collision | **FIXED** | §10 reordered to 15 slices; snapshot goes to **v5** |
| 18 | Migration/rollback do not restore prior state | **FIXED** | §9 corrected: `UNVERIFIED_IMPORT` added to the enum, shadow kept separate from canonical, dual-read to a cutover gate, reverse projection instead of delete, drilled restore |
| 19 | "~10,000 per round" not actually reconciled | **CONCEDED → §11.7** | rev 1 claimed a reconciliation it had not made; the requirement's owner must define zones, minimum total search and a stop rule |
| 20 | JSON Schema types vs CSV storage | **FIXED** | registries moved to `.jsonl`; §11.9 if the user prefers CSV |
| 21 | `WAITING` weaker in schema than in prose | **FIXED** | `anyOf` → both fields required |
| 22 | New write authority without governance migration | **GATED** | §11.8; S14 must not start before the user amends `AGENTS.md` §2 |

**Not adopted:** the audit's recommendation to cut scope to three axes and defer the rest. The user chose
on 2026-07-30 to fix all findings and keep the full slice set. Its over-engineering list is preserved in
the audit file and should be revisited if the pilot runs long.

---

## 15. Second audit response (re-audit 2026-07-30, verdict NO-GO again)

The re-audit graded all 22: **3 CLOSED · 6 MOVED-honest · 1 MOVED-evasive · 5 RESTATED · 7 REGRESSED.**
Every one of its factual claims about this document was re-measured here before being accepted.

**The seven REGRESSED findings shared one cause, and it was the method, not the content:
I fixed the appendix and left this document stating the old contract, then added a note underneath
saying the old contract was wrong.** So schema and design disagreed — which is the exact failure this
design exists to prevent, reproduced inside the design itself. The note is not the contract; the table is.
Rev 3 rewrites the contracts in place and deletes the notes:

| What was regressed | Rev 3 |
|---|---|
| Candidate id defined two ways (§2 vs schema) | §2 now says the digest is over the **payload**, which does not contain the id |
| Job manifest missing deposit/currency/effective-config | §4.5 replaced by the full `ExecutionKey` contract |
| `role` still on the global registry in §4.2 | §4.2 rewritten as two files + one resolver |
| CoverageCell still flat lane/fingerprint in §4.4 | §4.4 rewritten around `MetricRef` |
| §8.6 pilot checklist still 5 trade-list cases | §8.4/§8.6 now judge all seven parity points, and require the must-trade and deliberate-refusal cases to have actually fired |
| CSV/YAML in §1.5, §4, wrapper comment, checklist | JSONL everywhere; storage stated once at the head of §4 |
| Rollback table still said delete/drop/repoint | §9's table itself rewritten, with cutover gates; the correction note is gone |

**New P0 it found, and it is a good one.** `SnapshotMeta` was declared the schema of
`control_room_snapshot.json` while describing a *flat* root — but the real document is
`{meta:{…}, system_health:[…], …}` with nine top-level keys. A validator built to it would have passed
a shape that never exists and reported the pipeline schema-clean **without ever validating the Control
Room snapshot**. Fixed: `ControlRoomSnapshotV5` is the document; `SnapshotMeta` is its `meta` property.

**Ownership P0 still open in rev 2, now closed in schema:** a `WorkReceipt` carrying `order_ref` may no
longer also hold title/owner/status/acceptance; `SystemFinding` must pin the snapshot that owns detector
state; legacy magic exceptions must name their accounts and are a closed imported set.

**Privacy leak it caught two fields from where I had been careful:** `SafeProjection` masked account
numbers and then emitted the raw `finding_id`, whose stable key can be `FND-sensor-159503454`. Findings
now carry an opaque `public_id`, and it is the only id the projection may serialize.

**Still owed after rev 3** — stated plainly rather than marked fixed:
canonical JSON serialization for the candidate digest is undefined (two serializers ⇒ two digests) ·
~~`all_clear`'s builder-input vs persisted-output boundary is not specified~~ **CLOSED by ORDER-601:**
the boundary is `SnapshotBuilderInput` → `snapshot_validator.verify_snapshot` → `ControlRoomSnapshotV5`,
the field is **`reconciliation_clear`**, and it is **recomputed on read** so a persisted document whose
answer contradicts its own evidence is refused · the delivery ledger is designed but unbuilt ·
~~**no real JSON Schema validator has run**~~ **superseded:** `ajv-cli` is installed and
`run_schema_fixtures.py` runs **35 draft-2020-12 cases**; `check_schema_structure.py` remains a linter
for the two things ajv cannot see (discriminator consistency, the closed-object inventory).

**§11 now holds nine open decisions, not six**, which the re-audit was right to flag as under-reported.

**Still owed before this design is safe to break into orders:** items 4 and 16 are design-complete but
code-owed; item 14 needs the user's Decision-log amendment; item 19 needs a number this design refuses to
invent; item 22 needs a governance change. **A re-review should confirm the P0s are genuinely closed
rather than restated** — the first audit's most valuable finding was a claim this document made about
itself, not a bug in a schema.
