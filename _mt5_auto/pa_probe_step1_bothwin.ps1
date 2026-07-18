<#
pa_probe_step1_bothwin.ps1 — Step 1 gate: does PA give a real BOTH-WINDOW flat-lot edge
in the two contexts Phase 0 flagged positive (XAU-H1 continuation, EURGBP-H1 reversal)?
PA off vs on, split UP(2019-22) + DN(2023-26). PASS = PA-on expectancy positive on BOTH
windows AND beats PA-off on both. Guards against window-fit (the AUDNZD Model-2 trap).
Model 2. Meta 5b portable. m-prefixed vars.
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$proj="D:\EA_LAB\ea_projects\(TRD)_PA_Probe"
$setDir="$proj\set_files"; $csv="$proj\reports\step1_bothwin.csv"

# mode 0=cont 1=rev
$ctx=@(
  @{tag="XAU_H1_CONT"; mode=0; sym="XAUUSD"; tf="H1"}
  @{tag="EURGBP_H1_REV"; mode=1; sym="EURGBP"; tf="H1"}
)
$wins=@(
  @{w="UP"; from="2019.01.01"; to="2022.01.01"}
  @{w="DN"; from="2023.01.01"; to="2026.01.01"}
)
"ctx,window,usePA,PF,net,expPayoff,eqDDpct,trades,winpct,report" | Out-File -FilePath $csv -Encoding utf8
foreach($c in $ctx){ foreach($win in $wins){ foreach($pa in @("false","true")){
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "D:\Meta 5b\terminal64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $rn="PA1_{0}_{1}_pa{2}" -f $c.tag,$win.w,($pa.Substring(0,1))
  $sf="$setDir\$rn.set"
  @("_01_Mode=$($c.mode)","_01_UsePA=$pa") | Set-Content -LiteralPath $sf -Encoding ascii
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","PA_Probe","-Symbol",$c.sym,"-Period",$c.tf,"-Model","2","-FromDate",$win.from,"-ToDate",$win.to,"-SetFile",$sf,"-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","900","-Force")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mEP="";$mDD="";$mTr="";$mWp=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mEP=$o.expected_payoff;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}' -f $c.tag,$win.w,$pa,$mPF,$mNet,$mEP,$mDD,$mTr,$mWp,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $rn exp=$mEP PF=$mPF win=$mWp trades=$mTr"
}}}
Write-Output "STEP1 COMPLETE -> $csv"
