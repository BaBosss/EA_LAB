# ORDER-047 phase 1 — RSI from pips_EA breadth scan (symbol + TF) at DEFAULT params.
# Forward window 2026.03-07 M1 = guaranteed data on every symbol. Lane 1 (D:\Meta4).
# Goal: find which symbol/TF it trades AND is profitable on recently -> phase 2 BWD.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$src = "D:\Forex\10_EA_PROJECTS\2. wait for test\wait for test\RSI from pips_EA.ex4"
$dd = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$out = "D:\EA_LAB\_mt5_auto\RSI_BREADTH.csv"
$log = "D:\EA_LAB\_mt5_auto\rsi_breadth.log"
'"ea","symbol","tf","full_pf","full_trades","full_net","full_dd_pct","note"' | Out-File $out -Encoding utf8
Copy-Item -LiteralPath $src -Destination (Join-Path $dd "RSI from pips_EA.ex4") -Force

$deadline=(Get-Date).AddMinutes(5)
while((Get-Date) -lt $deadline){ $z=Get-Process terminal -ErrorAction SilentlyContinue|?{$_.Path -eq 'D:\Meta4\terminal.exe'}; if(-not $z){break}; Start-Sleep 15 }
Get-Process terminal -ErrorAction SilentlyContinue|?{$_.Path -eq 'D:\Meta4\terminal.exe'}|%{ Stop-Process -Id $_.Id -Force -Confirm:$false }

function Run-B { param([string]$Sym,[string]$TF)
  $rep="BR_RSI_${Sym}_${TF}"
  "[$(Get-Date -Format s)] RSI $Sym $TF" | Tee-Object $log -Append
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert "RSI from pips_EA" -Symbol $Sym -Period $TF -FromDate 2026.03.01 -ToDate 2026.07.01 -Model 1 -ReportName $rep -TimeoutSec 600 | Tee-Object $log -Append
  $htm="D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if(-not(Test-Path $htm)){ "`"RSI`",`"$Sym`",`"$TF`",,,,,NO_REPORT"|Add-Content $out; return }
  try{ $j=python D:\EA_LAB\scripts\parse_mt4_report.py $htm|ConvertFrom-Json
    "`"RSI`",`"$Sym`",`"$TF`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct)," | Add-Content $out
  }catch{ "`"RSI`",`"$Sym`",`"$TF`",,,,,PARSE_ERR"|Add-Content $out }
}

# symbol scan @ H1
foreach($s in 'EURUSD','USDJPY','GBPUSD','USDCAD','CHFJPY','EURGBP','EURCHF','AUDUSD','AUDCAD','XAUUSD'){ Run-B $s 'H1' }
# TF sweep on EURUSD (H1 already done above)
foreach($tf in 'M15','M30','H4'){ Run-B 'EURUSD' $tf }
"[$(Get-Date -Format s)] RSI breadth DONE -> $out" | Tee-Object $log -Append
