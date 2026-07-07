# Lane-1 chain 2026-07-07 (day-run resume after interrupted sweep):
#   step 1: TradePad_Current_Timeframe BWD-OOS 2020-22 (was cut off from b2021 sweep)
#   step 2: UnNomGuaiV1.132 spread-stress (Spread=30 pts) on same BWD window
#   step 3: mass-smoke batch 22 (lane 1)
# Appends to BWDOOS_MT4_B2021.csv (no header rewrite).
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$log = "D:\EA_LAB\_mt5_auto\lane1_chain_070707.log"
"[$(Get-Date -Format s)] lane-1 chain start" | Tee-Object $log -Append

$src_base = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$dd_experts = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$out = "D:\EA_LAB\_mt5_auto\BWDOOS_MT4_B2021.csv"

function Run-Bwd {
  param([string]$Ea, [string]$Sym, [string]$RelPath, [string]$Rep, [int]$Spread = 0, [string]$Note = "")
  $dstFile = Join-Path $dd_experts "$Ea.ex4"
  if (-not (Test-Path -LiteralPath $dstFile)) {
    $srcFile = Join-Path $src_base $RelPath
    if (Test-Path -LiteralPath $srcFile) { Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force }
    else { "`"$Ea`",`"$Sym`",,,,,SRC_MISSING" | Add-Content $out; return }
  }
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert $Ea -Symbol $Sym -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 1 -Spread $Spread -ReportName $Rep -TimeoutSec 900 | Tee-Object $log -Append
  $htm = "D:\EA_LAB\_mt4_auto\reports\$Rep.htm"
  if (-not (Test-Path $htm)) { "`"$Ea`",`"$Sym`",,,,,NO_REPORT$Note" | Add-Content $out; return }
  try {
    $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
    "`"$Ea`",`"$Sym`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct),$Note" | Add-Content $out
  } catch { "`"$Ea`",`"$Sym`",,,,,PARSE_ERR$Note" | Add-Content $out }
}

"[$(Get-Date -Format s)] step 1: TradePad BWD-OOS" | Tee-Object $log -Append
Run-Bwd -Ea "TradePad_Current_Timeframe" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\TradePad_Current_Timeframe.ex4" -Rep "BWD4B2021_TradePad_Current_Timeframe_EURUSD"

"[$(Get-Date -Format s)] step 2: UnNomGuai spread-stress 30pts" | Tee-Object $log -Append
Run-Bwd -Ea "UnNomGuaiV1.132" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\UnNomGuaiV1.132.ex4" -Rep "BWD4B2021_UnNomGuai_EU_SPR30" -Spread 30 -Note "SPREAD30"

"[$(Get-Date -Format s)] step 3: mass-smoke batch 22 (lane 1)" | Tee-Object $log -Append
powershell -File D:\EA_LAB\scripts\mass_smoke_mt4.ps1 -Batch 22 | Tee-Object $log -Append

"[$(Get-Date -Format s)] lane-1 chain DONE" | Tee-Object $log -Append
