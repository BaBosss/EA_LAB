from __future__ import annotations

import json
import sys
import unittest
from http.client import IncompleteRead
from io import BytesIO
from pathlib import Path
from urllib.error import HTTPError

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT))

from tools.control_routing_v1.jev_live import (
    API_URL,
    JevLiveError,
    _NoRedirect,
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


class FaultyReadResponse(FakeResponse):
    def __init__(self, exc):
        super().__init__(valid_response())
        self.exc = exc

    def read(self, limit):
        raise self.exc


class FaultyCloseResponse(FakeResponse):
    def close(self):
        self.closed = True
        raise OSError("provider-controlled close detail must not escape")


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

    def test_malformed_auth_refuses_before_network(self):
        for key in ("abc\r\ninjected", "x" * 4097):
            called = False

            def opener(request, timeout):
                nonlocal called
                called = True
                raise AssertionError("network must not be called")

            with self.subTest(length=len(key)):
                with self.assertRaisesRegex(JevLiveError, "TYPESAFE_API_KEY is malformed"):
                    invoke_jev(jev_input(), environ={"TYPESAFE_API_KEY": key}, opener=opener)
                self.assertFalse(called)

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

    def test_probability_numeric_edge_cases_fail_closed(self):
        invalid_values = [True, False, -(10**1000), 10**1000, float("nan"), float("inf"), float("-inf")]
        for value in invalid_values:
            confidence_payload = valid_response()
            confidence_payload["answers"]["decision"]["confidence"] = value
            with self.subTest(field="confidence", value=repr(value)):
                with self.assertRaises(JevLiveError):
                    invoke_jev(
                        jev_input(),
                        environ={"TYPESAFE_API_KEY": "k"},
                        opener=lambda *_args, p=confidence_payload, **_kwargs: FakeResponse(p),
                    )
            for option in jev_input()["options"]:
                probability_payload = valid_response()
                probability_payload["answers"]["decision"]["probabilities"][option] = value
                with self.subTest(field=f"probabilities.{option}", value=repr(value)):
                    with self.assertRaises(JevLiveError):
                        invoke_jev(
                            jev_input(),
                            environ={"TYPESAFE_API_KEY": "k"},
                            opener=lambda *_args, p=probability_payload, **_kwargs: FakeResponse(p),
                        )

    def test_request_id_is_strict_visible_identifier(self):
        invalid_ids = [
            "",
            "req-ok\r\n injected-line",
            "req\x1b[31m",
            "space not allowed",
            "req\r", "req\n", "req\t", "req\x00", "req\x7f",
            "x" * 129,
        ]
        for request_id in invalid_ids:
            with self.subTest(request_id=repr(request_id)):
                result = invoke_jev(
                    jev_input(),
                    environ={"TYPESAFE_API_KEY": "k"},
                    opener=lambda *_args, rid=request_id, **_kwargs: FakeResponse(
                        valid_response(), {"x-typesafe-request-id": rid}
                    ),
                )
                self.assertIsNone(result["request_id"])

    def test_transport_failures_are_credential_safe_refusals(self):
        cases = [
            ConnectionResetError("secret connection detail"),
            IncompleteRead(b"partial", 9),
            TimeoutError("secret timeout detail"),
        ]
        for exc in cases:
            with self.subTest(kind=type(exc).__name__):
                with self.assertRaises(JevLiveError) as caught:
                    invoke_jev(
                        jev_input(),
                        environ={"TYPESAFE_API_KEY": "secret-key"},
                        opener=(
                            (lambda *_args, e=exc, **_kwargs: (_ for _ in ()).throw(e))
                            if isinstance(exc, TimeoutError)
                            else (lambda *_args, e=exc, **_kwargs: FaultyReadResponse(e))
                        ),
                    )
                text = str(caught.exception)
                self.assertNotIn("secret-key", text)
                self.assertNotIn("secret connection detail", text)
                self.assertNotIn("secret timeout detail", text)

        response = FaultyCloseResponse(valid_response())
        with self.assertRaisesRegex(JevLiveError, "transport failure during close"):
            invoke_jev(
                jev_input(),
                environ={"TYPESAFE_API_KEY": "secret-key"},
                opener=lambda *_args, **_kwargs: response,
            )
        self.assertTrue(response.closed)

    def test_http_error_closes_body_and_sanitizes_request_id(self):
        for request_id, expected_suffix in (
            ("req-ok_1", " request_id=req-ok_1"),
            ("req-ok\r\n forged", ""),
        ):
            body = BytesIO(b'{"secret":"provider-body-must-not-escape"}')
            error = HTTPError(
                API_URL,
                503,
                "provider reason must not escape",
                {"x-typesafe-request-id": request_id},
                body,
            )
            with self.subTest(request_id=repr(request_id)):
                with self.assertRaises(JevLiveError) as caught:
                    invoke_jev(
                        jev_input(),
                        environ={"TYPESAFE_API_KEY": "secret-key"},
                        opener=lambda *_args, e=error, **_kwargs: (_ for _ in ()).throw(e),
                    )
                message = str(caught.exception)
                self.assertEqual(message, "TypeSafe HTTP 503" + expected_suffix)
                self.assertTrue(body.closed)

    def test_redirect_handler_refuses_redirect_request(self):
        handler = _NoRedirect()
        self.assertIsNone(
            handler.redirect_request(
                None, None, 302, "Found", {"location": "https://evil.invalid"},
                "https://evil.invalid"
            )
        )

    def test_raw_large_integer_decoder_refuses_safely(self):
        raw = b'{"confidence":' + b'9' * 5000 + b'}'
        with self.assertRaises(JevLiveError):
            invoke_jev(jev_input(), environ={"TYPESAFE_API_KEY": "k"},
                       opener=lambda *_a, **_kw: FakeResponse(raw))

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
