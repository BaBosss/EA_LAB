<#
agoil_phase3b_fill.ps1 — re-run the 7 cells that produced no report in the first
Phase 3b batch (Meta 5b had a stuck instance). Appends to the same CSV.
Kills any stray Meta 5b first (never touches D:\Meta 5 main).
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "D:\Meta 5b\terminal64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

$proj="D:\EA_LAB\ea_projects\(Boss)_AdaptiveGrid_Oil"
$setDir="$proj\set_files"; $csv="$proj\reports\phase3b_mech.csv"
$from="2019.01.01"; $to="2026.01.01"

$cells=@(
  @{tag="d1p5_t1p5"; dist=1.5; tp=1.5; ema=50;  lr=20}
  @{tag="d2_t0p7";   dist=2.0; tp=0.7; ema=50;  lr=20}
  @{tag="d2_t1";     dist=2.0; tp=1.0; ema=50;  lr=20}
  @{tag="d2_t1p5";   dist=2.0; tp=1.5; ema=50;  lr=20}
  @{tag="slow_e100l40"; dist=1.0; tp=1.0; ema=100; lr=40}
  @{tag="slow_e100l20"; dist=1.0; tp=1.0; ema=100; lr=20}
  @{tag="slow_e200l40"; dist=1.0; tp=1.0; ema=200; lr=40}
)
foreach($c in $cells){
  $rn="AGP3B_$($c.tag)"
  $sf="$setDir\$rn.set"
  @("_08_DirMode=1","_01_FilterMode=2","_01_GateAdds=true","_01_SlopeThresh=0.05",
    "_03_DistAtrMult=$($c.dist)","_04_BasketTpAtrMult=$($c.tp)","_01_EmaPeriod=$($c.ema)","_01_LrLookback=$($c.lr)") | Set-Content -LiteralPath $sf -Encoding ascii
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","AdaptiveGrid_Oil_rev03","-Symbol","WTI","-Period","H1","-Model","2","-FromDate",$from,"-ToDate",$to,"-SetFile",$sf,"-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","900","-Force")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp="";$mLL="";$mRec=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLL=$o.largest_loss_trade;$mRec=$o.recovery_factor
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12}' -f $c.tag,$c.dist,$c.tp,$c.ema,$c.lr,$mPF,$mNet,$mDD,$mTr,$mWp,$mLL,$mRec,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $rn PF=$mPF net=$mNet DD=$mDD trades=$mTr"
}
Write-Output "PHASE3B-FILL COMPLETE"
