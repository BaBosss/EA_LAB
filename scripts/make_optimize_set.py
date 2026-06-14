#!/usr/bin/env python3
"""Reconstruct an OPTIMIZE .set from an existing MT5 optimizer XML.

For each optimized parameter column it reads the min / max / smallest-step seen
across all passes (= the original optimize ranges) and writes a .set line
`Param=mid||min||step||max||Y` ready to re-optimize the SAME compiled EA.
Non-numeric params are emitted with the most common value and flag N.

Unlocks clean re-optimization of any EA that has a past optimizer XML.

Usage: python make_optimize_set.py <optimizer.xml> -o <out.set>
"""
import argparse
import os
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, r"C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts")
import parse_mt5_report as P          # noqa: E402


def fmt(x):
    try:
        xf = float(x)
        return str(int(xf)) if xf.is_integer() else str(round(xf, 5))
    except (TypeError, ValueError):
        return str(x)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xml")
    ap.add_argument("-o", "--out", required=True)
    a = ap.parse_args()
    d = P.parse_optimizer_xml(Path(a.xml), top=0)
    cols = d["parameter_columns"]
    passes = d["passes"]

    lines = [f"; optimize .set reconstructed from {os.path.basename(a.xml)} "
             f"({len(passes)} passes)"]
    n_opt = 0
    for c in cols:
        raw = [p.get(c) for p in passes if p.get(c) is not None]
        nums = [v for v in raw if isinstance(v, (int, float))]
        if nums and len(set(nums)) > 1:
            uniq = sorted(set(nums))
            step = min(uniq[i + 1] - uniq[i] for i in range(len(uniq) - 1))
            mid = uniq[len(uniq) // 2]
            lines.append(f"{c}={fmt(mid)}||{fmt(uniq[0])}||{fmt(step)}||{fmt(uniq[-1])}||Y")
            n_opt += 1
        elif raw:
            common = Counter(raw).most_common(1)[0][0]
            lines.append(f"{c}={fmt(common)}||{fmt(common)}||0||{fmt(common)}||N")
    Path(a.out).write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {a.out}: {n_opt} optimizable params (of {len(cols)} columns)")


if __name__ == "__main__":
    main()
