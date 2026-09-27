from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT))

from tools.control_routing_v1.jev_live import (
    API_URL,
    JevLiveError,
    invoke_jev,
)


def jev_input() -> dict:
    return {
        "schema_version": "ea_lab_jev_shadow_input/1",
        "task_id": "TASK-JEV-1",
        "question": "What should the bounded implementation lane do next?",
        "options": ["RETRY", "ESCALATE", "COMPLETE"],
        "evidence_summary": ["tests=PASS", "review=PASS"],
    }


def valid_response() -> dict:
    return {
        "model": "jev-accepted-test",
        "answers": {
            "decision": {
                "type": "choice",
                "choice": "COMPLETE",
                "confidence": 0.7,
                "probabilities": {
                    "RETRY": 0.2,
                    "ESCALATE": 0.1,
                    "COMPLETE": 0.7,
                },
            }
        },
        "usage": {"input_tokens": 42, "output_tokens": 4},
    }


class FakeResponse:
    def __init__(self, body, headers=None):
        if isinstance(body, bytes):
            self.raw = body
        else:
            self.raw = json.dumps(body, separators=(",", ":")).encode("utf-8")
        self.headers = headers or {}
        self.closed = False

    def read(self, limit):
        return self.raw[:limit]
    def close(self):
        self.closed = True


class JevLiveTests(unittest.TestCase):
    def test_missing_auth_refuses_before_network(self):
        called = False

        def opener(request, timeout):
            nonlocal called
            called = True
            raise AssertionError("network must not be called")

        with self.assertRaisesRegex(JevLiveError, "TYPESAFE_API_KEY is not configured"):
            invoke_jev(jev_input(), environ={}, opener=opener)
        self.assertFalse(called)

    def test_live_request_and_response_are_bounded(self):
        captured = {}

        def opener(request, timeout):
            captured["url"] = request.full_url
            captured["auth"] = request.get_header("Authorization")
            captured["body"] = json.loads(request.data.decode("utf-8"))
            captured["timeout"] = timeout
            return FakeResponse(valid_response(), {"x-typesafe-request-id": "req-test-1"})

        result = invoke_jev(
            jev_input(),
            environ={"TYPESAFE_API_KEY": "test-secret", "TYPESAFE_JEV_MODEL": "jev-latest"},
            opener=opener,
            timeout_seconds=3.0,
        )
        self.assertEqual(captured["url"], API_URL)
        self.assertEqual(captured["auth"], "Bearer test-secret")
        self.assertEqual(captured["body"]["model"], "jev-latest")
        question = captured["body"]["questions"]["decision"]
        self.assertEqual(question["type"], "choice")
        self.assertEqual(
            set(question["criteria"]),
            {"RETRY", "ESCALATE", "COMPLETE"},
        )
        self.assertEqual(captured["body"]["state"]["task_id"], "TASK-JEV-1")
        self.assertEqual(result["selected_option"], "COMPLETE")
        self.assertEqual(result["response_model"], "jev-accepted-test")
        self.assertEqual(result["request_id"], "req-test-1")
        self.assertEqual(result["authority_ceiling"], "ADVISORY_ONLY_NO_CONTROL_AUTHORITY")
        self.assertFalse(result["runtime_activation"])
        self.assertFalse(result["canonical"])
        self.assertNotIn("test-secret", json.dumps(result, sort_keys=True))

    def test_model_override_is_bounded_ascii(self):
        with self.assertRaisesRegex(JevLiveError, "TYPESAFE_JEV_MODEL"):
            invoke_jev(
                jev_input(),
                environ={"TYPESAFE_API_KEY": "k", "TYPESAFE_JEV_MODEL": "bad model"},
                opener=lambda *_args, **_kwargs: FakeResponse(valid_response()),
            )
    def test_malformed_provider_responses_fail_closed(self):
        cases = []

        extra = valid_response()
        extra["surprise"] = True
        cases.append(extra)

        missing_probability = valid_response()
        del missing_probability["answers"]["decision"]["probabilities"]["RETRY"]
        cases.append(missing_probability)

        wrong_sum = valid_response()
        wrong_sum["answers"]["decision"]["probabilities"] = {
            "RETRY": 0.1,
            "ESCALATE": 0.1,
            "COMPLETE": 0.1,
        }
        cases.append(wrong_sum)

        wrong_choice = valid_response()
        wrong_choice["answers"]["decision"]["choice"] = "RETRY"
        cases.append(wrong_choice)

        bad_confidence = valid_response()
        bad_confidence["answers"]["decision"]["confidence"] = "0.7"
        cases.append(bad_confidence)

        bad_usage = valid_response()
        bad_usage["usage"]["input_tokens"] = True
        cases.append(bad_usage)
        extra_answer = valid_response()
        extra_answer["answers"]["decision"]["raw"] = "not allowed"
        cases.append(extra_answer)

        for payload in cases:
            with self.subTest(payload=payload):
                with self.assertRaises(JevLiveError):
                    invoke_jev(
                        jev_input(),
                        environ={"TYPESAFE_API_KEY": "k"},
                        opener=lambda *_args, p=payload, **_kwargs: FakeResponse(p),
                    )

    def test_duplicate_provider_json_key_refuses(self):
        raw = (
            b'{"model":"jev-a","model":"jev-b","answers":{"decision":'
            b'{"type":"choice","choice":"COMPLETE","confidence":0.7,'
            b'"probabilities":{"RETRY":0.2,"ESCALATE":0.1,"COMPLETE":0.7}}},'
            b'"usage":{"input_tokens":1,"output_tokens":1}}'
        )
        with self.assertRaisesRegex(JevLiveError, "duplicate JSON key"):
            invoke_jev(
                jev_input(),
                environ={"TYPESAFE_API_KEY": "k"},
                opener=lambda *_args, **_kwargs: FakeResponse(raw),
            )

    def test_timeout_bounds_refuse_without_network(self):
        for value in (0.1, 31, float("inf"), True, "10"):
            with self.subTest(value=value):
                with self.assertRaises(JevLiveError):
                    invoke_jev(
                        jev_input(),
                        environ={"TYPESAFE_API_KEY": "k"},
                        opener=lambda *_args, **_kwargs: (_ for _ in ()).throw(
                            AssertionError("network must not be called")
                        ),
                        timeout_seconds=value,
                    )


if __name__ == "__main__":
    unittest.main()
