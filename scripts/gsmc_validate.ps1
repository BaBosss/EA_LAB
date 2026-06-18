<#
gsmc_validate.ps1 — Run IS + OOS for GSMC and produce full robustness report.

Usage: & .\gsmc_validate.ps1 [-SetFile <path>] [-Label <tag>]
  -SetFile : locked .set to use (default: GSMC_run004_locked.set)
  -Label   : prefix for report names (default: GSMC_v2)
#>
param(
  [string]$SetFile = "D:\EA_LAB\_mt5_auto\GSMC_run004_locked.set",
  [string]$Label   = "GSMC_v2"
)
$ErrorActionPreference = "Stop"
$scripts = "D:\EA_LAB\scripts"
$skills  = "C:\Users\patip\.claude\skills"

Write-Output "=== GSMC VALIDATE: $Label ==="
Write-Output "Set: $SetFile"

# IS: 2023-2026
Write-Output "`n--- IS 2023.01.01-2026.06.01 ---"
& "$scripts\mt5_run.ps1" -Expert "Gold_SMC_Continuous_MT5_RiskCapV1" -Symbol XAUUSD -Period H1 -Model 4 `
  -FromDate "2023.01.01" -ToDate "2026.06.01" -SetFile $SetFile -ReportName "${Label}_IS"

# OOS: 2020-2023
Write-Output "`n--- OOS 2020.01.01-2023.01.01 ---"
& "$scripts\mt5_run.ps1" -Expert "Gold_SMC_Continuous_MT5_RiskCapV1" -Symbol XAUUSD -Period H1 -Model 4 `
  -FromDate "2020.01.01" -ToDate "2023.01.01" -SetFile $SetFile -ReportName "${Label}_OOS"

# Parse IS + score
Write-Output "`n--- Parse + Score ---"
$is_htm  = "D:\EA_LAB\_mt5_auto\reports\${Label}_IS.htm"
$oos_htm = "D:\EA_LAB\_mt5_auto\reports\${Label}_OOS.htm"
$is_json  = "D:\EA_LAB\_mt5_auto\${Label}_IS_parsed.json"
$oos_json = "D:\EA_LAB\_mt5_auto\${Label}_OOS_parsed.json"
$is_csv   = "D:\EA_LAB\_mt5_auto\${Label}_IS_trades.csv"

python "$skills\backtest-report-analyzer\scripts\parse_mt5_report.py" $is_htm  | Set-Content $is_json  -Encoding UTF8
python "$skills\backtest-report-analyzer\scripts\parse_mt5_report.py" $oos_htm | Set-Content $oos_json -Encoding UTF8
python "$scripts\score_backtest.py" $is_json  --strategy mean_reversion
python "$scripts\score_backtest.py" $oos_json --strategy mean_reversion

# Extract deals + Monte Carlo on IS
Write-Output "`n--- Monte Carlo on IS ---"
python "$scripts\extract_deals.py" $is_htm -o $is_csv
python "$skills\robustness-validator\scripts\monte_carlo.py" $is_csv --deposit 10000 --bootstrap --ruin-dd 50 `
  -o "D:\EA_LAB\_mt5_auto\${Label}_IS_mc.json"
Get-Content "D:\EA_LAB\_mt5_auto\${Label}_IS_mc.json" -Encoding UTF8

Write-Output "`n=== DONE: $Label ==="
