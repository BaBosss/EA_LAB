<#
order098k_maker.ps1 - PairSpread_StatArb_Maker funnel (ORDER-098-K).
Maker (limit) entry variant vs baseline market-entry ExitZ0.3 (MAIN 1.14 / BWD 1.15 / HLD 1.23).
Defaults already = ExitZ0.3 locked config. Model 1 (fills matter for limit orders). 3 windows + MC extract.
#>
$ErrorActionPreference="Stop"
$auto="D:\EA_LAB\_mt5_auto"; $repDir="$auto\reports"; $CsvPath="$auto\order098k_maker.csv"
. D:\EA_LAB\scripts\use_python.ps1
$runs=@(
  @{win="MAIN"; from="2023.01.01"; to="2026.01.01"}
  @{win="BWD";  from="2020.01.01"; to="2022.12.31"}
  @{win="HLD";  from="2017.01.01"; to="2019.12.31"}
)
"window,PF,trades,winpct,eqDDpct,netprofit,largestWin,largestLoss,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($r in $runs){
  $name="O098K_maker_$($r.win)"
  Write-Output "=== RUN: $name ==="
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","PairSpread_StatArb_Maker","-Symbol","EURUSD","-Period","H4","-Model","1","-FromDate",$r.from,"-ToDate",$r.to,"-ReportName",$name,"-TimeoutSec","900")
  $out=& powershell $a 2>&1 | Out-String; Write-Output $out
  $status=if($out -match "OK REPORT"){"OK"}else{"ERROR"}
  $rep="$repDir\$name.htm"; $PF="";$T="";$W="";$DD="";$NP="";$LW="";$LL=""
  if($status -eq "OK" -and (Test-Path $rep)){
    try{ $obj=(python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json | Out-String)|ConvertFrom-Json
      $PF=$obj.profit_factor;$T=$obj.total_trades;$W=$obj.profit_trades_pct;$DD=$obj.equity_drawdown_relative_pct;$NP=$obj.net_profit;$LW=$obj.largest_profit_trade;$LL=$obj.largest_loss_trade
    }catch{Write-Output "PARSE ERR";$status="ERROR"}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8}' -f $r.win,$PF,$T,$W,$DD,$NP,$LW,$LL,$rep
  Add-Content -Path $CsvPath -Value $row; Write-Output "ROW: $row [$status]"
}
$cm="$repDir\O098K_maker_MAIN.htm"
if(Test-Path $cm){ python D:\EA_LAB\scripts\extract_deals.py $cm -o "$auto\order098k_maker_trades.csv" 2>&1 | Write-Output }
Write-Output "DONE."
