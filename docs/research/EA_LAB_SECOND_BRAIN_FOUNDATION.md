# EA_LAB Second Brain Foundation

Status: IMPLEMENTED FOUNDATION / NON-AUTHORITATIVE RESEARCH LAYER
Base: `d5cf847ab091f4a9bc04413327ddfe36af26d137`
Scope: research knowledge organization + project-local research skills + seed migration

## Purpose

The Second Brain converts research material into traceable knowledge that can support strategy hypotheses without bypassing the existing Factory, QI, evidence, authorization, or deployment systems.

Target flow:

```text
Source -> Source Registry -> Research Card -> Evidence Critique
      -> Mechanism / Component / Regime links -> Synthesis
      -> TESTABLE_HYPOTHESIS -> separate controlled experiment path
```

## Reuse instead of duplication

This foundation deliberately reuses existing EA_LAB owners:

- strategy identity/catalog remains `factory/strategy_catalog.json` under QI-1;
- experiment contracts/results/registry and negative experiment memory remain governed by the frozen QI-1 model;
- event/evidence infrastructure remains under `docs/memory_control/experiment_events/` and existing evidence owners;
- current status/authority remain `PROJECT_STATE.md` / `AGENTS.md` / taskboard / scorecard / deployment truth;
- Factory remains the controlled proof path.

`knowledge/08_experiments/` and `knowledge/09_strategy_blueprints/` are pointer/synthesis surfaces only and are fail-closed against shadow registry/data files.
## Knowledge domains

The initial structure separates source provenance, research cards, strategy mechanisms, components, regimes, validation methodology, risk/execution realism, synthesis, and research-level negative knowledge. Asset/timeframe transfer assumptions belong in research cards and synthesis rather than being silently generalized.

## Tooling installed project-locally

Pinned upstream skills:

- `marciob/skill-research-papers` @ `97131ba7007f62374cc689cf7a85fa8fead8bb2b`;
- `xingtaxueshu/literature-review-skills` @ `84de3ba1f3853334d565fbbe6ac4f321cba6bd6b`, selected skills only: method comparison, contradiction mapping, research-gap discovery.

EA_LAB-specific skills add research intake, evidence critique, knowledge query, strategy synthesis, and negative-memory lookup. Both `.agents/skills/` and `.claude/skills/` receive project-local copies. No global hooks or runtime configuration are required by this foundation.

## Seed migration

The first registered knowledge reuses already-extracted canonical research instead of rereading the same corpus:

- `_triage/SSRN_151strategies_PBX_ebook_2026-07-13.md`;
- `_triage/SSRN_151_catalog_mechanisms.md`;
- `_triage/FINDYOUR8_STRATEGY_PDF_CATALOG.md`.

Each tracked source is SHA-256 bound in `knowledge/01_sources/source_registry.jsonl`. The seed research cards explicitly state `DERIVED_CATALOG` evidence depth and do not claim full-text re-verification.

## Safety / scope boundary

This milestone does **not** implement QI-2 Evidence Intelligence, autonomous research ingestion, automatic strategy generation, automatic Factory launch, macro-driven trading, portfolio automation, risk/default changes, deployment, or DEMO/LIVE promotion. Those remain outside this foundation and existing owner hard stops continue to apply.

## Deterministic acceptance

- `scripts/check_second_brain.ps1` validates required structure, source IDs/hashes, research-card provenance, project-local skills, and no-shadow-registry constraints.
- `scripts/_test/second_brain_tests.ps1` includes positive and negative tests for source-hash tampering and attempted shadow experiment registry creation.
- Existing Knowledge OS integrity remains the parent navigation/integrity layer.

## Google Drive corpus status

The supplied Drive corpus is fully classified and provenance-bound: 26 direct PDF objects comprise 21 promoted trading/research sources, 3 rejected unrelated sources, and 2 byte-identical `151 Trading Strategies` objects retained as duplicate evidence. `PENDING_CLASSIFICATION = 0`. Source and receipt records preserve SHA-256 evidence for the completed intake. No Drive object was moved or deleted, and duplicate confirmation does not authorize deletion.

## Next research step

Use the completed corpus through `ea-knowledge-query`, `ea-strategy-synthesizer`, `ea-evidence-critic`, and `ea-negative-memory` to produce source-traceable `TESTABLE_HYPOTHESIS` candidates with contradictions, transfer gaps, execution assumptions, and falsification needs explicit. Ingest new literature only when a concrete research consumer exists. Existing Factory, experiment, evidence, runtime, deployment, and risk owners remain authoritative.