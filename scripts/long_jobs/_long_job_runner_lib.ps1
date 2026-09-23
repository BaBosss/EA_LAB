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

# Shared accepted Job Identity Provider primitives; capture and retry use the same evidence.
function Assert-StrictJsonSyntaxAndUniqueKeys {
    param([Parameter(Mandatory = $true)][string]$Text, [Parameter(Mandatory = $true)][string]$Label)
    $state = [pscustomobject]@{ Text = $Text; Index = 0; Length = $Text.Length }
    $skipWhitespace = {
        while ($state.Index -lt $state.Length -and [char]::IsWhiteSpace($state.Text[$state.Index])) { $state.Index++ }
    }
    $parseString = {
        & $skipWhitespace
        if ($state.Index -ge $state.Length -or $state.Text[$state.Index] -ne '"') { throw "invalid JSON in $Label" }
        $start = $state.Index
        $state.Index++
        $escaped = $false
        while ($state.Index -lt $state.Length) {
            $character = $state.Text[$state.Index]
            if ($escaped) {
                if ('"\/bfnrt'.IndexOf($character) -ge 0) {
                    $escaped = $false
                    $state.Index++
                    continue
                }
                if ($character -eq 'u') {
                    if ($state.Index + 4 -ge $state.Length) { throw "invalid JSON in $Label" }
                    $hex = $state.Text.Substring($state.Index + 1, 4)
                    if ($hex -cnotmatch '^[0-9A-Fa-f]{4}$') { throw "invalid JSON in $Label" }
                    $state.Index += 5
                    $escaped = $false
                    continue
                }
                throw "invalid JSON in $Label"
            }
            if ($character -eq '\') {
                $escaped = $true
                $state.Index++
                continue
            }
            if ($character -eq '"') {
                $state.Index++
                $token = $state.Text.Substring($start, $state.Index - $start)
                try { return ($token | ConvertFrom-Json) } catch { throw "invalid JSON in $Label" }
            }
            if ([int][char]$character -lt 0x20) { throw "invalid JSON in $Label" }
            $state.Index++
        }
        throw "invalid JSON in $Label"
    }
    $parseValue = $null
    $parseObject = {
        $state.Index++
        $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        & $skipWhitespace
        if ($state.Index -lt $state.Length -and $state.Text[$state.Index] -eq '}') { $state.Index++; return }
        while ($true) {
            $key = & $parseString
            if (-not $seen.Add([string]$key)) { throw "duplicate JSON key in $Label" }
            & $skipWhitespace
            if ($state.Index -ge $state.Length -or $state.Text[$state.Index] -ne ':') { throw "invalid JSON in $Label" }
            $state.Index++
            & $parseValue
            & $skipWhitespace
            if ($state.Index -ge $state.Length) { throw "invalid JSON in $Label" }
            $delimiter = $state.Text[$state.Index]
            $state.Index++
            if ($delimiter -eq '}') { return }
            if ($delimiter -ne ',') { throw "invalid JSON in $Label" }
        }
    }
    $parseArray = {
        $state.Index++
        & $skipWhitespace
        if ($state.Index -lt $state.Length -and $state.Text[$state.Index] -eq ']') { $state.Index++; return }
        while ($true) {
            & $parseValue
            & $skipWhitespace
            if ($state.Index -ge $state.Length) { throw "invalid JSON in $Label" }
            $delimiter = $state.Text[$state.Index]
            $state.Index++
            if ($delimiter -eq ']') { return }
            if ($delimiter -ne ',') { throw "invalid JSON in $Label" }
        }
    }
    $parseValue = {
        & $skipWhitespace
        if ($state.Index -ge $state.Length) { throw "invalid JSON in $Label" }
        $character = $state.Text[$state.Index]
        if ($character -eq '{') { & $parseObject; return }
        if ($character -eq '[') { & $parseArray; return }
        if ($character -eq '"') { [void](& $parseString); return }
        $remaining = $state.Text.Substring($state.Index)
        $match = [regex]::Match($remaining, '^(?:true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)')
        if (-not $match.Success) { throw "invalid JSON in $Label" }
        $state.Index += $match.Length
    }
    & $parseValue
    & $skipWhitespace
    if ($state.Index -ne $state.Length) { throw "invalid JSON in $Label" }
}

function ConvertFrom-StrictJsonBytes {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string[]]$AllowedKeys,
        [Parameter(Mandatory = $true)][string[]]$RequiredKeys
    )
    try { $text = (New-Object Text.UTF8Encoding($false, $true)).GetString($Bytes).TrimStart([char]0xFEFF) }
    catch { throw "invalid UTF-8 JSON in $Label" }
    Assert-StrictJsonSyntaxAndUniqueKeys $text $Label
    try { $value = $text | ConvertFrom-Json }
    catch { throw "invalid JSON in $Label" }
    if ($null -eq $value -or $value -isnot [pscustomobject]) { throw "$Label must be a JSON object" }
    $allowed = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $required = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($key in $AllowedKeys) { [void]$allowed.Add($key) }
    foreach ($key in $RequiredKeys) { [void]$required.Add($key) }
    foreach ($property in $value.PSObject.Properties) {
        if (-not $allowed.Contains($property.Name)) { throw "extra JSON key in $Label" }
        [void]$required.Remove($property.Name)
    }
    if ($required.Count -ne 0) { throw "missing JSON key in $Label" }
    return $value
}

function ConvertTo-PreciseUtcTicks {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    if ($Value -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})$') {
        throw 'invalid precise timestamp'
    }
    try {
        $parsed = [DateTimeOffset]::Parse($Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
    } catch {
        throw 'invalid precise timestamp'
    }
    return $parsed.UtcTicks
}

function Get-IdentityEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$LaneId,
        [Parameter(Mandatory = $true)][string]$JobId,
        [Parameter(Mandatory = $true)][ValidateSet('runner','child','postcondition')][string]$Role,
        [AllowNull()]$PidValue,
        [AllowNull()]$ExpectedCreationUtc,
        [bool]$PostconditionNotConfigured = $false,
        [bool]$PostconditionNotStarted = $false
    )
    $checked = [DateTime]::UtcNow.ToString('o')
    if ($null -eq $PidValue) {
        if ($Role -eq 'postcondition' -and $PostconditionNotConfigured) {
            return [ordered]@{
                lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $null
                expected_creation_utc = $null; current_creation_utc = $null
                identity = 'RECORDED_PROCESS_NOT_PRESENT'; query_status = 'NOT_CONFIGURED'; checked_utc = $checked
            }
        }
        if ($Role -eq 'postcondition' -and $PostconditionNotStarted -and $null -eq $ExpectedCreationUtc) {
            return [ordered]@{
                lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $null
                expected_creation_utc = $null; current_creation_utc = $null
                identity = 'RECORDED_PROCESS_NOT_PRESENT'; query_status = 'NOT_STARTED'; checked_utc = $checked
            }
        }
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $null
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $null
            identity = 'UNKNOWN'; query_status = 'ERROR'; checked_utc = $checked
        }
    }
    if (($PidValue -isnot [int] -and $PidValue -isnot [long]) -or $PidValue -le 0 -or $PidValue -gt [int]::MaxValue) {
        throw "invalid recorded PID"
    }
    # Missing identity must not become known absence merely because a PID lookup fails.
    $expectedTicks = ConvertTo-PreciseUtcTicks ([string]$ExpectedCreationUtc)
    if ($ExpectedCreationUtc -isnot [string] -or $null -eq $expectedTicks -or
        $expectedTicks -gt (ConvertTo-PreciseUtcTicks $checked)) { throw 'invalid recorded creation identity' }
    $observedPid = [int]$PidValue
    $snapshot = Get-LjrProcessSnapshot -ProcessId $observedPid
    if ($null -ne $snapshot) {
        if ($snapshot.Pid -ne $observedPid -or $snapshot.HasExited -isnot [bool] -or
            $snapshot.StartTimeUtc -isnot [string]) { throw 'ambiguous process snapshot' }
        if ([bool]$snapshot.HasExited) {
            return [ordered]@{
                lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
                expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $null
                identity = 'UNKNOWN'; query_status = 'ERROR'; checked_utc = $checked
            }
        }
        $current = [string]$snapshot.StartTimeUtc
        $identity = 'UNKNOWN'
        if (-not [string]::IsNullOrWhiteSpace([string]$ExpectedCreationUtc)) {
            $expectedTicks = ConvertTo-PreciseUtcTicks ([string]$ExpectedCreationUtc)
            $currentTicks = ConvertTo-PreciseUtcTicks $current
            if ($null -eq $currentTicks -or $currentTicks -gt (ConvertTo-PreciseUtcTicks $checked)) { throw 'invalid current creation identity' }
            $identity = if ($expectedTicks -eq $currentTicks) { 'MATCHING_RECORDED_PROCESS' } else { 'DIFFERENT_CREATION_IDENTITY' }
        }
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $current
            identity = $identity; query_status = 'PRESENT'; checked_utc = $checked
        }
    }

    # A null helper result is ambiguous. A second read-only query distinguishes the documented
    # no-such-process exception from access/metadata failures; every other outcome remains UNKNOWN.
    try {
        $process = [Diagnostics.Process]::GetProcessById($observedPid)
    } catch [ArgumentException] {
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $null
            identity = 'RECORDED_PROCESS_NOT_PRESENT'; query_status = 'NOT_PRESENT'; checked_utc = $checked
        }
    } catch {
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $null
            identity = 'UNKNOWN'; query_status = 'INACCESSIBLE'; checked_utc = $checked
        }
    }
    try {
        $current = $process.StartTime.ToUniversalTime().ToString('o')
        $identity = 'UNKNOWN'
        if (-not [string]::IsNullOrWhiteSpace([string]$ExpectedCreationUtc)) {
            $expectedTicks = ConvertTo-PreciseUtcTicks ([string]$ExpectedCreationUtc)
            $currentTicks = ConvertTo-PreciseUtcTicks $current
            if ($null -eq $currentTicks -or $currentTicks -gt (ConvertTo-PreciseUtcTicks $checked)) { throw 'invalid current creation identity' }
            $identity = if ($expectedTicks -eq $currentTicks) { 'MATCHING_RECORDED_PROCESS' } else { 'DIFFERENT_CREATION_IDENTITY' }
        }
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $current
            identity = $identity; query_status = 'PRESENT'; checked_utc = $checked
        }
    } catch {
        return [ordered]@{
            lane_id = $LaneId; job_id = $JobId; role = $Role; pid = $observedPid
            expected_creation_utc = $ExpectedCreationUtc; current_creation_utc = $null
            identity = 'UNKNOWN'; query_status = 'INACCESSIBLE'; checked_utc = $checked
        }
    } finally {
        if ($null -ne $process) { $process.Dispose() }
    }
}
