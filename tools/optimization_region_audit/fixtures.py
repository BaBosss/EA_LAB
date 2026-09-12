"""Named synthetic scenarios. All numerical rules here are test data, never defaults."""
from copy import deepcopy
from itertools import product
import sys
from pathlib import Path

if __package__:
    from .audit import VERSION, SCOPE, config_digest, digest, freeze
else:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from audit import VERSION, SCOPE, config_digest, digest, freeze


def stable_plateau(side=5, dimensions=2):
    axes = [{"name": f"p{i}", "values": [str(v) for v in range(side)]} for i in range(dimensions)]
    c = {
        "schema": VERSION, "scope": SCOPE, "contract_id": "synthetic-region-example",
        "logical_change": "synthetic entry-region mapping",
        "identity": {"source_sha256": digest("synthetic source"), "build_sha256": digest("synthetic build"),
                     "locked_config_sha256": digest("synthetic locked inputs"), "install_id": "SYNTHETIC_ONLY",
                     "symbol": "FIXTURE", "timeframe": "FIXTURE", "model": "M1"},
        "axes": axes, "metrics": ["net", "trades", "dd"],
        "windows": {"MAIN": ["2023-01-01", "2025-12-31"], "BWD": ["2020-01-01", "2022-12-31"],
                    "HOLDOUT": ["2026-01-01", "2026-06-30"]},
        "search": {"method": "COMPLETE", "stage": "LOCAL_GRID", "small_grid_max_cells": 25},
        "policy": {"neighborhood": "ORTHOGONAL_STEP_1",
                   "eligibility": [{"metric": "net", "op": "gt", "value": 0}],
                   "rank": [{"metric": "net", "aggregate": "min", "direction": "desc"},
                            {"metric": "trades", "aggregate": "min", "direction": "desc"},
                            {"metric": "dd", "aggregate": "max", "direction": "asc"}],
                   "coordinate_tie_break": [{"axis": a["name"], "direction": "asc"} for a in axes]},
    }
    rows = []
    for values in product(*(a["values"] for a in axes)):
        params = dict(zip((a["name"] for a in axes), values))
        rows.append({"scope": SCOPE, "phase": "MAIN", "window": list(c["windows"]["MAIN"]),
                     "identity": dict(c["identity"]), "parameters": params,
                     "metrics": {"net": 10, "trades": 200, "dd": 3}, "accepted": True,
                     "fixture_config_sha256": config_digest(c["identity"], params)})
    return c, rows


def receipt(c, row, pin, phase, main=None):
    row = deepcopy(row)
    row["phase"], row["window"] = phase, list(c["windows"][phase])
    return {"freeze_sha256": pin, "after_main_sha256": digest(main) if main else None, "row": row}


def bwd_fixture():
    c, rows = stable_plateau()
    locked = freeze(c, rows)
    pin = digest(locked)
    chosen = next(r for r in rows if r["parameters"] == locked["selected_center"])
    main = receipt(c, chosen, pin, "MAIN")
    bwd = receipt(c, chosen, pin, "BWD", main)
    return c, rows, locked, pin, main, bwd


def scenario(name):
    c, rows = stable_plateau()
    if name == "stable_plateau":
        pass
    elif name == "isolated_spike":
        for row in rows:
            row["metrics"]["net"] = 1000 if row["parameters"] == {"p0": "2", "p1": "2"} else -1
    elif name == "boundary_winner":
        rows[0]["metrics"]["net"] = 1_000_000
    elif name == "missing_neighbour":
        rows.pop(1)
    elif name == "sparse_genetic_surface":
        c["search"] = {"method": "FAST_GENETIC", "stage": "COARSE", "small_grid_max_cells": 9}
        rows = rows[::3]
    elif name == "holdout_contamination":
        rows[0]["window"] = list(c["windows"]["HOLDOUT"])
    elif name == "duplicate_parameter_coordinates":
        rows.append(deepcopy(rows[0]))
    elif name == "malformed_metric":
        rows[0]["metrics"]["net"] = "not-a-number"
    elif name == "mismatched_config_identity":
        rows[0]["fixture_config_sha256"] = "0" * 64
    elif name == "mismatched_source_identity":
        rows[0]["identity"]["source_sha256"] = "0" * 64
    else:
        raise ValueError(name)
    return c, rows


SCENARIOS = ("stable_plateau", "isolated_spike", "boundary_winner", "missing_neighbour",
             "sparse_genetic_surface", "holdout_contamination", "duplicate_parameter_coordinates",
             "malformed_metric", "mismatched_config_identity", "mismatched_source_identity")


def export(destination):
    """Create a new fixture directory; preserve any existing evidence."""
    import json
    from pathlib import Path
    root = Path(destination)
    root.mkdir(parents=True, exist_ok=False)
    for name in SCENARIOS:
        c, rows = scenario(name)
        folder = root / name
        folder.mkdir()
        for file, value in (("contract.json", c), ("surface.json", rows)):
            (folder / file).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    c, rows, locked, pin, main, bwd = bwd_fixture()
    other = next(row for row in rows if row["parameters"] == {"p0": "2", "p1": "2"})
    tempting = receipt(c, other, pin, "BWD", main)
    tempting["row"]["metrics"]["net"] = 1_000_000
    folder = root / "bwd_temptation"
    folder.mkdir()
    for file, value in (("contract", c), ("surface", rows), ("frozen", locked),
                        ("fixed-main", main), ("bwd", bwd), ("tempting-bwd", tempting)):
        (folder / (file + ".json")).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (folder / "freeze-pin.txt").write_text(pin + "\n", encoding="utf-8")


if __name__ == "__main__":
    import argparse
    import sys
    from pathlib import Path
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", help="new output directory")
    export(parser.parse_args().destination)
