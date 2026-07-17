<#
order098h2_combined.ps1 - PairSpread_StatArb combined-optimized confirm (ORDER-098-H2).
All three 098-H OFAT winners stacked: EntryZ 2.0 / ExitZ 0.3 / ZWindow 100 / StopZ 4.0.
Fresh both-window + holdout to guard against selection-fit, then extract deals for MC.
#>
$ErrorActionPreference = "Stop"
$auto="D:\EA_LAB\_mt5_auto"; $setDir="$auto\ab_sets\order098h"; $repDir="$auto\reports"
$CsvPath="$auto\order098h2_combined.csv"
. D:\EA_LAB\scripts\use_python.ps1
$setp="$setDir\h2_combined.set"
Set-Content -Path $setp -Value @("_01_EntryZ=2.0","_01_ExitZ=0.3","_01_ZWindow=100","_01_StopZ=4.0") -Encoding ascii

$runs=@(
  @{name="O098H2_comb_MAIN"; from="2023.01.01"; to="2026.01.01"; win="MAIN"}
  @{name="O098H2_comb_BWD";  from="2020.01.01"; to="2022.12.31"; win="BWD"}
  @{name="O098H2_comb_HLD";  from="2017.01.01"; to="2019.12.31"; win="HLD"}
)
"tag,window,PF,trades,winpct,eqDDpct,netprofit,largestWin,largestLoss,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($r in $runs){
  Write-Output "=== RUN: $($r.name) ==="
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","PairSpread_StatArb","-Symbol","EURUSD","-Period","H4","-Model","1","-FromDate",$r.from,"-ToDate",$r.to,"-ReportName",$r.name,"-SetFile",$setp,"-TimeoutSec","900")
  $out=& powershell $a 2>&1 | Out-String; Write-Output $out
  $status=if($out -match "OK REPORT"){"OK"}else{"ERROR"}
  $rep="$repDir\$($r.name).htm"; $PF="";$T="";$W="";$DD="";$NP="";$LW="";$LL=""
  if($status -eq "OK" -and (Test-Path $rep)){
    try{
      $obj=(python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json | Out-String)|ConvertFrom-Json
      $PF=$obj.profit_factor;$T=$obj.total_trades;$W=$obj.profit_trades_pct
      $DD=$obj.equity_drawdown_relative_pct;$NP=$obj.net_profit
      $LW=$obj.largest_profit_trade;$LL=$obj.largest_loss_trade
    }catch{Write-Output "PARSE ERR: $($_.Exception.Message)";$status="ERROR"}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}' -f ($r.name -replace "^O098H2_",""),$r.win,$PF,$T,$W,$DD,$NP,$LW,$LL,$rep
  Add-Content -Path $CsvPath -Value $row; Write-Output "ROW: $row [$status]"
}
# MC deals from combined MAIN
$cm="$repDir\O098H2_comb_MAIN.htm"
if(Test-Path $cm){ python D:\EA_LAB\scripts\extract_deals.py $cm -o "$auto\order098h2_comb_trades.csv" 2>&1 | Write-Output }
Write-Output "DONE."
