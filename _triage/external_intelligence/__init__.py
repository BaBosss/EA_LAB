"""Bounded external-intelligence adapter foundation."""

from .contracts import ContractError, ExternalWorldObservation, ResearchKnowledgeCandidate
from .research_graph_adapter import normalize_research_candidate
from .store import ExternalIntelligenceStore, ImmutableStoreError
from .world_context_adapter import normalize_world_observation

__all__ = [
    "ContractError",
    "ExternalWorldObservation",
    "ResearchKnowledgeCandidate",
    "normalize_research_candidate",
    "normalize_world_observation",
    "ExternalIntelligenceStore",
    "ImmutableStoreError",
]
