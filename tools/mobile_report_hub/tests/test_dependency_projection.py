"""Registry file -> actual PowerShell Audit -> safe DTO -> graph regression."""
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_index
import control_tower

ROOT = Path(__file__).resolve().parents[3]


class DependencyProjectionTests(unittest.TestCase):
    def pipeline(self, dependencies, *, mode="current", options=None):
        now = datetime.now(timezone.utc)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            records = []
            for lane_id in ("prerequisite-20260911", "consumer-20260911"):
                record = dict(lane_id=lane_id, owner_chat="fixture-owner", worker="Codex",
                              objective="uncontrolled prose must not escape", state="WAITING",
                              base_sha="a" * 40, head_sha="a" * 40,
                              worktree=str(root / "absent-worktree"), branch="ct/fixture",
                              allowed_paths=[], critical_paths=[], writer=False,
                              dependencies=dependencies if lane_id.startswith("consumer") else [],
                              direct_consumer="fixture", updated_at=now.isoformat())
                records.append(record)
            if mode == "stale":
                records[1]["updated_at"] = (now - timedelta(days=2)).isoformat()
            if mode == "stale_target":
                records[0]["updated_at"] = (now - timedelta(days=2)).isoformat()
            if mode == "duplicate":
                records.append(dict(records[0], state="BLOCKED"))
            for i, record in enumerate(records):
                (root / f"lane-{i}.json").write_text(json.dumps(record), encoding="utf-8")
            result = subprocess.run([
                "powershell.exe", "-NoProfile", "-File", str(ROOT / "scripts/lane_registry.ps1"),
                "-Command", "Audit", "-RegistryRoot", str(root), "-RepoRoot", str(root / "no-repo"), "-Json"
            ], capture_output=True, text=True, check=True)
            audit = json.loads(result.stdout)
            self.assertEqual(audit["records"][1].get("dependencies"), dependencies)
            path = root / "audit-output.json"
            path.write_text(json.dumps(audit), encoding="utf-8")
            dto = control_tower.registry_projection(path, now.isoformat(), build_index.safe_lane_id)
            program = "const g=require('./mobile_report_hub/agent_graph.js');const x=JSON.parse(require('fs').readFileSync(0,'utf8'));const m=g.buildModel({registry:x.dto},x.options);console.log(JSON.stringify({model:m,html:g.renderHTML(m)}));"
            output = subprocess.run(["node", "-e", program], cwd=ROOT,
                                    input=json.dumps(dict(dto=dto, options=options or {})),
                                    text=True, capture_output=True, check=True)
            graph = json.loads(output.stdout)
            self.assertNotIn(str(root), json.dumps(dto))
            self.assertNotIn("uncontrolled prose", json.dumps(dto))
            return dto, graph

    def test_explicit_dependency_survives_real_audit_and_renders(self):
        dto, graph = self.pipeline(["prerequisite-20260911"])
        self.assertEqual(dto["rows"][1]["direct_dependencies"], ["prerequisite-20260911"])
        self.assertEqual([e["type"] for e in graph["model"]["edges"]], ["DEPENDENCY"])
        self.assertIn("<strong>DEPENDENCY</strong>", graph["html"])

    def test_unresolved_target_stays_visible(self):
        _, graph = self.pipeline(["missing-20260911"])
        self.assertEqual(graph["model"]["edges"], [])
        self.assertIn("UNRESOLVED DEPENDENCY", graph["html"])

    def test_unknown_and_empty_dependencies_create_no_edge(self):
        for deps in (None, [], "prerequisite-20260911"):
            dto, graph = self.pipeline(deps)
            self.assertEqual(graph["model"]["edges"], [])
            self.assertEqual(dto["rows"][1]["direct_dependencies"], [] if deps == [] else "UNKNOWN")

    def test_duplicate_target_is_conflicting_and_unresolved(self):
        _, graph = self.pipeline(["prerequisite-20260911"], mode="duplicate")
        self.assertEqual(graph["model"]["edges"], [])
        self.assertIn("CONFLICT", [n["state"] for n in graph["model"]["nodes"]])
        self.assertIn("UNRESOLVED DEPENDENCY", graph["html"])

    def test_stale_source_cannot_claim_dependency(self):
        dto, graph = self.pipeline(["prerequisite-20260911"], mode="stale")
        self.assertEqual(dto["rows"][1]["direct_dependencies"], "UNKNOWN")
        self.assertEqual(graph["model"]["edges"], [])

    def test_stale_target_is_unresolved(self):
        _, graph = self.pipeline(["prerequisite-20260911"], mode="stale_target")
        self.assertEqual(graph["model"]["edges"], [])
        self.assertIn("UNRESOLVED DEPENDENCY", graph["html"])

    def test_cached_offline_cannot_claim_dependency(self):
        for options in ({"cached": True}, {"offline": True}):
            _, graph = self.pipeline(["prerequisite-20260911"], options=options)
            self.assertEqual(graph["model"]["edges"], [])
            self.assertTrue(all(n["dependency_evidence"] == "UNKNOWN" for n in graph["model"]["nodes"]))

    def test_hostile_dependencies_stay_inside_safe_dto(self):
        hostile = ["<script>alert(1)</script>", "x" * 1000, "account-463666728",
                   "D:\\private\\worktree", {"id": "prerequisite-20260911"}]
        dto, graph = self.pipeline(hostile)
        self.assertEqual(dto["rows"][1]["direct_dependencies"], ["UNKNOWN"] * len(hostile))
        self.assertEqual(graph["model"]["edges"], [])
        for value in hostile[:4]:
            self.assertNotIn(value, json.dumps(dto))


if __name__ == "__main__":
    unittest.main()
