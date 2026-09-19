<#
Deterministic source/adversarial checks for the bounded B17 structural-SL / ATR-exit seam.
This runner never launches MetaEditor, an MT5 terminal, or Strategy Tester.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$exitPath = Join-Path $RepoRoot 'ea_template\core\ExitManager.mqh'
$corePath = Join-Path $RepoRoot 'ea_template\core\LabCore.mqh'
$entryPath = Join-Path $RepoRoot 'ea_template\core\entries\Entry_Wave5.mqh'
$fixturePath = Join-Path $RepoRoot 'ea_template\tests\B17_StructSL_ATRExit_Test.mq5'
$registryPath = Join-Path $RepoRoot 'docs\PARAM_REGISTRY.csv'
$linkagePath = Join-Path $RepoRoot 'docs\PARAM_LINKAGE.md'

$paths = @($exitPath, $corePath, $entryPath, $fixturePath, $registryPath, $linkagePath)
foreach ($path in $paths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing required file: $path" }
}

$exitSource = [IO.File]::ReadAllText($exitPath)
$coreSource = [IO.File]::ReadAllText($corePath)
$entrySource = [IO.File]::ReadAllText($entryPath)
$fixtureSource = [IO.File]::ReadAllText($fixturePath)
$registrySource = [IO.File]::ReadAllText($registryPath)
$linkageSource = [IO.File]::ReadAllText($linkagePath)
$failures = [Collections.Generic.List[string]]::new()

function Add-Failure([string]$Message) {
    [void]$script:failures.Add($Message)
    Write-Host "[B17] FAIL: $Message" -ForegroundColor Red
}

function Add-Pass([string]$Message) {
    Write-Host "[B17] PASS: $Message" -ForegroundColor Green
}

function Require-Match([string]$Text, [string]$Pattern, [string]$Message) {
    if ($Text -notmatch $Pattern) { Add-Failure $Message } else { Add-Pass $Message }
}

function Get-B17RoutingMap([string]$Text) {
    $helper = [regex]::Match(
        $Text,
        '(?ms)bool\s+Exit_B17StructTPOverridesMode\s*\([^)]*\)\s*\{(?<body>.*?)\r?\n\}'
    )
    if (-not $helper.Success) { throw 'pure B17 structural-TP routing helper not found' }

    $map = @{}
    $groups = [regex]::Matches(
        $helper.Groups['body'].Value,
        '(?ms)(?<cases>(?:\s*case\s+EXIT_[A-Z_]+\s*:\s*)+)(?:\s*default\s*:\s*)?return\s+(?<value>true|false)\s*;'
    )
    foreach ($group in $groups) {
        $value = $group.Groups['value'].Value -eq 'true'
        foreach ($case in [regex]::Matches($group.Groups['cases'].Value, 'EXIT_[A-Z_]+')) {
            $map[$case.Value] = $value
        }
    }
    return $map
}

function Assert-B17RoutingPolicy([string]$Text, [string]$Label) {
    $map = Get-B17RoutingMap $Text
    $expected = [ordered]@{
        EXIT_FIXED_TP = $true
        EXIT_ATR_TP = $false
        EXIT_TRAIL = $false
        EXIT_RUN_TREND = $false
        EXIT_STRUCTURAL_TARGET = $true
    }
    foreach ($name in $expected.Keys) {
        if (-not $map.ContainsKey($name)) { throw "${Label}: route missing for $name" }
        if ($map[$name] -ne $expected[$name]) {
            throw "${Label}: route for $name was $($map[$name]), expected $($expected[$name])"
        }
    }
}

try {
    Assert-B17RoutingPolicy $exitSource 'canonical source'
    Add-Pass 'pure helper routes all current ExitMode values with ATR generic-owned'
} catch {
    Add-Failure $_.Exception.Message
}

# Mutation probe: emulate the precise regression this contract prevents by moving
# EXIT_ATR_TP into the structural-override case group. The policy assertion must fail.
$mutated = [regex]::Replace($exitSource, '(?m)^\s*case EXIT_ATR_TP:\s*\r?\n', '')
$mutated = $mutated.Replace('      case EXIT_FIXED_TP:', "      case EXIT_FIXED_TP:`r`n      case EXIT_ATR_TP:")
$mutationRejected = $false
try {
    Assert-B17RoutingPolicy $mutated 'ATR override mutation'
} catch {
    $mutationRejected = $true
}
if ($mutationRejected) { Add-Pass 'adversarial ATR-to-override mutation is rejected' }
else { Add-Failure 'adversarial ATR-to-override mutation was not rejected' }

$suppressIndex = $exitSource.IndexOf('if(_2_SuppressLegTP) return 0.0;')
$routeIndex = $exitSource.IndexOf('Exit_B17StructTPOverridesMode(ExitMode)', $suppressIndex + 1)
if ($suppressIndex -ge 0 -and $routeIndex -gt $suppressIndex) {
    Add-Pass '_2_SuppressLegTP remains before the B17 structural-TP route'
} else {
    Add-Failure '_2_SuppressLegTP is missing or no longer precedes the B17 structural-TP route'
}

Require-Match $exitSource '_17_UseStructLevels\s*&&\s*g_wave5_tp_price\s*>\s*0\.0\s*&&\s*Exit_B17StructTPOverridesMode\(ExitMode\)' 'Exit_InitialTP uses the pure B17 routing truth'
Require-Match $coreSource 'Exit_B17StructTPOverridesMode\(ExitMode\)' 'LabCore config reporting uses the same pure B17 routing truth'
Require-Match $coreSource 'structural TP override INACTIVE: generic ATR Exit ACTIVE' 'LabCore contains the ATR-specific truthful config message'

Require-Match $coreSource 'if\(_17_UseStructLevels\s*&&\s*StackMode\s*!=\s*STACK_SINGLE\)' 'B17 STACK_SINGLE structural safety guard remains present'
Require-Match $coreSource 'if\(_17_UseStructLevels\s*&&\s*RecoveryMode\s*!=\s*REC_NONE\)' 'B17 Recovery OFF structural safety guard remains present'
Require-Match $coreSource 'if\(_17_UseStructLevels\s*&&\s*HedgeMode\s*!=\s*HEDGE_OFF\)' 'B17 Hedge OFF structural safety guard remains present'

Require-Match $entrySource 'g_wave5_sl_price\s*=\s*slPrice\s*;' 'Entry_Wave5 structural SL publication remains present'
Require-Match $entrySource 'g_wave5_tp_price\s*=\s*\(dir\s*==\s*1\s*\?\s*px\s*\+\s*wave1Len\s*:\s*px\s*-\s*wave1Len\s*\)\s*;' 'Entry_Wave5 TP-reference publication remains unchanged'

foreach ($mode in @('EXIT_FIXED_TP', 'EXIT_ATR_TP', 'EXIT_TRAIL', 'EXIT_RUN_TREND', 'EXIT_STRUCTURAL_TARGET')) {
    Require-Match $fixtureSource ([regex]::Escape("B17_ExpectRoute($mode")) "focused fixture directly exercises $mode"
}
Require-Match $fixtureSource 'g_wave5_tp_price\s*=\s*987654\.321' 'focused fixture supplies a non-zero adversarial structural target'
Require-Match $fixtureSource 'Exit_StructSLMissing\(0\.0\)' 'focused fixture exercises the unchanged structural-SL seam'
if ($fixtureSource -match '(?im)\b(OrderSend|Exec_Open|Exec_PlacePending|trade\.(Buy|Sell))\b') {
    Add-Failure 'focused fixture contains an order-opening call'
} else {
    Add-Pass 'focused fixture contains no order-opening call'
}

Require-Match $registrySource 'generic ATR TP remains owned by ExitMode' 'PARAM_REGISTRY records ATR generic ownership under B17 structural mode'
Require-Match $registrySource 'EXIT_FIXED_TP/EXIT_STRUCTURAL_TARGET' 'PARAM_REGISTRY limits the B17 structural-TP override set'
Require-Match $linkageSource 'generic ATR TP remains owned by ExitMode' 'generated PARAM_LINKAGE records ATR generic ownership'
Require-Match $linkageSource 'EXIT_FIXED_TP/EXIT_STRUCTURAL_TARGET' 'generated PARAM_LINKAGE records the legacy structural-override set'

if ($failures.Count -gt 0) {
    Write-Host "[B17] FAILED: $($failures.Count) deterministic check(s) failed" -ForegroundColor Red
    exit 1
}

Write-Host '[B17] ALL PASS: source, adversarial mutation, fixture, logging, safety guards, and parameter truth' -ForegroundColor Green
exit 0
