#!/usr/bin/env python3
"""Deterministic integrity manifest for EA_LAB report packages.

This tool only binds declared package artifacts to relative paths, byte sizes, and
SHA-256 hashes. It does not interpret research results, validate Report Ladder
completeness, decide verdicts, or grant runtime/risk/deployment authority.

Usage:
  python report_package_integrity.py build --spec package_spec.json --out report_package_manifest.json
  python report_package_integrity.py validate --manifest report_package_manifest.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any

MANIFEST_VERSION = "EA_LAB_REPORT_PACKAGE_INTEGRITY_V1"
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class Refusal(ValueError):
    """Fail-closed input or integrity refusal."""

def _read_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError as exc:
        raise Refusal(f"file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise Refusal(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise Refusal(f"top-level JSON must be an object: {path}")
    return data


def _nonempty_text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise Refusal(f"{label} must be a non-empty string")
    return value.strip()


def _normalize_rel_path(value: Any) -> str:
    text = _nonempty_text(value, "artifact path").replace("\\", "/")
    if text.startswith("/") or re.match(r"^[A-Za-z]:", text):
        raise Refusal(f"artifact path must be relative: {value}")
    p = PurePosixPath(text)
    parts = p.parts
    if not parts or any(part in ("", ".", "..") for part in parts):
        raise Refusal(f"artifact path contains unsafe segment: {value}")
    if any(":" in part for part in parts):
        raise Refusal(f"artifact path contains unsupported colon segment: {value}")
    normalized = p.as_posix()
    if normalized in ("", "."):
        raise Refusal(f"artifact path is empty after normalization: {value}")
    return normalized


def _resolve_artifact(base_dir: Path, rel_path: str) -> Path:
    candidate = base_dir.joinpath(*PurePosixPath(rel_path).parts)
    try:
        resolved = candidate.resolve(strict=True)
    except FileNotFoundError as exc:
        raise Refusal(f"artifact missing: {rel_path}") from exc
    try:
        resolved.relative_to(base_dir.resolve(strict=True))
    except ValueError as exc:
        raise Refusal(f"artifact escapes package directory: {rel_path}") from exc
    if not resolved.is_file():
        raise Refusal(f"artifact is not a regular file: {rel_path}")
    if candidate.is_symlink():
        raise Refusal(f"artifact symlink is not allowed: {rel_path}")
    return resolved


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _artifact_record(base_dir: Path, item: Any, forbidden_path: Path | None = None) -> dict[str, Any]:
    if not isinstance(item, dict):
        raise Refusal("each artifacts entry must be an object")
    rel_path = _normalize_rel_path(item.get("path"))
    role = _nonempty_text(item.get("role"), f"role for {rel_path}")
    resolved = _resolve_artifact(base_dir, rel_path)
    if forbidden_path is not None and resolved == forbidden_path.resolve(strict=False):
        raise Refusal(f"manifest cannot hash itself as an artifact: {rel_path}")

    record: dict[str, Any] = {
        "path": rel_path,
        "role": role,
        "sha256": _sha256(resolved),
        "size_bytes": resolved.stat().st_size,
    }
    if "note" in item:
        record["note"] = _nonempty_text(item.get("note"), f"note for {rel_path}")
    return record


def build_manifest(spec_path: Path, out_path: Path) -> dict[str, Any]:
    spec_path = spec_path.resolve(strict=True)
    out_path = out_path.resolve(strict=False)
    base_dir = spec_path.parent
    if out_path.parent.resolve(strict=True) != base_dir:
        raise Refusal("manifest output must be in the same directory as the package spec")
    if out_path == spec_path:
        raise Refusal("manifest output cannot overwrite the package spec")

    spec = _read_json(spec_path)
    package_id = _nonempty_text(spec.get("package_id"), "package_id")
    direct_consumer = _nonempty_text(spec.get("direct_consumer"), "direct_consumer")
    authority = _nonempty_text(spec.get("authority"), "authority")
    artifacts = spec.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        raise Refusal("artifacts must be a non-empty list")
    metadata = spec.get("metadata", {})
    if not isinstance(metadata, dict):
        raise Refusal("metadata must be an object when present")

    records = [_artifact_record(base_dir, item, forbidden_path=out_path) for item in artifacts]
    seen: set[str] = set()
    for rec in records:
        key = rec["path"].casefold()
        if key in seen:
            raise Refusal(f"duplicate artifact path after normalization: {rec['path']}")
        seen.add(key)
    records.sort(key=lambda row: row["path"].casefold())

    return {
        "manifest_version": MANIFEST_VERSION,
        "package_id": package_id,
        "direct_consumer": direct_consumer,
        "authority": authority,
        "metadata": metadata,
        "artifacts": records,
    }


def write_manifest(manifest: dict[str, Any], out_path: Path) -> None:
    text = json.dumps(manifest, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    out_path.write_text(text, encoding="utf-8", newline="\n")


def validate_manifest(manifest_path: Path) -> dict[str, Any]:
    manifest_path = manifest_path.resolve(strict=True)
    base_dir = manifest_path.parent
    data = _read_json(manifest_path)
    if data.get("manifest_version") != MANIFEST_VERSION:
        raise Refusal(
            f"unsupported manifest_version: {data.get('manifest_version')!r}; expected {MANIFEST_VERSION}"
        )
    package_id = _nonempty_text(data.get("package_id"), "package_id")
    _nonempty_text(data.get("direct_consumer"), "direct_consumer")
    _nonempty_text(data.get("authority"), "authority")
    metadata = data.get("metadata", {})
    if not isinstance(metadata, dict):
        raise Refusal("metadata must be an object")
    artifacts = data.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        raise Refusal("artifacts must be a non-empty list")

    seen: set[str] = set()
    for item in artifacts:
        if not isinstance(item, dict):
            raise Refusal("each manifest artifact must be an object")
        rel_path = _normalize_rel_path(item.get("path"))
        key = rel_path.casefold()
        if key in seen:
            raise Refusal(f"duplicate artifact path after normalization: {rel_path}")
        seen.add(key)
        _nonempty_text(item.get("role"), f"role for {rel_path}")
        expected_hash = _nonempty_text(item.get("sha256"), f"sha256 for {rel_path}").lower()
        if not _SHA256_RE.fullmatch(expected_hash):
            raise Refusal(f"invalid sha256 for {rel_path}")
        expected_size = item.get("size_bytes")
        if not isinstance(expected_size, int) or isinstance(expected_size, bool) or expected_size < 0:
            raise Refusal(f"invalid size_bytes for {rel_path}")
        if "note" in item:
            _nonempty_text(item.get("note"), f"note for {rel_path}")

        resolved = _resolve_artifact(base_dir, rel_path)
        if resolved == manifest_path:
            raise Refusal(f"manifest cannot hash itself as an artifact: {rel_path}")
        actual_size = resolved.stat().st_size
        if actual_size != expected_size:
            raise Refusal(
                f"size mismatch for {rel_path}: expected {expected_size}, actual {actual_size}"
            )
        actual_hash = _sha256(resolved)
        if actual_hash != expected_hash:
            raise Refusal(
                f"sha256 mismatch for {rel_path}: expected {expected_hash}, actual {actual_hash}"
            )

    return {
        "status": "PASS",
        "manifest_version": MANIFEST_VERSION,
        "package_id": package_id,
        "artifact_count": len(artifacts),
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build", help="build deterministic manifest from package spec")
    build.add_argument("--spec", required=True, type=Path)
    build.add_argument("--out", required=True, type=Path)
    validate = sub.add_parser("validate", help="recompute and verify a package manifest")
    validate.add_argument("--manifest", required=True, type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "build":
            manifest = build_manifest(args.spec, args.out)
            write_manifest(manifest, args.out)
            result = {
                "status": "PASS",
                "operation": "build",
                "package_id": manifest["package_id"],
                "artifact_count": len(manifest["artifacts"]),
                "manifest": str(args.out),
            }
        else:
            result = validate_manifest(args.manifest)
            result["operation"] = "validate"
            result["manifest"] = str(args.manifest)
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        return 0
    except (Refusal, OSError) as exc:
        print(
            json.dumps(
                {"status": "BLOCKED", "operation": args.command, "error": str(exc)},
                ensure_ascii=False,
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2

if __name__ == "__main__":
    raise SystemExit(main())