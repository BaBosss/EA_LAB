<#
order098h_optimize.ps1 - PairSpread_StatArb edge-thickening (ORDER-098-H).
Base: H4 EURUSD/GBPUSD EntryZ 2.5 ZWindow 100. Two unexplored levers:
  (1) ExitZ 0.3 FRESH validation (neighbors 0.2/0.4 + cross EntryZ 2.0) -- x03 looked best in plateau map
  (2) StopZ cage sweep {2.5,3.0,4.0} at ExitZ 0.3 -- never swept before
  (3) holdout 2017-2019 at ExitZ 0.3
MAIN 2023.01.01->2026.01.01 ; BWD 2020.01.01->2022.12.31 ; HOLDOUT 2017.01.01->2019.12.31.
Foreground/synchronous. Model 1. (ExitZ 0.3 / StopZ 3.5 base already covered by O098G_x03_*.)
#>
$ErrorActionPreference = "Stop"
$auto   = "D:\EA_LAB\_mt5_auto"
$CsvPath = "$auto\order098h_optimize.csv"
$setDir = "$auto\ab_sets\order098h"
$repDir = "$auto\reports"
New-Item -ItemType Directory -Force -Path $setDir | Out-Null
. D:\EA_LAB\scripts\use_python.ps1

$MAIN_FROM="2023.01.01"; $MAIN_TO="2026.01.01"
$BWD_FROM="2020.01.01";  $BWD_TO="2022.12.31"
$HLD_FROM="2017.01.01";  $HLD_TO="2019.12.31"

function New-Set($name, [hashtable]$kv){
  $path = "$setDir\$name.set"
  $lines = foreach($k in $kv.Keys){ "$k=$($kv[$k])" }
  Set-Content -Path $path -Value $lines -Encoding ascii
  return $path
}
# base = EntryZ2.5 ExitZ0.3 ZWin100 StopZ3.5
$configs = @(
  # ExitZ neighbors (fresh validate x03 is not a lone spike)
  @{tag="x02";      kv=@{"_01_EntryZ"="2.5"; "_01_ExitZ"="0.2"; "_01_ZWindow"="100"; "_01_StopZ"="3.5"}; win="both"}
  @{tag="x04";      kv=@{"_01_EntryZ"="2.5"; "_01_ExitZ"="0.4"; "_01_ZWindow"="100"; "_01_StopZ"="3.5"}; win="both"}
  # cross ExitZ0.3 with EntryZ2.0 (best entry axis)
  @{tag="e20x03";   kv=@{"_01_EntryZ"="2.0"; "_01_ExitZ"="0.3"; "_01_ZWindow"="100"; "_01_StopZ"="3.5"}; win="both"}
  # StopZ cage sweep at ExitZ0.3 (unswept lever)
  @{tag="s25";      kv=@{"_01_EntryZ"="2.5"; "_01_ExitZ"="0.3"; "_01_ZWindow"="100"; "_01_StopZ"="2.5"}; win="both"}
  @{tag="s30";      kv=@{"_01_EntryZ"="2.5"; "_01_ExitZ"="0.3"; "_01_ZWindow"="100"; "_01_StopZ"="3.0"}; win="both"}
  @{tag="s40";      kv=@{"_01_EntryZ"="2.5"; "_01_ExitZ"="0.3"; "_01_ZWindow"="100"; "_01_StopZ"="4.0"}; win="both"}
  # holdout at ExitZ0.3 base
  @{tag="x03_HLD";  kv=@{"_01_EntryZ"="2.5"; "_01_ExitZ"="0.3"; "_01_ZWindow"="100"; "_01_StopZ"="3.5"}; win="hld"}
)

$runs = @()
foreach($c in $configs){
  $setp = New-Set "h_$($c.tag)" $c.kv
  if($c.win -eq "both"){
    foreach($w in @("MAIN","BWD")){
      $from = if($w -eq "MAIN"){$MAIN_FROM}else{$BWD_FROM}
      $to   = if($w -eq "MAIN"){$MAIN_TO}else{$BWD_TO}
      $runs += @{name="O098H_$($c.tag)_$w"; win=$w; from=$from; to=$to; set=$setp}
    }
  } else {
    $runs += @{name="O098H_$($c.tag)"; win="HLD"; from=$HLD_FROM; to=$HLD_TO; set=$setp}
  }
}

"tag,window,PF,trades,winpct,eqDDpct,netprofit,largestWin,largestLoss,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($r in $runs){
  Write-Output "=== RUN: $($r.name) ==="
  $a = @("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","PairSpread_StatArb","-Symbol","EURUSD","-Period","H4","-Model","1","-FromDate",$r.from,"-ToDate",$r.to,"-ReportName",$r.name,"-SetFile",$r.set,"-TimeoutSec","900")
  $out = & powershell $a 2>&1 | Out-String
  Write-Output $out
  $status="ERROR"
  if($out -match "OK REPORT"){ $status="OK" }
  elseif($out -match "ABORT: MT5 instance"){
    Start-Sleep -Seconds 30
    $out2 = & powershell $a 2>&1 | Out-String; Write-Output $out2
    if($out2 -match "OK REPORT"){ $status="OK" }
  }
  $rep="$repDir\$($r.name).htm"
  $PF="";$T="";$W="";$DD="";$NP="";$LW="";$LL=""
  if($status -eq "OK" -and (Test-Path $rep)){
    try{
      $obj = (python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json | Out-String) | ConvertFrom-Json
      $PF=$obj.profit_factor; $T=$obj.total_trades; $W=$obj.profit_trades_pct
      $DD=$obj.equity_drawdown_relative_pct; $NP=$obj.net_profit
      $LW=$obj.largest_profit_trade; $LL=$obj.largest_loss_trade
    } catch { Write-Output "PARSE ERR: $($_.Exception.Message)"; $status="ERROR" }
  }
  $tagcol = ($r.name -replace "^O098H_","")
  $row = '{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}' -f $tagcol,$r.win,$PF,$T,$W,$DD,$NP,$LW,$LL,$rep
  Add-Content -Path $CsvPath -Value $row
  Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
