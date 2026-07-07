# Lane-1 round 4, 2026-07-07 เย็น — spread-stress SPR30 2020-22 for the 4 EAs the
# other session queued "next session" (lane 1 free now, no reason to wait):
#   Z61 / Dark Venus / RSI from pips_EA / Yetti3_Mod2_newsWorking
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$src_base = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$dd_experts = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$out = "D:\EA_LAB\_mt5_auto\BWDOOS_MT4_ROUND4.csv"
$log = "D:\EA_LAB\_mt5_auto\lane1_round4_070707.log"
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
  param([string]$Ea, [string]$Sym, [string]$RelPath, [int]$Spread = 30, [int]$TimeoutSec = 1800, [string]$Note = "SPREAD30")
  $dstFile = Join-Path $dd_experts "$Ea.ex4"
  if (-not (Test-Path -LiteralPath $dstFile)) {
    $srcFile = Join-Path $src_base $RelPath
    if (Test-Path -LiteralPath $srcFile) { Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force }
    else { "`"$Ea`",`"$Sym`",,,,,SRC_MISSING" | Add-Content $out; return }
  }
  $safe = ($Ea -replace '[^A-Za-z0-9]','_'); if ($safe.Length -gt 36) { $safe = $safe.Substring(0,36) }
  $rep = "BWD4R4_${safe}_${Sym}_SPR$Spread"
  "[$(Get-Date -Format s)] $Ea @ $Sym (SPR$Spread)" | Tee-Object $log -Append
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert $Ea -Symbol $Sym -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 1 -Spread $Spread -ReportName $rep -TimeoutSec $TimeoutSec | Tee-Object $log -Append
  $htm = "D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if (-not (Test-Path $htm)) { "`"$Ea`",`"$Sym`",,,,,NO_REPORT$Note" | Add-Content $out; return }
  try {
    $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
    "`"$Ea`",`"$Sym`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct),$Note" | Add-Content $out
  } catch { "`"$Ea`",`"$Sym`",,,,,PARSE_ERR$Note" | Add-Content $out }
}

Run-One -Ea "RSI from pips_EA" -Sym "EURUSD" -RelPath "wait for test\RSI from pips_EA.ex4"
Run-One -Ea "Dark Venus" -Sym "EURUSD" -RelPath "wait for test\test 3\Dark\Dark Venus.ex4"
Run-One -Ea "Z61" -Sym "EURUSD" -RelPath "2026-07\Z61.ex4"
Run-One -Ea "Yetti3_Mod2_newsWorking" -Sym "EURUSD" -RelPath "wait for test\test 3\Yetti\Yetti3_Mod2_newsWorking.ex4"

"[$(Get-Date -Format s)] round 4 DONE -> $out" | Tee-Object $log -Append
