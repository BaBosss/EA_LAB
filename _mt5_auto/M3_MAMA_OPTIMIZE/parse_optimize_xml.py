#!/usr/bin/env python3
"""parse_optimize_xml.py -- parse an MT5 optimizer XML report into rows, apply the
ExpertMAMA M3 campaign's participation/PF/plateau gates, and print a plateau report.

Usage: python parse_optimize_xml.py <xml> [--min-trades 100] [--min-pf 1.2]
"""
import re
import sys
import json


def read_text(path):
    raw = open(path, "rb").read()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")


def parse_rows(path):
    text = read_text(path)
    rows_raw = re.findall(r"<Row>(.*?)</Row>", text, re.S)
    header = None
    out = []
    for r in rows_raw:
        cells = re.findall(r'<Data ss:Type="(?:String|Number)">([^<]*)</Data>', r)
        if header is None:
            header = cells
            continue
        if len(cells) != len(header):
            continue
        rec = dict(zip(header, cells))
        out.append(rec)
    return header, out


def to_num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def main():
    path = sys.argv[1]
    min_trades = 100
    min_pf = 1.2
    if "--min-trades" in sys.argv:
        min_trades = float(sys.argv[sys.argv.index("--min-trades") + 1])
    if "--min-pf" in sys.argv:
        min_pf = float(sys.argv[sys.argv.index("--min-pf") + 1])

    header, rows = parse_rows(path)
    print(f"=== {path}")
    print(f"total rows: {len(rows)}")

    lever_cols = [h for h in header if h.startswith("Inp_")]
    parsed = []
    for r in rows:
        trades = to_num(r.get("Trades"))
        pf = to_num(r.get("Profit Factor"))
        net = to_num(r.get("Profit"))
        ddpct = to_num(r.get("Equity DD %"))
        levers = {lc: to_num(r.get(lc)) for lc in lever_cols}
        parsed.append({"trades": trades, "pf": pf, "net": net, "eqdd_pct": ddpct, **levers})

    eligible = [p for p in parsed
                if p["trades"] is not None and p["trades"] >= min_trades
                and p["pf"] is not None and p["pf"] >= min_pf
                and p["net"] is not None and p["net"] > 0]

    n_ge100 = sum(1 for p in parsed if p["trades"] is not None and p["trades"] >= min_trades)
    n_pf_ok = sum(1 for p in parsed if p["pf"] is not None and p["pf"] >= min_pf)

    print(f"cells with trades>={min_trades}: {n_ge100}")
    print(f"cells with PF>={min_pf}: {n_pf_ok}")
    print(f"eligible (trades>={min_trades} AND PF>={min_pf} AND net>0): {len(eligible)}")

    if eligible:
        print("\n--- eligible cells ---")
        for p in sorted(eligible, key=lambda x: -x["pf"]):
            lv = " ".join(f"{k.replace('Inp_','')}={v:g}" for k, v in p.items()
                           if k.startswith("Inp_"))
            print(f"  trades={p['trades']:.0f} PF={p['pf']:.3f} net={p['net']:.2f} "
                  f"eqDD%={p['eqdd_pct']:.2f}  {lv}")

    # Plateau analysis: build a lookup keyed by the 3 lever values, then for each
    # eligible cell count how many of its 6 one-step orthogonal neighbours (+/- one
    # grid step in each of the 3 dimensions) are ALSO eligible.
    lookup = {}
    for p in parsed:
        key = tuple(p[lc] for lc in lever_cols)
        lookup[key] = p

    grid_steps = {}
    for lc in lever_cols:
        vals = sorted(set(p[lc] for p in parsed if p[lc] is not None))
        grid_steps[lc] = vals

    print("\n--- plateau support (eligible cells + their eligible-neighbour count) ---")
    plateau_rows = []
    for p in eligible:
        key = tuple(p[lc] for lc in lever_cols)
        support = 0
        neighbour_detail = []
        for i, lc in enumerate(lever_cols):
            vals = grid_steps[lc]
            cur = p[lc]
            idx = vals.index(cur)
            for step in (-1, 1):
                nidx = idx + step
                if 0 <= nidx < len(vals):
                    nkey = list(key)
                    nkey[i] = vals[nidx]
                    nkey = tuple(nkey)
                    if nkey in lookup:
                        npf = lookup[nkey]["pf"]
                        ntr = lookup[nkey]["trades"]
                        nnet = lookup[nkey]["net"]
                        is_elig = (ntr is not None and ntr >= min_trades and
                                   npf is not None and npf >= min_pf and
                                   nnet is not None and nnet > 0)
                        if is_elig:
                            support += 1
                            neighbour_detail.append(f"{lc.replace('Inp_','')}{'+' if step>0 else '-'}1step=OK(PF{npf:.2f})")
        plateau_rows.append((p, support, neighbour_detail))

    for p, support, detail in sorted(plateau_rows, key=lambda x: -x[1]):
        lv = " ".join(f"{k.replace('Inp_','')}={v:g}" for k, v in p.items() if k.startswith("Inp_"))
        print(f"  support={support}/6  PF={p['pf']:.3f} trades={p['trades']:.0f}  {lv}")

    out = {"header": header, "n_rows": len(rows), "n_ge_trades": n_ge100,
           "n_pf_ok": n_pf_ok, "eligible": eligible, "plateau": [
               {"cell": p, "support": s} for p, s, _ in plateau_rows]}
    outpath = path.rsplit(".", 1)[0] + "_parsed.json"
    with open(outpath, "w") as f:
        json.dump(out, f, indent=2)
    print(f"\nwrote: {outpath}")


if __name__ == "__main__":
    main()
