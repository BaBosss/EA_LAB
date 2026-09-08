# -*- coding: utf-8 -*-
"""Repository-only owner presentation derived from P1 OwnerRecipe sources.

The presentation is an additive, non-authoritative read model.  Its public
seams accept P1 source bundles, never prebuilt recipe dictionaries, and call
the public P1 catalog builder before projecting any owner-facing field.
"""
from __future__ import annotations

import copy
import json
import re
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, Mapping, Optional

from .contracts import canonical_json, sha256_bytes, stable_id
from .owner_recipe import (
    AUTHORITY,
    EFFECTIVE,
    IGNORED,
    LOCKED,
    LOT_PROGRESSION_SEMANTICS,
    SEMANTICS_REQUIRED,
    OwnerRecipeError,
    make_owner_recipe_catalog,
    validate_owner_recipe_catalog,
)


class OwnerRecipePresentationError(OwnerRecipeError):
    pass


PRESENTATION_SCHEMA = "factory-vnext-owner-recipe-presentation-v1"
PRESENTATION_SCOPE = "REPOSITORY_ONLY"
PRESENTATION_STATES = {EFFECTIVE, LOCKED, IGNORED, SEMANTICS_REQUIRED}
PRESENTATION_FIELDS = {
    "schema_version",
    "authority",
    "scope",
    "OwnerRecipePresentationID",
    "OwnerRecipePresentationSHA256",
    "Recipes",
}
ROW_FIELDS = {
    "FamilyID",
    "LogicalVariantID",
    "Modules",
    "Home",
    "Controls",
    "ExactReferences",
    "Blockers",
    "Status",
    "NextAction",
}
MODULE_FIELDS = {
    "ActiveCapabilities",
    "EnabledComponents",
    "LotProgressionSemantics",
}
HOME_FIELDS = {"HomeContractID"}
CONTROL_FIELDS = {
    "ParameterPID",
    "Parameter",
    "Requested",
    "Effective",
    "State",
    "Reason",
}
REFERENCE_FIELDS = {
    "IdentityProjectionID",
    "HypothesisRevision",
    "ProfileID",
    "ParameterSetID",
    "ParameterSnapshotSHA256",
    "ResolvedEffectiveConfigID",
    "ResolvedEffectiveConfigSHA256",
    "OwnerRecipeID",
    "OwnerRecipeSHA256",
    "PackageID",
    "BuildReceipt",
    "RunID",
    "LegacyAliasIDs",
}
BLOCKER_FIELDS = {"parameter_pid", "parameter", "reason"}
_REASON_CODE_RE = re.compile(r"^[A-Z][A-Z0-9_]{1,127}$")
_PRESENTATION_ID_RE = re.compile(r"^ORVIEW-[0-9a-f]{24}$")
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _presentation_payload(record: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "authority": record["authority"],
        "scope": record["scope"],
        "Recipes": record["Recipes"],
    }


def _read_json_without_duplicate_keys(path: Path) -> Any:
    def object_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise OwnerRecipePresentationError(
                    "source path JSON contains duplicate field %s" % key
                )
            result[key] = value
        return result

    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=object_pairs,
            parse_constant=lambda value: (_ for _ in ()).throw(
                OwnerRecipePresentationError(
                    "source path JSON contains non-finite value %s" % value
                )
            ),
        )
    except OwnerRecipePresentationError:
        raise
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise OwnerRecipePresentationError(
            "source path is unreadable or malformed JSON: %s" % path
        ) from exc


def _canonical_source_path(value: Any) -> PurePosixPath:
    if not isinstance(value, str) or not value or value != value.strip():
        raise OwnerRecipePresentationError(
            "source paths must be non-empty canonical repository-relative strings"
        )
    path = PurePosixPath(value)
    if (
        path.is_absolute()
        or path.as_posix() != value
        or value.startswith("/")
        or "\\" in value
        or ":" in value
        or any(part in {"", ".", ".."} for part in path.parts)
    ):
        raise OwnerRecipePresentationError(
            "source path must be canonical and repository-relative"
        )
    return path


def _validate_source_paths(
    sources: list[Mapping[str, Any]],
    source_paths: Optional[Iterable[str]],
    repo_root: Optional[str],
) -> None:
    if source_paths is None:
        return
    if repo_root is None:
        raise OwnerRecipePresentationError("source paths require repo_root")
    paths = list(source_paths)
    if len(paths) != len(sources):
        raise OwnerRecipePresentationError(
            "source/path count mismatch"
        )
    canonical = [_canonical_source_path(path) for path in paths]
    canonical_text = [path.as_posix() for path in canonical]
    if canonical_text != sorted(set(canonical_text)):
        raise OwnerRecipePresentationError(
            "source paths must be unique and deterministically sorted"
        )
    root = Path(repo_root).resolve()
    if not root.is_dir():
        raise OwnerRecipePresentationError("repo_root must be an existing directory")
    for source, relative in zip(sources, canonical):
        candidate = (root / Path(*relative.parts)).resolve()
        try:
            candidate.relative_to(root)
        except ValueError as exc:
            raise OwnerRecipePresentationError(
                "source path escapes repo_root"
            ) from exc
        loaded = _read_json_without_duplicate_keys(candidate)
        if loaded != source:
            raise OwnerRecipePresentationError(
                "source/path mismatch: source bundle differs from repository bytes"
            )


def _control_view(control: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "ParameterPID": control["parameter_pid"],
        "Parameter": control["parameter"],
        "Requested": copy.deepcopy(control["requested_value"]),
        "Effective": copy.deepcopy(control["effective_value"]),
        "State": control["state"],
        "Reason": control["reason"],
    }


def _recipe_view(
    recipe: Mapping[str, Any], source: Mapping[str, Any]
) -> dict[str, Any]:
    identity = recipe["Identity"]
    parameter_set = source["ParameterSet"]
    package = source["VariantBuildPackage"]
    return {
        "FamilyID": identity["FamilyID"],
        "LogicalVariantID": identity["LogicalVariantID"],
        "Modules": {
            "ActiveCapabilities": copy.deepcopy(package["ActiveCapabilities"]),
            "EnabledComponents": copy.deepcopy(package["EnabledComponents"]),
            "LotProgressionSemantics": copy.deepcopy(
                recipe["LotProgressionSemantics"]
            ),
        },
        "Home": {"HomeContractID": identity["HomeContractID"]},
        "Controls": [_control_view(control) for control in recipe["Controls"]],
        "ExactReferences": {
            "IdentityProjectionID": identity["IdentityProjectionID"],
            "HypothesisRevision": identity["HypothesisRevision"],
            "ProfileID": parameter_set["ProfileID"],
            "ParameterSetID": identity["ParameterSetID"],
            "ParameterSnapshotSHA256": parameter_set[
                "parameter_snapshot_sha256"
            ],
            "ResolvedEffectiveConfigID": recipe["ResolvedEffectiveConfigID"],
            "ResolvedEffectiveConfigSHA256": recipe[
                "ResolvedEffectiveConfigSHA256"
            ],
            "OwnerRecipeID": recipe["OwnerRecipeID"],
            "OwnerRecipeSHA256": recipe["OwnerRecipeSHA256"],
            "PackageID": identity["PackageID"],
            "BuildReceipt": identity["BuildReceipt"],
            "RunID": identity["RunID"],
            "LegacyAliasIDs": copy.deepcopy(identity["LegacyAliasIDs"]),
        },
        "Blockers": copy.deepcopy(recipe["Blockers"]),
        "Status": recipe["Status"],
        "NextAction": recipe["NextAction"],
    }


def _row_sort_key(row: Mapping[str, Any]) -> tuple[str, str, str, str, str]:
    refs = row["ExactReferences"]
    return (
        row["FamilyID"],
        row["LogicalVariantID"],
        row["Home"]["HomeContractID"],
        refs["ParameterSetID"],
        refs["OwnerRecipeID"],
    )


def make_owner_recipe_presentation(
    sources: Iterable[Mapping[str, Any]],
    *,
    repo_root: Optional[str] = None,
    source_paths: Optional[Iterable[str]] = None,
) -> dict[str, Any]:
    """Build one owner-facing projection from exact P1 source bundles."""
    source_rows = list(sources)
    _validate_source_paths(source_rows, source_paths, repo_root)
    try:
        catalog = make_owner_recipe_catalog(source_rows, repo_root=repo_root)
        validate_owner_recipe_catalog(
            catalog, sources=source_rows, repo_root=repo_root
        )
    except OwnerRecipeError as exc:
        raise OwnerRecipePresentationError(
            "P1 source bundle validation/build failed: %s" % exc
        ) from exc

    source_by_identity = {
        source["IdentityProjection"]["IdentityProjectionID"]: source
        for source in source_rows
    }
    rows = [
        _recipe_view(
            recipe,
            source_by_identity[recipe["Identity"]["IdentityProjectionID"]],
        )
        for recipe in catalog["Recipes"]
    ]
    rows.sort(key=_row_sort_key)
    record: dict[str, Any] = {
        "schema_version": PRESENTATION_SCHEMA,
        "authority": AUTHORITY,
        "scope": PRESENTATION_SCOPE,
        "Recipes": rows,
    }
    payload = _presentation_payload(record)
    record["OwnerRecipePresentationSHA256"] = sha256_bytes(
        canonical_json(payload).encode("utf-8")
    )
    record["OwnerRecipePresentationID"] = stable_id(
        "ORVIEW", payload, hex_chars=24
    )
    _validate_presentation_structure(record)
    return record


def _validate_presentation_structure(record: Mapping[str, Any]) -> None:
    if not isinstance(record, Mapping) or set(record) != PRESENTATION_FIELDS:
        raise OwnerRecipePresentationError(
            "OwnerRecipePresentation fields do not match schema"
        )
    if (
        record.get("schema_version") != PRESENTATION_SCHEMA
        or record.get("authority") != AUTHORITY
        or record.get("scope") != PRESENTATION_SCOPE
    ):
        raise OwnerRecipePresentationError(
            "OwnerRecipePresentation authority/scope/schema mismatch"
        )
    rows = record.get("Recipes")
    if not isinstance(rows, list):
        raise OwnerRecipePresentationError(
            "OwnerRecipePresentation Recipes must be a list"
        )
    for row in rows:
        if not isinstance(row, Mapping) or set(row) != ROW_FIELDS:
            raise OwnerRecipePresentationError("presentation row fields do not match schema")
        modules = row.get("Modules")
        home = row.get("Home")
        refs = row.get("ExactReferences")
        controls = row.get("Controls")
        blockers = row.get("Blockers")
        if not isinstance(modules, Mapping) or set(modules) != MODULE_FIELDS:
            raise OwnerRecipePresentationError("presentation Modules fields do not match schema")
        if modules.get("LotProgressionSemantics") != LOT_PROGRESSION_SEMANTICS:
            raise OwnerRecipePresentationError("presentation lot progression semantics drift")
        if not isinstance(modules.get("ActiveCapabilities"), list):
            raise OwnerRecipePresentationError("ActiveCapabilities must be a list")
        if not isinstance(modules.get("EnabledComponents"), list):
            raise OwnerRecipePresentationError("EnabledComponents must be a list")
        if not isinstance(home, Mapping) or set(home) != HOME_FIELDS:
            raise OwnerRecipePresentationError("presentation Home fields do not match schema")
        if not isinstance(refs, Mapping) or set(refs) != REFERENCE_FIELDS:
            raise OwnerRecipePresentationError(
                "presentation ExactReferences fields do not match schema"
            )
        if not isinstance(controls, list):
            raise OwnerRecipePresentationError("presentation Controls must be a list")
        control_keys: list[tuple[int, str]] = []
        for control in controls:
            if not isinstance(control, Mapping) or set(control) != CONTROL_FIELDS:
                raise OwnerRecipePresentationError(
                    "presentation control fields do not match schema"
                )
            state = control.get("State")
            reason = control.get("Reason")
            if state not in PRESENTATION_STATES:
                raise OwnerRecipePresentationError("unsupported presentation control state")
            if not isinstance(reason, str) or not _REASON_CODE_RE.fullmatch(reason):
                raise OwnerRecipePresentationError("unsupported presentation control reason")
            if state in {IGNORED, SEMANTICS_REQUIRED} and control.get("Effective") is not None:
                raise OwnerRecipePresentationError(
                    "ignored/blocked presentation control effective value must be null"
                )
            pid, name = control.get("ParameterPID"), control.get("Parameter")
            if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 0:
                raise OwnerRecipePresentationError("presentation ParameterPID is invalid")
            if not isinstance(name, str) or not name or name != name.strip():
                raise OwnerRecipePresentationError("presentation Parameter is invalid")
            control_keys.append((pid, name))
        if control_keys != sorted(control_keys) or len(control_keys) != len(set(control_keys)):
            raise OwnerRecipePresentationError(
                "presentation Controls must be unique and deterministically sorted"
            )
        if not isinstance(blockers, list):
            raise OwnerRecipePresentationError("presentation Blockers must be a list")
        for blocker in blockers:
            if not isinstance(blocker, Mapping) or set(blocker) != BLOCKER_FIELDS:
                raise OwnerRecipePresentationError(
                    "presentation blocker fields do not match schema"
                )
        expected_pair = (
            ("BLOCKED_SEMANTICS_REQUIRED", "RESOLVE_SEMANTICS_REQUIRED")
            if blockers
            else ("READY", "CONSUME_OWNER_RECIPE")
        )
        if (row.get("Status"), row.get("NextAction")) != expected_pair:
            raise OwnerRecipePresentationError(
                "presentation status/next action mismatch"
            )
    if rows != sorted(rows, key=_row_sort_key):
        raise OwnerRecipePresentationError(
            "presentation Recipes must be deterministically hierarchy-sorted"
        )
    ids = [row["ExactReferences"]["OwnerRecipeID"] for row in rows]
    if len(ids) != len(set(ids)):
        raise OwnerRecipePresentationError("duplicate OwnerRecipeID in presentation")
    expected_sha = sha256_bytes(
        canonical_json(_presentation_payload(record)).encode("utf-8")
    )
    if record.get("OwnerRecipePresentationSHA256") != expected_sha:
        raise OwnerRecipePresentationError(
            "OwnerRecipePresentationSHA256 mismatch"
        )
    expected_id = stable_id(
        "ORVIEW", _presentation_payload(record), hex_chars=24
    )
    if record.get("OwnerRecipePresentationID") != expected_id:
        raise OwnerRecipePresentationError("OwnerRecipePresentationID mismatch")
    if not _PRESENTATION_ID_RE.fullmatch(
        str(record.get("OwnerRecipePresentationID"))
    ) or not _SHA256_RE.fullmatch(
        str(record.get("OwnerRecipePresentationSHA256"))
    ):
        raise OwnerRecipePresentationError(
            "OwnerRecipePresentation identity/hash format is invalid"
        )


def validate_owner_recipe_presentation(
    record: Mapping[str, Any],
    *,
    sources: Iterable[Mapping[str, Any]],
    repo_root: Optional[str] = None,
    source_paths: Optional[Iterable[str]] = None,
) -> None:
    """Validate a presentation by rebuilding it from mandatory P1 sources."""
    _validate_presentation_structure(record)
    expected = make_owner_recipe_presentation(
        sources, repo_root=repo_root, source_paths=source_paths
    )
    if dict(record) != expected:
        raise OwnerRecipePresentationError(
            "OwnerRecipePresentation does not match supplied P1 source bundles"
        )


def serialize_owner_recipe_presentation(
    record: Mapping[str, Any],
    *,
    sources: Iterable[Mapping[str, Any]],
    repo_root: Optional[str] = None,
    source_paths: Optional[Iterable[str]] = None,
) -> bytes:
    """Serialize a source-bound presentation as canonical JSON plus newline."""
    validate_owner_recipe_presentation(
        record,
        sources=sources,
        repo_root=repo_root,
        source_paths=source_paths,
    )
    return (canonical_json(dict(record)) + "\n").encode("utf-8")
