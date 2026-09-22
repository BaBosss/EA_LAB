from __future__ import annotations

from typing import Any

from .core import Refused, checksum, count, finite, stable_hash, text

_HASH_KEYS = {
    "ea_source_sha256", "ex5_sha256", "set_sha256",
    "dataset_sha256", "broker_clock_sha256",
}
_LABEL_KEYS = {
    "install_id", "tester_model", "symbol", "timeframe",
    "window_id", "config_id",
}
_IDENTITY_KEYS = _HASH_KEYS | _LABEL_KEYS
_EVIDENCE_KEYS = {
    "year_split_sha256", "regime_split_sha256",
    "source_coverage_sha256", "transaction_economics_sha256",
}
_METRIC_KEYS = {
    "net", "pf_value", "pf_status", "eq_dd_pct", "eq_dd_definition",
    "closed_trades", "episodes", "max_exposure", "max_exposure_definition",
    "hard_kills", "guard_firings", "attempts_blocked", "contact_seconds",
    "time_in_market_seconds", "tail_loss_value", "tail_loss_definition",
}
_PF_STATES = {"FINITE", "UNDEFINED_NO_GROSS_LOSS", "UNAVAILABLE"}
_ARM_KINDS = {"BASE", "REAL_GUARD", "PLACEBO"}


def _metric_number(metrics: dict[str, Any], key: str) -> float:
    return finite(metrics[key])


def _validate_metrics(metrics: Any) -> dict[str, Any]:
    if not isinstance(metrics, dict) or set(metrics) != _METRIC_KEYS:
        raise Refused("RESULT_METRIC_SCHEMA_MISMATCH")
    out = dict(metrics)
    out["net"] = _metric_number(metrics, "net")
    out["eq_dd_pct"] = _metric_number(metrics, "eq_dd_pct")
    out["max_exposure"] = _metric_number(metrics, "max_exposure")
    out["tail_loss_value"] = _metric_number(metrics, "tail_loss_value")
    out["eq_dd_definition"] = text(metrics["eq_dd_definition"])
    out["max_exposure_definition"] = text(metrics["max_exposure_definition"])
    out["tail_loss_definition"] = text(metrics["tail_loss_definition"])
    if out["eq_dd_pct"] < 0 or out["max_exposure"] < 0 or out["tail_loss_value"] < 0:
        raise Refused("NEGATIVE_RISK_METRIC")
    for key in ("closed_trades", "episodes", "hard_kills", "guard_firings",
                "attempts_blocked", "contact_seconds", "time_in_market_seconds"):
        out[key] = count(metrics[key])
    status = metrics["pf_status"]
    if status not in _PF_STATES:
        raise Refused("PF_STATUS_UNKNOWN")
    value = metrics["pf_value"]
    if status == "FINITE":
        value = finite(value)
        if value < 0:
            raise Refused("PF_NEGATIVE")
    elif value is not None:
        raise Refused("PF_NONFINITE_STATUS_REQUIRES_NULL")
    out["pf_value"] = value
    return out


def compare_guard_ab(package: dict[str, Any]) -> dict[str, Any]:
    """Validate one frozen full-engine result family and report deltas only."""
    fields = {
        "schema_version", "changed_dimension", "evaluation_unit",
        "holdout_used", "frozen_identity", "placebo_seeds", "arms",
    }
    if not isinstance(package, dict) or set(package) != fields:
        raise Refused("RESULT_PACKAGE_SCHEMA_MISMATCH")
    if package["schema_version"] != "guard_ab_result_package/1":
        raise Refused("RESULT_PACKAGE_SCHEMA_MISMATCH")
    changed = text(package["changed_dimension"])
    if package["evaluation_unit"] not in ("TRADE", "BASKET_EPISODE"):
        raise Refused("UNKNOWN_EVALUATION_UNIT")
    if package["holdout_used"] is not False:
        raise Refused("HOLDOUT_AUTHORITY_REFUSED")

    identity = package["frozen_identity"]
    if not isinstance(identity, dict) or set(identity) != _IDENTITY_KEYS:
        raise Refused("FROZEN_IDENTITY_SCHEMA_MISMATCH")
    for key in _HASH_KEYS:
        checksum(identity[key])
    for key in _LABEL_KEYS:
        text(identity[key])
    identity_sha = stable_hash(identity)

    seeds = package["placebo_seeds"]
    if (not isinstance(seeds, list) or
            any(type(s) is not int or s < 0 for s in seeds) or
            len(set(seeds)) != len(seeds)):
        raise Refused("EXPLICIT_UNIQUE_PLACEBO_SEEDS_REQUIRED")

    arms = package["arms"]
    if not isinstance(arms, list) or len(arms) != 2 + len(seeds):
        raise Refused("EXACT_RESULT_ARM_SET_REQUIRED")
    by_kind = {"BASE": [], "REAL_GUARD": [], "PLACEBO": []}
    arm_ids = set()
    normalized = []
    arm_fields = {
        "arm_id", "arm_kind", "frozen_identity_sha256",
        "placebo_seed", "report_sha256", "native_receipt_sha256", "metrics",
    } | _EVIDENCE_KEYS
    for arm in arms:
        if not isinstance(arm, dict) or set(arm) != arm_fields:
            raise Refused("RESULT_ARM_SCHEMA_MISMATCH")
        arm_id = text(arm["arm_id"])
        if arm_id in arm_ids:
            raise Refused("DUPLICATE_RESULT_ARM")
        arm_ids.add(arm_id)
        kind = arm["arm_kind"]
        if kind not in _ARM_KINDS:
            raise Refused("UNKNOWN_RESULT_ARM_KIND")
        if arm["frozen_identity_sha256"] != identity_sha:
            raise Refused("ARM_IDENTITY_MISMATCH")
        checksum(arm["report_sha256"]); checksum(arm["native_receipt_sha256"])
        for key in _EVIDENCE_KEYS:
            checksum(arm[key])
        seed = arm["placebo_seed"]
        if kind == "PLACEBO":
            if type(seed) is not int or seed not in seeds:
                raise Refused("PLACEBO_SEED_ARM_MISMATCH")
        elif seed is not None:
            raise Refused("NONPLACEBO_SEED_MUST_BE_NULL")
        metrics = _validate_metrics(arm["metrics"])
        item = dict(arm)
        item["metrics"] = metrics
        by_kind[kind].append(item)
        normalized.append(item)

    if len(by_kind["BASE"]) != 1 or len(by_kind["REAL_GUARD"]) != 1:
        raise Refused("EXACT_BASE_REAL_ARM_REQUIRED")
    if sorted(a["placebo_seed"] for a in by_kind["PLACEBO"]) != sorted(seeds):
        raise Refused("ALL_PLACEBO_SEEDS_REQUIRED")
    base = by_kind["BASE"][0]
    real = by_kind["REAL_GUARD"][0]
    if base["metrics"]["guard_firings"] != 0 or base["metrics"]["attempts_blocked"] != 0:
        raise Refused("BASE_ARM_GUARD_ACTION_PRESENT")
    definition_keys = ("eq_dd_definition", "max_exposure_definition", "tail_loss_definition")
    for arm in normalized:
        if any(arm["metrics"][key] != base["metrics"][key] for key in definition_keys):
            raise Refused("METRIC_DEFINITION_DRIFT")

    delta_keys = ("net", "eq_dd_pct", "closed_trades", "episodes",
                  "max_exposure", "hard_kills", "guard_firings",
                  "attempts_blocked", "contact_seconds", "time_in_market_seconds",
                  "tail_loss_value")
    def delta(a, b):
        return {key: a["metrics"][key] - b["metrics"][key] for key in delta_keys}

    real_delta = delta(real, base)
    def pf_delta(a, b):
        if a["metrics"]["pf_status"] == "FINITE" and b["metrics"]["pf_status"] == "FINITE":
            return {"status": "FINITE", "value": a["metrics"]["pf_value"] - b["metrics"]["pf_value"]}
        return {"status": "UNAVAILABLE_NONFINITE_PF", "value": None}

    placebo_deltas = [
        {
            "seed": arm["placebo_seed"],
            "delta_vs_base": delta(arm, base),
            "pf_delta_vs_base": pf_delta(arm, base),
        }
        for arm in sorted(by_kind["PLACEBO"], key=lambda a: a["placebo_seed"])
    ]
    normalized.sort(key=lambda a: (
        {"BASE": 0, "REAL_GUARD": 1, "PLACEBO": 2}[a["arm_kind"]],
        -1 if a["placebo_seed"] is None else a["placebo_seed"],
        a["arm_id"],
    ))

    mechanism = (
        "UNTESTED_NO_GUARD_FIRINGS"
        if real["metrics"]["guard_firings"] == 0
        else "OBSERVED_GUARD_FIRINGS"
    )
    return {
        "schema_version": "guard_ab_descriptive_comparison/1",
        "changed_dimension": changed,
        "frozen_identity_sha256": identity_sha,
        "evaluation_unit": package["evaluation_unit"],
        "mechanism_status": mechanism,
        "arms": normalized,
        "real_delta_vs_base": real_delta,
        "real_pf_delta_vs_base": pf_delta(real, base),
        "placebo_deltas": placebo_deltas,
        "all_placebo_seeds_reported": True,
        "selection_performed": False,
        "verdict": None,
        "can_promote": False,
        "holdout_used": False,
    }
