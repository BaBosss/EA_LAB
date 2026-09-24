from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

PACKAGE_ROOT = Path(__file__).resolve().parent
if str(PACKAGE_ROOT) not in sys.path:
    sys.path.insert(0, str(PACKAGE_ROOT))

from decision import decide
from integrity import IntegrityError, verify_manifest
from jev_shadow import build_shadow_envelope
from routing import route_task


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("duplicate JSON key")
        value[key] = item
    return value


def _load_object(path: str) -> dict[str, Any]:
    try:
        value = json.loads(
            Path(path).read_text(encoding="utf-8-sig"),
            object_pairs_hook=_unique_object,
        )
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot load input JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError("input JSON must be an object")
    return value


def _emit(value: dict[str, Any]) -> None:
    print(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="EA_LAB passive Control Routing V1")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("route", "decide", "jev-shadow"):
        child = sub.add_parser(name)
        child.add_argument("--input", required=True)
    sub.add_parser("verify-integrity")
    args = parser.parse_args(argv)

    repo_root = Path(__file__).resolve().parents[2]
    try:
        integrity = verify_manifest(repo_root)
        if args.command == "verify-integrity":
            _emit(integrity)
            return 0
        value = _load_object(args.input)
        if args.command == "route":
            result = route_task(value)
        elif args.command == "decide":
            result = decide(value)
        else:
            result = build_shadow_envelope(value)
        result["implementation_manifest_sha256"] = integrity["manifest_sha256"]
        _emit(result)
        return 0
    except (ValueError, IntegrityError) as exc:
        print(f"REFUSED: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
