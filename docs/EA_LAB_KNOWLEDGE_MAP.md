# EA_LAB Knowledge Map

> **GENERATED / READ-ONLY NAVIGATION.** This page owns no fact. Canonical ownership remains in `docs/memory_control/FACT_OWNER_MAP.md`.
> Regenerate with `scripts/make_knowledge_map.ps1`; use `-Check` to detect drift.

## Current / Control Tower
- [PROJECT_STATE.md](../PROJECT_STATE.md) - current status, binding decisions, forward plan
- [AGENT_TASKBOARD.md](../AGENT_TASKBOARD.md) - active order text, acceptance, execution state
- [TASKBOARD_DIGEST.md](../TASKBOARD_DIGEST.md) - generated compact taskboard view

## Governance / Memory Control
- [AGENTS.md](../AGENTS.md) - roles, permissions, hard stops, execution protocol
- [VISION.md](../VISION.md) - owner big-picture and factory philosophy
- [docs/memory_control/README.md](../docs/memory_control/README.md) - Memory-Controlled OS status and file map
- [docs/memory_control/FACT_OWNER_MAP.md](../docs/memory_control/FACT_OWNER_MAP.md) - fact-to-canonical-owner map
- [docs/memory_control/B1_COHORT.md](../docs/memory_control/B1_COHORT.md) - context-friction observation protocol and MVP-2 gate evidence

## Factory / EA Selection
- [EA_SCORECARD_AND_REGISTRY.md](../EA_SCORECARD_AND_REGISTRY.md) - EA verdict authority
- [EA_MASTER_INDEX.csv](../EA_MASTER_INDEX.csv) - registry mirror / legacy index surface where still consumed
- [CLAUDE.md](../CLAUDE.md) - current Factory verdict gate and canonical operator rules
- [docs/PARAM_REGISTRY.csv](../docs/PARAM_REGISTRY.csv) - parameter semantics, activation and coupling metadata
- [docs/skills_mirror/skills/backtest-optimize-rigor/SKILL.md](../docs/skills_mirror/skills/backtest-optimize-rigor/SKILL.md) - optimization and robustness procedure
- [docs/research/FACTORY_VNEXT_DESIGN_DRAFT.md](../docs/research/FACTORY_VNEXT_DESIGN_DRAFT.md) - design-frozen non-canonical source for Factory vNext sidecar implementation
- [docs/research/FACTORY_VNEXT_MVP_PILOT_CONTRACT.md](../docs/research/FACTORY_VNEXT_MVP_PILOT_CONTRACT.md) - frozen non-authoritative sidecar implementation contract for the first Factory vNext pilot

## Template / Execution / Risk
- [ea_template](../ea_template) - EA template source and capabilities
- [scripts/new_template_entry.ps1](../scripts/new_template_entry.ps1) - new template entry scaffold
- [portfolio/DEPLOYMENTS.csv](../portfolio/DEPLOYMENTS.csv) - deployment truth

## Research / Intake
- [docs/research/RESEARCH_IDEA_INBOX.md](../docs/research/RESEARCH_IDEA_INBOX.md) - non-authoritative intake and triage queue for ideas, links, PDFs and observations
- [docs/research/EA_LAB_QUANT_INTELLIGENCE_ARCHITECTURE_PLAN.md](../docs/research/EA_LAB_QUANT_INTELLIGENCE_ARCHITECTURE_PLAN.md) - quant-intelligence research architecture where present

## History / Evidence
- [PROJECT_HISTORY.md](../PROJECT_HISTORY.md) - historical project narrative and decision provenance
- [docs/memory_control/experiment_events](../docs/memory_control/experiment_events) - append-only experiment event/evidence timeline
- [docs/memory_control/ARCHIVE_INDEX.md](../docs/memory_control/ARCHIVE_INDEX.md) - reviewed taskboard archive index

## Retrieval Rule
- Start with `PROJECT_STATE.md` for current status.
- Use this map only to navigate; follow the canonical owner before editing or deciding.
- For a bounded machine context, generate a transient packet with `scripts/make_context_packet.ps1`.
- If two active sources disagree, run `scripts/check_knowledge_integrity.ps1` and treat the disagreement as drift, not as permission to choose one silently.
