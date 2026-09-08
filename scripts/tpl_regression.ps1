<#
tpl_regression.ps1 - versioned, fail-closed Boss V2 regression cage.

The active selector names a Build-6090 provenance manifest.  The historical
ea_template\regression_baseline.csv is retained as Build-5836 evidence only and
is never loaded as a comparator.
#>
[CmdletBinding()]
param(
    [string]$Symbol = 'XAUUSD',
    [string]$Period = 'H1',
    [string]$FromDate = '2024.01.01',
    [string]$ToDate = '2024.07.01',
    [int]$Model = 1,
    [string]$Terminal = 'D:\Meta 5\terminal64.exe',
    [string]$DataDir = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
    [switch]$Portable,
    [switch]$ValidateOnly,
    [string]$ActiveSelectorPath = '',
    [string]$AdjacentControlRef = ''
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'lib\tpl_baseline.ps1')

function Invoke-TplCompile([string]$SourceRoot, [string]$Label) {
    & (Join-Path $SourceRoot 'ea_template\deploy.ps1') -Compile | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "REFUSE: $Label source compile failed" }
}

function Invoke-TplRegressionCase([object]$Case, [string]$SetPath, [string]$RunLabel, [string]$BuildReceiptRegistry) {
    $runStart = Get-Date
    $reportName = if ($RunLabel) { 'TPLREG_' + $RunLabel + '_' + $Case.ea } else { 'TPLREG_' + $Case.ea }
    $runArgs = @{
        Expert = 'EALabTpl\' + $Case.ea
        Symbol = $Symbol
        Period = $Period
        FromDate = $FromDate
        ToDate = $ToDate
        Model = $Model
        ReportName = $reportName
        SetFile = $SetPath
        Terminal = $Terminal
        DataDir = $DataDir
        Deposit = 10000
        Leverage = 100
        BuildReceiptRegistry = $BuildReceiptRegistry
    }
    if ($Portable) { $runArgs.Portable = $true }
    $runnerOutput = & (Join-Path $PSScriptRoot 'mt5_run.ps1') @runArgs 2>&1
    $runnerExit = $LASTEXITCODE
    $runnerOutput | ForEach-Object { Write-Host $_ }
    $reportPath = Join-Path $root ('_mt5_auto\reports\' + $reportName + '.htm')
    if (-not (Test-ReportIsFresh -Htm $reportPath -RunStart $runStart -RunnerExit $runnerExit -Label $Case.ea)) { throw "REFUSE: $($Case.ea) stale report" }
    $json = & $py $parser $reportPath --json
    if ($LASTEXITCODE -ne 0) { throw "REFUSE: $($Case.ea) report parse failed" }
    $report = $json | ConvertFrom-Json
    if ([int]$report.report_build -ne 6090) { throw "NONCOMPARABLE: $($Case.ea) report Build $($report.report_build), expected 6090" }
    if ($report.symbol -ne $Symbol -or $report.period -ne $Period -or $report.from_date -ne $FromDate -or $report.to_date -ne $ToDate -or [int]$report.initial_deposit -ne 10000 -or $report.currency -ne 'USD' -or $report.leverage -ne '1:100') { throw "REFUSE: $($Case.ea) tester contract mismatch" }
    return [pscustomobject]@{
        ea = [string]$Case.ea
        net = ('{0:F2}' -f [double]$report.net_profit)
        pf = ('{0:F2}' -f [double]$report.profit_factor)
        trades = ('{0:0}' -f [double]$report.total_trades)
        eqdd = ('{0:F2}({1:F2}%)' -f [double]$report.equity_drawdown_maximal_abs, [double]$report.equity_drawdown_maximal_pct)
    }
}

function Assert-TplMetricMatch([object]$Expected, [object]$Actual, [string]$ExpectedLabel, [string]$ActualLabel) {
    if ($Expected.net -ne $Actual.net -or $Expected.pf -ne $Actual.pf -or $Expected.trades -ne $Actual.trades -or $Expected.eqdd -ne $Actual.eqdd) {
        Write-Host ("[DRIFT] {0}: {1} net={2} pf={3} trades={4} eqdd={5}; {6} net={7} pf={8} trades={9} eqdd={10}" -f $Actual.ea,$ExpectedLabel,$Expected.net,$Expected.pf,$Expected.trades,$Expected.eqdd,$ActualLabel,$Actual.net,$Actual.pf,$Actual.trades,$Actual.eqdd) -ForegroundColor Red
        return $false
    }
    return $true
}

try {
    $baseline = Get-TplActiveBaseline -Root $root -ActiveSelectorPath $ActiveSelectorPath
    if ($AdjacentControlRef) {
        $sourceCommit = Assert-TplSourceContract -Root $root -Baseline $baseline -AdjacentControlRef $AdjacentControlRef -RegisteredUnbaselinedEas @($baseline.RegisteredUnbaselinedEas)
        $controlCommit = Assert-TplCommitIdentity -Root $root -Sha $AdjacentControlRef -Label 'AdjacentControlRef'
    } else {
        $sourceCommit = Assert-TplSourceContract -Root $root -Baseline $baseline
    }
    $contract = $baseline.Manifest.tester_contract
    if ($Symbol -ne $contract.symbol -or $Period -ne $contract.timeframe -or $FromDate -ne $contract.date_from -or $ToDate -ne $contract.date_to -or $Model -ne [int]$contract.model) {
        throw 'REFUSE: requested tester contract does not match the active Build-6090 baseline'
    }
    if ($ValidateOnly) {
        if ($AdjacentControlRef) {
            Write-Host "=== ADJACENT CONTROL STRUCTURALLY READY; RUNTIME CONTROL+CURRENT RUN REQUIRED (control $controlCommit, source $sourceCommit) ===" -ForegroundColor Yellow
        } else {
            Write-Host "=== BASELINE CONTRACT CLEAN (Build 6090, source $sourceCommit) ===" -ForegroundColor Green
        }
        exit 0
    }

    if (-not (Test-Path -LiteralPath $Terminal -PathType Leaf)) { throw "REFUSE: terminal not found: $Terminal" }
    . (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
    . (Join-Path $PSScriptRoot 'lib\setfile_surface.ps1')
    . (Join-Path $root 'scripts\use_python.ps1')
    $py = Assert-PortablePython -Root $root -Provision
    $parser = Join-Path $root 'scripts\parse_mt5_report.py'
    $cases = @($baseline.Manifest.cases | Sort-Object ea)
    $sets = @{}
    foreach ($case in $cases) {
        $setPath = Resolve-TplRepoPath $root ([string]$case.declared_set_path) "$($case.ea).declared_set_path"
        $surface = Get-SetSurfaceState -Path $setPath
        if ($surface.State -ne 'FULL' -or (Get-TplSha256 $setPath) -ne ([string]$case.declared_set_sha256).ToLowerInvariant()) { throw "REFUSE: $($case.ea) set hash differs or set is undeclared" }
        $sets[$case.ea] = $setPath
    }

    if (-not $AdjacentControlRef) {
        Invoke-TplCompile -SourceRoot $root -Label 'current'
        $fail = 0
        foreach ($case in $cases) {
            $actual = Invoke-TplRegressionCase -Case $case -SetPath $sets[$case.ea] -RunLabel ''
            $expected = @($baseline.Metrics | Where-Object ea -eq $case.ea)[0]
            if (-not (Assert-TplMetricMatch -Expected $expected -Actual $actual -ExpectedLabel 'baseline' -ActualLabel 'now')) { $fail++ }
            else { Write-Host "[OK] $($case.ea) matches Build-6090 baseline" -ForegroundColor Green }
        }
        if ($fail -gt 0) { throw "REGRESSION: $fail exact metric mismatch(es)" }
        Write-Host "=== REGRESSION CLEAN ($($cases.Count)/$($cases.Count), Build 6090, lane $Terminal, source $sourceCommit) ===" -ForegroundColor Green
    } else {
        $tmpParent = 'C:\ea_lab_tmp'
        $controlWorktree = Join-Path $tmpParent ('tpl_adjacent_control_' + [guid]::NewGuid().ToString('N'))
        if (-not $controlWorktree.StartsWith('C:\ea_lab_tmp\tpl_adjacent_control_', [StringComparison]::OrdinalIgnoreCase)) { throw 'REFUSE: unsafe adjacent control worktree path' }
        New-Item -ItemType Directory -Force $tmpParent | Out-Null
        try {
            if (Test-Path -LiteralPath $controlWorktree) { throw "REFUSE: adjacent control worktree already exists: $controlWorktree" }
            & git -C $root worktree add --detach $controlWorktree $controlCommit | ForEach-Object { Write-Host $_ }
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $controlWorktree -PathType Container)) { throw 'REFUSE: could not create detached adjacent control worktree' }

            Invoke-TplCompile -SourceRoot $controlWorktree -Label 'adjacent control'
            $controlMetrics = @{}
            foreach ($case in $cases) {
                $controlMetrics[$case.ea] = Invoke-TplRegressionCase -Case $case -SetPath $sets[$case.ea] -RunLabel 'CONTROL' -BuildReceiptRegistry (Join-Path $controlWorktree 'portfolio\build_receipts.jsonl')
            }

            Invoke-TplCompile -SourceRoot $root -Label 'current'
            $fail = 0
            foreach ($case in $cases) {
                $actual = Invoke-TplRegressionCase -Case $case -SetPath $sets[$case.ea] -RunLabel 'CURRENT' -BuildReceiptRegistry (Join-Path $root 'portfolio\build_receipts.jsonl')
                if (-not (Assert-TplMetricMatch -Expected $controlMetrics[$case.ea] -Actual $actual -ExpectedLabel 'control' -ActualLabel 'current')) { $fail++ }
                else { Write-Host "[OK] $($case.ea) current matches adjacent control" -ForegroundColor Green }
            }
            if ($fail -gt 0) { throw "REGRESSION: $fail adjacent control metric mismatch(es)" }
            Write-Host "=== ADJACENT REGRESSION CLEAN ($($cases.Count)/$($cases.Count), Build 6090, lane $Terminal, control $controlCommit, source $sourceCommit) ===" -ForegroundColor Green
        } finally {
            if ($controlWorktree -and (Test-Path -LiteralPath $controlWorktree)) {
                if (-not $controlWorktree.StartsWith('C:\ea_lab_tmp\tpl_adjacent_control_', [StringComparison]::OrdinalIgnoreCase)) { throw 'REFUSE: unsafe adjacent control cleanup path' }
                & git -C $root worktree remove --force $controlWorktree 2>$null
                if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath $controlWorktree)) { throw "REFUSE: adjacent control worktree cleanup failed: $controlWorktree" }
            }
        }
    }
    exit 0
} catch {
    Write-Host ("[TPL REGRESSION REFUSED] " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
