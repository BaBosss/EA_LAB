<#
order098j2_fib_xau_window.ps1 - FibPullback XAU both-window + holdout (ORDER-098-J2).
Smoke MAIN(2023-26) = XAU H4 1.73 / H1 1.37. Guard against 2023-25 XAU bull-run regime artifact:
run BWD(2020-22) + HOLDOUT(2017-19) on XAU H4/H1. Model 1 (real fills; confirm not artifact).
#>
$ErrorActionPreference="Stop"
$auto="D:\EA_LAB\_mt5_auto"; $repDir="$auto\reports"; $CsvPath="$auto\order098j2_fib_xau_window.csv"
. D:\EA_LAB\scripts\use_python.ps1
$runs=@(
  @{sym="XAUUSD"; tf="H4"; win="BWD"; from="2020.01.01"; to="2022.12.31"}
  @{sym="XAUUSD"; tf="H4"; win="HLD"; from="2017.01.01"; to="2019.12.31"}
  @{sym="XAUUSD"; tf="H4"; win="MAIN_M1"; from="2023.01.01"; to="2026.01.01"}
  @{sym="XAUUSD"; tf="H1"; win="BWD"; from="2020.01.01"; to="2022.12.31"}
  @{sym="XAUUSD"; tf="H1"; win="HLD"; from="2017.01.01"; to="2019.12.31"}
  @{sym="XAUUSD"; tf="H1"; win="MAIN_M1"; from="2023.01.01"; to="2026.01.01"}
)
"symbol,tf,window,PF,trades,winpct,eqDDpct,netprofit,largestWin,largestLoss,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($r in $runs){
  $name="O098J2_$($r.sym)_$($r.tf)_$($r.win)"
  Write-Output "=== RUN: $name ==="
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","FibPullback_Naked","-Symbol",$r.sym,"-Period",$r.tf,"-Model","1","-FromDate",$r.from,"-ToDate",$r.to,"-ReportName",$name,"-TimeoutSec","900")
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
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10}' -f $r.sym,$r.tf,$r.win,$PF,$T,$W,$DD,$NP,$LW,$LL,$rep
  Add-Content -Path $CsvPath -Value $row; Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
