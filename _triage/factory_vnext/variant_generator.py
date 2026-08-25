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


def _identity_payload(package: Mapping[str, Any]) -> Dict[str, Any]:
    return {key: package[key] for key in (
        "source_commit", "TemplateID", "MasterMoldID", "MasterMoldVersion",
        "MasterMoldSnapshotID", "FamilyID", "VariantID", "VariantSnapshotID",
        "StrategyVersion", "ParameterSurfaceID", "hypothesis_revision", "build_tag",
        "ActiveCapabilities", "EnabledComponents", "ParameterProjection",
    )}


def make_variant_build_package(
    *,
    master: Mapping[str, Any],
    family: Mapping[str, Any],
    variant: Mapping[str, Any],
    parameter_surface: Mapping[str, Any],
    source_commit: str,
    template_id: str,
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
    expected = stable_id("VPKG", _identity_payload(package), hex_chars=24)
    if package["PackageID"] != expected:
        raise VariantGeneratorError("PackageID does not match immutable package identity")


def serialize_variant_build_package(package: Mapping[str, Any]) -> bytes:
    validate_variant_build_package(package)
    return canonical_json(dict(package)).encode("utf-8")
