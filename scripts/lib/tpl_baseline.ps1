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

function Get-TplBossEasOnDisk([string]$Root) {
    $files = @(Get-ChildItem -LiteralPath (Join-Path $Root 'ea_template') -Filter 'Boss_*.mq5' -File | Sort-Object Name)
    if ($files.Count -eq 0) { throw 'FAIL: no canonical Boss EA wrappers found on disk under ea_template\' }
    $seenNames = @{}
    $seenTags = @{}
    return @($files | ForEach-Object {
        $match = [regex]::Match($_.BaseName, '^Boss_(\d+)_')
        if (-not $match.Success) { throw "FAIL: malformed Boss EA name $($_.Name)" }
        $tag = 'LAB_ENTRY_' + $match.Groups[1].Value
        if ($seenNames.ContainsKey($_.BaseName)) { throw "FAIL: duplicate Boss EA wrapper name on disk: $($_.Name)" }
        if ($seenTags.ContainsKey($tag)) { throw "FAIL: duplicate Boss EA LAB entry on disk: $tag" }
        $seenNames[$_.BaseName] = $true
        $seenTags[$tag] = $true
        [pscustomobject]@{
            Name = $_.BaseName
            Tag = $tag
            Source = $_
            RelativePath = Get-TplRelativePath -Root $Root -Path $_.FullName
        }
    })
}

function Get-TplWrapperOwnerRows([string]$Root) {
    $path = Join-Path $Root '_triage\factory_os\wrapper_owners.csv'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "REFUSE: wrapper owner registry missing: $path" }
    try { $lines = @(Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction Stop) }
    catch { throw "REFUSE: wrapper owner registry could not be read: $($_.Exception.Message)" }
    if ($lines.Count -lt 2 -or $lines[0] -cne 'build_tag,wrapper_rel') { throw 'REFUSE: wrapper owner registry header must be exactly build_tag,wrapper_rel' }
    $rows = New-Object System.Collections.Generic.List[object]
    $seenTags = @{}; $seenPaths = @{}
    for ($i=1; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { throw "REFUSE: blank wrapper owner row at line $($i+1)" }
        $parts = @($line.Split(','))
        if ($parts.Count -ne 2) { throw "REFUSE: wrapper owner row must have exactly 2 fields at line $($i+1)" }
        $tag=$parts[0].Trim(); $rel=$parts[1].Trim().Replace('\','/')
        if ($tag -notmatch '^LAB_ENTRY_\d+$') { throw "REFUSE: malformed wrapper build tag at line $($i+1): $tag" }
        if ($rel -notmatch '^ea_template/[^/]+\.mq5$' -or $rel.Contains('/./') -or $rel.Contains('../')) { throw "REFUSE: malformed wrapper owner path at line $($i+1): $rel" }
        if ($seenTags.ContainsKey($tag)) { throw "REFUSE: duplicate wrapper build tag: $tag" }
        if ($seenPaths.ContainsKey($rel.ToLowerInvariant())) { throw "REFUSE: duplicate wrapper owner path: $rel" }
        $seenTags[$tag]=$true; $seenPaths[$rel.ToLowerInvariant()]=$true
        $rows.Add([pscustomobject]@{Tag=$tag; RelativePath=$rel})
    }
    return $rows.ToArray()
}
function Get-TplHistoricalAndUnbaselinedEas([string]$Root, [object[]]$Cases) {
    $caseNames = @($Cases | ForEach-Object { [string]$_.ea })
    $caseNameSet = @($caseNames | Select-Object -Unique)
    if ($caseNameSet.Count -ne $caseNames.Count) {
        $dupes = @($caseNames | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object Name)
        throw "FAIL: manifest declares duplicate EA case name(s): $($dupes -join ', ')"
    }

    $historical = @($Cases | ForEach-Object {
        $match = [regex]::Match([string]$_.ea, '^Boss_(\d+)_')
        if (-not $match.Success) { throw "FAIL: malformed manifest Boss EA name $($_.ea)" }
        [pscustomobject]@{
            Name = [string]$_.ea
            Tag = 'LAB_ENTRY_' + $match.Groups[1].Value
            RelativePath = ([string]$_.source_path).Replace('\','/')
            SourcePath = ([string]$_.source_path).Replace('\','/')
        }
    })
    $duplicateHistoricalTags = @($historical | Group-Object Tag | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicateHistoricalTags.Count -gt 0) { throw "FAIL: manifest declares duplicate LAB entry tag(s): $($duplicateHistoricalTags -join ', ')" }

    $disk = @(Get-TplBossEasOnDisk $Root)
    $diskNames = @($disk | ForEach-Object Name)
    $missing = @($historical | Where-Object { $diskNames -notcontains $_.Name } | ForEach-Object Name)
    if ($missing.Count -gt 0) { throw "FAIL: historical manifest Boss wrapper missing or renamed: $($missing -join ', ')" }
    foreach ($ea in $historical) {
        $expectedPath = "ea_template/$($ea.Name).mq5"
        if ($ea.RelativePath -ne $expectedPath) { throw "REFUSE: historical manifest Boss path mismatch for $($ea.Name): $($ea.RelativePath)" }
        $actual = @($disk | Where-Object Name -eq $ea.Name)[0]
        if ($actual.Tag -ne $ea.Tag -or $actual.RelativePath -ne $expectedPath) { throw "REFUSE: historical manifest Boss identity mismatch for $($ea.Name)" }
        $ea | Add-Member -NotePropertyName Source -NotePropertyValue $actual.Source
    }

    $owners = @(Get-TplWrapperOwnerRows $Root)
    foreach ($ea in $disk) {
        $related = @($owners | Where-Object { $_.Tag -eq $ea.Tag -or $_.RelativePath -eq $ea.RelativePath })
        $exact = @($related | Where-Object { $_.Tag -eq $ea.Tag -and $_.RelativePath -eq $ea.RelativePath })
        if ($exact.Count -eq 0) { throw "REFUSE: unregistered or mismatched Boss wrapper: $($ea.Tag) $($ea.RelativePath)" }
        if ($exact.Count -ne 1 -or $related.Count -ne 1) { throw "REFUSE: duplicate or conflicting Boss wrapper owner registration: $($ea.Tag) $($ea.RelativePath)" }
    }
    $extras = @($disk | Where-Object { $caseNames -notcontains $_.Name } | ForEach-Object {
        [pscustomobject]@{ Name = $_.Name; Tag = $_.Tag; SourcePath = $_.RelativePath; RelativePath = $_.RelativePath; Source = $_.Source }
    })
    return [pscustomobject]@{ HistoricalEas = $historical; UnbaselinedEas = $extras }
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

    $cases = @($manifest.cases)
    if ($cases.Count -eq 0) { throw 'FAIL: manifest declares zero EA cases' }
    $cohorts = Get-TplHistoricalAndUnbaselinedEas -Root $Root -Cases $cases
    $expected = @($cohorts.HistoricalEas)

    $metricsPath = Resolve-TplRepoPath $Root ([string]$manifest.metrics_file) 'manifest.metrics_file'
    $metricsHash = Get-TplSha256 $metricsPath
    if ($metricsHash -ne ([string]$manifest.metrics_sha256).ToLowerInvariant()) { throw 'REFUSE: metrics integrity mismatch' }
    try { $metrics = @(Import-Csv -LiteralPath $metricsPath -ErrorAction Stop) }
    catch { throw "REFUSE: metrics file could not be parsed: $($_.Exception.Message)" }
    $expectedMetricCount = $cases.Count
    if ($metrics.Count -ne $expectedMetricCount) { throw "FAIL: versioned metrics contains $($metrics.Count) rows, expected $expectedMetricCount" }
    $metricFields = @('ea','net','pf','trades','eqdd')
    foreach ($row in $metrics) { Assert-TplRequired $row $metricFields 'metrics row' }

    $contract = $manifest.tester_contract
    Assert-TplRequired $contract @('symbol','timeframe','date_from','date_to','model','deposit','currency','leverage') 'manifest.tester_contract'
    if ($contract.symbol -ne 'XAUUSD' -or $contract.timeframe -ne 'H1' -or $contract.date_from -ne '2024.01.01' -or $contract.date_to -ne '2024.07.01' -or [int]$contract.model -ne 1 -or [int]$contract.deposit -ne 10000 -or $contract.currency -ne 'USD' -or [int]$contract.leverage -ne 100) {
        throw 'REFUSE: baseline tester contract is not XAUUSD/H1/2024.01.01-2024.07.01/Model1/$10000/USD/1:100'
    }

    $caseNames = @($cases | ForEach-Object { [string]$_.ea })

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
    return [pscustomobject]@{
        Selector = $selector
        Manifest = $manifest
        Metrics = $metrics
        ManifestPath = $manifestPath
        HistoricalEas = $cohorts.HistoricalEas
        UnbaselinedEas = $cohorts.UnbaselinedEas
        RegisteredUnbaselinedEas = $cohorts.UnbaselinedEas
    }
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

function Assert-TplAdjacentControlContract {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ControlRef,
        [Parameter(Mandatory)][object]$Baseline,
        [object[]]$RegisteredUnbaselinedEas = @()
    )
    $control = Assert-TplCommitIdentity -Root $Root -Sha $ControlRef -Label 'AdjacentControlRef'
    $head = (& git -C $Root rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $head) { throw 'REFUSE: current source identity unavailable' }
    $head = ([string]$head).Trim().ToLowerInvariant()
    $parent = (& git -C $Root rev-parse 'HEAD^' 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $parent -or ([string]$parent).Trim().ToLowerInvariant() -ne $control) {
        throw "REFUSE: AdjacentControlRef must be the immediate parent of HEAD $head"
    }

    $pending = if ($RegisteredUnbaselinedEas.Count -gt 0) {
        @($RegisteredUnbaselinedEas)
    } elseif ($null -ne $Baseline.PSObject.Properties['RegisteredUnbaselinedEas']) {
        @($Baseline.RegisteredUnbaselinedEas)
    } elseif ($null -ne $Baseline.PSObject.Properties['UnbaselinedEas']) {
        @($Baseline.UnbaselinedEas)
    } else { @() }
    if ($pending.Count -eq 0) { throw 'REFUSE: adjacent control requires at least one registered unbaselined Boss wrapper' }

    $historicalPaths = if ($null -ne $Baseline.PSObject.Properties['HistoricalEas']) {
        @($Baseline.HistoricalEas | ForEach-Object { if ($_.SourcePath) { [string]$_.SourcePath } else { [string]$_.RelativePath } })
    } else {
        @($Baseline.Manifest.cases | ForEach-Object { [string]$_.source_path })
    }
    foreach ($path in $historicalPaths) {
        & git -C $Root diff --quiet ($control + '..' + $head) -- $path 2>$null
        if ($LASTEXITCODE -ne 0) { throw "REFUSE: historical baseline Boss wrapper changed control->HEAD: $path" }
    }

    $addedPending = @()
    foreach ($ea in $pending) {
        $path = if ($ea.SourcePath) { [string]$ea.SourcePath } else { [string]$ea.RelativePath }
        if ([string]::IsNullOrWhiteSpace($path)) { throw 'REFUSE: registered unbaselined Boss wrapper has no source path' }
        $status = @(& git -C $Root diff --name-status ($control + '..' + $head) -- $path 2>$null)
        if ($LASTEXITCODE -ne 0) { throw "REFUSE: unable to reconcile registered unbaselined Boss wrapper against control: $path" }
        if ($status.Count -eq 1 -and ([string]$status[0]) -match '^A\s+') {
            $addedPending += $path
        } elseif ($status.Count -gt 0) {
            throw "REFUSE: registered unbaselined Boss wrapper has a non-addition change against control: $path"
        }
    }
    if ($addedPending.Count -eq 0) { throw 'REFUSE: adjacent control has no newly added registered unbaselined Boss wrapper' }
    return $control
}

function Assert-TplSourceContract {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][object]$Baseline,
        [string]$AdjacentControlRef = '',
        [object[]]$RegisteredUnbaselinedEas = @()
    )
    $git = & git -C $Root rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $git) { throw 'REFUSE: current source identity unavailable' }
    $current = ([string]$git).Trim()
    $base = Assert-TplCommitIdentity -Root $Root -Sha ([string]$Baseline.Manifest.baseline_source_commit) -Label 'baseline_source_commit'
    $runtime = Assert-TplCommitIdentity -Root $Root -Sha ([string]$Baseline.Manifest.accepted_runtime_lineage_tip) -Label 'accepted_runtime_lineage_tip'
    & git -C $Root merge-base --is-ancestor $runtime $base 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "REFUSE: accepted runtime lineage tip $runtime is not an ancestor of baseline source identity $base"
    }
    if ($current -eq $base -and -not $AdjacentControlRef) { return $current }
    & git -C $Root merge-base --is-ancestor $base $current 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "REFUSE: baseline source identity $base is not an ancestor of current source identity $current"
    }
    if ($AdjacentControlRef) {
        Assert-TplAdjacentControlContract -Root $Root -ControlRef $AdjacentControlRef -Baseline $Baseline -RegisteredUnbaselinedEas $RegisteredUnbaselinedEas | Out-Null
        return $current
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
