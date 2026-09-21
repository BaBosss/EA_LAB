from __future__ import annotations

from typing import Any

from .core import Refused, checksum


def build_monitor_handoff(*, source_head: str, canonical_sha: str,
                          readiness: dict[str, Any],
                          preflight: dict[str, Any],
                          result_summaries: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    """Build non-live payload for the existing Monitor owner.

    The payload cannot assert current guard effectiveness or a global regime.
    """
    if not isinstance(source_head, str) or len(source_head) != 40:
        raise Refused("EXACT_SOURCE_HEAD_REQUIRED")
    if not isinstance(canonical_sha, str) or len(canonical_sha) != 40:
        raise Refused("EXACT_CANONICAL_SHA_REQUIRED")
    if readiness.get("can_execute") is not False:
        raise Refused("READINESS_CANNOT_GRANT_EXECUTION")
    if readiness.get("world_regime") != "UNKNOWN" or readiness.get("probability") is not None:
        raise Refused("READINESS_MUST_REMAIN_UNKNOWN")
    if preflight.get("can_execute") is not False:
        raise Refused("PREFLIGHT_CANNOT_GRANT_EXECUTION")
    if preflight.get("historical_dataset_qualified") is not False:
        raise Refused("PREFLIGHT_CANNOT_QUALIFY_DATASET")

    summaries = result_summaries or []
    if not isinstance(summaries, list):
        raise Refused("RESULT_SUMMARY_LIST_REQUIRED")
    clean = []
    for row in summaries:
        if not isinstance(row, dict):
            raise Refused("RESULT_SUMMARY_OBJECT_REQUIRED")
        if row.get("schema_version") != "guard_ab_descriptive_comparison/1":
            raise Refused("UNQUALIFIED_RESULT_SUMMARY")
        if row.get("verdict") is not None or row.get("can_promote") is not False:
            raise Refused("RESULT_SUMMARY_AUTHORITY_LEAK")
        clean.append({
            "changed_dimension": row.get("changed_dimension"),
            "frozen_identity_sha256": row.get("frozen_identity_sha256"),
            "mechanism_status": row.get("mechanism_status"),
            "holdout_used": row.get("holdout_used"),
            "verdict": None,
        })

    return {
        "schema_version": "news_macro_monitor_handoff/1",
        "authority": "READ_ONLY_HANDOFF_NOT_LIVE",
        "source_head": source_head,
        "canonical_sha_at_handoff": canonical_sha,
        "installed": False,
        "live_publish_allowed": False,
        "runtime_effectiveness": {
            "NewsGuard": "UNKNOWN",
            "MacroGate": "UNKNOWN",
        },
        "global_regime": "UNKNOWN",
        "global_regime_probability": None,
        "source_readiness": {
            "world_regime": readiness["world_regime"],
            "cells": len(readiness.get("cells", [])),
            "historical_dataset_qualified": False,
        },
        "experiment_preflight": {
            "status": preflight.get("status"),
            "missing_gates": list(preflight.get("missing_gates", [])),
            "performance": preflight.get("performance", "NOT_RUN"),
            "native_runs": preflight.get("native_runs", 0),
        },
        "result_summaries": clean,
        "synthetic_or_preparation_must_not_render_as_live": True,
    }
