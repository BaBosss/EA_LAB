param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-LjrAtomicWriteText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $tmp = [System.IO.Path]::Combine($dir, ([System.IO.Path]::GetRandomFileName() + '.tmp'))
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $stream = $null
    $backup = [System.IO.Path]::Combine($dir, ([System.IO.Path]::GetRandomFileName() + '.bak'))
    try {
        $stream = [System.IO.File]::Open($tmp, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $writer = New-Object System.IO.StreamWriter($stream, $encoding)
        try {
            $writer.Write($Content)
            $writer.Flush()
            $stream.Flush($true)
        } finally {
            $writer.Dispose()
        }
        if (Test-Path -LiteralPath $Path) {
            [System.IO.File]::Replace($tmp, $Path, $backup, $true)
        } else {
            [System.IO.File]::Move($tmp, $Path)
        }
    } finally {
        if ($stream) { $stream.Dispose() }
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $backup) {
            Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-LjrAtomicWriteJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Object
    )

    $json = $Object | ConvertTo-Json -Depth 12
    Invoke-LjrAtomicWriteText -Path $Path -Content $json
}

function Get-LjrUtcNowIso {
    return ([DateTime]::UtcNow.ToString('o'))
}

function Test-LjrValidJobId {
    param([Parameter(Mandatory = $true)][string]$JobId)
    return ($JobId -match '^[A-Za-z0-9][A-Za-z0-9_.-]{2,79}$')
}

function Test-LjrValidTimeout {
    param([Parameter(Mandatory = $true)][int]$Value)
    return ($Value -gt 0 -and $Value -le 31536000)
}

function Test-LjrValidHeartbeat {
    param([Parameter(Mandatory = $true)][int]$Value)
    return ($Value -ge 1 -and $Value -le 86400)
}

function Resolve-LjrSafeAbsPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        throw "path must be absolute: $Path"
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-LjrValidBaseSha {
    param([string]$BaseSha)
    if ([string]::IsNullOrWhiteSpace($BaseSha)) { return $true }
    return ($BaseSha -match '^[0-9a-f]{40}$')
}

function Test-LjrValidWorktreePath {
    param([string]$Worktree)
    if ([string]::IsNullOrWhiteSpace($Worktree)) { return $true }
    if (-not [System.IO.Path]::IsPathRooted($Worktree)) { return $false }
    if (-not (Test-Path -LiteralPath $Worktree)) { return $false }
    return (Get-Item -LiteralPath $Worktree).PSIsContainer
}

function Test-LjrLeafFilePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not [System.IO.Path]::IsPathRooted($Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    return -not (Get-Item -LiteralPath $Path).PSIsContainer
}

function ConvertTo-LjrProcessArguments {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ArgumentList)

    function Quote-LjrArgument {
        param([string]$Value)
        if ($null -eq $Value) { return '""' }
        if ($Value -eq '') { return '""' }
        if ($Value -notmatch '[\s"`]') { return $Value }
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('"')
        $backslashes = 0
        foreach ($ch in $Value.ToCharArray()) {
            if ($ch -eq '\') {
                $backslashes++
                continue
            }
            if ($ch -eq '"') {
                [void]$sb.Append(('\' * ($backslashes * 2 + 1)))
                [void]$sb.Append('"')
                $backslashes = 0
                continue
            }
            if ($backslashes -gt 0) {
                [void]$sb.Append(('\' * $backslashes))
                $backslashes = 0
            }
            [void]$sb.Append($ch)
        }
        if ($backslashes -gt 0) {
            [void]$sb.Append(('\' * ($backslashes * 2)))
        }
        [void]$sb.Append('"')
        return $sb.ToString()
    }

    return (($ArgumentList | ForEach-Object { Quote-LjrArgument -Value ([string]$_) }) -join ' ')
}

function Get-LjrProcessSnapshot {
    param([int]$ProcessId)
    if ($ProcessId -le 0) { return $null }
    try {
        $proc = Get-Process -Id $ProcessId -ErrorAction Stop
        return [PSCustomObject]@{
            Pid = $proc.Id
            StartTimeUtc = $proc.StartTime.ToUniversalTime().ToString('o')
            HasExited = $proc.HasExited
        }
    } catch {
        return $null
    }
}

function Stop-LjrOwnedProcessTree {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [string]$ExpectedStartTimeUtc = ''
    )

    try {
        if ($ExpectedStartTimeUtc -and $Process.StartTime.ToUniversalTime().ToString('o') -ne $ExpectedStartTimeUtc) {
            throw "process identity changed for pid $($Process.Id)"
        }
    } catch {
        throw "process identity unavailable for pid $($($Process.Id))"
    }

    if ($Process.HasExited) { return }

    $taskkill = Join-Path $env:SystemRoot 'System32\taskkill.exe'
    if (-not (Test-Path -LiteralPath $taskkill)) {
        throw "taskkill unavailable; refusing parent-only termination for pid $($Process.Id)"
    }

    & $taskkill /PID $Process.Id /T /F | Out-Null
    $taskkillExit = $LASTEXITCODE
    try { [void]$Process.WaitForExit(5000) } catch {}
    if (-not $Process.HasExited) {
        throw "owned process tree termination failed for pid $($Process.Id) (taskkill_exit=$taskkillExit)"
    }
}
