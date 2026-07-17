<#
order098i_macddiv_rangers.ps1 - MacdDiv_Naked on untested right-home rangers (ORDER-098-I).
098-B closed MACD-divergence on XAU (win) + EURUSD (holdout FAIL 0.35, parked). EURGBP/AUDNZD
(tighter rangers = better reversion home) never tested. Default params, full funnel MAIN/BWD/HOLDOUT.
Single-symbol EA -> chart symbol = traded symbol, no set file (validated defaults).
Model 1 (naked entry + ATR SL/TP, bar-open-ish; keep consistent with 098-B Model-1 funnel).
#>
$ErrorActionPreference = "Stop"
$auto="D:\EA_LAB\_mt5_auto"; $repDir="$auto\reports"; $CsvPath="$auto\order098i_macddiv_rangers.csv"
. D:\EA_LAB\scripts\use_python.ps1
$wins=@(
  @{win="MAIN"; from="2023.01.01"; to="2026.01.01"}
  @{win="BWD";  from="2020.01.01"; to="2022.12.31"}
  @{win="HLD";  from="2017.01.01"; to="2019.12.31"}
)
$syms=@("EURGBP","AUDNZD")
"symbol,window,PF,trades,winpct,eqDDpct,netprofit,largestWin,largestLoss,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($s in $syms){
  foreach($w in $wins){
    $name="O098I_${s}_H4_$($w.win)"
    Write-Output "=== RUN: $name ==="
    $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","MacdDiv_Naked","-Symbol",$s,"-Period","H4","-Model","1","-FromDate",$w.from,"-ToDate",$w.to,"-ReportName",$name,"-TimeoutSec","900")
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
    $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}' -f $s,$w.win,$PF,$T,$W,$DD,$NP,$LW,$LL,$rep
    Add-Content -Path $CsvPath -Value $row; Write-Output "ROW: $row [$status]"
  }
}
Write-Output "DONE."
