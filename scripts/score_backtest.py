#!/usr/bin/env python3
"""Score a parsed MT5 backtest JSON with BacktestScore v1 (recovered EA_Monitor spec).

Pipeline step 2 of: parse_mt5_report.py -> score_backtest.py -> registry.
Uses only metrics that parse reliably (PF, DD%, RF, trades, expected_payoff).
Flags missing/uncertain inputs (monthly stability, one-big-trade) instead of faking them.

Usage:
  python score_backtest.py <parsed.json> [--strategy mean_reversion] [-o verdict.json]

Reference: D:\\EA_LAB\\docs\\RECOVERED_PLATFORM_DESIGN_20260614.md  section 3.
"""
import json
import sys
import argparse

# full-10-point trade-count threshold by strategy type
TRADE_MIN = {
    "scalping": 300, "intraday": 150, "session": 150, "trend_pullback": 80,
    "breakout": 80, "mean_reversion": 150, "swing": 40, "grid": 0, "default": 80,
}


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def pf_score(pf):
    if pf is None or pf < 1.20:
        return 0.0
    return round(clamp(15 + (pf - 1.20) / 1.0 * 10, 0, 25), 1)


def dd_score(dd):
    if dd is None:
        return 0.0
    return round(clamp(25 * (25 - dd) / 24, 0, 25), 1)


def rf_score(rf):
    if rf is None or rf < 1.0:
        return 0.0
    return round(clamp(12 + (rf - 1.5) / 2.5 * 8, 0, 20), 1)


def trade_score(n, strat):
    mn = TRADE_MIN.get(strat, TRADE_MIN["default"])
    if not n:
        return 0.0
    if mn == 0:
        return 7.0                       # grid: count cycles, neutral default
    if n >= mn:
        return 10.0
    if n >= mn * 0.5:
        return round(4 + (n - mn * 0.5) / (mn * 0.5) * 5, 1)   # 4-9 band
    return round(clamp(n / (mn * 0.5) * 4, 0, 4), 1)


def ep_score(ep, one_big):
    if ep is None or ep <= 0:
        return 0.0
    base = 7.0 if ep >= 5 else (5.0 if ep >= 2 else 3.0)
    if one_big is True:
        base = min(base, 4.0)
    elif one_big is False and ep >= 5:
        base = min(base + 2, 10.0)
    return round(clamp(base, 0, 10), 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("parsed")
    ap.add_argument("--strategy", default="default")
    ap.add_argument("-o", "--out")
    a = ap.parse_args()
    d = json.loads(open(a.parsed, encoding="utf-8").read())

    pf = d.get("profit_factor")
    dd = d.get("equity_drawdown_maximal_percent") or d.get("balance_drawdown_maximal_percent")
    rf = d.get("recovery_factor")
    trades = d.get("total_trades")
    ep = d.get("expected_payoff")

    warnings = []

    # one-big-trade: needs reliable net_profit (parser truncates thousands at comma)
    net = d.get("net_profit")
    big = d.get("largest_profit_trade")
    one_big = None
    if net and big and net > big * 1.5:        # net looks un-truncated
        one_big = (big / net) > 0.30
    else:
        warnings.append("net_profit unreliable (parser comma-truncation) -> one-big-trade unchecked")

    # monthly stability not present in single-report parse
    monthly = None
    warnings.append("monthly stability not in single-report parse -> scored conservatively (5/10)")

    comp = {
        "profit_factor": pf_score(pf),
        "max_dd": dd_score(dd),
        "recovery_factor": rf_score(rf),
        "trade_count": trade_score(trades, a.strategy),
        "expected_payoff": ep_score(ep, one_big),
        "monthly_stability": 5.0 if monthly is None else monthly,
    }
    score = round(sum(comp.values()), 1)

    # band
    if score >= 80:
        band = "A (strong)"
    elif score >= 65:
        band = "B (usable)"
    elif score >= 50:
        band = "C (watch/optimize)"
    else:
        band = "reject"

    # hard PASS/WATCH/REJECT gate
    if pf is None or pf < 1.05 or (dd or 99) > 30 or (rf or 0) < 1.0:
        verdict = "REJECT"
    elif pf >= 1.20 and (dd or 99) <= 20 and (rf or 0) >= 1.50 and score >= 65:
        verdict = "PASS"
    else:
        verdict = "WATCH"

    out = {
        "ea_name": d.get("ea_name"),
        "symbol": d.get("symbol"),
        "period": d.get("period"),
        "strategy": a.strategy,
        "metrics": {"PF": pf, "DD%": dd, "RF": rf, "trades": trades, "EP": ep},
        "components": comp,
        "BacktestScore": score,
        "band": band,
        "verdict": verdict,
        "warnings": warnings,
        "source": d.get("source_file"),
    }
    if a.out:
        open(a.out, "w", encoding="utf-8").write(json.dumps(out, ensure_ascii=False, indent=2))

    # human summary to stdout
    print(f"EA: {out['ea_name']}  [{a.strategy}]")
    print(f"PF={pf} DD%={dd} RF={rf} trades={trades} EP={ep}")
    print("components: " + ", ".join(f"{k}={v}" for k, v in comp.items()))
    print(f"BacktestScore = {score}/100  -> Tier {band}")
    print(f"VERDICT = {verdict}")
    for w in warnings:
        print(f"  ! {w}")


if __name__ == "__main__":
    main()
