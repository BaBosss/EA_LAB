"""Small READ-plane contracts. These projections confer no source authority."""
from .observations import (
    Freshness, SourceObservation, ResearchArtifactRef, GuardObservation,
    ProjectionError, observe, parse_json, safe_path, safe_text, digest, utc,
)
