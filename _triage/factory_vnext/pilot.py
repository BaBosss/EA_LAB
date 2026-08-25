# -*- coding: utf-8 -*-
"""End-to-end offline Factory vNext SuperTrendFlip sidecar pilot."""
from __future__ import annotations

import datetime as _dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
from typing import Any, Dict, Mapping, Optional

from .architecture import (
    make_component,
    make_master_mold,
    make_position_group,
    make_strategy_family,
    make_strategy_variant,
    variant_context,
)
from .contracts import (
    artifact_ref,
    canonical_json,
    home_match_status,
    make_home_contract,
    make_run_manifest,
    make_window_contract,
    stable_id,
    validate_run_manifest,
)
from .derived_metrics import derive_metric_bundle, validate_metric_bundle
from .grade_confidence import build_grade_evidence, validate_grade_evidence
from .report import build_report, validate_report_record
from .supertrend_adapter import (
    CONCEPT_ID,
    EXECUTION_TF,
    LOGICAL_SYMBOL,
    STRATEGY_VERSION,
    load_supertrend_pilot,
)
from .telemetry import make_event, validate_event


class PilotError(ValueError):
    pass


SCHEMA_VERSION = "factory-vnext-supertrend-pilot-v1"
AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"
VARIANT_ID = "LEGACY-STF-REV05"


def _need_text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise PilotError("%s is required" % name)
    return value.strip()


def _iso_mt5_date(value: str, name: str) -> str:
    text = _need_text(value, name).replace(".", "-")
    try:
        _dt.date.fromisoformat(text)
    except ValueError as exc:
        raise PilotError("%s must be an MT5 YYYY.MM.DD date" % name) from exc
    return text

def _as_nonnegative_int(value: Any, name: str) -> int:
    if isinstance(value, bool):
        raise PilotError("%s must be numeric" % name)
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise PilotError("%s must be numeric" % name) from exc
    if number < 0 or int(number) != number:
        raise PilotError("%s must be a non-negative integer" % name)
    return int(number)


def _load_mt5_parser(repo_root: str):
    parser_path = Path(repo_root) / "scripts" / "parse_mt5_report.py"
    if not parser_path.is_file():
        raise PilotError("MT5 report parser not found: %s" % parser_path)
    spec = importlib.util.spec_from_file_location("factory_vnext_mt5_report_parser", parser_path)
    if spec is None or spec.loader is None:
        raise PilotError("cannot load MT5 report parser")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    parser = getattr(module, "parse_report", None)
    if not callable(parser):
        raise PilotError("MT5 report parser has no parse_report")
    return parser


def _architecture():
    master = make_master_mold("LEGACY-STF-MOLD", "pilot-v1", ["CAP_ENTRY"])
    family = make_strategy_family(master, "LEGACY-STF", CONCEPT_ID, ["CAP_ENTRY"])
    group = make_position_group("PG_MAIN", "BASELINE")
    component = make_component("CMP_ENTRY", "ENTRY", "PG_MAIN", capabilities=["CAP_ENTRY"])
    variant = make_strategy_variant(family, VARIANT_ID, STRATEGY_VERSION, [group], [component])
    return master, family, variant

def _parse_and_validate_report(repo_root: str, report_path: str, tester_model: str) -> Dict[str, Any]:
    try:
        parsed = dict(_load_mt5_parser(repo_root)(report_path))
    except Exception as exc:
        raise PilotError("MT5 report parse failed: %s" % exc) from exc
    expected_ea = "%s_%s" % (CONCEPT_ID, STRATEGY_VERSION)
    if parsed.get("ea_name") != expected_ea:
        raise PilotError("unexpected Expert identity: %r" % parsed.get("ea_name"))
    symbol = _need_text(parsed.get("symbol"), "report.symbol").upper()
    tf = _need_text(parsed.get("period"), "report.period").upper()
    if symbol != LOGICAL_SYMBOL or tf != EXECUTION_TF:
        raise PilotError("OUTSIDE_VALIDATED_CONTRACT: report is %s/%s, expected %s/%s" % (
            symbol, tf, LOGICAL_SYMBOL, EXECUTION_TF,
        ))
    bars = _as_nonnegative_int(parsed.get("bars"), "report.bars")
    if bars <= 0:
        raise PilotError("bars generated must be > 0")
    _as_nonnegative_int(parsed.get("ticks"), "report.ticks")
    _as_nonnegative_int(parsed.get("total_trades"), "report.total_trades")
    company = _need_text(parsed.get("company"), "report.company")
    build = _as_nonnegative_int(parsed.get("report_build"), "report.report_build")
    if build <= 0:
        raise PilotError("report.report_build must be > 0")
    history_quality = _need_text(parsed.get("history_quality"), "report.history_quality")
    model = _need_text(tester_model, "tester_model").upper()
    if "REAL_TICKS" in model and "100% real ticks" not in history_quality.lower():
        raise PilotError("tester model requires raw History Quality = 100% real ticks")
    parsed["from_iso"] = _iso_mt5_date(parsed.get("from_date"), "report.from_date")
    parsed["to_iso"] = _iso_mt5_date(parsed.get("to_date"), "report.to_date")
    parsed["broker_data_environment"] = "%s|MT5_BUILD_%d" % (company, build)
    parsed["tester_model"] = model
    return parsed

def _range_evidence(parameter_count: int) -> Dict[str, Any]:
    return {
        "authority": AUTHORITY,
        "generator": "Factory vNext Range Generator V1",
        "status": "SEMANTICS_REQUIRED",
        "evidence_label": "UNAVAILABLE",
        "candidates": [],
        "parameter_count": parameter_count,
        "reason": (
            "Legacy SuperTrend rev05 preset has no canonical Factory vNext parameter semantic bindings; "
            "no optimization range may be invented by the sidecar"
        ),
    }


def _report_payload(parsed: Mapping[str, Any], raw_sha256: str) -> Dict[str, Any]:
    keys = (
        "history_quality", "bars", "ticks", "total_trades", "total_deals",
        "net_profit", "profit_factor", "equity_drawdown_relative_pct", "report_build",
    )
    payload = {key: parsed.get(key) for key in keys}
    payload.update({
        "report_sha256": raw_sha256,
        "from_date": parsed["from_iso"],
        "to_date": parsed["to_iso"],
    })
    return payload


def build_supertrend_report_pilot(
    repo_root: str,
    report_path: str,
    *,
    source_commit: str,
    window_class: str,
    tester_model: str,
    source_path: Optional[str] = None,
    preset_path: Optional[str] = None,
    report_root: Optional[str] = None,
) -> Dict[str, Any]:
    root = os.path.abspath(repo_root)
    report_full = os.path.abspath(report_path)
    if not os.path.isfile(report_full):
        raise PilotError("report artifact not found: %s" % report_full)
    parsed = _parse_and_validate_report(root, report_full, tester_model)
    adapter = load_supertrend_pilot(
        root,
        source_path=source_path,
        preset_path=preset_path,
    )
    master, family, variant = _architecture()
    context = variant_context(master, family, variant)
    home = make_home_contract(
        adapter["ConceptID"],
        adapter["StrategyVersion"],
        adapter["LogicalSymbol"],
        adapter["ExecutionTF"],
        context,
    )
    status = home_match_status(home, parsed["symbol"], parsed["period"])
    if status != "INSIDE_VALIDATED_CONTRACT":
        raise PilotError("OUTSIDE_VALIDATED_CONTRACT")

    outcomes = _as_nonnegative_int(parsed.get("total_trades"), "report.total_trades")
    bars = _as_nonnegative_int(parsed.get("bars"), "report.bars")
    window = make_window_contract(
        window_class,
        parsed["from_iso"],
        parsed["to_iso"],
        EXECUTION_TF,
        bars=bars,
        signals=None,
        outcomes=outcomes,
        outcome_unit="trades",
    )
    evidence_root = os.path.abspath(report_root or os.path.dirname(report_full))
    raw_report_ref = artifact_ref(report_full, root=evidence_root, label="MEASURED")
    run = make_run_manifest(
        source_commit=source_commit,
        home=home,
        window=window,
        profile_id=adapter["ProfileID"],
        parameter_set=adapter["ParameterSet"],
        physical_symbol=parsed["symbol"],
        broker_data=parsed["broker_data_environment"],
        tester_model=parsed["tester_model"],
        bars=bars,
        artifacts=[adapter["SourceRef"], adapter["PresetRef"], raw_report_ref],
    )
    context_event = make_event(
        run_id=run["RunID"],
        variant=variant,
        event_family="CONTEXT_EVENTS",
        evidence_label="MEASURED",
        scope="VARIANT",
        stable_key=raw_report_ref["sha256"],
        payload=_report_payload(parsed, raw_report_ref["sha256"]),
    )
    metric_bundle = derive_metric_bundle([context_event])
    grade = build_grade_evidence(metric_bundle, home_status=status)
    identity = {
        "Strategy": parsed["ea_name"],
        "HomeContractID": home["HomeContractID"],
        "LogicalSymbol": home["LogicalSymbol"],
        "PhysicalSymbol": run["PhysicalSymbol"],
        "ExecutionTF": home["ExecutionTF"],
        "ProfileID": run["ProfileID"],
        "BrokerData": run["BrokerDataEnvironment"],
        "WindowContractID": window["WindowContractID"],
        "ParameterSetID": run["ParameterSetID"],
        "RunID": run["RunID"],
        "VariantID": variant["VariantID"],
    }
    report = build_report(identity, metric_bundle, grade)
    range_evidence = _range_evidence(len(adapter["ParameterSet"]["parameters"]))
    pilot_identity = {
        "RunID": run["RunID"],
        "MetricBundleID": metric_bundle["MetricBundleID"],
        "GradeEvidenceID": grade["GradeEvidenceID"],
        "ReportID": report["ReportID"],
        "RawReportSHA256": raw_report_ref["sha256"],
        "RangeStatus": range_evidence["status"],
    }
    record: Dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "authority": AUTHORITY,
        "PilotID": stable_id("PILOT", pilot_identity, hex_chars=32),
        "Architecture": {
            "MasterMold": master,
            "Family": family,
            "Variant": variant,
        },
        "HomeContract": home,
        "WindowContract": window,
        "ParameterSet": adapter["ParameterSet"],
        "RunManifest": run,
        "RawReportRef": raw_report_ref,
        "RawReportSummary": _report_payload(parsed, raw_report_ref["sha256"]),
        "TelemetryEvents": [context_event],
        "MetricBundle": metric_bundle,
        "GradeEvidence": grade,
        "RangeEvidence": range_evidence,
        "Report": report,
    }
    validate_pilot_record(record)
    return record


def validate_pilot_record(record: Mapping[str, Any]) -> None:
    if not isinstance(record, Mapping):
        raise PilotError("pilot record must be a mapping")
    if record.get("authority") != AUTHORITY:
        raise PilotError("pilot authority boundary is missing")
    _need_text(record.get("PilotID"), "PilotID")
    home = record.get("HomeContract")
    window = record.get("WindowContract")
    run = record.get("RunManifest")
    raw_ref = record.get("RawReportRef")
    events = record.get("TelemetryEvents")
    if not isinstance(home, Mapping) or not isinstance(window, Mapping):
        raise PilotError("HomeContract and WindowContract are required")
    if not isinstance(run, Mapping):
        raise PilotError("RunManifest is required")
    if not isinstance(raw_ref, Mapping) or not raw_ref.get("sha256"):
        raise PilotError("RawReportRef is required")
    try:
        validate_run_manifest(run)
    except Exception as exc:
        raise PilotError(str(exc)) from exc
    if run.get("HomeContractID") != home.get("HomeContractID"):
        raise PilotError("RunManifest/HomeContractID mismatch")
    if run.get("WindowContractID") != window.get("WindowContractID"):
        raise PilotError("RunManifest/WindowContractID mismatch")
    if home_match_status(home, LOGICAL_SYMBOL, EXECUTION_TF) != "INSIDE_VALIDATED_CONTRACT":
        raise PilotError("OUTSIDE_VALIDATED_CONTRACT")
    architecture = record.get("Architecture")
    if not isinstance(architecture, Mapping):
        raise PilotError("Architecture is required")
    variant = architecture.get("Variant")
    if not isinstance(variant, Mapping) or variant.get("VariantID") != VARIANT_ID:
        raise PilotError("pilot Variant identity mismatch")
    if not isinstance(events, list) or len(events) != 1:
        raise PilotError("pilot must contain exactly one raw context event")
    try:
        validate_event(events[0])
        validate_metric_bundle(record.get("MetricBundle"))
        validate_grade_evidence(record.get("GradeEvidence"))
        validate_report_record(record.get("Report"))
    except Exception as exc:
        raise PilotError(str(exc)) from exc
    run_id = run.get("RunID")
    if events[0].get("RunID") != run_id:
        raise PilotError("Telemetry RunID mismatch")
    if record["MetricBundle"].get("RunID") != run_id:
        raise PilotError("MetricBundle RunID mismatch")
    if record["GradeEvidence"].get("RunID") != run_id:
        raise PilotError("GradeEvidence RunID mismatch")
    if record["Report"].get("RunID") != run_id:
        raise PilotError("Report RunID mismatch")
    range_evidence = record.get("RangeEvidence")
    if not isinstance(range_evidence, Mapping):
        raise PilotError("RangeEvidence is required")
    if range_evidence.get("status") != "SEMANTICS_REQUIRED" or range_evidence.get("candidates") != []:
        raise PilotError("legacy pilot must fail closed at SEMANTICS_REQUIRED")
    expected_pilot_id = stable_id("PILOT", {
        "RunID": run_id,
        "MetricBundleID": record["MetricBundle"]["MetricBundleID"],
        "GradeEvidenceID": record["GradeEvidence"]["GradeEvidenceID"],
        "ReportID": record["Report"]["ReportID"],
        "RawReportSHA256": raw_ref["sha256"],
        "RangeStatus": range_evidence["status"],
    }, hex_chars=32)
    if record["PilotID"] != expected_pilot_id:
        raise PilotError("PilotID does not match immutable evidence chain")


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _json_bytes(value: Mapping[str, Any]) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8")


def write_pilot_artifacts(record: Mapping[str, Any], output_dir: str) -> Dict[str, Any]:
    validate_pilot_record(record)
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)
    report_path = out / "report.html"
    manifest_path = out / "pilot_manifest.json"
    report_path.write_text(record["Report"]["html"], encoding="utf-8", newline="\n")
    manifest = dict(record)
    manifest["Report"] = {key: value for key, value in record["Report"].items() if key != "html"}
    manifest_path.write_bytes(_json_bytes(manifest))
    files = {
        "pilot_manifest.json": {
            "sha256": _sha256_file(manifest_path),
            "bytes": manifest_path.stat().st_size,
        },
        "report.html": {
            "sha256": _sha256_file(report_path),
            "bytes": report_path.stat().st_size,
        },
    }
    index = {
        "schema_version": "factory-vnext-pilot-artifact-index-v1",
        "authority": AUTHORITY,
        "PilotID": record["PilotID"],
        "RunID": record["RunManifest"]["RunID"],
        "RawReportRef": dict(record["RawReportRef"]),
        "files": files,
    }
    index["ArtifactIndexID"] = stable_id("PIDX", {
        "PilotID": index["PilotID"],
        "RunID": index["RunID"],
        "RawReportSHA256": index["RawReportRef"]["sha256"],
        "files": files,
    }, hex_chars=32)
    (out / "artifact_index.json").write_bytes(_json_bytes(index))
    return index
