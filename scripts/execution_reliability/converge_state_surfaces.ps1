<#
Deterministically converge the generated taskboard digest with canonical state/taskboard surfaces.
This helper never authors PROJECT_STATE.md or taskboard semantics. Apply mode only regenerates
TASKBOARD_DIGEST.md, then validates the digest and existing state guard. CheckOnly is read-only.
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [switch]$CheckOnly,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
if (-not [IO.Path]::IsPathRooted($Root)) { throw "Root must be absolute: $Root" }
$Root = [IO.Path]::GetFullPath($Root).TrimEnd('\')
if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw "repo root missing: $Root" }

$required = @('PROJECT_STATE.md','AGENT_TASKBOARD.md','taskboards\active','scripts\make_taskboard_digest.ps1','scripts\check_state.ps1')
foreach ($rel in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $rel))) { throw "required state surface missing: $rel" }
}
$digestScript = Join-Path $Root 'scripts\make_taskboard_digest.ps1'
$stateScript = Join-Path $Root 'scripts\check_state.ps1'
$psExe = Join-Path $PSHOME 'powershell.exe'
function Invoke-ChildPs {
    param([string]$Script,[string[]]$Arguments)
    $saved = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& $psExe -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1 | ForEach-Object { [string]$_ })
        $rc = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $saved
    }
    return [pscustomobject]@{ exit_code=$rc; output=($lines -join "`n") }
}

$generate = $null
if (-not $CheckOnly) {
    $generate = Invoke-ChildPs -Script $digestScript -Arguments @('-Root',$Root)
    if ($generate.exit_code -ne 0) {
        throw "digest generation failed exit=$($generate.exit_code): $($generate.output)"
    }
}
$digestCheck = Invoke-ChildPs -Script $digestScript -Arguments @('-Check','-Root',$Root)
$stateCheck = Invoke-ChildPs -Script $stateScript -Arguments @('-Root',$Root,'-Strict')
$status = if ($digestCheck.exit_code -eq 0 -and $stateCheck.exit_code -eq 0) { 'PASS' } else { 'REFUSED' }
$result = [ordered]@{
    schema_version = 'EA_LAB_STATE_SURFACE_CONVERGENCE_V1'
    status = $status
    mode = $(if($CheckOnly){'CHECK_ONLY'}else{'APPLY_DIGEST_THEN_CHECK'})
    root = $Root
    generated_digest = (-not $CheckOnly)
    digest_exit_code = [int]$digestCheck.exit_code
    state_exit_code = [int]$stateCheck.exit_code
}
if ($Json) {
    [pscustomobject]$result | ConvertTo-Json -Compress | Write-Output
} else {
    Write-Output ("STATE_SURFACE_CONVERGENCE status={0} mode={1}" -f $status,$result.mode)
    if ($digestCheck.output) { Write-Output $digestCheck.output }
    if ($stateCheck.output) { Write-Output $stateCheck.output }
}
if ($status -ne 'PASS') {
    if ($digestCheck.exit_code -ne 0) { [Console]::Error.WriteLine(("digest check failed: {0}" -f $digestCheck.output)) }
    if ($stateCheck.exit_code -ne 0) { [Console]::Error.WriteLine(("state check failed: {0}" -f $stateCheck.output)) }
    exit 2
}
exit 0
