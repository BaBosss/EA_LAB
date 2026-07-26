<#
.SYNOPSIS
    Order-number / lane collision guard. READ-ONLY validator intended to be called
    from .githooks/pre-commit alongside scripts/check_precommit_staged.ps1.

.DESCRIPTION
    Everything this script judges is read from the git INDEX (staged bytes) or from
    committed refs -- NEVER from the working tree. Same discipline (and the same
    ProcessStartInfo git primitive) as scripts/check_precommit_staged.ps1 /
    scripts/check_taskboard_archive.ps1.

    It activates ONLY when AGENT_TASKBOARD.md is among the staged paths. Any other
    commit is a fast no-op pass (exit 0), so this script never blocks ordinary work.

    RULE 1 -- duplicate order id (BLOCK)
        Every '## ORDER-<id>' header is parsed out of the STAGED AGENT_TASKBOARD.md
        and out of the COMMITTED ARCHIVE_TASKBOARD_2026-07A.md. <id> is everything
        up to the first space or em-dash, trimmed and upper-cased. It is a block if
        the same id appears twice inside the staged active board, or appears in BOTH
        the staged active board and the archive. Archive-internal duplicates are NOT
        this script's business (the archive is append-only history).

    RULE 2 -- order number outside the session's reserved block (BLOCK)
        docs/SESSION_LEDGER.md (committed) declares, per open session lane, an
        'order block' range like 230-239. Numeric order ids that this commit ADDS to
        AGENT_TASKBOARD.md (present in staged, absent from HEAD) must fall inside the
        union of the ranges declared by rows whose status is ACTIVE. Non-numeric ids
        (LANEC-FAN, GEN-STANDING, 098-C, ...) are exempt -- they do not consume a
        number. If the ledger does not exist, has no ACTIVE row, or no ACTIVE row
        declares a parseable range, the rule prints a NOTE and is skipped (never a
        block -- a missing reservation must not stop an otherwise valid commit).

    RULE 3 -- writing a file another ACTIVE session declared (WARN, never blocks)
        The 'owns paths' column of ACTIVE ledger rows lists backtick-quoted paths and
        globs ('_mt5_auto/**'). Every staged path that matches one is reported with
        the owning session id. This rule can never change the exit code.

    Exit 0 = pass (or nothing relevant staged). Exit 1 = a BLOCK rule fired.
    Exit 2 = tooling failure (git unavailable, ledger present but unparseable).

.PARAMETER StagedActiveContent
    Test override. Supplying ANY of the five override parameters puts the script in
    offline mode: no git process is spawned at all, and every override left unbound
    is treated as absent. Real hook usage passes none of them.
#>
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),

    # --- test overrides (see .PARAMETER StagedActiveContent) ---
    [AllowEmptyString()][string]$StagedActiveContent,
    [AllowEmptyString()][string]$ArchiveContent,
    [AllowEmptyString()][string]$HeadActiveContent,
    [AllowEmptyString()][string]$LedgerContent,
    [AllowEmptyCollection()][string[]]$StagedFileList
)

$ErrorActionPreference = 'Stop'

$Tag         = '[order-collision]'
$ActivePath  = 'AGENT_TASKBOARD.md'
$ArchivePath = 'ARCHIVE_TASKBOARD_2026-07A.md'
$LedgerPath  = 'docs/SESSION_LEDGER.md'

# Em-dash (U+2014) built at runtime on purpose: this file is kept pure ASCII because
# Windows PowerShell 5.1 decodes a BOM-less .ps1 as ANSI, which turns a literal
# em-dash into '?' and silently breaks the header regex.
$EmDash = [char]0x2014
$OrderHeaderRegex = '^##\s+ORDER-([^\s' + $EmDash + ']+)'

# ---------------------------------------------------------------------------
# HISTORICAL VIOLATIONS -- grandfathered so this guard can be switched on today.
# Each of these is a REAL DEFECT that still needs fixing separately; they are
# exempted, not forgiven. Do not add to this list to make a new commit pass.
#   098-C -- two entirely unrelated orders were both filed as ORDER-098-C
#   200   -- ORDER-200 header reused for the 'Phase A/B' history block
#   095   -- duplicated header inside the active board
#   082   -- duplicated header inside the active board
# ---------------------------------------------------------------------------
$GrandfatheredDuplicateIds = @('098-C', '200', '095', '082')

# ===========================================================================
# git primitives (index/committed only -- never the working tree)
# ===========================================================================

function Invoke-GitBytes {
    <# Runs `git <args>` with RepoRoot as cwd and returns the RAW stdout bytes, so the
       caller controls decoding (UTF-8) instead of letting the console codepage
       mangle the Thai text that both the ledger and the taskboard are full of.
       Mirrors Get-GitBlobBytes in scripts/check_taskboard_archive.ps1. #>
    param([string]$Arguments)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $RepoRoot
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $ms = New-Object System.IO.MemoryStream
    $proc.StandardOutput.BaseStream.CopyTo($ms)
    $stderrText = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [pscustomobject]@{ ExitCode = $proc.ExitCode; Bytes = $ms.ToArray(); StdErr = $stderrText }
}

function ConvertFrom-Utf8Bytes {
    param([byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return '' }
    $enc = New-Object System.Text.UTF8Encoding($false)
    $text = $enc.GetString($Bytes)
    if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
    return $text
}

function Get-GitBlobText {
    <# `git show <spec>` decoded as UTF-8. Returns $null when the object does not
       exist (path not in the index / not in HEAD / no HEAD at all). #>
    param([string]$Spec)
    $r = Invoke-GitBytes -Arguments ('show "{0}"' -f $Spec)
    if ($r.ExitCode -ne 0) { return $null }
    return (ConvertFrom-Utf8Bytes -Bytes $r.Bytes)
}

function Get-StagedPathsFromGit {
    $r = Invoke-GitBytes -Arguments '-c core.quotePath=false diff --cached --name-only'
    if ($r.ExitCode -ne 0) { throw ('git diff --cached --name-only failed (exit {0}): {1}' -f $r.ExitCode, $r.StdErr) }
    $text = ConvertFrom-Utf8Bytes -Bytes $r.Bytes
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($text -split "`r?`n")) {
        $t = $line.Trim()
        if (-not $t) { continue }
        $out.Add(($t -replace '\\', '/'))
    }
    return $out.ToArray()
}

# ===========================================================================
# parsing helpers
# ===========================================================================

function Get-OrderHeaders {
    <# Every '## ORDER-<id>' header in $Text -> @{ Id; Line }. Id is normalized
       (trimmed + upper-cased); everything after the first space or em-dash is the
       human title and is discarded. #>
    param([AllowEmptyString()][string]$Text)
    $rows = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrEmpty($Text)) { return $rows.ToArray() }
    $n = 0
    foreach ($line in ($Text -split "`r?`n")) {
        $n++
        if ($line -match $OrderHeaderRegex) {
            $id = $Matches[1].Trim().ToUpperInvariant()
            if ($id) { $rows.Add([pscustomobject]@{ Id = $id; Line = $n }) }
        }
    }
    return $rows.ToArray()
}

function Split-MarkdownRow {
    <# '| a | b | c |' -> @('a','b','c'). Returns $null for a non-table line. #>
    param([string]$Line)
    $t = $Line.Trim()
    if (-not $t.StartsWith('|')) { return $null }
    $t = $t.Substring(1)
    if ($t.EndsWith('|')) { $t = $t.Substring(0, $t.Length - 1) }
    $cells = @($t -split '\|')
    return @($cells | ForEach-Object { $_.Trim() })
}

function Get-CellPlain {
    <# Strip markdown emphasis/code ticks so '**230-239**' and '`ACTIVE`' compare cleanly. #>
    param([AllowEmptyString()][string]$Cell)
    if ($null -eq $Cell) { return '' }
    return ($Cell -replace '[`*_]', '').Trim()
}

function Test-SeparatorRow {
    param([string[]]$Cells)
    if ($null -eq $Cells -or $Cells.Count -eq 0) { return $false }
    foreach ($c in $Cells) { if ($c -notmatch '^:?-{2,}:?$') { return $false } }
    return $true
}

function Get-LedgerLanes {
    <# Parse the open-lane table out of docs/SESSION_LEDGER.md.

       The table is located by its ASCII column headers ('order block' + 'status'),
       NOT by the Thai section heading -- that keeps this file ASCII-only and also
       makes the parser survive a renamed heading. The closed-history table below it
       has an 'order block' column but no 'status' column, so requiring both picks
       the open-lane table unambiguously.

       Throws when the ledger has no recognisable lane table at all -> caller exits 2. #>
    param([AllowEmptyString()][string]$Text)

    $lines = @($Text -split "`r?`n")
    $sawAnyTableLine = $false
    $headerIdx = -1
    $colSession = -1
    $colBlock = -1
    $colOwns = -1
    $colStatus = -1

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $cells = Split-MarkdownRow -Line $lines[$i]
        if ($null -eq $cells) { continue }
        $sawAnyTableLine = $true
        if (Test-SeparatorRow -Cells $cells) { continue }
        $lower = @($cells | ForEach-Object { (Get-CellPlain $_).ToLowerInvariant() })
        $bi = [array]::IndexOf($lower, 'order block')
        $si = [array]::IndexOf($lower, 'status')
        if ($bi -ge 0 -and $si -ge 0) {
            $headerIdx = $i
            $colBlock = $bi
            $colStatus = $si
            $colSession = [array]::IndexOf($lower, 'session id')
            $colOwns = [array]::IndexOf($lower, 'owns paths')
            break
        }
    }

    if ($headerIdx -lt 0) {
        if (-not $sawAnyTableLine) { throw ('{0} contains no markdown table at all' -f $LedgerPath) }
        throw ('{0} has no lane table with both an "order block" and a "status" column' -f $LedgerPath)
    }

    $lanes = New-Object System.Collections.Generic.List[object]
    for ($i = $headerIdx + 1; $i -lt $lines.Count; $i++) {
        $cells = Split-MarkdownRow -Line $lines[$i]
        if ($null -eq $cells) {
            if ([string]::IsNullOrWhiteSpace($lines[$i])) { continue }
            break   # a non-blank, non-table line ends this table
        }
        if (Test-SeparatorRow -Cells $cells) { continue }
        if ($cells.Count -le $colStatus) { continue }

        $sessionId = 'unknown-session'
        if ($colSession -ge 0 -and $cells.Count -gt $colSession) {
            $v = Get-CellPlain $cells[$colSession]
            if ($v) { $sessionId = $v }
        }
        $ownsRaw = ''
        if ($colOwns -ge 0 -and $cells.Count -gt $colOwns) { $ownsRaw = $cells[$colOwns] }
        $blockRaw = ''
        if ($colBlock -ge 0 -and $cells.Count -gt $colBlock) { $blockRaw = $cells[$colBlock] }

        $ranges = New-Object System.Collections.Generic.List[object]
        foreach ($m in [regex]::Matches($blockRaw, '(\d+)\s*-\s*(\d+)')) {
            $lo = [int]$m.Groups[1].Value
            $hi = [int]$m.Groups[2].Value
            if ($lo -gt $hi) { $t = $lo; $lo = $hi; $hi = $t }
            $ranges.Add([pscustomobject]@{ Low = $lo; High = $hi })
        }

        $owns = New-Object System.Collections.Generic.List[string]
        foreach ($m in [regex]::Matches($ownsRaw, '`([^`]+)`')) {
            $p = ($m.Groups[1].Value -replace '\\', '/').Trim()
            # Only backtick tokens that actually look like a path/glob; the column
            # also carries prose notes such as (row ORDER-GEN-STANDING).
            if ($p -and ($p -match '[/.*]')) { $owns.Add($p) }
        }

        $lanes.Add([pscustomobject]@{
            SessionId = $sessionId
            Status    = (Get-CellPlain $cells[$colStatus]).ToUpperInvariant()
            Ranges    = $ranges.ToArray()
            OwnsPaths = $owns.ToArray()
        })
    }
    return $lanes.ToArray()
}

function Convert-GlobToRegex {
    <# '_mt5_auto/**' -> '^_mt5_auto/.*$'. '*' stops at a '/', '**' does not. #>
    param([string]$Glob)
    $g = ($Glob -replace '\\', '/')
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('^')
    $i = 0
    while ($i -lt $g.Length) {
        $c = $g[$i]
        if ($c -eq '*') {
            if (($i + 1) -lt $g.Length -and $g[$i + 1] -eq '*') {
                [void]$sb.Append('.*')
                $i += 2
            } else {
                [void]$sb.Append('[^/]*')
                $i++
            }
            continue
        }
        if ($c -eq '?') { [void]$sb.Append('[^/]'); $i++; continue }
        [void]$sb.Append([regex]::Escape([string]$c))
        $i++
    }
    [void]$sb.Append('$')
    return $sb.ToString()
}

function Test-PathOwned {
    param([string]$StagedPath, [string]$OwnedPattern)
    $p = ($StagedPath -replace '\\', '/')
    $o = ($OwnedPattern -replace '\\', '/').TrimEnd('/')
    if ($o -notmatch '[*?]') {
        # A plain token is either the file itself or a declared directory prefix.
        if ($p -eq $o) { return $true }
        return $p.StartsWith($o + '/', [System.StringComparison]::OrdinalIgnoreCase)
    }
    return ($p -match ('(?i)' + (Convert-GlobToRegex -Glob $o)))
}

# ===========================================================================
# input acquisition -- offline (test overrides) or git
# ===========================================================================

$overrideNames = @('StagedActiveContent', 'ArchiveContent', 'HeadActiveContent', 'LedgerContent', 'StagedFileList')
$offline = $false
foreach ($n in $overrideNames) { if ($PSBoundParameters.ContainsKey($n)) { $offline = $true } }

$stagedPaths = @()
if ($offline) {
    if ($PSBoundParameters.ContainsKey('StagedFileList')) {
        $stagedPaths = @($StagedFileList | Where-Object { $_ } | ForEach-Object { ($_ -replace '\\', '/').Trim() })
    } elseif ($PSBoundParameters.ContainsKey('StagedActiveContent')) {
        # Supplying staged board content without a file list implies the board is staged.
        $stagedPaths = @($ActivePath)
    }
} else {
    try {
        $stagedPaths = @(Get-StagedPathsFromGit)
    } catch {
        Write-Host ('{0} TOOLING: {1}' -f $Tag, $_.Exception.Message)
        exit 2
    }
}

$taskboardStaged = $false
foreach ($p in $stagedPaths) { if ($p -eq $ActivePath) { $taskboardStaged = $true } }
if (-not $taskboardStaged) {
    Write-Host ('{0} {1} not staged -- pass (no-op)' -f $Tag, $ActivePath)
    exit 0
}

# --- staged active board ---
$stagedActive = ''
if ($offline) {
    if ($PSBoundParameters.ContainsKey('StagedActiveContent')) { $stagedActive = $StagedActiveContent }
} else {
    $stagedActive = Get-GitBlobText -Spec (':{0}' -f $ActivePath)
    if ($null -eq $stagedActive) {
        Write-Host ('{0} NOTE: {1} is staged but has no index blob (staged for deletion) -- nothing to check, pass' -f $Tag, $ActivePath)
        exit 0
    }
}

# --- committed archive ---
$archiveText = ''
if ($offline) {
    if ($PSBoundParameters.ContainsKey('ArchiveContent')) { $archiveText = $ArchiveContent }
} else {
    $archiveText = Get-GitBlobText -Spec ('HEAD:{0}' -f $ArchivePath)
    if ($null -eq $archiveText) {
        Write-Host ('{0} NOTE: HEAD:{1} not readable -- cross-board duplicate check skipped' -f $Tag, $ArchivePath)
        $archiveText = ''
    }
}

# --- committed active board (to work out what THIS commit adds) ---
$headActive = ''
if ($offline) {
    if ($PSBoundParameters.ContainsKey('HeadActiveContent')) { $headActive = $HeadActiveContent }
} else {
    $headActive = Get-GitBlobText -Spec ('HEAD:{0}' -f $ActivePath)
    if ($null -eq $headActive) { $headActive = '' }
}

# --- committed ledger (absence is a NOTE, not an error) ---
$ledgerPresent = $false
$ledgerText = ''
if ($offline) {
    if ($PSBoundParameters.ContainsKey('LedgerContent')) { $ledgerPresent = $true; $ledgerText = $LedgerContent }
} else {
    $t = Get-GitBlobText -Spec ('HEAD:{0}' -f $LedgerPath)
    if ($null -ne $t) { $ledgerPresent = $true; $ledgerText = $t }
}

$violations = New-Object System.Collections.Generic.List[string]

# ===========================================================================
# RULE 1 -- duplicate order id
# ===========================================================================

$stagedHeaders = @(Get-OrderHeaders -Text $stagedActive)
$archiveHeaders = @(Get-OrderHeaders -Text $archiveText)

$archiveLineById = @{}
foreach ($h in $archiveHeaders) { if (-not $archiveLineById.ContainsKey($h.Id)) { $archiveLineById[$h.Id] = $h.Line } }

$grandfathered = @{}
foreach ($g in $GrandfatheredDuplicateIds) { $grandfathered[$g.Trim().ToUpperInvariant()] = $true }

foreach ($grp in ($stagedHeaders | Group-Object -Property Id)) {
    if ($grp.Count -le 1) { continue }
    $lineList = (($grp.Group | ForEach-Object { $_.Line }) -join ', ')
    if ($grandfathered.ContainsKey($grp.Name)) {
        Write-Host ('{0} NOTE: grandfathered duplicate id ORDER-{1} ({2}x, lines {3}) -- historical defect, still owed a fix' -f $Tag, $grp.Name, $grp.Count, $lineList)
        continue
    }
    $violations.Add(('duplicate order id ORDER-{0}: {1} headers in staged {2} (lines {3})' -f $grp.Name, $grp.Count, $ActivePath, $lineList))
}

foreach ($id in (@($stagedHeaders | ForEach-Object { $_.Id }) | Select-Object -Unique)) {
    if (-not $archiveLineById.ContainsKey($id)) { continue }
    if ($grandfathered.ContainsKey($id)) {
        Write-Host ('{0} NOTE: grandfathered id ORDER-{1} exists in both boards -- historical defect, still owed a fix' -f $Tag, $id)
        continue
    }
    $stagedLine = (@($stagedHeaders | Where-Object { $_.Id -eq $id } | ForEach-Object { $_.Line }) -join ', ')
    $violations.Add(('order id ORDER-{0} exists in BOTH staged {1} (line {2}) and committed {3} (line {4})' -f $id, $ActivePath, $stagedLine, $ArchivePath, $archiveLineById[$id]))
}

# ===========================================================================
# RULES 2 + 3 -- ledger-driven
# ===========================================================================

$activeLanes = @()
$ledgerUsable = $false
if (-not $ledgerPresent) {
    Write-Host ('{0} NOTE: {1} not found in HEAD -- reserved-block and owned-path rules skipped' -f $Tag, $LedgerPath)
} else {
    $lanes = @()
    try {
        $lanes = @(Get-LedgerLanes -Text $ledgerText)
    } catch {
        Write-Host ('{0} TOOLING: {1}' -f $Tag, $_.Exception.Message)
        exit 2
    }
    $activeLanes = @($lanes | Where-Object { $_.Status -eq 'ACTIVE' })
    if ($activeLanes.Count -eq 0) {
        Write-Host ('{0} NOTE: no ACTIVE lane in {1} ({2} row(s) parsed) -- reserved-block and owned-path rules skipped' -f $Tag, $LedgerPath, $lanes.Count)
    } else {
        $ledgerUsable = $true
    }
}

if ($ledgerUsable) {
    # --- RULE 2 ---
    $ranges = New-Object System.Collections.Generic.List[object]
    foreach ($lane in $activeLanes) { foreach ($r in $lane.Ranges) { $ranges.Add($r) } }

    if ($ranges.Count -eq 0) {
        Write-Host ('{0} NOTE: no ACTIVE lane in {1} declares a parseable order block -- reserved-block rule skipped' -f $Tag, $LedgerPath)
    } else {
        $headIds = @{}
        foreach ($h in (Get-OrderHeaders -Text $headActive)) { $headIds[$h.Id] = $true }

        $rangeText = (($ranges | ForEach-Object { '{0}-{1}' -f $_.Low, $_.High }) -join ', ')
        foreach ($id in (@($stagedHeaders | ForEach-Object { $_.Id }) | Select-Object -Unique)) {
            if ($headIds.ContainsKey($id)) { continue }          # not new in this commit
            if ($id -notmatch '^\d+$') {
                Write-Host ('{0} NOTE: new non-numeric order id ORDER-{1} is exempt from the reserved-block rule' -f $Tag, $id)
                continue
            }
            $n = [int]$id
            $inside = $false
            foreach ($r in $ranges) { if ($n -ge $r.Low -and $n -le $r.High) { $inside = $true; break } }
            if (-not $inside) {
                $violations.Add(('new order ORDER-{0} is outside every ACTIVE reserved block ({1}) declared in {2} -- reserve a block before using the number' -f $id, $rangeText, $LedgerPath))
            }
        }
    }

    # --- RULE 3 (WARN only, never touches the exit code) ---
    # Aggregated by (session, owned-pattern) on purpose. Emitting one line per staged
    # file produced ~70 warnings on a single archive-migration commit, most of them
    # about the committing lane's OWN declared paths. That volume is self-defeating:
    # a reader who scrolls past 70 warnings once will scroll past the 71st that
    # actually mattered. One line per claim, with a count and one example, keeps the
    # signal at a size somebody will read.
    $ruleThreeHits = New-Object System.Collections.Specialized.OrderedDictionary
    foreach ($sp in $stagedPaths) {
        foreach ($lane in $activeLanes) {
            $matchedPattern = $null
            foreach ($owned in $lane.OwnsPaths) {
                if (Test-PathOwned -StagedPath $sp -OwnedPattern $owned) { $matchedPattern = $owned; break }
            }
            if ($matchedPattern) {
                $key = '{0}|{1}' -f $lane.SessionId, $matchedPattern
                if (-not $ruleThreeHits.Contains($key)) {
                    $ruleThreeHits[$key] = [pscustomobject]@{
                        SessionId = $lane.SessionId; Pattern = $matchedPattern
                        Count = 0; Example = $sp
                    }
                }
                $ruleThreeHits[$key].Count++
            }
        }
    }
    foreach ($key in $ruleThreeHits.Keys) {
        $h = $ruleThreeHits[$key]
        if ($h.Count -eq 1) {
            Write-Host ('{0} WARN: staged path {1} is declared by ACTIVE session {2} (owns {3}) -- coordinate before writing' -f $Tag, $h.Example, $h.SessionId, $h.Pattern)
        } else {
            Write-Host ('{0} WARN: {1} staged path(s) match "{2}" declared by ACTIVE session {3} (e.g. {4}) -- coordinate before writing' -f $Tag, $h.Count, $h.Pattern, $h.SessionId, $h.Example)
        }
    }
}

# ===========================================================================

if ($violations.Count -gt 0) {
    foreach ($v in $violations) { Write-Host ('{0} BLOCK: {1}' -f $Tag, $v) }
    Write-Host ('{0} BLOCK: {1} collision violation(s) -- commit refused' -f $Tag, $violations.Count)
    exit 1
}

Write-Host ('{0} PASS -- {1} order header(s) staged, no id collision and no reserved-block breach' -f $Tag, $stagedHeaders.Count)
exit 0
