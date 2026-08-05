<#
order098d_runner.ps1 - CurrStrength_Naked multi-symbol matrix (Model 1, defaults).
Core: {EURJPY,GBPJPY,EURGBP} x H1 x {MAIN,BWD} = 6 runs.
Extra: EURJPY H1 threshold {0.005,0.020} x {MAIN,BWD} = 4 runs.
Foreground/synchronous. Appends rows to order098d_currstrength.csv.
#>
$ErrorActionPreference = "Stop"
$auto = "D:\EA_LAB\_mt5_auto"
$CsvPath = "$auto\order098d_currstrength.csv"
$setDir = "$auto\ab_sets\order098d"
New-Item -ItemType Directory -Force $setDir | Out-Null

. D:\EA_LAB\scripts\use_python.ps1

$MAIN_FROM = "2023.01.01"; $MAIN_TO = "2026.01.01"
$BWD_FROM  = "2021.01.01"; $BWD_TO  = "2023.01.01"

# threshold .set files
$thrSets = @{}
foreach ($t in @("0.005","0.020")) {
  $f = "$setDir\thr_$t.set"
  "_01_EntryThreshold=$t" | Out-File -FilePath $f -Encoding ascii
  $thrSets[$t] = $f
}

$runs = @()
foreach ($sym in @("EURJPY","GBPJPY","EURGBP")) {
  $runs += @{name="O098D_${sym}_H1_MAIN"; sym=$sym; tf="H1"; win="MAIN"; from=$MAIN_FROM; to=$MAIN_TO; set=""; thr="0.010"}
  $runs += @{name="O098D_${sym}_H1_BWD";  sym=$sym; tf="H1"; win="BWD";  from=$BWD_FROM;  to=$BWD_TO;  set=""; thr="0.010"}
}
foreach ($t in @("0.005","0.020")) {
  $tag = $t.Replace(".","")
  $runs += @{name="O098D_EURJPY_H1_MAIN_thr$tag"; sym="EURJPY"; tf="H1"; win="MAIN"; from=$MAIN_FROM; to=$MAIN_TO; set=$thrSets[$t]; thr=$t}
  $runs += @{name="O098D_EURJPY_H1_BWD_thr$tag";  sym="EURJPY"; tf="H1"; win="BWD";  from=$BWD_FROM;  to=$BWD_TO;  set=$thrSets[$t]; thr=$t}
}

if (-not (Test-Path $CsvPath)) {
  "symbol,tf,window,threshold,PF,trades,winpct,ddpct,report" | Out-File -FilePath $CsvPath -Encoding utf8
}

foreach ($r in $runs) {
  Write-Output "=== RUN: $($r.name) ==="
  $args = @("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","CurrStrength_Naked","-Symbol",$r.sym,"-Period",$r.tf,"-Model","1","-FromDate",$r.from,"-ToDate",$r.to,"-ReportName",$r.name,"-TimeoutSec","900")
  if ($r.set -ne "") { $args += @("-SetFile",$r.set) }
  $out = & powershell $args 2>&1 | Out-String
  Write-Output $out
  $status = "ERROR"
  if ($out -match "OK REPORT") { $status = "OK" }
  elseif ($out -match "TIMEOUT") { $status = "TIMEOUT" }
  elseif ($out -match "ABORT: MT5 instance") {
    Write-Output "BUSY - waiting 30s, retry once..."
    Start-Sleep -Seconds 30
    $out2 = & powershell $args 2>&1 | Out-String
    Write-Output $out2
    if ($out2 -match "OK REPORT") { $status = "OK" }
  }
  $reportPath = "$auto\reports\$($r.name).htm"
  $PF=""; $Trades=""; $DD=""; $Win=""
  if ($status -eq "OK" -and (Test-Path $reportPath)) {
    try {
      $j = python D:\EA_LAB\scripts\parse_mt5_report.py $reportPath --json | Out-String
      $obj = $j | ConvertFrom-Json
      $PF = $obj.profit_factor; $Trades = $obj.total_trades
      $DD = $obj.equity_drawdown_relative_pct; $Win = $obj.profit_trades_pct
    } catch { Write-Output "PARSE ERROR $($r.name): $($_.Exception.Message)"; $status="ERROR" }
  }
  $row = '{0},{1},{2},{3},{4},{5},{6},{7},{8}' -f $r.sym,$r.tf,$r.win,$r.thr,$PF,$Trades,$Win,$DD,$reportPath
  Add-Content -Path $CsvPath -Value $row
  Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
