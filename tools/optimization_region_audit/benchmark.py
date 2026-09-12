"""Synthetic scaling probe. Fixture generation is excluded from timed audit/freeze."""
import argparse
import gc
import json
import platform
import statistics
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit import analyze, canonical, digest, freeze
from fixtures import stable_plateau


def measure(sides, repeats):
    output = {"scope": "FIXTURE_ONLY", "python": platform.python_version(),
              "platform": platform.platform(), "repeats": repeats,
              "timing": "median seconds; generation excluded; audit includes row identity validation",
              "grids": []}
    for side in sides:
        c, rows = stable_plateau(side)
        times = []
        expected_hash = None
        for _ in range(repeats):
            start = time.perf_counter()
            result = analyze(c, rows)
            times.append(time.perf_counter() - start)
            result_hash = digest(result)
            assert expected_hash in (None, result_hash), "nondeterministic audit"
            expected_hash = result_hash
        assert result["neighbor_lookups"] == 4 * (side - 2) ** 2
        assert len(result["eligible_centers"]) == (side - 2) ** 2
        start = time.perf_counter()
        locked = freeze(c, rows)
        freeze_seconds = time.perf_counter() - start
        output["grids"].append({
            "side": side, "cells": side * side, "eligible_centers": len(result["eligible_centers"]),
            "neighbor_lookups": result["neighbor_lookups"], "audit_sha256": expected_hash,
            "freeze_sha256": digest(locked), "audit_median_seconds": round(statistics.median(times), 6),
            "audit_samples_seconds": [round(t, 6) for t in times],
            "freeze_seconds": round(freeze_seconds, 6),
        })
        del c, rows, result, locked
        gc.collect()
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sides", nargs="+", type=int, default=[100, 200, 400])
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--output")
    args = parser.parse_args()
    if not args.repeats > 0 or not all(3 <= s <= 1000 for s in args.sides):
        parser.error("positive repeats and sides 3..1000 required")
    result = measure(args.sides, args.repeats)
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        with Path(args.output).open("x", encoding="utf-8", newline="\n") as out:
            out.write(encoded)
    print(encoded, end="")
