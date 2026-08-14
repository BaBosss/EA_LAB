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
import subprocess
import tempfile

import candidate as _candidate
import capability as _capability
import evidence as _evidence
import run_journal_validator as _run_journal_validator


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
            if line.strip():
                try:
                    value = json.loads(line)
                except ValueError as exc:
                    raise QIValidationError(["%s:%s is not JSON: %s" % (path, line_no, exc)])
                if not isinstance(value, dict):
                    raise QIValidationError(["%s:%s authority record must be an object" % (path, line_no)])
                rows.append((line_no, value))
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


def _expected_expert(strategy_ref):
    ea_id = strategy_ref.get("ea_id") if isinstance(strategy_ref, dict) else None
    if not isinstance(ea_id, str) or not re.fullmatch(r"E01[1-8]", ea_id):
        return None
    wrapper = _capability.WRAPPER_FILE.get("LAB_ENTRY_" + ea_id[-2:])
    if not isinstance(wrapper, str) or not wrapper.endswith(".mq5"):
        return None
    return wrapper[:-4]


def _expert_matches(strategy_ref, observed):
    expected = _expected_expert(strategy_ref)
    expert = observed.get("expert") if isinstance(observed, dict) else None
    if not expected or not isinstance(expert, str):
        return False
    return re.split(r"[\\\\/]", expert)[-1] == expected


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
    """Project observed ExecutionKeys only after the canonical journal validator passes."""
    root = _root(root)
    source = _evidence.EvidenceSource("worktree", root=root)
    schema = _path(root, "_triage/factory_os/schemas.json")
    try:
        report = _run_journal_validator.validate_run_journals(source, schema)
    except _run_journal_validator.JournalInfrastructureError as exc:
        raise QIValidationError(["canonical run-journal validation is unavailable: %s" % exc])
    if not report.ok:
        raise QIValidationError(["%s:%s canonical RunTransition rejected: %s" %
                                 (row["file"], row["line"], row["detail"])
                                 for row in report.invalid_rows + report.error_rows])
    out = {}
    try:
        paths = source.list_committed("factory/runs/*.jsonl")
        for rel in sorted(paths):
            raw = source.read_committed_bytes(rel)
            for line_no, line in enumerate(raw.decode("utf-8-sig").splitlines(), 1):
                if not line.strip():
                    continue
                row = json.loads(line)
                if row.get("entity") != "RunTransition":
                    raise QIValidationError(["%s:%s canonical RunTransition projection is invalid" %
                                             (rel, line_no)])
                run_id, key = row.get("run_id"), row.get("execution_key")
                if key is None:
                    continue
                if not isinstance(run_id, str) or not isinstance(key, dict):
                    raise QIValidationError(["%s:%s canonical RunTransition has no readable ExecutionKey" %
                                             (rel, line_no)])
                if run_id in out and out[run_id] != key:
                    raise QIValidationError(["run_id %s has conflicting observed identities" % run_id])
                out[run_id] = key
    except (_evidence.ToolFailure, UnicodeDecodeError, ValueError) as exc:
        raise QIValidationError(["canonical run-journal projection failed: %s" % exc])
    return out


def _event_authority_snapshot(root=None):
    """Ask the canonical event utility to validate before QI derives any projection."""
    root = _root(root)
    utility = _path(REPO_ROOT, "scripts/experiment_event_log.ps1")
    if not os.path.isfile(utility):
        raise QIValidationError(["canonical event validator is unavailable: %s" % utility])
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", utility,
               "-Command", "Scan", "-RepoRoot", root]
    try:
        proc = subprocess.run(command, capture_output=True, text=True)
    except OSError as exc:
        raise QIValidationError(["canonical event validator cannot run: %s" % exc])
    if proc.returncode != 0:
        detail = ((proc.stdout or "") + "\n" + (proc.stderr or "")).strip()
        raise QIValidationError(["canonical event authority rejected: %s" % detail[:2000]])

    authority = _path(root, "docs/memory_control/experiment_events")
    evidence = {}
    manifest = os.path.join(authority, "evidence-manifest.jsonl")
    try:
        for _line_no, row in _jsonl(manifest):
            evidence_id = row.get("evidence_id")
            if evidence_id in evidence:
                raise QIValidationError(["evidence manifest duplicates %s" % evidence_id])
            evidence[evidence_id] = row
        events = []
        for name in sorted(os.listdir(authority)):
            if name.startswith("events-") and name.endswith(".jsonl"):
                events.extend(row for _line_no, row in _jsonl(os.path.join(authority, name)))
    except (IOError, OSError, ValueError) as exc:
        raise QIValidationError(["canonical event projection failed: %s" % exc])
    return evidence, events


def load_evidence_index(root=None):
    """Return manifest IDs after canonical event/evidence authority validation."""
    evidence, _events = _event_authority_snapshot(root)
    return evidence


def load_evidence_lineage(root=None):
    """Return canonical event records by evidence ID; never creates an authority store."""
    _evidence_index, events = _event_authority_snapshot(root)
    lineage = {}
    for event in events:
        for evidence_id in event.get("evidence_ids", []):
            lineage.setdefault(evidence_id, []).append(event)
    return lineage


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
    if (not isinstance(contract.get("experiment_type"), str) or
            contract.get("experiment_type") not in EXECUTABLE_TYPES):
        problems.append("experiment_type must be one of %s" % sorted(EXECUTABLE_TYPES))
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
        if (isinstance(contract.get("experiment_type"), str) and
                contract["experiment_type"] in EXECUTABLE_TYPES):
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


def _run_matches_implementation(implementation, execution_key):
    """Compare only immutable implementation facts shared by Contract and ExecutionKey."""
    if not isinstance(implementation, dict) or not isinstance(execution_key, dict):
        return False
    for field in ("ex5_hash", "effective_config_hash"):
        if execution_key.get(field) != implementation.get(field):
            return False
    if implementation.get("set_hash") is not None and execution_key.get("set_hash") != implementation["set_hash"]:
        return False
    # Current ExecutionKey has no source_hash.  Do not infer one from filenames or catalog state.
    if (implementation.get("source_hash") is not None and
            execution_key.get("source_hash") is not None and
            execution_key["source_hash"] != implementation["source_hash"]):
        return False
    return True


def _result_linked_event_matches_run(event, execution_key):
    """Require one direct, shared artifact identity; absent dimensions are never inferred."""
    artifacts = event.get("artifact_hashes") if isinstance(event, dict) else None
    if not isinstance(artifacts, dict) or not isinstance(execution_key, dict):
        return False
    shared = 0
    for event_field, run_field in (("ea", "ex5_hash"), ("set", "set_hash")):
        event_value = artifacts.get(event_field)
        run_value = execution_key.get(run_field)
        if event_value is not None and run_value is not None:
            shared += 1
            if event_value != run_value:
                return False
    return shared > 0


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
    executable = contract.get("experiment_type") in EXECUTABLE_TYPES
    run_ids = result.get("run_ids") if isinstance(result.get("run_ids"), list) else []
    if executable and not run_ids:
        problems.append("executable result requires at least one run_id")
    try:
        runs = load_run_index(root)
    except QIValidationError as exc:
        runs, _ = {}, problems.extend(exc.problems)
    try:
        evidence = load_evidence_index(root)
    except QIValidationError as exc:
        evidence, _ = {}, problems.extend(exc.problems)
    try:
        evidence_lineage = load_evidence_lineage(root)
    except QIValidationError as exc:
        evidence_lineage, _ = {}, problems.extend(exc.problems)
    implementation = contract.get("implementation_ref", {})
    observed_runs = []
    for run_id in run_ids:
        observed = runs.get(run_id)
        if observed is None:
            problems.append("run_id %s does not resolve in existing run journals" % run_id)
            continue
        if not _expert_matches(contract.get("strategy_ref"), observed):
            problems.append("run %s expert does not exactly match contract strategy wrapper" % run_id)
            continue
        if not _run_matches_implementation(implementation, observed):
            problems.append("run %s implementation identity does not match contract" % run_id)
            continue
        observed_runs.append(observed)
    for evidence_id in result.get("evidence_ids", []) if isinstance(result.get("evidence_ids"), list) else []:
        if evidence_id not in evidence:
            problems.append("evidence_id %s does not resolve through evidence-manifest.jsonl" % evidence_id)
            continue
        events = evidence_lineage.get(evidence_id, [])
        if {event.get("experiment_id") for event in events} != {contract.get("experiment_id")}:
            problems.append("evidence_id %s is not bound only to this experiment event lineage" % evidence_id)
            continue
        linked = [event for event in events if event.get("event_type") == "RESULT_LINKED"]
        if not linked:
            problems.append("evidence_id %s has no canonical RESULT_LINKED lineage" % evidence_id)
        elif executable and not any(_result_linked_event_matches_run(event, observed)
                                    for event in linked for observed in observed_runs):
            problems.append("evidence_id %s cannot be tied to a referenced run artifact identity" % evidence_id)
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
    fd, temporary = tempfile.mkstemp(prefix=".qi1-write-", suffix=".tmp",
                                     dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        try:
            os.link(temporary, path)
            return True
        except FileExistsError:
            with io.open(path, "rb") as handle:
                existing = handle.read()
            if existing != data:
                raise QIValidationError(["established QI record cannot be silently mutated: %s" % path])
            return False
    finally:
        try:
            os.unlink(temporary)
        except OSError:
            pass


def _acquire_store_lock(storage_root):
    lock = _path(storage_root, "factory/experiments/.qi1.lock")
    os.makedirs(os.path.dirname(lock), exist_ok=True)
    try:
        fd = os.open(lock, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    except FileExistsError:
        raise QIValidationError(["QI-1 store is busy; refusing concurrent mutation"])
    return lock, fd


def _release_store_lock(lock, fd):
    try:
        os.close(fd)
    finally:
        try:
            os.unlink(lock)
        except OSError:
            pass


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
    lock, fd = _acquire_store_lock(storage_root)
    try:
        repo_root = repo_root or REPO_ROOT
        store_problems, _contracts, _results = validate_store(storage_root, repo_root)
        if store_problems:
            raise QIValidationError(store_problems)
        _check_contract_supersession(contract, storage_root)
        path = _path(storage_root, "factory/experiments/%s/contract.json" % contract.get("experiment_id", "INVALID"))
        return _write_once(path, contract, validate_contract, storage_root, repo_root)
    finally:
        _release_store_lock(lock, fd)


def write_result(result, storage_root, repo_root=None):
    lock, fd = _acquire_store_lock(storage_root)
    try:
        repo_root = repo_root or REPO_ROOT
        store_problems, contracts, _results = validate_store(storage_root, repo_root)
        if store_problems:
            raise QIValidationError(store_problems)
        contract = contracts.get(result.get("experiment_id"))
        if contract is None:
            raise QIValidationError(["cannot write a result without an established contract"])
        if contract.get("experiment_id") != result.get("experiment_id"):
            raise QIValidationError(["stored contract/result experiment_id mismatch"])
        _check_result_supersession(result, storage_root)
        result_id = result.get("result_id", "INVALID")
        target = _path(storage_root, "factory/experiments/%s/results/%s.json" %
                       (result.get("experiment_id", "INVALID"), result_id))
        for established in _find_result_paths(storage_root, result_id):
            if os.path.normcase(os.path.abspath(established)) != os.path.normcase(os.path.abspath(target)):
                raise QIValidationError(["result_id is already established in another experiment: %s" % result_id])
        validator = lambda value, root: validate_result(value, root, contract=contract)
        return _write_once(target, result, validator, storage_root, repo_root)
    finally:
        _release_store_lock(lock, fd)


def derive_lifecycle(experiment_id, root=None):
    """Project lifecycle solely from existing event-v1 files; no lifecycle file is written."""
    _evidence_index, events = _event_authority_snapshot(root)
    return [{"event_id": event.get("event_id"), "event_type": event.get("event_type"),
             "timestamp_utc": event.get("timestamp_utc")}
            for event in events if event.get("experiment_id") == experiment_id]


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
