#!/usr/bin/env python3
"""Build the Boss19 P4 broad36 execution precondition/provenance gate.

This tool verifies accepted-evidence prerequisites and publishes execution-cost
planning context. It does not compute a numeric ROI threshold, issue a strategy
verdict, or grant HOLDOUT, optimization, risk, deployment, trading, or LIVE authority.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import statistics
from datetime import datetime
from pathlib import Path
from typing import Any

SCHEMA = "BOSS19_P4_BROAD36_EXECUTION_GATE_V2"
PROCEED_ACTION = "PROCEED_BROAD36_SOURCE_BOUND_EXECUTION"
DIRECT_CONSUMER = "ORDER-RND-P4 source-bound broad36 execution before deterministic P4B attribution"
AUTHORITY = "RESEARCH_EXECUTION_PRECONDITION_ONLY_NO_STRATEGY_VERDICT_NO_HOLDOUT_NO_OPTIMIZATION_NO_RUNTIME_RISK_DEPLOYMENT_TRADING"


class Refusal(RuntimeError):
    pass


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig") as fh:
        value = json.load(fh)
    if not isinstance(value, dict):
        raise Refusal(f"JSON root must be an object: {path}")
    return value


def require(value: bool, message: str) -> None:
    if not value:
        raise Refusal(message)


def parse_dt(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def progress_stats(path: Path, incident_gap_seconds: float = 300.0) -> dict[str, Any]:
    rows = []
    with path.open("r", encoding="utf-8-sig") as fh:
        for line in fh:
            if line.strip():
                rows.append(json.loads(line))
    require(len(rows) == 36, f"H3 progress must contain 36 completions, got {len(rows)}")
    times = [parse_dt(str(row["recorded_at"])) for row in rows]
    intervals = [(times[i] - times[i - 1]).total_seconds() for i in range(1, len(times))]
    normal = [x for x in intervals if x <= incident_gap_seconds]
    incidents = [x for x in intervals if x > incident_gap_seconds]
    require(normal, "H3 progress has no usable non-incident completion intervals")
    return {
        "completion_count": len(rows),
        "completion_span_minutes": round((times[-1] - times[0]).total_seconds() / 60.0, 1),
        "normal_interval_count": len(normal),
        "incident_interval_count": len(incidents),
        "normal_median_seconds": round(statistics.median(normal), 1),
        "normal_mean_seconds": round(statistics.mean(normal), 1),
        "normal_max_seconds": round(max(normal), 1),
        "incident_gap_threshold_seconds": incident_gap_seconds,
        "incident_gap_threshold_role": "DESCRIPTIVE_HEURISTIC_ONLY_NOT_A_DECISION_OR_ACCEPTANCE_BAR",
        "heterogeneity_note": "Inter-completion intervals span heterogeneous H3 cells and are planning context, not homogeneous per-cell runtime samples",
    }


def validate_matrix(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    require(len(rows) == 36, f"H3 matrix must contain exactly 36 rows, got {len(rows)}")
    ids = [row.get("cell_id", "") for row in rows]
    require(len(set(ids)) == 36 and all(ids), "H3 matrix cell IDs must be 36 unique non-empty values")
    require(all(row.get("model") == "1" for row in rows), "H3 matrix model drift")
    require(all(row.get("holdout") == "NO" for row in rows), "H3 matrix HOLDOUT drift")
    require(all(row.get("optimization") == "NO" for row in rows), "H3 matrix optimization drift")
    require({row.get("window") for row in rows} == {"MAIN", "BWD"}, "H3 matrix window drift")
    require(len({row.get("symbol") for row in rows}) == 6, "H3 matrix symbol-count drift")
    require({row.get("tf") for row in rows} == {"M15", "H1", "H4"}, "H3 matrix TF drift")
    return {"row_count": len(rows), "unique_cell_count": len(set(ids))}


def projection_minutes(seconds_per_run: float, runs: int) -> int:
    return int(round(seconds_per_run * runs / 60.0))


def build_gate(
    repair03_path: Path,
    run_manifest_path: Path,
    suitability_path: Path,
    matrix_path: Path,
    progress_path: Path,
    base_sha: str,
) -> dict[str, Any]:
    repair = load_json(repair03_path)
    run = load_json(run_manifest_path)
    suitability = load_json(suitability_path)
    matrix = validate_matrix(matrix_path)
    hist = progress_stats(progress_path)

    require(repair.get("status") == "PASS", "Repair03 status is not PASS")
    require(repair.get("broad_rerun") == "LOCKED_PENDING_CONTROL_TOWER_ROI_GATE", "Repair03 broad-rerun state drift")
    require(repair.get("holdout") == "UNSPENT", "Repair03 HOLDOUT drift")
    require(repair.get("optimization") == "NONE", "Repair03 optimization drift")
    require(repair.get("mechanical_gate", {}).get("status") == "PASS", "Repair03 mechanical gate not PASS")
    require(repair.get("source_magic_gate", {}).get("status") == "PASS", "Repair03 source-magic gate not PASS")
    require(run.get("status") == "PASS_SOURCE_BOUND_UNIT_RUN", "Repair03 run manifest is not source-bound PASS")
    require(run.get("cell_id") == "H3-C03-MAIN", "Repair03 pilot cell drift")
    require(run.get("model") == 1, "Repair03 run model drift")
    require(run.get("holdout") == "UNSPENT", "Repair03 run HOLDOUT drift")
    require(run.get("optimization") == "NONE", "Repair03 run optimization drift")
    require(run.get("linkage_basis") == "EXACT_DEAL_POSITION_ID_ONE_IN_ONE_OUT", "Repair03 linkage drift")
    require(run.get("source_magic_provenance") == "PER_DEAL_HISTORY_DEAL_MAGIC", "Repair03 source-magic provenance drift")

    audit = suitability.get("report_audit", {})
    provenance = suitability.get("provenance", {})
    require(suitability.get("status") == "BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)", "H3 suitability status drift")
    require(suitability.get("blocker_reason") == "NO_DURABLE_REALIZED_DEAL_TO_OPENING_TIMESTAMP_LINKAGE_IN_H3_REPORT_BYTES", "H3 suitability blocker reason drift")
    require(audit.get("reports_verified") == 36, "H3 suitability no longer verifies 36 reports")
    require(audit.get("total_realized_out_deals") == 1549, "accepted H3 historical deal population drift")
    require(provenance.get("holdout") == "UNSPENT", "H3 suitability HOLDOUT drift")
    require(provenance.get("optimization") == "NONE", "H3 suitability optimization drift")
    require(provenance.get("timeline_rows") == 1242682, "frozen timeline row count drift")
    require(bool(provenance.get("timeline_sha256")), "frozen timeline hash missing")

    started = parse_dt(str(run["started_utc"]))
    completed = parse_dt(str(run["completed_utc"]))
    pilot_seconds = (completed - started).total_seconds()
    require(pilot_seconds > 0, "Repair03 pilot duration is not positive")

    broad_runs = 36
    pilot_projection = projection_minutes(pilot_seconds, broad_runs)
    historical_median_projection = projection_minutes(hist["normal_median_seconds"], broad_runs)
    historical_mean_projection = projection_minutes(hist["normal_mean_seconds"], broad_runs)
    runtime = {
        "broad_runs_assumed": broad_runs,
        "forecast_role": "INFORMATIONAL_PLANNING_ONLY_NOT_A_DECISION_CONDITION",
        "pilot_reuse": "NOT_ASSUMED_CONTRACT_DOES_NOT_AUTHORIZE_REUSE",
        "repair03_pilot_seconds": round(pilot_seconds, 1),
        "repair03_pilot_sample_count": 1,
        "historical_normal_interval_count": hist["normal_interval_count"],
        "historical_incident_interval_count": hist["incident_interval_count"],
        "planning_projection_minutes_rounded": {
            "single_pilot_rate": pilot_projection,
            "historical_interval_median_rate": historical_median_projection,
            "historical_interval_mean_rate": historical_mean_projection,
        },
        "planning_band_minutes_nonprobabilistic": [min(pilot_projection, historical_median_projection, historical_mean_projection), max(pilot_projection, historical_median_projection, historical_mean_projection)],
        "historical_completion_span_minutes": hist["completion_span_minutes"],
        "incident_gap_threshold_seconds": hist["incident_gap_threshold_seconds"],
        "incident_gap_threshold_role": hist["incident_gap_threshold_role"],
        "sample_heterogeneity": hist["heterogeneity_note"],
        "runtime_class": "LONG_PLANNING_CONTEXT_NONPROBABILISTIC",
        "bottleneck": "D:\\Meta 5 serial Model-1 acceptance-critical lineage",
        "parallel_safety": "SERIAL_ONLY_ON_ACCEPTANCE_CRITICAL_INSTALL",
        "faster_mode_benefit": "NONE_WITHOUT_CHANGING_FROZEN_EXECUTION_CONTRACT",
    }
    source_hashes = {
        "repair03_result_sha256": file_sha256(repair03_path),
        "repair03_run_manifest_sha256": file_sha256(run_manifest_path),
        "h3_unit_suitability_sha256": file_sha256(suitability_path),
        "h3_matrix_manifest_sha256": file_sha256(matrix_path),
        "h3_progress_sha256": file_sha256(progress_path),
    }

    return {
        "schema_version": SCHEMA,
        "status": "PASS",
        "execution_action": PROCEED_ACTION,
        "decision_basis": "ALL_PREREQUISITE_AND_PROVENANCE_CHECKS_PASS_RUNTIME_CONTEXT_IS_NOT_A_NUMERIC_GATE",
        "base_sha": base_sha,
        "direct_consumer": DIRECT_CONSUMER,
        "authority": AUTHORITY,
        "evidence": {
            "repair03_source_bound_pilot": "PASS",
            "existing_h3_unit_attribution_status": suitability["status"],
            "existing_h3_unit_attribution_blocker_reason": suitability["blocker_reason"],
            "fixed_matrix": matrix,
            "historical_h3_realized_deals": 1549,
            "historical_deal_count_role": "EVIDENCE_SCALE_ONLY_NOT_BROAD_ACCEPTANCE_TARGET",
            "timeline_rows": provenance["timeline_rows"],
            "timeline_sha256": provenance["timeline_sha256"],
            "timeline_rebuild_required": False,
            "holdout": "UNSPENT",
            "optimization": "NONE",
            "selection_surface": "NONE_FULL_FROZEN_36_CELL_MATRIX",
        },
        "runtime_forecast": runtime,
        "source_hashes": source_hashes,
        "interpretation": {
            "unique_output": "Source-bound realized DEAL evidence for the complete frozen 36-cell H3 matrix",
            "downstream_skip": "Avoids rerunning P4A market capture/classifier timeline and avoids speculative subset mining",
            "value": "Fresh source-bound execution addresses the accepted H3 report-byte linkage blocker before deterministic P4B regime attribution",
            "cost": "One serial Model-1 broad batch; runtime figures are planning context only and are not a proceed/reject threshold",
            "uncertainty": "One Repair03 pilot plus heterogeneous H3 inter-completion intervals do not form a probabilistic runtime estimate; the >300 s incident split is a descriptive heuristic only; broker swap economics may drift and must be disclosed",
        },
        "decision": {
            "action": PROCEED_ACTION,
            "execution_scope": "ALL_36_FROZEN_CELLS_SERIAL_MODEL1",
            "stop_rule": "STOP_ON_FIRST_FAIL_CLOSED_CELL_AND_PRESERVE_PARTIAL_EVIDENCE",
            "no_retry_rule": "NO_AUTOMATIC_RETRY_WITHOUT_CLASSIFYING_PRODUCT_HARNESS_ENVIRONMENT_FAILURE",
            "postcondition": "FREEZE_AND_INDEPENDENTLY_REVIEW_SOURCE_BOUND_PACKAGE_BEFORE_ANY_REGIME_JOIN",
            "does_not_unlock": ["HOLDOUT", "OPTIMIZATION", "CANDIDATE", "GRADE_KINT", "DEMO_LIVE", "RISK_DEFAULT", "DEPLOYMENT", "TRADING"],
        },
        "material_unknowns": [
            "Exact broad36 wall-clock is unknown until executed; rounded projections are planning estimates only, not confidence bounds",
            "The Repair03 rate is one sample and historical H3 intervals span heterogeneous cells, so neither is a homogeneous runtime population",
            "The >300-second incident split is a descriptive heuristic selected for planning and has no acceptance or decision authority",
            "Repair03 pilot reuse is not assumed because the frozen contract does not explicitly authorize reuse in the broad package",
            "Basket attribution remains unavailable without a prospectively source-emitted basket ID",
        ],
    }


def render_markdown(gate: dict[str, Any]) -> str:
    ev = gate["evidence"]
    rt = gate["runtime_forecast"]
    return "\n".join([
        "# Boss19 P4 Broad36 Execution Precondition / Provenance Gate",
        "",
        f"Status: **{gate['status']} / {gate['execution_action']} / RESEARCH_EXECUTION_PRECONDITION_ONLY**",
        "",
        "> This artifact does not compute a numeric ROI score. PROCEED is the deterministic action when all frozen prerequisite/provenance checks pass; runtime figures below are informational planning context only.",
        "",
        "## Evidence",
        f"- Repair03 source-bound one-cell gate: **{ev['repair03_source_bound_pilot']}**.",
        f"- Existing H3 unit-attribution evidence: `{ev['existing_h3_unit_attribution_status']}` because `{ev['existing_h3_unit_attribution_blocker_reason']}`; this is why a fresh source-bound rerun is needed.",
        f"- Frozen scope: {ev['fixed_matrix']['row_count']} Model-1 cells; HOLDOUT `{ev['holdout']}`; optimization `{ev['optimization']}`.",
        f"- Historical evidence scale: {ev['historical_h3_realized_deals']} realized deals; this is **not** a broad-rerun acceptance target.",
        f"- Frozen P4 timeline already exists: {ev['timeline_rows']:,} rows, SHA-256 `{ev['timeline_sha256']}`; rebuild is not required.",
        "- Full frozen matrix is the execution surface; no performance-selected subset is introduced.",
        "",
        "## Runtime / cost",
        f"- Role: `{rt['forecast_role']}`.",
        f"- Repair03 exact one-cell wall clock: {rt['repair03_pilot_seconds']:.1f} s from **n={rt['repair03_pilot_sample_count']}** sample.",
        f"- Rounded 36-run planning projections (single-pilot / historical-interval median / historical-interval mean): {rt['planning_projection_minutes_rounded']['single_pilot_rate']} / {rt['planning_projection_minutes_rounded']['historical_interval_median_rate']} / {rt['planning_projection_minutes_rounded']['historical_interval_mean_rate']} min.",
        f"- Historical normal intervals: n={rt['historical_normal_interval_count']}; cells are heterogeneous, so these are not homogeneous per-cell samples.",
        f"- Historical completion span was {rt['historical_completion_span_minutes']:.1f} min with {rt['historical_incident_interval_count']} interval(s) above the {rt['incident_gap_threshold_seconds']:.0f}s descriptive heuristic; the threshold is not a gate.",
        f"- Runtime class: `{rt['runtime_class']}`; bottleneck: `{rt['bottleneck']}`.",
        "",
        "## Interpretation",
        f"- UNIQUE OUTPUT: {gate['interpretation']['unique_output']}.",
        f"- DOWNSTREAM SKIP: {gate['interpretation']['downstream_skip']}.",
        f"- DIRECT CONSUMER: {gate['direct_consumer']}.",
        f"- Value: {gate['interpretation']['value']}.",
        f"- Cost: {gate['interpretation']['cost']}.",
        "",
        "## Decision",
        f"**{gate['decision']['action']}** for all 36 frozen cells, serial Model 1, with stop-on-first-refusal behavior. This action follows prerequisite/provenance PASS, not a numerical ROI threshold.",
        "This is a prerequisite/provenance execution action only. Runtime planning figures do not determine PASS and no numeric ROI threshold is asserted. It is not a Boss19 strategy verdict and does not authorize HOLDOUT, optimization, Candidate, Grade/KINT, DEMO/LIVE, risk/default, deployment, or trading.",
        "After execution, freeze and independently review the complete source-bound package before any regime join.",
        "",
        "## Material unknowns",
        *[f"- {item}" for item in gate["material_unknowns"]],
        "",
        "## Provenance hashes",
        *[f"- `{key}` = `{value}`" for key, value in gate["source_hashes"].items()],
        "",
    ])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repair03-result", type=Path, required=True)
    ap.add_argument("--repair03-run-manifest", type=Path, required=True)
    ap.add_argument("--h3-unit-suitability", type=Path, required=True)
    ap.add_argument("--h3-matrix", type=Path, required=True)
    ap.add_argument("--h3-progress", type=Path, required=True)
    ap.add_argument("--base-sha", required=True)
    ap.add_argument("--out-json", type=Path, required=True)
    ap.add_argument("--out-md", type=Path, required=True)
    args = ap.parse_args()
    try:
        gate = build_gate(args.repair03_result, args.repair03_run_manifest, args.h3_unit_suitability, args.h3_matrix, args.h3_progress, args.base_sha)
        args.out_json.parent.mkdir(parents=True, exist_ok=True)
        args.out_md.parent.mkdir(parents=True, exist_ok=True)
        args.out_json.write_text(json.dumps(gate, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        args.out_md.write_text(render_markdown(gate), encoding="utf-8")
        print(json.dumps({"status": "PASS", "decision": gate["execution_action"], "json": str(args.out_json), "markdown": str(args.out_md)}, sort_keys=True))
        return 0
    except (Refusal, OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "BLOCKED", "reason": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
