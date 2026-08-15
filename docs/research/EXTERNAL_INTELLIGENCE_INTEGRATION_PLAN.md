# External Intelligence Adapter Foundation

Status: bounded foundation only; no provider execution, router integration, canonical-fact promotion,
trading, or risk behavior is enabled by this document.

## Purpose and direct consumers

The foundation gives the future Active Control Tower a typed boundary for two external research inputs:

1. accepted world-intelligence observations (quotes, ECB FX, yield curves, commodities, crypto, and raw
   macro signals, with the accepted optional classes kept explicitly opt-in); and
2. research-graph candidates that remain hypotheses until an owner-approved validation path accepts them.

The direct consumer is a future external-intelligence review/update lane. Router, Executor, EA source,
deployment, trading, and risk code are outside this boundary and are not imported or called here.

Accepted upstream evidence is referenced by provenance only:

- world-intel-mcp: `4528a6ed69f97ab93f91111ae814871bc1bc6a1a`;
- knowledge_graph: `3447d58fcabc2ddf8cde21f01314db2c276adae9`.

No substantial upstream source is copied. The adapter is standard-library-only.

## Architecture and data flow

```text
provider/tool response
        |
        v
bounded adapter -- policy + freshness + provenance --> versioned external record
        |                                                   |
        |                                                   v
        +-- reject unsupported/authority-bearing input   explicit external store root
                                                            |
                                                            v
                                                future review/update consumer
```

The world adapter accepts only named capability classes. Explicitly rejected classes fail closed;
unknown classes do not pass as generic data. The research adapter emits candidate concepts and
relationships, not canonical facts.

## Schema and provenance boundary

`ExternalWorldObservation` requires a schema version, record type, source/provider/tool, upstream
repository reference and SHA, retrieval and optional data timestamps, local freshness, stale flag,
availability (`AVAILABLE`, `PARTIAL`, `STALE`, or `UNAVAILABLE`), non-empty provenance, payload version,
raw and normalized hashes, payload, and diagnostics.

The adapter computes raw and normalized hashes from stable sorted-key JSON. It does not trust an upstream
stale flag. A local timestamp policy determines freshness; missing timestamps are not silently treated as
fresh. Empty or failed responses are unavailable, and incomplete yield-curve responses are partial.

`ResearchKnowledgeCandidate` requires the upstream reference, document SHA-256, source and chunk
references, extraction version, model identity, extraction timestamp, concept/relationship payload,
support reference, and evidence. Every candidate is forced to `UNVALIDATED` with
`canonical_fact_written=false`. Authority-bearing fields and attempts to enter a validated state are
rejected. Unsupported relationship types may be retained for research, but are explicitly marked
`UNSUPPORTED_RELATIONSHIP_UNVALIDATED` and cannot acquire authority in this layer.

## Storage and update rules

`ExternalIntelligenceStore` requires an explicit caller-supplied root. The intended future root is
`D:\EA_LAB_WORKSPACE\data\external-intelligence`; tests use temporary directories. The store refuses a
repository root and writes one stable JSON object per ID using write-once creation. A second write to an
existing ID fails; there is no overwrite, merge, delete, or implicit repository-local fallback.

Provider refresh is a future caller operation: retrieve externally, normalize into a new immutable record
ID, and retain provenance and diagnostics. It must not overwrite an existing record or promote a research
candidate. Retention, compaction, and deletion require a separate owner-gated maintenance contract.

## Failure, stale, and partial behavior

- explicit upstream failure or an empty success-shaped response → `UNAVAILABLE`;
- incomplete yield curve → `PARTIAL`;
- locally measured age beyond the caller policy → `STALE`;
- missing or malformed provenance/timestamps/hashes → contract rejection;
- explicitly rejected or unknown capability → adapter rejection;
- unsupported research relationship → retained only as an unvalidated candidate;
- attempted canonical-fact write or validation authority → rejection.

Diagnostics preserve classification details, including when an upstream stale flag was deliberately
ignored. No failure path supplies a Router/Executor/trading fallback.

## Testing and dependencies

`_triage/external_intelligence/run_tests.py` is a deterministic standard-library cage. It covers valid
world and research records, missing provenance and hashes, explicit stale state, empty and partial
responses, rejected capabilities, stable hashes, candidate identity, authority refusal, immutable
storage, repository-root refusal, and forbidden runtime imports. It uses fixed timestamps and payloads;
it does not contact a live provider or execute a monitor.

No LangChain, Qdrant, FastEmbed, Ollama, Pyvis, Jupyter, Docker, or upstream MCP runtime dependency is
introduced. No real provider rerun is part of this foundation.

## Phased integration boundary

1. **Foundation (this change):** contracts, bounded adapters, deterministic hashes, and external-only
   immutable storage.
2. **Owner-gated review lane:** decide retention roots, provider scheduling, and human review of
   `UNVALIDATED` candidates.
3. **Controlled consumer integration:** only after a separate contract defines freshness budgets,
   failure handling, provenance display, and rollback/isolation tests may a non-trading Control Tower
   view consume these records.
4. **Any canonical promotion:** requires an explicit owner-approved validation contract. This foundation
   cannot do it.

## QI relationship and rollback/isolation

This is a research/tooling boundary and does not modify QI-1, QI-2+, Router, Executor, EA source,
deployment, trading, risk defaults, or canonical project state. Rollback is limited to removing or
reverting the local bounded commit and discarding only caller-owned external records under the explicit
external root; no legacy workspace or runtime state is touched. The implementation is isolated in its
own worktree and can be reviewed independently before any future consumer wiring.
