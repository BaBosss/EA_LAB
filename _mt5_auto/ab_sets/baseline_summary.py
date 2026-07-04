import json, subprocess, sys

syms = ["USDJPY","AUDNZD","EURJPY","AUDCAD","CADJPY","EURUSD"]
for s in syms:
    f = f"D:\\EA_LAB\\_mt5_auto\\reports\\BOSS14_{s}_FULL_ISPICK_M1.htm"
    out = subprocess.run(["python", "D:\\EA_LAB\\scripts\\parse_mt5_report.py", f, "--json"], capture_output=True, text=True)
    d = json.loads(out.stdout)
    print(f"{s}: PF={d['profit_factor']} trades={int(d['total_trades'])} eqDD%={d['equity_drawdown_maximal_pct']} net={d['net_profit']}")
