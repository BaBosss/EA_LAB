#!/usr/bin/env python3
"""Score a parsed MT5 backtest with BacktestScore v1 (recovered EA_Monitor spec).

Pipeline step 2 of: parse_mt5_report.py -> score_backtest.py -> registry.
Importable: `from score_backtest import score` -> score(parsed_dict, strategy).

Usage (CLI):
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
        return 7.0
    if n >= mn:
        return 10.0
    if n >= mn * 0.5:
        return round(4 + (n - mn * 0.5) / (mn * 0.5) * 5, 1)
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


def score(d, strategy="default"):
    """Score a parsed single-backtest dict. Returns a verdict dict."""
    pf = d.get("profit_factor")
    dd = d.get("equity_drawdown_maximal_percent") or d.get("balance_drawdown_maximal_percent")
    rf = d.get("recovery_factor")
    trades = d.get("total_trades")
    ep = d.get("expected_payoff")

    warnings = []

    # one-big-trade (now reliable: parser comma-bug fixed)
    net = d.get("net_profit")
    big = d.get("largest_profit_trade")
    one_big = None
    if isinstance(net, (int, float)) and isinstance(big, (int, float)) and net > 0:
        one_big = (big / net) > 0.30
        if one_big:
            warnings.append(f"one-big-trade: largest {big} = {big/net*100:.0f}% of net")
    else:
        warnings.append("net/largest missing -> one-big-trade unchecked")

    # monthly stability: present only if report was parsed with --trades
    ts = d.get("trade_stats") or {}
    monthly = None
    if "profitable_months_pct" in ts:
        pm = ts["profitable_months_pct"]
        monthly = 9.0 if pm >= 60 else (7.0 if pm >= 55 else (5.0 if pm >= 50 else (4.0 if pm >= 40 else 2.0)))
    else:
        warnings.append("no monthly data (parse with --trades) -> stability scored 5/10")

    if strategy == "grid":
        warnings.append(f"GRID: size against REPORT DD ({dd}%) x2-3 — closed-trade Monte Carlo "
                        "understates floating basket drawdown; do not trust MC DD/ruin for grids")

    comp = {
        "profit_factor": pf_score(pf),
        "max_dd": dd_score(dd),
        "recovery_factor": rf_score(rf),
        "trade_count": trade_score(trades, strategy),
        "expected_payoff": ep_score(ep, one_big),
        "monthly_stability": 5.0 if monthly is None else monthly,
    }
    total = round(sum(comp.values()), 1)

    if total >= 80:
        band = "A (strong)"
    elif total >= 65:
        band = "B (usable)"
    elif total >= 50:
        band = "C (watch/optimize)"
    else:
        band = "reject"

    if pf is None or pf < 1.05 or (dd or 99) > 30 or (rf or 0) < 1.0:
        verdict = "REJECT"
    elif pf >= 1.20 and (dd or 99) <= 20 and (rf or 0) >= 1.50 and total >= 65:
        verdict = "PASS"
    else:
        verdict = "WATCH"

    return {
        "ea_name": d.get("ea_name"),
        "symbol": d.get("symbol"),
        "period": d.get("period"),
        "strategy": strategy,
        "metrics": {"PF": pf, "DD%": dd, "RF": rf, "trades": trades, "EP": ep, "net": net},
        "components": comp,
        "BacktestScore": total,
        "band": band,
        "verdict": verdict,
        "warnings": warnings,
        "source": d.get("source_file"),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("parsed")
    ap.add_argument("--strategy", default="default")
    ap.add_argument("-o", "--out")
    a = ap.parse_args()
    d = json.loads(open(a.parsed, encoding="utf-8-sig").read())
    out = score(d, a.strategy)
    if a.out:
        open(a.out, "w", encoding="utf-8").write(json.dumps(out, ensure_ascii=False, indent=2))
    c = out["components"]
    print(f"EA: {out['ea_name']}  [{a.strategy}]  symbol={out['symbol']}")
    print(f"PF={out['metrics']['PF']} DD%={out['metrics']['DD%']} RF={out['metrics']['RF']} "
          f"trades={out['metrics']['trades']} net={out['metrics']['net']}")
    print("components: " + ", ".join(f"{k}={v}" for k, v in c.items()))
    print(f"BacktestScore = {out['BacktestScore']}/100  -> Tier {out['band']}")
    print(f"VERDICT = {out['verdict']}")
    for w in out["warnings"]:
        print(f"  ! {w}")


if __name__ == "__main__":
    main()
