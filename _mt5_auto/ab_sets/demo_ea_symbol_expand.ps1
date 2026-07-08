# ORDER-049 — expand the 3 DEMO EAs across all majors to find MORE tradeable
# symbols (user 2026-07-08: test the demo EAs too). MT4 lane 1 (D:\Meta4), runs in
# PARALLEL with the MT5 RSI-MR sweep (different terminal exe). FORWARD window first
# (2026.03-07 M1, guaranteed data, fast) = find candidate pairs; BWD only survivors later.
# Compiled EAs -> reject/keep on default behavior + lot-check (Class B: can't optimize).
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$dd = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$sb = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$out = "D:\EA_LAB\_mt5_auto\DEMO_EA_EXPAND.csv"
$log = "D:\EA_LAB\_mt5_auto\demo_ea_expand.log"
'"ea","symbol","pf","net","dd_pct","trades","note"' | Out-File $out -Encoding utf8

$eas = @(
  @{ea="UnNomGuaiV1.132"; path="2024-06\FREE EA-20240608T074321Z-001\FREE EA\UnNomGuaiV1.132.ex4"; set=""},
  @{ea="RSI from pips_EA"; path="wait for test\RSI from pips_EA.ex4"; set=""},
  @{ea="swb grid 4.1.0.3_h"; path="2024-06\FREE EA-20240608T074321Z-001\FREE EA\swb grid 4.1.0.3_h.ex4"; set="D:\EA_LAB\_mt5_auto\ab_sets\swb_flat.set"}
)
$syms = 'EURUSD','GBPUSD','USDJPY','USDCHF','USDCAD','AUDUSD','NZDUSD','EURJPY','GBPJPY','EURGBP','AUDCAD','EURAUD'

foreach($e in $eas){
  $dst = Join-Path $dd "$($e.ea).ex4"
  if(-not(Test-Path -LiteralPath $dst)){ $src = Join-Path $sb $e.path; if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination $dst -Force } }
  foreach($sym in $syms){
    $safe = ($e.ea -replace '[^A-Za-z0-9]','_'); if($safe.Length -gt 20){$safe=$safe.Substring(0,20)}
    $rep = "EXP_${safe}_$sym"
    $args = @('-File','D:\EA_LAB\scripts\mt4_run.ps1','-Expert',$e.ea,'-Symbol',$sym,'-Period','H1','-FromDate','2026.03.01','-ToDate','2026.07.01','-Model','1','-ReportName',$rep,'-TimeoutSec','600')
    if($e.set){ $args += @('-SetFile',$e.set) }
    powershell @args *>> $log
    $htm = "D:\EA_LAB\_mt4_auto\reports\$rep.htm"
    if(Test-Path $htm){ try{ $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
        "`"$($e.ea)`",`"$sym`",$($j.profit_factor),$($j.net_profit),$($j.max_drawdown_pct),$($j.total_trades)," | Add-Content $out
      }catch{ "`"$($e.ea)`",`"$sym`",,,,,PARSE_ERR"|Add-Content $out } }
    else { "`"$($e.ea)`",`"$sym`",,,,,NO_REPORT"|Add-Content $out }
  }
}
"DEMO EXPAND DONE"; Get-Content $out
