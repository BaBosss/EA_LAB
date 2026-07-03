#!/usr/bin/env python3
"""mt5_montecarlo.py — bootstrap Monte Carlo on an MT5 Strategy Tester report.

MT5-adapted version of mt4_montecarlo.py. Extracts realized per-trade P/L from
the report's "Deals" table (13-cell rows, same format corr_monthly.py already
parses: column 4 = Direction, "out" rows are closes; column 10 = Profit).
Resamples the trade sequence many times to estimate the DISTRIBUTION of max
drawdown, final net, and profit factor — a single backtest gives ONE equity
path; its max DD is one sample of a random variable.

CAVEAT: trade-order resampling assumes trades are exchangeable. For a grid the
losing legs cluster (correlated), so this is an OPTIMISTIC lower bound on tail
risk — a real adverse trend can be worse than any reshuffle of these trades.
Treat the 95/99th-percentile DD as "at least this bad", not a ceiling.

Usage:
  python mt5_montecarlo.py <report.htm> [--deposit 10000] [--iters 5000]
"""
import re
import sys
import argparse
import random


def read_text(path):
    raw = open(path, "rb").read()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")


def extract_trades(path):
    raw = read_text(path)
    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", raw, re.S)
    profits = []
    for r in rows:
        cells = [re.sub("<[^>]+>", "", c).strip()
                 for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
        if len(cells) != 13:
            continue
        if cells[4].lower() != "out":
            continue
        try:
            profit = float(cells[10].replace(" ", "").replace(",", ""))
            commission = float(cells[8].replace(" ", "").replace(",", "") or 0)
            swap = float(cells[9].replace(" ", "").replace(",", "") or 0)
            profits.append(profit + commission + swap)
        except ValueError:
            continue
    return profits


def simulate(profits, deposit, iters, rng):
    n = len(profits)
    finals, maxdds, pfs = [], [], []
    for _ in range(iters):
        order = profits[:]
        rng.shuffle(order)
        equity = deposit
        peak = deposit
        maxdd = 0.0
        gross_profit = 0.0
        gross_loss = 0.0
        for p in order:
            equity += p
            if p > 0:
                gross_profit += p
            else:
                gross_loss += -p
            peak = max(peak, equity)
            dd = (peak - equity) / peak * 100.0 if peak > 0 else 0.0
            maxdd = max(maxdd, dd)
        finals.append(equity - deposit)
        maxdds.append(maxdd)
        pfs.append(gross_profit / gross_loss if gross_loss > 0 else float("inf"))
    return finals, maxdds, pfs


def pct(sorted_vals, p):
    if not sorted_vals:
        return float("nan")
    idx = min(len(sorted_vals) - 1, max(0, int(round(p / 100.0 * (len(sorted_vals) - 1)))))
    return sorted_vals[idx]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--deposit", type=float, default=10000.0)
    ap.add_argument("--iters", type=int, default=5000)
    ap.add_argument("--seed", type=int, default=42)
    a = ap.parse_args()

    profits = extract_trades(a.report)
    n = len(profits)
    if n < 10:
        print(f"TOO FEW TRADES ({n}) for a meaningful Monte Carlo — result would be noise.")
        sys.exit(1)

    rng = random.Random(a.seed)
    finals, maxdds, pfs = simulate(profits, a.deposit, a.iters, rng)
    finals.sort()
    maxdds.sort()
    finite_pfs = sorted(p for p in pfs if p != float("inf"))

    net_actual = sum(profits)
    print(f"report: {a.report}")
    print(f"trades: {n} | deposit: {a.deposit} | iterations: {a.iters}")
    print(f"actual net (real trade order): {net_actual:.2f}")
    print()
    print(f"{'metric':<28} {'5th pct':>10} {'median':>10} {'95th pct':>10} {'worst':>10}")
    print(f"{'Net profit':<28} {pct(finals,5):>10.2f} {pct(finals,50):>10.2f} {pct(finals,95):>10.2f} {finals[0]:>10.2f}")
    print(f"{'Max drawdown %':<28} {pct(maxdds,5):>10.2f} {pct(maxdds,50):>10.2f} {pct(maxdds,95):>10.2f} {maxdds[-1]:>10.2f}")
    if finite_pfs:
        print(f"{'Profit factor':<28} {pct(finite_pfs,5):>10.2f} {pct(finite_pfs,50):>10.2f} {pct(finite_pfs,95):>10.2f} {finite_pfs[0]:>10.2f}")
    ruin = sum(1 for f in finals if f <= -a.deposit) / len(finals) * 100.0
    print()
    print(f"ruin risk (net <= -deposit): {ruin:.2f}%")
    print(f"P(net profit < 0): {sum(1 for f in finals if f < 0) / len(finals) * 100.0:.1f}%")


if __name__ == "__main__":
    main()
