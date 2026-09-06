"""Task-scoped, manifest-bound fixed-backtest executor for Hermes EA_LAB.

The model supplies only a pre-authorized cell_id. Every launch argument comes
from a SHA-bound Control Tower manifest plus hard safety invariants here.
No arbitrary shell, executable, file-write, optimization, HOLDOUT, Force, or
legacy-identity escape surface is exposed.
"""
from __future__ import annotations

import csv
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable

from mcp.server.mcpserver.server import MCPServer
from mcp.types import ToolAnnotations

EXPECTED_EXPERT = r"EALabTpl\Probe_19_AdaptiveTrendGrid"
EXPECTED_SET_REL = "ea_template/sets/probe/Boss_19_AdaptiveTrendGrid_V0_STOP_VALIDATION_CENTER.set"
EXPECTED_MODEL = "1"
EXPECTED_DEPOSIT = "10000"
EXPECTED_LEVERAGE = "100"
ALLOWED_WINDOWS = {
    ("MAIN", "2023.01.01", "2025.12.31"),
    ("BWD", "2020.01.01", "2022.12.31"),
}
REQUIRED_COLUMNS = {
    "cell_id", "symbol", "tf", "window", "from_date", "to_date", "model",
    "set_path", "report_name", "holdout", "optimization",
}
EXECUTE_FIXED = ToolAnnotations(
    read_only_hint=False,
    destructive_hint=False,
    idempotent_hint=False,
    open_world_hint=False,
)


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def workspace_root(value: str | Path) -> Path:
    root = Path(value).resolve(strict=True)
    if not root.is_dir():
        raise ValueError("SafeWorkspace root must be a directory")
    return root


def resolve_set_inside(root: Path, relative_path: str) -> Path:
    raw = Path(relative_path)
    if raw.is_absolute():
        raise ValueError("set_path absolute paths are denied")
    if ".." in raw.parts:
        raise ValueError("set_path path escape is denied")
    candidate = (root / raw).resolve(strict=True)
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise ValueError("set_path escapes SafeWorkspace") from exc
    if not candidate.is_file():
        raise ValueError("set_path is not a file")
    return candidate


def verify_sha(path: Path, expected: str, label: str) -> str:
    if not path.is_file():
        raise ValueError(f"{label} not found")
    actual = sha256_path(path)
    if actual.lower() != expected.lower():
        raise ValueError(f"{label} SHA256 mismatch: expected {expected} actual {actual}")
    return actual


def verify_receipt_registry(path: str | Path, expected_sha: str) -> dict[str, object]:
    target = Path(path).resolve(strict=True)
    verify_sha(target, expected_sha, "receipt registry")
    matches: list[dict[str, object]] = []
    for line in target.read_text(encoding="utf-8-sig").splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        if record.get("ea_logical_identity") == "Probe_19_AdaptiveTrendGrid":
            matches.append(record)
    if len(matches) != 1:
        raise ValueError("receipt registry must contain exactly one Probe_19_AdaptiveTrendGrid receipt")
    artifact_sha = str(matches[0].get("artifact_sha256", ""))
    if len(artifact_sha) != 64:
        raise ValueError("receipt registry artifact_sha256 is invalid")
    return matches[0]


def _read_manifest(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None or set(reader.fieldnames) != REQUIRED_COLUMNS:
            raise ValueError("manifest columns mismatch")
        return list(reader)

def _validate_row(root: Path, row: dict[str, str], expected_set_sha: str) -> dict[str, str]:
    cell_id = row.get("cell_id", "").strip()
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,96}", cell_id):
        raise ValueError("cell_id is invalid")
    if row.get("holdout", "").upper() != "NO":
        raise ValueError("HOLDOUT execution is denied")
    if row.get("optimization", "").upper() != "NO":
        raise ValueError("optimization execution is denied")
    if row.get("model") != EXPECTED_MODEL:
        raise ValueError("H2 executor requires Model=1")
    window = (row.get("window", ""), row.get("from_date", ""), row.get("to_date", ""))
    if window not in ALLOWED_WINDOWS:
        if row.get("to_date", "") >= "2026.01.01":
            raise ValueError("HOLDOUT dates are denied")
        raise ValueError("window is outside the pre-authorized MAIN/BWD contract")
    if row.get("set_path") != EXPECTED_SET_REL:
        raise ValueError("set_path is not the locked Boss19 validation set")
    set_path = resolve_set_inside(root, row["set_path"])
    verify_sha(set_path, expected_set_sha, "set")
    symbol = row.get("symbol", "").strip()
    if not re.fullmatch(r"[A-Za-z0-9._-]{2,32}", symbol):
        raise ValueError("symbol is invalid")
    if row.get("tf") not in {"M15", "H1", "H4"}:
        raise ValueError("tf is outside H2 authorization")
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,120}", row.get("report_name", "")):
        raise ValueError("report_name is invalid")
    return row


def load_bound_cell(
    root: Path, manifest_path: str | Path, manifest_sha: str, cell_id: str, expected_set_sha: str
) -> dict[str, str]:
    manifest = Path(manifest_path).resolve(strict=True)
    verify_sha(manifest, manifest_sha, "manifest")
    rows = _read_manifest(manifest)
    matches = [row for row in rows if row.get("cell_id") == cell_id]
    if len(matches) != 1:
        raise ValueError("cell_id not authorized or duplicated")
    return _validate_row(root, matches[0], expected_set_sha)

def build_runner_argv(root: Path, row: dict[str, str], receipt_registry: str | Path) -> list[str]:
    runner = (root / "scripts" / "mt5_run.ps1").resolve(strict=True)
    set_path = resolve_set_inside(root, row["set_path"])
    return [
        "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(runner),
        "-Expert", EXPECTED_EXPERT,
        "-Symbol", row["symbol"],
        "-Period", row["tf"],
        "-FromDate", row["from_date"],
        "-ToDate", row["to_date"],
        "-SetFile", str(set_path),
        "-Model", EXPECTED_MODEL,
        "-Deposit", EXPECTED_DEPOSIT,
        "-Leverage", EXPECTED_LEVERAGE,
        "-ReportName", row["report_name"],
        "-BuildReceiptRegistry", str(Path(receipt_registry).resolve(strict=True)),
    ]


def parse_report_default(root: Path, report: Path) -> dict[str, object]:
    parser_path = (root / "scripts" / "parse_mt5_report.py").resolve(strict=True)
    spec = importlib.util.spec_from_file_location("ea_lab_parse_mt5_report", parser_path)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load parse_mt5_report.py")
    parser = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(parser)
    return parser.parse_report(str(report))


def report_identity_mismatches(metrics: dict[str, object], row: dict[str, str], runner_stdout: str) -> list[str]:
    mismatches: list[str] = []
    ea_name = str(metrics.get("ea_name", "")).replace(".ex5", "").replace("/", "\\").split("\\")[-1]
    if ea_name != "Probe_19_AdaptiveTrendGrid":
        mismatches.append(f"expert={metrics.get('ea_name')}")
    for key, expected in (("period", row["tf"]), ("from_date", row["from_date"]), ("to_date", row["to_date"])):
        if str(metrics.get(key, "")) != expected:
            mismatches.append(f"{key}={metrics.get(key)} expected={expected}")
    if str(metrics.get("leverage", "")) != "1:100":
        mismatches.append(f"leverage={metrics.get('leverage')} expected=1:100")
    match = re.search(r"symbol preflight:\s+logical=(\S+)\s+tester=(\S+)", runner_stdout)
    if match is None:
        mismatches.append("tester_symbol_preflight=MISSING")
    elif str(metrics.get("symbol", "")).casefold() != match.group(2).casefold():
        mismatches.append(f"symbol={metrics.get('symbol')} expected_tester={match.group(2)}")
    return mismatches


def _read_sidecar(path: Path) -> dict[str, object] | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception as exc:
        return {"status": "SIDECAR_PARSE_ERROR", "error": str(exc)}


def full_window_evidence_eligibility(truncation: dict[str, object] | None) -> tuple[bool, str]:
    if truncation is None:
        return False, "TRUNCATION_CHECK_MISSING"
    if not isinstance(truncation, dict):
        return False, "TRUNCATION_CHECK_PARSE_ERROR"
    if truncation.get("status") == "SIDECAR_PARSE_ERROR":
        return False, "TRUNCATION_CHECK_PARSE_ERROR"
    truncated = truncation.get("truncated")
    if truncated is True:
        return False, "TRUNCATED_RUN"
    if truncation.get("check_status") == "CHECK_ERROR":
        return False, "TRUNCATION_CHECK_ERROR"
    if (truncation.get("schema_version") == 2
            and truncation.get("check_status") == "CHECK_PASS"
            and type(truncation.get("checker_exit_code")) is int
            and truncation["checker_exit_code"] == 0 and truncated is False):
        return True, "TRUNCATION_CHECK_PASS"
    # Legacy false also encoded checker exceptions. It is not sufficient for
    # NEW admission; this does not rewrite any previously accepted receipt.
    return False, "TRUNCATION_CHECK_UNKNOWN"


def run_cell_impl(
    root: Path,
    manifest_path: str | Path,
    manifest_sha: str,
    receipt_registry: str | Path,
    receipt_sha: str,
    cell_id: str,
    expected_set_sha: str,
    *,
    run_process: Callable[..., subprocess.CompletedProcess[str]] = subprocess.run,
    parse_report: Callable[[Path], dict[str, object]] | None = None,
    start_time_ns: int | None = None,
) -> dict[str, object]:
    root = workspace_root(root)
    row = load_bound_cell(root, manifest_path, manifest_sha, cell_id, expected_set_sha)
    receipt = verify_receipt_registry(receipt_registry, receipt_sha)
    argv = build_runner_argv(root, row, receipt_registry)
    started_ns = time.time_ns() if start_time_ns is None else start_time_ns
    completed = run_process(
        argv, cwd=str(root), capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=1900
    )
    base = {
        "cell_id": cell_id,
        "symbol": row["symbol"], "tf": row["tf"], "window": row["window"],
        "runner_exit_code": completed.returncode,
        "runner_stdout": completed.stdout[-12000:] if completed.stdout else "",
        "runner_stderr": completed.stderr[-12000:] if completed.stderr else "",
        "build_receipt": receipt.get("build_receipt"),
    }
    if completed.returncode != 0:
        return {**base, "status": "MECHANICAL_FAIL", "reason": "RUNNER_NONZERO"}
    reports = root / "_mt5_auto" / "reports"
    report = reports / f"{row['report_name']}.htm"
    if not report.is_file() or report.stat().st_mtime_ns < started_ns:
        return {**base, "status": "MECHANICAL_FAIL", "reason": "STALE_OR_MISSING_REPORT"}
    report_sha = sha256_path(report)
    try:
        metrics = (parse_report or (lambda p: parse_report_default(root, p)))(report)
    except Exception as exc:
        return {
            **base, "status": "MECHANICAL_FAIL", "reason": "REPORT_PARSE_ERROR",
            "report_path": str(report), "report_sha256": report_sha, "parse_error": str(exc),
        }
    identity_mismatches = report_identity_mismatches(metrics, row, completed.stdout or "")
    if identity_mismatches:
        return {
            **base, "status": "MECHANICAL_FAIL", "reason": "REPORT_IDENTITY_MISMATCH",
            "report_path": str(report), "report_sha256": report_sha,
            "identity_mismatches": identity_mismatches, "metrics": metrics,
        }
    leverage = _read_sidecar(reports / f"{row['report_name']}.leverage_check.json")
    truncation = _read_sidecar(reports / f"{row['report_name']}.truncation_check.json")
    full_window_eligible, eligibility_reason = full_window_evidence_eligibility(truncation)
    return {
        **base,
        "status": "COMPLETE",
        "reason": "OK",
        "report_path": str(report),
        "report_sha256": report_sha,
        "metrics": metrics,
        "leverage_check": leverage,
        "truncation_check": truncation,
        "full_window_evidence_eligible": full_window_eligible,
        "evidence_eligibility_reason": eligibility_reason,
    }


def _required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError(f"missing task-scoped binding: {name}")
    return value

def create_server(workspace: str | Path) -> MCPServer:
    root = workspace_root(workspace)
    server = MCPServer(
        name="ea-lab-safe-tester-executor",
        description="Manifest-bound fixed-backtest execution for one EA_LAB Hermes tester task.",
    )

    @server.tool(annotations=EXECUTE_FIXED)
    def run_fixed_backtest(cell_id: str) -> str:
        """Run exactly one pre-authorized fixed backtest by manifest cell_id."""
        result = run_cell_impl(
            root,
            _required_env("EA_LAB_TESTER_MANIFEST"),
            _required_env("EA_LAB_TESTER_MANIFEST_SHA256"),
            _required_env("EA_LAB_TESTER_RECEIPT_REGISTRY"),
            _required_env("EA_LAB_TESTER_RECEIPT_SHA256"),
            cell_id,
            _required_env("EA_LAB_TESTER_SET_SHA256"),
        )
        return json.dumps(result, ensure_ascii=False, sort_keys=True)

    return server


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: safe_tester_executor_mcp.py <SafeWorkspace>", file=sys.stderr)
        return 2
    create_server(argv[1]).run("stdio")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
