<#
tpl_smoke_regression.ps1 - fast, cheap "did every Boss build come up alive" gate.

Complements tpl_regression.ps1, it does not replace it. tpl_regression.ps1 pins MT5
lane 1 and refuses on the SMALLEST metric drift against an exact 6-month baseline -
expensive and strict by design. This script asks a smaller question over a much
shorter window on a different lane (3, "light screens/sweeps" per AGENTS.md): did the
build compile, initialize, and produce a real, fresh, parseable tester report? No
baseline metric comparison is made here - a legitimate strategy change must not turn
this gate red, only compile failures, malformed sets, and INIT-time breaks should.

It invents no new fixtures: the case list and each build's declared, hash-verified
FULL-surface .set file are read from the SAME active regression baseline manifest
tpl_regression.ps1 already validates and pins.

USAGE
  powershell -File scripts\tpl_smoke_regression.ps1
#>
[CmdletBinding()]
param(
    [string]$Symbol = 'XAUUSD',
    [string]$Period = 'H1',
    [string]$FromDate = '2024.01.01',
    [string]$ToDate = '2024.01.15',
    [int]$Model = 1,
    [string]$Terminal = 'D:\Meta 5c\terminal64.exe',
    [string]$DataDir = 'D:\Meta 5c',
    [string]$ManifestPath = ''
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'lib\tpl_baseline.ps1')
. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
. (Join-Path $PSScriptRoot 'lib\setfile_surface.ps1')

try {
    if (-not $ManifestPath) {
        $selectorPath = Join-Path $root 'ea_template\regression_baseline.active.json'
        $selector = Get-TplJson $selectorPath 'active baseline selector'
        Assert-TplRequired $selector @('active_manifest') 'selector'
        $ManifestPath = Resolve-TplRepoPath $root ([string]$selector.active_manifest) 'selector.active_manifest'
    }
    $manifest = Get-TplJson $ManifestPath 'baseline manifest'
    Assert-TplRequired $manifest @('cases') 'manifest'
    $cases = @($manifest.cases)
    if ($cases.Count -eq 0) { throw 'REFUSE: manifest has no cases to smoke' }

    # Step 1: compile. deploy.ps1 -Compile only ever writes lane 1's data directory -
    # this is the same compile step tpl_regression.ps1 itself runs first.
    & (Join-Path $root 'ea_template\deploy.ps1') -Compile
    if ($LASTEXITCODE -ne 0) { throw 'REFUSE: current source compile failed' }

    # Step 2: mirror the freshly compiled EAs onto the smoke lane so a stale binary on
    # lane 3 cannot be mistaken for the build that was just compiled.
    $lane1Data = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355'
    $lane1Src = Join-Path $lane1Data 'MQL5\Experts\EALabTpl'
    $laneDst = Join-Path $DataDir 'MQL5\Experts\EALabTpl'
    if (-not (Test-Path -LiteralPath $lane1Src -PathType Container)) { throw "REFUSE: compiled EAs not found at $lane1Src" }
    robocopy $lane1Src $laneDst /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "REFUSE: could not mirror compiled EAs onto smoke lane ($DataDir)" }

    if (-not (Test-Path -LiteralPath $Terminal -PathType Leaf)) { throw "REFUSE: smoke lane terminal not found: $Terminal" }
    $py = Join-Path $root 'tools\python312\python.exe'
    if (-not (Test-Path -LiteralPath $py -PathType Leaf)) { throw "REFUSE: portable Python not found: $py" }
    $parser = Join-Path $root 'scripts\parse_mt5_report.py'

    $fail = 0
    $results = @()
    foreach ($case in ($cases | Sort-Object ea)) {
        $setPath = Resolve-TplRepoPath $root ([string]$case.declared_set_path) "$($case.ea).declared_set_path"
        $surface = Get-SetSurfaceState -Path $setPath
        if ($surface.State -ne 'FULL' -or (Get-TplSha256 $setPath) -ne ([string]$case.declared_set_sha256).ToLowerInvariant()) {
            throw "REFUSE: $($case.ea) declared set hash differs or set is not FULL-surface - smoke reuses the regression manifest's declared sets and does not invent its own"
        }
        $runStart = Get-Date
        $reportName = 'TPLSMOKE_' + $case.ea
        $expert = 'EALabTpl\' + $case.ea
        $runArgs = @{
            Expert = $expert; Symbol = $Symbol; Period = $Period; FromDate = $FromDate; ToDate = $ToDate
            Model = $Model; ReportName = $reportName; SetFile = $setPath; Terminal = $Terminal; DataDir = $DataDir
            Deposit = 10000; Leverage = 100; Portable = $true
        }
        & (Join-Path $PSScriptRoot 'mt5_run.ps1') @runArgs | ForEach-Object { Write-Host $_ }
        $runnerExit = $LASTEXITCODE
        $reportPath = Join-Path $root ('_mt5_auto\reports\' + $reportName + '.htm')
        if (-not (Test-ReportIsFresh -Htm $reportPath -RunStart $runStart -RunnerExit $runnerExit -Label $case.ea)) {
            Write-Host "[SMOKE FAIL] $($case.ea): no fresh report (INIT_FAILED or runner error)" -ForegroundColor Red
            $fail++
            $results += [pscustomobject]@{ ea = $case.ea; smoke = 'FAIL'; note = 'stale/missing report' }
            continue
        }
        $json = & $py $parser $reportPath --json
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[SMOKE FAIL] $($case.ea): report parse failed" -ForegroundColor Red
            $fail++
            $results += [pscustomobject]@{ ea = $case.ea; smoke = 'FAIL'; note = 'report parse failed' }
            continue
        }
        $report = $json | ConvertFrom-Json
        Write-Host "[SMOKE OK] $($case.ea): net=$($report.net_profit) trades=$($report.total_trades)" -ForegroundColor Green
        $results += [pscustomobject]@{ ea = $case.ea; smoke = 'OK'; net = $report.net_profit; trades = $report.total_trades }
    }
    $results | Format-Table -AutoSize | Out-String | Write-Host
    if ($fail -gt 0) { throw "SMOKE REGRESSION: $fail of $($cases.Count) build(s) failed to come up alive" }
    Write-Host ("=== SMOKE REGRESSION CLEAN ({0}/{0}, lane {1}) ===" -f $cases.Count, $Terminal) -ForegroundColor Green
    exit 0
} catch {
    Write-Host ("[TPL SMOKE REGRESSION REFUSED] " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
