# ORDER-047 phase 1 (parallel) — swb grid flat-lot reserve breadth scan (symbol + TF).
# Uses swb_flat.set (lot_multiplier=0). Forward 2026.03-07 M1. Lane MT4b (D:\Meta4b portable).
# Note: MT4b may lack M1 for some symbols -> 0-trade/NO_REPORT noted, not a failure.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$src = "D:\Forex\10_EA_PROJECTS\2. wait for test\2024-06\FREE EA-20240608T074321Z-001\FREE EA\swb grid 4.1.0.3_h.ex4"
$ddexp = "D:\Meta4b\MQL4\Experts"
$setfile = "D:\EA_LAB\_mt5_auto\ab_sets\swb_flat.set"
$out = "D:\EA_LAB\_mt5_auto\SWB_BREADTH.csv"
$log = "D:\EA_LAB\_mt5_auto\swb_breadth.log"
'"ea","symbol","tf","full_pf","full_trades","full_net","full_dd_pct","note"' | Out-File $out -Encoding utf8
Copy-Item -LiteralPath $src -Destination (Join-Path $ddexp "swb grid 4.1.0.3_h.ex4") -Force

$deadline=(Get-Date).AddMinutes(5)
while((Get-Date) -lt $deadline){ $z=Get-Process terminal -ErrorAction SilentlyContinue|?{$_.Path -eq 'D:\Meta4b\terminal.exe'}; if(-not $z){break}; Start-Sleep 15 }
Get-Process terminal -ErrorAction SilentlyContinue|?{$_.Path -eq 'D:\Meta4b\terminal.exe'}|%{ Stop-Process -Id $_.Id -Force -Confirm:$false }

function Run-B { param([string]$Sym,[string]$TF)
  $rep="BR_swb_${Sym}_${TF}"
  "[$(Get-Date -Format s)] swb $Sym $TF" | Tee-Object $log -Append
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert "swb grid 4.1.0.3_h" -Symbol $Sym -Period $TF -FromDate 2026.03.01 -ToDate 2026.07.01 -Model 1 -SetFile $setfile -ReportName $rep -TimeoutSec 600 -Portable -Terminal "D:\Meta4b\terminal.exe" -InstallDir "D:\Meta4b" -DataDir "D:\Meta4b" | Tee-Object $log -Append
  $htm="D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if(-not(Test-Path $htm)){ "`"swb`",`"$Sym`",`"$TF`",,,,,NO_REPORT"|Add-Content $out; return }
  try{ $j=python D:\EA_LAB\scripts\parse_mt4_report.py $htm|ConvertFrom-Json
    "`"swb`",`"$Sym`",`"$TF`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct)," | Add-Content $out
  }catch{ "`"swb`",`"$Sym`",`"$TF`",,,,,PARSE_ERR"|Add-Content $out }
}

foreach($s in 'EURUSD','USDJPY','GBPUSD','USDCAD','CHFJPY','EURGBP','EURCHF','AUDUSD','AUDCAD','XAUUSD'){ Run-B $s 'H1' }
foreach($tf in 'M15','M30','H4'){ Run-B 'EURUSD' $tf }
"[$(Get-Date -Format s)] swb breadth DONE -> $out" | Tee-Object $log -Append
