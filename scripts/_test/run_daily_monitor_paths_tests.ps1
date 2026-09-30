<#
.SYNOPSIS
    Offline cage for DailyMonitor repository-path portability.

.DESCRIPTION
    Exercises the repository-root resolver without invoking daily_monitor.ps1 or any
    monitor helper. The test only reads source files and computes expected paths.
    It deliberately uses both the legacy checkout and this repair worktree as the
    two public path-resolution cases.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve test directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}

. (Join-Path $RepoRoot 'scripts\lib\repo_paths.ps1')

$script:pass = 0
$script:fail = 0
function Assert-Equal {
    param([string]$What, $Expected, $Actual)
    if ("$Expected" -eq "$Actual") {
        $script:pass++
        Write-Host "[PASS] $What" -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host "[FAIL] $What`n       expected: $Expected`n       actual:   $Actual" -ForegroundColor Red
    }
}
function Assert-True {
    param([string]$What, [bool]$Condition)
    Assert-Equal $What $true $Condition
}
function Test-DetectorInvocationRoot {
    param([object[]]$Invocation, [string]$ExpectedRoot)
    $rootIndex = [Array]::IndexOf($Invocation, '-Root')
    return ($rootIndex -ge 0 -and
            ($rootIndex + 1) -lt $Invocation.Count -and
            "$($Invocation[$rootIndex + 1])" -eq $ExpectedRoot)
}

$legacyScript = 'D:\EA_LAB\scripts\daily_monitor.ps1'
$repairScript = Join-Path $RepoRoot 'scripts\daily_monitor.ps1'
$legacyRoot = Resolve-EaLabRepoRoot -AnchorPath $legacyScript
$repairRoot = Resolve-EaLabRepoRoot -AnchorPath $repairScript

Write-Host '=== DailyMonitor repository-path portability ==='
Assert-Equal 'legacy script resolves to the legacy repository root' 'D:\EA_LAB' $legacyRoot
Assert-Equal 'repair script resolves to its arbitrary worktree root' $RepoRoot $repairRoot
Assert-Equal 'legacy portfolio path remains path-equivalent' 'D:\EA_LAB\portfolio\live_deals' (Get-EaLabPath -RepoRoot $legacyRoot -RelativePath 'portfolio\live_deals')
Assert-Equal 'repair portfolio path follows the repair worktree' (Join-Path $RepoRoot 'portfolio\live_deals') (Get-EaLabPath -RepoRoot $repairRoot -RelativePath 'portfolio\live_deals')

$chain = @(
    'scripts\daily_monitor.ps1',
    'scripts\monitor_rotation.ps1',
    'scripts\collect_live_deals.ps1',
    'scripts\collect_vps_transport.ps1',
    'scripts\lib\onedrive_paths.ps1',
    'scripts\news_calendar.ps1',
    'scripts\mris\mris_run.ps1',
    'scripts\mris\mris_web_feeder.ps1',
    'scripts\mris\mris_macro_feeder.ps1',
    'scripts\mris\mris_classify.ps1',
    'scripts\mris\mris_crisis_models.ps1',
    'scripts\mris\mris_exposure.ps1',
    'scripts\mris\mris_brief.ps1',
    'scripts\mris\mris_alert.ps1',
    'scripts\mris\mris_notify.ps1',
    'scripts\publish_guard_feeds_to_vps.ps1',
    'scripts\mris\mris_export_regime.ps1',
    'scripts\live_dashboard.ps1',
    'scripts\control_room_snapshot.ps1',
    'scripts\detector_digest.ps1',
    'scripts\lib\monitor_coverage.ps1',
    'scripts\lib\snapshot_reader.ps1',
    'scripts\publish_dashboard_gist.ps1'
)

$legacyLiteral = 'D:\EA_LAB'
$executionHardCodes = @()
$allowedPrimaryRootDefaults = 0
$allSource = @{}
foreach ($relative in $chain) {
    $path = Join-Path $RepoRoot $relative
    Assert-True "execution-chain file exists: $relative" (Test-Path -LiteralPath $path -PathType Leaf)
    $lines = @(Get-Content -LiteralPath $path)
    $allSource[$relative] = ($lines -join "`n")
    foreach ($line in $lines) {
        if ($line -notmatch '^\s*#' -and $line.Contains($legacyLiteral)) {
            # L9 execution-context contract: this ONE literal is an external operator-workspace
            # identity, not a repository I/O root. control_room_snapshot.ps1 compares the current
            # checkout against it to decide whether gitignored compiled artifacts can be trusted.
            # Keep the exception exact so any second D:\EA_LAB operational literal still fails.
            if ($relative -eq 'scripts\control_room_snapshot.ps1' -and
                $line.Trim() -eq "[string]`$PrimaryRepoRoot = 'D:\EA_LAB'") {
                $allowedPrimaryRootDefaults++
                continue
            }
            $executionHardCodes += "$relative :: $line"
        }
    }
}
Assert-Equal 'exactly one declared PrimaryRepoRoot external-identity default exists' 1 $allowedPrimaryRootDefaults
Assert-Equal 'no other execution-chain operational literal D:\EA_LAB remains' 0 $executionHardCodes.Count

$parseErrors = @()
foreach ($relative in $chain) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $RepoRoot $relative),
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null
    if (@($errors).Count -gt 0) {
        $parseErrors += "$relative :: $(@($errors)[0].Message)"
    }
}
$resolverTokens = $null
$resolverErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $RepoRoot 'scripts\lib\repo_paths.ps1'),
    [ref]$resolverTokens,
    [ref]$resolverErrors
) | Out-Null
if (@($resolverErrors).Count -gt 0) {
    $parseErrors += "scripts\lib\repo_paths.ps1 :: $(@($resolverErrors)[0].Message)"
}
Assert-Equal 'execution chain and resolver parse without PowerShell errors' 0 $parseErrors.Count

Assert-True 'MetaQuotes Common Files remains an explicit external path' (($allSource.Values -join "`n") -match 'MetaQuotes\\Terminal\\Common\\Files')
Assert-True 'OneDrive VPS staging resolves through the Personal UserFolder contract' `
    ($allSource['scripts\lib\onedrive_paths.ps1'] -match 'Accounts\\Personal' -and
     $allSource['scripts\lib\onedrive_paths.ps1'] -match 'EA_LAB_VPS_SYNC' -and
     $allSource['scripts\publish_guard_feeds_to_vps.ps1'] -match 'Resolve-EaLabPersonalOneDriveRoot')
Assert-True 'DailyMonitor still owns its generated audit commit surface' ($allSource['scripts\daily_monitor.ps1'] -match "portfolio/live_deals" -and $allSource['scripts\daily_monitor.ps1'] -match 'git commit')
Assert-True 'DailyMonitor invokes VPS return ingest before snapshot build' `
    ($allSource['scripts\daily_monitor.ps1'].IndexOf("Step 'vps-return'") -ge 0 -and
     $allSource['scripts\daily_monitor.ps1'].IndexOf("Step 'vps-return'") -lt $allSource['scripts\daily_monitor.ps1'].IndexOf("Step 'snapshot'"))

# Execute only the two shipped detector call-site statements with a bounded stub. This
# proves their argument binding from a caller cwd unrelated to the repository without
# invoking DailyMonitor, detector_digest, or any other monitor-chain component.
$dailyMonitorPath = Join-Path $RepoRoot 'scripts\daily_monitor.ps1'
$dailyTokens = $null
$dailyParseErrors = $null
$dailyAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $dailyMonitorPath,
    [ref]$dailyTokens,
    [ref]$dailyParseErrors
)
$detectorCalls = @($dailyAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.PipelineAst] -and
    $node.Extent.Text -match '^\s*powershell\s+-NoProfile\s+-File\s+\$detectorDigest(?:\s|$)'
}, $true))
Assert-Equal 'exactly two shipped detector call sites are present' 2 $detectorCalls.Count

$fixtureCwd = Join-Path ([System.IO.Path]::GetTempPath()) ("daily-monitor-root-cage-{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureCwd | Out-Null
$originalLocation = Get-Location
try {
    Set-Location -LiteralPath $fixtureCwd
    $script:detectorInvocations = @()
    function powershell {
        $script:detectorInvocations += ,@($args)
        $global:LASTEXITCODE = 0
    }
    $detectorDigest = Join-Path $RepoRoot 'scripts\detector_digest.ps1'
    $log = Join-Path $fixtureCwd 'detector-cage.log'
    foreach ($call in $detectorCalls) {
        & ([scriptblock]::Create($call.Extent.Text))
    }
} finally {
    Set-Location -LiteralPath $originalLocation
    Remove-Item -LiteralPath function:\powershell -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $fixtureCwd -Recurse -Force -ErrorAction SilentlyContinue
}

Assert-Equal 'bounded fixture captured both detector invocations' 2 $script:detectorInvocations.Count
Assert-True 'negative control: missing root cannot satisfy detector root binding' `
    (-not (Test-DetectorInvocationRoot -Invocation @('-NoProfile','-File',$detectorDigest) -ExpectedRoot $RepoRoot))
Assert-True 'negative control: wrong root cannot satisfy detector root binding' `
    (-not (Test-DetectorInvocationRoot -Invocation @('-NoProfile','-File',$detectorDigest,'-Root','C:\Windows\System32') -ExpectedRoot $RepoRoot))
if ($script:detectorInvocations.Count -eq 2) {
    Assert-True 'full detector call passes the resolved repository root from unrelated cwd' `
        (Test-DetectorInvocationRoot -Invocation $script:detectorInvocations[0] -ExpectedRoot $RepoRoot)
    Assert-True 'full detector call remains the unfiltered digest' `
        ([Array]::IndexOf($script:detectorInvocations[0], '-SinceDays') -lt 0 -and
         [Array]::IndexOf($script:detectorInvocations[0], '-Quiet') -lt 0)
    Assert-True 'recent/quiet detector call passes the resolved repository root from unrelated cwd' `
        (Test-DetectorInvocationRoot -Invocation $script:detectorInvocations[1] -ExpectedRoot $RepoRoot)
    Assert-True 'recent/quiet detector call preserves its existing filters' `
        ([Array]::IndexOf($script:detectorInvocations[1], '-SinceDays') -ge 0 -and
         [Array]::IndexOf($script:detectorInvocations[1], '-Quiet') -ge 0)
}

Write-Host "RESULT: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
