#!/usr/bin/env python3
"""mt4_montecarlo.py — bootstrap Monte Carlo on an MT4 Strategy Tester report.

A single backtest gives ONE equity path; its max drawdown is one sample of a
random variable. For grid/averaging EAs especially, the historical DD can be
lucky. This extracts the realized per-trade P/L from the MT4 report's trade
list, then resamples the trade sequence many times to estimate the DISTRIBUTION
of max drawdown, final net, and profit factor.

MT4 trade-list columns: # Time Type Order Size Price S/L T/P Profit Balance.
Realized P/L appears in the Profit column only on CLOSING rows
(type in: t/p, s/l, close, close at stop). We pull those in order.

CAVEAT: trade-order resampling assumes trades are exchangeable. For a grid the
losing legs cluster (correlated), so this is an OPTIMISTIC lower bound on tail
risk — a real adverse trend can be worse than any reshuffle of these trades.
Treat the 95/99th-percentile DD as "at least this bad", not a ceiling.

Usage:
  python mt4_montecarlo.py <report.htm> [--deposit 10000] [--iters 5000]
"""
import re, sys, html, argparse, random

CLOSE_TYPES = ("t/p", "s/l", "close", "close at stop", "tp", "sl")

def extract_trades(path):
    raw = open(path, "r", encoding="utf-8", errors="ignore").read()
    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", raw, re.S)
    profits = []
    for r in rows:
        cells = [html.unescape(re.sub("<[^>]+>", "", c)).strip()
                 for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
        # closing rows have 10 cells: # Time Type Order Size Price S/L T/P Profit Balance
        if len(cells) != 10:
            continue
        ttype = cells[2].lower()
        if ttype not in CLOSE_TYPES:
            continue
        try:
            profits.append(float(cells[8].replace(" ", "").replace(",", "")))
        except ValueError:
            continue
    return profits

def max_dd(equity):
    peak = equity[0]; dd = 0.0
    for e in equity:
        if e > peak: peak = e
        dd = max(dd, peak - e)
    return dd

def curve(profits, start):
    eq = [start];
    for p in profits: eq.append(eq[-1] + p)
    return eq

def pf(profits):
    gp = sum(p for p in profits if p > 0); gl = -sum(p for p in profits if p < 0)
    return (gp / gl) if gl > 0 else float("inf")

def pct(sorted_list, q):
    if not sorted_list: return None
    i = min(len(sorted_list) - 1, int(q * len(sorted_list)))
    return sorted_list[i]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--deposit", type=float, default=10000)
    ap.add_argument("--iters", type=int, default=5000)
    ap.add_argument("--seed", type=int, default=12345)
    a = ap.parse_args()
    random.seed(a.seed)

    tr = extract_trades(a.report)
    if len(tr) < 10:
        print(f"ERROR: only {len(tr)} closed trades extracted — check report format"); sys.exit(1)

    hist_net = sum(tr)
    hist_dd = max_dd(curve(tr, a.deposit))
    hist_pf = pf(tr)
    print(f"== {a.report}")
    print(f"trades={len(tr)} | HISTORICAL net={hist_net:.2f} PF={hist_pf:.2f} "
          f"maxDD={hist_dd:.2f} ({hist_dd/a.deposit*100:.2f}%)")

    dds, nets, pfs, ruin = [], [], [], 0
    n = len(tr)
    for _ in range(a.iters):
        samp = [tr[random.randrange(n)] for _ in range(n)]   # bootstrap w/ replacement
        eq = curve(samp, a.deposit)
        d = max_dd(eq)
        dds.append(d); nets.append(eq[-1] - a.deposit); pfs.append(pf(samp))
        if min(eq) <= a.deposit * 0.5:   # >=50% equity loss at any point = "ruin"
            ruin += 1
    dds.sort(); nets.sort(); pfs.sort()
    dep = a.deposit
    print(f"\nMONTE CARLO (bootstrap, {a.iters} iters):")
    print(f"  maxDD%   median={pct(dds,.5)/dep*100:5.2f}  95th={pct(dds,.95)/dep*100:5.2f}  99th={pct(dds,.99)/dep*100:5.2f}  worst={dds[-1]/dep*100:5.2f}")
    print(f"  net      median={pct(nets,.5):8.2f}  5th={pct(nets,.05):8.2f}  prob(net<0)={sum(1 for x in nets if x<0)/len(nets)*100:.1f}%")
    print(f"  PF       median={pct(pfs,.5):5.2f}  5th={pct(pfs,.05):5.2f}")
    print(f"  ruin(>=50% equity loss): {ruin/a.iters*100:.2f}%")

if __name__ == "__main__":
    main()
