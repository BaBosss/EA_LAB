<#
basket_earun_gsmc_corr.ps1
Computes IS monthly P&L correlation between:
  A) EA_RUNNER_v1 (Donchian breakout, XAUUSD H1, Bars=55)
  B) Gold_SMC_Run004 (mean-reversion, XAUUSD H1)
Both run IS 2023.01 - 2026.05.
#>
$ErrorActionPreference = "Stop"

$RunnerHtm = "D:\EA_LAB\_mt5_auto\reports\EA_RUNNER_v1_bars55_PG_IS.htm"
$GsmcCsv   = "D:\EA_LAB\_mt5_auto\GSMC_locked_IS_trades.csv"

# ── EA_RUNNER_v1: parse Deals table (13-column HTML rows, cell[4]='out') ──────
function Get-RunnerMonthly($htm) {
    $text = [IO.File]::ReadAllText($htm)
    $rows = [regex]::Matches($text, '<tr[^>]*>(.*?)</tr>', 'Singleline,IgnoreCase')
    $map  = @{}
    foreach ($row in $rows) {
        $cells = [regex]::Matches($row.Groups[1].Value, '<td[^>]*>(.*?)</td>', 'Singleline,IgnoreCase') |
                 ForEach-Object { $_.Groups[1].Value -replace '<[^>]+>','' -replace '&nbsp;',' ' | ForEach-Object { $_.Trim() } }
        $arr = @($cells)
        if ($arr.Count -ne 13) { continue }
        if ($arr[4] -ne 'out') { continue }
        if ($arr[0] -notmatch '(\d{4}\.\d{2})') { continue }
        $month = $Matches[1]
        $profit = 0.0
        foreach ($ci in 8,9,10) {
            $v = ($arr[$ci] -replace '\s','') -replace '[^\d\.\-]',''
            if ($v -match '^-?\d+\.?\d*$') { $profit += [double]$v }
        }
        if (-not $map.ContainsKey($month)) { $map[$month] = 0.0 }
        $map[$month] += $profit
    }
    return $map
}

# ── GSMC: aggregate trade CSV (time,profit) to monthly ───────────────────────
function Get-GsmcMonthly($csv) {
    $map = @{}
    Import-Csv $csv | ForEach-Object {
        $t = $_.time
        if ($t -match '(\d{4}\.\d{2})') {
            $month = $Matches[1]
            if (-not $map.ContainsKey($month)) { $map[$month] = 0.0 }
            $map[$month] += [double]$_.profit
        }
    }
    return $map
}

# ── Pearson r ─────────────────────────────────────────────────────────────────
function Get-Pearson($xMap, $yMap) {
    $keys = ($xMap.Keys + $yMap.Keys) | Sort-Object -Unique
    $xs = @(); $ys = @()
    foreach ($k in $keys) {
        $xv = if ($xMap.ContainsKey($k)) { $xMap[$k] } else { 0.0 }
        $yv = if ($yMap.ContainsKey($k)) { $yMap[$k] } else { 0.0 }
        $xs += $xv; $ys += $yv
    }
    $n  = $xs.Count
    $mx = ($xs | Measure-Object -Average).Average
    $my = ($ys | Measure-Object -Average).Average
    $num = 0.0; $dx2 = 0.0; $dy2 = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $dx = $xs[$i] - $mx; $dy = $ys[$i] - $my
        $num  += $dx * $dy
        $dx2  += $dx * $dx
        $dy2  += $dy * $dy
    }
    $dg = [Math]::Sqrt($dx2 * $dy2)
    $r  = if ($dg -gt 1e-12) { $num / $dg } else { 0.0 }
    return [pscustomobject]@{ r=$r; n=$n; months=$keys }
}

# ── Run ───────────────────────────────────────────────────────────────────────
Write-Host "Parsing EA_RUNNER_v1 IS HTML..."
$runnerMap = Get-RunnerMonthly $RunnerHtm

Write-Host "Aggregating GSMC IS CSV..."
$gsmcMap   = Get-GsmcMonthly  $GsmcCsv

Write-Host ""
Write-Host "=== Monthly P&L (side-by-side) ==="
$allMonths = ($runnerMap.Keys + $gsmcMap.Keys) | Sort-Object -Unique
foreach ($m in $allMonths) {
    $r = if ($runnerMap.ContainsKey($m)) { "{0,9:F2}" -f $runnerMap[$m] } else { "     0.00" }
    $g = if ($gsmcMap.ContainsKey($m))   { "{0,9:F2}" -f $gsmcMap[$m]   } else { "     0.00" }
    Write-Host "$m  Runner=$r  GSMC=$g"
}

Write-Host ""
$stat = Get-Pearson $runnerMap $gsmcMap

$verdict = if     ($stat.r -le 0.40) { "ADDITIVE ✅" }
           elseif ($stat.r -le 0.60) { "WATCH ⚠️" }
           else                       { "REDUNDANT ❌" }

Write-Host ("IS Pearson r = {0:F3}  (n={1} months)  -> {2}" -f $stat.r, $stat.n, $verdict)

# ── Portfolio combined stats ──────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Combined portfolio stats (Runner 0.01 lot + GSMC 0.01 lot) ==="
$combinedPnl = @()
foreach ($m in $allMonths) {
    $rv = if ($runnerMap.ContainsKey($m)) { $runnerMap[$m] } else { 0.0 }
    $gv = if ($gsmcMap.ContainsKey($m))   { $gsmcMap[$m]   } else { 0.0 }
    $combinedPnl += ($rv + $gv)
}
$n    = $combinedPnl.Count
$mean = ($combinedPnl | Measure-Object -Average).Average
$std  = [Math]::Sqrt( ($combinedPnl | ForEach-Object { ($_ - $mean)*($_ - $mean) } | Measure-Object -Sum).Sum / [Math]::Max($n-1,1) )
# @() here is DEFENSIVE, not a bug fix, and an earlier version of this comment claimed otherwise.
# CORRECTED 2026-07-28 after a blind audit: the "single match yields $null .Count" trap is real for
# pipelines that emit OBJECTS (PSCustomObject from Where-Object returns $null on exactly one match -
# measured), but $combinedPnl holds NUMBERS, and in PS 5.1 a scalar Int32/Double exposes a synthetic
# .Count of 1. So the 0%-win-rate failure the previous comment described could not have happened
# here. The wrapper stays because it costs nothing and makes the count correct for either shape;
# the claim that it repaired a live defect was wrong and is withdrawn.
$wins = @($combinedPnl | Where-Object { $_ -gt 0 }).Count
$wr   = $wins / $n * 100
$sharpe = if ($std -gt 0) { $mean / $std * [Math]::Sqrt(12) } else { 0.0 }
$total = ($combinedPnl | Measure-Object -Sum).Sum

Write-Host ("Total: {0:F2}  Mean/mo: {1:F2}  Std: {2:F2}  WinRate: {3:F1}%  Sharpe: {4:F2}" -f $total, $mean, $std, $wr, $sharpe)
Write-Host ("Runner alone: {0:F2}  GSMC alone: {1:F2}" -f ($runnerMap.Values | Measure-Object -Sum).Sum, ($gsmcMap.Values | Measure-Object -Sum).Sum)
