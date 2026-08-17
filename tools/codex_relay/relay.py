"""Small, bounded, persistently evidenced relay for local Codex CLI jobs.

The relay is intentionally an execution adapter, not an authority layer.  It
accepts one prompt, starts the fixed ``codex exec --json`` interface, and
stores every byte needed to audit that invocation.  A future MCP server can
call :class:`ControlTowerRelay` without knowing anything about subprocesses or
the on-disk layout.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import threading
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Protocol, Tuple, Union


TERMINAL_STATES = frozenset({"DONE", "BLOCKED", "FAILED", "CANCELLED"})
ACTIVE_STATES = frozenset({"QUEUED", "RUNNING", "CONTINUING"})
JOB_ID_RE = re.compile(r"^[0-9a-f]{32}$")
SESSION_ID_RE = re.compile(r"^[A-Za-z0-9._:-]+$")


class RelayError(RuntimeError):
    """A fail-clear relay contract or persisted-state error."""


class JobNotFound(RelayError):
    """The caller supplied no known job identity."""


Prompt = Union[str, bytes]


def _utc_now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _prompt_bytes(prompt: Prompt) -> bytes:
    if isinstance(prompt, bytes):
        return prompt
    if isinstance(prompt, str):
        return prompt.encode("utf-8")
    raise RelayError("prompt must be str or bytes")


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode(
        "utf-8"
    )


def _atomic_write(path: Path, data: bytes) -> None:
    """Write a file without exposing a partially written metadata/result file."""

    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(".%s.%s.tmp" % (path.name, uuid.uuid4().hex))
    try:
        with temp.open("wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(str(temp), str(path))
    finally:
        try:
            temp.unlink()
        except FileNotFoundError:
            pass


def _read_json(path: Path) -> Dict[str, Any]:
    try:
        with path.open("rb") as handle:
            raw = handle.read()
        value = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise RelayError("corrupt job metadata: %s" % path) from exc
    if not isinstance(value, dict):
        raise RelayError("corrupt job metadata: root is not an object: %s" % path)
    return value


def _validate_job_id(job_id: str) -> None:
    if not isinstance(job_id, str) or JOB_ID_RE.fullmatch(job_id) is None:
        raise RelayError("invalid job_id")


@dataclass
class ExecutionHandle:
    process: Any
    pid: Optional[int]
    session_id: Optional[str] = None
    attempt_no: int = 0
    started_monotonic: float = 0.0


@dataclass
class ExecutionOutcome:
    state: str
    returncode: Optional[int]
    stdout: bytes
    stderr: bytes
    session_id: Optional[str]
    final_text: Optional[str]
    error: Optional[str] = None


class CodexAdapter(Protocol):
    """Narrow adapter seam used by the relay and its deterministic fake."""

    def start(self, prompt: bytes, cwd: Path, attempt_no: int) -> ExecutionHandle:
        ...

    def resume(
        self, session_id: str, prompt: bytes, cwd: Path, attempt_no: int
    ) -> ExecutionHandle:
        ...

    def poll(self, handle: ExecutionHandle) -> Optional[ExecutionOutcome]:
        ...

    def cancel(self, handle: ExecutionHandle) -> ExecutionOutcome:
        ...


class RealCodexAdapter:
    """Adapter for the installed, non-interactive Codex CLI.

    The command shape is fixed.  User input is sent only as stdin prompt
    bytes; no caller-provided command, executable, or shell fragment is
    accepted.  ``--sandbox read-only`` keeps this relay bounded to a read-only
    worker invocation.
    """

    def __init__(self, codex_executable: Optional[str] = None):
        # The supported Windows install resolves through the npm ``.CMD``
        # shim.  The packaged Store ``.EXE`` is present on this machine but
        # access-denied when launched directly, so use the fixed shim and
        # invoke it through the Windows command interpreter below.
        self.codex_executable = codex_executable or shutil.which("codex")

    def _require_executable(self) -> str:
        if not self.codex_executable:
            raise RelayError("Codex unavailable: codex executable was not found")
        return self.codex_executable

    def _launch(self, args: List[str], prompt: bytes, cwd: Path, attempt_no: int) -> ExecutionHandle:
        executable = self._require_executable()
        argv = [executable] + args + ["-"]
        if os.name == "nt" and Path(executable).suffix.lower() in {".cmd", ".bat"}:
            # This is not a caller shell: executable and every argument are
            # fixed by this adapter, while prompt bytes stay on stdin.
            command_line = subprocess.list2cmdline(argv)
            command = [os.environ.get("ComSpec", "cmd.exe"), "/d", "/s", "/c", command_line]
        else:
            command = argv
        try:
            process = subprocess.Popen(
                command,
                cwd=str(cwd),
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                shell=False,
            )
            assert process.stdin is not None
            process.stdin.write(prompt)
            process.stdin.close()
        except (OSError, ValueError) as exc:
            raise RelayError("Codex launch failed: %s" % exc) from exc
        return ExecutionHandle(
            process=process,
            pid=getattr(process, "pid", None),
            attempt_no=attempt_no,
            started_monotonic=time.monotonic(),
        )

    @staticmethod
    def _common_args(cwd: Path) -> List[str]:
        return [
            "exec",
            "--json",
            "--sandbox",
            "read-only",
            "--cd",
            str(cwd),
        ]

    def start(self, prompt: bytes, cwd: Path, attempt_no: int) -> ExecutionHandle:
        return self._launch(self._common_args(cwd), prompt, cwd, attempt_no)

    def resume(self, session_id: str, prompt: bytes, cwd: Path, attempt_no: int) -> ExecutionHandle:
        if not session_id or SESSION_ID_RE.fullmatch(session_id) is None:
            raise RelayError("malformed Codex session identity")
        args = [
            "exec",
            "resume",
            session_id,
            "--json",
            "--sandbox",
            "read-only",
            "--cd",
            str(cwd),
        ]
        return self._launch(args, prompt, cwd, attempt_no)

    @staticmethod
    def _collect_jsonl(stdout: bytes) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        session_id: Optional[str] = None
        final_text: Optional[str] = None
        error: Optional[str] = None
        for raw_line in stdout.splitlines():
            try:
                event = json.loads(raw_line.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                continue
            if not isinstance(event, dict):
                continue
            event_type = str(event.get("type", ""))
            if event_type == "thread.started":
                candidate = event.get("thread_id") or event.get("id")
                if isinstance(candidate, str):
                    session_id = candidate
            if "failed" in event_type or event_type == "error":
                error = str(event.get("message") or event.get("error") or event)
            item = event.get("item")
            if isinstance(item, dict):
                item_type = str(item.get("type", ""))
                text = item.get("text")
                if item_type in {"agent_message", "assistant_message", "message"} and isinstance(text, str):
                    final_text = text
            text = event.get("text")
            if event_type.endswith("output_text.done") and isinstance(text, str):
                final_text = text
        return session_id, final_text, error

    def poll(self, handle: ExecutionHandle) -> Optional[ExecutionOutcome]:
        process = handle.process
        if process.poll() is None:
            return None
        stdout, stderr = process.communicate()
        session_id, final_text, error = self._collect_jsonl(stdout)
        return ExecutionOutcome(
            state="FAILED" if process.returncode else "DONE",
            returncode=process.returncode,
            stdout=stdout,
            stderr=stderr,
            session_id=session_id,
            final_text=final_text,
            error=error,
        )

    def cancel(self, handle: ExecutionHandle) -> ExecutionOutcome:
        process = handle.process
        if process.poll() is None:
            try:
                process.terminate()
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)
        stdout, stderr = process.communicate()
        session_id, final_text, error = self._collect_jsonl(stdout)
        return ExecutionOutcome(
            state="CANCELLED",
            returncode=process.returncode,
            stdout=stdout,
            stderr=stderr,
            session_id=session_id,
            final_text=final_text,
            error=error,
        )


class FakeCodexAdapter:
    """Deterministic adapter for cages; it never starts a subprocess."""

    def __init__(self, outcomes: Optional[Iterable[str]] = None, polls_to_finish: int = 0):
        self.outcomes = list(outcomes or [])
        self.polls_to_finish = polls_to_finish
        self.started: List[Tuple[str, bytes, int]] = []
        self.resumed: List[Tuple[str, bytes, int]] = []
        self.cancelled: List[str] = []

    def _new_handle(self, prompt: bytes, attempt_no: int, resumed_from: Optional[str] = None) -> ExecutionHandle:
        session_id = resumed_from or ("fake-session-" + uuid.uuid4().hex)
        outcome_state = self.outcomes.pop(0) if self.outcomes else "DONE"
        process = {"polls": 0, "state": outcome_state, "prompt": prompt, "session": session_id}
        return ExecutionHandle(process=process, pid=None, session_id=session_id, attempt_no=attempt_no, started_monotonic=time.monotonic())

    def start(self, prompt: bytes, cwd: Path, attempt_no: int) -> ExecutionHandle:
        self.started.append((str(cwd), prompt, attempt_no))
        return self._new_handle(prompt, attempt_no)

    def resume(self, session_id: str, prompt: bytes, cwd: Path, attempt_no: int) -> ExecutionHandle:
        self.resumed.append((session_id, prompt, attempt_no))
        return self._new_handle(prompt, attempt_no, resumed_from=session_id)

    def poll(self, handle: ExecutionHandle) -> Optional[ExecutionOutcome]:
        process = handle.process
        process["polls"] += 1
        if process["polls"] <= self.polls_to_finish:
            return None
        state = process["state"]
        text = "FAKE:%s:%s" % (state, process["prompt"].decode("utf-8", "replace"))
        return ExecutionOutcome(
            state=state,
            returncode=0 if state in {"DONE", "BLOCKED", "CANCELLED"} else 1,
            stdout=(json.dumps({"type": "thread.started", "thread_id": process["session"]}) + "\n").encode()
            + (json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": text}}) + "\n").encode(),
            stderr=b"" if state != "FAILED" else b"fake failure",
            session_id=process["session"],
            final_text=text,
            error=None if state not in {"FAILED", "BLOCKED"} else "fake %s" % state.lower(),
        )

    def cancel(self, handle: ExecutionHandle) -> ExecutionOutcome:
        self.cancelled.append(handle.process["session"])
        return ExecutionOutcome(
            state="CANCELLED",
            returncode=None,
            stdout=b"fake cancelled\n",
            stderr=b"",
            session_id=handle.process["session"],
            final_text=None,
            error="cancelled by caller",
        )


class ControlTowerRelay:
    """Public backend contract for a future Control Tower/MCP frontend."""

    def __init__(
        self,
        state_dir: Union[str, Path],
        *,
        adapter: Optional[CodexAdapter] = None,
        codex_cwd: Optional[Union[str, Path]] = None,
        default_timeout_seconds: float = 300.0,
    ):
        self.state_dir = Path(state_dir).resolve()
        self.jobs_dir = self.state_dir / "jobs"
        self.jobs_dir.mkdir(parents=True, exist_ok=True)
        self.codex_cwd = Path(codex_cwd or Path.cwd()).resolve()
        if not self.codex_cwd.is_dir():
            raise RelayError("Codex working directory does not exist")
        self.default_timeout_seconds = float(default_timeout_seconds)
        if self.default_timeout_seconds <= 0:
            raise RelayError("default timeout must be positive")
        self.adapter: CodexAdapter = adapter or RealCodexAdapter()
        self._handles: Dict[str, ExecutionHandle] = {}
        self._locks: Dict[str, threading.RLock] = {}
        self._global_lock = threading.RLock()

    def _job_dir(self, job_id: str) -> Path:
        _validate_job_id(job_id)
        return self.jobs_dir / job_id

    def _metadata_path(self, job_id: str) -> Path:
        return self._job_dir(job_id) / "metadata.json"

    def _load(self, job_id: str) -> Dict[str, Any]:
        job_dir = self._job_dir(job_id)
        if not job_dir.is_dir() or not (job_dir / "metadata.json").is_file():
            raise JobNotFound("unknown job_id: %s" % job_id)
        metadata = _read_json(job_dir / "metadata.json")
        if metadata.get("job_id") != job_id:
            raise RelayError("job identity mismatch in persisted metadata")
        if metadata.get("state") not in ACTIVE_STATES | TERMINAL_STATES:
            raise RelayError("corrupt job state")
        if not isinstance(metadata.get("task_id"), str) or not metadata["task_id"].strip():
            raise RelayError("corrupt job metadata: missing task_id")
        attempts = metadata.get("attempts")
        if not isinstance(attempts, list) or not attempts or not all(isinstance(item, dict) for item in attempts):
            raise RelayError("corrupt job metadata: attempts must be a non-empty list")
        if not isinstance(attempts[-1].get("attempt_no"), int) or attempts[-1]["attempt_no"] < 1:
            raise RelayError("corrupt job metadata: malformed latest attempt")
        return metadata

    def _owned_path(self, job_id: str, relative_path: str) -> Path:
        if not isinstance(relative_path, str) or not relative_path:
            raise RelayError("corrupt job metadata: missing evidence path")
        job_root = self._job_dir(job_id).resolve()
        candidate = (self.state_dir / relative_path).resolve()
        if candidate == job_root or job_root not in candidate.parents:
            raise RelayError("corrupt job metadata: evidence path escapes job directory")
        return candidate

    def _lock_for(self, job_id: str) -> threading.RLock:
        with self._global_lock:
            return self._locks.setdefault(job_id, threading.RLock())

    def _save(self, metadata: Dict[str, Any]) -> None:
        _atomic_write(self._metadata_path(metadata["job_id"]), _json_bytes(metadata))

    def _attempt_dir(self, job_id: str, attempt_no: int) -> Path:
        return self._job_dir(job_id) / "attempts" / ("%04d" % attempt_no)

    def _persist_outcome(
        self, metadata: Dict[str, Any], outcome: ExecutionOutcome, *, requested_state: Optional[str] = None
    ) -> Dict[str, Any]:
        attempt = metadata["attempts"][-1]
        attempt_dir = self._attempt_dir(metadata["job_id"], int(attempt["attempt_no"]))
        _atomic_write(attempt_dir / "raw_stdout.bin", outcome.stdout)
        _atomic_write(attempt_dir / "raw_stderr.bin", outcome.stderr)
        result = {
            "job_id": metadata["job_id"],
            "attempt_no": attempt["attempt_no"],
            "state": requested_state or outcome.state,
            "returncode": outcome.returncode,
            "codex_session_id": outcome.session_id,
            "final_text": outcome.final_text,
            "error": outcome.error,
            "stdout_sha256": _sha256(outcome.stdout),
            "stderr_sha256": _sha256(outcome.stderr),
            "raw_stdout_path": str((attempt_dir / "raw_stdout.bin").relative_to(self.state_dir)),
            "raw_stderr_path": str((attempt_dir / "raw_stderr.bin").relative_to(self.state_dir)),
            "completed_at": _utc_now(),
        }
        result_bytes = _json_bytes(result)
        _atomic_write(attempt_dir / "result.json", result_bytes)
        attempt.update(
            {
                "state": result["state"],
                "completed_at": result["completed_at"],
                "result_path": str((attempt_dir / "result.json").relative_to(self.state_dir)),
                "result_sha256": _sha256(result_bytes),
                "stdout_sha256": result["stdout_sha256"],
                "stderr_sha256": result["stderr_sha256"],
            }
        )
        metadata["state"] = result["state"]
        metadata["updated_at"] = result["completed_at"]
        metadata["last_result_path"] = result["raw_stdout_path"]
        metadata["codex_session_id"] = metadata.get("codex_session_id") or outcome.session_id
        metadata["last_error"] = outcome.error
        self._save(metadata)
        return result

    def _observe(self, metadata: Dict[str, Any]) -> Dict[str, Any]:
        job_id = metadata["job_id"]
        handle = self._handles.get(job_id)
        if handle is None:
            if metadata["state"] in ACTIVE_STATES:
                return self._fail_without_process(metadata, "PROCESS_LOST")
            return metadata
        attempt = metadata["attempts"][-1]
        timeout = float(attempt["timeout_seconds"])
        if time.monotonic() - handle.started_monotonic > timeout:
            cancelled = self.adapter.cancel(handle)
            self._handles.pop(job_id, None)
            outcome = ExecutionOutcome(
                state="FAILED",
                returncode=cancelled.returncode,
                stdout=cancelled.stdout,
                stderr=cancelled.stderr,
                session_id=cancelled.session_id,
                final_text=cancelled.final_text,
                error="TIMEOUT",
            )
            self._persist_outcome(metadata, outcome, requested_state="FAILED")
            return self._load(job_id)
        outcome = self.adapter.poll(handle)
        if outcome is None:
            return metadata
        self._handles.pop(job_id, None)
        expected = metadata.get("codex_session_id")
        if expected and outcome.session_id and expected != outcome.session_id:
            outcome = ExecutionOutcome(
                state="FAILED",
                returncode=outcome.returncode,
                stdout=outcome.stdout,
                stderr=outcome.stderr,
                session_id=outcome.session_id,
                final_text=outcome.final_text,
                error="SESSION_ID_MISMATCH expected=%s got=%s" % (expected, outcome.session_id),
            )
        if not outcome.session_id and metadata.get("codex_session_id"):
            outcome = ExecutionOutcome(
                state="FAILED",
                returncode=outcome.returncode,
                stdout=outcome.stdout,
                stderr=outcome.stderr,
                session_id=None,
                final_text=outcome.final_text,
                error="SESSION_ID_MISSING",
            )
        self._persist_outcome(metadata, outcome)
        return self._load(job_id)

    def _fail_without_process(self, metadata: Dict[str, Any], reason: str) -> Dict[str, Any]:
        outcome = ExecutionOutcome(
            state="FAILED",
            returncode=None,
            stdout=b"",
            stderr=b"",
            session_id=metadata.get("codex_session_id"),
            final_text=None,
            error=reason,
        )
        self._persist_outcome(metadata, outcome, requested_state="FAILED")
        return self._load(metadata["job_id"])

    def dispatch_codex(
        self,
        task_id: str,
        prompt: Prompt,
        *,
        timeout_seconds: Optional[float] = None,
    ) -> Dict[str, Any]:
        if not isinstance(task_id, str) or not task_id.strip():
            raise RelayError("task_id must be a non-empty string")
        prompt_raw = _prompt_bytes(prompt)
        timeout = self.default_timeout_seconds if timeout_seconds is None else float(timeout_seconds)
        if timeout <= 0:
            raise RelayError("timeout_seconds must be positive")
        job_id = uuid.uuid4().hex
        job_dir = self._job_dir(job_id)
        try:
            job_dir.mkdir(parents=True, exist_ok=False)
            attempt_dir = self._attempt_dir(job_id, 1)
            attempt_dir.mkdir(parents=True, exist_ok=False)
            _atomic_write(attempt_dir / "prompt.bin", prompt_raw)
            metadata = {
                "schema_version": 1,
                "job_id": job_id,
                "task_id": task_id,
                "prompt_sha256": _sha256(prompt_raw),
                "created_at": _utc_now(),
                "updated_at": _utc_now(),
                "state": "QUEUED",
                "codex_cwd": str(self.codex_cwd),
                "codex_cli": getattr(self.adapter, "codex_executable", "fake"),
                "codex_session_id": None,
                "attempts": [
                    {
                        "attempt_no": 1,
                        "prompt_path": str((attempt_dir / "prompt.bin").relative_to(self.state_dir)),
                        "prompt_sha256": _sha256(prompt_raw),
                        "timeout_seconds": timeout,
                        "state": "QUEUED",
                        "started_at": None,
                        "completed_at": None,
                    }
                ],
            }
            self._save(metadata)
        except Exception:
            shutil.rmtree(job_dir, ignore_errors=True)
            raise
        lock = self._lock_for(job_id)
        with lock:
            try:
                handle = self.adapter.start(prompt_raw, self.codex_cwd, 1)
            except RelayError as exc:
                metadata = self._load(job_id)
                self._persist_outcome(
                    metadata,
                    ExecutionOutcome("FAILED", None, b"", b"", None, None, str(exc)),
                    requested_state="FAILED",
                )
                return self._load(job_id)
            except Exception as exc:
                metadata = self._load(job_id)
                self._persist_outcome(
                    metadata,
                    ExecutionOutcome("FAILED", None, b"", b"", None, None, "Codex launch failed: %s" % exc),
                    requested_state="FAILED",
                )
                return self._load(job_id)
            metadata = self._load(job_id)
            metadata["state"] = "RUNNING"
            metadata["updated_at"] = _utc_now()
            metadata["process_pid"] = handle.pid
            metadata["attempts"][0]["state"] = "RUNNING"
            metadata["attempts"][0]["started_at"] = metadata["updated_at"]
            self._handles[job_id] = handle
            self._save(metadata)
            return metadata

    def get_codex_status(self, job_id: str) -> Dict[str, Any]:
        with self._lock_for(job_id):
            metadata = self._load(job_id)
            if metadata["state"] in ACTIVE_STATES:
                metadata = self._observe(metadata)
            return {
                "job_id": metadata["job_id"],
                "task_id": metadata["task_id"],
                "state": metadata["state"],
                "codex_session_id": metadata.get("codex_session_id"),
                "attempt_no": metadata["attempts"][-1]["attempt_no"],
                "updated_at": metadata["updated_at"],
                "last_error": metadata.get("last_error"),
            }

    def get_codex_result(self, job_id: str) -> Dict[str, Any]:
        with self._lock_for(job_id):
            metadata = self._load(job_id)
            if metadata["state"] in ACTIVE_STATES:
                metadata = self._observe(metadata)
            if metadata["state"] not in TERMINAL_STATES:
                raise RelayError("job has no terminal result")
            result_path = self._owned_path(job_id, metadata["attempts"][-1].get("result_path"))
            result = _read_json(result_path)
            if result.get("job_id") != job_id:
                raise RelayError("result/job-ID mismatch")
            expected_hash = metadata["attempts"][-1].get("result_sha256")
            actual_hash = _sha256(_json_bytes(result))
            if expected_hash != actual_hash:
                raise RelayError("corrupt or mismatched result metadata")
            result["raw_stdout"] = self._owned_path(job_id, result["raw_stdout_path"]).read_bytes().decode("utf-8", "replace")
            result["raw_stderr"] = self._owned_path(job_id, result["raw_stderr_path"]).read_bytes().decode("utf-8", "replace")
            return result

    def continue_codex(
        self,
        job_id: str,
        prompt: Prompt,
        *,
        timeout_seconds: Optional[float] = None,
    ) -> Dict[str, Any]:
        prompt_raw = _prompt_bytes(prompt)
        with self._lock_for(job_id):
            metadata = self._load(job_id)
            if metadata["state"] in ACTIVE_STATES:
                raise RelayError("cannot continue an active job")
            session_id = metadata.get("codex_session_id")
            if not session_id:
                raise RelayError("cannot continue: Codex session identity is unavailable")
            attempt_no = len(metadata["attempts"]) + 1
            timeout = self.default_timeout_seconds if timeout_seconds is None else float(timeout_seconds)
            if timeout <= 0:
                raise RelayError("timeout_seconds must be positive")
            attempt_dir = self._attempt_dir(job_id, attempt_no)
            attempt_dir.mkdir(parents=True, exist_ok=False)
            _atomic_write(attempt_dir / "prompt.bin", prompt_raw)
            attempt = {
                "attempt_no": attempt_no,
                "prompt_path": str((attempt_dir / "prompt.bin").relative_to(self.state_dir)),
                "prompt_sha256": _sha256(prompt_raw),
                "timeout_seconds": timeout,
                "state": "QUEUED",
                "started_at": None,
                "completed_at": None,
            }
            metadata["attempts"].append(attempt)
            metadata["state"] = "CONTINUING"
            metadata["updated_at"] = _utc_now()
            self._save(metadata)
            try:
                handle = self.adapter.resume(session_id, prompt_raw, self.codex_cwd, attempt_no)
            except Exception as exc:
                self._persist_outcome(
                    metadata,
                    ExecutionOutcome(
                        "FAILED", None, b"", b"", session_id, None, "Codex continuation failed: %s" % exc
                    ),
                    requested_state="FAILED",
                )
                return self._load(job_id)
            metadata["state"] = "RUNNING"
            metadata["process_pid"] = handle.pid
            metadata["updated_at"] = _utc_now()
            attempt["state"] = "RUNNING"
            attempt["started_at"] = metadata["updated_at"]
            self._handles[job_id] = handle
            self._save(metadata)
            return metadata

    def cancel_codex(self, job_id: str) -> Dict[str, Any]:
        with self._lock_for(job_id):
            metadata = self._load(job_id)
            if metadata["state"] in TERMINAL_STATES:
                return self.get_codex_status(job_id)
            handle = self._handles.get(job_id)
            if handle is None:
                return self._fail_without_process(metadata, "PROCESS_LOST")
            outcome = self.adapter.cancel(handle)
            self._handles.pop(job_id, None)
            self._persist_outcome(metadata, outcome, requested_state="CANCELLED")
            return self.get_codex_status(job_id)
