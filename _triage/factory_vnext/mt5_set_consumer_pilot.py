# -*- coding: utf-8 -*-
"""Real-input MT5 set consumer pilot for Factory vNext SuperTrend rev05."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Any, Dict, Mapping, Optional

from .contracts import canonical_json, stable_id
from .mt5_set_compat import build_mt5_set_compat, render_proposed_set
from .semantic_metadata import build_supertrend_semantic_metadata, range_readiness
from .supertrend_adapter import PRESET_REL_PATH, load_supertrend_pilot
from .variant_generator import VariantGeneratorError, validate_variant_build_package


class MT5SetConsumerPilotError(ValueError):
    pass


SCHEMA_VERSION = "factory-vnext-mt5-set-consumer-pilot-v1"
AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"
_EXPECTED_FAMILY = "LEGACY-STF"
_EXPECTED_VARIANT = "LEGACY-STF-REV05"
_EXPECTED_VERSION = "rev05"


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _read_baseline(root: str) -> tuple[str, str]:
    path = Path(root).joinpath(*PRESET_REL_PATH.split("/"))
    raw = path.read_bytes()
    return raw.decode("utf-8-sig"), _sha256_bytes(raw)


def _readiness(meta: Mapping[str, Any]) -> Dict[str, Dict[str, Any]]:
    result: Dict[str, Dict[str, Any]] = {}
    for row in meta["parameters"]:
        name = row["parameter"]
        result[name] = range_readiness(meta, name)
    return result


def _validate_package_identity(package: Mapping[str, Any]) -> None:
    try:
        validate_variant_build_package(package)
    except VariantGeneratorError as exc:
        raise MT5SetConsumerPilotError(str(exc)) from exc
    expected = {
        "FamilyID": _EXPECTED_FAMILY,
        "VariantID": _EXPECTED_VARIANT,
        "StrategyVersion": _EXPECTED_VERSION,
    }
    for key, value in expected.items():
        if package.get(key) != value:
            raise MT5SetConsumerPilotError("package identity mismatch for %s" % key)


def _identity_payload(record: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        "schema_version": record["schema_version"],
        "authority": record["authority"],
        "ConceptID": record["ConceptID"],
        "StrategyVersion": record["StrategyVersion"],
        "LogicalSymbol": record["LogicalSymbol"],
        "ExecutionTF": record["ExecutionTF"],
        "ProfileID": record["ProfileID"],
        "BaselinePresetRef": record["BaselinePresetRef"],
        "SemanticMetadataID": record["SemanticMetadataID"],
        "KINT_001": record["KINT_001"],
        "PackageID": record["PackageID"],
        "status": record["status"],
        "consumer_stage": record["consumer_stage"],
        "adapter_invoked": record["adapter_invoked"],
        "refusal_reasons": record["refusal_reasons"],
        "compat_manifest": record["compat_manifest"],
        "proposed_output_sha256": record["proposed_output_sha256"],
    }


def build_supertrend_mt5_set_consumer_pilot(
    repo_root: str,
    *,
    package: Optional[Mapping[str, Any]] = None,
) -> Dict[str, Any]:
    root = os.path.abspath(repo_root)
    pilot = load_supertrend_pilot(root)
    meta = build_supertrend_semantic_metadata(root)
    readiness = _readiness(meta)
    baseline_text, baseline_file_sha256 = _read_baseline(root)
    if baseline_file_sha256 != pilot["PresetRef"]["sha256"]:
        raise MT5SetConsumerPilotError("baseline preset hash drift")

    semantics_required = sorted(
        name for name, row in readiness.items() if row["status"] == "SEMANTICS_REQUIRED"
    )
    proposed_set_text: Optional[str] = None
    compat_manifest: Optional[Dict[str, Any]] = None
    refusal_reasons: list[Dict[str, Any]] = []
    adapter_invoked = False
    package_id: Optional[str] = None

    if package is None:
        status = "REFUSED"
        consumer_stage = "PRE_ADAPTER_GATE"
        refusal_reasons.append({"code": "NO_CANONICAL_VARIANT_BUILD_PACKAGE"})
        if meta["KINT_001"] == {"state": "OPEN"}:
            refusal_reasons.append({"code": "KINT_001_OPEN"})
        if semantics_required:
            refusal_reasons.append({
                "code": "SEMANTICS_REQUIRED",
                "parameter_count": len(semantics_required),
                "parameters": semantics_required,
            })
    else:
        _validate_package_identity(package)
        package_id = str(package["PackageID"])
        semantic_states = {name: row["status"] for name, row in readiness.items()}
        result = build_mt5_set_compat(package, baseline_text, semantic_states)
        adapter_invoked = True
        compat_manifest = dict(result["manifest"])
        refusal_reasons.extend(dict(row) for row in result["refusal_rows"])
        unmapped = [row for row in result["operator_rows"] if row.get("disposition") == "UNMAPPED"]
        refusal_reasons.extend({
            "parameter": row["parameter"], "code": row.get("reason", "UNMAPPED")
        } for row in unmapped)

        if refusal_reasons or unmapped:
            status = "REFUSED"
            consumer_stage = "ADAPTER_GATE"
        else:
            proposed_set_text = render_proposed_set(result)
            status = "PROPOSED_SET_READY"
            consumer_stage = "PROPOSED_SET"

    record: Dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "authority": AUTHORITY,
        "ConceptID": pilot["ConceptID"],
        "StrategyVersion": pilot["StrategyVersion"],
        "LogicalSymbol": pilot["LogicalSymbol"],
        "ExecutionTF": pilot["ExecutionTF"],
        "ProfileID": pilot["ProfileID"],
        "BaselinePresetRef": dict(pilot["PresetRef"]),
        "SemanticMetadataID": meta["SemanticMetadataID"],
        "KINT_001": dict(meta["KINT_001"]),
        "PackageID": package_id,
        "status": status,
        "consumer_stage": consumer_stage,
        "adapter_invoked": adapter_invoked,
        "semantic_readiness": readiness,
        "refusal_reasons": refusal_reasons,
        "compat_manifest": compat_manifest,
        "proposed_output_sha256": (
            hashlib.sha256(proposed_set_text.encode("utf-8")).hexdigest()
            if proposed_set_text is not None else None
        ),
        "proposed_set_text": proposed_set_text,
        "mt5_terminal_touched": False,
        "strategy_tester_invoked": False,
    }
    record["ConsumerPilotID"] = stable_id("M5CON", _identity_payload(record), hex_chars=24)
    validate_mt5_set_consumer_pilot(record)
    return record


def validate_mt5_set_consumer_pilot(record: Mapping[str, Any]) -> None:
    if record.get("schema_version") != SCHEMA_VERSION:
        raise MT5SetConsumerPilotError("consumer schema_version mismatch")
    if record.get("authority") != AUTHORITY:
        raise MT5SetConsumerPilotError("consumer authority boundary is missing")
    if record.get("KINT_001") != {"state": "OPEN"}:
        raise MT5SetConsumerPilotError("KINT-001 must remain OPEN")
    if record.get("mt5_terminal_touched") is not False:
        raise MT5SetConsumerPilotError("consumer pilot must not touch MT5 terminal")
    if record.get("strategy_tester_invoked") is not False:
        raise MT5SetConsumerPilotError("consumer pilot must not invoke Strategy Tester")
    ref = record.get("BaselinePresetRef")
    if not isinstance(ref, Mapping) or not ref.get("path") or not ref.get("sha256"):
        raise MT5SetConsumerPilotError("BaselinePresetRef is required")
    readiness = record.get("semantic_readiness")
    if not isinstance(readiness, Mapping) or not readiness:
        raise MT5SetConsumerPilotError("semantic_readiness is required")
    status = record.get("status")
    if status not in ("REFUSED", "PROPOSED_SET_READY"):
        raise MT5SetConsumerPilotError("invalid consumer status")
    proposed = record.get("proposed_set_text")
    if status == "REFUSED" and proposed is not None:
        raise MT5SetConsumerPilotError("refused consumer must not contain proposed set")
    if status == "PROPOSED_SET_READY" and not isinstance(proposed, str):
        raise MT5SetConsumerPilotError("ready consumer requires proposed set text")
    if status == "REFUSED" and not record.get("refusal_reasons"):
        raise MT5SetConsumerPilotError("refused consumer requires refusal reasons")
    if record.get("ConceptID") != "(TRD)_SuperTrendFlip" or record.get("StrategyVersion") != _EXPECTED_VERSION:
        raise MT5SetConsumerPilotError("consumer strategy identity mismatch")
    if record.get("LogicalSymbol") != "BTCUSD" or record.get("ExecutionTF") != "H4":
        raise MT5SetConsumerPilotError("consumer Home identity mismatch")
    package_id = record.get("PackageID")
    stage = record.get("consumer_stage")
    adapter_invoked = record.get("adapter_invoked")
    if package_id is None:
        if stage != "PRE_ADAPTER_GATE" or adapter_invoked is not False:
            raise MT5SetConsumerPilotError("missing package must stop before adapter")
        codes = {row.get("code") for row in record.get("refusal_reasons", []) if isinstance(row, Mapping)}
        if "NO_CANONICAL_VARIANT_BUILD_PACKAGE" not in codes:
            raise MT5SetConsumerPilotError("missing package refusal evidence is required")
    else:
        if not isinstance(package_id, str) or not package_id:
            raise MT5SetConsumerPilotError("PackageID must be text")
        if adapter_invoked is not True:
            raise MT5SetConsumerPilotError("package consumer must invoke adapter")
    compat = record.get("compat_manifest")
    if adapter_invoked is False and compat is not None:
        raise MT5SetConsumerPilotError("pre-adapter refusal cannot contain compat manifest")
    digest = record.get("proposed_output_sha256")
    if proposed is None and digest is not None:
        raise MT5SetConsumerPilotError("missing proposed set cannot have output hash")
    if proposed is not None:
        expected_digest = hashlib.sha256(proposed.encode("utf-8")).hexdigest()
        if digest != expected_digest:
            raise MT5SetConsumerPilotError("proposed output hash mismatch")
    expected_id = stable_id("M5CON", _identity_payload(record), hex_chars=24)
    if record.get("ConsumerPilotID") != expected_id:
        raise MT5SetConsumerPilotError("ConsumerPilotID does not match immutable identity")


def serialize_consumer_pilot(record: Mapping[str, Any]) -> bytes:
    validate_mt5_set_consumer_pilot(record)
    return (canonical_json(dict(record)) + "\n").encode("utf-8")


def write_consumer_pilot(record: Mapping[str, Any], output_path: str) -> str:
    data = serialize_consumer_pilot(record)
    target = Path(output_path).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    return str(target)
