# ORDER-049c — swb flat-lot BWD-confirm the new forward-strong pairs (kill regime traps).
# swb@AUDCAD already passed full funnel (demo #3). Forward scan showed swb strong on
# EURAUD/GBPJPY/USDCHF/EURJPY/USDJPY/GBPUSD/NZDUSD too — BWD 2020-22 tells edge vs trap.
# Survivors (PF>1, DD<40, lot-ok) -> spread+Model-1 next. MT4 lane 1.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$dd = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$sb = "D:\Forex\10_EA_PROJECTS\2. wait for test\2024-06\FREE EA-20240608T074321Z-001\FREE EA\swb grid 4.1.0.3_h.ex4"
$set = "D:\EA_LAB\_mt5_auto\ab_sets\swb_flat.set"
$out = "D:\EA_LAB\_mt5_auto\SWB_BWD_EXPAND.csv"
$log = "D:\EA_LAB\_mt5_auto\swb_bwd_expand.log"
'"symbol","pf","net","dd_pct","trades","lotcheck"' | Out-File $out -Encoding utf8
if(-not(Test-Path -LiteralPath (Join-Path $dd "swb grid 4.1.0.3_h.ex4"))){ Copy-Item -LiteralPath $sb -Destination (Join-Path $dd "swb grid 4.1.0.3_h.ex4") -Force }
Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' } | ForEach-Object { Stop-Process -Id $_.Id -Force -Confirm:$false }
Start-Sleep 3
foreach($sym in 'EURAUD','GBPJPY','USDCHF','EURJPY','USDJPY','GBPUSD','NZDUSD'){
  $rep = "SWB_BWD_$sym"
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert "swb grid 4.1.0.3_h" -Symbol $sym -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 1 -SetFile $set -ReportName $rep -TimeoutSec 900 *>> $log
  $htm = "D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if(Test-Path $htm){ try{ $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
      $lc = (& D:\EA_LAB\scripts\mt4_lotcheck.ps1 -Report $htm) -replace '.*: ',''
      "`"$sym`",$($j.profit_factor),$($j.net_profit),$($j.max_drawdown_pct),$($j.total_trades),`"$lc`"" | Add-Content $out
    }catch{ "`"$sym`",,,,,PARSE_ERR"|Add-Content $out } }
  else { "`"$sym`",,,,,NO_REPORT"|Add-Content $out }
}
"SWB BWD DONE"; Get-Content $out
