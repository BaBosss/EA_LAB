<#
Verifies a Control Tower worktree before a bounded worker can be started.
The optional Python archive is copied only into an absent target after its
accepted SHA-256 is verified. A present mismatched target is never replaced.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$ExpectedHead,
    [string]$ExpectedHooksPath = '',
    [string]$PythonArchiveSource = '',
    [string]$PythonArchiveTarget = '',
    [string]$ExpectedPythonArchiveSha256 = '',
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Resolve-AbsolutePath([string]$Path) {
    if (-not [System.IO.Path]::IsPathRooted($Path)) { throw "path must be absolute: $Path" }
    return [System.IO.Path]::GetFullPath($Path)
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
}

function Fail-Bootstrap([string]$Reason) { throw "BOOTSTRAP_REFUSED: $Reason" }

function Invoke-GitLines([string[]]$Arguments) {
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& git @Arguments 2>&1 | ForEach-Object { [string]$_ })
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedPreference
    }
    return [PSCustomObject]@{ Lines = $lines; ExitCode = $exitCode }
}

try {
    if ($ExpectedHead -notmatch '^[0-9a-f]{40}$') { Fail-Bootstrap 'invalid expected head' }
    $worktreePath = Resolve-AbsolutePath $Worktree
    if (-not (Test-Path -LiteralPath $worktreePath -PathType Container)) { Fail-Bootstrap "worktree missing: $worktreePath" }
    $headResult = Invoke-GitLines @('-C',$worktreePath,'rev-parse','HEAD')
    $actualHead = ($headResult.Lines | Where-Object { $_ -match '^[0-9a-f]{40}$' } | Select-Object -Last 1).Trim()
    if ($headResult.ExitCode -ne 0 -or $actualHead -ne $ExpectedHead) { Fail-Bootstrap "HEAD mismatch expected=$ExpectedHead actual=$actualHead" }
    $statusResult = Invoke-GitLines @('-C',$worktreePath,'status','--porcelain','--untracked-files=no')
    $trackedChanges = @($statusResult.Lines | Where-Object { $_ -match '^[ MADRCU?!]{2}' })
    if ($statusResult.ExitCode -ne 0) { Fail-Bootstrap 'cannot read tracked cleanliness' }
    if ($trackedChanges.Count -ne 0) { Fail-Bootstrap 'tracked worktree is dirty' }

    $hooksResult = Invoke-GitLines @('-C',$worktreePath,'config','--get','core.hooksPath')
    $configuredHooks = ($hooksResult.Lines | Select-Object -Last 1).Trim()
    if ($ExpectedHooksPath) {
        $expectedHookRoot = if ([System.IO.Path]::IsPathRooted($ExpectedHooksPath)) { [System.IO.Path]::GetFullPath($ExpectedHooksPath) } else { [System.IO.Path]::GetFullPath((Join-Path $worktreePath $ExpectedHooksPath)) }
        $actualHookRoot = if ($configuredHooks) { if ([System.IO.Path]::IsPathRooted($configuredHooks)) { [System.IO.Path]::GetFullPath($configuredHooks) } else { [System.IO.Path]::GetFullPath((Join-Path $worktreePath $configuredHooks)) } } else { '' }
        if (-not $actualHookRoot -or $actualHookRoot -ne $expectedHookRoot -or -not (Test-Path -LiteralPath $actualHookRoot -PathType Container)) { Fail-Bootstrap "hooks path mismatch expected=$expectedHookRoot actual=$actualHookRoot" }
    }

    $archiveCopied = $false
    if ($PythonArchiveTarget -or $PythonArchiveSource -or $ExpectedPythonArchiveSha256) {
        if (-not ($PythonArchiveTarget -and $ExpectedPythonArchiveSha256)) { Fail-Bootstrap 'python archive target and expected hash are both required' }
        if ($ExpectedPythonArchiveSha256 -notmatch '^[0-9a-fA-F]{64}$') { Fail-Bootstrap 'invalid expected python archive hash' }
        $targetPath = Resolve-AbsolutePath $PythonArchiveTarget
        if (Test-Path -LiteralPath $targetPath) {
            if ((Get-Sha256 $targetPath) -ne $ExpectedPythonArchiveSha256.ToUpperInvariant()) { Fail-Bootstrap "existing python archive hash mismatch: $targetPath" }
        } else {
            if (-not $PythonArchiveSource) { Fail-Bootstrap 'python archive source is required when target is missing' }
            $sourcePath = Resolve-AbsolutePath $PythonArchiveSource
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { Fail-Bootstrap "python archive source missing: $sourcePath" }
            if ((Get-Sha256 $sourcePath) -ne $ExpectedPythonArchiveSha256.ToUpperInvariant()) { Fail-Bootstrap "python archive source hash mismatch: $sourcePath" }
            $targetDir = Split-Path -Parent $targetPath
            if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
            Copy-Item -LiteralPath $sourcePath -Destination $targetPath -ErrorAction Stop
            if ((Get-Sha256 $targetPath) -ne $ExpectedPythonArchiveSha256.ToUpperInvariant()) { Fail-Bootstrap "copied python archive hash mismatch: $targetPath" }
            $archiveCopied = $true
        }
    }

    $result = [ordered]@{ state = 'READY'; worktree = $worktreePath; head = $actualHead; hooks_path = $configuredHooks; python_archive_copied = $archiveCopied }
    if ($Json) { $result | ConvertTo-Json -Depth 4 | Write-Output } else { $result.GetEnumerator() | ForEach-Object { Write-Output "$($_.Key)=$($_.Value)" } }
} catch {
    if ($_.Exception.Message -like 'BOOTSTRAP_REFUSED:*') { throw }
    throw "BOOTSTRAP_REFUSED: $($_.Exception.Message)"
}
