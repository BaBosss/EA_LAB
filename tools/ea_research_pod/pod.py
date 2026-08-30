from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_VERSION = 1
LIFECYCLE = [
    "DORMANT", "SPAWN", "LOAD_FAMILY_MEMORY", "IDENTIFY_EVIDENCE_GAP",
    "PREREGISTER", "EXECUTE", "ANALYZE", "REVIEW",
    "ACCEPT", "BLOCK", "PARK", "SYNC_DURABLE_MEMORY", "SLEEP",
]
NEXT = {
    "SPAWN": {"LOAD_FAMILY_MEMORY"},
    "LOAD_FAMILY_MEMORY": {"IDENTIFY_EVIDENCE_GAP"},
    "IDENTIFY_EVIDENCE_GAP": {"PREREGISTER"},
    "PREREGISTER": {"EXECUTE"},
    "EXECUTE": {"ANALYZE"},
    "ANALYZE": {"REVIEW"},
    "REVIEW": {"ACCEPT", "BLOCK", "PARK"},
    "ACCEPT": {"SYNC_DURABLE_MEMORY"},
    "BLOCK": {"SYNC_DURABLE_MEMORY"},
    "PARK": {"SYNC_DURABLE_MEMORY"},
    "SYNC_DURABLE_MEMORY": {"SLEEP"},
}

REQUIRED = [
    "canonical_base_sha", "family", "variant", "parent", "strategy_thesis",
    "current_research_state", "hypothesis_id", "hypothesis", "observation",
    "expected_benefit_cost", "falsifier", "frozen_mechanics", "changed_mechanics",
    "accepted_evidence", "allowed_paths", "forbidden_paths", "deterministic_method",
    "runtime_estimate", "bottleneck", "loop_breaker", "direct_consumer",
    "acceptance", "reviewer_requirement", "authority_ceiling", "task_kind",
]
MECHANICAL_KINDS = {"mechanical", "backtest", "parse", "hash", "aggregate", "fixture"}
SEMANTIC_KINDS = {"semantic", "research", "mechanism", "interpretation", "review"}


def canonical_json(obj: object) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, obj: object) -> None:
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))

def validate_contract(contract: dict) -> None:
    missing = [key for key in REQUIRED if key not in contract]
    if missing:
        raise ValueError(f"missing contract fields: {', '.join(missing)}")
    if not re.fullmatch(r"[0-9a-f]{40}", str(contract["canonical_base_sha"])):
        raise ValueError("canonical_base_sha must be an exact 40-char lowercase Git SHA")
    if contract["authority_ceiling"] != "RESEARCH_ONLY":
        raise ValueError("authority_ceiling must be RESEARCH_ONLY")
    changed = contract["changed_mechanics"]
    if not isinstance(changed, dict) or len(changed) != 1:
        raise ValueError("ONE VARIANT = ONE LOGICAL CHANGE: changed_mechanics must contain exactly one key")
    if not isinstance(contract["frozen_mechanics"], dict) or not contract["frozen_mechanics"]:
        raise ValueError("frozen_mechanics must be a non-empty object")
    if not isinstance(contract["accepted_evidence"], list):
        raise ValueError("accepted_evidence must be a list")
    if not contract["direct_consumer"]:
        raise ValueError("direct_consumer is required")
    task_kind = str(contract["task_kind"]).lower()
    if task_kind not in MECHANICAL_KINDS | SEMANTIC_KINDS:
        raise ValueError(f"unsupported task_kind: {task_kind}")
    flags = contract.get("authority_flags", {})
    protected = ("holdout", "trading", "real_money", "deployment", "runtime_attach", "risk_default_change")
    enabled = [name for name in protected if bool(flags.get(name, False))]
    if enabled:
        raise ValueError("protected authority requested: " + ", ".join(enabled))


def route_for(contract: dict) -> str:
    kind = str(contract["task_kind"]).lower()
    return "DETERMINISTIC_TOOL" if kind in MECHANICAL_KINDS else "MODEL_WORKER"

def spawn(contract_path: Path, workspace: Path) -> dict:
    contract = read_json(contract_path)
    validate_contract(contract)
    workspace = workspace.resolve()
    repo_root = REPO_ROOT.resolve()
    if workspace == repo_root or repo_root in workspace.parents:
        raise ValueError("TRANSIENT_WORKSPACE_MUST_BE_OUTSIDE_REPO")
    workspace.mkdir(parents=True, exist_ok=True)
    dst_contract = workspace / "contract.json"
    state_path = workspace / "pod_state.json"
    if dst_contract.exists() or state_path.exists():
        raise ValueError("workspace already initialized; use resume/status")
    write_json(dst_contract, contract)
    state = {
        "schema_version": SCHEMA_VERSION,
        "lifecycle": "SPAWN",
        "canonical_base_sha": contract["canonical_base_sha"],
        "family": contract["family"],
        "variant": contract["variant"],
        "contract_sha256": file_sha256(dst_contract),
        "frozen_contract_sha256": None,
        "route": route_for(contract),
        "reviewer_requirement": contract["reviewer_requirement"],
        "direct_consumer": contract["direct_consumer"],
        "recommended_decision": None,
        "fixture_evidence_sha256": None,
    }
    write_json(state_path, state)
    return state


def resume(workspace: Path) -> tuple[dict, dict]:
    contract_path = workspace / "contract.json"
    state_path = workspace / "pod_state.json"
    if not contract_path.exists() or not state_path.exists():
        raise ValueError("workspace is not an initialized Research Pod")
    contract = read_json(contract_path)
    validate_contract(contract)
    return contract, read_json(state_path)

def _assert_frozen_contract(workspace: Path, state: dict) -> None:
    frozen = state.get("frozen_contract_sha256")
    if not frozen:
        return
    current = file_sha256(workspace / "contract.json")
    if current != frozen:
        raise ValueError("FROZEN_EXPERIMENT_DRIFT: contract changed after preregistration")


def advance(workspace: Path, target: str) -> dict:
    contract, state = resume(workspace)
    current = state["lifecycle"]
    if target not in LIFECYCLE:
        raise ValueError(f"unknown lifecycle state: {target}")
    if target not in NEXT.get(current, set()):
        raise ValueError(f"illegal transition: {current} -> {target}")
    _assert_frozen_contract(workspace, state)
    if target == "PREREGISTER":
        state["frozen_contract_sha256"] = file_sha256(workspace / "contract.json")
    if current == "REVIEW" and target in {"ACCEPT", "BLOCK", "PARK"}:
        recommended = state.get("recommended_decision")
        if recommended and target != recommended:
            raise ValueError(f"review decision must match fixture recommendation {recommended}")
    state["lifecycle"] = target
    state["route"] = route_for(contract)
    write_json(workspace / "pod_state.json", state)
    return state


def consume_fixture(workspace: Path, evidence_path: Path) -> dict:
    _, state = resume(workspace)
    if state["lifecycle"] != "ANALYZE":
        raise ValueError("fixture evidence may be consumed only in ANALYZE")
    _assert_frozen_contract(workspace, state)
    evidence = read_json(evidence_path)
    outcome = str(evidence.get("outcome", "")).upper()
    mapping = {"PASS": "ACCEPT", "BLOCK": "BLOCK", "PARK": "PARK"}
    if outcome not in mapping:
        raise ValueError("fixture outcome must be PASS, BLOCK, or PARK")
    state["fixture_evidence_sha256"] = file_sha256(evidence_path)
    state["recommended_decision"] = mapping[outcome]
    write_json(workspace / "pod_state.json", state)
    return state

def main() -> int:
    parser = argparse.ArgumentParser(description="EA_LAB deterministic Research Pod lifecycle")
    sub = parser.add_subparsers(dest="command", required=True)
    p_spawn = sub.add_parser("spawn")
    p_spawn.add_argument("--contract", required=True)
    p_spawn.add_argument("--workspace", required=True)
    p_advance = sub.add_parser("advance")
    p_advance.add_argument("--workspace", required=True)
    p_advance.add_argument("--to", required=True)
    p_consume = sub.add_parser("consume-fixture")
    p_consume.add_argument("--workspace", required=True)
    p_consume.add_argument("--evidence", required=True)
    p_status = sub.add_parser("status")
    p_status.add_argument("--workspace", required=True)
    args = parser.parse_args()
    if args.command == "spawn":
        result = spawn(Path(args.contract), Path(args.workspace))
    elif args.command == "advance":
        result = advance(Path(args.workspace), args.to)
    elif args.command == "consume-fixture":
        result = consume_fixture(Path(args.workspace), Path(args.evidence))
    else:
        contract, state = resume(Path(args.workspace))
        result = {"contract": contract, "state": state}
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
