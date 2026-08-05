import sys
sys.path.insert(0, r"D:\EA_LAB\scripts")
sys.path.insert(0, r"C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts")
import parse_mt5_report as P
import select_robust_pass as SR
from pathlib import Path

xml = sys.argv[1]
min_tr = int(sys.argv[2]) if len(sys.argv)>2 else 25
d = P.parse_optimizer_xml(Path(xml), top=0)
passes = d.get("passes") or []
surv = []
for p in passes:
    pf=p.get("profit_factor"); dd=p.get("max_drawdown_percent"); rf=p.get("recovery_factor"); tr=p.get("total_trades") or 0
    if pf is None or dd is None or rf is None: continue
    if pf>=1.20 and dd<=20 and rf>=1.50 and tr>=min_tr:
        surv.append(p)
pkeys = SR._param_keys(passes)
steps = {k: SR._grid_step(passes, k) for k in pkeys}
surv_keys = {tuple(p.get(k) for k in pkeys) for p in surv}
results=[]
for p in surv:
    here = tuple(p.get(k) for k in pkeys)
    n=0
    for other in surv_keys:
        if other==here: continue
        if all(abs((other[i] or 0)-(here[i] or 0)) <= steps[pkeys[i]]+1e-9 for i in range(len(pkeys))):
            n+=1
    results.append((n, p))
results.sort(key=lambda x: -x[0])
for n,p in results[:10]:
    print(n, {k:p.get(k) for k in pkeys}, SR._m(p))
