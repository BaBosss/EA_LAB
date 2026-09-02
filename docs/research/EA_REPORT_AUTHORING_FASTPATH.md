# EA_LAB Report Authoring Fast Path

Status: `REPORTING ROUTER / NO NEW AUTHORITY`
Authority: execution/reporting efficiency only. `EA_REPORT_LADDER.md` and `EA_REPORT_SCHEMA.md` remain canonical owners.

## Goal

Reduce repeated manual report work while keeping every claim traceable. The fast path is:

`raw evidence -> deterministic parser -> machine summary -> visuals -> report -> independent validation`

Use existing accepted parsers/generators before writing a new one. A model should consume reconciled evidence for interpretation, not repeatedly rediscover values from raw tester HTML.

## 1. Freeze the evidence boundary first

Before authoring, record:
- exact experiment/contract and parent/child identities;
- source/build/set/tester/window identities;
- eligible, empty and mechanical-fail cell counts;
- exact raw-evidence paths/hashes;
- HOLDOUT / Model-4 / MC states.

Do not write narrative while an adaptive search is still running. Finish the preregistered evidence surface first unless the contract itself specifies a mechanical stop.

## 2. Generate machine evidence once

Prefer one deterministic family/milestone parser that emits reusable JSON/CSV for:
- PF, net, exact DD field, trades/baskets/cycles;
- year/regime split where available;
- participation / active-time measures;
- exposure, depth, lot ladder and concentration for multi-position EAs;
- parent-child deltas;
- leverage/truncation/mechanical eligibility;
- native-data availability flags.

Reconcile headline metrics back to raw MT5 exports before narrative use.

## 3. Keep native evidence and proxies separate

A native MT5 balance/equity/DD series is native evidence only when exported by the accepted evidence path. If only closed-deal reconstruction is possible, label it explicitly as a closed-deal balance/equity proxy.

Never silently substitute:
- a proxy equity curve for native floating equity;
- MT5 display `PF=0.00` for mathematically undefined PF when gross loss is zero;
- missing mechanics or broker assumptions with guessed values.

Use `UNKNOWN`, `UNAVAILABLE`, or `NOT RUN` when the source does not support a field.

## 4. Author in three layers

Every milestone report should make these visibly distinct:

1. **Evidence** — measured/reconciled facts and identities.
2. **Interpretation** — what those facts suggest about mechanism, portability, robustness or economics.
3. **Decision** — the contract consumer: continue, refine, lock, PARK, BLOCK or advance to the next authorized conveyor step.

Negative experiments remain evidence. Mechanical/harness/environment failures remain separate from strategy interpretation.

## 5. Match graph effort to the Report Ladder

- R0: preregistration; no graph required.
- R1: aggregate discovery/participation/DD views.
- R2: selected-cell mechanism and parent-child views.
- R3: optimization surface, neighbours, boundary pressure, trade-off and participation.
- R4: MAIN/BWD, year/regime, concentration, sensitivity and available fidelity/MC evidence.
- R5+: full graph pack required by the canonical ladder.

Do not generate a full Candidate dossier for an experiment that has already PARKed at R1-R3.

## 6. Package once for review and reuse

A normal durable result package should contain, as applicable:
- raw or source-bound evidence receipts;
- machine JSON/CSV summaries;
- report Markdown;
- required visuals;
- deterministic analysis/packaging scripts;
- SHA-256 manifest covering decision-critical artifacts.

The independent reviewer should recompute high-impact claims from these artifacts rather than ask the author to rerun MT5.

### 6.1 Deterministic package-integrity helper

After the package contents are finalized, `tools/reporting/report_package_integrity.py` can bind the declared artifacts into a deterministic integrity manifest:

```text
python tools/reporting/report_package_integrity.py build --spec <package_spec.json> --out <report_package_manifest.json>
python tools/reporting/report_package_integrity.py validate --manifest <report_package_manifest.json>
```

The package spec declares `package_id`, `direct_consumer`, `authority`, optional metadata, and a non-empty artifact list with package-relative `path` plus `role` (and optional `note`). The helper records byte size and SHA-256 for every declared artifact, sorts paths deterministically, and refuses missing files, path escape, duplicates, self-reference, or later byte tampering.

This is an integrity seam, not a second report schema or a research judge. It does **not** decide Report Ladder completeness, validate narrative claims, interpret results, assign Grade/verdict, authorize optimization/HOLDOUT, or grant runtime/risk/deployment authority. The independent reviewer still validates decision-critical claims against the machine evidence and canonical experiment contract.

## 7. Model ROI rule

Use deterministic/local tools for extraction, joins, arithmetic, reconciliation, plotting and hashing. Use a model only when it produces a unique interpretation/review output with a direct downstream consumer.

If the same parsing/report boilerplate appears in two milestones, prefer a reusable deterministic family generator over another hand-authored copy.

## 8. Completion gate

A report is ready for milestone review when:
- requested ladder/schema fields are present or explicitly unavailable;
- headline metrics reconcile to exact evidence;
- identities and changed/frozen semantics are inspectable;
- visuals do not overstate proxy data;
- evidence, interpretation and decision are separated;
- authority/HOLDOUT/fidelity states are explicit;
- package integrity is hash-verifiable;
- the report answers the preregistered direct consumer and does not invent a new one.

This fast path changes no verdict, Grade, sample floor, optimization, HOLDOUT, deployment, runtime, risk or promotion authority.
