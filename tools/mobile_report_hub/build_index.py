#!/usr/bin/env python3
"""Build the mobile-report static data index from immutable Git objects only."""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

sys.path.insert(0, str(Path(__file__).resolve().parent))
from control_tower import build_projection
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "reporting"))
import mt5_report_assets as native_assets
import report_package_integrity as integrity

SCHEMA_VERSION = 1
GENERATOR_NAME = "mobile_report_hub.build_index"
GENERATOR_VERSION = "3.2.0"
B16 = "docs/factory/B16_H03_CONFIRMATION_RESULTS.md"
B19 = "docs/research/BOSS19_P4_REGIME_ATTRIBUTION_RESULTS.md"
H02 = "docs/factory/BOSS11_16_H02_LITERAL_PORTABILITY_RESULTS.md"
MASTER = "EA_MASTER_INDEX.csv"
TASKBOARD = "AGENT_TASKBOARD.md"


class BuildError(RuntimeError):
    pass


def git(repo: Path, *args: str) -> bytes:
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True)
    if result.returncode:
        raise BuildError(result.stderr.decode("utf-8", "replace").strip() or "git command failed")
    return result.stdout


def resolve_ref(repo: Path, ref: str) -> str:
    return git(repo, "rev-parse", "--verify", f"{ref}^{{commit}}").decode().strip()


def source_bytes(repo: Path, sha: str, path: str) -> bytes:
    if not re.fullmatch(r"[0-9a-f]{40}", sha) or not is_safe_repo_path(path):
        raise BuildError("unsafe canonical source request")
    return git(repo, "show", f"{sha}:{path}")


def is_safe_repo_path(path: str) -> bool:
    pure = PurePosixPath(path)
    return not pure.is_absolute() and ".." not in pure.parts and "\\" not in path


def text_source(repo: Path, sha: str, path: str) -> tuple[str, dict]:
    raw = source_bytes(repo, sha, path)
    return raw.decode("utf-8"), {"path": path, "sha256": hashlib.sha256(raw).hexdigest(), "canonical_sha": sha}


def state(value: object = None) -> str:
    return "UNKNOWN" if value is None else str(value)


def metric(pf=None, dd=None, trades=None, cycles=None) -> dict:
    return {"pf": state(pf), "dd_pct": state(dd), "trades": state(trades), "cycles": state(cycles)}


def record(*, identity: str, family: str, variant: str, name: str, symbol: str, timeframe: str,
           lifecycle="UNRATIFIED", research_state="UNKNOWN", latest="UNKNOWN", verdict="UNKNOWN",
           strategy="UNKNOWN", evidence=None, status="UNKNOWN", links=None, provenance=None) -> dict:
    return {
        "id": identity, "family_id": family, "variant_id": variant, "display_name": name,
        "home": {"symbol": symbol, "timeframe": timeframe}, "lifecycle": lifecycle,
        "research_state": research_state, "latest_experiment": latest, "verdict": verdict,
        "quality_grade": "UNRATIFIED", "evidence_confidence": "UNKNOWN",
        "portfolio_value": "UNRATIFIED", "build_potential": "UNRATIFIED", "strategy": strategy,
        "evidence": evidence or {"basis_id": "UNKNOWN", "report_stage": "UNKNOWN", "model": "UNKNOWN",
                                  "holdout_state": "UNKNOWN", "main": metric(), "bwd": metric(),
                                  "key_findings": [], "known_weaknesses": []},
        "status": status, "links": links or {}, "provenance": provenance or []
    }


def extract_b16(text: str, provenance: dict) -> dict:
    main = re.search(r"\| MAIN \| 79 \|.*?\| (4\.0843 \(4\.08\)) \|.*?\((6\.27%)\)", text)
    bwd = re.search(r"\| BWD \| 148 \|.*?\| (1\.4412 \(1\.44\)) \|.*?\((8\.29%)\)", text)
    cycles = re.search(r"\| MAIN \| BUY only \| (42) / 79 .*?\|.*?\|\s*\n\| BWD \| BUY only \| (70) / 148", text)
    shares = re.search(r"multi-entry cycles contribute \*\*(79\.80%) MAIN\*\* and \*\*(87\.89%) BWD", text)
    if not all((main, bwd, cycles, shares)) or "POSITION_ENGINE_DEPENDENT_OR_UNKNOWN" not in text:
        raise BuildError("B16 H03 canonical report malformed or missing required evidence")
    evidence = {
        "basis_id": "B16_H03_FIXED_CONFIG_CONFIRMATION", "report_stage": "H03", "model": "MODEL_1",
        "holdout_state": "UNSPENT", "main": metric("4.08", "6.27%", "79", cycles.group(1)),
        "bwd": metric("1.44", "8.29%", "148", cycles.group(2)),
        "key_findings": [f"Multi-entry gross-profit share: MAIN {shares.group(1)}, BWD {shares.group(2)}.",
                         "H04 is NOT unlocked."],
        "known_weaknesses": ["Intratrade equity path, exit classification, ATR normalization, and emergency-close attribution are UNKNOWN."]
    }
    return record(identity="b16-h03-xauusd-h4", family="B16", variant="H03", name="Boss 16 KangarooGrid â€” XAUUSD H4",
                  symbol="XAUUSD", timeframe="H4", lifecycle="Research", research_state="DONE",
                  latest="B16 H03 confirmation", verdict="POSITION_ENGINE_DEPENDENT_OR_UNKNOWN",
                  strategy="KangarooGrid", evidence=evidence, status="DONE", links={"full_report": "artifacts/B16_H03_CONFIRMATION_RESULTS.md"}, provenance=[provenance])


def extract_boss19(text: str, provenance: dict) -> dict:
    legacy_needed = ("BLOCKED(DATA_ENVIRONMENT_MISSING_IMMUTABLE_HISTORICAL_MARKET_INPUTS)",
                     "no classifier timeline has been written", "HOLDOUT/optimization/runtime/risk/deploy = NONE")
    current_needed = ("BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)",
                      "1,549 opening `in` deals and 1,549 realized `out` deals",
                      "no source-emitted Position/opening-link field",
                      "Opening and closing Order IDs are disjoint",
                      "UNAVAILABLE_NO_SOURCE_BASKET_ID",
                      "HOLDOUT remains UNSPENT; optimization/runtime/risk/deployment authority remains NONE")
    interpreted_needed = ("Status: `INTERPRETED / RESEARCH_ONLY / MIXED_EVIDENCE`",
                          "HOLDOUT (`2026H1`) is UNSPENT",
                          "This document supersedes the prior `BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)`")
    if all(piece in text for piece in interpreted_needed):
        windows = re.search(r"\*\*By window:\*\* MAIN net .*?\(n=([0-9,]+), PF ([0-9.]+)\) vs BWD net .*?\(n=([0-9,]+), PF ([0-9.]+)\)", text)
        if not windows:
            raise BuildError("Boss19 P4 canonical interpretation missing window reconciliation")
        evidence = {"basis_id": "BOSS19_P4_REGIME_ATTRIBUTION_MODEL1", "report_stage": "P4", "model": "MODEL_1",
                    "holdout_state": "UNSPENT", "main": metric(windows.group(2), "UNKNOWN", windows.group(1).replace(",", ""), "UNKNOWN"),
                    "bwd": metric(windows.group(4), "UNKNOWN", windows.group(3).replace(",", ""), "UNKNOWN"),
                    "key_findings": ["Mixed regime evidence is materially time-confounded; no single-regime edge is established."],
                    "known_weaknesses": ["Regime labels, calendar years, symbols, and windows remain context-dependent; interpretation is research-only."]}
        return record(identity="boss19-regime-attribution", family="B19", variant="P4", name="Boss 19 Regime Attribution",
                      symbol="MULTI", timeframe="MULTI", lifecycle="Research", research_state="DONE",
                      latest="Boss19 P4 regime attribution interpretation", verdict="MIXED_EVIDENCE",
                      strategy="Regime attribution", evidence=evidence, status="DONE",
                      links={"full_report": "artifacts/BOSS19_P4_REGIME_ATTRIBUTION_RESULTS.md"}, provenance=[provenance])
    if all(piece in text for piece in current_needed):
        evidence = {"basis_id": "BOSS19_P4B_REGIME_ATTRIBUTION", "report_stage": "P4B", "model": "MODEL_1",
                    "holdout_state": "UNSPENT", "main": metric("UNAVAILABLE", "UNAVAILABLE", "UNAVAILABLE", "UNAVAILABLE"),
                    "bwd": metric("UNAVAILABLE", "UNAVAILABLE", "UNAVAILABLE", "UNAVAILABLE"),
                    "key_findings": ["Classifier timeline is frozen/reviewed; current H3 reports are unsuitable for source-bound unit attribution.",
                                     "36/36 reports reconcile 1,549 opening in and 1,549 realized out deals."],
                    "known_weaknesses": ["No source-emitted realized-deal/position-to-opening identity or basket ID; this is an evidence-shape blocker, not a strategy finding."]}
        item = record(identity="boss19-regime-attribution", family="B19", variant="P4B", name="Boss 19 Regime Attribution",
                      symbol="MULTI", timeframe="MULTI", lifecycle="Research", research_state="BLOCKED",
                      latest="Boss19 P4B unit-attribution suitability", verdict="BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)",
                      strategy="Regime attribution", evidence=evidence, status="BLOCKED",
                      links={"full_report": "artifacts/BOSS19_P4_REGIME_ATTRIBUTION_RESULTS.md"}, provenance=[provenance])
        item["blocker_type"] = "EVIDENCE"
        item["blocker_reason"] = "Current H3 reports cannot durably link realized deals to opening timestamps; this is an evidence-shape blocker, not strategy failure or a regime conclusion."
        item["next_action"] = "Hash-pin and independently review a source-bound timestamped H3 unit export with durable realized-deal/position-to-opening identity before P4B attribution."
        return item
    if all(piece in text for piece in legacy_needed):
        evidence = {"basis_id": "BOSS19_P4B_REGIME_ATTRIBUTION", "report_stage": "P4B", "model": "MODEL_1",
                    "holdout_state": "UNSPENT", "main": metric("UNAVAILABLE", "UNAVAILABLE", "UNAVAILABLE", "UNAVAILABLE"),
                    "bwd": metric("UNAVAILABLE", "UNAVAILABLE", "UNAVAILABLE", "UNAVAILABLE"),
                    "key_findings": ["BLOCKED(C DATA / environment prerequisite).", "No timeline or outcome attribution has been produced."],
                    "known_weaknesses": ["Exact tester-data-identity OHLC package is unavailable; this is not a strategy finding."]}
        item = record(identity="boss19-regime-attribution", family="B19", variant="P4B", name="Boss 19 Regime Attribution",
                      symbol="MULTI", timeframe="MULTI", lifecycle="Research", research_state="BLOCKED",
                      latest="Boss19 P4B regime attribution", verdict="BLOCKED(C DATA / environment prerequisite)",
                      strategy="Regime attribution", evidence=evidence, status="BLOCKED",
                      links={"full_report": "artifacts/BOSS19_P4_REGIME_ATTRIBUTION_RESULTS.md"}, provenance=[provenance])
        item["blocker_type"] = "ENVIRONMENT"
        item["blocker_reason"] = "Exact tester-data-identity closed OHLC remains unavailable; this is a data/environment blocker, not strategy failure."
        item["next_action"] = "Freeze the exact immutable OHLC prerequisite before any classifier timeline or outcome attribution."
        return item
    raise BuildError("Boss19 P4B canonical report malformed or missing blocker semantics")


def extract_h02(text: str, provenance: dict) -> list[dict]:
    rows = re.findall(r"\| B16 \| (XAUUSD H4|USDJPY H1) \| ([\d.]+) / (\d+) \| ([\d.]+) / (\d+) \| ([\d.]+%) \| ([\d.]+%) \|", text)
    if len(rows) != 2:
        raise BuildError("H02 canonical report malformed or required B16 compare pairs missing")
    result = []
    for home, mpf, mtrades, bpf, btrades, mdd, bdd in rows:
        symbol, timeframe = home.split()
        identity = f"b16-h02-{symbol.lower()}-{timeframe.lower()}"
        evidence = {"basis_id": "H02_LITERAL_PORTABILITY_MODEL1", "report_stage": "H02", "model": "MODEL_1",
                    "holdout_state": "UNSPENT", "main": metric(mpf, mdd, mtrades, "UNKNOWN"),
                    "bwd": metric(bpf, bdd, btrades, "UNKNOWN"),
                    "key_findings": ["Dual-window positive PF screening pulse."],
                    "known_weaknesses": ["Screening only; not a candidate or optimizer seed."]}
        result.append(record(identity=identity, family="B16", variant="H02", name=f"Boss 16 KangarooGrid â€” {home}",
                             symbol=symbol, timeframe=timeframe, lifecycle="Research", research_state="DONE",
                             latest="B16 H02 literal portability", verdict="NON_AUTHORITATIVE_SCREEN", strategy="KangarooGrid",
                             evidence=evidence, status="DONE", links={"full_report": "artifacts/BOSS11_16_H02_LITERAL_PORTABILITY_RESULTS.md"}, provenance=[provenance]))
    return result


def inventory_records(text: str, sha: str) -> list[dict]:
    try:
        rows = list(csv.DictReader(io.StringIO(text)))
    except csv.Error as error:
        raise BuildError(f"EA_MASTER_INDEX malformed: {error}") from error
    records = []
    for row in rows[:100]:
        name, home = row.get("name", ""), row.get("home_cell", "")
        if not name or not re.fullmatch(r"[A-Za-z0-9_ ().-]+", name):
            continue
        m = re.search(r"([A-Z]{3,6})\s+(M\d+|H\d+|D\d+)", home)
        symbol, timeframe = (m.group(1), m.group(2)) if m else ("UNKNOWN", "UNKNOWN")
        slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
        records.append(record(identity=f"inventory-{slug}", family="INVENTORY", variant="MASTER_INDEX", name=name,
                              symbol=symbol, timeframe=timeframe, lifecycle="UNRATIFIED", research_state="UNKNOWN",
                              status="INVENTORY_ONLY", provenance=[{"path": MASTER, "canonical_sha": sha}]))
    if not records:
        raise BuildError("EA_MASTER_INDEX contains no safe inventory records")
    return records


def selected_artifact(path: str, content: bytes, out: Path, redact_local_paths: bool = False) -> str:
    target = out / "artifacts" / Path(path).name
    target.parent.mkdir(parents=True, exist_ok=True)
    rendered = content
    if redact_local_paths:
        text = content.decode("utf-8")
        text = re.sub(r"`[A-Za-z]:\\[^`]+`", "`[LOCAL_PATH_REDACTED]`", text)
        rendered = text.encode("utf-8")
    target.write_bytes(rendered)
    return target.relative_to(out).as_posix()


def lane_registry(path: Path | None) -> list[dict]:
    if path is None:
        return []
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError, UnicodeError) as error:
        raise BuildError(f"lane registry unreadable: {error}") from error
    rows = payload.get("records", payload.get("lanes", payload)) if isinstance(payload, dict) else payload
    if not isinstance(rows, list):
        raise BuildError("lane registry must be a list or an Audit/List object containing records/lanes")
    result = []
    for item in rows:
        if not isinstance(item, dict):
            continue
        classification = item.get("classification")
        if not isinstance(classification, str):
            continue
        if classification not in _LANE_CURRENT_CLASSIFICATIONS:
            continue
        row = {"lane_id": safe_lane_id(item.get("lane_id", "UNKNOWN")),
               "classification": classification}
        state_value = item.get("state")
        row["state"] = state_value if isinstance(state_value, str) and state_value in _LANE_STATES else "UNKNOWN"
        blocker_value = item.get("blocker_class")
        row["blocker_class"] = blocker_value[:1] if isinstance(blocker_value, str) and blocker_value[:1] in {"A", "B", "C", "D", "E"} else ""
        if isinstance(item.get("attention_required"), bool):
            row["attention_required"] = item["attention_required"]
        result.append(row)
    return result


_LANE_CURRENT_CLASSIFICATIONS = {"ACTIVE_CURRENT", "ACTIVE_MISSING_WORKTREE", "ACTIVE_IDENTITY_MISMATCH", "ACTIVE_AGED", "QUEUED_CURRENT"}
_LANE_STATES = {"READY", "RUNNING", "WAITING", "PAUSED", "REVIEW", "FROZEN", "INTEGRATING", "DONE", "BLOCKED"}
_LANE_ID_SENSITIVE_RE = re.compile(r"(?i)(?:account|acct|login)[._:-]*[0-9]+|(?<![0-9])[0-9]{9,}(?![0-9])")
_SAFE_LANE_ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}")

def safe_lane_id(value: object) -> str:
    text = str(value or "UNKNOWN")
    if not _SAFE_LANE_ID_RE.fullmatch(text) or _LANE_ID_SENSITIVE_RE.search(text):
        return "REDACTED_LANE_" + hashlib.sha256(text.encode("utf-8")).hexdigest()[:8]
    return text

def lane_summary(item: dict) -> str:
    classification = str(item.get("classification", "UNKNOWN"))
    if classification not in _LANE_CURRENT_CLASSIFICATIONS:
        return "Noncanonical Lane Registry status unavailable."
    return f"Noncanonical Lane Registry status: {classification}."


_MONITOR_SOURCE_NAMES = {"live_evidence", "control_room_snapshot", "daily_monitor_success"}
_MONITOR_STATES = {"CURRENT", "STALE", "MISSING", "INVALID", "DATE_ONLY", "FUTURE"}
_MONITOR_COUNT_FIELDS = ("deal_sensors_total", "deal_sensors_fresh", "floating_sensors_total", "floating_sensors_fresh")
_UTC_SECOND_RE = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z")
_LOCAL_SECOND_RE = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")
_SAFE_SENSOR_STATES = {"FRESH", "STALE", "BLIND", "MISSING", "UNKNOWN", "CONFLICT"}
_SAFE_DD_BANDS = {"OK", "WATCH", "BREACH", "UNKNOWN"}
_SAFE_FINDING_SEVERITIES = {"INFO", "WARN", "CRITICAL", "REAL_MONEY"}


def _valid_utc_second(value: object) -> bool:
    if not isinstance(value, str) or not _UTC_SECOND_RE.fullmatch(value):
        return False
    try:
        datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        return False
    return True


def _valid_local_second(value: object) -> bool:
    if not isinstance(value, str) or not _LOCAL_SECOND_RE.fullmatch(value):
        return False
    try:
        datetime.strptime(value, "%Y-%m-%dT%H:%M:%S")
    except ValueError:
        return False
    return True


def unavailable_monitoring(reason: str = "NOT_PROVIDED") -> dict:
    return {"status": "UNAVAILABLE", "reported_status": "UNKNOWN",
            "source_kind": "LOCAL_MONITORING_NONCANONICAL",
            "authority": "READ_ONLY_NO_RUNTIME_AUTHORITY", "binding_state": "UNKNOWN",
            "generated_at_utc": "UNKNOWN", "alert_present": "UNKNOWN", "sources": [],
            "coverage": {"state": "UNAVAILABLE_STALE_OR_INVALID", "deal_sensors_total": "UNKNOWN",
                         "deal_sensors_fresh": "UNKNOWN", "floating_sensors_total": "UNKNOWN",
                         "floating_sensors_fresh": "UNKNOWN"}, "reason": reason}


def unavailable_safe_projection(reason: str = "NOT_PROVIDED") -> dict:
    return {"status": "MISSING" if reason == "NOT_PROVIDED" else "INVALID",
            "entity": "SafeProjection", "source_kind": "SAFE_PROJECTION_DERIVED",
            "authority": "READ_ONLY_NO_RUNTIME_AUTHORITY", "freshness": "UNKNOWN",
            "build_id": "UNKNOWN", "generated_at": "UNKNOWN", "accounts": [],
            "findings": [], "reason": reason}


def safe_projection(path: Path | None, as_of: str | None = None) -> dict:
    """Strictly pass through the existing SafeProjection allowlist; add no new meaning."""
    if path is None:
        return unavailable_safe_projection()
    try:
        raw = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError, UnicodeError):
        return unavailable_safe_projection("INVALID_INPUT")
    if not isinstance(raw, dict) or set(raw) != {"entity", "build_id", "generated_at", "accounts", "findings"}:
        return unavailable_safe_projection("INVALID_SCHEMA")
    if raw.get("entity") != "SafeProjection":
        return unavailable_safe_projection("INVALID_ENTITY")
    if not isinstance(raw.get("build_id"), str) or not re.fullmatch(r"[0-9a-f]{16}", raw["build_id"]):
        return unavailable_safe_projection("INVALID_BUILD_ID")
    if not (_valid_local_second(raw.get("generated_at")) or _valid_utc_second(raw.get("generated_at"))):
        return unavailable_safe_projection("INVALID_TIMESTAMP")
    if not isinstance(raw.get("accounts"), list) or not isinstance(raw.get("findings"), list):
        return unavailable_safe_projection("INVALID_SCHEMA")

    accounts = []
    for item in raw["accounts"]:
        if not isinstance(item, dict) or set(item) != {"account_masked", "sensor_state", "dd_pct_band"}:
            return unavailable_safe_projection("INVALID_ACCOUNT_ROW")
        if not isinstance(item.get("account_masked"), str) or not re.fullmatch(r"\*{3}[0-9]{3}", item["account_masked"]):
            return unavailable_safe_projection("INVALID_ACCOUNT_ROW")
        if item.get("sensor_state") not in _SAFE_SENSOR_STATES or item.get("dd_pct_band") not in _SAFE_DD_BANDS:
            return unavailable_safe_projection("INVALID_ACCOUNT_ROW")
        accounts.append({name: item[name] for name in ("account_masked", "sensor_state", "dd_pct_band")})

    findings = []
    for item in raw["findings"]:
        if not isinstance(item, dict) or set(item) != {"public_id", "severity", "state"}:
            return unavailable_safe_projection("INVALID_FINDING_ROW")
        if not isinstance(item.get("public_id"), str) or not re.fullmatch(r"FP-[0-9a-f]{10}", item["public_id"]):
            return unavailable_safe_projection("INVALID_FINDING_ROW")
        if item.get("severity") not in _SAFE_FINDING_SEVERITIES:
            return unavailable_safe_projection("INVALID_FINDING_ROW")
        if not isinstance(item.get("state"), str) or not re.fullmatch(r"[A-Z][A-Z0-9_]{0,31}", item["state"]):
            return unavailable_safe_projection("INVALID_FINDING_ROW")
        findings.append({name: item[name] for name in ("public_id", "severity", "state")})

    freshness = "UNKNOWN"
    if _valid_utc_second(raw["generated_at"]) and _valid_utc_second(as_of):
        age_seconds = (datetime.strptime(as_of, "%Y-%m-%dT%H:%M:%SZ") -
                       datetime.strptime(raw["generated_at"], "%Y-%m-%dT%H:%M:%SZ")).total_seconds()
        # Same 26-hour bar and 5-minute future tolerance as monitor health.
        freshness = "FUTURE" if age_seconds < -300 else "CURRENT" if age_seconds <= 26 * 3600 else "STALE"

    return {"status": "AVAILABLE", "entity": "SafeProjection",
            "source_kind": "SAFE_PROJECTION_DERIVED",
            "authority": "READ_ONLY_NO_RUNTIME_AUTHORITY",
            "freshness": freshness, "build_id": raw["build_id"],
            "generated_at": raw["generated_at"], "accounts": accounts,
            "findings": findings, "reason": "AVAILABLE"}


def _monitor_count(value: object) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) and value >= 0 else None


def monitor_health(path: Path | None, canonical_sha: str) -> dict:
    if path is None:
        return unavailable_monitoring()
    try:
        raw = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError, UnicodeError):
        return unavailable_monitoring("INVALID_INPUT")
    if not isinstance(raw, dict) or raw.get("schema_version") != "EA_LAB_MONITOR_HEALTH_V1":
        return unavailable_monitoring("INVALID_SCHEMA")
    if raw.get("source_kind") != "LOCAL_MONITORING_NONCANONICAL" or raw.get("authority") != "READ_ONLY_NO_RUNTIME_AUTHORITY":
        return unavailable_monitoring("INVALID_AUTHORITY")
    reported_status = str(raw.get("status", "UNAVAILABLE"))
    if reported_status not in {"CURRENT", "DEGRADED"}:
        return unavailable_monitoring("INVALID_STATUS")
    repo_head = str(raw.get("repo_head", "UNKNOWN"))
    binding = "MATCHES_CANONICAL_SHA" if repo_head == canonical_sha else ("DIFFERENT_REPO_HEAD" if re.fullmatch(r"[0-9a-f]{40}", repo_head) else "UNKNOWN")
    repo_head = repo_head if re.fullmatch(r"[0-9a-f]{40}", repo_head) else "UNKNOWN"
    revision = raw.get("snapshot_revision", {})
    snapshot_head = revision.get("git_head") if isinstance(revision, dict) else None
    snapshot_head = snapshot_head if isinstance(snapshot_head, str) and re.fullmatch(r"[0-9a-f]{40}", snapshot_head) else "UNKNOWN"
    snapshot_binding = ("UNKNOWN" if "UNKNOWN" in (repo_head, snapshot_head) else
                        "MATCHES_RUNTIME_HEAD" if snapshot_head == repo_head else "DIFFERENT_SNAPSHOT_HEAD")
    snapshot_qualified = snapshot_binding == "MATCHES_RUNTIME_HEAD"
    raw_sources = raw.get("sources")
    if not isinstance(raw_sources, list) or len(raw_sources) != len(_MONITOR_SOURCE_NAMES):
        return unavailable_monitoring("INVALID_SOURCE_SET")
    names = [item.get("name") for item in raw_sources if isinstance(item, dict)]
    if len(names) != len(raw_sources) or set(names) != _MONITOR_SOURCE_NAMES or len(set(names)) != len(names):
        return unavailable_monitoring("INVALID_SOURCE_SET")
    expected_basis = {"live_evidence":{"latest_filename_date_only", "latest_filename_date_upper_bound"},
                      "control_room_snapshot":"snapshot_meta_generated_at",
                      "daily_monitor_success":"success_marker_content"}
    sources = []
    for item in raw_sources:
        source_state = str(item.get("state", "INVALID"))
        basis = str(item.get("timestamp_basis", ""))
        expected = expected_basis[item["name"]]
        if source_state not in _MONITOR_STATES or basis not in ({expected} if isinstance(expected, str) else expected):
            return unavailable_monitoring("INVALID_SOURCE_ROW")
        raw_age = item.get("age_hours")
        raw_observed = item.get("observed_at_utc")
        if source_state in {"CURRENT", "STALE"}:
            if not isinstance(raw_age, (int, float)) or isinstance(raw_age, bool):
                return unavailable_monitoring("INVALID_SOURCE_ROW")
            numeric_age = float(raw_age)
            if not math.isfinite(numeric_age) or numeric_age < 0:
                return unavailable_monitoring("INVALID_SOURCE_ROW")
            if not _valid_utc_second(raw_observed):
                return unavailable_monitoring("INVALID_SOURCE_ROW")
            age = round(numeric_age, 2)
            observed = raw_observed
        elif source_state == "FUTURE":
            if raw_age is not None or (raw_observed is not None and not _valid_utc_second(raw_observed)):
                return unavailable_monitoring("INVALID_SOURCE_ROW")
            age = "UNKNOWN"
            observed = raw_observed if raw_observed is not None else "UNKNOWN"
        elif source_state in {"MISSING", "INVALID", "DATE_ONLY"}:
            if raw_age is not None or raw_observed is not None:
                return unavailable_monitoring("INVALID_SOURCE_ROW")
            age = "UNKNOWN"
            observed = "UNKNOWN"
        sources.append({"name": item["name"], "state": source_state, "age_hours": age,
                        "observed_at_utc": observed, "timestamp_basis": basis})
    sources = sorted(sources, key=lambda x: x["name"])
    source_by_name = {item["name"]: item for item in sources}
    all_sources_current = set(source_by_name) == _MONITOR_SOURCE_NAMES and all(item["state"] == "CURRENT" for item in sources)
    alert_present = raw.get("alert_present") if isinstance(raw.get("alert_present"), bool) else "UNKNOWN"
    generated_raw = raw.get("generated_at_utc", "UNKNOWN")
    generated_valid = _valid_utc_second(generated_raw)
    effective_status = "CURRENT" if (reported_status == "CURRENT" and all_sources_current and alert_present is False and
                                     binding == "MATCHES_CANONICAL_SHA" and generated_valid and snapshot_qualified) else "DEGRADED"
    coverage_raw = raw.get("coverage", {}) if isinstance(raw.get("coverage"), dict) else {}
    requested_coverage = str(coverage_raw.get("state", "UNAVAILABLE_STALE_OR_INVALID"))
    counts = {name: _monitor_count(coverage_raw.get(name)) for name in _MONITOR_COUNT_FIELDS}
    counts_valid = all(value is not None for value in counts.values())
    counts_consistent = counts_valid and counts["deal_sensors_fresh"] <= counts["deal_sensors_total"] and counts["floating_sensors_fresh"] <= counts["floating_sensors_total"]
    control_room_current = source_by_name.get("control_room_snapshot", {}).get("state") == "CURRENT"
    coverage_current = requested_coverage == "AVAILABLE_CURRENT_SNAPSHOT" and control_room_current and counts_consistent and snapshot_qualified
    coverage = {"state": "AVAILABLE_CURRENT_SNAPSHOT" if coverage_current else "UNAVAILABLE_STALE_OR_INVALID"}
    for name in _MONITOR_COUNT_FIELDS:
        coverage[name] = counts[name] if coverage_current else "UNKNOWN"
    generated = generated_raw if generated_valid else "UNKNOWN"
    return {"status": effective_status, "reported_status": reported_status,
            "repo_head": repo_head, "snapshot_revision": {"git_head": snapshot_head, "binding_state": snapshot_binding},
            "source_kind": "LOCAL_MONITORING_NONCANONICAL",
            "authority": "READ_ONLY_NO_RUNTIME_AUTHORITY", "binding_state": binding,
            "generated_at_utc": generated, "alert_present": alert_present,
            "sources": sources, "coverage": coverage, "reason": "AVAILABLE"}


def build(repo: Path, ref: str, out: Path, as_of: str, expected_sha: str | None, registry: Path | None,
          monitor: Path | None = None, projection: Path | None = None) -> dict:
    sha = resolve_ref(repo, ref)
    if expected_sha and sha != expected_sha:
        raise BuildError(f"expected SHA mismatch: expected {expected_sha}, resolved {sha}")
    if not _valid_utc_second(as_of):
        raise BuildError("as-of must be a valid UTC timestamp at whole-second precision")
    b16_text, b16_p = text_source(repo, sha, B16)
    b19_text, b19_p = text_source(repo, sha, B19)
    h02_text, h02_p = text_source(repo, sha, H02)
    master_text, master_p = text_source(repo, sha, MASTER)
    # The taskboard is evidence for status only; report parsing remains the specialized source of truth.
    taskboard_text, taskboard_p = text_source(repo, sha, TASKBOARD)
    if "B16-H03" not in taskboard_text or "BOSS19-P4-REGIME-ATTRIBUTION" not in taskboard_text:
        raise BuildError("canonical taskboard missing required B16/Boss19 queue evidence")
    out.mkdir(parents=True, exist_ok=True)
    selected_artifact(B16, b16_text.encode(), out)
    selected_artifact(B19, b19_text.encode(), out, redact_local_paths=True)
    selected_artifact(H02, h02_text.encode(), out)
    b16_item = extract_b16(b16_text, b16_p)
    boss19_item = extract_boss19(b19_text, b19_p)
    if boss19_item["verdict"] == "BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)" and "EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION" not in taskboard_text:
        raise BuildError("canonical Boss19 P4 report/taskboard blocker mismatch")
    boss19_queue_blocker = boss19_item.get("blocker_type", "NOT_APPLICABLE")
    boss19_queue_summary = boss19_item.get("blocker_reason", "Boss19 P4 regime attribution interpretation complete; research-only mixed evidence.")
    eas = inventory_records(master_text, sha) + extract_h02(h02_text, h02_p) + [b16_item, boss19_item]
    add_native_reports(repo, sha, out, eas)
    index = {"schema_version": SCHEMA_VERSION, "generator": {"name": GENERATOR_NAME, "version": GENERATOR_VERSION},
             "project": {"canonical_sha": sha, "canonical_short_sha": sha[:12], "source_ref": ref,
                         "generated_at": as_of, "data_status": "CURRENT", "freshness": "PINNED_GIT_REF"},
             "sources": [b16_p, b19_p, h02_p, master_p, taskboard_p], "eas": eas,
             "queue": [{"id": "FACTORY-B16-H03-CONFIRMATION", "state": "DONE", "blocker_type": "NOT_APPLICABLE",
                        "summary": "B16 H03 confirmation complete; H04 is not unlocked.", "source_kind": "GIT_CANONICAL"},
                       {"id": "BOSS19-P4-REGIME-ATTRIBUTION", "state": boss19_item["status"], "blocker_type": boss19_queue_blocker,
                        "summary": boss19_queue_summary, "source_kind": "GIT_CANONICAL"}] +
                      [{"id": safe_lane_id(item.get("lane_id", "UNKNOWN")),
                        "state": item.get("state", "UNKNOWN"),
                        "blocker_type": {"A": "PRODUCT_DEFECT", "B": "HARNESS", "C": "ENVIRONMENT", "D": "EXECUTION", "E": "OWNER_EXTERNAL"}.get(str(item.get("blocker_class", ""))[:1], "NOT_APPLICABLE"),
                        "summary": lane_summary(item), "source_kind": "LANE_REGISTRY_NONCANONICAL",
                        "registry_classification": item.get("classification", "UNKNOWN"),
                        "attention_required": item.get("attention_required", False)}
                       for item in lane_registry(registry)],
             "monitoring": monitor_health(monitor, sha),
             "safe_projection": safe_projection(projection, as_of),
             "compare": {"compatibility_rule": "DIRECT only when basis_id is identical; otherwise DIFFERENT_BASIS / N/A."}}
    project_text, project_source = text_source(repo, sha, "PROJECT_STATE.md")
    boards = [(taskboard_text, taskboard_p)]
    manifest = re.search(r"<!-- TASKBOARD-ACTIVE-PARTS\s*\n(.*?)-->", taskboard_text, re.S)
    if manifest:
        paths = [line.strip() for line in manifest[1].splitlines() if line.strip()]
        if not paths or len(paths) != len(set(paths)):
            raise BuildError("invalid taskboard manifest")
        for path in paths:
            if not re.fullmatch(r"taskboards/active/[A-Za-z0-9_-]+\.md", path):
                raise BuildError("unsafe taskboard manifest path")
            boards.append(text_source(repo, sha, path))
    index["sources"].extend([project_source] + [source for _, source in boards[1:]])
    index["control_tower"] = build_projection(project_text, project_source, boards, registry, as_of, safe_lane_id)
    (out / "report_index.json").write_text(json.dumps(index, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return index


def graph_state(state="MISSING", reason="NO_SOURCE_BINDING", **binding) -> dict:
    return {"state": state, "reason": reason, **binding}


def safe_package_path(value: str) -> str:
    # Restrict materialized names on Windows as well as POSIX. Never follow Git links.
    if not isinstance(value, str) or not value or "\\" in value:
        raise BuildError("unsafe package path")
    for part in value.split("/"):
        if (not re.fullmatch(r"[A-Za-z0-9_(). -]+", part) or part in {".", ".."}
                or part.endswith((" ", ".")) or part != part.strip()
                or re.match(r"^(CON|PRN|AUX|NUL|COM\d|LPT\d)(\.|$)", part, re.I)):
            raise BuildError("unsafe package path")
    return value


def regular_blob(repo: Path, sha: str, path: str) -> bytes:
    safe_package_path(path)
    entry = git(repo, "ls-tree", sha, "--", path).decode().strip()
    if not re.match(r"^100(?:644|755) blob [0-9a-f]{40}\t", entry):
        raise BuildError("missing or non-regular Git artifact")
    return source_bytes(repo, sha, path)


def project_native_graphs(repo: Path, sha: str, item: dict, package_root: str,
                          manifest: dict, manifest_hash: str, out: Path) -> dict:
    """Inspect exact Git bytes, then defer package validation to its existing authority.

    metadata.native_graphs binds ea_id/basis_id and each role's report, asset_ref,
    from/to. No positional/filename graph selection, and no checkout file reads.
    """
    result = {role: graph_state() for role in ("main", "bwd")}
    try:
        metadata = manifest["metadata"]["native_graphs"]
        if metadata["ea_id"] != item["id"] or metadata["basis_id"] != item["evidence"]["basis_id"]:
            raise BuildError("package identity mismatch")
        package_id = manifest["package_id"]
        if not re.fullmatch(r"[A-Za-z0-9_.-]{1,128}", package_id):
            raise BuildError("unsafe package identity")
        with tempfile.TemporaryDirectory(prefix="ea-native-") as temp:
            root = Path(temp)
            declared = {}
            for artifact in manifest["artifacts"]:
                path = safe_package_path(artifact["path"])
                if path == "_validated_manifest.json" or path.casefold() in declared:
                    raise BuildError("duplicate package artifact")
                declared[path.casefold()] = artifact
                raw = regular_blob(repo, sha, f"{package_root}/{path}" if package_root else path)
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            closures = {}
            reports = []
            assets = []
            for role in result:
                binding = metadata.get(role)
                if binding is None:
                    continue
                if binding["role"] != role.upper():
                    raise BuildError("window role mismatch")
                for field in ("from", "to"):
                    datetime.strptime(binding[field], "%Y.%m.%d")
                if binding["from"] >= binding["to"]:
                    raise BuildError("invalid window")
                report = safe_package_path(binding["report"])
                if report.casefold() not in declared:
                    raise BuildError("unbound report")
                reports.append(report.casefold())
                closure = native_assets.inspect_report(root / report)
                if binding["report_sha256"] != closure["report_sha256"]:
                    raise BuildError("report/window hash binding mismatch")
                closures[role] = closure
                selected = binding.get("asset_ref")
                if selected is not None:
                    selected = native_assets._normalize_ref(selected)
                    assets.append((PurePosixPath(report).parent / selected).as_posix().casefold())
                result[role] = graph_state("MISSING", "NATIVE_CLOSURE_INCOMPLETE",
                    role=role.upper(), window={"from": binding["from"], "to": binding["to"]},
                    report_sha256=closure["report_sha256"], package_sha256=manifest_hash,
                    package_id=package_id, canonical_sha=sha, ea_id=item["id"],
                    basis_id=item["evidence"]["basis_id"],
                    references=closure["image_references_found"], available_assets=closure["unique_local_images"])
            if len(reports) != len(set(reports)) or len(assets) != len(set(assets)):
                raise BuildError("MAIN/BWD cross-binding")
            manifest_path = root / "_validated_manifest.json"
            integrity.write_manifest(manifest, manifest_path)
            integrity.validate_manifest(manifest_path)
            for role, closure in closures.items():
                binding = metadata[role]
                if closure["status"] == "REFUSED":
                    result[role].update(state="REFUSED", reason="UNSAFE_NATIVE_CLOSURE")
                    continue
                if closure["status"] != "PASS":
                    continue
                selected = binding.get("asset_ref")
                matched = next((a for a in closure["assets"] if a["path"] == selected), None)
                if not matched:
                    result[role].update(state="REFUSED", reason="NO_EXPLICIT_GRAPH_SELECTION")
                    continue
                source = (PurePosixPath(binding["report"]).parent / selected).as_posix()
                declared_asset = declared.get(source.casefold())
                if not declared_asset or declared_asset["sha256"] != matched["sha256"]:
                    raise BuildError("graph outside validated package")
                # Full source identity and content digest in pathname, never a query cache key.
                namespace = hashlib.sha256((package_id + manifest_hash + item["id"]).encode()).hexdigest()[:32]
                ext = {"image/png": ".png", "image/gif": ".gif", "image/jpeg": ".jpg"}[matched["media_type"]]
                href = f"artifacts/native/{sha}/{namespace}/{role}/{matched['sha256']}{ext}"
                target = out / href
                current = out.absolute()
                for part in Path(href).parts:
                    current = current / part
                    if integrity._is_reparse_component(current):
                        raise BuildError("unsafe static output")
                if integrity._is_reparse_component(out) or any(integrity._is_reparse_component(p) for p in out.absolute().parents):
                    raise BuildError("unsafe static output root")
                raw = (root / source).read_bytes()
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.exists() and target.read_bytes() != raw:
                    raise BuildError("static content collision")
                if not target.exists():
                    with target.open("xb") as handle:
                        handle.write(raw)
                result[role].update(state="AVAILABLE", reason="VALIDATED_SOURCE_BOUND_NATIVE_ASSET",
                                    asset_ref=selected, asset_sha256=matched["sha256"],
                                    media_type=matched["media_type"], href=href)
        return result
    except (BuildError, ValueError, OSError, KeyError, TypeError, AttributeError):
        return {role: graph_state("REFUSED", "PACKAGE_OR_BINDING_INVALID") for role in result}


def parse_set(raw: bytes) -> dict:
    text = raw.decode("utf-16") if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else raw.decode("utf-8-sig")
    result = {}
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith(";"):
            continue
        key, value = line.split("=", 1)
        if key in result or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise BuildError("invalid set parameter")
        result[key] = value.split("||", 1)[0]
    return result


H08_ROOT = "factory/runs/b16_h08_20260831/usdjpy_buy_h1"


def b16_h08_record(repo: Path, sha: str, out: Path) -> dict | None:
    """Explicit legacy adapter: existing receipt hashes feed package authority unchanged."""
    receipt_path = f"{H08_ROOT}/final_artifacts.sha256"
    if not git(repo, "ls-tree", sha, "--", receipt_path).strip():
        return None  # Older canonical refs predate H08.
    raw_receipt = regular_blob(repo, sha, receipt_path)
    source = {"path": receipt_path, "sha256": hashlib.sha256(raw_receipt).hexdigest(), "canonical_sha": sha}
    item = record(identity="b16-h08-usdjpy-h1", family="B16", variant="H08", name="Boss 16 KangarooGrid — USDJPY H1 H08",
                  symbol="USDJPY", timeframe="H1", lifecycle="Research", provenance=[source])
    try:
        declared = []
        raw_files = {}
        for line in raw_receipt.decode("utf-8-sig").splitlines():
            digest, path = line.split("  ", 1)
            raw = regular_blob(repo, sha, path)
            if not re.fullmatch(r"[0-9a-f]{64}", digest) or hashlib.sha256(raw).hexdigest() != digest:
                raise BuildError("H08 receipt mismatch")
            raw_files[path] = raw
            declared.append({"path": path, "sha256": digest, "size_bytes": len(raw), "role": "canonical_evidence"})
        def read(name):
            return raw_files[f"{H08_ROOT}/{name}"]
        summary = json.loads(read("final_summary.json"))
        lock = json.loads(read("center_lock.json"))
        windows = list(csv.DictReader(io.StringIO(read("validation_manifest.csv").decode("utf-8-sig"))))
        metrics = list(csv.DictReader(io.StringIO(read("validation_cell_summary.csv").decode("utf-8-sig"))))
        receipts = [json.loads(line) for line in read("validation_run_receipts.jsonl").decode("utf-8-sig").splitlines()]
        if any(len(rows) != 2 or {r["window"] for r in rows} != {"MAIN", "BWD"} for rows in [windows, metrics, receipts]):
            raise BuildError("H08 window ambiguity")
        preset = "B16_USDJPY_BUY_H1_OPT01_CENTER_14_35.set"
        parent = "B16_USDJPY_BUY_H1_PARENT.set"
        if hashlib.sha256(read(preset)).hexdigest() != lock["fixed_set_sha256"] or hashlib.sha256(read(parent)).hexdigest() != lock["parent_set_sha256"]:
            raise BuildError("H08 set identity mismatch")
        params, parents = parse_set(read(preset)), parse_set(read(parent))
        graph_bindings = {"ea_id": item["id"], "basis_id": summary["hypothesis_revision"]}
        evidence = {"basis_id": summary["hypothesis_revision"], "report_stage": "H08", "model": "MODEL_1", "holdout_state": summary["holdout"], "key_findings": [], "known_weaknesses": summary["known_unknowns"]}
        for w in windows:
            role = w["window"]
            r = next(r for r in receipts if r["window"] == role)
            m = next(m for m in metrics if m["window"] == role)
            report = f"{H08_ROOT}/validation/{role}/report.htm"
            if (hashlib.sha256(raw_files[report]).hexdigest() != r["report_sha256"] or m["report_sha256"] != r["report_sha256"]
                    or r["set_sha256"] != lock["fixed_set_sha256"] or any(r[k] != w[k] for k in ("from", "to", "symbol", "tf", "report_name"))):
                raise BuildError("H08 report identity mismatch")
            ini = read(f"validation/{role}/tester.ini").decode("utf-8-sig")
            for expected in ("Model=1", "Optimization=0", "Symbol=USDJPY", "Period=H1", "Leverage=1:100", f"FromDate={w['from']}", f"ToDate={w['to']}"):
                if expected not in ini.splitlines():
                    raise BuildError("H08 tested setup mismatch")
            leverage = json.loads(read(f"validation/{role}/leverage_check.json"))
            if leverage["match"] is not True or leverage["actual_leverage"] != 100:
                raise BuildError("H08 leverage mismatch")
            graph_bindings[role.lower()] = {"role": role, "report": report, "report_sha256": r["report_sha256"], "from": w["from"], "to": w["to"]}
            evidence[role.lower()] = {"pf": m["pf"], "net": m["net"], "eqdd_pct": m["eqdd_pct"], "dd_pct": m["eqdd_pct"], "trades": m["trades"], "cycles": m["cycles"]}
        item.update(evidence=evidence, verdict=summary["adoption_decision"], research_state=summary["search_status"], status=summary["search_status"], latest_experiment=summary["hypothesis_revision"])
        manifest = {"manifest_version": integrity.MANIFEST_VERSION, "package_id": "B16-H08-r1", "direct_consumer": "Existing EA Detail", "authority": "READ_ONLY_PRESENTATION", "metadata": {"native_graphs": graph_bindings}, "artifacts": declared}
        item["native_graphs"] = project_native_graphs(repo, sha, item, "", manifest, source["sha256"], out)
        if any(g["state"] == "REFUSED" for g in item["native_graphs"].values()):
            raise BuildError("H08 package refused")
        item["package_status"] = "INTEGRITY_VALIDATED_REVIEW_UNKNOWN"
        item["tested_setup"] = {"set": preset, "set_sha256": lock["fixed_set_sha256"], "package_id": "B16-H08-r1", "leverage": "1:100", "lane": "MT5-lane3"}
        # Lane source is the frozen validation runner, not the optimizer or current Registry.
        if "'MT5-lane3'" not in read("run_h08_validation.ps1").decode("utf-8-sig"):
            item["tested_setup"].pop("lane")
        item["parameters"] = {"source_sha256": lock["fixed_set_sha256"], "parent_sha256": lock["parent_set_sha256"], "parent": parent,
            "changed": [{"name": k, "parent": parents.get(k, "ABSENT"), "value": v} for k, v in params.items() if parents.get(k) != v],
            "key": [{"name": k, "value": params[k]} for k in lock["selected"]],
            "all": [{"name": k, "value": v} for k, v in params.items()]}
        item["explanation"] = {"evidence": "Fixed MAIN reproduction: " + summary["fixed_main_reproduction"], "interpretation": summary["decision_reason"], "decision": summary["adoption_decision"]}
        report_path = "docs/research/B16_USDJPY_BUY_H1_OPT01_RESULTS.md"
        item["links"] = {"full_report": selected_artifact(report_path, raw_files[report_path], out, redact_local_paths=True)}
    except (BuildError, ValueError, OSError, KeyError, TypeError):
        item["native_graphs"] = {r: graph_state("REFUSED", "PACKAGE_OR_BINDING_INVALID") for r in ("main", "bwd")}
        item["package_status"] = "REFUSED"
    return item


def add_native_reports(repo: Path, sha: str, out: Path, eas: list[dict]) -> None:
    h08 = b16_h08_record(repo, sha, out)
    if h08:
        eas.append(h08)
    # Reuse manifests, never create a second persisted report catalog.
    paths = git(repo, "ls-tree", "-r", "--name-only", sha, "--", "factory/runs").decode().splitlines()
    matches = {}
    for path in paths:
        if not path.endswith("/report_package_manifest.json"):
            continue
        try:
            raw = regular_blob(repo, sha, path)
            manifest = json.loads(raw)
            binding = manifest.get("metadata", {}).get("native_graphs")
            if binding:
                matches.setdefault(binding["ea_id"], []).append((path, raw, manifest))
        except (BuildError, ValueError, KeyError, TypeError, AttributeError):
            continue  # No trusted EA identity; never attach by filename.
    for item in eas:
        packages = matches.get(item["id"], [])
        if len(packages) > 1 or (packages and "native_graphs" in item):
            item["native_graphs"] = {r: graph_state("REFUSED", "AMBIGUOUS_PACKAGE") for r in ("main", "bwd")}
        elif packages:
            path, raw, manifest = packages[0]
            item["native_graphs"] = project_native_graphs(repo, sha, item, str(PurePosixPath(path).parent), manifest, hashlib.sha256(raw).hexdigest(), out)
            item["package_status"] = "INTEGRITY_VALIDATED_REVIEW_UNKNOWN" if all(g["state"] != "REFUSED" for g in item["native_graphs"].values()) else "REFUSED"
        item.setdefault("native_graphs", {r: graph_state() for r in ("main", "bwd")})


def classify_current(index: dict, current_sha: str) -> str:
    return "CURRENT" if index.get("project", {}).get("canonical_sha") == current_sha else "STALE"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--ref", default="origin/master")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--as-of", default=datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"))
    parser.add_argument("--lane-registry", type=Path)
    parser.add_argument("--expected-sha")
    parser.add_argument("--monitor-health", type=Path)
    parser.add_argument("--safe-projection", type=Path)
    args = parser.parse_args()
    try:
        build(args.repo, args.ref, args.out, args.as_of, args.expected_sha, args.lane_registry,
              args.monitor_health, args.safe_projection)
    except BuildError as error:
        print(f"FAIL_CLOSED: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
