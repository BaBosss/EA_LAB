[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Upstream = [ordered]@{
    repository = 'DietrichGebert/ponytail'
    commit = '2ed6c52c9d7e5e56942508591085fd45dea277d3'
    version = '4.9.0'
}

$Preserve = @(
    'validation',
    'error_handling',
    'security',
    'accessibility_when_applicable',
    'observability_and_diagnostics',
    'deterministic_fail_closed_behavior',
    'tests_cages_and_negative_tests',
    'evidence_and_auditability',
    'owner_hard_stop_guards'
)

$ProtectedWorkTypes = @('core','execution','position','accounting','money','risk','runtime','deployment','trading','live')
$LowRiskWorkTypes = @('tooling','docs','test','tests','script','adapter','research')
$ValidModes = @('auto','off','lite','full','ultra','review')

function Write-ResultAndExit {
    param(
        [string]$Decision,
        [string]$EffectiveMode,
        [bool]$Allowed,
        [string[]]$Reasons,
        [string]$Overlay,
        [int]$ExitCode
    )
    $result = [ordered]@{
        schema_version = '1.0'
        decision = $Decision
        allowed = $Allowed
        effective_mode = $EffectiveMode
        reasons = @($Reasons)
        optimization_target = 'minimum_necessary_complexity'
        preserve = @($Preserve)
        worker_overlay = $Overlay
        authority_granted = $false
        upstream = $Upstream
    }
    $result | ConvertTo-Json -Depth 8
    exit $ExitCode
}

function Get-OptionalPropertyValue {
    param($Object, [string]$Name)
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Normalize-PathValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $p = $Value.Trim().Replace('\','/').TrimStart('./')
    while ($p.Contains('//')) { $p = $p.Replace('//','/') }
    return $p.ToLowerInvariant()
}

function Test-UnsafeOrTraversalPath {
    param([string]$PathValue)
    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $true }
    $raw = $PathValue.Trim().Replace('\','/')
    if ($raw -match '^[a-zA-Z]:' -or $raw.StartsWith('/') -or $raw.StartsWith('//')) { return $true }
    if ($raw -eq '..' -or $raw.StartsWith('../') -or $raw.EndsWith('/..') -or $raw.Contains('/../')) { return $true }
    return $false
}

function Test-ProtectedPath {
    param([string]$PathValue)
    $p = Normalize-PathValue $PathValue
    if ($null -eq $p) { return $false }
    if ($p -match '(^|/)ea_template/core(/|$)') { return $true }
    if ($p -match '(^|/)ea_projects(/|$)') { return $true }
    if ($p -match '\.(mq4|mq5|mqh)$') { return $true }
    if ($p -match '(^|/)(_vps_deploy|_demo_deploy|_mt5_auto|_mt4_auto)(/|$)') { return $true }
    if ($p -eq 'portfolio/deployments.csv') { return $true }
    if ($p -match '^scripts/.+\.ps1$') {
        $relative = $p.Substring('scripts/'.Length)
        foreach ($segment in ($relative -split '/')) {
            if ($segment -match '(mt4|mt5|deploy|live|risk)') { return $true }
        }
    }
    return $false
}

function Test-LowRiskPath {
    param([string]$PathValue)
    $p = Normalize-PathValue $PathValue
    if ($null -eq $p) { return $false }
    if ($p -match '^(tools|docs|scripts|skills|templates)/') { return $true }
    if ($p -match '\.(md|txt)$') { return $true }
    return $false
}

$fullOverlay = 'Read and trace the touched flow first. Use the first rung that satisfies the task: skip unnecessary work; reuse existing code and accepted evidence; prefer standard library; prefer native platform capability; prefer an already-installed dependency; then implement the simplest local solution. Optimize for minimum necessary complexity, not minimum LOC. Never cut validation, error handling, security, applicable accessibility, observability/diagnostics, deterministic fail-closed behavior, tests/cages, evidence/auditability, or owner hard-stop guards. Existing EA_LAB governance and acceptance remain authoritative.'
$liteOverlay = 'Prefer reuse, standard library, native platform capability, and the simplest local implementation. Do not add abstractions or dependencies without a direct task need. Optimize for minimum necessary complexity, not minimum LOC. Preserve every EA_LAB safety, observability, test, evidence, and hard-stop guard.'
$reviewOverlay = 'Review only. Identify unnecessary new abstractions, dependencies, duplication, or code that can be removed without changing behavior. Do not modify protected code under this decision. Never recommend removing validation, error handling, security, applicable accessibility, observability/diagnostics, deterministic fail-closed behavior, tests/cages, evidence/auditability, or owner hard-stop guards merely to reduce code.'

try {
    $raw = [IO.File]::ReadAllText($InputPath, [Text.Encoding]::UTF8)
    $contract = $raw | ConvertFrom-Json
} catch {
    Write-ResultAndExit 'REFUSE' 'review' $false @('invalid_or_unreadable_contract') $reviewOverlay 2
}

$modeValue = Get-OptionalPropertyValue $contract 'requested_mode'
$workTypeValue = Get-OptionalPropertyValue $contract 'work_type'
$pathsValue = Get-OptionalPropertyValue $contract 'paths'
$mode = if ($null -ne $modeValue) { ([string]$modeValue).Trim().ToLowerInvariant() } else { '' }
$workType = if ($null -ne $workTypeValue) { ([string]$workTypeValue).Trim().ToLowerInvariant() } else { '' }
$paths = @()
if ($null -ne $pathsValue) { $paths = @($pathsValue | ForEach-Object { [string]$_ }) }

if ([string]::IsNullOrWhiteSpace($mode) -or $ValidModes -notcontains $mode) {
    Write-ResultAndExit 'REFUSE' 'review' $false @('unknown_requested_mode') $reviewOverlay 2
}
if ([string]::IsNullOrWhiteSpace($workType) -or $paths.Count -eq 0) {
    Write-ResultAndExit 'REFUSE' 'review' $false @('contract_requires_work_type_and_paths') $reviewOverlay 2
}

if ($mode -eq 'off') {
    Write-ResultAndExit 'ALLOW' 'off' $true @('ponytail_disabled_by_contract') '' 0
}
if ($mode -eq 'ultra') {
    Write-ResultAndExit 'REFUSE' 'review' $false @('ultra_disabled_in_ea_lab_v1','use_review_or_bounded_full_instead') $reviewOverlay 2
}
if ($mode -eq 'review') {
    Write-ResultAndExit 'ALLOW' 'review' $true @('explicit_review_only_mode') $reviewOverlay 0
}

$reasons = New-Object System.Collections.Generic.List[string]
$protected = $false
$unclassified = $false

if ($ProtectedWorkTypes -contains $workType) {
    $protected = $true
    $reasons.Add("protected_work_type:$workType")
} elseif ($LowRiskWorkTypes -notcontains $workType) {
    $unclassified = $true
    $reasons.Add("unclassified_work_type:$workType")
}

foreach ($pathValue in $paths) {
    if (Test-UnsafeOrTraversalPath $pathValue) {
        $unclassified = $true
        $reasons.Add("unsafe_or_unclassified_path:$pathValue")
        continue
    }
    if (Test-ProtectedPath $pathValue) {
        $protected = $true
        $reasons.Add("protected_path:$pathValue")
    } elseif (-not (Test-LowRiskPath $pathValue)) {
        $unclassified = $true
        $reasons.Add("unclassified_path:$pathValue")
    }
}

if ($protected) {
    Write-ResultAndExit 'DOWNGRADE' 'review' $true (@($reasons) + 'protected_surface_is_review_only') $reviewOverlay 0
}
if ($unclassified) {
    Write-ResultAndExit 'DOWNGRADE' 'review' $true (@($reasons) + 'fail_closed_to_review') $reviewOverlay 0
}

if ($mode -eq 'auto') {
    Write-ResultAndExit 'ALLOW' 'full' $true @('low_risk_surface','auto_selects_full') $fullOverlay 0
}
if ($mode -eq 'full') {
    Write-ResultAndExit 'ALLOW' 'full' $true @('low_risk_surface','explicit_full') $fullOverlay 0
}
if ($mode -eq 'lite') {
    Write-ResultAndExit 'ALLOW' 'lite' $true @('low_risk_surface','explicit_lite') $liteOverlay 0
}

Write-ResultAndExit 'REFUSE' 'review' $false @('unreachable_mode_state') $reviewOverlay 2