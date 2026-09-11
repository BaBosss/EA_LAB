import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
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

    def test_graph_projects_only_consumed_audit_metadata(self):
        row = self.audit([self.lane(head_sha="a" * 40, writer=True, blocker_class="E_OWNER_EXTERNAL",
                                   objective="do not export", worker="https://secret", branch="https://secret",
                                   worktree="https://private/secret", reviewer="<secret>", reviewed_head="b" * 40)])['rows'][0]
        self.assertEqual(row['head_sha'], 'a' * 40)
        self.assertEqual(row['role'], 'WRITER')
        self.assertEqual(row['registry_classification'], 'ACTIVE_CURRENT')
        self.assertEqual(row['blocker_class'], 'E')
        self.assertNotIn('secret', json.dumps(row))
        self.assertNotIn('objective', row)

    def metadata_lane(self, **changes):
        metadata = dict(worker='Codex-Primary', branch='ct/monitor-v31-final-r2-20260911',
                        worktree=r'D:\EA_LAB_CONTROL\worktrees\monitor-v31-final-r2-20260911',
                        reviewer='ChatGPT-Control-Tower', head_sha='a' * 40, reviewed_head='a' * 40,
                        head_matches_record=True)
        metadata.update(changes)
        return self.lane(**metadata)

    def test_realistic_structured_metadata_and_review(self):
        row = self.audit([self.metadata_lane()])['rows'][0]
        self.assertEqual(row['worker'], 'Codex-Primary')
        self.assertEqual(row['ref'], 'ct/monitor-v31-final-r2-20260911')
        self.assertEqual(row['worktree'], 'monitor-v31-final-r2-20260911')
        self.assertEqual(row['reviewer'], 'ChatGPT-Control-Tower')
        self.assertEqual(row['reviewed_head'], 'a' * 40)
        self.assertEqual(row['review_state'], 'REVIEWED_EXACT_HEAD')
        self.assertNotIn('EA_LAB_CONTROL', json.dumps(row))
        self.assertEqual(self.audit([self.metadata_lane(state='REVIEW')])['rows'][0]['review_state'], 'REVIEW_ACTIVE')
        for name in ('monitor-v31-final-integration-20260911', 'monitor-v31-final-r2-20260911'):
            self.assertEqual(ct.registry_identifier('ct/' + name, branch=True), 'ct/' + name)
            self.assertEqual(ct.registry_worktree('D:/EA_LAB_CONTROL/worktrees/' + name), name)
        for field in ('provider', 'model', 'pid', 'session', 'heartbeat', 'log_tail'):
            self.assertEqual(row.get(field, 'UNKNOWN'), 'UNKNOWN')

    def test_metadata_rejects_unsafe_values_without_truncating(self):
        bad = ('https://evil.test/a', '//evil.test/a', 'account-1234', 'login-user', 'acct-123',
               'worker-123456789', '123456789', 'Codex\nPrimary', 'Codex\rPrimary', 'Codex\x00',
               '<script>', 'worker&tag', 'x' * 161, None, 42, {}, 'Codex\tPrimary')
        for value in bad:
            for field in ('worker', 'branch', 'reviewer', 'worktree'):
                with self.subTest(value=value, field=field):
                    row = self.audit([self.metadata_lane(**{field: value})])['rows'][0]
                    self.assertEqual(row['ref' if field == 'branch' else field], 'UNKNOWN')
        for field in ('worker', 'branch', 'reviewer'):
            for value in (r'D:\private\worker', '/private/worker'):
                row = self.audit([self.metadata_lane(**{field: value})])['rows'][0]
                self.assertEqual(row['ref' if field == 'branch' else field], 'UNKNOWN')
        for field in ('worker', 'reviewer'):
            self.assertEqual(self.audit([self.metadata_lane(**{field: 'private/worker'})])['rows'][0][field], 'UNKNOWN')
        for value in (r'D:\private\account-1234', r'D:\private\worker-123456789', '../worker', 'D:/bad\n/worker'):
            self.assertEqual(ct.registry_worktree(value), 'UNKNOWN')

    def test_review_claim_requires_eligible_exact_evidence(self):
        for changes in ({'reviewed_head': 'b' * 40}, {'head_sha': 'bad'}, {'classification': 'ACTIVE_AGED'},
                        {'classification': 'ACTIVE_IDENTITY_MISMATCH'}, {'updated_at': '2026-09-01T00:00:00Z'}):
            self.assertEqual(self.audit([self.metadata_lane(**changes)])['rows'][0]['review_state'], 'UNKNOWN')
        for value in ('A' * 40, 'a' * 39, 'a' * 41, 'a' * 40 + '\n', None, 42, 'UNKNOWN'):
            row = self.audit([self.metadata_lane(reviewed_head=value)])['rows'][0]
            self.assertEqual(row['reviewed_head'], 'UNKNOWN')
            self.assertEqual(row['review_state'], 'UNKNOWN')
        for state in ('REVIEW', 'FROZEN'):
            self.assertEqual(self.audit([self.metadata_lane(state=state)], '2026-09-01T00:00:00Z')['rows'][0]['review_state'], 'UNKNOWN')
        rows = self.audit([self.metadata_lane(), self.metadata_lane()])['rows']
        self.assertTrue(all(row['review_state'] == 'UNKNOWN' for row in rows))

    def test_git_registry_conflict_suppresses_review_claim(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'audit.json'
            path.write_text(json.dumps({'result': 'AUDIT', 'generated_at': NOW,
                                        'records': [self.metadata_lane(lane_id='ORDER-1')]}))
            result = ct.build_projection('', SOURCE, [('## ORDER-1 - title `DONE`', SOURCE)], path, NOW, str)
        self.assertEqual(result['registry']['rows'][0]['review_state'], 'UNKNOWN')

    def test_review_identity_from_actual_audit_through_graph(self):
        root = Path(__file__).resolve().parents[3]
        head = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
        old_head = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD^'], text=True).strip()
        branch = subprocess.check_output(['git', '-C', str(root), 'branch', '--show-current'], text=True).strip()
        self.assertNotEqual(head, old_head)
        now = datetime.now(timezone.utc).isoformat()
        with tempfile.TemporaryDirectory() as directory:
            registry = Path(directory) / 'registry'
            registry.mkdir()
            for state in ('BLOCKED', 'WAITING', 'PAUSED', 'FROZEN'):
                for mode in ('exact', 'moved', 'missing-worktree'):
                    recorded = old_head if mode == 'moved' else head
                    lane_id = state.lower() + '-' + mode
                    record = dict(lane_id=lane_id, owner_chat='review-fixture', worker='Codex',
                                  objective='Review identity fixture', state=state, base_sha=old_head,
                                  head_sha=recorded, reviewed_head=recorded, reviewer='Independent-Reviewer',
                                  worktree=str(Path(directory) / 'absent') if mode == 'missing-worktree' else str(root),
                                  branch=branch, allowed_paths=[], critical_paths=[], writer=False,
                                  dependencies=[], direct_consumer='review-test', updated_at=now)
                    (registry / (lane_id + '.json')).write_text(json.dumps(record), encoding='utf-8')
            audit_text = subprocess.check_output([
                'powershell.exe', '-NoProfile', '-File', str(root / 'scripts/lane_registry.ps1'),
                '-Command', 'Audit', '-RegistryRoot', str(registry), '-RepoRoot', str(root), '-Json'
            ], text=True)
            audit = json.loads(audit_text)
            audit_path = Path(directory) / 'audit.json'
            audit_path.write_text(audit_text, encoding='utf-8')
            dto = ct.registry_projection(audit_path, now, build_index.safe_lane_id)
            graph_code = """
const g = require('./mobile_report_hub/agent_graph.js');
let input = '';
process.stdin.on('data', chunk => input += chunk).on('end', () => {
  const model = g.buildModel({registry: JSON.parse(input)});
  console.log(JSON.stringify(model.nodes.map(node => ({
    node: g.inspect(model, node.key).node,
    context: g.steeringContext(model, node.key, 'REVIEW')
  }))));
});
"""
            graph = json.loads(subprocess.check_output(['node', '-e', graph_code], cwd=root,
                                                      input=json.dumps(dto), text=True))
        for state in ('BLOCKED', 'WAITING', 'PAUSED', 'FROZEN'):
            for mode in ('exact', 'moved', 'missing-worktree'):
                with self.subTest(state=state, mode=mode):
                    lane_id = state.lower() + '-' + mode
                    source = next(row for row in audit['records'] if row['lane_id'] == lane_id)
                    row = next(row for row in dto['rows'] if row['id'] == lane_id)
                    rendered = next(item for item in graph if item['node']['id'] == lane_id)
                    self.assertIs(source['head_matches_record'],
                                  True if mode == 'exact' else False if mode == 'moved' else None)
                    if state != 'FROZEN':
                        self.assertEqual(source['classification'], 'QUEUED_CURRENT')
                    expected = 'REVIEWED_EXACT_HEAD' if mode == 'exact' else 'UNKNOWN'
                    self.assertEqual(row['review_state'], expected)
                    self.assertEqual(rendered['node']['review_state'], expected)
                    for projected in (row, rendered['node']):
                        self.assertEqual(projected['reviewer'], 'Independent-Reviewer')
                        self.assertEqual(projected['reviewed_head'], source['head_sha'])
                    self.assertIn(source['head_sha'], rendered['context'])

    def test_review_identity_requires_explicit_boolean_true(self):
        for state in ('BLOCKED', 'WAITING', 'PAUSED', 'FROZEN'):
            for identity in (False, None, 'true', 'false', 1, 0):
                with self.subTest(state=state, identity=identity):
                    row = self.audit([self.metadata_lane(state=state, head_matches_record=identity)])['rows'][0]
                    self.assertEqual(row['review_state'], 'UNKNOWN')
                    self.assertEqual(row['reviewed_head'], 'a' * 40)
            record = self.metadata_lane(state=state)
            del record['head_matches_record']
            self.assertEqual(self.audit([record])['rows'][0]['review_state'], 'UNKNOWN')
        # Queued classification never proved branch identity; do not add that requirement.
        row = self.audit([self.metadata_lane(state='WAITING', classification='QUEUED_CURRENT',
                                            branch_matches_record=False)])['rows'][0]
        self.assertEqual(row['review_state'], 'REVIEWED_EXACT_HEAD')

    def test_review_requires_qualified_reviewer_and_reviewed_head(self):
        for state in ('BLOCKED', 'WAITING', 'PAUSED', 'FROZEN'):
            for reviewer in (None, '', 'UNKNOWN', '<reviewer>', 'account-1234'):
                with self.subTest(state=state, reviewer=reviewer):
                    row = self.audit([self.metadata_lane(state=state, reviewer=reviewer)])['rows'][0]
                    self.assertEqual(row['review_state'], 'UNKNOWN')
                    self.assertEqual(row['reviewer'], 'UNKNOWN')
                    self.assertEqual(row['reviewed_head'], 'a' * 40)
            for field in ('reviewer', 'reviewed_head'):
                record = self.metadata_lane(state=state)
                del record[field]
                self.assertEqual(self.audit([record])['rows'][0]['review_state'], 'UNKNOWN')
            row = self.audit([self.metadata_lane(state=state, reviewed_head='b' * 40)])['rows'][0]
            self.assertEqual(row['review_state'], 'UNKNOWN')
            self.assertEqual(row['reviewed_head'], 'b' * 40)

    def test_graph_rejects_malformed_sha_and_coerced_writer(self):
        for sha in ('abc123', 'a' * 41, 'A' * 40, 42, None, 'D:/secret'):
            row = self.audit([self.lane(head_sha=sha, writer='true')])['rows'][0]
            self.assertEqual(row['head_sha'], 'UNKNOWN')
            self.assertEqual(row['role'], 'UNKNOWN')
        self.assertEqual(self.audit([self.lane(writer=False)])['rows'][0]['role'], 'READ_ONLY')

    def test_graph_dependencies_require_explicit_safe_exact_ids(self):
        row = self.audit([self.lane(dependencies=['prerequisite', 'missing', 'account-463666728', {'id': 'injected'}])])['rows'][0]
        self.assertEqual(row['direct_dependencies'], ['prerequisite', 'missing', 'UNKNOWN', 'UNKNOWN'])
        self.assertEqual(self.audit([self.lane(dependencies=[])])['rows'][0]['direct_dependencies'], [])
        for value in (None, 'guessed', {}):
            self.assertEqual(self.audit([self.lane(dependencies=value)])['rows'][0]['direct_dependencies'], 'UNKNOWN')

    def test_duplicate_registry_identifiers_suppress_owner_derivation(self):
        rows = self.audit([self.lane(blocker_class='E'), self.lane(blocker_class='E')])['rows']
        self.assertEqual([r['state'] for r in rows], ['CONFLICT', 'CONFLICT'])
        self.assertFalse(any(r['owner_required'] for r in rows))

    def test_graph_never_exports_blocker_prose_or_unknown_classification(self):
        row = self.audit([self.lane(blocker_class='E / token=secret', classification='secret')])['rows'][0]
        self.assertEqual(row['blocker_class'], 'E')
        self.assertEqual(row['registry_classification'], 'UNKNOWN')
        self.assertNotIn('secret', json.dumps(row))
        self.assertFalse(row['owner_required'])


if __name__ == "__main__":
    unittest.main()
