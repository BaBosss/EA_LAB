#!/usr/bin/env python
"""Extract per-trade profit from an MT5 Strategy Tester HTML report into a CSV
(columns: time, profit) for monte_carlo.py. MT5 reports store deals in a table;
the closing deals carry the realized profit. We take the 'Deals' section rows that
have a numeric profit in the profit column.

Usage: python mt5_deals_to_csv.py <report.htm> <out.csv>
"""
import sys, re, csv, io

def read_text(path):
    with open(path, "rb") as f:
        raw = f.read()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    for enc in ("utf-8", "cp1252", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", "replace")

def num(s):
    s = re.sub(r"<[^>]+>", "", s).replace("&nbsp;", " ").strip().replace(" ", "")
    if s in ("", "-"):
        return None
    try:
        return float(s)
    except ValueError:
        return None

def main():
    if len(sys.argv) < 3:
        sys.exit("usage: mt5_deals_to_csv.py <report.htm> <out.csv>")
    html = read_text(sys.argv[1])

    # Isolate the Deals section (after the 'Deals' header to end of its table).
    di = html.find(">Deals<")
    section = html[di:] if di != -1 else html

    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", section, re.S)
    # locate the header row of the deals table to map columns
    header_cells = None
    deals = []
    for r in rows:
        cells = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)
        if not cells:
            continue
        txt = [re.sub(r"<[^>]+>", "", c).replace("&nbsp;", " ").strip() for c in cells]
        low = [t.lower() for t in txt]
        if header_cells is None and "profit" in low and ("time" in low or "symbol" in low):
            header_cells = low
            continue
        if header_cells is None:
            continue
        if len(cells) < len(header_cells):
            continue
        rec = dict(zip(header_cells, cells))
        # MT5 deals: an 'out' / 'in/out' deal closes a position and carries profit.
        dtype = re.sub(r"<[^>]+>", "", rec.get("type", "")).strip().lower()
        p = num(rec.get("profit", ""))
        if p is None:
            continue
        # skip 'balance' (initial deposit) and pure 'in' opens (profit 0 but keep only closers)
        if dtype in ("balance",):
            continue
        # keep rows where profit is a real realized value on a closing deal
        if dtype in ("out", "in/out", "sell", "buy", "") and p != 0.0:
            t = re.sub(r"<[^>]+>", "", rec.get("time", "")).strip()
            deals.append((t, p))

    if not deals:
        sys.exit("no deals with profit found — inspect report structure")

    with open(sys.argv[2], "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["time", "profit"])
        w.writerows(deals)
    tot = sum(p for _, p in deals)
    print(f"wrote {len(deals)} trades, sum profit={tot:.2f} -> {sys.argv[2]}")

if __name__ == "__main__":
    main()
