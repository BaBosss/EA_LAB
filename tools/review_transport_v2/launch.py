"""Trusted launch orchestration. API only; real provider execution is unavailable.

Approval is an out-of-band frozen trust input, never created from transport state.
The caller must verify this implementation before importing/executing it. Self
hashes are continuity checks, not a bootstrap root of trust.
"""
from dataclasses import dataclass
from pathlib import Path
import sys

from broker import Broker
from model_client import FakeModelClient, ModelClient, dispatch
from preflight import (Pins, Refusal, canonical, identity, inventory, load_schema,
                       require, sha256, strict_json, unique, validate)
from receipt import Artifacts, persist, raw_output_inventory, reserve_run
from snapshot import export, head


IMPLEMENTATION_PATHS = (
    "README.md", "launch.py", "preflight.py", "snapshot.py", "broker.py", "model_client.py", "receipt.py",
    "schemas/contract.schema.json", "schemas/transport_state.schema.json", "schemas/bundle.schema.json",
    "schemas/review_result.schema.json", "schemas/receipt.schema.json",
    "tests/test_preflight.py", "tests/test_snapshot.py", "tests/test_broker.py",
    "tests/test_dispatch.py", "tests/test_receipt.py", "tests/test_gate_contract.py",
)


@dataclass(frozen=True)
class Approval:
    control_root: str
    control_identity: dict
    contract_id: str
    transport_id: str
    run_id: str
    contract_sha256: str
    state_sha256: str
    implementation_manifest_sha256: str
    implementation_manifest_bytes: bytes
    max_state_bytes: int = 65536


def verify_implementation(approval, pins):
    require(sha256(approval.implementation_manifest_bytes) == approval.implementation_manifest_sha256,
            "IMPLEMENTATION_MANIFEST_HASH")
    manifest = strict_json(approval.implementation_manifest_bytes, 1048576)
    require(type(manifest) is dict and set(manifest) == {"implementation", "dependencies"}, "IMPLEMENTATION_MANIFEST_FIELDS")
    for category in ("implementation", "dependencies"):
        block = manifest[category]
        require(type(block) is dict and set(block) == {"root", "identity", "files"}, "IMPLEMENTATION_BLOCK")
        root = pins.root(block["root"], block["identity"])
        if category == "implementation":
            require(root == Path(__file__).resolve().parent, "LAUNCHER_LOCATION")
            require(sorted(f["path"] for f in block["files"]) == sorted(IMPLEMENTATION_PATHS), "IMPLEMENTATION_EXACT_LIST")
        else:
            require(root == Path(sys.executable).resolve().parent, "PYTHON_LOCATION")
            require({"python.exe", "python312.dll", "python312.zip", "python312._pth"}
                    <= {f["path"] for f in block["files"]}, "DEPENDENCY_CLOSURE")
        unique(block["files"], "path")
        validate(block["identity"], {"type": "object", "additionalProperties": False,
                 "required": ["device", "inode"], "properties": {
                     "device": {"type": "integer", "minimum": 0, "maximum": 2**64-1},
                     "inode": {"type": "integer", "minimum": 1, "maximum": 2**128-1}}})
        require(inventory(root) == sorted(f["path"] for f in block["files"]), "IMPLEMENTATION_INVENTORY")
        for spec in block["files"]:
            require(set(spec) == {"path", "size", "sha256", "identity"}, "IMPLEMENTATION_ENTRY")
            validate(spec["sha256"], {"type": "string", "pattern": "[0-9a-f]{64}"})
            validate(spec["size"], {"type": "integer", "minimum": 0, "maximum": 64*1024*1024})
            raw = pins.read(root, spec["path"], 64 * 1024 * 1024, spec["identity"])
            require(len(raw) == spec["size"] and sha256(raw) == spec["sha256"], "IMPLEMENTATION_BYTES")
    # This version supports the pinned embeddable runtime with no site startup.
    require(sys.flags.no_site and sys.flags.dont_write_bytecode, "ISOLATED_PYTHON_FLAGS")
    return manifest


def run(approval, client):
    """Return a durable receipt, or raise before reservation if output is unsafe.

    Output-root/ID bootstrap failures cannot safely write an output receipt. The
    caller receives an exception and zero dispatch. All failures after reservation
    write an ENVIRONMENT receipt; preflight failures ALWAYS have zero dispatch.
    """
    id_schema = {"type": "string", "pattern": "[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}"}
    for value in (approval.run_id, approval.contract_id, approval.transport_id):
        validate(value, id_schema)
    for digest in (approval.contract_sha256, approval.state_sha256, approval.implementation_manifest_sha256):
        validate(digest, {"type": "string", "pattern": "[0-9a-f]{64}"})
    require(type(approval.max_state_bytes) is int and 1 <= approval.max_state_bytes <= 1048576, "APPROVED_STATE_BOUND")
    audit = {"model_dispatch_count": 0, "model_observed": None, "provider_request_ids": [],
             "raw_outputs": [], "tool_calls": 0}
    receipt = {"schema_version": "2", "run_id": approval.run_id,
               "contract_id": approval.contract_id, "contract_sha256": approval.contract_sha256,
               "transport_id": approval.transport_id, "transport_state_sha256": approval.state_sha256,
               "implementation_manifest_sha256": approval.implementation_manifest_sha256,
               "model_requested": None, "model_observed": None, "reasoning_effort": None,
               "endpoint_identity": None, "requested_head": None, "observed_head_pre": None,
               "observed_head_post": None, "reviewed_head": None, "git_tree_oid": None,
               "git_object_format": None, "bundle_manifest_sha256": None,
               "source_entries": [], "evidence_entries": [], "git_objects": [],
               "preflight_checks": [], "preflight_status": "FAIL", "model_dispatch_count": 0,
               "provider_request_ids": [], "read_log_sha256": sha256(b"[]"),
               "successful_evidence_reads": 0, "required_coverage": [],
               "raw_model_output_sha256": sha256(b"[]"), "raw_model_outputs": [],
               "validated_result_sha256": sha256(b"null"),
               "protected_state_before": None, "protected_state_after": None,
               "unchanged_checks": [], "gate_results": [], "disposition": "ENVIRONMENT",
               "substantive_verdict": None, "limitations": [
                   "Implementation tests cannot establish STANDARD_READY or operational qualification.",
                   "No qualified real API adapter; fake clients are deterministic tests only.",
                   "Trusted Windows launcher/runtime/OS and external approval issuer remain the trust base.",
                   "Standalone loose-object Git package required; linked, packed and partial stores are refused."]}
    broker = snapshot = contract = bundle = None
    result = None
    with Pins() as pins:
        control = pins.root(approval.control_root, approval.control_identity)
        pins.root(str(control / "evidence"), identity(control / "evidence"))
        run_dir = reserve_run(control, approval.run_id)
        pins.root(str(run_dir), identity(run_dir))
        # Receipt schema belongs to the trusted bootstrap, not the state document.
        receipt_schema = load_schema("receipt")
        try:
            verify_implementation(approval, pins)
            receipt["preflight_checks"].append("implementation_dependencies_schemas_dispatcher")
            contract_rel = "review_transport_v2/contracts/" + approval.contract_id + "/contract.json"
            contract_raw = pins.read(control, contract_rel, 1048576)
            require(sha256(contract_raw) == approval.contract_sha256, "CONTRACT_HASH")
            contract = strict_json(contract_raw)
            validate(contract, load_schema("contract"))
            require(contract["contract_id"] == approval.contract_id and contract["transport_id"] == approval.transport_id,
                    "CONTRACT_TRANSPORT_IDENTITY")
            require(contract["run_id"] == approval.run_id, "RUN_IDENTITY")
            require(contract["implementation_manifest_sha256"] == approval.implementation_manifest_sha256,
                    "CONTRACT_IMPLEMENTATION_IDENTITY")
            require(contract["result_schema"] == load_schema("review_result"), "RESULT_SCHEMA_IDENTITY")
            for key in ("model_requested", "reasoning_effort", "endpoint_identity", "requested_head", "git_tree_oid",
                        "git_object_format", "source_entries", "evidence_entries", "git_objects", "required_coverage"):
                receipt[key] = contract[key]
            receipt["preflight_checks"].append("contract")
            state_rel = "review_transport_v2/state/" + approval.transport_id + "/state.json"
            require(contract["state_path"] == state_rel, "DEDICATED_STATE_PATH")
            state_raw = pins.read(control, state_rel, min(approval.max_state_bytes, contract["bounds"]["max_state_bytes"]))
            require(sha256(state_raw) == approval.state_sha256, "STATE_RAW_SHA256")
            state = strict_json(state_raw, min(approval.max_state_bytes, contract["bounds"]["max_state_bytes"]),
                                contract["bounds"]["max_json_depth"])
            validate(state, load_schema("transport_state"))
            require(state == {"schema_version": "2", "transport_version": "2", "transport_id": approval.transport_id,
                              "contract_id": approval.contract_id, "contract_sha256": approval.contract_sha256,
                              "implementation_manifest_sha256": approval.implementation_manifest_sha256,
                              "endpoint_identity": contract["endpoint_identity"], "status": "READY"}, "STATE_BINDING")
            receipt["preflight_checks"].append("strict_state_and_frozen_hash")
            snapshot = export(contract, pins)
            validate(strict_json(snapshot.manifest_bytes, 8 * 1024 * 1024), load_schema("bundle"))
            receipt["observed_head_pre"] = contract["requested_head"]
            receipt["bundle_manifest_sha256"] = snapshot.manifest_sha256
            require(set(contract["required_coverage"]) <= set(snapshot.entries), "COVERAGE_UNKNOWN_ID")
            require(len(set(contract["required_coverage"])) == len(contract["required_coverage"]), "COVERAGE_DUPLICATE")
            require({e["id"] for e in contract["evidence_entries"]} <= set(contract["required_coverage"]), "EVIDENCE_COVERAGE_REQUIRED")
            receipt["preflight_checks"].append("head_source_git_evidence_capacity")
            # Bundle is content-addressed, create-once, never reused silently.
            bundle_parent = control / "review_transport_v2" / "bundles"
            pins.root(str(bundle_parent), identity(bundle_parent))
            bundle_dir = bundle_parent / snapshot.manifest_sha256
            bundle_dir.mkdir()
            bundle = Artifacts(bundle_dir, pins)
            bundle.add("manifest.json", snapshot.manifest_bytes)
            for entry_id, raw in snapshot.entries.items():
                bundle.add(entry_id + ".bin", raw)
            bundle.verify()
            require(type(client) in (FakeModelClient, ModelClient), "UNAPPROVED_CLIENT_IMPLEMENTATION")
            endpoint = client.preflight(contract["model_requested"], contract["reasoning_effort"], contract["endpoint_identity"])
            require(type(client) is FakeModelClient and not endpoint["operational"], "QUALIFIED_API_ADAPTER_UNAVAILABLE")
            receipt["preflight_checks"].append("explicit_client_endpoint")
            before = {"bundle_manifest_sha256": snapshot.manifest_sha256,
                      "contract_sha256": sha256(contract_raw), "transport_state_sha256": sha256(state_raw),
                      "implementation_manifest_sha256": approval.implementation_manifest_sha256,
                      "source_root_identity": identity(contract["source_root"]),
                      "evidence_root_identity": identity(contract["evidence_root"])}
            receipt["protected_state_before"] = before
            # Re-export and recheck identities immediately before dispatch.
            require(export(contract, pins).manifest_bytes == snapshot.manifest_bytes, "PREDISPATCH_PACKAGE_CHANGED")
            require(pins.read(control, contract_rel, 1048576) == contract_raw, "PREDISPATCH_CONTRACT_CHANGED")
            require(pins.read(control, state_rel, approval.max_state_bytes) == state_raw, "PREDISPATCH_STATE_CHANGED")
            verify_implementation(approval, pins)
            receipt["preflight_status"] = "PASS"
            broker = Broker(snapshot, contract["bounds"])
            returned = dispatch(client, broker, contract, audit)
            validate(returned, load_schema("review_result"))
            require(returned["reviewed_head"] == contract["requested_head"] and
                    returned["bundle_manifest_sha256"] == snapshot.manifest_sha256, "RESULT_PACKAGE_IDENTITY")
            require(all(c in snapshot.entries for c in returned["citations"]), "RESULT_CITATION_ID")
            require(broker.successful_evidence_reads > 0 and broker.covers(contract["required_coverage"]), "INSUFFICIENT_EVIDENCE_COVERAGE")
            require(set(returned["citations"]) >= {e["id"] for e in contract["evidence_entries"]}, "RESULT_EVIDENCE_CITATIONS")
            require(broker.covers(returned["citations"]), "RESULT_CITATION_COVERAGE")
            result = returned
        except (Refusal, OSError, ValueError, KeyError, TypeError, RuntimeError) as exc:
            receipt["limitations"].append(type(exc).__name__ + ": " + str(exc))
            result = None
        finally:
            # Postconditions run even on malformed/provider failures after dispatch.
            if snapshot is not None and contract is not None:
                try:
                    after_snapshot = export(contract, pins)
                    require(after_snapshot.manifest_bytes == snapshot.manifest_bytes, "POST_PACKAGE_CHANGED")
                    require(pins.read(control, contract_rel, 1048576) == contract_raw, "POST_CONTRACT_CHANGED")
                    require(pins.read(control, state_rel, approval.max_state_bytes) == state_raw, "POST_STATE_CHANGED")
                    verify_implementation(approval, pins)
                    receipt["observed_head_post"] = head(pins, Path(contract["source_root"]))
                    receipt["protected_state_after"] = {
                        "bundle_manifest_sha256": after_snapshot.manifest_sha256,
                        "contract_sha256": sha256(pins.read(control, contract_rel, 1048576)),
                        "transport_state_sha256": sha256(pins.read(control, state_rel, approval.max_state_bytes)),
                        "implementation_manifest_sha256": sha256(approval.implementation_manifest_bytes),
                        "source_root_identity": identity(contract["source_root"]),
                        "evidence_root_identity": identity(contract["evidence_root"])}
                    if receipt["protected_state_before"] is not None:
                        require(receipt["protected_state_after"] == receipt["protected_state_before"], "PROTECTED_STATE_CHANGED")
                    receipt["unchanged_checks"] = ["source", "evidence", "head", "contract", "state", "implementation", "dependencies"]
                except (Refusal, OSError, ValueError, KeyError, TypeError) as exc:
                    result = None
                    receipt["limitations"].append("POSTCONDITION: " + str(exc))
            if broker is not None:
                receipt["read_log_sha256"] = sha256(broker.read_log)
                receipt["successful_evidence_reads"] = broker.successful_evidence_reads
            for key in ("model_dispatch_count", "model_observed", "provider_request_ids"):
                receipt[key] = audit[key]
            receipt["raw_model_outputs"] = raw_output_inventory(audit["raw_outputs"])
            receipt["raw_model_output_sha256"] = sha256(canonical(receipt["raw_model_outputs"]))
            receipt["validated_result_sha256"] = sha256(canonical(result))
            if result is not None:
                receipt["reviewed_head"] = result["reviewed_head"]
                receipt["substantive_verdict"] = result["verdict"]
                receipt["disposition"] = "DETERMINISTIC_TEST_ONLY"
            # Runtime receipts report observations, never fabricated 12-gate PASS.
            receipt["gate_results"] = [{"gate": n, "status": "NOT_QUALIFIED"} for n in range(1, 13)]
            persist(run_dir, receipt, broker.read_log if broker else b"[]", audit["raw_outputs"], result,
                    receipt_schema, pins, bundle)
    return receipt


if __name__ == "__main__":
    raise SystemExit("ENVIRONMENT: no qualified real API adapter. Use the documented frozen Approval API for deterministic fixtures.")
