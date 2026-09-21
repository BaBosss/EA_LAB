from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any, Callable

import generate_native_fixture as generator
import parse_native_ledger as parser
import receipt_validation as receipts


ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
GENERATED = HERE / "generated"
EA_PATH = HERE / "OFPNativeFixtureParity.mq5"
RUN_ID = "OFP-NATIVE-FIXTURE-UNIT-TEST"
FIXTURE_HEAD = "814d18c159a8c912140cd2fb6ea77e9f8641d32e"
TERMINAL_CONFIG = b"fixture-only terminal configuration\n"
TESTER_CONFIG = b"fixture-only tester configuration\n"
EX5_BYTES = b"fixture-only ex5 bytes; not an executable runtime receipt\n"


def _canonical_json(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def _native_case_line(row: dict[str, object], expected: dict[str, object]) -> str:
    fields = {
        "run_id": RUN_ID,
        "native_origin": "ACTUAL_CANONICAL_MQL_REPLAY",
        "run_class": "SYNTHETIC_FIXTURE",
        "case_id": row["case_id"],
        "variant": row["variant"],
        "status": row["status"],
        "replay_return": "true" if row["status"] == "SIGNAL" else "false",
        "direction": row["direction"],
        "current_closed_bar_record_id": row["current_closed_bar_record_id"],
        "setup_time": row["setup_time"],
        "trigger_time": row["trigger_time"],
        "prospective_entry": row["prospective_entry"],
        "stop_price": row["stop_price"],
        "target_price": row["target_price"],
        "net_rr": row["net_rr"],
        "data_identity": row["data_identity"],
        "profile_identity": row["profile_identity"],
        "imbalance_identity": row["imbalance_identity"],
        "fixture_sha256": expected["fixture"]["sha256"],
        "source_graph_sha256": expected["source_graph"]["sha256"],
    }
    return "OFP_NATIVE_PARITY_CASE|" + "|".join(f"{key}={value}" for key, value in fields.items())


def _valid_log(expected: dict[str, object]) -> bytes:
    lines = ["tester prefix " + _native_case_line(row, expected) for row in expected["cases"]]
    lines.append(
        "OFP_NATIVE_PARITY_COMPLETED|"
        f"run_id={RUN_ID}|native_origin=ACTUAL_CANONICAL_MQL_REPLAY|run_class=SYNTHETIC_FIXTURE|"
        f"case_count=24|fixture_sha256={expected['fixture']['sha256']}|"
        f"source_graph_sha256={expected['source_graph']['sha256']}"
    )
    return ("\n".join(lines) + "\n").encode("utf-8")


def _rebind_manifest_output(manifest_bytes: bytes, path: str, data: bytes) -> bytes:
    manifest = json.loads(manifest_bytes.decode("utf-8"))
    row = next(item for item in manifest["generated_outputs"] if item["path"] == path)
    row["bytes"] = len(data)
    row["sha256"] = receipts.sha256_bytes(data)
    return _canonical_json(manifest)


def _fixture_bound_inputs(
    outputs: dict[str, bytes],
    log_bytes: bytes,
    *,
    expected_bytes: bytes | None = None,
    manifest_bytes: bytes | None = None,
    receipt_mutator: Callable[[dict[str, Any]], None] | None = None,
    evidence_mutator: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    expected_bytes = outputs["expected_python_ledger.json"] if expected_bytes is None else expected_bytes
    manifest_bytes = outputs["manifest.json"] if manifest_bytes is None else manifest_bytes
    manifest = json.loads(manifest_bytes.decode("utf-8"))
    include_bytes = outputs["NativeFixtureData.mqh"]
    runtime_request_bytes = outputs["runtime_request.NOT_EXECUTED.json"]
    ea_source_bytes = EA_PATH.read_bytes()
    receipt = {
        "schema": receipts.RECEIPT_SCHEMA,
        "classification": "TRUSTED_CONTROLLER_SAFE_RUNNER_RECEIPT",
        "bridge_source_head": FIXTURE_HEAD,
        "runtime_contract_id": RUN_ID,
        "terminal_configuration": receipts.artifact_binding(
            "fixture/terminal.ini", "FIXTURE_TERMINAL_CONFIG", TERMINAL_CONFIG
        ),
        "tester_configuration": receipts.artifact_binding(
            "fixture/tester.ini", "FIXTURE_TESTER_CONFIG", TESTER_CONFIG
        ),
        "ea_source": receipts.artifact_binding(
            "tools/orderflow_proxy/native_parity/OFPNativeFixtureParity.mq5",
            "OFP_NATIVE_FIXTURE_EA_SOURCE",
            ea_source_bytes,
        ),
        "ex5": receipts.artifact_binding(
            "fixture/OFPNativeFixtureParity.ex5", "FIXTURE_ONLY_EX5", EX5_BYTES
        ),
        "generated_include": receipts.artifact_binding(
            "tools/orderflow_proxy/native_parity/generated/NativeFixtureData.mqh",
            "GENERATED_NATIVE_FIXTURE_INCLUDE",
            include_bytes,
        ),
        "expected_ledger": receipts.artifact_binding(
            "tools/orderflow_proxy/native_parity/generated/expected_python_ledger.json",
            "EXPECTED_PYTHON_LEDGER",
            expected_bytes,
        ),
        "source_graph_sha256": manifest["source_graph"]["sha256"],
        "fixture_sha256": manifest["fixture"]["sha256"],
        "package_manifest": receipts.artifact_binding(
            "tools/orderflow_proxy/native_parity/generated/manifest.json",
            "GENERATED_PACKAGE_MANIFEST",
            manifest_bytes,
        ),
        "native_journal": receipts.artifact_binding(
            "fixture/native_journal.log", "FIXTURE_ONLY_NATIVE_JOURNAL", log_bytes
        ),
    }
    if receipt_mutator is not None:
        receipt_mutator(receipt)
    receipt_bytes = _canonical_json(receipt)
    controller_evidence = {
        "schema": receipts.CONTROLLER_EVIDENCE_SCHEMA,
        "classification": "INDEPENDENT_FROZEN_CONTROLLER_EVIDENCE",
        "evidence_scope": receipts.FIXTURE_SCOPE,
        "controller_evidence_id": "FIXTURE-ONLY-CONTROLLER-EVIDENCE",
        "reviewed_bridge_source_head": FIXTURE_HEAD,
        "runtime_contract_id": RUN_ID,
        "receipt": {
            "bytes": len(receipt_bytes),
            "sha256": receipts.sha256_bytes(receipt_bytes),
        },
        "package_manifest_sha256": receipts.sha256_bytes(manifest_bytes),
    }
    if evidence_mutator is not None:
        evidence_mutator(controller_evidence)
    controller_evidence_bytes = _canonical_json(controller_evidence)
    return {
        "package_manifest_bytes": manifest_bytes,
        "runtime_request_bytes": runtime_request_bytes,
        "generated_include_bytes": include_bytes,
        "ea_source_bytes": ea_source_bytes,
        "ex5_bytes": EX5_BYTES,
        "terminal_config_bytes": TERMINAL_CONFIG,
        "tester_config_bytes": TESTER_CONFIG,
        "receipt_bytes": receipt_bytes,
        "controller_evidence_bytes": controller_evidence_bytes,
        "expected_controller_evidence_sha256": receipts.sha256_bytes(controller_evidence_bytes),
        "repository_root": ROOT,
    }


class GeneratorTests(unittest.TestCase):
    def test_generated_bytes_are_deterministic_and_current(self) -> None:
        first = generator.build_outputs()
        second = generator.build_outputs()
        self.assertEqual(first, second)
        for name, data in first.items():
            self.assertEqual(data, (GENERATED / name).read_bytes(), name)

    def test_manifest_binds_every_generated_output_except_itself_and_bridge_sources(self) -> None:
        outputs = generator.build_outputs()
        manifest = json.loads(outputs["manifest.json"].decode("utf-8"))
        self.assertEqual(
            {"excluded": True, "reason": "SELF_HASH_RECURSION"},
            manifest["manifest_self_exclusion"],
        )
        self.assertEqual(list(receipts.GENERATED_OUTPUT_PATHS), [row["path"] for row in manifest["generated_outputs"]])
        for row in manifest["generated_outputs"]:
            name = Path(row["path"]).name
            self.assertEqual(len(outputs[name]), row["bytes"])
            self.assertEqual(receipts.sha256_bytes(outputs[name]), row["sha256"])
        self.assertEqual(list(receipts.REQUIRED_BRIDGE_SOURCE_PATHS), [row["path"] for row in manifest["bridge_sources"]])

    def test_exact_mirrored_matrix_and_expected_outcomes(self) -> None:
        ledger = json.loads((GENERATED / "expected_python_ledger.json").read_text(encoding="utf-8"))
        self.assertEqual(24, ledger["case_count"])
        self.assertEqual({variant: 4 for variant in generator.EXPECTED_VARIANTS}, ledger["variant_counts"])
        matrix = {(row["variant"], row["descriptor_direction"], row["scenario"]) for row in ledger["cases"]}
        self.assertEqual(24, len(matrix))
        self.assertEqual(12, sum(row["status"] == "SIGNAL" for row in ledger["cases"]))
        self.assertEqual(12, sum(row["status"] == "NO_SIGNAL" for row in ledger["cases"]))

    def test_writing_twice_produces_identical_files(self) -> None:
        with tempfile.TemporaryDirectory() as first_dir, tempfile.TemporaryDirectory() as second_dir:
            generator.write_outputs(Path(first_dir))
            generator.write_outputs(Path(second_dir))
            for name in generator.build_outputs():
                self.assertEqual((Path(first_dir) / name).read_bytes(), (Path(second_dir) / name).read_bytes())


class ParserTests(unittest.TestCase):
    def setUp(self) -> None:
        self.outputs = generator.build_outputs()
        self.expected_bytes = self.outputs["expected_python_ledger.json"]
        self.expected = json.loads(self.expected_bytes.decode("utf-8"))
        self.log = _valid_log(self.expected)

    def _compare(
        self,
        log_bytes: bytes | None = None,
        expected_bytes: bytes | None = None,
        *,
        manifest_bytes: bytes | None = None,
        receipt_mutator: Callable[[dict[str, Any]], None] | None = None,
        evidence_mutator: Callable[[dict[str, Any]], None] | None = None,
        input_mutator: Callable[[dict[str, Any]], None] | None = None,
    ) -> dict[str, Any]:
        log_bytes = self.log if log_bytes is None else log_bytes
        expected_bytes = self.expected_bytes if expected_bytes is None else expected_bytes
        kwargs = _fixture_bound_inputs(
            self.outputs,
            log_bytes,
            expected_bytes=expected_bytes,
            manifest_bytes=manifest_bytes,
            receipt_mutator=receipt_mutator,
            evidence_mutator=evidence_mutator,
        )
        if input_mutator is not None:
            input_mutator(kwargs)
        return parser.compare_native_log(log_bytes, expected_bytes, **kwargs)

    def test_rejects_expected_ledger_derived_log_without_controller_receipt(self) -> None:
        with self.assertRaisesRegex(parser.NativeParityError, "TRUSTED_CONTROLLER_RECEIPT_REQUIRED"):
            parser.compare_native_log(self.log, self.expected, expected_run_id=RUN_ID)

    def test_valid_bound_shape_is_explicitly_fixture_only_not_actual_execution(self) -> None:
        result = self._compare()
        self.assertEqual("FIXTURE_INTEGRITY_PASS", result["status"])
        self.assertEqual("FIXTURE_ONLY_CONTROLLER_RECEIPT_SHAPE_INTEGRITY", result["classification"])
        self.assertFalse(result["native_execution_qualified"])
        self.assertEqual("NOT_EXECUTED", result["execution_status"])

    def test_rejects_joint_forged_log_and_ledger_against_original_pins(self) -> None:
        forged_expected = copy.deepcopy(self.expected)
        forged_expected["cases"][0]["prospective_entry"] = "999.000000000000"
        forged_expected_bytes = _canonical_json(forged_expected)
        forged_log = self.log.replace(b"prospective_entry=100.900000000000", b"prospective_entry=999.000000000000", 1)
        original_pins = _fixture_bound_inputs(self.outputs, self.log)
        with self.assertRaisesRegex(parser.NativeParityError, "SHA256_MISMATCH|BYTES_MISMATCH"):
            parser.compare_native_log(forged_log, forged_expected_bytes, **original_pins)

    def test_rejects_wrong_receipt_package_ledger_journal_ex5_and_configs(self) -> None:
        cases: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
            ("CONTROLLER_RECEIPT_SHA256_MISMATCH", lambda values: values.__setitem__("receipt_bytes", values["receipt_bytes"].replace(b"UNIT-TEST", b"UNIT-TESX", 1))),
            ("CONTROLLER_PACKAGE_MANIFEST_SHA256_MISMATCH", lambda values: values.__setitem__("package_manifest_bytes", values["package_manifest_bytes"] + b"\n")),
            ("EXPECTED_LEDGER_SHA256_MISMATCH|GENERATED_OUTPUT_1_SHA256_MISMATCH", lambda values: values.__setitem__("expected_ledger_bytes", values["expected_ledger_bytes"].replace(b"100.900000000000", b"100.900000000001", 1))),
            ("NATIVE_JOURNAL_BYTES_MISMATCH|NATIVE_JOURNAL_SHA256_MISMATCH", lambda values: values.__setitem__("log_bytes", values["log_bytes"] + b"extra\n")),
            ("EX5_BYTES_MISMATCH|EX5_SHA256_MISMATCH", lambda values: values.__setitem__("ex5_bytes", values["ex5_bytes"] + b"x")),
            ("EA_SOURCE_BYTES_MISMATCH|EA_SOURCE_SHA256_MISMATCH", lambda values: values.__setitem__("ea_source_bytes", values["ea_source_bytes"] + b"x")),
            ("GENERATED_OUTPUT_0_BYTES_MISMATCH|GENERATED_INCLUDE_BYTES_MISMATCH|GENERATED_INCLUDE_SHA256_MISMATCH", lambda values: values.__setitem__("generated_include_bytes", values["generated_include_bytes"] + b"x")),
            ("TERMINAL_CONFIGURATION_BYTES_MISMATCH|TERMINAL_CONFIGURATION_SHA256_MISMATCH", lambda values: values.__setitem__("terminal_config_bytes", values["terminal_config_bytes"] + b"x")),
            ("TESTER_CONFIGURATION_BYTES_MISMATCH|TESTER_CONFIGURATION_SHA256_MISMATCH", lambda values: values.__setitem__("tester_config_bytes", values["tester_config_bytes"] + b"x")),
        ]
        for expected_error, mutate in cases:
            with self.subTest(expected_error=expected_error):
                kwargs = _fixture_bound_inputs(self.outputs, self.log)
                values = {"log_bytes": self.log, "expected_ledger_bytes": self.expected_bytes, **kwargs}
                mutate(values)
                with self.assertRaisesRegex(parser.NativeParityError, expected_error):
                    parser.compare_native_log(
                        values.pop("log_bytes"), values.pop("expected_ledger_bytes"), **values
                    )

    def test_rejects_wrong_reviewed_head_and_runtime_contract_id(self) -> None:
        with self.assertRaisesRegex(parser.NativeParityError, "BRIDGE_SOURCE_HEAD_MISMATCH"):
            self._compare(receipt_mutator=lambda value: value.__setitem__("bridge_source_head", "b" * 40))
        with self.assertRaisesRegex(parser.NativeParityError, "RUNTIME_CONTRACT_ID_MISMATCH"):
            self._compare(receipt_mutator=lambda value: value.__setitem__("runtime_contract_id", "OFP-NATIVE-FIXTURE-WRONG"))

    def test_rejects_missing_receipt_and_wrong_out_of_band_controller_digest(self) -> None:
        kwargs = _fixture_bound_inputs(self.outputs, self.log)
        kwargs["receipt_bytes"] = None
        with self.assertRaisesRegex(parser.NativeParityError, "TRUSTED_CONTROLLER_RECEIPT_REQUIRED"):
            parser.compare_native_log(self.log, self.expected_bytes, **kwargs)
        kwargs = _fixture_bound_inputs(self.outputs, self.log)
        kwargs["expected_controller_evidence_sha256"] = "0" * 64
        with self.assertRaisesRegex(parser.NativeParityError, "CONTROLLER_EVIDENCE_SHA256_MISMATCH"):
            parser.compare_native_log(self.log, self.expected_bytes, **kwargs)

    def test_rejects_missing_or_duplicate_sentinel_and_duplicate_or_extra_cases(self) -> None:
        lines = self.log.splitlines()
        variants = (
            (b"\n".join(lines[:-1]) + b"\n", "MISSING_OR_DUPLICATE_COMPLETED_SENTINEL"),
            (b"\n".join([*lines, lines[-1]]) + b"\n", "MISSING_OR_DUPLICATE_COMPLETED_SENTINEL"),
            (b"\n".join([lines[0], lines[0], *lines[2:]]) + b"\n", "DUPLICATE_NATIVE_CASE"),
            (b"\n".join(lines[1:]) + b"\n", "MISSING_OR_EXTRA_NATIVE_CASES"),
            (b"\n".join([lines[0].replace(b"case_id=OFPR-00-LONG-POS", b"case_id=EXTRA"), *lines[1:]]) + b"\n", "MISSING_OR_EXTRA_NATIVE_CASE_IDS"),
        )
        for mutated, expected_error in variants:
            with self.subTest(expected_error=expected_error):
                with self.assertRaisesRegex(parser.NativeParityError, expected_error):
                    self._compare(mutated)

    def test_rejects_malformed_receipt_and_expected_ledger_types(self) -> None:
        def malformed_receipt(value: dict[str, Any]) -> None:
            value["ex5"]["bytes"] = str(value["ex5"]["bytes"])

        with self.assertRaisesRegex(parser.NativeParityError, "INVALID_EX5_BYTES_TYPE"):
            self._compare(receipt_mutator=malformed_receipt)

        malformed_expected = copy.deepcopy(self.expected)
        malformed_expected["case_count"] = "24"
        malformed_expected_bytes = _canonical_json(malformed_expected)
        manifest = _rebind_manifest_output(
            self.outputs["manifest.json"],
            "tools/orderflow_proxy/native_parity/generated/expected_python_ledger.json",
            malformed_expected_bytes,
        )
        with self.assertRaisesRegex(parser.NativeParityError, "INVALID_EXPECTED_CASE_COUNT"):
            self._compare(expected_bytes=malformed_expected_bytes, manifest_bytes=manifest)

    def test_rejects_meaningful_comparison_mismatch_after_all_fixture_pins_validate(self) -> None:
        mutated = self.log.replace(b"prospective_entry=100.900000000000", b"prospective_entry=100.900000000001", 1)
        with self.assertRaisesRegex(parser.NativeParityError, "NATIVE_PARITY_MISMATCH"):
            self._compare(mutated)

    def test_rejects_generated_origin_even_when_fixture_receipt_binds_the_bytes(self) -> None:
        mutated = self.log.replace(b"ACTUAL_CANONICAL_MQL_REPLAY", b"GENERATED", 1)
        with self.assertRaisesRegex(parser.NativeParityError, "GENERATED_OR_UNKNOWN_NATIVE_RUN"):
            self._compare(mutated)

    def test_rejects_wrong_expected_source_graph_after_fixture_package_is_rebound(self) -> None:
        changed = copy.deepcopy(self.expected)
        changed["source_graph"]["sha256"] = "f" * 64
        changed_bytes = _canonical_json(changed)
        manifest = _rebind_manifest_output(
            self.outputs["manifest.json"],
            "tools/orderflow_proxy/native_parity/generated/expected_python_ledger.json",
            changed_bytes,
        )
        with self.assertRaisesRegex(parser.NativeParityError, "EXPECTED_LEDGER_SOURCE_GRAPH_BINDING_MISMATCH"):
            self._compare(expected_bytes=changed_bytes, manifest_bytes=manifest)


class StaticSafetyTests(unittest.TestCase):
    def test_ea_binds_canonical_components_and_refuses_non_tester_first(self) -> None:
        source = EA_PATH.read_text(encoding="utf-8")
        self.assertIn('../../../ea_template/components/orderflow_proxy/OrderFlowProxyComponents.mqh', source)
        on_init = source[source.index("int OnInit()") :]
        self.assertLess(on_init.index("if(!MQLInfoInteger(MQL_TESTER))"), on_init.index("InpRuntimeContractId"))

    def test_ea_contains_no_trade_market_history_or_runtime_activation_api(self) -> None:
        source = EA_PATH.read_text(encoding="utf-8")
        forbidden = (
            "OrderSend", "CTrade", "PositionOpen", "PositionClose", "PositionModify",
            "HistorySelect", "CopyRates", "CopyTicks", "SymbolInfoTick", "iOpen(",
            "iClose(", "Chart", "EventSetTimer", "EventSetMillisecondTimer", "WebRequest",
            "ShellExecute",
        )
        self.assertEqual([], [token for token in forbidden if token in source])

    def test_runtime_request_is_inert_unfrozen_and_not_a_receipt(self) -> None:
        request = json.loads(generator.build_outputs()["runtime_request.NOT_EXECUTED.json"].decode("utf-8"))
        self.assertEqual("NOT_EXECUTED", request["execution_status"])
        self.assertEqual("NOT_EXECUTED_UNFROZEN", request["runtime_contract_id"])
        self.assertEqual("ABSENT_NOT_EXECUTED", request["receipt_status"])
        self.assertFalse(request["auto_launch"])
        self.assertFalse(request["deployment"])


if __name__ == "__main__":
    unittest.main()
