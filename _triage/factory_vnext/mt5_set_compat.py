# -*- coding: utf-8 -*-
"""Deterministic, non-authoritative MT5 `.set` compatibility dry-run sidecar."""
from __future__ import annotations

import hashlib
from typing import Any, Dict, Mapping

from _triage.factory_os import setfile

from .contracts import canonical_json
from .variant_generator import AUTHORITY, VariantGeneratorError, validate_variant_build_package


class MT5SetCompatError(ValueError):
    pass


_SCHEMA_VERSION = "factory-vnext-mt5-set-compat-v1"
_SCALAR_TYPES = (str, int, float, bool)


def _sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _validate_package(package: Mapping[str, Any]) -> None:
    try:
        validate_variant_build_package(package)
    except VariantGeneratorError as exc:
        raise MT5SetCompatError(str(exc)) from exc
    if package.get("authority") != AUTHORITY:
        raise MT5SetCompatError("package authority must be NON_AUTHORITATIVE_SIDECAR")


def _projection_rows(package: Mapping[str, Any]) -> list[Dict[str, Any]]:
    names = set()
    pids = set()
    rows: list[Dict[str, Any]] = []
    for raw in package["ParameterProjection"]:
        if not isinstance(raw, Mapping):
            raise MT5SetCompatError("ParameterProjection must contain mapping rows")
        name = raw.get("parameter")
        for field in (
            "parameter_pid", "parameter", "role", "surface", "optimize_stage",
            "safe_range", "locked_value", "projection",
        ):
            if field not in raw:
                raise MT5SetCompatError("%s is required for %s" % (field, name or "ParameterProjection row"))
        pid = raw.get("parameter_pid")
        if not isinstance(name, str) or not name:
            raise MT5SetCompatError("ParameterProjection parameter is required")
        if isinstance(pid, bool) or not isinstance(pid, int):
            raise MT5SetCompatError("ParameterProjection parameter_pid must be an integer for %s" % name)
        if name in names:
            raise MT5SetCompatError("duplicate ParameterProjection parameter %s" % name)
        if pid in pids:
            raise MT5SetCompatError("duplicate ParameterProjection parameter_pid %s" % pid)
        projection = raw.get("projection")
        if projection not in ("ACTIVE_TUNABLE", "SNAPSHOT_ONLY"):
            raise MT5SetCompatError("unsupported ParameterProjection projection for %s" % name)
        role = raw.get("role")
        if (role, projection) not in (("TUNABLE", "ACTIVE_TUNABLE"), ("LOCKED", "SNAPSHOT_ONLY")):
            raise MT5SetCompatError("role/projection mismatch for %s" % name)
        names.add(name)
        pids.add(pid)
        rows.append(dict(raw))
    return sorted(rows, key=lambda row: (row["parameter_pid"], row["parameter"]))


def _semantic_state(states: Mapping[str, Any] | None, parameter: str) -> Any:
    if not states or parameter not in states:
        return None
    state = states[parameter]
    if isinstance(state, Mapping):
        if "state" in state and "status" in state and state["state"] != state["status"]:
            raise MT5SetCompatError("conflicting semantic state/status for %s" % parameter)
        return state.get("state", state.get("status"))
    return state


def _render_scalar(value: Any) -> str | None:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, _SCALAR_TYPES):
        return str(value)
    return None


def _snapshot_tail(tail: str | None) -> tuple[str | None, bool, str | None]:
    if tail is None:
        return None, False, None
    parts = tail.split("||")
    if len(parts) != 4 or any(not part for part in parts) or parts[-1] not in ("Y", "N"):
        return tail, False, "MALFORMED_SNAPSHOT_OPTIMIZER_TAIL"
    if parts[-1] == "N":
        return tail, False, None
    return tail[:-1] + "N", True, None


def _replace_optimizer_tail(raw: str, tail: str, proposed_tail: str) -> str:
    """Change only a validated optimizer flag while retaining the original physical line."""
    end = len(raw.rstrip())
    if not raw[:end].endswith(tail):
        raise MT5SetCompatError("cannot locate validated optimizer tail in baseline line")
    return raw[:end - len(tail)] + proposed_tail + raw[end:]


def _render_baseline_with_replacements(baseline_text: str, lines: list[Any], replacements: Mapping[int, str]) -> str:
    physical_lines = baseline_text.splitlines(keepends=True)
    for line in lines:
        if line.lineno not in replacements:
            continue
        index = line.lineno - 1
        original = physical_lines[index]
        ending = "\r\n" if original.endswith("\r\n") else "\n" if original.endswith("\n") else ""
        physical_lines[index] = replacements[line.lineno] + ending
    return "".join(physical_lines)


def _manifest(result: Mapping[str, Any], proposed: str | None) -> Dict[str, Any]:
    return {
        "schema_version": _SCHEMA_VERSION,
        "authority": AUTHORITY,
        "PackageID": result["PackageID"],
        "baseline_sha256": result["baseline_sha256"],
        "proposed_output_sha256": _sha256_text(proposed) if proposed is not None else None,
        "operator_rows": result["operator_rows"],
        "refusal_rows": result["refusal_rows"],
    }


def build_mt5_set_compat(
    package: Mapping[str, Any], baseline_text: str, semantic_states: Mapping[str, Any] | None = None,
) -> Dict[str, Any]:
    """Build a dry-run compatibility result; this function never reads or writes a path."""
    if not isinstance(baseline_text, str):
        raise MT5SetCompatError("baseline_text must be text")
    _validate_package(package)
    projection = _projection_rows(package)
    try:
        lines, _comments = setfile.parse_set(baseline_text)
    except setfile.Refusal as exc:
        raise MT5SetCompatError(str(exc)) from exc
    baseline_by_name = {line.name: line for line in lines}
    projection_names = {row["parameter"] for row in projection}
    refusal_rows = [
        {"parameter": line.name, "disposition": "REFUSE", "reason": "UNKNOWN_OR_REMOVED_BASELINE_KEY"}
        for line in lines if line.name not in projection_names
    ]
    rows: list[Dict[str, Any]] = []
    can_emit = not refusal_rows
    replacements: Dict[int, str] = {}
    for projected in projection:
        name = projected["parameter"]
        semantic_state = _semantic_state(semantic_states, name)
        line = baseline_by_name.get(name)
        row = dict(projected)
        row.update({
            "baseline_present": line is not None,
            "baseline_value": line.value if line is not None else None,
            "baseline_tail": line.optimize_tail if line is not None else None,
            "semantic_state": semantic_state,
            "optimizer_disabled": False,
        })
        if semantic_state == "SEMANTICS_REQUIRED":
            row.update({"disposition": "REFUSE", "reason": "SEMANTICS_REQUIRED"})
            refusal_rows.append({"parameter": name, "disposition": "REFUSE", "reason": "SEMANTICS_REQUIRED"})
            can_emit = False
        elif line is not None:
            tail = line.optimize_tail
            if projected["projection"] == "SNAPSHOT_ONLY":
                tail, changed, tail_error = _snapshot_tail(tail)
                if tail_error:
                    row.update({"disposition": "REFUSE", "reason": tail_error})
                    refusal_rows.append({"parameter": name, "disposition": "REFUSE", "reason": tail_error})
                    can_emit = False
                    rows.append(row)
                    continue
                row["optimizer_disabled"] = changed
                if changed:
                    replacements[line.lineno] = _replace_optimizer_tail(line.raw, line.optimize_tail, tail)
            row["disposition"] = "MATCH"
            row["proposed_value"] = line.value
            row["proposed_tail"] = tail
        elif projected["projection"] == "SNAPSHOT_ONLY":
            value = _render_scalar(projected.get("locked_value"))
            if value is None:
                row.update({"disposition": "UNMAPPED", "reason": "NO_RENDERABLE_LOCKED_VALUE"})
                can_emit = False
            else:
                row.update({"disposition": "ADD", "proposed_value": value, "proposed_tail": None})
        else:
            row.update({"disposition": "UNMAPPED", "reason": "MISSING_ACTIVE_TUNABLE"})
            can_emit = False
        rows.append(row)

    rows.sort(key=lambda row: (row["parameter_pid"], row["parameter"]))
    proposed = None
    if can_emit:
        proposed = _render_baseline_with_replacements(baseline_text, lines, replacements)
        additions = [row for row in rows if row["disposition"] == "ADD"]
        if additions:
            if proposed and not proposed.endswith(("\n", "\r")):
                proposed += "\n"
            proposed += "\n".join("%s=%s" % (row["parameter"], row["proposed_value"]) for row in additions) + "\n"
    result: Dict[str, Any] = {
        "schema_version": _SCHEMA_VERSION,
        "authority": AUTHORITY,
        "PackageID": package["PackageID"],
        "baseline_text": baseline_text,
        "baseline_sha256": _sha256_text(baseline_text),
        "operator_rows": rows,
        "refusal_rows": sorted(refusal_rows, key=lambda row: row["parameter"]),
        "proposed_set_text": proposed,
    }
    result["manifest"] = _manifest(result, proposed)
    return result


def render_proposed_set(result: Mapping[str, Any]) -> str:
    """Return the in-memory proposed `.set`, refusing incomplete or unsafe dry-runs."""
    proposed = result.get("proposed_set_text")
    if result.get("refusal_rows") or any(row.get("disposition") == "UNMAPPED" for row in result.get("operator_rows", [])):
        names = [row["parameter"] for row in result.get("refusal_rows", [])]
        names.extend(row["parameter"] for row in result.get("operator_rows", []) if row.get("disposition") == "UNMAPPED")
        raise MT5SetCompatError("proposed .set refused for: %s" % ", ".join(sorted(set(names))))
    if not isinstance(proposed, str):
        raise MT5SetCompatError("proposed .set is unavailable")
    return proposed


def serialize_compat_manifest(result: Mapping[str, Any]) -> bytes:
    """Serialize the deterministic machine manifest without host or clock fields."""
    manifest = result.get("manifest")
    if not isinstance(manifest, Mapping):
        raise MT5SetCompatError("compatibility manifest is required")
    return canonical_json(dict(manifest)).encode("utf-8")
