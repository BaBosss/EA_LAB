"""Read-only Long Job intake using the existing EA_LAB Harness validators.

This tool never starts/retries a job, writes canonical state, or grants authority.
Its admission contract must be supplied and hash-pinned by the task owner/intake.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "ea_lab_harness"))
from harness import HarnessValidationError, validate_assurance_packet


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path.name}")
    return value


def observe_job(job_dir: Path, expected_base: str) -> dict:
    """Do not infer safe retry from a missing/dead process or a terminal failure."""
    answer = {"job_id": job_dir.name, "authority_granted": False,
              "automatic_retry_allowed": False, "status": "UNKNOWN",
              "next_action": "INSPECT_EXISTING_ATTEMPT"}
    if re.fullmatch(r"[0-9a-f]{40}", expected_base) is None:
        raise ValueError("expected base must be an exact Git SHA")
    if not job_dir.exists():
        return {**answer, "status": "NO_ATTEMPT_RECORD", "next_action": "CHECK_CONTRACT_AND_LANE_BEFORE_DISPATCH"}
    try:
        # Long Jobs consumes request.json to avoid retaining raw arguments.
        # job.json is its durable public identity/command-hash record.
        request = read_object(job_dir / "job.json")
        state = read_object(job_dir / "state.json")
        if request.get("job_id") != job_dir.name or state.get("job_id") != job_dir.name:
            raise ValueError("job identity mismatch")
        if request.get("base_sha") != expected_base:
            return {**answer, "status": "SOURCE_MISMATCH", "next_action": "RECONCILE_INPUT_IDENTITY"}
        phase = state.get("state")
        answer["process_state"] = phase
        if phase in {"STARTING", "RUNNING", "POSTCONDITION_RUNNING"}:
            return {**answer, "status": "ATTEMPT_IN_PROGRESS_OR_LOST", "next_action": "STATUS_LONG_JOB_AND_INSPECT_BEFORE_RETRY"}
        if phase != "COMPLETE":
            return {**answer, "status": "ATTEMPT_NOT_COMPLETE"}
        result = read_object(job_dir / "result.json")
        if result.get("job_id") != job_dir.name or result.get("state") != "COMPLETE":
            raise ValueError("terminal records disagree")
        if type(result.get("exit_code")) is not int or result["exit_code"] != 0:
            raise ValueError("COMPLETE without integer zero exit")
        if request.get("postcondition_file_path"):
            if type(result.get("postcondition_exit_code")) is not int or result["postcondition_exit_code"] != 0:
                raise ValueError("postcondition missing/failed")
            answer["postconditions"] = "PASSED"
        else:
            answer["postconditions"] = "NOT_CONFIGURED"
        return {**answer, "status": "EXECUTION_COMPLETE_UNACCEPTED", "next_action": "VALIDATE_EVIDENCE_AND_REVIEW"}
    except (OSError, ValueError, TypeError) as exc:
        return {**answer, "reason": str(exc)}


def execution_binding(job_dir: Path, expected_base: str) -> dict:
    """Bind a completed attempt's durable records and logs, including absence.

    The integrator must pin this binding in the admission and reviewed packet.
    It establishes byte identity, not authenticated proof of who ran the job.
    """
    if observe_job(job_dir, expected_base)["status"] != "EXECUTION_COMPLETE_UNACCEPTED":
        raise ValueError("execution binding requires a completed attempt")
    root = job_dir.resolve(strict=True)
    files = [root / name for name in ("job.json", "state.json", "result.json")]
    logs = root / "logs"
    if not logs.is_dir() or logs.is_symlink():
        raise ValueError("execution logs missing or redirected")
    files.extend(sorted(logs.rglob("*")))
    hashes = {}
    for path in files:
        if path.is_symlink() or not path.resolve(strict=True).is_relative_to(root):
            raise ValueError("execution evidence redirected outside attempt")
        if path.is_file():
            hashes[path.relative_to(root).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    if not any(name.startswith("logs/") for name in hashes):
        raise ValueError("execution logs empty")
    return {"job_id": job_dir.name, "base_sha": expected_base, "files_sha256": hashes}


def qualify_assurance(packet: dict, admission: dict, artifact_root: Path, current_head: str,
                      job_dir: Path) -> dict:
    """Bind independently supplied contract/reviewer policy before Harness intake."""
    if admission.get("schema_version") != "ea-lab-job-admission/v1":
        raise ValueError("unsupported admission contract")
    expected = admission.get("assurance_contract")
    if not isinstance(expected, dict) or packet.get("contract") != expected:
        raise ValueError("assurance contract differs from pinned admission contract")
    binding = execution_binding(job_dir, expected.get("base_sha", ""))
    if admission.get("job_id") != binding["job_id"] or expected.get("execution_binding") != binding:
        raise ValueError("reviewed execution binding differs from actual attempt")
    policy = admission.get("review_policy")
    if not isinstance(policy, dict):
        raise ValueError("review policy missing")
    for field in ("independent_required", "different_family_required"):
        if type(policy.get(field)) is not bool:
            raise ValueError("review policy must be explicit booleans")
    review = packet.get("review", {})
    if not isinstance(review, dict):
        raise ValueError("review record malformed")
    for field in ("independent_required", "different_family_required"):
        if review.get(field) is not policy[field]:
            raise ValueError("review policy was weakened or changed")
    identity = {key: review.get(key) for key in ("reviewer_id", "reviewer_family", "reviewer_model")}
    for field in ("author_id", "author_family"):
        if not isinstance(expected.get(field), str) or not expected[field].strip():
            raise ValueError("author identity must be explicit")
    for value in identity.values():
        if not isinstance(value, str) or not value.strip():
            raise ValueError("reviewer identity must be explicit")
    if identity not in policy.get("qualified_reviewers", []):
        raise ValueError("reviewer identity not qualified by admission contract")
    if policy["independent_required"] and review["reviewer_id"].strip().casefold() == expected["author_id"].strip().casefold():
        raise ValueError("self-review is not independent")
    if policy["different_family_required"] and review["reviewer_family"].strip().casefold() == expected["author_family"].strip().casefold():
        raise ValueError("same-family review cannot meet different-family requirement")
    root = artifact_root.resolve(strict=True)
    hashes = {}
    artifacts = packet.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        raise ValueError("artifact records missing or malformed")
    for artifact in artifacts:
        if not isinstance(artifact, dict):
            raise ValueError("artifact record malformed")
        path = artifact.get("path", "")
        # Canonical repo-relative paths only; never follow outside the evidence root.
        if not isinstance(path, str) or not path or ":" in path or "\\" in path:
            raise ValueError("invalid artifact path")
        rel = Path(path)
        if rel.is_absolute() or ".." in rel.parts:
            raise ValueError("artifact escapes evidence root")
        full = (root / rel).resolve(strict=True)
        if not full.is_relative_to(root) or not full.is_file():
            raise ValueError("artifact escapes evidence root or is not a file")
        if path in hashes:
            raise ValueError("duplicate artifact path")
        hashes[path] = hashlib.sha256(full.read_bytes()).hexdigest()
    return validate_assurance_packet(packet, current_candidate_sha=current_head, artifact_hashes=hashes)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--job-dir", type=Path, required=True)
    parser.add_argument("--expected-base", required=True)
    parser.add_argument("--assurance", type=Path)
    parser.add_argument("--admission", type=Path)
    parser.add_argument("--admission-sha256")
    parser.add_argument("--artifact-root", type=Path)
    parser.add_argument("--current-head")
    args = parser.parse_args(argv)
    try:
        answer = observe_job(args.job_dir, args.expected_base)
        extra = (args.assurance, args.admission, args.admission_sha256, args.artifact_root, args.current_head)
        if any(extra):
            if not all(extra):
                raise ValueError("assurance intake requires all five evidence/identity arguments")
            if answer["status"] != "EXECUTION_COMPLETE_UNACCEPTED":
                raise ValueError("attempt is not complete; cannot intake assurance")
            if hashlib.sha256(args.admission.read_bytes()).hexdigest() != args.admission_sha256:
                raise ValueError("admission contract hash mismatch")
            admission = read_object(args.admission)
            if admission.get("job_id") != args.job_dir.name:
                raise ValueError("admission job mismatch")
            expected = admission.get("assurance_contract", {})
            if not isinstance(expected, dict) or expected.get("base_sha") != args.expected_base:
                raise ValueError("admission base mismatch")
            result = qualify_assurance(read_object(args.assurance), admission, args.artifact_root, args.current_head, args.job_dir)
            answer.update(status="ASSURANCE_VALIDATED", next_action="AUTHORIZED_INTEGRATOR_INTAKE", assurance=result)
        print(json.dumps(answer, ensure_ascii=False, indent=2))
        return 0 if answer["status"] in {"EXECUTION_COMPLETE_UNACCEPTED", "ASSURANCE_VALIDATED"} else 2
    except (OSError, ValueError, TypeError, HarnessValidationError) as exc:
        print(json.dumps({"status": "REFUSED", "reason": str(exc), "authority_granted": False, "automatic_retry_allowed": False}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
