<#
ORDER-740 targeted regression.

The shared dynamic-close input is inert on LAB_ENTRY_16 because LabCore routes
that build through Kangaroo_OnTick before Exit_ManageBasket.  This cage checks
the observable contract at runtime on lane 1:
  - Boss_16 + _57_DynCloseOn=true prints the inert-input warning;
  - Boss_16 + the declared default false stays silent;
  - Boss_15 + _57_DynCloseOn=true stays silent (preprocessor specificity).
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$Terminal = 'D:\Meta 5\terminal64.exe',
    [string]$DataDir = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
    [string]$Symbol = 'XAUUSD',
    [string]$Period = 'H1',
    [string]$FromDate = '2024.01.02',
    [string]$ToDate = '2024.01.05',
    [int]$Model = 1
)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$labCore = Join-Path $RepoRoot 'ea_template\core\LabCore.mqh'
$warningPrefix = '[INIT] WARN: _57_DynCloseOn has NO EFFECT on Boss_16/Kangaroo'
$source = Get-Content -LiteralPath $labCore -Raw
if ($source -notmatch '(?s)#ifdef LAB_ENTRY_16.*?if\(_57_DynCloseOn\).*?Print\("\[INIT\] WARN: _57_DynCloseOn has NO EFFECT on Boss_16/Kangaroo \(Kangaroo owns its exits\) - input ignored"\);.*?#endif') {
    throw 'ORDER-740 source guard missing or outside LAB_ENTRY_16'
}
if ($source -match '(?s)#ifndef LAB_ENTRY_16.*?_57_DynCloseOn has NO EFFECT') {
    throw 'ORDER-740 warning leaked into a non-LAB_ENTRY_16 guard'
}

function Get-LogSnapshot {
    param([string[]]$Roots)
    $snapshot = @{}
    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        foreach ($log in @(Get-ChildItem -LiteralPath $root -Recurse -Filter '*.log' -File -ErrorAction SilentlyContinue)) {
            $snapshot[$log.FullName] = @(Get-Content -LiteralPath $log.FullName -Encoding Unicode -ErrorAction SilentlyContinue).Count
        }
    }
    return $snapshot
}

function Get-NewLogLines {
    param([hashtable]$Before, [string[]]$Roots)
    $lines = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        foreach ($log in @(Get-ChildItem -LiteralPath $root -Recurse -Filter '*.log' -File -ErrorAction SilentlyContinue)) {
            if ($seen.ContainsKey($log.FullName)) { continue }
            $seen[$log.FullName] = $true
            $all = @(Get-Content -LiteralPath $log.FullName -Encoding Unicode -ErrorAction SilentlyContinue)
            $skip = if ($Before.ContainsKey($log.FullName)) { [int]$Before[$log.FullName] } else { 0 }
            if ($skip -lt $all.Count) { $lines.AddRange([string[]]$all[$skip..($all.Count - 1)]) }
        }
    }
    return @($lines)
}

function New-TestSet {
    param([string]$SourceSet, [bool]$DynCloseOn, [string]$Name)
    $path = Join-Path ([IO.Path]::GetTempPath()) ('order740_' + $Name + '_' + [guid]::NewGuid().ToString('N') + '.set')
    $text = Get-Content -LiteralPath $SourceSet -Raw
    $replacement = '_57_DynCloseOn=' + ($(if ($DynCloseOn) { 'true' } else { 'false' }))
    if ($text -notmatch '(?m)^_57_DynCloseOn=.*$') { throw "missing _57_DynCloseOn in $SourceSet" }
    $updated = [regex]::Replace($text, '(?m)^_57_DynCloseOn=.*$', $replacement)
    [IO.File]::WriteAllText($path, $updated, [Text.UTF8Encoding]::new($false))
    return $path
}

function Invoke-Case {
    param(
        [string]$Name,
        [string]$Expert,
        [string]$SetFile,
        [bool]$ExpectWarning
    )
    $testerRoot = Join-Path $DataDir 'Tester'
    $roots = @((Join-Path $testerRoot 'logs'))
    if (Test-Path -LiteralPath $testerRoot -PathType Container) {
        $roots += @(Get-ChildItem -LiteralPath $testerRoot -Directory -Filter 'Agent-*' -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'logs' })
    }
    $before = Get-LogSnapshot $roots
    $runStart = Get-Date
    $report = 'ORDER740_' + $Name
    $output = @(& (Join-Path $RepoRoot 'scripts\mt5_run.ps1') -Expert $Expert -Symbol $Symbol -Period $Period `
        -FromDate $FromDate -ToDate $ToDate -Model $Model -ReportName $report -SetFile $SetFile `
        -Terminal $Terminal -DataDir $DataDir 2>&1)
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) { throw "ORDER-740 $Name runner exit $exitCode" }
    $fresh = @(Get-NewLogLines $before $roots)
    # MT5 wraps long journal lines; the source assertion above owns the complete
    # wording, while the runtime assertion uses the stable prefix before wrapping.
    $matchingWarningLines = @($fresh | Where-Object { $_ -match [regex]::Escape($warningPrefix) })
    $actual = ($matchingWarningLines.Count -gt 0)
    if ($actual -ne $ExpectWarning) {
        throw "ORDER-740 $Name expected warning=$ExpectWarning actual=$actual (run started $runStart; fresh log lines=$($fresh.Count))"
    }
    $state = if ($actual) { 'FIRED' } else { 'SILENT' }
    Write-Host "[PASS] ORDER-740 $Name :: $state"
}

$sets = @()
try {
    $boss16 = New-TestSet (Join-Path $RepoRoot 'ea_template\sets\regression\Boss_16_KangarooGrid_defaults.set') $true 'boss16_on'
    $boss16Default = New-TestSet (Join-Path $RepoRoot 'ea_template\sets\regression\Boss_16_KangarooGrid_defaults.set') $false 'boss16_default'
    $boss15 = New-TestSet (Join-Path $RepoRoot 'ea_template\sets\regression\Boss_15_ST03_defaults.set') $true 'boss15_on'
    $sets += $boss16, $boss16Default, $boss15
    Invoke-Case 'boss16_on' 'EALabTpl\Boss_16_KangarooGrid' $boss16 $true
    Invoke-Case 'boss16_default' 'EALabTpl\Boss_16_KangarooGrid' $boss16Default $false
    Invoke-Case 'boss15_on' 'EALabTpl\Boss_15_ST03' $boss15 $false
    Write-Host 'ORDER-740 TARGETED REGRESSION: 3/3 PASS' -ForegroundColor Green
    exit 0
}
finally {
    foreach ($set in $sets) { Remove-Item -LiteralPath $set -Force -ErrorAction SilentlyContinue }
}
