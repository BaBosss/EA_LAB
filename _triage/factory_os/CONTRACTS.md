# Factory OS — normative contracts

<sub>⚙️ **THIS WHOLE FILE IS GENERATED** from `_triage/factory_os/schemas.json` by
`_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and
regenerate. `--check` runs in the fast cage tier and exits 1 on any drift.</sub>

## Why this file exists, separately from the design

BACKLOG-D31 made the design's normative tables generated, which closed the seam seven audit
findings had regressed through: the design prose and the schema each stating a contract by hand,
with nothing binding them. It also grew `EA_LAB_FACTORY_OS_DESIGN.md` from 829 to 1807 lines —
while that document's own §7.4 is about being readable without exhausting an agent's context.

So the tables live here and the design links to them. The design keeps what only a human can
write: **rationale** — why a field exists, what it cost to learn. This file keeps what only the
schema can state: **the contract**. Neither can drift from the schema, because neither is
hand-written. Recommended independently by this seat and by Codex audit 5 (Q4).

**Where the authority sits:** `schemas.json` is normative, this file renders it, and the design
explains it. If this file and the schema disagree, the generator has not been run — that is drift,
not a decision, and `--check` will say so.

**The design must link every contract below.** That is checked, not assumed: an entity nobody
references is an entity nobody reviews, and `validate_coverage` refuses it.

<!-- BEGIN GENERATED CONTRACT: __STORAGE__ -->
### __STORAGE__

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

| entity | canonical storage | writer | enforced by |
|---|---|---|---|
| `OwnerRef` | *embedded in its parent — no file* | — | candidate.owner_ref_resolution_problems: RESOLUTION, which JSON Schema cannot express. R1 commit_oid:path resolves to a blob; R2 that blob is the one blob_oid names; R3 sha256 over the blob's raw bytes equals raw_sha256; R4 anchor contains no spaces and occurs EXACTLY once in the blob - the rule stated in prose on the field below, which nothing read until ORDER-1263. The schema checks the PATTERNS only, and three well-formed hex fields can identify three different documents: an authorization_ref whose path was VISION.md, whose blob_oid was PROJECT_STATE.md's and whose raw_sha256 was unrelated validated clean on a CANDIDATE_ASSIGNED event. |
| `Hypothesis` | `factory/hypotheses.jsonl` | claude|user | hypothesis_validator: status transitions, and the refusal to register without a falsifier |
| `ModuleUse` | *embedded in its parent — no file* | — | — |
| `ParameterBinding` | `factory/parameter_bindings.jsonl` | claude | — |
| `TestUniverse` | `factory/universe.jsonl` | claude|user | — |
| `LogicalSymbol` | `factory/universe.jsonl` | — | — |
| `InstrumentProfile` | `factory/instrument_profiles.jsonl` | — | — |
| `MetricRef` | *embedded in its parent — no file* | — | run_schema_fixtures.py: ajv validates the pf/pf_state conditional in BOTH directions, over the crafted fixtures AND over every live row of every registry store |
| `CoverageCell` | `factory/coverage.jsonl` | automation for state; claude only for not_applicable_reason | coverage_validator: comparison-group same-lane rule; MASTER_BACKLOG section 2 regenerated from this, never hand-edited |
| `ExecutionKey` | *embedded in its parent — no file* | — | — |
| `RunAttempt` | *embedded in its parent — no file* | — | — |
| `RunTransition` | `factory/runs/<run_id>.jsonl - ONE OF THESE PER LINE, append-only` | the scheduler only | _triage/factory_os/run_schema_fixtures.py: ajv validates every committed factory/runs/*.jsonl RunTransition row; exactly three byte-pinned historical manifests are visible LEGACY_EXCEPTION results until their event-log occurrence is durable |
| `RunJournal` | **derived, never written** — True | — | — |
| `EvidenceRef` | `docs/memory_control/experiment_events/evidence-manifest.jsonl (EXISTING - NOT replaced)` | — | — |
| `CandidatePayload` | *embedded in its parent — no file* | — | — |
| `CandidateManifest` | `factory/candidates/<candidate_id>.json` | claude, once, at verdict time | candidate_validator: MUST recompute sha256 over the canonical serialization of `payload` and compare to candidate_digest. The schema checks the PATTERN only - it cannot verify a hash. |
| `MagicAllocation` | `factory/magic_allocations.jsonl` | automation allocates; claude approves; user ratifies scope changes | allocator: global uniqueness for NEW allocations; check_state.ps1 remains the account\|magic backstop |
| `DeploymentAttestationEvent` | `portfolio/ATTESTATION_MAP.csv (EXISTING) + append-only event log` | claude|user only | attestation_validator: no actor other than user/claude may append an event that changes candidate_id or status; automation may append OBSERVED events only |
| `WorkReceipt` | `ops/receipts/*.jsonl (append-only events -> single-writer projection)` | PENDING GOVERNANCE CHANGE - see description | receipt_validator: only the user may write CANCELLED_BY_USER |
| `SystemFinding` | `ops/findings.jsonl` | — | finding_validator: RUNTIME resolves only after two consecutive healthy checks; GOVERNANCE/AUDIT/DEPLOYMENT_DRIFT never auto-close |
| `IdeaRef` | `INTAKE_QUEUE.md (EXISTING - NOT replaced)` | — | — |
| `ControlRoomSnapshotV5` | `portfolio/control_room_snapshot.json (EXISTING, v4 at HEAD)` | — | snapshot_validator: reconciliation_clear is COMPUTED and MUST NOT be read from input |
| `ReconciliationEvidence` | `the `meta.reconciliation` property of a SnapshotBuilderInput and of portfolio/control_room_snapshot.json` | — | snapshot_validator: this object is the INPUT to the reconciliation_clear computation and never contains the answer |
| `SnapshotVerdict` | `the `verdict` property of portfolio/control_room_snapshot.json - written ONLY by snapshot_validator` | — | snapshot_validator.verify_snapshot: recomputes reconciliation_clear from the persisted evidence and refuses a document whose stored verdict does not match. Proves INTERNAL CONSISTENCY, not authenticity: read_ok/age_hours/path/sha256/mtime and the reconciliation counts are builder claims taken at face value (Codex audit 6 accepted a document whose sources all pointed at a nonexistent drive with mtime 2099). Deriving them from the real files and re-hashing on read is S4. NOT on every READ - Codex audit 6 measured that no reader calls load_verified(); wiring readers is S4, so the honest status today is BUILT_NOT_WIRED |
| `SnapshotBuilderInput` | `NONE - transient. Produced by the snapshot builder, consumed by snapshot_validator, never persisted.` | — | snapshot_validator.build_snapshot: refuses a supplied answer via a recursive forbidden-key scan (verdict / reconciliation_clear / all_clear / reasons) UNCONDITIONALLY; refuses a schema-invalid input only when called with ajv_schema_validator, which the fast computation suite does not do. Treat the schema half as enforced at the load_verified() boundary, not on every code path |
| `RuntimeIdentityObserved` | `runtime sidecars collected under portfolio/live_deals/` | — | runtime_identity.py: validates the EA-emitted identity shape and build/artifact evidence |
| `RuntimeIdentityRecord` | `runtime_identity in portfolio/control_room_snapshot.json` | — | runtime_identity.py: annotates collected identity records with fail-closed validation state |
| `RuntimeIdentitySummary` | `runtime_identity_summary in portfolio/control_room_snapshot.json` | — | monitor_coverage.ps1: red-lines missing, legacy, mixed, or failed runtime identity evidence |
| `SnapshotMeta` | `the `meta` property of portfolio/control_room_snapshot.json` | — | — |
| `SafeProjection` | `build/safe_projection.json (derived, never hand-written)` | — | projection_validator: recursive forbidden-key scan + synthetic secret/account fixtures; the Telegram sender MUST NOT be able to read the full snapshot |
| `AlertEvent` | **derived, never written** — True | — | notifier.assert_sendable: the declared SHAPE checked against this file, PLUS safe_projection.scan_forbidden run with the real snapshot secret list - the layer the sender structurally cannot run |
| `AlertDelivery` | `ops/delivery_ledger.jsonl` | — | notifier.deliver: every event produces exactly one line whatever happened, and dedupe reads DELIVERED and nothing else |

<!-- END GENERATED CONTRACT: __STORAGE__ -->

<!-- BEGIN GENERATED CONTRACT: Hypothesis -->
### Hypothesis

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`Hypothesis`** · stored in `factory/hypotheses.jsonl` · written by *claude|user* · enforced by *hypothesis_validator: status transitions, and the refusal to register without a falsifier*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `Hypothesis` | **yes** |  |
| `hypothesis_id` | `string` | **yes** | pattern `^B(1[1-8])-H[0-9]{2}$` |
| `boss_family` | `integer` | **yes** | min `11` · max `18` |
| `revision` | `integer` | **yes** | min `1` |
| `revision_id` | `string` | — | pattern `^B(1[1-8])-H[0-9]{2}-r[0-9]+$` |
| `architecture_digest` | `string` | **yes** | pattern `^[0-9a-f]{16}$` · hash of (entry, exit_owner, stack_owner, lot_owner, recovery, hedge, regime). Change here MECHANICALLY forces a new revision. |
| `module_set` | array of [`ModuleUse`](#moduleuse) | **yes** | minItems `1` |
| `coupling_class` | `SCALE_INVARIANT` \| `COUPLED` | **yes** |  |
| `experimental` | `boolean` | **yes** | REQUIRED, not defaulted. Audit P1: JSON Schema `default` does not populate a missing field, so a consumer would have read absent as false and let an experimental module reach a promotion path. |
| `engine_edge` | `boolean` | — |  |
| `status` | `DRAFT` \| `REGISTERED` \| `WRAPPER_GENERATED` \| `PARITY_PASSED` \| `EVIDENCE_IN_PROGRESS` \| `EVIDENCE_COMPLETE` \| `AWAITING_VERDICT` \| `CLOSED` | **yes** |  |
| `preregistration_ref` | [`OwnerRef`](#ownerref) | **yes** | the taskboard order that owns the causal claim, falsifier and pre-registered bars. This entity does NOT copy them. |
| `superseded_by` | `string` \| `null` | — |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: Hypothesis -->

<!-- BEGIN GENERATED CONTRACT: ModuleUse -->
### ModuleUse

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`ModuleUse`** · embedded — has no file of its own

| field | type | required | rule |
|---|---|---|---|
| `token` | `string` | **yes** | pattern `^LAB_CAP_[A-Z0-9_]+$` |
| `module_version` | `string` | **yes** |  |
| `stability` | `EXPERIMENTAL` \| `CERTIFIABLE` | **yes** |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: ModuleUse -->

<!-- BEGIN GENERATED CONTRACT: OwnerRef -->
### OwnerRef

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`OwnerRef`** · embedded — has no file of its own · enforced by *candidate.owner_ref_resolution_problems: RESOLUTION, which JSON Schema cannot express. R1 commit_oid:path resolves to a blob; R2 that blob is the one blob_oid names; R3 sha256 over the blob's raw bytes equals raw_sha256; R4 anchor contains no spaces and occurs EXACTLY once in the blob - the rule stated in prose on the field below, which nothing read until ORDER-1263. The schema checks the PATTERNS only, and three well-formed hex fields can identify three different documents: an authorization_ref whose path was VISION.md, whose blob_oid was PROJECT_STATE.md's and whose raw_sha256 was unrelated validated clean on a CANDIDATE_ASSIGNED event.*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `OwnerRef` | **yes** |  |
| `owner_type` | `taskboard_order` \| `scorecard` \| `project_state` \| `deployments_csv` \| `accounts_csv` \| `attestation_map` \| `master_backlog` \| `param_registry` \| `param_linkage` \| `intake_queue` \| `event_log` \| `evidence_manifest` \| `session_ledger` \| `optimization_procedure` | **yes** |  |
| `path` | `string` | **yes** |  |
| `commit_oid` | `string` | **yes** | pattern `^[0-9a-f]{40}$` |
| `blob_oid` | `string` | **yes** | pattern `^[0-9a-f]{40}$` |
| `raw_sha256` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `anchor` | `string` \| `null` | — | must occur EXACTLY once in the blob and contain no spaces - inherited constraint from the event log utility |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: OwnerRef -->

<!-- BEGIN GENERATED CONTRACT: META_parameter_registry_columns -->
### META_parameter_registry_columns

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

| column | meaning | scope |
|---|---|---|
| owner | which module reads this input | global |
| unit_true | what the CODE does with the number, not what the name claims - the chassis holds two meanings of 'pip' at once | global |
| context | where in the strategy it applies | global |
| active_when | the condition under which this input has any effect at all | global |
| coupled_with | inputs that must move with it or the strategy changes rather than resizes | global |
| causal_question | the question a sweep of this input answers | global |
| classification | OPERATOR / TUNING / OVERRIDE / DEAD - OVERRIDE means member of a precedence chain, NOT dead (Stage 0A P0) | global |
| display_label | the label the generated Inputs page shows | global |
| enum_name | the enum type when the input is an enum, so a diff table cannot compare a name against a number | global |
| precedence_owner | which sibling wins when an OVERRIDE chain has more than one member set | global |
| role | ABSENT FROM THIS TABLE ON PURPOSE - role/locked_value/safe_range/optimize_stage are per-hypothesis and live in factory/parameter_bindings.jsonl | NOT A COLUMN |

<!-- END GENERATED CONTRACT: META_parameter_registry_columns -->

<!-- BEGIN GENERATED CONTRACT: ParameterBinding -->
### ParameterBinding

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`ParameterBinding`** · stored in `factory/parameter_bindings.jsonl` · written by *claude*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `ParameterBinding` | **yes** |  |
| `hypothesis_revision` | `string` | **yes** | pattern `^B(1[1-8])-H[0-9]{2}-r[0-9]+$` |
| `parameter` | `string` | **yes** | ORDER-672: the BARE parameter name. A build tag inside this string is REFUSED -- `StackMode[LAB_ENTRY_16]` encodes two facts in the join key, which produced F1 (a tagged binding invisible to its only consumer: bare => AMBIGUOUS, tagged => unseen, jointly unsatisfiable) and half of S7 (last-wins across rows that disagree). The tag lives in build_tag. Two encodings of one fact is the defect, not a migration path. |
| `parameter_pid` | `integer` | **yes** | min `10000` · max `99999` · R4 global five-digit parameter identity; it must resolve back to parameter exactly. |
| `build_tag` | `string` \| `null` | — | pattern `^LAB_ENTRY_[0-9A-Za-z_]+$` · ORDER-672: which BUILD this binding is about, or null for "every build of the revision". A field, not a suffix -- so "these rows disagree, therefore the binding must name the tag" is representable IN THE DATA rather than inferred by whichever call site remembered to run a parser. A second parser of that string is a second resolver. |
| `role` | `TUNABLE` \| `RUNTIME` \| `SIZING` \| `SAFETY` \| `LOCKED` \| `INACTIVE` | **yes** |  |
| `surface` | `OPERATOR` \| `RESEARCH` \| `HIDDEN` | **yes** |  |
| `locked_value` | `any` | — | required when role=LOCKED; emitted as a const by the generator |
| `optimize_stage` | `ARCHITECTURE` \| `SIGNAL` \| `EXIT` \| `EXECUTION` \| `STRESS` \| `FREEZE` \| `UNKNOWN` | — |  |
| `safe_range` | `object` \| `null` | — | closed · requires `start`, `step`, `stop` |
| `safe_range.start` | `number` | **yes** |  |
| `safe_range.step` | `number` | **yes** |  |
| `safe_range.stop` | `number` | **yes** |  |
| `definition_ref` | [`OwnerRef`](#ownerref) | **yes** | pins the docs/PARAM_REGISTRY.csv row that owns this parameter's permanent semantics |

**Unknown fields:** rejected (closed object).

**Conditional requirements:**
- **when `role` = `LOCKED`** → requires `locked_value`

<!-- END GENERATED CONTRACT: ParameterBinding -->

<!-- BEGIN GENERATED CONTRACT: TestUniverse -->
### TestUniverse

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`TestUniverse`** · stored in `factory/universe.jsonl` · written by *claude|user*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `TestUniverse` | **yes** |  |
| `universe_version` | `string` | **yes** | pattern `^v[0-9]+$` |
| `kind` | `CORE` \| `EXPANSION` \| `PILOT` | **yes** |  |
| `symbols` | array of `string` | **yes** | minItems `1` |
| `timeframes` | array of `M5` \| `M15` \| `M30` \| `H1` \| `H4` \| `D1` | **yes** | minItems `1` |
| `created_commit` | `string` | **yes** | pattern `^[0-9a-f]{40}$` |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: TestUniverse -->

<!-- BEGIN GENERATED CONTRACT: LogicalSymbol -->
### LogicalSymbol

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`LogicalSymbol`** · stored in `factory/universe.jsonl`

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `LogicalSymbol` | **yes** |  |
| `logical` | `string` | **yes** |  |
| `asset_class` | `FX_MAJOR` \| `FX_JPY` \| `GOLD` \| `SILVER` \| `CRYPTO` \| `INDEX` \| `ENERGY` | **yes** |  |
| `broker_map` | `object` | **yes** | lane id -> broker symbol. Real cases: DE40 traded as GER40; USDJPYm/EURUSDm suffixed. |
| `swap_mode` | `POINTS` \| `INTEREST_CURRENT` \| `UNKNOWN` | — | MEASURED. The tester charges POINTS-mode swap (XAUUSD verified -29.25) but not INTEREST_CURRENT (BTCUSD -14.67%/yr), which must then be deducted post-hoc from measured holding time. |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: LogicalSymbol -->

<!-- BEGIN GENERATED CONTRACT: InstrumentProfile -->
### InstrumentProfile

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`InstrumentProfile`** · stored in `factory/instrument_profiles.jsonl`

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `InstrumentProfile` | **yes** |  |
| `profile_id` | `string` | **yes** |  |
| `profile_version` | `integer` | **yes** | min `1` |
| `content_hash` | `string` | **yes** | pattern `^[0-9a-f]{64}$` · hash of the RESOLVED profile content. Candidates hash this, not the id. |
| `layer` | `ASSET_CLASS` \| `SYMBOL_OVERRIDE` \| `BROKER_LANE` | **yes** |  |
| `asset_class` | `FX_MAJOR` \| `FX_JPY` \| `GOLD` \| `SILVER` \| `CRYPTO` \| `INDEX` \| `ENERGY` | — |  |
| `account_unit` | `USD` \| `CENT` | — |  |
| `values` | `object` | — |  |
| `semantics_ref` | [`OwnerRef`](#ownerref) | — |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: InstrumentProfile -->

<!-- BEGIN GENERATED CONTRACT: CoverageCell -->
### CoverageCell

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`CoverageCell`** · stored in `factory/coverage.jsonl` · written by *automation for state; claude only for not_applicable_reason* · enforced by *coverage_validator: comparison-group same-lane rule; MASTER_BACKLOG section 2 regenerated from this, never hand-edited*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `CoverageCell` | **yes** |  |
| `cell_id` | `string` | **yes** |  |
| `hypothesis_revision` | `string` | **yes** | pattern `^B(1[1-8])-H[0-9]{2}-r[0-9]+$` |
| `logical_symbol` | `string` | **yes** |  |
| `tf` | `M5` \| `M15` \| `M30` \| `H1` \| `H4` \| `D1` | **yes** |  |
| `universe_version` | `string` | **yes** |  |
| `state` | `UNTESTED` \| `BASELINE_RUN` \| `PROBE_RUN` \| `PULSE` \| `NO_PULSE` \| `RESCUE_IN_PROGRESS` \| `EVIDENCE_COMPLETE` \| `NOT_APPLICABLE` \| `UNVERIFIED_IMPORT` | **yes** |  |
| `metrics` | array of [`MetricRef`](#metricref) | **yes** | PF is unrepresentable without trades and dd_pct by construction: two BWD-clearing hosts had 52 and 62 trades at under 2% DD while every failing host had 343-473. |
| `trial_count` | `integer` | **yes** | min `0` |
| `boundary_hit` | `boolean` | — | true = best result on a grid edge; the cell may NOT be closed until the range is expanded |
| `not_applicable_reason` | `string` \| `null` | — |  |
| `backlog_ref` | [`OwnerRef`](#ownerref) | — |  |

**Unknown fields:** rejected (closed object).

**Conditional requirements:**
- **when `state` = `NOT_APPLICABLE`** → requires `not_applicable_reason` · `not_applicable_reason` → `string` (minLength `10`)

<!-- END GENERATED CONTRACT: CoverageCell -->

<!-- BEGIN GENERATED CONTRACT: MetricRef -->
### MetricRef

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`MetricRef`** · embedded — has no file of its own · enforced by *run_schema_fixtures.py: ajv validates the pf/pf_state conditional in BOTH directions, over the crafted fixtures AND over every live row of every registry store*

| field | type | required | rule |
|---|---|---|---|
| `window` | `MAIN` \| `BWD` \| `HOLDOUT` \| `OTHER` | **yes** |  |
| `pf` | `number` \| `null` | **yes** | null ONLY with pf_state = UNDEFINED_NO_LOSSES. Never 0 to mean undefined: 0 is a real PF (a run with winners worth nothing) and the tester prints it for both, which is how the inversion happened. |
| `pf_state` | `DEFINED` \| `UNDEFINED_NO_LOSSES` | **yes** | Why pf is or is not a number. Required so that an absent denominator has to be DECLARED rather than encoded as a value. |
| `trades` | `integer` | **yes** | min `0` |
| `dd_pct` | `number` | **yes** |  |
| `run_id` | `string` | **yes** |  |
| `lane` | `string` | **yes** |  |
| `data_fingerprint` | `string` | **yes** |  |
| `model` | `1` \| `2` \| `4` | **yes** |  |

**Unknown fields:** rejected (closed object).

**Conditional requirements:**
- **when `pf_state` = `DEFINED`** → `pf` → `number`
- **when `pf_state` = `UNDEFINED_NO_LOSSES`** → `pf` → `null`

<!-- END GENERATED CONTRACT: MetricRef -->

<!-- BEGIN GENERATED CONTRACT: RunTransition -->
### RunTransition

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`RunTransition`** · stored in `factory/runs/<run_id>.jsonl - ONE OF THESE PER LINE, append-only` · written by *the scheduler only* · enforced by *_triage/factory_os/run_schema_fixtures.py: ajv validates every committed factory/runs/*.jsonl RunTransition row; exactly three byte-pinned historical manifests are visible LEGACY_EXCEPTION results until their event-log occurrence is durable*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `RunTransition` | **yes** |  |
| `run_id` | `string` | **yes** | pattern `^RUN-[0-9]{8}-[0-9]{3,}$` |
| `cell_id` | `string` | **yes** |  |
| `execution_key` | `any` | — | written once, on the QUEUED line |
| `attempt` | `integer` | **yes** | min `1` |
| `transition` | `QUEUED` \| `LEASED` \| `LAUNCH_INTENT` \| `PROCESS_OBSERVED` \| `RUNNING` \| `COMPLETED` \| `FAILED` \| `ABANDONED` \| `EVIDENCE_REGISTERED` | **yes** |  |
| `at` | `string` | **yes** |  |
| `record` | [`RunAttempt`](#runattempt) | — |  |
| `event_log_ref` | [`OwnerRef`](#ownerref) | — |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: RunTransition -->

<!-- BEGIN GENERATED CONTRACT: RunAttempt -->
### RunAttempt

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`RunAttempt`** · embedded — has no file of its own

| field | type | required | rule |
|---|---|---|---|
| `attempt` | `integer` | **yes** | min `1` |
| `transition` | `QUEUED` \| `LEASED` \| `LAUNCH_INTENT` \| `PROCESS_OBSERVED` \| `RUNNING` \| `COMPLETED` \| `FAILED` \| `ABANDONED` \| `EVIDENCE_REGISTERED` | **yes** |  |
| `at` | `string` | **yes** |  |
| `lease` | `object` \| `null` | — | closed · requires `lease_id`, `owner`, `expires_at` · SELF-REVIEW FIX: rev 3 required `pid` on the lease, but LEASED happens BEFORE any process exists - the lane is reserved first. A schema that demands a fact nobody can know yet is a schema that gets filled with a placeholder. pid moves to process_observed and is not part of the lease. |
| `lease.lease_id` | `string` | **yes** |  |
| `lease.owner` | `string` | **yes** |  |
| `lease.expires_at` | `string` | **yes** | without an expiry a machine that died holding a lease keeps the lane forever |
| `launch_intent_at` | `string` \| `null` | — | written BEFORE spawn. Its presence with no process_observed means the crash happened around the spawn and the resume must RECONCILE (is an MT5 already running on this lane?) rather than launch again. |
| `report_path` | `string` \| `null` | — | the report path bound by LAUNCH_INTENT for this attempt; later transitions cannot replace that identity |
| `process_observed` | `object` \| `null` | — | closed · requires `pid`, `observed_at` · SELF-REVIEW FIX: rev 3 had a single `launched_at` written before launch, which cannot distinguish crash-before-spawn from crash-after-spawn - the exact hole the field was added to close. Two records, so the pair is decidable. |
| `process_observed.pid` | `integer` | **yes** |  |
| `process_observed.observed_at` | `string` | **yes** |  |
| `process_observed.process_fingerprint` | `string` \| `null` | — |  |
| `ini_sha256` | `string` \| `null` | — | pattern `^[0-9a-f]{64}$` · USER DECISION 2026-08-02 (USER_DECISIONS_PENDING item 6): the sha256 of the .ini the runner actually wrote, recorded PER ATTEMPT and AFTER the file exists. It moved here from ExecutionKey, where it was a fact nobody could know at the moment the key was needed. Identity lives in the key; forensics - what exactly was handed to the tester - lives here, where it can be true. |
| `exit_code` | `integer` \| `null` | — | persisted immediately on receipt - the freshness guard needs exit 0/3 and cannot reconstruct it |
| `failure_class` | `NONE` \| `TESTER_ERROR` \| `TERMINAL_ERROR` \| `TIMEOUT` \| `LEASE_LOST` \| `KILLED` \| `CONFIG_REJECTED` | — | decision 18 permits a re-run of an identical ExecutionKey only after an execution or a tester error. USER DECISION 2026-08-02 (USER_DECISIONS_PENDING item 7) ratified that those are two CATEGORIES, not two enum members: tester = TESTER_ERROR; execution = TERMINAL_ERROR, TIMEOUT, KILLED, LEASE_LOST; neither, and therefore still blocked = CONFIG_REJECTED. This description used to name only TESTER_ERROR and TERMINAL_ERROR, and read literally it made a machine crash a permanent block on the configuration - in the slice whose whole purpose is recovery. |
| `report_fresh_proof` | `object` \| `null` | — |  |
| `event_id` | `string` \| `null` | — | id returned by the existing event-log append, so a crash between append and EVIDENCE_REGISTERED does not duplicate the occurrence on retry |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: RunAttempt -->

<!-- BEGIN GENERATED CONTRACT: RunJournal -->
### RunJournal

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`RunJournal`** · **DERIVED** — True · stored in `NONE - derived by folding the RunTransition lines of one run_id. Never persisted, never written.`

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `RunJournal` | **yes** |  |
| `run_id` | `string` | **yes** | pattern `^RUN-[0-9]{8}-[0-9]{3,}$` |
| `cell_id` | `string` | **yes** |  |
| `execution_key` | `any` | **yes** |  |
| `attempts` | array of [`RunAttempt`](#runattempt) | **yes** | minItems `1` |
| `event_log_ref` | [`OwnerRef`](#ownerref) | — |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: RunJournal -->

<!-- BEGIN GENERATED CONTRACT: ExecutionKey -->
### ExecutionKey

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`ExecutionKey`** · embedded — has no file of its own

| field | type | required | rule |
|---|---|---|---|
| `expert` | `string` | **yes** |  |
| `symbol` | `string` | **yes** |  |
| `tf` | `string` | **yes** |  |
| `from_date` | `string` | **yes** |  |
| `to_date` | `string` | **yes** |  |
| `model` | `1` \| `2` \| `4` | **yes** |  |
| `deposit` | `number` | **yes** |  |
| `currency` | const `USD` | **yes** |  |
| `account_unit` | `USD` \| `CENT` | **yes** |  |
| `leverage` | `integer` | **yes** | written as 1:N in the ini and asserted post-run; a bare Leverage=N is a silent no-op |
| `terminal_build` | `integer` | **yes** | min `0` · numeric build component mechanically read from the resolved terminal64.exe FileVersion; never inferred from lane or caller text |
| `set_hash` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `ex5_hash` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `effective_config_hash` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `data_fingerprint` | `string` | **yes** |  |
| `lane` | `string` | **yes** |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: ExecutionKey -->

<!-- BEGIN GENERATED CONTRACT: EvidenceRef -->
### EvidenceRef

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`EvidenceRef`** · stored in `docs/memory_control/experiment_events/evidence-manifest.jsonl (EXISTING - NOT replaced)`

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `EvidenceRef` | **yes** |  |
| `evidence_id` | `string` | **yes** | pattern `^evd_sha256_[0-9a-f]{64}$` |
| `kind` | `REPORT` \| `SET` \| `INI` \| `EX5` \| `SOURCE` \| `DATA_PROVENANCE` \| `CSV` \| `OTHER` | **yes** |  |
| `path` | `string` | **yes** | pattern `^[A-Za-z0-9_./\\-]+$` |
| `commit_oid` | `string` | **yes** | pattern `^[0-9a-f]{40}$` |
| `raw_sha256` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: EvidenceRef -->

<!-- BEGIN GENERATED CONTRACT: CandidatePayload -->
### CandidatePayload

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`CandidatePayload`** · embedded — has no file of its own

| field | type | required | rule |
|---|---|---|---|
| `hypothesis_revision` | `string` | **yes** |  |
| `module_set` | array of [`ModuleUse`](#moduleuse) | **yes** | minItems `1` |
| `experimental` | `boolean` | **yes** | MUST be false for any candidate on a promotion path; the validator additionally resolves every evidence -> run -> module set and fails if any module is not CERTIFIABLE |
| `logical_symbol` | `string` | **yes** |  |
| `tf` | `string` | **yes** |  |
| `build_tag` | `string` | **yes** | pattern `^LAB_ENTRY_[0-9A-Za-z_]+$` · ORDER-1268. The build whose input surface `parameters` claims to BE. Added because `parameters` was required to be the FULL effective surface while nothing named the surface it was full OF, so the only enforceable reading of the rule was non-emptiness - and a one-key map validated clean. Inputs.mqh declares StackMode eight times, once per LAB_ENTRY tag, and no single build exposes all 184 declarations, so a parameter map without its build is a map against no surface at all. |
| `parameters` | `object` | **yes** | FULL effective surface OF build_tag, key for key. A partial set lets unlisted inputs be filled from the per-terminal tester cache - the documented root cause of the ORDER-165 8/8 false drift. ORDER-1268: enforced by resolving build_tag's surface out of ea_template/core/Inputs.mqh and comparing key sets, through the same setfile.surface_problems the .set reader uses - one policy, two callers. |
| `profiles` | object *(fields below)* | **yes** | closed · requires `instrument`, `exit`, `sizing`, `safety`, `execution` · content hashes, not mutable string ids - otherwise instrument_profiles could change under a fixed id and the candidate would still look valid |
| `profiles.instrument` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `profiles.exit` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `profiles.sizing` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `profiles.safety` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `profiles.execution` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `evidence` | array of [`MetricRef`](#metricref) | **yes** | minItems `1` · per window, each with its own run/lane/fingerprint - MAIN and BWD cannot share a fingerprint and must not be flattened to one |
| `ex5_sha256` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `source_sha256` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `allowlist_sha256` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `generator_version` | `string` | **yes** |  |
| `effective_config_hash` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `universe_version` | `string` | **yes** |  |
| `trial_count` | `integer` | **yes** | min `0` |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: CandidatePayload -->

<!-- BEGIN GENERATED CONTRACT: CandidateManifest -->
### CandidateManifest

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`CandidateManifest`** · stored in `factory/candidates/<candidate_id>.json` · written by *claude, once, at verdict time* · enforced by *candidate_validator: MUST recompute sha256 over the canonical serialization of `payload` and compare to candidate_digest. The schema checks the PATTERN only - it cannot verify a hash.*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `CandidateManifest` | **yes** |  |
| `candidate_id` | `string` | **yes** | pattern `^CAND-[0-9a-f]{12}$` · DISPLAY id = first 12 hex of candidate_digest. Never the hash input. |
| `candidate_digest` | `string` | **yes** | pattern `^[0-9a-f]{64}$` · full sha256 over the canonical serialization of `payload` - which does not contain it |
| `payload` | [`CandidatePayload`](#candidatepayload) | **yes** |  |
| `scorecard_ref` | [`OwnerRef`](#ownerref) | **yes** | the verdict TEXT lives in EA_SCORECARD_AND_REGISTRY.md and is never copied here |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: CandidateManifest -->

<!-- BEGIN GENERATED CONTRACT: MagicAllocation -->
### MagicAllocation

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`MagicAllocation`** · stored in `factory/magic_allocations.jsonl` · written by *automation allocates; claude approves; user ratifies scope changes* · enforced by *allocator: global uniqueness for NEW allocations; check_state.ps1 remains the account|magic backstop*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `MagicAllocation` | **yes** |  |
| `magic` | `integer` | **yes** | min `1` |
| `scope` | `GLOBAL` \| `LEGACY_ACCOUNT_SCOPED` | **yes** | GLOBAL for everything allocated from now on; LEGACY_ACCOUNT_SCOPED only for the pre-existing collisions |
| `legacy_exception` | `boolean` | — |  |
| `legacy_accounts` | array of `string` | — | populated only for legacy exceptions; frozen until judge |
| `allocated_to` | `string` \| `null` | — | candidate_id. Deployment status is NOT copied here - DEPLOYMENTS.csv owns it. |
| `deployment_ref` | [`OwnerRef`](#ownerref) | — |  |
| `status` | `RESERVED` \| `ASSIGNED` \| `RETIRED` | **yes** | RETIRED is never re-issued - a reused magic silently re-attributes historical deals |
| `allocated_at_commit` | `string` | **yes** | pattern `^[0-9a-f]{40}$` |
| `imported_in_cutover` | `boolean` | — | RE-AUDIT P1: legacy exceptions are a CLOSED SET imported once, not an open category. Rev 2 let an unlimited number of new LEGACY_ACCOUNT_SCOPED rows be minted, which would have quietly reintroduced account-scoped magics forever. The allocator refuses a legacy row with imported_in_cutover=false after the cutover commit. |

**Unknown fields:** rejected (closed object).

**Conditional requirements:**
- **when `scope` = `LEGACY_ACCOUNT_SCOPED`** → requires `legacy_exception`, `legacy_accounts`, `imported_in_cutover` · `legacy_exception` → const `True` · `legacy_accounts` → array of `any` (minItems `2`) · scope and the exception flags must agree, and a legacy exception exists precisely because the magic is on more than one account
- **otherwise (no `scope` = `LEGACY_ACCOUNT_SCOPED`)** → `legacy_exception` → const `False`

<!-- END GENERATED CONTRACT: MagicAllocation -->

<!-- BEGIN GENERATED CONTRACT: DeploymentAttestationEvent -->
### DeploymentAttestationEvent

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`DeploymentAttestationEvent`** · stored in `portfolio/ATTESTATION_MAP.csv (EXISTING) + append-only event log` · written by *claude|user only* · enforced by *attestation_validator: no actor other than user/claude may append an event that changes candidate_id or status; automation may append OBSERVED events only*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `DeploymentAttestationEvent` | **yes** |  |
| `prev_hash` | `string` | **yes** | pattern `^[0-9a-f]{64}$` · ORDER-1260 #3: sha256 of the canonical bytes of the PREVIOUS line, or 64 zeros for the first. Replay alone could not tell an appended log from an edited one - an edited event is still a well-formed event in a well-ordered log - so attestation.validate_event A8 chains them. It protects every event that has a successor; the LAST line is only protected by pinning the head elsewhere |
| `event_id` | `string` | **yes** |  |
| `account` | `string` | **yes** |  |
| `magic` | `integer` | **yes** |  |
| `event_type` | `OBSERVED` \| `CANDIDATE_ASSIGNED` \| `CANDIDATE_REASSIGNED` \| `ATTEST_STATE_CHANGED` \| `FROZEN` \| `RETIRED` | **yes** |  |
| `at` | `string` | **yes** |  |
| `actor` | `user` \| `claude` \| `automation` | **yes** |  |
| `authorization_ref` | [`OwnerRef`](#ownerref) | — | REQUIRED for any event that is not OBSERVED - the human decision that authorized it |
| `candidate_id` | `string` \| `null` | — |  |
| `attest_state` | `HASHED` \| `PARTIAL` \| `FILE_MISSING` \| `UNVERIFIED` \| `None` | — |  |
| `core_revision` | `string` \| `null` | — |  |
| `deployment_ref` | [`OwnerRef`](#ownerref) | **yes** |  |

**Unknown fields:** rejected (closed object).

**Conditional requirements:**
- **when `event_type` `any`** → requires `authorization_ref` · `actor` → `user` \| `claude`

<!-- END GENERATED CONTRACT: DeploymentAttestationEvent -->

<!-- BEGIN GENERATED CONTRACT: WorkReceipt -->
### WorkReceipt

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`WorkReceipt`** · stored in `ops/receipts/*.jsonl (append-only events -> single-writer projection)` · written by *PENDING GOVERNANCE CHANGE - see description* · enforced by *receipt_validator: only the user may write CANCELLED_BY_USER*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `WorkReceipt` | **yes** |  |
| `receipt_id` | `string` | **yes** | pattern `^WRK-[0-9]{8}-[0-9]{3}$` |
| `title` | `string` | — |  |
| `source_agent` | `claude` \| `codex` \| `automation` \| `legacy` | **yes** |  |
| `requested_at` | `string` | **yes** |  |
| `order_ref` | [`OwnerRef`](#ownerref) | — | when present, the taskboard owns status/acceptance/owner and this Receipt must NOT restate them |
| `owner` | `string` | — |  |
| `status` | `CAPTURED` \| `READY` \| `IN_PROGRESS` \| `WAITING` \| `BLOCKED` \| `HANDOFF` \| `DONE_PENDING_REVIEW` \| `AUDIT_REQUIRED` \| `AUDIT_IN_PROGRESS` \| `REWORK` \| `REVIEWED` \| `CANCELLED_BY_USER` \| `STATE_CONFLICT` | — | DONE is deliberately absent - DONE is not closed. No AGING/NEGLECTED state exists either. |
| `next_action` | `string` | — |  |
| `acceptance` | `string` \| `null` | — |  |
| `evidence_refs` | array of `string` | — |  |
| `blocked_by` | array of `string` | — |  |
| `review_required` | `boolean` | — |  |
| `rework_cycles` | `integer` | — | min `0` |
| `waiting_for` | `string` \| `null` | — |  |
| `wake_condition` | `string` \| `null` | — |  |
| `handoff_summary` | `string` \| `null` | — |  |
| `cancelled_by_user_ref` | `string` \| `null` | — |  |

**Unknown fields:** rejected (closed object).

**Conditional requirements:**
- **when `order_ref` present** → **REFUSED if it also carries** `title`, `owner`, `status`, `acceptance` · RE-AUDIT P0: a Receipt that references an ORDER may NOT also carry title/owner/status/acceptance. Those are taskboard facts, and holding a second mutable copy is the ownership fork this design exists to prevent - Order REVIEWED while Receipt still IN_PROGRESS. Read them through order_ref.
- **otherwise (no `order_ref` present)** → requires `title`, `owner`, `status` · a Receipt with no Order is the only case where it owns these - a chat commitment not yet formalised
- **when `status` = `WAITING`** → requires `waiting_for`, `wake_condition` · `waiting_for` → `string` · `wake_condition` → `string` · Audit P1: rev 1 used anyOf here, so one of the two sufficed - which produced exactly the indefinitely-parked item the design says it prevents. Both are now required.
- **when `status` = `CANCELLED_BY_USER`** → requires `cancelled_by_user_ref`
- **when `status` = `HANDOFF`** → requires `handoff_summary`, `next_action`, `evidence_refs`, `review_required`

<!-- END GENERATED CONTRACT: WorkReceipt -->

<!-- BEGIN GENERATED CONTRACT: SystemFinding -->
### SystemFinding

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`SystemFinding`** · stored in `ops/findings.jsonl` · enforced by *finding_validator: RUNTIME resolves only after two consecutive healthy checks; GOVERNANCE/AUDIT/DEPLOYMENT_DRIFT never auto-close*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `SystemFinding` | **yes** |  |
| `finding_id` | `string` | **yes** | pattern `^FND-[A-Za-z0-9_]+-[A-Za-z0-9_.:-]+$` · INTERNAL ONLY. Its stable key may legitimately contain an account number, a magic, or a strategy name (e.g. FND-sensor-159503454), so it MUST NOT be serialized into any online or Telegram surface. |
| `public_id` | `string` | **yes** | pattern `^FP-[0-9a-f]{10}$` · RE-AUDIT P1: opaque projection-safe identifier - the ONLY finding id a SafeProjection may carry. Rev 2 leaked the raw finding_id into the online projection while carefully masking account numbers two fields away. |
| `detector_ref` | [`OwnerRef`](#ownerref) | **yes** | RE-AUDIT P0: the snapshot owns detector state. Without a pinned reference this entity becomes a second, drifting copy - snapshot RESOLVED while the finding still reads OPEN. |
| `detector` | `string` | **yes** |  |
| `class` | `RUNTIME` \| `GOVERNANCE` \| `DEPLOYMENT_DRIFT` \| `AUDIT` | **yes** |  |
| `severity` | `INFO` \| `WARN` \| `CRITICAL` \| `REAL_MONEY` | **yes** | part of the alert dedupe key - audit P1: dedupe on (id,state) alone would swallow a warning that escalated to real-money critical while the state stayed OPEN |
| `material_revision` | `integer` | **yes** | min `0` · REQUIRED. Bumped whenever the payload materially changes, and part of the dedupe key alongside severity - dedupe on (id,state) alone swallows a WARN that escalates to REAL_MONEY while the state stays OPEN |
| `first_seen` | `string` | **yes** |  |
| `last_seen` | `string` | **yes** |  |
| `state` | `OPEN` \| `HEALTHY_1_OF_2` \| `RESOLVED` \| `FLAPPING` \| `SUPPRESSED_MAINTENANCE` | **yes** |  |
| `occurrences_24h` | `integer` | — |  |
| `evidence_refs` | array of `string` | — |  |
| `owner` | `string` \| `null` | — |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: SystemFinding -->

<!-- BEGIN GENERATED CONTRACT: IdeaRef -->
### IdeaRef

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`IdeaRef`** · stored in `INTAKE_QUEUE.md (EXISTING - NOT replaced)`

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `IdeaRef` | **yes** |  |
| `idea_id` | `string` | **yes** | pattern `^IDEA-[0-9]{4}$` |
| `received_at` | `string` | **yes** |  |
| `source` | `telegram` \| `claude` \| `codex` \| `legacy_openclaw` | **yes** |  |
| `normalized_url` | `string` \| `null` | — |  |
| `duplicate_of` | `string` \| `null` | — |  |
| `status` | `NEW` \| `READ` \| `SHORTLIST` \| `REFERENCE` \| `DROP` \| `ORDER` | **yes** |  |
| `intake_ref` | [`OwnerRef`](#ownerref) | **yes** |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: IdeaRef -->

<!-- BEGIN GENERATED CONTRACT: SnapshotBuilderInput -->
### SnapshotBuilderInput

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`SnapshotBuilderInput`** · stored in `NONE - transient. Produced by the snapshot builder, consumed by snapshot_validator, never persisted.` · enforced by *snapshot_validator.build_snapshot: refuses a supplied answer via a recursive forbidden-key scan (verdict / reconciliation_clear / all_clear / reasons) UNCONDITIONALLY; refuses a schema-invalid input only when called with ajv_schema_validator, which the fast computation suite does not do. Treat the schema half as enforced at the load_verified() boundary, not on every code path*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `SnapshotBuilderInput` | **yes** |  |
| `meta` | [`SnapshotMeta`](#snapshotmeta) | **yes** |  |
| `system_health` | array of `object` | **yes** |  |
| `floating_risk` | array of `object` | **yes** |  |
| `deployments` | `object` | **yes** |  |
| `unknown_magics` | array of `any` | **yes** |  |
| `attestation` | array of `any` | **yes** |  |
| `judge_readiness` | array of `any` | **yes** |  |
| `judge_cohorts` | array of `object` | **yes** | MEASURED 2026-07-31 (ORDER-612 / S4): this was `type: object` and the real document has always carried an ARRAY of 17 per-judge-date cohort rollups (scripts/control_room_snapshot.ps1 `$cohorts`). The first build of a v5 document was refused by ajv naming `/judge_cohorts`, which is how it was found. It is the same defect class as rev 2's flat root: a contract that claims to describe a file and describes a shape the file never has. Nothing caught it earlier because no fixture ever validated the REAL document -- which is exactly what C1 of this order requires and why C1 is worded as a flip of that line rather than as a claim about it. |
| `summary` | `object` | **yes** |  |
| `runtime_identity` | array of [`RuntimeIdentityObserved`](#runtimeidentityobserved) | — |  |
| `runtime_identity_summary` | object *(fields below)* | — | closed · requires `state`, `records`, `identity_findings` |
| `runtime_identity_summary.state` | `PASS` \| `FAIL` \| `LEGACY_UNVERIFIED` | **yes** |  |
| `runtime_identity_summary.records` | `integer` | **yes** | min `0` |
| `runtime_identity_summary.identity_findings` | array of object *(fields below)* | **yes** | items closed · items require `code`, `detail` |
| `runtime_identity_summary.identity_findings[].code` | `string` | **yes** | minLength `1` |
| `runtime_identity_summary.identity_findings[].detail` | `string` | **yes** |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: SnapshotBuilderInput -->

<!-- BEGIN GENERATED CONTRACT: ReconciliationEvidence -->
### ReconciliationEvidence

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`ReconciliationEvidence`** · stored in `the `meta.reconciliation` property of a SnapshotBuilderInput and of portfolio/control_room_snapshot.json` · enforced by *snapshot_validator: this object is the INPUT to the reconciliation_clear computation and never contains the answer*

| field | type | required | rule |
|---|---|---|---|
| `discovered` | `integer` | **yes** | min `0` |
| `categorized` | `integer` | **yes** | min `0` |
| `categories` | object *(fields below)* | **yes** | closed · requires `actionable`, `running`, `waiting`, `review_audit`, `completed`, `cancelled_by_user` · the equation's right-hand side must be ENCODED, not implied in prose |
| `categories.actionable` | `integer` | **yes** | min `0` |
| `categories.running` | `integer` | **yes** | min `0` |
| `categories.waiting` | `integer` | **yes** | min `0` |
| `categories.review_audit` | `integer` | **yes** | min `0` |
| `categories.completed` | `integer` | **yes** | min `0` |
| `categories.cancelled_by_user` | `integer` | **yes** | min `0` |
| `coverage` | object *(fields below)* | **yes** | closed · requires `cells_in_universe`, `tested`, `untested`, `not_applicable` |
| `coverage.cells_in_universe` | `integer` | **yes** | min `0` |
| `coverage.tested` | `integer` | **yes** | min `0` |
| `coverage.untested` | `integer` | **yes** | min `0` |
| `coverage.not_applicable` | `integer` | **yes** | min `0` |
| `duplicates` | `integer` | **yes** | min `0` |
| `conflicts` | `integer` | **yes** | min `0` |
| `unclassified` | `integer` | **yes** | min `0` |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: ReconciliationEvidence -->

<!-- BEGIN GENERATED CONTRACT: SnapshotVerdict -->
### SnapshotVerdict

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`SnapshotVerdict`** · stored in `the `verdict` property of portfolio/control_room_snapshot.json - written ONLY by snapshot_validator` · enforced by *snapshot_validator.verify_snapshot: recomputes reconciliation_clear from the persisted evidence and refuses a document whose stored verdict does not match. Proves INTERNAL CONSISTENCY, not authenticity: read_ok/age_hours/path/sha256/mtime and the reconciliation counts are builder claims taken at face value (Codex audit 6 accepted a document whose sources all pointed at a nonexistent drive with mtime 2099). Deriving them from the real files and re-hashing on read is S4. NOT on every READ - Codex audit 6 measured that no reader calls load_verified(); wiring readers is S4, so the honest status today is BUILT_NOT_WIRED*

| field | type | required | rule |
|---|---|---|---|
| `reconciliation_clear` | `boolean` | **yes** | COMPUTED, never supplied. True only when every mandatory source is present, read_ok and fresh; discovered==categorized; the category sum matches; the coverage sum matches; duplicates==0; conflicts==0; unclassified==0; and categories.actionable==0. SCOPE - narrower than the old name promised: computed from meta.reconciliation and the source rows ONLY. It was called `all_clear` until Codex audit 6 built a document with a NO_SENSOR fleet sensor, a BLIND floating-risk sensor, missing kill/judge controls, an UNCLASSIFIED unknown magic and missing attestation, and it verified true - because none of those domains reach the computation. system_health, floating_risk, deployments.gaps, unknown_magics, attestation, judge_readiness and summary are carried through UNCHECKED. Do not render this as Control Room health. |
| `reasons` | array of object *(fields below)* | **yes** | items closed · items require `code` · empty if and only if reconciliation_clear is true - the two must not be able to disagree |
| `reasons[].code` | `MANDATORY_SOURCE_MISSING` \| `MANDATORY_SOURCE_UNREADABLE` \| `MANDATORY_SOURCE_STALE` \| `SOURCE_REGISTRY_MISMATCH` \| `DUPLICATE_SOURCE_NAME` \| `SOURCE_MANDATORY_FLAG_CONTRADICTS_REGISTRY` \| `DISCOVERED_CATEGORIZED_MISMATCH` \| `CATEGORY_SUM_MISMATCH` \| `COVERAGE_SUM_MISMATCH` \| `DUPLICATES_PRESENT` \| `CONFLICTS_PRESENT` \| `UNCLASSIFIED_PRESENT` \| `ACTIONABLE_PRESENT` | **yes** | MISSING and UNREADABLE are separate codes on purpose: 'cannot read it' and 'it is not there' have opposite fixes and this repo has collapsed them before |
| `reasons[].detail` | `string` \| `null` | — | the source name, or the two numbers that failed to match - so a fixture can assert WHICH instance fired |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: SnapshotVerdict -->

<!-- BEGIN GENERATED CONTRACT: ControlRoomSnapshotV5 -->
### ControlRoomSnapshotV5

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`ControlRoomSnapshotV5`** · stored in `portfolio/control_room_snapshot.json (EXISTING, v4 at HEAD)` · enforced by *snapshot_validator: reconciliation_clear is COMPUTED and MUST NOT be read from input*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `ControlRoomSnapshotV5` | **yes** |  |
| `meta` | [`SnapshotMeta`](#snapshotmeta) | **yes** |  |
| `verdict` | [`SnapshotVerdict`](#snapshotverdict) | **yes** |  |
| `system_health` | array of `object` | **yes** |  |
| `floating_risk` | array of `object` | **yes** |  |
| `deployments` | `object` | **yes** |  |
| `unknown_magics` | array of `any` | **yes** |  |
| `attestation` | array of `any` | **yes** |  |
| `judge_readiness` | array of `any` | **yes** |  |
| `judge_cohorts` | array of `object` | **yes** | MEASURED 2026-07-31 (ORDER-612 / S4): this was `type: object` and the real document has always carried an ARRAY of 17 per-judge-date cohort rollups (scripts/control_room_snapshot.ps1 `$cohorts`). The first build of a v5 document was refused by ajv naming `/judge_cohorts`, which is how it was found. It is the same defect class as rev 2's flat root: a contract that claims to describe a file and describes a shape the file never has. Nothing caught it earlier because no fixture ever validated the REAL document -- which is exactly what C1 of this order requires and why C1 is worded as a flip of that line rather than as a claim about it. |
| `summary` | `object` | **yes** |  |
| `runtime_identity` | array of [`RuntimeIdentityRecord`](#runtimeidentityrecord) | — |  |
| `runtime_identity_summary` | [`RuntimeIdentitySummary`](#runtimeidentitysummary) | — |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: ControlRoomSnapshotV5 -->

<!-- BEGIN GENERATED CONTRACT: RuntimeIdentityObserved -->
### RuntimeIdentityObserved

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`RuntimeIdentityObserved`** · stored in `runtime sidecars collected under portfolio/live_deals/` · enforced by *runtime_identity.py: validates the EA-emitted identity shape and build/artifact evidence*

| field | type | required | rule |
|---|---|---|---|
| `schema` | const `runtime_identity/1` | **yes** |  |
| `account_login` | `string` | **yes** | pattern `^[1-9][0-9]*$` |
| `magic` | `string` | **yes** | pattern `^[1-9][0-9]*$` |
| `ea_logical_identity` | `string` | **yes** | minLength `1` |
| `build_receipt` | `string` | **yes** | pattern `^br-[0-9a-f]{32}$` |
| `config_fingerprint` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `config_fingerprint_version` | const `cfgfp-v1` | **yes** |  |
| `symbol` | `string` | **yes** | minLength `1` |
| `timeframe` | `string` | **yes** | minLength `1` |
| `attach_epoch` | `string` | **yes** | pattern `^epoch-[1-9][0-9]*$` |
| `attach_time_unix` | `integer` | — | min `1` |
| `first_trade_epoch` | `string` \| `null` | **yes** |  |
| `evidence_timestamp` | `string` | **yes** | minLength `1` |
| `evidence_source` | const `EA_RUNTIME_COMMON_FILE` | **yes** |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: RuntimeIdentityObserved -->

<!-- BEGIN GENERATED CONTRACT: RuntimeIdentityRecord -->
### RuntimeIdentityRecord

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`RuntimeIdentityRecord`** · stored in `runtime_identity in portfolio/control_room_snapshot.json` · enforced by *runtime_identity.py: annotates collected identity records with fail-closed validation state*

| field | type | required | rule |
|---|---|---|---|
| `schema` | const `runtime_identity/1` | **yes** |  |
| `account_login` | `string` | **yes** | pattern `^[1-9][0-9]*$` |
| `magic` | `string` | **yes** | pattern `^[1-9][0-9]*$` |
| `ea_logical_identity` | `string` | **yes** | minLength `1` |
| `build_receipt` | `string` | **yes** | pattern `^br-[0-9a-f]{32}$` |
| `config_fingerprint` | `string` | **yes** | pattern `^[0-9a-f]{64}$` |
| `config_fingerprint_version` | const `cfgfp-v1` | **yes** |  |
| `symbol` | `string` | **yes** | minLength `1` |
| `timeframe` | `string` | **yes** | minLength `1` |
| `attach_epoch` | `string` | **yes** | pattern `^epoch-[1-9][0-9]*$` |
| `attach_time_unix` | `integer` | — | min `1` |
| `first_trade_epoch` | `string` \| `null` | **yes** |  |
| `evidence_timestamp` | `string` | **yes** | minLength `1` |
| `evidence_source` | const `EA_RUNTIME_COMMON_FILE` | **yes** |  |
| `validation_state` | `PASS` \| `FAIL` \| `LEGACY_UNVERIFIED` | **yes** |  |
| `validation_reasons` | array of object *(fields below)* | **yes** | items closed · items require `code`, `detail` |
| `validation_reasons[].code` | `string` | **yes** | minLength `1` |
| `validation_reasons[].detail` | `string` | **yes** |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: RuntimeIdentityRecord -->

<!-- BEGIN GENERATED CONTRACT: RuntimeIdentitySummary -->
### RuntimeIdentitySummary

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`RuntimeIdentitySummary`** · stored in `runtime_identity_summary in portfolio/control_room_snapshot.json` · enforced by *monitor_coverage.ps1: red-lines missing, legacy, mixed, or failed runtime identity evidence*

| field | type | required | rule |
|---|---|---|---|
| `state` | `PASS` \| `FAIL` \| `LEGACY_UNVERIFIED` | **yes** |  |
| `records` | `integer` | **yes** | min `0` |
| `forward_test_state` | `DEMO_DEPLOYED_AWAITING_FIRST_TRADE` \| `FORWARD_TEST_EVIDENCE_STARTED` \| `FORWARD_TEST_UNTRUSTED` \| `NO_VALID_RUNTIME_IDENTITY` | — |  |
| `first_trade_findings` | array of object *(fields below)* | — | items closed · items require `account_login`, `magic`, `state` |
| `first_trade_findings[].account_login` | `string` | **yes** | pattern `^[1-9][0-9]*$` |
| `first_trade_findings[].magic` | `string` | **yes** | pattern `^[1-9][0-9]*$` |
| `first_trade_findings[].state` | `string` | **yes** | minLength `1` |
| `first_trade_findings[].first_trade_epoch` | `string` \| `null` | — |  |
| `first_trade_findings[].qualifying_deal` | `object` \| `null` | — |  |
| `first_trade_findings[].reasons` | array of `any` | — |  |
| `reasons` | array of object *(fields below)* | **yes** | items closed · items require `code`, `detail` |
| `reasons[].code` | `string` | **yes** | minLength `1` |
| `reasons[].detail` | `string` | **yes** |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: RuntimeIdentitySummary -->

<!-- BEGIN GENERATED CONTRACT: SnapshotMeta -->
### SnapshotMeta

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`SnapshotMeta`** · stored in `the `meta` property of portfolio/control_room_snapshot.json`

| field | type | required | rule |
|---|---|---|---|
| `schema` | const `ControlRoomSnapshot` | **yes** |  |
| `version` | `integer` | **yes** | min `5` · v5+ for anything carrying the Factory domain; v4 already exists at HEAD |
| `build_id` | `string` | **yes** |  |
| `generated_at` | `string` | **yes** |  |
| `git_head` | `string` | — |  |
| `mandatory_sources` | array of `string` | **yes** | minItems `1` · the REGISTRY of what must be present, kept separate from what was discovered - otherwise a missing source is indistinguishable from one that was never expected. `uniqueItems` because a registry naming the same source twice makes its own cardinality unreadable; a DUPLICATE name in the `sources` array below is not expressible in JSON Schema and is snapshot_validator's DUPLICATE_SOURCE_NAME predicate instead. |
| `sources` | array of object *(fields below)* | **yes** | items closed · items require `name`, `mandatory`, `read_ok`, `fresh`, `age_hours` |
| `sources[].name` | `string` | **yes** |  |
| `sources[].mandatory` | `boolean` | **yes** |  |
| `sources[].read_ok` | `boolean` | **yes** | false must stay distinguishable from 'read fine, found nothing' in EVERY consumer |
| `sources[].fresh` | `boolean` | **yes** | DERIVED, and the validator does not trust the supplied value: it recomputes fresh from `age_hours` against `stale_bar_hours` and overwrites this on the way out. Present because the real v4 consumers read it. A caller-supplied `fresh: true` on an over-the-bar row therefore does NOT buy an reconciliation_clear - there is a fixture for exactly that. |
| `sources[].age_hours` | `number` \| `null` | **yes** |  |
| `sources[].path` | `string` \| `null` | — | COMPATIBILITY: the real v4 source rows are {path, sha256, mtime, age_hours} (scripts/control_room_snapshot.ps1 FileMeta) and carry no `name` at all. These three were absent from this closed row, so a builder holding the real metadata could not even be expressed at the boundary, let alone preserve it. Reconciling `path` with `name` as the identity is S4's job; carrying it through is this order's. |
| `sources[].sha256` | `string` \| `null` | — | COMPATIBILITY: as `path`. |
| `sources[].mtime` | `string` \| `null` | — | COMPATIBILITY: as `path`. |
| `stale_bar_hours` | `number` \| `null` | — | COMPATIBILITY: exists in the real v4 file (scripts/control_room_snapshot.ps1). The validator derives freshness from this, never from a hardcoded threshold and never from a caller-supplied `fresh`. |
| `decision_bar_trades` | `integer` \| `null` | — | COMPATIBILITY: exists in the real v4 file. Audit 3 found the schema silently dropped it. |
| `counting_method` | `string` \| `null` | — | COMPATIBILITY: exists in the real v4 file. Audit 3 found the schema silently dropped it. |
| `runtime_identity_required` | `boolean` | — | Current VPS DEMO/forward-test snapshots require runtime identity; legacy snapshots may omit this policy flag. |
| `reconciliation` | [`ReconciliationEvidence`](#reconciliationevidence) | **yes** |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: SnapshotMeta -->

<!-- BEGIN GENERATED CONTRACT: SafeProjection -->
### SafeProjection

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`SafeProjection`** · stored in `build/safe_projection.json (derived, never hand-written)` · enforced by *projection_validator: recursive forbidden-key scan + synthetic secret/account fixtures; the Telegram sender MUST NOT be able to read the full snapshot*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `SafeProjection` | **yes** |  |
| `build_id` | `string` | **yes** | pattern `^[0-9a-f]{16}$` · ORDER-1267 Part 2: constrained because it was an unconstrained string that the notifier interpolates verbatim into the text it sends. Shape DERIVED, not invented -- snapshot_build.compute_build_id returns sha256(...).hexdigest()[:16]. |
| `generated_at` | `string` | **yes** | pattern `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$` · ORDER-1267 Part 2, same reasoning and same route as build_id. Shape DERIVED -- control_room_snapshot.ps1 writes $now.ToString('s'): yyyy-MM-ddTHH:mm:ss, no fraction, no zone. |
| `accounts` | array of object *(fields below)* | **yes** | items closed · items require `account_masked`, `sensor_state`, `dd_pct_band` |
| `accounts[].account_masked` | `string` | **yes** | pattern `^\*{3}[0-9]{3}$` |
| `accounts[].sensor_state` | `FRESH` \| `STALE` \| `BLIND` \| `MISSING` \| `UNKNOWN` \| `CONFLICT` | **yes** | CONFLICT (ORDER-1267 #2, owner-ratified 2026-08-04) is what the two detectors DISAGREEING renders - control_center.sensors_disagree() owns the rule and safe_projection.build() calls it. It is not a state any detector emits, so it is absent from SENSOR_STATE_MAP's keys and present in its target vocabulary |
| `accounts[].dd_pct_band` | `OK` \| `WATCH` \| `BREACH` \| `UNKNOWN` | **yes** | a BAND, not a number - a percentage plus a known base equity reconstructs the money amount |
| `findings` | array of object *(fields below)* | **yes** | items closed · items require `public_id`, `severity`, `state` |
| `findings[].public_id` | `string` | **yes** | pattern `^FP-[0-9a-f]{10}$` |
| `findings[].severity` | `INFO` \| `WARN` \| `CRITICAL` \| `REAL_MONEY` | **yes** |  |
| `findings[].state` | `string` | **yes** |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: SafeProjection -->

<!-- BEGIN GENERATED CONTRACT: AlertEvent -->
### AlertEvent

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`AlertEvent`** · **DERIVED** — True · stored in `(in memory only) an AlertEvent is never persisted; ops/delivery_ledger.jsonl records that one existed` · enforced by *notifier.assert_sendable: the declared SHAPE checked against this file, PLUS safe_projection.scan_forbidden run with the real snapshot secret list - the layer the sender structurally cannot run*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `AlertEvent` | **yes** |  |
| `kind` | `ALERT` \| `RECOVERY` \| `MORNING_BRIEF` \| `DELIVERY_PROBE` | **yes** |  |
| `channel` | `EMERGENCY` \| `CONTROL_ROOM` | **yes** | design 7.3 names two bots on ONE event system. The channel is decided by the severity routing table the owner ratified on 2026-08-02, not by a chat id in a config file. |
| `public_id` | `string` | **yes** | pattern `^FP-[0-9a-f]{10}$` · The internal finding_id may embed an account, a magic or an EA name and MUST NOT travel. This is safe_projection.public_id() of it, so the id on Telegram and the id on the dashboard are pinned together as design 7.3 requires. |
| `severity` | `INFO` \| `WARN` \| `CRITICAL` \| `REAL_MONEY` | **yes** |  |
| `state` | `OPEN` \| `HEALTHY_1_OF_2` \| `RESOLVED` \| `FLAPPING` \| `SUPPRESSED_MAINTENANCE` | **yes** |  |
| `class` | `RUNTIME` \| `GOVERNANCE` \| `DEPLOYMENT_DRIFT` \| `AUDIT` | **yes** | Safe to send: a four-value closed enum with no identity in it. It is what makes a thin alert actionable at 3am without a detail line. |
| `material_revision` | `integer` | **yes** | min `0` · Part of the dedupe key. It cannot be computed from the SafeProjection - that surface carries public_id/severity/state and nothing else - so it is produced local-side by notifier.observe() from ops/finding_journal.jsonl. Naming that gap is the point. |
| `dedupe_key` | `string` | **yes** | pattern `^[A-Za-z0-9\|_.:-]+$` · public_id + state + severity + material_revision, per design 7.3. Rev 1 deduped on (id, state), which suppressed a WARN escalating to REAL_MONEY while the state stayed OPEN. |
| `build_id` | `string` | **yes** |  |
| `text` | `string` | **yes** | The rendered message. The ONLY free-form field, and therefore the one assert_sendable's literal scan exists for. |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: AlertEvent -->

<!-- BEGIN GENERATED CONTRACT: AlertDelivery -->
### AlertDelivery

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**`AlertDelivery`** · stored in `ops/delivery_ledger.jsonl` · enforced by *notifier.deliver: every event produces exactly one line whatever happened, and dedupe reads DELIVERED and nothing else*

| field | type | required | rule |
|---|---|---|---|
| `entity` | const `AlertDelivery` | **yes** |  |
| `dedupe_key` | `string` | **yes** |  |
| `channel` | `EMERGENCY` \| `CONTROL_ROOM` | **yes** |  |
| `kind` | `ALERT` \| `RECOVERY` \| `MORNING_BRIEF` \| `DELIVERY_PROBE` | **yes** |  |
| `outcome` | `DELIVERED` \| `SUPPRESSED_DUPLICATE` \| `UNCONFIGURED` \| `UNCONFIGURED_REGRESSION` \| `FAILED` | **yes** | UNCONFIGURED and FAILED are STATED failures that make the CLI exit non-zero. A sender that cannot send and reports nothing is indistinguishable from a quiet fleet. UNCONFIGURED_REGRESSION (ORDER-1261 #6) is the third: a channel that HAS delivered before and now has no credential. It is split from UNCONFIGURED because that one routes to exit 4, which ORDER-219 deliberately mutes in the daily chain - correct for 'the owner has not made the bot yet', wrong for 'the credential that was working is gone' |
| `receipt` | `string` \| `null` | **yes** | The provider's message id, which is what makes 'did this arrive' answerable. Null for every outcome that is not DELIVERED. |
| `at` | `string` | **yes** |  |
| `openclaw` | `RUNNING` \| `NOT_RUNNING` \| `UNKNOWN` | **yes** | design 10 requires alerts to work with OpenClaw stopped. Recording the OBSERVED gateway state beside the receipt turns that from a claim in a handoff into a measurement stored next to the evidence. UNKNOWN is a real third answer and is never collapsed onto NOT_RUNNING. |
| `detail` | `string` | **yes** |  |

**Unknown fields:** rejected (closed object).

<!-- END GENERATED CONTRACT: AlertDelivery -->

<!-- BEGIN GENERATED CONTRACT: META_parity_cases -->
### META_parity_cases

<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by `_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>

**Every case below is judged on ALL SEVEN points of section 5.5 - init result, [CFG] fingerprint, full order request/result trace including rejections, trade list, end-state positions/pendings, terminal side effects, errors - never on the trade list alone. All must pass before any cell's evidence counts.**

| case | what it compares | what it proves |
|---|---|---|
| 1 | wrapper vs parent, compiled defaults, XAUUSD H1 | baseline equivalence |
| 2 | wrapper vs parent, pilot .set, XAUUSD H4 | equivalence under the config the pilot actually runs |
| 2b | a config that provably opens trades | a run where both sides open nothing cannot be mistaken for agreement |
| 2c | _42_RiskPct paired with an SLMode yielding no distance, which MM-SAFETY-001 fails at OnInit | both sides refuse, for the same reason - parity can tell refused from silent |
| 3 | a locked parameter absent from the wrapper's Inputs page | absent from the page AND its value provably applied |
| 4 | a locked value changed in the registry, regenerated | behaviour changes, and parity vs the parent configured the same way still passes - lock is not ignore |
| 5 | delete the generated tree, regenerate from the registry | byte-identical .mq5 - NOT .ex5, MQL5 compilation is not reproducible, staleness is judged by mtime |

<!-- END GENERATED CONTRACT: META_parity_cases -->
