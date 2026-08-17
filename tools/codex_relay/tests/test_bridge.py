import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from codex_relay.bridge import run_request
from codex_relay.relay import ControlTowerRelay, FakeCodexAdapter


class BridgeTests(unittest.TestCase):
    def make_relay(self, adapter=None, polls_to_finish=0):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        return ControlTowerRelay(
            Path(temp.name),
            adapter=adapter or FakeCodexAdapter(polls_to_finish=polls_to_finish),
            codex_cwd=temp.name,
            default_timeout_seconds=30,
        )

    # 1. submit exact prompt -> receive unique Relay job
    def test_submit_exact_prompt_returns_unique_job(self):
        relay = self.make_relay(FakeCodexAdapter())
        resp = run_request(relay, {"op": "submit", "task_id": "ct-task-1", "prompt": "exact prompt text"})
        self.assertTrue(resp["ok"])
        self.assertEqual(resp["data"]["task_id"], "ct-task-1")
        job_id = resp["data"]["job_id"]
        self.assertRegex(job_id, r"^[0-9a-f]{32}$")
        second = run_request(relay, {"op": "submit", "task_id": "ct-task-1", "prompt": "exact prompt text"})
        self.assertNotEqual(second["data"]["job_id"], job_id)

    # 2. status request resolves the correct job
    def test_status_resolves_correct_job(self):
        relay = self.make_relay(FakeCodexAdapter())
        a = run_request(relay, {"op": "submit", "task_id": "task-a", "prompt": "alpha"})["data"]
        b = run_request(relay, {"op": "submit", "task_id": "task-b", "prompt": "bravo"})["data"]
        status_a = run_request(relay, {"op": "status", "job_id": a["job_id"]})
        status_b = run_request(relay, {"op": "status", "job_id": b["job_id"]})
        self.assertEqual(status_a["data"]["job_id"], a["job_id"])
        self.assertEqual(status_a["data"]["task_id"], "task-a")
        self.assertEqual(status_b["data"]["job_id"], b["job_id"])
        self.assertEqual(status_b["data"]["task_id"], "task-b")

    # 3. result request cannot return another job's result
    def test_result_cannot_return_another_jobs_result(self):
        relay = self.make_relay(FakeCodexAdapter())
        a = run_request(relay, {"op": "submit", "task_id": "task-a", "prompt": "alpha"})["data"]
        b = run_request(relay, {"op": "submit", "task_id": "task-b", "prompt": "bravo"})["data"]
        result_a = run_request(relay, {"op": "result", "job_id": a["job_id"]})
        result_b = run_request(relay, {"op": "result", "job_id": b["job_id"]})
        self.assertEqual(result_a["data"]["job_id"], a["job_id"])
        self.assertIn("alpha", result_a["data"]["final_text"])
        self.assertEqual(result_b["data"]["job_id"], b["job_id"])
        self.assertIn("bravo", result_b["data"]["final_text"])
        self.assertNotEqual(result_a["data"]["job_id"], result_b["data"]["job_id"])

    # 4. malformed job ID fails clearly
    def test_malformed_job_id_fails_clearly(self):
        relay = self.make_relay(FakeCodexAdapter())
        for bad in ["", "not-hex", "0" * 31, "0" * 33, None, 12345]:
            for op in ("status", "result", "cancel"):
                resp = run_request(relay, {"op": op, "job_id": bad})
                self.assertFalse(resp["ok"], msg="op=%s job_id=%r" % (op, bad))
                self.assertEqual(resp["error_type"], "BRIDGE_ERROR")

    # 5. malformed request fails clearly
    def test_malformed_request_fails_clearly(self):
        relay = self.make_relay(FakeCodexAdapter())
        cases = [
            {},
            {"op": "not-a-real-op"},
            {"op": "submit"},  # missing task_id/prompt
            {"op": "submit", "task_id": "", "prompt": "x"},
            {"op": "submit", "task_id": "t", "prompt": 12345},
            {"op": "submit", "task_id": "t", "prompt": "p", "timeout_seconds": -5},
            "not a dict",
            None,
        ]
        for request in cases:
            resp = run_request(relay, request)
            self.assertFalse(resp["ok"], msg="request=%r" % (request,))
            self.assertIn(resp["error_type"], {"BRIDGE_ERROR"})

    def test_cli_is_a_persistent_jsonlines_server_that_survives_a_bad_line(self):
        # One process handles two lines: a malformed one (must not crash the
        # loop -- the process is meant to stay alive for a whole Control
        # Tower session) followed by a well-formed one.
        run_bridge = Path(__file__).resolve().parents[1] / "run_bridge.py"
        with tempfile.TemporaryDirectory() as scratch:
            stdin_payload = b"{not json\n" + json.dumps({"op": "status", "job_id": "0" * 32}).encode("utf-8") + b"\n"
            result = subprocess.run(
                [sys.executable, str(run_bridge), "--state-dir", scratch],
                input=stdin_payload,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        self.assertEqual(result.returncode, 0, msg=result.stderr.decode("utf-8", "replace"))
        lines = [line for line in result.stdout.decode("utf-8").splitlines() if line.strip()]
        self.assertEqual(len(lines), 2)
        first = json.loads(lines[0])
        second = json.loads(lines[1])
        self.assertFalse(first["ok"])
        self.assertEqual(first["error_type"], "MALFORMED_REQUEST")
        self.assertFalse(second["ok"])
        self.assertEqual(second["error_type"], "JOB_NOT_FOUND")

    def test_relay_persistence_across_serve_calls_prevents_process_lost(self):
        # Regression test for the real E2E smoke finding: a job dispatched
        # through one call into the serve loop must be observable -- not
        # PROCESS_LOST -- by a later call, as long as the SAME relay
        # instance (i.e. the same live bridge process) handles both.
        from codex_relay.bridge import _serve

        relay = self.make_relay(FakeCodexAdapter(polls_to_finish=1))

        submit_out = io.BytesIO()
        _serve(
            relay,
            io.BytesIO(json.dumps({"op": "submit", "task_id": "t", "prompt": "p"}).encode("utf-8") + b"\n"),
            submit_out,
        )
        submit_resp = json.loads(submit_out.getvalue().decode("utf-8").strip())
        self.assertTrue(submit_resp["ok"])
        self.assertEqual(submit_resp["data"]["state"], "RUNNING")
        job_id = submit_resp["data"]["job_id"]

        status_out_1 = io.BytesIO()
        _serve(relay, io.BytesIO(json.dumps({"op": "status", "job_id": job_id}).encode("utf-8") + b"\n"), status_out_1)
        status_resp_1 = json.loads(status_out_1.getvalue().decode("utf-8").strip())
        self.assertIn(status_resp_1["data"]["state"], ("RUNNING", "DONE"))
        self.assertNotEqual(status_resp_1["data"].get("last_error"), "PROCESS_LOST")

        status_out_2 = io.BytesIO()
        _serve(relay, io.BytesIO(json.dumps({"op": "status", "job_id": job_id}).encode("utf-8") + b"\n"), status_out_2)
        status_resp_2 = json.loads(status_out_2.getvalue().decode("utf-8").strip())
        self.assertEqual(status_resp_2["data"]["state"], "DONE")

    # 6. backend failure propagates clearly
    def test_backend_failure_propagates_clearly(self):
        relay = self.make_relay(FakeCodexAdapter())
        unknown_job_id = "0" * 32
        resp = run_request(relay, {"op": "status", "job_id": unknown_job_id})
        self.assertFalse(resp["ok"])
        self.assertEqual(resp["error_type"], "JOB_NOT_FOUND")

        class Broken(FakeCodexAdapter):
            def start(self, prompt, cwd, attempt_no):
                from codex_relay.relay import RelayError

                raise RelayError("Codex unavailable")

        broken_relay = self.make_relay(Broken())
        submit = run_request(broken_relay, {"op": "submit", "task_id": "t", "prompt": "p"})
        self.assertTrue(submit["ok"])  # the bridge call itself succeeded
        self.assertEqual(submit["data"]["state"], "FAILED")
        self.assertIn("unavailable", submit["data"]["last_error"])

    # 7. repeated status polling is safe
    def test_repeated_status_polling_is_safe(self):
        relay = self.make_relay(FakeCodexAdapter())
        job = run_request(relay, {"op": "submit", "task_id": "t", "prompt": "p"})["data"]
        first = run_request(relay, {"op": "status", "job_id": job["job_id"]})
        for _ in range(5):
            again = run_request(relay, {"op": "status", "job_id": job["job_id"]})
            self.assertEqual(again, first)

    # 8. result retrieval preserves structured metadata and raw-evidence references
    def test_result_preserves_structured_metadata_and_evidence_refs(self):
        relay = self.make_relay(FakeCodexAdapter())
        job = run_request(relay, {"op": "submit", "task_id": "evidence-task", "prompt": "p"})["data"]
        result = run_request(relay, {"op": "result", "job_id": job["job_id"]})["data"]
        for field in (
            "job_id",
            "task_id",
            "attempt_no",
            "state",
            "codex_session_id",
            "final_text",
            "stdout_sha256",
            "stderr_sha256",
            "raw_stdout_path",
            "raw_stderr_path",
            "raw_stdout",
            "raw_stderr",
            "completed_at",
        ):
            self.assertIn(field, result)
        self.assertEqual(result["task_id"], "evidence-task")
        self.assertTrue(result["raw_stdout_path"])

    # 9. continuation cannot switch job/session identity
    def test_continuation_cannot_switch_job_or_session_identity(self):
        adapter = FakeCodexAdapter()
        relay = self.make_relay(adapter)
        job = run_request(relay, {"op": "submit", "task_id": "t", "prompt": "first"})["data"]
        original_session = run_request(relay, {"op": "status", "job_id": job["job_id"]})["data"]["codex_session_id"]
        # extraneous fields (session override attempt, task_id override) must be ignored
        resp = run_request(
            relay,
            {
                "op": "continue",
                "job_id": job["job_id"],
                "prompt": "second",
                "codex_session_id": "attacker-controlled-session",
                "task_id": "hijacked-task-id",
            },
        )
        self.assertTrue(resp["ok"])
        self.assertEqual(resp["data"]["job_id"], job["job_id"])
        self.assertEqual(resp["data"]["task_id"], "t")  # unchanged, extraneous field ignored
        self.assertEqual(adapter.resumed[-1][0], original_session)  # relay resumed the REAL session
        self.assertNotEqual(adapter.resumed[-1][0], "attacker-controlled-session")

    # 10. cancel applies only to the exact job
    def test_cancel_applies_only_to_exact_job(self):
        relay = self.make_relay(FakeCodexAdapter(polls_to_finish=100))
        a = run_request(relay, {"op": "submit", "task_id": "a", "prompt": "p"})["data"]
        b = run_request(relay, {"op": "submit", "task_id": "b", "prompt": "p"})["data"]
        cancel_resp = run_request(relay, {"op": "cancel", "job_id": a["job_id"]})
        self.assertTrue(cancel_resp["ok"])
        self.assertEqual(cancel_resp["data"]["state"], "CANCELLED")
        status_b = run_request(relay, {"op": "status", "job_id": b["job_id"]})
        self.assertEqual(status_b["data"]["state"], "RUNNING")

    # 11. bridge cannot inject an arbitrary executable/shell command
    def test_bridge_cannot_inject_arbitrary_executable_or_shell(self):
        calls = {}

        class RecordingAdapter(FakeCodexAdapter):
            def start(self, prompt, cwd, attempt_no):
                calls["start"] = {"prompt": prompt, "cwd": str(cwd), "attempt_no": attempt_no}
                return super().start(prompt, cwd, attempt_no)

        relay = self.make_relay(RecordingAdapter())
        malicious_request = {
            "op": "submit",
            "task_id": "t",
            "prompt": "p",
            "executable": "evil.exe",
            "shell": "rm -rf /",
            "cmd": "calc.exe",
            "cwd": "C:/Windows/System32",
            "codex_executable": "evil.exe",
        }
        resp = run_request(relay, malicious_request)
        self.assertTrue(resp["ok"])
        # the adapter only ever saw the fixed cwd the relay was constructed with,
        # and the exact prompt bytes -- none of the extraneous fields reached it
        self.assertEqual(calls["start"]["cwd"], str(relay.codex_cwd))
        self.assertEqual(calls["start"]["prompt"], b"p")
        self.assertNotIn("executable", str(calls["start"]))
        # the schema itself: no allowed op exposes an executable/shell/cwd field
        from codex_relay.bridge import ControlTowerBridge

        source_fields = set()
        for name in ("_op_submit", "_op_status", "_op_result", "_op_continue", "_op_cancel"):
            method = getattr(ControlTowerBridge, name)
            source_fields.update(method.__code__.co_names)
        for forbidden in ("executable", "shell", "cmd", "cwd", "codex_executable"):
            self.assertNotIn(forbidden, source_fields)

    # 12. existing R1 Relay tests remain PASS -- covered by running both
    # test modules together (see run_all invocation); this test asserts the
    # bridge stays importable alongside the untouched relay module.
    def test_relay_module_untouched_surface_still_importable(self):
        from codex_relay.relay import ControlTowerRelay as DirectImport

        self.assertIs(DirectImport, ControlTowerRelay)


if __name__ == "__main__":
    unittest.main()
