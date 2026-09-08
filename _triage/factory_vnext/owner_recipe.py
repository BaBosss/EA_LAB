# -*- coding: utf-8 -*-
"""Deterministic owner-recipe read model for Factory vNext.

This module is additive and NON_AUTHORITATIVE_SIDECAR only.  It joins an
explicitly resolved IdentityProjection with source config/package facts; it
never infers product semantics, runtime precedence, or strategy quality.
"""
from __future__ import annotations

import copy
import json
import re
from typing import Any, Dict, Iterable, Mapping, Optional

from .contracts import canonical_json, sha256_bytes, stable_id
from .identity_model import IDENTITY_SCHEMA_VERSION, validate_identity_projection
from .variant_generator import validate_variant_build_package


class OwnerRecipeError(ValueError):
    pass


AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"
EFFECTIVE_SCHEMA = "factory-vnext-resolved-effective-config-v1"
RECIPE_SCHEMA = "factory-vnext-owner-recipe-v1"
CATALOG_SCHEMA = "factory-vnext-owner-recipe-catalog-v1"

EFFECTIVE = "EFFECTIVE"
LOCKED = "LOCKED"
IGNORED = "IGNORED"
SEMANTICS_REQUIRED = "SEMANTICS_REQUIRED"
STATES = {EFFECTIVE, LOCKED, IGNORED, SEMANTICS_REQUIRED}
_REASON_CODE_RE = re.compile(r"^[A-Z][A-Z0-9_]{1,127}$")
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_RESOLVED_CONFIG_ID_RE = re.compile(r"^RECFG-[0-9a-f]{24}$")

PARAMETER_SET_FIELDS = {
    "schema_version", "ProfileID", "ParameterSetID",
    "parameter_snapshot_sha256", "parameters",
}
VARIANT_BUILD_PACKAGE_FIELDS = {
    "schema_version", "authority", "source_commit", "TemplateID",
    "MasterMoldID", "MasterMoldVersion", "MasterMoldSnapshotID", "FamilyID",
    "VariantID", "VariantSnapshotID", "StrategyVersion", "ParameterSurfaceID",
    "hypothesis_revision", "build_tag", "ActiveCapabilities",
    "EnabledComponents", "ParameterProjection", "PackageID",
}
PARAMETER_PROJECTION_FIELDS = {
    "parameter_pid", "parameter", "role", "surface", "optimize_stage",
    "safe_range", "locked_value", "projection",
}
ENABLED_COMPONENT_FIELDS = {
    "ComponentID", "ComponentRole", "PositionGroupID", "ParentPositionGroupID",
    "RecoveryScopePositionGroupID", "Capabilities",
}
RESOLUTION_FIELDS = {
    "parameter_pid", "parameter", "state", "effective_value", "reason",
}
CONTROL_FIELDS = {
    "parameter_pid", "parameter", "requested_value", "effective_value",
    "state", "reason", "role", "surface", "optimize_stage",
}
EFFECTIVE_FIELDS = {
    "schema_version", "authority", "ResolvedEffectiveConfigID",
    "ResolvedEffectiveConfigSHA256",
    "IdentityProjectionID", "FamilyID", "LogicalVariantID",
    "HypothesisRevision", "ProfileID", "ParameterSetID",
    "ParameterSnapshotSHA256", "PackageID", "Controls", "Blockers",
    "LotProgressionSemantics",
}
RECIPE_IDENTITY_FIELDS = {
    "IdentityProjectionID", "FamilyID", "LogicalVariantID", "HypothesisRevision",
    "HomeContractID", "ParameterSetID", "BuildReceipt", "RunID", "PackageID", "LegacyAliasIDs",
}
RECIPE_FIELDS = {
    "schema_version", "authority", "OwnerRecipeID", "OwnerRecipeSHA256",
    "Identity", "ResolvedEffectiveConfigID", "ResolvedEffectiveConfigSHA256",
    "Controls", "Blockers", "Status", "NextAction",
    "LotProgressionSemantics",
}
CATALOG_FIELDS = {
    "schema_version", "authority", "OwnerRecipeCatalogID",
    "OwnerRecipeCatalogSHA256", "Recipes",
}
CATALOG_SOURCE_FIELDS = {
    "IdentityProjection", "ParameterSet", "VariantBuildPackage", "Resolutions",
}

LOT_PROGRESSION_SEMANTICS = {
    "PROG_PLUS": "ADDITIVE: firstLot + plus * level",
    "PROG_LINEAR": "PROPORTIONAL: firstLot * (1 + factor * level)",
}

def _need_text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip() or value != value.strip():
        raise OwnerRecipeError("%s is required without surrounding whitespace" % name)
    return value


def _reason_code(value: Any, name: str) -> str:
    text = _need_text(value, name)
    if not _REASON_CODE_RE.fullmatch(text):
        raise OwnerRecipeError("%s must be an uppercase machine reason code" % name)
    return text


def _payload_sha256(value: Mapping[str, Any]) -> str:
    return sha256_bytes(canonical_json(dict(value)).encode("utf-8"))


def _validate_json_value(value: Any, name: str) -> None:
    try:
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
    except (TypeError, ValueError) as exc:
        raise OwnerRecipeError(
            "%s must contain only finite JSON values" % name
        ) from exc


def _same_json_value(left: Any, right: Any) -> bool:
    _validate_json_value(left, "effective/requested value")
    _validate_json_value(right, "effective/requested value")
    return canonical_json(left) == canonical_json(right)


def _validate_parameter_set(parameter_set: Mapping[str, Any]) -> Dict[str, Any]:
    if not isinstance(parameter_set, Mapping) or set(parameter_set) != PARAMETER_SET_FIELDS:
        raise OwnerRecipeError("ParameterSet fields do not match schema")
    if parameter_set.get("schema_version") != "factory-vnext-parameter-set-v1":
        raise OwnerRecipeError("unsupported ParameterSet schema_version")
    _need_text(parameter_set.get("ProfileID"), "ProfileID")
    params = parameter_set.get("parameters")
    if not isinstance(params, Mapping):
        raise OwnerRecipeError("ParameterSet.parameters must be a mapping")
    if any(
        not isinstance(key, str) or not key or key != key.strip()
        for key in params
    ):
        raise OwnerRecipeError(
            "ParameterSet parameter names must be non-empty strings without surrounding whitespace"
        )
    snapshot = {key: params[key] for key in sorted(params)}
    _validate_json_value(snapshot, "ParameterSet.parameters")
    digest = sha256_bytes(canonical_json(snapshot).encode("utf-8"))
    expected_id = "PARAM-%s" % digest[:20]
    if parameter_set.get("parameter_snapshot_sha256") != digest:
        raise OwnerRecipeError("ParameterSet snapshot hash mismatch")
    if parameter_set.get("ParameterSetID") != expected_id:
        raise OwnerRecipeError("ParameterSetID mismatch")
    return snapshot


def _sorted_unique_text_list(value: Any, name: str) -> list[str]:
    if not isinstance(value, list):
        raise OwnerRecipeError("%s must be a list" % name)
    normalized = [_need_text(item, name + " item") for item in value]
    if normalized != sorted(set(normalized)):
        raise OwnerRecipeError("%s must be unique and deterministically sorted" % name)
    return normalized


def _validate_package_schema(package: Mapping[str, Any]) -> None:
    package_fields = set(package) if isinstance(package, Mapping) else set()
    if package_fields not in (
        VARIANT_BUILD_PACKAGE_FIELDS,
        VARIANT_BUILD_PACKAGE_FIELDS | {"BaselineCoverage"},
    ):
        raise OwnerRecipeError("VariantBuildPackage fields do not match schema")
    _sorted_unique_text_list(package.get("ActiveCapabilities"), "ActiveCapabilities")
    components = package.get("EnabledComponents")
    if not isinstance(components, list):
        raise OwnerRecipeError("EnabledComponents must be a list")
    component_ids: list[str] = []
    for component in components:
        if not isinstance(component, Mapping) or set(component) != ENABLED_COMPONENT_FIELDS:
            raise OwnerRecipeError("EnabledComponents row fields do not match schema")
        component_ids.append(_need_text(component.get("ComponentID"), "ComponentID"))
        _need_text(component.get("ComponentRole"), "ComponentRole")
        _need_text(component.get("PositionGroupID"), "PositionGroupID")
        for field in ("ParentPositionGroupID", "RecoveryScopePositionGroupID"):
            if component.get(field) is not None:
                _need_text(component.get(field), field)
        _sorted_unique_text_list(
            component.get("Capabilities"), "EnabledComponents.Capabilities"
        )
    if component_ids != sorted(set(component_ids)):
        raise OwnerRecipeError(
            "EnabledComponents must be unique and deterministically sorted"
        )
    _projection_rows(package)

def _validate_join(identity: Mapping[str, Any], parameter_set: Mapping[str, Any], package: Mapping[str, Any]) -> None:
    try:
        validate_identity_projection(identity)
    except ValueError as exc:
        raise OwnerRecipeError("IdentityProjection validation failed") from exc
    _validate_package_schema(package)
    try:
        validate_variant_build_package(package)
    except ValueError as exc:
        raise OwnerRecipeError("VariantBuildPackage validation failed") from exc
    if identity["ParameterSetID"] != parameter_set["ParameterSetID"]:
        raise OwnerRecipeError("IdentityProjection ParameterSetID mismatch")
    if identity["FamilyID"] != package.get("FamilyID"):
        raise OwnerRecipeError("IdentityProjection FamilyID mismatch")
    if identity["HypothesisRevision"] != package.get("hypothesis_revision"):
        raise OwnerRecipeError("IdentityProjection HypothesisRevision mismatch")
    package_ref = identity.get("PackageID")
    if package_ref is None:
        raise OwnerRecipeError(
            "IdentityProjection PackageID is required when a VariantBuildPackage is used"
        )
    if package_ref != package.get("PackageID"):
        raise OwnerRecipeError("IdentityProjection PackageID mismatch")


def _projection_rows(package: Mapping[str, Any]) -> list[Dict[str, Any]]:
    rows = package.get("ParameterProjection")
    if not isinstance(rows, list):
        raise OwnerRecipeError("ParameterProjection must be a list")
    seen_pid, seen_name = set(), set()
    result = []
    for raw in rows:
        if not isinstance(raw, Mapping):
            raise OwnerRecipeError("ParameterProjection row must be a mapping")
        if set(raw) != PARAMETER_PROJECTION_FIELDS:
            raise OwnerRecipeError("ParameterProjection row fields do not match schema")
        pid = raw.get("parameter_pid")
        name = raw.get("parameter")
        if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 0:
            raise OwnerRecipeError("ParameterProjection parameter_pid must be positive integer")
        _need_text(name, "ParameterProjection.parameter")
        if pid in seen_pid:
            raise OwnerRecipeError("duplicate ParameterProjection parameter_pid")
        if name in seen_name:
            raise OwnerRecipeError("duplicate ParameterProjection parameter")
        role = _need_text(raw.get("role"), "ParameterProjection.role")
        projection = _need_text(
            raw.get("projection"), "ParameterProjection.projection"
        )
        _need_text(raw.get("surface"), "ParameterProjection.surface")
        _need_text(raw.get("optimize_stage"), "ParameterProjection.optimize_stage")
        if (role, projection) not in {
            ("TUNABLE", "ACTIVE_TUNABLE"),
            ("LOCKED", "SNAPSHOT_ONLY"),
        }:
            raise OwnerRecipeError(
                "ParameterProjection role/projection combination is unsupported"
            )
        if role == "TUNABLE" and raw.get("locked_value") is not None:
            raise OwnerRecipeError(
                "ACTIVE_TUNABLE ParameterProjection locked_value must be null"
            )
        seen_pid.add(pid); seen_name.add(name)
        result.append(dict(raw))
    sorted_rows = sorted(
        result, key=lambda row: (row["parameter_pid"], row["parameter"])
    )
    if result != sorted_rows:
        raise OwnerRecipeError(
            "ParameterProjection rows must be deterministically sorted"
        )
    return sorted_rows

def _resolution_index(resolutions: Iterable[Mapping[str, Any]], rows: list[Dict[str, Any]]) -> Dict[int, Dict[str, Any]]:
    by_pid = {row["parameter_pid"]: row for row in rows}
    by_name = {row["parameter"]: row for row in rows}
    result: Dict[int, Dict[str, Any]] = {}
    for raw in resolutions:
        if not isinstance(raw, Mapping) or set(raw) != RESOLUTION_FIELDS:
            raise OwnerRecipeError("resolution fields do not match schema")
        pid = raw.get("parameter_pid")
        name = raw.get("parameter")
        if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 0:
            raise OwnerRecipeError("resolution parameter_pid must be positive integer")
        _need_text(name, "resolution.parameter")
        if pid in result:
            raise OwnerRecipeError("duplicate resolution parameter_pid")
        if pid not in by_pid or name not in by_name or by_pid[pid]["parameter"] != name:
            raise OwnerRecipeError("resolution does not match ParameterProjection")
        state = _need_text(raw.get("state"), "resolution.state")
        if state not in STATES:
            raise OwnerRecipeError("unsupported resolution state")
        _reason_code(raw.get("reason"), "resolution.reason")
        if by_pid[pid].get("role") == "LOCKED":
            raise OwnerRecipeError("explicit resolution cannot override package LOCKED row")
        if state == LOCKED:
            raise OwnerRecipeError("LOCKED state is package-derived only")
        effective = raw.get("effective_value")
        if state in {IGNORED, SEMANTICS_REQUIRED} and effective is not None:
            raise OwnerRecipeError("ignored/blocked resolution effective_value must be null")
        result[pid] = dict(raw)
    return result

def _control_from_row(row: Mapping[str, Any], params: Mapping[str, Any], override: Optional[Mapping[str, Any]]) -> Dict[str, Any]:
    pid = row["parameter_pid"]
    name = row["parameter"]
    requested = params.get(name)
    role = row.get("role")
    locked_value = row.get("locked_value")
    if name not in params:
        state, effective, reason = SEMANTICS_REQUIRED, None, "REQUEST_VALUE_MISSING"
    elif role == "LOCKED":
        if locked_value is None:
            state, effective, reason = SEMANTICS_REQUIRED, None, "PACKAGE_LOCKED_VALUE_MISSING"
        else:
            state, effective, reason = LOCKED, locked_value, "PACKAGE_LOCKED_VALUE"
    elif override is not None:
        state = override["state"]
        effective = override["effective_value"]
        reason = override["reason"]
        if state == EFFECTIVE:
            if name not in params:
                raise OwnerRecipeError("EFFECTIVE resolution requires requested parameter")
            if not _same_json_value(effective, requested):
                raise OwnerRecipeError("EFFECTIVE resolution cannot fake effective value")
    else:
        state, effective, reason = (
            SEMANTICS_REQUIRED, None, "EXPLICIT_RESOLUTION_REQUIRED"
        )
    return {
        "parameter_pid": pid,
        "parameter": name,
        "requested_value": requested,
        "effective_value": effective,
        "state": state,
        "reason": reason,
        "role": role,
        "surface": row.get("surface"),
        "optimize_stage": row.get("optimize_stage"),
    }

def _blockers(controls: Iterable[Mapping[str, Any]]) -> list[Dict[str, Any]]:
    rows = [
        {"parameter_pid": row["parameter_pid"], "parameter": row["parameter"], "reason": row["reason"]}
        for row in controls if row["state"] == SEMANTICS_REQUIRED
    ]
    return sorted(rows, key=lambda row: (row["parameter_pid"], row["parameter"]))


def _effective_payload(record: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        key: record[key]
        for key in (
            "IdentityProjectionID", "FamilyID", "LogicalVariantID", "HypothesisRevision",
            "ProfileID", "ParameterSetID", "ParameterSnapshotSHA256", "PackageID",
            "Controls", "Blockers", "LotProgressionSemantics",
        )
    }


def make_resolved_effective_config(
    identity: Mapping[str, Any], parameter_set: Mapping[str, Any], package: Mapping[str, Any],
    *, resolutions: Iterable[Mapping[str, Any]] = (),
) -> Dict[str, Any]:
    """Build the reason-coded effective-config read model from explicit source facts."""
    params = _validate_parameter_set(parameter_set)
    _validate_join(identity, parameter_set, package)
    rows = _projection_rows(package)
    overrides = _resolution_index(resolutions, rows)
    controls = [_control_from_row(row, params, overrides.get(row["parameter_pid"])) for row in rows]
    blockers = _blockers(controls)
    record: Dict[str, Any] = {
        "schema_version": EFFECTIVE_SCHEMA, "authority": AUTHORITY,
        "IdentityProjectionID": identity["IdentityProjectionID"], "FamilyID": identity["FamilyID"],
        "LogicalVariantID": identity["LogicalVariantID"], "HypothesisRevision": identity["HypothesisRevision"],
        "ProfileID": parameter_set["ProfileID"],
        "ParameterSetID": identity["ParameterSetID"],
        "ParameterSnapshotSHA256": parameter_set["parameter_snapshot_sha256"],
        "PackageID": package["PackageID"],
        "Controls": controls, "Blockers": blockers,
        "LotProgressionSemantics": dict(LOT_PROGRESSION_SEMANTICS),
    }
    record["ResolvedEffectiveConfigSHA256"] = _payload_sha256(
        _effective_payload(record)
    )
    record["ResolvedEffectiveConfigID"] = stable_id("RECFG", _effective_payload(record), hex_chars=24)
    _validate_resolved_effective_config_structure(record)
    return record

def _validate_control_rows(controls: Any) -> list[tuple[int, str]]:
    if not isinstance(controls, list):
        raise OwnerRecipeError("Controls must be a list")
    keys = []
    for row in controls:
        if not isinstance(row, Mapping) or set(row) != CONTROL_FIELDS:
            raise OwnerRecipeError("control fields do not match schema")
        if row.get("state") not in STATES:
            raise OwnerRecipeError("unsupported control state")
        _reason_code(row.get("reason"), "control.reason")
        pid, name = row.get("parameter_pid"), row.get("parameter")
        if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 0:
            raise OwnerRecipeError("control parameter_pid invalid")
        _need_text(name, "control.parameter")
        role = _need_text(row.get("role"), "control.role")
        _need_text(row.get("surface"), "control.surface")
        _need_text(row.get("optimize_stage"), "control.optimize_stage")
        if role not in {"TUNABLE", "LOCKED"}:
            raise OwnerRecipeError("unsupported control role")
        if row["state"] in {IGNORED, SEMANTICS_REQUIRED} and row.get("effective_value") is not None:
            raise OwnerRecipeError("ignored/blocked control effective_value must be null")
        if row["state"] in {EFFECTIVE, LOCKED} and row.get("effective_value") is None:
            raise OwnerRecipeError("effective/locked control effective_value is required")
        _validate_json_value(row.get("requested_value"), "control.requested_value")
        _validate_json_value(row.get("effective_value"), "control.effective_value")
        if row["state"] == EFFECTIVE and not _same_json_value(
            row.get("requested_value"), row.get("effective_value")
        ):
            raise OwnerRecipeError("EFFECTIVE control cannot fake effective value")
        if row["state"] == LOCKED and role != "LOCKED":
            raise OwnerRecipeError("LOCKED control must be package-derived")
        if role == "LOCKED" and row["state"] not in {LOCKED, SEMANTICS_REQUIRED}:
            raise OwnerRecipeError("package LOCKED control state is invalid")
        keys.append((pid, name))
    if keys != sorted(keys):
        raise OwnerRecipeError("Controls must be deterministically sorted")
    pids = [key[0] for key in keys]
    names = [key[1] for key in keys]
    if len(pids) != len(set(pids)):
        raise OwnerRecipeError("duplicate control parameter_pid")
    if len(names) != len(set(names)):
        raise OwnerRecipeError("duplicate control parameter")
    return keys


def _validate_resolved_effective_config_structure(record: Mapping[str, Any]) -> None:
    if not isinstance(record, Mapping) or set(record) != EFFECTIVE_FIELDS:
        raise OwnerRecipeError("ResolvedEffectiveConfig fields do not match schema")
    if record.get("schema_version") != EFFECTIVE_SCHEMA or record.get("authority") != AUTHORITY:
        raise OwnerRecipeError("ResolvedEffectiveConfig authority/schema mismatch")
    controls = record.get("Controls")
    _validate_control_rows(controls)
    expected_blockers = _blockers(controls)
    if record.get("Blockers") != expected_blockers:
        raise OwnerRecipeError("Blockers do not match SEMANTICS_REQUIRED controls")
    if record.get("LotProgressionSemantics") != LOT_PROGRESSION_SEMANTICS:
        raise OwnerRecipeError("lot progression semantics drift")
    expected_sha = _payload_sha256(_effective_payload(record))
    if record.get("ResolvedEffectiveConfigSHA256") != expected_sha:
        raise OwnerRecipeError("ResolvedEffectiveConfigSHA256 mismatch")
    expected = stable_id("RECFG", _effective_payload(record), hex_chars=24)
    if record.get("ResolvedEffectiveConfigID") != expected:
        raise OwnerRecipeError("ResolvedEffectiveConfigID mismatch")


def validate_resolved_effective_config(
    record: Mapping[str, Any],
    *,
    identity: Mapping[str, Any],
    parameter_set: Mapping[str, Any],
    package: Mapping[str, Any],
    resolutions: Iterable[Mapping[str, Any]] = (),
) -> None:
    """Validate structure and rebuild from mandatory source facts."""
    _validate_resolved_effective_config_structure(record)
    expected_record = make_resolved_effective_config(
        identity, parameter_set, package, resolutions=resolutions
    )
    if dict(record) != expected_record:
        raise OwnerRecipeError(
            "ResolvedEffectiveConfig does not match supplied source facts"
        )

def _recipe_identity(identity: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        key: identity[key]
        for key in (
            "IdentityProjectionID", "FamilyID", "LogicalVariantID", "HypothesisRevision",
            "HomeContractID", "ParameterSetID", "BuildReceipt", "RunID", "PackageID", "LegacyAliasIDs",
        )
    }


def _recipe_payload(record: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        key: record[key]
        for key in (
            "Identity", "ResolvedEffectiveConfigID", "ResolvedEffectiveConfigSHA256",
            "Controls", "Blockers", "Status", "NextAction",
            "LotProgressionSemantics",
        )
    }


def make_owner_recipe(
    identity: Mapping[str, Any],
    effective_config: Mapping[str, Any],
    *,
    parameter_set: Mapping[str, Any],
    package: Mapping[str, Any],
    resolutions: Iterable[Mapping[str, Any]] = (),
) -> Dict[str, Any]:
    resolution_rows = list(resolutions)
    try:
        validate_identity_projection(identity)
    except ValueError as exc:
        raise OwnerRecipeError("IdentityProjection validation failed") from exc
    validate_resolved_effective_config(
        effective_config,
        identity=identity,
        parameter_set=parameter_set,
        package=package,
        resolutions=resolution_rows,
    )
    for field in ("IdentityProjectionID", "FamilyID", "LogicalVariantID", "HypothesisRevision", "ParameterSetID"):
        if effective_config[field] != identity[field]:
            raise OwnerRecipeError("effective config identity mismatch: %s" % field)
    if effective_config["PackageID"] != identity["PackageID"]:
        raise OwnerRecipeError("effective config PackageID mismatch")
    blockers = list(effective_config["Blockers"])
    status = "BLOCKED_SEMANTICS_REQUIRED" if blockers else "READY"
    next_action = "RESOLVE_SEMANTICS_REQUIRED" if blockers else "CONSUME_OWNER_RECIPE"
    record: Dict[str, Any] = {
        "schema_version": RECIPE_SCHEMA, "authority": AUTHORITY,
        "Identity": copy.deepcopy(_recipe_identity(identity)), "ResolvedEffectiveConfigID": effective_config["ResolvedEffectiveConfigID"],
        "ResolvedEffectiveConfigSHA256": effective_config["ResolvedEffectiveConfigSHA256"],
        "Controls": copy.deepcopy(effective_config["Controls"]),
        "Blockers": copy.deepcopy(blockers),
        "Status": status, "NextAction": next_action,
        "LotProgressionSemantics": dict(LOT_PROGRESSION_SEMANTICS),
    }
    record["OwnerRecipeSHA256"] = _payload_sha256(_recipe_payload(record))
    record["OwnerRecipeID"] = stable_id("ORECIPE", _recipe_payload(record), hex_chars=24)
    _validate_owner_recipe_structure(record)
    return record


def _validate_owner_recipe_structure(record: Mapping[str, Any]) -> None:
    if not isinstance(record, Mapping) or set(record) != RECIPE_FIELDS:
        raise OwnerRecipeError("OwnerRecipe fields do not match schema")
    if record.get("schema_version") != RECIPE_SCHEMA or record.get("authority") != AUTHORITY:
        raise OwnerRecipeError("OwnerRecipe authority/schema mismatch")
    identity_reference = record.get("Identity")
    if (
        not isinstance(identity_reference, Mapping)
        or set(identity_reference) != RECIPE_IDENTITY_FIELDS
    ):
        raise OwnerRecipeError("OwnerRecipe.Identity fields do not match schema")
    projection = {
        "schema_version": IDENTITY_SCHEMA_VERSION,
        "authority": AUTHORITY,
        **identity_reference,
    }
    try:
        validate_identity_projection(projection)
    except ValueError as exc:
        raise OwnerRecipeError("OwnerRecipe.Identity validation failed") from exc
    controls = record.get("Controls")
    _validate_control_rows(controls)
    blockers = _blockers(controls)
    if record.get("Blockers") != blockers:
        raise OwnerRecipeError("OwnerRecipe blockers mismatch")
    expected_status = "BLOCKED_SEMANTICS_REQUIRED" if blockers else "READY"
    expected_next = "RESOLVE_SEMANTICS_REQUIRED" if blockers else "CONSUME_OWNER_RECIPE"
    if record.get("Status") != expected_status or record.get("NextAction") != expected_next:
        raise OwnerRecipeError("OwnerRecipe status/next action mismatch")
    if record.get("LotProgressionSemantics") != LOT_PROGRESSION_SEMANTICS:
        raise OwnerRecipeError("OwnerRecipe lot progression semantics drift")
    resolved_sha = record.get("ResolvedEffectiveConfigSHA256")
    if not isinstance(resolved_sha, str) or not _SHA256_RE.fullmatch(resolved_sha):
        raise OwnerRecipeError("ResolvedEffectiveConfigSHA256 is invalid")
    resolved_id = record.get("ResolvedEffectiveConfigID")
    if (
        not isinstance(resolved_id, str)
        or not _RESOLVED_CONFIG_ID_RE.fullmatch(resolved_id)
    ):
        raise OwnerRecipeError("ResolvedEffectiveConfigID is invalid")
    expected_sha = _payload_sha256(_recipe_payload(record))
    if record.get("OwnerRecipeSHA256") != expected_sha:
        raise OwnerRecipeError("OwnerRecipeSHA256 mismatch")
    expected = stable_id("ORECIPE", _recipe_payload(record), hex_chars=24)
    if record.get("OwnerRecipeID") != expected:
        raise OwnerRecipeError("OwnerRecipeID mismatch")


def validate_owner_recipe(
    record: Mapping[str, Any],
    *,
    identity: Mapping[str, Any],
    effective_config: Mapping[str, Any],
    parameter_set: Mapping[str, Any],
    package: Mapping[str, Any],
    resolutions: Iterable[Mapping[str, Any]] = (),
) -> None:
    """Validate a recipe against every source used to resolve it."""
    resolution_rows = list(resolutions)
    _validate_owner_recipe_structure(record)
    validate_resolved_effective_config(
        effective_config,
        identity=identity,
        parameter_set=parameter_set,
        package=package,
        resolutions=resolution_rows,
    )
    expected_record = make_owner_recipe(
        identity,
        effective_config,
        parameter_set=parameter_set,
        package=package,
        resolutions=resolution_rows,
    )
    if dict(record) != expected_record:
        raise OwnerRecipeError("OwnerRecipe does not match supplied source facts")


def serialize_resolved_effective_config(
    record: Mapping[str, Any],
    *,
    identity: Mapping[str, Any],
    parameter_set: Mapping[str, Any],
    package: Mapping[str, Any],
    resolutions: Iterable[Mapping[str, Any]] = (),
) -> bytes:
    """Serialize a source-bound resolved config deterministically."""
    validate_resolved_effective_config(
        record,
        identity=identity,
        parameter_set=parameter_set,
        package=package,
        resolutions=resolutions,
    )
    return (canonical_json(dict(record)) + "\n").encode("utf-8")


def serialize_owner_recipe(
    record: Mapping[str, Any],
    *,
    identity: Mapping[str, Any],
    effective_config: Mapping[str, Any],
    parameter_set: Mapping[str, Any],
    package: Mapping[str, Any],
    resolutions: Iterable[Mapping[str, Any]] = (),
) -> bytes:
    """Serialize a source-bound owner recipe deterministically."""
    validate_owner_recipe(
        record,
        identity=identity,
        effective_config=effective_config,
        parameter_set=parameter_set,
        package=package,
        resolutions=resolutions,
    )
    return (canonical_json(dict(record)) + "\n").encode("utf-8")


def _catalog_payload(record: Mapping[str, Any]) -> Dict[str, Any]:
    return {"Recipes": record["Recipes"]}


def _recipe_from_source_bundle(source: Mapping[str, Any]) -> Dict[str, Any]:
    if not isinstance(source, Mapping) or set(source) != CATALOG_SOURCE_FIELDS:
        raise OwnerRecipeError("catalog source fields do not match schema")
    resolutions = source.get("Resolutions")
    if not isinstance(resolutions, list):
        raise OwnerRecipeError("catalog source Resolutions must be a list")
    identity = source["IdentityProjection"]
    parameter_set = source["ParameterSet"]
    package = source["VariantBuildPackage"]
    effective_config = make_resolved_effective_config(
        identity, parameter_set, package, resolutions=resolutions
    )
    return make_owner_recipe(
        identity,
        effective_config,
        parameter_set=parameter_set,
        package=package,
        resolutions=resolutions,
    )


def make_owner_recipe_catalog(
    sources: Iterable[Mapping[str, Any]],
) -> Dict[str, Any]:
    """Build a catalog only from exact source-fact bundles."""
    rows = [_recipe_from_source_bundle(source) for source in sources]
    rows.sort(key=lambda recipe: recipe["OwnerRecipeID"])
    recipe_ids = [recipe["OwnerRecipeID"] for recipe in rows]
    if len(recipe_ids) != len(set(recipe_ids)):
        raise OwnerRecipeError("duplicate OwnerRecipeID in catalog")
    identity_ids = [
        recipe["Identity"]["IdentityProjectionID"] for recipe in rows
    ]
    if len(identity_ids) != len(set(identity_ids)):
        raise OwnerRecipeError("duplicate IdentityProjectionID in catalog")
    config_ids = [recipe["ResolvedEffectiveConfigID"] for recipe in rows]
    if len(config_ids) != len(set(config_ids)):
        raise OwnerRecipeError("duplicate ResolvedEffectiveConfigID in catalog")
    record: Dict[str, Any] = {
        "schema_version": CATALOG_SCHEMA,
        "authority": AUTHORITY,
        "Recipes": rows,
    }
    record["OwnerRecipeCatalogSHA256"] = _payload_sha256(
        _catalog_payload(record)
    )
    record["OwnerRecipeCatalogID"] = stable_id(
        "ORCAT", _catalog_payload(record), hex_chars=24
    )
    _validate_owner_recipe_catalog_structure(record)
    return record


def _validate_owner_recipe_catalog_structure(record: Mapping[str, Any]) -> None:
    if not isinstance(record, Mapping) or set(record) != CATALOG_FIELDS:
        raise OwnerRecipeError("OwnerRecipe catalog fields do not match schema")
    if (
        record.get("schema_version") != CATALOG_SCHEMA
        or record.get("authority") != AUTHORITY
    ):
        raise OwnerRecipeError("OwnerRecipe catalog authority/schema mismatch")
    recipes = record.get("Recipes")
    if not isinstance(recipes, list):
        raise OwnerRecipeError("OwnerRecipe catalog Recipes must be a list")
    for recipe in recipes:
        _validate_owner_recipe_structure(recipe)
    recipe_ids = [recipe["OwnerRecipeID"] for recipe in recipes]
    if len(recipe_ids) != len(set(recipe_ids)):
        raise OwnerRecipeError("duplicate OwnerRecipeID in catalog")
    identity_ids = [
        recipe["Identity"]["IdentityProjectionID"] for recipe in recipes
    ]
    if len(identity_ids) != len(set(identity_ids)):
        raise OwnerRecipeError("duplicate IdentityProjectionID in catalog")
    config_ids = [recipe["ResolvedEffectiveConfigID"] for recipe in recipes]
    if len(config_ids) != len(set(config_ids)):
        raise OwnerRecipeError("duplicate ResolvedEffectiveConfigID in catalog")
    if recipe_ids != sorted(recipe_ids):
        raise OwnerRecipeError("OwnerRecipe catalog must be deterministically sorted")
    expected_sha = _payload_sha256(_catalog_payload(record))
    if record.get("OwnerRecipeCatalogSHA256") != expected_sha:
        raise OwnerRecipeError("OwnerRecipeCatalogSHA256 mismatch")
    expected_id = stable_id("ORCAT", _catalog_payload(record), hex_chars=24)
    if record.get("OwnerRecipeCatalogID") != expected_id:
        raise OwnerRecipeError("OwnerRecipeCatalogID mismatch")


def validate_owner_recipe_catalog(
    record: Mapping[str, Any],
    *,
    sources: Iterable[Mapping[str, Any]],
) -> None:
    """Validate a catalog by rebuilding it from exact source-fact bundles."""
    _validate_owner_recipe_catalog_structure(record)
    expected_record = make_owner_recipe_catalog(sources)
    if dict(record) != expected_record:
        raise OwnerRecipeError("OwnerRecipe catalog does not match supplied source facts")


def serialize_owner_recipe_catalog(
    record: Mapping[str, Any],
    *,
    sources: Iterable[Mapping[str, Any]],
) -> bytes:
    """Serialize a source-bound recipe catalog deterministically."""
    validate_owner_recipe_catalog(record, sources=sources)
    return (canonical_json(dict(record)) + "\n").encode("utf-8")
