"""Deterministic non-authoritative range generation for Factory vNext.

This sidecar only plans parameter ranges and active dimension sets. It never
changes current Factory policy, risk, deployment, or LIVE authority.
"""
from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence


class RangeGeneratorError(ValueError):
    pass


STAGES = ("COARSE", "REGION_SELECT", "REFINE", "SENSITIVITY")
ROLES = ("TUNABLE",)
SEMANTIC_TYPES = (
    "period_lookback",
    "threshold",
    "normalized_multiplier",
    "distance_spacing",
    "count_depth",
    "progression_factor",
    "enum_mechanism",
    "time_session",
    "mtf_relation",
    "boolean_policy",
    "ordered_pair",
    "percentage_ratio",
)


def _text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise RangeGeneratorError("%s is required" % name)
    return value.strip()


def _upper(value: Any, name: str) -> str:
    return _text(value, name).upper()


def _as_decimal(value: Any, name: str) -> Decimal:
    if isinstance(value, Decimal):
        return value
    if isinstance(value, bool):
        raise RangeGeneratorError("%s must be numeric" % name)
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError) as exc:
        raise RangeGeneratorError("%s must be numeric" % name) from exc


def _normalize_domain(domain: Mapping[str, Any]) -> Dict[str, Any]:
    kind = _upper(domain.get("kind"), "domain.kind")
    result: Dict[str, Any] = {"kind": kind}
    if kind == "ENUM":
        allowed = list(domain.get("allowed") or [])
        if not allowed:
            raise RangeGeneratorError("domain.allowed is required for enum semantics")
        result["allowed"] = [str(item) for item in allowed]
        return result
    if kind not in ("NUMERIC", "INTEGER"):
        raise RangeGeneratorError("unsupported domain.kind %r" % kind)
    for key in ("min", "max"):
        if key not in domain:
            raise RangeGeneratorError("domain.%s is required" % key)
    result["min"] = _as_decimal(domain["min"], "domain.min")
    result["max"] = _as_decimal(domain["max"], "domain.max")
    if result["min"] > result["max"]:
        raise RangeGeneratorError("domain.min must be <= domain.max")
    return result


def _normalize_spec(parameter_spec: Mapping[str, Any]) -> Dict[str, Any]:
    name = _text(parameter_spec.get("name"), "parameter_spec.name")
    role = _upper(parameter_spec.get("role"), "parameter_spec.role")
    surface = _upper(parameter_spec.get("surface"), "parameter_spec.surface")
    semantic_type = _text(parameter_spec.get("semantic_type"), "parameter_spec.semantic_type").lower()
    stage_hint = parameter_spec.get("stage_hint")
    stage = _upper(stage_hint, "parameter_spec.stage_hint") if stage_hint else None
    if role not in ROLES:
        return {
            "name": name,
            "role": role,
            "surface": surface,
            "semantic_type": semantic_type,
            "stage_hint": stage,
        }
    domain = parameter_spec.get("domain")
    if not isinstance(domain, Mapping):
        raise RangeGeneratorError("parameter_spec.domain is required")
    return {
        "name": name,
        "role": role,
        "surface": surface,
        "semantic_type": semantic_type,
        "stage_hint": stage,
        "domain": _normalize_domain(domain),
        "unit": parameter_spec.get("unit"),
        "safety_ceiling": parameter_spec.get("safety_ceiling"),
        "activation": parameter_spec.get("activation"),
        "coupling_group": parameter_spec.get("coupling_group"),
        "allowed_values": list(parameter_spec.get("allowed_values") or []),
        "historical_observed": bool(parameter_spec.get("historical_observed", False)),
        "historical_label": parameter_spec.get("historical_label"),
    }


def _candidate_values(stage: str, domain: Mapping[str, Any], semantic_type: str) -> List[Any]:
    if domain["kind"] == "ENUM":
        return list(dict.fromkeys(domain["allowed"]))
    lo = domain["min"]
    hi = domain["max"]
    if semantic_type == "period_lookback":
        if stage == "COARSE":
            raw = [lo, lo + 1, lo + 2, lo + 4, lo + 8, hi]
        elif stage == "REGION_SELECT":
            mid = (lo + hi) / 2
            raw = [lo, mid - 1, mid, mid + 1, hi]
        elif stage == "REFINE":
            span = (hi - lo) / 4
            mid = (lo + hi) / 2
            raw = [mid - span, mid - span / 2, mid, mid + span / 2, mid + span]
        else:
            mid = (lo + hi) / 2
            raw = [mid - Decimal("0.5"), mid, mid + Decimal("0.5")]
    else:
        if stage == "COARSE":
            raw = [lo, lo + (hi - lo) / 4, (lo + hi) / 2, lo + (hi - lo) * 3 / 4, hi]
        elif stage == "REGION_SELECT":
            raw = [lo, lo + (hi - lo) / 3, (lo + hi) / 2, lo + (hi - lo) * 2 / 3, hi]
        elif stage == "REFINE":
            raw = [lo + (hi - lo) / 3, lo + (hi - lo) * Decimal("0.4"), (lo + hi) / 2,
                   lo + (hi - lo) * Decimal("0.6"), lo + (hi - lo) * 2 / 3]
        else:
            mid = (lo + hi) / 2
            raw = [mid - (hi - lo) / 20, mid, mid + (hi - lo) / 20]
    return raw


def _coerce_candidates(domain: Mapping[str, Any], values: Iterable[Any]) -> List[Any]:
    if domain["kind"] == "ENUM":
        allowed = set(domain["allowed"])
        result = [v for v in values if v in allowed]
        return list(dict.fromkeys(result))
    result: List[Any] = []
    is_integer = domain["kind"] == "INTEGER"
    lo = domain["min"]
    hi = domain["max"]
    for value in values:
        dec = _as_decimal(value, "candidate")
        if dec < lo or dec > hi:
            continue
        if is_integer:
            rounded = int(dec.to_integral_value())
            if Decimal(rounded) != dec:
                continue
            candidate: Any = rounded
        else:
            candidate = float(dec)
        if candidate not in result:
            result.append(candidate)
    return result


def plan_parameter_range(parameter_spec: Mapping[str, Any], stage: str, *, safe_ceiling: Optional[Any] = None) -> Dict[str, Any]:
    spec = _normalize_spec(parameter_spec)
    stage_name = _upper(stage, "stage")
    if stage_name not in STAGES:
        raise RangeGeneratorError("stage must be one of %s" % (STAGES,))
    if spec["role"] != "TUNABLE":
        return {
            "status": "REFUSED:non-tunable refused",
            "candidates": [],
            "reason": "role %s is not auto-tunable" % spec["role"],
            "provenance": {
                "parameter": spec["name"],
                "role": spec["role"],
                "surface": spec.get("surface"),
                "semantic_type": spec["semantic_type"],
                "stage": stage_name,
            },
        }
    if spec.get("surface") != "RESEARCH":
        return {
            "status": "REFUSED:non-research refused",
            "candidates": [],
            "reason": "surface %s is not auto-tunable" % spec.get("surface"),
            "provenance": {
                "parameter": spec["name"],
                "role": spec["role"],
                "surface": spec.get("surface"),
                "semantic_type": spec["semantic_type"],
                "stage": stage_name,
            },
        }
    semantic_type = spec["semantic_type"]
    if semantic_type not in SEMANTIC_TYPES:
        return {
            "status": "SEMANTICS_REQUIRED:semantics required",
            "candidates": [],
            "reason": "unknown semantic_type %r" % semantic_type,
            "provenance": {
                "parameter": spec["name"],
                "role": spec["role"],
                "surface": spec.get("surface"),
                "semantic_type": semantic_type,
                "stage": stage_name,
            },
        }
    candidates = _coerce_candidates(spec["domain"], _candidate_values(stage_name, spec["domain"], semantic_type))
    ceiling = safe_ceiling if safe_ceiling is not None else spec.get("safety_ceiling")
    reason = "planned"
    status = stage_name
    if ceiling is not None and spec["domain"]["kind"] != "ENUM":
        ceiling_dec = _as_decimal(ceiling, "safe_ceiling")
        limited = [c for c in candidates if _as_decimal(c, "candidate") <= ceiling_dec]
        if limited != candidates and limited:
            candidates = limited
            status = "SAFETY_LIMITED"
            reason = "candidate plan clipped at safety ceiling"
        elif not limited:
            return {
                "status": "STOP_AUTO_EXPANSION",
                "candidates": [],
                "reason": "safety ceiling reached",
                "provenance": {"parameter": spec["name"], "role": spec["role"], "semantic_type": semantic_type, "stage": stage_name, "safety_ceiling": float(ceiling_dec)},
            }
    provenance = {
        "parameter": spec["name"],
        "role": spec["role"],
        "surface": spec.get("surface"),
        "semantic_type": semantic_type,
        "unit": spec.get("unit"),
        "stage": stage_name,
        "domain": spec["domain"],
        "historical_observed": bool(spec.get("historical_observed", False)),
        "historical_label": spec.get("historical_label") or ("PROVISIONAL" if spec.get("historical_observed") else None),
    }
    return {"status": status, "candidates": candidates, "reason": reason, "provenance": provenance}


def plan_dimension_set(dimensions: Sequence[Mapping[str, Any]], *, stage: str) -> Dict[str, Any]:
    stage_name = _upper(stage, "stage")
    if stage_name not in STAGES:
        raise RangeGeneratorError("stage must be one of %s" % (STAGES,))
    normalized = [_normalize_spec(dim) for dim in dimensions]
    active = [dim for dim in normalized if dim.get("role") == "TUNABLE" and dim.get("surface") == "RESEARCH"]
    if len(active) > 4:
        return {
            "status": "REFUSED",
            "active_dimensions": [],
            "reason": "active dimensions exceed limit of 4",
            "provenance": {"stage": stage_name, "requested": [dim["name"] for dim in active]},
        }
    coupling_groups = []
    seen = set()
    for dim in active:
        group = dim.get("coupling_group")
        if not group:
            continue
        if isinstance(group, (list, tuple, set)):
            group_value = tuple(str(item) for item in group)
        else:
            group_value = (str(group),)
        if group_value not in seen:
            seen.add(group_value)
            coupling_groups.append(list(group_value))
    return {
        "status": stage_name,
        "active_dimensions": [dim["name"] for dim in active],
        "coupling_groups": coupling_groups,
        "reason": "dimension plan accepted",
        "provenance": {"stage": stage_name, "requested": [dim["name"] for dim in normalized]},
    }


def plan_parameter_range_from_metadata(
    semantic_metadata: Mapping[str, Any], parameter: str, stage: str
) -> Dict[str, Any]:
    """Plan only when the semantic sidecar proves every required range fact."""
    from .semantic_metadata import range_readiness, validate_semantic_metadata

    validate_semantic_metadata(semantic_metadata)
    readiness = range_readiness(semantic_metadata, parameter)
    if readiness["status"] == "SEMANTICS_REQUIRED":
        return {
            "status": "SEMANTICS_REQUIRED:semantics required",
            "candidates": [],
            "reason": "semantic metadata is incomplete: %s" % ", ".join(readiness["missing"]),
            "provenance": {"parameter": parameter, "stage": _upper(stage, "stage")},
        }
    rows = [row for row in semantic_metadata["parameters"] if row["parameter"] == parameter]
    row = rows[0]
    if readiness["status"] == "NOT_ELIGIBLE":
        return plan_parameter_range(
            {"name": parameter, "role": "LOCKED", "surface": "RESEARCH", "semantic_type": row["semantic_type"]["value"]},
            stage,
        )
    return plan_parameter_range(
        {
            "name": parameter,
            "role": "TUNABLE",
            "surface": "RESEARCH",
            "semantic_type": row["semantic_type"]["value"],
            "domain": row["optimization_domain"]["value"],
            "unit": row["unit"]["value"],
        },
        stage,
    )
