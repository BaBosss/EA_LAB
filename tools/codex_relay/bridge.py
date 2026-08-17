"""Narrow Control-Tower-facing bridge over :class:`ControlTowerRelay`.

This is the R3 layer described in ``CONTRACT.md``: a thin, replaceable seam
between an EA_LAB Control Tower caller and the existing Relay/Codex backend.
It transports exact, already-authorized tasks; it does not grant authority.

The request/response contract is deliberately narrow:

- ``op`` is one of ``submit``, ``status``, ``result``, ``continue``, ``cancel``.
- Every other field is a plain, bounded value (a string, a job_id, a number).
- There is no field anywhere in the schema for a shell command, an
  executable path, a working directory, or any other escalation surface --
  those remain fixed at process-launch time by whoever starts the bridge,
  exactly as ``ControlTowerRelay`` already fixes them today. A future MCP
  frontend can call :func:`run_request` directly without knowing anything
  about subprocesses, the CLI framing, or the on-disk job layout.

The CLI entry point (``run_bridge.py``) is a persistent JSON-Lines server,
not a one-shot-per-call process: it reads one JSON request per line from
stdin and writes one JSON response per line to stdout until stdin closes.
This is required, not stylistic -- ``ControlTowerRelay`` tracks a dispatched
job's live subprocess handle only in the memory of the process that started
it, so a fresh process per call could only ever observe ``PROCESS_LOST`` for
any job not already finished. See :func:`_serve`.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, Optional

from .relay import ControlTowerRelay, JobNotFound, RelayError

ALLOWED_OPS = frozenset({"submit", "status", "result", "continue", "cancel"})
JOB_ID_RE = re.compile(r"^[0-9a-f]{32}$")

DEFAULT_STATE_DIR = Path(__file__).resolve().parent / "_relay_state"


class BridgeError(RuntimeError):
    """A malformed-request or bridge-boundary error.

    Never wraps a raw backend exception message beyond what RelayError
    already exposes -- this class is reserved for requests that never even
    reach the relay.
    """


def _require_str(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise BridgeError("%s must be a non-empty string" % field)
    return value


def _require_prompt(value: Any) -> str:
    if not isinstance(value, str):
        raise BridgeError("prompt must be a string")
    return value


def _require_job_id(value: Any) -> str:
    if not isinstance(value, str) or JOB_ID_RE.fullmatch(value) is None:
        raise BridgeError("malformed job_id")
    return value


def _optional_timeout(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise BridgeError("timeout_seconds must be a number")
    if value <= 0:
        raise BridgeError("timeout_seconds must be positive")
    return float(value)


def _project_dispatch(metadata: Dict[str, Any]) -> Dict[str, Any]:
    """Bounded view of relay metadata -- never the raw internal dict."""

    return {
        "job_id": metadata["job_id"],
        "task_id": metadata["task_id"],
        "state": metadata["state"],
        "prompt_sha256": metadata["prompt_sha256"],
        "created_at": metadata["created_at"],
        "updated_at": metadata["updated_at"],
        "codex_session_id": metadata.get("codex_session_id"),
        "attempt_no": metadata["attempts"][-1]["attempt_no"],
        "last_error": metadata.get("last_error"),
    }


def _project_result(job_id: str, task_id: Optional[str], result: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "job_id": result["job_id"],
        "task_id": task_id,
        "attempt_no": result["attempt_no"],
        "state": result["state"],
        "returncode": result["returncode"],
        "codex_session_id": result["codex_session_id"],
        "final_text": result["final_text"],
        "error": result["error"],
        "stdout_sha256": result["stdout_sha256"],
        "stderr_sha256": result["stderr_sha256"],
        "raw_stdout_path": result["raw_stdout_path"],
        "raw_stderr_path": result["raw_stderr_path"],
        "raw_stdout": result["raw_stdout"],
        "raw_stderr": result["raw_stderr"],
        "completed_at": result["completed_at"],
    }


class ControlTowerBridge:
    """Deterministic request/response boundary over one ``ControlTowerRelay``.

    Each ``_op_*`` handler reads only the fields it declares below; any other
    key present in the request (e.g. an attempted ``executable`` or ``cwd``
    override) is never inspected and never reaches the backend.
    """

    def __init__(self, relay: ControlTowerRelay):
        self.relay = relay

    def handle(self, request: Dict[str, Any]) -> Dict[str, Any]:
        if not isinstance(request, dict):
            raise BridgeError("request must be a JSON object")
        op = request.get("op")
        if op not in ALLOWED_OPS:
            raise BridgeError("unknown op: %r" % (op,))
        method = getattr(self, "_op_%s" % op)
        return method(request)

    def _op_submit(self, request: Dict[str, Any]) -> Dict[str, Any]:
        task_id = _require_str(request.get("task_id"), "task_id")
        prompt = _require_prompt(request.get("prompt"))
        timeout_seconds = _optional_timeout(request.get("timeout_seconds"))
        metadata = self.relay.dispatch_codex(task_id, prompt, timeout_seconds=timeout_seconds)
        return _project_dispatch(metadata)

    def _op_status(self, request: Dict[str, Any]) -> Dict[str, Any]:
        job_id = _require_job_id(request.get("job_id"))
        return self.relay.get_codex_status(job_id)

    def _op_result(self, request: Dict[str, Any]) -> Dict[str, Any]:
        job_id = _require_job_id(request.get("job_id"))
        result = self.relay.get_codex_result(job_id)
        task_id: Optional[str] = None
        try:
            task_id = self.relay.get_codex_status(job_id).get("task_id")
        except RelayError:
            pass
        return _project_result(job_id, task_id, result)

    def _op_continue(self, request: Dict[str, Any]) -> Dict[str, Any]:
        job_id = _require_job_id(request.get("job_id"))
        prompt = _require_prompt(request.get("prompt"))
        timeout_seconds = _optional_timeout(request.get("timeout_seconds"))
        metadata = self.relay.continue_codex(job_id, prompt, timeout_seconds=timeout_seconds)
        return _project_dispatch(metadata)

    def _op_cancel(self, request: Dict[str, Any]) -> Dict[str, Any]:
        job_id = _require_job_id(request.get("job_id"))
        return self.relay.cancel_codex(job_id)


def run_request(relay: ControlTowerRelay, request: Any) -> Dict[str, Any]:
    """Execute one request against ``relay`` and return the JSON envelope.

    Structured for a future MCP frontend: pass a relay instance and a plain
    dict, get back a plain dict. Never raises -- every failure mode
    (malformed request, unknown job, backend error) resolves to
    ``{"ok": False, ...}`` instead of an exception or traceback.
    """

    bridge = ControlTowerBridge(relay)
    op = request.get("op") if isinstance(request, dict) else None
    try:
        data = bridge.handle(request)
        return {"ok": True, "op": op, "data": data}
    except BridgeError as exc:
        return {"ok": False, "op": op, "error": str(exc), "error_type": "BRIDGE_ERROR"}
    except JobNotFound as exc:
        return {"ok": False, "op": op, "error": str(exc), "error_type": "JOB_NOT_FOUND"}
    except RelayError as exc:
        return {"ok": False, "op": op, "error": str(exc), "error_type": "RELAY_ERROR"}
    except Exception as exc:  # last-resort: never leak a raw traceback to the caller
        return {"ok": False, "op": op, "error": str(exc), "error_type": "UNEXPECTED_ERROR"}


def _build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Control Tower Relay bridge: reads one JSON request object from "
            "stdin, writes one JSON response envelope to stdout."
        )
    )
    parser.add_argument(
        "--state-dir",
        default=str(DEFAULT_STATE_DIR),
        help="Directory for persisted job state (operator-fixed, not part of any request).",
    )
    parser.add_argument(
        "--codex-cwd",
        default=None,
        help="Working directory Codex is launched in (operator-fixed, not part of any request).",
    )
    parser.add_argument("--timeout-seconds", type=float, default=300.0)
    return parser


def _serve(relay: ControlTowerRelay, in_stream: Any, out_stream: Any) -> int:
    """Read one JSON request per line until EOF; write one JSON response
    envelope per line, flushing after each.

    This process must stay alive for the life of a Control Tower session --
    dispatched jobs run asynchronously and the relay tracks the live
    subprocess handle only in this process's memory (``ControlTowerRelay``
    has no other way to observe a still-running job; see ``CONTRACT.md``).
    A fresh process per call would only ever see ``PROCESS_LOST`` for any
    job not already finished, so submit/status/result/continue/cancel must
    all be sent to the same running instance of this loop.

    A malformed line yields an error envelope but never stops the loop; only
    EOF (stdin closed) ends it.
    """

    for raw_line in in_stream:
        line = raw_line.strip()
        if not line:
            continue
        try:
            text = line.decode("utf-8") if isinstance(line, bytes) else line
            request = json.loads(text)
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            envelope: Dict[str, Any] = {
                "ok": False,
                "op": None,
                "error": "malformed JSON request: %s" % exc,
                "error_type": "MALFORMED_REQUEST",
            }
        else:
            envelope = run_request(relay, request)
        out_stream.write((json.dumps(envelope, sort_keys=True) + "\n").encode("utf-8"))
        out_stream.flush()
    return 0


def _main(argv: Optional[list] = None) -> int:
    args = _build_arg_parser().parse_args(argv)
    relay = ControlTowerRelay(
        args.state_dir,
        codex_cwd=args.codex_cwd,
        default_timeout_seconds=args.timeout_seconds,
    )
    return _serve(relay, sys.stdin.buffer, sys.stdout.buffer)


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
