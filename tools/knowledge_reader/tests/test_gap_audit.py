"""Deterministic fixtures for source-pinned Second Brain feedback drafts."""
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from gap_audit import audit, verified_evidence, main
from reader import ReaderError, build_index


def put(root, name, body):
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf8")
    return path


def git(root, *args):
    proc = subprocess.run(["git", "-C", str(root), *args], text=True,
                          capture_output=True, check=True)
    return proc.stdout.strip()


class GapAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        git(self.root, "init", "-q")
        git(self.root, "config", "user.name", "Fixture")
        git(self.root, "config", "user.email", "fixture@example.invalid")
        source = "# Source\n\nGrid research source.\n"
        path = "knowledge/01_sources/SRC-GRID.md"
        put(self.root, path, source)
        registry = {"source_id": "SRC-GRID", "source_type": "note",
                    "title": "Grid", "locator": path,
                    "sha256": hashlib.sha256(source.encode()).hexdigest(),
                    "status": "REGISTERED_DERIVED", "authority": "RESEARCH_ONLY"}
        put(self.root, "knowledge/README.md", "# Research only\n")
        put(self.root, "knowledge/00_indexes/SECOND_BRAIN_INDEX.md", "# Index\n")
        put(self.root, "knowledge/01_sources/source_registry.jsonl",
            json.dumps(registry) + "\n")
        put(self.root, "knowledge/02_research_cards/GRID.md",
            "---\ncard_type: RESEARCH_CARD\ncard_id: RC-GRID\nsource_id: SRC-GRID\n---\n"
            "# Grid strategy\n\n## SOURCE_CLAIM\nGrid is a mechanism.\n")
        put(self.root, "knowledge/90_negative_knowledge/grid.md",
            "# Grid negative\n\nGrid may incur margin pressure.\n")
        self.evidence_path = "docs/research/GRID_RECEIPT.md"
        body = "# Fixture receipt\n\nNO PERFORMANCE VERDICT\n"
        put(self.root, self.evidence_path, body)
        self.evidence_hash = hashlib.sha256(body.encode()).hexdigest()
        git(self.root, "add", ".")
        git(self.root, "commit", "-qm", "fixture")
        self.ref = git(self.root, "rev-parse", "HEAD")
        self.index = build_index(self.root, self.ref, self.ref)

    def test_no_evidence_never_claims_performance(self):
        evidence = verified_evidence(self.root, self.ref, None, None, None)
        result = audit(self.index, "Grid", {"ea": "B17", "symbol": "XAUUSD"}, evidence)
        self.assertEqual(result["intake_status"], "DRAFT_NOT_IMPORTED")
        self.assertIsNone(result["test_verdict"])
        self.assertIsNone(result["performance_grade"])
        self.assertIsNone(result["candidate_status"])
        self.assertFalse(result["qi_factory_authority"])
        self.assertEqual(result["automatic_actions"], [])
        self.assertEqual(result["negative_memory"]["status"], "MATCH")
        self.assertEqual(result["problem_intake"]["symbol"], "XAUUSD")
        self.assertIn("NO_VERIFIED_EXPERIMENT_POINTER", [x["kind"] for x in result["open_gaps"]])

    def test_byte_verified_pointer_is_not_test_verdict(self):
        proof = verified_evidence(self.root, self.ref, self.evidence_path,
                                  self.evidence_hash, "GRID-FIXTURE-01")
        result = audit(self.index, "Grid", {}, proof)
        self.assertEqual(proof["state"], "POINTER_VERIFIED_CONTENT_NOT_ADJUDICATED")
        self.assertIsNone(result["test_verdict"])
        self.assertTrue(result["review_required"])
        self.assertNotIn("NO_VERIFIED_EXPERIMENT_POINTER", [x["kind"] for x in result["open_gaps"]])

    def test_untrusted_and_mismatched_evidence_fail_closed(self):
        for path in ("../secrets.txt", "knowledge/01_sources/SRC-GRID.md", "docs/research/missing.md"):
            with self.subTest(path=path):
                with self.assertRaises(ReaderError):
                    verified_evidence(self.root, self.ref, path, self.evidence_hash, "TEST-1")
        with self.assertRaisesRegex(ReaderError, "hash mismatch"):
            verified_evidence(self.root, self.ref, self.evidence_path, "0" * 64, "TEST-1")
        with self.assertRaisesRegex(ReaderError, "supplied together"):
            verified_evidence(self.root, self.ref, self.evidence_path, None, "TEST-1")
        with self.assertRaisesRegex(ReaderError, "invalid experiment-id"):
            verified_evidence(self.root, self.ref, self.evidence_path,
                              self.evidence_hash, "../BAD")

    def test_pinned_source_ignores_dirty_file(self):
        (self.root / self.evidence_path).write_text("TAMPERED ON DISK", encoding="utf8")
        proof = verified_evidence(self.root, self.ref, self.evidence_path,
                                  self.evidence_hash, "TEST-1")
        self.assertEqual(proof["sha256"], self.evidence_hash)

    def test_negative_no_match_is_not_no_history(self):
        result = audit(self.index, "unrelated impossible query", {},
                       verified_evidence(self.root, self.ref, None, None, None))
        self.assertIn("NO_KEYWORD_MATCH", [x["kind"] for x in result["open_gaps"]])
        self.assertIn("NEGATIVE_MEMORY_NO_KEYWORD_MATCH", [x["kind"] for x in result["open_gaps"]])

    def test_index_tamper_is_rejected(self):
        changed = dict(self.index)
        changed["health"] = {**self.index["health"], "status": "OKAY"}
        with self.assertRaisesRegex(ReaderError, "unverified"):
            audit(changed, "Grid", {}, verified_evidence(self.root, self.ref, None, None, None))

    def test_cli_pin_mismatch_does_not_create_output(self):
        output = Path(self.temp.name) / "should_not_exist.json"
        code = main(["--repo", str(self.root), "--ref", self.ref,
                     "--expected-sha", "0" * 40, "--question", "Grid",
                     "--output", str(output)])
        self.assertEqual(code, 2)
        self.assertFalse(output.exists())

    def test_cli_positive_produces_draft(self):
        output = Path(self.temp.name) / "proposal.json"
        code = main(["--repo", str(self.root), "--ref", self.ref,
                     "--expected-sha", self.ref, "--question", "Grid",
                     "--evidence-path", self.evidence_path,
                     "--evidence-sha256", self.evidence_hash,
                     "--experiment-id", "TEST-1", "--output", str(output)])
        self.assertEqual(code, 0)
        value = json.loads(output.read_text(encoding="utf8"))
        self.assertEqual(value["canonical"]["sha"], self.ref)
        self.assertEqual(value["intake_status"], "DRAFT_NOT_IMPORTED")


if __name__ == "__main__":
    unittest.main()
