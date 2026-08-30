#!/usr/bin/env python3
"""Build the mobile-report static data index from immutable Git objects only."""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

SCHEMA_VERSION = 1
GENERATOR_NAME = "mobile_report_hub.build_index"
GENERATOR_VERSION = "1.0.0"
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
    return record(identity="b16-h03-xauusd-h4", family="B16", variant="H03", name="Boss 16 KangarooGrid — XAUUSD H4",
                  symbol="XAUUSD", timeframe="H4", lifecycle="Research", research_state="DONE",
                  latest="B16 H03 confirmation", verdict="POSITION_ENGINE_DEPENDENT_OR_UNKNOWN",
                  strategy="KangarooGrid", evidence=evidence, status="DONE", links={"full_report": "artifacts/B16_H03_CONFIRMATION_RESULTS.md"}, provenance=[provenance])


def extract_boss19(text: str, provenance: dict) -> dict:
    needed = ("BLOCKED(DATA_ENVIRONMENT_MISSING_IMMUTABLE_HISTORICAL_MARKET_INPUTS)",
              "no classifier timeline has been written", "HOLDOUT/optimization/runtime/risk/deploy = NONE")
    if not all(piece in text for piece in needed):
        raise BuildError("Boss19 P4B canonical report malformed or missing blocker semantics")
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
        result.append(record(identity=identity, family="B16", variant="H02", name=f"Boss 16 KangarooGrid — {home}",
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
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise BuildError(f"lane registry unreadable: {error}") from error
    rows = payload.get("lanes", payload) if isinstance(payload, dict) else payload
    if not isinstance(rows, list):
        raise BuildError("lane registry must be a list or {lanes: list}")
    allowed = ("lane_id", "state", "blocker_class", "objective", "direct_consumer")
    return [{key: str(item[key]) for key in allowed if key in item and isinstance(item[key], (str, int, float))}
            for item in rows if isinstance(item, dict)]


def lane_summary(item: dict) -> str:
    candidates = [item.get("objective"), item.get("direct_consumer")]
    for value in candidates:
        if value and not re.search(r"(?:^|[\s`\"'(])(?:[A-Za-z]:\\|\\\\)", str(value)):
            return str(value)
    return "[LOCAL_PATH_REDACTED]" if any(candidates) else "UNKNOWN"

def build(repo: Path, ref: str, out: Path, as_of: str, expected_sha: str | None, registry: Path | None) -> dict:
    sha = resolve_ref(repo, ref)
    if expected_sha and sha != expected_sha:
        raise BuildError(f"expected SHA mismatch: expected {expected_sha}, resolved {sha}")
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
    eas = inventory_records(master_text, sha) + extract_h02(h02_text, h02_p) + [extract_b16(b16_text, b16_p), extract_boss19(b19_text, b19_p)]
    index = {"schema_version": SCHEMA_VERSION, "generator": {"name": GENERATOR_NAME, "version": GENERATOR_VERSION},
             "project": {"canonical_sha": sha, "canonical_short_sha": sha[:12], "source_ref": ref,
                         "generated_at": as_of, "data_status": "CURRENT", "freshness": "PINNED_GIT_REF"},
             "sources": [b16_p, b19_p, h02_p, master_p, taskboard_p], "eas": eas,
             "queue": [{"id": "FACTORY-B16-H03-CONFIRMATION", "state": "DONE", "blocker_type": "NOT_APPLICABLE",
                        "summary": "B16 H03 confirmation complete; H04 is not unlocked.", "source_kind": "GIT_CANONICAL"},
                       {"id": "BOSS19-P4-REGIME-ATTRIBUTION", "state": "BLOCKED", "blocker_type": "ENVIRONMENT",
                        "summary": "Immutable tester-data-identity OHLC prerequisite remains missing; not strategy failure.", "source_kind": "GIT_CANONICAL"}] +
                      [{"id": item.get("lane_id", "UNKNOWN"),
                        "state": {"WAITING": "READY", "PAUSED": "READY", "REVIEW": "RUNNING", "FROZEN": "RUNNING", "INTEGRATING": "RUNNING"}.get(item.get("state", "UNKNOWN"), item.get("state", "UNKNOWN")),
                        "blocker_type": {"A": "PRODUCT_DEFECT", "B": "HARNESS", "C": "ENVIRONMENT", "D": "EXECUTION", "E": "OWNER_EXTERNAL"}.get(str(item.get("blocker_class", ""))[:1], "NOT_APPLICABLE"),
                        "summary": lane_summary(item), "source_kind": "LANE_REGISTRY_NONCANONICAL"}
                       for item in lane_registry(registry) if item.get("state") != "DONE"],
             "compare": {"compatibility_rule": "DIRECT only when basis_id is identical; otherwise DIFFERENT_BASIS / N/A."}}
    (out / "report_index.json").write_text(json.dumps(index, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return index


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
    args = parser.parse_args()
    try:
        build(args.repo, args.ref, args.out, args.as_of, args.expected_sha, args.lane_registry)
    except BuildError as error:
        print(f"FAIL_CLOSED: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
