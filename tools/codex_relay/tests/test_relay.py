import json
import tempfile
import unittest
from pathlib import Path

from codex_relay.relay import ControlTowerRelay, FakeCodexAdapter, RelayError


class RelayTests(unittest.TestCase):
    def make_relay(self, adapter=None, polls_to_finish=0):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        return ControlTowerRelay(
            Path(temp.name),
            adapter=adapter or FakeCodexAdapter(polls_to_finish=polls_to_finish),
            codex_cwd=temp.name,
            default_timeout_seconds=30,
        )

    def test_success_identity_evidence_and_idempotent_result(self):
        adapter = FakeCodexAdapter()
        relay = self.make_relay(adapter)
        job = relay.dispatch_codex("tower-task-1", b"exact\x00prompt")
        job_id = job["job_id"]
        status = relay.get_codex_status(job_id)
        self.assertEqual(status["state"], "DONE")
        result = relay.get_codex_result(job_id)
        again = relay.get_codex_result(job_id)
        self.assertEqual(result, again)
        self.assertEqual(result["job_id"], job_id)
        self.assertIn("exact", result["raw_stdout"])
        self.assertEqual(job["prompt_sha256"], relay._load(job_id)["prompt_sha256"])
        self.assertEqual(adapter.started[0][1], b"exact\x00prompt")

    def test_distinct_jobs_cannot_cross_results(self):
        relay = self.make_relay(FakeCodexAdapter())
        first = relay.dispatch_codex("one", "alpha")
        second = relay.dispatch_codex("two", "bravo")
        first_result = relay.get_codex_result(first["job_id"])
        second_result = relay.get_codex_result(second["job_id"])
        self.assertIn("alpha", first_result["final_text"])
        self.assertIn("bravo", second_result["final_text"])
        with self.assertRaises(RelayError):
            relay.get_codex_result("0" * 31 + "1")

    def test_blocked_failed_and_cancelled_are_distinct(self):
        relay = self.make_relay(FakeCodexAdapter(["BLOCKED", "FAILED"], polls_to_finish=0))
        blocked = relay.dispatch_codex("blocked", "b")
        failed = relay.dispatch_codex("failed", "f")
        self.assertEqual(relay.get_codex_status(blocked["job_id"])["state"], "BLOCKED")
        self.assertEqual(relay.get_codex_status(failed["job_id"])["state"], "FAILED")
        cancel_relay = self.make_relay(FakeCodexAdapter(polls_to_finish=5))
        cancelled = cancel_relay.dispatch_codex("cancel", "c")
        self.assertEqual(cancel_relay.get_codex_status(cancelled["job_id"])["state"], "RUNNING")
        self.assertEqual(cancel_relay.cancel_codex(cancelled["job_id"])["state"], "CANCELLED")

    def test_timeout_is_failed_and_raw_evidence_is_retained(self):
        relay = self.make_relay(FakeCodexAdapter(polls_to_finish=10))
        job = relay.dispatch_codex("timeout", "wait", timeout_seconds=0.001)
        relay._handles[job["job_id"]].started_monotonic -= 1
        status = relay.get_codex_status(job["job_id"])
        self.assertEqual(status["state"], "FAILED")
        result = relay.get_codex_result(job["job_id"])
        self.assertEqual(result["error"], "TIMEOUT")

    def test_launch_failure_is_clear(self):
        class Broken(FakeCodexAdapter):
            def start(self, prompt, cwd, attempt_no):
                raise RelayError("Codex unavailable")

        relay = self.make_relay(Broken())
        job = relay.dispatch_codex("unavailable", "p")
        self.assertEqual(job["state"], "FAILED")
        self.assertIn("unavailable", job["last_error"])

    def test_corrupt_metadata_and_result_identity_refuse(self):
        relay = self.make_relay(FakeCodexAdapter())
        job = relay.dispatch_codex("corrupt", "p")
        job_id = job["job_id"]
        metadata_path = relay._metadata_path(job_id)
        metadata_path.write_text("not json", encoding="utf-8")
        with self.assertRaises(RelayError):
            relay.get_codex_status(job_id)

        relay = self.make_relay(FakeCodexAdapter())
        job = relay.dispatch_codex("wrong-result", "p")
        result = relay.get_codex_result(job["job_id"])
        result_path = relay.state_dir / relay._load(job["job_id"])["attempts"][-1]["result_path"]
        result["job_id"] = "0" * 32
        result_path.write_text(json.dumps(result), encoding="utf-8")
        with self.assertRaises(RelayError):
            relay.get_codex_result(job["job_id"])

        relay = self.make_relay(FakeCodexAdapter())
        job = relay.dispatch_codex("wrong-evidence", "p")
        relay.get_codex_result(job["job_id"])
        result = relay.get_codex_result(job["job_id"])
        stdout_path = relay.state_dir / result["raw_stdout_path"]
        stdout_path.write_bytes(b"tampered")
        with self.assertRaises(RelayError):
            relay.get_codex_result(job["job_id"])

    def test_reload_terminal_and_lost_running_job(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        state = Path(temp.name)
        relay = ControlTowerRelay(state, adapter=FakeCodexAdapter(), codex_cwd=temp.name)
        done = relay.dispatch_codex("reload-done", "p")
        relay.get_codex_status(done["job_id"])
        reloaded = ControlTowerRelay(state, adapter=FakeCodexAdapter(), codex_cwd=temp.name)
        self.assertEqual(reloaded.get_codex_status(done["job_id"])["state"], "DONE")

        running_relay = ControlTowerRelay(state, adapter=FakeCodexAdapter(polls_to_finish=100), codex_cwd=temp.name)
        running = running_relay.dispatch_codex("reload-running", "p")
        self.assertEqual(running_relay.get_codex_status(running["job_id"])["state"], "RUNNING")
        lost = ControlTowerRelay(state, adapter=FakeCodexAdapter(), codex_cwd=temp.name)
        self.assertEqual(lost.get_codex_status(running["job_id"])["state"], "FAILED")
        self.assertEqual(lost.get_codex_result(running["job_id"])["error"], "PROCESS_LOST")

    def test_continuation_preserves_job_identity_and_session(self):
        adapter = FakeCodexAdapter()
        relay = self.make_relay(adapter)
        job = relay.dispatch_codex("continue", "first")
        relay.get_codex_status(job["job_id"])
        continued = relay.continue_codex(job["job_id"], "second")
        self.assertEqual(continued["job_id"], job["job_id"])
        status = relay.get_codex_status(job["job_id"])
        self.assertEqual(status["state"], "DONE")
        self.assertEqual(adapter.resumed[0][0], status["codex_session_id"])
        self.assertIn("second", relay.get_codex_result(job["job_id"])["final_text"])

    def test_continuation_launch_failure_has_terminal_evidence(self):
        class BrokenResume(FakeCodexAdapter):
            def resume(self, session_id, prompt, cwd, attempt_no):
                raise RelayError("resume unavailable")

        relay = self.make_relay(BrokenResume())
        job = relay.dispatch_codex("continue-fail", "first")
        relay.get_codex_status(job["job_id"])
        continued = relay.continue_codex(job["job_id"], "second")
        self.assertEqual(continued["state"], "FAILED")
        self.assertIn("resume unavailable", relay.get_codex_result(job["job_id"])["error"])


if __name__ == "__main__":
    unittest.main()
