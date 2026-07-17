<#
order098j4_fib_holdout.ps1 - FibPullback XAU H1 holdout decider (ORDER-098-J4).
Probe found H1 TP1.5R both-window >1.1 (p3850_rr15 1.43/1.19, p3862_rr15 1.42/1.12). Decide
selection-fit vs real: run HOLDOUT 2017-2019 (never used to select) on the 2 best configs. Model 1.
#>
$ErrorActionPreference="Stop"
$auto="D:\EA_LAB\_mt5_auto"; $setDir="$auto\ab_sets\order098j"; $repDir="$auto\reports"
$CsvPath="$auto\order098j4_fib_holdout.csv"
. D:\EA_LAB\scripts\use_python.ps1
$configs=@(
  @{tag="p3850_rr15"; set="$setDir\fib_p3850_rr15.set"}
  @{tag="p3862_rr15"; set="$setDir\fib_p3862_rr15.set"}
)
"tag,window,PF,trades,winpct,eqDDpct,netprofit,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($c in $configs){
  $name="O098J4_$($c.tag)_HLD"
  Write-Output "=== RUN: $name ==="
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","FibPullback_Naked","-Symbol","XAUUSD","-Period","H1","-Model","1","-FromDate","2017.01.01","-ToDate","2019.12.31","-ReportName",$name,"-SetFile",$c.set,"-TimeoutSec","900")
  $out=& powershell $a 2>&1 | Out-String; Write-Output $out
  $status=if($out -match "OK REPORT"){"OK"}else{"ERROR"}
  $rep="$repDir\$name.htm"; $PF="";$T="";$W="";$DD="";$NP=""
  if($status -eq "OK" -and (Test-Path $rep)){
    try{ $obj=(python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json | Out-String)|ConvertFrom-Json
      $PF=$obj.profit_factor;$T=$obj.total_trades;$W=$obj.profit_trades_pct;$DD=$obj.equity_drawdown_relative_pct;$NP=$obj.net_profit
    }catch{Write-Output "PARSE ERR";$status="ERROR"}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7}' -f $c.tag,"HLD",$PF,$T,$W,$DD,$NP,$rep
  Add-Content -Path $CsvPath -Value $row; Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
