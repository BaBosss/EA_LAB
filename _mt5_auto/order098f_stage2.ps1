<#
order098f_stage2.ps1 - PairSpread_StatArb Stage-2 funnel (Model 1).
EntryZ sweep EURUSD/GBPUSD (chart EURUSD) + second pair AUDUSD/NZDUSD (chart AUDUSD).
MAIN 2023.01.01->2026.01.01 ; BWD 2020.01.01->2022.12.31. Foreground/synchronous.
#>
$ErrorActionPreference = "Stop"
$auto = "D:\EA_LAB\_mt5_auto"
$CsvPath = "$auto\order098f_statarb.csv"
$setDir = "$auto\ab_sets\order098f"

. D:\EA_LAB\scripts\use_python.ps1

$MAIN_FROM="2023.01.01"; $MAIN_TO="2026.01.01"
$BWD_FROM="2020.01.01";  $BWD_TO="2022.12.31"

$runs = @()
# EURUSD/GBPUSD entryZ sweep, chart EURUSD
foreach($w in @("MAIN","BWD")){
  $from = if($w -eq "MAIN"){$MAIN_FROM}else{$BWD_FROM}
  $to   = if($w -eq "MAIN"){$MAIN_TO}else{$BWD_TO}
  $runs += @{name="O098F_EU_z20_$w"; pair="EURUSD/GBPUSD"; sym="EURUSD"; z="2.0"; win=$w; from=$from; to=$to; set=""}
  $runs += @{name="O098F_EU_z15_$w"; pair="EURUSD/GBPUSD"; sym="EURUSD"; z="1.5"; win=$w; from=$from; to=$to; set="$setDir\z15.set"}
  $runs += @{name="O098F_EU_z25_$w"; pair="EURUSD/GBPUSD"; sym="EURUSD"; z="2.5"; win=$w; from=$from; to=$to; set="$setDir\z25.set"}
}
# AUDUSD/NZDUSD default z2.0, chart AUDUSD
foreach($w in @("MAIN","BWD")){
  $from = if($w -eq "MAIN"){$MAIN_FROM}else{$BWD_FROM}
  $to   = if($w -eq "MAIN"){$MAIN_TO}else{$BWD_TO}
  $runs += @{name="O098F_AN_z20_$w"; pair="AUDUSD/NZDUSD"; sym="AUDUSD"; z="2.0"; win=$w; from=$from; to=$to; set="$setDir\audnzd.set"}
}

"pair,chart,entryZ,window,PF,trades,winpct,eqDDpct,netprofit,largestWin,largestLoss,report" | Out-File -FilePath $CsvPath -Encoding utf8

foreach($r in $runs){
  Write-Output "=== RUN: $($r.name) ==="
  $a = @("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","PairSpread_StatArb","-Symbol",$r.sym,"-Period","H1","-Model","1","-FromDate",$r.from,"-ToDate",$r.to,"-ReportName",$r.name,"-TimeoutSec","900")
  if($r.set -ne ""){ $a += @("-SetFile",$r.set) }
  $out = & powershell $a 2>&1 | Out-String
  Write-Output $out
  $status="ERROR"
  if($out -match "OK REPORT"){ $status="OK" }
  elseif($out -match "ABORT: MT5 instance"){
    Start-Sleep -Seconds 30
    $out2 = & powershell $a 2>&1 | Out-String; Write-Output $out2
    if($out2 -match "OK REPORT"){ $status="OK" }
  }
  $rep="$auto\reports\$($r.name).htm"
  $PF="";$T="";$W="";$DD="";$NP="";$LW="";$LL=""
  if($status -eq "OK" -and (Test-Path $rep)){
    try{
      $obj = (python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json | Out-String) | ConvertFrom-Json
      $PF=$obj.profit_factor; $T=$obj.total_trades; $W=$obj.profit_trades_pct
      $DD=$obj.equity_drawdown_relative_pct; $NP=$obj.net_profit
      $LW=$obj.largest_profit_trade; $LL=$obj.largest_loss_trade
    } catch { Write-Output "PARSE ERR: $($_.Exception.Message)"; $status="ERROR" }
  }
  $row = '{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11}' -f $r.pair,$r.sym,$r.z,$r.win,$PF,$T,$W,$DD,$NP,$LW,$LL,$rep
  Add-Content -Path $CsvPath -Value $row
  Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
