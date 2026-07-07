# Lane-1 last BWD-OOS chain 2026-07-07 late afternoon:
#   step 1: Z61 (batch 24 candidate) BWD-OOS 2020-2022, both symbols
#   step 2: batch-27's 4 candidates (Dark Mimas, Dark Venus, RSI from
#           pips_EA, Yetti3_Mod2_newsWorking) via bwdoos_mt4_sweep_b27.ps1
#           (already fixed to target lane 1)
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$log = "D:\EA_LAB\_mt5_auto\lane1_last_bwd_070707.log"
"[$(Get-Date -Format s)] lane-1 last-bwd chain start" | Tee-Object $log -Append

$src_base = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$dd_experts = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$out = "D:\EA_LAB\_mt5_auto\BWDOOS_MT4_Z61.csv"
'"ea","symbol","full_pf","full_trades","full_net","full_dd_pct","note"' | Out-File $out -Encoding utf8

function Run-Bwd {
  param([string]$Ea, [string]$Sym, [string]$RelPath, [string]$Rep)
  $dstFile = Join-Path $dd_experts "$Ea.ex4"
  if (-not (Test-Path -LiteralPath $dstFile)) {
    $srcFile = Join-Path $src_base $RelPath
    if (Test-Path -LiteralPath $srcFile) { Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force }
    else { "`"$Ea`",`"$Sym`",,,,,SRC_MISSING" | Add-Content $out; return }
  }
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert $Ea -Symbol $Sym -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 1 -ReportName $Rep -TimeoutSec 900 | Tee-Object $log -Append
  $htm = "D:\EA_LAB\_mt4_auto\reports\$Rep.htm"
  if (-not (Test-Path $htm)) { "`"$Ea`",`"$Sym`",,,,,NO_REPORT" | Add-Content $out; return }
  try {
    $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
    "`"$Ea`",`"$Sym`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct)," | Add-Content $out
  } catch { "`"$Ea`",`"$Sym`",,,,,PARSE_ERR" | Add-Content $out }
}

"[$(Get-Date -Format s)] step 1: Z61 BWD-OOS" | Tee-Object $log -Append
Run-Bwd -Ea "Z61" -Sym "EURUSD" -RelPath "2026-07\Z61.ex4" -Rep "BWD4Z61_EURUSD"
Run-Bwd -Ea "Z61" -Sym "USDJPY" -RelPath "2026-07\Z61.ex4" -Rep "BWD4Z61_USDJPY"

"[$(Get-Date -Format s)] step 2: batch-27 candidates BWD-OOS" | Tee-Object $log -Append
powershell -File D:\EA_LAB\_mt5_auto\ab_sets\bwdoos_mt4_sweep_b27.ps1 | Tee-Object $log -Append

"[$(Get-Date -Format s)] lane-1 last-bwd chain DONE" | Tee-Object $log -Append
