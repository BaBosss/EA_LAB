# ORDER-047 phase 3 — swb flat-lot on its BWD-surviving symbols (AUDCAD/AUDUSD/XAUUSD):
# spread-stress SPR30 + Model-0 every-tick, 2020-22. This is the gate swb-EURUSD died at
# (M0 DD 42%). If AUDCAD (BWD DD 8.63%, ladder x3) holds < 40% here, swb revives on AUDCAD.
# RSI from pips = NOT run: phase-2 BWD proved it is EURUSD-specific (all other symbols DD 50%+,
# ladder x11-19 in trend years) - already fully validated at defaults on EURUSD, no black-box
# optimize (overfit risk >> marginal gain on a no-source binary).
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$dd = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$swb_src = "D:\Forex\10_EA_PROJECTS\2. wait for test\2024-06\FREE EA-20240608T074321Z-001\FREE EA\swb grid 4.1.0.3_h.ex4"
$swb_set = "D:\EA_LAB\_mt5_auto\ab_sets\swb_flat.set"
$out = "D:\EA_LAB\_mt5_auto\ORDER047_PHASE3.csv"
$log = "D:\EA_LAB\_mt5_auto\order047_phase3.log"
'"ea","symbol","full_pf","full_trades","full_net","full_dd_pct","note"' | Out-File $out -Encoding utf8
Copy-Item -LiteralPath $swb_src -Destination (Join-Path $dd "swb grid 4.1.0.3_h.ex4") -Force

$deadline=(Get-Date).AddMinutes(5)
while((Get-Date) -lt $deadline){ $z=Get-Process terminal -ErrorAction SilentlyContinue|?{$_.Path -eq 'D:\Meta4\terminal.exe'}; if(-not $z){break}; Start-Sleep 15 }
Get-Process terminal -ErrorAction SilentlyContinue|?{$_.Path -eq 'D:\Meta4\terminal.exe'}|%{ Stop-Process -Id $_.Id -Force -Confirm:$false }

function Run-Gate { param([string]$Sym,[int]$Spread,[int]$Model,[string]$Tag)
  $rep="O47P3_swb_${Sym}_${Tag}"
  "[$(Get-Date -Format s)] swb $Sym $Tag" | Tee-Object $log -Append
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert "swb grid 4.1.0.3_h" -Symbol $Sym -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model $Model -Spread $Spread -SetFile $swb_set -ReportName $rep -TimeoutSec 1800 | Tee-Object $log -Append
  $htm="D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if(-not(Test-Path $htm)){ "`"swb`",`"$Sym`",,,,,NO_REPORT-$Tag"|Add-Content $out; return }
  try{ $j=python D:\EA_LAB\scripts\parse_mt4_report.py $htm|ConvertFrom-Json
    "`"swb`",`"$Sym`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct),$Tag"|Add-Content $out
  }catch{ "`"swb`",`"$Sym`",,,,,PARSE_ERR-$Tag"|Add-Content $out }
}

# spread-stress first (cheapest kill), then Model-0 for whichever look alive
foreach($s in 'AUDCAD','AUDUSD','XAUUSD'){ Run-Gate $s 30 1 'SPR30' }
foreach($s in 'AUDCAD','AUDUSD','XAUUSD'){ Run-Gate $s 0 0 'M0' }
"[$(Get-Date -Format s)] ORDER-047 phase 3 DONE -> $out" | Tee-Object $log -Append
