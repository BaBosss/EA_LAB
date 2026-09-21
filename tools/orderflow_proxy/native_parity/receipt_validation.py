#!/usr/bin/env python3
"""Validate source-bound native comparison inputs against an external trust root.

This module validates byte identities and cross-document bindings.  It does not
observe MetaTrader, authenticate a machine, or create controller authority.  A
caller must supply the SHA-256 of independently frozen controller evidence as
an out-of-band trust root.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping


MANIFEST_SCHEMA = "orderflow_proxy_native_fixture_package/v2"
RECEIPT_SCHEMA = "orderflow_proxy_native_execution_receipt/v1"
CONTROLLER_EVIDENCE_SCHEMA = "orderflow_proxy_native_controller_evidence/v1"
ACTUAL_SCOPE = "ACTUAL_NATIVE_EXECUTION"
FIXTURE_SCOPE = "FIXTURE_ONLY_INTEGRITY_CONTROL"
SHA256_RE = re.compile(r"[0-9a-f]{64}\Z")
HEAD_RE = re.compile(r"[0-9a-f]{40}\Z")

REQUIRED_BRIDGE_SOURCE_PATHS = (
    "docs/research/ORDERFLOW_PROXY_NATIVE_FIXTURE_PARITY_V1_20260920.md",
    "tools/orderflow_proxy/native_parity/OFPNativeFixtureParity.mq5",
    "tools/orderflow_proxy/native_parity/generate_native_fixture.py",
    "tools/orderflow_proxy/native_parity/parse_native_ledger.py",
    "tools/orderflow_proxy/native_parity/receipt_validation.py",
    "tools/orderflow_proxy/native_parity/test_native_parity.py",
)
REQUIRED_SOURCE_GRAPH_PATHS = (
    "tools/orderflow_proxy/offline_reference.py",
    "ea_template/components/orderflow_proxy/OrderFlowProxyTypes.mqh",
    "ea_template/components/orderflow_proxy/OrderFlowProxyValidation.mqh",
    "ea_template/components/orderflow_proxy/TickActivityProfile.mqh",
    "ea_template/components/orderflow_proxy/OFPRReversal.mqh",
    "ea_template/components/orderflow_proxy/OFPCContinuation.mqh",
    "ea_template/components/orderflow_proxy/OrderFlowProxyComponents.mqh",
)
GENERATED_OUTPUT_PATHS = (
    "tools/orderflow_proxy/native_parity/generated/NativeFixtureData.mqh",
    "tools/orderflow_proxy/native_parity/generated/expected_python_ledger.json",
    "tools/orderflow_proxy/native_parity/generated/runtime_request.NOT_EXECUTED.json",
)


class ReceiptValidationError(ValueError):
    pass


@dataclass(frozen=True)
class ValidatedControllerReceipt:
    evidence_scope: str
    controller_evidence_id: str
    bridge_source_head: str
    runtime_contract_id: str
    fixture_sha256: str
    source_graph_sha256: str
    receipt_sha256: str
    controller_evidence_sha256: str


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _pairs_no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ReceiptValidationError(f"DUPLICATE_JSON_KEY:{key}")
        result[key] = value
    return result


def load_strict_json(value: bytes, label: str) -> dict[str, Any]:
    try:
        decoded = value.decode("utf-8", errors="strict")
        parsed = json.loads(decoded, object_pairs_hook=_pairs_no_duplicates)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ReceiptValidationError(f"MALFORMED_{label}_JSON:{error}") from error
    if type(parsed) is not dict:
        raise ReceiptValidationError(f"INVALID_{label}_TYPE")
    return parsed


def _require_exact_keys(value: Mapping[str, Any], expected: set[str], label: str) -> None:
    if set(value) != expected:
        raise ReceiptValidationError(f"INVALID_{label}_FIELDS")


def _require_string(value: Any, label: str) -> str:
    if type(value) is not str or not value:
        raise ReceiptValidationError(f"INVALID_{label}_TYPE")
    return value


def _require_int(value: Any, label: str) -> int:
    if type(value) is not int or value < 0:
        raise ReceiptValidationError(f"INVALID_{label}_TYPE")
    return value


def _require_sha256(value: Any, label: str) -> str:
    candidate = _require_string(value, label)
    if SHA256_RE.fullmatch(candidate) is None:
        raise ReceiptValidationError(f"INVALID_{label}")
    return candidate


def _require_head(value: Any, label: str) -> str:
    candidate = _require_string(value, label)
    if HEAD_RE.fullmatch(candidate) is None:
        raise ReceiptValidationError(f"INVALID_{label}")
    return candidate


def artifact_binding(path: str, identity: str, data: bytes) -> dict[str, Any]:
    """Build a deterministic binding for fixture-only tests and controller tooling."""

    return {
        "path": path,
        "identity": identity,
        "bytes": len(data),
        "sha256": sha256_bytes(data),
    }


def _validate_artifact_binding(
    binding: Any,
    data: bytes,
    label: str,
    *,
    required_path: str | None = None,
) -> dict[str, Any]:
    if type(binding) is not dict:
        raise ReceiptValidationError(f"INVALID_{label}_BINDING_TYPE")
    _require_exact_keys(binding, {"path", "identity", "bytes", "sha256"}, f"{label}_BINDING")
    path = _require_string(binding["path"], f"{label}_PATH")
    _require_string(binding["identity"], f"{label}_IDENTITY")
    expected_bytes = _require_int(binding["bytes"], f"{label}_BYTES")
    expected_sha256 = _require_sha256(binding["sha256"], f"{label}_SHA256")
    if required_path is not None and path != required_path:
        raise ReceiptValidationError(f"{label}_PATH_MISMATCH")
    if expected_bytes != len(data):
        raise ReceiptValidationError(f"{label}_BYTES_MISMATCH")
    if expected_sha256 != sha256_bytes(data):
        raise ReceiptValidationError(f"{label}_SHA256_MISMATCH")
    return dict(binding)


def _validate_manifest_artifact(
    binding: Any, data: bytes, label: str, *, required_path: str
) -> dict[str, Any]:
    if type(binding) is not dict:
        raise ReceiptValidationError(f"INVALID_{label}_BINDING_TYPE")
    _require_exact_keys(binding, {"path", "bytes", "sha256"}, f"{label}_BINDING")
    if _require_string(binding["path"], f"{label}_PATH") != required_path:
        raise ReceiptValidationError(f"{label}_PATH_MISMATCH")
    if _require_int(binding["bytes"], f"{label}_BYTES") != len(data):
        raise ReceiptValidationError(f"{label}_BYTES_MISMATCH")
    if _require_sha256(binding["sha256"], f"{label}_SHA256") != sha256_bytes(data):
        raise ReceiptValidationError(f"{label}_SHA256_MISMATCH")
    return dict(binding)


def _read_repo_file(repository_root: Path, relative: str, label: str) -> bytes:
    path = repository_root / Path(relative)
    try:
        return path.read_bytes()
    except OSError as error:
        raise ReceiptValidationError(f"MISSING_{label}:{relative}") from error


def _validate_source_rows(
    rows: Any,
    repository_root: Path,
    expected_paths: tuple[str, ...],
    label: str,
) -> list[dict[str, Any]]:
    if type(rows) is not list or len(rows) != len(expected_paths):
        raise ReceiptValidationError(f"INVALID_{label}_COUNT")
    if [row.get("path") if type(row) is dict else None for row in rows] != list(expected_paths):
        raise ReceiptValidationError(f"INVALID_{label}_PATHS")
    validated: list[dict[str, Any]] = []
    for index, (row, relative) in enumerate(zip(rows, expected_paths, strict=True)):
        data = _read_repo_file(repository_root, relative, label)
        if type(row) is not dict:
            raise ReceiptValidationError(f"INVALID_{label}_ROW_TYPE:{index}")
        _require_exact_keys(row, {"path", "bytes", "sha256"}, f"{label}_ROW")
        _validate_manifest_artifact(row, data, f"{label}_{index}", required_path=relative)
        validated.append(dict(row))
    return validated


def _source_graph_hash(rows: list[dict[str, Any]]) -> str:
    binding = b"".join(
        f"{row['path']}\0{row['bytes']}\0{row['sha256']}\n".encode("utf-8") for row in rows
    )
    return sha256_bytes(binding)


def validate_package_manifest(
    manifest_bytes: bytes,
    *,
    repository_root: Path,
    generated_include_bytes: bytes,
    expected_ledger_bytes: bytes,
    runtime_request_bytes: bytes,
) -> dict[str, Any]:
    manifest = load_strict_json(manifest_bytes, "PACKAGE_MANIFEST")
    _require_exact_keys(
        manifest,
        {
            "schema",
            "classification",
            "execution_status",
            "fixture",
            "source_graph",
            "case_count",
            "variant_counts",
            "generated_outputs",
            "manifest_self_exclusion",
            "bridge_sources",
        },
        "PACKAGE_MANIFEST",
    )
    if manifest["schema"] != MANIFEST_SCHEMA:
        raise ReceiptValidationError("INVALID_PACKAGE_MANIFEST_SCHEMA")
    if manifest["classification"] != "SOURCE_ONLY_SYNTHETIC_FIXTURE_PARITY_PREPARATION":
        raise ReceiptValidationError("INVALID_PACKAGE_MANIFEST_CLASSIFICATION")
    if manifest["execution_status"] != "NOT_EXECUTED":
        raise ReceiptValidationError("INVALID_PACKAGE_EXECUTION_STATUS")
    if type(manifest["case_count"]) is not int or manifest["case_count"] != 24:
        raise ReceiptValidationError("INVALID_PACKAGE_CASE_COUNT")
    expected_variant_counts = {
        variant: 4
        for variant in ("OFPC-00", "OFPC-01", "OFPC-02", "OFPR-00", "OFPR-01", "OFPR-02")
    }
    if manifest["variant_counts"] != expected_variant_counts:
        raise ReceiptValidationError("INVALID_PACKAGE_VARIANT_COUNTS")
    if manifest["manifest_self_exclusion"] != {
        "excluded": True,
        "reason": "SELF_HASH_RECURSION",
    }:
        raise ReceiptValidationError("INVALID_MANIFEST_SELF_EXCLUSION")

    fixture_path = "tools/orderflow_proxy/fixtures/mirrored_cases.json"
    fixture_bytes = _read_repo_file(repository_root, fixture_path, "FIXTURE")
    _validate_manifest_artifact(
        manifest["fixture"], fixture_bytes, "FIXTURE", required_path=fixture_path
    )

    source_graph = manifest["source_graph"]
    if type(source_graph) is not dict:
        raise ReceiptValidationError("INVALID_SOURCE_GRAPH_TYPE")
    _require_exact_keys(source_graph, {"sha256", "files"}, "SOURCE_GRAPH")
    source_rows_raw = source_graph["files"]
    if type(source_rows_raw) is not list:
        raise ReceiptValidationError("INVALID_SOURCE_GRAPH_FILES_TYPE")
    source_rows = _validate_source_rows(
        source_rows_raw, repository_root, REQUIRED_SOURCE_GRAPH_PATHS, "SOURCE_GRAPH_FILES"
    )
    if _require_sha256(source_graph["sha256"], "SOURCE_GRAPH_SHA256") != _source_graph_hash(source_rows):
        raise ReceiptValidationError("SOURCE_GRAPH_SHA256_MISMATCH")

    _validate_source_rows(
        manifest["bridge_sources"],
        repository_root,
        REQUIRED_BRIDGE_SOURCE_PATHS,
        "BRIDGE_SOURCES",
    )

    outputs = manifest["generated_outputs"]
    if type(outputs) is not list or len(outputs) != len(GENERATED_OUTPUT_PATHS):
        raise ReceiptValidationError("INVALID_GENERATED_OUTPUT_COUNT")
    expected_data = {
        GENERATED_OUTPUT_PATHS[0]: generated_include_bytes,
        GENERATED_OUTPUT_PATHS[1]: expected_ledger_bytes,
        GENERATED_OUTPUT_PATHS[2]: runtime_request_bytes,
    }
    if [row.get("path") if type(row) is dict else None for row in outputs] != list(
        GENERATED_OUTPUT_PATHS
    ):
        raise ReceiptValidationError("INVALID_GENERATED_OUTPUT_PATHS")
    for index, row in enumerate(outputs):
        path = GENERATED_OUTPUT_PATHS[index]
        _validate_manifest_artifact(
            row, expected_data[path], f"GENERATED_OUTPUT_{index}", required_path=path
        )
    return manifest


def validate_controller_receipt(
    *,
    manifest_bytes: bytes,
    expected_ledger_bytes: bytes,
    generated_include_bytes: bytes,
    runtime_request_bytes: bytes,
    ea_source_bytes: bytes,
    ex5_bytes: bytes,
    terminal_config_bytes: bytes,
    tester_config_bytes: bytes,
    native_journal_bytes: bytes,
    receipt_bytes: bytes,
    controller_evidence_bytes: bytes,
    expected_controller_evidence_sha256: str,
    repository_root: Path,
) -> ValidatedControllerReceipt:
    """Validate all supplied bytes against a separately pinned controller root."""

    expected_controller_sha = _require_sha256(
        expected_controller_evidence_sha256, "EXPECTED_CONTROLLER_EVIDENCE_SHA256"
    )
    actual_controller_sha = sha256_bytes(controller_evidence_bytes)
    if actual_controller_sha != expected_controller_sha:
        raise ReceiptValidationError("CONTROLLER_EVIDENCE_SHA256_MISMATCH")

    evidence = load_strict_json(controller_evidence_bytes, "CONTROLLER_EVIDENCE")
    _require_exact_keys(
        evidence,
        {
            "schema",
            "classification",
            "evidence_scope",
            "controller_evidence_id",
            "reviewed_bridge_source_head",
            "runtime_contract_id",
            "receipt",
            "package_manifest_sha256",
        },
        "CONTROLLER_EVIDENCE",
    )
    if evidence["schema"] != CONTROLLER_EVIDENCE_SCHEMA:
        raise ReceiptValidationError("INVALID_CONTROLLER_EVIDENCE_SCHEMA")
    if evidence["classification"] != "INDEPENDENT_FROZEN_CONTROLLER_EVIDENCE":
        raise ReceiptValidationError("INVALID_CONTROLLER_EVIDENCE_CLASSIFICATION")
    scope = evidence["evidence_scope"]
    if scope not in {ACTUAL_SCOPE, FIXTURE_SCOPE}:
        raise ReceiptValidationError("INVALID_CONTROLLER_EVIDENCE_SCOPE")
    evidence_id = _require_string(evidence["controller_evidence_id"], "CONTROLLER_EVIDENCE_ID")
    evidence_head = _require_head(
        evidence["reviewed_bridge_source_head"], "REVIEWED_BRIDGE_SOURCE_HEAD"
    )
    evidence_runtime_id = _require_string(
        evidence["runtime_contract_id"], "CONTROLLER_RUNTIME_CONTRACT_ID"
    )
    if _require_sha256(
        evidence["package_manifest_sha256"], "CONTROLLER_PACKAGE_MANIFEST_SHA256"
    ) != sha256_bytes(manifest_bytes):
        raise ReceiptValidationError("CONTROLLER_PACKAGE_MANIFEST_SHA256_MISMATCH")
    receipt_pin = evidence["receipt"]
    if type(receipt_pin) is not dict:
        raise ReceiptValidationError("INVALID_CONTROLLER_RECEIPT_PIN_TYPE")
    _require_exact_keys(receipt_pin, {"bytes", "sha256"}, "CONTROLLER_RECEIPT_PIN")
    if _require_int(receipt_pin["bytes"], "CONTROLLER_RECEIPT_BYTES") != len(receipt_bytes):
        raise ReceiptValidationError("CONTROLLER_RECEIPT_BYTES_MISMATCH")
    receipt_sha = sha256_bytes(receipt_bytes)
    if _require_sha256(receipt_pin["sha256"], "CONTROLLER_RECEIPT_SHA256") != receipt_sha:
        raise ReceiptValidationError("CONTROLLER_RECEIPT_SHA256_MISMATCH")

    manifest = validate_package_manifest(
        manifest_bytes,
        repository_root=repository_root,
        generated_include_bytes=generated_include_bytes,
        expected_ledger_bytes=expected_ledger_bytes,
        runtime_request_bytes=runtime_request_bytes,
    )
    receipt = load_strict_json(receipt_bytes, "CONTROLLER_RECEIPT")
    _require_exact_keys(
        receipt,
        {
            "schema",
            "classification",
            "bridge_source_head",
            "runtime_contract_id",
            "terminal_configuration",
            "tester_configuration",
            "ea_source",
            "ex5",
            "generated_include",
            "expected_ledger",
            "source_graph_sha256",
            "fixture_sha256",
            "package_manifest",
            "native_journal",
        },
        "CONTROLLER_RECEIPT",
    )
    if receipt["schema"] != RECEIPT_SCHEMA:
        raise ReceiptValidationError("INVALID_CONTROLLER_RECEIPT_SCHEMA")
    if receipt["classification"] != "TRUSTED_CONTROLLER_SAFE_RUNNER_RECEIPT":
        raise ReceiptValidationError("INVALID_CONTROLLER_RECEIPT_CLASSIFICATION")
    receipt_head = _require_head(receipt["bridge_source_head"], "RECEIPT_BRIDGE_SOURCE_HEAD")
    runtime_contract_id = _require_string(receipt["runtime_contract_id"], "RUNTIME_CONTRACT_ID")
    if runtime_contract_id in {"NOT_EXECUTED_UNFROZEN", "UNKNOWN", "GENERATED"} or not runtime_contract_id.startswith(
        "OFP-NATIVE-FIXTURE-"
    ):
        raise ReceiptValidationError("UNKNOWN_OR_UNFROZEN_RUNTIME_CONTRACT_ID")

    fixed_paths = {
        "ea_source": "tools/orderflow_proxy/native_parity/OFPNativeFixtureParity.mq5",
        "generated_include": GENERATED_OUTPUT_PATHS[0],
        "expected_ledger": GENERATED_OUTPUT_PATHS[1],
        "package_manifest": "tools/orderflow_proxy/native_parity/generated/manifest.json",
    }
    supplied = {
        "terminal_configuration": terminal_config_bytes,
        "tester_configuration": tester_config_bytes,
        "ea_source": ea_source_bytes,
        "ex5": ex5_bytes,
        "generated_include": generated_include_bytes,
        "expected_ledger": expected_ledger_bytes,
        "package_manifest": manifest_bytes,
        "native_journal": native_journal_bytes,
    }
    for label, data in supplied.items():
        _validate_artifact_binding(
            receipt[label],
            data,
            label.upper(),
            required_path=fixed_paths.get(label),
        )

    manifest_fixture = manifest["fixture"]["sha256"]
    manifest_source_graph = manifest["source_graph"]["sha256"]
    if _require_sha256(receipt["fixture_sha256"], "RECEIPT_FIXTURE_SHA256") != manifest_fixture:
        raise ReceiptValidationError("RECEIPT_FIXTURE_SHA256_MISMATCH")
    if (
        _require_sha256(receipt["source_graph_sha256"], "RECEIPT_SOURCE_GRAPH_SHA256")
        != manifest_source_graph
    ):
        raise ReceiptValidationError("RECEIPT_SOURCE_GRAPH_SHA256_MISMATCH")

    if evidence_head != receipt_head:
        raise ReceiptValidationError("BRIDGE_SOURCE_HEAD_MISMATCH")
    if evidence_runtime_id != runtime_contract_id:
        raise ReceiptValidationError("RUNTIME_CONTRACT_ID_MISMATCH")

    return ValidatedControllerReceipt(
        evidence_scope=scope,
        controller_evidence_id=evidence_id,
        bridge_source_head=receipt_head,
        runtime_contract_id=runtime_contract_id,
        fixture_sha256=manifest_fixture,
        source_graph_sha256=manifest_source_graph,
        receipt_sha256=receipt_sha,
        controller_evidence_sha256=actual_controller_sha,
    )
