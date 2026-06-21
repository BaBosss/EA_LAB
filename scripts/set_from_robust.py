#!/usr/bin/env python3
"""Build a ready-to-run MT5 .set from the ROBUST optimizer pass.

Takes an optimizer XML + the base .set that was used to launch it, overrides the
optimized parameters with the robust pass's values (flag -> N so a single test
uses exactly those values), and writes a new .set named per the project standard.

Usage:
  python set_from_robust.py <optimizer.xml> --base <base.set> -o <out.set> [--strategy grid]

The XML optimizer columns are EA input names = .set keys, so they map by name.
"""
import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, r"C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts")
import parse_mt5_report as P          # noqa: E402
import select_robust_pass as RS       # noqa: E402


def read_text_auto(path):
    raw = Path(path).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16"), "utf-16"
    for enc in ("utf-8-sig", "cp1252"):
        try:
            return raw.decode(enc), "utf-8-sig"
        except (UnicodeDecodeError, UnicodeError):
            continue
    return raw.decode("utf-8", errors="replace"), "utf-8-sig"


def fmt(v):
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xml")
    ap.add_argument("--base", required=True)
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--strategy", default="default")
    a = ap.parse_args()

    d = P.parse_optimizer_xml(Path(a.xml), top=0)
    cols = d["parameter_columns"]
    r = RS.select_robust(d["passes"], a.strategy)
    if not r["robust"]:
        sys.exit(f"no robust pass (plateau={r['plateau']}) — not generating .set")
    rb = r["robust"]
    match = next((p for p in d["passes"]
                  if p.get("profit_factor") == rb["PF"]
                  and p.get("max_drawdown_percent") == rb["DD%"]), None)
    if not match:
        sys.exit("could not locate robust pass row")
    overrides = {c: match.get(c) for c in cols if match.get(c) is not None}

    text, enc = read_text_auto(a.base)
    out_lines, applied = [], 0
    for ln in text.splitlines():
        s = ln.strip()
        if s and not s.startswith(";") and "=" in s:
            key = s.split("=", 1)[0].strip()
            if key in overrides:
                v = fmt(overrides[key])
                out_lines.append(f"{key}={v}||{v}||0||{v}||N")
                applied += 1
                continue
        out_lines.append(ln)

    header = (f"; robust-pass .set generated 2026-06-14 from {os.path.basename(a.xml)}\n"
              f"; robust pick: PF={rb['PF']} DD%={rb['DD%']} RF={rb['RF']} trades={rb['trades']} "
              f"plateau={r['plateau']} survivors={r['survivors']}/{r['total_passes']}\n"
              f"; OVERRIDDEN {applied} optimized params; load in MT5 Inputs->Load, run SINGLE test\n")
    body = header + "\n".join(out_lines)
    Path(a.out).write_text(body, encoding="utf-16" if enc == "utf-16" else "utf-8")
    print(f"wrote {a.out}  (overrode {applied}/{len(overrides)} params; plateau {r['plateau']})")
    if applied == 0:
        print("  ! WARNING 0 overrides — XML cols may not match base .set keys")


if __name__ == "__main__":
    main()
