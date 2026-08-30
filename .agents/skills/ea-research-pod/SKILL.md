---
name: ea-research-pod
description: Spawn or resume a bounded EA_LAB family research workflow while preserving frozen experiment identity and canonical Git authority.
---

# EA Research Pod

Authority: `RESEARCH_ONLY`.

Use when a Control Tower needs to continue research on one EA family/variant without relying on prior chat history.

Before launch, resolve current pushed `origin/master`, read canonical research owners, and identify accepted evidence not to rediscover. Create the standard Pod contract documented in `docs/research/EA_RESEARCH_POD.md`.

Use deterministic tooling for MT5/backtest/parse/hash/aggregate/fixture work. Use a model only for semantic/mechanism/interpretation/review work that passes the project model-ROI gate.

After `PREREGISTER`, never edit the frozen hypothesis/mechanics in response to observed results. One variant is one logical change. A drifted contract is BLOCKED, not silently repaired.

Pod workspace state is transient. Migrate accepted findings to existing canonical owners, review/integrate/push them, then allow the Pod to sleep. Do not create a second Control Tower, strategy registry, experiment registry, deployment authority, HOLDOUT authority, risk authority, or trading authority.
