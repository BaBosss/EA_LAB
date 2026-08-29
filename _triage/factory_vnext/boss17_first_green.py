# -*- coding: utf-8 -*-
"""Build the deterministic, non-authoritative B17-H01 first-green package."""
from __future__ import annotations

import csv
import hashlib
import json
import sys
from pathlib import Path
from typing import Any, Iterable, Mapping

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    __package__ = "_triage.factory_vnext"

from _triage.factory_os import setfile

from .architecture import (
    make_component,
    make_master_mold,
    make_position_group,
    make_strategy_family,
    make_strategy_variant,
)
from .contracts import canonical_json, stable_id
from .mt5_set_compat import build_mt5_set_compat, render_proposed_set
from .parameter_surface import make_variant_parameter_surface
from .variant_generator import (
    make_variant_build_package,
    serialize_variant_build_package,
    validate_variant_build_package,
)


AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"
HYPOTHESIS_REVISION = "B17-H01-r1"
BUILD_TAG = "LAB_ENTRY_17"
SOURCE_COMMIT = "f27f992707aa8eb3c358a2e7c45e28e3d0078491"
PILOT_RELATIVE_PATH = "factory/vnext/pilots/boss17_h01_first_green"


class Boss17FirstGreenError(ValueError):
    pass


def _jsonl(path: Path) -> list[dict[str, Any]]:
    rows = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        row = json.loads(line)
        if not isinstance(row, dict):
            raise Boss17FirstGreenError("%s:%s is not an object" % (path, number))
        if "_comment" not in row:
            rows.append(row)
    return rows


def _registry_rows(path: Path) -> list[dict[str, str]]:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    try:
        header = next(index for index, line in enumerate(lines) if line.startswith('"name",'))
    except StopIteration as exc:
        raise Boss17FirstGreenError("PARAM_REGISTRY header not found") from exc
    return list(csv.DictReader(lines[header:]))


def _strip_scope(name: str) -> str:
    suffix = "[LAB_ENTRY_17]"
    if not name.endswith(suffix):
        return name
    # Registry names conventionally attach the terminal scope without a space;
    # tolerate one optional delimiter, but do not perform any other aliasing.
    base = name[:-len(suffix)]
    return base[:-1] if base.endswith(" ") else base


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _source_ref(root: Path, relative_path: str) -> dict[str, Any]:
    raw = (root / relative_path).read_bytes()
    return {"path": relative_path.replace("\\", "/"), "sha256": _sha256_bytes(raw), "bytes": len(raw)}


def _module_tokens(rows: Iterable[Mapping[str, Any]]) -> list[str]:
    return sorted({str(module["token"]) for row in rows for module in row["module_set"]})


def _selected_hypothesis(hypotheses: Iterable[Mapping[str, Any]]) -> dict[str, Any]:
    selected = [dict(row) for row in hypotheses if row.get("revision_id") == HYPOTHESIS_REVISION and row.get("boss_family") == 17]
    if len(selected) != 1:
        raise Boss17FirstGreenError("expected exactly one selected B17-H01 hypothesis")
    return selected[0]


def _architecture(hypotheses: list[dict[str, Any]]) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    selected = _selected_hypothesis(hypotheses)
    versions = {str(module["module_version"]) for module in selected["module_set"]}
    if len(versions) != 1:
        raise Boss17FirstGreenError("selected hypothesis must have one module_version")
    master = make_master_mold("EA_TEMPLATE_V2", versions.pop(), _module_tokens([row for row in hypotheses if row.get("boss_family") == 17]))
    family_hypotheses = [row for row in hypotheses if row.get("boss_family") == 17]
    if not family_hypotheses:
        raise Boss17FirstGreenError("Boss17 family has no hypotheses")
    family = make_strategy_family(master, "B17", "Boss17", _module_tokens(family_hypotheses))
    h01_tokens = sorted(str(module["token"]) for module in selected["module_set"])
    group = make_position_group("PG_MAIN", "MAIN")
    component = make_component(
        "CMP_B17_H01_COMPOSITION", "OTHER", "PG_MAIN", capabilities=h01_tokens, enabled=True,
    )
    variant = make_strategy_variant(family, "B17-H01-R1", HYPOTHESIS_REVISION, [group], [component])
    return master, family, variant


def _h01_bindings(rows: Iterable[Mapping[str, Any]]) -> list[dict[str, Any]]:
    selected = [dict(row) for row in rows if row.get("hypothesis_revision") == HYPOTHESIS_REVISION and row.get("build_tag") == BUILD_TAG]
    if len(selected) != 147:
        raise Boss17FirstGreenError("expected 147 B17-H01 bindings, got %s" % len(selected))
    return sorted(selected, key=lambda row: (row["parameter_pid"], row["parameter"]))


def _parameter_surface(
    variant: Mapping[str, Any], bindings: list[dict[str, Any]], metadata: Iterable[Mapping[str, Any]],
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    projection = [row for row in bindings if row.get("role") in ("TUNABLE", "LOCKED")]
    pids = [row["parameter_pid"] for row in projection]
    if len(projection) != 31 or len(pids) != len(set(pids)):
        raise Boss17FirstGreenError("expected 31 unique TUNABLE/LOCKED projection bindings")
    if any(row.get("role") == "TUNABLE" for row in projection):
        raise Boss17FirstGreenError("B17-H01 is frozen and must not expose TUNABLE projection rows")
    projection_pids = set(pids)
    displays = [dict(row) for row in metadata if row.get("parameter_pid") in projection_pids]
    # The accepted metadata row for P90001 carries an empty relation hint.  The
    # existing surface schema requires text, so represent that absence explicitly
    # without changing the selected row set or any binding semantics.
    for row in displays:
        if not row.get("relation_hint"):
            row["relation_hint"] = "none"
    return make_variant_parameter_surface(variant, projection, displays, HYPOTHESIS_REVISION, BUILD_TAG), projection


def _baseline_coverage(
    baseline_text: str, registry: Iterable[Mapping[str, str]], bindings: Iterable[Mapping[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    try:
        lines, _comments = setfile.parse_set(baseline_text)
    except setfile.Refusal as exc:
        raise Boss17FirstGreenError("baseline parse failed: %s" % exc) from exc
    if len(lines) != 159 or len({line.name for line in lines}) != len(lines):
        raise Boss17FirstGreenError("expected 159 unique physical baseline keys")
    registry_by_name: dict[str, list[dict[str, str]]] = {}
    for row in registry:
        try:
            pid = int(row["parameter_pid"])
        except (KeyError, TypeError, ValueError) as exc:
            raise Boss17FirstGreenError("registry row has invalid parameter_pid") from exc
        normalized = dict(row)
        normalized["parameter_pid"] = pid  # type: ignore[assignment]
        registry_by_name.setdefault(_strip_scope(row["name"]), []).append(normalized)
    binding_by_pid: dict[int, list[dict[str, Any]]] = {}
    for row in bindings:
        binding_by_pid.setdefault(row["parameter_pid"], []).append(dict(row))
    coverage: list[dict[str, Any]] = []
    baseline_pids: set[int] = set()
    for line in lines:
        candidates = registry_by_name.get(line.name, [])
        if len(candidates) > 1:
            candidates = [row for row in candidates if row["name"].endswith("[LAB_ENTRY_17]")]
        if len(candidates) != 1:
            raise Boss17FirstGreenError("registry mapping is not unique for baseline key %s" % line.name)
        pid = int(candidates[0]["parameter_pid"])
        if pid in baseline_pids:
            raise Boss17FirstGreenError("duplicate baseline PID %s" % pid)
        baseline_pids.add(pid)
        matches = binding_by_pid.get(pid, [])
        if len(matches) > 1:
            raise Boss17FirstGreenError("more than one H01 binding for PID %s" % pid)
        binding = matches[0] if matches else None
        if binding is not None and binding["parameter"] != line.name:
            raise Boss17FirstGreenError(
                "binding name does not match baseline key for PID %s" % pid
            )
        project = binding is not None and binding["role"] in ("TUNABLE", "LOCKED")
        coverage.append({
            "baseline_parameter": line.name,
            "parameter_pid": pid,
            "projection_parameter": binding["parameter"] if project else None,
            "disposition": "PROJECT" if project else "PRESERVE_SNAPSHOT",
        })
    if len(coverage) != 159 or len({row["baseline_parameter"] for row in coverage}) != 159:
        raise Boss17FirstGreenError("physical baseline coverage is incomplete")
    projected_not_in_baseline = [
        row for row in bindings
        if row["role"] in ("TUNABLE", "LOCKED") and row["parameter_pid"] not in baseline_pids
    ]
    return coverage, sorted(projected_not_in_baseline, key=lambda row: (row["parameter_pid"], row["parameter"]))


def _assert_locked_values(root: Path, baseline_text: str, bindings: Iterable[Mapping[str, Any]]) -> None:
    factory_os = root / "_triage/factory_os"
    if str(factory_os) not in sys.path:
        sys.path.insert(0, str(factory_os))
    import preset as factory_preset
    raw = factory_preset.parse_surface((root / "ea_template/core/Inputs.mqh").read_text(encoding="utf-8"), BUILD_TAG)
    declarations = {decl.name: decl for decl in raw.inputs}
    baseline = {line.name: line for line in setfile.parse_set(baseline_text)[0]}
    locked = [dict(row) for row in bindings if row.get("role") == "LOCKED"]
    if len(locked) != 31:
        raise Boss17FirstGreenError("expected exactly 31 frozen LOCKED bindings")
    mismatches = []
    for row in locked:
        name = row["parameter"]
        decl = declarations.get(name)
        line = baseline.get(name)
        if decl is None or line is None or row.get("locked_value") is None:
            mismatches.append(name + ":missing")
            continue
        rendered = factory_preset.render_value(decl, row["locked_value"], raw.enums)
        if line.value != rendered:
            mismatches.append("%s:%s!=%s" % (name, line.value, rendered))
    if mismatches:
        raise Boss17FirstGreenError("frozen LOCKED values differ from physical baseline: %s" % ", ".join(mismatches[:8]))


def build_boss17_first_green(repo_root: str) -> dict[str, Any]:
    """Build all B17-H01 package records in memory; no MT5/runtime path is touched."""
    root = Path(repo_root).resolve()
    hypotheses = _jsonl(root / "factory/hypotheses.jsonl")
    bindings = _h01_bindings(_jsonl(root / "factory/parameter_bindings.jsonl"))
    metadata = _jsonl(root / "factory/parameter_display_metadata.jsonl")
    master, family, variant = _architecture(hypotheses)
    surface, projection = _parameter_surface(variant, bindings, metadata)
    baseline_path = root / "ea_template/sets/Boss17_Wave5_XAU_990301_M2M3_full.set"
    baseline_text = baseline_path.read_bytes().decode("utf-8-sig")
    _assert_locked_values(root, baseline_text, bindings)
    coverage, missing = _baseline_coverage(baseline_text, _registry_rows(root / "docs/PARAM_REGISTRY.csv"), bindings)
    package = make_variant_build_package(
        master=master, family=family, variant=variant, parameter_surface=surface,
        source_commit=SOURCE_COMMIT, template_id="EA_TEMPLATE_V2", baseline_coverage=coverage,
    )
    validate_variant_build_package(package)
    compat = build_mt5_set_compat(package, baseline_text, semantic_states=None)
    if compat["refusal_rows"] or compat["proposed_set_text"] is None:
        raise Boss17FirstGreenError("MT5 compatibility must emit a zero-refusal proposed set")
    proposed = render_proposed_set(compat)
    if [line.name for line in setfile.parse_set(proposed)[0]] != [line.name for line in setfile.parse_set(baseline_text)[0]]:
        raise Boss17FirstGreenError("proposed set physical key order differs from baseline")
    return {
        "master_mold": master, "strategy_family": family, "strategy_variant": variant,
        "parameter_surface": surface, "baseline_coverage": coverage,
        "variant_build_package": package, "mt5_set_compat_manifest": compat["manifest"],
        "proposed_set": proposed, "all_binding_count": len(bindings),
        "projection_binding_count": len(projection), "physical_baseline_key_count": len(coverage),
        "projected_not_in_baseline": missing,
    }


def _acceptance_markdown(build: Mapping[str, Any]) -> str:
    missing = build["projected_not_in_baseline"]
    missing_text = ", ".join("P%s %s" % (row["parameter_pid"], row["parameter"]) for row in missing) or "none"
    return """# B17-H01 first-green Factory vNext package\n\n- Source commit: `%s`\n- Authority: `NON_AUTHORITATIVE_SIDECAR`\n- PackageID: `%s`\n- All H01 bindings: %s\n- Projection bindings: %s\n- Physical baseline keys: %s\n- Baseline coverage rows: %s\n- MT5 compatibility refusals: 0\n- Projected not in baseline: %s\n\nThis is an offline sidecar artifact only. It makes no MT5, optimization, tester, runtime, deployment, trading, LIVE, risk/default, promotion, or KINT-001 closure claim.\n""" % (
        SOURCE_COMMIT, build["variant_build_package"]["PackageID"], build["all_binding_count"],
        build["projection_binding_count"], build["physical_baseline_key_count"],
        len(build["baseline_coverage"]), missing_text,
    )


def write_boss17_first_green(repo_root: str, output_dir: str | None = None) -> dict[str, Any]:
    """Write the deterministic pilot package below the supplied repository root."""
    root = Path(repo_root).resolve()
    target = Path(output_dir).resolve() if output_dir else root / PILOT_RELATIVE_PATH
    build = build_boss17_first_green(str(root))
    files: dict[str, bytes] = {
        "master_mold.json": canonical_json(build["master_mold"]).encode("utf-8"),
        "strategy_family.json": canonical_json(build["strategy_family"]).encode("utf-8"),
        "strategy_variant.json": canonical_json(build["strategy_variant"]).encode("utf-8"),
        "parameter_surface.json": canonical_json(build["parameter_surface"]).encode("utf-8"),
        "baseline_coverage.json": canonical_json(build["baseline_coverage"]).encode("utf-8"),
        "variant_build_package.json": serialize_variant_build_package(build["variant_build_package"]),
        "mt5_set_compat_manifest.json": canonical_json(build["mt5_set_compat_manifest"]).encode("utf-8"),
        "proposed_B17_H01_r1.set": build["proposed_set"].encode("utf-8"),
        "ACCEPTANCE.md": _acceptance_markdown(build).encode("utf-8"),
    }
    target.mkdir(parents=True, exist_ok=True)
    for name, content in files.items():
        (target / name).write_bytes(content)
    sources = [
        "factory/hypotheses.jsonl", "factory/parameter_bindings.jsonl", "factory/parameter_display_metadata.jsonl",
        "docs/PARAM_REGISTRY.csv", "ea_template/sets/Boss17_Wave5_XAU_990301_M2M3_full.set",
        "_triage/factory_vnext/architecture.py", "_triage/factory_vnext/parameter_surface.py",
        "_triage/factory_vnext/variant_generator.py", "_triage/factory_vnext/mt5_set_compat.py",
        "_triage/factory_vnext/boss17_first_green.py",
    ]
    index = {
        "schema_version": "factory-vnext-boss17-first-green-artifact-index-v1",
        "authority": AUTHORITY,
        "source_commit": SOURCE_COMMIT,
        "PackageID": build["variant_build_package"]["PackageID"],
        "files": {name: {"sha256": _sha256_bytes(content), "bytes": len(content)} for name, content in sorted(files.items())},
        "source_refs": [_source_ref(root, source) for source in sources],
    }
    index["ArtifactIndexID"] = stable_id("B17IDX", index, hex_chars=24)
    (target / "artifact_index.json").write_bytes(canonical_json(index).encode("utf-8"))
    return build


if __name__ == "__main__":
    write_boss17_first_green(str(Path(__file__).resolve().parents[2]))
