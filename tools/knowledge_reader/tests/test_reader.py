import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from reader import (
    ReaderError, build_index, matches, offline_html, query_packet,
)


def run(cwd: Path, *args: str) -> str:
    completed = subprocess.run(args, cwd=cwd, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return completed.stdout.strip()


def put(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


class ReaderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name) / "repo"
        self.repo.mkdir()
        run(self.repo, "git", "init", "-q")
        run(self.repo, "git", "config", "user.email", "reader@example.invalid")
        run(self.repo, "git", "config", "user.name", "Reader Test")
        source = "# Source\n\nOrder Flow source claim.\n"
        source_hash = hashlib.sha256(source.encode()).hexdigest()
        put(self.repo / "knowledge/README.md", "# Brain\n")
        put(self.repo / "knowledge/00_indexes/SECOND_BRAIN_INDEX.md", "# Index\n\n[card](../02_research_cards/RC-1.md)\n")
        put(self.repo / "knowledge/01_sources/SRC-ONE.md", source)
        registry = {"source_id": "SRC-ONE", "source_type": "note", "title": "One", "locator": "knowledge/01_sources/SRC-ONE.md", "sha256": source_hash, "status": "REGISTERED_DERIVED", "authority": "RESEARCH_ONLY"}
        put(self.repo / "knowledge/01_sources/source_registry.jsonl", json.dumps(registry) + "\n")
        put(self.repo / "knowledge/02_research_cards/RC-1.md", "---\ncard_type: RESEARCH_CARD\ncard_id: RC-1\nsource_id: SRC-ONE\n---\n# EA risk ภาษาไทย\n\n## SOURCE_CLAIM\nOrder Flow, not Seafood. <script>window.pwned=1</script>\n")
        put(self.repo / "knowledge/90_negative_knowledge/risk.md", "# Risk negative knowledge\n\nSRC-ONE says EA risk failed.\n")
        run(self.repo, "git", "add", ".")
        run(self.repo, "git", "commit", "-qm", "fixture")
        self.sha = run(self.repo, "git", "rev-parse", "HEAD")

    def tearDown(self):
        self.temp.cleanup()

    def build(self, **kwargs):
        return build_index(self.repo, self.sha, self.sha, **kwargs)

    def test_exact_ref_ignores_dirty_checkout(self):
        (self.repo / "knowledge/02_research_cards/RC-1.md").write_text("# DIRTY Seafood only", encoding="utf-8")
        data = self.build()
        card = next(row for row in data["documents"] if row["id"] == "RC-1")
        self.assertIn("Order Flow", card["body"])
        self.assertNotIn("DIRTY", card["body"])

    def test_registry_hash_binding_and_line_refs(self):
        data = self.build()
        card = next(row for row in data["documents"] if row["id"] == "RC-1")
        self.assertEqual(card["authority_class"], "REGISTERED_RESEARCH")
        self.assertTrue(any(row["section"] == "SOURCE_CLAIM" for row in card["line_refs"]))
        self.assertEqual(data["health"]["registry_binding_problem_count"], 0)

    def test_search_boundaries_and_thai(self):
        data = self.build(); card = next(row for row in data["documents"] if row["id"] == "RC-1")
        seafood = {**card, "title": "Seafood", "body": "Seafood market", "topics": [], "source_ids": []}
        self.assertTrue(matches(card, "EA")); self.assertFalse(matches(seafood, "EA"))
        self.assertTrue(matches(card, "ภาษา")); self.assertFalse(matches(card, "ไม่พบ"))

    def test_negative_memory_is_explicit(self):
        data = self.build()
        packet = query_packet(data, "EA risk", {})
        self.assertEqual(packet["negative_memory"]["status"], "MATCH")
        self.assertTrue(all(packet["problem_intake"][key] is None for key in packet["problem_intake"]))
        packet2 = query_packet(data, "Demon Beam", {})
        self.assertEqual(packet2["negative_memory"]["status"], "NO_MATCH")
        self.assertTrue(packet2["unresolved_evidence_caveats"])

    def test_pin_mismatch_fails(self):
        with self.assertRaisesRegex(ReaderError, "pin mismatch"):
            build_index(self.repo, self.sha, "0" * 40)

    def packet(self, bad_path=None, tamper=False):
        root = Path(self.temp.name) / "packet"; root.mkdir(exist_ok=True)
        relative = bad_path or "knowledge/02_research_cards/DRAFT.md"
        target = root / "knowledge/02_research_cards/DRAFT.md"; put(target, "---\ncard_id: DRAFT-1\nsource_id: SRC-DRAFT\n---\n# Draft\n")
        raw = target.read_bytes()
        manifest = {"schema": "derived-packet-manifest/1", "files": [{"path": relative, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}]}
        manifest_path = root / "MANIFEST_SHA256.json"; manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        digest = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
        if tamper: target.write_text("tampered", encoding="utf-8")
        return root, digest

    def test_draft_separation_and_manifest_tamper(self):
        root, digest = self.packet(); data = self.build(packet=root, manifest_sha=digest)
        draft = next(row for row in data["documents"] if row["authority_class"] == "DRAFT_NOT_IMPORTED")
        self.assertIsNone(draft["path"]); self.assertEqual(data["health"]["draft_documents"], 1)
        root2, digest2 = self.packet(tamper=True)
        with self.assertRaisesRegex(ReaderError, "hash/size mismatch"):
            self.build(packet=root2, manifest_sha=digest2)

    def test_manifest_path_escape_fails_before_consumption(self):
        root, digest = self.packet(bad_path="../outside.md")
        with self.assertRaisesRegex(ReaderError, "unsafe path"):
            self.build(packet=root, manifest_sha=digest)

    @unittest.skipUnless(hasattr(os, "symlink"), "symlink unsupported")
    def test_manifest_symlink_refused(self):
        root = Path(self.temp.name) / "linked"; root.mkdir()
        outside = Path(self.temp.name) / "outside.md"; outside.write_text("# outside", encoding="utf-8")
        target = root / "knowledge/02_research_cards/LINK.md"; target.parent.mkdir(parents=True)
        try: os.symlink(outside, target)
        except OSError: self.skipTest("symlink privilege unavailable")
        raw = outside.read_bytes(); manifest = {"files": [{"path": "knowledge/02_research_cards/LINK.md", "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}]}
        manifest_path = root / "MANIFEST_SHA256.json"; manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        digest = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ReaderError, "symlink"):
            self.build(packet=root, manifest_sha=digest)

    def test_offline_payload_escapes_script_termination(self):
        output = offline_html(self.build(), "window.EALabKnowledgeReader={mount(){}}", "body{}")
        self.assertNotIn("<script>window.pwned", output)
        self.assertIn("\\u003cscript", output)
        self.assertNotIn("fetch(", output)


if __name__ == "__main__":
    unittest.main()
