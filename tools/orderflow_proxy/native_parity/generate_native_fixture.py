#!/usr/bin/env python3
"""Generate the frozen synthetic OFP Python/MQL fixture parity package.

This module deliberately imports the accepted Python reference and calls its
fixture expander and evaluator.  It does not implement another OFP engine.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
from collections import Counter
from pathlib import Path
from typing import Any


SCHEMA = "orderflow_proxy_native_fixture_package/v2"
LEDGER_SCHEMA = "orderflow_proxy_native_expected_ledger/v1"
RUNTIME_SCHEMA = "orderflow_proxy_native_runtime_request/v1"
FLOAT_DECIMAL_PLACES = 12
EXPECTED_CASE_COUNT = 24
EXPECTED_VARIANTS = (
    "OFPR-00",
    "OFPR-01",
    "OFPR-02",
    "OFPC-00",
    "OFPC-01",
    "OFPC-02",
)

REPO_ROOT = Path(__file__).resolve().parents[3]
FIXTURE_PATH = REPO_ROOT / "tools/orderflow_proxy/fixtures/mirrored_cases.json"
REFERENCE_PATH = REPO_ROOT / "tools/orderflow_proxy/offline_reference.py"
SOURCE_GRAPH_PATHS = (
    "tools/orderflow_proxy/offline_reference.py",
    "ea_template/components/orderflow_proxy/OrderFlowProxyTypes.mqh",
    "ea_template/components/orderflow_proxy/OrderFlowProxyValidation.mqh",
    "ea_template/components/orderflow_proxy/TickActivityProfile.mqh",
    "ea_template/components/orderflow_proxy/OFPRReversal.mqh",
    "ea_template/components/orderflow_proxy/OFPCContinuation.mqh",
    "ea_template/components/orderflow_proxy/OrderFlowProxyComponents.mqh",
)
BRIDGE_SOURCE_PATHS = (
    "docs/research/ORDERFLOW_PROXY_NATIVE_FIXTURE_PARITY_V1_20260920.md",
    "tools/orderflow_proxy/native_parity/OFPNativeFixtureParity.mq5",
    "tools/orderflow_proxy/native_parity/generate_native_fixture.py",
    "tools/orderflow_proxy/native_parity/parse_native_ledger.py",
    "tools/orderflow_proxy/native_parity/receipt_validation.py",
    "tools/orderflow_proxy/native_parity/test_native_parity.py",
)
DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent / "generated"


def _load_reference() -> Any:
    spec = importlib.util.spec_from_file_location("ofp_accepted_offline_reference", REFERENCE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("ACCEPTED_REFERENCE_IMPORT_FAILED")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _canonical_json(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True) + "\n").encode("utf-8")


def _source_graph() -> tuple[list[dict[str, Any]], str]:
    rows: list[dict[str, Any]] = []
    for relative in SOURCE_GRAPH_PATHS:
        data = (REPO_ROOT / relative).read_bytes()
        rows.append({"path": relative, "bytes": len(data), "sha256": _sha256_bytes(data)})
    binding = b"".join(
        f"{row['path']}\0{row['bytes']}\0{row['sha256']}\n".encode("utf-8") for row in rows
    )
    return rows, _sha256_bytes(binding)


def _file_rows(paths: tuple[str, ...]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for relative in paths:
        data = (REPO_ROOT / relative).read_bytes()
        rows.append({"path": relative, "bytes": len(data), "sha256": _sha256_bytes(data)})
    return rows


def _output_binding(relative: str, data: bytes) -> dict[str, Any]:
    return {"path": relative, "bytes": len(data), "sha256": _sha256_bytes(data)}


def _mql_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _mql_float(value: Any) -> str:
    number = float(value)
    if not math.isfinite(number):
        raise ValueError("NON_FINITE_FIXTURE_NUMBER")
    return format(number, ".17g")


def _fixed_float(value: Any) -> str:
    return format(float(value), f".{FLOAT_DECIMAL_PLACES}f")


def _variant_enum(variant: str) -> str:
    return {
        "OFPR-00": "OFPR_00_PROFILE_PRICE_CONTROL",
        "OFPR-01": "OFPR_01_TICK_ACTIVITY",
        "OFPR-02": "OFPR_02_QUOTE_IMBALANCE",
        "OFPC-00": "OFPC_00_PROFILE_PRICE_CONTROL",
        "OFPC-01": "OFPC_01_TICK_ACTIVITY",
        "OFPC-02": "OFPC_02_QUOTE_IMBALANCE",
    }[variant]


def _validate_descriptors(package: dict[str, Any]) -> list[dict[str, Any]]:
    if package.get("schema") != "orderflow_proxy_fixture/v1":
        raise ValueError("INVALID_ACCEPTED_FIXTURE_SCHEMA")
    if package.get("record_class") != "FIXTURE":
        raise ValueError("INVALID_ACCEPTED_FIXTURE_CLASS")
    cases = package.get("cases")
    if not isinstance(cases, list) or len(cases) != EXPECTED_CASE_COUNT:
        raise ValueError("EXPECTED_EXACTLY_24_ACCEPTED_CASES")
    ids = [case.get("id") for case in cases]
    if any(not isinstance(case_id, str) or not case_id for case_id in ids) or len(set(ids)) != len(ids):
        raise ValueError("INVALID_OR_DUPLICATE_ACCEPTED_CASE_ID")
    counts = Counter(case.get("variant") for case in cases)
    if counts != Counter({variant: 4 for variant in EXPECTED_VARIANTS}):
        raise ValueError("EXPECTED_SIX_VARIANTS_FOUR_CASES_EACH")
    expected_matrix = {
        (variant, direction, scenario)
        for variant in EXPECTED_VARIANTS
        for direction in ("long", "short")
        for scenario in ("positive", "gate_negative")
    }
    actual_matrix = {(case.get("variant"), case.get("direction"), case.get("scenario")) for case in cases}
    if actual_matrix != expected_matrix:
        raise ValueError("MIRRORED_POSITIVE_NEGATIVE_MATRIX_MISMATCH")
    for case in cases:
        expected = "SIGNAL" if case["scenario"] == "positive" else "NO_SIGNAL"
        if case.get("expected_status") != expected:
            raise ValueError("ACCEPTED_EXPECTED_STATUS_MISMATCH")
    return cases


def _quote_counts(reference: Any, bar: dict[str, Any]) -> dict[str, int]:
    mids = [(float(tick["bid"]) + float(tick["ask"])) * 0.5 for tick in bar["quote_ticks"]]
    result = reference.quote_direction_imbalance(mids)
    return {
        "up": int(result["up_count"]),
        "down": int(result["down_count"]),
        "unchanged": int(result["unchanged_count"]),
    }


def _normalized_expected(
    descriptor: dict[str, Any], case: dict[str, Any], result: dict[str, Any]
) -> dict[str, Any]:
    geometry = result.get("geometry") if isinstance(result.get("geometry"), dict) else {}
    return {
        "case_id": descriptor["id"],
        "variant": descriptor["variant"],
        "descriptor_direction": descriptor["direction"],
        "scenario": descriptor["scenario"],
        "status": result["status"],
        "direction": int(geometry.get("direction", 0)),
        "current_closed_bar_record_id": case["bars"][-1]["record_id"],
        "setup_time": int(geometry.get("setup_time", 0)),
        "trigger_time": int(geometry.get("trigger_time", 0)),
        "prospective_entry": _fixed_float(geometry.get("prospective_entry", 0.0)),
        "stop_price": _fixed_float(geometry.get("stop_price", 0.0)),
        "target_price": _fixed_float(geometry.get("target_price", 0.0)),
        "net_rr": _fixed_float(geometry.get("net_rr", 0.0)),
        "data_identity": result["data_identity"],
        "profile_identity": result["profile_identity"],
        "imbalance_identity": result["imbalance_identity"],
    }


def _assign(lines: list[str], target: str, field: str, value: Any, *, kind: str = "string") -> None:
    if kind == "string":
        rendered = _mql_string(str(value))
    elif kind == "float":
        rendered = _mql_float(value)
    elif kind == "bool":
        rendered = "true" if bool(value) else "false"
    else:
        rendered = str(int(value))
    lines.append(f"         {target}.{field} = {rendered};")


def _emit_case(reference: Any, index: int, descriptor: dict[str, Any], case: dict[str, Any]) -> list[str]:
    lines = [f"      case {index}:", "      {"]
    _assign(lines, "meta", "case_id", descriptor["id"])
    _assign(lines, "meta", "variant_name", descriptor["variant"])
    _assign(lines, "meta", "descriptor_direction", descriptor["direction"])
    _assign(lines, "meta", "scenario", descriptor["scenario"])
    _assign(lines, "meta", "expected_status", descriptor["expected_status"])
    lines.append(f"         meta.variant = {_variant_enum(descriptor['variant'])};")

    labels = case["labels"]
    for field, source in (
        ("data_identity", "data_identity"),
        ("profile_identity", "profile_identity"),
        ("imbalance_identity", "imbalance_identity"),
        ("signal_instrument_id", "signal_instrument_id"),
        ("signal_source_id", "signal_source_id"),
    ):
        _assign(lines, "contract", field, labels[source])
    lines.append("         contract.profile_recipe_id = OFP_PROFILE_RECIPE_ID;")
    lines.append("         contract.session_id = OFP_SESSION_ID;")

    profile = case["profile"]
    for field in (
        "record_id",
        "instrument_id",
        "source_id",
        "previous_d1_record_id",
        "current_d1_record_id",
    ):
        _assign(lines, "profile", field, profile[field])
    lines.append("         profile.profile_identity = OFP_PROFILE_IDENTITY;")
    lines.append("         profile.profile_recipe_id = OFP_PROFILE_RECIPE_ID;")
    lines.append("         profile.session_id = OFP_SESSION_ID;")
    for field in (
        "previous_d1_sequence",
        "previous_d1_open_time",
        "current_d1_sequence",
        "current_d1_open_time",
        "session_start",
        "session_end",
        "available_at",
    ):
        _assign(lines, "profile", field, profile[field], kind="int")
    _assign(lines, "profile", "completed", profile["completed"], kind="bool")
    for field in ("val", "poc", "vah"):
        _assign(lines, "profile", field, profile[field], kind="float")
    # The accepted Python fixture supplies a frozen [VAL, POC, VAH] profile,
    # not raw D1 profile ticks.  These carrier fields are the unique coherent
    # one-bin representation of [100, 105, 110] and do not alter replay logic.
    profile_width = float(profile["vah"]) - float(profile["val"])
    if profile_width <= 0.0 or abs(float(profile["poc"]) - (float(profile["val"]) + profile_width / 2.0)) > 1e-12:
        raise ValueError("FIXTURE_PROFILE_NOT_ONE_BIN_REPRESENTABLE")
    base_index = int(round(float(profile["val"]) / profile_width))
    _assign(lines, "profile", "bin_size", profile_width, kind="float")
    _assign(lines, "profile", "bin_size_source", "SYNTHETIC_FIXTURE_EXPLICIT")
    _assign(lines, "profile", "poc_bin_index", base_index, kind="int")
    _assign(lines, "profile", "val_bin_index", base_index, kind="int")
    _assign(lines, "profile", "vah_outer_bin_index", base_index, kind="int")
    _assign(lines, "profile", "total_activity", 1, kind="int")
    _assign(lines, "profile", "value_area_activity", 1, kind="int")

    contexts = case["contexts"]
    lines.append(f"         ArrayResize(contexts, {len(contexts)});")
    for context_index, context in enumerate(contexts):
        target = f"contexts[{context_index}]"
        for field in ("record_id", "instrument_id", "source_id", "d1_record_id"):
            _assign(lines, target, field, context[field])
        _assign(lines, target, "d1_sequence", context["d1_sequence"], kind="int")
        _assign(lines, target, "d1_open_time", context["d1_open_time"], kind="int")
        _assign(lines, target, "sequence", context_index + 1, kind="int")
        for field in ("period_seconds", "open_time", "close_time", "available_at"):
            _assign(lines, target, field, context[field], kind="int")
        _assign(lines, target, "completed", context["completed"], kind="bool")
        _assign(lines, target, "close", context["close"], kind="float")

    bars = case["bars"]
    lines.append(f"         ArrayResize(bars, {len(bars)});")
    for bar_index, bar in enumerate(bars):
        target = f"bars[{bar_index}]"
        for field in ("record_id", "instrument_id", "source_id", "d1_record_id"):
            _assign(lines, target, field, bar[field])
        _assign(lines, target, "d1_sequence", bar["d1_sequence"], kind="int")
        _assign(lines, target, "d1_open_time", bar["d1_open_time"], kind="int")
        _assign(lines, target, "sequence", bar_index + 1, kind="int")
        for field in ("period_seconds", "open_time", "close_time", "available_at"):
            _assign(lines, target, field, bar[field], kind="int")
        _assign(lines, target, "completed", bar["completed"], kind="bool")
        for field in ("open", "high", "low", "close"):
            _assign(lines, target, field, bar[field], kind="float")
        _assign(lines, target, "tick_volume", bar["tick_volume"], kind="int")
        counts = _quote_counts(reference, bar)
        _assign(lines, target, "quote_up_count", counts["up"], kind="int")
        _assign(lines, target, "quote_down_count", counts["down"], kind="int")
        _assign(lines, target, "quote_unchanged_count", counts["unchanged"], kind="int")
        _assign(lines, target, "quote_proxy_valid", True, kind="bool")

    quote = case["quote"]
    for field in ("record_id", "instrument_id", "source_id", "d1_record_id"):
        _assign(lines, "quote", field, quote[field])
    for field in ("d1_sequence", "d1_open_time", "observed_at", "available_at"):
        _assign(lines, "quote", field, quote[field], kind="int")
    for field in ("bid", "ask", "all_in_cost_price"):
        _assign(lines, "quote", field, quote[field], kind="float")

    _assign(lines, "envelope", "evaluation_time", case["evaluation_time"], kind="int")
    _assign(lines, "envelope", "current_closed_bar_record_id", bars[-1]["record_id"])
    _assign(lines, "envelope", "current_closed_bar_close_time", bars[-1]["close_time"], kind="int")
    lines.extend(("         return true;", "      }"))
    return lines


def _render_mql_include(
    reference: Any,
    descriptors: list[dict[str, Any]],
    expanded_cases: list[dict[str, Any]],
    fixture_sha256: str,
    source_graph_sha256: str,
) -> bytes:
    lines = [
        "// GENERATED FILE. Run generate_native_fixture.py; do not hand-edit.",
        "#ifndef EA_LAB_OFP_NATIVE_FIXTURE_DATA_MQH",
        "#define EA_LAB_OFP_NATIVE_FIXTURE_DATA_MQH",
        "",
        f"const int OFP_NATIVE_FIXTURE_CASE_COUNT = {EXPECTED_CASE_COUNT};",
        f"const int OFP_NATIVE_FLOAT_DECIMAL_PLACES = {FLOAT_DECIMAL_PLACES};",
        f"const string OFP_NATIVE_FIXTURE_SHA256 = {_mql_string(fixture_sha256)};",
        f"const string OFP_NATIVE_SOURCE_GRAPH_SHA256 = {_mql_string(source_graph_sha256)};",
        "const string OFP_NATIVE_RUN_CLASS = \"SYNTHETIC_FIXTURE\";",
        "",
        "struct OFPNativeFixtureMeta",
        "{",
        "   string case_id;",
        "   string variant_name;",
        "   string descriptor_direction;",
        "   string scenario;",
        "   string expected_status;",
        "   ENUM_OFP_VARIANT variant;",
        "};",
        "",
        "bool OFP_LoadNativeFixtureCase(const int case_index,",
        "                               OFPNativeFixtureMeta &meta,",
        "                               OFPDataContract &contract,",
        "                               OFPProfile &profile,",
        "                               OFPContextBar &contexts[],",
        "                               OFPBar &bars[],",
        "                               OFPProspectiveQuote &quote,",
        "                               OFPDecisionEnvelope &envelope)",
        "{",
        "   if(case_index < 0 || case_index >= OFP_NATIVE_FIXTURE_CASE_COUNT)",
        "      return false;",
        "   ArrayResize(contexts, 0);",
        "   ArrayResize(bars, 0);",
        "   switch(case_index)",
        "   {",
    ]
    for index, (descriptor, case) in enumerate(zip(descriptors, expanded_cases, strict=True)):
        lines.extend(_emit_case(reference, index, descriptor, case))
    lines.extend(
        (
            "   }",
            "   return false;",
            "}",
            "",
            "#endif // EA_LAB_OFP_NATIVE_FIXTURE_DATA_MQH",
            "",
        )
    )
    return "\n".join(lines).encode("utf-8")


def build_outputs() -> dict[str, bytes]:
    reference = _load_reference()
    fixture_bytes = FIXTURE_PATH.read_bytes()
    fixture_sha256 = _sha256_bytes(fixture_bytes)
    package = json.loads(fixture_bytes.decode("utf-8"))
    descriptors = _validate_descriptors(package)
    source_rows, source_graph_sha256 = _source_graph()
    expanded_cases: list[dict[str, Any]] = []
    expected_cases: list[dict[str, Any]] = []
    for descriptor in descriptors:
        case = reference._expand_fixture_descriptor(descriptor)
        result = reference.evaluate_variant(case)
        if result["status"] != descriptor["expected_status"]:
            raise ValueError(f"ACCEPTED_REFERENCE_OUTCOME_MISMATCH:{descriptor['id']}")
        expanded_cases.append(case)
        expected_cases.append(_normalized_expected(descriptor, case, result))

    ledger = {
        "schema": LEDGER_SCHEMA,
        "classification": "EXPECTED_PYTHON_SYNTHETIC_FIXTURE_LEDGER",
        "record_class": "SYNTHETIC_FIXTURE",
        "case_count": EXPECTED_CASE_COUNT,
        "float_comparison": {
            "method": "EXACT_FIXED_DECIMAL_STRING",
            "decimal_places": FLOAT_DECIMAL_PLACES,
            "tolerance": None,
        },
        "fixture": {
            "path": FIXTURE_PATH.relative_to(REPO_ROOT).as_posix(),
            "bytes": len(fixture_bytes),
            "sha256": fixture_sha256,
        },
        "source_graph": {"sha256": source_graph_sha256, "files": source_rows},
        "variant_counts": dict(sorted(Counter(row["variant"] for row in expected_cases).items())),
        "cases": expected_cases,
    }
    runtime_request = {
        "schema": RUNTIME_SCHEMA,
        "classification": "SYNTHETIC_FIXTURE_DIAGNOSTIC_REQUEST_ONLY",
        "execution_status": "NOT_EXECUTED",
        "runtime_contract_id": "NOT_EXECUTED_UNFROZEN",
        "requested_lane": "MT5_PRIMARY_EXCLUSIVE",
        "terminal_path": "D:/Meta 5/terminal64.exe",
        "ea_source": "tools/orderflow_proxy/native_parity/OFPNativeFixtureParity.mq5",
        "fixture_sha256": fixture_sha256,
        "source_graph_sha256": source_graph_sha256,
        "required_preconditions": [
            "SEPARATE_EXACT_HEAD_SOURCE_SCRUTINY_PASS",
            "EXCLUSIVE_PRIMARY_TESTER_LANE_VERIFIED",
            "FROZEN_SYNTHETIC_DIAGNOSTIC_RUNTIME_CONTRACT",
            "ELIGIBLE_EXISTING_SAFE_RUNNER_PARAMETERS_FROZEN",
            "TRUSTED_CONTROLLER_RECEIPT_FROZEN_AFTER_EXECUTION",
            "INDEPENDENT_CONTROLLER_EVIDENCE_PINS_RECEIPT_DIGEST_OUT_OF_BAND",
        ],
        "receipt_status": "ABSENT_NOT_EXECUTED",
        "trust_boundary": (
            "This inert descriptor is not a runtime receipt or trust root. Matching self-supplied "
            "names and hashes cannot prove execution."
        ),
        "forbidden_claims": [
            "REAL_DATA_PARITY",
            "REAL_QUOTE_HISTORY",
            "FILL_FIDELITY",
            "RISK_OR_PNL",
            "STRATEGY_PERFORMANCE",
            "PRODUCTION_RUNTIME",
        ],
        "auto_launch": False,
        "deployment": False,
    }
    include_bytes = _render_mql_include(
        reference, descriptors, expanded_cases, fixture_sha256, source_graph_sha256
    )
    ledger_bytes = _canonical_json(ledger)
    runtime_request_bytes = _canonical_json(runtime_request)
    manifest = {
        "schema": SCHEMA,
        "classification": "SOURCE_ONLY_SYNTHETIC_FIXTURE_PARITY_PREPARATION",
        "execution_status": "NOT_EXECUTED",
        "fixture": {
            "path": FIXTURE_PATH.relative_to(REPO_ROOT).as_posix(),
            "bytes": len(fixture_bytes),
            "sha256": fixture_sha256,
        },
        "source_graph": {"sha256": source_graph_sha256, "files": source_rows},
        "case_count": EXPECTED_CASE_COUNT,
        "variant_counts": ledger["variant_counts"],
        "generated_outputs": [
            _output_binding(
                "tools/orderflow_proxy/native_parity/generated/NativeFixtureData.mqh",
                include_bytes,
            ),
            _output_binding(
                "tools/orderflow_proxy/native_parity/generated/expected_python_ledger.json",
                ledger_bytes,
            ),
            _output_binding(
                "tools/orderflow_proxy/native_parity/generated/runtime_request.NOT_EXECUTED.json",
                runtime_request_bytes,
            ),
        ],
        "manifest_self_exclusion": {
            "excluded": True,
            "reason": "SELF_HASH_RECURSION",
        },
        "bridge_sources": _file_rows(BRIDGE_SOURCE_PATHS),
    }
    return {
        "NativeFixtureData.mqh": include_bytes,
        "expected_python_ledger.json": ledger_bytes,
        "runtime_request.NOT_EXECUTED.json": runtime_request_bytes,
        "manifest.json": _canonical_json(manifest),
    }


def write_outputs(output_dir: Path) -> dict[str, str]:
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs = build_outputs()
    hashes: dict[str, str] = {}
    for name, data in sorted(outputs.items()):
        (output_dir / name).write_bytes(data)
        hashes[name] = _sha256_bytes(data)
    return hashes


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    try:
        outputs = build_outputs()
        if args.check:
            mismatches = [
                name
                for name, data in outputs.items()
                if not (args.output_dir / name).is_file() or (args.output_dir / name).read_bytes() != data
            ]
            if mismatches:
                print(json.dumps({"status": "STALE", "mismatches": sorted(mismatches)}, sort_keys=True))
                return 1
            print(json.dumps({"status": "CURRENT", "files": sorted(outputs)}, sort_keys=True))
            return 0
        hashes = write_outputs(args.output_dir)
        print(json.dumps({"status": "GENERATED", "hashes": hashes}, sort_keys=True))
        return 0
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "REFUSED", "error": str(error)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
