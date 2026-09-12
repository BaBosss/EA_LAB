"""Build a searchable projection; Report V3 still owns every research fact.

Use build_catalog for Git input. project_index is the internal seam for the
existing builder's verified in-memory result, not an importer for arbitrary JSON.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.control_center.contracts import ResearchArtifactRef, ProjectionError, digest, safe_text, safe_path, utc
from tools.control_center.contracts.observations import hex_value
from tools.mobile_report_hub import build_index as reports

METRICS = {"pf", "dd_pct", "eqdd_pct", "net", "trades", "cycles"}
MODELS = {"MODEL_1", "MODEL_4"}


def text(value, default="UNKNOWN"):
    if value is None or value == "":
        return default
    return safe_text(value)


def metric_fields(value):
    if not isinstance(value, dict) or set(value) - METRICS:
        raise ProjectionError("METRIC_SCHEMA_MISMATCH")
    result = {}
    for key, number in value.items():
        if number == "UNKNOWN":
            result[key] = number
        elif type(number) in (float, int) and math.isfinite(number):
            result[key] = number
        elif isinstance(number, str) and re.fullmatch(r"-?\d+(?:\.\d+)?%?", number):
            result[key] = number  # Preserve exact representation and field names.
        else:
            raise ProjectionError("MALFORMED_METRIC")
    return result


def provenance(rows, sha):
    if not isinstance(rows, list):
        raise ProjectionError("PROVENANCE_SHAPE")
    result = []
    for row in rows:
        if not isinstance(row, dict) or set(row) != {"path", "sha256", "canonical_sha"} or row["canonical_sha"] != sha:
            raise ProjectionError("SOURCE_IDENTITY_MISMATCH")
        result.append(dict(path=safe_path(row["path"]), sha256=hex_value(row["sha256"], 64), canonical_sha=sha))
    return result


def graph_projection(graph, role, ea_id, basis, sha):
    if graph is None:
        return {"state": "MISSING", "reason": "NO_SOURCE_BINDING"}
    if not isinstance(graph, dict) or graph.get("state") not in {"AVAILABLE", "MISSING", "REFUSED"}:
        raise ProjectionError("GRAPH_SCHEMA_MISMATCH")
    if graph["state"] == "REFUSED":
        return {"state": "REFUSED", "reason": "EXISTING_REPORT_BINDING_REFUSED"}
    result = {"state": graph["state"], "reason": text(graph.get("reason"))}
    if "package_id" not in graph:
        if graph["state"] == "AVAILABLE":
            raise ProjectionError("UNBOUND_GRAPH")
        return result
    if (graph.get("role") != role.upper() or graph.get("ea_id") != ea_id
            or graph.get("basis_id") != basis or graph.get("canonical_sha") != sha):
        raise ProjectionError("GRAPH_IDENTITY_MISMATCH")
    result.update(role=role.upper(), ea_id=ea_id, basis_id=basis, canonical_sha=sha,
                  package_id=text(graph["package_id"]), package_sha256=hex_value(graph.get("package_sha256"), 64),
                  report_sha256=hex_value(graph.get("report_sha256"), 64))
    window = graph.get("window")
    if not isinstance(window, dict) or set(window) != {"from", "to"}:
        raise ProjectionError("WINDOW_SHAPE")
    for value in window.values():
        if not isinstance(value, str) or not re.fullmatch(r"\d{4}\.\d\d\.\d\d", value):
            raise ProjectionError("WINDOW_SHAPE")
        utc(value.replace(".", "-") + "T00:00:00Z")
    if window["from"] >= window["to"]:
        raise ProjectionError("WINDOW_ORDER")
    result["window"] = dict(window)
    if graph["state"] == "AVAILABLE":
        asset_hash = hex_value(graph.get("asset_sha256"), 64)
        href = safe_path(graph.get("href"))
        namespace = digest((result["package_id"] + result["package_sha256"] + ea_id).encode())[:32]
        media = graph.get("media_type")
        ext = {"image/png": "png", "image/jpeg": "jpg", "image/gif": "gif"}.get(media)
        if ext is None or href != f"artifacts/native/{sha}/{namespace}/{role}/{asset_hash}.{ext}":
            raise ProjectionError("GRAPH_NAMESPACE_MISMATCH")
        result.update(href=href, asset_sha256=asset_hash, media_type=media)
    return result


def parameter_projection(value):
    if value is None:
        return None
    if not isinstance(value, dict):
        raise ProjectionError("PARAMETER_SCHEMA_MISMATCH")
    result = {"source_sha256": hex_value(value.get("source_sha256"), 64),
              "parent_sha256": hex_value(value.get("parent_sha256"), 64)}
    for group in ("key", "changed", "all"):
        rows = value.get(group, [])
        if not isinstance(rows, list):
            raise ProjectionError("PARAMETER_SCHEMA_MISMATCH")
        result[group] = []
        for row in rows:
            fields = {"name", "parent", "value"} if group == "changed" else {"name", "value"}
            if not isinstance(row, dict) or set(row) != fields:
                raise ProjectionError("PARAMETER_SCHEMA_MISMATCH")
            result[group].append({key: text(val) for key, val in row.items()})
    return result


def project_record(item, sha):
    ea_id, basis = text(item["id"]), text(item["evidence"].get("basis_id"))
    setup, evidence = item.get("tested_setup", {}), item["evidence"]
    package_status = text(item.get("package_status"))
    sources = provenance(item.get("provenance", []), sha)
    model = text(evidence.get("model"))
    graphs = {role: graph_projection(item.get("native_graphs", {}).get(role), role, ea_id, basis, sha)
              for role in ("main", "bwd")}
    packages = {(g["package_id"], g["package_sha256"]) for g in graphs.values() if "package_id" in g}
    if len(packages) > 1:
        raise ProjectionError("CONFLICTING_PACKAGE")
    package_id = next(iter(packages))[0] if packages else text(setup.get("package_id"))
    if setup.get("package_id") and packages and setup["package_id"] != package_id:
        raise ProjectionError("WRONG_PACKAGE")
    missing = []
    bound = bool(sources) and basis != "UNKNOWN"
    for key, value in [("basis_id", basis), ("package_id", package_id), ("package_status", package_status),
                       ("installation_lineage", setup.get("lane", "UNKNOWN")),
                       ("source_build_id", setup.get("source_build_id", "UNKNOWN")),
                       ("config_sha256", setup.get("set_sha256", "UNKNOWN"))]:
        if value == "UNKNOWN": missing.append(key)
    if not sources: missing.append("source_provenance")
    if model not in MODELS: missing.append("research_qualified_tester_model")
    refused = package_status == "REFUSED" or any(g["state"] == "REFUSED" for g in graphs.values())
    performance = bound and model in MODELS and not refused
    windows = {}
    for role, graph in graphs.items():
        if graph["state"] != "AVAILABLE": missing.append(f"{role}_native_graph")
        if "window" not in graph: missing.append(f"{role}_date_window")
        windows[role] = {"role": role.upper(), "window": graph.get("window"), "graph": graph,
                         "metrics": metric_fields(evidence.get(role, {})) if performance else {},
                         "performance_status": "SOURCE_REPORTED" if performance else "WITHHELD_UNQUALIFIED_OR_REFUSED"}
    if setup.get("set_sha256"):
        config = hex_value(setup["set_sha256"], 64)
    else:
        config = None
    params = parameter_projection(item.get("parameters")) if not refused else None
    if params and params["source_sha256"] != config:
        raise ProjectionError("CONFIG_IDENTITY_MISMATCH")
    result = {"family_id": text(item.get("family_id")), "variant_id": text(item.get("variant_id")),
              "display_name": text(item.get("display_name")),
              "symbol": text(item["home"].get("symbol")), "timeframe": text(item["home"].get("timeframe")),
              "model": model, "installation_lineage": text(setup.get("lane")),
              "source_build_id": text(setup.get("source_build_id")), "config_sha256": config,
              "research_status": text(item.get("research_state")), "evidence_status": text(item.get("status")),
              "acceptance": "NOT_DERIVED_BY_SHELF", "windows": windows, "parameters": params,
              "provenance": sources, "quality": "REFUSED" if refused else "PARTIAL" if missing else "SOURCE_BOUND"}
    identity_hash = digest(json.dumps(result, sort_keys=True, separators=(",", ":")).encode())
    result["ref"] = ResearchArtifactRef("research_artifact_ref/1", ea_id, basis, sha, identity_hash,
                                         package_id, package_status, tuple(missing)).to_dict()
    return result


def project_index(index: dict, expected_sha: str) -> dict:
    hex_value(expected_sha, 40)
    if (not isinstance(index, dict) or index.get("schema_version") != 1
            or index.get("project", {}).get("canonical_sha") != expected_sha
            or not isinstance(index.get("eas"), list)):
        raise ProjectionError("INDEX_IDENTITY_OR_SCHEMA_MISMATCH")
    ids = [i.get("id") for i in index["eas"] if isinstance(i, dict) and isinstance(i.get("id"), str)]
    duplicates = {key for key, count in Counter(ids).items() if count > 1}
    records, refused = [], []
    source_lookup = {s["path"]: s for s in index.get("sources", [])
                     if isinstance(s, dict) and set(s) == {"path", "sha256", "canonical_sha"}
                     and s["canonical_sha"] == expected_sha}
    for ordinal, item in enumerate(index["eas"]):
        try:
            if not isinstance(item, dict) or item.get("id") in duplicates:
                raise ProjectionError("CONFLICTING_DUPLICATE_CLAIMANT")
            # Inventory records reference the index's hashed master source rather
            # than repeating its hash. Join on exact path AND SHA, never filename.
            item = dict(item)
            item["provenance"] = [source_lookup.get(p["path"], p)
                if isinstance(p, dict) and set(p) == {"path", "canonical_sha"}
                and p["canonical_sha"] == expected_sha else p for p in item.get("provenance", [])]
            records.append(project_record(item, expected_sha))
        except (ProjectionError, KeyError, TypeError, AttributeError, ValueError):
            # Never echo rejected identifiers, raw paths, parameters or exceptions.
            refused.append({"ordinal": ordinal, "state": "REFUSED", "reason": "RECORD_INVALID_OR_CONFLICTING"})
    return {"schema": "research_shelf/1", "canonical_sha": expected_sha,
            "authority": "READ_ONLY_PRESENTATION", "freshness": "HISTORICAL",
            "records": records, "refused": refused, "status": "PARTIAL" if refused else "SOURCE_PROJECTED"}


def select(catalog, *, ea_id, basis_id, canonical_sha, record_sha256):
    """Exact async selection token: a response for an old selection is refused."""
    matches = [r for r in catalog["records"] if all(r["ref"].get(k) == v for k, v in
               dict(ea_id=ea_id, basis_id=basis_id, canonical_sha=canonical_sha, record_sha256=record_sha256).items())]
    if len(matches) != 1 or catalog["canonical_sha"] != canonical_sha:
        raise ProjectionError("STALE_OR_AMBIGUOUS_SELECTION")
    return matches[0]


def comparison(left, right):
    """No numbers compared without complete, equal experimental lineage."""
    keys = ("installation_lineage", "source_build_id", "model", "symbol", "timeframe")
    if any(left[k] in (None, "UNKNOWN") or right[k] in (None, "UNKNOWN") for k in keys):
        return "UNKNOWN_LINEAGE"
    if any(left[k] != right[k] for k in keys) or left["ref"]["basis_id"] != right["ref"]["basis_id"]:
        return "INCOMPATIBLE_LINEAGE"
    if (left["ref"]["basis_id"] == "UNKNOWN" or not left["config_sha256"] or not right["config_sha256"]
            or left["model"] not in MODELS or any(left["windows"][r]["window"] is None for r in ("main", "bwd"))):
        return "UNKNOWN_LINEAGE"
    if any(left["windows"][r]["window"] != right["windows"][r]["window"] for r in ("main", "bwd")):
        return "INCOMPATIBLE_LINEAGE"
    return "SAME_RECORDED_LINEAGE_NO_VERDICT"


def build_catalog(repo: Path, sha: str, out: Path, as_of: str):
    hex_value(sha, 40)
    if out.exists():
        raise ProjectionError("OUTPUT_ALREADY_EXISTS")
    index = reports.build(repo, sha, out, as_of, sha, None)
    catalog = project_index(index, sha)
    (out / "research_shelf.json").write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")
    return catalog


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--as-of", required=True)
    args = parser.parse_args()
    try:
        catalog = build_catalog(args.repo, args.sha, args.out, args.as_of)
        print(json.dumps({"status": catalog["status"], "records": len(catalog["records"]), "refused": len(catalog["refused"])}))
        return 0
    except (ProjectionError, reports.BuildError, OSError, ValueError):
        print("RESEARCH_SHELF_BUILD_REFUSED", file=sys.stderr)
        return 1


if __name__ == "__main__": raise SystemExit(main())
