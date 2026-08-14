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


def main():
    failures = 0
    with tempfile.TemporaryDirectory(prefix="qi1-cage-") as tmp:
        store = os.path.join(tmp, "factory", "experiments")
        os.makedirs(store)
        runs = qi.load_run_index(ROOT)
        run = runs["RUN-20260802-001"]
        evidence_id = "evd_sha256_092b3189c504570708f91b4bb2d48fe3119f04396f515299d34d728db03622de"
        contract = valid_contract(run)
        result = valid_result(contract, None, evidence_id)

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
        custom = copy.deepcopy(contract)
        custom["experiment_type"] = "CUSTOM_EXECUTION"
        custom["implementation_ref"]["ex5_hash"] = None
        custom["implementation_ref"]["effective_config_hash"] = None
        failures += check("unsupported CUSTOM_EXECUTION cannot bypass hashes",
                          qi.validate_contract(custom, ROOT))
        unsupported_shape = copy.deepcopy(contract)
        unsupported_shape["experiment_type"] = []
        failures += check("unsupported non-string experiment_type fails closed without crashing",
                          qi.validate_contract(unsupported_shape, ROOT))
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
                          qi.validate_result(dict(result, run_ids=["RUN-20260802-001"]), ROOT, contract=bad))
        identity_run = dict(run, strategy_ref=copy.deepcopy(contract["strategy_ref"]))
        failures += check("exact strategy/run identity accepts the observed expert",
                          qi.strategy_matches_run(contract["strategy_ref"], identity_run, ROOT))
        failures += check("legacy run without exact strategy_ref fails closed",
                          not qi.strategy_matches_run(contract["strategy_ref"], run, ROOT))
        wrong_revision_run = dict(identity_run,
                                  strategy_ref={"ea_id": "E014", "strategy_revision": 2})
        failures += check("run strategy_revision mismatch fails closed",
                          not qi.strategy_matches_run(contract["strategy_ref"],
                                                      wrong_revision_run, ROOT))
        lookalike = dict(identity_run, expert="MaliciousGridLogCopy")
        failures += check("strategy lookalike expert is rejected",
                          not qi.strategy_matches_run(contract["strategy_ref"], lookalike, ROOT))
        failures += check("unknown expert is rejected",
                          not qi.strategy_matches_run(contract["strategy_ref"],
                                                      dict(identity_run, expert="TotallyDifferentGridLog"), ROOT))
        failures += check("E016 uses the existing KangarooGrid wrapper identity",
                          qi.strategy_matches_run(
                              {"ea_id": "E016", "strategy_revision": 1},
                              dict(run, strategy_ref={"ea_id": "E016", "strategy_revision": 1}, expert="EALabTpl\\Boss_16_KangarooGrid"), ROOT))

        bad = copy.deepcopy(result)
        bad["experiment_id"] = "exp_87654321-4321-4321-8321-ba0987654321"
        failures += check("wrong result/contract linkage is rejected",
                          qi.validate_result(bad, ROOT, contract=contract))
        bad = copy.deepcopy(contract)
        bad["implementation_ref"]["ex5_hash"] = "0" * 64
        failures += check("wrong EX5 hash is rejected", qi.validate_result(
            dict(result, run_ids=["RUN-20260802-001"]), ROOT, contract=bad))
        bad = copy.deepcopy(contract)
        bad["implementation_ref"]["effective_config_hash"] = "0" * 64
        failures += check("wrong effective config hash is rejected", qi.validate_result(
            dict(result, run_ids=["RUN-20260802-001"]), ROOT, contract=bad))
        bad = copy.deepcopy(contract)
        bad["implementation_ref"]["ex5_hash"] = None
        failures += check("executable contract requires EX5 hash", qi.validate_contract(bad, ROOT))
        bad = copy.deepcopy(result)
        bad["evidence_ids"] = ["evd_sha256_" + "0" * 64]
        failures += check("unresolved evidence is rejected",
                          qi.validate_result(bad, ROOT, contract=contract))
        cross_contract = copy.deepcopy(contract)
        cross_contract["experiment_id"] = "exp_abcdefab-cdef-4abc-8def-abcdefabcdef"
        failures += check("cross-experiment evidence is rejected",
                          qi.validate_result(valid_result(cross_contract, None, evidence_id),
                                             ROOT, contract=cross_contract))
        malformed = os.path.join(tmp, "malformed.jsonl")
        non_object = os.path.join(tmp, "non-object.jsonl")
        with open(malformed, "w", encoding="utf-8") as handle:
            handle.write("not-json\n")
        with open(non_object, "w", encoding="utf-8") as handle:
            handle.write("[]\n")
        failures += check("malformed JSONL fails closed", _jsonl_refused(malformed))
        failures += check("non-object JSONL fails closed", _jsonl_refused(non_object))
        failures += check("corrupt event authority object fails closed",
                          _corrupt_authority_refused("event-v1.schema.json",
                                                     "events-2026-01.jsonl",
                                                     {"experiment_id": contract["experiment_id"],
                                                      "evidence_ids": [evidence_id]},
                                                     qi.load_evidence_lineage))
        failures += check("corrupt evidence authority object fails closed",
                          _corrupt_authority_refused("evidence-v1.schema.json",
                                                     "evidence-manifest.jsonl",
                                                     {"evidence_id": evidence_id},
                                                     qi.load_evidence_index))
        failures += check("actor/role-invalid event authority fails closed",
                          _mutated_authority_refused(
                              "events-2026-07.jsonl",
                              lambda rows: rows[0].update(actor="user", role="peer_engineer"),
                              qi.load_evidence_lineage))
        failures += check("evidence_id/raw_sha256 mismatch fails closed",
                          _mutated_authority_refused(
                              "evidence-manifest.jsonl",
                              lambda rows: rows[0].update(evidence_id="evd_sha256_" + "0" * 64),
                              qi.load_evidence_index))
        failures += check("forged committed evidence locator fails closed",
                          _mutated_authority_refused(
                              "evidence-manifest.jsonl",
                              lambda rows: rows[0].update(blob_oid="0" * 40),
                              qi.load_evidence_index))
        failures += check("nested non-object event authority fails closed without crashing",
                          _mutated_authority_refused(
                              "events-2026-07.jsonl",
                              lambda rows: rows[0].update(artifact_hashes=[]),
                              qi.load_evidence_lineage))
        failures += check("orphan event lineage cannot establish evidence binding",
                          _mutated_authority_refused(
                              "events-2026-07.jsonl",
                              lambda rows: rows[1].update(
                                  prior_event_id="evt_00000000-0000-4000-8000-000000000000"),
                              qi.load_evidence_lineage))

        with tempfile.TemporaryDirectory(prefix="qi1-poisoned-contract-") as poisoned:
            qi.write_contract(contract, poisoned, repo_root=ROOT)
            first_contract = os.path.join(poisoned, "factory", "experiments",
                                          contract["experiment_id"], "contract.json")
            invalid = copy.deepcopy(contract)
            invalid["experiment_type"] = "CUSTOM_EXECUTION"
            with open(first_contract, "wb") as handle:
                handle.write(qi._canonical_bytes(invalid))
            failures += check("invalid stored contract blocks result write",
                              _write_refused(result, poisoned, ROOT, qi.write_result))

        with tempfile.TemporaryDirectory(prefix="qi1-poisoned-result-") as poisoned:
            qi.write_contract(contract, poisoned, repo_root=ROOT)
            second_contract = copy.deepcopy(contract)
            second_contract["experiment_id"] = "exp_abcdefab-cdef-4abc-8def-abcdefabcdef"
            qi.write_contract(second_contract, poisoned, repo_root=ROOT)
            alias = os.path.join(poisoned, "factory", "experiments",
                                 second_contract["experiment_id"], "results", "alias.json")
            os.makedirs(os.path.dirname(alias), exist_ok=True)
            duplicate = copy.deepcopy(result)
            duplicate["experiment_id"] = second_contract["experiment_id"]
            with open(alias, "wb") as handle:
                handle.write(qi._canonical_bytes(duplicate))
            failures += check("poisoned alias cannot bypass global result_id uniqueness",
                              _write_refused(result, poisoned, ROOT, qi.write_result))

        failures += check("canonical path is invisible until atomic install",
                          _atomic_visibility_preserved(contract))
        failures += check("competing immutable writes cannot overwrite",
                          _competing_writes_refused(contract))

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
