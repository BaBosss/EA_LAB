# QI-1 Foundation Design Freeze

Status: OWNER-APPROVED / FROZEN
Scope: durable documentation only
Canonical base: `72fa23061b62913bfeccd552ba0eb41dfc74ebb3`

This document records the frozen QI-1 decision. It is not an implementation
specification expansion and does not authorize QI-1 implementation.

## 1. Strategy identity

Strategy Identity is exactly:

```text
{ea_id, strategy_revision}
```

QI-1 reuses the existing R4 `ea_id`. `strategy_revision` is additive, and a
semantic strategy change increments `strategy_revision`.

PID is not strategy identity. EX5 hash is not strategy identity. Magic is not
strategy identity.

## 2. StrategyRecordV1

`StrategyRecordV1` is additive to the existing:

```text
factory/strategy_catalog.json
```

There must not be a second strategy registry. No frozen StrategyRecord field
set is introduced beyond the existing catalog plus additive
`strategy_revision`.

The minimum migration is exactly:

```text
strategy_revision: 1
```

for exactly:

```text
E011 E012 E013 E014 E015 E016 E017 E018
```

This is not a generic or mass migration.

## 3. ExperimentContractV1

`ExperimentContractV1` is immutable and preregistered.

Its exact required fields are:

```text
schema_version
entity
experiment_id
created_at_utc
strategy_ref
experiment_type
spec_ref
hypothesis_revision
implementation_ref
parameter_refs
supersedes_experiment_id
```

`implementation_ref` freezes exactly:

```text
ex5_hash
source_hash
effective_config_hash
set_hash
```

Executable EA experiments require:

```text
ex5_hash
effective_config_hash
```

No extra Contract V1 fields are frozen here.

## 4. ExperimentResultV1

`ExperimentResultV1` is immutable.

Its exact required fields are:

```text
schema_version
entity
result_id
experiment_id
recorded_at_utc
run_ids
evidence_ids
verdict
reason_code
reason_ref
supersedes_result_id
```

No extra Result V1 fields are frozen here.

## 5. Verdict vocabulary

The exact QI-1 verdict vocabulary is:

```text
ACCEPTED
REJECTED
INCONCLUSIVE
INVALID
```

No other verdict values are frozen. `SUPERSEDED` is not a verdict.

Supersession is represented through `supersedes_experiment_id`,
`supersedes_result_id`, and derived state.

## 6. Derived objects and lifecycle

### Experiment Registry

The Experiment Registry is derived only and is never independently edited.

### Lifecycle

QI-1 reuses the existing experiment-event v1 chain. It does not create a
second lifecycle source.

### Negative Experiment Memory

Negative Experiment Memory is derived from durable `ExperimentResultV1`
records with verdict:

```text
REJECTED
INCONCLUSIVE
INVALID
```

There is no independently writable negative-memory source.

## 7. Existing infrastructure reuse

QI-1 reuses unchanged:

- R4 EA identity / `ea_id`
- existing experiment-event v1
- evidence-v1
- evidence manifest
- `factory/hypotheses.jsonl`
- ParameterBinding PID
- run journals / ExecutionKey
- controlled proof / receipt architecture
- scorecard history
- optimization decision log

R4 EA/PID identity must not be rewritten. Existing event-v1 remains
unchanged. Existing evidence-v1 and evidence manifest remain unchanged.

## 8. Supersession and immutability

`ExperimentContractV1` is immutable. `ExperimentResultV1` is immutable.

Corrections and evolution use append-only supersession references. Historical
contract and result objects are not mutated in place.

`SUPERSEDED` is derived state, not a verdict.

## 9. Legacy and migration

There is no mass historical rewrite.

Legacy experiments may remain:

```text
legacy_uncontracted
```

unless a lossless backfill is possible. Historical evidence must be preserved.
No semantics are invented during migration.

## 10. QI-1 boundary

QI-1 does not authorize:

- QI-2+ implementation
- AI reasoning runtime
- macro
- portfolio automation
- execution changes
- trading behavior changes
- risk changes
- Router changes
- Executor changes
- Auth changes
- Backtest behavior changes
- Optimization behavior changes
- deployment changes

## 11. Frozen acceptance intent

The durable document preserves the already frozen QI-1 acceptance intent:

- no second identity system
- strict Contract/Result schemas
- immutable contracts/results
- contract/run EX5 + effective-config identity binding
- PID semantic-revision resolution
- evidence reference resolution
- derived lifecycle
- derived Experiment Registry
- derived Negative Experiment Memory
- append-only supersession
- legacy readability
- no Router/Executor/Auth/Backtest/Optimization/deployment/trading/risk changes

## 12. Explicit non-scope

This document records a frozen decision only. It does not create schemas,
implementation code, tests, registries, lifecycle sources, migration tooling,
or any other QI-1 or QI-2+ implementation.
