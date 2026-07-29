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
   no owner today (there are eleven — §1.3), this design names exactly one new owner and says who writes it.
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

### 1.3 Facts with **no owner today** — the eleven this design creates

Each gets exactly one owner, one writer, one ID format, and one validator. Nothing here duplicates §1.1.

| # | New fact | Owner artifact | Writer | Why nothing owns it today |
|---|---|---|---|---|
| 1 | Hypothesis + its revisions | `factory/hypotheses.csv` | Claude/user | hypotheses live in order prose and die with the order |
| 2 | Test Universe (versioned symbol×TF sets) | `factory/universe.yaml` | Claude/user | "Core Universe" exists only as a sentence |
| 3 | Coverage cell state | `factory/coverage.csv` (generated + curated flags) | Automation writes state, Claude writes `NOT_APPLICABLE` | the coverage matrix is hand-typed and stale |
| 4 | Instrument Profile (asset class → symbol override → broker/lane map) | `factory/instrument_profiles.yaml` | Claude | `OPTIMIZATION_PROCEDURE_V2` §4 specifies it; no file implements it |
| 5 | Run / Attempt manifest | `factory/runs/<run_id>.json` | Automation | run state lives in ad-hoc `_mt5_auto` files; nothing survives a restart |
| 6 | Evidence bundle index | `factory/evidence/index.csv` → content-addressed store | Automation | raw reports are `.gitignore`d and referenced by path, not identity |
| 7 | Candidate manifest (immutable) | `factory/candidates/<candidate_id>.json` | Claude (on verdict) | "the locked .set" is a file path with a naming convention |
| 8 | Magic allocation | `factory/magic_allocations.csv` | Automation, Claude approves | uniqueness is enforced *after the fact* by `check_state.ps1` |
| 9 | Work Receipt | `ops/receipts/*.json` (append-only events → projection) | any agent | chat commitments vanish at handoff (handoff §7) |
| 10 | System Finding | `ops/findings.csv` | Automation, Claude resolves governance ones | detector output is transient console text |
| 11 | Idea Tank entry | `ops/ideas.csv` | Automation on intake | links are pasted into chat and lost |

**Naming rule:** every new artifact lives under `factory/` or `ops/` so that "is this a canonical owner or a
projection?" is answerable from the path alone. Generated projections go to `build/` and are never edited.

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
- **`ALL CLEAR` is one rule for both domains.** The handoff's reconciliation equation is promoted to a
  global invariant and applied to Factory data too:
  `discovered = categorized` and `categorized = actionable + running + waiting + review/audit + completed + cancelled_by_user`.
  For coverage: `cells_in_universe = tested + untested + not_applicable(with reason)`. Fail either and the
  page shows `UNKNOWN — ตรวจไม่ครบ` with `sources N/M · uncategorized N · conflicts N`. **Never translate
  silence into healthy** — and never translate *"I could not read the input"* into *"there is nothing to
  report"*, which is the specific defect Stage 0B is repairing in `daily_monitor.ps1` right now.

### 1.5 Extension of `§20.7` (not a fork)

| New artifact | Canonical owner + write path | Generated/reference rule |
|---|---|---|
| Hypothesis registry | `factory/hypotheses.csv`, single writer = Claude/user | Control Center renders; wrapper generator reads; neither writes back |
| Coverage cells | `factory/coverage.csv`, state written by the runner, `NOT_APPLICABLE` + reason written by Claude only | the heatmap and `MASTER_BACKLOG` §2 are generated from it |
| Run/Attempt manifests | `factory/runs/`, written only by the scheduler, append-only per attempt | evidence references resolve into the existing event log |
| Candidate manifests | `factory/candidates/`, written once at verdict, immutable thereafter | a change = a new candidate id, never an edit |
| Work Receipts | `ops/receipts/`, append-only events, single-writer projection | handoff view is generated; taskboard stays authoritative for Order state |
| Findings / Ideas | `ops/findings.csv`, `ops/ideas.csv` | dashboard and Telegram read the same IDs |

The rules of §20.7 carry over unchanged: **occurrence metadata + hashes + owner references only; no
result or verdict prose in any of them.**

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
| Candidate | `CAND-<sha256[:12]>` over the canonical manifest | any field changes ⇒ different id (immutability by construction) |
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

Full field/type/validation definitions live in the single appendix `_triage/factory_os/schemas.json`
(one file, `$defs` per entity — deliberately one file to avoid document sprawl). The design-level rules:

### 4.1 Hypothesis registry (`factory/hypotheses.csv`)
`hypothesis_id · boss_family · revision · title · causal_claim · falsifier · architecture_digest ·
module_set · coupling_class · safety_profile · status · created_commit · superseded_by`
- `causal_claim` and `falsifier` are **required non-empty**. A hypothesis you cannot falsify is a slogan.
- `architecture_digest` = hash of (entry module, exit owner, stack owner, lot owner, recovery, hedge,
  regime) — **this is what decides whether a change needs a new revision**, mechanically rather than by
  someone's judgment about whether the claim "really" changed.

### 4.2 Parameter Registry extensions (`docs/PARAM_REGISTRY.csv` — extend, do not fork)
Add: `role` ∈ {`TUNABLE`,`RUNTIME`,`SIZING`,`SAFETY`,`LOCKED`,`INACTIVE`} (decision 28) ·
`surface` ∈ {`OPERATOR`,`RESEARCH`,`HIDDEN`} · `display_label` · `enum_name` ·
`optimize_stage` · `safe_range_start/step/stop` · `precedence_owner` · `supported_profiles`.
- **Verified today: `OptimizeStage` is `UNKNOWN` on 177/184 rows and `SafeRange` on 181/184.** The
  registry can therefore answer "what does this parameter do" but **not** "which round should optimize it
  and over what range" — so it cannot yet generate an optimize plan. Filling it is a **discovery task per
  Boss, Operator surface first** (Codex's sequencing, adopted). The acceptance bar is "zero `UNKNOWN` on
  the Operator surface of Boss 11–18", not "all 184 rows".
- `role`/`surface` are what the wrapper generator reads. Existing columns keep their meaning, so
  `param_registry_check.ps1` (CLEAN today: 170 identifiers / 184 rows) keeps working through the change.

### 4.3 Test Universe (`factory/universe.yaml`) and Instrument Profile
- Universe is **versioned** (decision 25); a Candidate records which universe version it was searched in.
- `LogicalSymbol` is separate from the broker string (decision 26). Real cases already in the repo:
  `DE40` traded as `GER40`; `USDJPYm`/`EURUSDm` suffixed symbols on two accounts.
- InstrumentProfile layers exactly as `OPTIMIZATION_PROCEDURE_V2` §4 specifies:
  **AssetClass → SymbolOverride → Broker/LaneMapping** (decision 27), classes
  `FX_MAJOR · FX_JPY · GOLD · SILVER · CRYPTO · INDEX · ENERGY`.
- A profile carries **no signal optimization** — that separation is what makes profile reuse legitimate.

### 4.4 Coverage cells (`factory/coverage.csv`)
`cell_id · hypothesis_revision · logical_symbol · tf · universe_version · state · baseline_run_id ·
probe_run_id · best_pf_main · best_pf_bwd · trades_main · trades_bwd · dd_main · trial_count ·
lane · data_fingerprint · not_applicable_reason · last_updated_commit`
- `trades_*` and `dd_*` sit **next to** every PF by construction, because of the finding recorded in
  `CLAUDE.md` (memory `bar-cleared-by-non-participation`): the two hosts that cleared BWD did so on
  52 and 62 trades at under 2% drawdown, while every host that failed took 343–473. A schema that lets
  you print a PF without its participation is a schema that invites that mistake again.

### 4.5 Job manifest, evidence manifest, candidate manifest
- Job manifest: `run_id · attempt · cell_id · lane · terminal_path · data_dir · symbol · tf · from · to ·
  model · set_hash · ini_hash · ex5_hash · leverage · lease_id · state · started_at · finished_at ·
  exit_code · report_path · report_fresh_proof · data_fingerprint`.
- **Evidence is registered through the existing event-log utility** (`RegisterEvidence`,
  `evd_sha256_<raw sha256>`, committed Git artifacts only). No parallel evidence store is invented.
  The known rough edges are inherited and must be designed around, not rediscovered: `.ex5` binaries are
  gitignored and need `git add -f`; the evidence path pattern **forbids parentheses and spaces**, which
  the repo's `(EXP)_Name` convention violates; tick history has no committable artifact so `data` uses a
  committed **provenance descriptor** instead (`EVENT_LOG_ADOPTION.md` §6).
- Candidate manifest is the canonical-order JSON whose sha256 **is** the candidate id.

### 4.6 Magic allocator (`factory/magic_allocations.csv`)
`magic · allocated_to(candidate_id) · account · status · allocated_at · released_never`
- Globally unique across EA LAB, allocated automatically (decision 56), **never reused** even after a
  deployment ends — a reused magic silently re-attributes historical deals.
- Reserved ranges per Boss family so a magic tells you its family on sight.
- `check_state.ps1` already blocks duplicate `account|magic`; the allocator moves that from *detection
  after the fact* to *prevention*, and the existing check stays as the backstop.

### 4.7 Attribution key
`Deployment ID + Account + Magic + Symbol + Candidate/Variant identity` (decision 57). The current key is
`(magic, symbol)`, which cannot distinguish two revisions of the same EA on one account — exactly the
Champion–Challenger case §3.7 introduces.

---

## 5. (E) Thin Wrapper architecture

### 5.1 The good news from current state
`Boss_14_GridLog.mq5` is **13 lines**: two `#define`s and `#include "core/LabCore.mqh"`. The Boss family is
already a thin-wrapper pattern; the generator does not have to invent it, only to extend it with a
hypothesis token and a compile-time allowlist. This is the single largest reuse in this design.

### 5.2 Generated artifact
```mql5
//  GENERATED - do not edit. Source: factory/hypotheses.csv B14-H01-r2 @ <commit>
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
- Current state, measured: **209 `input`/`sinput` declarations, 25 `input group` sections, 28 preprocessor
  guards.** A static walk of the guards gives **128–153 visible inputs per Boss** (16 is the worst at 153);
  Codex's read of the actual MT5 Inputs page gave **113–135**. *The two methods disagree by ~15, and that
  discrepancy is itself a discovery task* — a design promising "zero inert visible inputs" needs a
  **measured** per-build surface, and today no two methods agree on what it is. Target after the change:
  **Operator ≤ 40** per Boss.

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
> A Thin Wrapper is valid **iff**, on one lane, one data fingerprint, one window and one model, the
> wrapper and the **parent Boss configured with the wrapper's effective config** produce an **identical
> trade list** — same count, same entry/exit times, same volumes, same prices.

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
- Transition-based, deduplicated by stable finding id + state: one alert, then silence until state
  changes, one recovery message.
- Workstation offline (heartbeat > 45 min) renders neutral `WORKSTATION OFFLINE / UNKNOWN` with last-sync
  time. **Never guess** hibernate vs crash vs network. Never nag about a known offline state.
- Telegram and Dashboard read **the same snapshot and the same event ids**, or they will drift.
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
1. Wrapper vs parent, compiled defaults, XAUUSD H1 — identical trade list.
2. Wrapper vs parent, pilot `.set`, XAUUSD H4 — identical trade list.
3. Locked parameter provably absent from the wrapper's Inputs page **and** its value provably applied.
4. A locked parameter's value changed in the registry ⇒ regenerate ⇒ behaviour changes ⇒ **parity vs the
   parent configured the same way still passes** (proves lock ≠ ignore).
5. Delete the whole generated tree, regenerate from the registry ⇒ byte-identical `.mq5`
   (note: **`.ex5` will not be byte-identical** — MQL5 compilation is not reproducible, memory
   `mql5-compile-not-byte-reproducible`; staleness is judged by mtime, never by hash).

### 8.5 Failure and rescue branches
`NO_PULSE` on a cell → rescue ladder R0–R4 (implementation/linkage audit → re-optimize related params →
adjacent architecture → symbol transfer → alternate profile/TF), ≥4 lever families, then
last-optimize-before-verdict, then a human verdict. Boundary hits expand the grid instead of concluding.

### 8.6 Pilot acceptance checklist (the pass/fail for the whole Stage-4 pilot)
- [ ] `factory/hypotheses.csv` holds B14-H01/H02 with causal claim **and** falsifier
- [ ] wrappers generate from the registry, contain zero logic, and regenerate byte-identically
- [ ] all 5 parity cases pass on one lane, with the lane named in the output
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

| Stage | Action | Rollback |
|---|---|---|
| M0 | Build `factory/` + `ops/` owners empty, with validators; change nothing else | delete the directories |
| M1 | Import: coverage cells generated from taskboard/scorecard history **as `UNVERIFIED_IMPORT`**, never as evidence | drop the file |
| M2 | Legacy handoff import → Work Receipts, exact-dedupe, provenance to every original file, originals untouched | delete receipts; `_triage/HANDOFF_*.md` still authoritative |
| M3 | Control Room shadow mode: new snapshot built alongside the old, totals compared, **user-facing URL unchanged** | stop building it |
| M4 | Switch the user-facing URL only after the totals agree and the acceptance scenarios pass | repoint to the old page |
| M5 | Pilot only: Boss_14 wrappers generated; parent Boss untouched and still compiling | delete `build/`; parent unchanged |
| M6 | Standalone EAs with proven edge ported one at a time as Boss hypotheses + parity (decision 70) | keep the standalone; it was never removed |

**Artifact store:** content-addressed, outside git for blobs, with the manifest and hashes **in** git
(decision 66/67). Backup and restore must be **drilled**, not assumed — an untested backup is a story
about a backup. Retention: candidate binary + `.set` + evidence kept permanently (decision 68).

**Rollback for the Control Center itself:** build to a temporary output, validate, then atomically replace
last-known-good. A failed build **retains last-known-good and labels it `STALE / BUILD FAILED`**. A
partially generated "current" page is never published.

---

## 10. (J) Implementation slices

Vertical, each independently verifiable, each with a cage that can fail. Dependency order is top to bottom.
**No taskboard Order may be written from this list until the blind audit is answered.**

| # | Slice | Acceptance cage | Prohibitions | Owner (`AGENTS.md`) |
|---|---|---|---|---|
| S1 | Monitoring integrity foundation (**= Stage 0B**) | fixture tests green/warn/red/stale/blind + two accounts with different base equity; each guard **observed firing** | no new risk threshold; no dashboard-local constants | Claude writes · Codex audits |
| S2 | Snapshot schema v4 + reconciliation validator + `ALL CLEAR` rule | seeded N discovered ⇒ exactly N categorized or explicit `UNKNOWN`; missing source ⇒ no `ALL CLEAR`; atomic build keeps last-known-good | no second projection; no independently calculated totals | Codex/Sonnet under order |
| S3 | Work Receipts + legacy handoff import + untracked-work adapter | duplicate Order+Receipt+handoff+commit renders as **one** row with all provenance; similar titles do **not** auto-merge; `[auto]` commits excluded | may not write taskboard state; may not cancel anything | Codex/Sonnet |
| S4 | Control Center shell + TODAY/WORK/LIVE/SYSTEM/IDEA in **shadow mode** | all 30 handoff acceptance scenarios; safe projection contains no accounts/tokens/lots/money amounts | no dispatch, no claim, no closure from the UI | Codex/Sonnet |
| S5 | Direct Telegram Control Room + Morning Brief | alerts work with OpenClaw stopped; repeated unchanged checks send nothing; one recovery message; hibernate intake acknowledged after resume | no token in git/log/HTML/chat; OpenClaw not in the path | Codex/Sonnet |
| S6 | Parameter registry extension + Operator/Research surface **for Boss_14 only** | `param_registry_check` CLEAN; zero `UNKNOWN` on Boss_14's Operator surface; old `.set` migrates or **fails loudly**, never silently ignored | no key renames; no strategy/default behaviour change | **Claude writes** · Codex blind-audits |
| S7 | Thin Wrapper generator + parity harness | 5 parity cases (§8.4); wrapper contains zero logic; regenerate byte-identical `.mq5` | no wrapper edited by hand; no bulk generation beyond the pilot | **Claude writes** · Codex audits |
| S8 | Hypothesis/Universe/Coverage/Profile registries + validators | round-trip; `NOT_APPLICABLE` refused without a reason; `MASTER_BACKLOG` §2 generated and matching | no verdict field anywhere in these files | Codex/Sonnet |
| S9 | Recoverable scheduler (§20.8 Contract B) | kill mid-batch ⇒ resume with zero completed attempts re-run; lane-lock test; cross-lane comparison **refused** | no process kill, no `-Force`, no tester-safety change | **Claude writes** · Codex audits |
| S10 | Preset compiler + effective-config fingerprint | unknown key refused; partial set refused; generated `.set` full-surface and deterministic | must not read the terminal cache | Codex/Sonnet |
| S11 | Candidate/Bench/Deployment identity + magic allocator + attestation | candidate id changes iff manifest changes; duplicate magic impossible; `check_state.ps1` stays green | no auto-update of any deployment | **Claude writes** |
| S12 | Boss_14 H01/H02 pilot matrix end-to-end | §8.6 checklist | automation stops at `EVIDENCE_COMPLETE` | mixed; batch to qwen/ZCode |
| S13 | Expand Core Universe + other Boss families | pilot passed first | no bulk migration before that | mixed |

Batch execution goes to qwen/ZCode (decision 77). Core/money/EA code is written by the Claude seat and
blind-audited by Codex (decisions 75, 76; `AGENTS.md` §5.2).

---

## 11. Genuinely unresolved decisions (the only ones)

Everything else in this document follows from a locked decision or an existing rule. These six do not,
and three of them are the user's alone because they change a bar or spend money.

1. **Trial-count → required-confirmation ladder.** §6.7 records trial count but nothing consumes it.
   Proposal to react to: ≤50 trials ⇒ current bars · 51–500 ⇒ **plus** one independent confirmation
   (second symbol **or** holdout) · >500 ⇒ **plus** Model-4 and a second instrument.
   **This changes the bar table ⇒ user ratification required** (ORDER-235 precedent). Not adopted here.
2. **The `PENDING-RATIFY` participation floor.** `CLAUDE.md` already records that `n ≥ 30` screens out
   *having no trades*, not *having too few to interpret* — hosts cleared BWD on 52–62 trades at <2% DD
   while failing hosts took 343–473. The Factory OS makes trades-per-window computable per cell for the
   first time. **The number is still the user's to set.**
3. **Inputs.mqh token-guard refactor: rollout shape.** Per-Boss (safe, slow, two conventions coexist for
   weeks) vs all-eight at once (fast, one convention, risks all eight builds together). Recommendation:
   **per-Boss starting with Boss_14**, because `tpl_regression` gives per-EA drift detection and a broken
   Boss is then one row, not eight. Needs confirmation because it sets the pace of everything after S6.
4. **Old `.set` compatibility policy.** Fail-loud on unknown/removed keys (safe, breaks stored sets) vs
   migrate-with-report (convenient, can silently mis-migrate). Recommendation: **fail-loud plus an
   explicit migration tool**, because `.set` files are how live configuration reaches a chart and this
   repo has already lost three days to a bundled `.set` that silently set `AllowLive=false`.
5. **Artifact store location and backup.** Blobs outside git (content-addressed dir + drilled restore) vs
   git-lfs. Affects cost and the backup drill, and there is a P2 backup-drill item already in the backlog.
6. **Core Universe v1 membership.** Which symbol×TF cells are *mandatory* (decision 24 says Core Universe
   is compulsory). Every added cell is Baseline + probe × every hypothesis, so this is a direct wall-clock
   cost the user should set, not the system.

**Deliberately not reopened:** the 78 locked Grill decisions, the VERDICT GATE bars, the Model-2 ban, the
3-year MAIN window, cap-breach-resize-first, correlation→reduce-lot, and the cross-install comparison ban.

---

## 12. Summary answers the master file asks for

**What is reused:** the entire Boss thin-wrapper pattern (a Boss `.mq5` is already 13 lines), the parameter
registry and its `param_registry_check` cage, the linkage/override table, the build-inert audit, the
repaired `optimize_guard`, `tpl_regression` with its now-explicit lane pin, `mt5_run`/`mt5_optimize`, the
report-freshness guard, the experiment event log and its evidence registry, `control_room_snapshot.json`
as the projection ancestor, `DEPLOYMENTS.csv`/`ACCOUNTS.csv`/`ATTESTATION_MAP.csv`, `check_state.ps1`,
the fast-cage tier, the session ledger as a lane-lease source, and `PIPELINE.md` as stage routing.

**What must be built:** the eleven unowned facts of §1.3, the wrapper generator and parity harness, the
recoverable scheduler, the preset compiler, the effective-config fingerprint, the Control Center shell
and its two domains, and the direct Telegram path.

**Source-of-truth map:** §1.1 (kept), §1.2 (retired/demoted), §1.3 (new), §1.5 (the §20.7 extension).

**Unresolved implementation questions:** §11 — six, three of them user-only.

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

**Known weak points, stated in advance so the audit does not have to find them first:** §5.3's input
counts come from two methods that disagree; §6.7's trial ladder has no numbers; §9's artifact store has no
location decided; the Control Center's local-vs-published split (decision 10 says local web app, today's
mechanism is a published gist) is designed only at the level of "safe projection vs full projection"; and
this document has been read by exactly one model.
