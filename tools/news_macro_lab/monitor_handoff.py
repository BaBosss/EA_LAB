from __future__ import annotations

import re
from typing import Any

from .core import Refused, checksum, count, stable_hash
from .planning import experiment_preflight
from .results import validate_frozen_identity

_GIT_SHA1_RE = re.compile(r"[0-9a-f]{40}")
_RESULT_SCHEMA = {
    "schema_version", "changed_dimension", "frozen_identity",
    "frozen_identity_sha256", "evaluation_unit", "mechanism_status",
    "arms", "real_delta_vs_base", "real_pf_delta_vs_base",
    "placebo_deltas", "all_placebo_seeds_reported", "selection_performed",
    "verdict", "can_promote", "holdout_used",
}
_CHANGED_DIMENSIONS = {"NEWS_FIXED_WINDOW", "MACRO_FROZEN_RULES"}
_EVALUATION_UNITS = {"TRADE", "BASKET_EPISODE"}
_MECHANISM_STATUSES = {
    "UNTESTED_NO_GUARD_FIRINGS",
    "OBSERVED_GUARD_FIRINGS",
}
_PREFLIGHT_STATUSES = {
    "BLOCKED_CONTRACT_INCOMPLETE",
    "DECLARED_FIELDS_COMPLETE_REVIEW_REQUIRED",
}
_CONTROLLER_CONTRACT_SCHEMA = {
    "schema_version",
    "expected_source_head",
    "expected_canonical_sha",
    "experiment_contract_sha256",
}


def _git_sha1(value: Any, reason: str) -> str:
    if not isinstance(value, str) or _GIT_SHA1_RE.fullmatch(value) is None:
        raise Refused(reason)
    if any(value == value[:width] * (40 // width) for width in (1, 2, 4, 5, 8, 10)):
        raise Refused(reason)
    return value


def _validate_preflight(preflight: Any) -> str:
    if not isinstance(preflight, dict) or preflight.get("schema_version") != "guard_experiment_preflight/2":
        raise Refused("PREFLIGHT_SCHEMA_REQUIRED")
    proposal_sha = checksum(preflight.get("proposal_sha256"))
    if preflight.get("status") not in _PREFLIGHT_STATUSES:
        raise Refused("PREFLIGHT_STATUS_UNSUPPORTED")
    if preflight.get("can_execute") is not False:
        raise Refused("PREFLIGHT_CANNOT_GRANT_EXECUTION")
    if preflight.get("historical_dataset_qualified") is not False:
        raise Refused("PREFLIGHT_CANNOT_QUALIFY_DATASET")
    if preflight.get("holdout_used") is not False:
        raise Refused("HOLDOUT_AUTHORITY_REFUSED")
    if preflight.get("performance") != "NOT_RUN":
        raise Refused("PREFLIGHT_PERFORMANCE_UNSUPPORTED")
    if preflight.get("changed_dimension") not in _CHANGED_DIMENSIONS:
        raise Refused("PREFLIGHT_CHANGED_DIMENSION_UNSUPPORTED")
    if preflight.get("evaluation_unit") not in _EVALUATION_UNITS | {None}:
        raise Refused("PREFLIGHT_EVALUATION_UNIT_UNSUPPORTED")
    count(preflight.get("native_runs"))
    return proposal_sha


def build_monitor_handoff(*, source_head: str, canonical_sha: str,
                          expected_source_head: str,
                          expected_canonical_sha: str,
                          readiness: dict[str, Any],
                          preflight: dict[str, Any],
                          experiment_contract: dict[str, Any] | None = None,
                          result_summaries: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    """Build non-live payload for the existing Monitor owner.

    The payload cannot assert current guard effectiveness or a global regime.
    """
    source_head = _git_sha1(source_head, "EXACT_SOURCE_HEAD_REQUIRED")
    canonical_sha = _git_sha1(canonical_sha, "EXACT_CANONICAL_SHA_REQUIRED")
    expected_source_head = _git_sha1(
        expected_source_head, "EXPECTED_SOURCE_HEAD_REQUIRED"
    )
    expected_canonical_sha = _git_sha1(
        expected_canonical_sha, "EXPECTED_CANONICAL_SHA_REQUIRED"
    )
    if source_head != expected_source_head:
        raise Refused("SOURCE_HEAD_BINDING_MISMATCH")
    if canonical_sha != expected_canonical_sha:
        raise Refused("CANONICAL_SHA_BINDING_MISMATCH")
    if readiness.get("can_execute") is not False:
        raise Refused("READINESS_CANNOT_GRANT_EXECUTION")
    if readiness.get("world_regime") != "UNKNOWN" or readiness.get("probability") is not None:
        raise Refused("READINESS_MUST_REMAIN_UNKNOWN")
    proposal_sha = _validate_preflight(preflight)

    summaries = [] if result_summaries is None else result_summaries
    if not isinstance(summaries, list):
        raise Refused("RESULT_SUMMARY_LIST_REQUIRED")
    if not isinstance(experiment_contract, dict):
        raise Refused("EXACT_EXPERIMENT_CONTRACT_REQUIRED")
    derived_preflight = experiment_preflight(experiment_contract)
    if derived_preflight != preflight:
        raise Refused("PREFLIGHT_CONTRACT_MISMATCH")
    if preflight.get("frozen_identity") is None:
        raise Refused("EXACT_EXPERIMENT_IDENTITY_REQUIRED")
    expected = validate_frozen_identity(preflight.get("frozen_identity"))
    clean = []
    for row in summaries:
        if not isinstance(row, dict):
            raise Refused("RESULT_SUMMARY_OBJECT_REQUIRED")
        if set(row) != _RESULT_SCHEMA or row.get("schema_version") != "guard_ab_descriptive_comparison/2":
            raise Refused("UNQUALIFIED_RESULT_SUMMARY")
        if row.get("verdict") is not None or row.get("can_promote") is not False:
            raise Refused("RESULT_SUMMARY_AUTHORITY_LEAK")
        if row.get("holdout_used") is not False:
            raise Refused("HOLDOUT_AUTHORITY_REFUSED")
        if (row.get("changed_dimension") not in _CHANGED_DIMENSIONS or
                row.get("evaluation_unit") not in _EVALUATION_UNITS):
            raise Refused("RESULT_ENUM_UNSUPPORTED")
        if row.get("mechanism_status") not in _MECHANISM_STATUSES:
            raise Refused("MECHANISM_STATUS_UNSUPPORTED")
        if (row.get("changed_dimension") != preflight.get("changed_dimension") or
                row.get("evaluation_unit") != preflight.get("evaluation_unit")):
            raise Refused("RESULT_CONTRACT_SEMANTICS_MISMATCH")
        if (row.get("all_placebo_seeds_reported") is not True or
                row.get("selection_performed") is not False):
            raise Refused("RESULT_SUMMARY_ACCOUNTING_MISMATCH")
        identity = validate_frozen_identity(row.get("frozen_identity"))
        identity_sha = checksum(row.get("frozen_identity_sha256"))
        if stable_hash(identity) != identity_sha:
            raise Refused("RESULT_IDENTITY_MISMATCH")
        if identity != expected:
            raise Refused("RESULT_IDENTITY_MISMATCH")
        clean.append({
            "changed_dimension": row.get("changed_dimension"),
            "evaluation_unit": row.get("evaluation_unit"),
            "frozen_identity": identity,
            "frozen_identity_sha256": identity_sha,
            "mechanism_status": row.get("mechanism_status"),
            "holdout_used": False,
            "verdict": None,
        })

    return {
        "schema_version": "news_macro_monitor_handoff/2",
        "authority": "READ_ONLY_HANDOFF_NOT_LIVE",
        "source_head": source_head,
        "canonical_sha_at_handoff": canonical_sha,
        "expected_experimental_identity_sha256": (
            stable_hash(expected)
        ),
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
            "proposal_sha256": proposal_sha,
            "status": preflight.get("status"),
            "missing_gates": list(preflight.get("missing_gates", [])),
            "performance": preflight.get("performance", "NOT_RUN"),
            "native_runs": preflight.get("native_runs", 0),
        },
        "result_summaries": clean,
        "synthetic_or_preparation_must_not_render_as_live": True,
    }


def build_production_monitor_handoff(*, source_head: str, canonical_sha: str,
                                     controller_contract: dict[str, Any],
                                     accepted_controller_contract_sha256: str,
                                     readiness: dict[str, Any],
                                     experiment_contract: dict[str, Any] | None,
                                     result_summaries: list[dict[str, Any]] | None = None,
                                     ) -> dict[str, Any]:
    """Production-owned, non-live handoff entry point.

    The accepted controller contract pins both Git identities and the exact
    experiment contract. Preflight is derived here and cannot be substituted by
    a second input artifact. All output is produced by the hardened builder.
    """
    if not isinstance(experiment_contract, dict):
        raise Refused("EXACT_EXPERIMENT_CONTRACT_REQUIRED")
    if (not isinstance(controller_contract, dict) or
            set(controller_contract) != _CONTROLLER_CONTRACT_SCHEMA or
            controller_contract.get("schema_version") != "news_macro_handoff_controller/1"):
        raise Refused("EXACT_HANDOFF_CONTROLLER_CONTRACT_REQUIRED")
    accepted_controller_sha = checksum(accepted_controller_contract_sha256)
    if stable_hash(controller_contract) != accepted_controller_sha:
        raise Refused("CONTROLLER_CONTRACT_BINDING_MISMATCH")
    expected_contract_sha = checksum(
        controller_contract.get("experiment_contract_sha256")
    )
    if stable_hash(experiment_contract) != expected_contract_sha:
        raise Refused("EXPERIMENT_CONTRACT_BINDING_MISMATCH")
    preflight = experiment_preflight(experiment_contract)
    return build_monitor_handoff(
        source_head=source_head,
        canonical_sha=canonical_sha,
        expected_source_head=controller_contract.get("expected_source_head"),
        expected_canonical_sha=controller_contract.get("expected_canonical_sha"),
        readiness=readiness,
        preflight=preflight,
        experiment_contract=experiment_contract,
        result_summaries=result_summaries,
    )
