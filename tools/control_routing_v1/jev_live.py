from __future__ import annotations

import json
import math
import os
import re
import socket
from http.client import HTTPException
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

try:
    from .jev_shadow import build_shadow_envelope
except ImportError:  # direct CLI execution adds this package directory to sys.path
    from jev_shadow import build_shadow_envelope

OUTPUT_SCHEMA = "ea_lab_jev_live_result/1"
API_URL = "https://api.typesafe.ai/v1/systemone"
DEFAULT_MODEL = "jev-latest"
UPSTREAM_SDK_COMMIT = "f078f1e208a0d885154dc758344ae4fce77ac168"
AUTH_ENV_VAR = "TYPESAFE_API_KEY"
MODEL_ENV_VAR = "TYPESAFE_JEV_MODEL"
ANSWER_KEY = "decision"
MAX_RESPONSE_BYTES = 256 * 1024
DEFAULT_TIMEOUT_SECONDS = 10.0
PROBABILITY_SUM_TOLERANCE = 0.02
REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")


class JevLiveError(ValueError):
    pass


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


_STDLIB_OPEN = build_opener(_NoRedirect()).open


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise JevLiveError("duplicate JSON key in provider response")
        result[key] = value
    return result


def _decode_json(raw: bytes) -> Any:
    try:
        return json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_object)
    except JevLiveError:
        raise
    except (UnicodeDecodeError, ValueError, RecursionError):
        raise JevLiveError("provider response is not valid unique-key UTF-8 JSON") from None


def _probability(value: Any, name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise JevLiveError(f"{name} must be numeric")
    try:
        number = float(value)
    except (OverflowError, ValueError):
        raise JevLiveError(f"{name} must be safely convertible to a finite number") from None
    if not math.isfinite(number) or not 0.0 <= number <= 1.0:
        raise JevLiveError(f"{name} must be finite and within 0..1")
    return number


def _safe_request_id(value: Any) -> str | None:
    if isinstance(value, str) and REQUEST_ID_RE.fullmatch(value):
        return value
    return None


def _close_response(response: Any, *, suppress_error: bool) -> None:
    close = getattr(response, "close", None)
    if not callable(close):
        return
    try:
        close()
    except (OSError, HTTPException) as exc:
        if suppress_error:
            return
        raise JevLiveError(
            f"TypeSafe transport failure during close: {type(exc).__name__}"
        ) from None


def _nonnegative_int(value: Any, name: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise JevLiveError(f"{name} must be an integer >= 0")
    return value

def _resolve_model(environ: dict[str, str]) -> str:
    raw = environ.get(MODEL_ENV_VAR, DEFAULT_MODEL)
    if not isinstance(raw, str):
        raise JevLiveError(f"{MODEL_ENV_VAR} must be text")
    model = raw.strip()
    if not model or len(model) > 128:
        raise JevLiveError(f"{MODEL_ENV_VAR} must be 1..128 characters")
    if any(ord(ch) < 33 or ord(ch) > 126 for ch in model):
        raise JevLiveError(f"{MODEL_ENV_VAR} contains unsupported characters")
    return model


def build_live_request(value: Any, model: str) -> tuple[dict[str, Any], dict[str, Any]]:
    shadow = build_shadow_envelope(value, environ={})
    request = {
        "state": {
            "task_id": shadow["task_id"],
            "evidence_summary": list(shadow["evidence_summary"]),
        },
        "model": model,
        "questions": {
            ANSWER_KEY: {
                "type": "choice",
                "instructions": shadow["question"],
                "criteria": {option: None for option in shadow["options"]},
            }
        },
    }
    return shadow, request


def validate_live_response(payload: Any, options: list[str]) -> dict[str, Any]:
    if not isinstance(payload, dict) or set(payload) != {"model", "answers", "usage"}:
        raise JevLiveError("provider response must contain exactly model/answers/usage")
    model = payload["model"]
    if not isinstance(model, str) or not model.strip() or len(model) > 128:
        raise JevLiveError("provider response model is invalid")

    answers = payload["answers"]
    if not isinstance(answers, dict) or set(answers) != {ANSWER_KEY}:
        raise JevLiveError("provider answers must contain exactly the decision answer")
    answer = answers[ANSWER_KEY]
    required_answer = {"type", "choice", "confidence", "probabilities"}
    if not isinstance(answer, dict) or set(answer) != required_answer:
        raise JevLiveError("decision answer has an unexpected shape")
    if answer["type"] != "choice":
        raise JevLiveError("decision answer type must be choice")
    choice = answer["choice"]
    if not isinstance(choice, str) or choice not in options:
        raise JevLiveError("decision choice is outside the requested option set")
    confidence = _probability(answer["confidence"], "confidence")

    probabilities = answer["probabilities"]
    if not isinstance(probabilities, dict) or set(probabilities) != set(options):
        raise JevLiveError("decision probabilities must exactly cover requested options")
    normalized = {
        option: _probability(probabilities[option], f"probabilities.{option}")
        for option in options
    }
    total = sum(normalized.values())
    if abs(total - 1.0) > PROBABILITY_SUM_TOLERANCE:
        raise JevLiveError("decision probabilities do not sum approximately to 1")
    maximum = max(normalized.values())
    if normalized[choice] + 1e-12 < maximum:
        raise JevLiveError("decision choice is not a maximum-probability option")

    usage = payload["usage"]
    if not isinstance(usage, dict) or set(usage) != {"input_tokens", "output_tokens"}:
        raise JevLiveError("provider usage must contain exactly input_tokens/output_tokens")
    clean_usage = {
        "input_tokens": _nonnegative_int(usage["input_tokens"], "usage.input_tokens"),
        "output_tokens": _nonnegative_int(usage["output_tokens"], "usage.output_tokens"),
    }
    return {
        "response_model": model.strip(),
        "selected_option": choice,
        "confidence": confidence,
        "probabilities": normalized,
        "usage": clean_usage,
    }


def _read_provider_response(response: Any) -> tuple[bytes, str | None]:
    raw = response.read(MAX_RESPONSE_BYTES + 1)
    if not isinstance(raw, (bytes, bytearray)):
        raise JevLiveError("provider response body is not bytes")
    if len(raw) > MAX_RESPONSE_BYTES:
        raise JevLiveError("provider response exceeds bounded size")
    request_id = None
    headers = getattr(response, "headers", None)
    if headers is not None:
        request_id = _safe_request_id(headers.get("x-typesafe-request-id"))
    return bytes(raw), request_id


def invoke_jev(
    value: Any,
    *,
    environ: dict[str, str] | None = None,
    opener: Callable[..., Any] | None = None,
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
) -> dict[str, Any]:
    env = os.environ if environ is None else environ
    key = env.get(AUTH_ENV_VAR)
    if not isinstance(key, str) or not key.strip():
        raise JevLiveError(f"{AUTH_ENV_VAR} is not configured")
    key = key.strip()
    if len(key) > 4096 or "\r" in key or "\n" in key:
        raise JevLiveError(f"{AUTH_ENV_VAR} is malformed")
    if isinstance(timeout_seconds, bool) or not isinstance(timeout_seconds, (int, float)):
        raise JevLiveError("timeout_seconds must be numeric")
    timeout = float(timeout_seconds)
    if not math.isfinite(timeout) or not 0.5 <= timeout <= 30.0:
        raise JevLiveError("timeout_seconds must be within 0.5..30")

    model = _resolve_model(env)
    shadow, body = build_live_request(value, model)
    encoded = json.dumps(
        body, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    request = Request(
        API_URL,
        data=encoded,
        method="POST",
        headers={
            "Authorization": f"Bearer {key}",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "ea-lab-control-routing-jev-live/1",
        },
    )
    call = _STDLIB_OPEN if opener is None else opener
    response = None
    try:
        response = call(request, timeout=timeout)
        raw, request_id = _read_provider_response(response)
    except HTTPError as exc:
        safe_id = _safe_request_id(
            exc.headers.get("x-typesafe-request-id") if exc.headers else None
        )
        _close_response(exc, suppress_error=True)
        suffix = f" request_id={safe_id}" if safe_id else ""
        raise JevLiveError(f"TypeSafe HTTP {exc.code}{suffix}") from None
    except (URLError, TimeoutError, socket.timeout, OSError, HTTPException) as exc:
        raise JevLiveError(f"TypeSafe transport failure: {type(exc).__name__}") from None
    finally:
        if response is not None:
            _close_response(response, suppress_error=False)

    validated = validate_live_response(_decode_json(raw), list(shadow["options"]))
    return {
        "schema_version": OUTPUT_SCHEMA,
        "task_id": shadow["task_id"],
        "provider": "typesafe",
        "endpoint": API_URL,
        "requested_model": model,
        "response_model": validated["response_model"],
        "transport_status": "LIVE_CALL_PASS",
        "request_id": request_id,
        "selected_option": validated["selected_option"],
        "confidence": validated["confidence"],
        "probabilities": validated["probabilities"],
        "usage": validated["usage"],
        "auth_env_var": AUTH_ENV_VAR,
        "auth_present": True,
        "upstream_sdk_commit": UPSTREAM_SDK_COMMIT,
        "authority_ceiling": "ADVISORY_ONLY_NO_CONTROL_AUTHORITY",
        "provider_call_completed": True,
        "runtime_activation": False,
        "canonical": False,
    }
