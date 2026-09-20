"""CLI for the source-bound OFP preparation report."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from tools.orderflow_proxy.research_presentation.projection import (
        ProjectionError,
        build_bound_projection,
        load_observation_file,
        render_html,
        safe_output_name,
        serialize_projection,
    )
else:
    from .projection import (
        ProjectionError,
        build_bound_projection,
        load_observation_file,
        render_html,
        safe_output_name,
        serialize_projection,
    )


def _write_same_or_new(path: Path, data: bytes) -> None:
    if path.exists():
        if not path.is_file() or path.read_bytes() != data:
            raise ProjectionError(f"OUTPUT_EXISTS_WITH_DIFFERENT_BYTES:{path.name}")
        return
    path.write_bytes(data)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build a deterministic OFP R0 preparation projection; no backtest or Monitor hookup.")
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--repo-ref", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--json-name", default="orderflow_preparation_projection.json")
    parser.add_argument("--html-name", default="orderflow_preparation_report.html")
    parser.add_argument("--observation-root")
    parser.add_argument("--observation-file", help="Repository-style relative path under --observation-root")
    parser.add_argument("--observation-as-of-utc", help="Explicit validation clock for a supplied observation; never a freshness claim")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        json_name = safe_output_name(args.json_name, ".json")
        html_name = safe_output_name(args.html_name, ".html")
        observation = None
        if any((args.observation_root, args.observation_file, args.observation_as_of_utc)):
            if not all((args.observation_root, args.observation_file, args.observation_as_of_utc)):
                raise ProjectionError("OBSERVATION_ARGUMENTS_MUST_BE_COMPLETE")
            observation = load_observation_file(Path(args.observation_root), args.observation_file)
        projection = build_bound_projection(Path(args.repo_root), args.repo_ref, observation, args.observation_as_of_utc)
        json_bytes = serialize_projection(projection)
        html_bytes = render_html(projection)
        output_dir = Path(args.output_dir).resolve(strict=True)
        if not output_dir.is_dir():
            raise ProjectionError("OUTPUT_DIR_NOT_DIRECTORY")
        json_path = output_dir / json_name
        html_path = output_dir / html_name
        _write_same_or_new(json_path, json_bytes)
        _write_same_or_new(html_path, html_bytes)
        result = {
            "result": "PREPARATION_REPORT_GENERATED",
            "json": {"path": str(json_path), "sha256": hashlib.sha256(json_bytes).hexdigest()},
            "html": {"path": str(html_path), "sha256": hashlib.sha256(html_bytes).hexdigest()},
            "source_ref": args.repo_ref,
            "execution_status": "NOT_RUN",
            "monitor_wired": False,
        }
        print(json.dumps(result, sort_keys=True))
        return 0
    except ProjectionError as exc:
        print(json.dumps({"result": "REFUSED", "reason": str(exc)}, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
