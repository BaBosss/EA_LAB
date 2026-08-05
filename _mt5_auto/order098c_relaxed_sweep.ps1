<#
order098c_relaxed_sweep.ps1 — FVGFill_RSIgate RELAXED RSI gate sweep.
8 Model-1 runs: {EURUSD,XAUUSD} x {H1} x {MAIN,BWD} x {rsi_40_60, rsi_50_50}.
Foreground/synchronous. Parses each report, appends row to order098c_rsigate_ab.csv.
#>
$ErrorActionPreference = "Stop"
$auto = "D:\EA_LAB\_mt5_auto"
$CsvPath = "$auto\order098c_rsigate_ab.csv"
$setDir = "$auto\ab_sets\order098c"

. D:\EA_LAB\scripts\use_python.ps1

$MAIN_FROM = "2023.01.01"; $MAIN_TO = "2026.01.01"
$BWD_FROM  = "2020.01.01"; $BWD_TO  = "2022.12.31"

$cells = @(
  @{sym="EURUSD"; tf="H1"},
  @{sym="XAUUSD"; tf="H1"}
)
$windows = @(
  @{w="MAIN"; from=$MAIN_FROM; to=$MAIN_TO},
  @{w="BWD";  from=$BWD_FROM;  to=$BWD_TO}
)
$thresholds = @("rsi_40_60","rsi_50_50")

$runs = @()
foreach ($c in $cells) {
  foreach ($th in $thresholds) {
    foreach ($win in $windows) {
      $runs += @{symbol=$c.sym; period=$c.tf; window=$win.w; from=$win.from; to=$win.to;
                 thr=$th; setfile="$setDir\$th.set";
                 name="O098C_$($c.sym)_$($c.tf)_$($th)_$($win.w)"}
    }
  }
}

"symbol,tf,window,threshold,PF,trades,winpct,ddpct" | Out-File -FilePath $CsvPath -Encoding utf8

foreach ($r in $runs) {
  Write-Output "=== RUN: $($r.name) ==="
  $out = & powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "FVGFill_RSIgate" -Symbol $r.symbol -Period $r.period -Model 1 -FromDate $r.from -ToDate $r.to -SetFile $r.setfile -ReportName $r.name -TimeoutSec 600 2>&1 | Out-String
  Write-Output $out

  $status = "ERROR"
  $reportPath = "$auto\reports\$($r.name).htm"
  if ($out -match "OK REPORT") { $status = "OK" }
  elseif ($out -match "TIMEOUT") { $status = "TIMEOUT" }
  elseif ($out -match "ABORT: MT5 instance") {
    Write-Output "BUSY - waiting 30s and retrying once..."
    Start-Sleep -Seconds 30
    $out2 = & powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "FVGFill_RSIgate" -Symbol $r.symbol -Period $r.period -Model 1 -FromDate $r.from -ToDate $r.to -SetFile $r.setfile -ReportName $r.name -TimeoutSec 600 2>&1 | Out-String
    Write-Output $out2
    if ($out2 -match "OK REPORT") { $status = "OK" } elseif ($out2 -match "TIMEOUT") { $status = "TIMEOUT" } else { $status = "BUSY" }
  }

  $PF=""; $Trades=""; $DD=""; $Win=""
  if ($status -eq "OK" -and (Test-Path $reportPath)) {
    try {
      $j = python D:\EA_LAB\scripts\parse_mt5_report.py $reportPath --json | Out-String
      $obj = $j | ConvertFrom-Json
      $PF = $obj.profit_factor
      $Trades = $obj.total_trades
      $DD = $obj.equity_drawdown_relative_pct
      $Win = $obj.profit_trades_pct
    } catch {
      Write-Output "PARSE ERROR for $($r.name): $($_.Exception.Message)"
      $status = "ERROR"
    }
  }

  $row = '{0},{1},{2},{3},{4},{5},{6},{7}' -f $r.symbol,$r.period,$r.window,$r.thr,$PF,$Trades,$Win,$DD
  Add-Content -Path $CsvPath -Value $row
  Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
