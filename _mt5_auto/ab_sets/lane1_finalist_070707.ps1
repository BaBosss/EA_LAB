# Lane-1 finalist round 2026-07-07 เย็น (after resurrect sweep verdicts):
#   1. UnNomGuai Model-0 every-tick 2020-22  (passed BWD+lot+spread -> last cage)
#   2. spread-stress SPR30 2020-22 for the 5 new BWD survivors:
#      Yetti3+NewsSherry / EAForexTH_MultiHedge / Oracle EA / EAForexTH_Scalper_S3
#      (absurd-PF flag - spread+tick-model artifact suspect) / Expert (weak PF 1.11)
#   3. retries with TimeoutSec 1800: TradePad BWD (timed out 902s twice),
#      VisualMartiEA BWD (timed out 902s)
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$src_base = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$dd_experts = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$out = "D:\EA_LAB\_mt5_auto\BWDOOS_MT4_FINALIST.csv"
$log = "D:\EA_LAB\_mt5_auto\lane1_finalist_070707.log"
'"ea","symbol","full_pf","full_trades","full_net","full_dd_pct","note"' | Out-File $out -Encoding utf8

# preflight: wait for lane then kill leftover (same rationale as resurrect sweep)
$deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
  $z = Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' }
  if (-not $z) { break }
  Start-Sleep -Seconds 15
}
Get-Process terminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta4\terminal.exe' } |
  ForEach-Object { "[preflight] killing leftover terminal PID $($_.Id)" | Tee-Object $log -Append; Stop-Process -Id $_.Id -Force -Confirm:$false }

function Run-Bwd {
  param([string]$Ea, [string]$Sym, [string]$RelPath, [int]$Spread = 0, [int]$Model = 1, [int]$TimeoutSec = 900, [string]$Note = "")
  $dstFile = Join-Path $dd_experts "$Ea.ex4"
  if (-not (Test-Path -LiteralPath $dstFile)) {
    $srcFile = Join-Path $src_base $RelPath
    if (Test-Path -LiteralPath $srcFile) { Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force }
    else { "`"$Ea`",`"$Sym`",,,,,SRC_MISSING" | Add-Content $out; return }
  }
  $safe = ($Ea -replace '[^A-Za-z0-9]','_'); if ($safe.Length -gt 40) { $safe = $safe.Substring(0,40) }
  $rep = "BWD4FIN_${safe}_$Sym"
  if ($Spread -gt 0) { $rep += "_SPR$Spread" }
  if ($Model -ne 1) { $rep += "_M$Model" }
  "[$(Get-Date -Format s)] $Ea @ $Sym (model=$Model spread=$Spread)" | Tee-Object $log -Append
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert $Ea -Symbol $Sym -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model $Model -Spread $Spread -ReportName $rep -TimeoutSec $TimeoutSec | Tee-Object $log -Append
  $htm = "D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if (-not (Test-Path $htm)) { "`"$Ea`",`"$Sym`",,,,,NO_REPORT$Note" | Add-Content $out; return }
  try {
    $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
    "`"$Ea`",`"$Sym`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct),$Note" | Add-Content $out
  } catch { "`"$Ea`",`"$Sym`",,,,,PARSE_ERR$Note" | Add-Content $out }
}

Run-Bwd -Ea "UnNomGuaiV1.132" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\UnNomGuaiV1.132.ex4" -Model 0 -TimeoutSec 1800 -Note "MODEL0"
Run-Bwd -Ea "Yetti3+NewsSherry" -Sym "EURUSD" -RelPath "2024-06\Yetti3+NewsSherry\Yetti3+NewsSherry.ex4" -Spread 30 -Note "SPREAD30"
Run-Bwd -Ea "EAForexTH_MultiHedge_1.0" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\EAForexTH_MultiHedge_1.0.ex4" -Spread 30 -Note "SPREAD30"
Run-Bwd -Ea "Oracle EA" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\Oracle EA.ex4" -Spread 30 -Note "SPREAD30"
Run-Bwd -Ea "EAForexTH_Scalper_S3_1.0" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\EAForexTH_Scalper_S3_1.0.ex4" -Spread 30 -Note "SPREAD30"
Run-Bwd -Ea "Expert" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\Expert.ex4" -Spread 30 -Note "SPREAD30"
Run-Bwd -Ea "TradePad_Current_Timeframe" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\TradePad_Current_Timeframe.ex4" -TimeoutSec 1800 -Note "RETRY1800"
Run-Bwd -Ea "VisualMartiEA" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\VisualMartiEA.ex4" -TimeoutSec 1800 -Note "RETRY1800"

"[$(Get-Date -Format s)] finalist round DONE -> $out" | Tee-Object $log -Append
