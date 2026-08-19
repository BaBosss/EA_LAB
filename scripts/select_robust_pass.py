#!/usr/bin/env python3
"""Pick the ROBUST pass from an MT5 optimizer batch — not the profit-max peak.

Profit-max passes are usually overfit (high PF, high DD, isolated peak). This
applies the recovered "Pass-1 stability gate" (PF>=1.20, DD<=20, RF>=1.50),
ranks survivors by a DD-weighted robust score, and measures plateau quality by
how many passes survive the gate (a wide robust zone = trustworthy; a lone
survivor = overfit peak).

Importable: from select_robust_pass import select_robust
CLI: python select_robust_pass.py <optimizer.xml> [--strategy mean_reversion]

Reference: _archive_docs/RECOVERED_PLATFORM_DESIGN_20260614.md sections 3 & 5 (archived/superseded spec —
this script still implements the old BacktestScore v1 gate; not re-verified against the current
VERDICT GATE / backtest-optimize-rigor LADDER as part of ORDER-152(c)).
"""
import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score_backtest as SB                      # noqa: E402

GATE_PF, GATE_DD, GATE_RF = 1.20, 20.0, 1.50


class LegacySelectionRefused(RuntimeError):
    """Raised when the legacy BacktestScore v1 selection gate is invoked
    without explicit opt-in. This selector is NOT the current Factory
    selection contract (see docs/PARAM_REGISTRY.csv + pre-registered
    candidate/hypothesis selection contracts). It is preserved for
    historical/research use only and requires allow_legacy=True."""


def _m(p):
    return {
        "PF": p.get("profit_factor"),
        "DD%": p.get("max_drawdown_percent"),
        "RF": p.get("recovery_factor"),
        "trades": p.get("total_trades"),
        "net": p.get("net_profit"),
        "EP": p.get("expected_payoff"),
        "SR": p.get("sharpe_ratio"),
    }


# keys that are metrics/ids, NOT optimizable parameters — everything else in a
# pass dict is treated as a tunable param for plateau-center detection
_NON_PARAM = {
    "Pass", "Result", "Profit", "Expected Payoff", "Profit Factor",
    "Recovery Factor", "Sharpe Ratio", "Custom", "Equity DD %", "Trades",
    "pass_id", "result", "net_profit", "expected_payoff", "profit_factor",
    "recovery_factor", "sharpe_ratio", "custom", "max_drawdown_percent",
    "total_trades",
}


def _param_keys(passes):
    """Optimizable param columns = numeric keys that vary across passes."""
    if not passes:
        return []
    keys = []
    for k in passes[0]:
        if k in _NON_PARAM:
            continue
        vals = {p.get(k) for p in passes if isinstance(p.get(k), (int, float))}
        if len(vals) > 1:                  # only params that actually varied
            keys.append(k)
    return keys


def _grid_step(passes, key):
    """Smallest positive gap between distinct sorted values of a param."""
    vals = sorted({p[key] for p in passes if isinstance(p.get(key), (int, float))})
    gaps = [b - a for a, b in zip(vals, vals[1:]) if b - a > 0]
    return min(gaps) if gaps else 1.0


def plateau_center(survivors_passes, all_passes):
    """Pick the survivor whose neighbours (±1 grid step in every param) are also
    survivors — the CENTRE of the robust zone, not a median of metrics.

    A param value that's good but surrounded by failing params is an overfit
    spike; the centre of a wide plateau transfers to live/OOS far better.
    Returns (best_pass, neighbour_count) or (None, 0).
    """
    pkeys = _param_keys(all_passes)
    if not pkeys or not survivors_passes:
        return (survivors_passes[0] if survivors_passes else None, 0)
    steps = {k: _grid_step(all_passes, k) for k in pkeys}
    surv_keys = {tuple(p.get(k) for k in pkeys) for p in survivors_passes}

    best, best_n = None, -1
    for p in survivors_passes:
        here = tuple(p.get(k) for k in pkeys)
        # count surviving neighbours within 1 grid step on each axis
        n = 0
        for other in surv_keys:
            if other == here:
                continue
            if all(abs((other[i] or 0) - (here[i] or 0)) <= steps[pkeys[i]] + 1e-9
                   for i in range(len(pkeys))):
                n += 1
        if n > best_n:
            best, best_n = p, n
    return best, best_n


def select_robust(passes, strategy="default", allow_legacy=False):
    if not allow_legacy:
        raise LegacySelectionRefused(
            "select_robust() is the legacy BacktestScore v1 gate "
            "(PF>=1.20, DD<=20, RF>=1.50, trade floor) — superseded and NOT the "
            "current Factory selection contract. Refusing by default. Pass "
            "allow_legacy=True (or --allow-legacy-selection on the CLI) to run "
            "it explicitly as historical/research-only (NON_FACTORY output).")
    total = len(passes)
    # trade-count floor: reject high-PF/low-trade flukes (e.g. PF 24 on 30 trades)
    min_trades = max(100, SB.TRADE_MIN.get(strategy, 80))
    survivors = []
    for p in passes:
        pf = p.get("profit_factor")
        dd = p.get("max_drawdown_percent")
        rf = p.get("recovery_factor")
        tr = p.get("total_trades") or 0
        if pf is None or dd is None or rf is None:
            continue
        if pf >= GATE_PF and dd <= GATE_DD and rf >= GATE_RF and tr >= min_trades:
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

    # plateau-centre pick: most robust param region, not just best single metric
    surv_passes = [p for _, p in survivors]
    center_pass, center_neighbours = plateau_center(surv_passes, passes)
    pkeys = _param_keys(passes)

    return {
        "total_passes": total,
        "survivors": n,
        "survivor_ratio_pct": round(100 * n / total, 1) if total else 0,
        "plateau": plateau,
        "robust": _m(survivors[0][1]) if survivors else None,
        "robust_score": survivors[0][0] if survivors else None,
        "profit_max": _m(profit_max),
        "param_keys": pkeys,
        "center": _m(center_pass) if center_pass else None,
        "center_params": {k: center_pass.get(k) for k in pkeys} if center_pass else None,
        "center_neighbours": center_neighbours,
        "robust_params": {k: survivors[0][1].get(k) for k in pkeys} if survivors else None,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xml")
    ap.add_argument("--strategy", default="default")
    ap.add_argument("--allow-legacy-selection", action="store_true",
                    help="Explicitly run this legacy selector as "
                         "historical/research-only (NON_FACTORY output).")
    a = ap.parse_args()
    if not a.allow_legacy_selection:
        print("REFUSED (LEGACY / NON_FACTORY): select_robust_pass.py is the "
              "superseded BacktestScore v1 gate (PF>=1.20, DD<=20, RF>=1.50, "
              "trade floor). It is NOT the current Factory selection contract.")
        print("Current Factory selection comes from candidate/hypothesis "
              "pre-registration (ParameterBinding + registry resolver).")
        print("To run it explicitly as historical/research-only, re-invoke "
              "with --allow-legacy-selection.")
        sys.exit(3)
    sys.path.insert(0, r"C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts")
    import parse_mt5_report as P
    d = P.parse_optimizer_xml(Path(a.xml), top=0)
    r = select_robust(d.get("passes") or [], a.strategy, allow_legacy=True)
    print("LEGACY / NON_FACTORY: output is historical/research-only and "
          "NON-AUTHORITATIVE for current Factory verdict/selection.")
    print(f"passes={r['total_passes']} survivors={r['survivors']} "
          f"({r['survivor_ratio_pct']}%) plateau={r['plateau']}")
    print(f"robust pick : {r['robust']}  score={r['robust_score']}")
    print(f"  params    : {r['robust_params']}")
    print(f"center pick : {r['center']}  neighbours={r['center_neighbours']}  <- USE THIS (plateau centre)")
    print(f"  params    : {r['center_params']}")
    print(f"profit-max  : {r['profit_max']}  <- overfit-prone")


if __name__ == "__main__":
    main()
