<#
Starts an approved headless worker through Long Job Runner.

The launcher deliberately supports Codex only.  Codex is invoked with its
noninteractive workspace-write sandbox flags.  Qwen write requests fail before
bootstrap or Long Job Runner are called because this repository has no locally
proven deterministic, noninteractive write-approval mode for Qwen.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('Codex','Qwen')][string]$Provider,
    [Parameter(Mandatory = $true)][ValidateSet('ReadOnly','Write')][string]$AccessMode,
    [Parameter(Mandatory = $true)][string]$ProviderExecutable,
    [Parameter(Mandatory = $true)][string]$PromptFile,
    [Parameter(Mandatory = $true)][string]$JobId,
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [string]$ExpectedHooksPath = '',
    [string]$PythonArchiveSource = '',
    [string]$PythonArchiveTarget = '',
    [string]$ExpectedPythonArchiveSha256 = '',
    [Parameter(Mandatory = $true)][string]$PostconditionFilePath,
    [string[]]$PostconditionArgumentList = @(),
    [int]$TimeoutSec = 3600,
    [int]$HeartbeatSec = 5,
    [string]$JobsRoot = 'D:\EA_LAB_CONTROL\jobs',
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

# This check intentionally precedes every operation that could reach a model
# provider, including the detached runner that would execute it.
if ($Provider -eq 'Qwen' -and $AccessMode -eq 'Write') {
    throw 'QWEN_WRITE_REFUSED: no deterministic locally proven noninteractive write approval mode is configured'
}
if ($Provider -eq 'Qwen') {
    throw 'QWEN_READ_ONLY_UNSUPPORTED: no deterministic Qwen command contract is configured'
}

function Resolve-LauncherAbsoluteLeaf([string]$Path, [string]$Name) {
    if (-not [System.IO.Path]::IsPathRooted($Path)) { throw "$Name must be an absolute path: $Path" }
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "$Name missing: $fullPath" }
    return $fullPath
}

$providerPath = Resolve-LauncherAbsoluteLeaf $ProviderExecutable 'provider executable'
$promptPath = Resolve-LauncherAbsoluteLeaf $PromptFile 'prompt file'
$prompt = (Get-Content -LiteralPath $promptPath -Raw).TrimEnd("`r", "`n")
if ([string]::IsNullOrWhiteSpace($prompt)) { throw 'prompt file must contain non-whitespace text' }

$bootstrap = Join-Path $PSScriptRoot 'bootstrap_worktree.ps1'
& $bootstrap -Worktree $Worktree -ExpectedHead $ExpectedHead -ExpectedHooksPath $ExpectedHooksPath -PythonArchiveSource $PythonArchiveSource -PythonArchiveTarget $PythonArchiveTarget -ExpectedPythonArchiveSha256 $ExpectedPythonArchiveSha256 -Json | Out-Null

$sandbox = if ($AccessMode -eq 'Write') { 'workspace-write' } else { 'read-only' }
$providerArguments = @('exec','--sandbox',$sandbox,'--ask-for-approval','never','--cd',$Worktree,$prompt)
$start = Join-Path (Split-Path -Parent $PSScriptRoot) 'long_jobs\start_long_job.ps1'
$startArguments = @{
    FilePath = $providerPath
    ArgumentList = $providerArguments
    JobId = $JobId
    TimeoutSec = $TimeoutSec
    HeartbeatSec = $HeartbeatSec
    Worktree = $Worktree
    BaseSha = $ExpectedHead
    Stage = "WORKER_CODEX_$($AccessMode.ToUpperInvariant())"
    PostconditionFilePath = $PostconditionFilePath
    PostconditionArgumentList = $PostconditionArgumentList
    JobsRoot = $JobsRoot
    Json = $Json
}
& $start @startArguments
