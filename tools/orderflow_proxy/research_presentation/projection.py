"""Deterministic, source-bound OFP preparation projection.

This module intentionally has no MT5, Monitor, Registry, network, or runtime
integration.  It reports only the preregistered plan and the gates visible in
the accepted repository source.  Prose never promotes an experiment to RUN.
"""

from __future__ import annotations

import copy
import datetime as dt
import hashlib
import html
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
from typing import Any


SCHEMA = "ea_lab_orderflow_report_monitor_projection/v1"
MANIFEST_SCHEMA = "ea_lab_orderflow_mt5_proxy_template_seam_v1/v1"
OBSERVATION_SCHEMA = "ea_lab_orderflow_preparation_observation/v1"
MANIFEST_PATH = "portfolio/ORDERFLOW_MT5_PROXY_TEMPLATE_SEAM_V1_20260920.json"
HEX40 = re.compile(r"[0-9a-f]{40}\Z")
HEX64 = re.compile(r"[0-9a-f]{64}\Z")

SYMBOLS = ("XAUUSD", "EURUSD", "GBPUSD", "EURGBP", "USDJPY", "EURJPY")
PARKED_SYMBOLS = ("BTCUSD", "ETHUSD")

# This is a contract lock, not a discovery list.  A future source change needs
# a separately reviewed contract instead of silently changing the projection.
SOURCE_LOCK = {
    "docs/research/ORDERFLOW_MT5_PROXY_TEMPLATE_SEAM_V1_20260920.md": "a62d157fa313390c6d15c0e7b525119792bd050b42da622da9bb8dc4f26a2227",
    "docs/research/ORDERFLOW_MT5_PROXY_V1.md": "f0cd807a8d430959a9ab25c5e161c4385b03b69ec59ee4ac6fa4cc117edd3e4b",
    "ea_template/components/orderflow_proxy/OFPCContinuation.mqh": "906705a5cdc468297ad11d55808330f855d9f99662db6e4fb83fca3c1382b65b",
    "ea_template/components/orderflow_proxy/OFPRReversal.mqh": "978d7b932d242d612a4da51c5a1a2600c7613cfc69bc311fe7a441cd28faa644",
    "ea_template/components/orderflow_proxy/OrderFlowProxyComponents.mqh": "a0f05cb253d5a5690173be12b67a6576549bbcf678fcce302223c2b2d6b8c1a7",
    "ea_template/components/orderflow_proxy/OrderFlowProxyTypes.mqh": "ccf0c1b1a13f9bf57723a631cfd004bcb85cf78cd3127338a14b1050587033d8",
    "ea_template/components/orderflow_proxy/OrderFlowProxyValidation.mqh": "3e61dbc1e79ca5f3008f5bb8e0cc9d630380c2da068effefb79d31dbe000e906",
    "ea_template/components/orderflow_proxy/TickActivityProfile.mqh": "882792c4c861412352981203bd896eff1240ed18d6754b3a7e2f52182f978527",
    "ea_template/components/orderflow_proxy/provider/OrderFlowProxyTemplateSeam.mqh": "ea758969322f46290da7ba457f4a301501e1855f6c7bf85b79cf91e1d01b05cd",
    "ea_template/components/orderflow_proxy/provider/ThinkMarketsA2Evidence.mqh": "026fe3762107cb805e47e6ef8bf7f4a37bbb7dc2d21dacf55402440d810e69c0",
    "ea_template/strategy_cards/orderflow_proxy/OFPC-00_PROFILE_PRICE_CONTROL.md": "1f190e785fe8dd1afa04976d8713000c5677d3be747805ea40af820aed3ca418",
    "ea_template/strategy_cards/orderflow_proxy/OFPC-01_TICK_ACTIVITY.md": "eaa60b5f85cc1d2ff639af18a848b5c030d6eacb450ba0f59182c2eaaed82121",
    "ea_template/strategy_cards/orderflow_proxy/OFPC-02_QUOTE_IMBALANCE.md": "361cf23e8f5da34c9d46c98c54914653c515f667a465c966d2e006623bf28052",
    "ea_template/strategy_cards/orderflow_proxy/OFPR-00_PROFILE_PRICE_CONTROL.md": "cd1709789f49991ba7de4479a473b99892452f1343ecb45d106b215d4e257218",
    "ea_template/strategy_cards/orderflow_proxy/OFPR-01_TICK_ACTIVITY.md": "1756d38eeacb84b5e26e5e372129f39c30615935549ee8a9415c3d95afe2e204",
    "ea_template/strategy_cards/orderflow_proxy/OFPR-02_QUOTE_IMBALANCE.md": "52972f855ab12bb338c52a9080fec34ab63c1b75fef000a7fbdb5d7a1bcfdd32",
    MANIFEST_PATH: "ad6b29fd23afdfb94c8c34c02b3bf6b48d7484b6196256db95767e2c19771721",
    "tools/orderflow_proxy/fixtures/mirrored_cases.json": "55ad678178f4606da64091cb5853b043fb76a89b9ea799970db5c847212f2732",
    "tools/orderflow_proxy/offline_reference.py": "aa14180736f11e9f9a1497bf13ec306945be5d6f937095a803b12e33bcc61b6d",
    "tools/orderflow_proxy/provider_bundle.py": "0742ece8bfee72eb921adb589f730793f479d1b89063213ca5fef1ac9c5cb0bc",
}

BUNDLE_LOCK = {
    "XAUUSD": "eb4ae690ae9c8cbe32e5ca3b69baef1e1ce42ebe63e1fa3eba560ab95da71a8d",
    "EURUSD": "776df940030826e6dc60389c0b2fe731999d66b8853a8651231947f73d1de75c",
    "GBPUSD": "3fa11f7c2db87873dcf809dafa344a487b9869fb091c351d68a3da7da7383046",
    "EURGBP": "330fb9d2e0cdbd4d82ab7fa25c998c47a51a0f1f520cbfe1f14fadc807966c92",
    "USDJPY": "26f6af2bba8bfa786e1940b1f818d4a84d2c7cec3c332ebe65267e5226953287",
    "EURJPY": "e9c2d00c7d193e5e488e0b30bb25418f6f506db7933eb33233ede02c73f10576",
}


class ProjectionError(ValueError):
    """Fail-closed contract or binding error."""


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _expect_keys(value: Any, keys: set[str], where: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ProjectionError(f"MALFORMED_FIELD:{where}:object_required")
    actual = set(value)
    if actual != keys:
        extra = sorted(actual - keys)
        missing = sorted(keys - actual)
        raise ProjectionError(f"UNKNOWN_OR_MISSING_FIELDS:{where}:extra={extra}:missing={missing}")
    return value


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise ProjectionError(code)


def _safe_relative_path(root: Path, relative: str) -> Path:
    _require(isinstance(relative, str) and relative != "", "INVALID_RELATIVE_PATH")
    _require("\\" not in relative and ":" not in relative, "PATH_ESCAPE")
    parsed = PurePosixPath(relative)
    _require(not parsed.is_absolute() and ".." not in parsed.parts, "PATH_ESCAPE")
    try:
        root_resolved = root.resolve(strict=True)
    except OSError as exc:
        raise ProjectionError("DECLARED_ROOT_NOT_FOUND") from exc
    candidate = root.joinpath(*parsed.parts)
    try:
        resolved = candidate.resolve(strict=True)
    except OSError as exc:
        raise ProjectionError("INPUT_PATH_NOT_FOUND") from exc
    try:
        resolved.relative_to(root_resolved)
    except ValueError as exc:
        raise ProjectionError("SYMLINK_OR_PATH_ESCAPE") from exc
    return resolved


def _git(repo_root: Path, *args: str) -> bytes:
    env = os.environ.copy()
    env["GIT_CONFIG_GLOBAL"] = os.devnull
    env["GIT_CONFIG_NOSYSTEM"] = "1"
    try:
        return subprocess.check_output(
            ["git", "--no-optional-locks", "-C", str(repo_root), *args],
            stderr=subprocess.STDOUT,
            env=env,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        detail = getattr(exc, "output", b"").decode("utf-8", "replace").strip()
        raise ProjectionError(f"GIT_READ_FAILED:{detail}") from exc


def _validate_manifest(manifest: Any) -> dict[str, Any]:
    top = _expect_keys(
        manifest,
        {"schema", "date", "status", "canonical_head", "provider_qualification", "template_seam", "semantics", "gates", "authority", "next_gate"},
        "manifest",
    )
    _require(top["schema"] == MANIFEST_SCHEMA, "SOURCE_MANIFEST_SCHEMA_MISMATCH")
    _require(top["date"] == "2026-09-20", "SOURCE_MANIFEST_DATE_MISMATCH")
    _require(top["status"] == "SOURCE_ACCEPTED_REVIEWED_CANONICAL_RESEARCH_INPUT_ONLY", "SOURCE_STATUS_MISMATCH")
    _require(top["canonical_head"] == "5436833f3791049655f3ab44b90582c73d222e1d", "SOURCE_ACCEPTED_HEAD_MISMATCH")
    _require(isinstance(top["next_gate"], str), "MALFORMED_FIELD:next_gate")

    provider = _expect_keys(
        top["provider_qualification"],
        {"provider", "terminal_build", "status", "basis", "qualified_symbols", "blocked_symbols", "review", "true_exchange_orderflow", "executed_volume_or_delta_qualified", "standing_future_window_qualification", "evidence_root", "evidence_manifest_sha256", "review_sha256"},
        "provider_qualification",
    )
    _require(provider["provider"] == "ThinkMarkets-Live", "PROVIDER_MISMATCH")
    _require(type(provider["terminal_build"]) is int and provider["terminal_build"] == 6182, "TERMINAL_BUILD_MISMATCH")
    _require(provider["status"] == "PARTIALLY_QUALIFIED_CURRENT_WINDOW", "PROVIDER_STATUS_MISMATCH")
    _require(provider["basis"] == "MT5_SYNCED_COPY_TICKS_INFO_EXACT_REPEAT_PER_INTERVAL", "PROVIDER_BASIS_MISMATCH")
    _require(provider["qualified_symbols"] == list(SYMBOLS), "QUALIFIED_SYMBOL_SET_MISMATCH")
    _require(provider["blocked_symbols"] == {symbol: "RATE_SNAPSHOT_CHANGED" for symbol in PARKED_SYMBOLS}, "BLOCKED_SYMBOL_SET_MISMATCH")
    _require(provider["review"] == "SCRUTINY_PASS / HIGH", "SOURCE_REVIEW_MISMATCH")
    _require(provider["true_exchange_orderflow"] is False, "TRUE_ORDERFLOW_PROMOTION_REFUSED")
    _require(provider["executed_volume_or_delta_qualified"] is False, "DELTA_PROMOTION_REFUSED")
    _require(provider["standing_future_window_qualification"] is False, "FUTURE_WINDOW_PROMOTION_REFUSED")
    _require(isinstance(provider["evidence_root"], str), "MALFORMED_FIELD:evidence_root")
    _require(HEX64.fullmatch(provider["evidence_manifest_sha256"] or "") is not None, "MALFORMED_EVIDENCE_SHA256")
    _require(HEX64.fullmatch(provider["review_sha256"] or "") is not None, "MALFORMED_REVIEW_SHA256")

    seam = _expect_keys(
        top["template_seam"],
        {"initial_head", "initial_review", "repair_budget", "accepted_head", "targeted_recheck", "accepted_symbols", "blocked_symbols", "bundle_sha256", "source_acceptance_sha256", "targeted_recheck_sha256"},
        "template_seam",
    )
    _require(seam["initial_head"] == "654cdf6d4e7bfd35b6e4fb4d8847e20c9ea6b50d", "INITIAL_HEAD_MISMATCH")
    _require(seam["initial_review"] == "SCRUTINY_REPAIR_REQUIRED / HIGH / OFP-SEAM-V1-001", "INITIAL_REVIEW_MISMATCH")
    _require(seam["repair_budget"] == "1/1_USED", "REPAIR_HISTORY_MISMATCH")
    _require(seam["accepted_head"] == top["canonical_head"], "ACCEPTED_HEAD_MISMATCH")
    _require(seam["targeted_recheck"] == "SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION", "RECHECK_MISMATCH")
    _require(seam["accepted_symbols"] == list(SYMBOLS), "SEAM_SYMBOL_SET_MISMATCH")
    _require(seam["blocked_symbols"] == provider["blocked_symbols"], "SEAM_BLOCKED_SYMBOL_MISMATCH")
    _require(seam["bundle_sha256"] == BUNDLE_LOCK, "BUNDLE_HASH_SET_MISMATCH")
    _require(HEX64.fullmatch(seam["source_acceptance_sha256"] or "") is not None, "MALFORMED_SOURCE_ACCEPTANCE_SHA256")
    _require(HEX64.fullmatch(seam["targeted_recheck_sha256"] or "") is not None, "MALFORMED_RECHECK_SHA256")

    semantics = _expect_keys(
        top["semantics"],
        {"geometry_preserved", "current_entry_signal_compatible", "order_execution_authorized", "true_orderflow", "executed_volume_delta_qualified", "time_exit_consumer_owned"},
        "semantics",
    )
    _require(semantics == {"geometry_preserved": True, "current_entry_signal_compatible": False, "order_execution_authorized": False, "true_orderflow": False, "executed_volume_delta_qualified": False, "time_exit_consumer_owned": True}, "SEMANTICS_PROMOTION_OR_MISMATCH")

    gates = _expect_keys(top["gates"], {"provider_bundle", "existing_proxy", "mirrored_fixtures", "template_seam_compile", "proxy_components_compile", "native_execution", "protected_tracked_files", "byte_mismatches"}, "gates")
    _require(gates["native_execution"] == "NOT_EXECUTED", "NATIVE_EXECUTION_PROMOTION_REFUSED")
    _require(type(gates["protected_tracked_files"]) is int and type(gates["byte_mismatches"]) is int, "MALFORMED_GATE_COUNTS")
    _require(gates["byte_mismatches"] == 0, "SOURCE_BYTE_MISMATCH_RECORDED")

    authority = _expect_keys(top["authority"], {"research_input_only", "backtest", "performance", "optimization", "model4", "holdout", "candidate", "runtime", "deployment", "trading"}, "authority")
    _require(authority["research_input_only"] is True, "RESEARCH_INPUT_AUTHORITY_MISMATCH")
    _require(all(authority[name] is False for name in authority if name != "research_input_only"), "AUTHORITY_PROMOTION_REFUSED")
    return top


def bind_repository(repo_root: Path, repo_ref: str) -> tuple[dict[str, Any], list[dict[str, str]], str]:
    _require(HEX40.fullmatch(repo_ref or "") is not None, "EXACT_40_HEX_REF_REQUIRED")
    root = repo_root.resolve(strict=True)
    commit = _git(root, "rev-parse", "--verify", f"{repo_ref}^{{commit}}").decode().strip()
    head = _git(root, "rev-parse", "HEAD").decode().strip()
    _require(commit == repo_ref, "REF_RESOLUTION_MISMATCH")
    _require(head == repo_ref, "CHECKOUT_HEAD_MISMATCH")

    bindings: list[dict[str, str]] = []
    manifest_bytes = b""
    for relative, expected_sha in sorted(SOURCE_LOCK.items()):
        committed = _git(root, "show", f"{repo_ref}:{relative}")
        actual_sha = _sha256(committed)
        _require(actual_sha == expected_sha, f"SOURCE_LOCK_MISMATCH:{relative}")
        worktree_path = _safe_relative_path(root, relative)
        _require(worktree_path.is_file(), f"SOURCE_NOT_FILE:{relative}")
        _require(worktree_path.read_bytes() == committed, f"DIRTY_INPUT_BYTES:{relative}")
        blob = _git(root, "rev-parse", f"{repo_ref}:{relative}").decode().strip()
        _require(HEX40.fullmatch(blob) is not None, f"INVALID_GIT_BLOB:{relative}")
        bindings.append({"path": relative, "sha256": actual_sha, "git_blob": blob})
        if relative == MANIFEST_PATH:
            manifest_bytes = committed

    try:
        manifest = json.loads(manifest_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ProjectionError("MALFORMED_SOURCE_MANIFEST_JSON") from exc
    validated = _validate_manifest(manifest)
    set_preimage = "".join(f"{item['path']}\0{item['sha256']}\n" for item in bindings).encode("utf-8")
    return validated, bindings, _sha256(set_preimage)


def _parse_utc(value: Any, field: str) -> dt.datetime:
    _require(isinstance(value, str) and value.endswith("Z"), f"MALFORMED_FIELD:{field}")
    try:
        parsed = dt.datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise ProjectionError(f"MALFORMED_FIELD:{field}") from exc
    _require(parsed.tzinfo == dt.timezone.utc, f"MALFORMED_FIELD:{field}")
    return parsed


def validate_observation(observation: Any, repo_ref: str, manifest_sha256: str, as_of_utc: str) -> dict[str, Any]:
    obj = _expect_keys(
        observation,
        {"schema", "source_ref", "source_artifact_path", "source_artifact_sha256", "observed_at_utc", "valid_until_utc", "observation_kind", "execution_status", "executed_cells", "performance_metrics", "claims", "monitor"},
        "observation",
    )
    _require(obj["schema"] == OBSERVATION_SCHEMA, "OBSERVATION_SCHEMA_MISMATCH")
    _require(obj["source_ref"] == repo_ref, "UNBOUND_OBSERVATION_REF")
    _require(obj["source_artifact_path"] == MANIFEST_PATH, "UNBOUND_OBSERVATION_PATH")
    _require(obj["source_artifact_sha256"] == manifest_sha256, "UNBOUND_OBSERVATION_HASH")
    _require(obj["observation_kind"] == "PREPARATION_STATUS_ONLY", "OBSERVATION_KIND_REFUSED")
    _require(obj["execution_status"] == "NOT_RUN", "OBSERVATION_EXECUTION_PROMOTION_REFUSED")
    _require(type(obj["executed_cells"]) is int and obj["executed_cells"] == 0, "OBSERVATION_EXECUTED_CELLS_REFUSED")
    _require(obj["performance_metrics"] is None, "INVENTED_PERFORMANCE_REFUSED")
    claims = _expect_keys(obj["claims"], {"true_orderflow", "executed_volume_delta_qualified", "order_execution_authorized"}, "observation.claims")
    _require(all(value is False for value in claims.values()), "OBSERVATION_AUTHORITY_PROMOTION_REFUSED")
    monitor = _expect_keys(obj["monitor"], {"wired", "deployed", "live_refresh_asserted"}, "observation.monitor")
    _require(all(value is False for value in monitor.values()), "OBSERVATION_MONITOR_PROMOTION_REFUSED")
    observed = _parse_utc(obj["observed_at_utc"], "observed_at_utc")
    valid_until = _parse_utc(obj["valid_until_utc"], "valid_until_utc")
    as_of = _parse_utc(as_of_utc, "observation_as_of_utc")
    _require(observed <= as_of <= valid_until, "STALE_OR_FUTURE_OBSERVATION")
    return obj


def _variants() -> list[dict[str, Any]]:
    return [
        {"family": "OFPR", "variant": "OFPR-00", "parent": None, "one_change": "Profile, price, wick, trigger, and geometry control; no activity or imbalance gate.", "hypothesis": "CONTROL_ONLY_PENDING_QUALIFIED_DATA", "expected_cost": "Control may retain quote-path noise."},
        {"family": "OFPR", "variant": "OFPR-01", "parent": "OFPR-00", "one_change": "Add the test-bar relative tick-activity gate.", "hypothesis": "Activity may improve event selection after prerequisite gates.", "expected_cost": "Fewer eligible events."},
        {"family": "OFPR", "variant": "OFPR-02", "parent": "OFPR-01", "one_change": "Add the test-bar quote-direction imbalance gate.", "hypothesis": "Quote-direction imbalance may further filter rejection events after prerequisite gates.", "expected_cost": "Fewer eligible events and stronger quote-path dependence."},
        {"family": "OFPC", "variant": "OFPC-00", "parent": None, "one_change": "Profile, price, breakout, retest, confirmation, and geometry control; no activity or imbalance gate.", "hypothesis": "CONTROL_ONLY_PENDING_QUALIFIED_DATA", "expected_cost": "Control may retain quote-path noise."},
        {"family": "OFPC", "variant": "OFPC-01", "parent": "OFPC-00", "one_change": "Add the second-breakout relative tick-activity gate.", "hypothesis": "Activity may improve event selection after prerequisite gates.", "expected_cost": "Fewer eligible events."},
        {"family": "OFPC", "variant": "OFPC-02", "parent": "OFPC-01", "one_change": "Add second-breakout and confirmation quote-direction imbalance gates.", "hypothesis": "Quote-direction imbalance may further filter continuation events after prerequisite gates.", "expected_cost": "Fewer eligible events and stronger quote-path dependence."},
    ]


def build_projection(manifest: dict[str, Any], bindings: list[dict[str, str]], source_set_sha256: str, repo_ref: str, observation: dict[str, Any] | None = None, observation_as_of_utc: str | None = None) -> dict[str, Any]:
    _validate_manifest(copy.deepcopy(manifest))
    manifest_binding = next((item for item in bindings if item["path"] == MANIFEST_PATH), None)
    _require(manifest_binding is not None, "MANIFEST_BINDING_MISSING")
    observed = None
    if observation is not None:
        _require(observation_as_of_utc is not None, "OBSERVATION_AS_OF_REQUIRED")
        observed = validate_observation(observation, repo_ref, manifest_binding["sha256"], observation_as_of_utc)

    projection = {
        "schema": SCHEMA,
        "report": {
            "heading": "PREPARATION REPORT / NOT A BACKTEST REPORT",
            "ladder_stage": "R0_PREPARATION",
            "status": "WAITING_GATES_NOT_RUN",
            "direct_consumer": "EXISTING_MONITOR_INTEGRATOR_AFTER_SERIALIZER_AND_UI_OWNERSHIP_IS_FREE",
            "authority_ceiling": "RESEARCH_PREPARATION_ONLY",
        },
        "source_binding": {
            "projection_source_ref": repo_ref,
            "accepted_source_status_commit": manifest["canonical_head"],
            "manifest_path": MANIFEST_PATH,
            "manifest_sha256": manifest_binding["sha256"],
            "source_set_sha256": source_set_sha256,
            "source_artifacts": bindings,
            "source_acceptance_scope": "HISTORICAL_SRC_ACCEPTANCE_EXACT_WINDOW_ONLY",
            "source_status": manifest["status"],
        },
        "observation": {
            "status": "BOUND_METADATA_ONLY" if observed else "NOT_SUPPLIED",
            "observed_at_utc": observed["observed_at_utc"] if observed else None,
            "valid_until_utc": observed["valid_until_utc"] if observed else None,
            "validation_as_of_utc": observation_as_of_utc if observed else None,
            "freshness": "NOT_ASSERTED",
            "basis": "CALLER_SUPPLIED_BOUND_METADATA_NOT_RUNTIME_LIVENESS" if observed else "NO_OBSERVATION_NO_RUNTIME_LIVENESS_CLAIM",
        },
        "claims": {
            "true_orderflow": False,
            "executed_volume_delta_qualified": False,
            "order_execution_authorized": False,
            "backtest_report": False,
            "candidate_or_grade_recommendation": False,
        },
        "scope": {
            "exact_window_only_symbols": [{"symbol": symbol, "source_status": "EXACT_WINDOW_ONLY"} for symbol in SYMBOLS],
            "parked_symbols": [{"symbol": symbol, "status": "PARKED", "reason": "RATE_SNAPSHOT_CHANGED", "fallback": None} for symbol in PARKED_SYMBOLS],
            "timeframes": [
                {"timeframe": "D1", "role": "PROFILE", "source_mechanics": "DEFINED", "historical_data": "WAITING_GATE"},
                {"timeframe": "M15", "role": "CONTEXT", "source_mechanics": "DEFINED", "historical_data": "WAITING_GATE"},
                {"timeframe": "M5", "role": "SIGNAL", "source_mechanics": "DEFINED", "historical_data": "WAITING_GATE"},
            ],
        },
        "experiment_plan": {
            "variants": _variants(),
            "frozen_mechanics": "Existing geometry and thresholds remain unchanged; P0 still consumes quote ticks for its activity profile.",
            "parent_observation": "NO_PARENT_PERFORMANCE_OBSERVED_FOR_THIS_RESEARCH_DESIGN",
            "windows": [
                {"name": "MAIN", "requested_range": "2023-01-01/2025-12-31", "status": "REQUESTED_NOT_QUALIFIED", "planned_cells": 36, "executed_cells": 0},
                {"name": "BWD", "requested_range": "2020-01-01/2022-12-31", "status": "REQUESTED_NOT_QUALIFIED_FROZEN_FALSIFICATION_SURFACE", "planned_cells": 36, "executed_cells": 0},
            ],
            "total_planned_cells": 72,
            "total_executed_cells": 0,
            "holdout": "UNTOUCHED_2026H1",
            "future_performance_schema": "OUT_OF_SCOPE_UNTIL_RAW_RESULT_CONTRACT_AND_REVIEW_IDENTITY_EXIST",
            "stop_condition": "DO_NOT_EXECUTE_UNTIL_HISTORICAL_DATA_NATIVE_PARITY_AND_EXECUTION_CONTRACT_GATES_PASS",
        },
        "gate_status": [
            {"gate": "CURRENT_WINDOW_SOURCE_ACCEPTANCE", "state": "SOURCE_FACT_EXACT_WINDOW_ONLY", "reason": "Six named A2 bundles are historically accepted only for their frozen current windows."},
            {"gate": "HISTORICAL_RAW_DATASET", "state": "WAITING_GATE", "reason": "Current-window hashes and counts are not historical raw bid/ask/time/flags data."},
            {"gate": "HISTORICAL_MANIFEST_BUNDLE_CONTRACT", "state": "WAITING_GATE", "reason": "No separately reviewed historical trust root is supplied."},
            {"gate": "PYTHON_MQL_NATIVE_PARITY", "state": "WAITING_GATE", "reason": "Native event and geometry parity is not qualified."},
            {"gate": "GEOMETRY_AWARE_EXECUTION_CONTRACT", "state": "WAITING_GATE", "reason": "Entry, fill, arbitration, cost, lot, leverage, rounding, rejection, exit, and safety semantics remain unfrozen."},
            {"gate": "MAIN_AND_BWD_EXECUTION", "state": "NOT_RUN", "reason": "Prerequisite gates are incomplete; prose containing RUN or Model4 is not execution evidence."},
        ],
        "performance": {
            "status": "NOT_RUN",
            "reason": "NO_RAW_RESULT_CONTRACT_OR_REVIEW_IDENTITY",
            "metrics": {"profit_factor": None, "net": None, "drawdown": None, "trades_or_episodes": None, "expectancy": None, "participation": None},
            "native_equity": {"status": "UNAVAILABLE", "series": None},
            "graphs": [],
        },
        "source_history": {
            "initial_head": manifest["template_seam"]["initial_head"],
            "initial_review": manifest["template_seam"]["initial_review"],
            "repair_budget": manifest["template_seam"]["repair_budget"],
            "accepted_head": manifest["template_seam"]["accepted_head"],
            "targeted_recheck": manifest["template_seam"]["targeted_recheck"],
            "history_kind": "CLOSED_SOURCE_REPAIR_FACTS_NOT_PERFORMANCE_EVIDENCE",
        },
        "monitor_projection": {"wired": False, "deployed": False, "live_refresh_asserted": False, "replacement_monitor": False},
        "artifact_link_policy": {"allowed": "RELATIVE_CONTENT_ADDRESSED_ONLY", "links": []},
        "limitations": [
            "No historical raw quote dataset is qualified.",
            "No Python/MQL native event or geometry parity is qualified.",
            "No geometry-aware execution contract is frozen.",
            "No MAIN, BWD, Model4, HOLDOUT, optimization, Candidate, runtime, deployment, or trading result exists here.",
            "File mtime, wall time, generated output, and prose do not establish freshness or execution.",
        ],
    }
    validate_projection(projection)
    return projection


def build_bound_projection(repo_root: Path, repo_ref: str, observation: dict[str, Any] | None = None, observation_as_of_utc: str | None = None) -> dict[str, Any]:
    manifest, bindings, source_set_sha256 = bind_repository(repo_root, repo_ref)
    return build_projection(manifest, bindings, source_set_sha256, repo_ref, observation, observation_as_of_utc)


def validate_projection(projection: Any) -> None:
    obj = _expect_keys(projection, {"schema", "report", "source_binding", "observation", "claims", "scope", "experiment_plan", "gate_status", "performance", "source_history", "monitor_projection", "artifact_link_policy", "limitations"}, "projection")
    _require(obj["schema"] == SCHEMA, "PROJECTION_SCHEMA_MISMATCH")
    report = _expect_keys(obj["report"], {"heading", "ladder_stage", "status", "direct_consumer", "authority_ceiling"}, "projection.report")
    _require(report["heading"] == "PREPARATION REPORT / NOT A BACKTEST REPORT", "REPORT_HEADING_MISMATCH")
    _require(report["status"] == "WAITING_GATES_NOT_RUN", "SOURCE_PROMOTION_REFUSED")
    source = _expect_keys(obj["source_binding"], {"projection_source_ref", "accepted_source_status_commit", "manifest_path", "manifest_sha256", "source_set_sha256", "source_artifacts", "source_acceptance_scope", "source_status"}, "projection.source_binding")
    _require(HEX40.fullmatch(source["projection_source_ref"] or "") is not None, "INVALID_PROJECTION_SOURCE_REF")
    _require(HEX40.fullmatch(source["accepted_source_status_commit"] or "") is not None, "INVALID_ACCEPTED_SOURCE_HEAD")
    _require(source["manifest_path"] == MANIFEST_PATH, "INVALID_MANIFEST_PATH")
    _require(HEX64.fullmatch(source["manifest_sha256"] or "") is not None and HEX64.fullmatch(source["source_set_sha256"] or "") is not None, "INVALID_SOURCE_HASH")
    _require(source["source_acceptance_scope"] == "HISTORICAL_SRC_ACCEPTANCE_EXACT_WINDOW_ONLY", "SOURCE_SCOPE_PROMOTION_REFUSED")
    _require(isinstance(source["source_artifacts"], list) and len(source["source_artifacts"]) == len(SOURCE_LOCK), "SOURCE_ARTIFACT_SET_MISMATCH")
    for item in source["source_artifacts"]:
        artifact = _expect_keys(item, {"path", "sha256", "git_blob"}, "projection.source_artifact")
        _require(artifact["path"] in SOURCE_LOCK and artifact["sha256"] == SOURCE_LOCK[artifact["path"]], "SOURCE_ARTIFACT_LOCK_MISMATCH")
        _require(HEX40.fullmatch(artifact["git_blob"] or "") is not None, "INVALID_SOURCE_BLOB")
    claims = _expect_keys(obj["claims"], {"true_orderflow", "executed_volume_delta_qualified", "order_execution_authorized", "backtest_report", "candidate_or_grade_recommendation"}, "projection.claims")
    _require(all(value is False for value in claims.values()), "CLAIM_PROMOTION_REFUSED")
    observation = _expect_keys(obj["observation"], {"status", "observed_at_utc", "valid_until_utc", "validation_as_of_utc", "freshness", "basis"}, "projection.observation")
    _require(observation["status"] in {"NOT_SUPPLIED", "BOUND_METADATA_ONLY"} and observation["freshness"] == "NOT_ASSERTED", "OBSERVATION_PROMOTION_REFUSED")
    if observation["status"] == "NOT_SUPPLIED":
        _require(all(observation[name] is None for name in ("observed_at_utc", "valid_until_utc", "validation_as_of_utc")), "UNBOUND_OBSERVATION_METADATA")
    scope = _expect_keys(obj["scope"], {"exact_window_only_symbols", "parked_symbols", "timeframes"}, "projection.scope")
    symbols = scope["exact_window_only_symbols"]
    _require(isinstance(symbols, list) and all(isinstance(item, dict) and set(item) == {"symbol", "source_status"} for item in symbols), "MALFORMED_SYMBOL_SCOPE")
    _require([item["symbol"] for item in symbols] == list(SYMBOLS) and all(item["source_status"] == "EXACT_WINDOW_ONLY" for item in symbols), "SIX_SYMBOL_SCOPE_MISMATCH")
    parked = scope["parked_symbols"]
    _require(isinstance(parked, list) and all(isinstance(item, dict) and set(item) == {"symbol", "status", "reason", "fallback"} for item in parked), "MALFORMED_PARKED_SCOPE")
    _require([item["symbol"] for item in parked] == list(PARKED_SYMBOLS), "PARKED_SYMBOL_SCOPE_MISMATCH")
    _require(all(item == {"symbol": item["symbol"], "status": "PARKED", "reason": "RATE_SNAPSHOT_CHANGED", "fallback": None} for item in parked), "PARKED_SYMBOL_FALLBACK_REFUSED")
    timeframes = scope["timeframes"]
    _require(isinstance(timeframes, list) and [item.get("timeframe") for item in timeframes if isinstance(item, dict)] == ["D1", "M15", "M5"], "TIMEFRAME_SCOPE_MISMATCH")
    _require(all(set(item) == {"timeframe", "role", "source_mechanics", "historical_data"} and item["source_mechanics"] == "DEFINED" and item["historical_data"] == "WAITING_GATE" for item in timeframes), "TIMEFRAME_STATUS_PROMOTION_REFUSED")
    plan = _expect_keys(obj["experiment_plan"], {"variants", "frozen_mechanics", "parent_observation", "windows", "total_planned_cells", "total_executed_cells", "holdout", "future_performance_schema", "stop_condition"}, "projection.experiment_plan")
    _require(plan["total_planned_cells"] == 72 and plan["total_executed_cells"] == 0, "CELL_COUNT_PROMOTION_REFUSED")
    _require(isinstance(plan["variants"], list) and len(plan["variants"]) == 6, "VARIANT_COUNT_MISMATCH")
    _require(all(isinstance(item, dict) and set(item) == {"family", "variant", "parent", "one_change", "hypothesis", "expected_cost"} for item in plan["variants"]), "MALFORMED_VARIANT")
    _require([item["variant"] for item in plan["variants"]] == ["OFPR-00", "OFPR-01", "OFPR-02", "OFPC-00", "OFPC-01", "OFPC-02"], "VARIANT_IDENTITY_MISMATCH")
    _require(isinstance(plan["windows"], list) and all(isinstance(item, dict) and set(item) == {"name", "requested_range", "status", "planned_cells", "executed_cells"} for item in plan["windows"]), "MALFORMED_WINDOW_PLAN")
    _require(sum(item["planned_cells"] for item in plan["windows"]) == 72 and all(item["executed_cells"] == 0 for item in plan["windows"]), "WINDOW_CELL_COUNT_MISMATCH")
    _require(plan["holdout"] == "UNTOUCHED_2026H1", "HOLDOUT_PROMOTION_REFUSED")
    gates = obj["gate_status"]
    _require(isinstance(gates, list) and len(gates) == 6 and all(isinstance(item, dict) and set(item) == {"gate", "state", "reason"} for item in gates), "MALFORMED_GATE_STATUS")
    _require(gates[-1]["gate"] == "MAIN_AND_BWD_EXECUTION" and gates[-1]["state"] == "NOT_RUN", "EXECUTION_STATUS_PROMOTION_REFUSED")
    performance = _expect_keys(obj["performance"], {"status", "reason", "metrics", "native_equity", "graphs"}, "projection.performance")
    metrics = _expect_keys(performance["metrics"], {"profit_factor", "net", "drawdown", "trades_or_episodes", "expectancy", "participation"}, "projection.performance.metrics")
    _require(performance["status"] == "NOT_RUN" and all(value is None for value in performance["metrics"].values()), "INVENTED_PERFORMANCE_REFUSED")
    _require(all(value is None for value in metrics.values()), "INVENTED_PERFORMANCE_REFUSED")
    _require(performance["native_equity"] == {"status": "UNAVAILABLE", "series": None}, "NATIVE_EQUITY_PROMOTION_REFUSED")
    _require(performance["graphs"] == [], "PREPARATION_GRAPHS_REFUSED")
    history = _expect_keys(obj["source_history"], {"initial_head", "initial_review", "repair_budget", "accepted_head", "targeted_recheck", "history_kind"}, "projection.source_history")
    _require(history["history_kind"] == "CLOSED_SOURCE_REPAIR_FACTS_NOT_PERFORMANCE_EVIDENCE", "SOURCE_HISTORY_PROMOTION_REFUSED")
    monitor = _expect_keys(obj["monitor_projection"], {"wired", "deployed", "live_refresh_asserted", "replacement_monitor"}, "projection.monitor")
    _require(all(value is False for value in monitor.values()), "MONITOR_PROMOTION_REFUSED")
    links = _expect_keys(obj["artifact_link_policy"], {"allowed", "links"}, "projection.artifact_link_policy")
    _require(links == {"allowed": "RELATIVE_CONTENT_ADDRESSED_ONLY", "links": []}, "ARTIFACT_LINK_POLICY_MISMATCH")
    _require(isinstance(obj["limitations"], list) and obj["limitations"] and all(isinstance(item, str) and item for item in obj["limitations"]), "MALFORMED_LIMITATIONS")


def serialize_projection(projection: dict[str, Any]) -> bytes:
    validate_projection(projection)
    return (json.dumps(projection, sort_keys=True, indent=2, ensure_ascii=True) + "\n").encode("utf-8")


def _e(value: Any) -> str:
    if value is None:
        return "UNAVAILABLE"
    if isinstance(value, bool):
        value = "true" if value else "false"
    return html.escape(str(value), quote=True)


def render_html(projection: dict[str, Any]) -> bytes:
    validate_projection(projection)
    report = projection["report"]
    source = projection["source_binding"]
    scope = projection["scope"]
    plan = projection["experiment_plan"]
    perf = projection["performance"]
    rows = "".join(
        f"<tr><td>{_e(v['variant'])}</td><td>{_e(v['parent'])}</td><td>{_e(v['one_change'])}</td><td>{_e(v['hypothesis'])}</td><td>{_e(v['expected_cost'])}</td></tr>"
        for v in plan["variants"]
    )
    gates = "".join(
        f"<tr><td>{_e(g['gate'])}</td><td><span class='state'>{_e(g['state'])}</span></td><td>{_e(g['reason'])}</td></tr>"
        for g in projection["gate_status"]
    )
    accepted = "".join(f"<li><strong>{_e(s['symbol'])}</strong> — {_e(s['source_status'])}</li>" for s in scope["exact_window_only_symbols"])
    parked = "".join(f"<li><strong>{_e(s['symbol'])}</strong> — {_e(s['status'])}: {_e(s['reason'])}; fallback {_e(s['fallback'])}</li>" for s in scope["parked_symbols"])
    windows = "".join(f"<tr><td>{_e(w['name'])}</td><td>{_e(w['requested_range'])}</td><td>{_e(w['status'])}</td><td>{_e(w['planned_cells'])}</td><td>{_e(w['executed_cells'])}</td></tr>" for w in plan["windows"])
    limits = "".join(f"<li>{_e(item)}</li>" for item in projection["limitations"])
    metrics = "".join(f"<tr><td>{_e(name)}</td><td>{_e(value)}</td><td>{_e(perf['reason'])}</td></tr>" for name, value in perf["metrics"].items())
    artifact_rows = "".join(f"<tr><td><code>{_e(a['path'])}</code></td><td><code>{_e(a['sha256'])}</code></td></tr>" for a in source["source_artifacts"])
    document = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{_e(report['heading'])}</title>
<style>body{{margin:0;background:#0b1020;color:#e7ecf5;font:15px/1.5 system-ui,sans-serif}}main{{max-width:1120px;margin:auto;padding:24px}}h1{{font-size:clamp(1.55rem,4vw,2.45rem);line-height:1.1}}h2{{margin-top:32px}}.banner{{border:2px solid #f0b429;background:#2d2511;padding:16px;border-radius:10px}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:16px}}.card{{background:#151d31;border:1px solid #32415f;border-radius:10px;padding:16px;overflow-wrap:anywhere}}table{{width:100%;border-collapse:collapse;background:#11192b}}th,td{{border:1px solid #34415b;padding:9px;text-align:left;vertical-align:top}}th{{background:#1c2944}}code{{font-size:.82rem}}.scroll{{overflow-x:auto}}.state{{font-weight:700;color:#ffd166}}.null{{color:#ff9f9f}}footer{{margin-top:30px;color:#aab5ca}}@media(max-width:520px){{main{{padding:14px}}th,td{{padding:7px;font-size:.87rem}}}}</style></head>
<body><main><section class="banner"><h1>{_e(report['heading'])}</h1><p>Status: <strong>{_e(report['status'])}</strong>. Authority: {_e(report['authority_ceiling'])}.</p><p>This is an R0 readiness view. It contains no backtest, performance, Candidate, grade, runtime, deployment, or trading recommendation.</p></section>
<h2>Source, data, and execution are separate</h2><div class="grid">
<section class="card"><h3>Source acceptance</h3><p>Historical SRC acceptance only: <strong>{_e(source['source_acceptance_scope'])}</strong>.</p><p>Projection ref:<br><code>{_e(source['projection_source_ref'])}</code></p><p>Accepted source status commit:<br><code>{_e(source['accepted_source_status_commit'])}</code></p><p>Manifest SHA-256:<br><code>{_e(source['manifest_sha256'])}</code></p></section>
<section class="card"><h3>Data readiness</h3><p><strong>WAITING_GATE</strong></p><p>No qualified historical raw bid/ask/time/flags dataset or historical trust-root bundle exists in this report.</p></section>
<section class="card"><h3>Execution</h3><p><strong>NOT_RUN</strong></p><p>Planned: {_e(plan['total_planned_cells'])}. Executed: {_e(plan['total_executed_cells'])}. Model4 prose is not execution evidence.</p></section>
<section class="card"><h3>Observation / Monitor</h3><p>Observation: {_e(projection['observation']['status'])}; freshness: {_e(projection['observation']['freshness'])}.</p><p>Monitor wired: {_e(projection['monitor_projection']['wired'])}; deployed: {_e(projection['monitor_projection']['deployed'])}; live refresh: {_e(projection['monitor_projection']['live_refresh_asserted'])}.</p></section></div>
<h2>Symbol scope</h2><div class="grid"><section class="card"><h3>Six exact-window source facts</h3><ul>{accepted}</ul></section><section class="card"><h3>Parked, no fallback</h3><ul>{parked}</ul></section></div>
<h2>Frozen one-change plan</h2><div class="scroll"><table><thead><tr><th>Variant</th><th>Parent</th><th>One logical change</th><th>R0 hypothesis</th><th>Expected cost</th></tr></thead><tbody>{rows}</tbody></table></div>
<p>{_e(plan['frozen_mechanics'])}</p>
<h2>Requested windows — not qualified</h2><div class="scroll"><table><thead><tr><th>Window</th><th>Requested range</th><th>Status</th><th>Planned</th><th>Executed</th></tr></thead><tbody>{windows}</tbody></table></div>
<h2>Prerequisite gates</h2><div class="scroll"><table><thead><tr><th>Gate</th><th>State</th><th>Reason</th></tr></thead><tbody>{gates}</tbody></table></div>
<h2>Performance is absent, not zero</h2><p>Status: <strong>{_e(perf['status'])}</strong>. Native equity: <strong>{_e(perf['native_equity']['status'])}</strong>. No graphs are rendered because there are no bound results.</p><div class="scroll"><table><thead><tr><th>Metric</th><th>Value</th><th>Reason</th></tr></thead><tbody>{metrics}</tbody></table></div>
<h2>Source artifact binding</h2><p>Source-set SHA-256: <code>{_e(source['source_set_sha256'])}</code>. Paths are display-only repository-relative identities; this report emits no links.</p><div class="scroll"><table><thead><tr><th>Repository path</th><th>SHA-256</th></tr></thead><tbody>{artifact_rows}</tbody></table></div>
<h2>Limitations</h2><ul>{limits}</ul>
<footer>Direct consumer: {_e(report['direct_consumer'])}. Relative content-addressed artifact links only; current link set is empty.</footer></main></body></html>"""
    return document.encode("utf-8")


def load_observation_file(root: Path, relative_path: str) -> dict[str, Any]:
    path = _safe_relative_path(root, relative_path)
    _require(path.is_file(), "OBSERVATION_NOT_FILE")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ProjectionError("MALFORMED_OBSERVATION_JSON") from exc
    _require(isinstance(value, dict), "MALFORMED_OBSERVATION_JSON")
    return value


def safe_output_name(name: str, suffix: str) -> str:
    _require(isinstance(name, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,119}", name) is not None, "INVALID_OUTPUT_FILENAME")
    _require(name.endswith(suffix), "INVALID_OUTPUT_SUFFIX")
    _require(".." not in name, "OUTPUT_FILENAME_TRAVERSAL")
    return name
