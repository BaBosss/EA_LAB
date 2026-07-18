<#
agoil_phase6_persymbol.ps1 — proper PER-SYMBOL optimization (user point: screen != optimize).
For each symbol, sweep the core grid levers DistAtrMult x BasketTpAtrMult (3x3) on the FULL
window 2019-2026, rev03 dynamic AGREE thr0.05. Judge each symbol on its OWN plateau, not the
WTI-tuned config. Symbols: EURUSD/AUDNZD (mean-reversion rangers) + BTCUSD (trender, user ask).
Model 2. Kills stray Meta 5b between runs. m-prefixed metric vars.
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$proj="D:\EA_LAB\ea_projects\(Boss)_AdaptiveGrid_Oil"
$setDir="$proj\set_files"; $csv="$proj\reports\phase6_persymbol.csv"
$from="2019.01.01"; $to="2026.01.01"

$syms=@("EURUSD","AUDNZD","BTCUSD")
$dists=@(0.7,1.0,1.5)
$tps=@(0.8,1.2,1.8)

"symbol,dist,tp,PF,net,eqDDpct,trades,winpct,maxLoss,recovery,report" | Out-File -FilePath $csv -Encoding utf8
foreach($sym in $syms){ foreach($dist in $dists){ foreach($tp in $tps){
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "D:\Meta 5b\terminal64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $rn="AGP6_{0}_d{1}_t{2}" -f $sym,($dist.ToString().Replace('.','p')),($tp.ToString().Replace('.','p'))
  $sf="$setDir\$rn.set"
  @("_08_DirMode=1","_01_FilterMode=2","_01_GateAdds=true","_01_SlopeThresh=0.05",
    "_03_DistAtrMult=$dist","_04_BasketTpAtrMult=$tp","_01_EmaPeriod=50","_01_LrLookback=20") | Set-Content -LiteralPath $sf -Encoding ascii
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","AdaptiveGrid_Oil_rev03","-Symbol",$sym,"-Period","H1","-Model","2","-FromDate",$from,"-ToDate",$to,"-SetFile",$sf,"-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","900","-Force")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp="";$mLL="";$mRec=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLL=$o.largest_loss_trade;$mRec=$o.recovery_factor
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10}' -f $sym,$dist,$tp,$mPF,$mNet,$mDD,$mTr,$mWp,$mLL,$mRec,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $rn PF=$mPF net=$mNet DD=$mDD trades=$mTr"
}}}
Write-Output "PHASE6 COMPLETE -> $csv"
