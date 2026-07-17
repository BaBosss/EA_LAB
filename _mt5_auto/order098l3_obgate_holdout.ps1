<#
order098l3_obgate_holdout.ps1 - OB-gate holdout decider (ORDER-098-L3).
Candidate holdout = 2026H1 (never used to select; base Model-4 got 1.14). Does OB gate's
both-window lift hold on unseen data? obOFF vs obON, EURUSD H1, 2026.01.01-2026.07.01. Model 1.
#>
$ErrorActionPreference="Stop"
$auto="D:\EA_LAB\_mt5_auto"; $setDir="$auto\ab_sets\order098l"; $repDir="$auto\reports"; $CsvPath="$auto\order098l3_obgate_holdout.csv"
. D:\EA_LAB\scripts\use_python.ps1
$runs=@(
  @{tag="obOFF"; set="$setDir\cand_obOFF.set"}
  @{tag="obON";  set="$setDir\cand_obON.set"}
)
"gate,window,PF,trades,winpct,eqDDpct,netprofit,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($r in $runs){
  $name="O098L3_$($r.tag)_HLD"
  Write-Output "=== RUN: $name ==="
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","EmaStoRev_OB","-Symbol","EURUSD","-Period","H1","-Model","1","-FromDate","2026.01.01","-ToDate","2026.07.01","-ReportName",$name,"-SetFile",$r.set,"-TimeoutSec","900")
  $out=& powershell $a 2>&1 | Out-String; Write-Output $out
  $status=if($out -match "OK REPORT"){"OK"}else{"ERROR"}
  $rep="$repDir\$name.htm"; $PF="";$T="";$W="";$DD="";$NP=""
  if($status -eq "OK" -and (Test-Path $rep)){
    try{ $obj=(python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json | Out-String)|ConvertFrom-Json
      $PF=$obj.profit_factor;$T=$obj.total_trades;$W=$obj.profit_trades_pct;$DD=$obj.equity_drawdown_relative_pct;$NP=$obj.net_profit
    }catch{Write-Output "PARSE ERR";$status="ERROR"}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7}' -f $r.tag,"HLD",$PF,$T,$W,$DD,$NP,$rep
  Add-Content -Path $CsvPath -Value $row; Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
