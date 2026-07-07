# ORDER-046 stage 2 — revived configs through the remaining gates:
#   swb grid flat-lot + Yetti3 no-boost: SPR30 then Model-0 (2020-22, EURUSD)
# Verdict rule (Claude): M0 result only counts if SPR30 held PF > ~1.3.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$dd_experts = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$sets = "D:\EA_LAB\_mt5_auto\ab_sets"
$out = "D:\EA_LAB\_mt5_auto\BWDOOS_MT4_REVIVAL2.csv"
$log = "D:\EA_LAB\_mt5_auto\lane1_revival2_070707.log"
'"ea","symbol","full_pf","full_trades","full_net","full_dd_pct","note"' | Out-File $out -Encoding utf8

$deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
  $z = Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' }
  if (-not $z) { break }
  Start-Sleep -Seconds 15
}
Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' } |
  ForEach-Object { "[preflight] killing leftover terminal PID $($_.Id)" | Tee-Object $log -Append; Stop-Process -Id $_.Id -Force -Confirm:$false }

function Run-Gate {
  param([string]$Ea, [string]$SetFile, [int]$Spread, [int]$Model, [string]$Rep, [string]$Note)
  "[$(Get-Date -Format s)] $Ea ($Note)" | Tee-Object $log -Append
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert $Ea -Symbol EURUSD -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model $Model -Spread $Spread -SetFile $SetFile -ReportName $Rep -TimeoutSec 1800 | Tee-Object $log -Append
  $htm = "D:\EA_LAB\_mt4_auto\reports\$Rep.htm"
  if (-not (Test-Path $htm)) { "`"$Ea`",`"EURUSD`",,,,,NO_REPORT-$Note" | Add-Content $out; return }
  try {
    $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
    "`"$Ea`",`"EURUSD`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct),$Note" | Add-Content $out
  } catch { "`"$Ea`",`"EURUSD`",,,,,PARSE_ERR-$Note" | Add-Content $out }
}

Run-Gate -Ea "swb grid 4.1.0.3_h" -SetFile "$sets\swb_flat.set" -Spread 30 -Model 1 -Rep "REV2_swb_SPR30" -Note "FLAT-SPR30"
Run-Gate -Ea "Yetti3+NewsSherry" -SetFile "$sets\Yetti3_noboost.set" -Spread 30 -Model 1 -Rep "REV2_Yetti3_SPR30" -Note "NOBOOST-SPR30"
Run-Gate -Ea "swb grid 4.1.0.3_h" -SetFile "$sets\swb_flat.set" -Spread 0 -Model 0 -Rep "REV2_swb_M0" -Note "FLAT-M0"
Run-Gate -Ea "Yetti3+NewsSherry" -SetFile "$sets\Yetti3_noboost.set" -Spread 0 -Model 0 -Rep "REV2_Yetti3_M0" -Note "NOBOOST-M0"

"[$(Get-Date -Format s)] revival stage-2 DONE -> $out" | Tee-Object $log -Append
