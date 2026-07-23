<#
corr_monthly_quick.ps1 - Pearson correlation of monthly P&L between two MT5 tester reports
(deal-list table extraction, mirrors _mt5_auto/corr_monthly.py logic in PowerShell -
written 2026-07-23 because the .py version is hardcoded to old filenames, not a reusable CLI).
Reports must include the full deal list (Model 4 / detailed reports do; summary-only don't).
#>
param(
    [Parameter(Mandatory)][string]$ReportA,
    [Parameter(Mandatory)][string]$ReportB,
    [string]$LabelA = "A",
    [string]$LabelB = "B"
)
function Get-MonthlyPnL($path) {
    $t = [IO.File]::ReadAllText($path, [Text.Encoding]::Unicode)
    $rows = [regex]::Matches($t, '<tr[^>]*>(.*?)</tr>', [Text.RegularExpressions.RegexOptions]::Singleline)
    $monthly = @{}
    foreach ($r in $rows) {
        $cells = [regex]::Matches($r.Groups[1].Value, '<t[dh][^>]*>(.*?)</t[dh]>', [Text.RegularExpressions.RegexOptions]::Singleline) |
                 ForEach-Object { ($_.Groups[1].Value -replace '<[^>]+>', '').Trim() }
        if ($cells.Count -ne 13 -or $cells[4] -ne 'out') { continue }
        $profit = 0.0; $comm = 0.0; $swap = 0.0
        if (-not [double]::TryParse(($cells[10] -replace '[ ,]', ''), [ref]$profit)) { continue }
        [double]::TryParse(($cells[8] -replace '[ ,]', ''), [ref]$comm) | Out-Null
        [double]::TryParse(($cells[9] -replace '[ ,]', ''), [ref]$swap) | Out-Null
        if ($cells[0] -match '^(\d{4})\.(\d{2})') {
            $ym = "$($Matches[1])-$($Matches[2])"
            if (-not $monthly.ContainsKey($ym)) { $monthly[$ym] = 0.0 }
            $monthly[$ym] += $profit + $comm + $swap
        }
    }
    return $monthly
}
function Get-Pearson($xs, $ys) {
    $n = $xs.Count
    if ($n -lt 4) { return [double]::NaN }
    $mx = ($xs | Measure-Object -Average).Average
    $my = ($ys | Measure-Object -Average).Average
    $num = 0.0; $dx = 0.0; $dy = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $num += ($xs[$i] - $mx) * ($ys[$i] - $my)
        $dx  += [Math]::Pow($xs[$i] - $mx, 2)
        $dy  += [Math]::Pow($ys[$i] - $my, 2)
    }
    if ($dx -eq 0 -or $dy -eq 0) { return [double]::NaN }
    return $num / ([Math]::Sqrt($dx) * [Math]::Sqrt($dy))
}

$a = Get-MonthlyPnL $ReportA
$b = Get-MonthlyPnL $ReportB
$shared = @($a.Keys | Where-Object { $b.ContainsKey($_) } | Sort-Object)
Write-Host "$LabelA months: $($a.Keys.Count) | $LabelB months: $($b.Keys.Count) | shared: $($shared.Count)"
if ($shared.Count -lt 4) { Write-Host "not enough shared months for correlation"; exit 1 }
$xs = @($shared | ForEach-Object { $a[$_] })
$ys = @($shared | ForEach-Object { $b[$_] })
$corr = Get-Pearson $xs $ys
$verdict = if ([double]::IsNaN($corr)) { "N/A" } elseif ($corr -le 0.40) { "LOW - additive" } elseif ($corr -le 0.60) { "WATCH" } else { "HIGH - concentration risk" }
Write-Host ("{0} vs {1}: corr={2:F3}  shared_months={3}  verdict={4}" -f $LabelA, $LabelB, $corr, $shared.Count, $verdict)
foreach ($m in $shared) { Write-Host ("  {0}: {1,10:F2}  {2,10:F2}" -f $m, $a[$m], $b[$m]) }
