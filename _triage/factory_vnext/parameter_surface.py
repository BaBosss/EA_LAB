# -*- coding: utf-8 -*-
"""Non-authoritative Variant Parameter Surface sidecar for Factory vNext.

This module joins hypothesis-specific binding rows to human display metadata rows,
then emits a deterministic machine surface snapshot. It never edits canonical
registry metadata and it never promotes binding semantics to global facts.
"""
from __future__ import annotations

from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence

from . import NON_AUTHORITATIVE
from .contracts import canonical_json, stable_id


class ParameterSurfaceError(ValueError):
    pass


SURFACE_AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"


def _text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ParameterSurfaceError("%s is required" % name)
    return value.strip()


def _rows(records: Iterable[Mapping[str, Any]], name: str) -> List[Dict[str, Any]]:
    if records is None:
        raise ParameterSurfaceError("%s is required" % name)
    return [dict(record) for record in records]


def _row_key(row: Mapping[str, Any], name: str) -> int:
    value = row.get(name)
    if isinstance(value, bool) or not isinstance(value, int):
        raise ParameterSurfaceError("%s must be an integer" % name)
    return value


def _join_identity(binding_rows: Sequence[Mapping[str, Any]], display_rows: Sequence[Mapping[str, Any]]) -> List[Dict[str, Any]]:
    bindings_by_pid: Dict[int, Dict[str, Any]] = {}
    for row in binding_rows:
        pid = _row_key(row, "parameter_pid")
        if pid in bindings_by_pid:
            raise ParameterSurfaceError("duplicate binding parameter_pid %s" % pid)
        bindings_by_pid[pid] = dict(row)

    displays_by_pid: Dict[int, Dict[str, Any]] = {}
    for row in display_rows:
        pid = _row_key(row, "parameter_pid")
        if pid in displays_by_pid:
            raise ParameterSurfaceError("duplicate display parameter_pid %s" % pid)
        displays_by_pid[pid] = dict(row)

    missing_display = sorted(set(bindings_by_pid) - set(displays_by_pid))
    if missing_display:
        raise ParameterSurfaceError("missing display metadata for parameter_pid %s" % missing_display[0])
    missing_binding = sorted(set(displays_by_pid) - set(bindings_by_pid))
    if missing_binding:
        raise ParameterSurfaceError("missing binding row for parameter_pid %s" % missing_binding[0])

    joined: List[Dict[str, Any]] = []
    for pid in sorted(bindings_by_pid):
        binding = bindings_by_pid[pid]
        display = displays_by_pid[pid]
        binding_name = _text(binding.get("parameter"), "parameter")
        display_name = _text(display.get("parameter"), "parameter")
        if binding_name != display_name:
            raise ParameterSurfaceError(
                "parameter name mismatch for parameter_pid %s: %s != %s" % (pid, binding_name, display_name)
            )
        joined.append({"binding": binding, "display": display})
    return joined


def make_variant_parameter_surface(
    variant: Mapping[str, Any],
    binding_rows: Iterable[Mapping[str, Any]],
    display_rows: Iterable[Mapping[str, Any]],
    hypothesis_revision: str,
    build_tag: str,
) -> Dict[str, Any]:
    variant_id = _text(variant.get("VariantID"), "VariantID")
    variant_snapshot_id = _text(variant.get("VariantSnapshotID"), "VariantSnapshotID")
    hypothesis = _text(hypothesis_revision, "hypothesis_revision")
    build = _text(build_tag, "build_tag")
    joined = _join_identity(_rows(binding_rows, "binding_rows"), _rows(display_rows, "display_rows"))

    filtered: List[Dict[str, Any]] = []
    for item in joined:
        binding = item["binding"]
        if _text(binding.get("hypothesis_revision"), "hypothesis_revision") != hypothesis:
            continue
        if _text(binding.get("build_tag"), "build_tag") != build:
            continue
        display = item["display"]
        filtered.append(
            {
                "parameter_pid": _row_key(binding, "parameter_pid"),
                "parameter": _text(binding.get("parameter"), "parameter"),
                "role": _text(binding.get("role"), "role"),
                "surface": _text(binding.get("surface"), "surface"),
                "optimize_stage": _text(binding.get("optimize_stage"), "optimize_stage"),
                "safe_range": binding.get("safe_range"),
                "locked_value": binding.get("locked_value"),
                "display_label": _text(display.get("display_label"), "display_label"),
                "portability": _text(display.get("portability"), "portability"),
                "unit_true": _text(display.get("unit_true"), "unit_true"),
                "relation_hint": _text(display.get("relation_hint", ""), "relation_hint"),
                "relations": [dict(rel) for rel in (display.get("relations") or [])],
            }
        )

    if not filtered:
        raise ParameterSurfaceError(
            "no binding rows matched hypothesis_revision=%s build_tag=%s" % (hypothesis, build)
        )

    filtered.sort(key=lambda row: (row["parameter_pid"], row["parameter"]))
    machine_rows = [
        {
            "parameter_pid": row["parameter_pid"],
            "parameter": row["parameter"],
            "role": row["role"],
            "surface": row["surface"],
            "optimize_stage": row["optimize_stage"],
            "safe_range": row["safe_range"],
            "locked_value": row["locked_value"],
        }
        for row in filtered
    ]
    machine_identity = {
        "VariantID": variant_id,
        "VariantSnapshotID": variant_snapshot_id,
        "hypothesis_revision": hypothesis,
        "build_tag": build,
        "rows": machine_rows,
    }
    surface = {
        "schema_version": "factory-vnext-parameter-surface-v1",
        "authority": SURFACE_AUTHORITY,
        "VariantID": variant_id,
        "VariantSnapshotID": variant_snapshot_id,
        "hypothesis_revision": hypothesis,
        "build_tag": build,
        "SurfaceRowCount": len(filtered),
        "SurfaceRows": filtered,
    }
    surface["SurfaceID"] = stable_id("PSURF", machine_identity, hex_chars=24)
    validate_variant_parameter_surface(surface)
    return surface


def validate_variant_parameter_surface(surface: Mapping[str, Any]) -> None:
    if surface.get("authority") != SURFACE_AUTHORITY or not NON_AUTHORITATIVE:
        raise ParameterSurfaceError("surface authority boundary is missing")
    for name in ("SurfaceID", "VariantID", "VariantSnapshotID", "hypothesis_revision", "build_tag"):
        _text(surface.get(name), name)
    rows = surface.get("SurfaceRows")
    if not isinstance(rows, list) or not rows:
        raise ParameterSurfaceError("SurfaceRows must be a non-empty list")
    normalized = []
    for row in rows:
        if not isinstance(row, Mapping):
            raise ParameterSurfaceError("SurfaceRows must contain mapping rows")
        normalized.append({
            "parameter_pid": _row_key(row, "parameter_pid"),
            "parameter": _text(row.get("parameter"), "parameter"),
            "role": _text(row.get("role"), "role"),
            "surface": _text(row.get("surface"), "surface"),
            "optimize_stage": _text(row.get("optimize_stage"), "optimize_stage"),
            "safe_range": row.get("safe_range"),
            "locked_value": row.get("locked_value"),
        })
    normalized.sort(key=lambda row: (row["parameter_pid"], row["parameter"]))
    expected = stable_id(
        "PSURF",
        {
            "VariantID": surface["VariantID"],
            "VariantSnapshotID": surface["VariantSnapshotID"],
            "hypothesis_revision": surface["hypothesis_revision"],
            "build_tag": surface["build_tag"],
            "rows": normalized,
        },
        hex_chars=24,
    )
    if surface["SurfaceID"] != expected:
        raise ParameterSurfaceError("SurfaceID does not match immutable machine identity")


def surface_machine_rows(surface: Mapping[str, Any]) -> List[Dict[str, Any]]:
    validate_variant_parameter_surface(surface)
    return [
        {
            "parameter_pid": row["parameter_pid"],
            "parameter": row["parameter"],
            "role": row["role"],
            "surface": row["surface"],
            "optimize_stage": row["optimize_stage"],
            "safe_range": row["safe_range"],
            "locked_value": row["locked_value"],
        }
        for row in sorted(surface["SurfaceRows"], key=lambda row: (row["parameter_pid"], row["parameter"]))
    ]
