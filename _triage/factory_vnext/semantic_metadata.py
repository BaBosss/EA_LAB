# -*- coding: utf-8 -*-
"""Deterministic semantic metadata for the accepted SuperTrendFlip vNext pilot.

Only mechanically provable facts are emitted. Names and comments never create
strategy semantics. Unknown facts remain explicit UNKNOWN values.
"""
from __future__ import annotations

from decimal import Decimal, InvalidOperation
import os
import re
from typing import Any, Dict, List, Mapping, Optional

from .contracts import canonical_json, stable_id
from .supertrend_adapter import (
    CONCEPT_ID,
    EXECUTION_TF,
    LOGICAL_SYMBOL,
    SOURCE_REL_PATH,
    STRATEGY_VERSION,
    SuperTrendAdapterError,
    load_supertrend_pilot,
)


class SemanticMetadataError(ValueError):
    pass


SCHEMA_VERSION = "factory-vnext-semantic-metadata-v1"
AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"
STATUS_VALUES = ("PROVEN", "PARTIAL", "UNKNOWN")
_INPUT_RE = re.compile(
    r"^\s*input\s+(bool|int|long|ulong|double|string)\s+([A-Za-z_]\w*)\s*=\s*(.*?)\s*;",
    re.IGNORECASE,
)


def _fact(status: str, value: Any = None) -> Dict[str, Any]:
    if status not in STATUS_VALUES:
        raise SemanticMetadataError("invalid fact status %r" % status)
    return {"status": status, "value": value}


def _parse_literal(source_type: str, raw: str, label: str) -> Any:
    text = raw.strip()
    kind = source_type.lower()
    if kind == "bool":
        lowered = text.lower()
        if lowered == "true":
            return True
        if lowered == "false":
            return False
        raise SemanticMetadataError("%s invalid bool literal %r" % (label, raw))
    if kind in ("int", "long", "ulong"):
        if not re.match(r"^[+-]?\d+$", text):
            raise SemanticMetadataError("%s invalid integer literal %r" % (label, raw))
        value = int(text, 10)
        if kind == "ulong" and value < 0:
            raise SemanticMetadataError("%s invalid ulong literal %r" % (label, raw))
        return value
    if kind == "double":
        try:
            value = Decimal(text)
        except (InvalidOperation, ValueError) as exc:
            raise SemanticMetadataError("%s invalid numeric literal %r" % (label, raw)) from exc
        if not value.is_finite():
            raise SemanticMetadataError("%s invalid numeric literal %r" % (label, raw))
        return float(value)
    if kind == "string":
        if len(text) < 2 or not (text.startswith('"') and text.endswith('"')):
            raise SemanticMetadataError("%s invalid string literal %r" % (label, raw))
        return text[1:-1]
    raise SemanticMetadataError("%s unsupported input type %r" % (label, source_type))


def _parse_input_source(text: str) -> Dict[str, Dict[str, Any]]:
    definitions: Dict[str, Dict[str, Any]] = {}
    for lineno, line in enumerate(text.splitlines(), start=1):
        match = _INPUT_RE.match(line)
        if not match:
            continue
        source_type, name, raw_default = match.groups()
        if name in definitions:
            raise SemanticMetadataError("duplicate source input %r" % name)
        definitions[name] = {
            "source_type": source_type.lower(),
            "default_value": _parse_literal(source_type, raw_default, "%s default" % name),
            "source_line": lineno,
        }
    if not definitions:
        raise SemanticMetadataError("no MQL5 input definitions found")
    return definitions


def _value_behavior(source_type: str) -> str:
    if source_type == "bool":
        return "BOOLEAN"
    if source_type in ("int", "long", "ulong"):
        return "INTEGER"
    if source_type == "double":
        return "CONTINUOUS"
    if source_type == "string":
        return "DISCRETE_TEXT"
    raise SemanticMetadataError("unsupported source_type %r" % source_type)


def _unknown_fields(source_type: str) -> Dict[str, Dict[str, Any]]:
    facts = {
        "semantic_type": _fact("UNKNOWN"),
        "unit": _fact("UNKNOWN"),
        "directionality": _fact("UNKNOWN"),
        "boundedness": _fact("UNKNOWN"),
        "allowed_values": _fact("UNKNOWN"),
        "optimization_eligibility": _fact("UNKNOWN"),
        "optimization_domain": _fact("UNKNOWN"),
        "dependency": _fact("UNKNOWN"),
    }
    if source_type == "bool":
        facts.update({
            "semantic_type": _fact("PROVEN", "boolean_policy"),
            "unit": _fact("PROVEN", "UNITLESS"),
            "boundedness": _fact("PROVEN", "BOUNDED"),
            "allowed_values": _fact("PROVEN", [False, True]),
            "optimization_domain": _fact("PROVEN", {"kind": "ENUM", "allowed": [False, True]}),
        })
    return facts


def _semantic_identity(record: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        "schema_version": record["schema_version"],
        "authority": record["authority"],
        "ConceptID": record["ConceptID"],
        "StrategyVersion": record["StrategyVersion"],
        "LogicalSymbol": record["LogicalSymbol"],
        "ExecutionTF": record["ExecutionTF"],
        "ProfileID": record["ProfileID"],
        "ParameterSetID": record["ParameterSetID"],
        "parameter_snapshot_sha256": record["parameter_snapshot_sha256"],
        "source": record["source"],
        "preset": record["preset"],
        "KINT_001": record["KINT_001"],
        "parameters": record["parameters"],
    }


def _expected_identity(record: Mapping[str, Any]) -> None:
    expected = {
        "ConceptID": CONCEPT_ID,
        "StrategyVersion": STRATEGY_VERSION,
        "LogicalSymbol": LOGICAL_SYMBOL,
        "ExecutionTF": EXECUTION_TF,
    }
    for key, value in expected.items():
        if record.get(key) != value:
            raise SemanticMetadataError("strategy identity mismatch for %s" % key)


def _is_portable_path(value: Any) -> bool:
    if not isinstance(value, str) or not value:
        return False
    if os.path.isabs(value):
        return False
    normalized = value.replace("\\", "/")
    return not normalized.startswith("../") and "/../" not in normalized


def build_supertrend_semantic_metadata(
    repo_root: str,
    *,
    source_path: Optional[str] = None,
    preset_path: Optional[str] = None,
) -> Dict[str, Any]:
    root = os.path.abspath(repo_root)
    try:
        pilot = load_supertrend_pilot(root, source_path=source_path, preset_path=preset_path)
    except SuperTrendAdapterError as exc:
        raise SemanticMetadataError(str(exc)) from exc

    resolved_source = os.path.abspath(source_path) if source_path else os.path.join(root, *SOURCE_REL_PATH.split("/"))
    if not os.path.isfile(resolved_source):
        raise SemanticMetadataError("source not found: %s" % resolved_source)
    with open(resolved_source, "r", encoding="utf-8-sig") as fh:
        definitions = _parse_input_source(fh.read())

    snapshot = dict(pilot["ParameterSet"]["parameters"])
    missing_source = sorted(set(snapshot) - set(definitions))
    if missing_source:
        raise SemanticMetadataError("preset parameter missing from source: %s" % missing_source[0])
    executable_inputs = {
        name for name, spec in definitions.items()
        if not (spec["source_type"] == "string" and name.startswith("_g"))
    }
    missing_preset = sorted(executable_inputs - set(snapshot))
    if missing_preset:
        raise SemanticMetadataError("source input missing from full preset: %s" % missing_preset[0])

    source_ref = dict(pilot["SourceRef"])
    preset_ref = dict(pilot["PresetRef"])
    parameters: List[Dict[str, Any]] = []
    for name in sorted(snapshot):
        spec = definitions[name]
        source_type = spec["source_type"]
        preset_value = _parse_literal(source_type, snapshot[name], "%s preset" % name)
        facts = _unknown_fields(source_type)
        row: Dict[str, Any] = {
            "parameter": name,
            "source_name": name,
            "source_line": spec["source_line"],
            "source_type": _fact("PROVEN", source_type),
            "default_value": _fact("PROVEN", spec["default_value"]),
            "preset_value": _fact("PROVEN", preset_value),
            "value_behavior": _fact("PROVEN", _value_behavior(source_type)),
            "semantic_type": facts["semantic_type"],
            "unit": facts["unit"],
            "directionality": facts["directionality"],
            "boundedness": facts["boundedness"],
            "allowed_values": facts["allowed_values"],
            "optimization_eligibility": facts["optimization_eligibility"],
            "optimization_domain": facts["optimization_domain"],
            "dependency": facts["dependency"],
            "overall_status": "PARTIAL",
            "provenance": {
                "source": {"path": source_ref["path"], "sha256": source_ref["sha256"], "line": spec["source_line"]},
                "preset": {"path": preset_ref["path"], "sha256": preset_ref["sha256"], "key": name},
            },
        }
        parameters.append(row)

    record: Dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "authority": AUTHORITY,
        "ConceptID": pilot["ConceptID"],
        "StrategyVersion": pilot["StrategyVersion"],
        "LogicalSymbol": pilot["LogicalSymbol"],
        "ExecutionTF": pilot["ExecutionTF"],
        "ProfileID": pilot["ProfileID"],
        "ParameterSetID": pilot["ParameterSet"]["ParameterSetID"],
        "parameter_snapshot_sha256": pilot["ParameterSet"]["parameter_snapshot_sha256"],
        "source": source_ref,
        "preset": preset_ref,
        "KINT_001": {"state": "OPEN"},
        "parameters": parameters,
    }
    record["SemanticMetadataID"] = stable_id("SMETA", _semantic_identity(record), hex_chars=24)
    validate_semantic_metadata(record)
    return record


def _validate_fact(row: Mapping[str, Any], name: str) -> Dict[str, Any]:
    fact = row.get(name)
    if not isinstance(fact, Mapping):
        raise SemanticMetadataError("%s fact is required" % name)
    status = fact.get("status")
    if status not in STATUS_VALUES:
        raise SemanticMetadataError("%s fact has invalid status" % name)
    if "value" not in fact:
        raise SemanticMetadataError("%s fact value is required" % name)
    return dict(fact)


def _validate_ref(ref: Any, name: str) -> Dict[str, Any]:
    if not isinstance(ref, Mapping):
        raise SemanticMetadataError("%s is required" % name)
    path = ref.get("path")
    digest = ref.get("sha256")
    if not _is_portable_path(path):
        raise SemanticMetadataError("%s path must be repository-relative" % name)
    if not isinstance(digest, str) or not re.match(r"^[0-9a-f]{64}$", digest):
        raise SemanticMetadataError("%s sha256 is invalid" % name)
    return dict(ref)


def validate_semantic_metadata(record: Mapping[str, Any]) -> None:
    if not isinstance(record, Mapping):
        raise SemanticMetadataError("semantic metadata record is required")
    if record.get("schema_version") != SCHEMA_VERSION:
        raise SemanticMetadataError("semantic metadata schema_version mismatch")
    if record.get("authority") != AUTHORITY:
        raise SemanticMetadataError("semantic metadata authority boundary is missing")
    _expected_identity(record)
    if record.get("KINT_001") != {"state": "OPEN"}:
        raise SemanticMetadataError("KINT-001 must remain OPEN")
    for name in ("ProfileID", "ParameterSetID", "parameter_snapshot_sha256", "SemanticMetadataID"):
        value = record.get(name)
        if not isinstance(value, str) or not value.strip():
            raise SemanticMetadataError("%s is required" % name)
    _validate_ref(record.get("source"), "source")
    _validate_ref(record.get("preset"), "preset")

    rows = record.get("parameters")
    if not isinstance(rows, list) or not rows:
        raise SemanticMetadataError("parameters must be a non-empty list")
    seen = set()
    fact_names = (
        "source_type", "default_value", "preset_value", "value_behavior",
        "semantic_type", "unit", "directionality", "boundedness",
        "allowed_values", "optimization_eligibility", "optimization_domain",
        "dependency",
    )
    for row in rows:
        if not isinstance(row, Mapping):
            raise SemanticMetadataError("parameter row must be a mapping")
        name = row.get("parameter")
        if not isinstance(name, str) or not name:
            raise SemanticMetadataError("parameter is required")
        if name in seen:
            raise SemanticMetadataError("duplicate parameter %s" % name)
        seen.add(name)
        if row.get("source_name") != name:
            raise SemanticMetadataError("source_name mismatch for %s" % name)
        if row.get("overall_status") not in STATUS_VALUES:
            raise SemanticMetadataError("overall_status invalid for %s" % name)
        for fact_name in fact_names:
            _validate_fact(row, fact_name)
        provenance = row.get("provenance")
        if not isinstance(provenance, Mapping):
            raise SemanticMetadataError("provenance is required for %s" % name)
        src = provenance.get("source")
        pre = provenance.get("preset")
        if not isinstance(src, Mapping) or not _is_portable_path(src.get("path")):
            raise SemanticMetadataError("source provenance path invalid for %s" % name)
        if not isinstance(pre, Mapping) or not _is_portable_path(pre.get("path")):
            raise SemanticMetadataError("preset provenance path invalid for %s" % name)

    expected = stable_id("SMETA", _semantic_identity(record), hex_chars=24)
    if record.get("SemanticMetadataID") != expected:
        raise SemanticMetadataError("SemanticMetadataID does not match immutable identity")


def canonical_semantic_metadata_bytes(record: Mapping[str, Any]) -> bytes:
    validate_semantic_metadata(record)
    return (canonical_json(dict(record)) + "\n").encode("utf-8")


def write_supertrend_semantic_metadata(repo_root: str, output_path: str) -> str:
    record = build_supertrend_semantic_metadata(repo_root)
    target = os.path.abspath(output_path)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "wb") as fh:
        fh.write(canonical_semantic_metadata_bytes(record))
    return target


def _find_parameter(record: Mapping[str, Any], parameter: str) -> Dict[str, Any]:
    validate_semantic_metadata(record)
    matches = [row for row in record["parameters"] if row["parameter"] == parameter]
    if len(matches) != 1:
        raise SemanticMetadataError("parameter not found: %s" % parameter)
    return dict(matches[0])


def range_readiness(record: Mapping[str, Any], parameter: str) -> Dict[str, Any]:
    row = _find_parameter(record, parameter)
    required = ("semantic_type", "unit", "optimization_eligibility", "optimization_domain")
    missing = [name for name in required if row[name]["status"] != "PROVEN"]
    eligible = row["optimization_eligibility"].get("value") if not missing else None
    if missing:
        return {"status": "SEMANTICS_REQUIRED", "parameter": parameter, "missing": missing}
    if eligible is not True:
        return {"status": "NOT_ELIGIBLE", "parameter": parameter, "missing": []}
    return {"status": "READY", "parameter": parameter, "missing": []}
