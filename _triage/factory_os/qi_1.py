# -*- coding: utf-8 -*-
"""QI-1 Foundation: strict records, identity binding, and derived projections.

This module is deliberately a bounded layer over the existing R4 catalog, PID
allocation, run journal, OwnerRef, event-v1, and evidence-manifest stores.  It
does not write any of those stores and it never turns an experiment verdict
into a strategy, deployment, execution, or risk decision.
"""
import copy
import io
import json
import os
import re

import candidate as _candidate
import capability as _capability
import evidence as _evidence


EXPERIMENT_ID_RE = re.compile(r"^exp_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
RESULT_ID_RE = re.compile(r"^res_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
HASH_RE = re.compile(r"^[0-9a-f]{64}$")
PID_RE = re.compile(r"^[1-9][0-9]{4}$")
TIME_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{3})?Z$")
REASON_RE = re.compile(r"^[a-z][a-z0-9_]{0,47}$")
EXECUTABLE_TYPES = frozenset((
    "EA_EXECUTABLE", "EA_BACKTEST", "BACKTEST", "OPTIMIZATION", "EA_OPTIMIZATION",
))
VERDICTS = frozenset(("ACCEPTED", "REJECTED", "INCONCLUSIVE", "INVALID"))
NEGATIVE_VERDICTS = frozenset(("REJECTED", "INCONCLUSIVE", "INVALID"))

CONTRACT_FIELDS = frozenset((
    "schema_version", "entity", "experiment_id", "created_at_utc", "strategy_ref",
    "experiment_type", "spec_ref", "hypothesis_revision", "implementation_ref",
    "parameter_refs", "supersedes_experiment_id",
))
RESULT_FIELDS = frozenset((
    "schema_version", "entity", "result_id", "experiment_id", "recorded_at_utc",
    "run_ids", "evidence_ids", "verdict", "reason_code", "reason_ref",
    "supersedes_result_id",
))
IMPLEMENTATION_FIELDS = frozenset(("ex5_hash", "source_hash", "effective_config_hash", "set_hash"))
STRATEGY_FIELDS = frozenset(("ea_id", "strategy_revision"))
PARAMETER_REF_FIELDS = frozenset(("pid", "semantic_rev"))

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


class QIValidationError(ValueError):
    """A durable QI-1 record cannot be accepted as supplied."""

    def __init__(self, problems):
        self.problems = tuple(str(p) for p in problems)
        super().__init__("; ".join(self.problems))


def _root(root=None):
    return os.path.abspath(root or REPO_ROOT)


def _path(root, rel):
    return os.path.join(_root(root), rel.replace("/", os.sep))


def _json(path):
    with io.open(path, encoding="utf-8-sig") as handle:
        return json.load(handle)


def _jsonl(path):
    rows = []
    with io.open(path, encoding="utf-8-sig") as handle:
        for line_no, line in enumerate(handle, 1):
            if line.strip() and not line.lstrip().startswith("{"):
                continue
            if line.strip():
                try:
                    rows.append((line_no, json.loads(line)))
                except ValueError as exc:
                    raise QIValidationError(["%s:%s is not JSON: %s" % (path, line_no, exc)])
    return rows


def _shape(record, fields, name):
    problems = []
    if not isinstance(record, dict):
        return ["%s must be an object" % name]
    missing = sorted(fields - set(record))
    extra = sorted(set(record) - fields)
    if missing:
        problems.append("%s missing required fields: %s" % (name, ", ".join(missing)))
    if extra:
        problems.append("%s has unknown fields: %s" % (name, ", ".join(extra)))
    return problems


def _hash_value(value, field, nullable=True):
    if value is None and nullable:
        return []
    if not isinstance(value, str) or not HASH_RE.fullmatch(value):
        return ["%s must be a lowercase SHA-256 hex string" % field]
    return []


def _id_or_null(value, regex, field):
    if value is not None and (not isinstance(value, str) or not regex.fullmatch(value)):
        return ["%s is not a UUIDv4 identifier or null" % field]
    return []


def _owner_ref_problems(ref, field, root):
    if isinstance(ref, dict):
        type_problems = []
        for name in ("entity", "owner_type", "path", "commit_oid", "blob_oid", "raw_sha256"):
            if name in ref and not isinstance(ref[name], str):
                type_problems.append("%s.%s must be a string" % (field, name))
        if "anchor" in ref and ref["anchor"] is not None and not isinstance(ref["anchor"], str):
            type_problems.append("%s.anchor must be a string or null" % field)
        if type_problems:
            return type_problems
    source = _evidence.EvidenceSource("worktree", root=_root(root))
    problems = _candidate.owner_ref_problems(ref, field, src=source)
    try:
        schema = _json(_path(root, "_triage/factory_os/schemas.json"))
        allowed = schema["$defs"]["OwnerRef"]["properties"]["owner_type"]["enum"]
    except (IOError, KeyError, TypeError, ValueError) as exc:
        problems.append("canonical OwnerRef schema is unavailable: %s" % exc)
        return problems
    if isinstance(ref, dict) and ref.get("owner_type") not in allowed:
        problems.append("%s.owner_type is not a canonical OwnerRef value" % field)
    return problems


def load_strategy_index(root=None):
    """Read the one R4 strategy catalog and return `{ea_id: strategy_revision}`."""
    value = _json(_path(root, "factory/strategy_catalog.json"))
    if not isinstance(value, list):
        raise QIValidationError(["factory/strategy_catalog.json must be an array"])
    expected = ["E0%s" % i for i in range(11, 19)]
    ids = [row.get("ea_id") for row in value if isinstance(row, dict)]
    if ids != expected:
        raise QIValidationError(["strategy catalog must contain E011-E018 exactly once in order"])
    problems = []
    out = {}
    for row in value:
        if set(row).intersection(("strategy_id", "strategy_uid", "strategy_namespace")):
            problems.append("strategy catalog contains a second strategy identity namespace")
        if row.get("strategy_revision") != 1:
            problems.append("%s must have strategy_revision=1" % row.get("ea_id"))
        out[row["ea_id"]] = row.get("strategy_revision")
    if problems:
        raise QIValidationError(problems)
    return out


def load_pid_index(root=None):
    """Read the existing R4 PID + semantic_rev allocation authority."""
    value = _json(_path(root, "_triage/factory_os/EA_TEMPLATE_PID_ALLOCATION_V1_R4_FINAL.json"))
    allocations = value.get("allocations") if isinstance(value, dict) else None
    if not isinstance(allocations, list):
        raise QIValidationError(["R4 PID allocation artifact has no allocations array"])
    out = {}
    problems = []
    for row in allocations:
        pid, rev = row.get("pid"), row.get("semantic_rev")
        if not isinstance(pid, int) or not 10000 <= pid <= 99999 or not isinstance(rev, int) or rev < 1:
            problems.append("R4 PID allocation contains an invalid identity: %r" % row)
            continue
        key = (pid, rev)
        if key in out:
            problems.append("R4 PID allocation duplicates %s" % (key,))
        out[key] = row
    if problems:
        raise QIValidationError(problems)
    return out


def load_run_index(root=None):
    """Return the observed first ExecutionKey for every existing run journal."""
    out = {}
    run_dir = _path(root, "factory/runs")
    for name in sorted(os.listdir(run_dir)) if os.path.isdir(run_dir) else []:
        if not name.endswith(".jsonl"):
            continue
        for _line, row in _jsonl(os.path.join(run_dir, name)):
            if row.get("entity") != "RunTransition":
                continue
            run_id, key = row.get("run_id"), row.get("execution_key")
            if not isinstance(run_id, str) or not isinstance(key, dict):
                continue
            if run_id in out and out[run_id] != key:
                raise QIValidationError(["run_id %s has conflicting observed identities" % run_id])
            out[run_id] = key
    return out


def load_evidence_index(root=None):
    """Return the existing evidence-manifest IDs; this module never rewrites that manifest."""
    path = _path(root, "docs/memory_control/experiment_events/evidence-manifest.jsonl")
    out = {}
    for _line, row in _jsonl(path):
        evidence_id = row.get("evidence_id")
        if evidence_id in out:
            raise QIValidationError(["evidence manifest duplicates %s" % evidence_id])
        out[evidence_id] = row
    return out


def validate_contract(contract, root=None):
    root = _root(root)
    problems = _shape(contract, CONTRACT_FIELDS, "ExperimentContract")
    if problems:
        return problems
    if contract.get("schema_version") != 1:
        problems.append("schema_version must be 1")
    if contract.get("entity") != "ExperimentContract":
        problems.append("entity must be ExperimentContract")
    if not isinstance(contract.get("experiment_id"), str) or not EXPERIMENT_ID_RE.fullmatch(contract["experiment_id"]):
        problems.append("experiment_id must use exp_<UUIDv4>")
    if not isinstance(contract.get("created_at_utc"), str) or not TIME_RE.fullmatch(contract["created_at_utc"]):
        problems.append("created_at_utc must be an ISO-UTC timestamp")
    strategy = contract.get("strategy_ref")
    if not isinstance(strategy, dict) or set(strategy) != STRATEGY_FIELDS:
        problems.append("strategy_ref must be exactly {ea_id, strategy_revision}")
    else:
        try:
            strategies = load_strategy_index(root)
            if strategy.get("ea_id") not in strategies:
                problems.append("strategy_ref.ea_id is unknown")
            elif strategies[strategy["ea_id"]] != strategy.get("strategy_revision"):
                problems.append("strategy_ref.strategy_revision does not resolve for ea_id")
        except QIValidationError as exc:
            problems.extend(exc.problems)
    if not isinstance(contract.get("experiment_type"), str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]{0,63}", contract["experiment_type"]):
        problems.append("experiment_type must be a non-empty stable token")
    problems.extend(_owner_ref_problems(contract.get("spec_ref"), "spec_ref", root))
    hypothesis = contract.get("hypothesis_revision")
    if hypothesis is not None and (not isinstance(hypothesis, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", hypothesis)):
        problems.append("hypothesis_revision must be a revision token or null")
    implementation = contract.get("implementation_ref")
    if not isinstance(implementation, dict) or set(implementation) != IMPLEMENTATION_FIELDS:
        problems.append("implementation_ref must contain exactly ex5_hash/source_hash/effective_config_hash/set_hash")
    else:
        for field in sorted(IMPLEMENTATION_FIELDS):
            problems.extend(_hash_value(implementation[field], "implementation_ref.%s" % field))
        if contract["experiment_type"] in EXECUTABLE_TYPES:
            for field in ("ex5_hash", "effective_config_hash"):
                if implementation.get(field) is None:
                    problems.append("executable experiment requires implementation_ref.%s" % field)
    refs = contract.get("parameter_refs")
    if not isinstance(refs, list):
        problems.append("parameter_refs must be an array")
    else:
        seen = set()
        try:
            pids = load_pid_index(root)
        except QIValidationError as exc:
            pids, _ = {}, problems.extend(exc.problems)
        for ref in refs:
            if not isinstance(ref, dict) or set(ref) != PARAMETER_REF_FIELDS:
                problems.append("each parameter_ref must be exactly {pid, semantic_rev}")
                continue
            pid, rev = ref["pid"], ref["semantic_rev"]
            key = (pid, rev)
            if key in seen:
                problems.append("parameter_refs contains a duplicate identity %s" % (key,))
            seen.add(key)
            if not isinstance(pid, int) or not PID_RE.fullmatch(str(pid)) or not isinstance(rev, int) or rev < 1:
                problems.append("parameter_ref identity is malformed")
            elif key not in pids:
                problems.append("parameter_ref %s does not resolve through R4 PID + semantic_rev" % (key,))
    problems.extend(_id_or_null(contract.get("supersedes_experiment_id"), EXPERIMENT_ID_RE, "supersedes_experiment_id"))
    if contract.get("supersedes_experiment_id") == contract.get("experiment_id"):
        problems.append("a contract cannot supersede itself")
    return problems


def strategy_matches_run(strategy_ref, execution_key, root=None):
    """Match an observed run to one exact, existing R4 strategy identity."""
    if (not isinstance(strategy_ref, dict) or set(strategy_ref) != STRATEGY_FIELDS or
            not isinstance(execution_key, dict)):
        return False
    expected = load_strategy_index(root)
    ea_id = strategy_ref.get("ea_id")
    if ea_id not in expected or expected[ea_id] != strategy_ref.get("strategy_revision"):
        return False
    wrapper = _capability.WRAPPER_FILE.get("LAB_ENTRY_%d" % int(ea_id[1:]))
    if not isinstance(wrapper, str) or not wrapper.lower().endswith(".mq5"):
        return False
    expected_expert = "EALabTpl\\%s" % wrapper[:-4]
    return execution_key.get("expert") == expected_expert


def validate_result(result, root=None, contract=None):
    root = _root(root)
    problems = _shape(result, RESULT_FIELDS, "ExperimentResult")
    if problems:
        return problems
    if result.get("schema_version") != 1:
        problems.append("schema_version must be 1")
    if result.get("entity") != "ExperimentResult":
        problems.append("entity must be ExperimentResult")
    if not isinstance(result.get("result_id"), str) or not RESULT_ID_RE.fullmatch(result["result_id"]):
        problems.append("result_id must use res_<UUIDv4>")
    if not isinstance(result.get("experiment_id"), str) or not EXPERIMENT_ID_RE.fullmatch(result["experiment_id"]):
        problems.append("experiment_id must use exp_<UUIDv4>")
    if not isinstance(result.get("recorded_at_utc"), str) or not TIME_RE.fullmatch(result["recorded_at_utc"]):
        problems.append("recorded_at_utc must be an ISO-UTC timestamp")
    if result.get("verdict") not in VERDICTS:
        problems.append("verdict must be one of %s; SUPERSEDED is derived" % sorted(VERDICTS))
    if not isinstance(result.get("reason_code"), str) or not REASON_RE.fullmatch(result["reason_code"]):
        problems.append("reason_code is malformed")
    problems.extend(_owner_ref_problems(result.get("reason_ref"), "reason_ref", root))
    for field in ("run_ids", "evidence_ids"):
        values = result.get(field)
        if not isinstance(values, list) or any(not isinstance(v, str) for v in values):
            problems.append("%s must be an array of strings" % field)
        elif len(values) != len(set(values)):
            problems.append("%s contains duplicate IDs" % field)
    problems.extend(_id_or_null(result.get("supersedes_result_id"), RESULT_ID_RE, "supersedes_result_id"))
    if result.get("supersedes_result_id") == result.get("result_id"):
        problems.append("a result cannot supersede itself")

    if contract is None:
        problems.append("result validation requires its canonical contract")
        return problems
    if result.get("experiment_id") != contract.get("experiment_id"):
        problems.append("result experiment_id does not match its contract")
    try:
        runs = load_run_index(root)
    except QIValidationError as exc:
        runs, _ = {}, problems.extend(exc.problems)
    try:
        evidence = load_evidence_index(root)
    except QIValidationError as exc:
        evidence, _ = {}, problems.extend(exc.problems)
    implementation = contract.get("implementation_ref", {})
    for run_id in result.get("run_ids", []) if isinstance(result.get("run_ids"), list) else []:
        observed = runs.get(run_id)
        if observed is None:
            problems.append("run_id %s does not resolve in existing run journals" % run_id)
            continue
        if implementation.get("ex5_hash") and observed.get("ex5_hash") != implementation["ex5_hash"]:
            problems.append("run %s ex5_hash does not match contract" % run_id)
        if implementation.get("effective_config_hash") and observed.get("effective_config_hash") != implementation["effective_config_hash"]:
            problems.append("run %s effective_config_hash does not match contract" % run_id)
        if not strategy_matches_run(contract.get("strategy_ref", {}), observed, root):
            problems.append("run %s is bound to a different strategy identity" % run_id)
    for evidence_id in result.get("evidence_ids", []) if isinstance(result.get("evidence_ids"), list) else []:
        if evidence_id not in evidence:
            problems.append("evidence_id %s does not resolve through evidence-manifest.jsonl" % evidence_id)
    return problems


def _read_contracts(storage_root, repo_root):
    base = _path(storage_root, "factory/experiments")
    contracts = {}
    results = {}
    if not os.path.isdir(base):
        return contracts, results
    for experiment_id in sorted(os.listdir(base)):
        directory = os.path.join(base, experiment_id)
        if not os.path.isdir(directory):
            continue
        contract_path = os.path.join(directory, "contract.json")
        if os.path.isfile(contract_path):
            contract = _json(contract_path)
            if experiment_id in contracts:
                raise QIValidationError(["duplicate experiment_id %s" % experiment_id])
            problems = validate_contract(contract, repo_root)
            if problems:
                raise QIValidationError(problems)
            if contract["experiment_id"] != experiment_id:
                raise QIValidationError(["contract path/id mismatch for %s" % experiment_id])
            contracts[experiment_id] = contract
        result_dir = os.path.join(directory, "results")
        if os.path.isdir(result_dir):
            for name in sorted(os.listdir(result_dir)):
                if not name.endswith(".json"):
                    continue
                result = _json(os.path.join(result_dir, name))
                result_id = result.get("result_id")
                if name[:-5] != result_id:
                    raise QIValidationError(["result path/id mismatch for %s" % name])
                if result.get("experiment_id") != experiment_id:
                    raise QIValidationError(["result directory/id mismatch for %s" % name])
                if result_id in results:
                    raise QIValidationError(["duplicate result_id %s" % result_id])
                results[result_id] = result
    for result_id, result in results.items():
        contract = contracts.get(result.get("experiment_id"))
        if contract is None:
            raise QIValidationError(["result %s references an unknown experiment" % result_id])
        problems = validate_result(result, repo_root, contract=contract)
        if problems:
            raise QIValidationError(problems)
    return contracts, results


def check_supersession_graph(records, id_field, supersedes_field):
    """Return a list of cycle/duplicate-link problems; no verdict is inferred."""
    by_id = {}
    problems = []
    for record in records:
        ident = record.get(id_field)
        if ident in by_id:
            problems.append("duplicate %s %s" % (id_field, ident))
        by_id[ident] = record
    for ident in by_id:
        seen = set()
        current = ident
        while current is not None:
            if current in seen:
                problems.append("supersession cycle at %s" % current)
                break
            seen.add(current)
            target = by_id.get(current, {}).get(supersedes_field)
            if target is not None and target not in by_id:
                problems.append("%s %s supersedes unknown %s" % (id_field, current, target))
                break
            current = target
    return sorted(set(problems))


def validate_store(storage_root, repo_root=None):
    repo_root = _root(repo_root)
    contracts, results = _read_contracts(storage_root, repo_root)
    problems = check_supersession_graph(list(contracts.values()), "experiment_id", "supersedes_experiment_id")
    problems.extend(check_supersession_graph(list(results.values()), "result_id", "supersedes_result_id"))
    return sorted(set(problems)), contracts, results


def _canonical_bytes(record):
    return (json.dumps(record, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _write_once(path, record, validator, storage_root, repo_root):
    problems = validator(record, repo_root)
    if problems:
        raise QIValidationError(problems)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = _canonical_bytes(record)
    if os.path.exists(path):
        with io.open(path, "rb") as handle:
            existing = handle.read()
        if existing != data:
            raise QIValidationError(["established QI record cannot be silently mutated: %s" % path])
        return False
    with io.open(path, "wb") as handle:
        handle.write(data)
    return True


def _find_result_paths(storage_root, result_id):
    base = _path(storage_root, "factory/experiments")
    paths = []
    if not os.path.isdir(base):
        return paths
    for experiment_id in sorted(os.listdir(base)):
        candidate = os.path.join(base, experiment_id, "results", result_id + ".json")
        if os.path.isfile(candidate):
            paths.append(candidate)
    return paths


def _find_result_path(storage_root, result_id):
    paths = _find_result_paths(storage_root, result_id)
    return paths[0] if paths else None


def _check_contract_supersession(contract, storage_root):
    target = contract.get("supersedes_experiment_id")
    if target is None:
        return
    path = _path(storage_root, "factory/experiments/%s/contract.json" % target)
    if not os.path.isfile(path):
        raise QIValidationError(["supersedes_experiment_id does not resolve to an established contract"])


def _check_result_supersession(result, storage_root):
    target = result.get("supersedes_result_id")
    if target is None:
        return
    path = _find_result_path(storage_root, target)
    if path is None:
        raise QIValidationError(["supersedes_result_id does not resolve to an established result"])
    prior = _json(path)
    if prior.get("experiment_id") != result.get("experiment_id"):
        raise QIValidationError(["a result may supersede only a result in the same experiment"])


def write_contract(contract, storage_root, repo_root=None):
    _check_contract_supersession(contract, storage_root)
    path = _path(storage_root, "factory/experiments/%s/contract.json" % contract.get("experiment_id", "INVALID"))
    return _write_once(path, contract, validate_contract, storage_root, repo_root or REPO_ROOT)


def write_result(result, storage_root, repo_root=None):
    repo_root = repo_root or REPO_ROOT
    contract_path = _path(storage_root, "factory/experiments/%s/contract.json" % result.get("experiment_id", "INVALID"))
    if not os.path.isfile(contract_path):
        raise QIValidationError(["cannot write a result without an established contract"])
    _check_result_supersession(result, storage_root)
    result_id = result.get("result_id", "INVALID")
    target = _path(storage_root, "factory/experiments/%s/results/%s.json" %
                   (result.get("experiment_id", "INVALID"), result_id))
    for established in _find_result_paths(storage_root, result_id):
        if os.path.normcase(os.path.abspath(established)) != os.path.normcase(os.path.abspath(target)):
            raise QIValidationError(["result_id is already established in another experiment: %s" % result_id])
    contract = _json(contract_path)
    validator = lambda value, root: validate_result(value, root, contract=contract)
    return _write_once(target, result, validator, storage_root, repo_root)


def derive_lifecycle(experiment_id, root=None):
    """Project lifecycle solely from existing event-v1 files; no lifecycle file is written."""
    root = _root(root)
    events = []
    event_root = _path(root, "docs/memory_control/experiment_events")
    for name in sorted(os.listdir(event_root)) if os.path.isdir(event_root) else []:
        if not (name.startswith("events-") and name.endswith(".jsonl")):
            continue
        for line_no, event in _jsonl(os.path.join(event_root, name)):
            if event.get("experiment_id") == experiment_id:
                events.append({"event_id": event.get("event_id"), "event_type": event.get("event_type"),
                               "timestamp_utc": event.get("timestamp_utc"), "line": line_no,
                               "path": "docs/memory_control/experiment_events/%s" % name})
    return events


def derive_registry(storage_root, repo_root=None):
    problems, contracts, results = validate_store(storage_root, repo_root)
    if problems:
        raise QIValidationError(problems)
    experiments = []
    for experiment_id in sorted(contracts):
        contract = contracts[experiment_id]
        linked = [r for r in results.values() if r["experiment_id"] == experiment_id]
        experiments.append({
            "experiment_id": experiment_id,
            "strategy_ref": copy.deepcopy(contract["strategy_ref"]),
            "experiment_type": contract["experiment_type"],
            "created_at_utc": contract["created_at_utc"],
            "supersedes_experiment_id": contract["supersedes_experiment_id"],
            "result_ids": sorted(r["result_id"] for r in linked),
            "lifecycle": derive_lifecycle(experiment_id, repo_root),
        })
    return {"schema_version": 1, "entity": "ExperimentRegistry", "experiments": experiments}


def derive_negative_memory(storage_root, repo_root=None):
    problems, _contracts, results = validate_store(storage_root, repo_root)
    if problems:
        raise QIValidationError(problems)
    return sorted(({
        "result_id": result["result_id"], "experiment_id": result["experiment_id"],
        "recorded_at_utc": result["recorded_at_utc"], "verdict": result["verdict"],
        "reason_code": result["reason_code"],
    } for result in results.values() if result["verdict"] in NEGATIVE_VERDICTS),
                   key=lambda row: (row["recorded_at_utc"], row["result_id"]))


def build_projections(storage_root, repo_root=None, output_root=None):
    """Write disposable projections only; canonical contracts/results remain the source."""
    output_root = output_root or storage_root
    target = _path(output_root, "build/quant_intelligence")
    os.makedirs(target, exist_ok=True)
    registry = derive_registry(storage_root, repo_root)
    negative = derive_negative_memory(storage_root, repo_root)
    for name, value in (("experiment_registry.json", registry), ("negative_experiment_memory.json", negative)):
        with io.open(os.path.join(target, name), "wb") as handle:
            handle.write(_canonical_bytes(value))
    return registry, negative
