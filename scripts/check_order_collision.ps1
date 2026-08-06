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
        and out of the STAGED ARCHIVE_TASKBOARD_2026-07A.md -- both at the INDEX,
        because "appears in both boards" is a claim about the repository this commit
        produces. The archive side read HEAD until 2026-07-31 (ORDER-674 owed half);
        see the block comment at the archive read for what that missed. <id> is everything
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
    # ORDER-760 RULE 4 judges the STAGED ledger, so the cage needs to supply both vintages
    # independently -- otherwise the one case that matters (a commit that REPAIRS a malformed
    # row must land) cannot be expressed at all.
    [AllowEmptyString()][string]$StagedLedgerContent,
    [AllowEmptyCollection()][string[]]$StagedFileList,
    # ORDER-1460 (2026-08-06). RULE 2's restoration answer, supplied by the cage. Offline mode
    # spawns no git at all, so the "did this file ever carry this header?" question -- which is
    # a question about HISTORY, not about any content this script is handed -- has no other way
    # to be expressed. A single element 'NONE' means "the empty list", the spelled-sentinel
    # convention this repo already uses because `powershell -File` cannot pass @().
    [AllowEmptyCollection()][string[]]$RestorableIdsOverride
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

function Test-IsRestoredId {
    <# ORDER-1460. Did the active board EVER carry `## ORDER-<id>` and lose it?

       This is a question about HISTORY, which is why it cannot be answered from any content
       this script is handed: RULE 2 compares STAGED headers against HEAD's, and both vintages
       agree that a restored id is absent. Only the log knows it was there.

       Offline mode spawns no git at all, so the cage supplies the answer through
       -RestorableIdsOverride and the git call below is never reached from a test. That split is
       deliberate and is the same one every other input in this file uses.

       `git log -G` matches commits whose diff ADDS OR REMOVES a line matching the pattern. It is
       anchored at column 0 and demands the trailing space, so `## ORDER-1460` cannot be
       satisfied by a mention of ORDER-14600 or by prose quoting the id mid-sentence. `-1` stops
       at the first hit. It runs ONLY for an id that would otherwise be refused, so the ordinary
       commit pays nothing for it.

       Returns the COMMIT that last added or removed the header, or '' for "never carried it".
       Returning the evidence rather than a boolean is deliberate: this rule permits an id that
       every other reading calls out-of-block, so it has to be able to say WHICH commit entitles
       it. "Trust me" printed by a guard is the thing this repo keeps paying to remove. #>
    param([string]$Id)
    if ($null -ne $script:RestorableIds) {
        if ($script:RestorableIds.ContainsKey($Id)) { return '<supplied by -RestorableIdsOverride>' }
        return ''
    }
    $r = Invoke-GitBytes -Arguments ('log -1 --format=%H -G "^## ORDER-{0} " -- "{1}"' -f $Id, $ActivePath)
    # A git failure must NOT read as "not a restoration" -- that would be the same silent
    # downgrade this file refuses everywhere else. An unreadable log leaves the violation
    # standing, which is the conservative direction: the commit is refused and says why.
    if ($r.ExitCode -ne 0) { return '' }
    return (ConvertFrom-Utf8Bytes -Bytes $r.Bytes).Trim()
}

function Get-StagedPathsFromGit {
    # snapshot: index -- the paths this commit carries. This decides whether the guard runs at
    # all, so it must be the same vintage as the content read below; a trigger from one moment
    # and a verdict from another is A2.
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
    <# '| a | b | c |' -> @('a','b','c'). Returns $null for a non-table line.

       ORDER-760: the split is ESCAPE-AWARE. '\|' is how markdown writes a literal pipe inside a
       table cell, and every renderer treats it as one -- so a parser that splits on it disagrees
       with what a human sees, which is the "second source of truth" this order's own PROHIBITION
       names. Measured before changing it: of the 56 lane rows in docs/SESSION_LEDGER.md, TWO had
       a cell count that disagreed with the header, and ONE of them -- S-2026-08-01-CODEXBRIEF --
       had already written '\|' CORRECTLY and was being mis-split by this function. So the escape
       half is not a convenience; it is a live defect that made a correctly-written row malformed.

       Backticks are NOT honoured, deliberately. Markdown tables do not treat a pipe inside code
       ticks as literal either, so honouring them here would recreate the same disagreement in the
       other direction. #>
    param([string]$Line)
    $t = $Line.Trim()
    if (-not $t.StartsWith('|')) { return $null }
    $t = $t.Substring(1)
    # A TRAILING '\|' is an escaped pipe, not the row terminator. Checking the raw last two chars
    # before stripping keeps '...text \|' from losing its final cell boundary.
    if ($t.EndsWith('|') -and -not $t.EndsWith('\|')) { $t = $t.Substring(0, $t.Length - 1) }
    $cells = @($t -split '(?<!\\)\|')
    return @($cells | ForEach-Object { ($_ -replace '\\\|', '|').Trim() })
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

    # Strip HTML comments BEFORE splitting into lines. The row loop below stops at the first
    # non-blank line that is not a table row, so a <!-- ... --> note placed between the separator
    # and the first lane row silently truncated the table to ZERO lanes -- and a zero-lane parse
    # is reported as a NOTE, not a failure, so every reserved-block and owned-path rule was
    # skipped without anyone being told. Happened for real on 2026-07-27 (a VERIFY270 explanatory
    # note landed directly under the header). Explanatory prose inside the table is a reasonable
    # thing for a human to write; a guard that quietly switches itself off because of it is not.
    $Text = [regex]::Replace($Text, '(?s)<!--.*?-->', '')

    $lines = @($Text -split "`r?`n")
    $sawAnyTableLine = $false
    $headerIdx = -1
    $headerCells = @()
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
            $headerCells = $cells      # ORDER-760: the width every lane row is held to
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

    # ORDER-760: the header's own width is the contract every row is held to. Without it, a row
    # with an extra cell reads its STATUS from the wrong column and a row with too few is dropped
    # by the `continue` below -- and both look exactly like "this lane is not ACTIVE".
    $expectedCells = $headerCells.Count

    $lanes = New-Object System.Collections.Generic.List[object]
    for ($i = $headerIdx + 1; $i -lt $lines.Count; $i++) {
        $cells = Split-MarkdownRow -Line $lines[$i]
        if ($null -eq $cells) {
            if ([string]::IsNullOrWhiteSpace($lines[$i])) { continue }
            break   # a non-blank, non-table line ends this table
        }
        if (Test-SeparatorRow -Cells $cells) { continue }
        if ($cells.Count -le $colStatus) {
            # WAS a silent `continue`, and that silence is the whole of ORDER-760's instance A: a
            # row shifted far enough to lose its status column vanished from the parse, the lane
            # table still reported dozens of rows, and RULE 2 / RULE 3 switched themselves off
            # with a NOTE that read like a quiet day. It is now RECORDED so the caller can refuse.
            $lostId = 'unknown-session'
            if ($colSession -ge 0 -and $cells.Count -gt $colSession) {
                $v = Get-CellPlain $cells[$colSession]
                if ($v) { $lostId = $v }
            }
            $lanes.Add([pscustomobject]@{
                SessionId     = $lostId
                Status        = '<UNREADABLE>'
                Ranges        = @()
                Malformed     = @()
                OwnsPaths     = @()
                CellCount     = $cells.Count
                ExpectedCells = $expectedCells
                LineNumber    = $i + 1
            })
            continue
        }

        $sessionId = 'unknown-session'
        if ($colSession -ge 0 -and $cells.Count -gt $colSession) {
            $v = Get-CellPlain $cells[$colSession]
            if ($v) { $sessionId = $v }
        }
        $ownsRaw = ''
        if ($colOwns -ge 0 -and $cells.Count -gt $colOwns) { $ownsRaw = $cells[$colOwns] }
        $blockRaw = ''
        if ($colBlock -ge 0 -and $cells.Count -gt $colBlock) { $blockRaw = $cells[$colBlock] }

        # A RANGE TOKEN MUST BE A RANGE, not any two numbers that happen to have a dash
        # between them (ORDER-675). The old scan was '(\d+)\s*-\s*(\d+)' over the whole cell
        # with a low>high SWAP, and lane rows legitimately cite filenames and dates in this
        # column. `ARCHIVE_TASKBOARD_2026-07A.md` yielded 2026-07, the swap turned it into
        # 7-2026, and that ONE range contains every order number this repo will ever issue --
        # so the reserved-block rule reported PASS on ORDER-999. Measured on the real ledger,
        # by the lane that wrote the row.
        #   * the boundaries reject a match glued to a word char, a dot or another dash, which
        #     is what excludes 2026-07A (leading '_') and 2026-07-31 (trailing '-31');
        #   * NO SWAP. A descending pair is not a declaration written backwards, it is a token
        #     this parser cannot interpret -- inverting it INVENTS a reservation nobody made.
        #     It is ignored and NAMED, because "I could not read it" must never look like
        #     "there was nothing there" (memory: guard-disarmed-by-prose-reported-as-note).
        #   * STATED LIMIT: a bare range immediately followed by '.' or '-' (e.g. a sentence
        #     ending "670-679.") is silently NOT matched -- the cost of excluding filenames.
        #     The failure lands on the LOUD path (zero ranges => a named NOTE + rule skipped,
        #     or the other declared ranges still enforce), never on a wrong range. The
        #     `enforcing reserved block(s):` line below is how a human notices the drop.
        $ranges = New-Object System.Collections.Generic.List[object]
        $malformed = New-Object System.Collections.Generic.List[string]
        foreach ($m in [regex]::Matches($blockRaw, '(?<![-\w.])(\d+)\s*-\s*(\d+)(?![-\w.])')) {
            $lo = [int]$m.Groups[1].Value
            $hi = [int]$m.Groups[2].Value
            if ($lo -gt $hi) { $malformed.Add($m.Value.Trim()); continue }
            $ranges.Add([pscustomobject]@{ Low = $lo; High = $hi })
        }

        $owns = New-Object System.Collections.Generic.List[string]
        foreach ($m in [regex]::Matches($ownsRaw, '`([^`]+)`')) {
            $p = ($m.Groups[1].Value -replace '\\', '/').Trim()
            # Only backtick tokens that actually look like a path/glob; the column
            # also carries prose notes such as (row ORDER-GEN-STANDING).
            if ($p -and ($p -match '[/.*]')) { $owns.Add($p) }
        }

        # Take the status VERB, not the whole cell. Every lane annotates its status with what
        # it closed, which commit, what is still owed -- so comparing the whole cell against
        # 'ACTIVE' silently misses every annotated row, and in practice that is nearly all of
        # them. Same family as the HTML-comment truncation above (ORDER-351): human prose in a
        # machine-read cell must not be able to switch the guard off. Anchored to the start so
        # a note that merely MENTIONS another state ("CLOSED, reopened as ACTIVE") cannot flip it.
        $statusRaw = (Get-CellPlain $cells[$colStatus]).ToUpperInvariant()
        $statusVerb = if ($statusRaw -match '^(ACTIVE|CLOSED|ABANDONED|BLOCKED)\b') { $Matches[1] } else { $statusRaw }

        $lanes.Add([pscustomobject]@{
            SessionId     = $sessionId
            Status        = $statusVerb
            Ranges        = $ranges.ToArray()
            Malformed     = $malformed.ToArray()
            OwnsPaths     = $owns.ToArray()
            CellCount     = $cells.Count
            ExpectedCells = $expectedCells
            LineNumber    = $i + 1
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

$overrideNames = @('StagedActiveContent', 'ArchiveContent', 'HeadActiveContent', 'LedgerContent', 'StagedLedgerContent', 'StagedFileList', 'RestorableIdsOverride')
$offline = $false
foreach ($n in $overrideNames) { if ($PSBoundParameters.ContainsKey($n)) { $offline = $true } }

# ORDER-1460. $null means "ask git"; a hashtable (possibly empty) means the cage answered.
$script:RestorableIds = $null
if ($PSBoundParameters.ContainsKey('RestorableIdsOverride')) {
    $script:RestorableIds = @{}
    foreach ($rid in @($RestorableIdsOverride)) {
        $t = "$rid".Trim()
        if ($t -and $t -ne 'NONE') { $script:RestorableIds[$t] = $true }
    }
} elseif ($offline) {
    # An offline run that did not answer the question must not silently fall through to git --
    # offline means no git process at all. The empty answer is the strict one: nothing is a
    # restoration, so every existing offline case keeps the verdict it had before this change.
    $script:RestorableIds = @{}
}

# ORDER-674 owed half: EVERY READ BELOW DECLARES ITS SNAPSHOT, and one of them was wrong.
# The file's own .DESCRIPTION said "read from the git INDEX or from committed refs -- NEVER from
# the working tree", which is true and was never the question. The question L3 asks is WHICH of
# the two, per read, and answering it found the archive being judged at the wrong vintage. See
# the fix at the `--- committed archive ---` block below.
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
    # snapshot: index -- the board as this commit will contain it. RULE 1's subject.
    $stagedActive = Get-GitBlobText -Spec (':{0}' -f $ActivePath)
    if ($null -eq $stagedActive) {
        Write-Host ('{0} NOTE: {1} is staged but has no index blob (staged for deletion) -- nothing to check, pass' -f $Tag, $ActivePath)
        exit 0
    }
}

# --- archive board, AS THIS COMMIT WILL CONTAIN IT ---
#
# ORDER-674 owed half, 2026-07-31: THIS READ WAS `HEAD:` AND THAT WAS WRONG.
#
# RULE 1 asks "does any order id appear in both boards". Both boards means both boards IN THE
# RESULTING REPOSITORY, and the resulting repository is the index -- the active side was already
# read from `:{0}` eight lines up. Reading the archive from HEAD made one verdict out of two
# moments, which is A2's crime in the guard whose whole job is cross-board consistency.
#
# What it cost, both directions, and neither is theoretical:
#   MISS  -- a commit that adds `## ORDER-X` to the active board AND to the archive creates the
#            duplicate this rule exists to refuse, and HEAD cannot see either half of it. PASS.
#            Proven by attack in scripts/_test/run_front_guard_evidence_tests.ps1 (case B1)
#            before this line changed.
#   FALSE BLOCK -- un-archiving (id removed from the staged archive, restored to the active
#            board) is refused against a HEAD that still holds it, i.e. the guard blocks the
#            commit that FIXES the state it is complaining about.
#
# `:{0}` is correct for an unmodified path too: its index entry is HEAD's blob, so the ordinary
# commit reads exactly what it read before. This is a strictly-more-accurate read, not a
# stricter one -- verified as such by the specificity half of the same case.
$archiveText = ''
if ($offline) {
    if ($PSBoundParameters.ContainsKey('ArchiveContent')) { $archiveText = $ArchiveContent }
} else {
    # snapshot: index
    $archiveText = Get-GitBlobText -Spec (':{0}' -f $ArchivePath)
    if ($null -eq $archiveText) {
        Write-Host ('{0} NOTE: :{1} not readable from the index -- cross-board duplicate check skipped' -f $Tag, $ArchivePath)
        $archiveText = ''
    }
}

# --- committed active board (to work out what THIS commit adds) ---
$headActive = ''
if ($offline) {
    if ($PSBoundParameters.ContainsKey('HeadActiveContent')) { $headActive = $HeadActiveContent }
} else {
    # snapshot: HEAD -- and DELIBERATELY not the index, unlike the two reads above. This is the
    # BASELINE that defines "what this commit ADDS": staged ids minus HEAD ids. Reading it from
    # the index would subtract the staged board from itself, RULE 2 would see zero new orders,
    # and the reserved-block rule could never fire again -- shape 3, produced by making the
    # vintages agree when they are supposed to differ.
    $headActive = Get-GitBlobText -Spec ('HEAD:{0}' -f $ActivePath)
    if ($null -eq $headActive) { $headActive = '' }
}

# --- committed ledger (absence is a NOTE, not an error) ---
$ledgerPresent = $false
$ledgerText = ''
if ($offline) {
    if ($PSBoundParameters.ContainsKey('LedgerContent')) { $ledgerPresent = $true; $ledgerText = $LedgerContent }
} else {
    # snapshot: HEAD -- deliberate, and it is a RATIFIED RULE rather than an implementation
    # detail: Decision log 2026-07-26 says "the reservation must be committed before the number
    # is used (the hook reads the ledger from HEAD, not the index)". Moving this to the index
    # would let one commit reserve a block and spend it, which is the entire failure the lane
    # ledger was created after (3 real collisions in a month). Do not "fix" it to match the
    # reads above; it differs on purpose and the purpose is written down.
    $t = Get-GitBlobText -Spec ('HEAD:{0}' -f $LedgerPath)
    if ($null -ne $t) { $ledgerPresent = $true; $ledgerText = $t }
}

# --- ORDER-760 RULE 4's OWN snapshot, and it is deliberately NOT the one above ---
#
# RULE 4 asks "is the lane table READABLE", which is a question about the bytes this commit will
# contain. RULE 2 asks "what was reserved BEFORE this commit", which is a question about HEAD and
# is a ratified rule. Reading both from HEAD made RULE 4 refuse the commit that REPAIRS a
# malformed row -- caught immediately, on the very commit that introduced the rule, because HEAD
# still held the bad row. That is ORDER-731's defect class ("the gate blocks its own repair")
# recreated inside the fix for a different one, which is GUARD_SHAPES shape 5.
#
# So RULE 4 judges the STAGED ledger when the ledger is staged. This weakens nothing: RULE 2 and
# RULE 3 keep reading HEAD exactly as ratified, so one commit still cannot reserve a block and
# spend it. Only the SHAPE question moves, and it moves to the snapshot the question is about.
$ledgerShapeText = $ledgerText
if ($offline) {
    if ($PSBoundParameters.ContainsKey('StagedLedgerContent')) { $ledgerShapeText = $StagedLedgerContent }
} else {
    $ledgerLedgerStaged = $false
    foreach ($p in $stagedPaths) { if ($p -eq $LedgerPath) { $ledgerLedgerStaged = $true } }
    if ($ledgerLedgerStaged) {
        # snapshot: index -- the ledger as this commit will contain it. See the paragraph above.
        $ts = Get-GitBlobText -Spec (':{0}' -f $LedgerPath)
        if ($null -ne $ts) { $ledgerShapeText = $ts }
    }
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
    # --- RULE 4 (ORDER-760): every lane row must have the header's width ---
    #
    # WHY THIS BLOCKS RATHER THAN WARNS, with the number C1 asked for. Measured on the real
    # ledger before writing it: of 56 lane rows, TWO disagreed with the 6-cell header -- and one
    # of those was fixed by the escape-aware split alone, because it had written '\|' correctly
    # and the parser was breaking on it. That leaves exactly ONE row, repaired in the same commit
    # as this rule. So the steady-state cost of blocking is zero rows.
    #
    # And a WARN is precisely what already existed and already failed. On 2026-08-01 a row with a
    # literal pipe made this guard print "NOTE: no ACTIVE lane ... rules skipped" and PASS, so two
    # commits were made with RULE 2 and RULE 3 unarmed. A louder version of the thing that failed
    # is not a fix; the failure mode is a guard switching ITSELF off, and the only answer to that
    # is refusing to run rather than running blind.
    # Judged on the STAGED ledger when one is staged (see the $ledgerShapeText paragraph above),
    # so a commit that REPAIRS a malformed row is allowed to land. Re-parsed rather than reusing
    # $lanes, because $lanes is the HEAD-vintage parse RULE 2 needs and mixing the two vintages in
    # one verdict is the mistake this repo files as A2.
    $shapeLanes = $lanes
    if ($ledgerShapeText -ne $ledgerText) {
        try {
            $shapeLanes = @(Get-LedgerLanes -Text $ledgerShapeText)
        } catch {
            Write-Host ('{0} TOOLING: staged {1}: {2}' -f $Tag, $LedgerPath, $_.Exception.Message)
            exit 2
        }
    }
    # STATED LIMIT, because a reader will hit it before they find this file. When the ledger is
    # NOT staged, the shape is judged at HEAD -- so a malformed row that somehow reached HEAD
    # blocks EVERY commit, including ones with nothing to do with the ledger, until it is fixed.
    # That is deliberate (a guard that switches itself off is the defect this rule exists for) and
    # the only way in is --no-verify: the staged check above refuses a malformed row before it can
    # land. The fix is always one edit to one row, and the message names the row and its line.
    $badShape = @($shapeLanes | Where-Object { $_.CellCount -ne $_.ExpectedCells })
    if ($badShape.Count -gt 0) {
        foreach ($b in $badShape) {
            Write-Host ('{0} BLOCK: lane row {1} (line {2}) has {3} cells, but the table header has {4}. A row of the wrong width reads its STATUS from the wrong column -- which looks exactly like a lane that is not ACTIVE, so the reserved-block and owned-path rules switch themselves off silently. Write a literal pipe as \| (markdown escape); do not leave a bare | in a cell.' -f `
                $Tag, $b.SessionId, $b.LineNumber, $b.CellCount, $b.ExpectedCells)
        }
        Write-Host ('{0} BLOCK: {1} malformed lane row(s) in {2} -- commit refused' -f $Tag, $badShape.Count, $LedgerPath)
        exit 1
    }

    $activeLanes = @($lanes | Where-Object { $_.Status -eq 'ACTIVE' })
    if ($activeLanes.Count -eq 0) {
        # "0 lanes parsed" and "every lane is closed" look identical in the output but mean
        # opposite things: the first is the guard failing to read its own input, the second is
        # the guard correctly having nothing to enforce. Separate them loudly -- a parser that
        # reads nothing while the file plainly says ACTIVE is a broken guard, not a quiet day.
        if ($lanes.Count -eq 0 -and $ledgerText -match 'ACTIVE') {
            Write-Host ('{0} BLOCK: parsed 0 lane rows from {1} but the file contains "ACTIVE" -- the lane table is unreadable, so reserved-block and owned-path rules would be silently skipped. Fix the table (stray prose/HTML between the header separator and the first row truncates it).' -f $Tag, $LedgerPath)
            exit 1
        }
        Write-Host ('{0} NOTE: no ACTIVE lane in {1} ({2} row(s) parsed) -- reserved-block and owned-path rules skipped' -f $Tag, $LedgerPath, $lanes.Count)
    } else {
        $ledgerUsable = $true
    }
}

if ($ledgerUsable) {
    # --- RULE 2 ---
    $ranges = New-Object System.Collections.Generic.List[object]
    foreach ($lane in $activeLanes) { foreach ($r in $lane.Ranges) { $ranges.Add($r) } }

    # Name what could not be read, per ACTIVE lane. An unreadable token is not an absence.
    foreach ($lane in $activeLanes) {
        foreach ($bad in $lane.Malformed) {
            Write-Host ('{0} NOTE: ignored malformed order-block token {1} in lane {2} (high < low; NOT swapped -- inverting it would invent a reservation)' -f $Tag, $bad, $lane.SessionId)
        }
    }

    if ($ranges.Count -eq 0) {
        Write-Host ('{0} NOTE: no ACTIVE lane in {1} declares a parseable order block -- reserved-block rule skipped' -f $Tag, $LedgerPath)
    } else {
        $headIds = @{}
        foreach ($h in (Get-OrderHeaders -Text $headActive)) { $headIds[$h.Id] = $true }

        $rangeText = (($ranges | ForEach-Object { '{0}-{1}' -f $_.Low, $_.High }) -join ', ')
        # STATE WHAT IS ALLOWED, on every run -- not only inside a refusal (Decision log
        # 2026-07-30: "any future guard must be able to state what it ALLOWS"). One printed
        # line would have exposed ORDER-675's swallowed range the first time it appeared,
        # instead of it being found by probing the guard with an id nobody had reserved.
        Write-Host ('{0} enforcing reserved block(s): {1}' -f $Tag, $rangeText)
        foreach ($id in (@($stagedHeaders | ForEach-Object { $_.Id }) | Select-Object -Unique)) {
            if ($headIds.ContainsKey($id)) { continue }          # not new in this commit
            if ($id -notmatch '^\d+$') {
                Write-Host ('{0} NOTE: new non-numeric order id ORDER-{1} is exempt from the reserved-block rule' -f $Tag, $id)
                continue
            }
            $n = [int]$id
            $inside = $false
            foreach ($r in $ranges) { if ($n -ge $r.Low -and $n -le $r.High) { $inside = $true; break } }
            $restoredBy = if ($inside) { '' } else { Test-IsRestoredId -Id $id }
            if (-not $inside -and $restoredBy) {
                # ORDER-1460 (2026-08-06). A header this file ONCE CARRIED and lost is a REPAIR,
                # not a new number, and this rule could not tell the two apart -- it compares the
                # staged headers against HEAD's and calls anything absent from HEAD "new".
                #
                # MEASURED, not hypothesised: `## ORDER-1460`'s header line was consumed by the
                # edit that inserted ORDER-1462, leaving the row's body behind with no header and
                # invisible to every `^## ORDER-<n>` sweep -- including the block-derivation test
                # every lane runs before reserving. The commit restoring it verbatim from
                # 70c00840 was REFUSED here, because 1460 is not in the restoring lane's block
                # and never can be: it belongs to a lane that closed. So the guard blocked the
                # commit that FIXED the state it was complaining about, which is the same
                # FALSE BLOCK shape this file's un-archiving note already describes one case over.
                #
                # It cannot be laundered into a collision: an id this file previously carried is
                # BY DEFINITION already issued, so re-adding it creates no fresh claim on a
                # number. An actual duplicate is still caught -- by the duplicate-id rule above,
                # which is a different rule and is untouched.
                # 🔴 STATE THE NARROWING OUT LOUD. This rule used to refuse every out-of-block id
                # unconditionally, which incidentally also refused RETIRED numbers -- and the
                # ledger's "never re-issue" list (207-209, 223-229, 1340-1349, ...) is exactly a
                # list of ids this file once carried. So a retired number is now reachable
                # without a block, and the honest thing is to print the commit that entitles it
                # rather than to imply the guard verified more than it did. What still holds: an
                # actual duplicate is caught by the duplicate-id rule above, which is untouched.
                Write-Host ('{0} NOTE: ORDER-{1} is a RESTORATION -- {2} carried this header at commit {3} and no longer does at HEAD, so it is not a new number and the reserved-block rule does not apply. If this is a RETIRED id being re-issued rather than a lost header being repaired, that is a different act and this rule cannot tell them apart -- check the ledger.' -f $Tag, $id, $ActivePath, $restoredBy)
                continue
            }
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
