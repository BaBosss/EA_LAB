<#
order098j_fibpullback_smoke.ps1 - FibPullback_Naked naked smoke (ORDER-098-J).
Signal-scanner triage: Fib-retracement pullback = trend-continuation -> trenders (XAU/GBP);
add rangers (EUR/EURGBP) for the reversion-geometry interpretation. Model 2, 2023.01-2026.01, default params.
#>
$ErrorActionPreference="Stop"
$auto="D:\EA_LAB\_mt5_auto"; $repDir="$auto\reports"; $CsvPath="$auto\order098j_fibpullback_smoke.csv"
. D:\EA_LAB\scripts\use_python.ps1
$cells=@(
  @{sym="XAUUSD"; tf="H4"}
  @{sym="XAUUSD"; tf="H1"}
  @{sym="GBPUSD"; tf="H4"}
  @{sym="EURUSD"; tf="H4"}
  @{sym="EURGBP"; tf="H4"}
)
"symbol,tf,PF,trades,winpct,eqDDpct,netprofit,largestWin,largestLoss,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($c in $cells){
  $name="O098J_$($c.sym)_$($c.tf)"
  Write-Output "=== RUN: $name ==="
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","FibPullback_Naked","-Symbol",$c.sym,"-Period",$c.tf,"-Model","2","-FromDate","2023.01.01","-ToDate","2026.01.01","-ReportName",$name,"-TimeoutSec","900")
  $out=& powershell $a 2>&1 | Out-String; Write-Output $out
  $status=if($out -match "OK REPORT"){"OK"}else{"ERROR"}
  $rep="$repDir\$name.htm"; $PF="";$T="";$W="";$DD="";$NP="";$LW="";$LL=""
  if($status -eq "OK" -and (Test-Path $rep)){
    try{
      $obj=(python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json | Out-String)|ConvertFrom-Json
      $PF=$obj.profit_factor;$T=$obj.total_trades;$W=$obj.profit_trades_pct
      $DD=$obj.equity_drawdown_relative_pct;$NP=$obj.net_profit
      $LW=$obj.largest_profit_trade;$LL=$obj.largest_loss_trade
    }catch{Write-Output "PARSE ERR: $($_.Exception.Message)";$status="ERROR"}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}' -f $c.sym,$c.tf,$PF,$T,$W,$DD,$NP,$LW,$LL,$rep
  Add-Content -Path $CsvPath -Value $row; Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
