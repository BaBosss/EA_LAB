#!/usr/bin/env python3
"""Focused deterministic tests for the external-intelligence foundation."""

from datetime import datetime, timezone
import ast
from pathlib import Path
import tempfile
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

from contracts import ExternalWorldObservation
from contracts import ContractError, ResearchKnowledgeCandidate
from research_graph_adapter import normalize_research_candidate
from store import ExternalIntelligenceStore, ImmutableStoreError
from world_context_adapter import UnsupportedCapabilityError, normalize_world_observation


UPSTREAM_WORLD_SHA = "4528a6ed69f97ab93f91111ae814871bc1bc6a1a"
UPSTREAM_GRAPH_SHA = "3447d58fcabc2ddf8cde21f01314db2c276adae9"
DOC_SHA = "a" * 64
UTC = "2026-08-15T00:00:00Z"


def _expect(exc_type, function) -> None:
    try:
        function()
    except exc_type:
        return
    raise AssertionError(f"expected {exc_type.__name__}")


def test_valid_world_observation() -> None:
    record = ExternalWorldObservation(
        schema_version="1.0",
        record_type="ExternalWorldObservation",
        source="world-intel-mcp",
        provider="fixture",
        tool="market_quotes",
        upstream_repo="world-intel-mcp",
        upstream_sha="4528a6ed69f97ab93f91111ae814871bc1bc6a1a",
        retrieved_at_utc=datetime.now(timezone.utc),
        data_timestamp_utc=None,
        freshness_seconds=None,
        stale=False,
        availability="AVAILABLE",
        provenance={"fixture": "deterministic"},
        payload_version="1",
        raw_sha256="0" * 64,
        normalized_sha256="1" * 64,
        payload={"quotes": [{"symbol": "EURUSD", "price": "1.1000"}]},
        diagnostics={},
    )
    record.validate()


def _world(**overrides):
    values = {
        "capability": "market_quotes",
        "payload": {"quotes": [{"symbol": "EURUSD", "price": "1.1000"}]},
        "source": "world-intel-mcp",
        "provider": "fixture",
        "tool": "market_quotes",
        "upstream_repo": "world-intel-mcp",
        "upstream_sha": UPSTREAM_WORLD_SHA,
        "retrieved_at_utc": UTC,
        "data_timestamp_utc": UTC,
        "provenance": {"fixture": "deterministic"},
        "now_utc": UTC,
    }
    values.update(overrides)
    return normalize_world_observation(**values)


def test_world_negative_and_freshness() -> None:
    _expect(ContractError, lambda: _world(upstream_sha=""))
    _expect(ContractError, lambda: _world(provenance={}))
    stale = _world(data_timestamp_utc="2026-08-13T00:00:00Z", max_age_seconds=3600)
    assert stale.stale and stale.availability == "STALE"
    empty = _world(payload={})
    assert empty.availability == "UNAVAILABLE"
    no_timestamp = _world(data_timestamp_utc=None)
    assert no_timestamp.availability == "PARTIAL"
    partial = _world(capability="yield_curve", payload={"tenors": {"2Y": 0.02}, "complete": False})
    assert partial.availability == "PARTIAL"
    _expect(UnsupportedCapabilityError, lambda: _world(capability="gdelt_event_intensity"))


def test_world_hashes_are_deterministic() -> None:
    left = _world(payload={"b": 2, "a": 1})
    right = _world(payload={"a": 1, "b": 2})
    assert left.raw_sha256 == right.raw_sha256
    assert left.normalized_sha256 == right.normalized_sha256


def _research(**overrides) -> ResearchKnowledgeCandidate:
    values = {
        "upstream_repo": "knowledge_graph",
        "upstream_sha": UPSTREAM_GRAPH_SHA,
        "document_sha256": DOC_SHA,
        "source_ref": "docs/sample.md",
        "chunk_ref": "docs/sample.md#chunk-001",
        "extraction_version": "candidate-v1",
        "model_identity": "fixture-model",
        "extracted_at_utc": UTC,
        "support_ref": "docs/sample.md#chunk-001",
        "concept": {"name": "volatility clustering"},
        "relationship": {"type": "supports", "target": "regime"},
        "evidence": {"quote_hash": "b" * 64},
    }
    values.update(overrides)
    return normalize_research_candidate(**values)


def test_research_negative_and_identity() -> None:
    candidate = _research()
    assert candidate.validation_state == "UNVALIDATED"
    assert candidate.canonical_fact_written is False
    _expect(ContractError, lambda: _research(canonical_fact_written=True))
    _expect(ContractError, lambda: _research(validation_state="VALIDATED"))
    _expect(ContractError, lambda: _research(document_sha256="missing"))
    _expect(ContractError, lambda: _research(source_ref=""))
    _expect(ContractError, lambda: _research(support_ref="", evidence={}))
    unsupported = _research(relationship={"type": "invented", "target": "x"})
    assert unsupported.validation_state == "UNVALIDATED"
    assert unsupported.relationship["support_status"] == "UNSUPPORTED_RELATIONSHIP_UNVALIDATED"
    left = _research(model_identity="model-a", evidence={"one": 1})
    right = _research(model_identity="model-b", evidence={"two": 2})
    assert left.candidate_id == right.candidate_id


def test_store_is_immutable_and_external_root_only() -> None:
    _expect(TypeError, lambda: ExternalIntelligenceStore(None))
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp) / "external-intelligence"
        store = ExternalIntelligenceStore(root)
        store.put("world-001", _world())
        _expect(ImmutableStoreError, lambda: store.put("world-001", _world(payload={"changed": True})))
        assert store.get("world-001")["record_type"] == "ExternalWorldObservation"
        repository_root = Path(temp) / "repo"
        (repository_root / ".git").mkdir(parents=True)
        _expect(ContractError, lambda: ExternalIntelligenceStore(repository_root))


def test_adapters_have_no_forbidden_runtime_imports() -> None:
    forbidden = {"router", "executor", "risk", "deployment"}
    package_root = Path(__file__).resolve().parent
    for path in (package_root / "world_context_adapter.py", package_root / "research_graph_adapter.py"):
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom):
                names = [node.module or ""]
            else:
                continue
            assert not any(name.split(".")[0].lower() in forbidden for name in names), path


if __name__ == "__main__":
    tests = [
        test_valid_world_observation,
        test_world_negative_and_freshness,
        test_world_hashes_are_deterministic,
        test_research_negative_and_identity,
        test_store_is_immutable_and_external_root_only,
        test_adapters_have_no_forbidden_runtime_imports,
    ]
    for test in tests:
        test()
        print(f"PASS: {test.__name__}")
