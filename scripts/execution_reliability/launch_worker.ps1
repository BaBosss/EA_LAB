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
    [string]$ProviderHelpFile = '',
    [string]$ProviderVersion = 'UNKNOWN',
    [ValidateSet('gpt-6-astra','gpt-5.6-sol','gpt-5.6-terra','gpt-5.6-luna','gpt-5.5','gpt-5.4-mini','gpt-5.3-codex-spark')][string]$Model = '',
    [ValidateSet('low','medium','high','xhigh','max','ultra')][string]$ReasoningEffort = '',
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
    [switch]$ValidateOnly,
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
if ($ProviderHelpFile -and -not $ValidateOnly) {
    throw 'CODEX_HELP_FIXTURE_VALIDATE_ONLY: ProviderHelpFile is forbidden for an actual launch'
}
$supportedReasoning = @{
    'gpt-6-astra'=@('low','medium','high','xhigh','max','ultra')
    'gpt-5.6-sol'=@('low','medium','high','xhigh','max','ultra')
    'gpt-5.6-terra'=@('low','medium','high','xhigh','max','ultra')
    'gpt-5.6-luna'=@('low','medium','high','xhigh','max')
    'gpt-5.5'=@('low','medium','high','xhigh')
    'gpt-5.4-mini'=@('low','medium','high','xhigh')
    'gpt-5.3-codex-spark'=@('low','medium','high','xhigh')
}
if ($ReasoningEffort -and -not $Model) {
    throw 'CODEX_REASONING_REFUSED: ReasoningEffort requires an explicit task-scoped Model'
}
if ($ReasoningEffort -and $supportedReasoning[$Model] -notcontains $ReasoningEffort) {
    throw "CODEX_REASONING_REFUSED: $Model does not support reasoning effort $ReasoningEffort"
}

function Resolve-LauncherAbsoluteLeaf([string]$Path, [string]$Name) {
    if (-not [System.IO.Path]::IsPathRooted($Path)) { throw "$Name must be an absolute path: $Path" }
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "$Name missing: $fullPath" }
    return $fullPath
}

$providerPath = Resolve-LauncherAbsoluteLeaf $ProviderExecutable 'provider executable'
if (-not $ValidateOnly -and [System.IO.Path]::GetExtension($providerPath) -ine '.exe') {
    throw 'CODEX_NATIVE_EXECUTABLE_REQUIRED: actual Long Job launch requires the native codex.exe, not a shell wrapper'
}
$promptPath = Resolve-LauncherAbsoluteLeaf $PromptFile 'prompt file'
$prompt = (Get-Content -LiteralPath $promptPath -Raw).TrimEnd("`r", "`n")
if ([string]::IsNullOrWhiteSpace($prompt)) { throw 'prompt file must contain non-whitespace text' }

$preflightScript = Join-Path $PSScriptRoot 'provider_cli_preflight.ps1'
$helpText = ''
if ($ProviderHelpFile) {
    $helpPath = Resolve-LauncherAbsoluteLeaf $ProviderHelpFile 'provider help file'
    $helpText = Get-Content -LiteralPath $helpPath -Raw -Encoding UTF8
} else {
    $helpText = ((& $providerPath exec --help 2>&1) | Out-String)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($helpText)) {
        throw 'CODEX_HELP_REFUSED: installed client did not return exec help'
    }
    $observedVersion = ((& $providerPath --version 2>&1) | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($observedVersion)) {
        throw 'CODEX_VERSION_REFUSED: installed client did not return a version'
    }
    if ($observedVersion -notmatch '^codex-cli\s+\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
        throw "CODEX_IDENTITY_REFUSED: selected executable returned unexpected identity '$observedVersion'"
    }
    $ProviderVersion = $observedVersion
}
$preflight = & $preflightScript -Provider Codex -HelpText $helpText -ProviderVersion $ProviderVersion -FailOnIncompatible -Json | ConvertFrom-Json

$sandbox = if ($AccessMode -eq 'Write') { 'workspace-write' } else { 'read-only' }
$providerArguments = @('exec','--config','approval_policy="never"')
if ($ReasoningEffort) { $providerArguments += @('--config',("model_reasoning_effort=`"{0}`"" -f $ReasoningEffort)) }
if ($Model) { $providerArguments += @('--model',$Model) }
$providerArguments += @('--sandbox',$sandbox,'--cd',$Worktree,'--',$prompt)
$argumentHash = [Convert]::ToBase64String((New-Object System.Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes(($providerArguments -join "`u0000"))))
if ($ValidateOnly) {
    $validation = [ordered]@{
        schema_version='EA_LAB_WORKER_LAUNCH_VALIDATION_V1'
        provider='Codex';access_mode=$AccessMode;provider_version=$preflight.provider_version
        requested_model=if($Model){$Model}else{$null};requested_reasoning_effort=if($ReasoningEffort){$ReasoningEffort}else{$null}
        compatibility=$preflight.compatibility;provider_readiness=$preflight.provider_readiness
        argument_contract=$preflight.argument_contract;argument_count=$providerArguments.Count;argument_hash=$argumentHash
        would_bootstrap=$false;would_launch=$false
    }
    if ($Json) { $validation | ConvertTo-Json -Depth 6 } else { [pscustomobject]$validation }
    return
}
$bootstrap = Join-Path $PSScriptRoot 'bootstrap_worktree.ps1'
& $bootstrap -Worktree $Worktree -ExpectedHead $ExpectedHead -ExpectedHooksPath $ExpectedHooksPath -PythonArchiveSource $PythonArchiveSource -PythonArchiveTarget $PythonArchiveTarget -ExpectedPythonArchiveSha256 $ExpectedPythonArchiveSha256 -Json | Out-Null
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
