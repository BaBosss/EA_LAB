import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import control_tower as ct
import build_index

NOW = "2026-09-10T10:00:00Z"
SOURCE = {"path": "PROJECT_STATE.md", "canonical_sha": "a" * 40, "sha256": "b" * 64}


class ControlTowerTests(unittest.TestCase):
    def audit(self, rows, stamp=NOW):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "audit.json"
            path.write_text(json.dumps({"result": "AUDIT", "generated_at": stamp, "records": rows}))
            return ct.registry_projection(path, NOW, build_index.safe_lane_id)

    def lane(self, **changes):
        return dict({"lane_id": "worker-1", "state": "RUNNING", "updated_at": NOW,
                     "classification": "ACTIVE_CURRENT", "blocker_class": ""}, **changes)

    def test_preserves_waiting_review_integrating_and_paused(self):
        for state in ("WAITING", "READY", "REVIEW", "INTEGRATING", "PAUSED", "BLOCKED"):
            self.assertEqual(self.audit([self.lane(state=state)])["rows"][0]["state"], state)

    def test_missing_registry_is_not_empty_current(self):
        value = ct.registry_projection(None, NOW, build_index.safe_lane_id)
        self.assertEqual(value["status"], "UNAVAILABLE")

    def test_missing_file_malformed_json_and_wrong_envelope(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "missing"
            self.assertEqual(ct.registry_projection(path, NOW, str)["reason"], "INVALID_INPUT")
            for value in ("{", "[]", '{"records":[]}', '{"result":"AUDIT","records":[null]}'):
                path.write_text(value)
                self.assertEqual(ct.registry_projection(path, NOW, str)["reason"], "INVALID_INPUT")

    def test_empty_audit_is_available_only_with_timestamp(self):
        self.assertEqual(self.audit([])["status"], "AVAILABLE")
        self.assertEqual(self.audit([], "invalid")["status"], "UNAVAILABLE")

    def test_stale_envelope_suppresses_running_and_owner_action(self):
        value = self.audit([self.lane(blocker_class="E_OWNER_EXTERNAL")], "2026-09-01T00:00:00Z")
        self.assertEqual(value["rows"][0]["state"], "UNKNOWN")
        self.assertFalse(value["rows"][0]["owner_required"])

    def test_future_envelope_and_future_row(self):
        for stamp in ("2026-09-11T00:00:00Z", "invalid", "2026-09-10T10:00:00"):
            self.assertEqual(self.audit([self.lane()], stamp)["rows"][0]["state"], "UNKNOWN")
            self.assertEqual(self.audit([self.lane(updated_at=stamp)])["rows"][0]["state"], "UNKNOWN")

    def test_aged_active_and_identity_conflict(self):
        self.assertEqual(self.audit([self.lane(classification="ACTIVE_AGED")])["rows"][0]["state"], "UNKNOWN")
        self.assertEqual(self.audit([self.lane(classification="ACTIVE_IDENTITY_MISMATCH")])["rows"][0]["state"], "CONFLICT")

    def test_owner_requires_explicit_current_e_class(self):
        self.assertTrue(self.audit([self.lane(blocker_class="E_OWNER_EXTERNAL")])["rows"][0]["owner_required"])
        for blocker in ("ENVIRONMENT", "C", "", None):
            self.assertFalse(self.audit([self.lane(blocker_class=blocker)])["rows"][0]["owner_required"])

    def test_runtime_is_unknown_and_generic_owner_prose_is_not_action(self):
        projection = ct.build_projection("owner approval required", SOURCE, [], None, NOW, str)
        self.assertEqual(projection["need_boss"], [])
        self.assertTrue(all(item["state"] == "UNKNOWN" for item in projection["runtime"]))

    def test_specific_global_declaration_only(self):
        self.assertEqual(ct.project_projection("old DEGRADED_MONITORING", SOURCE)["global_state"], "UNKNOWN")
        self.assertEqual(ct.project_projection("**Global state: `DEGRADED_MONITORING`.**", SOURCE)["global_state"], "DEGRADED_MONITORING")
        self.assertEqual(ct.project_projection("**Global state: `DEGRADED_MONITORING`.**\r\n", SOURCE)["global_state"], "DEGRADED_MONITORING")

    def test_exact_current_base_build_includes_manifest_parts(self):
        root = Path(__file__).resolve().parents[3]
        sha = "389159d960d312a2a4f304f5becfee699b127b01"
        with tempfile.TemporaryDirectory() as directory:
            index = build_index.build(root, sha, Path(directory), NOW, sha, None)
        self.assertEqual(index["control_tower"]["project"]["global_state"], "DEGRADED_MONITORING")
        self.assertGreater(len(index["control_tower"]["work"]), 0)
        paths = {row["provenance"]["path"] for row in index["control_tower"]["work"]}
        self.assertTrue({"taskboards/active/P01.md", "taskboards/active/P02.md", "taskboards/active/P03.md"}.issubset(paths))

    def test_same_id_disagreement_keeps_both_source_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "audit.json"
            path.write_text(json.dumps({"result": "AUDIT", "generated_at": NOW,
                                       "records": [self.lane(lane_id="ORDER-1", blocker_class="E")]}))
            value = ct.build_projection("", SOURCE, [("## ORDER-1 - title `DONE`", SOURCE)], path, NOW, str)
        self.assertEqual(value["work"][0]["state"], "CONFLICT")
        self.assertEqual(value["registry"]["rows"][0]["state"], "CONFLICT")
        self.assertEqual(value["need_boss"], [])

    def test_plan_boundary_and_order_are_literal_not_ready(self):
        text = "### 5.1 NOW\n1. **First.** Context\n2. **Second.** More\n### 5.2 NEXT\n3. **Excluded.** X"
        result = ct.project_projection(text, SOURCE)
        self.assertEqual([item["priority"] for item in result["next"]], [1, 2])
        self.assertTrue(all(item["state"] == "UNKNOWN" for item in result["next"]))

    def test_open_is_not_ready_and_ambiguous_state_is_conflict(self):
        rows = ct.task_rows("## ORDER-1 — title `OPEN`\n## ORDER-2 — title `DONE / BLOCKED`", SOURCE)
        self.assertEqual([row["state"] for row in rows], ["UNKNOWN", "CONFLICT"])

    def test_status_span_is_not_last_code_span(self):
        rows = ct.task_rows("## ORDER-1 — `symbol` title — `WAITING` — `config`", SOURCE)
        self.assertEqual(rows[0]["state"], "WAITING")

    def test_duplicate_canonical_ids_are_conflict(self):
        projection = ct.build_projection("", SOURCE, [("## ORDER-1 — title `DONE`\n## ORDER-1 — title `RUNNING`", SOURCE)], None, NOW, str)
        self.assertEqual([row["state"] for row in projection["work"]], ["CONFLICT", "CONFLICT"])

    def test_runtime_free_text_and_account_ids_not_exported(self):
        row = self.lane(lane_id="account-463666728", objective="secret", runtime_lane="D:\\Meta 5")
        text = json.dumps(self.audit([row]))
        self.assertNotIn("463666728", text)
        self.assertNotIn("secret", text)
        self.assertNotIn("Meta 5", text)

    def test_public_git_text_suppresses_numeric_id_and_path(self):
        self.assertNotIn("463666728", ct.public_text("account 463666728 at D:\\secret\\file"))
        self.assertNotIn("secret", ct.public_text("account 463666728 at D:\\secret\\file"))


if __name__ == "__main__":
    unittest.main()
