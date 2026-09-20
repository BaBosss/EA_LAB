from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

import generate_native_fixture as generator
import parse_native_ledger as parser


ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
GENERATED = HERE / "generated"
EA_PATH = HERE / "OFPNativeFixtureParity.mq5"
RUN_ID = "OFP-NATIVE-FIXTURE-UNIT-TEST"


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


def _valid_log(expected: dict[str, object]) -> str:
    lines = ["tester prefix " + _native_case_line(row, expected) for row in expected["cases"]]
    lines.append(
        "OFP_NATIVE_PARITY_COMPLETED|"
        f"run_id={RUN_ID}|native_origin=ACTUAL_CANONICAL_MQL_REPLAY|run_class=SYNTHETIC_FIXTURE|"
        f"case_count=24|fixture_sha256={expected['fixture']['sha256']}|"
        f"source_graph_sha256={expected['source_graph']['sha256']}"
    )
    return "\n".join(lines) + "\n"


class GeneratorTests(unittest.TestCase):
    def test_generated_bytes_are_deterministic_and_current(self) -> None:
        first = generator.build_outputs()
        second = generator.build_outputs()
        self.assertEqual(first, second)
        for name, data in first.items():
            self.assertEqual(data, (GENERATED / name).read_bytes(), name)

    def test_exact_mirrored_matrix_and_expected_outcomes(self) -> None:
        ledger = json.loads((GENERATED / "expected_python_ledger.json").read_text(encoding="utf-8"))
        self.assertEqual(24, ledger["case_count"])
        self.assertEqual({variant: 4 for variant in generator.EXPECTED_VARIANTS}, ledger["variant_counts"])
        matrix = {
            (row["variant"], row["descriptor_direction"], row["scenario"])
            for row in ledger["cases"]
        }
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
        self.expected = json.loads((GENERATED / "expected_python_ledger.json").read_text(encoding="utf-8"))
        self.log = _valid_log(self.expected)

    def test_accepts_complete_exact_actual_native_shape(self) -> None:
        result = parser.compare_native_log(self.log, self.expected, expected_run_id=RUN_ID)
        self.assertEqual("PASS", result["status"])
        self.assertEqual("SYNTHETIC_FIXTURE_NATIVE_PARITY_ONLY", result["classification"])

    def test_rejects_missing_duplicate_and_extra_cases(self) -> None:
        lines = self.log.splitlines()
        with self.assertRaisesRegex(parser.NativeParityError, "MISSING_OR_EXTRA_NATIVE_CASES"):
            parser.compare_native_log("\n".join(lines[1:]) + "\n", self.expected, expected_run_id=RUN_ID)
        with self.assertRaisesRegex(parser.NativeParityError, "DUPLICATE_NATIVE_CASE"):
            parser.compare_native_log(
                "\n".join([lines[0], lines[0], *lines[2:]]) + "\n",
                self.expected,
                expected_run_id=RUN_ID,
            )
        extra = lines[0].replace("case_id=OFPR-00-LONG-POS", "case_id=EXTRA")
        with self.assertRaisesRegex(parser.NativeParityError, "MISSING_OR_EXTRA_NATIVE_CASE_IDS"):
            parser.compare_native_log(
                "\n".join([extra, *lines[1:]]) + "\n", self.expected, expected_run_id=RUN_ID
            )

    def test_rejects_hash_identity_and_sentinel_failures(self) -> None:
        with self.assertRaisesRegex(parser.NativeParityError, "HASH_MISMATCH"):
            parser.compare_native_log(
                self.log.replace(self.expected["fixture"]["sha256"], "0" * 64, 1),
                self.expected,
                expected_run_id=RUN_ID,
            )
        with self.assertRaisesRegex(parser.NativeParityError, "SENTINEL"):
            parser.compare_native_log(
                "\n".join(self.log.splitlines()[:-1]) + "\n", self.expected, expected_run_id=RUN_ID
            )

    def test_rejects_value_mismatch_without_tolerance(self) -> None:
        mutated = self.log.replace("prospective_entry=100.900000000000", "prospective_entry=100.900000000001", 1)
        with self.assertRaisesRegex(parser.NativeParityError, "NATIVE_PARITY_MISMATCH"):
            parser.compare_native_log(mutated, self.expected, expected_run_id=RUN_ID)

    def test_rejects_generated_or_unknown_native_run(self) -> None:
        with self.assertRaisesRegex(parser.NativeParityError, "UNKNOWN_OR_UNFROZEN"):
            parser.compare_native_log(self.log, self.expected, expected_run_id="GENERATED")
        with self.assertRaisesRegex(parser.NativeParityError, "GENERATED_OR_UNKNOWN"):
            parser.compare_native_log(
                self.log.replace("ACTUAL_CANONICAL_MQL_REPLAY", "GENERATED", 1),
                self.expected,
                expected_run_id=RUN_ID,
            )

    def test_rejects_wrong_expected_source_graph(self) -> None:
        changed = copy.deepcopy(self.expected)
        changed["source_graph"]["sha256"] = "f" * 64
        with self.assertRaisesRegex(parser.NativeParityError, "SENTINEL_IDENTITY_MISMATCH"):
            parser.compare_native_log(self.log, changed, expected_run_id=RUN_ID)


class StaticSafetyTests(unittest.TestCase):
    def test_ea_binds_canonical_components_and_refuses_non_tester_first(self) -> None:
        source = EA_PATH.read_text(encoding="utf-8")
        self.assertIn('../../../ea_template/components/orderflow_proxy/OrderFlowProxyComponents.mqh', source)
        on_init = source[source.index("int OnInit()") :]
        self.assertLess(on_init.index("if(!MQLInfoInteger(MQL_TESTER))"), on_init.index("InpRuntimeContractId"))

    def test_ea_contains_no_trade_market_history_or_runtime_activation_api(self) -> None:
        source = EA_PATH.read_text(encoding="utf-8")
        forbidden = (
            "OrderSend",
            "CTrade",
            "PositionOpen",
            "PositionClose",
            "PositionModify",
            "HistorySelect",
            "CopyRates",
            "CopyTicks",
            "SymbolInfoTick",
            "iOpen(",
            "iClose(",
            "Chart",
            "EventSetTimer",
            "EventSetMillisecondTimer",
            "WebRequest",
            "ShellExecute",
        )
        self.assertEqual([], [token for token in forbidden if token in source])

    def test_runtime_request_is_inert_and_not_executed(self) -> None:
        request = json.loads((GENERATED / "runtime_request.NOT_EXECUTED.json").read_text(encoding="utf-8"))
        self.assertEqual("NOT_EXECUTED", request["execution_status"])
        self.assertFalse(request["auto_launch"])
        self.assertFalse(request["deployment"])


if __name__ == "__main__":
    unittest.main()
