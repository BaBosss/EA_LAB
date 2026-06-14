#!/usr/bin/env python3
"""Extract the realized per-trade P/L from an MT5 Strategy Tester HTML report.

MT5 single-test reports embed a Deals table (UTF-16LE HTML). Each closed trade
has an 'out' deal carrying realized Profit (+ Commission + Swap). This pulls
those into a clean trades CSV usable by monte_carlo.py and
parse_mt5_report.py --trades (for monthly distribution).

Usage: python extract_deals.py <report.html> -o <trades.csv>
Output columns: time,profit
"""
import re
import sys
import argparse
from pathlib import Path


def read_text_auto(path):
    raw = Path(path).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    for enc in ("utf-8-sig", "cp1252", "utf-16-le"):
        try:
            t = raw.decode(enc)
            if t.count("\x00") < max(1, len(t) // 100):
                return t
        except (UnicodeDecodeError, UnicodeError):
            continue
    return raw.decode("utf-8", errors="replace")


def num(s):
    if s is None:
        return None
    s = str(s).strip().replace("\xa0", "").replace(" ", "").replace(",", "")
    try:
        return float(s)
    except ValueError:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("-o", "--out", required=True)
    a = ap.parse_args()
    text = read_text_auto(a.report)
    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", text, re.S)

    deals = []
    for r in rows:
        cells = [re.sub("<[^>]+>", "", c).strip()
                 for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
        if len(cells) != 13:
            continue
        # cols: Time Deal Symbol Type Direction Volume Price Order Commission Swap Profit Balance Comment
        direction = cells[4].lower()
        if direction != "out":            # realized P/L is on the closing deal
            continue
        profit = num(cells[10])
        if profit is None:
            continue
        commission = num(cells[8]) or 0.0
        swap = num(cells[9]) or 0.0
        deals.append((cells[0], profit + commission + swap))

    if not deals:
        print("ERROR: no 'out' deals found — check report format")
        sys.exit(1)

    with open(a.out, "w", encoding="utf-8", newline="") as f:
        f.write("time,profit\n")
        for t, p in deals:
            f.write(f"{t},{p:.2f}\n")

    total = sum(p for _, p in deals)
    wins = sum(1 for _, p in deals if p > 0)
    print(f"wrote {a.out}")
    print(f"trades={len(deals)}  net={total:.2f}  wins={wins} ({wins*100//len(deals)}%)")


if __name__ == "__main__":
    main()
