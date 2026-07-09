# generate (time,profit) trade CSVs for the 3 MT4 demo EAs over 2023-2026 for the corr matrix.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$dd = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$sb = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$eas = @(
  @{ea="UnNomGuaiV1.132"; sym="EURUSD"; src="2024-06\FREE EA-20240608T074321Z-001\FREE EA\UnNomGuaiV1.132.ex4"; set="D:\EA_LAB\_demo_deploy\UnNomGuai_cap20.set"},
  @{ea="RSI from pips_EA"; sym="EURUSD"; src="wait for test\RSI from pips_EA.ex4"; set=""},
  @{ea="swb grid 4.1.0.3_h"; sym="AUDCAD"; src="2024-06\FREE EA-20240608T074321Z-001\FREE EA\swb grid 4.1.0.3_h.ex4"; set="D:\EA_LAB\_mt5_auto\ab_sets\swb_flat.set"}
)
Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' } | ForEach-Object { Stop-Process -Id $_.Id -Force -Confirm:$false }
Start-Sleep 3
foreach($e in $eas){
  $dst = Join-Path $dd "$($e.ea).ex4"
  if(-not(Test-Path -LiteralPath $dst)){ Copy-Item -LiteralPath (Join-Path $sb $e.src) -Destination $dst -Force }
  $safe = ($e.ea -replace '[^A-Za-z0-9]','_')
  $rep = "CORR_$safe"
  $args = @('-File','D:\EA_LAB\scripts\mt4_run.ps1','-Expert',$e.ea,'-Symbol',$e.sym,'-Period','H1','-FromDate','2023.01.01','-ToDate','2026.07.01','-Model','1','-ReportName',$rep,'-TimeoutSec','1200')
  if($e.set){ $args += @('-SetFile',$e.set) }
  powershell @args | Out-Null
  $htm = "D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if(Test-Path $htm){ python D:\EA_LAB\scripts\mt4_deals_to_csv.py $htm "D:\EA_LAB\_mt5_auto\CORR_$safe.csv" }
  else { "NO_REPORT $($e.ea)" }
}
"MT4 CORR DONE"
