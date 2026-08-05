<#
order098f_costdrag.ps1 - PairSpread_StatArb cost-drag hypothesis sweep (Model 1).
EURUSD/GBPUSD (chart EURUSD). H4 x {z2.5,z3.0,z30_ex0} + H1 x z3.0, both windows = 8 runs.
MAIN 2023.01.01->2026.01.01 ; BWD 2020.01.01->2022.12.31. Foreground/synchronous.
Appends to existing order098f_statarb.csv.
#>
$ErrorActionPreference = "Stop"
$auto = "D:\EA_LAB\_mt5_auto"
$CsvPath = "$auto\order098f_statarb.csv"
$setDir = "$auto\ab_sets\order098f"

$MAIN_FROM="2023.01.01"; $MAIN_TO="2026.01.01"
$BWD_FROM="2020.01.01";  $BWD_TO="2022.12.31"

$configs = @(
  @{tf="H4"; z="2.5"; set="$setDir\z25.set";     tag="z25"}
  @{tf="H4"; z="3.0"; set="$setDir\z30.set";     tag="z30"}
  @{tf="H4"; z="3.0"; set="$setDir\z30_ex0.set"; tag="z30ex0"}
  @{tf="H1"; z="3.0"; set="$setDir\z30.set";     tag="z30"}
)

$runs = @()
foreach($c in $configs){
  foreach($w in @("MAIN","BWD")){
    $from = if($w -eq "MAIN"){$MAIN_FROM}else{$BWD_FROM}
    $to   = if($w -eq "MAIN"){$MAIN_TO}else{$BWD_TO}
    $runs += @{name="O098F_CD_EU_$($c.tf)_$($c.tag)_$w"; tf=$c.tf; z=$c.z; win=$w; from=$from; to=$to; set=$c.set; tag=$c.tag}
  }
}

foreach($r in $runs){
  Write-Output "=== RUN: $($r.name) ==="
  $a = @("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","PairSpread_StatArb","-Symbol","EURUSD","-Period",$r.tf,"-Model","1","-FromDate",$r.from,"-ToDate",$r.to,"-ReportName",$r.name,"-SetFile",$r.set,"-TimeoutSec","900")
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
  # config column encodes tf+tag so it stays distinct in the shared entryZ column CSV
  $cfg = "$($r.tf)_$($r.tag)"
  $row = '{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11}' -f "EURUSD/GBPUSD","EURUSD","$($r.z)($cfg)",$r.win,$PF,$T,$W,$DD,$NP,$LW,$LL,$rep
  Add-Content -Path $CsvPath -Value $row
  Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
