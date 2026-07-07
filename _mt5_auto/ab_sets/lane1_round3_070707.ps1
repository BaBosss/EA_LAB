# Lane-1 round 3, 2026-07-07 ค่ำ (after finalist verdicts):
#   1. Z61 (batch-24 candidate) BWD 2020-22 EU+JP
#   2. Model-0 every-tick 2020-22: Oracle EA + EAForexTH_MultiHedge (passed spread)
#   3. Scalper_S3 Model-0 default-spread (artifact test - it has a spread filter,
#      0 trades at SPR30, so every-tick PF collapse = tick artifact verdict)
#   4. UnNomGuai forward-window Model-0 (2026.03-07) - confirm current regime on every-tick
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$src_base = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$dd_experts = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$out = "D:\EA_LAB\_mt5_auto\BWDOOS_MT4_ROUND3.csv"
$log = "D:\EA_LAB\_mt5_auto\lane1_round3_070707.log"
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
  param([string]$Ea, [string]$Sym, [string]$RelPath, [string]$From = "2020.01.01", [string]$To = "2023.01.01",
        [int]$Spread = 0, [int]$Model = 1, [int]$TimeoutSec = 1800, [string]$Note = "")
  $dstFile = Join-Path $dd_experts "$Ea.ex4"
  if (-not (Test-Path -LiteralPath $dstFile)) {
    $srcFile = Join-Path $src_base $RelPath
    if (Test-Path -LiteralPath $srcFile) { Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force }
    else { "`"$Ea`",`"$Sym`",,,,,SRC_MISSING" | Add-Content $out; return }
  }
  $safe = ($Ea -replace '[^A-Za-z0-9]','_'); if ($safe.Length -gt 36) { $safe = $safe.Substring(0,36) }
  $rep = "BWD4R3_${safe}_$Sym"
  if ($Spread -gt 0) { $rep += "_SPR$Spread" }
  if ($Model -ne 1) { $rep += "_M$Model" }
  if ($From -ne "2020.01.01") { $rep += "_FWD" }
  "[$(Get-Date -Format s)] $Ea @ $Sym ($From..$To model=$Model spread=$Spread)" | Tee-Object $log -Append
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert $Ea -Symbol $Sym -Period H1 -FromDate $From -ToDate $To -Model $Model -Spread $Spread -ReportName $rep -TimeoutSec $TimeoutSec | Tee-Object $log -Append
  $htm = "D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if (-not (Test-Path $htm)) { "`"$Ea`",`"$Sym`",,,,,NO_REPORT$Note" | Add-Content $out; return }
  try {
    $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
    "`"$Ea`",`"$Sym`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct),$Note" | Add-Content $out
  } catch { "`"$Ea`",`"$Sym`",,,,,PARSE_ERR$Note" | Add-Content $out }
}

Run-One -Ea "Z61" -Sym "EURUSD" -RelPath "2026-07\Z61.ex4" -Note "BWD"
Run-One -Ea "Z61" -Sym "USDJPY" -RelPath "2026-07\Z61.ex4" -Note "BWD"
Run-One -Ea "Oracle EA" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\Oracle EA.ex4" -Model 0 -Note "MODEL0"
Run-One -Ea "EAForexTH_MultiHedge_1.0" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\EAForexTH_MultiHedge_1.0.ex4" -Model 0 -Note "MODEL0"
Run-One -Ea "EAForexTH_Scalper_S3_1.0" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\EAForexTH_Scalper_S3_1.0.ex4" -Model 0 -Note "MODEL0-ARTIFACT-TEST"
Run-One -Ea "UnNomGuaiV1.132" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\UnNomGuaiV1.132.ex4" -From "2026.03.01" -To "2026.07.01" -Model 0 -Note "MODEL0-FWD"

"[$(Get-Date -Format s)] round 3 DONE -> $out" | Tee-Object $log -Append
