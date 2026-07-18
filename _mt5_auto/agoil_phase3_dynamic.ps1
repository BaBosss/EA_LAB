<#
agoil_phase3_dynamic.ps1 — rev03 DYNAMIC-direction test.
ONE instance picks direction from the trend (long uptrend / short downtrend / flat=stand aside).
Headline test: FULL span 2019-2026 continuous (matches the source post's claimed period,
PF 5x / DD 16%) — does a single instance adapt across the up->down regime change?
Also confirm on each sub-window. Sweep _01_SlopeThresh. Meta 5b portable, Model 2.
Vars m-prefixed (PowerShell case-insensitive).
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$proj="D:\EA_LAB\ea_projects\(Boss)_AdaptiveGrid_Oil"
$setDir="$proj\set_files"; $csv="$proj\reports\phase3_dynamic.csv"

$cells=@(
  @{win="FULL1926"; from="2019.01.01"; to="2026.01.01"; thr=0.03}
  @{win="FULL1926"; from="2019.01.01"; to="2026.01.01"; thr=0.05}
  @{win="FULL1926"; from="2019.01.01"; to="2026.01.01"; thr=0.08}
  @{win="FULL1926"; from="2019.01.01"; to="2026.01.01"; thr=0.10}
  @{win="UP1922";   from="2019.01.01"; to="2022.01.01"; thr=0.05}
  @{win="UP1922";   from="2019.01.01"; to="2022.01.01"; thr=0.10}
  @{win="DN2326";   from="2023.01.01"; to="2026.01.01"; thr=0.05}
  @{win="DN2326";   from="2023.01.01"; to="2026.01.01"; thr=0.10}
)
"win,slopeThresh,PF,net,eqDDpct,trades,winpct,maxLoss,recovery,sharpe,report" | Out-File -FilePath $csv -Encoding utf8

foreach($c in $cells){
  $rn="AGP3_{0}_st{1}" -f $c.win,($c.thr.ToString().Replace('.','p'))
  $sf="$setDir\$rn.set"
  @("_08_DirMode=1","_01_FilterMode=2","_01_GateAdds=true","_01_SlopeThresh=$($c.thr)") | Set-Content -LiteralPath $sf -Encoding ascii
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","AdaptiveGrid_Oil_rev03","-Symbol","WTI","-Period","H1","-Model","2","-FromDate",$c.from,"-ToDate",$c.to,"-SetFile",$sf,"-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","900")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp="";$mLL="";$mRec="";$mSh=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLL=$o.largest_loss_trade;$mRec=$o.recovery_factor;$mSh=$o.sharpe_ratio
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10}' -f $c.win,$c.thr,$mPF,$mNet,$mDD,$mTr,$mWp,$mLL,$mRec,$mSh,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $rn PF=$mPF net=$mNet DD=$mDD trades=$mTr rec=$mRec"
}
Write-Output "PHASE3 COMPLETE -> $csv"
