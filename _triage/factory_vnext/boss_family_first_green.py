# -*- coding: utf-8 -*-
"""Deterministic fixed-config first-green Factory packages for Boss11/12/13/15/16."""
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
from .architecture import make_component, make_master_mold, make_position_group, make_strategy_family, make_strategy_variant
from .contracts import canonical_json, stable_id
from .mt5_set_compat import build_mt5_set_compat, render_proposed_set
from .parameter_surface import make_variant_parameter_surface
from .variant_generator import make_variant_build_package, serialize_variant_build_package, validate_variant_build_package

AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"
SOURCE_COMMIT = "38bfd8c137a9febac9c5d53abda4f1a027373511"

SPECS = {
    11: dict(short="GridTrend", build="LAB_ENTRY_11", baseline="ea_template/sets/regression/Boss_11_GridTrend_defaults.set", physical=151, bindings=139),
    12: dict(short="Breakout", build="LAB_ENTRY_12", baseline="ea_template/sets/regression/Boss_12_Breakout_defaults.set", physical=155, bindings=143),
    13: dict(short="MeanRev", build="LAB_ENTRY_13", baseline="ea_template/sets/regression/Boss_13_MeanRev_defaults.set", physical=157, bindings=145),
    15: dict(short="ST03", build="LAB_ENTRY_15", baseline="ea_template/sets/regression/Boss_15_ST03_defaults.set", physical=157, bindings=145),
    16: dict(short="Kangaroo", build="LAB_ENTRY_16", baseline="ea_template/sets/regression/Boss_16_KangarooGrid_defaults.set", physical=134, bindings=161),
}

class BossFamilyFirstGreenError(ValueError):
    pass

def revision_id(boss: int) -> str:
    return "B%d-H01-r1" % boss

def pilot_relative_path(boss: int) -> str:
    return "factory/vnext/pilots/boss%d_h01_first_green" % boss

def _jsonl(path: Path) -> list[dict[str, Any]]:
    rows=[]
    for n,line in enumerate(path.read_text(encoding="utf-8").splitlines(),1):
        if not line.strip(): continue
        row=json.loads(line)
        if not isinstance(row,dict): raise BossFamilyFirstGreenError("%s:%d is not an object"%(path,n))
        if "_comment" not in row: rows.append(row)
    return rows

def _registry_rows(path: Path) -> list[dict[str,str]]:
    lines=path.read_text(encoding="utf-8-sig").splitlines()
    try: header=next(i for i,line in enumerate(lines) if line.startswith('"name",'))
    except StopIteration as exc: raise BossFamilyFirstGreenError("PARAM_REGISTRY header not found") from exc
    return list(csv.DictReader(lines[header:]))

def _strip_scope(name: str, build_tag: str) -> str:
    suffix="[%s]"%build_tag
    if not name.endswith(suffix): return name
    base=name[:-len(suffix)]
    return base[:-1] if base.endswith(" ") else base

def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def _source_ref(root: Path, rel: str) -> dict[str,Any]:
    raw=(root/rel).read_bytes()
    return {"path":rel.replace("\\","/"),"sha256":_sha256_bytes(raw),"bytes":len(raw)}

def _selected_hypothesis(hyps: Iterable[Mapping[str,Any]], boss: int) -> dict[str,Any]:
    rid=revision_id(boss)
    selected=[dict(r) for r in hyps if r.get("revision_id")==rid and r.get("boss_family")==boss]
    if len(selected)!=1: raise BossFamilyFirstGreenError("expected exactly one %s hypothesis"%rid)
    return selected[0]

def _architecture(hyps: list[dict[str,Any]], boss: int):
    selected=_selected_hypothesis(hyps,boss)
    versions={str(m["module_version"]) for m in selected["module_set"]}
    if len(versions)!=1: raise BossFamilyFirstGreenError("selected hypothesis must have one module_version")
    tokens=sorted(str(m["token"]) for m in selected["module_set"])
    master=make_master_mold("EA_TEMPLATE_V2",versions.pop(),tokens)
    family=make_strategy_family(master,"B%d"%boss,"Boss%d"%boss,tokens)
    group=make_position_group("PG_MAIN","MAIN")
    component=make_component("CMP_B%d_H01_COMPOSITION"%boss,"OTHER","PG_MAIN",capabilities=tokens,enabled=True)
    variant=make_strategy_variant(family,"B%d-H01-R1"%boss,revision_id(boss),[group],[component])
    return master,family,variant

def _h01_bindings(rows: Iterable[Mapping[str,Any]], boss: int) -> list[dict[str,Any]]:
    spec=SPECS[boss]; rid=revision_id(boss)
    selected=[dict(r) for r in rows if r.get("hypothesis_revision")==rid and r.get("build_tag")==spec["build"]]
    if len(selected)!=spec["bindings"]: raise BossFamilyFirstGreenError("expected %d %s bindings, got %d"%(spec["bindings"],rid,len(selected)))
    if any(r.get("role")=="TUNABLE" for r in selected): raise BossFamilyFirstGreenError("%s is fixed-config and must expose zero TUNABLE rows"%rid)
    return sorted(selected,key=lambda r:(r["parameter_pid"],r["parameter"]))

def _parameter_surface(variant: Mapping[str,Any], bindings: list[dict[str,Any]], metadata: Iterable[Mapping[str,Any]], boss: int):
    spec=SPECS[boss]; rid=revision_id(boss)
    projection=[r for r in bindings if r.get("role") in ("TUNABLE","LOCKED")]
    if any(r.get("role")=="TUNABLE" for r in projection): raise BossFamilyFirstGreenError("%s must not expose TUNABLE projection rows"%rid)
    pids=[r["parameter_pid"] for r in projection]
    if len(pids)!=len(set(pids)): raise BossFamilyFirstGreenError("duplicate projection PID")
    displays=[dict(r) for r in metadata if r.get("parameter_pid") in set(pids)]
    for row in displays:
        if not row.get("relation_hint"): row["relation_hint"]="none"
    return make_variant_parameter_surface(variant,projection,displays,rid,spec["build"]),projection

def _baseline_coverage(baseline_text: str, registry_rows: Iterable[Mapping[str,str]], bindings: Iterable[Mapping[str,Any]], boss: int):
    spec=SPECS[boss]
    try: lines,_=setfile.parse_set(baseline_text)
    except setfile.Refusal as exc: raise BossFamilyFirstGreenError("baseline parse failed: %s"%exc) from exc
    if len(lines)!=spec["physical"] or len({x.name for x in lines})!=len(lines): raise BossFamilyFirstGreenError("expected %d unique physical baseline keys"%spec["physical"])
    reg_by={}
    for row in registry_rows:
        norm=dict(row)
        try: norm["parameter_pid"]=int(row["parameter_pid"])
        except Exception as exc: raise BossFamilyFirstGreenError("registry row has invalid parameter_pid") from exc
        reg_by.setdefault(_strip_scope(row["name"],spec["build"]),[]).append(norm)
    bind_by={}
    for row in bindings: bind_by.setdefault(row["parameter_pid"],[]).append(dict(row))
    coverage=[]; baseline_pids=set(); baseline_names=set()
    for line in lines:
        candidates=reg_by.get(line.name,[])
        if len(candidates)>1:
            candidates=[r for r in candidates if r["name"].endswith("[%s]"%spec["build"])]
        if len(candidates)!=1: raise BossFamilyFirstGreenError("registry mapping is not unique for baseline key %s"%line.name)
        pid=int(candidates[0]["parameter_pid"])
        if pid in baseline_pids: raise BossFamilyFirstGreenError("duplicate baseline PID %s"%pid)
        baseline_pids.add(pid); baseline_names.add(line.name)
        matches=bind_by.get(pid,[])
        if len(matches)>1: raise BossFamilyFirstGreenError("more than one H01 binding for PID %s"%pid)
        binding=matches[0] if matches else None
        if binding is not None and binding["parameter"]!=line.name: raise BossFamilyFirstGreenError("binding name mismatch for PID %s"%pid)
        project=binding is not None and binding["role"] in ("TUNABLE","LOCKED")
        coverage.append({"baseline_parameter":line.name,"parameter_pid":pid,"projection_parameter":binding["parameter"] if project else None,"disposition":"PROJECT" if project else "PRESERVE_SNAPSHOT"})
    # Explicitly cover locked projections absent from the older physical baseline. The compat
    # adapter then materializes those exact frozen values instead of relying on an implicit default.
    missing=[]
    for row in bindings:
        if row["role"] not in ("TUNABLE","LOCKED") or row["parameter_pid"] in baseline_pids: continue
        coverage.append({"baseline_parameter":row["parameter"],"parameter_pid":row["parameter_pid"],"projection_parameter":row["parameter"],"disposition":"PROJECT"})
        missing.append(dict(row))
    return coverage,sorted(missing,key=lambda r:(r["parameter_pid"],r["parameter"]))

def _assert_locked_values(root: Path, baseline_text: str, bindings: Iterable[Mapping[str,Any]], boss: int) -> None:
    factory_os=root/'_triage/factory_os'
    if str(factory_os) not in sys.path: sys.path.insert(0,str(factory_os))
    import preset as factory_preset
    spec=SPECS[boss]
    raw=factory_preset.parse_surface((root/'ea_template/core/Inputs.mqh').read_text(encoding='utf-8'),spec["build"])
    decls={d.name:d for d in raw.inputs}; baseline={x.name:x for x in setfile.parse_set(baseline_text)[0]}
    mismatches=[]
    for row in [dict(r) for r in bindings if r.get("role")=="LOCKED"]:
        name=row["parameter"]; decl=decls.get(name)
        if decl is None or row.get("locked_value") is None: mismatches.append(name+":missing"); continue
        rendered=factory_preset.render_value(decl,row["locked_value"],raw.enums)
        if name in baseline:
            if baseline[name].value!=rendered: mismatches.append("%s:%s!=%s"%(name,baseline[name].value,rendered))
        else:
            default=factory_preset.render_value(decl,decl.default_expr,raw.enums)
            if rendered!=default: mismatches.append("%s:missing baseline and locked %s != default %s"%(name,rendered,default))
    if mismatches: raise BossFamilyFirstGreenError("frozen LOCKED values differ from physical baseline/defaults: %s"%", ".join(mismatches[:8]))

def build_boss_first_green(repo_root: str, boss: int) -> dict[str,Any]:
    if boss not in SPECS: raise BossFamilyFirstGreenError("unsupported Boss family %s"%boss)
    root=Path(repo_root).resolve(); spec=SPECS[boss]
    hyps=_jsonl(root/'factory/hypotheses.jsonl'); bindings=_h01_bindings(_jsonl(root/'factory/parameter_bindings.jsonl'),boss)
    metadata=_jsonl(root/'factory/parameter_display_metadata.jsonl')
    master,family,variant=_architecture(hyps,boss)
    surface,projection=_parameter_surface(variant,bindings,metadata,boss)
    baseline_path=root/spec["baseline"]; baseline_text=baseline_path.read_bytes().decode('utf-8-sig')
    _assert_locked_values(root,baseline_text,bindings,boss)
    coverage,missing=_baseline_coverage(baseline_text,_registry_rows(root/'docs/PARAM_REGISTRY.csv'),bindings,boss)
    package=make_variant_build_package(master=master,family=family,variant=variant,parameter_surface=surface,source_commit=SOURCE_COMMIT,template_id='EA_TEMPLATE_V2',baseline_coverage=coverage)
    validate_variant_build_package(package)
    compat=build_mt5_set_compat(package,baseline_text,semantic_states=None)
    if compat["refusal_rows"] or compat["proposed_set_text"] is None: raise BossFamilyFirstGreenError("MT5 compatibility must emit a zero-refusal proposed set")
    proposed=render_proposed_set(compat)
    return {"master_mold":master,"strategy_family":family,"strategy_variant":variant,"parameter_surface":surface,"baseline_coverage":coverage,"variant_build_package":package,"mt5_set_compat_manifest":compat["manifest"],"proposed_set":proposed,"all_binding_count":len(bindings),"projection_binding_count":len(projection),"physical_baseline_key_count":spec["physical"],"projected_not_in_baseline":missing,"baseline_path":spec["baseline"]}

def _acceptance_markdown(build: Mapping[str,Any], boss: int) -> str:
    missing=build["projected_not_in_baseline"]
    return """# B%d-H01 first-green Factory vNext package\n\n- Source commit: `%s`\n- Authority: `%s`\n- PackageID: `%s`\n- All H01 bindings: %d\n- Projection bindings: %d (LOCKED only; TUNABLE=0)\n- Physical baseline keys: %d\n- BaselineCoverage rows: %d\n- MT5 compatibility refusals: 0\n- Frozen projections absent from original baseline and materialized by proposed set: %d\n\nThis package is a deterministic offline sidecar. It grants no optimizer, tester-result, HOLDOUT, candidate-selection, runtime, deployment, trading, DEMO/LIVE, risk/default, or promotion authority.\n"""%(boss,SOURCE_COMMIT,AUTHORITY,build["variant_build_package"]["PackageID"],build["all_binding_count"],build["projection_binding_count"],build["physical_baseline_key_count"],len(build["baseline_coverage"]),len(missing))

def write_boss_first_green(repo_root: str, boss: int, output_dir: str|None=None) -> dict[str,Any]:
    root=Path(repo_root).resolve(); build=build_boss_first_green(str(root),boss)
    target=Path(output_dir).resolve() if output_dir else root/pilot_relative_path(boss)
    files={"master_mold.json":canonical_json(build["master_mold"]).encode(),"strategy_family.json":canonical_json(build["strategy_family"]).encode(),"strategy_variant.json":canonical_json(build["strategy_variant"]).encode(),"parameter_surface.json":canonical_json(build["parameter_surface"]).encode(),"baseline_coverage.json":canonical_json(build["baseline_coverage"]).encode(),"variant_build_package.json":serialize_variant_build_package(build["variant_build_package"]),"mt5_set_compat_manifest.json":canonical_json(build["mt5_set_compat_manifest"]).encode(),"proposed_B%d_H01_r1.set"%boss:build["proposed_set"].encode(),"ACCEPTANCE.md":_acceptance_markdown(build,boss).encode()}
    target.mkdir(parents=True,exist_ok=True)
    for name,content in files.items(): (target/name).write_bytes(content)
    spec=SPECS[boss]
    sources=["factory/hypotheses.jsonl","factory/parameter_bindings.jsonl","factory/parameter_display_metadata.jsonl","docs/PARAM_REGISTRY.csv",spec["baseline"],"_triage/factory_vnext/architecture.py","_triage/factory_vnext/parameter_surface.py","_triage/factory_vnext/variant_generator.py","_triage/factory_vnext/mt5_set_compat.py","_triage/factory_vnext/boss_family_first_green.py"]
    index={"schema_version":"factory-vnext-boss%d-first-green-artifact-index-v1"%boss,"authority":AUTHORITY,"source_commit":SOURCE_COMMIT,"PackageID":build["variant_build_package"]["PackageID"],"files":{n:{"sha256":_sha256_bytes(c),"bytes":len(c)} for n,c in sorted(files.items())},"source_refs":[_source_ref(root,s) for s in sources]}
    index["ArtifactIndexID"]=stable_id("B%dIDX"%boss,index,hex_chars=24)
    (target/'artifact_index.json').write_bytes(canonical_json(index).encode())
    return build
