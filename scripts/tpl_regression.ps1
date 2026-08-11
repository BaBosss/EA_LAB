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
    [string]$ActiveSelectorPath = ''
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'lib\tpl_baseline.ps1')

try {
    $baseline = Get-TplActiveBaseline -Root $root -ActiveSelectorPath $ActiveSelectorPath
    $sourceCommit = Assert-TplSourceContract -Root $root -Baseline $baseline
    $contract = $baseline.Manifest.tester_contract
    if ($Symbol -ne $contract.symbol -or $Period -ne $contract.timeframe -or $FromDate -ne $contract.date_from -or $ToDate -ne $contract.date_to -or $Model -ne [int]$contract.model) {
        throw 'REFUSE: requested tester contract does not match the active Build-6090 baseline'
    }
    if (-not $ValidateOnly) {
        if (-not (Test-Path -LiteralPath $Terminal -PathType Leaf)) { throw "REFUSE: terminal not found: $Terminal" }
        $deployStart = Get-Date
        & (Join-Path $root 'ea_template\deploy.ps1') -Compile
        if ($LASTEXITCODE -ne 0) { throw 'REFUSE: current source compile failed' }
        . (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
        . (Join-Path $PSScriptRoot 'lib\setfile_surface.ps1')
        $py = Join-Path $root 'tools\python312\python.exe'
        if ((-not (Test-Path -LiteralPath $py -PathType Leaf) -or -not (Test-Path -LiteralPath (Join-Path (Split-Path $py -Parent) 'Lib\encodings') -PathType Container)) -and (Test-Path -LiteralPath 'D:\EA_LAB\tools\python312\python.exe')) { $py = 'D:\EA_LAB\tools\python312\python.exe' }
        if (-not (Test-Path -LiteralPath $py -PathType Leaf)) { throw "REFUSE: portable Python not found: $py" }
        $parser = Join-Path $root 'scripts\parse_mt5_report.py'
        $fail = 0
        $cases = @($baseline.Manifest.cases)
        foreach ($case in ($cases | Sort-Object ea)) {
            $setPath = Resolve-TplRepoPath $root ([string]$case.declared_set_path) "$($case.ea).declared_set_path"
            $surface = Get-SetSurfaceState -Path $setPath
            if ($surface.State -ne 'FULL' -or (Get-TplSha256 $setPath) -ne ([string]$case.declared_set_sha256).ToLowerInvariant()) { throw "REFUSE: $($case.ea) set hash differs or set is undeclared" }
            $runStart = Get-Date
            $reportName = 'TPLREG_' + $case.ea
            $expert = 'EALabTpl\' + $case.ea
            $runArgs = @{ Expert = $expert; Symbol = $Symbol; Period = $Period; FromDate = $FromDate; ToDate = $ToDate; Model = $Model; ReportName = $reportName; SetFile = $setPath; Terminal = $Terminal; DataDir = $DataDir; Deposit = 10000; Leverage = 100 }
            if ($Portable) { $runArgs.Portable = $true }
            & (Join-Path $PSScriptRoot 'mt5_run.ps1') @runArgs | ForEach-Object { Write-Host $_ }
            $runnerExit = $LASTEXITCODE
            $reportPath = Join-Path $root ('_mt5_auto\reports\' + $reportName + '.htm')
            if (-not (Test-ReportIsFresh -Htm $reportPath -RunStart $runStart -RunnerExit $runnerExit -Label $case.ea)) { throw "REFUSE: $($case.ea) stale report" }
            $json = & $py $parser $reportPath --json
            if ($LASTEXITCODE -ne 0) { throw "REFUSE: $($case.ea) report parse failed" }
            $report = $json | ConvertFrom-Json
            $reportHash = Get-TplSha256 $reportPath
            if ([int]$report.report_build -ne 6090) { throw "NONCOMPARABLE: $($case.ea) report Build $($report.report_build), expected 6090" }
            if ($report.symbol -ne $Symbol -or $report.period -ne $Period -or $report.from_date -ne $FromDate -or $report.to_date -ne $ToDate -or [int]$report.initial_deposit -ne 10000 -or $report.currency -ne 'USD' -or $report.leverage -ne '1:100') { throw "REFUSE: $($case.ea) tester contract mismatch" }
            $net = ('{0:F2}' -f [double]$report.net_profit)
            $pf = ('{0:F2}' -f [double]$report.profit_factor)
            $trades = ('{0:0}' -f [double]$report.total_trades)
            $eqdd = ('{0:F2}({1:F2}%)' -f [double]$report.equity_drawdown_maximal_abs, [double]$report.equity_drawdown_maximal_pct)
            $expected = @($baseline.Metrics | Where-Object ea -eq $case.ea)[0]
            if ($expected.net -ne $net -or $expected.pf -ne $pf -or $expected.trades -ne $trades -or $expected.eqdd -ne $eqdd) {
                Write-Host ("[DRIFT] {0}: baseline net={1} pf={2} trades={3} eqdd={4}; now net={5} pf={6} trades={7} eqdd={8}" -f $case.ea,$expected.net,$expected.pf,$expected.trades,$expected.eqdd,$net,$pf,$trades,$eqdd) -ForegroundColor Red
                $fail++
            } else { Write-Host "[OK] $($case.ea) matches Build-6090 baseline" -ForegroundColor Green }
        }
        if ($fail -gt 0) { throw "REGRESSION: $fail exact metric mismatch(es)" }
        Write-Host "=== REGRESSION CLEAN (8/8, Build 6090, lane $Terminal, source $sourceCommit) ===" -ForegroundColor Green
    } else {
        Write-Host "=== BASELINE CONTRACT CLEAN (Build 6090, source $sourceCommit) ===" -ForegroundColor Green
    }
    exit 0
} catch {
    Write-Host ("[TPL REGRESSION REFUSED] " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
