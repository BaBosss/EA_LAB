from __future__ import annotations

import os
import re
from typing import Any

INPUT_SCHEMA = "ea_lab_jev_shadow_input/1"
OUTPUT_SCHEMA = "ea_lab_jev_shadow_envelope/1"
TASK_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
INPUT_KEYS = {"schema_version", "task_id", "question", "options", "evidence_summary"}
ALLOWED_OPTIONS = {
    "BLOCK",
    "COMPLETE",
    "CONTINUE",
    "ESCALATE",
    "RETRY",
    "VERIFY_MORE",
    "WAIT",
}


class JevShadowError(ValueError):
    pass


def build_shadow_envelope(value: Any, environ: dict[str, str] | None = None) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise JevShadowError("shadow input must be an object")
    missing = sorted(INPUT_KEYS - set(value))
    unknown = sorted(set(value) - INPUT_KEYS)
    if missing or unknown:
        raise JevShadowError(f"shadow input keys mismatch missing={missing} unknown={unknown}")
    if value["schema_version"] != INPUT_SCHEMA:
        raise JevShadowError("unsupported shadow input schema")
    if not isinstance(value["task_id"], str) or not TASK_ID_RE.fullmatch(value["task_id"]):
        raise JevShadowError("invalid task_id")
    question = value["question"]
    if not isinstance(question, str) or not question.strip() or len(question) > 2000:
        raise JevShadowError("question must be 1..2000 characters")
    options = value["options"]
    if (
        not isinstance(options, list)
        or len(options) < 2
        or len(options) != len(set(options))
        or any(option not in ALLOWED_OPTIONS for option in options)
    ):
        raise JevShadowError("options must be 2+ unique bounded decision values")
    evidence = value["evidence_summary"]
    if (
        not isinstance(evidence, list)
        or len(evidence) > 30
        or any(not isinstance(line, str) or not line or len(line) > 500 for line in evidence)
    ):
        raise JevShadowError("evidence_summary must contain <=30 bounded strings")

    env = os.environ if environ is None else environ
    return {
        "schema_version": OUTPUT_SCHEMA,
        "task_id": value["task_id"],
        "provider": "typesafe",
        "intended_model": "jev",
        "transport_status": "DISABLED_NO_LIVE_ADAPTER",
        "auth_env_var": "TYPESAFE_API_KEY",
        "auth_present": bool(env.get("TYPESAFE_API_KEY")),
        "question": question,
        "options": list(options),
        "evidence_summary": list(evidence),
        "authority_ceiling": "SHADOW_ONLY_NO_CONTROL_AUTHORITY",
        "activation": False,
        "canonical": False,
    }
