"""Numbered gates and reusable fixture construction (no extra helper path)."""
from dataclasses import replace
import os
from pathlib import Path
import sys
import unittest
import uuid
import zlib

from broker import Broker
from launch import Approval, IMPLEMENTATION_PATHS, run
from model_client import FakeModelClient
from preflight import Pins, canonical, identity, inventory, load_schema, sha256, strict_json, validate
from snapshot import export, oid


def file_spec(root, relative):
    path = root / relative
    raw = path.read_bytes()
    return {"path": relative, "identity": identity(path), "size": len(raw), "sha256": sha256(raw)}


def envelope(calls=None, result=None, request_id="fake-1"):
    return {"model": "deterministic-fake-v2", "request_id": request_id,
            "tool_calls": calls or [], "result": result}


def call(name, **arguments):
    return {"name": name, "arguments": arguments}


class Fixture:
    def __init__(self, object_format="sha1"):
        base = Path(os.environ["RT_V2_TEST_ROOT"])
        assert base.is_absolute() and base.is_dir()
        self.root = base / ("fixture-" + uuid.uuid4().hex)
        self.root.mkdir()
        self.control = self.root / "control"
        for rel in ("review_transport_v2/contracts/c1", "review_transport_v2/state/t1",
                    "review_transport_v2/bundles", "evidence"):
            (self.control / rel).mkdir(parents=True, exist_ok=True)
        self.repo = self.root / "source"
        self.evidence = self.root / "evidence-package"
        self.repo.mkdir()
        self.evidence.mkdir()
        git = self.repo / ".git"
        (git / "objects").mkdir(parents=True)
        (git / "refs/heads").mkdir(parents=True)
        (git / "config").write_text('[core]\n repositoryformatversion = 0\n' +
                                    ('[extensions]\n objectformat = sha256\n' if object_format == 'sha256' else ''), encoding='utf-8')
        self.data = b"print('sealed source')\n"
        (self.repo / "a.py").write_bytes(self.data)
        (self.evidence / "result.txt").write_bytes(b"deterministic evidence: PASS\n")
        self.objects = []

        def add(kind, raw, entry_id):
            object_id = oid(kind, raw, object_format)
            p = git / "objects" / object_id[:2] / object_id[2:]
            p.parent.mkdir(exist_ok=True)
            p.write_bytes(zlib.compress(kind.encode() + b" " + str(len(raw)).encode() + b"\0" + raw))
            self.objects.append({"id": entry_id, "type": kind, "oid": object_id,
                                 "size": len(raw), "sha256": sha256(raw)})
            return object_id
        blob = add("blob", self.data, "g_blob")
        tree = add("tree", b"100644 a.py\0" + bytes.fromhex(blob), "g_tree")
        commit = add("commit", ("tree " + tree + "\nauthor Fixture <fixture@example.invalid> 0 +0000\n"
                                "committer Fixture <fixture@example.invalid> 0 +0000\n\nfixture\n").encode(), "g_commit")
        (git / "HEAD").write_text("ref: refs/heads/main\n", encoding="ascii")
        (git / "refs/heads/main").write_text(commit + "\n", encoding="ascii")
        impl = Path(__file__).resolve().parents[1]
        runtime = Path(sys.executable).resolve().parent
        self.impl_manifest = canonical({
            "implementation": {"root": str(impl), "identity": identity(impl),
                               "files": [file_spec(impl, rel) for rel in IMPLEMENTATION_PATHS]},
            "dependencies": {"root": str(runtime), "identity": identity(runtime),
                             "files": [file_spec(runtime, rel) for rel in inventory(runtime)]}})
        self.contract = {"schema_version": "2", "contract_id": "c1", "transport_id": "t1", "run_id": "r1",
                         "transport_version": "2", "requested_head": commit, "git_tree_oid": tree,
                         "git_object_format": object_format, "source_root": str(self.repo),
                         "source_root_identity": identity(self.repo), "evidence_root": str(self.evidence),
                         "evidence_root_identity": identity(self.evidence),
                         "state_path": "review_transport_v2/state/t1/state.json",
                         "implementation_manifest_sha256": sha256(self.impl_manifest),
                         "source_entries": [dict(file_spec(self.repo, "a.py"), id="s_01", blob_oid=blob)],
                         "evidence_entries": [dict(file_spec(self.evidence, "result.txt"), id="e_01")],
                         "git_objects": self.objects, "model_requested": "deterministic-fake-v2",
                         "reasoning_effort": "none", "endpoint_identity": "fake://deterministic-v2",
                         "required_coverage": ["s_01", "e_01", "g_commit", "g_tree", "g_blob"],
                         "result_schema": load_schema("review_result"),
                         "bounds": {"max_state_bytes": 65536, "max_json_depth": 20, "max_entries": 100,
                                    "max_entry_bytes": 65536, "max_bundle_bytes": 1048576,
                                    "max_read_bytes": 65536, "max_response_bytes": 1048576,
                                    "max_tool_calls": 100, "max_model_rounds": 10, "max_model_output_bytes": 65536}}
        self.freeze()

    @property
    def state_path(self):
        return self.control / "review_transport_v2/state/t1/state.json"

    def freeze(self, state_raw=None):
        # Fixture preparation only, before the launch creates immutable output.
        contract_raw = canonical(self.contract)
        (self.control / "review_transport_v2/contracts/c1/contract.json").write_bytes(contract_raw)
        self.state = {"schema_version": "2", "transport_version": "2", "transport_id": "t1",
                      "contract_id": "c1", "contract_sha256": sha256(contract_raw),
                      "implementation_manifest_sha256": sha256(self.impl_manifest),
                      "endpoint_identity": self.contract["endpoint_identity"], "status": "READY"}
        raw = canonical(self.state) if state_raw is None else state_raw
        self.state_path.write_bytes(raw)
        self.approval = Approval(str(self.control), identity(self.control), "c1", "t1", "r1",
                                 sha256(contract_raw), sha256(raw), sha256(self.impl_manifest), self.impl_manifest)

    def snapshot(self):
        with Pins() as pins:
            return export(self.contract, pins)

    def result(self):
        return {"schema_version": "2", "reviewed_head": self.contract["requested_head"],
                "bundle_manifest_sha256": self.snapshot().manifest_sha256, "verdict": "PASS",
                "findings": [], "citations": ["e_01"]}

    def client(self, extra=()):
        calls = list(extra)
        for kind, field, key in (("read_source", "source_entries", "source_id"),
                                 ("read_evidence", "evidence_entries", "evidence_id"),
                                 ("read_git_object", "git_objects", "object_id")):
            calls += [call(kind, **{key: e["id"], "offset": 0, "length": e["size"]}) for e in self.contract[field]]
        return FakeModelClient([envelope(calls), envelope(result=self.result(), request_id="fake-2")])

    def launch(self, client=None):
        return run(self.approval, client if client is not None else self.client())


class NumberedGates(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = Fixture()
        cls.receipt = cls.fixture.launch()

    def test_01_exact_frozen_head(self):
        self.assertEqual(self.receipt["disposition"], "DETERMINISTIC_TEST_ONLY", self.receipt["limitations"])
        self.assertEqual(self.receipt["reviewed_head"], self.fixture.contract["requested_head"])

    def test_02_wrong_head_zero_dispatch(self):
        fixture = Fixture()
        client = fixture.client()
        fixture.contract["requested_head"] = "0" * 40
        fixture.freeze()
        receipt = fixture.launch(client)
        self.assertEqual(receipt["model_dispatch_count"], 0)
        self.assertIsNone(receipt["substantive_verdict"])
        self.assertEqual(client.requests, [])

    def test_03_source_hashes(self):
        for entry in self.receipt["source_entries"]:
            self.assertEqual(entry["sha256"], sha256((self.fixture.repo / entry["path"]).read_bytes()))

    def test_04_git_commit_tree_blob(self):
        snapshot = self.fixture.snapshot()
        self.assertEqual({e["type"] for e in self.receipt["git_objects"]}, {"commit", "tree", "blob"})
        for entry in self.receipt["git_objects"]:
            self.assertEqual(oid(entry["type"], snapshot.entries[entry["id"]], "sha1"), entry["oid"])

    def test_05_exact_evidence_root(self):
        fixture = Fixture()
        client = fixture.client()
        fixture.contract["evidence_root"] = str(fixture.repo)
        fixture.freeze()
        self.assertEqual(fixture.launch(client)["model_dispatch_count"], 0)

    def deny(self, requests):
        fixture = Fixture()
        receipt = fixture.launch(fixture.client(requests))
        self.assertEqual(receipt["disposition"], "DETERMINISTIC_TEST_ONLY", receipt["limitations"])
        log = strict_json((fixture.control / "evidence/review-transport-v2-r1/read_log.json").read_bytes())
        self.assertTrue(all(e["status"] == "DENIED" for e in log[:len(requests)]))
        self.assertEqual(len(log), len(requests) + 5)

    def test_06_private_unrelated_roots_absent_capability(self):
        self.deny([call("open", path="C:/Users/private/secret"), call("read_source", source_id="../../private", offset=0, length=1), call("browser", url="https://example.invalid")])

    def test_07_source_evidence_writes_impossible(self):
        self.deny([call("write_source", source_id="s_01", data="evil"), call("write_evidence", evidence_id="e_01", data="evil")])

    def test_08_registry_writes_impossible(self):
        self.deny([call("Registry.Transition", state="DONE"), call("write_file", path="D:/EA_LAB_CONTROL/lanes/registry-v1/x.json")])

    def test_09_runtime_process_mutation_impossible(self):
        self.deny([call("exec", command="terminal64.exe"), call("kill_process", pid=123), call("computer_use", action="click"), call("mt5", action="trade")])

    def test_10_malformed_state_zero_dispatch(self):
        fixture = Fixture()
        client = fixture.client()
        fixture.freeze(b'{"duplicate":1,"duplicate":2}')
        receipt = fixture.launch(client)
        self.assertEqual(receipt["model_dispatch_count"], 0)
        self.assertEqual(receipt["disposition"], "ENVIRONMENT")

    def test_11_zero_evidence_no_verdict(self):
        fixture = Fixture()
        receipt = fixture.launch(FakeModelClient([envelope(result=fixture.result())]))
        self.assertEqual(receipt["model_dispatch_count"], 1)
        self.assertEqual(receipt["successful_evidence_reads"], 0)
        self.assertIsNone(receipt["substantive_verdict"])

    def test_12_receipt_exact_identity_state_hash(self):
        fixture = self.fixture
        receipt = self.receipt
        validate(receipt, load_schema("receipt"))
        self.assertEqual(receipt["contract_sha256"], fixture.approval.contract_sha256)
        self.assertEqual(receipt["transport_state_sha256"], fixture.approval.state_sha256)
        self.assertEqual(receipt["implementation_manifest_sha256"], fixture.approval.implementation_manifest_sha256)
        self.assertEqual(receipt["protected_state_before"], receipt["protected_state_after"])
        self.assertEqual(receipt["observed_head_pre"], receipt["observed_head_post"])
