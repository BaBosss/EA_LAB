"""Passive deterministic routing/decision helpers for EA_LAB Control Tower.

V1 is source-only. It does not launch models, mutate the Lane Registry,
activate runtime, or call TypeSafe/Jev over the network.
"""

__all__ = ["routing", "decision", "integrity", "jev_shadow"]
