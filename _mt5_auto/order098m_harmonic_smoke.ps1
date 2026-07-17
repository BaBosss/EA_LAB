<#
order098m_harmonic_smoke.ps1 - HarmonicABCD_Naked smoke (ORDER-098-M).
Reversion-geometry -> rangers first (EURUSD/EURGBP/AUDNZD H4) + XAU H4 ref. Model 2, 2023-26, default params.
#>
$ErrorActionPreference="Stop"
$auto="D:\EA_LAB\_mt5_auto"; $repDir="$auto\reports"; $CsvPath="$auto\order098m_harmonic_smoke.csv"
. D:\EA_LAB\scripts\use_python.ps1
$cells=@(
  @{sym="EURUSD"; tf="H4"}
  @{sym="EURGBP"; tf="H4"}
  @{sym="AUDNZD"; tf="H4"}
  @{sym="XAUUSD"; tf="H4"}
)
"symbol,tf,PF,trades,winpct,eqDDpct,netprofit,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($c in $cells){
  $name="O098M_$($c.sym)_$($c.tf)"
  Write-Output "=== RUN: $name ==="
  $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","HarmonicABCD_Naked","-Symbol",$c.sym,"-Period",$c.tf,"-Model","2","-FromDate","2023.01.01","-ToDate","2026.01.01","-ReportName",$name,"-TimeoutSec","900")
  $out=& powershell $a 2>&1 | Out-String; Write-Output $out
  $status=if($out -match "OK REPORT"){"OK"}else{"ERROR"}
  $rep="$repDir\$name.htm"; $PF="";$T="";$W="";$DD="";$NP=""
  if($status -eq "OK" -and (Test-Path $rep)){
    try{ $obj=(python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json | Out-String)|ConvertFrom-Json
      $PF=$obj.profit_factor;$T=$obj.total_trades;$W=$obj.profit_trades_pct;$DD=$obj.equity_drawdown_relative_pct;$NP=$obj.net_profit
    }catch{Write-Output "PARSE ERR";$status="ERROR"}
  }
  $row='{0},{1},{2},{3},{4},{5},{6},{7}' -f $c.sym,$c.tf,$PF,$T,$W,$DD,$NP,$rep
  Add-Content -Path $CsvPath -Value $row; Write-Output "ROW: $row [$status]"
}
Write-Output "DONE."
