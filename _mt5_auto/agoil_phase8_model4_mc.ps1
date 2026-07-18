<#
agoil_phase8_model4_mc.ps1 — truth test for the AUDNZD ranger edge.
(A) AUDNZD d1.0/t1.2 on MODEL 4 (real ticks) both windows — grid fills are intra-bar sensitive,
    Model 2 can flatter them. If it holds PF>2 on real ticks both windows, it is genuine.
(B) sister-ranger both-window at t1.2 (Model 2) — confirm the edge class is portable, not AUDNZD-only.
Kills stray Meta 5b between runs. m-prefixed metric vars.
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$proj="D:\EA_LAB\ea_projects\(Boss)_AdaptiveGrid_Oil"
$setDir="$proj\set_files"; $csv="$proj\reports\phase8_model4.csv"

# (label, symbol, from, to, model)
$cells=@(
  @{lab="AUDNZD_UP_M4"; sym="AUDNZD"; from="2019.01.01"; to="2022.01.01"; model=4}
  @{lab="AUDNZD_DN_M4"; sym="AUDNZD"; from="2023.01.01"; to="2026.01.01"; model=4}
  @{lab="AUDNZD_FULL_M4"; sym="AUDNZD"; from="2019.01.01"; to="2026.01.01"; model=4}
  # sister both-window at t1.2, Model 2
  @{lab="AUDCAD_UP"; sym="AUDCAD"; from="2019.01.01"; to="2022.01.01"; model=2}
  @{lab="AUDCAD_DN"; sym="AUDCAD"; from="2023.01.01"; to="2026.01.01"; model=2}
  @{lab="NZDCAD_UP"; sym="NZDCAD"; from="2019.01.01"; to="2022.01.01"; model=2}
  @{lab="NZDCAD_DN"; sym="NZDCAD"; from="2023.01.01"; to="2026.01.01"; model=2}
  @{lab="EURCHF_UP"; sym="EURCHF"; from="2019.01.01"; to="2022.01.01"; model=2}
  @{lab="EURCHF_DN"; sym="EURCHF"; from="2023.01.01"; to="2026.01.01"; model=2}
)
"label,symbol,model,PF,net,eqDDpct,trades,winpct,maxLoss,recovery,sharpe,report" | Out-File -FilePath $csv -Encoding utf8
foreach($c in $cells){
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "D:\Meta 5b\terminal64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $rn="AGP8_$($c.lab)"
  $sf="$setDir\$rn.set"
  @("_08_DirMode=1","_01_FilterMode=2","_01_GateAdds=true","_01_SlopeThresh=0.05",
    "_03_DistAtrMult=1.0","_04_BasketTpAtrMult=1.2","_01_EmaPeriod=50","_01_LrLookback=20") | Set-Content -LiteralPath $sf -Encoding ascii
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","AdaptiveGrid_Oil_rev03","-Symbol",$c.sym,"-Period","H1","-Model","$($c.model)","-FromDate",$c.from,"-ToDate",$c.to,"-SetFile",$sf,"-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","1500","-Force")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp="";$mLL="";$mRec="";$mSh=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLL=$o.largest_loss_trade;$mRec=$o.recovery_factor;$mSh=$o.sharpe_ratio
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11}' -f $c.lab,$c.sym,$c.model,$mPF,$mNet,$mDD,$mTr,$mWp,$mLL,$mRec,$mSh,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $rn PF=$mPF net=$mNet DD=$mDD trades=$mTr"
}
Write-Output "PHASE8 COMPLETE -> $csv"
