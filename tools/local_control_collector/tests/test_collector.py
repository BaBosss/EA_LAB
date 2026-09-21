from __future__ import annotations

import copy
import hashlib
import json
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "tools" / "local_control_collector" / "collector.py"
sys.path.insert(0, str(TOOL.parent))

import collector  # noqa: E402


AS_OF = "2026-09-21T12:00:00Z"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_codex_home(root: Path, rows: list[tuple] | None = None) -> Path:
    home = root / "codex"
    home.mkdir()
    db = sqlite3.connect(home / "state_5.sqlite")
    db.execute(
        "CREATE TABLE threads(thread_id TEXT PRIMARY KEY,updated_at_ms INTEGER,"
        "tokens_used INTEGER,model TEXT,reasoning_effort TEXT,initial_prompt TEXT,"
        "parent_thread_id TEXT,agent_role TEXT)"
    )
    db.executemany(
        "INSERT INTO threads VALUES(?,?,?,?,?,?,?,?)",
        rows
        or [
            ("t-root", 1_795_000_000_000, 100, "gpt-5", "high", "lane-a", None, "root"),
            ("t-child", 1_795_000_000_100, 25, "gpt-5-mini", None, "secret=abc", "t-root", "worker"),
        ],
    )
    db.commit()
    db.close()
    history = sqlite3.connect(home / "thread_history_1.sqlite")
    history.execute("CREATE TABLE thread_history(thread_id TEXT,item_type TEXT)")
    history.executemany(
        "INSERT INTO thread_history VALUES(?,?)",
        [("t-root", "user"), ("t-root", "assistant"), ("t-child", "assistant")],
    )
    history.commit()
    history.close()
    return home


def make_v3_codex_home(root: Path) -> Path:
    home = root / "codex-v3"
    home.mkdir()
    db = sqlite3.connect(home / "state_5.sqlite")
    db.execute("CREATE TABLE threads(id TEXT PRIMARY KEY,updated_at_ms INTEGER,tokens_used INTEGER,model TEXT,reasoning_effort TEXT,title TEXT,source TEXT,thread_source TEXT)")
    source = json.dumps({"subagent": {"thread_spawn": {"parent_thread_id": "parent-1"}}})
    db.executemany("INSERT INTO threads VALUES(?,?,?,?,?,?,?,?)", [
        ("parent-1", 1, 100, "gpt", "high", "bounded title", "vscode", "user"),
        ("child-1", 2, 25, "gpt-mini", "low", "token=secret", source, "subagent"),
    ])
    db.commit()
    db.close()
    history = sqlite3.connect(home / "thread_history_1.sqlite")
    history.execute("CREATE TABLE thread_turns(thread_id TEXT,turn_id TEXT)")
    history.executemany("INSERT INTO thread_turns VALUES(?,?)", [("parent-1", "1"), ("parent-1", "2"), ("child-1", "3")])
    history.commit()
    history.close()
    return home


class CollectorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_readonly_db_bytes_unchanged_and_lifetime_is_not_delta(self) -> None:
        home = make_codex_home(self.root)
        before = {p.name: digest(p) for p in home.glob("*.sqlite")}
        usage = collector.collect_codex_usage([home], AS_OF, {}, None)
        self.assertEqual(before, {p.name: digest(p) for p in home.glob("*.sqlite")})
        self.assertEqual(usage["threads"][0]["current_lifetime_tokens"], 25)
        self.assertIsNone(usage["threads"][0]["delta_tokens"])
        self.assertEqual(usage["threads"][0]["delta_status"], "INITIAL")
        self.assertIn("lifetime", usage["truth_note"].lower())

    def test_initial_positive_null_and_counter_decrease(self) -> None:
        home = make_codex_home(
            self.root,
            [
                ("initial", 1, 10, "m", "low", "lane-a", None, "root"),
                ("positive", 2, 50, "m", "low", "lane-a", None, "root"),
                ("null", 3, None, "m", "low", "lane-a", None, "root"),
                ("decrease", 4, 20, "m", "low", "lane-a", None, "root"),
            ],
        )
        prior = {"positive": 35, "null": 1, "decrease": 30}
        usage = collector.collect_codex_usage([home], AS_OF, {}, prior)
        rows = {row["thread_id"]: row for row in usage["threads"]}
        self.assertEqual(rows["initial"]["delta_status"], "INITIAL")
        self.assertEqual(rows["positive"]["delta_tokens"], 15)
        self.assertEqual(rows["positive"]["delta_status"], "DELTA_OK")
        self.assertEqual(rows["null"]["delta_status"], "UNKNOWN")
        self.assertIsNone(rows["null"]["delta_tokens"])
        self.assertEqual(rows["decrease"]["delta_status"], "COUNTER_DECREASED_UNKNOWN")
        self.assertIsNone(rows["decrease"]["delta_tokens"])

    def test_missing_and_corrupt_db_are_unavailable(self) -> None:
        missing = self.root / "missing"
        missing.mkdir()
        corrupt = self.root / "corrupt"
        corrupt.mkdir()
        (corrupt / "state_5.sqlite").write_bytes(b"not sqlite")
        result = collector.collect_codex_usage([missing, corrupt], AS_OF, {}, None)
        self.assertEqual(result["status"], "UNAVAILABLE")
        self.assertEqual(result["threads"], [])

    def test_v3_layout_uses_turns_and_structured_parent_without_prompt_dump(self) -> None:
        home = make_v3_codex_home(self.root)
        usage = collector.collect_codex_usage([home], AS_OF, {}, None)
        rows = {row["thread_id"]: row for row in usage["threads"]}
        self.assertEqual(usage["status"], "AVAILABLE")
        self.assertEqual(rows["parent-1"]["invocation_count"], 2)
        self.assertEqual(rows["child-1"]["parent_thread_id"], "parent-1")
        self.assertEqual(rows["child-1"]["identity"], "CHILD")
        self.assertNotIn("secret", rows["child-1"]["label"])

    def test_exact_and_ambiguous_lane_mapping(self) -> None:
        home = make_codex_home(self.root)
        mappings = {
            "t-root": [collector.Identity("lane-a", "milestone-a", "AUTHOR")],
            "t-child": [
                collector.Identity("lane-a", None, None),
                collector.Identity("lane-b", None, None),
            ],
        }
        usage = collector.collect_codex_usage([home], AS_OF, mappings, None)
        rows = {row["thread_id"]: row for row in usage["threads"]}
        self.assertEqual(rows["t-root"]["lane_id"], "lane-a")
        self.assertEqual(rows["t-root"]["role"], "AUTHOR")
        self.assertEqual(rows["t-child"]["lane_id"], "UNKNOWN")
        self.assertEqual(rows["t-child"]["mapping_status"], "AMBIGUOUS")

    def test_malformed_registry_job_and_evidence_fail_closed(self) -> None:
        registry = collector.parse_registry({"result": "AUDIT", "records": [{"lane_id": "x"}]})
        job = collector.parse_job_outputs("x", "j", "{bad", "{}", None, None)
        evidence = collector.parse_evidence(self.root / "missing.json")
        self.assertEqual(registry["status"], "UNAVAILABLE")
        self.assertEqual(job["status"], "UNAVAILABLE")
        self.assertEqual(evidence["status"], "UNKNOWN")

    def test_recognized_evidence_has_binding_and_unknown_contract_is_unknown(self) -> None:
        path = self.root / "review.json"
        path.write_text(
            json.dumps(
                {
                    "schema_version": "EA_LAB_REVIEW_RESULT_V1",
                    "verdict": "PASS",
                    "confidence": "HIGH",
                    "decision": "ALLOW",
                    "findings": ["none"],
                    "reviewed_head": "a" * 40,
                }
            ),
            encoding="utf-8",
        )
        row = collector.parse_evidence(path)
        self.assertEqual(row["status"], "AVAILABLE")
        self.assertEqual(row["sha256"], digest(path))
        path.write_text('{"schema_version":"OTHER"}', encoding="utf-8")
        self.assertEqual(collector.parse_evidence(path)["status"], "UNKNOWN")

    def test_path_overlap_is_segment_aware(self) -> None:
        self.assertTrue(collector.paths_overlap("tools/x", "tools/x/a.py"))
        self.assertTrue(collector.paths_overlap("tools/x/**", "tools/x/a.py"))
        self.assertFalse(collector.paths_overlap("tools/x", "tools/xyz/a.py"))

    def test_secret_and_absolute_path_redaction(self) -> None:
        text = collector.safe_label(r"token=abc C:\\Users\\patip\\secret prompt body", 80)
        self.assertNotIn("abc", text)
        self.assertNotIn("patip", text.lower())
        self.assertLessEqual(len(text), 80)

    def test_closed_schema_rejects_unknown_field(self) -> None:
        packet = collector.empty_packet(AS_OF)
        collector.validate_packet(packet)
        bad = copy.deepcopy(packet)
        bad["unexpected"] = True
        with self.assertRaises(collector.Refusal):
            collector.validate_packet(bad)
        nested = copy.deepcopy(packet)
        nested["daily_aggregation"]["by_lane"] = [{"lane_id": "x", "delta_tokens": 1, "extra": 2}]
        with self.assertRaises(collector.Refusal):
            collector.validate_packet(nested)

    def test_valid_registry_and_allowed_critical_overlap(self) -> None:
        record = {
            "lane_id": "other", "state": "RUNNING", "writer": True, "owner_chat": "chat",
            "classification": "ACTIVE_CURRENT", "head_sha": "a" * 40, "reviewed_head": "",
            "blocker_class": "", "updated_at": AS_OF, "worktree": r"D:\\worktrees\\other",
            "allowed_paths": ["tools/**"], "critical_paths": ["tools/local_control_collector/**"],
        }
        registry = collector.parse_registry({"result": "AUDIT", "records": [record]})
        git = {"changed_paths": ["tools/local_control_collector/collector.py"], "overlap": []}
        collector.add_overlap(git, registry, None)
        self.assertEqual(registry["status"], "AVAILABLE")
        self.assertEqual(git["overlap"][0]["classification"], "CRITICAL")
        self.assertEqual(git["overlap"][0]["allowed_paths"], ["tools/**"])

    def test_valid_job_output_preserves_canonical_decisions(self) -> None:
        status = json.dumps({"job_id": "job-1", "state": "RUNNING", "runner_alive": True, "child_alive": True, "postcondition_alive": False})
        retry = json.dumps({"job_id": "job-1", "state": "RUNNING", "runner_alive": True, "child_alive": True, "postcondition_alive": False, "retry_decision": "REFUSE_RETRY", "reason": "live"})
        row = collector.parse_job_outputs("lane-a", "job-1", status, retry, {"job_id": "job-1"}, {"job_id": "job-1"}, 2.5, "UNKNOWN")
        self.assertEqual(row["status"], "AVAILABLE")
        self.assertTrue(row["runner_alive"])
        self.assertEqual(row["retry_decision"], "REFUSE_RETRY")
        self.assertRegex(row["lease_identity"], r"^[0-9a-f]{64}$")

    def test_output_ledger_is_external_append_only_and_create_only(self) -> None:
        repo = self.root / "repo"
        repo.mkdir()
        output = self.root / "operator-output"
        packet = collector.empty_packet(AS_OF)
        collector.write_outputs(output, repo, packet)
        ledger_before = (output / "snapshots.jsonl").read_bytes()
        self.assertTrue(ledger_before.endswith(b"\n"))
        with self.assertRaises(collector.Refusal):
            collector.write_outputs(output, repo, packet)
        self.assertEqual((output / "snapshots.jsonl").read_bytes(), ledger_before)
        with self.assertRaises(collector.Refusal):
            collector.assert_output_root(repo / "evidence", repo)
        with self.assertRaises(collector.Refusal):
            collector.assert_output_root(Path("relative-output"), repo)

    def test_invalid_observation_thresholds_refuse(self) -> None:
        for thresholds in ([1], [2, 2], [-1, 2], [3, 2]):
            with self.subTest(thresholds=thresholds), self.assertRaises(collector.Refusal):
                collector.aggregate_usage([], thresholds)

    def test_daily_aggregation_uses_only_valid_deltas(self) -> None:
        rows = [
            {"thread_id": "a", "delta_status": "DELTA_OK", "delta_tokens": 12, "lane_id": "l", "milestone": "m", "model": "g", "reasoning_effort": "high", "role": "AUTHOR", "invocation_count": 2},
            {"thread_id": "b", "delta_status": "COUNTER_DECREASED_UNKNOWN", "delta_tokens": None, "lane_id": "l", "milestone": "m", "model": "g", "reasoning_effort": "high", "role": "AUTHOR", "invocation_count": 3},
        ]
        aggregate = collector.aggregate_usage(rows, [10, 20])
        self.assertEqual(aggregate["valid_delta_tokens"], 12)
        self.assertEqual(aggregate["observed_thread_count"], 2)
        self.assertEqual(aggregate["observed_invocation_count"], 5)
        self.assertEqual(aggregate["observation_signal"], "ELEVATED")

    def test_cli_fixture_output_is_deterministic_and_no_scheduler_mutation(self) -> None:
        home = make_codex_home(self.root)
        repo = self.root / "repo"
        repo.mkdir()
        subprocess.run(["git", "init", str(repo)], check=True, capture_output=True)
        subprocess.run(["git", "-C", str(repo), "config", "user.email", "a@b.invalid"], check=True)
        subprocess.run(["git", "-C", str(repo), "config", "user.name", "A"], check=True)
        (repo / "a.txt").write_text("a", encoding="utf-8")
        subprocess.run(["git", "-C", str(repo), "add", "a.txt"], check=True)
        subprocess.run(["git", "-C", str(repo), "commit", "-m", "init"], check=True, capture_output=True)
        args = [
            sys.executable,
            str(TOOL),
            "--repo-root",
            str(repo),
            "--codex-home",
            str(home),
            "--as-of",
            AS_OF,
            "--skip-registry",
            "--skip-remote-observe",
        ]
        first = subprocess.run(args, capture_output=True, text=True, check=True).stdout
        second = subprocess.run(args, capture_output=True, text=True, check=True).stdout
        self.assertEqual(first, second)
        value = json.loads(first)
        self.assertFalse(value["runtime_mutation"])
        self.assertEqual(value["installation_actions"], [])
        self.assertNotIn("scheduler", " ".join(value.keys()).lower())


if __name__ == "__main__":
    unittest.main()
