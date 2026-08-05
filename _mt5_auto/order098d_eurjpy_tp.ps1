<#
order098d_eurjpy_tp.ps1 - CurrStrength_Naked EURJPY TP-widen sweep (Model 1).
Matrix: {H1,H4} x {default(TP3),tp4(RR2.0),tp6(RR3.0)} x {MAIN,BWD} = 12 runs.
Foreground/synchronous. Appends rows to order098d_currstrength.csv.
#>
$ErrorActionPreference = "Stop"
$auto = "D:\EA_LAB\_mt5_auto"
$CsvPath = "$auto\order098d_currstrength.csv"
$setDir = "$auto\ab_sets\order098d"

. D:\EA_LAB\scripts\use_python.ps1

$MAIN_FROM = "2023.01.01"; $MAIN_TO = "2026.01.01"
$BWD_FROM  = "2021.01.01"; $BWD_TO  = "2023.01.01"

$exits = @(
  @{tag="def"; rr="1.5"; set=""},
  @{tag="tp4"; rr="2.0"; set="$setDir\tp4.set"},
  @{tag="tp6"; rr="3.0"; set="$setDir\tp6.set"}
)

$runs = @()
foreach ($tf in @("H1","H4")) {
  foreach ($e in $exits) {
    $runs += @{name="O098D_EURJPY_${tf}_MAIN_$($e.tag)"; tf=$tf; win="MAIN"; from=$MAIN_FROM; to=$MAIN_TO; set=$e.set; rr=$e.rr}
    $runs += @{name="O098D_EURJPY_${tf}_BWD_$($e.tag)";  tf=$tf; win="BWD";  from=$BWD_FROM;  to=$BWD_TO;  set=$e.set; rr=$e.rr}
  }
}

if (-not (Test-Path $CsvPath)) {
  "symbol,tf,window,threshold,PF,trades,winpct,ddpct,report" | Out-File -FilePath $CsvPath -Encoding utf8
}

foreach ($r in $runs) {
  Write-Output "=== RUN: $($r.name) ==="
  $args = @("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","CurrStrength_Naked","-Symbol","EURJPY","-Period",$r.tf,"-Model","1","-FromDate",$r.from,"-ToDate",$r.to,"-ReportName",$r.name,"-TimeoutSec","900")
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
  $row = '{0},{1},{2},{3},{4},{5},{6},{7},{8}' -f "EURJPY",$r.tf,"$($r.win)_$($r.rr)",$r.rr,$PF,$Trades,$Win,$DD,$reportPath
  Add-Content -Path $CsvPath -Value $row
  Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
