#!/usr/bin/env python3
"""ORDER-205 custom select — same gate as select_robust_pass.py (PF>=1.20, DD<=20,
RF>=1.50) but with a trade floor of 25 (not the script's hardcoded 100), because this
EA is a low-frequency breakout system validated at 30-50 trades/3yr. See order text.
"""
import sys
sys.path.insert(0, r"D:\EA_LAB\scripts")
sys.path.insert(0, r"C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts")
import parse_mt5_report as P
import select_robust_pass as SR

GATE_PF, GATE_DD, GATE_RF, MIN_TRADES = 1.20, 20.0, 1.50, 25

def select(passes, min_trades=MIN_TRADES):
    survivors = []
    for p in passes:
        pf = p.get("profit_factor"); dd = p.get("max_drawdown_percent")
        rf = p.get("recovery_factor"); tr = p.get("total_trades") or 0
        if pf is None or dd is None or rf is None:
            continue
        if pf >= GATE_PF and dd <= GATE_DD and rf >= GATE_RF and tr >= min_trades:
            rscore = pf * 10 - dd  # simple robust score: reward PF, penalize DD
            survivors.append((round(rscore, 2), p))
    survivors.sort(key=lambda x: (-x[0], x[1].get("max_drawdown_percent") or 99))
    n = len(survivors)
    surv_passes = [p for _, p in survivors]
    pkeys = SR._param_keys(passes)
    center_pass, center_n = SR.plateau_center(surv_passes, passes)
    return {
        "total": len(passes), "survivors": n,
        "survivor_pcts": round(100*n/len(passes),1) if passes else 0,
        "top10": [(_ , SR._m(p)) for _, p in survivors[:10]],
        "top10_params": [{k: p.get(k) for k in pkeys} for _, p in survivors[:10]],
        "center": SR._m(center_pass) if center_pass else None,
        "center_params": {k: center_pass.get(k) for k in pkeys} if center_pass else None,
        "center_neighbours": center_n,
        "pkeys": pkeys,
    }

if __name__ == "__main__":
    xml = sys.argv[1]
    min_tr = int(sys.argv[2]) if len(sys.argv) > 2 else MIN_TRADES
    d = P.parse_optimizer_xml(__import__("pathlib").Path(xml), top=0)
    r = select(d.get("passes") or [], min_tr)
    print(f"total={r['total']} survivors={r['survivors']} ({r['survivor_pcts']}%) min_trades={min_tr}")
    print(f"center: {r['center']}  neighbours={r['center_neighbours']}")
    print(f"center_params: {r['center_params']}")
    print("--- top10 ---")
    for (sc,m),pr in zip(r['top10'], r['top10_params']):
        print(sc, m, pr)
