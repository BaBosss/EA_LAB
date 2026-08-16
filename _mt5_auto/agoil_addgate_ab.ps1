<#
agoil_addgate_ab.ps1 — validate the add-gating core edit on Boss_14 GridLog.
(1) NEUTRALITY: OLD ex5 vs NEW ex5, both gate-off (home set), Model 2 one window.
    Must be byte-identical (net/PF/trades) -> proves the edit is additive/default-off.
(2) A/B on real ticks: NEW ex5 gate OFF vs ON (mode1, block long-DCA adds in downtrend),
    AUDNZD full 2019-2026 Model 4. Does gating adds cut DD/maxLoss without killing PF?
Meta 5b portable. Kills stray Meta 5b between runs. m-prefixed metric vars.
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$sd="D:\EA_LAB\ea_template\sets"
$csv="D:\EA_LAB\ea_projects\(Boss)_AdaptiveGrid_Oil\reports\addgate_ab.csv"

# label, expert, set, sym, from, to, model
$cells=@(
  @{lab="NEUT_OLD"; ex="Boss_14_GridLog_OLD"; set="Boss14_GridLog_AUDNZD_ISpick.set"; sym="AUDNZD"; from="2023.01.01"; to="2026.01.01"; model=2}
  @{lab="NEUT_NEWoff"; ex="EALabTpl\Boss_14_GridLog"; set="Boss14_GridLog_AUDNZD_ISpick.set"; sym="AUDNZD"; from="2023.01.01"; to="2026.01.01"; model=2}
  @{lab="AB_off_M4"; ex="EALabTpl\Boss_14_GridLog"; set="B14_AB_off.set"; sym="AUDNZD"; from="2019.01.01"; to="2026.01.01"; model=4}
  @{lab="AB_on_M4";  ex="EALabTpl\Boss_14_GridLog"; set="B14_AB_on.set";  sym="AUDNZD"; from="2019.01.01"; to="2026.01.01"; model=4}
)
"label,expert,PF,net,eqDDpct,trades,winpct,maxLoss,recovery,report" | Out-File -FilePath $csv -Encoding utf8
foreach($c in $cells){
  if ($c.ex -match '(?i)(^|\\)Boss_14_GridLog_OLD\d*$') {
    Write-Error "REFUSE: legacy executable identity '$($c.ex)' is not an active writer target"
    exit 2
  }
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "D:\Meta 5b\terminal64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $rn="ADGATE_$($c.lab)"
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert",$c.ex,"-Symbol",$c.sym,"-Period","H1","-Model","$($c.model)","-FromDate",$c.from,"-ToDate",$c.to,"-SetFile","$sd\$($c.set)","-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","1500","-Force")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp="";$mLL="";$mRec=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLL=$o.largest_loss_trade;$mRec=$o.recovery_factor
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}' -f $c.lab,$c.ex,$mPF,$mNet,$mDD,$mTr,$mWp,$mLL,$mRec,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $($c.lab) PF=$mPF net=$mNet DD=$mDD trades=$mTr maxLoss=$mLL"
}
Write-Output "ADGATE-AB COMPLETE -> $csv"
