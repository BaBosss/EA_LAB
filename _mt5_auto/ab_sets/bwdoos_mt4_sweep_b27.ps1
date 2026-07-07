# BWD-OOS 2020-2022 sweep of 036 batch-27 Tier A survivors (lot-check already
# passed clean, ratios 3x-6x, no grid signature). Lane 1 (D:\Meta4) ONLY - lane
# MT4b (D:\Meta4b) does not have 2020-2022 history loaded (confirmed 2026-07-07:
# every test there exits instantly with NO REPORT despite launching fine - it's
# a portable copy set up for the recent-4mo smoke basket only). All BWD-OOS/
# backward work must run on lane 1.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$src_base = "D:\Forex\10_EA_PROJECTS\2. wait for test"
$dd_experts = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$targets = Import-Csv "D:\EA_LAB\_mt5_auto\ab_sets\bwd_mt4_targets_b27.csv"
$out = "D:\EA_LAB\_mt5_auto\BWDOOS_MT4_B27.csv"
'"ea","symbol","full_pf","full_trades","full_net","full_dd_pct","note"' | Out-File $out -Encoding utf8

$i=0; $n=($targets|Measure-Object).Count
foreach ($t in $targets) {
  $i++
  Write-Output "[$i/$n] $($t.ea) @ $($t.symbol)"
  $srcFile = Join-Path $src_base $t.path
  $dstFile = Join-Path $dd_experts "$($t.ea).ex4"
  if (-not (Test-Path -LiteralPath $dstFile)) {
    if (Test-Path -LiteralPath $srcFile) { Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force }
    else { "`"$($t.ea)`",`"$($t.symbol)`",,,,,SRC_MISSING" | Add-Content $out; continue }
  }
  $safe = ($t.ea -replace '[^A-Za-z0-9]','_'); if ($safe.Length -gt 40) { $safe = $safe.Substring(0,40) }
  $rep = "BWD4B27_${safe}_$($t.symbol)"
  powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert $t.ea -Symbol $t.symbol -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 1 -ReportName $rep -TimeoutSec 900
  $htm = "D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if (-not (Test-Path $htm)) { "`"$($t.ea)`",`"$($t.symbol)`",,,,,NO_REPORT" | Add-Content $out; continue }
  try {
    $j = python D:\EA_LAB\scripts\parse_mt4_report.py $htm | ConvertFrom-Json
    "`"$($t.ea)`",`"$($t.symbol)`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct)," | Add-Content $out
  } catch { "`"$($t.ea)`",`"$($t.symbol)`",,,,,PARSE_ERR" | Add-Content $out }
}
Write-Output "MT4 BWD SWEEP B27 (lane 1) DONE -> $out"
