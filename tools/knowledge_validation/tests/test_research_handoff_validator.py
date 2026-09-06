from __future__ import annotations

import copy
import importlib.util
import json
import unittest
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
HANDOFF_PATH = REPO_ROOT / "knowledge/11_readiness_evals/SECOND_BRAIN_READINESS_HANDOFF_EXACT749.json"
NEGATIVE_PATH = Path(__file__).resolve().parent / "fixtures/research_handoff_negative_cases.json"
SPEC = importlib.util.spec_from_file_location("research_handoff_validator", TOOL_ROOT / "research_handoff_validator.py")
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def set_path(document: dict, dotted_path: str, value: object) -> None:
    parts = dotted_path.split(".")
    cursor: object = document
    for part in parts[:-1]:
        cursor = cursor[int(part)] if isinstance(cursor, list) else cursor[part]  # type: ignore[index]
    if isinstance(cursor, list):
        cursor[int(parts[-1])] = value
    else:
        cursor[parts[-1]] = value  # type: ignore[index]


class ResearchHandoffValidatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.handoff = json.loads(HANDOFF_PATH.read_text(encoding="utf-8"))
        cls.negative_cases = json.loads(NEGATIVE_PATH.read_text(encoding="utf-8"))

    def test_actual_six_question_handoff_is_source_bound_and_blocked(self) -> None:
        result = MODULE.validate_handoff(copy.deepcopy(self.handoff), REPO_ROOT)
        self.assertEqual("PASS", result["validation_status"])
        self.assertEqual("VALIDATED_RESEARCH_ONLY", result["handoff_readiness"])
        self.assertEqual("BLOCKED_UNRESOLVED_SEMANTICS", result["execution_readiness"])
        self.assertEqual(6, result["question_count"])
        self.assertGreater(result["citation_count"], 6)
        self.assertFalse(result["automatic_store_write"])
        self.assertFalse(result["semantic_correctness_proven"])

    def test_machine_readable_negative_cases_refuse(self) -> None:
        for case in self.negative_cases:
            with self.subTest(case=case["case_id"]):
                mutated = copy.deepcopy(self.handoff)
                set_path(mutated, case["mutation"]["path"], case["mutation"]["value"])
                result = MODULE.validate_handoff(mutated, REPO_ROOT)
                self.assertEqual("REFUSED", result["validation_status"])
                self.assertIn(case["expected_error"], {error["code"] for error in result["errors"]})
                self.assertFalse(result["automatic_store_write"])

    def test_malformed_handoff_refuses_without_store_write(self) -> None:
        result = MODULE.validate_handoff([], REPO_ROOT)
        self.assertEqual("REFUSED", result["validation_status"])
        self.assertEqual("INVALID_INPUT_NOT_OBJECT", result["errors"][0]["code"])
        self.assertFalse(result["automatic_store_write"])


if __name__ == "__main__":
    unittest.main()
