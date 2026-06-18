#!/usr/bin/env python3
"""Rank a symbol universe by how well it fits a strategy TYPE — so you optimize
the few symbols that actually suit the edge, instead of guessing.

Two modes:
  1. KNOWLEDGE mode (default): score each symbol from a curated FX profile table
     (trendiness, volatility class, instrument family) against the strategy's
     preferences. Instant, no data needed. Use to pick the first batch to smoke.
  2. EMPIRICAL mode (--from-reports DIR): rank by ACTUAL smoke-test PF already on
     disk (reports/smoke_<EA>_<SYM>.htm). Use after a screening batch to confirm.

Strategy types: trend, mean_reversion, grid, breakout, scalp.

CLI:
  python symbol_fitness.py --strategy trend
  python symbol_fitness.py --strategy mean_reversion --top 8
  python symbol_fitness.py --strategy trend --from-reports _mt5_auto/reports --ea MACD
"""
import argparse
import os
import sys
from pathlib import Path

# --- Curated FX symbol profiles -------------------------------------------------
# trend  : tendency to sustain directional moves (0 ranging .. 1 strong trend)
# vol    : average true-range class (low / med / high)
# family : major / cross / metal  (spread & session behaviour proxy)
SYMBOL_PROFILE = {
    "EURUSD": {"trend": 0.45, "vol": "low",  "family": "major"},
    "GBPUSD": {"trend": 0.65, "vol": "med",  "family": "major"},
    "USDJPY": {"trend": 0.70, "vol": "med",  "family": "major"},
    "USDCHF": {"trend": 0.50, "vol": "low",  "family": "major"},
    "USDCAD": {"trend": 0.60, "vol": "med",  "family": "major"},
    "AUDUSD": {"trend": 0.55, "vol": "med",  "family": "major"},
    "NZDUSD": {"trend": 0.55, "vol": "med",  "family": "major"},
    "EURGBP": {"trend": 0.30, "vol": "low",  "family": "cross"},
    "EURJPY": {"trend": 0.65, "vol": "high", "family": "cross"},
    "GBPJPY": {"trend": 0.75, "vol": "high", "family": "cross"},
    "CHFJPY": {"trend": 0.55, "vol": "med",  "family": "cross"},
    "CADJPY": {"trend": 0.60, "vol": "high", "family": "cross"},
    "AUDJPY": {"trend": 0.62, "vol": "high", "family": "cross"},
    "EURCHF": {"trend": 0.25, "vol": "low",  "family": "cross"},
    "EURCAD": {"trend": 0.50, "vol": "med",  "family": "cross"},
    "EURAUD": {"trend": 0.55, "vol": "high", "family": "cross"},
    "GBPCHF": {"trend": 0.50, "vol": "med",  "family": "cross"},
    "AUDCAD": {"trend": 0.40, "vol": "low",  "family": "cross"},
    "AUDNZD": {"trend": 0.30, "vol": "low",  "family": "cross"},
    "AUDCHF": {"trend": 0.40, "vol": "med",  "family": "cross"},
    "NZDCAD": {"trend": 0.40, "vol": "low",  "family": "cross"},
    "XAUUSD": {"trend": 0.70, "vol": "high", "family": "metal"},
    "XAGUSD": {"trend": 0.65, "vol": "high", "family": "metal"},
}

# --- Strategy preferences -------------------------------------------------------
# Each scorer returns 0..1. Higher = better fit for that strategy type.
VOL_RANK = {"low": 0.0, "med": 0.5, "high": 1.0}


def _fit_trend(p):
    # trend-following wants trending instruments, medium+ volatility helps
    return 0.75 * p["trend"] + 0.25 * VOL_RANK[p["vol"]]


def _fit_mean_reversion(p):
    # MR wants RANGING instruments (low trend), low/med volatility (clean bounces)
    return 0.70 * (1 - p["trend"]) + 0.30 * (1 - VOL_RANK[p["vol"]])


def _fit_grid(p):
    # grids want ranging + LOW volatility (controlled basket exposure)
    rng = 1 - p["trend"]
    lowvol = 1 - VOL_RANK[p["vol"]]
    return 0.55 * rng + 0.45 * lowvol


def _fit_breakout(p):
    # breakout wants HIGH volatility + some trend follow-through
    return 0.60 * VOL_RANK[p["vol"]] + 0.40 * p["trend"]


def _fit_scalp(p):
    # scalping wants low spread (majors) + low/med volatility, range OK
    fam = 1.0 if p["family"] == "major" else (0.5 if p["family"] == "cross" else 0.2)
    return 0.55 * fam + 0.45 * (1 - VOL_RANK[p["vol"]])


SCORERS = {
    "trend": _fit_trend,
    "mean_reversion": _fit_mean_reversion,
    "grid": _fit_grid,
    "breakout": _fit_breakout,
    "scalp": _fit_scalp,
}


def rank_knowledge(strategy, universe=None):
    scorer = SCORERS[strategy]
    syms = universe or list(SYMBOL_PROFILE)
    rows = []
    for s in syms:
        p = SYMBOL_PROFILE.get(s)
        if not p:
            continue
        rows.append((s, round(scorer(p), 3), p))
    rows.sort(key=lambda x: -x[1])
    return rows


def rank_empirical(reports_dir, ea):
    """Rank by actual smoke-test PF on disk."""
    sys.path.insert(0, r"C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts")
    import parse_mt5_report as P
    rows = []
    for fn in os.listdir(reports_dir):
        low = fn.lower()
        if not low.endswith(".htm"):
            continue
        if ea.lower() not in low:
            continue
        try:
            d = P.parse_html_report(Path(reports_dir, fn))
            sym = d.get("symbol") or fn
            rows.append((sym, fn, round(d.get("profit_factor", 0), 2),
                         round(d.get("equity_drawdown_relative", 0), 1),
                         d.get("total_trades", 0)))
        except Exception:
            pass
    rows.sort(key=lambda x: -x[2])
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--strategy", required=True, choices=list(SCORERS))
    ap.add_argument("--top", type=int, default=10)
    ap.add_argument("--from-reports", default=None,
                    help="reports dir for EMPIRICAL ranking by real smoke PF")
    ap.add_argument("--ea", default=None, help="EA name substring (empirical mode)")
    a = ap.parse_args()

    if a.from_reports:
        if not a.ea:
            ap.error("--from-reports requires --ea")
        rows = rank_empirical(a.from_reports, a.ea)
        print(f"EMPIRICAL fit for '{a.ea}' (by real smoke PF):")
        print(f"{'Symbol':<10}{'PF':>6}{'DD%':>7}{'Trades':>8}  file")
        for sym, fn, pf, dd, tr in rows[:a.top]:
            flag = "  <<" if pf >= 1.5 and dd <= 30 and tr >= 100 else ""
            print(f"{sym:<10}{pf:>6.2f}{dd:>6.1f}%{tr:>8}  {fn}{flag}")
        return

    rows = rank_knowledge(a.strategy)
    print(f"KNOWLEDGE fit for strategy='{a.strategy}' (top {a.top}):")
    print(f"{'Symbol':<10}{'Fit':>6}  {'trend':>6} {'vol':>5} {'family'}")
    for s, score, p in rows[:a.top]:
        print(f"{s:<10}{score:>6.3f}  {p['trend']:>6.2f} {p['vol']:>5} {p['family']}")
    print(f"\n-> optimize the top 3-5; skip the rest unless portfolio needs "
          f"a low-correlation outlier.")


if __name__ == "__main__":
    main()
