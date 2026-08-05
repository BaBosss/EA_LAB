import sys, os, subprocess, shutil
sys.path.insert(0, r"D:\EA_LAB\scripts")
from parse_mt5_report import parse_report

base_set = r"D:\EA_LAB\_mt5_auto\ab_sets\o1411\PVT_base.set"
work_dir = r"D:\EA_LAB\_mt5_auto\ab_sets\o1411"
reports_folder = r"D:\EA_LAB\_mt5_auto\reports"
md_path = r"D:\EA_LAB\_mt5_auto\O1411_CELL2.md"
mt5_run = r"D:\EA_LAB\scripts\mt5_run.ps1"
mt5 = r"D:\Meta 5c\terminal64.exe"
data_dir = r"D:\Meta 5c"

sl_values = [1.0, 1.5, 2.0, 2.5, 3.0]
atr_values = [7, 10, 14, 20, 28]

# Write header
with open(md_path, "w") as f:
    f.write("| SlAtrMult | AtrPeriod | PF | trades | DD% | net | report |\n")
    f.write("|---|---|---|---|---|---|---|\n")

for sl in sl_values:
    for atr in atr_values:
        rpt_name = f"O1411_PVT2_Sl{sl}_Atr{atr}"
        copy_set = os.path.join(work_dir, f"{rpt_name}.set")
        
        # Copy base and replace params
        with open(base_set, "r") as f:
            lines = f.readlines()
        with open(copy_set, "w") as f:
            for line in lines:
                if line.startswith("_02_SlAtrMult"):
                    f.write(f"_02_SlAtrMult={sl}\n")
                elif line.startswith("_01_AtrPeriod"):
                    f.write(f"_01_AtrPeriod={atr}\n")
                else:
                    f.write(line)
        
        print(f"RUN: {rpt_name} (Sl={sl}, Atr={atr})")
        
        # Run backtest
        cmd = [
            "powershell", "-File", mt5_run,
            "-Expert", "PivotBreakout_XAU",
            "-Symbol", "USDJPY",
            "-Period", "H4",
            "-FromDate", "2023.01.01",
            "-ToDate", "2025.12.31",
            "-Model", "1",
            "-SetFile", copy_set,
            "-ReportName", rpt_name,
            "-Terminal", mt5,
            "-DataDir", data_dir,
            "-Portable"
        ]
        subprocess.run(cmd, capture_output=True, text=True)
        
        rpt_path = os.path.join(reports_folder, f"{rpt_name}.htm")
        if os.path.exists(rpt_path):
            r = parse_report(rpt_path)
            pf = r.get("profit_factor", 0)
            trades = int(r.get("total_trades", 0))
            dd = r.get("equity_drawdown_relative_pct", 0)
            net = r.get("net_profit", 0)
            row = f"| {sl} | {atr} | {pf} | {trades} | {dd} | {net} | {rpt_name} |\n"
            print(f"  -> PF={pf} trades={trades} DD%={dd} net={net}")
            with open(md_path, "a") as f:
                f.write(row)
        else:
            print(f"  REPORT NOT FOUND: {rpt_path}")
            row = f"| {sl} | {atr} | MISSING | {rpt_name} |\n"
            with open(md_path, "a") as f:
                f.write(row)

print("ALL DONE")
