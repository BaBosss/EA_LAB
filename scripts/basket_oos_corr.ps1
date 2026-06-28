<#
basket_oos_corr.ps1 — parse OOS HTML Deals tables for GSMC + MG, compute monthly PnL correlation.
Run after mt5_run.ps1 has completed both OOS backtests.
Reports expected:
  D:\EA_LAB\_mt5_auto\reports\GSMC_run004_OOS_corr.htm
  D:\EA_LAB\_mt5_auto\reports\MG_CHFJPY_OOS_corr.htm
#>
param(
    [string]$GsmcHtm = "D:\EA_LAB\_mt5_auto\reports\GSMC_run004_OOS_corr.htm",
    [string]$MgHtm   = "D:\EA_LAB\_mt5_auto\reports\MG_CHFJPY_OOS_corr.htm"
)

function Extract-Monthly($path) {
    if (-not (Test-Path $path)) { throw "File not found: $path" }
    $text = [IO.File]::ReadAllText($path, [Text.Encoding]::Unicode)
    $map  = @{}
    $rows = [regex]::Matches($text, '<tr[^>]*>(.*?)</tr>', 'Singleline,IgnoreCase')
    foreach ($row in $rows) {
        $cells = [regex]::Matches($row.Groups[1].Value, '<td[^>]*>(.*?)</td>', 'Singleline,IgnoreCase') |
                 ForEach-Object { [regex]::Replace($_.Groups[1].Value, '<[^>]+>', '').Trim() }
        $arr = @($cells)
        # Standard MT5 13-col Deals table: col[4]='out', col[0]=time, col[8..10]=comm+swap+profit
        if ($arr.Count -ne 13 -or $arr[4] -ne 'out') { continue }
        if ($arr[0] -notmatch '(\d{4}\.\d{2})') { continue }
        $month  = $Matches[1]
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

function Pearson($g, $m, $months) {
    $n = $months.Count; if ($n -lt 3) { return 0.0 }
    $gv = $months | ForEach-Object { $g[$_] }
    $mv = $months | ForEach-Object { $m[$_] }
    $mu_g = ($gv | Measure-Object -Sum).Sum / $n
    $mu_m = ($mv | Measure-Object -Sum).Sum / $n
    $num = 0.0; $dg = 0.0; $dm = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $dgi = $gv[$i]-$mu_g; $dmi = $mv[$i]-$mu_m
        $num += $dgi*$dmi; $dg += $dgi*$dgi; $dm += $dmi*$dmi
    }
    return if ($dg -gt 0 -and $dm -gt 0) { $num/[Math]::Sqrt($dg*$dm) } else { 0.0 }
}

Write-Host "=== BASKET OOS CORRELATION CHECK ===" -ForegroundColor Cyan
$gsmc = Extract-Monthly $GsmcHtm
$mg   = Extract-Monthly $MgHtm
$shared = @($gsmc.Keys | Where-Object { $mg.ContainsKey($_) } | Sort-Object)
Write-Host ("Shared OOS months: {0}  ({1} to {2})" -f $shared.Count, $shared[0], $shared[-1])
$r = Pearson $gsmc $mg $shared
Write-Host ("Pearson r (OOS monthly PnL): {0:F4}" -f $r)
$verdict = if ($r -le 0.40) { "ADDITIVE ✅ (≤0.40)" } elseif ($r -le 0.60) { "WATCH ⚠️ (0.40-0.60)" } else { "REDUNDANT ❌ (>0.60)" }
Write-Host "Verdict: $verdict"

# Combined portfolio stats
$cVals = $shared | ForEach-Object { $gsmc[$_] + $mg[$_] }
$n     = $shared.Count
$cMean = ($cVals | Measure-Object -Sum).Sum / $n
$cStd  = [Math]::Sqrt((($cVals | ForEach-Object { ($_-$cMean)*($_-$cMean) }) | Measure-Object -Sum).Sum / ($n-1))
$cPos  = ($cVals | Where-Object { $_ -gt 0 }).Count

Write-Host ""
Write-Host "=== COMBINED OOS PORTFOLIO ===" -ForegroundColor Yellow
Write-Host ("Mean monthly PnL: {0:F2}" -f $cMean)
Write-Host ("Std monthly PnL:  {0:F2}" -f $cStd)
Write-Host ("Sharpe proxy:     {0:F2}  (annualized)" -f ($cMean/$cStd*[Math]::Sqrt(12)))
Write-Host ("Win months:       {0}/{1} ({2:F1}%)" -f $cPos, $n, ($cPos/$n*100))
Write-Host ("Total OOS PnL:    {0:F2}" -f (($cVals | Measure-Object -Sum).Sum))

Write-Host "`nMonthly breakdown (GSMC | MG | Combined):"
foreach ($mo in $shared) {
    $c = $gsmc[$mo] + $mg[$mo]
    $flag = if ($c -lt 0) { " <<" } else { "" }
    Write-Host ("  {0}: {1,10:F2} | {2,10:F2} | {3,10:F2}{4}" -f $mo, $gsmc[$mo], $mg[$mo], $c, $flag)
}
