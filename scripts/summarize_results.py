#!/usr/bin/env python3
"""Summarize MT5 result artifacts without inventing missing metrics."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def parse_mt5_html_report(path: Path) -> dict[str, Any]:
    """Placeholder parser for MT5 HTML reports."""
    return {
        "path": str(path),
        "status": "found",
        "metrics": {},
        "note": "Parser placeholder. Metrics are not extracted yet.",
    }


def parse_optimization_csv(path: Path) -> dict[str, Any]:
    """Placeholder parser for MT5 optimization CSV exports."""
    return {
        "path": str(path),
        "status": "found",
        "metrics": {},
        "note": "Parser placeholder. Metrics are not extracted yet.",
    }


def parse_equity_curve_csv(path: Path) -> dict[str, Any]:
    """Placeholder parser for equity curve CSV files."""
    return {
        "path": str(path),
        "status": "found",
        "metrics": {},
        "note": "Parser placeholder. Metrics are not extracted yet.",
    }


def first_match(folder: Path, patterns: list[str]) -> Path | None:
    matches: list[Path] = []
    for pattern in patterns:
        matches.extend(folder.rglob(pattern))
    files = [path for path in matches if path.is_file()]
    return max(files, key=lambda path: path.stat().st_mtime) if files else None


def summarize(folder: Path) -> dict[str, Any]:
    html_report = first_match(folder, ["*.html", "*.htm"])
    optimization_csv = first_match(folder, ["*optimization*.csv", "*opt*.csv"])
    equity_curve_csv = first_match(folder, ["*equity*.csv", "*balance*.csv"])
    set_file = first_match(folder, ["*.set"])

    summary: dict[str, Any] = {
        "folder": str(folder),
        "generated_at_source": "local system time",
        "safety": "summary only; no live trading, deployment, or account changes",
        "files": {
            "mt5_html_report": str(html_report) if html_report else None,
            "optimization_csv": str(optimization_csv) if optimization_csv else None,
            "equity_curve_csv": str(equity_curve_csv) if equity_curve_csv else None,
            "set_file": str(set_file) if set_file else None,
        },
        "missing": [],
        "parsed": {},
    }

    if html_report:
        summary["parsed"]["mt5_html_report"] = parse_mt5_html_report(html_report)
    else:
        summary["missing"].append("MT5 HTML report")

    if optimization_csv:
        summary["parsed"]["optimization_csv"] = parse_optimization_csv(optimization_csv)
    else:
        summary["missing"].append("optimization CSV")

    if equity_curve_csv:
        summary["parsed"]["equity_curve_csv"] = parse_equity_curve_csv(equity_curve_csv)
    else:
        summary["missing"].append("equity curve CSV")

    if set_file:
        summary["parsed"]["set_file"] = {
            "path": str(set_file),
            "status": "found",
            "note": "Set file found; content not interpreted.",
        }
    else:
        summary["missing"].append("final .set file")

    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Create summary.json for MT5 result artifacts.")
    parser.add_argument("folder", help="Folder containing MT5 report artifacts.")
    args = parser.parse_args()

    folder = Path(args.folder).expanduser().resolve()
    if not folder.exists() or not folder.is_dir():
        raise SystemExit(f"Folder not found: {folder}")

    summary = summarize(folder)
    output_path = folder / "summary.json"
    output_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
