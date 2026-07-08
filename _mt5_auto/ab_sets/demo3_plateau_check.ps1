# ORDER-050 — plateau-robustness check on the 3 validated DEMO EAs (user 2026-07-08:
# "optimize เพิ่มรึยัง" — no, they passed at default only). This is NOT a PF-chase and
# does NOT change the deploy config. It sweeps the single most PF-relevant input around
# its DEFAULT, on BOTH regimes, to confirm the default sits on a stable plateau (neighbours
# also OK) vs a fragile spike (a losing neighbour = deploy the default with caution / distrust).
# MT4 lane 1. Home symbol each (UnNomGuai/RSI=EURUSD, swb=AUDCAD).
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$dd = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\demo3_sets"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\DEMO3_PLATEAU.csv"
$log = "D:\EA_LAB\_mt5_auto\demo3_plateau.log"
'"ea","symbol","param","value","window","pf","net","dd_pct","trades"' | Out-File $out -Encoding utf8

# ea | symbol | src | swept param name | default | test values | extra baseline set lines
$specs = @(
  @{ea="UnNomGuaiV1.132"; sym="EURUSD"; src="2024-06\FREE EA-20240608T074321Z-001\FREE EA\UnNomGuaiV1.132.ex4";
    param="pairglobalprofit"; def=8; vals=@(5,8,12); base=@("space3Orders=20")},
  @{ea="RSI from pips_EA"; sym="EURUSD"; src="wait for test\RSI from pips_EA.ex4";
    param="TP_pips"; def=15; vals=@(10,15,20); base=@()},
  @{ea="swb grid 4.1.0.3_h"; sym="AUDCAD"; src="2024-06\FREE EA-20240608T074321Z-001\FREE EA\swb grid 4.1.0.3_h.ex4";
    param="tp_in_money"; def=5; vals=@(3,5,8); base=@("lot_multiplier=false","lot_multiplier_2=1")}
)
$sb = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2026.03.01";t="2026.07.01"})

Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' } | ForEach-Object { Stop-Process -Id $_.Id -Force -Confirm:$false }
Start-Sleep 3

foreach($s in $specs){
  $dstEx = Join-Path $dd "$($s.ea).ex4"
  if(-not(Test-Path -LiteralPath $dstEx)){ $src = Join-Path $sb $s.src; if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination $dstEx -Force } }
  foreach($v in $s.vals){
    $set = "$setdir\$(($s.ea -replace '[^A-Za-z0-9]','_'))_$($s.param)_$v.set"
    ($s.base + @("$($s.param)=$v")) -join "`r`n" | Out-File $set -Encoding ascii
    foreach($win in $wins){
      $safe = ($s.ea -replace '[^A-Za-z0-9]','_'); if($safe.Length -gt 16){$safe=$safe.Substring(0,16)}
      $rep = "PLT_${safe}_$($s.param)$($v)_$($win.w)"
      powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert $s.ea -Symbol $s.sym -Period H1 -FromDate $win.f -ToDate $win.t -Model 1 -SetFile $set -ReportName $rep -TimeoutSec 900 *>> $log
      $htm = "D:\EA_LAB\_mt4_auto\reports\$rep.htm"
      if(Test-Path $htm){ try{ $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
          "`"$($s.ea)`",`"$($s.sym)`",`"$($s.param)`",$v,`"$($win.w)`",$($j.profit_factor),$($j.net_profit),$($j.max_drawdown_pct),$($j.total_trades)" | Add-Content $out
        }catch{ "`"$($s.ea)`",`"$($s.sym)`",`"$($s.param)`",$v,`"$($win.w)`",,,,PARSE_ERR"|Add-Content $out } }
      else { "`"$($s.ea)`",`"$($s.sym)`",`"$($s.param)`",$v,`"$($win.w)`",,,,NO_REPORT"|Add-Content $out }
    }
  }
}
"DEMO3 PLATEAU DONE"; Get-Content $out
