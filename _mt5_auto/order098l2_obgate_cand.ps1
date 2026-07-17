<#
order098l2_obgate_cand.ps1 - OB-gate delta on the TRUE both-window candidate (ORDER-098-L2).
Candidate: StoK13/OS30/OB80/AdxMax30/SL3.0/TP1/EMA50 (verdict = MAIN 1.50 / BWD 1.24, ~130t).
Compare OB OFF vs ON, both-window. Model 1. Acceptance: OB must raise PF AND keep >=60t/window.
#>
$ErrorActionPreference="Stop"
$auto="D:\EA_LAB\_mt5_auto"; $setDir="$auto\ab_sets\order098l"; $repDir="$auto\reports"; $CsvPath="$auto\order098l2_obgate_cand.csv"
. D:\EA_LAB\scripts\use_python.ps1
$runs=@(
  @{tag="obOFF"; set="$setDir\cand_obOFF.set"; win="MAIN"; from="2023.01.01"; to="2026.01.01"}
  @{tag="obOFF"; set="$setDir\cand_obOFF.set"; win="BWD";  from="2020.01.01"; to="2022.12.31"}
  @{tag="obON";  set="$setDir\cand_obON.set";  win="MAIN"; from="2023.01.01"; to="2026.01.01"}
  @{tag="obON";  set="$setDir\cand_obON.set";  win="BWD";  from="2020.01.01"; to="2022.12.31"}
)
"gate,window,PF,trades,winpct,eqDDpct,netprofit,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($r in $runs){
  $name="O098L2_$($r.tag)_$($r.win)"
  Write-Output "=== RUN: $name ==="
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","EmaStoRev_OB","-Symbol","EURUSD","-Period","H1","-Model","1","-FromDate",$r.from,"-ToDate",$r.to,"-ReportName",$name,"-SetFile",$r.set,"-TimeoutSec","900")
  $out=& powershell $a 2>&1 | Out-String; Write-Output $out
  $status=if($out -match "OK REPORT"){"OK"}else{"ERROR"}
  $rep="$repDir\$name.htm"; $PF="";$T="";$W="";$DD="";$NP=""
  if($status -eq "OK" -and (Test-Path $rep)){
    try{ $obj=(python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json | Out-String)|ConvertFrom-Json
      $PF=$obj.profit_factor;$T=$obj.total_trades;$W=$obj.profit_trades_pct;$DD=$obj.equity_drawdown_relative_pct;$NP=$obj.net_profit
    }catch{Write-Output "PARSE ERR";$status="ERROR"}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7}' -f $r.tag,$r.win,$PF,$T,$W,$DD,$NP,$rep
  Add-Content -Path $CsvPath -Value $row; Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
