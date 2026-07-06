# BWD-OOS sweep: run backward-OOS 2020-2022 (Model 1) on every remaining ORDER-035 Tier A/B survivor.
# Rule (2026-07-06): backward-OOS is the FIRST gate for every Tier A - kills regime harvesters in 1 run.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$csv = Import-Csv "D:\EA_LAB\_mt5_auto\mass_smoke_mt5.csv"
$judged = @('(oh) pun fix lot v05','EA_GapinFX_MT5','North East Way MT5 v1.309_fix','Breakout Retest Pro EA Source Code (1)')
$surv = $csv | Where-Object { $_.tier -match 'Tier' -and $judged -notcontains $_.ea }
# unique EA -> best-PF symbol row
$targets = $surv | Group-Object ea | ForEach-Object {
  $_.Group | Sort-Object { [double]$_.m1_pf } -Descending | Select-Object -First 1 }

$out = "D:\EA_LAB\_mt5_auto\BWDOOS_SWEEP.csv"
"ea,symbol,y2020_pf,y2021_pf,y2022_pf,full_pf,full_net,full_baldd,eqdd_max,note" | Out-File $out -Encoding utf8
$i=0; $n=($targets|Measure-Object).Count
foreach ($t in $targets) {
  $i++
  $safe = ($t.ea -replace '[^A-Za-z0-9]','_')
  $rep = "BWD_$safe"
  Write-Output "[$i/$n] $($t.ea) @ $($t.symbol)"
  powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "_smoke\$($t.ea)" -Symbol $t.symbol -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 1 -ReportName $rep -TimeoutSec 600 -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable | Out-Null
  $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
  if (-not (Test-Path $htm)) { "$($t.ea),$($t.symbol),,,,,,,,NO_REPORT" | Add-Content $out; continue }
  try {
    $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm --json | ConvertFrom-Json
    $ys = python D:\EA_LAB\scripts\report_year_split.py $htm | Out-String
    $pf = @{}
    foreach ($ln in ($ys -split "`n")) {
      if ($ln -match '^\s+(20\d\d)\s+trades=\s*\d+\s+PF=\s*([\d.]+|inf)') { $pf[$Matches[1]] = $Matches[2] }
    }
    "$($t.ea),$($t.symbol),$($pf['2020']),$($pf['2021']),$($pf['2022']),$($j.profit_factor),$($j.net_profit),$($j.balance_drawdown_maximal_pct),$($j.equity_drawdown_maximal_pct)," | Add-Content $out
  } catch { "$($t.ea),$($t.symbol),,,,,,,,PARSE_ERR" | Add-Content $out }
}
Write-Output "SWEEP DONE -> $out"
