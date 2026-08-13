# -*- coding: utf-8 -*-
"""QI-1 deterministic and adversarial cage.

The tests exercise the public QI-1 validator/projection seams.  They intentionally
use a real repository root for pinned OwnerRefs and existing run/evidence facts,
while all durable QI records are written only into temporary directories.
"""
import copy
import hashlib
import os
import subprocess
import sys
import tempfile

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
        "experiment_id": "exp_12345678-1234-4234-8234-1234567890ab",
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
        "run_ids": [run_id],
        "evidence_ids": [evidence_id],
        "verdict": "INCONCLUSIVE",
        "reason_code": "insufficient_forward_evidence",
        "reason_ref": owner_ref("AGENT_TASKBOARD.md"),
        "supersedes_result_id": None,
    }


def main():
    failures = 0
    with tempfile.TemporaryDirectory(prefix="qi1-cage-") as tmp:
        store = os.path.join(tmp, "factory", "experiments")
        os.makedirs(store)
        runs = qi.load_run_index(ROOT)
        run = runs["RUN-20260802-001"]
        evidence_id = "evd_sha256_092b3189c504570708f91b4bb2d48fe3119f04396f515299d34d728db03622de"
        contract = valid_contract(run)
        result = valid_result(contract, "RUN-20260802-001", evidence_id)

        failures += check("E011-E018 resolve with strategy_revision=1",
                          qi.load_strategy_index(ROOT) ==
                          {"E0%s" % i: 1 for i in range(11, 19)})
        failures += check("valid contract validates",
                          not qi.validate_contract(contract, ROOT))
        failures += check("canonical taskboard_order OwnerRef is accepted",
                          not qi._owner_ref_problems(contract["spec_ref"], "spec_ref", ROOT))
        bad = copy.deepcopy(contract)
        bad["spec_ref"] = owner_ref("AGENT_TASKBOARD.md", owner_type="preregistration")
        failures += check("non-canonical OwnerRef owner_type is rejected",
                          qi.validate_contract(bad, ROOT))
        bad = copy.deepcopy(contract)
        bad["spec_ref"]["raw_sha256"] = "0" * 64
        failures += check("malformed/unresolvable OwnerRef is rejected",
                          qi.validate_contract(bad, ROOT))
        bad = copy.deepcopy(contract)
        bad["spec_ref"]["anchor"] = 17
        failures += check("OwnerRef anchor type is schema-validated",
                          qi.validate_contract(bad, ROOT))
        failures += check("unknown contract field is rejected",
                          qi.validate_contract(dict(contract, extra="nope"), ROOT))
        failures += check("valid result validates and evidence resolves",
                          not qi.validate_result(result, ROOT, contract=contract))
        failures += check("result metrics are rejected",
                          qi.validate_result(dict(result, metrics={"pf": 2.0}), ROOT,
                                             contract=contract))
        failures += check("SUPERSEDED is not a stored verdict",
                          qi.validate_result(dict(result, verdict="SUPERSEDED"), ROOT,
                                             contract=contract))

        bad = copy.deepcopy(contract)
        bad["strategy_ref"]["ea_id"] = "E999"
        failures += check("unknown ea_id is rejected", qi.validate_contract(bad, ROOT))
        bad = copy.deepcopy(contract)
        bad["strategy_ref"]["strategy_revision"] = 2
        failures += check("unknown strategy revision is rejected", qi.validate_contract(bad, ROOT))
        bad = copy.deepcopy(contract)
        bad["parameter_refs"][0]["semantic_rev"] = 2
        failures += check("wrong PID semantic_rev is rejected", qi.validate_contract(bad, ROOT))
        bad = copy.deepcopy(contract)
        bad["parameter_refs"][0]["pid"] = 99999
        failures += check("unknown PID is rejected", qi.validate_contract(bad, ROOT))
        bad = copy.deepcopy(contract)
        bad["strategy_ref"]["ea_id"] = "E011"
        failures += check("cross-strategy run binding is rejected",
                          qi.validate_result(result, ROOT, contract=bad))
        failures += check("exact strategy/run identity accepts the observed expert",
                          qi.strategy_matches_run(contract["strategy_ref"], run, ROOT))
        lookalike = dict(run, expert=run["expert"] + "Suffix")
        failures += check("strategy lookalike expert is rejected",
                          not qi.strategy_matches_run(contract["strategy_ref"], lookalike, ROOT))
        failures += check("unknown expert is rejected",
                          not qi.strategy_matches_run(contract["strategy_ref"],
                                                      dict(run, expert="TotallyDifferentGridLog"), ROOT))
        failures += check("E016 uses the existing KangarooGrid wrapper identity",
                          qi.strategy_matches_run(
                              {"ea_id": "E016", "strategy_revision": 1},
                              dict(run, expert="EALabTpl\\Boss_16_KangarooGrid"), ROOT))

        bad = copy.deepcopy(result)
        bad["experiment_id"] = "exp_87654321-4321-4321-8321-ba0987654321"
        failures += check("wrong result/contract linkage is rejected",
                          qi.validate_result(bad, ROOT, contract=contract))
        bad = copy.deepcopy(contract)
        bad["implementation_ref"]["ex5_hash"] = "0" * 64
        failures += check("wrong EX5 hash is rejected", qi.validate_result(
            result, ROOT, contract=bad))
        bad = copy.deepcopy(contract)
        bad["implementation_ref"]["effective_config_hash"] = "0" * 64
        failures += check("wrong effective config hash is rejected", qi.validate_result(
            result, ROOT, contract=bad))
        bad = copy.deepcopy(contract)
        bad["implementation_ref"]["ex5_hash"] = None
        failures += check("executable contract requires EX5 hash", qi.validate_contract(bad, ROOT))
        bad = copy.deepcopy(result)
        bad["evidence_ids"] = ["evd_sha256_" + "0" * 64]
        failures += check("unresolved evidence is rejected",
                          qi.validate_result(bad, ROOT, contract=contract))

        first = os.path.join(store, contract["experiment_id"], "contract.json")
        bad = copy.deepcopy(contract)
        bad["experiment_id"] = "exp_87654321-4321-4321-8321-ba0987654321"
        bad["supersedes_experiment_id"] = contract["experiment_id"]
        failures += check("unknown contract supersession target is rejected", _write_refused(
            bad, tmp, ROOT, qi.write_contract))
        qi.write_contract(contract, tmp, repo_root=ROOT)
        failures += check("established contract cannot be overwritten",
                          _overwrite_refused(first, contract, tmp, ROOT))
        failures += check("supersession cycle is rejected",
                          qi.check_supersession_graph(
                              [{"experiment_id": "exp_a", "supersedes_experiment_id": "exp_b"},
                               {"experiment_id": "exp_b", "supersedes_experiment_id": "exp_a"}],
                              "experiment_id", "supersedes_experiment_id"))
        failures += check("duplicate IDs are rejected",
                          qi.check_supersession_graph(
                              [{"experiment_id": "exp_a", "supersedes_experiment_id": None},
                               {"experiment_id": "exp_a", "supersedes_experiment_id": None}],
                              "experiment_id", "supersedes_experiment_id"))

        qi.write_result(result, tmp, repo_root=ROOT)
        second_contract = copy.deepcopy(contract)
        second_contract["experiment_id"] = "exp_abcdefab-cdef-4abc-8def-abcdefabcdef"
        qi.write_contract(second_contract, tmp, repo_root=ROOT)
        duplicate = copy.deepcopy(result)
        duplicate["experiment_id"] = second_contract["experiment_id"]
        failures += check("duplicate result_id is rejected before a second write",
                          _write_refused(duplicate, tmp, ROOT, qi.write_result))
        failures += check("first result remains the only established result",
                          len(qi._find_result_paths(tmp, result["result_id"])) == 1 and
                          qi.validate_store(tmp, ROOT)[0] == [])
        registry_a = qi.derive_registry(tmp, ROOT)
        registry_b = qi.derive_registry(tmp, ROOT)
        failures += check("derived registry is deterministic", registry_a == registry_b)
        mutated = copy.deepcopy(registry_b)
        mutated["experiments"].append({"experiment_id": "exp_fake"})
        failures += check("derived registry drift is detectable", mutated != registry_a)
        negative = qi.derive_negative_memory(tmp, ROOT)
        failures += check("negative memory is derived and verdict-scoped",
                          len(negative) == 1 and negative[0]["verdict"] == "INCONCLUSIVE" and
                          "result_id" in negative[0])
        failures += check("legacy uncontracted evidence remains readable",
                          os.path.isfile(os.path.join(ROOT, "factory", "runs",
                                                       "RUN-20260802-001.jsonl")))

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


if __name__ == "__main__":
    sys.exit(main())
