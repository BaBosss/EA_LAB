#!/usr/bin/env python3
"""Offline, non-authoritative EA artifact catalog for CT review.

This tool neither executes MT5 nor changes EA/Factory/Monitor source-of-truth files.
Only an explicit --out directory receives scan outputs. No source corpus mutation.
"""
from __future__ import annotations

import argparse
import csv
from collections import Counter, defaultdict
import hashlib
import json
import os
from pathlib import Path, PureWindowsPath
import re
import sys

EXT_CLASS = {
    ".mq4": "SOURCE_MQL4", ".mq5": "SOURCE_MQL5",
    ".ex4": "COMPILED_MT4", ".ex5": "COMPILED_MT5",
    ".set": "PRESET", ".ini": "TESTER_INI", ".opt": "OPTIMIZER_CACHE",
    ".zip": "ARCHIVE", ".rar": "ARCHIVE", ".7z": "ARCHIVE",
}
ID_RE = re.compile(r"^[A-Z][A-Z0-9_-]{2,63}$")
SENSITIVE = re.compile(r"password|secret|token|apikey|api_key|credential|private.?key", re.I)
DRAFT_AUTH = "LOCAL_DRAFT_UNVERIFIED"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def stable_id(prefix: str, key: str) -> str:
    return prefix + hashlib.sha256(key.encode("utf-8")).hexdigest()[:16].upper()


def write_csv(path: Path, fields: list[str], records: list[dict]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(records)


def write_json(path: Path, obj: object) -> None:
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def no_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key refused: " + key)
        result[key] = value
    return result


def is_within(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def ensure_new_output(out: Path, corpus: Path, projects: Path | None) -> None:
    if out.exists():
        raise ValueError(f"Output exists; refusing overwrite: {out}")
    if is_within(out, corpus) or (projects and is_within(out, projects)):
        raise ValueError("Output must be outside source and project trees")
    out.mkdir(parents=True, exist_ok=False)


def source_files(root: Path):
    for folder, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if not (Path(folder) / d).is_symlink())
        for name in sorted(files, key=str.casefold):
            path = Path(folder) / name
            if path.is_symlink():
                continue
            if path.is_file():
                yield path


def legacy_relative(value: str) -> Path | None:
    raw = value.strip()
    if not raw:
        return None
    normalized = PureWindowsPath(raw.replace("/", "\\"))
    if normalized.is_absolute() or ".." in normalized.parts or normalized.drive:
        return None
    parts = normalized.parts
    if any(part in ("", ".") for part in parts):
        return None
    return Path(*parts)


def load_legacy(path: Path | None) -> list[dict]:
    if path is None:
        return []
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def read_set_lines(path: Path) -> list[tuple[str, str]]:
    raw = path.read_bytes()
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        content = raw.decode("utf-16")
    else:
        try:
            content = raw.decode("utf-8-sig")
        except UnicodeDecodeError:
            content = raw.decode("cp1252")
    params = []
    for line in content.splitlines():
        item = line.strip()
        if not item or item.startswith(("#", ";", "//")) or "=" not in item:
            continue
        key, value = item.split("=", 1)
        key = key.strip()
        if not key or len(key) > 256:
            continue
        params.append((key, value.strip()))
    return params


def scan(root: Path, out: Path, index: Path | None, projects: Path | None) -> dict:
    root = root.resolve()
    if not root.is_dir():
        raise ValueError("The source directory does not exist")
    if projects and not projects.is_dir():
        raise ValueError("External project directory does not exist")
    if index and not index.is_file():
        raise ValueError("Legacy index does not exist")
    # Validate inputs before creating output.
    legacy = load_legacy(index)
    ensure_new_output(out, root, projects)
    inventory = []
    dup = defaultdict(list)
    by_rel = {}
    failures = []
    presets = []
    params = []
    for path in source_files(root):
        rel = path.relative_to(root).as_posix()
        try:
            digest = sha256_file(path)
            size = path.stat().st_size
        except OSError as exc:
            failures.append({"path": rel, "reason": str(exc)})
            continue
        ext = path.suffix.lower()
        record = {
            "relative_path": rel, "sha256": digest, "bytes": size,
            "extension": ext, "artifact_type": EXT_CLASS.get(ext, "OTHER"),
            "top_category": Path(rel).parts[0] if "/" in rel else "_ROOT",
            "authority": "SOURCE_FILE_HASH_ONLY",
        }
        inventory.append(record)
        by_rel[rel.casefold()] = record
        dup[digest].append(rel)
        if ext == ".set":
            count = 0
            try:
                entries = read_set_lines(path)
                for key, val in entries:
                    if SENSITIVE.search(key):
                        # Never export even a value associated with credential-like keys.
                        continue
                    segments = val.split("||")
                    params.append({
                        "preset_path": rel, "preset_sha256": digest,
                        "parameter": key, "raw_value": segments[0],
                        "optimization_start": segments[1] if len(segments) > 1 else "",
                        "optimization_step": segments[2] if len(segments) > 2 else "",
                        "optimization_stop": segments[3] if len(segments) > 3 else "",
                        "optimization_enabled": segments[4] if len(segments) > 4 else "",
                        "binding": "UNRESOLVED_NO_EFFECTIVE_CONFIG",
                    })
                    count += 1
                presets.append({"relative_path": rel, "sha256": digest,
                                "parsed_parameters": count, "strategy_binding": "UNRESOLVED"})
            except (UnicodeError, OSError, ValueError) as exc:
                failures.append({"path": rel, "reason": "SET_PARSE_FAIL: " + str(exc)})
    links = []
    for pos, item in enumerate(legacy, 1):
        raw = item.get("Path", "")
        rel = legacy_relative(raw)
        matches = []
        if rel is None:
            state = "UNRESOLVED_UNSAFE_OR_EMPTY_PATH"
        else:
            target = root / rel
            if not is_within(target, root):
                state = "UNRESOLVED_OUTSIDE_CORPUS"
            elif not target.exists():
                state = "UNRESOLVED_MISSING_PATH"
            elif target.is_file():
                matches = [target.relative_to(root).as_posix()]
                state = "FILE_PATH_ONLY_SEMANTICS_UNVERIFIED"
            elif target.is_dir():
                prefix = target.relative_to(root).as_posix().casefold() + "/"
                matches = [r["relative_path"] for r in inventory
                           if r["relative_path"].casefold().startswith(prefix)]
                declared = item.get("FilesCount", "")
                if rel.as_posix().casefold() in {
                        "02_ai_generated_bots", "01_boss_custom_fxdreema",
                        "03_fxdreema_modified", "04_ealab_templates_and_origins"}:
                    state = "UNRESOLVED_BROAD_FOLDER"
                elif declared.isdecimal() and int(declared) != len(matches):
                    state = "COUNT_MISMATCH"
                else:
                    state = "FOLDER_PATH_ONLY_SEMANTICS_UNVERIFIED"
            else:
                state = "UNRESOLVED_PATH_TYPE"
        key = f"{item.get('Category', '')}|{item.get('Name', '')}|{pos}"
        links.append({
            "legacy_row": pos, "provisional_candidate_id": stable_id("CAND-", key),
            "name": item.get("Name", ""), "category": item.get("Category", ""),
            "declared_file_count": item.get("FilesCount", ""),
            "actual_file_count": len(matches),
            "raw_path": raw, "mapping_state": state,
            "candidate_files_json": json.dumps(matches, ensure_ascii=False),
            "strategy_id": "", "family_id": "", "variant_id": "",
            "template_target_proposal_only": item.get("TargetChassis", ""),
            "research_status": "SOURCE_CLAIM_ONLY",
        })
    extra_projects = []
    if projects:
        for project in sorted(projects.iterdir(), key=lambda p: p.name.casefold()):
            if not project.is_dir() or project.is_symlink():
                continue
            found = Counter(p.suffix.lower() for p in source_files(project))
            extra_projects.append({
                "project_name": project.name, "external_path": str(project),
                "mq4": found[".mq4"], "mq5": found[".mq5"],
                "ex4": found[".ex4"], "ex5": found[".ex5"],
                "catalog_status": "EXTERNAL_REFERENCE_NOT_MOVED",
                "strategy_id": "",
            })
    duplicates = [{"sha256": sha, "copies": len(paths),
                   "paths_json": json.dumps(paths, ensure_ascii=False)}
                  for sha, paths in sorted(dup.items()) if len(paths) > 1]
    write_csv(out / "SOURCE_FILES.csv", list(inventory[0]) if inventory else [
        "relative_path", "sha256", "bytes", "extension", "artifact_type",
        "top_category", "authority"], inventory)
    write_csv(out / "LEGACY_CROSSWALK.csv", [
        "legacy_row", "provisional_candidate_id", "name", "category",
        "declared_file_count", "actual_file_count", "raw_path", "mapping_state",
        "candidate_files_json", "strategy_id", "family_id", "variant_id",
        "template_target_proposal_only", "research_status"], links)
    write_csv(out / "EXACT_DUPLICATE_BYTES.csv", ["sha256", "copies", "paths_json"], duplicates)
    write_csv(out / "PRESETS.csv", [
        "relative_path", "sha256", "parsed_parameters", "strategy_binding"], presets)
    write_csv(out / "PRESET_PARAMETERS.csv", [
        "preset_path", "preset_sha256", "parameter", "raw_value",
        "optimization_start", "optimization_step", "optimization_stop",
        "optimization_enabled", "binding"], params)
    write_csv(out / "EXTERNAL_PROJECTS.csv", [
        "project_name", "external_path", "mq4", "mq5", "ex4", "ex5",
        "catalog_status", "strategy_id"], extra_projects)
    stats = {
        "schema": "EA_LAB_CUSTOM_EA_INTAKE_V1",
        "authority": "READ_ONLY_PREPARATION_NOT_ADMITTED",
        "source_root": str(root), "original_file_count": len(inventory),
        "prior_audit_files": sum(r["top_category"].upper().startswith("_AUDIT_") for r in inventory),
        "strategy_corpus_files_excluding_prior_audits": sum(not r["top_category"].upper().startswith("_AUDIT_") for r in inventory),
        "byte_count": sum(int(r["bytes"]) for r in inventory),
        "file_kind_counts": dict(sorted(Counter(r["artifact_type"] for r in inventory).items())),
        "source_catalog_rows": len(links),
        "mapping_states": dict(sorted(Counter(r["mapping_state"] for r in links).items())),
        "duplicate_groups": len(duplicates),
        "duplicate_extra_copies": sum(r["copies"] - 1 for r in duplicates),
        "external_project_folders": len(extra_projects),
        "preset_files": len(presets), "preset_parameter_rows": len(params),
        "read_failures": failures,
        "unknowns": ["No verified StrategyID, FamilyID, VariantID mapping",
                     "No source-to-template parity", "No actual Backtest or Optimize results",
                     "No accepted report/Monitor link or source-parameter approval"],
        "live_execution_allowed": False, "factory_submit_allowed": False,
    }
    write_json(out / "INTAKE_SUMMARY.json", stats)
    write_json(out / "RESEARCH_MONITOR_PROJECTION_DRAFT.json", {
        "schema": "EA_LAB_CUSTOM_EA_RESEARCH_PROJECTION_DRAFT_V1",
        "authority": "UNVERIFIED_CATALOG_ONLY_NOT_RUNTIME_DATA",
        "source_root": str(root),
        "source_catalog_count": len(links),
        "strategy_links_accepted": 0,
        "run_links_accepted": 0,
        "report_links_accepted": 0,
        "monitor_status": "NOT_LINKED",
        "portfolio_live_status": "NOT_APPLICABLE",
        "records": [{
            "candidate_id": r["provisional_candidate_id"], "name": r["name"],
            "mapping_state": r["mapping_state"],
            "strategy_id": None, "build_id": None,
            "run_id": None, "report_id": None,
            "result": None, "freshness": "UNKNOWN",
        } for r in links],
    })
    if failures:
        raise RuntimeError(f"Inventory generated with {len(failures)} read/parse failures. See summary.")
    return stats


def init_strategy(root: Path, strategy_id: str) -> dict:
    windows_reserved = {"CON", "PRN", "AUX", "NUL", "CLOCK$"} | {
        f"{prefix}{i}" for prefix in ("COM", "LPT") for i in range(1, 10)}
    if not ID_RE.fullmatch(strategy_id) or strategy_id in windows_reserved:
        raise ValueError("StrategyID must be a safe uppercase identifier of 3-64 characters")
    root = root.resolve(strict=True)
    if not root.is_dir():
        raise ValueError("Root must be a directory")
    landing = root / "06_Template_Converted"
    if landing.is_symlink():
        raise ValueError("Refusing symlink landing directory")
    landing.mkdir(exist_ok=True)
    target = landing / strategy_id
    if target.exists() or target.is_symlink():
        raise ValueError("Strategy directory exists; refusing overwrite")
    target.mkdir()
    for dirname in ("origin", "spec", "src", "presets", "runs", "reports"):
        (target / dirname).mkdir()
    card = {
        "schema": "EA_LAB_STRATEGY_DRAFT_V1",
        "authority": "DRAFT_NOT_ADMITTED", "strategy_id": strategy_id,
        "family_id": None, "variant_id": None, "source_refs": [],
        "mechanics": {
            "hypothesis": None, "home_symbol": None, "home_timeframe": None,
            "entry_buy": None, "entry_sell": None, "indicators": [],
            "signal_timing": None, "state_machine": None,
            "exit_tp": None, "exit_sl": None, "risk_caps": None,
            "grid_lot_ladder": None,
        },
        "template_release": None, "parameter_binding": None,
        "effective_config": None, "owner_review": "NOT_APPROVED",
    }
    links = {
        "schema": "EA_LAB_STRATEGY_LINKS_DRAFT_V1",
        "strategy_id": strategy_id, "source_sha256": [],
        "builder_revision": None, "variant_ids": [],
        "build_ids": [], "preset_ids": [], "run_ids": [],
        "report_ids": [], "deployment_ids": [],
        "authority": "NO_FACTORY_OR_MONITOR_AUTHORITY",
    }
    write_json(target / "spec" / "strategy_card.json", card)
    write_json(target / "links.json", links)
    return {"path": str(target), "status": "DRAFT_NOT_ADMITTED"}


def import_builder_draft(source: Path, out: Path) -> dict:
    if out.exists():
        raise ValueError("Output exists; refusing overwrite")
    raw = source.read_bytes()
    if len(raw) > 5_000_000:
        raise ValueError("Builder JSON too large")
    data = json.loads(raw.decode("utf-8-sig"), object_pairs_hook=no_duplicate_keys)
    if not isinstance(data, dict) or data.get("authority") != DRAFT_AUTH:
        raise ValueError("Only an unverified local Builder draft is accepted")
    expected = {"schema", "authority", "revision", "parent_revision", "title",
                "notes", "intent", "entry_mode", "bindings", "plans"}
    if set(data) != expected or not isinstance(data.get("schema"), str):
        raise ValueError("Unexpected M1 draft fields")
    if data.get("entry_mode") != "ENTRY_ONLY" or not isinstance(data.get("bindings"), dict):
        raise ValueError("Unsupported Builder draft contract")
    if not isinstance(data.get("plans"), list) or any(
        not isinstance(x, dict) or x.get("enabled") is not False for x in data["plans"]
    ):
        raise ValueError("Enabled/invalid plans are forbidden")
    for key in ("template_release", "default_profile", "entry_contract", "test_plan"):
        binding = data["bindings"].get(key)
        if not isinstance(binding, dict) or set(binding) != {"id", "revision"} or not isinstance(binding.get("id"), str) or not isinstance(binding.get("revision"), str):
            raise ValueError("Invalid/missing Builder binding")
    result = {
        "schema": "EA_LAB_BUILDER_REFERENCE_V1",
        "authority": "DRAFT_NOT_SUBMITTED",
        "builder_draft_sha256": hashlib.sha256(raw).hexdigest(),
        "builder_schema_claim": str(data.get("schema", ""))[:128],
        "title": str(data.get("title", ""))[:300],
        "revision": str(data.get("revision", ""))[:128],
        "intent": str(data.get("intent", ""))[:64],
        "entry_mode": "ENTRY_ONLY",
        "binding_references_unverified": data["bindings"],
        "effective_configuration": None, "approved_source": None,
        "can_submit": False, "can_execute": False,
        "known_blockers": [
            "CATALOG_NOT_BOUND", "PROFILE_NOT_APPROVED",
            "ENTRY_PARITY_NOT_PROVEN", "T3_EXECUTION_NOT_AUTHORIZED",
        ],
    }
    write_json(out, result)
    return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sc = sub.add_parser("scan", help="inventory and crosswalk; no source writes")
    sc.add_argument("--root", required=True, type=Path)
    sc.add_argument("--out", required=True, type=Path)
    sc.add_argument("--legacy-index", type=Path)
    sc.add_argument("--projects", type=Path)
    init = sub.add_parser("init", help="create safe DRAFT strategy in 06_Template_Converted")
    init.add_argument("--root", required=True, type=Path)
    init.add_argument("--strategy-id", required=True)
    draft = sub.add_parser("draft", help="normalize offline M1 Builder draft only")
    draft.add_argument("--input", required=True, type=Path)
    draft.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        if args.cmd == "scan":
            result = scan(args.root, args.out, args.legacy_index, args.projects)
        elif args.cmd == "init":
            result = init_strategy(args.root, args.strategy_id)
        else:
            result = import_builder_draft(args.input, args.out)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (OSError, UnicodeError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"BLOCKED: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
