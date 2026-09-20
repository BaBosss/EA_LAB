#!/usr/bin/env python3
"""Focused positive and negative tests for the pure packet builder."""

from __future__ import annotations

import base64
import contextlib
import hashlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path


TOOLS_ROOT = Path(__file__).resolve().parents[2]
if str(TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOLS_ROOT))

from codex_budget import packet_builder as builder  # noqa: E402


HEAD = "7c6bdea7aa980eb1adabebb822785eb74cbc058f"
HASH_A = "a" * 64
HASH_B = "b" * 64


def task_input(mode: str | None = "NORMAL") -> dict:
    value = {
        "schema_version": "codex_budget_packet_input/1",
        "packet_type": "TASK_PACKET",
        "task_id": "BUDGET-PACKET-V1",
        "lane_id": "ct-codex-budget-packets-v1-20260919",
        "source_head": HEAD,
        "objective": "Build one bounded deterministic packet.",
        "allowed_paths": ["tools/codex_budget/packet_builder.py"],
        "forbidden_operations": ["runtime activation", "usage reporter transfer"],
        "authority_ceiling": ["SOURCE_ONLY", "NO_RUNTIME", "NO_MT5"],
        "direct_consumer": "Control Tower deterministic checks and separate exact-head GPT scrutiny",
        "downstream_skip": ["accepted EA source/runtime suites", "old usage-reporter tests"],
        "unique_output": "AUTHOR_RESULT.json",
        "source_records": [{"locator": "tools/codex_budget/packet_builder.py", "sha256": HASH_A}],
        "evidence_records": [{"locator": "D:\\EA_LAB_CONTROL\\evidence\\packet\\CONTRACT.md", "sha256": HASH_B}],
        "required_gates": [{"gate_id": "focused-tests", "requirement": "Run the focused unit tests."}],
        "repair_used": 1,
        "repair_limit": 1,
    }
    if mode is not None:
        value["mode"] = mode
    return value


def review_input() -> dict:
    value = task_input()
    value.update({
        "packet_type": "REVIEW_PACKET",
        "author_job_id": "author-job",
        "author_lane_id": "author-lane",
        "reviewer_job_id": "reviewer-job",
        "reviewer_lane_id": "reviewer-lane",
        "reviewed_head": HEAD,
        "evidence_identity": "frozen-evidence-v1",
    })
    return value


def encoded(value: dict) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


class PacketBuilderTests(unittest.TestCase):
    def test_schema_and_runtime_expose_the_same_closed_fields(self) -> None:
        schema = json.loads(Path(builder.__file__).with_name("packet.schema.json").read_bytes())
        task_schema = schema["$defs"]["task"]
        review_schema = schema["$defs"]["review"]
        self.assertEqual(set(task_schema["properties"]), builder.COMMON_FIELDS)
        self.assertEqual(set(task_schema["required"]), builder.REQUIRED_COMMON_FIELDS)
        self.assertEqual(set(review_schema["properties"]), builder.COMMON_FIELDS | builder.REVIEW_FIELDS)
        self.assertEqual(set(review_schema["required"]), builder.REQUIRED_COMMON_FIELDS | builder.REVIEW_FIELDS)

    def test_task_is_deterministic_and_default_mode_is_normal(self) -> None:
        raw = encoded(task_input(None))
        first, first_bytes = builder.build_packet(raw)
        second, second_bytes = builder.build_packet(raw)
        self.assertEqual(first, second)
        self.assertEqual(first_bytes, second_bytes)
        self.assertEqual(first["payload"]["packet"]["mode"], "NORMAL")
        self.assertEqual(first["payload"]["boot_mini"]["next"], "TASK_PACKET")
        self.assertEqual(first["payload"]["packet"]["repair_used"], 1)
        self.assertEqual(first["payload"]["packet"]["repair_limit"], 1)

    def test_modes_have_identical_acceptance_content(self) -> None:
        normal, _ = builder.build_packet(encoded(task_input("NORMAL")))
        economy, _ = builder.build_packet(encoded(task_input("ECONOMY")))
        self.assertEqual(
            normal["payload"]["packet"]["acceptance_requirements"],
            economy["payload"]["packet"]["acceptance_requirements"],
        )
        self.assertTrue(normal["payload"]["packet"]["mode_metadata"]["recommendation_only"])
        self.assertTrue(economy["payload"]["packet"]["mode_metadata"]["recommendation_only"])

    def test_receipt_binds_actual_input_policy_and_payload_bytes(self) -> None:
        raw = encoded(task_input())
        envelope, _ = builder.build_packet(raw)
        receipt = envelope["receipt"]
        payload_bytes = builder._compact(envelope["payload"])
        self.assertEqual(receipt["input_sha256"], hashlib.sha256(raw).hexdigest())
        self.assertEqual(receipt["policy_sha256"], hashlib.sha256(builder.POLICY_PATH.read_bytes()).hexdigest())
        self.assertEqual(receipt["output_payload_sha256"], hashlib.sha256(payload_bytes).hexdigest())
        self.assertIn("cannot self-hash", receipt["receipt_scope"])

    def test_declared_hash_and_verified_supplied_bytes_are_distinguished(self) -> None:
        value = task_input()
        supplied = b"evidence bytes on demand"
        value["evidence_records"][0] = {
            "locator": "evidence/payload.bin",
            "sha256": hashlib.sha256(supplied).hexdigest(),
            "bytes_base64": base64.b64encode(supplied).decode("ascii"),
        }
        envelope, _ = builder.build_packet(encoded(value))
        packet = envelope["payload"]["packet"]
        self.assertEqual(packet["evidence_records"][0]["verification"], "VERIFIED_SUPPLIED_BYTES")
        self.assertEqual(packet["source_records"][0]["verification"], "DECLARED_NOT_RECOMPUTED")
        self.assertNotIn("bytes_base64", packet["evidence_records"][0])

    def test_bad_supplied_bytes_refuse(self) -> None:
        value = task_input()
        value["evidence_records"][0]["bytes_base64"] = base64.b64encode(b"wrong").decode("ascii")
        with self.assertRaisesRegex(builder.PacketError, "do not match"):
            builder.build_packet(encoded(value))

    def test_review_requires_distinct_jobs_lanes_and_matching_head(self) -> None:
        for field, replacement, message in (
            ("reviewer_job_id", "author-job", "distinct from author job"),
            ("reviewer_lane_id", "author-lane", "distinct from author lane"),
            ("reviewed_head", "0" * 40, "must exactly equal"),
        ):
            value = review_input()
            value[field] = replacement
            with self.subTest(field=field), self.assertRaisesRegex(builder.PacketError, message):
                builder.build_packet(encoded(value))

    def test_review_preserves_evidence_identity_and_authority(self) -> None:
        envelope, _ = builder.build_packet(encoded(review_input()))
        packet = envelope["payload"]["packet"]
        self.assertEqual(packet["evidence_identity"], "frozen-evidence-v1")
        self.assertEqual(packet["authority_ceiling"], ["SOURCE_ONLY", "NO_RUNTIME", "NO_MT5"])

    def test_task_preserves_every_contract_routing_and_scope_field(self) -> None:
        source = task_input()
        envelope, _ = builder.build_packet(encoded(source))
        packet = envelope["payload"]["packet"]
        for field in (
            "objective", "allowed_paths", "forbidden_operations", "authority_ceiling",
            "direct_consumer", "downstream_skip", "unique_output", "required_gates",
            "repair_used", "repair_limit",
        ):
            self.assertEqual(packet[field], source[field])
        self.assertTrue(envelope["payload"]["boot_mini"]["navigation_only"])
        self.assertIn("Not a substitute", envelope["payload"]["boot_mini"]["warning"])

    def test_missing_or_empty_authority_and_gates_refuse(self) -> None:
        for field, replacement in (("authority_ceiling", []), ("required_gates", [])):
            value = task_input()
            value[field] = replacement
            with self.subTest(field=field), self.assertRaises(builder.PacketError):
                builder.build_packet(encoded(value))
        value = task_input()
        del value["authority_ceiling"]
        with self.assertRaisesRegex(builder.PacketError, "closed contract"):
            builder.build_packet(encoded(value))

    def test_duplicate_keys_and_unknown_fields_refuse(self) -> None:
        with self.assertRaisesRegex(builder.PacketError, "duplicate JSON key"):
            builder.load_json_bytes(b'{"packet_type":"TASK_PACKET","packet_type":"REVIEW_PACKET"}')
        value = task_input()
        value["surprise"] = True
        with self.assertRaisesRegex(builder.PacketError, "unknown"):
            builder.build_packet(encoded(value))

    def test_malformed_hash_head_mode_nan_and_negative_refuse(self) -> None:
        cases = []
        value = task_input(); value["source_head"] = "abc"; cases.append(value)
        value = task_input(); value["source_records"][0]["sha256"] = "xyz"; cases.append(value)
        value = task_input(); value["mode"] = "TURBO"; cases.append(value)
        value = task_input(); value["repair_used"] = -1; cases.append(value)
        for value in cases:
            with self.subTest(value=value), self.assertRaises(builder.PacketError):
                builder.build_packet(encoded(value))
        raw = encoded(task_input()).replace(b'"repair_used":1', b'"repair_used":NaN')
        with self.assertRaisesRegex(builder.PacketError, "non-finite"):
            builder.build_packet(raw)

    def test_invalid_repair_budget_refuses_and_exhausted_budget_is_preserved(self) -> None:
        value = task_input(); value["repair_used"] = 2
        with self.assertRaisesRegex(builder.PacketError, "cannot exceed"):
            builder.build_packet(encoded(value))
        envelope, _ = builder.build_packet(encoded(task_input()))
        packet = envelope["payload"]["packet"]
        self.assertEqual((packet["repair_used"], packet["repair_limit"]), (1, 1))

    def test_duplicate_and_conflicting_locators_refuse(self) -> None:
        for digest in (HASH_A, HASH_B):
            value = task_input()
            value["source_records"].append({"locator": "TOOLS/codex_budget/packet_builder.py", "sha256": digest})
            with self.subTest(digest=digest), self.assertRaisesRegex(builder.PacketError, "duplicate or case-ambiguous locator"):
                builder.build_packet(encoded(value))

    def test_cross_array_duplicate_and_case_variant_conflicts_refuse(self) -> None:
        cases = (
            ("tools/codex_budget/packet_builder.py", HASH_A),
            ("TOOLS/CODEX_BUDGET/PACKET_BUILDER.PY", HASH_B),
        )
        for locator, digest in cases:
            value = task_input()
            value["evidence_records"][0] = {"locator": locator, "sha256": digest}
            with self.subTest(locator=locator, digest=digest), self.assertRaisesRegex(
                builder.PacketError, "duplicate or case-ambiguous locator"
            ):
                builder.build_packet(encoded(value))

    def test_traversal_ambiguous_paths_and_output_names_refuse(self) -> None:
        mutations = (
            ("allowed_paths", ["tools/../secret"]),
            ("allowed_paths", ["tools\\packet.py"]),
            ("unique_output", "../AUTHOR_RESULT.json"),
            ("unique_output", "nested/AUTHOR_RESULT.json"),
        )
        for field, replacement in mutations:
            value = task_input(); value[field] = replacement
            with self.subTest(field=field, replacement=replacement), self.assertRaises(builder.PacketError):
                builder.build_packet(encoded(value))
        value = task_input(); value["evidence_records"][0]["locator"] = "D:\\evidence\\..\\secret"
        with self.assertRaisesRegex(builder.PacketError, "traversal"):
            builder.build_packet(encoded(value))

    def test_source_head_is_only_syntax_validated(self) -> None:
        envelope, _ = builder.build_packet(encoded(task_input()))
        self.assertEqual(envelope["payload"]["packet"]["verification_limits"]["source_head"], "SYNTAX_VALIDATED_NOT_GIT_ACCEPTED")

    def test_write_is_create_only_and_preserves_input(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            input_path = root / "input.json"
            raw = encoded(task_input())
            input_path.write_bytes(raw)
            output = builder.write_packet(input_path, root)
            self.assertEqual(input_path.read_bytes(), raw)
            first_output = output.read_bytes()
            with self.assertRaisesRegex(builder.PacketError, "already exists"):
                builder.write_packet(input_path, root)
            self.assertEqual(output.read_bytes(), first_output)

    def test_cli_creates_unique_output_and_reports_digests(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            input_path = root / "input.json"
            input_path.write_bytes(encoded(task_input()))
            stdout, stderr = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                result = builder.main(["--input", str(input_path), "--output-dir", str(root)])
            self.assertEqual(result, 0, stderr.getvalue())
            summary = json.loads(stdout.getvalue())
            self.assertEqual(summary["status"], "CREATED")
            self.assertEqual(summary["source_head"], HEAD)
            self.assertEqual(len(summary["input_sha256"]), 64)
            self.assertEqual(len(summary["policy_sha256"]), 64)

    def test_cli_refusal_returns_two_and_preserves_existing_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            input_path = root / "input.json"
            input_path.write_bytes(encoded(task_input()))
            existing = root / "AUTHOR_RESULT.json"
            existing.write_bytes(b"preserve me")
            stdout, stderr = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                result = builder.main(["--input", str(input_path), "--output-dir", str(root)])
            self.assertEqual(result, 2)
            self.assertEqual(stdout.getvalue(), "")
            self.assertIn("REFUSED", stderr.getvalue())
            self.assertEqual(existing.read_bytes(), b"preserve me")

    def test_policy_and_output_make_no_saving_or_activation_claim(self) -> None:
        policy_text = builder.POLICY_PATH.read_text(encoding="utf-8").casefold()
        envelope, _ = builder.build_packet(encoded(task_input("ECONOMY")))
        output_text = json.dumps(envelope).casefold()
        self.assertNotIn("tokens saved", policy_text + output_text)
        self.assertNotIn("quota saved", policy_text + output_text)
        self.assertEqual(envelope["payload"]["packet"]["verification_limits"]["runtime"], "NOT_ACTIVATED")

    def test_policy_is_closed_and_cannot_add_mode_specific_acceptance(self) -> None:
        policy = json.loads(builder.POLICY_PATH.read_bytes())
        policy["modes"]["NORMAL"]["acceptance_requirements"] = ["weaker gate"]
        with self.assertRaisesRegex(builder.PacketError, "packaged canonical"):
            builder.build_packet(encoded(task_input()), encoded(policy))

    def test_mutated_policy_values_and_bytes_refuse(self) -> None:
        canonical = builder.POLICY_PATH.read_bytes()
        mutated = json.loads(canonical)
        mutated["modes"]["ECONOMY"]["subagents"] = "ON"
        for supplied in (encoded(mutated), canonical + b"\n"):
            with self.subTest(supplied_sha256=hashlib.sha256(supplied).hexdigest()), self.assertRaisesRegex(
                builder.PacketError, "byte-identical"
            ):
                builder.build_packet(encoded(task_input()), supplied)


if __name__ == "__main__":
    unittest.main()
