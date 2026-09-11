"""Local-only, closed-vocabulary mechanical learning intake; never a memory writer.

The Control Tower supplies a separately trusted accepted-source index. Its entries
bind the *whole record*, not merely a document hash: a worker cannot attach an
invented lesson to accepted bytes. Hashes establish identity, not reviewer trust;
the index must be accepted outside this module. No text from source files is
interpreted, copied into the pack, or executed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path, PurePosixPath


class LearningError(ValueError):
    """Fail-visible intake refusal."""


LESSONS = {
    "VERIFY_EXACT_ARTIFACT_HASHES": "EVIDENCE_PROVENANCE",
    "REUSE_ONLY_MATCHING_FROZEN_CHECKPOINT": "CHECKPOINT_RESUME",
    "STOP_ON_AMBIGUOUS_STARTED_CELL": "CHECKPOINT_RESUME",
    "PRESERVE_MECHANICAL_FAILURE_CLASS": "ENVIRONMENT_DIAGNOSTIC",
}
FIELDS = {
    "schema_version", "record_id", "source_ref", "source_sha256",
    "acceptance_status", "acceptance_class", "scope", "reusable_lesson",
}


def canonical_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True, allow_nan=False).encode("utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _digest(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def _shape(record: object) -> dict:
    if not isinstance(record, dict) or set(record) != FIELDS:
        raise LearningError("E_LEARNING_SCHEMA: missing or prohibited/free-form fields")
    if type(record["schema_version"]) is not int or record["schema_version"] != 1:
        raise LearningError("E_LEARNING_VERSION")
    if not isinstance(record["record_id"], str) or not re.fullmatch(
            r"[a-z0-9][a-z0-9_-]{0,63}", record["record_id"]):
        raise LearningError("E_LEARNING_ID")
    if not _digest(record["source_sha256"]):
        raise LearningError("E_LEARNING_SOURCE_SHA")
    if record["acceptance_status"] != "ACCEPTED":
        raise LearningError("E_LEARNING_UNACCEPTED")
    if record["acceptance_class"] not in ("MECHANICAL_PATTERN", "MECHANICAL_LESSON"):
        raise LearningError("E_LEARNING_ACCEPTANCE_CLASS")
    lesson = record["reusable_lesson"]
    if not isinstance(lesson, dict) or set(lesson) != {"code"}:
        raise LearningError("E_LEARNING_FREEFORM_LESSON")
    if not isinstance(lesson["code"], str) or lesson["code"] not in LESSONS:
        raise LearningError("E_LEARNING_UNAPPROVED_LESSON")
    if record["scope"] != LESSONS[lesson["code"]]:
        raise LearningError("E_LEARNING_SCOPE")
    ref = record["source_ref"]
    if not isinstance(ref, str) or not ref or "\\" in ref or ":" in ref:
        raise LearningError("E_LEARNING_SOURCE_PATH")
    parts = ref.split("/")
    if PurePosixPath(ref).is_absolute() or any(p in ("", ".", "..") for p in parts):
        raise LearningError("E_LEARNING_SOURCE_PATH")
    return record


def validate_record(record: object, source_root: Path, accepted_index: dict) -> dict:
    """Return a detached validated record. Index = {record_id: record SHA256}."""
    record = _shape(record)
    if not isinstance(accepted_index, dict) or any(
            not isinstance(k, str) or not _digest(v) for k, v in accepted_index.items()):
        raise LearningError("E_LEARNING_ACCEPTED_INDEX")
    if accepted_index.get(record["record_id"]) != sha256(canonical_bytes(record)):
        raise LearningError("E_LEARNING_NO_MATCHING_ACCEPTANCE")
    root = Path(source_root).resolve(strict=True)
    try:
        source = (root / record["source_ref"]).resolve(strict=True)
        source.relative_to(root)
        if not source.is_file():
            raise ValueError("not a file")
        content = source.read_bytes()
    except (OSError, ValueError) as exc:
        raise LearningError("E_LEARNING_SOURCE_UNAVAILABLE_OR_ESCAPE") from exc
    if sha256(content) != record["source_sha256"]:
        raise LearningError("E_LEARNING_SOURCE_TAMPERED")
    return json.loads(canonical_bytes(record))


def build_pack(records: list, source_root: Path, accepted_index: dict) -> dict:
    """Build an inert task-local pack in memory; no persistent-memory side effects."""
    if not isinstance(records, list) or not records:
        raise LearningError("E_LEARNING_RECORDS")
    validated = [validate_record(r, source_root, accepted_index) for r in records]
    ids = [r["record_id"] for r in validated]
    if len(ids) != len(set(ids)):
        raise LearningError("E_LEARNING_DUPLICATE_ID")
    validated.sort(key=lambda r: r["record_id"])
    return {
        "schema_version": 1,
        "kind": "VERIFIED_MECHANICAL_LEARNING_PACK",
        "usage": "TASK_LOCAL_SUPERVISORY_DATA_ONLY",
        "authority": "NONE",
        "accepted_index_sha256": sha256(canonical_bytes(accepted_index)),
        "records_sha256": sha256(canonical_bytes(validated)),
        "records": validated,
    }


def _unique_object(pairs: list) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise LearningError("E_LEARNING_DUPLICATE_JSON_KEY")
        result[key] = value
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--records", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--accepted-index", type=Path, required=True)
    parser.add_argument("--accepted-index-sha256", required=True,
                        help="External Control Tower pin of accepted index file bytes")
    args = parser.parse_args(argv)
    try:
        index_bytes = args.accepted_index.read_bytes()
        if not _digest(args.accepted_index_sha256) or sha256(index_bytes) != args.accepted_index_sha256:
            raise LearningError("E_LEARNING_ACCEPTED_INDEX_SHA")
        index = json.loads(index_bytes, object_pairs_hook=_unique_object)
        records = json.loads(args.records.read_bytes(), object_pairs_hook=_unique_object)
        print(json.dumps(build_pack(records, args.source_root, index), indent=2, sort_keys=True))
    except (LearningError, OSError, ValueError) as exc:
        parser.exit(2, f"verified-learning refused: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
