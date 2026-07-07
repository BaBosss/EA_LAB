# ORDER-046 revival probes, 2026-07-07 ค่ำ — กฎ user "ห้าม DEAD ก่อนลอง optimize" applied
# to the ONLY cases where a single structural input closes the known kill-cause
# (NOT parameter tuning — each probe = one flip, then the SAME full gate chain re-judges):
#   1. FZ2 (killed: ladder x18.6) -> multiplier=0 + MM=0  == convert to the exact config
#      class of UnNomGuai (same engine, already passed everything). CANARY for -SetFile
#      mechanism: if ladder still x18.6 in the new report, the .set did NOT apply.
#   2. UnNomGuai cap probe: space3Orders 99->20. Historically never >9 concurrent, so
#      result should be IDENTICAL to baseline (PF 1.89/3640trd/+8527) == free tail-risk
#      close for the demo config. If numbers differ, the cap binds somewhere - judge.
#   3. swb grid (killed: ladder x25.9 + DD52): lot_multiplier=0 -> flat 0.1 BB+Stoch+RSI grid
#   4. Yetti3+NewsSherry (killed: spread PF 1.25->0.97): Boost=1.0 (kill martingale boost)
#      - weakest case, last in queue
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$src_base = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$dd_experts = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$sets = "D:\EA_LAB\_mt5_auto\ab_sets"
$out = "D:\EA_LAB\_mt5_auto\BWDOOS_MT4_REVIVAL.csv"
$log = "D:\EA_LAB\_mt5_auto\lane1_revival_070707.log"
'"ea","symbol","full_pf","full_trades","full_net","full_dd_pct","note"' | Out-File $out -Encoding utf8

$deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
  $z = Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' }
  if (-not $z) { break }
  Start-Sleep -Seconds 15
}
Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' } |
  ForEach-Object { "[preflight] killing leftover terminal PID $($_.Id)" | Tee-Object $log -Append; Stop-Process -Id $_.Id -Force -Confirm:$false }

function Run-Probe {
  param([string]$Ea, [string]$RelPath, [string]$SetFile, [string]$Rep, [string]$Note)
  $dstFile = Join-Path $dd_experts "$Ea.ex4"
  if (-not (Test-Path -LiteralPath $dstFile)) {
    $srcFile = Join-Path $src_base $RelPath
    if (Test-Path -LiteralPath $srcFile) { Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force }
    else { "`"$Ea`",`"EURUSD`",,,,,SRC_MISSING" | Add-Content $out; return }
  }
  "[$(Get-Date -Format s)] $Ea probe ($Note)" | Tee-Object $log -Append
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert $Ea -Symbol EURUSD -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 1 -SetFile $SetFile -ReportName $Rep -TimeoutSec 1800 | Tee-Object $log -Append
  $htm = "D:\EA_LAB\_mt4_auto\reports\$Rep.htm"
  if (-not (Test-Path $htm)) { "`"$Ea`",`"EURUSD`",,,,,NO_REPORT-$Note" | Add-Content $out; return }
  try {
    $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
    "`"$Ea`",`"EURUSD`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct),$Note" | Add-Content $out
  } catch { "`"$Ea`",`"EURUSD`",,,,,PARSE_ERR-$Note" | Add-Content $out }
  # free lot-check straight away so the verdict evidence is in the log
  powershell -File D:\EA_LAB\scripts\mt4_lotcheck.ps1 -Report $htm | Tee-Object $log -Append
}

Run-Probe -Ea "FZ2" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\FZ2.ex4" -SetFile "$sets\FZ2_flat.set" -Rep "REV_FZ2_EURUSD_flat" -Note "PROBE-mult0-MM0"
Run-Probe -Ea "UnNomGuaiV1.132" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\UnNomGuaiV1.132.ex4" -SetFile "$sets\UnNomGuai_cap20.set" -Rep "REV_UnNomGuai_EURUSD_cap20" -Note "PROBE-cap20-expect-identical"
Run-Probe -Ea "swb grid 4.1.0.3_h" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\swb grid 4.1.0.3_h.ex4" -SetFile "$sets\swb_flat.set" -Rep "REV_swb_grid_EURUSD_flat" -Note "PROBE-flatlot"
Run-Probe -Ea "Yetti3+NewsSherry" -RelPath "2024-06\Yetti3+NewsSherry\Yetti3+NewsSherry.ex4" -SetFile "$sets\Yetti3_noboost.set" -Rep "REV_Yetti3_EURUSD_noboost" -Note "PROBE-boost1"

"[$(Get-Date -Format s)] revival probes DONE -> $out" | Tee-Object $log -Append
