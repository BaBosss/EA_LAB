import sys, json, os
sys.path.insert(0, "D:\EA_LAB\scripts")
from parse_mt5_report import parse_report

report = sys.argv[1]
r = parse_report(report)
pf = r.get("profit_factor", 0)
trades = int(r.get("total_trades", 0))
dd = r.get("equity_drawdown_relative_pct", 0)
net = r.get("net_profit", 0)
print(f"{pf} | {trades} | {dd} | {net}")
