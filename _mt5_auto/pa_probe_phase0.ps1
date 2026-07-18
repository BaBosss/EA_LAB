<#
pa_probe_phase0.ps1 — Phase 0 candle-confirm A/B (tendency study, NOT pass/fail).
Same base signal, PA OFF vs ON, flat-lot single-position ATR-SL/RR-TP.
CONTINUATION on trenders (XAU/GBP), REVERSAL on rangers (EUR/AUDNZD/EURGBP).
Read Delta(on-off) across expectancy/win%/payoff/DD/#trades to see what PA DOES
in each context. Model 2, 2019-2026. Meta 5b portable. m-prefixed metric vars.
#>
$ErrorActionPreference="Stop"
. D:\EA_LAB\scripts\use_python.ps1
$proj="D:\EA_LAB\ea_projects\(TRD)_PA_Probe"
$setDir="$proj\set_files"; $csv="$proj\reports\phase0_pa_ab.csv"
$from="2019.01.01"; $to="2026.01.01"

# mode 0=continuation 1=reversal
$cells=@(
  @{mode=0; sym="XAUUSD"; tf="H1"}
  @{mode=0; sym="XAUUSD"; tf="H4"}
  @{mode=0; sym="GBPUSD"; tf="H1"}
  @{mode=1; sym="EURUSD"; tf="H1"}
  @{mode=1; sym="AUDNZD"; tf="H1"}
  @{mode=1; sym="EURGBP"; tf="H1"}
)
"mode,symbol,tf,usePA,PF,net,expPayoff,eqDDpct,trades,winpct,largeWin,largeLoss,report" | Out-File -FilePath $csv -Encoding utf8
foreach($c in $cells){ foreach($pa in @("false","true")){
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "D:\Meta 5b\terminal64.exe" } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $mtag = if($c.mode -eq 0){"CONT"}else{"REV"}
  $rn="PA0_{0}_{1}_{2}_pa{3}" -f $mtag,$c.sym,$c.tf,($pa.Substring(0,1))
  $sf="$setDir\$rn.set"
  @("_01_Mode=$($c.mode)","_01_UsePA=$pa") | Set-Content -LiteralPath $sf -Encoding ascii
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","PA_Probe","-Symbol",$c.sym,"-Period",$c.tf,"-Model","2","-FromDate",$from,"-ToDate",$to,"-SetFile",$sf,"-ReportName",$rn,"-Terminal","D:\Meta 5b\terminal64.exe","-Portable","-DataDir","D:\Meta 5b","-TimeoutSec","900","-Force")
  & powershell $a 2>&1 | Out-Null
  $rep="D:\EA_LAB\_mt5_auto\reports\$rn.htm"
  $mPF="";$mNet="";$mEP="";$mDD="";$mTr="";$mWp="";$mLW="";$mLL=""
  if(Test-Path $rep){
    try{ $o=python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mEP=$o.expected_payoff;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct;$mLW=$o.largest_profit_trade;$mLL=$o.largest_loss_trade
    }catch{}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12}' -f $mtag,$c.sym,$c.tf,$pa,$mPF,$mNet,$mEP,$mDD,$mTr,$mWp,$mLW,$mLL,$rn
  Add-Content -Path $csv -Value $row
  Write-Output "DONE $rn PF=$mPF exp=$mEP win=$mWp trades=$mTr"
}}
Write-Output "PHASE0 COMPLETE -> $csv"
