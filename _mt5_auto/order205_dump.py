import sys
sys.path.insert(0, r"D:\EA_LAB\scripts")
sys.path.insert(0, r"C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts")
import parse_mt5_report as P
import order205_select as OS
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
from collections import Counter
for k in ["_01_BreakoutBars","_02_SlAtrMult","_02_TpAtrMult","_04_EmaPeriod"]:
    c = Counter(p.get(k) for p in surv)
    print(k, sorted(c.items()))
print("n_survivors", len(surv))
