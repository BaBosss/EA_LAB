from __future__ import annotations

import copy
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MODULE_PATH = ROOT / "tools" / "orderflow_proxy" / "provider_bundle.py"
A2_ROOT = Path(r"D:\EA_LAB_CONTROL\evidence\ct-ofp-thinkmarkets-sync-basis-20260920")
REQUIRED_A2_FILES = (
    "CONTRACT.md",
    "RESULT.json",
    "PASS1.json",
    "PASS2.json",
    "FROZEN_INTERVALS.json",
    "EVIDENCE_MANIFEST.json",
    "REVIEW_OUTPUT.json",
    "REVIEW_RECOVERY.json",
)
ACCEPTED = ("XAUUSD", "EURUSD", "GBPUSD", "EURGBP", "USDJPY", "EURJPY")
BLOCKED = ("BTCUSD", "ETHUSD")
EXPECTED_BUNDLE_SHA256 = {
    "XAUUSD": "eb4ae690ae9c8cbe32e5ca3b69baef1e1ce42ebe63e1fa3eba560ab95da71a8d",
    "EURUSD": "776df940030826e6dc60389c0b2fe731999d66b8853a8651231947f73d1de75c",
    "GBPUSD": "3fa11f7c2db87873dcf809dafa344a487b9869fb091c351d68a3da7da7383046",
    "EURGBP": "330fb9d2e0cdbd4d82ab7fa25c998c47a51a0f1f520cbfe1f14fadc807966c92",
    "USDJPY": "26f6af2bba8bfa786e1940b1f818d4a84d2c7cec3c332ebe65267e5226953287",
    "EURJPY": "e9c2d00c7d193e5e488e0b30bb25418f6f506db7933eb33233ede02c73f10576",
}


spec = importlib.util.spec_from_file_location("provider_bundle", MODULE_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError("provider_bundle import spec unavailable")
provider_bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provider_bundle)


class ProviderBundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.documents = provider_bundle.load_verified_evidence(A2_ROOT)

    def assert_refused(self, documents: dict, symbol: str, reason: str) -> None:
        with self.assertRaisesRegex(provider_bundle.ProviderEvidenceError, reason):
            provider_bundle.derive_bundle(documents, symbol)

    def test_review_and_manifest_are_pinned_before_use(self) -> None:
        self.assertEqual(self.documents["review"]["decision"], "SCRUTINY_PASS")
        self.assertEqual(self.documents["review"]["confidence"], "HIGH")
        self.assertEqual(self.documents["review"]["material_findings"], [])
        self.assertEqual(
            self.documents["review"]["evidence_manifest_sha256"],
            provider_bundle.EXPECTED_A2_SHA256["EVIDENCE_MANIFEST.json"],
        )

    def test_review_claims_cannot_be_bypassed_in_memory(self) -> None:
        mutations = (
            (lambda d: d["review"].__setitem__("decision", "SCRUTINY_FAIL"), "A2_REVIEW_NOT_PASS"),
            (lambda d: d["review"].__setitem__("confidence", "LOW"), "A2_REVIEW_NOT_HIGH_CONFIDENCE"),
            (lambda d: d["review"].__setitem__("material_findings", [{"id": "x"}]), "A2_REVIEW_HAS_MATERIAL_FINDINGS"),
            (lambda d: d["review"].__setitem__("reviewed_repo_head", "0" * 40), "REVIEWED_REPO_HEAD_MISMATCH"),
            (lambda d: d["review"].__setitem__("evidence_manifest_sha256", "0" * 64), "REVIEW_MANIFEST_HASH_MISMATCH"),
        )
        for mutate, reason in mutations:
            with self.subTest(reason=reason):
                documents = copy.deepcopy(self.documents)
                mutate(documents)
                self.assert_refused(documents, "XAUUSD", reason)

    def test_modified_immutable_evidence_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            copied = Path(temp)
            for name in REQUIRED_A2_FILES:
                shutil.copy2(A2_ROOT / name, copied / name)
            result = json.loads((copied / "RESULT.json").read_text(encoding="utf-8-sig"))
            result["provider_server"] = "modified"
            (copied / "RESULT.json").write_text(json.dumps(result), encoding="utf-8")
            with self.assertRaisesRegex(
                provider_bundle.ProviderEvidenceError,
                "EVIDENCE_FILE_HASH_MISMATCH:RESULT.json",
            ):
                provider_bundle.load_verified_evidence(copied)

    def test_only_exact_six_current_windows_emit(self) -> None:
        bundles = provider_bundle.derive_bundles(self.documents)
        self.assertEqual(tuple(bundles), ACCEPTED)
        self.assertEqual(provider_bundle.EXPECTED_BUNDLE_SHA256, EXPECTED_BUNDLE_SHA256)
        self.assertEqual(
            {symbol: bundle["bundle_sha256"] for symbol, bundle in bundles.items()},
            EXPECTED_BUNDLE_SHA256,
        )
        for symbol, bundle in bundles.items():
            self.assertEqual(bundle["logical_symbol"], symbol)
            self.assertEqual(bundle["classification"], "RESEARCH_INPUT_ONLY_CURRENT_WINDOW")
            self.assertEqual(bundle["policy_id"], "THINKMARKETS_LIVE_A2_V1")
            self.assertEqual(len(bundle["interval_receipts"]), 22)
            self.assertFalse(bundle["true_orderflow"])
            self.assertFalse(bundle["executed_volume_delta_qualified"])
            self.assertFalse(bundle["order_execution_authorized"])

    def test_all_six_native_integrity_pins_bind_exact_reviewed_payloads(self) -> None:
        bundles = provider_bundle.derive_bundles(self.documents)
        self.assertEqual(
            {
                symbol: provider_bundle.validate_native_payload_binding(bundle)
                for symbol, bundle in bundles.items()
            },
            provider_bundle.EXPECTED_NATIVE_PAYLOAD_INTEGRITY_SHA256,
        )
        self.assertEqual(
            set(provider_bundle.EXPECTED_NATIVE_PAYLOAD_INTEGRITY_SHA256),
            set(ACCEPTED),
        )

    def test_native_binding_refuses_field_and_boolean_mutations(self) -> None:
        original = provider_bundle.derive_bundle(self.documents, "EURUSD")
        mutations = (
            (
                "count",
                lambda b: b["interval_receipts"][0].__setitem__(
                    "pass1_count", b["interval_receipts"][0]["pass1_count"] + 1
                ),
            ),
            (
                "timestamp",
                lambda b: b["interval_receipts"][0].__setitem__(
                    "pass1_first_time_msc", b["interval_receipts"][0]["pass1_first_time_msc"] + 1
                ),
            ),
            (
                "quote_hash",
                lambda b: b["interval_receipts"][0].__setitem__(
                    "pass1_quote_stream_sha256", "0" + b["interval_receipts"][0]["pass1_quote_stream_sha256"][1:]
                ),
            ),
            (
                "snapshot_state",
                lambda b: b["interval_receipts"][0].__setitem__("rate_snapshot_stable", False),
            ),
            (
                "api_boolean",
                lambda b: b["interval_receipts"][0].__setitem__("pass1_api_success", False),
            ),
            (
                "claim_boolean",
                lambda b: b.__setitem__("true_orderflow", True),
            ),
        )
        for label, mutate in mutations:
            with self.subTest(field=label):
                changed = copy.deepcopy(original)
                mutate(changed)
                with self.assertRaisesRegex(
                    provider_bundle.ProviderEvidenceError,
                    "NATIVE_PAYLOAD_INTEGRITY_MISMATCH",
                ):
                    provider_bundle.validate_native_payload_binding(changed)

    def test_shape_valid_or_recomputed_caller_bundle_digest_cannot_bypass_pins(self) -> None:
        original = provider_bundle.derive_bundle(self.documents, "EURUSD")

        changed = copy.deepcopy(original)
        changed["bundle_sha256"] = "b" * 64
        with self.assertRaisesRegex(provider_bundle.ProviderEvidenceError, "BUNDLE_SHA256_MISMATCH"):
            provider_bundle.validate_native_payload_binding(changed)

        changed = copy.deepcopy(original)
        changed["interval_receipts"][0]["pass1_count"] += 1
        without_digest = {key: value for key, value in changed.items() if key != "bundle_sha256"}
        changed["bundle_sha256"] = provider_bundle._bundle_hash(without_digest)
        self.assertRegex(changed["bundle_sha256"], r"^[0-9a-f]{64}$")
        with self.assertRaisesRegex(provider_bundle.ProviderEvidenceError, "BUNDLE_SHA256_MISMATCH"):
            provider_bundle.validate_native_payload_binding(changed)

    def test_blocked_and_unsupported_symbols_are_refused(self) -> None:
        for symbol in (*BLOCKED, "AUDUSD"):
            with self.subTest(symbol=symbol):
                with self.assertRaisesRegex(
                    provider_bundle.ProviderEvidenceError,
                    "SYMBOL_NOT_REVIEWED_QUALIFIED",
                ):
                    provider_bundle.derive_bundle(self.documents, symbol)

    def test_naked_qualified_boolean_cannot_override_bad_evidence(self) -> None:
        documents = copy.deepcopy(self.documents)
        symbol = provider_bundle.symbol_record(documents["pass1"], "XAUUSD")
        symbol["qualified"] = True
        symbol["interval_results"][0]["copy"]["sha256"] = "0" * 64
        self.assert_refused(documents, "XAUUSD", "REPEAT_IDENTITY_MISMATCH")

    def test_bad_provider_build_and_hash_are_refused(self) -> None:
        mutations = (
            ("result", lambda d: d.__setitem__("provider_server", "Other"), "PROVIDER_IDENTITY_MISMATCH"),
            ("pass1", lambda d: d["identity"].__setitem__("build", 1), "TERMINAL_IDENTITY_MISMATCH"),
            (
                "pass1",
                lambda d: d["symbols"][0]["interval_results"][0]["copy"].__setitem__("sha256", "bad"),
                "MALFORMED_QUOTE_STREAM_SHA256",
            ),
        )
        for document, mutate, reason in mutations:
            with self.subTest(reason=reason):
                documents = copy.deepcopy(self.documents)
                mutate(documents[document])
                self.assert_refused(documents, "XAUUSD", reason)

    def test_missing_duplicate_and_out_of_order_receipts_are_refused(self) -> None:
        mutations = (
            (lambda rows: rows.pop(), "INTERVAL_RECEIPT_COUNT_MISMATCH"),
            (lambda rows: rows.__setitem__(1, copy.deepcopy(rows[0])), "INTERVAL_RECEIPT_ORDER_MISMATCH"),
            (lambda rows: rows.__setitem__(slice(1, 3), [rows[2], rows[1]]), "INTERVAL_RECEIPT_ORDER_MISMATCH"),
        )
        for mutate, reason in mutations:
            with self.subTest(reason=reason):
                documents = copy.deepcopy(self.documents)
                rows = provider_bundle.symbol_record(documents["pass1"], "XAUUSD")["interval_results"]
                mutate(rows)
                self.assert_refused(documents, "XAUUSD", reason)

    def test_repeat_mismatch_and_unstable_snapshot_are_refused(self) -> None:
        documents = copy.deepcopy(self.documents)
        row = provider_bundle.symbol_record(documents["pass2"], "XAUUSD")["interval_results"][3]
        row["copy"]["count"] += 1
        row["copy"]["valid_bid_ask"] += 1
        self.assert_refused(documents, "XAUUSD", "REPEAT_IDENTITY_MISMATCH")

        documents = copy.deepcopy(self.documents)
        provider_bundle.symbol_record(documents["pass1"], "XAUUSD")["rate_snapshots_stable"] = False
        self.assert_refused(documents, "XAUUSD", "RATE_SNAPSHOT_CHANGED")

    def test_malformed_counts_and_times_are_refused(self) -> None:
        fields = (
            ("count", True, "MALFORMED_COUNT"),
            ("valid_bid_ask", -1, "MALFORMED_VALID_BID_ASK_COUNT"),
            ("first_time_msc", 1.5, "MALFORMED_FIRST_TIME_MSC"),
            ("last_time_msc", 0, "MALFORMED_LAST_TIME_MSC"),
        )
        for field, value, reason in fields:
            with self.subTest(field=field):
                documents = copy.deepcopy(self.documents)
                row = provider_bundle.symbol_record(documents["pass1"], "XAUUSD")["interval_results"][1]
                row["copy"][field] = value
                self.assert_refused(documents, "XAUUSD", reason)

    def test_future_profile_and_candidate_role_mismatch_are_refused(self) -> None:
        documents = copy.deepcopy(self.documents)
        frozen = provider_bundle.symbol_record(documents["frozen"], "XAUUSD")
        frozen["selection"]["intervals"][0]["end"] = frozen["selection"]["candidate_open"] + 1
        self.assert_refused(documents, "XAUUSD", "FUTURE_PROFILE_INTERVAL")

        documents = copy.deepcopy(self.documents)
        provider_bundle.symbol_record(documents["pass1"], "XAUUSD")["interval_results"][-1]["role"] = "WARMUP"
        self.assert_refused(documents, "XAUUSD", "INTERVAL_RECEIPT_ORDER_MISMATCH")

    def test_bundle_is_deterministic_and_has_no_account_identity(self) -> None:
        first = provider_bundle.derive_bundle(self.documents, "EURUSD")
        second = provider_bundle.derive_bundle(self.documents, "EURUSD")
        first_bytes = provider_bundle.canonical_json_bytes(first)
        self.assertEqual(first_bytes, provider_bundle.canonical_json_bytes(second))
        self.assertEqual(first["bundle_sha256"], second["bundle_sha256"])
        flattened = first_bytes.decode("ascii").lower()
        for forbidden in ("account", "login", "password", "credential", "data_path"):
            self.assertNotIn(forbidden, flattened)

    def test_write_bundles_produces_six_stable_files(self) -> None:
        with tempfile.TemporaryDirectory() as first_dir, tempfile.TemporaryDirectory() as second_dir:
            first = provider_bundle.write_bundles(A2_ROOT, Path(first_dir))
            second = provider_bundle.write_bundles(A2_ROOT, Path(second_dir))
            self.assertEqual(first, second)
            self.assertEqual(first["accepted_symbols"], list(ACCEPTED))
            self.assertEqual(first["blocked_symbols"], list(BLOCKED))
            self.assertEqual(set(first["bundle_sha256"]), set(ACCEPTED))
            for symbol in ACCEPTED:
                self.assertEqual(
                    (Path(first_dir) / f"{symbol}.json").read_bytes(),
                    (Path(second_dir) / f"{symbol}.json").read_bytes(),
                )


if __name__ == "__main__":
    unittest.main()
