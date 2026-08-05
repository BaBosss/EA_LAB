<#
order098e_runner.ps1 - CurrStrength_Ranked portfolio ranking, exit-mode funnel (Model 1).
3 exit modes x 2 windows = 6 runs. Foreground/synchronous.
#>
$ErrorActionPreference = "Stop"
$auto = "D:\EA_LAB\_mt5_auto"
$CsvPath = "$auto\order098e_ranked.csv"
. D:\EA_LAB\scripts\use_python.ps1

$MAIN_FROM = "2023.01.01"; $MAIN_TO = "2026.01.01"
$BWD_FROM  = "2021.01.01"; $BWD_TO  = "2023.01.01"
$e1 = "$auto\ab_sets\order098e\exit1.set"
$e2 = "$auto\ab_sets\order098e\exit2.set"

$runs = @(
  @{name="O098E_FIXED_ATR_MAIN"; mode="FIXED_ATR"; win="MAIN"; from=$MAIN_FROM; to=$MAIN_TO; set=""},
  @{name="O098E_FIXED_ATR_BWD";  mode="FIXED_ATR"; win="BWD";  from=$BWD_FROM;  to=$BWD_TO;  set=""},
  @{name="O098E_TRAILING_MAIN";  mode="TRAILING";  win="MAIN"; from=$MAIN_FROM; to=$MAIN_TO; set=$e1},
  @{name="O098E_TRAILING_BWD";   mode="TRAILING";  win="BWD";  from=$BWD_FROM;  to=$BWD_TO;  set=$e1},
  @{name="O098E_PARTIAL_BE_MAIN";mode="PARTIAL_BE";win="MAIN"; from=$MAIN_FROM; to=$MAIN_TO; set=$e2},
  @{name="O098E_PARTIAL_BE_BWD"; mode="PARTIAL_BE";win="BWD";  from=$BWD_FROM;  to=$BWD_TO;  set=$e2}
)

if (-not (Test-Path $CsvPath)) {
  "exit_mode,window,PF,trades,winpct,eqddpct,report" | Out-File -FilePath $CsvPath -Encoding utf8
}

foreach ($r in $runs) {
  Write-Output "=== RUN: $($r.name) ==="
  $a = @("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","CurrStrength_Ranked","-Symbol","EURJPY","-Period","H4","-Model","1","-FromDate",$r.from,"-ToDate",$r.to,"-ReportName",$r.name,"-TimeoutSec","900")
  if ($r.set -ne "") { $a += @("-SetFile",$r.set) }
  $out = & powershell $a 2>&1 | Out-String
  Write-Output $out
  $status = "ERROR"
  if ($out -match "OK REPORT") { $status = "OK" }
  elseif ($out -match "ABORT: MT5 instance") {
    Write-Output "BUSY - waiting 30s, retry once..."
    Start-Sleep -Seconds 30
    $out2 = & powershell $a 2>&1 | Out-String
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
    } catch { Write-Output "PARSE ERROR: $($_.Exception.Message)"; $status="ERROR" }
  }
  $row = '{0},{1},{2},{3},{4},{5},{6}' -f $r.mode,$r.win,$PF,$Trades,$Win,$DD,$reportPath
  Add-Content -Path $CsvPath -Value $row
  Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
