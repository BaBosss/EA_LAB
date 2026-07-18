<#
agoil_phase7_ranger_validate.ps1 — the FX-ranger edge is the real finding. Validate it.
(A) BOTH-WINDOW split for the AUDNZD/EURUSD plateau configs — a full-window plateau can be
    carried by one window; require BOTH 2019-22 and 2023-26 to hold.
(B) SISTER-RANGER portability — same plateau config on EURGBP/AUDCAD/NZDCAD/EURCHF (classic
    mean-reversion crosses) full window, to see if it's a portable ranger edge or AUDNZD-only.
rev03 dynamic AGREE thr0.05. Model 2. Kills stray Meta 5b between runs.
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$proj="D:\EA_LAB\ea_projects\(Boss)_AdaptiveGrid_Oil"
$setDir="$proj\set_files"; $csv="$proj\reports\phase7_ranger.csv"

# (label, symbol, from, to, dist, tp)
$cells=@(
  # A) both-window split — AUDNZD at its two plateau TPs, EURUSD at tp1.8
  @{lab="AUDNZD_UP_t1p2"; sym="AUDNZD"; from="2019.01.01"; to="2022.01.01"; dist=1.0; tp=1.2}
  @{lab="AUDNZD_DN_t1p2"; sym="AUDNZD"; from="2023.01.01"; to="2026.01.01"; dist=1.0; tp=1.2}
  @{lab="AUDNZD_UP_t1p8"; sym="AUDNZD"; from="2019.01.01"; to="2022.01.01"; dist=1.0; tp=1.8}
  @{lab="AUDNZD_DN_t1p8"; sym="AUDNZD"; from="2023.01.01"; to="2026.01.01"; dist=1.0; tp=1.8}
  @{lab="EURUSD_UP_t1p8"; sym="EURUSD"; from="2019.01.01"; to="2022.01.01"; dist=1.0; tp=1.8}
  @{lab="EURUSD_DN_t1p8"; sym="EURUSD"; from="2023.01.01"; to="2026.01.01"; dist=1.0; tp=1.8}
  # B) sister-ranger portability — full window, two TPs each
  @{lab="EURGBP_FULL_t1p2"; sym="EURGBP"; from="2019.01.01"; to="2026.01.01"; dist=1.0; tp=1.2}
  @{lab="EURGBP_FULL_t1p8"; sym="EURGBP"; from="2019.01.01"; to="2026.01.01"; dist=1.0; tp=1.8}
  @{lab="AUDCAD_FULL_t1p2"; sym="AUDCAD"; from="2019.01.01"; to="2026.01.01"; dist=1.0; tp=1.2}
  @{lab="AUDCAD_FULL_t1p8"; sym="AUDCAD"; from="2019.01.01"; to="2026.01.01"; dist=1.0; tp=1.8}
  @{lab="NZDCAD_FULL_t1p2"; sym="NZDCAD"; from="2019.01.01"; to="2026.01.01"; dist=1.0; tp=1.2}
  @{lab="NZDCAD_FULL_t1p8"; sym="NZDCAD"; from="2019.01.01"; to="2026.01.01"; dist=1.0; tp=1.8}
  @{lab="EURCHF_FULL_t1p2"; sym="EURCHF"; from="2019.01.01"; to="2026.01.01"; dist=1.0; tp=1.2}
  @{lab="EURCHF_FULL_t1p8"; sym="EURCHF"; from="2019.01.01"; to="2026.01.01"; dist=1.0; tp=1.8}
)
"label,symbol,PF,net,eqDDpct,trades,winpct,maxLoss,recovery,report" | Out-File -FilePath $csv -Encoding utf8
foreach($c in $cells){
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "D:\Meta 5b\terminal64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $rn="AGP7_$($c.lab)"
  $sf="$setDir\$rn.set"
  @("_08_DirMode=1","_01_FilterMode=2","_01_GateAdds=true","_01_SlopeThresh=0.05",
    "_03_DistAtrMult=$($c.dist)","_04_BasketTpAtrMult=$($c.tp)","_01_EmaPeriod=50","_01_LrLookback=20") | Set-Content -LiteralPath $sf -Encoding ascii
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","AdaptiveGrid_Oil_rev03","-Symbol",$c.sym,"-Period","H1","-Model","2","-FromDate",$c.from,"-ToDate",$c.to,"-SetFile",$sf,"-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","900","-Force")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp="";$mLL="";$mRec=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLL=$o.largest_loss_trade;$mRec=$o.recovery_factor
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}' -f $c.lab,$c.sym,$mPF,$mNet,$mDD,$mTr,$mWp,$mLL,$mRec,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $rn PF=$mPF net=$mNet DD=$mDD trades=$mTr"
}
Write-Output "PHASE7 COMPLETE -> $csv"
