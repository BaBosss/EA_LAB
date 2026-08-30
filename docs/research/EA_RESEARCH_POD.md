# EA_LAB EA Research Pod

Status: `RESEARCH_ONLY / TOOLING CAPABILITY`.

Upstream architectural reference: `ltjed/freephdlabor` pinned at `b8a9ab1a54db8c0502dc3a61dcc3c1fd13c65d5a` (MIT). EA_LAB does not embed or run freephdlabor as its Control Tower; no substantial upstream code is copied by this integration.

## Purpose

The Research Pod is a spawn-on-demand research coordinator under the ONE EA_LAB Main Control Tower. It helps route a family/variant through the next legal research step while preserving existing canonical owners, deterministic tooling, review rules, and hard stops.

Governing rule:

`DYNAMIC WORKFLOW + FROZEN EXPERIMENT`

The Pod may choose the next research stage. Once the experiment reaches `PREREGISTER`, the exact contract hash is frozen. Later evidence cannot mutate the hypothesis or mechanics. `ONE VARIANT = ONE LOGICAL CHANGE` remains mandatory.

## Lifecycle

`DORMANT -> SPAWN -> LOAD_FAMILY_MEMORY -> IDENTIFY_EVIDENCE_GAP -> PREREGISTER -> EXECUTE -> ANALYZE -> REVIEW -> ACCEPT|BLOCK|PARK -> SYNC_DURABLE_MEMORY -> SLEEP`

Agents/workers are disposable. The Pod does not keep one permanent agent per EA.

## Memory and source-of-truth boundary

A Pod workspace is transient and should live outside the repository, for example under `D:\EA_LAB_CONTROL\research_pods\...`. `contract.json` and `pod_state.json` make that run interruptible/resumable, but they are not canonical project truth.

Durable family memory is reconstructed from pushed Git owners already used by EA_LAB: `PROJECT_STATE.md`, taskboards, family contracts/results, Factory registries, accepted evidence, and Second Brain knowledge. Accepted findings must be migrated into those owners, reviewed, integrated, and pushed before a future Pod treats them as canonical.

This avoids a second strategy registry, experiment registry, Control Tower, or project-state database.

## Routing roles

The logical Pod can route semantic work to Research Manager, Strategy Thesis/Mechanism, Experiment Designer, Evidence Analyst, Mechanism/Ablation, Optimization, Regime/Robustness, Independent Reviewer, and Report/Graph/Diagram workers.

These are roles, not mandatory persistent LLM processes. Mechanical work stays deterministic: MT5 runner, parser, hash checks, matrix aggregation, evidence packaging, and fixture validation.

`tools/ea_research_pod/pod.py` routes mechanical/backtest/parse/hash/aggregate/fixture work to `DETERMINISTIC_TOOL`; semantic/research/mechanism/interpretation/review work routes to `MODEL_WORKER`. Actual model dispatch still requires the project model-ROI gate and direct consumer.

## Standard launch contract

A launch contract records: exact canonical base SHA; family/variant/parent; strategy thesis and current research state; hypothesis/observation/expected benefit-cost/falsifier; frozen mechanics; exactly one changed mechanic; accepted evidence not to rediscover; allowed/forbidden paths; deterministic method; runtime/bottleneck/loop breaker; direct consumer; acceptance; reviewer requirement; authority ceiling; and task kind.

The deterministic validator requires `authority_ceiling = RESEARCH_ONLY` and rejects any enabled HOLDOUT, trading, real-money, deployment, runtime-attach, or risk-default-change flag.

At `PREREGISTER`, the workspace contract SHA-256 is frozen. Every later transition validates the current bytes against that frozen hash and fails with `FROZEN_EXPERIMENT_DRIFT` on mutation.

## Dry-run acceptance

The test fixture represents B16 after H03: a position-engine ablation hypothesis with one logical change. It demonstrates spawn, family-memory load, evidence-gap routing, preregistration, deterministic execution route, synthetic evidence intake, independent-review state, ACCEPT, durable-sync routing, SLEEP, and resume from disk.

Negative fixtures prove: a second logical change is refused; protected authority is refused; and editing the hypothesis after preregistration blocks execution.

No real HOLDOUT, trading, broker connection, runtime attachment, or new MT5 run is needed to validate this capability.
