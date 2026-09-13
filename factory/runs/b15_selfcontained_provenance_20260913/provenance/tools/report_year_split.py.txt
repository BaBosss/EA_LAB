#!/usr/bin/env python3
"""report_year_split.py - per-year breakdown of an MT5 report's closed deals.

One full-window backtest -> built-in backward-OOS view: full-window stats plus
PF / net / trades / peak-to-trough balance DD per calendar year, from the
"out" rows of the Deals table. Lesson from ZeusInspired (2026-07-03): an
aggregate PF can hide a losing or DD-blown year; every sweep verdict must look
at the per-year rows, not just the total.

Usage:
  python report_year_split.py <report.htm> [more.htm ...]
"""
import re
import sys
from datetime import datetime
from collections import defaultdict


def read_text(path):
    raw = open(path, "rb").read()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")


def extract_trades(path):
    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", read_text(path), re.S)
    out = []
    for r in rows:
        cells = [re.sub("<[^>]+>", "", c).strip()
                 for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
        if len(cells) != 13 or cells[4].lower() != "out":
            continue
        try:
            t = datetime.strptime(cells[0], "%Y.%m.%d %H:%M:%S")
            profit = float(cells[10].replace(" ", "").replace(",", ""))
            comm = float(cells[8].replace(" ", "").replace(",", "") or 0)
            swap = float(cells[9].replace(" ", "").replace(",", "") or 0)
            out.append((t, profit + comm + swap))
        except ValueError:
            continue
    return out


def stats(trades, deposit=10000.0):
    eq = peak = deposit
    maxdd = 0.0
    gp = gl = 0.0
    for _, p in trades:
        eq += p
        gp += max(p, 0.0)
        gl += max(-p, 0.0)
        peak = max(peak, eq)
        if peak > 0:
            maxdd = max(maxdd, (peak - eq) / peak * 100.0)
    pf = (gp / gl) if gl > 0 else float("inf")
    return len(trades), pf, eq - deposit, maxdd


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for path in sys.argv[1:]:
        trades = extract_trades(path)
        n, pf, net, dd = stats(trades)
        name = path.replace("\\", "/").rsplit("/", 1)[-1]
        print(f"=== {name}")
        print(f"  FULL   trades={n:4d}  PF={pf:5.2f}  net={net:+10.2f}  balDD={dd:5.2f}%")
        byyear = defaultdict(list)
        for t, p in trades:
            byyear[t.year].append((t, p))
        for y in sorted(byyear):
            n2, pf2, net2, dd2 = stats(byyear[y])
            flag = ""
            if pf2 < 1.0:
                flag = "  <-- LOSING YEAR"
            elif pf2 < 1.2:
                flag = "  <-- thin"
            print(f"  {y}   trades={n2:4d}  PF={pf2:5.2f}  net={net2:+10.2f}  balDD={dd2:5.2f}%{flag}")


if __name__ == "__main__":
    main()
