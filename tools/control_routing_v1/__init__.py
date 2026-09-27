"""Bounded routing/decision helpers for the EA_LAB Control Tower.

Deterministic routing remains authoritative. Jev live calls are explicit, bounded,
advisory-only requests and never mutate Registry state or activate persistent runtime.
"""

__all__ = ["routing", "decision", "integrity", "jev_shadow", "jev_live"]
