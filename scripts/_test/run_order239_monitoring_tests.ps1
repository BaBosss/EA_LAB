<#
ORDER-239 deterministic monitoring cage.

Exercises the real live_dashboard.ps1 floating-basket path with a fixed expectation
threshold and fixed raw snapshot fixtures. The output assertions are intentionally
integration-style: they verify the visible status row, not a private helper.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$DashScript = ''
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
if (-not $DashScript) { $DashScript = Join-Path $RepoRoot 'scripts\live_dashboard.ps1' }
$fixtureRoot = Join-Path $RepoRoot 'scripts\_test\fixtures\order239'
$script:pass = 0
$script:fail = 0

function Assert-True([string]$name, [bool]$condition) {
    if ($condition) { $script:pass++; Write-Host "[PASS] $name" }
    else { $script:fail++; Write-Host "[FAIL] $name" -ForegroundColor Red }
}

function Get-FloatingRow([string]$html) {
    foreach ($m in [regex]::Matches($html, '(?s)<tr[^>]*>.*?</tr>')) {
        if ($m.Value -match '900001' -and $m.Value -match 'kill 20% ref') { return $m.Value }
    }
    return ''
}

function Run-Case([string]$name, [string]$snapshotName, [scriptblock]$mutate = $null) {
    $work = Join-Path ([IO.Path]::GetTempPath()) ("order239_" + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $work -Force | Out-Null
        Copy-Item (Join-Path $fixtureRoot 'portfolio') (Join-Path $work 'portfolio') -Recurse -Force
        $dealsDir = Join-Path $work 'portfolio\live_deals'
        Copy-Item (Join-Path $fixtureRoot $snapshotName) (Join-Path $dealsDir 'EA_LAB_snapshot_100000001_20260813.csv')
        if ($mutate) { & $mutate (Join-Path $work 'portfolio') }
        $out = Join-Path $work ($name + '.html')
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $DashScript -LiveDealsDir $dealsDir -OutFile $out | Out-Null
        Assert-True "$name dashboard exits cleanly" ($LASTEXITCODE -eq 0)
        $html = Get-Content $out -Raw
        $row = Get-FloatingRow $html
        Assert-True "$name finds the 900001 floating row" ($row -ne '')
        return $row
    } finally {
        if (Test-Path $work) { Remove-Item $work -Recurse -Force }
    }
}

Write-Host '=== ORDER-239 basket-age monitoring ==='
$below = Run-Case 'T1 below threshold' 'T1_below.csv'
Assert-True 'T1 below threshold is non-alerting' ($below -notmatch 'st-yellow|st-red|st-unknown' -and $below -notmatch 'OLD BASKET|BASKET AGE UNKNOWN')
Assert-True 'T1 still renders the raw oldest age' ($below -match '>2399\.9<')

$boundary = Run-Case 'T2 boundary' 'T2_boundary.csv'
Assert-True 'T2 exact boundary uses the inclusive ORDER-239 warning comparison' ($boundary -match 'class="st-yellow"' -and $boundary -match 'OLD BASKET' -and $boundary -match '&gt;= 2400 h')

$above = Run-Case 'T3 above threshold' 'T3_above.csv'
Assert-True 'T3 above threshold is visibly warning/alerting' ($above -match 'class="st-yellow"' -and $above -match 'OLD BASKET')

$ordinaryMissing = Run-Case 'P4 ordinary + missing age' 'T4_missing.csv'
Assert-True 'P4 ordinary + missing age becomes st-unknown' ($ordinaryMissing -match 'class="st-unknown"' -and $ordinaryMissing -match 'BASKET AGE UNKNOWN' -and $ordinaryMissing -notmatch 'class="st-green"')

$ordinaryMalformed = Run-Case 'P3 ordinary + malformed age' 'T4_malformed.csv'
Assert-True 'P3 ordinary + malformed age becomes st-unknown' ($ordinaryMalformed -match 'class="st-unknown"' -and $ordinaryMalformed -match 'BASKET AGE UNKNOWN' -and $ordinaryMalformed -notmatch 'class="st-green"')

$noBase = {
    param($portfolioPath)
    $path = Join-Path $portfolioPath 'ACCOUNTS.csv'
    $text = [IO.File]::ReadAllText($path)
    $text = $text.Replace(',10000,USD,', ',,USD,')
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
}
$noBaseMissing = Run-Case 'P2 st-nobase + missing age' 'T4_missing.csv' $noBase
Assert-True 'P2 st-nobase + missing age remains st-nobase' ($noBaseMissing -match 'class="st-nobase"' -and $noBaseMissing -notmatch 'class="st-unknown"')

$noBaseMalformed = Run-Case 'P1 st-nobase + malformed age' 'T4_malformed.csv' $noBase
Assert-True 'P1 st-nobase + malformed age remains st-nobase' ($noBaseMalformed -match 'class="st-nobase"' -and $noBaseMalformed -notmatch 'class="st-unknown"')

$unchanged = Run-Case 'T5 unrelated expectation fields' 'T1_below.csv' {
    param($portfolioPath)
    $path = Join-Path $portfolioPath 'expectations.csv'
    $text = [IO.File]::ReadAllText($path)
    $text = $text.Replace('1.50,MAIN,1.0,2.0,MC95', '9.99,OTHER,99.0,99.0,OTHER')
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
}
Assert-True 'T5 unrelated expectation fields do not change age classification' ($unchanged -notmatch 'st-yellow|st-red|st-unknown|OLD BASKET|BASKET AGE UNKNOWN' -and $unchanged -match 'kill 20% ref \(2,000\)')

if ($script:fail -gt 0) {
    Write-Host ("FAIL {0}/{1}" -f $script:fail, ($script:pass + $script:fail)) -ForegroundColor Red
    exit 1
}
Write-Host ("PASS {0}/{0}" -f $script:pass) -ForegroundColor Green
exit 0
