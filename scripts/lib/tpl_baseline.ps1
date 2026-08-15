<#
Fail-closed validation for the versioned TPL regression baseline.

This library deliberately validates the active selector, the referenced manifest,
the versioned metrics, the declared set surface, and the archived baseline reports
before a tester result is compared.  The historical Build-5836 CSV is never loaded
as a comparator.
#>

function Get-TplSha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "missing file: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TplJson([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "REFUSE: $Label missing: $Path" }
    try { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop) }
    catch { throw "REFUSE: malformed $Label '$Path': $($_.Exception.Message)" }
}

function Get-TplRelativePath([string]$Root, [string]$Path) {
    $fullRoot = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\') + '\'
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($fullRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "REFUSE: path escapes repository root: $Path"
    }
    return $fullPath.Substring($fullRoot.Length).Replace('\', '/')
}

function Resolve-TplRepoPath([string]$Root, [string]$RelativePath, [string]$Field) {
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
        throw "REFUSE: $Field must be a non-empty repository-relative path"
    }
    $candidate = Join-Path $Root ($RelativePath -replace '/', '\')
    $resolved = [IO.Path]::GetFullPath($candidate)
    $rootFull = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "REFUSE: $Field escapes repository root"
    }
    return $resolved
}

function Get-TplExpectedEas([string]$Root) {
    $files = @(Get-ChildItem -LiteralPath (Join-Path $Root 'ea_template') -Filter 'Boss_*.mq5' -File | Sort-Object Name)
    if ($files.Count -ne 8) { throw "FAIL: expected exactly 8 canonical Boss EAs, found $($files.Count)" }
    return @($files | ForEach-Object {
        $match = [regex]::Match($_.BaseName, '^Boss_(\d+)_')
        if (-not $match.Success) { throw "FAIL: malformed Boss EA name $($_.Name)" }
        [pscustomobject]@{ Name = $_.BaseName; Tag = ('LAB_ENTRY_' + $match.Groups[1].Value); Source = $_ }
    })
}

function Assert-TplRequired([object]$Object, [string[]]$Fields, [string]$Label) {
    foreach ($field in $Fields) {
        $property = $Object.PSObject.Properties[$field]
        $value = if ($null -eq $property) { $null } else { $property.Value }
        $emptyCollection = ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string]) -and @($value).Count -eq 0)
        if ($null -eq $property -or $null -eq $value -or $emptyCollection -or (($value -is [string]) -and [string]::IsNullOrWhiteSpace([string]$value))) {
            throw "REFUSE: incomplete provenance: $Label.$field"
        }
    }
}

function Get-TplActiveBaseline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$ActiveSelectorPath = ''
    )
    if (-not $ActiveSelectorPath) { $ActiveSelectorPath = Join-Path $Root 'ea_template\regression_baseline.active.json' }
    $selector = Get-TplJson $ActiveSelectorPath 'active baseline selector'
    Assert-TplRequired $selector @('schema','active_manifest','active_build','historical_manifest') 'selector'
    if ($selector.schema -ne 'tpl_regression_selector/1') { throw "REFUSE: unsupported selector schema '$($selector.schema)'" }
    if ([int]$selector.active_build -ne 6090) { throw "REFUSE: active selector build is $($selector.active_build), expected 6090" }

    $manifestPath = Resolve-TplRepoPath $Root ([string]$selector.active_manifest) 'selector.active_manifest'
    $manifest = Get-TplJson $manifestPath 'active baseline manifest'
    Assert-TplRequired $manifest @('schema','status','baseline_kind','metrics_file','metrics_sha256','expected_mt5_build','terminal_executable','tester_data_directory','portable','baseline_source_commit','baseline_source_clean','accepted_runtime_lineage_tip','tester_contract','cases','generation_utc','report_freshness_evidence') 'manifest'
    if ($manifest.schema -ne 'tpl_regression_baseline/2') { throw "REFUSE: unsupported baseline manifest schema '$($manifest.schema)'" }
    if ($manifest.status -ne 'ACTIVE_COMPARABLE' -or $manifest.baseline_kind -ne 'VERSIONED') { throw "REFUSE: active manifest status is not ACTIVE_COMPARABLE/VERSIONED" }
    if ([int]$manifest.expected_mt5_build -ne 6090) { throw "REFUSE: expected MT5 build is $($manifest.expected_mt5_build), not 6090" }
    if (-not [bool]$manifest.baseline_source_clean) { throw 'REFUSE: baseline source was not clean' }

    $metricsPath = Resolve-TplRepoPath $Root ([string]$manifest.metrics_file) 'manifest.metrics_file'
    $metricsHash = Get-TplSha256 $metricsPath
    if ($metricsHash -ne ([string]$manifest.metrics_sha256).ToLowerInvariant()) { throw 'REFUSE: metrics integrity mismatch' }
    try { $metrics = @(Import-Csv -LiteralPath $metricsPath -ErrorAction Stop) }
    catch { throw "REFUSE: metrics file could not be parsed: $($_.Exception.Message)" }
    if ($metrics.Count -ne 8) { throw "FAIL: versioned metrics contains $($metrics.Count) rows, expected 8" }
    $metricFields = @('ea','net','pf','trades','eqdd')
    foreach ($row in $metrics) { Assert-TplRequired $row $metricFields 'metrics row' }

    $contract = $manifest.tester_contract
    Assert-TplRequired $contract @('symbol','timeframe','date_from','date_to','model','deposit','currency','leverage') 'manifest.tester_contract'
    if ($contract.symbol -ne 'XAUUSD' -or $contract.timeframe -ne 'H1' -or $contract.date_from -ne '2024.01.01' -or $contract.date_to -ne '2024.07.01' -or [int]$contract.model -ne 1 -or [int]$contract.deposit -ne 10000 -or $contract.currency -ne 'USD' -or [int]$contract.leverage -ne 100) {
        throw 'REFUSE: baseline tester contract is not XAUUSD/H1/2024.01.01-2024.07.01/Model1/$10000/USD/1:100'
    }

    $expected = Get-TplExpectedEas $Root
    $cases = @($manifest.cases)
    if ($cases.Count -ne 8) { throw "FAIL: manifest has $($cases.Count) EA cases, expected 8" }
    $caseNames = @($cases | ForEach-Object { [string]$_.ea })
    $expectedNames = @($expected | ForEach-Object Name)
    $missing = @($expectedNames | Where-Object { $caseNames -notcontains $_ })
    $extra = @($caseNames | Where-Object { $expectedNames -notcontains $_ })
    if ($missing.Count -gt 0) { throw "FAIL: manifest missing EA(s): $($missing -join ', ')" }
    if ($extra.Count -gt 0) { throw "FAIL: manifest has extra EA(s): $($extra -join ', ')" }

    foreach ($ea in $expected) {
        $case = @($cases | Where-Object { $_.ea -eq $ea.Name })[0]
        Assert-TplRequired $case @('ea','source_path','source_sha256','source_commit','build_receipt','compiled_artifact_path','compiled_artifact_sha256','declared_set_path','declared_set_sha256','set_surface','report_path','report_sha256','report_build','report_fresh','symbol','timeframe','date_from','date_to','model','deposit','currency','leverage','history_quality','bars','ticks','metrics') ("case $($ea.Name)")
        if ($case.source_commit -ne $manifest.baseline_source_commit) { throw "REFUSE: $($ea.Name) source identity does not match baseline commit" }
        $sourcePath = Resolve-TplRepoPath $Root ([string]$case.source_path) "$($ea.Name).source_path"
        if ((Get-TplSha256 $sourcePath) -ne ([string]$case.source_sha256).ToLowerInvariant()) { throw "REFUSE: $($ea.Name) source hash mismatch" }
        $setPath = Resolve-TplRepoPath $Root ([string]$case.declared_set_path) "$($ea.Name).declared_set_path"
        if ((Get-TplSha256 $setPath) -ne ([string]$case.declared_set_sha256).ToLowerInvariant()) { throw "REFUSE: $($ea.Name) set hash differs" }
        if (-not (Get-Command Get-SetSurfaceState -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'setfile_surface.ps1') }
        $actualSurface = Get-SetSurfaceState -Path $setPath
        if ($actualSurface.State -ne 'FULL' -or $case.set_surface.state -ne 'FULL' -or [int]$case.set_surface.declared -ne [int]$case.set_surface.assignments -or [int]$actualSurface.Declared -ne [int]$actualSurface.Assignments -or $case.set_surface.build_tag -ne $ea.Tag -or $actualSurface.BuildTag -ne $ea.Tag) { throw "REFUSE: $($ea.Name) set is not a declared full surface" }
        $reportPath = Resolve-TplRepoPath $Root ([string]$case.report_path) "$($ea.Name).report_path"
        if ((Get-TplSha256 $reportPath) -ne ([string]$case.report_sha256).ToLowerInvariant()) { throw "REFUSE: $($ea.Name) report integrity mismatch" }
        if ([int]$case.report_build -ne 6090 -or -not [bool]$case.report_fresh) { throw "REFUSE: $($ea.Name) report is not a fresh Build 6090 report" }
        if ($case.symbol -ne $contract.symbol -or $case.timeframe -ne $contract.timeframe -or $case.date_from -ne $contract.date_from -or $case.date_to -ne $contract.date_to -or [int]$case.model -ne [int]$contract.model -or [int]$case.deposit -ne [int]$contract.deposit -or $case.currency -ne $contract.currency -or [int]$case.leverage -ne [int]$contract.leverage) { throw "REFUSE: $($ea.Name) tester contract mismatch" }
        $m = $case.metrics
        foreach ($field in $metricFields | Where-Object { $_ -ne 'ea' }) { Assert-TplRequired $m @($field) "$($ea.Name).metrics" }
        $row = @($metrics | Where-Object { $_.ea -eq $ea.Name })[0]
        if ($null -eq $row -or $row.net -ne $m.net -or $row.pf -ne $m.pf -or $row.trades -ne $m.trades -or $row.eqdd -ne $m.eqdd) { throw "REFUSE: $($ea.Name) metrics file does not match manifest" }
    }
    return [pscustomobject]@{ Selector = $selector; Manifest = $manifest; Metrics = $metrics; ManifestPath = $manifestPath }
}

function Assert-TplCommitIdentity {
    param([Parameter(Mandatory)][string]$Root, [string]$Sha, [Parameter(Mandatory)][string]$Label)
    $value = $Sha.Trim()
    if ($value -notmatch '^[0-9a-fA-F]{40}$') {
        throw "REFUSE: $Label must be a full 40-hex commit SHA"
    }
    $type = (& git -C $Root cat-file -t $value 2>$null)
    if ($LASTEXITCODE -ne 0 -or ([string]$type).Trim() -ne 'commit') {
        throw "REFUSE: $Label is not a resolvable commit object: $value"
    }
    return $value.ToLowerInvariant()
}

function Assert-TplSourceContract {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][object]$Baseline)
    $git = & git -C $Root rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $git) { throw 'REFUSE: current source identity unavailable' }
    $current = ([string]$git).Trim()
    $base = Assert-TplCommitIdentity -Root $Root -Sha ([string]$Baseline.Manifest.baseline_source_commit) -Label 'baseline_source_commit'
    $runtime = Assert-TplCommitIdentity -Root $Root -Sha ([string]$Baseline.Manifest.accepted_runtime_lineage_tip) -Label 'accepted_runtime_lineage_tip'
    & git -C $Root merge-base --is-ancestor $runtime $base 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "REFUSE: accepted runtime lineage tip $runtime is not an ancestor of baseline source identity $base"
    }
    if ($current -eq $base) { return $current }
    & git -C $Root merge-base --is-ancestor $base $current 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "REFUSE: baseline source identity $base is not an ancestor of current source identity $current"
    }
    $changed = @(& git -C $Root diff --name-only ($base + '..' + $current) 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "REFUSE: source identity $current is not in the accepted comparison lineage" }
    $forbidden = @($changed | Where-Object { $_ -match '^(ea_template/(core|modules|generated)/|ea_template/Boss_.*\.mq5$|ea_template/EA_LabTemplate\.mq5$)' })
    if ($forbidden.Count -gt 0) { throw "REFUSE: source/build identity changed behavioral EA source: $($forbidden -join ', ')" }
    return $current
}

function Assert-TplCurrentReport {
    param([Parameter(Mandatory)][object]$Case, [Parameter(Mandatory)][hashtable]$Report, [Parameter(Mandatory)][string]$ReportPath, [Parameter(Mandatory)][datetime]$RunStart, [Parameter(Mandatory)][int]$RunnerExit)
    if ($RunnerExit -ne 0) { throw "REFUSE: $($Case.ea) runner did not produce a comparable report (exit $RunnerExit)" }
    if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) { throw "REFUSE: $($Case.ea) stale/missing report" }
    if ((Get-Item -LiteralPath $ReportPath).LastWriteTime -lt $RunStart) { throw "REFUSE: $($Case.ea) stale report" }
    if ([int]$Report.report_build -ne 6090) { throw "NONCOMPARABLE: $($Case.ea) report Build $($Report.report_build), expected 6090" }
    if ($Report.symbol -ne $Case.symbol -or $Report.period -ne $Case.timeframe -or $Report.from_date -ne $Case.date_from -or $Report.to_date -ne $Case.date_to -or [int]$Report.model -ne [int]$Case.model -or [int]$Report.initial_deposit -ne [int]$Case.deposit -or $Report.currency -ne $Case.currency -or $Report.leverage -ne ('1:' + [string]$Case.leverage)) { throw "REFUSE: $($Case.ea) tester contract mismatch" }
}
