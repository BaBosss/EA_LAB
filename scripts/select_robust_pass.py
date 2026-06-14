#!/usr/bin/env python3
"""Pick the ROBUST pass from an MT5 optimizer batch — not the profit-max peak.

Profit-max passes are usually overfit (high PF, high DD, isolated peak). This
applies the recovered "Pass-1 stability gate" (PF>=1.20, DD<=20, RF>=1.50),
ranks survivors by a DD-weighted robust score, and measures plateau quality by
how many passes survive the gate (a wide robust zone = trustworthy; a lone
survivor = overfit peak).

Importable: from select_robust_pass import select_robust
CLI: python select_robust_pass.py <optimizer.xml> [--strategy mean_reversion]

Reference: RECOVERED_PLATFORM_DESIGN_20260614.md sections 3 & 5.
"""
import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score_backtest as SB                      # noqa: E402

GATE_PF, GATE_DD, GATE_RF = 1.20, 20.0, 1.50


def _m(p):
    return {
        "PF": p.get("profit_factor"),
        "DD%": p.get("max_drawdown_percent"),
        "RF": p.get("recovery_factor"),
        "trades": p.get("total_trades"),
        "net": p.get("net_profit"),
    }


def select_robust(passes, strategy="default"):
    total = len(passes)
    survivors = []
    for p in passes:
        pf = p.get("profit_factor")
        dd = p.get("max_drawdown_percent")
        rf = p.get("recovery_factor")
        if pf is None or dd is None or rf is None:
            continue
        if pf >= GATE_PF and dd <= GATE_DD and rf >= GATE_RF:
            rscore = (SB.pf_score(pf) + SB.dd_score(dd) + SB.rf_score(rf)
                      + SB.trade_score(p.get("total_trades"), strategy))
            survivors.append((round(rscore, 1), p))
    # rank: high robust score, then lowest DD
    survivors.sort(key=lambda x: (-x[0], x[1].get("max_drawdown_percent") or 99))

    n = len(survivors)
    if n >= 20:
        plateau = "GOOD"
    elif n >= 5:
        plateau = "WEAK"
    elif n >= 1:
        plateau = "THIN"
    else:
        plateau = "NONE"

    profit_max = max(passes, key=lambda p: (p.get("net_profit")
                     if isinstance(p.get("net_profit"), (int, float)) else float("-inf")))
    return {
        "total_passes": total,
        "survivors": n,
        "survivor_ratio_pct": round(100 * n / total, 1) if total else 0,
        "plateau": plateau,
        "robust": _m(survivors[0][1]) if survivors else None,
        "robust_score": survivors[0][0] if survivors else None,
        "profit_max": _m(profit_max),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xml")
    ap.add_argument("--strategy", default="default")
    a = ap.parse_args()
    sys.path.insert(0, r"C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts")
    import parse_mt5_report as P
    d = P.parse_optimizer_xml(Path(a.xml), top=0)
    r = select_robust(d.get("passes") or [], a.strategy)
    print(f"passes={r['total_passes']} survivors={r['survivors']} "
          f"({r['survivor_ratio_pct']}%) plateau={r['plateau']}")
    print(f"robust pick: {r['robust']}  score={r['robust_score']}")
    print(f"profit-max : {r['profit_max']}  <- overfit-prone")


if __name__ == "__main__":
    main()
