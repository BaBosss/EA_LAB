# EA_LAB Capability Scout / Technology Radar

Status: `RESEARCH_ONLY / DISCOVERY TOOL`.

Catalog upstream: `LLMQuant/awesome-trading-agents` pinned at `a5bcbc6a192386e7c625976082715dabed9bfb26` (CC0-1.0). The pinned README was deterministically indexed into 118 GitHub-backed entries. No linked Agent, MCP, Skill, broker, or exchange project is installed by this capability.

## Purpose

When a Research Pod or Control Tower encounters a capability gap, check current EA_LAB capability first. If the capability is covered or already building, use that path. Only a genuine gap reaches the external catalog.

Flow:

`CAPABILITY GAP -> CHECK EA_LAB -> USE_EXISTING | SCOUT PINNED CATALOG -> SHORTLIST -> SECURITY/LICENSE/AUTHORITY REVIEW -> ADOPT|ADAPT|PARK`

`Installed`, `catalogued`, and `EA_LAB capability accepted` are separate milestones.

## Canonical boundary

`tools/external_capability_scout/ea_lab_capabilities.json` is a lightweight lookup/index whose rows point to existing canonical owners. It does not replace `PROJECT_STATE.md`, `AGENTS.md`, Factory, portfolio, deployment, or research contracts.

## Current capability mapping

- Backtest execution -> EA_LAB deterministic MT5 runner -> `COVERED`.
- Research orchestration -> EA Research Pod -> `BUILDING`.
- Regime attribution -> frozen P4 framework -> `PARTIAL` while the exact local-data prerequisite remains blocked.
- External research/market data -> bounded External Intelligence layer -> `PARTIAL`.
- Portfolio attribution -> `SCOUT` for future research-only capability review.
- Agent evaluation/benchmarking -> `SCOUT`.
- Broker/exchange/order execution -> `BLOCKED_BY_DESIGN` for this milestone.

## Candidate review fields

The scout returns source URL/category/section/description, match score, authority class, security reasons, and install state. A later adoption contract must separately verify the candidate repository's exact SHA, license, maintenance, dependency burden, network/service needs, data provenance, permissions, reproducibility, Windows compatibility, and EA/MT5 relevance.

The Awesome catalog's own license does not grant permission to copy a linked project's code. Every downstream candidate must have its own license verified before reuse.

## Fail-closed policy

Brokerage/exchange sections and descriptions exposing live trading, order placement, wallets/private keys, transaction broadcasting, or execution bridges are classified `EXECUTION_EXPOSED` and `PARK_BLOCKED_BY_DESIGN`. The scout never installs a shortlist candidate and has no credential or MCP activation path.

Potential future research-only candidates include agent-evaluation/benchmark references such as `ulab-uiuc/live-trade-bench` and `Open-Finance-Lab/AgenticTrading`, architecture references such as `TauricResearch/TradingAgents` or `AI4Finance-Foundation/FinRobot`, and separately reviewed research/data skills or sources. Catalog presence is not recommendation or approval.

## Dry-run acceptance

Deterministic fixtures demonstrate:

1. `MT5 backtest execution` resolves to `USE_EXISTING` and returns no external shortlist.
2. `broker execution MCP order placement` resolves to `BLOCKED_BY_DESIGN` and returns no shortlist.
3. an uncovered research gap produces a shortlist with every entry `NOT_INSTALLED`.
4. execution-exposed catalog entries are parked, not adopted.
5. catalog identity is pinned to upstream SHA and README SHA-256.

A future upstream refresh is a separate bounded intake: pin a new SHA, regenerate the snapshot, compare changes, review authority/security changes, then integrate normally.
