# ORDER-049b — BWD-confirm UnNomGuai's strong-forward pairs (kill regime traps before
# believing them). UnNomGuai is already a validated demo candidate on EURUSD; if these
# pairs also pass BWD 2020-22 + lot-check they are deployable additional instances.
# MT4 lane 1. + martingale_recheck (SL/cap) on each.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$dd = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$sb = "D:\Forex\10_EA_PROJECTS\2. wait for test\2024-06\FREE EA-20240608T074321Z-001\FREE EA\UnNomGuaiV1.132.ex4"
$out = "D:\EA_LAB\_mt5_auto\UNNOMGUAI_BWD.csv"
$log = "D:\EA_LAB\_mt5_auto\unnomguai_bwd.log"
'"symbol","pf","net","dd_pct","trades","lotcheck"' | Out-File $out -Encoding utf8
if(-not(Test-Path -LiteralPath (Join-Path $dd "UnNomGuaiV1.132.ex4"))){ Copy-Item -LiteralPath $sb -Destination (Join-Path $dd "UnNomGuaiV1.132.ex4") -Force }

Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' } | ForEach-Object { Stop-Process -Id $_.Id -Force -Confirm:$false }
Start-Sleep 3

foreach($sym in 'AUDUSD','EURAUD','AUDCAD','EURJPY','GBPJPY','GBPUSD','EURGBP','USDCHF','NZDUSD'){
  $rep = "UNG_BWD_$sym"
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert "UnNomGuaiV1.132" -Symbol $sym -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 1 -ReportName $rep -TimeoutSec 900 *>> $log
  $htm = "D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if(Test-Path $htm){ try{ $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
      $lc = (& D:\EA_LAB\scripts\mt4_lotcheck.ps1 -Report $htm) -replace '.*: ',''
      "`"$sym`",$($j.profit_factor),$($j.net_profit),$($j.max_drawdown_pct),$($j.total_trades),`"$lc`"" | Add-Content $out
    }catch{ "`"$sym`",,,,,PARSE_ERR"|Add-Content $out } }
  else { "`"$sym`",,,,,NO_REPORT"|Add-Content $out }
}
"UNNOMGUAI BWD DONE"; Get-Content $out
