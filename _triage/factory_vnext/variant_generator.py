# -*- coding: utf-8 -*-
"""Deterministic non-authoritative Template Variant Generator for Factory vNext."""
from __future__ import annotations

import re
from typing import Any, Dict, Mapping

from .contracts import canonical_json, stable_id
from .parameter_surface import (
    ParameterSurfaceError,
    surface_machine_rows,
    validate_variant_parameter_surface,
)


class VariantGeneratorError(ValueError):
    pass


AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"
SCHEMA_VERSION = "factory-vnext-variant-build-package-v1"
_ALLOWED_PARAMETER_ROLES = {"TUNABLE", "LOCKED"}
_SOURCE_SHA_RE = re.compile(r"^[0-9a-f]{40}$")


def _need_text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise VariantGeneratorError("%s is required" % name)
    return value.strip()


def _validate_linkage(
    master: Mapping[str, Any],
    family: Mapping[str, Any],
    variant: Mapping[str, Any],
    parameter_surface: Mapping[str, Any],
) -> None:
    master_id = _need_text(master.get("MasterMoldID"), "MasterMoldID")
    family_master = _need_text(family.get("MasterMoldID"), "Family.MasterMoldID")
    if family_master != master_id:
        raise VariantGeneratorError("MasterMoldID mismatch between Master Mold and Family")
    family_id = _need_text(family.get("FamilyID"), "FamilyID")
    if _need_text(variant.get("FamilyID"), "Variant.FamilyID") != family_id:
        raise VariantGeneratorError("FamilyID mismatch between Family and Variant")
    variant_id = _need_text(variant.get("VariantID"), "VariantID")
    if _need_text(parameter_surface.get("VariantID"), "Surface.VariantID") != variant_id:
        raise VariantGeneratorError("VariantID mismatch between Variant and Parameter Surface")
    snapshot_id = _need_text(variant.get("VariantSnapshotID"), "VariantSnapshotID")
    if _need_text(parameter_surface.get("VariantSnapshotID"), "Surface.VariantSnapshotID") != snapshot_id:
        raise VariantGeneratorError("VariantSnapshotID mismatch between Variant and Parameter Surface")


def _validate_surface_roles(parameter_surface: Mapping[str, Any]) -> None:
    rows = parameter_surface.get("SurfaceRows")
    if not isinstance(rows, list) or not rows:
        raise VariantGeneratorError("Parameter SurfaceRows must be a non-empty list")
    for row in rows:
        role = str(row.get("role", "")).strip().upper()
        if role not in _ALLOWED_PARAMETER_ROLES:
            raise VariantGeneratorError("unsupported parameter role %r" % row.get("role"))


def _enabled_components(variant: Mapping[str, Any], family: Mapping[str, Any]) -> list[Dict[str, Any]]:
    family_caps = {str(x) for x in (family.get("Capabilities") or [])}
    result: list[Dict[str, Any]] = []
    for raw in variant.get("Components") or []:
        if not bool(raw.get("Enabled")):
            continue
        capabilities = sorted({str(x) for x in (raw.get("Capabilities") or [])})
        outside = sorted(set(capabilities) - family_caps)
        if outside:
            raise VariantGeneratorError("enabled component capability outside Family: %s" % ",".join(outside))
        result.append({
            "ComponentID": _need_text(raw.get("ComponentID"), "ComponentID"),
            "ComponentRole": _need_text(raw.get("ComponentRole"), "ComponentRole"),
            "PositionGroupID": _need_text(raw.get("PositionGroupID"), "PositionGroupID"),
            "ParentPositionGroupID": raw.get("ParentPositionGroupID"),
            "RecoveryScopePositionGroupID": raw.get("RecoveryScopePositionGroupID"),
            "Capabilities": capabilities,
        })
    result.sort(key=lambda row: row["ComponentID"])
    return result


def _parameter_projection(parameter_surface: Mapping[str, Any]) -> list[Dict[str, Any]]:
    try:
        rows = surface_machine_rows(parameter_surface)
    except ParameterSurfaceError as exc:
        raise VariantGeneratorError(str(exc)) from exc
    result: list[Dict[str, Any]] = []
    for row in rows:
        role = str(row["role"]).upper()
        projection = "ACTIVE_TUNABLE" if role == "TUNABLE" else "SNAPSHOT_ONLY"
        result.append({
            "parameter_pid": row["parameter_pid"],
            "parameter": row["parameter"],
            "role": role,
            "surface": row["surface"],
            "optimize_stage": row["optimize_stage"],
            "safe_range": row["safe_range"],
            "locked_value": row["locked_value"],
            "projection": projection,
        })
    result.sort(key=lambda row: (row["parameter_pid"], row["parameter"]))
    return result


def _baseline_coverage(
    coverage: Any, projection: list[Dict[str, Any]],
) -> list[Dict[str, Any]]:
    if not isinstance(coverage, list):
        raise VariantGeneratorError("BaselineCoverage must be a list")
    projection_by_name: Dict[str, list[Dict[str, Any]]] = {}
    for row in projection:
        projection_by_name.setdefault(row["parameter"], []).append(row)
    result: list[Dict[str, Any]] = []
    names = set()
    pids = set()
    required = {
        "baseline_parameter", "parameter_pid", "projection_parameter", "disposition",
    }
    for raw in coverage:
        if not isinstance(raw, Mapping):
            raise VariantGeneratorError("BaselineCoverage must contain mapping rows")
        if set(raw) != required:
            missing = sorted(required - set(raw))
            if missing:
                raise VariantGeneratorError("%s is required for BaselineCoverage row" % missing[0])
            raise VariantGeneratorError("BaselineCoverage row has unsupported fields")
        baseline = _need_text(raw.get("baseline_parameter"), "baseline_parameter")
        if baseline != raw.get("baseline_parameter"):
            raise VariantGeneratorError("baseline_parameter must not have surrounding whitespace")
        if baseline in names:
            raise VariantGeneratorError("duplicate BaselineCoverage baseline_parameter %s" % baseline)
        pid = raw.get("parameter_pid")
        if isinstance(pid, bool) or not isinstance(pid, int):
            raise VariantGeneratorError("parameter_pid must be an integer for %s" % baseline)
        if pid in pids:
            raise VariantGeneratorError("duplicate BaselineCoverage parameter_pid %s" % pid)
        disposition = raw.get("disposition")
        projection_parameter = raw.get("projection_parameter")
        if disposition == "PROJECT":
            if not isinstance(projection_parameter, str) or not projection_parameter:
                raise VariantGeneratorError("PROJECT projection_parameter is required for %s" % baseline)
            matches = projection_by_name.get(projection_parameter, [])
            if len(matches) != 1:
                raise VariantGeneratorError("PROJECT projection_parameter must reference exactly one ParameterProjection row for %s" % baseline)
            if matches[0]["parameter_pid"] != pid:
                raise VariantGeneratorError("parameter_pid mismatch for BaselineCoverage %s" % baseline)
        elif disposition == "PRESERVE_SNAPSHOT":
            if projection_parameter is not None:
                raise VariantGeneratorError("PRESERVE_SNAPSHOT projection_parameter must be null for %s" % baseline)
        else:
            raise VariantGeneratorError("unsupported BaselineCoverage disposition for %s" % baseline)
        names.add(baseline)
        pids.add(pid)
        result.append({
            "baseline_parameter": baseline,
            "parameter_pid": pid,
            "projection_parameter": projection_parameter,
            "disposition": disposition,
        })
    return sorted(result, key=lambda row: row["baseline_parameter"])


def _identity_payload(package: Mapping[str, Any]) -> Dict[str, Any]:
    keys = (
        "source_commit", "TemplateID", "MasterMoldID", "MasterMoldVersion",
        "MasterMoldSnapshotID", "FamilyID", "VariantID", "VariantSnapshotID",
        "StrategyVersion", "ParameterSurfaceID", "hypothesis_revision", "build_tag",
        "ActiveCapabilities", "EnabledComponents", "ParameterProjection",
    )
    payload = {key: package[key] for key in keys}
    if "BaselineCoverage" in package:
        payload["BaselineCoverage"] = package["BaselineCoverage"]
    return payload


def make_variant_build_package(
    *,
    master: Mapping[str, Any],
    family: Mapping[str, Any],
    variant: Mapping[str, Any],
    parameter_surface: Mapping[str, Any],
    source_commit: str,
    template_id: str,
    baseline_coverage: list[Mapping[str, Any]] | None = None,
) -> Dict[str, Any]:
    _validate_linkage(master, family, variant, parameter_surface)
    _validate_surface_roles(parameter_surface)
    if not _SOURCE_SHA_RE.match(str(source_commit)):
        raise VariantGeneratorError("source_commit must be a lowercase 40-hex SHA")
    template = _need_text(template_id, "TemplateID")
    try:
        validate_variant_parameter_surface(parameter_surface)
    except ParameterSurfaceError as exc:
        raise VariantGeneratorError(str(exc)) from exc
    components = _enabled_components(variant, family)
    active_caps = sorted({cap for row in components for cap in row["Capabilities"]})
    projection = _parameter_projection(parameter_surface)
    package: Dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "authority": AUTHORITY,
        "source_commit": str(source_commit),
        "TemplateID": template,
        "MasterMoldID": _need_text(master.get("MasterMoldID"), "MasterMoldID"),
        "MasterMoldVersion": _need_text(master.get("MasterMoldVersion"), "MasterMoldVersion"),
        "MasterMoldSnapshotID": _need_text(master.get("MasterMoldSnapshotID"), "MasterMoldSnapshotID"),
        "FamilyID": _need_text(family.get("FamilyID"), "FamilyID"),
        "VariantID": _need_text(variant.get("VariantID"), "VariantID"),
        "VariantSnapshotID": _need_text(variant.get("VariantSnapshotID"), "VariantSnapshotID"),
        "StrategyVersion": _need_text(variant.get("StrategyVersion"), "StrategyVersion"),
        "ParameterSurfaceID": _need_text(parameter_surface.get("SurfaceID"), "SurfaceID"),
        "hypothesis_revision": _need_text(parameter_surface.get("hypothesis_revision"), "hypothesis_revision"),
        "build_tag": _need_text(parameter_surface.get("build_tag"), "build_tag"),
        "ActiveCapabilities": active_caps,
        "EnabledComponents": components,
        "ParameterProjection": projection,
    }
    if baseline_coverage is not None:
        package["BaselineCoverage"] = _baseline_coverage(baseline_coverage, projection)
    package["PackageID"] = stable_id("VPKG", _identity_payload(package), hex_chars=24)
    validate_variant_build_package(package)
    return package


def validate_variant_build_package(package: Mapping[str, Any]) -> None:
    if package.get("authority") != AUTHORITY:
        raise VariantGeneratorError("package authority boundary is missing")
    if package.get("schema_version") != SCHEMA_VERSION:
        raise VariantGeneratorError("unsupported package schema_version")
    if not _SOURCE_SHA_RE.match(str(package.get("source_commit", ""))):
        raise VariantGeneratorError("source_commit must be a lowercase 40-hex SHA")
    for name in (
        "PackageID", "TemplateID", "MasterMoldID", "MasterMoldVersion",
        "MasterMoldSnapshotID", "FamilyID", "VariantID", "VariantSnapshotID",
        "StrategyVersion", "ParameterSurfaceID", "hypothesis_revision", "build_tag",
    ):
        _need_text(package.get(name), name)
    if not isinstance(package.get("ActiveCapabilities"), list):
        raise VariantGeneratorError("ActiveCapabilities must be a list")
    if not isinstance(package.get("EnabledComponents"), list):
        raise VariantGeneratorError("EnabledComponents must be a list")
    if not isinstance(package.get("ParameterProjection"), list):
        raise VariantGeneratorError("ParameterProjection must be a list")
    if "BaselineCoverage" in package:
        normalized_coverage = _baseline_coverage(package["BaselineCoverage"], package["ParameterProjection"])
        if package["BaselineCoverage"] != normalized_coverage:
            raise VariantGeneratorError("BaselineCoverage rows must be deterministically sorted")
    expected = stable_id("VPKG", _identity_payload(package), hex_chars=24)
    if package["PackageID"] != expected:
        raise VariantGeneratorError("PackageID does not match immutable package identity")


def serialize_variant_build_package(package: Mapping[str, Any]) -> bytes:
    validate_variant_build_package(package)
    return canonical_json(dict(package)).encode("utf-8")
