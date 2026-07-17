<#
order098g_validate.ps1 - PairSpread_StatArb ROBUSTNESS funnel (ORDER-098-G).
Candidate: H4 EURUSD/GBPUSD EntryZ 2.5 ExitZ 0.5 ZWindow 100 (StopZ 3.5).
OFAT plateau map around center + holdout window + cross-pair generalization.
MAIN 2023.01.01->2026.01.01 ; BWD 2020.01.01->2022.12.31 ; HOLDOUT 2017.01.01->2019.12.31.
Foreground/synchronous. Model 1.
#>
$ErrorActionPreference = "Stop"
$auto   = "D:\EA_LAB\_mt5_auto"
$CsvPath = "$auto\order098g_validate.csv"
$setDir = "$auto\ab_sets\order098g"
$repDir = "$auto\reports"
New-Item -ItemType Directory -Force -Path $setDir | Out-Null

. D:\EA_LAB\scripts\use_python.ps1

$MAIN_FROM="2023.01.01"; $MAIN_TO="2026.01.01"
$BWD_FROM="2020.01.01";  $BWD_TO="2022.12.31"
$HLD_FROM="2017.01.01";  $HLD_TO="2019.12.31"

# --- generate .set files (KEY=VALUE overrides on top of EA defaults) ---
function New-Set($name, [hashtable]$kv){
  $path = "$setDir\$name.set"
  $lines = foreach($k in $kv.Keys){ "$k=$($kv[$k])" }
  Set-Content -Path $path -Value $lines -Encoding ascii
  return $path
}
# center = EntryZ2.5 ExitZ0.5 ZWin100 (EURUSD/GBPUSD)
$C = @{ "_01_EntryZ"="2.5"; "_01_ExitZ"="0.5"; "_01_ZWindow"="100" }
# OFAT plateau configs (vary one axis, hold others at center)
$plateau = @(
  @{tag="e20";  sym="EURUSD"; kv=@{"_01_EntryZ"="2.0"; "_01_ExitZ"="0.5"; "_01_ZWindow"="100"}}
  @{tag="e225"; sym="EURUSD"; kv=@{"_01_EntryZ"="2.25";"_01_ExitZ"="0.5"; "_01_ZWindow"="100"}}
  @{tag="e25";  sym="EURUSD"; kv=$C}   # center
  @{tag="e275"; sym="EURUSD"; kv=@{"_01_EntryZ"="2.75";"_01_ExitZ"="0.5"; "_01_ZWindow"="100"}}
  @{tag="x03";  sym="EURUSD"; kv=@{"_01_EntryZ"="2.5"; "_01_ExitZ"="0.3"; "_01_ZWindow"="100"}}
  @{tag="x07";  sym="EURUSD"; kv=@{"_01_EntryZ"="2.5"; "_01_ExitZ"="0.7"; "_01_ZWindow"="100"}}
  @{tag="w80";  sym="EURUSD"; kv=@{"_01_EntryZ"="2.5"; "_01_ExitZ"="0.5"; "_01_ZWindow"="80"}}
  @{tag="w120"; sym="EURUSD"; kv=@{"_01_EntryZ"="2.5"; "_01_ExitZ"="0.5"; "_01_ZWindow"="120"}}
)
# cross-pair at center z2.5 (chart symbol = SymbolA)
$crosspair = @(
  @{tag="cp_gu";  sym="GBPUSD"; kv=@{"_01_SymbolA"="GBPUSD"; "_01_SymbolB"="EURUSD"; "_01_EntryZ"="2.5"; "_01_ExitZ"="0.5"; "_01_ZWindow"="100"}}
  @{tag="cp_chf"; sym="EURCHF"; kv=@{"_01_SymbolA"="EURCHF"; "_01_SymbolB"="USDCHF"; "_01_EntryZ"="2.5"; "_01_ExitZ"="0.5"; "_01_ZWindow"="100"}}
)

# --- build run list ---
$runs = @()
# plateau: both windows
foreach($p in $plateau){
  $setp = New-Set "g_$($p.tag)" $p.kv
  foreach($w in @("MAIN","BWD")){
    $from = if($w -eq "MAIN"){$MAIN_FROM}else{$BWD_FROM}
    $to   = if($w -eq "MAIN"){$MAIN_TO}else{$BWD_TO}
    $runs += @{name="O098G_$($p.tag)_$w"; sym=$p.sym; win=$w; from=$from; to=$to; set=$setp; grp="plateau"}
  }
}
# holdout: center config only
$setC = "$setDir\g_e25.set"
$runs += @{name="O098G_e25_HLD"; sym="EURUSD"; win="HLD"; from=$HLD_FROM; to=$HLD_TO; set=$setC; grp="holdout"}
# cross-pair: both windows
foreach($p in $crosspair){
  $setp = New-Set "g_$($p.tag)" $p.kv
  foreach($w in @("MAIN","BWD")){
    $from = if($w -eq "MAIN"){$MAIN_FROM}else{$BWD_FROM}
    $to   = if($w -eq "MAIN"){$MAIN_TO}else{$BWD_TO}
    $runs += @{name="O098G_$($p.tag)_$w"; sym=$p.sym; win=$w; from=$from; to=$to; set=$setp; grp="crosspair"}
  }
}

"grp,tag,chart,window,PF,trades,winpct,eqDDpct,netprofit,largestWin,largestLoss,report" | Out-File -FilePath $CsvPath -Encoding utf8

foreach($r in $runs){
  Write-Output "=== RUN: $($r.name) ==="
  $a = @("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","PairSpread_StatArb","-Symbol",$r.sym,"-Period","H4","-Model","1","-FromDate",$r.from,"-ToDate",$r.to,"-ReportName",$r.name,"-SetFile",$r.set,"-TimeoutSec","900")
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
  $tagcol = ($r.name -replace "^O098G_","")
  $row = '{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11}' -f $r.grp,$tagcol,$r.sym,$r.win,$PF,$T,$W,$DD,$NP,$LW,$LL,$rep
  Add-Content -Path $CsvPath -Value $row
  Write-Output "ROW: $row [$status]"
}

# --- extract trade list for the center config (MAIN) for Monte Carlo ---
$centerRep = "$repDir\O098G_e25_MAIN.htm"
$tradeCsv  = "$auto\order098g_center_trades.csv"
if(Test-Path $centerRep){
  Write-Output "=== extract center-config deals for MC ==="
  python D:\EA_LAB\scripts\extract_deals.py $centerRep -o $tradeCsv 2>&1 | Write-Output
}
Write-Output "DONE."
