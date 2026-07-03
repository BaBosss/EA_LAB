#!/usr/bin/env python3
"""Monthly P&L correlation across ZeusInspired_GridLog confirmed candidates.

Adapted from _mt5_auto/corr_monthly.py's extract_monthly() pattern, generalized
to take an arbitrary list of (label, report_path) pairs instead of hardcoded names.
"""
import re
from pathlib import Path
from collections import defaultdict
from itertools import combinations

def read_text(path):
    raw = Path(path).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")

def num(s):
    s = str(s).strip().replace("\xa0", "").replace(" ", "").replace(",", "")
    try:
        return float(s)
    except Exception:
        return None

def extract_monthly(paths):
    monthly = defaultdict(float)
    for path in paths:
        if not Path(path).exists():
            continue
        text = read_text(path)
        rows = re.findall(r"<tr[^>]*>(.*?)</tr>", text, re.S)
        for r in rows:
            cells = [re.sub("<[^>]+>", "", c).strip()
                     for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
            if len(cells) != 13:
                continue
            if cells[4].lower() != "out":
                continue
            profit = num(cells[10])
            if profit is None:
                continue
            commission = num(cells[8]) or 0.0
            swap = num(cells[9]) or 0.0
            t = cells[0]
            m = re.match(r"(\d{4})\.(\d{2})", t)
            if m:
                ym = f"{m.group(1)}-{m.group(2)}"
                monthly[ym] += profit + commission + swap
    return monthly

def pearson(xs, ys):
    n = len(xs)
    if n < 4:
        return float("nan")
    mx = sum(xs) / n
    my = sum(ys) / n
    num_ = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    dx = (sum((x - mx) ** 2 for x in xs)) ** 0.5
    dy = (sum((y - my) ** 2 for y in ys)) ** 0.5
    if dx == 0 or dy == 0:
        return float("nan")
    return num_ / (dx * dy)

rdir = Path(r"D:\EA_LAB\_mt5_auto\reports")

candidates = {
    "AUDJPY": rdir / "ZIGL_AUDJPY_baseline_M1.htm",
    "AUDUSD": rdir / "ZIGL_AUDUSD_baseline_M1.htm",
    "EURCAD": rdir / "ZIGL_EURCAD_baseline_M1.htm",
    "USDJPY": rdir / "ZIGL_USDJPY_baseline_M1.htm",
    "EURCHF": rdir / "ZIGL_EURCHF_baseline_M1.htm",
    "EURJPY": rdir / "ZIGL_EURJPY_baseline_M1.htm",
}

series = {name: extract_monthly([path]) for name, path in candidates.items()}
for name, m in series.items():
    print(f"{name}: {len(m)} months of data -> {sorted(m.keys())}")
print()

print(f"{'Pair':<20} {'Corr':>8} {'SharedMo':>10} {'Verdict':>14}")
print("-" * 56)
rows = []
for a, b in combinations(series.keys(), 2):
    sa, sb = series[a], series[b]
    shared = sorted(set(sa) & set(sb))
    if len(shared) < 3:
        print(f"{a}/{b:<15} {'not enough shared months (' + str(len(shared)) + ')':>32}")
        continue
    xs = [sa[m] for m in shared]
    ys = [sb[m] for m in shared]
    corr = pearson(xs, ys)
    verdict = "LOW-additive" if corr <= 0.40 else ("WATCH" if corr <= 0.60 else "HIGH-redundant")
    rows.append((a, b, corr, len(shared), verdict))
    print(f"{a+'/'+b:<20} {corr:>8.3f} {len(shared):>10} {verdict:>14}")
