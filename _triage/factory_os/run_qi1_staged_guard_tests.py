# -*- coding: utf-8 -*-
"""Adversarial cage for the QI-1 staged append-only guard."""
import copy
import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import qi_1 as qi  # noqa: E402


PYTHON = os.path.join(ROOT, "tools", "python312", "python.exe")
GUARD = os.path.join(HERE, "qi1_staged_guard.py")
RUN_ID = "RUN-20990101-001"
EVIDENCE_ID = "evd_sha256_092b3189c504570708f91b4bb2d48fe3119f04396f515299d34d728db03622de"
BASE_EXP = "exp_93d9457a-4857-438e-99af-370def7a8392"
BASE_RESULT = "res_12345678-1234-4234-8234-1234567890ab"


def run_git(root, *args):
    return subprocess.check_output(["git", "-C", root] + list(args), stderr=subprocess.STDOUT).decode("utf-8").strip()


def run_git_quiet(root, *args):
    subprocess.check_call(["git", "-C", root] + list(args), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def write_json(path, value):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with io.open(path, "wb") as handle:
        handle.write(qi._canonical_bytes(value))


def copy_authority(root):
    files = [
        "AGENT_TASKBOARD.md",
        "factory/strategy_catalog.json",
        "docs/memory_control/experiment_events/evidence-manifest.jsonl",
        "docs/memory_control/experiment_events/events-2026-07.jsonl",
        "docs/memory_control/experiment_events/schema/event-v1.schema.json",
        "docs/memory_control/experiment_events/schema/evidence-v1.schema.json",
        "_triage/factory_os/schemas.json",
        "_triage/factory_os/EA_TEMPLATE_PID_ALLOCATION_V1_R4_FINAL.json",
    ]
    for rel in files:
        source = os.path.join(ROOT, rel.replace("/", os.sep))
        target = os.path.join(root, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copyfile(source, target)
    with open(os.path.join(ROOT, "docs", "memory_control", "experiment_events", "events-2026-07.jsonl"), encoding="utf-8") as handle:
        event = next(json.loads(line) for line in handle if json.loads(line).get("event_type") == "RESULT_LINKED")
    artifacts = event["artifact_hashes"]
    key = {"expert": "EALabTpl\\Boss_14_GridLog", "symbol": "XAUUSD", "tf": "H1",
           "from_date": "2024.01.02", "to_date": "2024.01.16", "model": 1, "deposit": 10000,
           "currency": "USD", "account_unit": "USD", "leverage": 100, "terminal_build": 0,
           "set_hash": artifacts["set"], "ex5_hash": artifacts["ea"],
           "effective_config_hash": "0" * 64, "data_fingerprint": "QI-1 staged fixture", "lane": "fixture"}
    row = {"entity": "RunTransition", "run_id": RUN_ID, "cell_id": "QI-1", "execution_key": key,
           "attempt": 1, "transition": "QUEUED", "at": "2099-01-01T00:00:00Z"}
    path = os.path.join(root, "factory", "runs", RUN_ID + ".jsonl")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(row, separators=(",", ":")) + "\n")


def owner_ref(root):
    commit = run_git(root, "rev-parse", "HEAD")
    blob = run_git(root, "rev-parse", "HEAD:AGENT_TASKBOARD.md")
    raw = subprocess.check_output(["git", "-C", root, "cat-file", "blob", blob])
    return {"entity": "OwnerRef", "owner_type": "taskboard_order", "path": "AGENT_TASKBOARD.md",
            "commit_oid": commit, "blob_oid": blob,
            "raw_sha256": hashlib.sha256(raw).hexdigest()}


def hydrate_evidence_objects(root):
    objects = run_git(ROOT, "rev-parse", "--path-format=absolute", "--git-path", "objects")
    alternates = os.path.join(root, ".git", "objects", "info", "alternates")
    os.makedirs(os.path.dirname(alternates), exist_ok=True)
    with io.open(alternates, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(objects.replace("\\", "/") + "\n")


def make_contract(root, experiment_id=BASE_EXP):
    run = qi.load_run_index(root)[RUN_ID]
    return {
        "schema_version": 1, "entity": "ExperimentContract", "experiment_id": experiment_id,
        "created_at_utc": "2026-08-13T00:00:00Z",
        "strategy_ref": {"ea_id": "E014", "strategy_revision": 1},
        "experiment_type": "EA_EXECUTABLE", "spec_ref": owner_ref(root),
        "hypothesis_revision": None,
        "implementation_ref": {"ex5_hash": run["ex5_hash"], "source_hash": None,
                                "effective_config_hash": run["effective_config_hash"],
                                "set_hash": run["set_hash"]},
        "parameter_refs": [{"pid": 11000, "semantic_rev": 1}],
        "supersedes_experiment_id": None,
    }


def make_result(root, contract, result_id=BASE_RESULT, supersedes=None):
    return {
        "schema_version": 1, "entity": "ExperimentResult", "result_id": result_id,
        "experiment_id": contract["experiment_id"], "recorded_at_utc": "2026-08-13T00:01:00Z",
        "run_ids": [RUN_ID], "evidence_ids": [EVIDENCE_ID], "verdict": "INCONCLUSIVE",
        "reason_code": "insufficient_forward_evidence", "reason_ref": owner_ref(root),
        "supersedes_result_id": supersedes,
    }


def fixture(with_result=True):
    temp = tempfile.TemporaryDirectory(prefix="qi1-guard-fixture-")
    root = temp.name
    copy_authority(root)
    run_git_quiet(root, "init", "-q")
    run_git_quiet(root, "config", "user.email", "qi1-tests@example.invalid")
    run_git_quiet(root, "config", "user.name", "QI-1 tests")
    hydrate_evidence_objects(root)
    run_git_quiet(root, "add", ".")
    run_git_quiet(root, "commit", "-qm", "authority")
    contract = make_contract(root)
    qi.write_contract(contract, root, repo_root=root)
    result = make_result(root, contract) if with_result else None
    if result:
        qi.write_result(result, root, repo_root=root)
    run_git_quiet(root, "add", "factory/experiments")
    run_git_quiet(root, "commit", "-qm", "baseline QI records")
    return temp, root, contract, result


def guard(root):
    completed = subprocess.run([PYTHON, GUARD, root], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    return completed.returncode, completed.stdout


def check(label, condition, detail=""):
    if condition:
        print("[PASS] " + label)
        return 0
    print("[FAIL] " + label + (": " + detail if detail else ""))
    return 1


def main():
    failures = 0

    temp, root, contract, result = fixture()
    try:
        changed = copy.deepcopy(contract)
        changed["experiment_type"] = "ANALYSIS"
        write_json(os.path.join(root, "factory", "experiments", BASE_EXP, "contract.json"), changed)
        run_git_quiet(root, "add", "factory/experiments")
        code, output = guard(root)
        failures += check("staged contract modification is rejected", code != 0 and "modified" in output)
    finally:
        temp.cleanup()

    temp, root, contract, result = fixture()
    try:
        changed = copy.deepcopy(result)
        changed["verdict"] = "REJECTED"
        write_json(os.path.join(root, "factory", "experiments", BASE_EXP, "results", BASE_RESULT + ".json"), changed)
        run_git_quiet(root, "add", "factory/experiments")
        code, output = guard(root)
        failures += check("staged result modification is rejected", code != 0 and "modified" in output)
    finally:
        temp.cleanup()

    temp, root, contract, result = fixture()
    try:
        os.remove(os.path.join(root, "factory", "experiments", BASE_EXP, "contract.json"))
        run_git_quiet(root, "add", "-u", "factory/experiments")
        code, output = guard(root)
        failures += check("staged contract deletion is rejected", code != 0 and "deleted" in output)
    finally:
        temp.cleanup()

    temp, root, contract, result = fixture()
    try:
        os.remove(os.path.join(root, "factory", "experiments", BASE_EXP, "results", BASE_RESULT + ".json"))
        run_git_quiet(root, "add", "-u", "factory/experiments")
        code, output = guard(root)
        failures += check("staged result deletion is rejected", code != 0 and "deleted" in output)
    finally:
        temp.cleanup()

    temp, root, contract, result = fixture()
    try:
        added = make_result(root, contract,
                            result_id="res_abcdefab-cdef-4abc-8def-abcdefabcdef")
        qi.write_result(added, root, repo_root=root)
        run_git_quiet(root, "add", "factory/experiments")
        code, output = guard(root)
        failures += check("new valid result is accepted", code == 0, output)
    finally:
        temp.cleanup()

    temp, root, contract, result = fixture()
    try:
        added = make_result(root, contract,
                            result_id="res_abcdefab-cdef-4abc-8def-abcdefabcdef",
                            supersedes=BASE_RESULT)
        qi.write_result(added, root, repo_root=root)
        run_git_quiet(root, "add", "factory/experiments")
        code, output = guard(root)
        failures += check("new valid superseding result is accepted", code == 0, output)
    finally:
        temp.cleanup()

    temp, root, contract, result = fixture()
    try:
        second_id = "exp_abcdefab-cdef-4abc-8def-abcdefabcdef"
        second = make_contract(root, second_id)
        qi.write_contract(second, root, repo_root=root)
        duplicate = make_result(root, second, result_id=BASE_RESULT)
        write_json(os.path.join(root, "factory", "experiments", second_id, "results", BASE_RESULT + ".json"), duplicate)
        run_git_quiet(root, "add", "factory/experiments")
        code, output = guard(root)
        failures += check("staged whole-store duplicate result_id is rejected",
                          code != 0 and "duplicate result_id" in output)
    finally:
        temp.cleanup()

    print("QI-1 STAGED GUARD TESTS: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
