<#
agoil_phase1_slopethresh.ps1 — AdaptiveGrid_Oil Phase 1 campaign.
Crux test: does the LinReg trend filter (component #1) enable adaptive direction?
Sweep _01_SlopeThresh x direction x window. Portfolio = BUY-instance + SELL-instance
run independently (magic 990201/990202); per-window combined = sum of the two nets.
Goal: a SlopeThresh where COMBINED net > 0 on BOTH windows (up 2019-22 + down 2023-26).
Meta 5b portable only (no collision with main D:\Meta 5). Model 2 for sweep speed.
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$proj="D:\EA_LAB\ea_projects\(Boss)_AdaptiveGrid_Oil"
$setDir="$proj\set_files"; $csv="$proj\reports\phase1_slopethresh.csv"
New-Item -ItemType Directory -Force $setDir | Out-Null

$thresh=@(0.01,0.02,0.04,0.08,0.15)
$dirs=@(@{tag="BUY";v="1"},@{tag="SELL";v="-1"})
$wins=@(
  @{tag="UP1922";  from="2019.01.01"; to="2022.01.01"}
  @{tag="DN2326";  from="2023.01.01"; to="2026.01.01"}
)
"win,dir,slopeThresh,PF,net,eqDDpct,trades,winpct,maxLoss,report" | Out-File -FilePath $csv -Encoding utf8

foreach($w in $wins){ foreach($d in $dirs){ foreach($t in $thresh){
  $rn="AGP1_{0}_{1}_st{2}" -f $w.tag,$d.tag,($t.ToString().Replace('.','p'))
  $sf="$setDir\$rn.set"
  @("_08_Direction=$($d.v)","_01_SlopeThresh=$t") | Set-Content -LiteralPath $sf -Encoding ascii
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","AdaptiveGrid_Oil","-Symbol","WTI","-Period","H1","-Model","2","-FromDate",$w.from,"-ToDate",$w.to,"-SetFile",$sf,"-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","900")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  # NOTE: PowerShell variables are CASE-INSENSITIVE. Metric vars MUST NOT collide
  # with loop vars ($t,$w,$d) — use m-prefixed names.
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp="";$mLL=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLL=$o.largest_loss_trade
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}' -f $w.tag,$d.tag,$t,$mPF,$mNet,$mDD,$mTr,$mWp,$mLL,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $rn PF=$mPF net=$mNet DD=$mDD"
}}}
Write-Output "PHASE1 COMPLETE -> $csv"
