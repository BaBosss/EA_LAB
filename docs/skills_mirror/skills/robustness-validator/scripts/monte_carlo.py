#!/usr/bin/env python3
"""Monte Carlo robustness testing on an MT5 trade list.

Tests:
  - Trade-order shuffle (default 1000 permutations): PF percentiles are
    invariant to order, but max-drawdown and ruin probability are not —
    this measures sequence risk.
  - Optional bootstrap resampling (with replacement): PF 5th/median/95th,
    DD 95th, probability of ruin.
  - Optional date-based IS/OOS split metrics.

Input CSV: needs a profit-per-trade column (profit/pnl/result) and optionally
a time column for the OOS split. Use parse_mt5_report.py or MT5 deal export.

Usage:
  python monte_carlo.py trades.csv --deposit 10000 [-n 1000] [--bootstrap]
                        [--ruin-dd 50] [--oos-split 0.7] [-o out.json]
"""
import argparse
import csv
import io
import json
import math
import random
import re
import sys
from pathlib import Path


def read_text_auto(path: Path) -> str:
    raw = path.read_bytes()
    if raw[:2] in (bytes([255, 254]), bytes([254, 255])):  # UTF-16 BOM
        return raw.decode("utf-16")
    for enc in ("utf-8-sig", "cp1252", "utf-16-le"):
        try:
            text = raw.decode(enc)
            if text.count("\x00") < max(1, len(text) // 100):
                return text
        except (UnicodeDecodeError, UnicodeError):
            continue
    return raw.decode("utf-8", errors="replace")


def to_number(s):
    if s is None:
        return None
    s = str(s).strip().replace("\xa0", "").replace(" ", "").replace(",", "")
    try:
        return float(s)
    except ValueError:
        return None


def load_trades(path: Path):
    text = read_text_auto(path)
    try:
        dialect = csv.Sniffer().sniff(text[:4000], delimiters=",;\t")
    except csv.Error:
        dialect = csv.excel
    rows = list(csv.DictReader(io.StringIO(text), dialect=dialect))
    if not rows:
        sys.exit("empty CSV")
    profit_col = time_col = None
    for col in rows[0]:
        lc = (col or "").strip().lower()
        if profit_col is None and lc in ("profit", "net profit", "pnl", "p/l", "result"):
            profit_col = col
        if time_col is None and lc in ("time", "close time", "date", "open time"):
            time_col = col
    if profit_col is None:
        sys.exit(f"no profit column in {list(rows[0])}")
    trades = []
    for r in rows:
        p = to_number(r.get(profit_col))
        if p is not None:
            trades.append((str(r.get(time_col, "")), p))
    return trades


def profit_factor(profits):
    gp = sum(p for p in profits if p > 0)
    gl = -sum(p for p in profits if p < 0)
    if gl == 0:
        return float("inf") if gp > 0 else 0.0
    return gp / gl


def max_dd_pct(profits, deposit):
    equity = deposit
    peak = deposit
    worst = 0.0
    for p in profits:
        equity += p
        peak = max(peak, equity)
        if peak > 0:
            worst = max(worst, (peak - equity) / peak * 100.0)
        if equity <= 0:
            return 100.0
    return worst


def percentile(sorted_vals, q):
    if not sorted_vals:
        return None
    idx = (len(sorted_vals) - 1) * q
    lo, hi = math.floor(idx), math.ceil(idx)
    if lo == hi:
        return sorted_vals[lo]
    return sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * (idx - lo)


def simulate(profits, deposit, n, ruin_dd, mode, rng):
    pfs, dds, ruins = [], [], 0
    for _ in range(n):
        if mode == "shuffle":
            sample = profits[:]
            rng.shuffle(sample)
        else:  # bootstrap
            sample = [rng.choice(profits) for _ in profits]
        pf = profit_factor(sample)
        dd = max_dd_pct(sample, deposit)
        pfs.append(min(pf, 99.0))
        dds.append(dd)
        if dd >= ruin_dd:
            ruins += 1
    pfs.sort()
    dds.sort()
    return {
        "pf_5th": round(percentile(pfs, 0.05), 3),
        "pf_median": round(percentile(pfs, 0.50), 3),
        "pf_95th": round(percentile(pfs, 0.95), 3),
        "pf_range_5_95": round(percentile(pfs, 0.95) - percentile(pfs, 0.05), 3),
        "dd_median_pct": round(percentile(dds, 0.50), 2),
        "dd_95th_pct": round(percentile(dds, 0.95), 2),
        "prob_of_ruin_pct": round(100.0 * ruins / n, 2),
        "permutations": n,
    }


def oos_metrics(trades, split, deposit):
    dated = [(t, p) for t, p in trades if re.match(r"\d{4}", t)]
    if len(dated) < len(trades) * 0.9:
        return {"status": "SKIPPED_NO_DATA", "note": "trade times missing — cannot date-split"}
    dated.sort(key=lambda x: x[0])
    cut = int(len(dated) * split)
    is_p = [p for _, p in dated[:cut]]
    oos_p = [p for _, p in dated[cut:]]
    if not is_p or not oos_p:
        return {"status": "SKIPPED_NO_DATA", "note": "split produced empty segment"}
    is_pf, oos_pf = profit_factor(is_p), profit_factor(oos_p)
    is_dd, oos_dd = max_dd_pct(is_p, deposit), max_dd_pct(oos_p, deposit)
    return {
        "status": "COMPUTED",
        "split": split,
        "is_trades": len(is_p), "oos_trades": len(oos_p),
        "is_pf": round(is_pf, 3), "oos_pf": round(oos_pf, 3),
        "pf_ratio": round(oos_pf / is_pf, 3) if is_pf else None,
        "pf_degradation_pct": round((1 - oos_pf / is_pf) * 100, 1) if is_pf else None,
        "is_dd_pct": round(is_dd, 2), "oos_dd_pct": round(oos_dd, 2),
        "dd_ratio": round(oos_dd / is_dd, 3) if is_dd else None,
        "oos_net_profit": round(sum(oos_p), 2),
        "note": "OOS from date-split of the same backtest — weaker evidence than a true separate OOS run",
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("trades_csv")
    ap.add_argument("--deposit", type=float, required=True)
    ap.add_argument("-n", "--permutations", type=int, default=1000)
    ap.add_argument("--bootstrap", action="store_true")
    ap.add_argument("--ruin-dd", type=float, default=50.0,
                    help="drawdown %% treated as ruin (default 50)")
    ap.add_argument("--oos-split", type=float, default=None,
                    help="IS fraction for date-based OOS split, e.g. 0.7")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("-o", "--output")
    args = ap.parse_args()

    trades = load_trades(Path(args.trades_csv))
    profits = [p for _, p in trades]
    if len(profits) < 20:
        sys.exit(f"only {len(profits)} trades — too few for Monte Carlo (min 20)")

    rng = random.Random(args.seed)
    out = {
        "source_file": args.trades_csv,
        "trade_count": len(profits),
        "net_profit": round(sum(profits), 2),
        "observed_pf": round(min(profit_factor(profits), 99.0), 3),
        "observed_dd_pct": round(max_dd_pct(profits, args.deposit), 2),
        "deposit": args.deposit,
        "ruin_dd_threshold_pct": args.ruin_dd,
        "shuffle": simulate(profits, args.deposit, args.permutations, args.ruin_dd, "shuffle", rng),
    }
    if args.bootstrap:
        if len(profits) >= 50:
            out["bootstrap"] = simulate(profits, args.deposit, args.permutations,
                                        args.ruin_dd, "bootstrap", rng)
        else:
            out["bootstrap"] = {"status": "SKIPPED", "note": "needs >= 50 trades"}
    if args.oos_split:
        out["oos"] = oos_metrics(trades, args.oos_split, args.deposit)

    text = json.dumps(out, indent=2)
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
        print(f"wrote {args.output}")
    else:
        print(text)


if __name__ == "__main__":
    main()
