#!/usr/bin/env python3
"""Deterministic planning bridge from EA Research Workbook V1 to existing EA Template/Factory.

This tool emits planning/proposal artifacts only. It never writes .set files, starts MT5,
selects Home/TF, invents ranges, spends HOLDOUT, or turns owner draft bytes into authority.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path, PurePosixPath

PLAN_SCHEMA = "EA_LAB_WORKBOOK_PLAN_EXPORT_V1"
PROPOSAL_SCHEMA = "EA_LAB_EXECUTION_PROPOSAL_V1"
RESULT_SCHEMA = "EA_LAB_RESULT_BINDING_V1"
WORKBOOK_SCHEMA = "EA_LAB_RESEARCH_WORKBOOK_V1"
PARAM_CLASSES = {"LOCKED", "FIXED", "SEARCHABLE", "OWNER_REQUIRED", "UNKNOWN"}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
HEX40_RE = re.compile(r"^[0-9a-f]{40}$")
ALLOWED_TFS = {"M5", "M15", "M30", "H1", "H4", "D1"}

class BridgeRefusal(Exception):
    pass

def canonical_json(obj):
    return (json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")

def sha256_bytes(raw):
    return hashlib.sha256(raw).hexdigest()

def sha256_path(path):
    return sha256_bytes(Path(path).read_bytes())

def run_git(repo, *args, check=True):
    proc = subprocess.run(["git", "-C", str(repo), *args], capture_output=True)
    if check and proc.returncode:
        raise BridgeRefusal("git " + " ".join(args) + " failed: " + proc.stderr.decode("utf-8", "replace")[-500:])
    return proc

def verify_ref(repo, ref):
    if not HEX40_RE.fullmatch(ref):
        raise BridgeRefusal("ref must be lowercase 40-hex")
    actual = run_git(repo, "rev-parse", "--verify", ref + "^{commit}").stdout.decode().strip()
    if actual != ref:
        raise BridgeRefusal("ref does not resolve to itself")

def git_blob(repo, ref, rel):
    rel = PurePosixPath(rel).as_posix()
    if rel.startswith("/") or ".." in PurePosixPath(rel).parts:
        raise BridgeRefusal("unsafe repo path")
    typ = run_git(repo, "cat-file", "-t", f"{ref}:{rel}", check=False)
    if typ.returncode or typ.stdout.strip() != b"blob":
        raise BridgeRefusal(f"missing regular Git blob: {rel}")
    mode = run_git(repo, "ls-tree", ref, "--", rel).stdout.decode().split(None, 1)[0]
    if mode == "120000":
        raise BridgeRefusal(f"symlink Git path refused: {rel}")
    return run_git(repo, "show", f"{ref}:{rel}").stdout

def git_blob_or_none(repo, ref, rel):
    try:
        return git_blob(repo, ref, rel)
    except BridgeRefusal:
        return None

def load_json_blob(repo, ref, rel):
    try:
        return json.loads(git_blob(repo, ref, rel).decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise BridgeRefusal(f"invalid JSON blob {rel}: {exc}") from exc

def validate_workbook_payload_with_canonical_js(repo, ref, payload):
    if not isinstance(payload, (bytes, bytearray)):
        raise BridgeRefusal("Workbook payload must be immutable bytes")
    raw = bytes(payload)
    canonical = git_blob(repo, ref, "mobile_report_hub/research_workbook.js")
    validator = Path(repo) / "tools/research_workbook_bridge/validate_workbook.cjs"
    proc = subprocess.run(["node", str(validator), str(Path(repo).resolve()), ref],
                          cwd=repo, input=raw, capture_output=True)
    try:
        receipt = json.loads(proc.stdout.decode("utf-8").strip())
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise BridgeRefusal("Workbook validator did not emit JSON") from exc
    if proc.returncode != 0 or receipt.get("status") != "PASS":
        raise BridgeRefusal("Workbook planning schema validation failed: " + str(receipt.get("reason")))
    expected_payload_sha = sha256_bytes(raw)
    expected_validator_sha = sha256_bytes(canonical)
    if receipt.get("workbook_sha256") != expected_payload_sha:
        raise BridgeRefusal("Workbook validator payload digest mismatch")
    if receipt.get("validator_sha256") != expected_validator_sha or receipt.get("validator_ref") != ref:
        raise BridgeRefusal("Workbook validator exact-ref digest mismatch")
    return receipt

def parse_validated_workbook(payload, validation_receipt):
    if not isinstance(payload, (bytes, bytearray)):
        raise BridgeRefusal("Workbook payload must be immutable bytes")
    raw = bytes(payload)
    if validation_receipt.get("workbook_sha256") != sha256_bytes(raw):
        raise BridgeRefusal("Validated Workbook receipt does not bind these payload bytes")
    try:
        book = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise BridgeRefusal(f"cannot parse validated workbook payload: {exc}") from exc
    if not isinstance(book, dict) or book.get("schema_version") != WORKBOOK_SCHEMA:
        raise BridgeRefusal("unsupported workbook schema")
    doc = book.get("document") or {}
    if doc.get("status") != "OWNER_DRAFT_UNVERIFIED" or doc.get("authority") != "PLANNING_PRESENTATION_ONLY":
        raise BridgeRefusal("workbook must remain owner draft planning-only")
    windows = book.get("windows")
    if not isinstance(windows, list) or [w.get("role") for w in windows] != ["MAIN", "BWD", "HOLDOUT"]:
        raise BridgeRefusal("workbook windows must be MAIN/BWD/HOLDOUT")
    if windows[2].get("state") != "LOCKED_UNSPENT":
        raise BridgeRefusal("HOLDOUT must remain LOCKED_UNSPENT")
    return book

def parameter_class(row):
    raw = str(row.get("search_state") or "").strip().upper()
    return raw if raw in PARAM_CLASSES else "UNKNOWN"

def explicit_range(row):
    enums = [x.strip() for x in re.split(r"[,;|\n]", str(row.get("enum_values") or "")) if x.strip()]
    vals = [row.get("range_min"), row.get("range_step"), row.get("range_max")]
    numeric = all(v is not None and str(v).strip() != "" for v in vals)
    return {"enum_values": enums, "range_min": vals[0], "range_step": vals[1], "range_max": vals[2],
            "complete": bool(enums) or numeric}
def validate_factory_contract(repo, ref, pilot_dir, source_ref, source_sha):
    base = PurePosixPath(pilot_dir).as_posix().rstrip("/")
    package = load_json_blob(repo, ref, base + "/variant_build_package.json")
    surface = load_json_blob(repo, ref, base + "/parameter_surface.json")
    compat = load_json_blob(repo, ref, base + "/mt5_set_compat_manifest.json")
    index = load_json_blob(repo, ref, base + "/artifact_index.json")
    blockers = []
    facts = {}

    if package.get("authority") != "NON_AUTHORITATIVE_SIDECAR":
        blockers.append("FACTORY_PACKAGE_AUTHORITY_UNEXPECTED")
    if surface.get("authority") != "NON_AUTHORITATIVE_SIDECAR":
        blockers.append("PARAMETER_SURFACE_AUTHORITY_UNEXPECTED")
    if compat.get("authority") != "NON_AUTHORITATIVE_SIDECAR":
        blockers.append("SET_COMPAT_AUTHORITY_UNEXPECTED")
    if len({package.get("PackageID"), compat.get("PackageID"), index.get("PackageID")}) != 1:
        blockers.append("FACTORY_PACKAGE_ID_MISMATCH")

    surface_rows = surface.get("SurfaceRows") or []
    if surface.get("SurfaceRowCount") != len(surface_rows):
        blockers.append("PARAMETER_SURFACE_COUNT_MISMATCH")
    names = [r.get("parameter") for r in surface_rows]
    if len(names) != len(set(names)):
        blockers.append("PARAMETER_SURFACE_DUPLICATE_NAME")

    set_name = next((n for n in (index.get("files") or {}) if n.endswith(".set")), None)
    if not set_name:
        blockers.append("FACTORY_SET_ARTIFACT_MISSING")
        set_sha = None
    else:
        set_bytes = git_blob(repo, ref, base + "/" + set_name)
        set_sha = sha256_bytes(set_bytes)
        if set_sha != compat.get("proposed_output_sha256"):
            blockers.append("FACTORY_SET_HASH_MISMATCH")
        if set_sha != (index.get("files", {}).get(set_name) or {}).get("sha256"):
            blockers.append("FACTORY_ARTIFACT_INDEX_SET_HASH_MISMATCH")

    package_source_commit = package.get("source_commit")
    if not isinstance(package_source_commit, str) or not HEX40_RE.fullmatch(package_source_commit):
        blockers.append("FACTORY_PACKAGE_SOURCE_COMMIT_INVALID")
        package_source_sha = None
    else:
        old_blob = git_blob_or_none(repo, package_source_commit, source_ref) if source_ref else None
        package_source_sha = sha256_bytes(old_blob) if old_blob is not None else None
        if source_sha and package_source_sha and source_sha != package_source_sha:
            blockers.append("FACTORY_PACKAGE_SOURCE_DRIFT")

    inputs = git_blob(repo, ref, "ea_template/core/Inputs.mqh").decode("utf-8-sig")
    build_tag = package.get("build_tag")
    if not isinstance(build_tag, str) or f"#ifndef {build_tag}" not in inputs:
        blockers.append("FACTORY_BUILD_TAG_NOT_IN_CURRENT_INPUTS")

    facts.update({
        "pilot_dir": base,
        "package_id": package.get("PackageID"),
        "family_id": package.get("FamilyID"),
        "variant_id": package.get("VariantID"),
        "template_id": package.get("TemplateID"),
        "master_mold_id": package.get("MasterMoldID"),
        "build_tag": build_tag,
        "factory_source_commit": package_source_commit,
        "factory_source_sha256": package_source_sha,
        "parameter_surface_id": surface.get("SurfaceID"),
        "parameter_surface_rows": len(surface_rows),
        "factory_set_ref": base + "/" + set_name if set_name else None,
        "factory_set_sha256": set_sha,
        "factory_authority": package.get("authority"),
    })
    return package, surface_rows, compat, facts, blockers

def build_plan_export(book, ref):
    identity = book.get("identity") or {}
    params = []
    unresolved = []
    for idx, row in enumerate(book.get("parameters") or []):
        if not isinstance(row, dict):
            raise BridgeRefusal(f"parameter row {idx + 1} is not an object")
        name = row.get("name")
        if not isinstance(name, str) or not name.strip():
            raise BridgeRefusal(f"parameter row {idx + 1} has no name")
        cls = parameter_class(row)
        rng = explicit_range(row)
        if cls in {"OWNER_REQUIRED", "UNKNOWN"}:
            unresolved.append({"kind": "PARAMETER", "name": name, "state": cls})
        params.append({
            "name": name,
            "type": row.get("type"),
            "classification": cls,
            "source_default": row.get("source_default"),
            "proposed_baseline": row.get("proposed_baseline"),
            "range_proposal": rng,
            "active_when": row.get("active_when"),
            "dependencies": row.get("dependencies"),
            "stage": row.get("stage"),
            "rationale": row.get("rationale"),
            "source_locator": row.get("source_locator"),
        })

    universe = []
    for row in book.get("universe") or []:
        if not isinstance(row, dict):
            raise BridgeRefusal("universe row must be object")
        universe.append({
            "logical_symbol": row.get("logical_symbol"),
            "broker_symbol_proposal": row.get("broker_symbol"),
            "timeframe_proposal": row.get("timeframe"),
            "role": row.get("role"),
            "home_state": row.get("home_state"),
            "notes": row.get("notes"),
            "authority": "OWNER_PROPOSAL_UNVERIFIED",
        })

    return {
        "schema_version": PLAN_SCHEMA,
        "authority": "PLANNING_PRESENTATION_ONLY",
        "canonical_ref": ref,
        "workbook_schema_version": book.get("schema_version"),
        "campaign_id": (book.get("document") or {}).get("campaign_id"),
        "revision_id": (book.get("document") or {}).get("revision_id"),
        "identity": {
            k: identity.get(k) for k in [
                "family_id", "ea_id", "variant_id", "parent_id",
                "source_ref", "source_sha256", "parent_ref", "parent_sha256",
                "build_ref", "build_sha256", "config_ref", "config_sha256",
                "hypothesis", "objective", "falsifier", "direct_consumer", "provenance"
            ]
        },
        "strategy": book.get("strategy"),
        "parameters": params,
        "universe_proposals": universe,
        "optimization_proposals": book.get("optimizer_sets") or [],
        "filter_module_proposals": book.get("filters_modules") or [],
        "windows": book.get("windows"),
        "required_gates": [r.get("stage") for r in (book.get("stage_plan") or []) if isinstance(r, dict) and r.get("stage")],
        "unresolved_owner_decisions": unresolved,
        "authority_ceiling": "NO_EXECUTION_AUTHORITY",
    }
def build_execution_proposal(repo, ref, book, plan, pilot_dir):
    identity = plan["identity"]
    blockers = []
    source_ref = identity.get("source_ref")
    source_sha = str(identity.get("source_sha256") or "").lower()
    source_status = "UNRESOLVED"
    if source_ref and SHA256_RE.fullmatch(source_sha):
        blob = git_blob_or_none(repo, ref, source_ref)
        if blob is None:
            blockers.append("SOURCE_REF_NOT_IN_CANONICAL_REF")
        elif sha256_bytes(blob) != source_sha:
            blockers.append("SOURCE_SHA256_MISMATCH")
        else:
            source_status = "EXACT_GIT_BLOB_MATCH"
    else:
        blockers.append("SOURCE_IDENTITY_INCOMPLETE")

    package, surface_rows, compat, factory, factory_blockers = validate_factory_contract(
        repo, ref, pilot_dir, source_ref, source_sha if SHA256_RE.fullmatch(source_sha) else None
    )
    blockers.extend(factory_blockers)
    if identity.get("family_id") and identity.get("family_id") != package.get("FamilyID"):
        blockers.append("FAMILY_ID_FACTORY_MISMATCH")
    if identity.get("variant_id") and identity.get("variant_id") != package.get("VariantID"):
        blockers.append("VARIANT_ID_FACTORY_MISMATCH")

    build_ref = identity.get("build_ref")
    build_sha = str(identity.get("build_sha256") or "").lower()
    if build_ref and SHA256_RE.fullmatch(build_sha):
        build_blob = git_blob_or_none(repo, ref, build_ref)
        if build_blob is None or sha256_bytes(build_blob) != build_sha:
            blockers.append("BUILD_IDENTITY_NOT_CANONICAL")
    else:
        blockers.append("BUILD_IDENTITY_OWNER_OR_BUILD_GATE_REQUIRED")

    canonical_universe = git_blob_or_none(repo, ref, "factory/universe.jsonl")
    if canonical_universe is None:
        blockers.append("CANONICAL_TEST_UNIVERSE_UNAVAILABLE")
        universe_status = "BLOCKED_CANONICAL_STORE_ABSENT"
    else:
        universe_status = "AVAILABLE_REQUIRES_EXACT_RECORD_RESOLUTION"

    proposed_home_symbols = sorted({
        str(r.get("logical_symbol")) for r in plan["universe_proposals"]
        if r.get("logical_symbol") and str(r.get("role") or "").upper().startswith("HOME")
    })
    proposed_home_tfs = sorted({
        str(r.get("timeframe_proposal")) for r in plan["universe_proposals"]
        if r.get("timeframe_proposal") and str(r.get("role") or "").upper().startswith("HOME")
    })
    blockers.append("HOME_SYMBOL_CANONICAL_FREEZE_REQUIRED")
    blockers.append("HOME_TIMEFRAME_CANONICAL_FREEZE_REQUIRED")

    surface_by_name = {r.get("parameter"): r for r in surface_rows if isinstance(r, dict) and r.get("parameter")}
    resolved_params = []
    for row in plan["parameters"]:
        name = row["name"]
        cls = row["classification"]
        factory_row = surface_by_name.get(name)
        factory_role = factory_row.get("role") if factory_row else "NOT_IN_PARAMETER_SURFACE"
        factory_locked = factory_row.get("locked_value") if factory_row else None
        if cls in {"OWNER_REQUIRED", "UNKNOWN"}:
            blockers.append(f"PARAMETER_{cls}:{name}")
        if cls == "SEARCHABLE" and not row["range_proposal"]["complete"]:
            blockers.append(f"SEARCHABLE_RANGE_INCOMPLETE:{name}")
        if cls == "SEARCHABLE" and factory_role == "LOCKED":
            blockers.append(f"PARAMETER_CLASSIFICATION_CONFLICT:{name}")
        if cls in {"LOCKED", "FIXED"} and row.get("proposed_baseline") in (None, "") and row.get("source_default") in (None, ""):
            blockers.append(f"PARAMETER_VALUE_UNRESOLVED:{name}")
        resolved_params.append({
            "name": name,
            "workbook_classification": cls,
            "workbook_baseline_proposal": row.get("proposed_baseline"),
            "workbook_range_proposal": row.get("range_proposal"),
            "factory_surface_role": factory_role,
            "factory_locked_value": factory_locked,
            "factory_surface_authority": "NON_AUTHORITATIVE_SIDECAR",
            "execution_value": None,
            "execution_range": None,
        })

    optimizer_rows = plan["optimization_proposals"]
    if optimizer_rows:
        for row in optimizer_rows:
            if str(row.get("search_role") or "") != "MAIN_ONLY":
                blockers.append("OPTIMIZER_SEARCH_ROLE_NOT_MAIN_ONLY")
        blockers.append("OPTIMIZATION_AUTHORITY_NOT_GRANTED")

    holdout = next((w for w in plan["windows"] if w.get("role") == "HOLDOUT"), None)
    if not holdout or holdout.get("state") != "LOCKED_UNSPENT":
        blockers.append("HOLDOUT_NOT_LOCKED_UNSPENT")

    blockers = sorted(set(blockers))
    proposal = {
        "schema_version": PROPOSAL_SCHEMA,
        "authority": "NON_EXECUTABLE_PROPOSAL_ONLY",
        "canonical_ref": ref,
        "workbook_revision_id": plan.get("revision_id"),
        "factory": factory,
        "source_identity": {
            "source_ref": source_ref,
            "source_sha256": source_sha or None,
            "status": source_status,
        },
        "build_identity": {
            "build_ref": build_ref or None,
            "build_sha256": build_sha or None,
            "status": "UNRESOLVED" if "BUILD_IDENTITY_OWNER_OR_BUILD_GATE_REQUIRED" in blockers else "PROVIDED_REQUIRES_GATE",
        },
        "home": {
            "logical_symbol_proposals": proposed_home_symbols,
            "timeframe_proposals": proposed_home_tfs,
            "symbol_status": "CANONICAL_FREEZE_REQUIRED",
            "timeframe_status": "CANONICAL_FREEZE_REQUIRED",
            "canonical_test_universe_status": universe_status,
        },
        "parameters": resolved_params,
        "optimization": {
            "proposal_rows": optimizer_rows,
            "authority": "NOT_GRANTED",
            "search_surface_emitted": False,
        },
        "windows": plan["windows"],
        "holdout": {"state": holdout.get("state") if holdout else "UNKNOWN", "spend_authorized": False},
        "set_output": {
            "generated_from_workbook": False,
            "factory_compat_reference": factory.get("factory_set_ref"),
            "factory_compat_sha256": factory.get("factory_set_sha256"),
            "authority": "REFERENCE_ONLY",
        },
        "can_execute": False,
        "blockers": blockers,
        "reason": "BLOCKED_UNTIL_CANONICAL_AUTHORITY_RESOLVES_ALL_FIELDS",
        "downstream_consumer": "EXISTING_EA_TEMPLATE_FACTORY_AFTER_ACCEPTED_CONTRACT",
        "forbidden_inferences": [
            "WORKBOOK_VALUES_ARE_NOT_EXECUTION_AUTHORITY",
            "NO_HOME_TF_INFERENCE",
            "NO_RANGE_INFERENCE",
            "NO_DIRECT_SET_GENERATION",
            "NO_MT5_LAUNCH",
            "NO_HOLDOUT",
            "NO_RISK_DEFAULT_CHANGE",
        ],
    }
    return proposal

def result_binding_template(ref, proposal):
    return {
        "schema_version": RESULT_SCHEMA,
        "authority": "NO_RESULT_EVIDENCE",
        "canonical_ref": ref,
        "workbook_revision_id": proposal.get("workbook_revision_id"),
        "run_id": None,
        "cell_id": None,
        "manifest_sha256": None,
        "set_sha256": None,
        "source_sha256": proposal["source_identity"].get("source_sha256"),
        "build_sha256": proposal["build_identity"].get("build_sha256"),
        "installation_lineage": None,
        "model": None,
        "window_role": None,
        "symbol": None,
        "timeframe": None,
        "metrics": {"profit_factor": None, "net_profit": None, "drawdown": None, "trades": None},
        "year_split": None,
        "report_ref": None,
        "graph_refs": [],
        "evidence_refs": [],
        "verification_status": "UNAVAILABLE_NO_ACCEPTED_RUN",
        "interpretation": None,
        "decision": None,
    }

def validate_test_universe_fixture(repo, ref, fixture):
    schemas = load_json_blob(repo, ref, "_triage/factory_os/schemas.json")
    definition = schemas["$defs"]["TestUniverse"]
    missing = [k for k in definition["required"] if k not in fixture]
    if missing:
        raise BridgeRefusal("TestUniverse fixture missing: " + ",".join(missing))
    if fixture.get("entity") != "TestUniverse":
        raise BridgeRefusal("fixture entity mismatch")
    if fixture.get("kind") not in definition["properties"]["kind"]["enum"]:
        raise BridgeRefusal("fixture kind invalid")
    for tf in fixture.get("timeframes") or []:
        if tf not in definition["properties"]["timeframes"]["items"]["enum"]:
            raise BridgeRefusal("fixture timeframe invalid")
    if fixture.get("created_commit") != ref:
        raise BridgeRefusal("fixture created_commit must equal exact ref")
    return {
        "status": "PASS_SCHEMA_REQUIRED_ENUM_SUBSET",
        "authority": "SYNTHETIC_FIXTURE_ONLY",
        "canonical_owner_path": definition.get("x-owner-file"),
        "canonical_owner_path_exists": git_blob_or_none(repo, ref, definition.get("x-owner-file")) is not None,
    }

def write_once(path, raw):
    path = Path(path)
    if path.exists():
        if path.read_bytes() != raw:
            raise BridgeRefusal(f"output collision mismatch: {path.name}")
        return
    path.write_bytes(raw)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--ref", required=True)
    ap.add_argument("--workbook", required=True)
    ap.add_argument("--factory-pilot-dir", required=True)
    ap.add_argument("--test-universe-fixture", required=True)
    ap.add_argument("--output-root", required=True)
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    out = Path(args.output_root).resolve()
    verify_ref(repo, args.ref)
    if out.exists() and any(out.iterdir()):
        raise BridgeRefusal("output root must be fresh or empty")
    out.mkdir(parents=True, exist_ok=True)

    try:
        workbook_payload = Path(args.workbook).read_bytes()
    except OSError as exc:
        raise BridgeRefusal(f"cannot read workbook payload: {exc}") from exc
    workbook_validation = validate_workbook_payload_with_canonical_js(repo, args.ref, workbook_payload)
    book = parse_validated_workbook(workbook_payload, workbook_validation)
    plan = build_plan_export(book, args.ref)
    plan["planning_schema_validation"] = workbook_validation
    proposal = build_execution_proposal(repo, args.ref, book, plan, args.factory_pilot_dir)
    result = result_binding_template(args.ref, proposal)
    fixture = json.loads(Path(args.test_universe_fixture).read_text(encoding="utf-8-sig"))
    universe_check = validate_test_universe_fixture(repo, args.ref, fixture)

    outputs = {
        "WORKBOOK_PLAN_EXPORT.json": plan,
        "EXECUTION_PROPOSAL.json": proposal,
        "RESULT_BINDING_TEMPLATE.json": result,
        "TEST_UNIVERSE_FIXTURE_CHECK.json": universe_check,
    }
    manifest_files = {}
    for name, obj in outputs.items():
        raw = canonical_json(obj)
        write_once(out / name, raw)
        manifest_files[name] = {"sha256": sha256_bytes(raw), "bytes": len(raw)}
    manifest = {
        "schema_version": "EA_LAB_WORKBOOK_FACTORY_BRIDGE_PACKAGE_V1",
        "authority": "NON_TRADING_FIXTURE_ONLY",
        "canonical_ref": args.ref,
        "files": manifest_files,
        "deterministic": True,
        "mt5_execution": False,
        "set_generation": False,
        "holdout_spent": False,
        "can_execute": proposal["can_execute"],
    }
    raw = canonical_json(manifest)
    write_once(out / "BRIDGE_MANIFEST.json", raw)
    print(json.dumps({
        "status": "PASS",
        "can_execute": proposal["can_execute"],
        "blockers": proposal["blockers"],
        "manifest_sha256": sha256_bytes(raw),
        "output_root": str(out),
    }, sort_keys=True))
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BridgeRefusal as exc:
        print(json.dumps({"status": "BLOCKED", "reason": str(exc)}, sort_keys=True))
        raise SystemExit(2)
