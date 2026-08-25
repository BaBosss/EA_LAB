[CmdletBinding()]
param(
    [ValidateSet('Plan','Stage','Build','Compat','Manifest')][string]$Command,
    [string]$RepoRoot,
    [string]$SourceRoot = 'D:\EA_LAB_TOOLS\lnwjud-v4-src',
    [string]$TargetRef = 'v4.10.0',
    [string]$CandidateRoot = 'D:\EA_LAB_CONTROL\lnwjud-upgrades\v4.10.0\source',
    [string]$StagingRoot = 'D:\EA_LAB_CONTROL\lnwjud-upgrades',
    [string]$ExpectedSha,
    [string]$ManifestPath = 'D:\EA_LAB_CONTROL\lnwjud-upgrades\v4.10.0\upgrade-manifest.json',
    [switch]$Fetch,
    [switch]$SkipInstall
)
$ErrorActionPreference = 'Stop'
$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptPath)) { throw 'cannot resolve wrapper script path' }
$scriptDirectory = Split-Path -Parent $scriptPath
Import-Module (Join-Path $scriptDirectory 'LnwjudUpgrade.psm1') -Force
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = (Resolve-Path (Join-Path $scriptDirectory '..\..')).Path }
$probePath = Join-Path $scriptDirectory 'node_probe.mjs'

switch ($Command) {
    'Plan' { Get-LnwjudUpgradePlan -RepoRoot $RepoRoot -SourceRoot $SourceRoot -TargetRef $TargetRef -CandidateRoot $CandidateRoot -StagingRoot $StagingRoot | ConvertTo-Json -Depth 8 }
    'Stage' { New-LnwjudUpgradeCandidate -RepoRoot $RepoRoot -SourceRoot $SourceRoot -TargetRef $TargetRef -CandidateRoot $CandidateRoot -StagingRoot $StagingRoot -Fetch:$Fetch | ConvertTo-Json -Depth 8 }
    'Build' { Invoke-LnwjudCandidateBuild -CandidateRoot $CandidateRoot -SkipInstall:$SkipInstall | ConvertTo-Json -Depth 8 }
    'Compat' {
        if ([string]::IsNullOrWhiteSpace($ExpectedSha)) { throw 'Compat requires -ExpectedSha' }
        Test-LnwjudCandidateCompatibility -CandidateRoot $CandidateRoot -ExpectedVersion ($TargetRef.TrimStart('v')) -ExpectedSha $ExpectedSha -ProbePath $probePath | ConvertTo-Json -Depth 12
    }
    'Manifest' {
        if ([string]::IsNullOrWhiteSpace($ExpectedSha)) { throw 'Manifest requires -ExpectedSha' }
        $plan = Get-LnwjudUpgradePlan -RepoRoot $RepoRoot -SourceRoot $SourceRoot -TargetRef $TargetRef -CandidateRoot $CandidateRoot -StagingRoot $StagingRoot
        $compat = Test-LnwjudCandidateCompatibility -CandidateRoot $CandidateRoot -ExpectedVersion ($TargetRef.TrimStart('v')) -ExpectedSha $ExpectedSha -ProbePath $probePath
        Write-LnwjudUpgradeManifest -Plan $plan -Compatibility $compat -OutputPath $ManifestPath
    }
}
