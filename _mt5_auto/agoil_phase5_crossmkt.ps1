<#
agoil_phase5_crossmkt.ps1 — cross-market screen of the AdaptiveGrid concept.
Was oil the wrong home? Screen rev03 dynamic config A (dist1.0/tp1.0/thr0.05, AGREE+GateAdds)
across crypto / FX majors / index / metal, H1, common window 2021-2026 (crypto has this).
ATR-normalized spacing+threshold transfer across instruments, so config A is a fair default.
Model 2. Kills stray Meta 5b between runs. m-prefixed metric vars.
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$proj="D:\EA_LAB\ea_projects\(Boss)_AdaptiveGrid_Oil"
$setDir="$proj\set_files"; $csv="$proj\reports\phase5_crossmkt.csv"
$from="2021.01.01"; $to="2026.01.01"

$syms=@("BTCUSD","ETHUSD","SOLUSD","EURUSD","GBPUSD","USDJPY","AUDUSD","XAUUSD","NAS100")

"symbol,PF,net,eqDDpct,trades,winpct,maxLoss,recovery,report" | Out-File -FilePath $csv -Encoding utf8
foreach($sym in $syms){
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "D:\Meta 5b\terminal64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $rn="AGP5_$sym"
  $sf="$setDir\$rn.set"
  @("_08_DirMode=1","_01_FilterMode=2","_01_GateAdds=true","_01_SlopeThresh=0.05",
    "_03_DistAtrMult=1.0","_04_BasketTpAtrMult=1.0","_01_EmaPeriod=50","_01_LrLookback=20") | Set-Content -LiteralPath $sf -Encoding ascii
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","AdaptiveGrid_Oil_rev03","-Symbol",$sym,"-Period","H1","-Model","2","-FromDate",$from,"-ToDate",$to,"-SetFile",$sf,"-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","900","-Force")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp="";$mLL="";$mRec=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLL=$o.largest_loss_trade;$mRec=$o.recovery_factor
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8}' -f $sym,$mPF,$mNet,$mDD,$mTr,$mWp,$mLL,$mRec,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $sym PF=$mPF net=$mNet DD=$mDD trades=$mTr"
}
Write-Output "PHASE5 COMPLETE -> $csv"
