from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "ea_lab_control_routing_manifest/1"
RUNTIME_FILES = (
    "tools/control_routing_v1/__init__.py",
    "tools/control_routing_v1/policy.json",
    "tools/control_routing_v1/integrity.py",
    "tools/control_routing_v1/routing.py",
    "tools/control_routing_v1/decision.py",
    "tools/control_routing_v1/jev_shadow.py",
    "tools/control_routing_v1/cli.py",
    "tools/control_routing_v1/build_manifest.py",
)
MANIFEST_PATH = "tools/control_routing_v1/implementation_manifest.json"


class IntegrityError(ValueError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")


def build_manifest(repo_root: Path) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    files: dict[str, str] = {}
    for rel in RUNTIME_FILES:
        path = repo_root / rel
        if not path.is_file():
            raise IntegrityError(f"missing runtime file: {rel}")
        files[rel] = sha256_file(path)
    return {"schema_version": SCHEMA_VERSION, "runtime_files": files}


def verify_manifest(repo_root: Path) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    path = repo_root / MANIFEST_PATH
    if not path.is_file():
        raise IntegrityError(f"missing implementation manifest: {MANIFEST_PATH}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise IntegrityError(f"invalid implementation manifest: {exc}") from exc

    if not isinstance(data, dict) or set(data) != {"schema_version", "runtime_files"}:
        raise IntegrityError("manifest must contain exactly schema_version/runtime_files")
    if data["schema_version"] != SCHEMA_VERSION:
        raise IntegrityError("unsupported implementation manifest schema")
    files = data["runtime_files"]
    if not isinstance(files, dict):
        raise IntegrityError("runtime_files must be an object")
    if set(files) != set(RUNTIME_FILES):
        missing = sorted(set(RUNTIME_FILES) - set(files))
        extra = sorted(set(files) - set(RUNTIME_FILES))
        raise IntegrityError(f"manifest path-set mismatch missing={missing} extra={extra}")

    for rel in RUNTIME_FILES:
        declared = files[rel]
        if (
            not isinstance(declared, str)
            or len(declared) != 64
            or any(ch not in "0123456789abcdef" for ch in declared)
        ):
            raise IntegrityError(f"invalid sha256 for {rel}")
        actual = sha256_file(repo_root / rel)
        if actual != declared:
            raise IntegrityError(f"runtime hash mismatch: {rel}")

    return {
        "status": "PASS",
        "schema_version": SCHEMA_VERSION,
        "runtime_file_count": len(RUNTIME_FILES),
        "manifest_sha256": sha256_file(path),
    }
