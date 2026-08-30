---
name: ea-capability-scout
description: Check EA_LAB for an existing capability, then search the pinned Awesome Trading Agents catalog only when a genuine research capability gap remains.
---

# EA Capability Scout

Authority: `RESEARCH_ONLY / DISCOVERY_ONLY`.

Use when a Research Pod or Control Tower has a concrete capability gap with a direct consumer.

First query the existing EA_LAB capability index. If status is `COVERED` or `BUILDING`, use the existing path and do not install an external project. If status is `BLOCKED_BY_DESIGN`, stop.

Only a genuine gap may search the pinned catalog through `tools/external_capability_scout/scout.py`. Evaluate shortlist entries for overlap, deterministic-vs-LLM behavior, source availability, maintenance, documentation, license, dependencies, security, network/data provenance, MCP permissions, services, reproducibility, Windows/MT5 relevance, and authority exposure.

The scout never installs candidates. Any `ADAPT_CANDIDATE` requires a separate bounded adoption contract with exact upstream SHA and direct license verification. Brokerage/exchange/order/wallet/private-key/execution capabilities remain parked unless a later owner-authorized contract explicitly opens them.
