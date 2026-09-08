# -*- coding: utf-8 -*-
"""Additive identity projections for the non-authoritative Factory vNext sidecar."""
from __future__ import annotations

import json
import re
from pathlib import Path, PurePosixPath
from typing import Any, Dict, Iterable, Mapping, Optional

from .contracts import sha256_file, stable_id
from .variant_generator import validate_variant_build_package


class IdentityModelError(ValueError):
    pass


AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"
IDENTITY_SCHEMA_VERSION = "factory-vnext-identity-projection-v1"
LEGACY_ALIAS_SCHEMA_VERSION = "factory-vnext-legacy-identity-alias-v1"
ALIAS_CATALOG_SCHEMA_VERSION = "factory-vnext-identity-alias-catalog-v1"
H01_SEMANTICS_REQUIRED_REASON = (
    "LEGACY_H01_FIXED_CONFIG_LOGICAL_VARIANT_SEMANTICS_REQUIRED"
)
EXPLICIT_MAPPING_REASON = "EXPLICIT_SEMANTIC_MAPPING"
_MACHINE_ID_RE = re.compile(r"^[A-Z][A-Z0-9._-]{1,63}$")
_ALIAS_ID_RE = re.compile(r"^IALIAS-[0-9a-f]{24}$")
_BUILD_RECEIPT_RE = re.compile(r"^br-[0-9a-f]{32}$")
_HOME_ID_RE = re.compile(r"^HOME-[0-9a-f]{20}$")
_PARAMETER_SET_ID_RE = re.compile(r"^PARAM-[0-9a-f]{20}$")
_RUN_ID_RE = re.compile(r"^RUN-[0-9a-f]{24}$")
_PACKAGE_ID_RE = re.compile(r"^VPKG-[0-9a-f]{24}$")
_VARIANT_SNAPSHOT_ID_RE = re.compile(r"^VAR-[0-9a-f]{24}$")
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")

_IDENTITY_FIELDS = {
    "schema_version",
    "authority",
    "IdentityProjectionID",
    "FamilyID",
    "LogicalVariantID",
    "HypothesisRevision",
    "HomeContractID",
    "ParameterSetID",
    "BuildReceipt",
    "RunID",
    "PackageID",
    "LegacyAliasIDs",
}
_SOURCE_ARTIFACT_FIELDS = {"path", "sha256"}
_LEGACY_ALIAS_FIELDS = {
    "schema_version",
    "authority",
    "AliasID",
    "FamilyID",
    "LegacyVariantID",
    "VariantSnapshotID",
    "HypothesisRevision",
    "StrategyVersion",
    "LogicalVariantID",
    "ResolutionStatus",
    "ReasonCode",
    "BuildReceipt",
    "RunID",
    "PackageID",
    "SourceArtifact",
}
_ALIAS_CATALOG_FIELDS = {
    "schema_version",
    "authority",
    "AliasCatalogID",
    "Aliases",
}


def _clean_text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise IdentityModelError("%s is required" % name)
    if value != value.strip():
        raise IdentityModelError("%s must not have surrounding whitespace" % name)
    return value


def _machine_id(value: Any, name: str) -> str:
    text = _clean_text(value, name).upper()
    if not _MACHINE_ID_RE.fullmatch(text):
        raise IdentityModelError("%s is not a valid machine id" % name)
    return text


def _optional_ref(value: Any, name: str, pattern: re.Pattern[str]) -> Optional[str]:
    if value is None:
        return None
    text = _clean_text(value, name)
    if not pattern.fullmatch(text):
        raise IdentityModelError("%s is not a valid reference" % name)
    return text


def _required_ref(value: Any, name: str, pattern: re.Pattern[str]) -> str:
    text = _clean_text(value, name)
    if not pattern.fullmatch(text):
        raise IdentityModelError("%s is not a valid reference" % name)
    return text


def _logical_variant_id(value: Any, family_id: str) -> str:
    logical = _machine_id(value, "LogicalVariantID")
    if not logical.startswith(family_id + "-"):
        raise IdentityModelError("LogicalVariantID must belong to FamilyID %s" % family_id)
    return logical


def _alias_id(value: Any) -> str:
    return _required_ref(value, "LegacyAliasID", _ALIAS_ID_RE)


def _source_path(value: Any) -> str:
    text = _clean_text(value, "SourceArtifact.path")
    if "\\" in text:
        raise IdentityModelError("SourceArtifact.path must use forward slashes")
    path = PurePosixPath(text)
    if path.is_absolute() or ".." in path.parts or str(path) != text:
        raise IdentityModelError("SourceArtifact.path must be a normalized repository-relative path")
    return text


def _source_artifact(value: Any) -> Dict[str, str]:
    if not isinstance(value, Mapping) or set(value) != _SOURCE_ARTIFACT_FIELDS:
        raise IdentityModelError("SourceArtifact fields do not match schema")
    path = _source_path(value.get("path"))
    sha256 = _required_ref(value.get("sha256"), "SourceArtifact.sha256", _SHA256_RE)
    return {"path": path, "sha256": sha256}


def source_artifact_ref(repo_root: str, source_path: str) -> Dict[str, str]:
    """Return a repository-relative source reference without interpreting its identity."""
    relative = _source_path(str(source_path).replace("\\", "/"))
    root = Path(repo_root).resolve()
    candidate = (root / Path(*PurePosixPath(relative).parts)).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise IdentityModelError("SourceArtifact.path escapes repository root") from exc
    if not candidate.is_file():
        raise IdentityModelError("SourceArtifact does not exist: %s" % relative)
    return {"path": relative, "sha256": sha256_file(str(candidate))}


def _identity_payload(record: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        key: record[key]
        for key in (
            "FamilyID",
            "LogicalVariantID",
            "HypothesisRevision",
            "HomeContractID",
            "ParameterSetID",
            "BuildReceipt",
            "RunID",
            "PackageID",
            "LegacyAliasIDs",
        )
    }


def make_identity_projection(
    *,
    family_id: str,
    logical_variant_id: str,
    hypothesis_revision: str,
    home_contract_id: str,
    parameter_set_id: str,
    build_receipt: Optional[str] = None,
    run_id: Optional[str] = None,
    package_id: Optional[str] = None,
    legacy_alias_ids: Iterable[str] = (),
) -> Dict[str, Any]:
    """Build a normalized resolved identity from explicitly supplied identity layers."""
    family = _machine_id(family_id, "FamilyID")
    aliases = sorted({_alias_id(value) for value in legacy_alias_ids})
    record: Dict[str, Any] = {
        "schema_version": IDENTITY_SCHEMA_VERSION,
        "authority": AUTHORITY,
        "FamilyID": family,
        "LogicalVariantID": _logical_variant_id(logical_variant_id, family),
        "HypothesisRevision": _clean_text(hypothesis_revision, "HypothesisRevision"),
        "HomeContractID": _required_ref(home_contract_id, "HomeContractID", _HOME_ID_RE),
        "ParameterSetID": _required_ref(parameter_set_id, "ParameterSetID", _PARAMETER_SET_ID_RE),
        "BuildReceipt": _optional_ref(build_receipt, "BuildReceipt", _BUILD_RECEIPT_RE),
        "RunID": _optional_ref(run_id, "RunID", _RUN_ID_RE),
        "PackageID": _optional_ref(package_id, "PackageID", _PACKAGE_ID_RE),
        "LegacyAliasIDs": aliases,
    }
    record["IdentityProjectionID"] = stable_id(
        "EAID", _identity_payload(record), hex_chars=24
    )
    validate_identity_projection(record)
    return record


def validate_identity_projection(record: Mapping[str, Any]) -> None:
    if not isinstance(record, Mapping):
        raise IdentityModelError("identity projection must be a mapping")
    if set(record) != _IDENTITY_FIELDS:
        raise IdentityModelError("identity projection fields do not match schema")
    if record.get("schema_version") != IDENTITY_SCHEMA_VERSION:
        raise IdentityModelError("unsupported identity projection schema_version")
    if record.get("authority") != AUTHORITY:
        raise IdentityModelError("identity projection authority boundary is missing")
    family = _machine_id(record.get("FamilyID"), "FamilyID")
    if record.get("FamilyID") != family:
        raise IdentityModelError("FamilyID must use canonical uppercase form")
    logical = _logical_variant_id(record.get("LogicalVariantID"), family)
    if record.get("LogicalVariantID") != logical:
        raise IdentityModelError("LogicalVariantID must use canonical uppercase form")
    _clean_text(record.get("HypothesisRevision"), "HypothesisRevision")
    _required_ref(record.get("HomeContractID"), "HomeContractID", _HOME_ID_RE)
    _required_ref(record.get("ParameterSetID"), "ParameterSetID", _PARAMETER_SET_ID_RE)
    _optional_ref(record.get("BuildReceipt"), "BuildReceipt", _BUILD_RECEIPT_RE)
    _optional_ref(record.get("RunID"), "RunID", _RUN_ID_RE)
    _optional_ref(record.get("PackageID"), "PackageID", _PACKAGE_ID_RE)
    aliases = record.get("LegacyAliasIDs")
    if not isinstance(aliases, list):
        raise IdentityModelError("LegacyAliasIDs must be a list")
    normalized_aliases = sorted({_alias_id(value) for value in aliases})
    if aliases != normalized_aliases:
        raise IdentityModelError("LegacyAliasIDs must be unique and deterministically sorted")
    expected = stable_id("EAID", _identity_payload(record), hex_chars=24)
    if record.get("IdentityProjectionID") != expected:
        raise IdentityModelError("IdentityProjectionID does not match identity layers")


def _alias_payload(record: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        key: record[key]
        for key in (
            "FamilyID",
            "LegacyVariantID",
            "VariantSnapshotID",
            "HypothesisRevision",
            "StrategyVersion",
            "BuildReceipt",
            "RunID",
            "PackageID",
            "SourceArtifact",
        )
    }


def make_legacy_alias(
    *,
    family_id: str,
    legacy_variant_id: str,
    variant_snapshot_id: str,
    hypothesis_revision: str,
    strategy_version: str,
    package_id: str,
    source_artifact: Mapping[str, Any],
    logical_variant_id: Optional[str] = None,
    resolution_status: str = "SEMANTICS_REQUIRED",
    reason_code: str = H01_SEMANTICS_REQUIRED_REASON,
    build_receipt: Optional[str] = None,
    run_id: Optional[str] = None,
) -> Dict[str, Any]:
    """Build a legacy alias row; resolution is explicit and is never derived."""
    family = _machine_id(family_id, "FamilyID")
    status = _clean_text(resolution_status, "ResolutionStatus").upper()
    logical = (
        _logical_variant_id(logical_variant_id, family)
        if logical_variant_id is not None
        else None
    )
    record: Dict[str, Any] = {
        "schema_version": LEGACY_ALIAS_SCHEMA_VERSION,
        "authority": AUTHORITY,
        "FamilyID": family,
        "LegacyVariantID": _machine_id(legacy_variant_id, "LegacyVariantID"),
        "VariantSnapshotID": _required_ref(
            variant_snapshot_id, "VariantSnapshotID", _VARIANT_SNAPSHOT_ID_RE
        ),
        "HypothesisRevision": _clean_text(
            hypothesis_revision, "HypothesisRevision"
        ),
        "StrategyVersion": _clean_text(strategy_version, "StrategyVersion"),
        "LogicalVariantID": logical,
        "ResolutionStatus": status,
        "ReasonCode": _machine_id(reason_code, "ReasonCode"),
        "BuildReceipt": _optional_ref(
            build_receipt, "BuildReceipt", _BUILD_RECEIPT_RE
        ),
        "RunID": _optional_ref(run_id, "RunID", _RUN_ID_RE),
        "PackageID": _required_ref(package_id, "PackageID", _PACKAGE_ID_RE),
        "SourceArtifact": _source_artifact(source_artifact),
    }
    record["AliasID"] = stable_id("IALIAS", _alias_payload(record), hex_chars=24)
    validate_legacy_alias(record)
    return record


def validate_legacy_alias(
    record: Mapping[str, Any], *, repo_root: Optional[str] = None
) -> None:
    if not isinstance(record, Mapping):
        raise IdentityModelError("legacy alias must be a mapping")
    if set(record) != _LEGACY_ALIAS_FIELDS:
        raise IdentityModelError("legacy alias fields do not match schema")
    if record.get("schema_version") != LEGACY_ALIAS_SCHEMA_VERSION:
        raise IdentityModelError("unsupported legacy alias schema_version")
    if record.get("authority") != AUTHORITY:
        raise IdentityModelError("legacy alias authority boundary is missing")
    family = _machine_id(record.get("FamilyID"), "FamilyID")
    if record.get("FamilyID") != family:
        raise IdentityModelError("FamilyID must use canonical uppercase form")
    legacy = _machine_id(record.get("LegacyVariantID"), "LegacyVariantID")
    if record.get("LegacyVariantID") != legacy:
        raise IdentityModelError("LegacyVariantID must use canonical uppercase form")
    _required_ref(record.get("VariantSnapshotID"), "VariantSnapshotID", _VARIANT_SNAPSHOT_ID_RE)
    _clean_text(record.get("HypothesisRevision"), "HypothesisRevision")
    _clean_text(record.get("StrategyVersion"), "StrategyVersion")
    status = _clean_text(record.get("ResolutionStatus"), "ResolutionStatus")
    reason = _machine_id(record.get("ReasonCode"), "ReasonCode")
    logical = record.get("LogicalVariantID")
    if status == "SEMANTICS_REQUIRED":
        if logical is not None:
            raise IdentityModelError(
                "SEMANTICS_REQUIRED alias must keep LogicalVariantID null"
            )
        if reason != H01_SEMANTICS_REQUIRED_REASON:
            raise IdentityModelError("SEMANTICS_REQUIRED alias has unsupported ReasonCode")
    elif status == "RESOLVED":
        _logical_variant_id(logical, family)
        if reason != EXPLICIT_MAPPING_REASON:
            raise IdentityModelError("RESOLVED alias has unsupported ReasonCode")
    else:
        raise IdentityModelError("unsupported ResolutionStatus")
    _optional_ref(record.get("BuildReceipt"), "BuildReceipt", _BUILD_RECEIPT_RE)
    _optional_ref(record.get("RunID"), "RunID", _RUN_ID_RE)
    _required_ref(record.get("PackageID"), "PackageID", _PACKAGE_ID_RE)
    source = _source_artifact(record.get("SourceArtifact"))
    expected = stable_id("IALIAS", _alias_payload(record), hex_chars=24)
    if record.get("AliasID") != expected:
        raise IdentityModelError("AliasID does not match legacy source identity")
    if repo_root is not None:
        actual_ref = source_artifact_ref(repo_root, source["path"])
        if actual_ref["sha256"] != source["sha256"]:
            raise IdentityModelError("SourceArtifact sha256 mismatch")
        source_path = Path(repo_root).resolve() / Path(
            *PurePosixPath(source["path"]).parts
        )
        try:
            source_record = json.loads(source_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            raise IdentityModelError("SourceArtifact is not readable JSON") from exc
        if not isinstance(source_record, Mapping):
            raise IdentityModelError("SourceArtifact must contain a JSON object")
        try:
            validate_variant_build_package(source_record)
        except ValueError as exc:
            raise IdentityModelError("SourceArtifact package validation failed") from exc
        expected_source_fields = {
            "FamilyID": record["FamilyID"],
            "VariantID": record["LegacyVariantID"],
            "VariantSnapshotID": record["VariantSnapshotID"],
            "hypothesis_revision": record["HypothesisRevision"],
            "StrategyVersion": record["StrategyVersion"],
            "PackageID": record["PackageID"],
            "authority": AUTHORITY,
        }
        for name, value in expected_source_fields.items():
            if source_record.get(name) != value:
                raise IdentityModelError(
                    "legacy alias does not match SourceArtifact field %s" % name
                )


def _alias_sort_key(record: Mapping[str, Any]) -> tuple[str, str, str]:
    return (
        str(record.get("FamilyID")),
        str(record.get("LegacyVariantID")),
        str(record.get("VariantSnapshotID")),
    )


def make_alias_catalog(aliases: Iterable[Mapping[str, Any]]) -> Dict[str, Any]:
    rows = [dict(alias) for alias in aliases]
    rows.sort(key=_alias_sort_key)
    catalog: Dict[str, Any] = {
        "schema_version": ALIAS_CATALOG_SCHEMA_VERSION,
        "authority": AUTHORITY,
        "Aliases": rows,
    }
    catalog["AliasCatalogID"] = stable_id(
        "IALCAT", {"Aliases": rows}, hex_chars=24
    )
    validate_alias_catalog(catalog)
    return catalog


def validate_alias_catalog(
    catalog: Mapping[str, Any], *, repo_root: Optional[str] = None
) -> None:
    if not isinstance(catalog, Mapping):
        raise IdentityModelError("alias catalog must be a mapping")
    if set(catalog) != _ALIAS_CATALOG_FIELDS:
        raise IdentityModelError("alias catalog fields do not match schema")
    if catalog.get("schema_version") != ALIAS_CATALOG_SCHEMA_VERSION:
        raise IdentityModelError("unsupported alias catalog schema_version")
    if catalog.get("authority") != AUTHORITY:
        raise IdentityModelError("alias catalog authority boundary is missing")
    aliases = catalog.get("Aliases")
    if not isinstance(aliases, list):
        raise IdentityModelError("Aliases must be a list")
    for alias in aliases:
        validate_legacy_alias(alias, repo_root=repo_root)
    if aliases != sorted(aliases, key=_alias_sort_key):
        raise IdentityModelError("Aliases must be deterministically sorted")
    alias_ids = [alias["AliasID"] for alias in aliases]
    legacy_keys = [
        (alias["FamilyID"], alias["LegacyVariantID"]) for alias in aliases
    ]
    source_paths = [alias["SourceArtifact"]["path"] for alias in aliases]
    if (
        len(alias_ids) != len(set(alias_ids))
        or len(legacy_keys) != len(set(legacy_keys))
        or len(source_paths) != len(set(source_paths))
    ):
        raise IdentityModelError("duplicate legacy alias")
    expected = stable_id("IALCAT", {"Aliases": aliases}, hex_chars=24)
    if catalog.get("AliasCatalogID") != expected:
        raise IdentityModelError("AliasCatalogID does not match alias rows")


def serialize_alias_catalog(catalog: Mapping[str, Any]) -> bytes:
    validate_alias_catalog(catalog)
    return (json.dumps(catalog, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def load_alias_catalog(path: str, *, repo_root: str) -> Dict[str, Any]:
    try:
        catalog = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise IdentityModelError("alias catalog is not readable JSON") from exc
    if not isinstance(catalog, dict):
        raise IdentityModelError("alias catalog must contain a JSON object")
    validate_alias_catalog(catalog, repo_root=repo_root)
    return catalog
