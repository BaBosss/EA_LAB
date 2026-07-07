# BWD-OOS 2020-2022 sweep of RESURRECTED candidates (2026-07-07 lot-check audit:
# the old quick-grep matched Profit/Balance cells -> ~15 false AUTO-REJECTs in
# batches 12-19; true Size-column ratios all <10x for these. See
# ORDER-036_MT4_MASS_SMOKE.md "Lot-check audit 2026-07-07".)
# Also includes spread-stress (Spread=30 pts) for the two already-BWD-passed
# resurrections: 2020v2 (b05, PF 2.26 DD 6.3%) + Automated Forex Grail (b10,
# PF 1.53 DD 33%). Lane 1 (D:\Meta4). Run AFTER lane1_chain_070707 finishes.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$src_base = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$dd_experts = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$out = "D:\EA_LAB\_mt5_auto\BWDOOS_MT4_RESURRECT.csv"
$log = "D:\EA_LAB\_mt5_auto\bwdoos_resurrect.log"
'"ea","symbol","full_pf","full_trades","full_net","full_dd_pct","note"' | Out-File $out -Encoding utf8

function Run-Bwd {
  param([string]$Ea, [string]$Sym, [string]$RelPath, [int]$Spread = 0, [string]$Note = "")
  $dstFile = Join-Path $dd_experts "$Ea.ex4"
  if (-not (Test-Path -LiteralPath $dstFile)) {
    $srcFile = Join-Path $src_base $RelPath
    if (Test-Path -LiteralPath $srcFile) { Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force }
    else { "`"$Ea`",`"$Sym`",,,,,SRC_MISSING" | Add-Content $out; return }
  }
  $safe = ($Ea -replace '[^A-Za-z0-9]','_'); if ($safe.Length -gt 40) { $safe = $safe.Substring(0,40) }
  $rep = "BWD4RES_${safe}_$Sym"; if ($Spread -gt 0) { $rep += "_SPR$Spread" }
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert $Ea -Symbol $Sym -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 1 -Spread $Spread -ReportName $rep -TimeoutSec 900 | Tee-Object $log -Append
  $htm = "D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if (-not (Test-Path $htm)) { "`"$Ea`",`"$Sym`",,,,,NO_REPORT$Note" | Add-Content $out; return }
  try {
    $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
    "`"$Ea`",`"$Sym`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct),$Note" | Add-Content $out
  } catch { "`"$Ea`",`"$Sym`",,,,,PARSE_ERR$Note" | Add-Content $out }
}

"[$(Get-Date -Format s)] resurrect sweep start" | Tee-Object $log -Append

# --- spread-stress for already-BWD-passed resurrections (highest priority) ---
Run-Bwd -Ea "2020v2" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\2020v2.ex4" -Spread 30 -Note "SPREAD30"
Run-Bwd -Ea "2020v2" -Sym "USDJPY" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\2020v2.ex4" -Spread 30 -Note "SPREAD30"
Run-Bwd -Ea "Automated Forex Grail" -Sym "EURUSD" -RelPath "2024-06\FREE EA-20240608T074321Z-001\FREE EA\Automated Forex Grail.ex4" -Spread 30 -Note "SPREAD30"

# --- BWD-OOS for false-reject resurrections (strongest first) ---
$targets = Import-Csv "D:\EA_LAB\_mt5_auto\ab_sets\bwd_mt4_targets_resurrect.csv"
$i = 0; $n = ($targets | Measure-Object).Count
foreach ($t in $targets) {
  $i++
  "[$(Get-Date -Format s)] [$i/$n] $($t.ea) @ $($t.symbol)" | Tee-Object $log -Append
  Run-Bwd -Ea $t.ea -Sym $t.symbol -RelPath $t.path
}
"[$(Get-Date -Format s)] resurrect sweep DONE -> $out" | Tee-Object $log -Append
