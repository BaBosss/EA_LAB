"""Offline V2 serial foundation. No production runner or model dispatch surface."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

import safe_tester_executor_mcp as safe


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def digest(value):
    return hashlib.sha256(encoded(value)).hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def git_head(root):
    return subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()


def inside(root, relative):
    return safe.resolve_set_inside(root, relative)


def validate_contract(root, contract, head_reader=git_head):
    keys = {"schema", "mode", "head", "manifest", "manifest_sha256", "receipt",
            "receipt_sha256", "set_sha256", "artifact", "artifact_sha256", "lane"}
    if set(contract) != keys or contract["schema"] != "hermes-batch/1":
        raise ValueError("contract schema mismatch")
    if contract["mode"] != "FIXTURE_ONLY" or contract["lane"] != "FIXTURE_NO_MT5":
        raise ValueError("only fixture mode/lane is qualified")
    if not re.fullmatch(r"[0-9a-f]{40}", contract["head"]) or head_reader(root) != contract["head"]:
        raise ValueError("contract HEAD mismatch")
    for key in ("manifest_sha256", "receipt_sha256", "set_sha256", "artifact_sha256"):
        if not re.fullmatch(r"[0-9a-f]{64}", contract[key]):
            raise ValueError("invalid SHA binding")
    manifest = inside(root, contract["manifest"])
    safe.verify_sha(manifest, contract["manifest_sha256"], "manifest")
    receipt = safe.verify_receipt_registry(inside(root, contract["receipt"]), contract["receipt_sha256"])
    if receipt["artifact_sha256"] != contract["artifact_sha256"]:
        raise ValueError("receipt artifact identity mismatch")
    safe.verify_sha(inside(root, contract["artifact"]), contract["artifact_sha256"], "artifact")
    rows = safe._read_manifest(manifest)
    if not rows:
        raise ValueError("empty manifest")
    if any(set(row) != safe.REQUIRED_COLUMNS or
           any(not isinstance(value, str) for value in row.values()) for row in rows):
        raise ValueError("malformed manifest row")
    for field in ("cell_id", "report_name"):
        values = [row[field].casefold() for row in rows]
        if len(set(values)) != len(values):
            raise ValueError(f"duplicate {field}")
    for row in rows:
        safe._validate_row(root, row, contract["set_sha256"])
        if row["cell_id"] != row["cell_id"].strip():
            raise ValueError("noncanonical cell id")
    return rows


def durable_write(path, data):
    with path.open("xb") as handle:
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())


def read_checkpoint(path, fingerprint, rows, state, expected_sha):
    if path.is_symlink() or path.resolve(strict=True).parent != state or path.stat().st_nlink != 1:
        raise ValueError("checkpoint path escape")
    safe.verify_sha(path, expected_sha, "checkpoint")
    raw = path.read_bytes()
    if not raw.endswith(b"\n"):
        raise ValueError("torn checkpoint")
    events, statuses = [], {}
    previous = "0" * 64
    for line in raw.splitlines():
        event = json.loads(line, object_pairs_hook=unique_object)
        if set(event) != {"seq", "contract", "previous", "cell_id", "status", "output_sha256", "hash"}:
            raise ValueError("checkpoint schema mismatch")
        payload = {key: value for key, value in event.items() if key != "hash"}
        if (event["hash"] != digest(payload) or event["previous"] != previous
                or event["seq"] != len(events) or event["contract"] != fingerprint):
            raise ValueError("checkpoint identity/hash mismatch")
        cell = event["cell_id"]
        index = len(statuses) if cell not in statuses else len(statuses) - 1
        if index >= len(rows) or cell != rows[index]["cell_id"]:
            raise ValueError("checkpoint cell order mismatch")
        status = event["status"]
        if status == "STARTED":
            if cell in statuses or (statuses and list(statuses.values())[-1] == "STARTED") or event["output_sha256"] is not None:
                raise ValueError("duplicate or invalid cell start")
        elif status in {"COMPLETE", "MECHANICAL_FAIL"}:
            if statuses.get(cell) != "STARTED":
                raise ValueError("invalid terminal transition")
            output = inside(state, f"{cell}.output.json")
            safe.verify_sha(output, event["output_sha256"], "output")
            result = json.loads(output.read_bytes())
            validate_result(state, cell, result)
            if result["status"] != status:
                raise ValueError("terminal status mismatch")
        else:
            raise ValueError("unknown checkpoint state")
        statuses[cell] = status
        previous = event["hash"]
        events.append(event)
    if not events:
        raise ValueError("empty checkpoint")
    if "STARTED" in statuses.values():
        raise ValueError("AMBIGUOUS_STARTED: reconciliation required; replay denied")
    return events, statuses


def validate_result(state, cell, result):
    if set(result) != {"cell_id", "status", "reason", "artifacts"} or result["cell_id"] != cell:
        raise ValueError("result schema/identity mismatch")
    if result["status"] not in {"COMPLETE", "MECHANICAL_FAIL"}:
        raise ValueError("nonmechanical terminal status denied")
    if result["reason"] not in {"FIXTURE_OK", "FIXTURE_ENVIRONMENT_FAILURE", "RUNNER_EXCEPTION"}:
        raise ValueError("unqualified result reason")
    artifacts = result["artifacts"]
    if not isinstance(artifacts, list) or (result["status"] == "COMPLETE" and not artifacts):
        raise ValueError("missing artifacts")
    paths = set()
    for item in artifacts:
        if set(item) != {"path", "sha256"} or item["path"].casefold() in paths:
            raise ValueError("artifact schema/duplicate mismatch")
        paths.add(item["path"].casefold())
        safe.verify_sha(inside(state, item["path"]), item["sha256"], "report artifact")


def run_batch(root, contract, state, *, runner, resume_sha=None, replay_cells=(),
              head_reader=git_head, on_checkpoint=None):
    """Trusted Python fixture seam only. Manifest order owns every dispatch.

    Resume SHA must come from the controller's retained checkpoint receipt, not
    a hash recomputed from untrusted state. STARTED is never automatically retried.
    """
    root = safe.workspace_root(root)
    contract = json.loads(encoded(contract))
    rows = validate_contract(root, contract, head_reader)
    state = Path(state).resolve()
    state.relative_to(root)
    if state == root:
        raise ValueError("state must be a dedicated child directory")
    state.mkdir(parents=True, exist_ok=True)
    lock = state / "batch.lock"
    # Exclusive persistent lock: process death intentionally needs reconciliation.
    with lock.open("x"):
        pass
    try:
        checkpoint = state / "checkpoint.jsonl"
        fingerprint = digest({"contract": contract, "workspace": str(root),
                              "state": str(state), "executor_sha256": safe.sha256_path(Path(__file__)),
                              "safe_executor_sha256": safe.sha256_path(Path(safe.__file__))})
        events, statuses = [], {}
        if resume_sha is not None:
            events, statuses = read_checkpoint(checkpoint, fingerprint, rows, state, resume_sha)
        elif any(path != lock for path in state.iterdir()):
            raise ValueError("existing state: explicit verified resume required")
        if replay_cells:
            raise ValueError("explicit cell replay denied; only unresolved manifest cells may run")
        retained_sha = resume_sha

        def append(cell, status, output_sha=None):
            nonlocal retained_sha
            if (checkpoint.is_symlink() or checkpoint.resolve().parent != state or
                    (checkpoint.exists() and checkpoint.stat().st_nlink != 1)):
                raise ValueError("checkpoint path escape")
            if retained_sha is not None:
                safe.verify_sha(checkpoint, retained_sha, "checkpoint")
            elif checkpoint.exists():
                raise ValueError("unexpected checkpoint creation")
            event = {"seq": len(events), "contract": fingerprint,
                     "previous": events[-1]["hash"] if events else "0" * 64,
                     "cell_id": cell, "status": status, "output_sha256": output_sha}
            event["hash"] = digest(event)
            with checkpoint.open("ab") as handle:
                handle.write(encoded(event) + b"\n")
                handle.flush()
                os.fsync(handle.fileno())
            events.append(event)
            retained_sha = safe.sha256_path(checkpoint)
            if on_checkpoint is not None:
                on_checkpoint({"cell_id": cell, "status": status,
                               "checkpoint_sha256": retained_sha})

        for row in rows:
            if row["cell_id"] in statuses:
                continue
            validate_contract(root, contract, head_reader)
            cell = row["cell_id"]
            append(cell, "STARTED")
            try:
                result = runner(dict(row), state)
            except Exception:
                result = {"cell_id": cell, "status": "MECHANICAL_FAIL",
                          "reason": "RUNNER_EXCEPTION", "artifacts": []}
            validate_result(state, cell, result)
            output = state / f"{cell}.output.json"
            durable_write(output, encoded(result))
            append(cell, result["status"], safe.sha256_path(output))
            statuses[cell] = result["status"]
        validate_contract(root, contract, head_reader)
        verified_events, verified_statuses = read_checkpoint(checkpoint, fingerprint, rows, state, retained_sha)
        if verified_events != events or verified_statuses != statuses:
            raise ValueError("checkpoint changed during execution")
        return {"status": "ACCOUNTED", "cells": statuses, "authority_granted": False,
                "checkpoint_sha256": retained_sha}
    finally:
        lock.unlink()


def fixture_runner(row, state):
    """Synthetic report, explicitly non-performance evidence; never starts MT5."""
    report = state / f"{row['cell_id']}.fixture.json"
    durable_write(report, encoded({"fixture_only": True, "row": row}))
    return {"cell_id": row["cell_id"], "status": "COMPLETE", "reason": "FIXTURE_OK",
            "artifacts": [{"path": report.name, "sha256": safe.sha256_path(report)}]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--contract-sha256", required=True)
    parser.add_argument("--state", required=True, type=Path)
    parser.add_argument("--resume-sha256")
    args = parser.parse_args()
    try:
        safe.verify_sha(args.contract, args.contract_sha256, "contract")
        result = run_batch(args.workspace, json.loads(args.contract.read_bytes(), object_pairs_hook=unique_object), args.state,
                           runner=fixture_runner, resume_sha=args.resume_sha256,
                           on_checkpoint=lambda receipt: print(json.dumps({"checkpoint_receipt": receipt}), flush=True))
        print(json.dumps(result, sort_keys=True))
        return 0
    except (ValueError, OSError, KeyError, TypeError) as exc:
        print(json.dumps({"status": "BLOCKED_MECHANICAL", "error": str(exc), "authority_granted": False}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
