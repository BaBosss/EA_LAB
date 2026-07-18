<#
pa_grid_step2b.ps1 — re-run ON (StackConfirm=CONF_PA_ENGULF, fixed set) Model 4 both-window.
The first run had a duplicate StackConfirm key so PA never activated. OFF results reused.
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$sd="D:\EA_LAB\ea_template\sets"
$csv="D:\EA_LAB\ea_projects\(TRD)_PA_Probe\reports\step2b_on.csv"
$cells=@(
  @{lab="ON_UP_M4"; from="2019.01.01"; to="2022.01.01"}
  @{lab="ON_DN_M4"; from="2023.01.01"; to="2026.01.01"}
)
"label,PF,net,eqDDpct,trades,winpct,maxLoss,recovery,report" | Out-File -FilePath $csv -Encoding utf8
foreach($c in $cells){
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "D:\Meta 5b\terminal64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $rn="PAGRID2_$($c.lab)"
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","Boss_14_GridLog","-Symbol","AUDNZD","-Period","H1","-Model","4","-FromDate",$c.from,"-ToDate",$c.to,"-SetFile","$sd\B14_PAon.set","-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","1500","-Force")
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
Write-Output "STEP2B COMPLETE"
