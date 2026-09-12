#!/usr/bin/env python3
"""Validate local image dependencies referenced by an MT5 HTML report.

This is an evidence-shape helper only. It does not interpret strategy quality,
change research verdicts, or grant runtime/risk/deployment authority.
PASS proves local img-src closure and signatures only, not graph contents or
Balance/Equity semantics. Consumers must bind graph roles to source evidence.
Package manifests remain owned by report_package_integrity.py.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path, PurePosixPath
from typing import Any

SCHEMA_VERSION = "EA_LAB_MT5_NATIVE_ASSET_CLOSURE_V1"
ALLOWED_IMAGE_EXTENSIONS = {".png", ".gif", ".jpg", ".jpeg"}


class AssetRefusal(ValueError):
    """Fail-closed unsafe or malformed asset reference."""


class _ImageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.sources: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.casefold() == "base" or (tag.casefold() in {"img", "source"} and
                                       any(key == "srcset" for key, _ in attrs)):
            raise AssetRefusal("base/srcset changes image resolution; unsupported")
        if tag.casefold() != "img":
            return
        sources = [value for key, value in attrs if key.casefold() == "src"]
        if len(sources) != 1 or sources[0] is None:
            raise AssetRefusal("img must have exactly one non-empty src")
        self.sources.append(sources[0])


def _decode_html(raw: bytes) -> str:
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        return raw.decode("utf-16")
    # MT5 normally emits a UTF-16 BOM. Also support BOM-less LE/BE HTML.
    if re.match(rb"^(?:[\t\r\n ]\x00)*<\x00", raw):
        return raw.decode("utf-16-le")
    if re.match(rb"^(?:\x00[\t\r\n ])*\x00<", raw):
        return raw.decode("utf-16-be")
    return raw.decode("utf-8-sig")


def _image_record(path: Path, rel: str) -> dict[str, Any]:
    # Signature, size and hash describe the same opened byte stream.
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as handle:
        head = handle.read(12)
        handle.seek(0)
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
            size += len(chunk)
    return {"path": rel, "media_type": _media_type(path, head),
            "sha256": digest.hexdigest(), "size_bytes": size}


def _normalize_ref(value: str) -> str:
    if any(ord(c) < 32 or ord(c) == 127 for c in value) or "%" in value:
        raise AssetRefusal(f"control/percent-encoded image reference is unsupported: {value}")
    if value != value.strip():
        raise AssetRefusal(f"leading/trailing whitespace in image reference: {value}")
    text = value.replace("\\", "/")
    if not text:
        raise AssetRefusal("empty image reference")
    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", text) or text.startswith("//"):
        raise AssetRefusal(f"non-local image reference: {value}")
    if "?" in text or "#" in text:
        raise AssetRefusal(f"query/fragment image reference is unsupported: {value}")
    if re.match(r"^[A-Za-z]:", text) or text.startswith("/"):
        raise AssetRefusal(f"absolute image reference is not allowed: {value}")
    parts = text.split("/")
    if any(part in ("", ".", "..") or part.endswith((" ", ".")) for part in parts):
        raise AssetRefusal(f"unsafe image reference: {value}")
    if any(re.search(r'[<>"|*]', part) or
           re.match(r"^(CON|PRN|AUX|NUL|COM[0-9¹²³]|LPT[0-9¹²³])(?:\.|$)", part, re.I)
           for part in parts):
        raise AssetRefusal(f"unsupported Windows filename: {value}")
    pure = PurePosixPath(text)
    if any(":" in part for part in pure.parts):
        raise AssetRefusal(f"unsupported colon in image reference: {value}")
    normalized = pure.as_posix()
    if Path(normalized).suffix.casefold() not in ALLOWED_IMAGE_EXTENSIONS:
        raise AssetRefusal(f"unsupported image extension: {value}")
    return normalized


def _is_reparse_component(path: Path) -> bool:
    if path.is_symlink():
        return True
    is_junction = getattr(path, "is_junction", None)
    if callable(is_junction) and is_junction():
        return True
    try:
        attrs = getattr(path.lstat(), "st_file_attributes", 0)
    except FileNotFoundError:
        return False
    return bool(attrs & 0x400)


def _resolve_local_asset(base_dir: Path, rel_path: str) -> Path:
    current = base_dir
    for part in PurePosixPath(rel_path).parts:
        current = current / part
        if _is_reparse_component(current):
            raise AssetRefusal(f"reparse/symlink image dependency is not allowed: {rel_path}")
    candidate = base_dir.joinpath(*PurePosixPath(rel_path).parts)
    try:
        resolved_base = base_dir.resolve(strict=True)
    except FileNotFoundError as exc:
        raise AssetRefusal(f"report directory missing: {base_dir}") from exc
    try:
        resolved = candidate.resolve(strict=True)
    except FileNotFoundError:
        return candidate
    try:
        resolved.relative_to(resolved_base)
    except ValueError as exc:
        raise AssetRefusal(f"image dependency escapes report directory: {rel_path}") from exc
    return resolved


def _media_type(path: Path, head: bytes) -> str:
    suffix = path.suffix.casefold()
    if suffix == ".png" and head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if suffix == ".gif" and head.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif"
    if suffix in {".jpg", ".jpeg"} and head.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    raise AssetRefusal(f"image signature does not match extension: {path.name}")


def _extract_refs(text: str) -> list[str]:
    parser = _ImageParser()
    parser.feed(text)
    parser.close()
    return parser.sources


def inspect_report(report: Path, require_images: bool = True) -> dict[str, Any]:
    report = report.resolve(strict=True)
    raw = report.read_bytes()
    refs = _extract_refs(_decode_html(raw))
    seen: dict[str, str] = {}
    assets: list[dict[str, Any]] = []
    missing: list[str] = []
    refused: list[dict[str, str]] = []

    for original in refs:
        try:
            rel = _normalize_ref(original)
            key = rel.casefold()
            if key in seen:
                if seen[key] != rel:
                    raise AssetRefusal(f"ambiguous case-alias image reference: {original}")
                continue
            seen[key] = rel
            resolved = _resolve_local_asset(report.parent, rel)
            if not resolved.exists():
                missing.append(rel)
                continue
            if not resolved.is_file():
                raise AssetRefusal(f"image dependency is not a regular file: {rel}")
            assets.append(_image_record(resolved, rel))
        except (AssetRefusal, OSError, ValueError) as exc:
            refused.append({"reference": original, "reason": str(exc)})
    assets.sort(key=lambda item: item["path"].casefold())
    missing = sorted(set(missing), key=str.casefold)
    refused.sort(key=lambda item: (item["reference"].casefold(), item["reason"]))

    if refused:
        status = "REFUSED"
    elif missing:
        status = "INCOMPLETE"
    elif not assets:
        status = "NO_IMAGE_REFERENCES"
    else:
        status = "PASS"

    return {
        "schema_version": SCHEMA_VERSION,
        "status": status,
        "graph_asset_state": "AVAILABLE" if status == "PASS" else
                             "GRAPH ASSET MISSING" if status in {"INCOMPLETE", "NO_IMAGE_REFERENCES"}
                             else "GRAPH ASSET REFUSED",
        "report": report.name,
        "report_sha256": hashlib.sha256(raw).hexdigest(),
        "image_references_found": len(refs),
        "unique_local_images": len(assets),
        "require_images": True,
        "assets": assets,
        "missing": missing,
        "refused": refused,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--require-images", action="store_true", default=True,
                        help="compatibility flag; images are always required")
    parser.add_argument("--out", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        result = inspect_report(args.report, require_images=args.require_images)
    except (ValueError, OSError) as exc:
        result = {
            "schema_version": SCHEMA_VERSION,
            "status": "REFUSED",
            "error": str(exc),
        }
    # ASCII escapes keep machine JSON valid even through legacy Windows pipes.
    rendered = json.dumps(result, ensure_ascii=True, sort_keys=True, indent=2) + "\n"
    if args.out:
        # Never overwrite evidence (including aliases/hardlinks). New JSON only.
        try:
            if args.out.suffix.casefold() != ".json":
                raise AssetRefusal("output must be a new .json file")
            args.out.parent.mkdir(parents=True, exist_ok=True)
            with args.out.open("x", encoding="utf-8", newline="\n") as handle:
                handle.write(rendered)
        except (ValueError, OSError) as exc:
            sys.stdout.write(json.dumps({"schema_version": SCHEMA_VERSION,
                                         "status": "REFUSED", "error": str(exc)},
                                        ensure_ascii=True, sort_keys=True) + "\n")
            return 2
    else:
        sys.stdout.write(rendered)
    return 0 if result.get("status") == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
