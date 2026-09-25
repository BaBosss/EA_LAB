from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import Counter
from datetime import datetime, time
from pathlib import Path
from typing import Any, Iterable

from tools.news_macro_lab import macrogate_native as native


FROZEN_CONTRACT_HEAD = "d6547994b5277a3fa940856f9132604e9c7c9cd4"
FROZEN_CAUSAL_TIMELINE_SHA = "44ed3c16451bf9d8e9066d1f552939c62d3c0bfcb1c9059613ad4150d963ed5f"
FROZEN_CAUSAL_MANIFEST_SHA = "436baeeb45d1aba7d5176473dbc462963e43d1b31937e3fcbdf16ad76771d3e1"
EXPECTED_CAUSAL_TIMELINE_SHA = FROZEN_CAUSAL_TIMELINE_SHA
EXPECTED_CAUSAL_MANIFEST_SHA = FROZEN_CAUSAL_MANIFEST_SHA
FROZEN_NATIVE_EXPORTER_SHA = "ec22220fb7995518fd71c694dca43008638bd8692386cba54283002c9a9163d1"
EXPECTED_NATIVE_EXPORTER_SHA = FROZEN_NATIVE_EXPORTER_SHA
EXPECTED_PREREG_SHA = "57594c5c21b5f7330490740d0a746afd86a6c39a54c1f54477ce2fea020b1042"
EXPECTED_WRAPPER_SHA = "e235105deac8c975093a920b34b84565d2d6e355fa64a7802b05dd6592c1d88f"
EXPECTED_PARENT_SET_SHA = "ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c"

FROZEN_SEEDS = (2026092501, 2026092502, 2026092503, 2026092504, 2026092505)
CANDIDATE_SHIFTS = tuple(range(-52, -7)) + tuple(range(8, 53))
EXPECTED_SEED_SHIFTS = {
    2026092501: 38,
    2026092502: -23,
    2026092503: -8,
    2026092504: -32,
    2026092505: 36,
}
WINDOWS = {
    "MAIN": ("2023-01-01T00:00:00Z", "2026-01-01T00:00:00Z"),
    "BWD": ("2020-01-01T00:00:00Z", "2023-01-01T00:00:00Z"),
}
WINDOW_ORDER = ("MAIN", "BWD")
EXPECTED_ROWS_PER_WINDOW = 1096
CLASSIFICATION = "SYNTHETIC_PLACEBO_ONLY"
DONOR_AVAILABILITY_SEMANTICS = "PROVENANCE_ONLY_NOT_CAUSAL_TRUTH"


class Refused(ValueError):
    pass


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def _assert_hash(path: Path, expected: str, label: str) -> None:
    if sha256_file(path) != expected:
        raise Refused(label + "_HASH_MISMATCH")


def _hash_order(seed: int, shift: int) -> str:
    return hashlib.sha256(f"{seed}:{shift}".encode("ascii")).hexdigest()


def select_seed_shifts(
    seeds: Iterable[int], candidates: Iterable[int], stratum_sizes: Iterable[int]
) -> dict[int, int]:
    seeds = tuple(seeds)
    candidates = tuple(candidates)
    sizes = tuple(stratum_sizes)
    if not seeds or any(type(seed) is not int for seed in seeds) or len(set(seeds)) != len(seeds):
        raise Refused("UNIQUE_INTEGER_SEEDS_REQUIRED")
    if (
        not candidates
        or any(type(shift) is not int or shift == 0 for shift in candidates)
        or len(set(candidates)) != len(candidates)
    ):
        raise Refused("UNIQUE_NONZERO_INTEGER_SHIFTS_REQUIRED")
    if not sizes or any(type(size) is not int or size <= 0 for size in sizes):
        raise Refused("POSITIVE_WEEKDAY_STRATUM_SIZES_REQUIRED")

    selected: dict[int, int] = {}
    used: set[int] = set()
    for seed in seeds:
        ordered = sorted(candidates, key=lambda shift: _hash_order(seed, shift))
        chosen = next(
            (
                shift
                for shift in ordered
                if shift not in used and all(shift % size != 0 for size in sizes)
            ),
            None,
        )
        if chosen is None:
            raise Refused("SEED_SHIFT_ASSIGNMENT_INFEASIBLE")
        selected[seed] = chosen
        used.add(chosen)
    return selected


def _load_prereg(path: Path) -> dict[str, Any]:
    _assert_hash(Path(path), EXPECTED_PREREG_SHA, "PREREG")
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise Refused("PREREG_INVALID_JSON") from exc
    if data.get("schema_version") != "ea_lab_macrogate_ab_prereg/1":
        raise Refused("PREREG_SCHEMA_MISMATCH")
    if data.get("frozen_contract_head") != FROZEN_CONTRACT_HEAD:
        raise Refused("PREREG_HEAD_MISMATCH")
    upstream = data.get("upstream", {})
    if (
        upstream.get("causal_timeline_sha256") != FROZEN_CAUSAL_TIMELINE_SHA
        or upstream.get("causal_manifest_sha256") != FROZEN_CAUSAL_MANIFEST_SHA
        or upstream.get("macrogate_native_sha256") != FROZEN_NATIVE_EXPORTER_SHA
    ):
        raise Refused("PREREG_UPSTREAM_BINDING_MISMATCH")
    parent = data.get("parent", {})
    if (
        parent.get("family") != "B15"
        or parent.get("ea") != "Boss_15_ST03"
        or parent.get("home_symbol") != "GBPUSD"
        or parent.get("home_timeframe") != "H4"
        or parent.get("wrapper_sha256") != EXPECTED_WRAPPER_SHA
        or parent.get("set_sha256") != EXPECTED_PARENT_SET_SHA
        or parent.get("fresh_ex5_sha256") != "NOT_YET_FROZEN"
        or parent.get("build_receipt") != "NOT_YET_FROZEN"
        or parent.get("tester_reservation") != "NOT_YET_FROZEN"
    ):
        raise Refused("PREREG_PARENT_BINDING_MISMATCH")
    placebo = data.get("placebo", {})
    if tuple(placebo.get("seeds", ())) != FROZEN_SEEDS:
        raise Refused("PREREG_SEEDS_MISMATCH")
    if tuple(placebo.get("candidate_shift_weeks", ())) != CANDIDATE_SHIFTS:
        raise Refused("PREREG_SHIFT_POOL_MISMATCH")
    recorded_map = {int(key): value for key, value in placebo.get("seed_shift_weeks", {}).items()}
    if recorded_map != EXPECTED_SEED_SHIFTS:
        raise Refused("PREREG_SEED_MAP_MISMATCH")
    for name, (start, end) in WINDOWS.items():
        item = data.get("windows", {}).get(name, {})
        if item.get("start_utc") != start or item.get("end_utc") != end:
            raise Refused("PREREG_WINDOW_MISMATCH")
    if (
        data.get("can_execute") is not False
        or data.get("performance") != "NOT_RUN"
        or data.get("holdout_used") is not False
        or data.get("probability") is not None
        or data.get("selection_performed") is not False
        or data.get("all_seeds_retained") is not True
    ):
        raise Refused("PREREG_AUTHORITY_EXPANDED")
    return data


def _load_source(timeline: Path, manifest: Path, repo: Path) -> list[dict[str, str]]:
    exporter = Path(repo) / "tools/news_macro_lab/macrogate_native.py"
    _assert_hash(exporter, EXPECTED_NATIVE_EXPORTER_SHA, "NATIVE_EXPORTER")
    _assert_hash(Path(timeline), EXPECTED_CAUSAL_TIMELINE_SHA, "CAUSAL_TIMELINE")
    _assert_hash(Path(manifest), EXPECTED_CAUSAL_MANIFEST_SHA, "CAUSAL_MANIFEST")
    try:
        rows, _ = native._load_causal(Path(timeline), Path(manifest))
    except native.Refused:
        raise
    if any(row["macro_state"] not in native.RECOGNIZED_STATES for row in rows):
        raise Refused("FROZEN_SOURCE_REQUIRES_RECOGNIZED_STATES")
    starts = [row["valid_from_utc"] for row in rows]
    if len(starts) != len(set(starts)):
        raise Refused("DUPLICATE_TARGET_INTERVAL")
    return rows


def _window_rows(rows: list[dict[str, str]], name: str) -> list[dict[str, str]]:
    start_text, end_text = WINDOWS[name]
    start, end = native.utc(start_text), native.utc(end_text)
    selected = [
        row
        for row in rows
        if start <= native.utc(row["valid_from_utc"]) < end
    ]
    if len(selected) != EXPECTED_ROWS_PER_WINDOW:
        raise Refused(f"{name}_ROW_COUNT_MISMATCH")
    if selected[0]["valid_from_utc"] != start_text or selected[-1]["valid_to_utc"] != end_text:
        raise Refused(f"{name}_COVERAGE_MISMATCH")
    for row in selected:
        row_start = native.utc(row["valid_from_utc"])
        row_end = native.utc(row["valid_to_utc"])
        if (row_end - row_start).total_seconds() != 86400:
            raise Refused(f"{name}_NON_DAILY_INTERVAL")
    return selected


def _render_native(
    provenance: list[dict[str, Any]], window: str, seed: int
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    rendered: list[dict[str, Any]] = []
    quarantine: list[dict[str, Any]] = []
    for row in provenance:
        start = native.utc(row["target_valid_from_utc"])
        state = row["donor_macro_state"]
        try:
            server, offset = native.utc_to_server(start)
        except native.Refused as exc:
            if str(exc) != "UTC_TO_SERVER_UNRESOLVED":
                raise
            transition_date = native._transition_server_date(start)
            marker = datetime.combine(transition_date, time.min)
            rendered_row = {
                "datetime": marker.strftime("%Y.%m.%d %H:%M"),
                "state": "UNKNOWN",
                "ri": row["donor_macro_ri"],
                "flags": row["donor_macro_flags"],
                "source_utc": row["target_valid_from_utc"],
                "source_state": state,
                "source_interval_index": row["target_index"],
                "offset_hours": None,
                "representation": "TRANSITION_UNKNOWN_BOUNDARY_MARKER",
            }
            rendered.append(rendered_row)
            quarantine.append({
                "source_interval_index": row["target_index"],
                "source_valid_from_utc": row["target_valid_from_utc"],
                "source_valid_to_utc": row["target_valid_to_utc"],
                "source_state": state,
                "transition_server_date": transition_date.isoformat(),
                "native_marker_datetime": rendered_row["datetime"],
                "native_marker_state": "UNKNOWN",
                "clock_rule": "UNKNOWN_DST_TRANSITION",
                "marker_semantics": "SERVER_DATE_BOUNDARY_NOT_SWITCH_INSTANT",
                "window": window,
                "seed": seed,
                "probability": None,
            })
        else:
            if native.server_to_utc(server) != start:
                raise Refused("CLOCK_ROUNDTRIP_MISMATCH")
            rendered.append({
                "datetime": server.strftime("%Y.%m.%d %H:%M"),
                "state": state,
                "ri": row["donor_macro_ri"],
                "flags": row["donor_macro_flags"],
                "source_utc": row["target_valid_from_utc"],
                "source_state": state,
                "source_interval_index": row["target_index"],
                "offset_hours": offset,
                "representation": "STABLE_MAPPED_ROW",
            })

    times = [datetime.strptime(row["datetime"], "%Y.%m.%d %H:%M") for row in rendered]
    if times != sorted(times) or len(times) != len(set(times)):
        raise Refused("NATIVE_TIMES_NOT_STRICTLY_ASCENDING_UNIQUE")
    if len(rendered) != EXPECTED_ROWS_PER_WINDOW:
        raise Refused("NATIVE_TARGET_COVERAGE_MISMATCH")
    native._complete_quarantine_evidence(rendered, quarantine)
    by_index = {row["source_interval_index"]: row for row in rendered}
    quarantine_by_index = {row["source_interval_index"]: row for row in quarantine}
    for row in provenance:
        native_row = by_index[row["target_index"]]
        row["target_native_datetime"] = native_row["datetime"]
        row["target_native_state"] = native_row["state"]
        row["target_representation"] = native_row["representation"]
        evidence = quarantine_by_index.get(row["target_index"])
        row["target_transition_server_date"] = (
            evidence["transition_server_date"] if evidence else ""
        )
        row["unknown_selected_until_resume"] = (
            evidence["unknown_selected_until_resume"] if evidence else False
        )
        row["resume_native_datetime"] = evidence["resume_native_datetime"] if evidence else ""
    return rendered, quarantine


def _build_cell(
    rows: list[dict[str, str]], window: str, seed: int, shift: int
) -> dict[str, Any]:
    strata: dict[int, list[tuple[int, dict[str, str], datetime]]] = {day: [] for day in range(7)}
    for index, row in enumerate(rows):
        start = native.utc(row["valid_from_utc"])
        strata[start.weekday()].append((index, row, start))

    provenance: list[dict[str, Any]] = []
    stratum_evidence: list[dict[str, Any]] = []
    for weekday in range(7):
        items = strata[weekday]
        size = len(items)
        if size == 0 or shift % size == 0:
            raise Refused("IDENTITY_WEEKDAY_STRATUM")
        displacement_counts: Counter[int] = Counter()
        wrap_count = 0
        for local_index, (target_index, target, target_start) in enumerate(items):
            raw_donor_index = local_index - shift
            donor_local_index = raw_donor_index % size
            wrapped = raw_donor_index < 0 or raw_donor_index >= size
            donor_index, donor, donor_start = items[donor_local_index]
            displacement_days = (donor_start - target_start).days
            if displacement_days % 7:
                raise Refused("WEEKDAY_DISPLACEMENT_NOT_WHOLE_WEEK")
            displacement_weeks = displacement_days // 7
            displacement_counts[displacement_weeks] += 1
            wrap_count += int(wrapped)
            provenance.append({
                "window": window,
                "seed": seed,
                "shift_weeks": shift,
                "classification": CLASSIFICATION,
                "causal_state_qualified": False,
                "donor_availability_semantics": DONOR_AVAILABILITY_SEMANTICS,
                "target_index": target_index,
                "target_weekday": weekday,
                "target_weekday_index": local_index,
                "target_valid_from_utc": target["valid_from_utc"],
                "target_valid_to_utc": target["valid_to_utc"],
                "donor_index": donor_index,
                "donor_weekday": donor_start.weekday(),
                "donor_weekday_index": donor_local_index,
                "donor_valid_from_utc": donor["valid_from_utc"],
                "donor_valid_to_utc": donor["valid_to_utc"],
                "donor_macro_state": donor["macro_state"],
                "donor_macro_as_of_utc": donor["macro_as_of_utc"],
                "donor_macro_source_date": donor["macro_source_date"],
                "donor_macro_ri": donor["macro_ri"],
                "donor_macro_confidence": donor["macro_confidence"],
                "donor_macro_coverage": donor["macro_coverage"],
                "donor_macro_missing_inputs": donor["macro_missing_inputs"],
                "donor_macro_partial": donor["macro_partial"],
                "donor_macro_flags": donor["macro_flags"],
                "wrapped_at_weekday_stratum_seam": wrapped,
                "displacement_days": displacement_days,
                "displacement_weeks": displacement_weeks,
                "weekday_mismatch": int(target_start.weekday() != donor_start.weekday()),
                "cross_window": int(
                    not (
                        native.utc(WINDOWS[window][0])
                        <= donor_start
                        < native.utc(WINDOWS[window][1])
                    )
                ),
                "holdout_contact": int(donor_start >= native.utc("2026-01-01T00:00:00Z")),
            })
        stratum_evidence.append({
            "utc_weekday": weekday,
            "row_count": size,
            "wrap_seam_target_count": wrap_count,
            "displacement_weeks_counts": {
                str(key): value for key, value in sorted(displacement_counts.items())
            },
        })

    provenance.sort(key=lambda row: row["target_index"])
    if len(provenance) != len(rows):
        raise Refused("TARGET_COVERAGE_MISMATCH")
    if len({row["target_index"] for row in provenance}) != len(rows):
        raise Refused("TARGET_NOT_UNIQUE")
    if len({row["donor_index"] for row in provenance}) != len(rows):
        raise Refused("DONOR_NOT_BIJECTIVE")
    if any(row["weekday_mismatch"] for row in provenance):
        raise Refused("DONOR_TARGET_WEEKDAY_MISMATCH")
    if any(row["cross_window"] or row["holdout_contact"] for row in provenance):
        raise Refused("DONOR_AUTHORITY_BOUNDARY_BREACH")

    source_counts = Counter(row["macro_state"] for row in rows)
    donor_counts = Counter(row["donor_macro_state"] for row in provenance)
    if donor_counts != source_counts:
        raise Refused("MARGINAL_DONOR_STATE_COUNTS_CHANGED")
    rendered, quarantine = _render_native(provenance, window, seed)
    return {
        "window": window,
        "seed": seed,
        "shift_weeks": shift,
        "target_row_count": len(provenance),
        "unique_target_count": len({row["target_index"] for row in provenance}),
        "unique_donor_count": len({row["donor_index"] for row in provenance}),
        "weekday_mismatch_count": 0,
        "cross_window_count": 0,
        "holdout_contact_count": 0,
        "marginal_donor_state_counts_preserved": True,
        "source_state_counts": dict(sorted(source_counts.items())),
        "donor_state_counts": dict(sorted(donor_counts.items())),
        "wrap_seam_target_count": sum(
            item["wrap_seam_target_count"] for item in stratum_evidence
        ),
        "weekday_strata": stratum_evidence,
        "uniform_calendar_shift_claimed": False,
        "exact_run_length_preservation_at_seams_claimed": False,
        "seam_disclosure": (
            "Circular wrap is applied independently inside each UTC-weekday stratum; "
            "wrapped rows have a different whole-week displacement, so no uniform calendar "
            "shift or exact run-length preservation is claimed at synthetic seams."
        ),
        "transition_quarantine_count": len(quarantine),
        "native_rows_strictly_ascending_unique": True,
        "native_rows": rendered,
        "quarantine_rows": quarantine,
        "provenance_rows": provenance,
    }


def build_placebo_package(
    timeline: Path, manifest: Path, prereg: Path, repo: Path
) -> dict[str, Any]:
    prereg_data = _load_prereg(Path(prereg))
    rows = _load_source(Path(timeline), Path(manifest), Path(repo))
    window_rows = {name: _window_rows(rows, name) for name in WINDOW_ORDER}
    stratum_sizes = sorted({
        sum(
            native.utc(row["valid_from_utc"]).weekday() == weekday
            for row in selected
        )
        for selected in window_rows.values()
        for weekday in range(7)
    })
    seed_shifts = select_seed_shifts(FROZEN_SEEDS, CANDIDATE_SHIFTS, stratum_sizes)
    if seed_shifts != EXPECTED_SEED_SHIFTS:
        raise Refused("FROZEN_SEED_MAP_MISMATCH")
    recorded = {
        int(key): value
        for key, value in prereg_data["placebo"]["seed_shift_weeks"].items()
    }
    if recorded != seed_shifts:
        raise Refused("PREREG_SEED_MAP_MISMATCH")

    window_summary = {}
    for name, selected in window_rows.items():
        window_summary[name] = {
            "start_utc": WINDOWS[name][0],
            "end_utc": WINDOWS[name][1],
            "source_row_count": len(selected),
            "source_state_counts": dict(
                sorted(Counter(row["macro_state"] for row in selected).items())
            ),
        }
    cells = [
        _build_cell(window_rows[name], name, seed, seed_shifts[seed])
        for name in WINDOW_ORDER
        for seed in FROZEN_SEEDS
    ]
    return {
        "schema_version": "ea_lab_macrogate_weekday_placebo_package/1",
        "classification": "MACROGATE_AB_PREREGISTRATION_TOOLING_ONLY",
        "frozen_contract_head": FROZEN_CONTRACT_HEAD,
        "source_timeline_sha256": sha256_file(Path(timeline)),
        "source_manifest_sha256": sha256_file(Path(manifest)),
        "native_exporter_sha256": EXPECTED_NATIVE_EXPORTER_SHA,
        "prereg_sha256": sha256_file(Path(prereg)),
        "windows": window_summary,
        "seed_shift_weeks": seed_shifts,
        "cells": cells,
        "all_seeds_retained": True,
        "selection_performed": False,
        "can_execute": False,
        "performance": "NOT_RUN",
        "holdout_used": False,
        "probability": None,
    }


PROVENANCE_FIELDS = (
    "window", "seed", "shift_weeks", "classification", "causal_state_qualified",
    "donor_availability_semantics", "target_index", "target_weekday",
    "target_weekday_index", "target_valid_from_utc", "target_valid_to_utc",
    "target_native_datetime", "target_native_state", "target_representation",
    "target_transition_server_date", "unknown_selected_until_resume",
    "resume_native_datetime", "donor_index", "donor_weekday", "donor_weekday_index",
    "donor_valid_from_utc", "donor_valid_to_utc", "donor_macro_state",
    "donor_macro_as_of_utc", "donor_macro_source_date", "donor_macro_ri",
    "donor_macro_confidence", "donor_macro_coverage", "donor_macro_missing_inputs",
    "donor_macro_partial", "donor_macro_flags", "wrapped_at_weekday_stratum_seam",
    "displacement_days", "displacement_weeks", "weekday_mismatch", "cross_window",
    "holdout_contact",
)


def write_artifacts(
    package: dict[str, Any], out_dir: Path, repo: Path, prereg: Path
) -> dict[str, Any]:
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=False)
    files: dict[str, str] = {}
    cell_manifests = []
    for cell in package["cells"]:
        stem = f"{cell['window']}_seed_{cell['seed']}"
        native_name = stem + "_macrogate_native.csv"
        provenance_name = stem + "_provenance.csv"
        native_path = out_dir / native_name
        provenance_path = out_dir / provenance_name
        with native_path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(
                handle, fieldnames=("datetime", "state", "ri", "flags"), lineterminator="\n"
            )
            writer.writeheader()
            writer.writerows(
                {key: row[key] for key in ("datetime", "state", "ri", "flags")}
                for row in cell["native_rows"]
            )
        with provenance_path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=PROVENANCE_FIELDS, lineterminator="\n")
            writer.writeheader()
            writer.writerows(
                {key: row[key] for key in PROVENANCE_FIELDS}
                for row in cell["provenance_rows"]
            )
        native_sha = sha256_file(native_path)
        provenance_sha = sha256_file(provenance_path)
        files[native_name] = native_sha
        files[provenance_name] = provenance_sha
        cell_manifests.append({
            key: value
            for key, value in cell.items()
            if key not in {"native_rows", "quarantine_rows", "provenance_rows"}
        } | {
            "native_csv": native_name,
            "native_csv_sha256": native_sha,
            "provenance_csv": provenance_name,
            "provenance_csv_sha256": provenance_sha,
        })

    repo = Path(repo)
    manifest_data = {
        key: value for key, value in package.items() if key != "cells"
    }
    manifest_data.update({
        "implementation": {
            "macro_placebo_path": "tools/news_macro_lab/macro_placebo.py",
            "macro_placebo_sha256": sha256_file(repo / "tools/news_macro_lab/macro_placebo.py"),
            "tests_path": "tools/news_macro_lab/tests/test_macro_placebo.py",
            "tests_sha256": sha256_file(repo / "tools/news_macro_lab/tests/test_macro_placebo.py"),
            "prereg_path": "tools/news_macro_lab/macrogate_ab_prereg_v1_20260925.json",
            "prereg_sha256": sha256_file(Path(prereg)),
            "expected_prereg_sha256": EXPECTED_PREREG_SHA,
            "native_exporter_path": "tools/news_macro_lab/macrogate_native.py",
            "native_exporter_sha256": EXPECTED_NATIVE_EXPORTER_SHA,
        },
        "cells": cell_manifests,
    })
    manifest_path = out_dir / "macrogate_ab_placebo_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest_data, sort_keys=True, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    manifest_sha = sha256_file(manifest_path)
    files[manifest_path.name] = manifest_sha
    return {
        "manifest": str(manifest_path),
        "manifest_sha256": manifest_sha,
        "files": dict(sorted(files.items())),
        "cell_count": len(cell_manifests),
        "can_execute": False,
        "performance": "NOT_RUN",
        "holdout_used": False,
        "probability": None,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeline", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--prereg", type=Path, required=True)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    package = build_placebo_package(args.timeline, args.manifest, args.prereg, args.repo)
    print(json.dumps(write_artifacts(package, args.out, args.repo, args.prereg), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
