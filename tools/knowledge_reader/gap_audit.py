"""Source-pinned Second Brain gap audit and non-authoritative feedback proposal.

This is deliberately a consumer of the existing Knowledge Reader and QI owners.
It never imports research, assigns EA grades, or edits any canonical source.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

try:
    from .binding import require_verified
    from .reader import ReaderError, build_index, git_bytes, git_tree, query_packet, safe_posix
except ImportError:
    from binding import require_verified
    from reader import ReaderError, build_index, git_bytes, git_tree, query_packet, safe_posix

AUDIT_SCHEMA = "ea-lab-second-brain-gap-feedback/1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
EXP_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
FIELDS = ("ea", "variant", "build", "config", "symbol", "timeframe", "window", "data_source")


def verified_evidence(repo: Path, ref: str, path: str | None,
                      digest: str | None, experiment_id: str | None) -> dict:
    """A tracked, byte-verified pointer, *not* a claim about test validity."""
    if path is None and digest is None and experiment_id is None:
        return {"state": "NO_EVIDENCE_SUPPLIED", "ref": None, "sha256": None,
                "experiment_id": None}
    if not all(isinstance(value, str) and value for value in (path, digest, experiment_id)):
        raise ReaderError("evidence-path, evidence-sha256 and experiment-id must be supplied together")
    if not SHA256.fullmatch(digest):
        raise ReaderError("evidence-sha256 must be lowercase 64-hex")
    if not EXP_ID.fullmatch(experiment_id):
        raise ReaderError("invalid experiment-id")
    safe = safe_posix(path)
    if not safe.startswith(("docs/memory_control/experiment_events/",
                            "factory/runs/", "docs/research/")):
        raise ReaderError("evidence path is outside existing allowed evidence owners")
    tree = git_tree(repo, ref)
    if tree.get(safe) != "100644":
        raise ReaderError("evidence path missing or not a regular tracked blob at pinned commit")
    raw = git_bytes(repo, ref, safe)
    if hashlib.sha256(raw).hexdigest() != digest:
        raise ReaderError("evidence hash mismatch at pinned commit")
    return {"state": "POINTER_VERIFIED_CONTENT_NOT_ADJUDICATED", "ref": safe,
            "sha256": digest, "experiment_id": experiment_id}


def audit(index: dict, question: str, intake: dict, evidence: dict) -> dict:
    try:
        require_verified(index)
    except (TypeError, ValueError, KeyError) as exc:
        raise ReaderError("unverified Second Brain index") from exc
    packet = query_packet(index, question, intake)
    health = index["health"]
    problems = [
        {"kind": problem.get("kind", "UNKNOWN"), "path": problem.get("path"),
         "source_ids": problem.get("source_ids"),
         "target": problem.get("target")}
        for problem in health.get("problems", [])
    ]
    gaps = []
    if not packet["matches"]:
        gaps.append({"kind": "NO_KEYWORD_MATCH", "meaning": "Not proof of no prior research/experiment"})
    if packet["negative_memory"]["status"] == "NO_MATCH":
        gaps.append({"kind": "NEGATIVE_MEMORY_NO_KEYWORD_MATCH",
                     "meaning": "Existing experiment owners still require inspection"})
    if evidence["state"] == "NO_EVIDENCE_SUPPLIED":
        gaps.append({"kind": "NO_VERIFIED_EXPERIMENT_POINTER",
                     "meaning": "Do not claim this question has a measured result"})
    for issue in problems:
        gaps.append({"kind": "LIBRARY_HEALTH_PROBLEM", "issue": issue})
    return {
        "schema_version": AUDIT_SCHEMA,
        "authority": "RESEARCH_ONLY_DRAFT_NOT_IMPORTED",
        "canonical": {"ref": index["canonical"]["ref"], "sha": index["canonical"]["sha"]},
        "question": packet["question"],
        "problem_intake": packet["problem_intake"],
        "research_matches": packet["matches"],
        "negative_memory": packet["negative_memory"],
        "library_health": {"status": health["status"],
                           "canonical_documents": health["canonical_documents"],
                           "registry_records": health["registry_records"],
                           "problems": problems},
        "verified_evidence_pointer": evidence,
        "open_gaps": gaps,
        "review_required": True,
        "intake_status": "DRAFT_NOT_IMPORTED",
        "qi_factory_authority": False,
        "test_verdict": None,
        "performance_grade": None,
        "candidate_status": None,
        "automatic_actions": [],
        "next_gate": "Main CT reviews existing source/negative memory and exact experiment owners; "
                     "authorized intake is a separate controlled operation.",
    }


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Exact-ref, read-only EA_LAB Second Brain gap/feedback draft")
    p.add_argument("--repo", required=True, type=Path)
    p.add_argument("--ref", required=True)
    p.add_argument("--expected-sha", required=True)
    p.add_argument("--question", required=True)
    p.add_argument("--output", required=True, type=Path)
    p.add_argument("--evidence-path")
    p.add_argument("--evidence-sha256")
    p.add_argument("--experiment-id")
    for field in FIELDS:
        p.add_argument("--" + field.replace("_", "-"))
    args = p.parse_args(argv)
    try:
        repo = args.repo.resolve(strict=True)
        index = build_index(repo, args.ref, args.expected_sha)
        evidence = verified_evidence(repo, args.ref, args.evidence_path,
                                     args.evidence_sha256, args.experiment_id)
        intake = {field: getattr(args, field) for field in FIELDS}
        result = audit(index, args.question, intake, evidence)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                               encoding="utf-8")
    except (ReaderError, OSError, TypeError, ValueError, KeyError) as exc:
        print("GAP_AUDIT_BLOCKED: " + str(exc), file=sys.stderr)
        return 2
    print(json.dumps({"status": "DRAFT_NOT_IMPORTED", "output": str(args.output),
                      "canonical_sha": result["canonical"]["sha"],
                      "open_gaps": len(result["open_gaps"])}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
