<#
.SYNOPSIS
    Handoff routing-contract guard. READ-ONLY validator intended to be called from
    .githooks/pre-commit alongside scripts/check_precommit_staged.ps1 and
    scripts/check_order_collision.ps1.

.DESCRIPTION
    Everything this script judges is read from the git INDEX (staged bytes) or from
    committed refs -- NEVER from the working tree. Same ProcessStartInfo git
    primitive and the same explicit UTF-8 decode discipline as
    scripts/check_order_collision.ps1.

    WHY IT EXISTS
        docs/WORK_LIFECYCLE.md section 2: a handoff is a shift report, not a work
        queue -- the queue lives on AGENT_TASKBOARD.md alone. A 2026-07-26 sweep of
        17 handoffs found 100 forward-looking items of which 27 had never reached
        the board: written at the end of a session, invisible to the next one. This
        guard turns that requirement from something remembered into something
        enforced.

    TRIGGER
        Any staged path matching _triage/HANDOFF*.md or _triage/SESSION_HANDOFF*.md
        (at any depth under _triage/) whose staged status is A or M. Paths under
        _triage/_archive/** are ignored entirely -- an already-closed handoff must
        never be re-validated. Deletions (and renames/copies, which are how a
        handoff gets archived) are ignored. Nothing matching -> fast no-op pass.

    THE CONTRACT
        Each triggering handoff must carry a routing section opened by the literal
        HTML comment line

            <!-- HANDOFF-ROUTING -->

        and running to the next '## ' heading or EOF. Destination tokens are read
        out of the markdown table rows inside that block (lines starting with '|');
        prose inside the block is ignored on purpose (see below). Three shapes:

            ORDER-<id>    id = [0-9A-Za-z] groups joined by '-' or '_'
                          (ORDER-230, ORDER-098-C, ORDER-LANEC-FAN)
            BACKLOG-<id>  (BACKLOG-D7)
            DONE          finished in this session, needs no future home

        A token RESOLVES when:
            ORDER-x    '## ORDER-x' is a header in the staged-or-HEAD
                       AGENT_TASKBOARD.md, or in HEAD:ARCHIVE_TASKBOARD_2026-07A.md
            BACKLOG-x  '| x |' opens a table row in the staged-or-HEAD
                       MASTER_BACKLOG.md
            DONE       always

        Ids are matched WHOLE: the token ORDER-098 is not satisfied by a
        '## ORDER-098-C' header. Two unrelated orders is exactly the accident this
        repo already owns one of.

    WHAT IT DELIBERATELY DOES NOT DO
        It does not read prose and it does not count items. No script can verify
        "you listed every forward-looking item". The checkable half of the rule is
        "you wrote down where each item went, and those places exist" -- that is
        all this enforces. So it fails CLOSED on a missing or token-less routing
        section, and stays silent about everything else it cannot understand.

    Exit 0 = pass (or nothing relevant staged). Exit 1 = a BLOCK rule fired.
    Exit 2 = tooling failure (git unavailable, staged blob unreadable, or the
    destination boards unreadable while tokens still need resolving).

.PARAMETER StagedFileList
    Test override. Supplying ANY override parameter puts the script in offline mode:
    no git process is spawned at all, and every override left unbound is treated as
    absent (empty). Real hook usage passes none of them.

    Entries are 'git diff --cached --name-status' lines ("M<TAB>path"); for test
    convenience "M path" and a bare "path" are also accepted (bare = modified). On a
    rename/copy line the LAST tab-separated field is taken as the path.

.PARAMETER HandoffContentMap
    Test override. Hashtable of staged-path -> file text. Replaces 'git show :<path>'.

.PARAMETER ActiveBoardContent
    Test override. Replaces the staged-or-HEAD AGENT_TASKBOARD.md blob.

.PARAMETER ArchiveBoardContent
    Test override. Replaces the HEAD:ARCHIVE_TASKBOARD_2026-07A.md blob.

.PARAMETER BacklogContent
    Test override. Replaces the staged-or-HEAD MASTER_BACKLOG.md blob.
#>
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),

    # --- test overrides (see .PARAMETER StagedFileList) ---
    [AllowEmptyCollection()][string[]]$StagedFileList,
    [hashtable]$HandoffContentMap,
    [AllowEmptyString()][string]$ActiveBoardContent,
    [AllowEmptyString()][string]$ArchiveBoardContent,
    [AllowEmptyString()][string]$BacklogContent
)

$ErrorActionPreference = 'Stop'

$Tag              = '[handoff-contract]'
$ActiveBoardPath  = 'AGENT_TASKBOARD.md'
$ArchiveBoardPath = 'ARCHIVE_TASKBOARD_2026-07A.md'
$BacklogPath      = 'MASTER_BACKLOG.md'
$MarkerLiteral    = '<!-- HANDOFF-ROUTING -->'

# This file is kept pure ASCII on purpose: Windows PowerShell 5.1 decodes a BOM-less
# .ps1 as ANSI, which turns any literal non-ASCII character into '?' and silently
# breaks whatever regex or message contained it. The handoffs themselves are full of
# Thai -- that text only ever arrives as decoded UTF-8 DATA, never as source.
$MarkerRegex      = '^\s*<!--\s*HANDOFF-ROUTING\s*-->\s*$'
$SectionEndRegex  = '^##\s'
$HandoffPathRegex = '(?i)^_triage/(?:[^/]+/)*(?:SESSION_)?HANDOFF[^/]*\.md$'
$ArchiveDirRegex  = '(?i)^_triage/_archive/'

# One id shape everywhere: alnum groups joined by '-' or '_'.
$IdPattern           = '[0-9A-Za-z]+(?:[-_][0-9A-Za-z]+)*'
$OrderTokenRegex     = 'ORDER-(' + $IdPattern + ')'
$BacklogTokenRegex   = 'BACKLOG-(' + $IdPattern + ')'
$DoneTokenRegex      = '\bDONE\b'
$OrderHeaderRegex    = '^##\s+ORDER-(' + $IdPattern + ')'
$BacklogRowRegex     = '^\|\s*[`*]*(' + $IdPattern + ')[`*]*\s*\|'

# ===========================================================================
# git primitives (index / committed only -- never the working tree)
# ===========================================================================

function Invoke-GitBytes {
    <# Runs `git <args>` with RepoRoot as cwd and returns the RAW stdout bytes, so the
       caller controls decoding (UTF-8) instead of letting the console codepage mangle
       the Thai that every handoff in this repo is written in. #>
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
    <# `git show <spec>` decoded as UTF-8. $null when the object does not exist
       (path not in the index / not in HEAD / no HEAD at all). #>
    param([string]$Spec)
    $r = Invoke-GitBytes -Arguments ('show "{0}"' -f $Spec)
    if ($r.ExitCode -ne 0) { return $null }
    return (ConvertFrom-Utf8Bytes -Bytes $r.Bytes)
}

function ConvertTo-StagedEntry {
    <# One 'git diff --cached --name-status' line -> @{ Status; Path }, or $null for a
       blank line. Status is normalised to its leading letter ('R100' -> 'R'). #>
    param([AllowEmptyString()][string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
    $status = 'M'
    $path = ''
    $fields = @($Line -split "`t")
    if ($fields.Count -ge 2) {
        $status = $fields[0].Trim()
        # rename/copy lines are 'R100 <old> <new>' -- the new path is what got staged
        $path = $fields[$fields.Count - 1].Trim()
    } elseif ($Line -match '^\s*([AMDRCTUX][0-9]*)\s+(\S.*)$') {
        $status = $Matches[1].Trim()
        $path = $Matches[2].Trim()
    } else {
        $path = $Line.Trim()
    }
    if (-not $path) { return $null }
    if ($status) { $status = $status.Substring(0, 1).ToUpperInvariant() } else { $status = 'M' }
    return [pscustomobject]@{ Status = $status; Path = ($path -replace '\\', '/') }
}

function Get-StagedEntriesFromGit {
    # snapshot: index -- which handoffs this commit adds or modifies. The status letter matters
    # as much as the path (a rename/delete is how a handoff gets archived and must not trigger),
    # and both come from this one read, so the trigger cannot disagree with itself.
    $r = Invoke-GitBytes -Arguments '-c core.quotePath=false diff --cached --name-status'
    if ($r.ExitCode -ne 0) { throw ('git diff --cached --name-status failed (exit {0}): {1}' -f $r.ExitCode, $r.StdErr) }
    $text = ConvertFrom-Utf8Bytes -Bytes $r.Bytes
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($line in ($text -split "`r?`n")) {
        $e = ConvertTo-StagedEntry -Line $line
        if ($null -ne $e) { $out.Add($e) }
    }
    return $out.ToArray()
}

# ===========================================================================
# markdown / token parsing
# ===========================================================================

function Split-MarkdownRow {
    <# '| a | b | c |' -> @('a','b','c'). $null for a non-table line. #>
    param([string]$Line)
    $t = $Line.Trim()
    if (-not $t.StartsWith('|')) { return $null }
    $t = $t.Substring(1)
    if ($t.EndsWith('|')) { $t = $t.Substring(0, $t.Length - 1) }
    $cells = @($t -split '\|')
    return @($cells | ForEach-Object { $_.Trim() })
}

function Test-SeparatorRow {
    param([string[]]$Cells)
    if ($null -eq $Cells -or $Cells.Count -eq 0) { return $false }
    foreach ($c in $Cells) { if ($c -notmatch '^:?-{2,}:?$') { return $false } }
    return $true
}

function Get-CellPlain {
    <# Strip markdown code ticks / emphasis so `ORDER-230` and **DONE** compare cleanly.
       Underscore is NOT stripped: it is a legal character inside an id. #>
    param([AllowEmptyString()][string]$Cell)
    if ($null -eq $Cell) { return '' }
    return ($Cell -replace '[`*]', '').Trim()
}

function Test-IsHandoffPath {
    <# _triage/_archive/** is excluded FIRST: a closed handoff is history, and
       re-validating history would block every archival commit. #>
    param([string]$Path)
    $p = ($Path -replace '\\', '/').Trim()
    if (-not $p) { return $false }
    if ($p -match $ArchiveDirRegex) { return $false }
    return ($p -match $HandoffPathRegex)
}

function Get-RoutingBlock {
    <# -> @{ MarkerFound; MarkerLine; Lines }. The block runs from the line after the
       marker to the next '## ' heading (exclusive) or EOF. #>
    param([AllowEmptyString()][string]$Text)
    $lines = @()
    if (-not [string]::IsNullOrEmpty($Text)) { $lines = @($Text -split "`r?`n") }
    $markerIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -cmatch $MarkerRegex) { $markerIdx = $i; break }
    }
    if ($markerIdx -lt 0) {
        return [pscustomobject]@{ MarkerFound = $false; MarkerLine = 0; Lines = @() }
    }
    $block = New-Object System.Collections.Generic.List[string]
    for ($i = $markerIdx + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $SectionEndRegex) { break }
        $block.Add($lines[$i])
    }
    return [pscustomobject]@{ MarkerFound = $true; MarkerLine = ($markerIdx + 1); Lines = $block.ToArray() }
}

function Get-DestinationTokens {
    <# Destination tokens from the TABLE ROWS of a routing block, in order, with the
       1-based line number inside the block. Matching is case-SENSITIVE: the tokens
       are an uppercase convention, and a case-insensitive '\bDONE\b' would fire on
       the English word 'done' sitting in a description cell. #>
    param([string[]]$BlockLines, [int]$BlockStartLine)
    $out = New-Object System.Collections.Generic.List[object]
    if ($null -eq $BlockLines) { return $out.ToArray() }
    for ($i = 0; $i -lt $BlockLines.Count; $i++) {
        $cells = Split-MarkdownRow -Line $BlockLines[$i]
        if ($null -eq $cells) { continue }
        if (Test-SeparatorRow -Cells $cells) { continue }
        $lineNo = $BlockStartLine + $i
        foreach ($cell in $cells) {
            $plain = Get-CellPlain $cell
            if (-not $plain) { continue }
            foreach ($m in [regex]::Matches($plain, $OrderTokenRegex)) {
                $out.Add([pscustomobject]@{ Kind = 'ORDER'; Id = $m.Groups[1].Value.ToUpperInvariant(); Text = ('ORDER-' + $m.Groups[1].Value); Line = $lineNo })
            }
            foreach ($m in [regex]::Matches($plain, $BacklogTokenRegex)) {
                $out.Add([pscustomobject]@{ Kind = 'BACKLOG'; Id = $m.Groups[1].Value.ToUpperInvariant(); Text = ('BACKLOG-' + $m.Groups[1].Value); Line = $lineNo })
            }
            if ([regex]::IsMatch($plain, $DoneTokenRegex)) {
                $out.Add([pscustomobject]@{ Kind = 'DONE'; Id = 'DONE'; Text = 'DONE'; Line = $lineNo })
            }
        }
    }
    return $out.ToArray()
}

function Get-OrderHeaderIds {
    <# Set of '## ORDER-<id>' ids in a board. Whole-id: '## ORDER-098-C' yields
       '098-C' and NOT '098'. #>
    param([AllowEmptyString()][string]$Text)
    $ids = @{}
    if ([string]::IsNullOrEmpty($Text)) { return $ids }
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match $OrderHeaderRegex) { $ids[$Matches[1].ToUpperInvariant()] = $true }
    }
    return $ids
}

function Get-BacklogRowIds {
    <# Set of first-column ids of every markdown table row in MASTER_BACKLOG.md. #>
    param([AllowEmptyString()][string]$Text)
    $ids = @{}
    if ([string]::IsNullOrEmpty($Text)) { return $ids }
    foreach ($line in ($Text -split "`r?`n")) {
        $t = $line.Trim()
        if (-not $t.StartsWith('|')) { continue }
        if ($t -match $BacklogRowRegex) { $ids[$Matches[1].ToUpperInvariant()] = $true }
    }
    return $ids
}

# ===========================================================================
# input acquisition -- offline (test overrides) or git
# ===========================================================================

$overrideNames = @('StagedFileList', 'HandoffContentMap', 'ActiveBoardContent', 'ArchiveBoardContent', 'BacklogContent')
$offline = $false
foreach ($n in $overrideNames) { if ($PSBoundParameters.ContainsKey($n)) { $offline = $true } }

$handoffMap = @{}
if ($offline -and $PSBoundParameters.ContainsKey('HandoffContentMap') -and $null -ne $HandoffContentMap) {
    foreach ($k in $HandoffContentMap.Keys) {
        $handoffMap[(([string]$k) -replace '\\', '/').Trim()] = [string]$HandoffContentMap[$k]
    }
}

$entries = @()
if ($offline) {
    if ($PSBoundParameters.ContainsKey('StagedFileList')) {
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($raw in @($StagedFileList)) {
            $e = ConvertTo-StagedEntry -Line $raw
            if ($null -ne $e) { $list.Add($e) }
        }
        $entries = $list.ToArray()
    } elseif ($handoffMap.Count -gt 0) {
        # Content supplied without a file list implies those paths are staged (modified).
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($k in $handoffMap.Keys) { $list.Add([pscustomobject]@{ Status = 'M'; Path = $k }) }
        $entries = $list.ToArray()
    }
} else {
    try {
        $entries = @(Get-StagedEntriesFromGit)
    } catch {
        Write-Host ('{0} TOOLING: {1}' -f $Tag, $_.Exception.Message)
        exit 2
    }
}

$targets = New-Object System.Collections.Generic.List[object]
$seenPath = @{}
foreach ($e in $entries) {
    if ($e.Status -ne 'A' -and $e.Status -ne 'M') { continue }
    if (-not (Test-IsHandoffPath -Path $e.Path)) { continue }
    if ($seenPath.ContainsKey($e.Path)) { continue }
    $seenPath[$e.Path] = $true
    $targets.Add($e)
}

if ($targets.Count -eq 0) {
    Write-Host ('{0} no added/modified handoff staged -- pass (no-op)' -f $Tag)
    exit 0
}

# --- handoff bodies (index blobs) ---
$docs = New-Object System.Collections.Generic.List[object]
foreach ($t in $targets) {
    $text = $null
    if ($offline) {
        if ($handoffMap.ContainsKey($t.Path)) { $text = $handoffMap[$t.Path] }
    } else {
        # snapshot: index -- the handoff as this commit will contain it. Reading the worktree
        # here would judge a routing section the author has since edited and not staged.
        $text = Get-GitBlobText -Spec (':{0}' -f $t.Path)
    }
    if ($null -eq $text) {
        Write-Host ('{0} TOOLING: cannot read the staged blob for {1} (git show :{1})' -f $Tag, $t.Path)
        exit 2
    }
    $docs.Add([pscustomobject]@{ Path = $t.Path; Text = $text })
}

# ===========================================================================
# parse every triggering handoff, then resolve what it points at
# ===========================================================================

$violations = New-Object System.Collections.Generic.List[string]
$parsed = New-Object System.Collections.Generic.List[object]
$needOrder = $false
$needBacklog = $false

foreach ($d in $docs) {
    $block = Get-RoutingBlock -Text $d.Text
    if (-not $block.MarkerFound) {
        $violations.Add(('{0} has no {1} section -- every forward-looking item needs a written destination (docs/WORK_LIFECYCLE.md section 2)' -f $d.Path, $MarkerLiteral))
        continue
    }
    $tokens = @(Get-DestinationTokens -BlockLines $block.Lines -BlockStartLine ($block.MarkerLine + 1))
    if ($tokens.Count -eq 0) {
        $violations.Add(('{0} has a {1} section (line {2}) with no destination token -- expected markdown table rows carrying ORDER-<id>, BACKLOG-<id> or DONE' -f $d.Path, $MarkerLiteral, $block.MarkerLine))
        continue
    }
    foreach ($tk in $tokens) {
        if ($tk.Kind -eq 'ORDER') { $needOrder = $true }
        if ($tk.Kind -eq 'BACKLOG') { $needBacklog = $true }
    }
    $parsed.Add([pscustomobject]@{ Path = $d.Path; Tokens = $tokens })
}

# --- destination registries, fetched only when a token actually needs them ---
$activeIds = @{}
$archiveIds = @{}
$backlogIds = @{}

if ($needOrder) {
    if ($offline) {
        $activeIds = Get-OrderHeaderIds -Text $ActiveBoardContent
        $archiveIds = Get-OrderHeaderIds -Text $ArchiveBoardContent
    } else {
        # snapshot: index -- the board as this commit will contain it. A handoff routing an item
        # to an order the SAME commit opens must resolve, or the guard forbids the one shape
        # WORK_LIFECYCLE actually asks for.
        $activeText = Get-GitBlobText -Spec (':{0}' -f $ActiveBoardPath)
        # snapshot: HEAD -- reached only when the path has NO index entry at all (staged for
        # deletion, or untracked). Not a vintage preference: it is "the board still exists in
        # history, resolve against that rather than refuse", and it is stated so the fallback
        # cannot be mistaken for the primary read.
        if ($null -eq $activeText) { $activeText = Get-GitBlobText -Spec ('HEAD:{0}' -f $ActiveBoardPath) }
        # ORDER-674 owed half, 2026-07-31: THIS READ WAS `HEAD:` AND IT REFUSED VALID WORK.
        #
        # Decision log 2026-07-26 (WORK_LIFECYCLE): "REVIEWED* = archive it immediately, SAME
        # COMMIT -- no big sweep passes". So the normal, mandated shape is a commit that moves
        # `## ORDER-X` out of the active board and into the archive. Under a HEAD read, a
        # handoff in that same commit routing an item to ORDER-X resolved against NEITHER board:
        # the staged active no longer has it and HEAD's archive does not have it yet. BLOCK --
        # on the exact workflow this repo requires.
        #
        # That is the failure the Decision log names on 2026-07-30: "a guard that refuses valid
        # work is not extra safe, it is the failure that gets guards switched off". Caged as C1.
        #
        # Reading the index is also STRICTER where it should be: an id deleted from the staged
        # archive stops resolving, instead of resolving against a HEAD copy the commit removes.
        # snapshot: index
        $archiveText = Get-GitBlobText -Spec (':{0}' -f $ArchiveBoardPath)
        if ($null -eq $activeText -and $null -eq $archiveText) {
            Write-Host ('{0} TOOLING: neither {1} nor {2} is readable, but ORDER tokens need resolving -- refusing to guess' -f $Tag, $ActiveBoardPath, $ArchiveBoardPath)
            exit 2
        }
        if ($null -eq $activeText) { Write-Host ('{0} NOTE: {1} unreadable -- ORDER tokens resolved against the archive only' -f $Tag, $ActiveBoardPath) }
        if ($null -eq $archiveText) { Write-Host ('{0} NOTE: :{1} unreadable from the index -- ORDER tokens resolved against the active board only' -f $Tag, $ArchiveBoardPath) }
        $activeIds = Get-OrderHeaderIds -Text $activeText
        $archiveIds = Get-OrderHeaderIds -Text $archiveText
    }
}

if ($needBacklog) {
    if ($offline) {
        $backlogIds = Get-BacklogRowIds -Text $BacklogContent
    } else {
        # snapshot: index -- same reason as the active board: a BACKLOG row added by this commit
        # must resolve for a handoff in the same commit.
        $backlogText = Get-GitBlobText -Spec (':{0}' -f $BacklogPath)
        # snapshot: HEAD -- the no-index-entry fallback, the pair of the line above.
        if ($null -eq $backlogText) { $backlogText = Get-GitBlobText -Spec ('HEAD:{0}' -f $BacklogPath) }
        if ($null -eq $backlogText) {
            Write-Host ('{0} TOOLING: {1} is not readable, but BACKLOG tokens need resolving -- refusing to guess' -f $Tag, $BacklogPath)
            exit 2
        }
        $backlogIds = Get-BacklogRowIds -Text $backlogText
    }
}

$resolvedTotal = 0

foreach ($p in $parsed) {
    $nOrder = 0
    $nBacklog = 0
    $nDone = 0
    $reported = @{}
    foreach ($tk in $p.Tokens) {
        $key = $tk.Kind + '|' + $tk.Id
        $ok = $false
        $where = ''
        if ($tk.Kind -eq 'DONE') {
            $ok = $true
            $where = 'closed in this session'
        } elseif ($tk.Kind -eq 'ORDER') {
            if ($activeIds.ContainsKey($tk.Id)) { $ok = $true; $where = $ActiveBoardPath }
            elseif ($archiveIds.ContainsKey($tk.Id)) { $ok = $true; $where = $ArchiveBoardPath }
        } elseif ($tk.Kind -eq 'BACKLOG') {
            if ($backlogIds.ContainsKey($tk.Id)) { $ok = $true; $where = $BacklogPath }
        }

        if ($ok) {
            if (-not $reported.ContainsKey($key)) {
                $reported[$key] = $true
                $resolvedTotal++
                if ($tk.Kind -eq 'ORDER') { $nOrder++ }
                elseif ($tk.Kind -eq 'BACKLOG') { $nBacklog++ }
                else { $nDone++ }
            }
            continue
        }

        if ($reported.ContainsKey($key)) { continue }
        $reported[$key] = $true
        if ($tk.Kind -eq 'ORDER') {
            $violations.Add(('{0} (line {1}) routes to {2} but no "## {2}" header exists in {3} or {4} -- open the order (reserve the number first) or point the row somewhere real' -f $p.Path, $tk.Line, $tk.Text, $ActiveBoardPath, $ArchiveBoardPath))
        } else {
            $violations.Add(('{0} (line {1}) routes to {2} but no "| {3} |" row exists in {4} -- add the backlog row (with its wake-up condition) or point the row somewhere real' -f $p.Path, $tk.Line, $tk.Text, $tk.Id, $BacklogPath))
        }
    }
    Write-Host ('{0} routed: {1} -- {2} order, {3} backlog, {4} done' -f $Tag, $p.Path, $nOrder, $nBacklog, $nDone)
}

# ===========================================================================

if ($violations.Count -gt 0) {
    foreach ($v in $violations) { Write-Host ('{0} BLOCK: {1}' -f $Tag, $v) }
    Write-Host ('{0} BLOCK: {1} handoff routing violation(s) -- commit refused' -f $Tag, $violations.Count)
    exit 1
}

Write-Host ('{0} PASS -- {1} handoff file(s) staged, {2} destination token(s), all resolved' -f $Tag, $targets.Count, $resolvedTotal)
exit 0
