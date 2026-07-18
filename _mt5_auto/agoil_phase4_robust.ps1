<#
agoil_phase4_robust.ps1 — cross-TF + cross-symbol robustness of the two "positive-region"
rev03 dynamic configs. If the modest edge (PF ~1.4-1.6 on WTI H1) is real it should survive
a timeframe change (H4) and a correlated-but-different symbol (BRENT). If it collapses, the
WTI-H1 numbers were fragile. Kills stray Meta 5b between runs to avoid the batch hang.
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$proj="D:\EA_LAB\ea_projects\(Boss)_AdaptiveGrid_Oil"
$setDir="$proj\set_files"; $csv="$proj\reports\phase4_robust.csv"

$configs=@(
  @{cfg="A_d1t1";   dist=1.0; tp=1.0}
  @{cfg="B_d1t1p5"; dist=1.0; tp=1.5}
)
$cells=@(
  @{tag="WTI_H4";   sym="WTI";   tf="H4"}
  @{tag="BRENT_H1"; sym="BRENT"; tf="H1"}
  @{tag="BRENT_H4"; sym="BRENT"; tf="H4"}
)
"config,cell,PF,net,eqDDpct,trades,winpct,maxLoss,recovery,report" | Out-File -FilePath $csv -Encoding utf8

foreach($cf in $configs){ foreach($c in $cells){
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "D:\Meta 5b\terminal64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $rn="AGP4_$($cf.cfg)_$($c.tag)"
  $sf="$setDir\$rn.set"
  @("_08_DirMode=1","_01_FilterMode=2","_01_GateAdds=true","_01_SlopeThresh=0.05",
    "_03_DistAtrMult=$($cf.dist)","_04_BasketTpAtrMult=$($cf.tp)","_01_EmaPeriod=50","_01_LrLookback=20") | Set-Content -LiteralPath $sf -Encoding ascii
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","AdaptiveGrid_Oil_rev03","-Symbol",$c.sym,"-Period",$c.tf,"-Model","2","-FromDate","2019.01.01","-ToDate","2026.01.01","-SetFile",$sf,"-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","900","-Force")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp="";$mLL="";$mRec=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLL=$o.largest_loss_trade;$mRec=$o.recovery_factor
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}' -f $cf.cfg,$c.tag,$mPF,$mNet,$mDD,$mTr,$mWp,$mLL,$mRec,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $rn PF=$mPF net=$mNet DD=$mDD trades=$mTr"
}}
Write-Output "PHASE4 COMPLETE -> $csv"
