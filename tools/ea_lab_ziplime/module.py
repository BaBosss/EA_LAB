"""Deterministic EA_LAB adapter for Ziplime research dataset preparation."""
from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.metadata
import json
import pathlib
import sys
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Any

SCHEMA_VERSION = "ea-lab-ziplime-dataset-v1"
TOOL_VERSION = "0.1.0"
EXPECTED_ZIPLIME_VERSION = "1.19.16"
PILOT_LOGICAL_SYMBOL = "BTCUSD"
PILOT_EXECUTION_TF = "H4"
AUTHORITY = "RESEARCH_ONLY"
REQUIRED_FIELDS = ("timestamp", "open", "high", "low", "close", "volume")


class ModuleError(ValueError):
    """Fail-closed module validation error."""


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_decimal(raw: str, field: str, row_number: int) -> tuple[Decimal, str]:
    try:
        value = Decimal(str(raw).strip())
    except (InvalidOperation, AttributeError):
        raise ModuleError(f"row {row_number}: {field} is not a decimal")
    if not value.is_finite():
        raise ModuleError(f"row {row_number}: {field} must be finite")
    if value == 0:
        return value, "0"
    return value, format(value.normalize(), "f")


def canonical_timestamp(raw: str, config: dict[str, Any], row_number: int) -> tuple[datetime, str]:
    text = str(raw).strip()
    fmt = config.get("timestamp_format")
    try:
        if fmt:
            stamp = datetime.strptime(text, fmt)
        else:
            stamp = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ModuleError(f"row {row_number}: invalid timestamp: {exc}") from exc
    if stamp.tzinfo is None:
        if config.get("timezone", "UTC") != "UTC":
            raise ModuleError("naive timestamps require timezone='UTC'")
        stamp = stamp.replace(tzinfo=timezone.utc)
    stamp = stamp.astimezone(timezone.utc)
    timespec = "microseconds" if stamp.microsecond else "seconds"
    return stamp, stamp.isoformat(timespec=timespec).replace("+00:00", "Z")


def load_column_map(path: pathlib.Path) -> dict[str, Any]:
    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ModuleError(f"invalid column-map JSON: {exc}") from exc
    if not isinstance(config, dict) or not isinstance(config.get("columns"), dict):
        raise ModuleError("column-map must contain object field 'columns'")
    columns = config["columns"]
    missing = [name for name in REQUIRED_FIELDS if not columns.get(name)]
    if missing:
        raise ModuleError(f"column-map missing explicit fields: {','.join(missing)}")
    if config.get("timezone", "UTC") != "UTC":
        raise ModuleError("only timezone='UTC' is supported in v1")
    return config


def validate_pilot_identity(logical_symbol: str, execution_tf: str) -> None:
    if logical_symbol != PILOT_LOGICAL_SYMBOL or execution_tf != PILOT_EXECUTION_TF:
        raise ModuleError(
            "OUTSIDE_VALIDATED_CONTRACT: "
            f"expected {PILOT_LOGICAL_SYMBOL}/{PILOT_EXECUTION_TF}, got {logical_symbol}/{execution_tf}"
        )


def validate_sha(value: str, name: str) -> None:
    if len(value) != 40 or any(c not in "0123456789abcdef" for c in value):
        raise ModuleError(f"{name} must be lowercase 40-hex")


def read_normalized_rows(input_path: pathlib.Path, config: dict[str, Any]) -> list[dict[str, str]]:
    columns = config["columns"]
    rows: list[dict[str, str]] = []
    previous_stamp: datetime | None = None
    try:
        handle = input_path.open("r", encoding="utf-8-sig", newline="")
    except OSError as exc:
        raise ModuleError(f"cannot read input CSV: {exc}") from exc
    with handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise ModuleError("input CSV has no header")
        mapped_headers = [str(columns[name]) for name in REQUIRED_FIELDS]
        missing_headers = [name for name in mapped_headers if name not in reader.fieldnames]
        if missing_headers:
            raise ModuleError(f"input CSV missing mapped columns: {','.join(missing_headers)}")
        for row_number, row in enumerate(reader, start=2):
            stamp_dt, stamp_text = canonical_timestamp(row[columns["timestamp"]], config, row_number)
            if previous_stamp is not None and stamp_dt <= previous_stamp:
                raise ModuleError(f"row {row_number}: timestamps must be strictly increasing and unique")
            previous_stamp = stamp_dt
            numeric: dict[str, Decimal] = {}
            canonical: dict[str, str] = {}
            for name in ("open", "high", "low", "close", "volume"):
                numeric[name], canonical[name] = canonical_decimal(row[columns[name]], name, row_number)
            if numeric["volume"] < 0:
                raise ModuleError(f"row {row_number}: volume must be non-negative")
            if numeric["high"] < max(numeric["open"], numeric["low"], numeric["close"]):
                raise ModuleError(f"row {row_number}: high violates OHLC consistency")
            if numeric["low"] > min(numeric["open"], numeric["high"], numeric["close"]):
                raise ModuleError(f"row {row_number}: low violates OHLC consistency")
            rows.append({"timestamp": stamp_text, **canonical})
    if not rows:
        raise ModuleError("input CSV contains no data rows")
    return rows


def write_normalized(rows: list[dict[str, str]], path: pathlib.Path) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=REQUIRED_FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_json_deterministic(payload: dict[str, Any], path: pathlib.Path) -> None:
    text = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n"
    path.write_text(text, encoding="utf-8", newline="\n")


def prepare_dataset(args: argparse.Namespace) -> dict[str, Any]:
    input_path = pathlib.Path(args.input).resolve()
    map_path = pathlib.Path(args.column_map).resolve()
    output_dir = pathlib.Path(args.output_dir).resolve()
    validate_pilot_identity(args.logical_symbol, args.execution_tf)
    validate_sha(args.source_commit, "source_commit")
    if not input_path.is_file():
        raise ModuleError(f"input CSV not found: {input_path}")
    if not map_path.is_file():
        raise ModuleError(f"column-map not found: {map_path}")
    config = load_column_map(map_path)
    rows = read_normalized_rows(input_path, config)
    output_dir.mkdir(parents=True, exist_ok=True)
    normalized_path = output_dir / "normalized_dataset.csv"
    manifest_path = output_dir / "dataset_manifest.json"
    write_normalized(rows, normalized_path)
    payload = {
        "authority": AUTHORITY,
        "column_map_name": map_path.name,
        "column_map_sha256": sha256_file(map_path),
        "concept": args.concept,
        "execution_tf": args.execution_tf,
        "first_timestamp": rows[0]["timestamp"],
        "home_contract_id": args.home_contract_id,
        "last_timestamp": rows[-1]["timestamp"],
        "logical_symbol": args.logical_symbol,
        "normalized_dataset_sha256": sha256_file(normalized_path),
        "parameter_set_id": args.parameter_set_id,
        "profile_id": args.profile_id,
        "row_count": len(rows),
        "run_id": args.run_id,
        "schema_version": SCHEMA_VERSION,
        "source_commit": args.source_commit,
        "source_name": input_path.name,
        "source_sha256": sha256_file(input_path),
        "tool_version": TOOL_VERSION,
        "window_contract_id": args.window_contract_id,
        "ziplime_expected_version": EXPECTED_ZIPLIME_VERSION,
    }
    for key in ("concept", "home_contract_id", "window_contract_id", "profile_id", "parameter_set_id", "run_id"):
        if not payload[key]:
            raise ModuleError(f"{key} must not be empty")
    write_json_deterministic(payload, manifest_path)
    return payload


def load_manifest(path: pathlib.Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ModuleError(f"invalid dataset manifest: {exc}") from exc
    if not isinstance(payload, dict):
        raise ModuleError("dataset manifest must be a JSON object")
    return payload


def verify_dataset(args: argparse.Namespace) -> dict[str, Any]:
    output_dir = pathlib.Path(args.output_dir).resolve()
    source_path = pathlib.Path(args.source).resolve()
    map_path = pathlib.Path(args.column_map).resolve()
    manifest_path = output_dir / "dataset_manifest.json"
    normalized_path = output_dir / "normalized_dataset.csv"
    if not manifest_path.is_file() or not normalized_path.is_file():
        raise ModuleError("dataset artifacts are incomplete")
    if not source_path.is_file() or not map_path.is_file():
        raise ModuleError("verification source or column-map is missing")
    payload = load_manifest(manifest_path)
    required = {
        "authority": AUTHORITY,
        "schema_version": SCHEMA_VERSION,
        "logical_symbol": PILOT_LOGICAL_SYMBOL,
        "execution_tf": PILOT_EXECUTION_TF,
        "ziplime_expected_version": EXPECTED_ZIPLIME_VERSION,
    }
    for key, expected in required.items():
        if payload.get(key) != expected:
            raise ModuleError(f"manifest {key} mismatch: expected {expected!r}, got {payload.get(key)!r}")
    validate_sha(str(payload.get("source_commit", "")), "manifest source_commit")
    checks = {
        "normalized_dataset_sha256": sha256_file(normalized_path),
        "source_sha256": sha256_file(source_path),
        "column_map_sha256": sha256_file(map_path),
    }
    for key, actual in checks.items():
        if payload.get(key) != actual:
            raise ModuleError(f"artifact hash mismatch for {key}")
    with normalized_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        normalized_rows = list(reader)
    if reader.fieldnames != list(REQUIRED_FIELDS):
        raise ModuleError("normalized dataset schema mismatch")
    if payload.get("row_count") != len(normalized_rows) or not normalized_rows:
        raise ModuleError("normalized dataset row_count mismatch")
    if payload.get("first_timestamp") != normalized_rows[0]["timestamp"]:
        raise ModuleError("normalized dataset first_timestamp mismatch")
    if payload.get("last_timestamp") != normalized_rows[-1]["timestamp"]:
        raise ModuleError("normalized dataset last_timestamp mismatch")
    return payload


def evaluate_environment(python_version: tuple[int, int], ziplime_version: str | None) -> dict[str, Any]:
    python_ok = (3, 12) <= python_version < (3, 14)
    ziplime_ok = ziplime_version == EXPECTED_ZIPLIME_VERSION
    return {
        "ok": python_ok and ziplime_ok,
        "python_ok": python_ok,
        "python_version": f"{python_version[0]}.{python_version[1]}",
        "ziplime_expected_version": EXPECTED_ZIPLIME_VERSION,
        "ziplime_installed_version": ziplime_version,
        "ziplime_ok": ziplime_ok,
    }


def doctor_environment() -> dict[str, Any]:
    try:
        installed = importlib.metadata.version("ziplime")
    except importlib.metadata.PackageNotFoundError:
        installed = None
    return evaluate_environment((sys.version_info.major, sys.version_info.minor), installed)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ea_lab_ziplime")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("doctor", help="check pinned external runtime without installing anything")
    prep = sub.add_parser("prepare", help="normalize an explicit CSV source into governed artifacts")
    prep.add_argument("--input", required=True)
    prep.add_argument("--column-map", required=True)
    prep.add_argument("--output-dir", required=True)
    prep.add_argument("--source-commit", required=True)
    prep.add_argument("--concept", required=True)
    prep.add_argument("--logical-symbol", required=True)
    prep.add_argument("--execution-tf", required=True)
    prep.add_argument("--home-contract-id", required=True)
    prep.add_argument("--window-contract-id", required=True)
    prep.add_argument("--profile-id", required=True)
    prep.add_argument("--parameter-set-id", required=True)
    prep.add_argument("--run-id", required=True)
    verify = sub.add_parser("verify", help="verify governed artifacts and source hashes")
    verify.add_argument("--output-dir", required=True)
    verify.add_argument("--source", required=True)
    verify.add_argument("--column-map", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.command == "doctor":
            result = doctor_environment()
            print(json.dumps(result, sort_keys=True))
            return 0 if result["ok"] else 2
        if args.command == "prepare":
            result = prepare_dataset(args)
        elif args.command == "verify":
            result = verify_dataset(args)
        else:
            raise ModuleError(f"unknown command: {args.command}")
        print(json.dumps({"ok": True, "authority": AUTHORITY, "run_id": result.get("run_id")}, sort_keys=True))
        return 0
    except ModuleError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
