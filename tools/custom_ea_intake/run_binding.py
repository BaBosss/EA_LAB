#!/usr/bin/env python3
"""Verify immutable run/report file identity and emit research-only references.

Read-only evidence consumer. It never parses/declares PF, DD, trade results,
review outcome or authorizes Tester, Factory, optimizer, monitoring or LIVE.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

HASH_RE = re.compile(r"^[a-fA-F0-9]{64}$")
ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{2,127}$")
ARTIFACTS = ("source", "compiled_ea", "preset", "native_report", "native_graph")
OPTIONAL_ARTIFACTS = ("optimizer_xml", "report_markdown", "report_pdf", "deal_ledger")
REQUIRED_TEXT = ("strategy_id", "variant_id", "build_id", "run_id",
                 "symbol", "timeframe", "tester_model", "window_start", "window_end")


def check_artifact(kind: str, value: object) -> dict:
    if not isinstance(value, dict) or set(value) != {"path", "sha256"}:
        raise ValueError(f"{kind}: must provide exact path and sha256")
    rawpath, digest = value["path"], value["sha256"]
    if not isinstance(rawpath, str) or not rawpath:
        raise ValueError(f"{kind}: missing path")
    if not isinstance(digest, str) or not HASH_RE.fullmatch(digest):
        raise ValueError(f"{kind}: invalid sha256")
    path = Path(rawpath)
    if not path.is_absolute() or path.is_symlink() or not path.is_file():
        raise ValueError(f"{kind}: missing, link or non-absolute file")
    hasher = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            hasher.update(block)
    if hasher.hexdigest() != digest.lower():
        raise ValueError(f"{kind}: SHA256_MISMATCH")
    return {"path": str(path), "sha256": digest.lower(), "bytes": path.stat().st_size,
            "integrity": "SHA256_CHECKED"}


def bind_manifest(path: Path, out: Path) -> dict:
    if out.exists():
        raise ValueError("Output exists; refusing overwrite")
    raw = path.read_bytes()
    if len(raw) > 300_000:
        raise ValueError("Manifest too large")
    data = json.loads(raw.decode("utf-8-sig"))
    if not isinstance(data, dict) or data.get("schema") != "EA_LAB_RUN_EVIDENCE_INPUT_V1":
        raise ValueError("Wrong input schema")
    for key in REQUIRED_TEXT:
        val = data.get(key)
        if not isinstance(val, str) or not val or len(val) > 250:
            raise ValueError("Missing or invalid identity: " + key)
    if not ID_RE.fullmatch(data["run_id"]) or not ID_RE.fullmatch(data["strategy_id"]):
        raise ValueError("Unsafe RunID or StrategyID")
    artifacts = data.get("artifacts")
    if not isinstance(artifacts, dict) or set(artifacts) - set(ARTIFACTS + OPTIONAL_ARTIFACTS):
        raise ValueError("Unexpected artifact keys")
    if not all(k in artifacts for k in ARTIFACTS):
        raise ValueError("Required original source, EX5, SET, native HTML and graph proof missing")
    if data.get("stage") not in ("MODEL1", "MODEL4", "OPTIMIZATION", "BWD", "OOS", "HOLDOUT"):
        raise ValueError("Unsupported stage")
    if data.get("holdout_authorized") is True:
        raise ValueError("Cannot authorize HOLDOUT by importing a manifest")
    outputs = {k: check_artifact(k, v) for k, v in sorted(artifacts.items())}
    result = {
        "schema": "EA_LAB_RUN_EVIDENCE_REFERENCE_V1",
        "authority": "RAW_FILE_HASH_CHECK_ONLY_NOT_REVIEWED",
        "receipt_input_sha256": hashlib.sha256(raw).hexdigest(),
        "identity": {k: data[k] for k in REQUIRED_TEXT},
        "stage": data["stage"], "artifacts": outputs,
        "run_result": None, "metric_status": "NOT_VERIFIED",
        "selection_verdict": None, "research_grade": "UNKNOWN",
        "report_acceptance": "NOT_REVIEWED",
        "candidate_accepted": False, "can_execute": False,
        "can_submit": False, "portfolio_deployment": None,
        "monitor_link_state": "REFERENCE_ONLY_NOT_PUBLISHED",
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        result = bind_manifest(args.manifest, args.out)
        print(json.dumps({"run_id": result["identity"]["run_id"],
                          "files_checked": len(result["artifacts"]),
                          "report_acceptance": result["report_acceptance"]}, indent=2))
        return 0
    except (OSError, ValueError, UnicodeError) as exc:
        print("BLOCKED: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
