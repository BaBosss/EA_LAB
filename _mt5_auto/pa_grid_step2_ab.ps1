<#
pa_grid_step2_ab.ps1 — Step 2: PA-confirm on grid ADDS in Boss_14 GridLog.
(1) NEUTRALITY: regime-only ex5 (OLD2) vs new ex5, both home set (StackConfirm=DISTANCE),
    Model 2 -> byte-identical proves the PA edit is additive/default-off.
(2) A/B Model 4 AUDNZD both-window: StackConfirm=DISTANCE(off) vs CONF_PA_ENGULF(on).
    Does gating adds on a real engulfing improve Boss_14's DCA on real ticks?
Judge honestly (Step 1 flat-lot PA failed both-window, so expectations tempered).
Meta 5b portable. m-prefixed vars.
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$sd="D:\EA_LAB\ea_template\sets"
$csv="D:\EA_LAB\ea_projects\(TRD)_PA_Probe\reports\step2_grid_ab.csv"

# label, expert, set, from, to, model
$cells=@(
  @{lab="NEUT_OLD2"; ex="Boss_14_GridLog_OLD2"; set="Boss14_GridLog_AUDNZD_ISpick.set"; from="2023.01.01"; to="2026.01.01"; model=2}
  @{lab="NEUT_NEW";  ex="Boss_14_GridLog";      set="Boss14_GridLog_AUDNZD_ISpick.set"; from="2023.01.01"; to="2026.01.01"; model=2}
  @{lab="OFF_UP_M4"; ex="Boss_14_GridLog"; set="Boss14_GridLog_AUDNZD_ISpick.set"; from="2019.01.01"; to="2022.01.01"; model=4}
  @{lab="ON_UP_M4";  ex="Boss_14_GridLog"; set="B14_PAon.set";                     from="2019.01.01"; to="2022.01.01"; model=4}
  @{lab="OFF_DN_M4"; ex="Boss_14_GridLog"; set="Boss14_GridLog_AUDNZD_ISpick.set"; from="2023.01.01"; to="2026.01.01"; model=4}
  @{lab="ON_DN_M4";  ex="Boss_14_GridLog"; set="B14_PAon.set";                     from="2023.01.01"; to="2026.01.01"; model=4}
)
"label,PF,net,eqDDpct,trades,winpct,maxLoss,recovery,report" | Out-File -FilePath $csv -Encoding utf8
foreach($c in $cells){
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "D:\Meta 5b\terminal64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $rn="PAGRID_$($c.lab)"
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert",$c.ex,"-Symbol","AUDNZD","-Period","H1","-Model","$($c.model)","-FromDate",$c.from,"-ToDate",$c.to,"-SetFile","$sd\$($c.set)","-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","1500","-Force")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp="";$mLL="";$mRec=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLL=$o.largest_loss_trade;$mRec=$o.recovery_factor
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8}' -f $c.lab,$mPF,$mNet,$mDD,$mTr,$mWp,$mLL,$mRec,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $($c.lab) PF=$mPF net=$mNet DD=$mDD trades=$mTr"
}
Write-Output "STEP2 COMPLETE -> $csv"
