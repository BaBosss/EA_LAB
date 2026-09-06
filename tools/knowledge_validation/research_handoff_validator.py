from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path, PurePosixPath
from typing import Any

SCHEMA = "ea_lab_research_handoff/1"
UNRESOLVED = {"UNKNOWN", "SEMANTICS_REQUIRED", "NOT_EXECUTED"}
SEMANTIC_STATES = UNRESOLVED | {"RESOLVED", "CLOSED_PRIOR_EVIDENCE"}
ALLOWED_NEXT_ACTIONS = {
    "KEEP_FROZEN",
    "CREATE_SEPARATE_RESEARCH_CONTRACT",
    "STOP_CLOSED_PATH",
    "FREEZE_TARGET_SEMANTICS",
    "CREATE_SEMANTICS_PACKET",
    "RETURN_ABSTENTION_AND_OWNER_POINTER",
}
FORBIDDEN_REQUESTS = {"AUTO_REGISTER", "FACTORY_EXECUTE", "CREATE_EXPERIMENT", "GRADE", "PROMOTE", "DEPLOY", "TRADE"}


def git_text(repo: Path, ref: str, path: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(repo), "show", f"{ref}:{path}"],
        check=False,
        capture_output=True,
    )
    if completed.returncode != 0:
        raise ValueError(f"git source missing: {ref}:{path}")
    return completed.stdout.decode("utf-8", errors="strict")


def load_source_registry(repo: Path, ref: str) -> dict[str, dict[str, Any]]:
    registry: dict[str, dict[str, Any]] = {}
    raw = git_text(repo, ref, "knowledge/01_sources/source_registry.jsonl")
    for line in raw.splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        registry[row["source_id"]] = row
    return registry


def validate_handoff(handoff: dict[str, Any], repo: Path) -> dict[str, Any]:
    errors: list[dict[str, str]] = []

    def add(code: str, detail: str) -> None:
        errors.append({"code": code, "detail": detail})

    if not isinstance(handoff, dict):
        return {
            "schema_version": "ea_lab_research_handoff_validation/1",
            "validation_status": "REFUSED",
            "handoff_readiness": "REFUSED",
            "execution_readiness": "BLOCKED_VALIDATION_ERRORS",
            "errors": [{"code": "INVALID_INPUT_NOT_OBJECT", "detail": type(handoff).__name__}],
            "unresolved_semantics": [],
            "automatic_store_write": False,
            "semantic_correctness_proven": False,
        }

    base = handoff.get("source_commit")
    if handoff.get("schema_version") != SCHEMA:
        add("INVALID_SCHEMA_VERSION", str(handoff.get("schema_version")))
    if handoff.get("authority") != "RESEARCH_ONLY":
        add("INVALID_AUTHORITY", str(handoff.get("authority")))
    if not isinstance(base, str) or re.fullmatch(r"[0-9a-f]{40}", base) is None:
        add("INVALID_SOURCE_COMMIT", str(base))
        base = ""
    if handoff.get("auto_registration_requested") is not False:
        add("AUTO_REGISTRATION_FORBIDDEN", "auto_registration_requested must be false")
    if handoff.get("execution_requested") is not False:
        add("EXECUTION_REQUEST_FORBIDDEN", "execution_requested must be false")
    requested_raw = handoff.get("requested_actions")
    if not isinstance(requested_raw, list) or any(not isinstance(item, str) for item in requested_raw):
        add("REQUESTED_ACTIONS_INVALID", "requested_actions must be a list of strings")
        requested: set[str] = set()
    else:
        requested = set(requested_raw)
    for forbidden in sorted(requested & FORBIDDEN_REQUESTS):
        add("FORBIDDEN_REQUEST", forbidden)

    registry: dict[str, dict[str, Any]] = {}
    if base:
        commit = subprocess.run(["git", "-C", str(repo), "cat-file", "-e", f"{base}^{{commit}}"], check=False)
        if commit.returncode != 0:
            add("SOURCE_COMMIT_UNAVAILABLE", base)
        else:
            try:
                registry = load_source_registry(repo, base)
            except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
                add("SOURCE_REGISTRY_UNAVAILABLE", str(exc))

    citations: dict[str, dict[str, Any]] = {}
    for citation in handoff.get("citations", []) if isinstance(handoff.get("citations"), list) else []:
        if not isinstance(citation, dict):
            add("CITATION_INVALID", type(citation).__name__)
            continue
        citation_id = citation.get("citation_id")
        if not isinstance(citation_id, str) or not citation_id:
            add("CITATION_ID_MISSING", "citation_id")
            continue
        if citation_id in citations:
            add("DUPLICATE_CITATION_ID", citation_id)
            continue
        citations[citation_id] = citation
        path = citation.get("path")
        anchor = citation.get("anchor_text")
        depth = citation.get("evidence_depth")
        if not isinstance(path, str) or not path or PurePosixPath(path).is_absolute() or ".." in PurePosixPath(path).parts:
            add("CITATION_PATH_INVALID", citation_id)
            continue
        if not isinstance(anchor, str) or not anchor:
            add("CITATION_ANCHOR_MISSING", citation_id)
            continue
        if not isinstance(depth, str) or not depth:
            add("CITATION_EVIDENCE_DEPTH_MISSING", citation_id)
        if base:
            try:
                content = git_text(repo, base, path)
                if anchor not in content:
                    add("CITATION_ANCHOR_NOT_FOUND", citation_id)
                source_id = citation.get("source_id")
                if source_id:
                    if source_id not in registry:
                        add("SOURCE_ID_UNREGISTERED", f"{citation_id}:{source_id}")
                    elif registry[source_id].get("authority") != "RESEARCH_ONLY":
                        add("SOURCE_ID_AUTHORITY_INVALID", f"{citation_id}:{source_id}")
                    if path.startswith("knowledge/02_research_cards/") and f"source_id: {source_id}" not in content:
                        add("RESEARCH_CARD_SOURCE_ID_MISMATCH", f"{citation_id}:{source_id}")
            except (ValueError, UnicodeDecodeError) as exc:
                add("CITATION_SOURCE_UNAVAILABLE", f"{citation_id}:{exc}")

    questions = handoff.get("questions")
    if not isinstance(questions, list) or len(questions) != 6:
        add("QUESTION_COUNT_INVALID", str(len(questions) if isinstance(questions, list) else "not-list"))
        questions = questions if isinstance(questions, list) else []
    question_ids: set[str] = set()
    unresolved: list[dict[str, str]] = []
    for question in questions:
        if not isinstance(question, dict):
            add("QUESTION_INVALID", type(question).__name__)
            continue
        question_id = question.get("question_id")
        if not isinstance(question_id, str) or not question_id:
            add("QUESTION_ID_MISSING", "question_id")
            continue
        if question_id in question_ids:
            add("DUPLICATE_QUESTION_ID", question_id)
        question_ids.add(question_id)
        for field in ("answer_code", "answer_summary", "abstentions"):
            value = question.get(field)
            if (not isinstance(value, str) or not value) and not (field == "abstentions" and isinstance(value, list) and value):
                add("QUESTION_FIELD_MISSING", f"{question_id}:{field}")
        used = question.get("citation_ids")
        contradictions = question.get("contradiction_citation_ids")
        negative = question.get("negative_memory_citation_ids")
        if not isinstance(used, list) or not used:
            add("CITATIONS_REQUIRED", question_id)
            used = []
        if not isinstance(contradictions, list) or not contradictions:
            add("CONTRADICTIONS_REQUIRED", question_id)
            contradictions = []
        if not isinstance(negative, list) or not negative:
            add("NEGATIVE_MEMORY_REQUIRED", question_id)
            negative = []
        for citation_id in [*used, *contradictions, *negative]:
            if citation_id not in citations:
                add("QUESTION_CITATION_UNRESOLVED", f"{question_id}:{citation_id}")
        if not set(contradictions).issubset(set(used)):
            add("CONTRADICTION_NOT_IN_CITATIONS", question_id)
        if not set(negative).issubset(set(used)):
            add("NEGATIVE_MEMORY_NOT_IN_CITATIONS", question_id)
        semantics = question.get("required_semantics")
        if not isinstance(semantics, list) or not semantics:
            add("REQUIRED_SEMANTICS_MISSING", question_id)
            semantics = []
        for semantic in semantics:
            if not isinstance(semantic, dict):
                add("REQUIRED_SEMANTIC_INVALID", f"{question_id}:{type(semantic).__name__}")
                continue
            name = semantic.get("name")
            status = semantic.get("status")
            reason = semantic.get("reason")
            if not isinstance(name, str) or not name or status not in SEMANTIC_STATES or not isinstance(reason, str) or not reason:
                add("REQUIRED_SEMANTIC_INVALID", f"{question_id}:{name}")
                continue
            if status in UNRESOLVED:
                unresolved.append({"question_id": question_id, "name": name, "status": status})
        next_action = question.get("legal_next_action")
        if not isinstance(next_action, dict) or next_action.get("code") not in ALLOWED_NEXT_ACTIONS:
            add("LEGAL_NEXT_ACTION_INVALID", question_id)
        elif next_action.get("execution") is not False or next_action.get("authority") != "RESEARCH_ONLY":
            add("LEGAL_NEXT_ACTION_AUTHORITY_INVALID", question_id)

    claimed = handoff.get("execution_readiness_claim")
    if unresolved and claimed == "READY":
        add("UNRESOLVED_SEMANTICS_EXECUTION_READY_CONFLICT", f"unresolved={len(unresolved)}")
    if claimed not in {"BLOCKED", "SEPARATE_CONTRACT_REQUIRED"}:
        add("EXECUTION_READINESS_CLAIM_INVALID", str(claimed))

    if errors:
        return {
            "schema_version": "ea_lab_research_handoff_validation/1",
            "validation_status": "REFUSED",
            "handoff_readiness": "REFUSED",
            "execution_readiness": "BLOCKED_VALIDATION_ERRORS",
            "errors": errors,
            "unresolved_semantics": unresolved,
            "automatic_store_write": False,
            "semantic_correctness_proven": False,
        }
    return {
        "schema_version": "ea_lab_research_handoff_validation/1",
        "validation_status": "PASS",
        "handoff_readiness": "VALIDATED_RESEARCH_ONLY",
        "execution_readiness": "BLOCKED_UNRESOLVED_SEMANTICS" if unresolved else "SEPARATE_CONTRACT_REQUIRED",
        "errors": [],
        "source_commit": base,
        "citation_count": len(citations),
        "question_count": len(questions),
        "unresolved_semantics": unresolved,
        "automatic_store_write": False,
        "semantic_correctness_proven": False,
        "note": "Source binding and required fields passed. A model/human review remains responsible for semantic correctness.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a source-bound RESEARCH_ONLY Second Brain handoff")
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        handoff = json.loads(args.input.read_text(encoding="utf-8"))
        result = validate_handoff(handoff, args.repo.resolve())
    except (OSError, json.JSONDecodeError) as exc:
        result = {"validation_status": "ERROR_INVALID_INPUT", "error": str(exc)}
        code = 2
    else:
        code = 0 if result["validation_status"] == "PASS" else 1
    rendered = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
