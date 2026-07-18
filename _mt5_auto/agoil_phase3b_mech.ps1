<#
agoil_phase3b_mech.ps1 — rev03 dynamic, mechanical-lever sweep on FULL span 2019-2026.
Hold dynamic thr0.05 (best from Phase 3). Sweep grid spacing x basket-TP looking for a
PLATEAU (neighbours all positive), not an isolated spike. Then 3 slower-filter probes to
see if a less twitchy trend detector cuts the dynamic whipsaw.
Meta 5b portable, Model 2. m-prefixed metric vars (PowerShell case-insensitive).
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$proj="D:\EA_LAB\ea_projects\(Boss)_AdaptiveGrid_Oil"
$setDir="$proj\set_files"; $csv="$proj\reports\phase3b_mech.csv"
$from="2019.01.01"; $to="2026.01.01"

"tag,dist,tp,ema,lr,PF,net,eqDDpct,trades,winpct,maxLoss,recovery,report" | Out-File -FilePath $csv -Encoding utf8

function RunCell($tag,$dist,$tp,$ema,$lr){
  $rn="AGP3B_$tag"
  $sf="$setDir\$rn.set"
  @("_08_DirMode=1","_01_FilterMode=2","_01_GateAdds=true","_01_SlopeThresh=0.05",
    "_03_DistAtrMult=$dist","_04_BasketTpAtrMult=$tp","_01_EmaPeriod=$ema","_01_LrLookback=$lr") | Set-Content -LiteralPath $sf -Encoding ascii
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","AdaptiveGrid_Oil_rev03","-Symbol","WTI","-Period","H1","-Model","2","-FromDate",$from,"-ToDate",$to,"-SetFile",$sf,"-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","900")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp="";$mLL="";$mRec=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLL=$o.largest_loss_trade;$mRec=$o.recovery_factor
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12}' -f $tag,$dist,$tp,$ema,$lr,$mPF,$mNet,$mDD,$mTr,$mWp,$mLL,$mRec,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $rn PF=$mPF net=$mNet DD=$mDD trades=$mTr"
}

# Mechanical grid: spacing x basket-TP (filter held at Ema50/LR20)
foreach($dist in @(0.7,1.0,1.5,2.0)){ foreach($tp in @(0.7,1.0,1.5)){
  $tag="d{0}_t{1}" -f ($dist.ToString().Replace('.','p')),($tp.ToString().Replace('.','p'))
  RunCell $tag $dist $tp 50 20
}}

# Slower-filter probes (cut dynamic whipsaw) at the default spacing/TP
RunCell "slow_e100l40" 1.0 1.0 100 40
RunCell "slow_e100l20" 1.0 1.0 100 20
RunCell "slow_e200l40" 1.0 1.0 200 40

Write-Output "PHASE3B COMPLETE -> $csv"
