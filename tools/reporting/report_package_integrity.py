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
_REDACTED_PATH_RE = re.compile(
    r"^(<(?:REPO_ROOT|EVIDENCE_ROOT|ABSOLUTE_ROOT|"
    r"(?:EVIDENCE_ROOT|WORKTREE|USER_HOME|UNC_ROOT|ABSOLUTE_ROOT|DEVICE_PATH|UNSAFE_TAIL)_[0-9A-F]{10}|"
    r"UNSAFE_PATH_[0-9A-F]{64})>)$"
)
_EMBEDDED_ABSOLUTE_PATH_START_RE = re.compile(
    r"(?i)(?:\\\\|//|[A-Z]:[\\/]|(?<![\w>?.])[\\/]|(?<!\w)~[^\s/\\]*[\\/])"
)
_PLACEHOLDER_START_RE = re.compile(
    r"(?<!\w)<(?=[A-Za-z_<\\/])|"
    r"[<>](?=\s*[A-Za-z_][A-Za-z0-9_-]*\s+(?:[<>]|\S*[\\/]))|"
    r"<(?=\s*[A-Za-z_][A-Za-z0-9_-]*\s*(?:>|[\\/]))|"
    r"[<>](?=\s*[^\s<>\"'\\/]*[\\/])"
)
REPO_ROOT = Path(__file__).resolve().parents[2]


class Refusal(ValueError):
    """Fail-closed input or integrity refusal."""


def _canonicalize_windows_namespace(text: str) -> str:
    """Collapse Windows namespace aliases and lexical path segments before classification."""
    original = text
    if text.casefold().startswith("//?/unc/"):
        text = "//" + text[8:]
    elif text.startswith("//?/"):
        remainder = text[4:]
        if re.match(r"^[A-Za-z]:/", remainder):
            text = remainder
    for prefix in ("/??/", "//??/"):
        if text.casefold().startswith(prefix + "unc/"):
            text = "//" + text[len(prefix) + 4:]
            break
        if text.startswith(prefix):
            remainder = text[len(prefix):]
            if re.match(r"^[A-Za-z]:/", remainder):
                text = remainder
                break

    def unsafe() -> str:
        digest = hashlib.sha256(original.casefold().encode("utf-8")).hexdigest()
        return f"//?/UNSAFE/{digest}"

    def normalized_parts(values: list[str]) -> list[str] | None:
        result: list[str] = []
        for part in values:
            if part in ("", "."):
                continue
            if part == "..":
                if not result:
                    return None
                result.pop()
                continue
            result.append(part)
        return result

    if text.casefold().startswith(("//./", "//?/", "/??/", "//??/")):
        return text

    drive = re.match(r"^(?P<root>[A-Za-z]:)/+(?P<tail>.*)$", text)
    if drive:
        parts = normalized_parts(drive.group("tail").split("/"))
        if parts is None:
            return unsafe()
        suffix = "/".join(parts)
        return drive.group("root") + "/" + suffix

    if text.startswith("//"):
        unc_parts = [part for part in text.lstrip("/").split("/") if part]
        if len(unc_parts) < 2 or any(part in (".", "..") for part in unc_parts[:2]):
            return unsafe()
        tail = normalized_parts(unc_parts[2:])
        if tail is None:
            return unsafe()
        return "//" + "/".join(unc_parts[:2] + tail)

    if text.startswith("/"):
        parts = normalized_parts(text.split("/"))
        if parts is None:
            return unsafe()
        return "/" + "/".join(parts)
    return text


def _is_windows_device_absolute(text: str) -> bool:
    folded = text.casefold()
    return folded.startswith(("//./", "//?/", "/??/", "//??/"))


def _absolute_path_kind(text: str) -> str | None:
    if _is_windows_device_absolute(text):
        return "device"
    if text.startswith("//"):
        return "unc"
    if re.match(r"^[A-Za-z]:/", text):
        return "drive"
    if text.startswith("/"):
        return "posix"
    return None


def _opaque_path_label(kind: str, value: str) -> str:
    digest = hashlib.sha256(value.casefold().encode("utf-8")).hexdigest()[:10].upper()
    return f"<{kind}_{digest}>"


def portable_path(value: str | Path, *, repo_root: str | Path | None = None) -> str:
    """Return a deterministic display path without exposing machine/user roots.

    This is presentation-only. Artifact hashes and the paths used for filesystem access are
    untouched. Absolute paths yield readable tails only under a qualified repository root.
    Labels do not attest to tail provenance; opaque identities bind the whole path.
    """
    raw = str(value)

    def closed_placeholder(text: str) -> str:
        match = _REDACTED_PATH_RE.fullmatch(text)
        if match:
            return text
        # No string-only provenance check can distinguish a generated readable tail
        # from a forged one. Accept bare labels only, even for known-root labels.
        # Bind the entire original spelling, before separator/namespace collapse.
        # Never retain any tail from malformed, unknown, repeated or nested labels.
        digest = hashlib.sha256(raw.encode("utf-8")).hexdigest().upper()
        return f"<UNSAFE_PATH_{digest}>"

    text = raw.strip().replace("\\", "/")
    if "<" in text or ">" in text:
        return closed_placeholder(text)
    result = _portable_unlabelled_path(text, repo_root=repo_root)
    # Generated labels obey the same grammar, making presentation idempotent.
    return closed_placeholder(result) if "<" in result or ">" in result else result


def _portable_unlabelled_path(text: str, *, repo_root: str | Path | None) -> str:
    while text.startswith("./"):
        text = text[2:]
    text = _canonicalize_windows_namespace(text)

    path_kind = _absolute_path_kind(text)
    if path_kind is None:
        if re.match(r"^~[^/]*/", text):
            return _opaque_path_label("USER_HOME", text)
        return text

    if path_kind == "device":
        return _opaque_path_label("DEVICE_PATH", text)

    def below(root_value: str | Path | None) -> str | None:
        if root_value is None:
            return None
        root = _canonicalize_windows_namespace(
            str(root_value).strip().replace("\\", "/")
        ).rstrip("/")
        if not root or _absolute_path_kind(root) is None:
            return None
        if text.casefold() == root.casefold():
            return ""
        prefix = root + "/"
        if text.casefold().startswith(prefix.casefold()):
            return text[len(prefix):]
        return None

    repo_relative = below(repo_root)
    if repo_relative is not None:
        return repo_relative or "<REPO_ROOT>"

    evidence = re.match(r"(?i)^[A-Z]:/EA_LAB_CONTROL/evidence(?:/(.*))?$", text)
    if evidence:
        return "<EVIDENCE_ROOT>" if not evidence.group(1) else _opaque_path_label("EVIDENCE_ROOT", text)

    worktree = re.match(
        r"(?i)^(?P<root>[A-Z]:/EA_LAB_CONTROL/(?:worktrees|w)/[^/]+)(?:/(?P<tail>.*))?$",
        text,
    )
    if worktree:
        return _opaque_path_label("WORKTREE", text)

    user_worktree = re.match(
        r"(?i)^(?P<root>[A-Z]:/Users/[^/]+/\.codex/worktrees/[^/]+(?:/EA_LAB)?)(?:/(?P<tail>.*))?$",
        text,
    )
    if user_worktree:
        return _opaque_path_label("WORKTREE", text)

    user_home = re.match(r"(?i)^(?P<root>[A-Z]:/Users/[^/]+)(?:/(?P<tail>.*))?$", text)
    if user_home:
        return _opaque_path_label("USER_HOME", text)

    if path_kind == "unc":
        return _opaque_path_label("UNC_ROOT", text)

    return _opaque_path_label("ABSOLUTE_ROOT", text)


def _sanitize_error_text(
    message: str, *, repo_root: str | Path | None = None
) -> str:
    """Keep diagnostic prefixes; never trust delimiters to end a private reference.

    Free text has no filename boundary: quotes, line breaks and arrows can all
    belong to a malformed path. Once a reference begins, its entire remaining
    span is untrusted. Only outer terminal quoting/whitespace and an exact chain
    of bare opaque labels can be retained without releasing a readable tail.
    Structured OSError filenames are handled separately by portable_error.
    """
    starts = [match for pattern in (_EMBEDDED_ABSOLUTE_PATH_START_RE, _PLACEHOLDER_START_RE)
              if (match := pattern.search(message)) is not None]
    if not starts:
        return message
    match = min(starts, key=lambda item: item.start())
    start = match.start()
    candidate = message[start:].rstrip()
    suffix = message[start + len(candidate):]
    if start and message[start - 1] in ("'", '"') and candidate.endswith(message[start - 1]):
        suffix = candidate[-1] + suffix
        candidate = candidate[:-1]

    # This is the complete output grammar of structured two-filename errors,
    # not permission to retain arbitrary text following a recognizable label.
    if all(_REDACTED_PATH_RE.fullmatch(part) for part in candidate.split(" -> ")):
        return message

    # A qualified root permits relative output only for one unambiguous path.
    # Do not let a second reference or delimiter-bearing tail inherit that trust.
    ambiguous = any(char in candidate for char in ("'", '"', "\r", "\n", " -> "))
    ambiguous = ambiguous or _EMBEDDED_ABSOLUTE_PATH_START_RE.search(
        candidate, match.end() - start
    ) is not None
    shown = portable_path(candidate, repo_root=None if ambiguous else repo_root)
    return message[:start] + shown + suffix


def portable_error(exc: Exception, *, repo_root: str | Path | None = None) -> str:
    """Render OS errors without copying their machine-local filename into an export."""
    if isinstance(exc, OSError):
        detail = _sanitize_error_text(
            exc.strerror or exc.__class__.__name__, repo_root=repo_root
        )
        names = [name for name in (exc.filename, exc.filename2) if name]
        if names:
            refs = " -> ".join(portable_path(name, repo_root=repo_root) for name in names)
            return f"{detail}: {refs}"
        return detail
    return _sanitize_error_text(str(exc), repo_root=repo_root)


def _read_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError as exc:
        raise Refusal(f"file not found: {portable_path(path, repo_root=REPO_ROOT)}") from exc
    except json.JSONDecodeError as exc:
        raise Refusal(f"invalid JSON in {portable_path(path, repo_root=REPO_ROOT)}: {exc}") from exc
    if not isinstance(data, dict):
        raise Refusal(f"top-level JSON must be an object: {portable_path(path, repo_root=REPO_ROOT)}")
    return data


def _nonempty_text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise Refusal(f"{label} must be a non-empty string")
    return value.strip()


def _normalize_rel_path(value: Any) -> str:
    text = _nonempty_text(value, "artifact path").replace("\\", "/")
    display = portable_path(text, repo_root=REPO_ROOT)
    if text.startswith("/") or re.match(r"^[A-Za-z]:", text):
        raise Refusal(f"artifact path must be relative: {display}")
    p = PurePosixPath(text)
    parts = p.parts
    if not parts or any(part in ("", ".", "..") for part in parts):
        raise Refusal(f"artifact path contains unsafe segment: {display}")
    if any(":" in part for part in parts):
        raise Refusal(f"artifact path contains unsupported colon segment: {display}")
    normalized = p.as_posix()
    if normalized in ("", "."):
        raise Refusal(f"artifact path is empty after normalization: {display}")
    return normalized


def _is_reparse_component(path: Path) -> bool:
    if path.is_symlink():
        return True
    is_junction = getattr(path, "is_junction", None)
    if is_junction is not None and is_junction():
        return True
    try:
        attrs = getattr(path.lstat(), "st_file_attributes", 0)
    except FileNotFoundError:
        return False
    return bool(attrs & 0x400)  # Windows FILE_ATTRIBUTE_REPARSE_POINT


def _resolve_artifact(base_dir: Path, rel_path: str) -> Path:
    candidate = base_dir.joinpath(*PurePosixPath(rel_path).parts)
    current = base_dir
    for part in PurePosixPath(rel_path).parts:
        current = current / part
        if _is_reparse_component(current):
            raise Refusal(f"artifact reparse component is not allowed: {rel_path}")
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
                "manifest": portable_path(args.out, repo_root=REPO_ROOT),
            }
        else:
            result = validate_manifest(args.manifest)
            result["operation"] = "validate"
            result["manifest"] = portable_path(args.manifest, repo_root=REPO_ROOT)
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        return 0
    except (Refusal, OSError) as exc:
        print(
            json.dumps(
                {
                    "status": "BLOCKED",
                    "operation": args.command,
                    "error": portable_error(exc, repo_root=REPO_ROOT),
                },
                ensure_ascii=False,
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2

if __name__ == "__main__":
    raise SystemExit(main())
