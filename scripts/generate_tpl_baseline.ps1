<#
Generate one explicit Build-6090 TPL baseline from the caller's clean source tree.

This command is intentionally separate from tpl_regression.ps1.  It writes only
versioned metrics/manifest/report evidence when -ConfirmBaseline is supplied and
must be run from the owner-selected pre-identity source worktree.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$SourceCommit,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$AcceptedRuntimeLineageTip,
    [switch]$ConfirmBaseline,
    [string]$PythonExe = '',
    [string]$SetScriptPath = '',
    [string]$ParserPath = '',
    [string]$GeneratorPath = '',
    [string]$ReportRoot = '',
    [string]$Terminal = 'D:\Meta 5\terminal64.exe',
    [string]$DataDir = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355'
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
if (-not $ReportRoot) { $ReportRoot = Join-Path $RepoRoot '_mt5_auto' }
$SourceCommit = $SourceCommit.Trim().ToLowerInvariant()
$sourceType = (& git -C $RepoRoot cat-file -t $SourceCommit 2>$null)
if ($LASTEXITCODE -ne 0 -or ([string]$sourceType).Trim() -ne 'commit') {
    throw "refusing invalid baseline source commit: $SourceCommit"
}
$head = (& git -C $RepoRoot rev-parse HEAD).Trim()
if ($head -ne $SourceCommit) { throw "baseline generator must run at $SourceCommit, got $head" }
$originHead = (& git -C $RepoRoot rev-parse --verify 'origin/master^{commit}' 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $originHead) {
    throw 'refusing baseline source validation: origin/master commit is unavailable'
}
$sourceIsAncestor = $false
& git -C $RepoRoot merge-base --is-ancestor $SourceCommit ([string]$originHead).Trim() 2>$null
$sourceIsAncestor = ($LASTEXITCODE -eq 0)
$originIsAncestor = $false
& git -C $RepoRoot merge-base --is-ancestor ([string]$originHead).Trim() $SourceCommit 2>$null
$originIsAncestor = ($LASTEXITCODE -eq 0)
if (-not ($sourceIsAncestor -or $originIsAncestor)) {
    throw "refusing baseline source ${SourceCommit}: it is not linearly related to origin/master"
}
$acceptedTip = $AcceptedRuntimeLineageTip.Trim().ToLowerInvariant()
$tipType = (& git -C $RepoRoot cat-file -t $acceptedTip 2>$null)
if ($LASTEXITCODE -ne 0 -or ([string]$tipType).Trim() -ne 'commit') {
    throw "refusing invalid accepted runtime lineage tip: $acceptedTip"
}
& git -C $RepoRoot merge-base --is-ancestor $acceptedTip ([string]$originHead).Trim() 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "refusing accepted runtime lineage tip ${acceptedTip}: it is not an ancestor of origin/master"
}
$beforeStatus = @(git -C $RepoRoot status --porcelain)
if ($beforeStatus.Count -ne 0) { throw 'baseline source worktree is not clean before generation' }
if (-not (Test-Path -LiteralPath $Terminal -PathType Leaf)) { throw "terminal not found: $Terminal" }

. (Join-Path $RepoRoot 'scripts\lib\setfile_surface.ps1')
. (Join-Path $RepoRoot 'scripts\lib\report_freshness.ps1')
. (Join-Path $RepoRoot 'scripts\lib\build_receipt.ps1')
$py = if ($PythonExe) { $PythonExe } else { Join-Path $RepoRoot 'tools\python312\python.exe' }
$pyLib = Join-Path (Split-Path $py -Parent) 'Lib\encodings'
if ((-not (Test-Path -LiteralPath $py -PathType Leaf) -or -not (Test-Path -LiteralPath $pyLib -PathType Container)) -and (Test-Path -LiteralPath 'D:\EA_LAB\tools\python312\python.exe' -PathType Leaf)) { $py = 'D:\EA_LAB\tools\python312\python.exe' }
if (-not (Test-Path -LiteralPath $py -PathType Leaf)) { throw "portable Python not found: $py" }
$parser = if ($ParserPath) { $ParserPath } else { Join-Path $RepoRoot 'scripts\parse_mt5_report.py' }
$setScript = if ($SetScriptPath) { $SetScriptPath } else { Join-Path $RepoRoot 'scripts\generate_tpl_regression_sets.ps1' }
$genPath = if ($GeneratorPath) { $GeneratorPath } else { Join-Path $RepoRoot '_triage\factory_os\gen_default_preset.py' }
& $setScript -RepoRoot $RepoRoot -PythonExe $py -GeneratorPath $genPath
if ($LASTEXITCODE -ne 0) { throw 'declared set generation failed' }

$archiveDir = Join-Path $RepoRoot 'ea_template\regression_reports\build6090'
New-Item -ItemType Directory -Force $archiveDir | Out-Null
$dataResolved = (Resolve-Path -LiteralPath $DataDir).Path
$laneExperts = Join-Path $dataResolved 'MQL5\Experts\EALabTpl'
New-Item -ItemType Directory -Force $laneExperts | Out-Null
robocopy (Join-Path $RepoRoot 'ea_template') $laneExperts /MIR /R:1 /W:1 /XD .git /XF *.ex5 *.log /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw 'baseline source copy to pinned tester lane failed' }
$meta = 'D:\Meta 5\MetaEditor64.exe'
$receiptRegistry = Join-Path ([IO.Path]::GetTempPath()) ('tpl_receipts_' + [guid]::NewGuid().ToString('N') + '.jsonl')
$receiptMap = @{}
foreach ($mq5 in @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'ea_template') -Filter 'Boss_*.mq5' | Sort-Object Name)) {
    $target = Join-Path $laneExperts $mq5.Name
    $artifact = Join-Path $laneExperts ($mq5.BaseName + '.ex5')
    $log = Join-Path $laneExperts ('compile_' + $mq5.BaseName + '.log')
    if (Test-Path -LiteralPath $artifact) { Remove-Item -LiteralPath $artifact -Force }
    if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
    $receipt = New-BuildReceiptToken
    Write-BuildReceiptHeader -HeaderPath (Join-Path $laneExperts 'core\BuildReceipt_gen.mqh') -Receipt $receipt
    Start-Process -FilePath $meta -ArgumentList @('/compile:"' + $target + '"', '/log:"' + $log + '"') -Wait
    if (-not (Test-Path -LiteralPath $log)) { throw "$($mq5.BaseName) compile log missing" }
    $compileText = Get-Content -LiteralPath $log -Raw -Encoding Unicode
    if ($compileText -notmatch 'Result:\s*0\s+errors,\s*0\s+warnings' -or -not (Test-Path -LiteralPath $artifact)) { throw "$($mq5.BaseName) did not compile 0/0" }
    Write-BuildReceiptRecord -RegistryPath $receiptRegistry -Receipt $receipt -ArtifactPath $artifact `
        -SourcePath $mq5.FullName -EaLogicalIdentity $mq5.BaseName
    $receiptMap[$mq5.BaseName] = $receipt
    if ($mq5.BaseName -eq 'Boss_14_GridLog') {
        Sync-ManagedCompatibilityArtifact -CanonicalArtifactPath $artifact `
            -CompatibilityArtifactPath (Join-Path (Split-Path $laneExperts -Parent) 'Boss_14_GridLog.ex5') | Out-Null
    }
}
$compileStartUtc = (Get-Date).ToUniversalTime().ToString('o')

$cases = @()
$metricRows = @()
$setMap = @{
    Boss_11_GridTrend = 'Boss_11_GridTrend_defaults.set'; Boss_12_Breakout = 'Boss_12_Breakout_defaults.set'; Boss_13_MeanRev = 'Boss_13_MeanRev_defaults.set';
    Boss_14_GridLog = 'Boss_14_GridLog_regression_full.set'; Boss_15_ST03 = 'Boss_15_ST03_defaults.set'; Boss_16_KangarooGrid = 'Boss_16_KangarooGrid_regression_full.set';
    Boss_17_Wave5 = 'Boss_17_Wave5_defaults.set'; Boss_18_JumStoch = 'Boss_18_JumStoch_defaults.set'; Boss_19_AdaptiveTrendGrid = 'Boss_19_AdaptiveTrendGrid_defaults.set'
}

foreach ($ea in ($setMap.Keys | Sort-Object)) {
    $setPath = Join-Path $RepoRoot ('ea_template\sets\regression\' + $setMap[$ea])
    $surface = Get-SetSurfaceState -Path $setPath
    if ($surface.State -ne 'FULL') { throw "$ea set is not FULL: $($surface.Message)" }
    $header = Get-Content -LiteralPath $setPath | Where-Object { $_ -match '^;\s*build=(\S+)\s+surface=(\d+)\s+effective_config_hash=([0-9a-f]{64})' } | Select-Object -First 1
    if (-not $header) { throw "$ea set has no effective-config provenance header" }
    [regex]::Match($header, '^;\s*build=(\S+)\s+surface=(\d+)\s+effective_config_hash=([0-9a-f]{64})') | Out-Null
    $setTag = $Matches[1]; $declared = [int]$Matches[2]; $configHash = $Matches[3]
    $runStart = Get-Date
    $reportName = 'TPLBASE6090_' + $ea
    $runArgs = @{ Expert = ('EALabTpl\' + $ea); Symbol = 'XAUUSD'; Period = 'H1'; FromDate = '2024.01.01'; ToDate = '2024.07.01'; Model = 1; ReportName = $reportName; SetFile = $setPath; Terminal = $Terminal; DataDir = $DataDir; Deposit = 10000; Leverage = 100; BuildReceiptRegistry = $receiptRegistry }
    & (Join-Path $RepoRoot 'scripts\mt5_run.ps1') @runArgs | ForEach-Object { Write-Host $_ }
    $exit = $LASTEXITCODE
    if ($exit -ne 0) { throw "$ea baseline run failed with exit $exit" }
    $reportPath = Join-Path $ReportRoot ('reports\' + $reportName + '.htm')
    if (-not (Test-ReportIsFresh -Htm $reportPath -RunStart $runStart -RunnerExit $exit -Label $ea -Quiet)) { throw "$ea report is missing, stale, or not from a comparable runner exit" }
    $parsed = (& $py $parser $reportPath --json | ConvertFrom-Json)
    if ([int]$parsed.report_build -ne 6090) { throw "$ea report Build $($parsed.report_build), expected 6090" }
    if ($parsed.symbol -ne 'XAUUSD' -or $parsed.period -ne 'H1' -or $parsed.from_date -ne '2024.01.01' -or $parsed.to_date -ne '2024.07.01' -or [int]$parsed.initial_deposit -ne 10000 -or $parsed.currency -ne 'USD' -or $parsed.leverage -ne '1:100') { throw "$ea report contract mismatch" }
    $metric = [ordered]@{ ea=$ea; net=('{0:F2}' -f [double]$parsed.net_profit); pf=('{0:F2}' -f [double]$parsed.profit_factor); trades=('{0:0}' -f [double]$parsed.total_trades); eqdd=('{0:F2}({1:F2}%)' -f [double]$parsed.equity_drawdown_maximal_abs, [double]$parsed.equity_drawdown_maximal_pct) }
    $metricRows += [pscustomobject]$metric
    $src = Join-Path $RepoRoot ('ea_template\' + $ea + '.mq5')
    $artifactPath = Join-Path $laneExperts ($ea + '.ex5')
    $artifactHash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $buildReceipt = [string]$receiptMap[$ea]
    if ($buildReceipt -notmatch '^br-[0-9a-f]{32}$') { throw "$ea has no stamped baseline build receipt" }
    $archivedReport = Join-Path $archiveDir ($reportName + '.htm')
    Copy-Item -LiteralPath $reportPath -Destination $archivedReport -Force
    $cases += [ordered]@{
        ea=$ea; source_path=('ea_template/' + $ea + '.mq5'); source_sha256=(Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash.ToLowerInvariant(); source_commit=$SourceCommit
        build_receipt=$buildReceipt; build_receipt_kind='baseline_compile'; compiled_artifact_path=$artifactPath; compiled_artifact_sha256=$artifactHash
        declared_set_path=('ea_template/sets/regression/' + $setMap[$ea]); declared_set_sha256=(Get-FileHash -LiteralPath $setPath -Algorithm SHA256).Hash.ToLowerInvariant()
        set_surface=[ordered]@{ state=$surface.State; build_tag=$setTag; declared=$declared; assignments=[int]$surface.Assignments; effective_config_hash=$configHash }
        report_path=('ea_template/regression_reports/build6090/' + $reportName + '.htm'); report_sha256=(Get-FileHash -LiteralPath $archivedReport -Algorithm SHA256).Hash.ToLowerInvariant(); report_build=6090; report_fresh=$true
        symbol='XAUUSD'; timeframe='H1'; date_from='2024.01.01'; date_to='2024.07.01'; model=1; deposit=10000; currency='USD'; leverage=100
        history_quality=[string]$parsed.history_quality; bars=[int]$parsed.bars; ticks=[int]$parsed.ticks; metrics=$metric
    }
    Write-Host "$ea Build6090 net=$($metric.net) pf=$($metric.pf) trades=$($metric.trades) eqdd=$($metric.eqdd)" -ForegroundColor Green
}

if (-not $ConfirmBaseline) { Write-Host 'DRY RUN: baseline artifacts not written; rerun with -ConfirmBaseline'; exit 1 }
$metricsPath = Join-Path $RepoRoot 'ea_template\regression_baseline_build6090.csv'
$metricRows | Export-Csv -LiteralPath $metricsPath -NoTypeInformation -Encoding UTF8
$terminalHash = (Get-FileHash -LiteralPath $Terminal -Algorithm SHA256).Hash.ToLowerInvariant()
$manifest = [ordered]@{
    schema='tpl_regression_baseline/2'; status='ACTIVE_COMPARABLE'; baseline_kind='VERSIONED'; metrics_file='ea_template/regression_baseline_build6090.csv'; metrics_sha256=(Get-FileHash -LiteralPath $metricsPath -Algorithm SHA256).Hash.ToLowerInvariant()
    expected_mt5_build=6090; terminal_executable=$Terminal; terminal_executable_sha256=$terminalHash; tester_data_directory=$DataDir; portable=$false
    baseline_source_commit=$SourceCommit; baseline_source_clean=$true; accepted_runtime_lineage_tip=$acceptedTip
    tester_contract=[ordered]@{ symbol='XAUUSD'; timeframe='H1'; date_from='2024.01.01'; date_to='2024.07.01'; model=1; deposit=10000; currency='USD'; leverage=100 }
    generation_utc=(Get-Date).ToUniversalTime().ToString('o'); report_freshness_evidence=[ordered]@{ all_fresh=$true; runner_exit_codes=@{ baseline='0 per EA' }; generated_from=$SourceCommit }
    cases=$cases
}
$manifestPath = Join-Path $RepoRoot 'ea_template\regression_baseline_build6090.manifest.json'
$json = $manifest | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText($manifestPath, $json, (New-Object Text.UTF8Encoding($false)))
$historicalPath = Join-Path $RepoRoot 'ea_template\regression_baseline.csv'
$historicalManifest = [ordered]@{ schema='tpl_regression_baseline/1'; status='HISTORICAL'; comparability='NONCOMPARABLE_TO_BUILD_6090'; metrics_file='ea_template/regression_baseline.csv'; metrics_sha256=(Get-FileHash -LiteralPath $historicalPath -Algorithm SHA256).Hash.ToLowerInvariant(); expected_historical_build=5836 }
[IO.File]::WriteAllText((Join-Path $RepoRoot 'ea_template\regression_baseline_build5836.manifest.json'), ($historicalManifest | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
$selector = [ordered]@{ schema='tpl_regression_selector/1'; active_manifest='ea_template/regression_baseline_build6090.manifest.json'; active_build=6090; historical_manifest='ea_template/regression_baseline_build5836.manifest.json' }
[IO.File]::WriteAllText((Join-Path $RepoRoot 'ea_template\regression_baseline.active.json'), ($selector | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
Write-Host 'BUILD-6090 BASELINE WRITTEN' -ForegroundColor Green
