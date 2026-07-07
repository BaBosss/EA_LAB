# Lane-1 round 5 (final), 2026-07-07 ค่ำ — RSI from pips_EA last gates:
#   Model-0 every-tick backward 2020-22 + forward 2026.03-07
#   (same final ladder UnNomGuai went through)
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$src_base = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$dd_experts = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$out = "D:\EA_LAB\_mt5_auto\BWDOOS_MT4_ROUND5.csv"
$log = "D:\EA_LAB\_mt5_auto\lane1_round5_070707.log"
'"ea","symbol","full_pf","full_trades","full_net","full_dd_pct","note"' | Out-File $out -Encoding utf8

$deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
  $z = Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' }
  if (-not $z) { break }
  Start-Sleep -Seconds 15
}
Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' } |
  ForEach-Object { "[preflight] killing leftover terminal PID $($_.Id)" | Tee-Object $log -Append; Stop-Process -Id $_.Id -Force -Confirm:$false }

function Run-One {
  param([string]$Ea, [string]$Sym, [string]$RelPath, [string]$From, [string]$To, [string]$Rep, [string]$Note)
  $dstFile = Join-Path $dd_experts "$Ea.ex4"
  if (-not (Test-Path -LiteralPath $dstFile)) {
    $srcFile = Join-Path $src_base $RelPath
    if (Test-Path -LiteralPath $srcFile) { Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force }
    else { "`"$Ea`",`"$Sym`",,,,,SRC_MISSING" | Add-Content $out; return }
  }
  "[$(Get-Date -Format s)] $Ea @ $Sym ($From..$To Model 0)" | Tee-Object $log -Append
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert $Ea -Symbol $Sym -Period H1 -FromDate $From -ToDate $To -Model 0 -ReportName $Rep -TimeoutSec 1800 | Tee-Object $log -Append
  $htm = "D:\EA_LAB\_mt4_auto\reports\$Rep.htm"
  if (-not (Test-Path $htm)) { "`"$Ea`",`"$Sym`",,,,,NO_REPORT$Note" | Add-Content $out; return }
  try {
    $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
    "`"$Ea`",`"$Sym`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct),$Note" | Add-Content $out
  } catch { "`"$Ea`",`"$Sym`",,,,,PARSE_ERR$Note" | Add-Content $out }
}

Run-One -Ea "RSI from pips_EA" -Sym "EURUSD" -RelPath "wait for test\RSI from pips_EA.ex4" -From "2020.01.01" -To "2023.01.01" -Rep "BWD4R5_RSI_from_pips_EA_EURUSD_M0" -Note "MODEL0-BWD"
Run-One -Ea "RSI from pips_EA" -Sym "EURUSD" -RelPath "wait for test\RSI from pips_EA.ex4" -From "2026.03.01" -To "2026.07.01" -Rep "BWD4R5_RSI_from_pips_EA_EURUSD_M0_FWD" -Note "MODEL0-FWD"

"[$(Get-Date -Format s)] round 5 DONE -> $out" | Tee-Object $log -Append
