"""Fixture-only deterministic surface validator. No tester or production verdicts."""
import argparse
import hashlib
import itertools
import json
import math
import operator
import re
from datetime import date
from decimal import Decimal, InvalidOperation
from pathlib import Path

SCOPE = "FIXTURE_ONLY"
VERSION = "optimization_region_audit/1"
MAX_CELLS = 1_000_000  # Technical resource ceiling, not a strategy threshold.
OPS = {"gt": operator.gt, "ge": operator.ge, "lt": operator.lt, "le": operator.le}


class Refusal(ValueError):
    def __init__(self, code, detail):
        self.code = code
        super().__init__(f"{code}: {detail}")


def require(ok, code, detail):
    if not ok:
        raise Refusal(code, detail)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def exact(value, keys, where):
    require(type(value) is dict and set(value) == set(keys), "SCHEMA", where)


def nonempty(value, where):
    require(type(value) is str and bool(value.strip()), "SCHEMA", where)


def sha(value, where):
    require(type(value) is str and re.fullmatch("[0-9a-f]{64}", value) is not None, "IDENTITY", where)


def number(value, where):
    require(type(value) in (int, float) and math.isfinite(value), "METRIC", where)


def axis_number(value):
    require(type(value) is str and len(value) <= 80, "PARAMETER_IDENTITY", "exact decimal strings required")
    try:
        result = Decimal(value)
    except InvalidOperation:
        raise Refusal("PARAMETER_IDENTITY", "invalid decimal") from None
    require(result.is_finite(), "PARAMETER_IDENTITY", "nonfinite coordinate")
    return result


def window(value):
    require(type(value) is list and len(value) == 2, "WINDOW", "expected inclusive [start,end]")
    try:
        require(all(type(v) is str and date.fromisoformat(v).isoformat() == v for v in value),
                "WINDOW", "ISO dates required")
    except (ValueError, TypeError):
        raise Refusal("WINDOW", "invalid ISO date") from None
    require(value[0] <= value[1], "WINDOW", "reversed dates")
    return value


def overlaps(a, b):
    return a[0] <= b[1] and b[0] <= a[1]


def validate_contract(c):
    exact(c, ("schema", "scope", "contract_id", "logical_change", "identity", "axes",
              "metrics", "windows", "search", "policy"), "contract keys")
    require(c["schema"] == VERSION and c["scope"] == SCOPE, "SCOPE", "fixture schema required")
    nonempty(c["contract_id"], "contract_id")
    nonempty(c["logical_change"], "one declared logical_change required")
    ident = c["identity"]
    exact(ident, ("source_sha256", "build_sha256", "locked_config_sha256",
                  "install_id", "symbol", "timeframe", "model"), "identity keys")
    for key in ("source_sha256", "build_sha256", "locked_config_sha256"):
        sha(ident[key], key)
    for key in ("install_id", "symbol", "timeframe"):
        nonempty(ident[key], key)
    require(ident["model"] in ("M1", "M0", "M4"), "DIAGNOSTIC_MODEL", "Model2/Open Prices/Math refused")
    axes = c["axes"]
    require(type(axes) is list and 1 <= len(axes) <= 16, "AXES", "1..16 axes required")
    names, maps, size = [], [], 1
    for axis in axes:
        exact(axis, ("name", "values"), "axis keys")
        nonempty(axis["name"], "axis name")
        require(axis["name"] not in names, "DUPLICATE_AXIS", axis["name"])
        values = axis["values"]
        require(type(values) is list and len(values) >= 3, "AXES", "axis requires an interior")
        numeric = [axis_number(v) for v in values]
        require(all(a < b for a, b in zip(numeric, numeric[1:])), "AXES", "ascending, no numeric aliases")
        names.append(axis["name"])
        maps.append({v: i for i, v in enumerate(values)})
        size *= len(values)
        require(size <= MAX_CELLS, "RESOURCE_LIMIT", "technical cell ceiling exceeded")
    metrics = c["metrics"]
    require(type(metrics) is list and metrics and all(type(m) is str and m for m in metrics)
            and len(set(metrics)) == len(metrics), "SCHEMA", "unique metrics required")
    exact(c["windows"], ("MAIN", "BWD", "HOLDOUT"), "window keys")
    for w in c["windows"].values():
        window(w)
    ws = c["windows"]
    require(not overlaps(ws["MAIN"], ws["HOLDOUT"]) and not overlaps(ws["BWD"], ws["HOLDOUT"]),
            "HOLDOUT_CONTAMINATION", "evidence overlaps HOLDOUT")
    require(ws["BWD"][1] < ws["MAIN"][0], "WINDOW", "BWD must precede MAIN")
    exact(c["search"], ("method", "stage", "small_grid_max_cells"), "search keys")
    search = c["search"]
    require(type(search["small_grid_max_cells"]) is int and search["small_grid_max_cells"] >= 1,
            "SEARCH", "contract must define small-grid budget")
    require((search["method"], search["stage"]) in (
        ("COMPLETE", "LOCAL_GRID"), ("COMPLETE", "COARSE"), ("FAST_GENETIC", "COARSE")),
        "SEARCH", "Genetic only allowed for MAIN coarse region mapping")
    require(search["method"] != "FAST_GENETIC" or size > search["small_grid_max_cells"],
            "SMALL_GRID_REQUIRES_COMPLETE", "small grids require Complete")
    p = c["policy"]
    exact(p, ("neighborhood", "eligibility", "rank", "coordinate_tie_break"), "policy keys")
    require(p["neighborhood"] == "ORTHOGONAL_STEP_1", "POLICY", "unsupported neighborhood")
    require(type(p["eligibility"]) is list and p["eligibility"], "POLICY", "explicit eligibility required")
    for rule in p["eligibility"]:
        exact(rule, ("metric", "op", "value"), "eligibility keys")
        require(rule["metric"] in metrics and rule["op"] in OPS, "POLICY", "unknown predicate")
        number(rule["value"], "eligibility threshold")
    require(type(p["rank"]) is list and p["rank"], "POLICY", "explicit scoring required")
    for rule in p["rank"]:
        exact(rule, ("metric", "aggregate", "direction"), "rank keys")
        require(rule["metric"] in metrics and rule["aggregate"] in ("min", "max")
                and rule["direction"] in ("asc", "desc"), "POLICY", "unsupported scoring function")
    ties = p["coordinate_tie_break"]
    require(type(ties) is list and len(ties) == len(names), "POLICY", "total coordinate tie-break required")
    for tie in ties:
        exact(tie, ("axis", "direction"), "tie-break keys")
        require(tie["axis"] in names and tie["direction"] in ("asc", "desc"), "POLICY", "invalid tie-break")
    require(len({t["axis"] for t in ties}) == len(names), "POLICY", "tie-break axes must be unique")
    return names, maps, size


def config_digest(identity, parameters):
    """Synthetic full-config identity; not an MT5 set fingerprint."""
    return digest({"identity": identity, "parameters": parameters})


def validate_row(row, c, names, maps, phase):
    exact(row, ("scope", "phase", "window", "identity", "parameters", "metrics",
                "accepted", "fixture_config_sha256"), "row keys")
    require(row["scope"] == SCOPE, "SCOPE", "only fixture rows accepted")
    w = window(row["window"])
    require(row["phase"] != "HOLDOUT" and not overlaps(w, c["windows"]["HOLDOUT"]),
            "HOLDOUT_CONTAMINATION", "HOLDOUT is never a search/validation surface")
    require(row["phase"] == phase, "PHASE", "selection uses MAIN; BWD validates only")
    require(w == c["windows"][phase], "WINDOW", "window differs from contract")
    require(row["identity"] == c["identity"], "IDENTITY_MISMATCH", "source/build/config/install/model")
    exact(row["parameters"], names, "parameter keys")
    coord = []
    for name, mapping in zip(names, maps):
        v = row["parameters"][name]
        require(type(v) is str and v in mapping, "PARAMETER_IDENTITY", f"off-lattice {name}")
        coord.append(mapping[v])
    require(row["fixture_config_sha256"] == config_digest(c["identity"], row["parameters"]),
            "CONFIG_MISMATCH", "fixture fingerprint differs")
    exact(row["metrics"], c["metrics"], "metric keys")
    for k, v in row["metrics"].items():
        number(v, k)
    require(type(row["accepted"]) is bool, "SCHEMA", "accepted must be boolean")
    return tuple(coord)


def neighbors(coord):
    for axis in range(len(coord)):
        for step in (-1, 1):
            other = list(coord)
            other[axis] += step
            yield tuple(other)


def analyze(c, rows):
    names, maps, expected = validate_contract(c)
    require(type(rows) is list and len(rows) <= MAX_CELLS, "SCHEMA", "bounded row list required")
    index = {}
    for row in rows:
        coord = validate_row(row, c, names, maps, "MAIN")
        require(coord not in index, "DUPLICATE_COORDINATE", str(coord))
        index[coord] = row
    base = {"schema": VERSION, "scope": SCOPE, "candidate_authority": False,
            "contract_sha256": digest(c), "expected_cells": expected, "observed_cells": len(index),
            "missing_cells": expected - len(index), "eligible_centers": [], "selected_center": None,
            "neighbor_lookups": 0}
    if c["search"]["method"] == "FAST_GENETIC":
        return dict(base, status="REGION_MAP_ONLY", code="GENETIC_CANNOT_FREEZE")
    if len(index) != expected:
        sample = itertools.islice((co for co in itertools.product(*(range(len(m)) for m in maps))
                                   if co not in index), 10)
        return dict(base, status="REFUSED", code="MISSING_REQUIRED_NEIGHBORS",
                    missing_coordinate_sample=[list(co) for co in sample])
    p = c["policy"]
    good = {co for co, r in index.items() if r["accepted"] and all(
        OPS[rule["op"]](r["metrics"][rule["metric"]], rule["value"]) for rule in p["eligibility"])}
    best = None
    for co in itertools.product(*(range(1, len(m) - 1) for m in maps)):
        adjacent = list(neighbors(co))
        base["neighbor_lookups"] += len(adjacent)
        if co not in good or not all(n in good for n in adjacent):
            continue
        cross = [index[pos] for pos in [co, *adjacent]]
        score = []
        for rule in p["rank"]:
            vals = [r["metrics"][rule["metric"]] for r in cross]
            val = min(vals) if rule["aggregate"] == "min" else max(vals)
            score.append(val if rule["direction"] == "asc" else -val)
        for tie in p["coordinate_tie_break"]:
            val = co[names.index(tie["axis"])]
            score.append(val if tie["direction"] == "asc" else -val)
        params = dict(index[co]["parameters"])
        base["eligible_centers"].append(params)
        key = tuple(score)
        if best is None or key < best[0]:
            best = (key, params)
    base["selected_center"] = best[1] if best else None
    return dict(base, status="FIXTURE_ACCEPTED" if best else "REFUSED",
                code="COMPLETE_STABLE_REGION" if best else "NO_ELIGIBLE_INTERIOR_CENTER")


def freeze(c, rows):
    result = analyze(c, rows)
    require(result["status"] == "FIXTURE_ACCEPTED", result["code"], "cannot freeze")
    names = [a["name"] for a in c["axes"]]
    ordered = sorted(rows, key=lambda r: tuple(r["parameters"][n] for n in names))
    selected = result["selected_center"]
    return {"schema": VERSION, "scope": SCOPE, "candidate_authority": False,
            "contract_sha256": digest(c), "surface_sha256": digest(ordered),
            "selected_center": selected, "identity": c["identity"],
            "fixture_config_sha256": config_digest(c["identity"], selected)}


def verify_bwd(c, rows, frozen, expected_freeze_sha256, main, bwd):
    """Validate immutable fixture lineage only; no BWD scoring or strategy verdict."""
    sha(expected_freeze_sha256, "externally pinned freeze hash")
    require(digest(frozen) == expected_freeze_sha256, "FREEZE_TAMPERED", "freeze differs from trusted pin")
    require(frozen == freeze(c, rows), "FREEZE_MISMATCH", "recomputed MAIN freeze differs")
    names, maps, _ = validate_contract(c)
    for receipt, phase in ((main, "MAIN"), (bwd, "BWD")):
        exact(receipt, ("freeze_sha256", "after_main_sha256", "row"), "receipt keys")
        require(receipt["freeze_sha256"] == expected_freeze_sha256, "FREEZE_MISMATCH", phase)
        validate_row(receipt["row"], c, names, maps, phase)
        require(receipt["row"]["parameters"] == frozen["selected_center"], "FROZEN_CENTER_CHANGED", phase)
        require(receipt["row"]["accepted"], "MECHANICAL_EVIDENCE_INCOMPLETE", phase)
    require(main["after_main_sha256"] is None, "LINEAGE", "fixed MAIN cannot follow itself")
    require(bwd["after_main_sha256"] == digest(main), "LINEAGE", "BWD must reference fixed MAIN receipt")
    return {"schema": VERSION, "scope": SCOPE, "status": "FIXTURE_LINEAGE_VALID",
            "candidate_authority": False, "freeze_sha256": expected_freeze_sha256,
            "main_sha256": digest(main), "bwd_sha256": digest(bwd), "strategy_verdict": "NOT_ASSESSED"}


def read_json(path):
    def pairs(items):
        result = {}
        for k, v in items:
            require(k not in result, "DUPLICATE_JSON_KEY", k)
            result[k] = v
        return result
    def constant(value):
        raise Refusal("METRIC", f"non-finite JSON constant {value}")
    return json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=pairs, parse_constant=constant)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("preflight", "audit", "freeze", "verify-bwd"))
    parser.add_argument("contract")
    for opt in ("surface", "frozen", "freeze-sha256", "fixed-main", "bwd", "output"):
        parser.add_argument("--" + opt)
    args = parser.parse_args()
    try:
        c = read_json(args.contract)
        validate_contract(c)
        if args.action == "preflight":
            result = {"scope": SCOPE, "status": "FIXTURE_PREFLIGHT_VALID",
                      "contract_sha256": digest(c), "candidate_authority": False}
        else:
            require(args.surface is not None, "ARGUMENT", "--surface required")
            rows = read_json(args.surface)
            if args.action == "audit":
                result = analyze(c, rows)
            elif args.action == "freeze":
                result = freeze(c, rows)
            else:
                require(all((args.frozen, args.freeze_sha256, args.fixed_main, args.bwd)),
                        "ARGUMENT", "freeze pin, frozen, fixed-main and bwd required")
                result = verify_bwd(c, rows, read_json(args.frozen), args.freeze_sha256,
                                    read_json(args.fixed_main), read_json(args.bwd))
        encoded = canonical(result).decode() + "\n"
        if args.output:
            with Path(args.output).open("x", encoding="utf-8", newline="\n") as out:
                out.write(encoded)
        else:
            print(encoded, end="")
        return 2 if result.get("status") in ("REFUSED", "REGION_MAP_ONLY") else 0
    except (Refusal, OSError, ValueError, TypeError, KeyError, OverflowError) as exc:
        print(json.dumps({"scope": SCOPE, "status": "REFUSED", "code": getattr(exc, "code", "INVALID_INPUT"),
                          "detail": str(exc), "candidate_authority": False}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
