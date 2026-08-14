# -*- coding: utf-8 -*-
"""QI-1 deterministic and adversarial cage.

The tests exercise the public QI-1 validator/projection seams.  They intentionally
use a real repository root for pinned OwnerRefs and existing run/evidence facts,
while all durable QI records are written only into temporary directories.
"""
import concurrent.futures
import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
from contextlib import contextmanager

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import qi_1 as qi  # noqa: E402


def check(label, condition, detail=""):
    if condition:
        print("[PASS] " + label)
        return 0
    print("[FAIL] " + label + (": " + str(detail) if detail else ""))
    return 1


def git(*args):
    return subprocess.check_output(["git", "-C", ROOT] + list(args)).decode("ascii").strip()


def owner_ref(path, owner_type="taskboard_order"):
    commit = git("rev-parse", "HEAD")
    blob = git("rev-parse", "%s:%s" % (commit, path))
    raw = subprocess.check_output(["git", "-C", ROOT, "cat-file", "blob", blob])
    return {"entity": "OwnerRef", "owner_type": owner_type, "path": path,
            "commit_oid": commit, "blob_oid": blob,
            "raw_sha256": hashlib.sha256(raw).hexdigest()}


def valid_contract(run):
    observed = run
    return {
        "schema_version": 1,
        "entity": "ExperimentContract",
        "experiment_id": "exp_93d9457a-4857-438e-99af-370def7a8392",
        "created_at_utc": "2026-08-13T00:00:00Z",
        "strategy_ref": {"ea_id": "E014", "strategy_revision": 1},
        "experiment_type": "EA_EXECUTABLE",
        "spec_ref": owner_ref("AGENT_TASKBOARD.md"),
        "hypothesis_revision": None,
        "implementation_ref": {
            "ex5_hash": observed["ex5_hash"],
            "source_hash": None,
            "effective_config_hash": observed["effective_config_hash"],
            "set_hash": observed["set_hash"],
        },
        "parameter_refs": [{"pid": 11000, "semantic_rev": 1}],
        "supersedes_experiment_id": None,
    }


def valid_result(contract, run_id, evidence_id):
    return {
        "schema_version": 1,
        "entity": "ExperimentResult",
        "result_id": "res_12345678-1234-4234-8234-1234567890ab",
        "experiment_id": contract["experiment_id"],
        "recorded_at_utc": "2026-08-13T00:01:00Z",
        "run_ids": [] if run_id is None else [run_id],
        "evidence_ids": [evidence_id],
        "verdict": "INCONCLUSIVE",
        "reason_code": "insufficient_forward_evidence",
        "reason_ref": owner_ref("AGENT_TASKBOARD.md"),
        "supersedes_result_id": None,
    }


def result_linked_artifacts():
    path = os.path.join(ROOT, "docs", "memory_control", "experiment_events", "events-2026-07.jsonl")
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            row = json.loads(line)
            if row.get("event_type") == "RESULT_LINKED":
                return row["artifact_hashes"]
    raise RuntimeError("canonical fixture has no RESULT_LINKED event")


def canonical_execution_key(artifacts, ex5_hash=None):
    return {
        "expert": "EALabTpl\\Boss_14_GridLog",
        "symbol": "XAUUSD", "tf": "H1", "from_date": "2024.01.02", "to_date": "2024.01.16",
        "model": 1, "deposit": 10000, "currency": "USD", "account_unit": "USD",
        "leverage": 100, "terminal_build": 0, "set_hash": artifacts["set"],
        "ex5_hash": ex5_hash or artifacts["ea"],
        "effective_config_hash": "0" * 64,
        "data_fingerprint": "synthetic canonical QI-1 authority", "lane": "synthetic",
    }


@contextmanager
def authority_fixture(execution_key=None, mutate_event=None):
    """A complete authority fixture: QI reads only canonical validator-approved bytes."""
    with tempfile.TemporaryDirectory(prefix="qi1-authority-") as root:
        authority = os.path.join(root, "docs", "memory_control", "experiment_events")
        shutil.copytree(os.path.join(ROOT, "docs", "memory_control", "experiment_events"), authority)
        os.makedirs(os.path.join(root, "factory", "runs"))
        shutil.copyfile(os.path.join(ROOT, "factory", "strategy_catalog.json"),
                        os.path.join(root, "factory", "strategy_catalog.json"))
        triage = os.path.join(root, "_triage", "factory_os")
        os.makedirs(triage)
        for name in ("schemas.json", "EA_TEMPLATE_PID_ALLOCATION_V1_R4_FINAL.json"):
            shutil.copyfile(os.path.join(ROOT, "_triage", "factory_os", name), os.path.join(triage, name))
        if mutate_event:
            path = os.path.join(authority, "events-2026-07.jsonl")
            with open(path, encoding="utf-8") as handle:
                rows = [json.loads(line) for line in handle if line.strip()]
            mutate_event(rows)
            with open(path, "w", encoding="utf-8", newline="\n") as handle:
                for row in rows:
                    handle.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n")
        key = execution_key or canonical_execution_key(result_linked_artifacts())
        row = {"entity": "RunTransition", "run_id": "RUN-20990101-001", "cell_id": "QI-1",
               "execution_key": key, "attempt": 1, "transition": "QUEUED",
               "at": "2099-01-01T00:00:00Z"}
        with open(os.path.join(root, "factory", "runs", "RUN-20990101-001.jsonl"), "w",
                  encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(row, separators=(",", ":")) + "\n")
        subprocess.check_call(["git", "-C", root, "init", "-q"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        objects = git("rev-parse", "--path-format=absolute", "--git-path", "objects")
        alternates = os.path.join(root, ".git", "objects", "info", "alternates")
        os.makedirs(os.path.dirname(alternates), exist_ok=True)
        with open(alternates, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(objects.replace("\\", "/") + "\n")
        yield root


def _refused(call):
    try:
        call()
    except qi.QIValidationError:
        return True
    return False


def _reverse_last_event(rows):
    rows[-1] = dict(reversed(list(rows[-1].items())))


def _event_lifecycle_loader(root):
    return qi.derive_lifecycle("exp_93d9457a-4857-438e-99af-370def7a8392", root)


def main():
    failures = 0
    artifacts = result_linked_artifacts()
    evidence_id = "evd_sha256_092b3189c504570708f91b4bb2d48fe3119f04396f515299d34d728db03622de"
    with authority_fixture() as authority:
        runs = qi.load_run_index(authority)
        run_id = "RUN-20990101-001"
        run = runs[run_id]
        contract = valid_contract(run)
        result = valid_result(contract, run_id, evidence_id)

        failures += check("canonical run journal is projected after validator PASS", run_id in runs)
        failures += check("E011-E018 resolve with strategy_revision=1",
                          qi.load_strategy_index(ROOT) == {"E0%s" % i: 1 for i in range(11, 19)})
        failures += check("valid Contract strategy identity validates", not qi.validate_contract(contract, ROOT))
        failures += check("schema-valid run plus matching Contract/Event evidence validates",
                          not qi.validate_result(result, authority, contract=contract))
        failures += check("canonical OwnerRef vocabulary rejects preregistration",
                          qi.validate_contract(dict(contract, spec_ref=owner_ref(
                              "AGENT_TASKBOARD.md", owner_type="preregistration")), ROOT))
        for field in ("ex5_hash", "effective_config_hash"):
            bad = copy.deepcopy(contract)
            bad["implementation_ref"][field] = "f" * 64
            failures += check("run %s mismatch is rejected" % field,
                              qi.validate_result(result, authority, contract=bad))
        failures += check("executable result with run_ids=[] is rejected",
                          qi.validate_result(valid_result(contract, None, evidence_id), authority,
                                             contract=contract))
        failures += check("unknown run is rejected",
                          qi.validate_result(dict(result, run_ids=["RUN-20990101-999"]), authority,
                                             contract=contract))
        unknown = copy.deepcopy(contract)
        unknown["strategy_ref"]["strategy_revision"] = 2
        failures += check("unknown Contract strategy revision is rejected", qi.validate_contract(unknown, ROOT))
        custom = copy.deepcopy(contract)
        custom["experiment_type"] = "CUSTOM_EXECUTION"
        failures += check("unknown experiment type is rejected", qi.validate_contract(custom, ROOT))
        bad_evidence = copy.deepcopy(result)
        bad_evidence["evidence_ids"] = ["evd_sha256_" + "0" * 64]
        failures += check("unresolved evidence is rejected",
                          qi.validate_result(bad_evidence, authority, contract=contract))
        cross = copy.deepcopy(contract)
        cross["experiment_id"] = "exp_abcdefab-cdef-4abc-8def-abcdefabcdef"
        failures += check("cross-experiment evidence is rejected",
                          qi.validate_result(valid_result(cross, run_id, evidence_id), authority,
                                             contract=cross))

        with authority_fixture(canonical_execution_key(artifacts, ex5_hash="1" * 64)) as mismatch:
            mismatch_run = qi.load_run_index(mismatch)[run_id]
            mismatch_contract = valid_contract(mismatch_run)
            failures += check("RESULT_LINKED artifact inconsistent with every run is rejected",
                              qi.validate_result(valid_result(mismatch_contract, run_id, evidence_id),
                                                 mismatch, contract=mismatch_contract))

        with tempfile.TemporaryDirectory(prefix="qi1-store-") as store:
            qi.write_contract(contract, store, repo_root=authority)
            stored = os.path.join(store, "factory", "experiments", contract["experiment_id"], "contract.json")
            invalid = copy.deepcopy(contract)
            invalid["experiment_type"] = "CUSTOM_EXECUTION"
            with open(stored, "wb") as handle:
                handle.write(qi._canonical_bytes(invalid))
            failures += check("invalid stored Contract blocks Result write",
                              _write_refused(result, store, authority, qi.write_result))
            failures += check("invalid stored Contract created no Result",
                              not os.path.isdir(os.path.join(os.path.dirname(stored), "results")))

    with authority_fixture(dict(canonical_execution_key(artifacts), strategy_ref={"ea_id": "E014", "strategy_revision": 1})) as fake:
        failures += check("fake ExecutionKey.strategy_ref is rejected by canonical validator",
                          _refused(lambda: qi.load_run_index(fake)))
    with authority_fixture() as invalid_run:
        path = os.path.join(invalid_run, "factory", "runs", "RUN-20990101-001.jsonl")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write('{"entity":"RunTransition"}\n')
        failures += check("structurally invalid RunTransition is rejected",
                          _refused(lambda: qi.load_run_index(invalid_run)))
    failures += check("forged event owner_ref is rejected by canonical event validator",
                      _mutated_authority_refused(
                          "events-2026-07.jsonl",
                          lambda rows: rows[-1]["owner_refs"][0].update(raw_sha256="0" * 64),
                          qi.load_evidence_lineage))
    failures += check("noncanonical event encoding is rejected by canonical event validator",
                      _mutated_authority_refused(
                          "events-2026-07.jsonl", _reverse_last_event, qi.load_evidence_lineage))
    failures += check("bogus event type is rejected by canonical event validator",
                      _mutated_authority_refused(
                          "events-2026-07.jsonl",
                          lambda rows: rows[-1].update(event_type="BOGUS"), _event_lifecycle_loader))

    print("QI-1 TESTS: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
    return 0 if failures == 0 else 1


def _overwrite_refused(path, contract, storage_root, repo_root):
    changed = copy.deepcopy(contract)
    changed["experiment_type"] = "ANALYSIS"
    try:
        qi.write_contract(changed, storage_root, repo_root=repo_root)
    except qi.QIValidationError:
        return True
    return False


def _write_refused(record, storage_root, repo_root, writer):
    try:
        writer(record, storage_root, repo_root=repo_root)
    except qi.QIValidationError:
        return True
    return False


def _jsonl_refused(path):
    try:
        qi._jsonl(path)
    except qi.QIValidationError:
        return True
    return False


def _corrupt_authority_refused(schema_name, data_name, row, loader):
    with tempfile.TemporaryDirectory(prefix="qi1-authority-") as root:
        authority = os.path.join(root, "docs", "memory_control", "experiment_events")
        schema_dir = os.path.join(authority, "schema")
        os.makedirs(schema_dir)
        shutil.copyfile(os.path.join(ROOT, "docs", "memory_control", "experiment_events",
                                     "schema", schema_name),
                        os.path.join(schema_dir, schema_name))
        with open(os.path.join(authority, data_name), "w", encoding="utf-8") as handle:
            handle.write(json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n")
        try:
            loader(root)
        except qi.QIValidationError:
            return True
        return False


def _mutated_authority_refused(data_name, mutate, loader):
    with tempfile.TemporaryDirectory(prefix="qi1-authority-mutation-") as root:
        source = os.path.join(ROOT, "docs", "memory_control", "experiment_events")
        authority = os.path.join(root, "docs", "memory_control", "experiment_events")
        shutil.copytree(source, authority)
        subprocess.check_call(["git", "-C", root, "init", "-q"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        objects = git("rev-parse", "--path-format=absolute", "--git-path", "objects")
        alternates = os.path.join(root, ".git", "objects", "info", "alternates")
        os.makedirs(os.path.dirname(alternates), exist_ok=True)
        with open(alternates, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(objects.replace("\\", "/") + "\n")
        path = os.path.join(authority, data_name)
        with open(path, encoding="utf-8") as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
        mutate(rows)
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            for row in rows:
                handle.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n")
        try:
            loader(root)
        except qi.QIValidationError:
            return True
        return False


def _atomic_visibility_preserved(contract):
    with tempfile.TemporaryDirectory(prefix="qi1-atomic-") as root:
        entered = threading.Event()
        release = threading.Event()
        original = qi.os.fdopen

        class DelayedFile(object):
            def __init__(self, inner):
                self.inner = inner

            def __enter__(self):
                entered.set()
                release.wait(5)
                return self.inner

            def __exit__(self, *args):
                return self.inner.__exit__(*args)

        qi.os.fdopen = lambda fd, *args, **kwargs: DelayedFile(original(fd, *args, **kwargs))
        outcome = []

        def writer():
            try:
                outcome.append(qi.write_contract(contract, root, repo_root=ROOT))
            except Exception as exc:  # pragma: no cover - reported by the assertion below
                outcome.append(exc)

        thread = threading.Thread(target=writer)
        thread.start()
        entered.wait(5)
        target = os.path.join(root, "factory", "experiments", contract["experiment_id"],
                              "contract.json")
        hidden = not os.path.exists(target)
        release.set()
        thread.join(5)
        qi.os.fdopen = original
        return hidden and outcome == [True] and os.path.isfile(target)


def _competing_writes_refused(contract):
    with tempfile.TemporaryDirectory(prefix="qi1-competing-") as root:
        first = copy.deepcopy(contract)
        second = copy.deepcopy(contract)
        second["hypothesis_revision"] = "competitor"
        barrier = threading.Barrier(2)

        def attempt(value):
            barrier.wait()
            try:
                return ("accepted", qi.write_contract(value, root, repo_root=ROOT))
            except qi.QIValidationError:
                return ("refused", False)

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            outcomes = list(pool.map(attempt, (first, second)))
        target = os.path.join(root, "factory", "experiments", contract["experiment_id"],
                              "contract.json")
        with open(target, "rb") as handle:
            stored = handle.read()
        accepted = sum(state == "accepted" and value is True for state, value in outcomes)
        return accepted == 1 and stored in (qi._canonical_bytes(first), qi._canonical_bytes(second))


if __name__ == "__main__":
    sys.exit(main())
