"""Bounded PowerShell watchdog. Windows only; no third-party dependencies."""

import argparse
from datetime import datetime, timezone
import hashlib
import hmac
import json
import math
import os
from pathlib import Path
import secrets
import shutil
import stat
import subprocess
import sys
import threading
import time
import uuid

# Embeddable Python's isolated ._pth can omit the script directory.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from windows_job import Job

TRUSTED_ROOT = Path(r"D:\EA_LAB_CONTROL\trusted_exec")
# Selected fatal/termination NTSTATUS values, not ordinary PowerShell exit codes.
ABRUPT_STATUSES = {0xC0000005, 0xC000013A, 0xC0000409, 0x40000015}


def utc():
    return datetime.now(timezone.utc).isoformat()


def write_json(path, value):
    with path.open("w", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, ensure_ascii=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def classification(exit_code, timed_out=False):
    if timed_out:
        return "TIMEOUT"
    if exit_code == 0:
        return "SUCCESS"
    if exit_code is not None and (exit_code & 0xFFFFFFFF) in ABRUPT_STATUSES:
        return "ABRUPT_TERMINATION_SUSPECTED"
    return "SCRIPT_FAILED"


def final_classification(attempts):
    last = attempts[-1]["classification"]
    if len(attempts) == 1:
        return last
    return ("RETRY_SUCCESS_AFTER_ABRUPT_TERMINATION" if last == "SUCCESS"
            else "BLOCKED_C_ENVIRONMENT_DEPENDENCY")


def assert_no_reparse(path):
    # Never follow a junction/symlink into a different temp/log/cleanup root.
    for part in (path, *path.parents):
        try:
            attributes = part.lstat().st_file_attributes
        except FileNotFoundError:
            continue
        if attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
            raise OSError("reparse point in execution storage path")


def clean_attempt(path, root):
    assert_no_reparse(root)
    if path.parent != root or not path.name.startswith("attempt-"):
        raise OSError("invalid attempt cleanup boundary")
    assert_no_reparse(path)
    if not path.exists():
        return
    # Refuse cleanup if the target created any reparse points. Preserve evidence
    # instead of relying on platform/version-dependent recursive-delete behavior.
    for current, dirs, files in os.walk(path, followlinks=False):
        for name in dirs + files:
            assert_no_reparse(Path(current) / name)
    shutil.rmtree(path)


class OutputDigest:
    """Drain without retaining raw output, including script-echoed secrets."""
    def __init__(self, pipe, key):
        self.pipe = pipe
        self.count = 0
        self.digest = hmac.new(key, digestmod=hashlib.sha256)
        self.failed = False
        self.thread = threading.Thread(target=self.drain, daemon=True)
        self.thread.start()

    def drain(self):
        try:
            with self.pipe:
                while block := self.pipe.read(65536):
                    self.count += len(block)
                    self.digest.update(block)
        except OSError:
            self.failed = True

    def finish(self, path):
        self.thread.join(5)
        complete = not self.thread.is_alive() and not self.failed
        write_json(path, {"bytes": self.count, "hmac_sha256": self.digest.hexdigest(),
                          "complete": complete, "raw_output_retained": False})
        return complete


def run_attempt(command, env, record, journal, key, timeout):
    proc = None
    job = None
    readers = []
    started = time.monotonic()
    timed_out = False
    record.update(started_at=utc(), child_pid=None, exit_code=None,
                  tree_cleanup_confirmed=False, classification=None)
    journal("ATTEMPT_START", record)
    try:
        job = Job()
        proc = subprocess.Popen(
            command, shell=False, env=env, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            creationflags=0x00000004 | subprocess.CREATE_NO_WINDOW)  # suspended
        record["child_pid"] = proc.pid
        journal("CHILD_CREATED_SUSPENDED", record)
        readers = [OutputDigest(proc.stdout, key), OutputDigest(proc.stderr, key)]
        job.assign_and_resume(proc)
        try:
            proc.wait(timeout=max(0.001, timeout - (time.monotonic() - started)))
        except subprocess.TimeoutExpired:
            timed_out = True
        record["classification"] = classification(proc.returncode, timed_out)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        # Exception text can include command lines; record numeric/type metadata only.
        record.update(classification="BLOCKED_C_ENVIRONMENT_DEPENDENCY",
                      error_type=type(exc).__name__, winerror=getattr(exc, "winerror", None))
    finally:
        if job:
            try:
                record["tree_cleanup_confirmed"] = job.terminate_and_wait()
            except OSError:
                record["tree_cleanup_confirmed"] = False
            finally:
                job.close()
        if proc:
            # If assignment failed, the still-suspended child has no descendants.
            if proc.poll() is None:
                try:
                    proc.kill()  # exact Popen-owned handle, never a PID/name search
                except OSError:
                    record["tree_cleanup_confirmed"] = False
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                record["tree_cleanup_confirmed"] = False
            record["exit_code"] = proc.returncode
        output_complete = True
        for reader, field in zip(readers, ("stdout_path", "stderr_path")):
            output_complete = reader.finish(Path(record[field])) and output_complete
        if not readers:
            for field in ("stdout_path", "stderr_path"):
                write_json(Path(record[field]), {"bytes": 0, "complete": True,
                                                "raw_output_retained": False})
        record["output_complete"] = output_complete
        if not record["tree_cleanup_confirmed"] or not output_complete:
            record["classification"] = "BLOCKED_C_ENVIRONMENT_DEPENDENCY"
        record.update(ended_at=utc(), duration_seconds=round(time.monotonic() - started, 6))
    return record


def run(script, arguments, timeout=300, *, _root=TRUSTED_ROOT):
    """_root is only a fixture seam; the CLI always uses the fixed trusted root."""
    if os.name != "nt":
        raise OSError("Windows required")
    if not math.isfinite(timeout) or not 0 < timeout <= 86400:
        raise ValueError("timeout must be finite and in (0, 86400]")
    script = Path(script).resolve(strict=True)
    if script.suffix.lower() != ".ps1" or not script.is_file():
        raise ValueError("target must be an existing .ps1 file")
    root = Path(_root).absolute()
    temp_root, logs_root = root / "temp", root / "logs"
    for directory in (temp_root, logs_root):
        assert_no_reparse(directory)
        directory.mkdir(parents=True, exist_ok=True)
        assert_no_reparse(directory)
    run_id = uuid.uuid4().hex
    logs = logs_root / ("run-" + run_id)
    logs.mkdir()
    key = secrets.token_bytes(32)  # deliberately never persisted
    summary = {"run_id": run_id, "target_script": str(script),
               "argument_count": len(arguments), "argument_hash": hmac.new(
                   key, json.dumps(arguments, ensure_ascii=True).encode(), hashlib.sha256).hexdigest(),
               "hash_kind": "HMAC-SHA256/ephemeral-unlogged-key",
               "runner_pid": os.getpid(), "started_at": utc(),
               "timeout_seconds_per_attempt": timeout, "attempts": [],
               "logs_path": str(logs)}

    def journal(event, record):
        with (logs / "events.jsonl").open("a", encoding="utf-8") as stream:
            stream.write(json.dumps({"event": event, "at": utc(), **summary,
                                     "attempt": record}) + "\n")
            stream.flush()
            os.fsync(stream.fileno())

    # Absolute executable avoids PATH hijacking; no global environment mutation.
    powershell = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32/WindowsPowerShell/v1.0/powershell.exe"
    command = [str(powershell), "-NoLogo", "-NoProfile", "-NonInteractive",
               "-File", str(script), *arguments]
    journal("RUN_START", {})
    for attempt in range(2):
        attempt_started = time.monotonic()
        temp = temp_root / ("attempt-" + run_id + "-" + str(attempt))
        env = os.environ.copy()
        env.update(TEMP=str(temp), TMP=str(temp), TMPDIR=str(temp))
        record = {"retry_count": attempt, "temp_path": str(temp),
                  "started_at": utc(), "child_pid": None, "exit_code": None,
                  "stdout_path": str(logs / f"attempt-{attempt}.stdout.json"),
                  "stderr_path": str(logs / f"attempt-{attempt}.stderr.json")}
        try:
            temp.mkdir()
            run_attempt(command, env, record, journal, key, timeout)
        except OSError as exc:
            record.update(classification="BLOCKED_C_ENVIRONMENT_DEPENDENCY",
                          error_type=type(exc).__name__, winerror=getattr(exc, "winerror", None),
                          ended_at=utc())
        finally:
            record.setdefault("duration_seconds", round(time.monotonic() - attempt_started, 6))
            record.setdefault("ended_at", utc())
            try:
                if not record.get("tree_cleanup_confirmed"):
                    raise OSError("tree cleanup not confirmed; preserve temp")
                clean_attempt(temp, temp_root)
                record["temp_cleaned"] = True
            except OSError as exc:
                record.update(temp_cleaned=False, cleanup_error_type=type(exc).__name__)
                record["classification"] = "BLOCKED_C_ENVIRONMENT_DEPENDENCY"
        summary["attempts"].append(record)
        journal("ATTEMPT_FINISHED", record)
        if record["classification"] != "ABRUPT_TERMINATION_SUSPECTED":
            break
    summary.update(classification=final_classification(summary["attempts"]),
                   retry_count=len(summary["attempts"]) - 1, ended_at=utc())
    write_json(logs / "summary.json", summary)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float, default=300,
                        help="seconds per attempt, >0 and <=86400 (default 300)")
    parser.add_argument("script")
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        result = run(args.script, args.arguments, args.timeout)
    except (OSError, ValueError) as exc:
        # No raw exception messages (may contain arguments/environment values).
        print(json.dumps({"classification": "BLOCKED_C_ENVIRONMENT_DEPENDENCY",
                          "error_type": type(exc).__name__,
                          "winerror": getattr(exc, "winerror", None)}))
        return 125
    print(json.dumps(result))
    state = result["classification"]
    if state in ("SUCCESS", "RETRY_SUCCESS_AFTER_ABRUPT_TERMINATION"):
        return 0
    if state == "SCRIPT_FAILED":
        code = result["attempts"][-1]["exit_code"]
        return code if code is not None and 1 <= code <= 255 else 1
    return 124 if state == "TIMEOUT" else 125


if __name__ == "__main__":
    sys.exit(main())
