import sys
sys.path.insert(0, r"C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts")
import parse_mt5_report as P
from pathlib import Path
d = P.parse_html_report(Path(sys.argv[1]))
for k in ["profit_factor","max_drawdown_percent","recovery_factor","total_trades","net_profit","sharpe_ratio","expected_payoff"]:
    print(k, d.get(k))
