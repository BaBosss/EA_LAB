<#
order098l_obgate.ps1 - EmaStoRev_OB: OB-gate delta test (ORDER-098-L).
Confirmed SMC×STO EURUSD H1 candidate (top1 ADX config). Compare OB-gate OFF vs ON, both-window.
OFF must ~reproduce Stage-0 baseline; ON must RAISE PF+win% with sane trades (>=60/win) to be worth it.
Model 1 (STO cross + BE not bar-open-pure).
#>
$ErrorActionPreference="Stop"
$auto="D:\EA_LAB\_mt5_auto"; $setDir="$auto\ab_sets\order098l"; $repDir="$auto\reports"; $CsvPath="$auto\order098l_obgate.csv"
. D:\EA_LAB\scripts\use_python.ps1
$runs=@(
  @{tag="obOFF"; set="$setDir\base_obOFF.set"; win="MAIN"; from="2023.01.01"; to="2026.01.01"}
  @{tag="obOFF"; set="$setDir\base_obOFF.set"; win="BWD";  from="2020.01.01"; to="2022.12.31"}
  @{tag="obON";  set="$setDir\base_obON.set";  win="MAIN"; from="2023.01.01"; to="2026.01.01"}
  @{tag="obON";  set="$setDir\base_obON.set";  win="BWD";  from="2020.01.01"; to="2022.12.31"}
)
"gate,window,PF,trades,winpct,eqDDpct,netprofit,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($r in $runs){
  $name="O098L_$($r.tag)_$($r.win)"
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
