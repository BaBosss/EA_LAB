<#
.SYNOPSIS
    ORDER-101 Contract C0 -- READ-ONLY reconcile + validator for the
    AGENT_TASKBOARD.md / ARCHIVE_TASKBOARD_2026-07A.md split.

.DESCRIPTION
    Proves the manual 2026-07-12 taskboard split lost/duplicated/mutated nothing
    (1a split-integrity, multiset-by-hash against committed states), tracks what
    has legitimately changed since the split under the LIVING APPEND-ONLY LOG model
    (ORDER-103): the archive is a growing immutable log (1b-ARCHIVE append-only --
    current archive must be a superset-by-content of the split-time archive; post-
    split appends are allowed and reported) and the active board is the writable
    queue (1b-ACTIVE conservation -- every split-active ORDER block's canonical id
    must resolve in current-active OR current-archive; non-order removals like the
    manual index are allowed). Scans the current archive for policy/integrity
    exceptions, and emits a manifest + generated index.

    This script NEVER writes to AGENT_TASKBOARD.md or ARCHIVE_TASKBOARD_2026-07A.md.
    It only reads them (working tree + git history) and writes new artifact files
    under docs/memory_control/.

.PARAMETER Generate
    The ONLY mode that WRITES docs/memory_control/ARCHIVE_MANIFEST.csv +
    ARCHIVE_INDEX.md + RECONCILE_EXCEPTIONS.md. Computes the manifest fresh from
    the live archive and overwrites whatever was on disk. Exit code follows the
    same Audit-style rule (0 clean-or-policy-only, 2 integrity/tooling failure) --
    Generate is "regenerate truth", not "enforce cleanliness"; use -Strict
    separately (read-only) to gate on policy debt.

.PARAMETER Audit
    READ-ONLY. Reads the EXISTING on-disk manifest/index/exceptions report (does NOT
    write them) and validates them against the live archive. Report everything. Exit 0
    if clean OR only policy exceptions exist. Exit 2 if any INTEGRITY/tooling failure
    exists -- including a corrupt or stale COMMITTED manifest/index/exceptions report
    (ORDER-101 fix 1: RECONCILE_EXCEPTIONS.md is recomputed in-memory and compared
    byte-for-byte to what's on disk, exactly like the manifest/index), which this mode
    must catch, never silently repair.

.PARAMETER Strict
    READ-ONLY (same as -Audit: never writes the manifest/index/exceptions report). Exit
    0 only if fully clean -- fully clean now means every raw policy exception has been
    CANONICALLY REVIEWED (ORDER-102 Contract C1: closed via a REVIEW-block linkage or a
    C1-CLOSURE block; see the CONTRACT C1 section below), not merely "zero raw
    exceptions". Exit 1 if any UNRESOLVED policy exception remains (raw minus
    canonically-reviewed; no integrity failures). Exit 2 if any INTEGRITY/tooling
    failure exists.

.NOTES (CONTRACT C1 -- CANONICAL REVIEW LINKAGE, ORDER-102)
    A raw policy exception from the exception scan can be closed two ways, both
    READ-ONLY and both reported separately (raw_detected / canonically_reviewed /
    unresolved counts, never silently merged):
      Source A -- REVIEW-BLOCK LINKAGE: any raw exception whose canonical_id is
        covered by a block matching header '^## REVIEW ORDER-<canonicalid>' with a
        REVIEWED/REVIEWED-CLOSED status verb is closed.
      Source B -- C1-CLOSURE BLOCK: a single '## C1-CLOSURE' block (status
        REVIEWED(Opus, ...)) containing a markdown table with columns
        kind | block_id | block_sha256 | disposition | evidence. Each row closes
        the ONE raw exception whose EXACT (kind, block_id) matches AND whose
        block_sha256 equals that exception's CURRENT block hash (the canonical-LF
        sha256 recorded in ARCHIVE_MANIFEST.csv). A sha mismatch = STALE (reported,
        not honored). An unknown or duplicate closure row is an INTEGRITY failure
        (exit 2 under both -Audit and -Strict).

.PARAMETER RepoRoot
    Repo root. Defaults to the parent of this script's directory.

.PARAMETER PreSplitSource / SplitActiveSource / SplitArchiveSource /
           CurrentActiveSource / CurrentArchiveSource
    Source specs, each either "GIT:<ref>:<path>" (read via `git show`) or
    "FILE:<absolute-path>" (read directly from disk). Defaults point at the
    real repo's 4aebbc37 split commit and the real working-tree files. Negative
    tests override these with small synthetic fixture files so the exact same
    parsing/scoring logic is exercised without touching real repo content.

.PARAMETER SkipArtifacts
    Under -Generate only: compute but do NOT write ARCHIVE_MANIFEST.csv /
    ARCHIVE_INDEX.md / RECONCILE_EXCEPTIONS.md (dry-run generate). Has no effect
    under -Audit/-Strict -- those modes never write regardless, by construction
    (ORDER-101 fix 1: a corrupt/stale COMMITTED manifest must be caught, not
    silently overwritten-then-reported-clean).

.PARAMETER ManifestPath / IndexPath / ExceptionsPath
    Override output/input artifact locations (tests point these at
    scripts/_test/fixtures/...). Under -Audit/-Strict these are READ from; under
    -Generate they are WRITTEN to.

.NOTES
    HASH SEMANTICS (ORDER-101 hardening 6): the per-row `sha256` column in
    ARCHIVE_MANIFEST.csv is a CANONICAL-TEXT hash -- computed after normalizing
    CRLF/CR to LF (see Get-NormalizedTextFromBytes) -- NOT a raw-byte hash. A
    CRLF-only edit inside one block does not change that block's sha256. To
    catch file-level EOL/whitespace drift that the per-block hashes cannot see,
    ARCHIVE_INDEX.md's generated header also carries a separate whole-file
    RAW-BYTE SHA256 of ARCHIVE_TASKBOARD_2026-07A.md as committed (CRLF as-is).

    ARCHIVE-CONTENT IDENTITY (ORDER-101 fix 2): each manifest row's
    `archive_blob_sha` is the **git blob SHA of the archive file's content**
    (see Get-ArchiveContentIdentity), NOT the repo's current HEAD commit.
    Content-addressed identity means regenerating after any commit that does
    not touch ARCHIVE_TASKBOARD_2026-07A.md reproduces a byte-identical
    manifest + index -- committing unrelated work no longer rewrites all rows.
#>
[CmdletBinding(DefaultParameterSetName = 'Audit')]
param(
    [Parameter(ParameterSetName = 'Audit')]
    [switch]$Audit,

    [Parameter(ParameterSetName = 'Strict')]
    [switch]$Strict,

    [Parameter(ParameterSetName = 'Generate')]
    [switch]$Generate,

    [string]$RepoRoot = '',

    [string]$PreSplitSource      = 'GIT:4aebbc37^:AGENT_TASKBOARD.md',
    [string]$SplitActiveSource   = 'GIT:4aebbc37:AGENT_TASKBOARD.md',
    [string]$SplitArchiveSource  = 'GIT:4aebbc37:ARCHIVE_TASKBOARD_2026-07A.md',
    [string]$CurrentActiveSource = '',
    [string]$CurrentArchiveSource = '',

    [switch]$SkipArtifacts,
    [string]$ManifestPath = '',
    [string]$IndexPath = '',
    [string]$ExceptionsPath = ''
)

# Resolve RepoRoot robustly (was a param default `Split-Path -Parent $PSScriptRoot`,
# which throws when $PSScriptRoot is empty during param binding under some
# `powershell.exe -File` invocations in Windows PowerShell 5.1). Compute in the
# body from the most reliable source available.
if (-not $RepoRoot) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot }
                 elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
                 else { (Get-Location).Path }
    $RepoRoot = Split-Path -Parent $scriptDir
}

# ============================================================================
# CONSTANTS
# ============================================================================

# Header whose block is a split-generated extra (manual index, not present pre-split).
$script:GeneratedExtraHeaderPatterns = @(
    '^## .{0,4}ARCHIVED ORDERS INDEX'
)

# Annotation headers that are legitimately status-less (do NOT guess a status for these).
# Built via [char]0x2014 (EM DASH) rather than a literal Unicode character in the source so
# this still matches correctly if the .ps1 is ever re-saved without a UTF-8 BOM (Windows
# PowerShell 5.1 reads BOM-less scripts using the system ANSI codepage, not UTF-8, which
# would otherwise mangle a literal em-dash into mojibake before the regex ever runs).
$script:EmDash = [char]0x2014
$script:AnnotationHeaderPatterns = @(
    '^ORDER-\d+[A-Za-z0-9]*-REVIEW note',
    ('^ORDER-\d+(?:/\d+)?\s*[-' + $script:EmDash + ']\s*NOTE')
)
$script:AnnotationDualIdPattern = '^ORDER-(\d+)(?:/(\d+))?\s*[-' + $script:EmDash + ']\s*NOTE'

# Terminal status verbs, longest/most-specific first so composite statuses aren't truncated.
$script:TerminalPatternsOrdered = @(
    'DONE-STOPPED-AT-STAGE-\d+',
    'DONE-PHASE1',
    'REVIEWED/CLOSED',
    'BUILT\+FUNNELED',
    'BUILT\+CLOSED',
    'STAGE2-DONE',
    'REVIEWED',
    'DONE',
    'CLOSED',
    'SKIPPED',
    'BUILT',
    'FUNNELED'
)

# Non-terminal status verbs. Checked BEFORE terminal so a mixed status ("OPEN -> ...") is
# correctly classified non-terminal per spec ("mixed status containing OPEN = non-terminal").
$script:NonTerminalPatternsOrdered = @(
    'WAITING-USER',
    'WAITING',
    'CLAIMED',
    'IN-PROGRESS',
    'HOLD',
    'OPEN'
)

# Pending/partial-stage markers (ORDER-101 fix 4). A block whose backtick status verb
# is terminal (e.g. `STAGE2-DONE(...)`) can still carry a pending-stage marker OUTSIDE
# the backtick span (e.g. ORDER-071: "`STAGE2-DONE(...)` -- Stage 3 = รอ main session
# ตัดสินตามเกณฑ์..."). Matching is done against the header with all backtick spans
# stripped out first (see Get-HeaderTextOutsideBackticks) -- this deliberately does NOT
# fire on a pending phrase that lives INSIDE the backticks (e.g. ORDER-081's
# "`DONE(... -- รอ Claude/user ตัดสิน go/no-go)`" is a self-contained, already-terminal
# DONE with descriptive commentary, not a genuine split/pending stage).
# Thai literals built from [char] code points rather than literal source characters --
# same reason as $script:EmDash above: Windows PowerShell 5.1 reads a BOM-less .ps1 using
# the system ANSI codepage, not UTF-8, which would silently mangle a literal Thai string
# in the source into the wrong regex (matching nothing) even though the fixture/repo
# content being scanned is correctly-decoded UTF-8 in memory.
$script:ThaiRor = -join (@(0x0E23, 0x0E2D) | ForEach-Object { [char]$_ })            # "รอ"
$script:ThaiTudsin = -join (@(0x0E15, 0x0E31, 0x0E14, 0x0E2A, 0x0E34, 0x0E19) | ForEach-Object { [char]$_ })  # "ตัดสิน"
$script:PendingStageMarkerPatterns = @(
    ('Stage\s*\d+\s*=\s*' + $script:ThaiRor + '[^\r\n]*'),                # "Stage <n> = รอ..."
    ($script:ThaiRor + '[^\r\n]*?' + $script:ThaiTudsin),                 # "รอ ... ตัดสิน"
    ($script:ThaiRor + $script:ThaiTudsin),                               # "รอตัดสิน"
    '(?i)\bpending\b'
)

New-Variable -Name EXIT_OK -Value 0 -Option Constant -Scope Script -Force
New-Variable -Name EXIT_POLICY -Value 1 -Option Constant -Scope Script -Force
New-Variable -Name EXIT_INTEGRITY -Value 2 -Option Constant -Scope Script -Force

# ============================================================================
# LOW-LEVEL IO HELPERS
# ============================================================================

function Get-Sha256Hex {
    param([byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($Bytes)
        return -join ($hash | ForEach-Object { $_.ToString('x2') })
    } finally {
        $sha.Dispose()
    }
}

function Get-NormalizedTextFromBytes {
    param([byte[]]$Bytes)
    $text = [System.Text.Encoding]::UTF8.GetString($Bytes)
    # Normalize CRLF/CR -> LF so working-tree (CRLF, core.autocrlf=true) and git-blob
    # (LF, as stored) content hash identically when byte-content is otherwise the same.
    $text = $text.Replace("`r`n", "`n")
    $text = $text.Replace("`r", "`n")
    return $text
}

function Get-GitBlobBytes {
    param([string]$RepoRoot, [string]$Ref, [string]$Path)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = 'show "{0}:{1}"' -f $Ref, $Path
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
    if ($proc.ExitCode -ne 0) {
        throw ('git show {0}:{1} failed (exit {2}): {3}' -f $Ref, $Path, $proc.ExitCode, $stderrText)
    }
    return $ms.ToArray()
}

function Get-SourceBytes {
    param([string]$RepoRoot, [string]$SourceSpec)
    if ($SourceSpec -match '^GIT:(.+?):(.+)$') {
        return Get-GitBlobBytes -RepoRoot $RepoRoot -Ref $Matches[1] -Path $Matches[2]
    } elseif ($SourceSpec -match '^FILE:(.+)$') {
        return [System.IO.File]::ReadAllBytes($Matches[1])
    } else {
        throw "Unrecognized source spec (expected GIT:ref:path or FILE:path): $SourceSpec"
    }
}

function Get-ArchiveContentIdentity {
    <#
        ORDER-101 fix 2: a stable ARCHIVE-CONTENT identity, not repo HEAD.

        Returns the git blob SHA of the archive file's content at the given source.
        This is content-addressed: git only mints a new blob SHA when the file's
        BYTES change, so as long as ARCHIVE_TASKBOARD_2026-07A.md is untouched,
        this value is identical no matter which later commit HEAD happens to be
        at when the generator runs. That is what makes "regenerate after an
        unrelated commit -> byte-identical manifest+index" hold.

        - SourceSpec "GIT:<ref>:<path>"  -> resolved directly as `git rev-parse <ref>:<path>`.
        - SourceSpec "FILE:<abs-path>"   -> path is made repo-relative and resolved
          as `git rev-parse HEAD:<rel-path>` (the working-tree file must be committed;
          this is the normal real-repo case where CurrentArchiveSource defaults to
          FILE:<RepoRoot>/ARCHIVE_TASKBOARD_2026-07A.md).
    #>
    param([string]$RepoRoot, [string]$SourceSpec)

    if ($SourceSpec -match '^GIT:(.+?):(.+)$') {
        $ref = $Matches[1]
        $relPath = $Matches[2]
    } elseif ($SourceSpec -match '^FILE:(.+)$') {
        $absPath = $Matches[1]
        $normRoot = ($RepoRoot -replace '\\', '/').TrimEnd('/')
        $normAbs  = ($absPath  -replace '\\', '/')
        $prefix = $normRoot + '/'
        if ($normAbs.Length -gt $prefix.Length -and $normAbs.Substring(0, $prefix.Length) -eq $prefix) {
            $relPath = $normAbs.Substring($prefix.Length)
        } else {
            throw "Get-ArchiveContentIdentity: FILE path is not under RepoRoot, cannot derive a repo-relative path for a stable archive-content identity: $absPath (RepoRoot=$RepoRoot)"
        }
        $ref = 'HEAD'
    } else {
        throw "Get-ArchiveContentIdentity: unrecognized source spec (expected GIT:ref:path or FILE:path): $SourceSpec"
    }

    $spec = '{0}:{1}' -f $ref, $relPath
    $out = & git -C $RepoRoot rev-parse $spec 2>$null
    if (-not $out) {
        throw "Get-ArchiveContentIdentity: 'git rev-parse $spec' failed -- is the archive file committed at that ref/path?"
    }
    return ([string]$out).Trim()
}

# ============================================================================
# BLOCK MODEL
# ============================================================================

function Get-Blocks {
    <#
        A "block" = one top-level "## " section: the header line through the line
        before the next "## " header or EOF. Parsed from already-LF-normalized text.
    #>
    param([string]$Text, [string]$SourceTag)

    $blocks = New-Object System.Collections.Generic.List[object]
    $headerMatches = [regex]::Matches($Text, '(?m)^## .*$')
    if ($headerMatches.Count -eq 0) { return $blocks }

    for ($i = 0; $i -lt $headerMatches.Count; $i++) {
        $start = $headerMatches[$i].Index
        if ($i + 1 -lt $headerMatches.Count) { $end = $headerMatches[$i + 1].Index } else { $end = $Text.Length }
        $content = $Text.Substring($start, $end - $start)
        $header = $headerMatches[$i].Value
        $sha = Get-Sha256Hex -Bytes ([System.Text.Encoding]::UTF8.GetBytes($content))

        $blocks.Add([pscustomobject]@{
            Ordinal   = $i + 1   # 1-based H2 ordinal within this file/source
            Header    = $header
            Content   = $content
            Sha256    = $sha
            SourceTag = $SourceTag
        })
    }
    return $blocks
}

function Get-CanonicalIdsGeneric {
    <#
        Extract every ORDER-<id> reference anywhere in a header string.
        <id> = digits, optionally one trailing uppercase letter directly appended
        (e.g. 008B), optionally followed by a hyphen-suffix group of the form
        "-<Letter><digits><lowercase-letter>?" or "-<Letter>" (e.g. -D1c, -A).
        Deliberately does NOT swallow English-word suffixes like "-REVIEW" or
        "-AMENDMENT" -- those never match the hyphen-suffix grammar below.
    #>
    param([string]$HeaderBody)
    $pattern = 'ORDER-(\d+[A-Z]?(?:-[A-Za-z]\d*[a-z]?)?)'
    $ms = [regex]::Matches($HeaderBody, $pattern)
    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($m in $ms) { $ids.Add($m.Groups[1].Value) }
    return $ids
}

function Get-BlockType {
    param([string]$HeaderBody)
    foreach ($pat in $script:AnnotationHeaderPatterns) {
        if ($HeaderBody -match $pat) { return 'ANNOTATION' }
    }
    if ($HeaderBody -match '^ORDER-') { return 'ORDER' }
    if ($HeaderBody -match '^REVIEW\b') { return 'REVIEW-NOTE' }
    if ($HeaderBody -match '(?i)\bMERGE\b') { return 'MERGE-REF' }
    return 'OTHER'
}

function Get-StatusClass {
    <#
        Returns @{ Class = Terminal|NonTerminal|NA|Unparseable ; Label = matched text or $null }
        Search order: prefer text inside backtick spans (the documented status
        convention); if a header has NO backticks at all, fall back to a bare
        vocabulary-word search across the whole header (handles the one real
        corpus case -- ORDER-091C-D1e -- that wrote DONE(...) without backticks).
        Non-terminal patterns are checked before terminal ones so a mixed status
        ("OPEN -> ...") is correctly classified non-terminal.
    #>
    param([string]$Header, [string]$BlockType)

    if ($BlockType -eq 'ANNOTATION') {
        return [pscustomobject]@{ Class = 'NA'; Label = '(annotation header -- no status expected)' }
    }

    $backtickMatches = [regex]::Matches($Header, '`([^`]+)`')
    $searchSpaces = New-Object System.Collections.Generic.List[string]
    if ($backtickMatches.Count -gt 0) {
        foreach ($m in $backtickMatches) { $searchSpaces.Add($m.Groups[1].Value) }
    } else {
        $searchSpaces.Add($Header)
    }

    foreach ($s in $searchSpaces) {
        foreach ($pat in $script:NonTerminalPatternsOrdered) {
            if ($s -match $pat) { return [pscustomobject]@{ Class = 'NonTerminal'; Label = $Matches[0] } }
        }
    }
    foreach ($s in $searchSpaces) {
        foreach ($pat in $script:TerminalPatternsOrdered) {
            if ($s -match $pat) { return [pscustomobject]@{ Class = 'Terminal'; Label = $Matches[0] } }
        }
    }

    if ($BlockType -eq 'OTHER') {
        return [pscustomobject]@{ Class = 'NA'; Label = '(no recognized status token -- OTHER block, not required)' }
    }
    return [pscustomobject]@{ Class = 'Unparseable'; Label = $null }
}

function Get-HeaderTextOutsideBackticks {
    <# Strips all `...` spans out of a header, leaving only the text outside them. #>
    param([string]$Header)
    return [regex]::Replace($Header, '`[^`]*`', ' ')
}

function Test-HasPendingStageMarker {
    <#
        ORDER-101 fix 4: detects a mixed/partial-stage header -- a pending-stage
        marker (e.g. "Stage 3 = รอ...", "รอ...ตัดสิน", "pending") appearing OUTSIDE
        the backtick status span. Returns the matched text, or $null if none found.
        Deliberately searches only the non-backtick remainder of the header so a
        pending phrase embedded INSIDE an already-terminal backtick verb (e.g.
        "`DONE(... -- รอ user ตัดสิน go/no-go)`") does not false-positive.
    #>
    param([string]$Header)
    $remainder = Get-HeaderTextOutsideBackticks -Header $Header
    foreach ($pat in $script:PendingStageMarkerPatterns) {
        if ($remainder -match $pat) { return $Matches[0].Trim() }
    }
    return $null
}

function Add-Classification {
    param([Parameter(ValueFromPipeline = $true)]$Block)
    process {
        $headerBody = $Block.Header.Substring(3)  # strip "## "
        $blockType = Get-BlockType -HeaderBody $headerBody

        $canonicalIds = New-Object System.Collections.Generic.List[string]
        if ($blockType -eq 'ANNOTATION') {
            if ($headerBody -match '^ORDER-(\d+)-REVIEW note') {
                $canonicalIds.Add($Matches[1])
            } elseif ($headerBody -match $script:AnnotationDualIdPattern) {
                $canonicalIds.Add($Matches[1])
                if ($Matches[2]) { $canonicalIds.Add($Matches[2]) }
            }
        } elseif ($blockType -eq 'ORDER') {
            $allIds = @(Get-CanonicalIdsGeneric -HeaderBody $headerBody)
            if ($allIds.Count -gt 0) { $canonicalIds.Add($allIds[0]) }  # own id = first found
        } elseif ($blockType -eq 'REVIEW-NOTE') {
            foreach ($id in @(Get-CanonicalIdsGeneric -HeaderBody $headerBody)) { $canonicalIds.Add($id) }
        }

        $statusInfo = Get-StatusClass -Header $Block.Header -BlockType $blockType

        $ownIdForBlockId = 'NA'
        if ($canonicalIds.Count -gt 0) { $ownIdForBlockId = $canonicalIds[0] }
        $blockId = '{0}|{1}|{2}#{3}' -f $ownIdForBlockId, $blockType, $Block.SourceTag, $Block.Ordinal

        $Block | Add-Member -NotePropertyName BlockType    -NotePropertyValue $blockType -Force
        $Block | Add-Member -NotePropertyName CanonicalIds -NotePropertyValue @($canonicalIds) -Force
        $Block | Add-Member -NotePropertyName StatusClass  -NotePropertyValue $statusInfo.Class -Force
        $Block | Add-Member -NotePropertyName StatusLabel  -NotePropertyValue $statusInfo.Label -Force
        $Block | Add-Member -NotePropertyName BlockId      -NotePropertyValue $blockId -Force
        $Block
    }
}

function Get-ClassifiedBlocks {
    param([string]$Text, [string]$SourceTag)
    return @((Get-Blocks -Text $Text -SourceTag $SourceTag) | Add-Classification)
}

# ============================================================================
# 1a -- SPLIT-INTEGRITY (multiset-by-hash)
# ============================================================================

function Test-IsGeneratedExtra {
    param($Block)
    foreach ($pat in $script:GeneratedExtraHeaderPatterns) {
        if ($Block.Header -match $pat) { return $true }
    }
    return $false
}

function Get-HashMultiset {
    param($Blocks)
    $dict = @{}
    foreach ($b in $Blocks) {
        if ($dict.ContainsKey($b.Sha256)) { $dict[$b.Sha256].Add($b) } else {
            $list = New-Object System.Collections.Generic.List[object]
            $list.Add($b)
            $dict[$b.Sha256] = $list
        }
    }
    return $dict
}

function Invoke-SplitIntegrityCheck {
    param($PreBlocks, $ActiveSplitBlocks, $ArchiveSplitBlocks)

    $unionAll = New-Object System.Collections.Generic.List[object]
    foreach ($b in $ActiveSplitBlocks) { $unionAll.Add($b) }
    foreach ($b in $ArchiveSplitBlocks) { $unionAll.Add($b) }

    $generatedExtras = New-Object System.Collections.Generic.List[object]
    $unionMatchable = New-Object System.Collections.Generic.List[object]
    foreach ($b in $unionAll) {
        if (Test-IsGeneratedExtra $b) { $generatedExtras.Add($b) } else { $unionMatchable.Add($b) }
    }

    $preMultiset = Get-HashMultiset -Blocks $PreBlocks
    $unionMultiset = Get-HashMultiset -Blocks $unionMatchable

    $missing = New-Object System.Collections.Generic.List[object]
    $duplicated = New-Object System.Collections.Generic.List[object]

    $allHashesSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in $preMultiset.Keys) { [void]$allHashesSet.Add($k) }
    foreach ($k in $unionMultiset.Keys) { [void]$allHashesSet.Add($k) }

    foreach ($h in $allHashesSet) {
        $preCount = 0; if ($preMultiset.ContainsKey($h)) { $preCount = $preMultiset[$h].Count }
        $unionCount = 0; if ($unionMultiset.ContainsKey($h)) { $unionCount = $unionMultiset[$h].Count }
        if ($unionCount -lt $preCount) {
            $deficit = $preCount - $unionCount
            for ($i = 0; $i -lt $deficit; $i++) { $missing.Add($preMultiset[$h][$i]) }
        } elseif ($unionCount -gt $preCount) {
            $excess = $unionCount - $preCount
            for ($i = 0; $i -lt $excess; $i++) { $duplicated.Add($unionMultiset[$h][$i]) }
        }
    }

    # Secondary pass: pair leftover "missing" / "duplicated" entries by exact header
    # text to distinguish a true content MUTATION (same header, different hash) from
    # a pure delete+insert. Consumes matched pairs out of missing/duplicated.
    $missingByHeader = @{}
    foreach ($m in $missing) {
        if (-not $missingByHeader.ContainsKey($m.Header)) { $missingByHeader[$m.Header] = New-Object System.Collections.Generic.List[object] }
        $missingByHeader[$m.Header].Add($m)
    }
    $mutated = New-Object System.Collections.Generic.List[object]
    $remainingDuplicated = New-Object System.Collections.Generic.List[object]
    foreach ($d in $duplicated) {
        if ($missingByHeader.ContainsKey($d.Header) -and $missingByHeader[$d.Header].Count -gt 0) {
            $pair = $missingByHeader[$d.Header][0]
            $missingByHeader[$d.Header].RemoveAt(0)
            $mutated.Add([pscustomobject]@{ Before = $pair; After = $d })
        } else {
            $remainingDuplicated.Add($d)
        }
    }
    $remainingMissing = New-Object System.Collections.Generic.List[object]
    foreach ($k in $missingByHeader.Keys) { foreach ($item in $missingByHeader[$k]) { $remainingMissing.Add($item) } }

    return [pscustomobject]@{
        Missing              = $remainingMissing
        Mutated              = $mutated
        Duplicated           = $remainingDuplicated
        GeneratedExtras      = $generatedExtras
        PreCount             = $PreBlocks.Count
        UnionCount           = $unionAll.Count
        UnionMatchableCount  = $unionMatchable.Count
    }
}

# ============================================================================
# 1b -- POST-SPLIT DRIFT
# ============================================================================

function Group-BlocksByIdType {
    param($Blocks)
    $g = @{}
    foreach ($b in $Blocks) {
        if ($b.CanonicalIds.Count -gt 0) { $key = '{0}|{1}' -f $b.CanonicalIds[0], $b.BlockType }
        else { $key = 'NA|{0}|{1}' -f $b.BlockType, $b.Sha256 }
        if (-not $g.ContainsKey($key)) { $g[$key] = New-Object System.Collections.Generic.List[object] }
        $g[$key].Add($b)
    }
    return $g
}

function Invoke-ActiveConservationCheck {
    <#
        ORDER-103 living-log evolution (1b-ACTIVE -- CONSERVATION, replaces the old
        frozen-snapshot "no removals allowed" drift check).

        The active board is the writable queue: orders are added, statuses change, and
        an order block may legitimately be REMOVED from active (moved into the archive,
        e.g. a C1 migration). The invariant that matters is not "nothing left the file"
        but "no ORDER was silently lost": every split-active block whose BlockType is
        'ORDER' must have its canonical_id resolvable in CURRENT active OR CURRENT
        archive. A split-active NON-order block (manual index, annotation) may vanish
        from active with no failure -- it was never a conserved unit.

        Returns:
          Additions        - blocks in current-active not present at split (report only)
          Mutations        - (Before,After) pairs for same (canonical id, type) whose
                              hash changed -- status edits etc. (report only, always allowed)
          RemovedNonOrder  - split-active blocks of BlockType != 'ORDER' absent from
                              current-active (allowed removal, report only)
          OrderLost        - split-active ORDER blocks whose canonical_id resolves to
                              NEITHER current-active NOR current-archive (INTEGRITY failure)
    #>
    param($SplitActiveBlocks, $CurrentActiveBlocks, $CurrentArchiveBlocks)

    # Group by (CanonicalId, BlockType) in file order to line up "the Nth ORDER-x
    # block" in the split snapshot with "the Nth ORDER-x block" now, even when a
    # canonical id has multiple blocks (e.g. ORDER-082 main + ORDER-082 AMENDMENT).
    $oldGroups = Group-BlocksByIdType -Blocks $SplitActiveBlocks
    $newGroups = Group-BlocksByIdType -Blocks $CurrentActiveBlocks

    $additions = New-Object System.Collections.Generic.List[object]
    $mutations = New-Object System.Collections.Generic.List[object]
    $removedNonOrder = New-Object System.Collections.Generic.List[object]

    $allKeys = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in $oldGroups.Keys) { [void]$allKeys.Add($k) }
    foreach ($k in $newGroups.Keys) { [void]$allKeys.Add($k) }

    foreach ($key in $allKeys) {
        $oldList = New-Object System.Collections.Generic.List[object]
        if ($oldGroups.ContainsKey($key)) { $oldList = $oldGroups[$key] }
        $newList = New-Object System.Collections.Generic.List[object]
        if ($newGroups.ContainsKey($key)) { $newList = $newGroups[$key] }

        $max = [Math]::Max($oldList.Count, $newList.Count)
        for ($i = 0; $i -lt $max; $i++) {
            $old = $null; if ($i -lt $oldList.Count) { $old = $oldList[$i] }
            $new = $null; if ($i -lt $newList.Count) { $new = $newList[$i] }
            if ($null -eq $old -and $null -ne $new) {
                $additions.Add($new)
            } elseif ($null -ne $old -and $null -eq $new) {
                # ORDER removals are NOT reported/gated here -- they are exactly what the
                # conservation check below classifies (conserved-elsewhere vs lost).
                # Only non-order removals (manual index, annotations) are unconditionally
                # allowed and reported here for transparency.
                if ($old.BlockType -ne 'ORDER') { $removedNonOrder.Add($old) }
            } elseif ($old.Sha256 -ne $new.Sha256) {
                $mutations.Add([pscustomobject]@{ Before = $old; After = $new })
            }
        }
    }

    # CONSERVATION: every split-active ORDER block's own canonical id must resolve to
    # an ORDER block (its own id) somewhere in the CURRENT corpus -- active or archive.
    $currentActiveOrderIds = New-Object System.Collections.Generic.HashSet[string]
    foreach ($b in $CurrentActiveBlocks) {
        if ($b.BlockType -eq 'ORDER' -and $b.CanonicalIds.Count -gt 0) { [void]$currentActiveOrderIds.Add($b.CanonicalIds[0]) }
    }
    $currentArchiveOrderIds = New-Object System.Collections.Generic.HashSet[string]
    foreach ($b in $CurrentArchiveBlocks) {
        if ($b.BlockType -eq 'ORDER' -and $b.CanonicalIds.Count -gt 0) { [void]$currentArchiveOrderIds.Add($b.CanonicalIds[0]) }
    }

    $orderLost = New-Object System.Collections.Generic.List[object]
    foreach ($b in $SplitActiveBlocks) {
        if ($b.BlockType -ne 'ORDER') { continue }
        if ($b.CanonicalIds.Count -eq 0) { continue }   # can't identify -- nothing to conserve against
        $id = $b.CanonicalIds[0]
        if (-not $currentActiveOrderIds.Contains($id) -and -not $currentArchiveOrderIds.Contains($id)) {
            $orderLost.Add($b)
        }
    }

    return [pscustomobject]@{
        Additions       = $additions
        Mutations       = $mutations
        RemovedNonOrder = $removedNonOrder
        OrderLost       = $orderLost
    }
}

function Invoke-ArchiveAppendOnlyCheck {
    <#
        ORDER-103 living-log evolution (1b-ARCHIVE -- APPEND-ONLY LOG, replaces the old
        frozen-snapshot "exact multiset equality" drift check).

        The archive is a growing immutable LOG, not a frozen snapshot: current archive
        must be a SUPERSET of the split-time archive by block content (canonical-LF
        sha256) -- every split-archive block must still be present, byte-unmutated, in
        the current archive. Extra current-archive blocks (post-split appends, e.g. a
        superseded order moved in from active, or a closure block) are ALLOWED and
        reported, never a failure. Failure fires ONLY when a split-archive block is
        missing or mutated.

        Uses the same missing/duplicated(extra)-then-pair-by-header technique as
        Invoke-SplitIntegrityCheck to additionally classify pure delete-vs-mutation
        where the header text is unchanged (informational only -- either classification
        triggers the same failure, so this never changes exit-code behavior).
    #>
    param($SplitArchiveBlocks, $CurrentArchiveBlocks)

    $splitMultiset = Get-HashMultiset -Blocks $SplitArchiveBlocks
    $currentMultiset = Get-HashMultiset -Blocks $CurrentArchiveBlocks

    $missingRaw = New-Object System.Collections.Generic.List[object]
    $extraRaw = New-Object System.Collections.Generic.List[object]

    $allHashesSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in $splitMultiset.Keys) { [void]$allHashesSet.Add($k) }
    foreach ($k in $currentMultiset.Keys) { [void]$allHashesSet.Add($k) }

    foreach ($h in $allHashesSet) {
        $sc = 0; if ($splitMultiset.ContainsKey($h)) { $sc = $splitMultiset[$h].Count }
        $cc = 0; if ($currentMultiset.ContainsKey($h)) { $cc = $currentMultiset[$h].Count }
        if ($cc -lt $sc) {
            $deficit = $sc - $cc
            for ($i = 0; $i -lt $deficit; $i++) { $missingRaw.Add($splitMultiset[$h][$i]) }
        } elseif ($cc -gt $sc) {
            $excess = $cc - $sc
            for ($i = $sc; $i -lt $cc; $i++) { $extraRaw.Add($currentMultiset[$h][$i]) }
        }
    }

    # Secondary pass: pair a leftover "missing" entry with a leftover "extra" entry that
    # shares the exact same header text -- that pairing is a true content MUTATION
    # (same header, different hash) rather than a pure delete or a pure append.
    # Informational only: whether a given failure surfaces as Missing or as (the Before
    # side of) Mutated, it is still counted as a split-archive block that did not survive
    # unmutated, and both drive the identical archive-not-append-only failure below.
    $missingByHeader = @{}
    foreach ($m in $missingRaw) {
        if (-not $missingByHeader.ContainsKey($m.Header)) { $missingByHeader[$m.Header] = New-Object System.Collections.Generic.List[object] }
        $missingByHeader[$m.Header].Add($m)
    }
    $mutated = New-Object System.Collections.Generic.List[object]
    $postSplitAppends = New-Object System.Collections.Generic.List[object]
    foreach ($e in $extraRaw) {
        if ($missingByHeader.ContainsKey($e.Header) -and $missingByHeader[$e.Header].Count -gt 0) {
            $pair = $missingByHeader[$e.Header][0]
            $missingByHeader[$e.Header].RemoveAt(0)
            $mutated.Add([pscustomobject]@{ Before = $pair; After = $e })
        } else {
            $postSplitAppends.Add($e)
        }
    }
    $missing = New-Object System.Collections.Generic.List[object]
    foreach ($k in $missingByHeader.Keys) { foreach ($item in $missingByHeader[$k]) { $missing.Add($item) } }

    return [pscustomobject]@{
        Missing           = $missing
        Mutated           = $mutated
        PostSplitAppends  = $postSplitAppends
        IsAppendOnlyClean = (($missing.Count -eq 0) -and ($mutated.Count -eq 0))
    }
}

# ============================================================================
# EXCEPTION SCAN (current archive)
# ============================================================================

function Invoke-ExceptionScan {
    param($CurrentActiveBlocks, $CurrentArchiveBlocks)

    $policyExceptions = New-Object System.Collections.Generic.List[object]
    $integrityFailures = New-Object System.Collections.Generic.List[object]

    # (a) non-terminal in archive / status-unparseable in archive
    foreach ($b in $CurrentArchiveBlocks) {
        if ($b.StatusClass -eq 'NonTerminal') {
            $cid = ''; if ($b.CanonicalIds.Count -gt 0) { $cid = $b.CanonicalIds[0] }
            $policyExceptions.Add([pscustomobject]@{
                Kind = 'non-terminal-in-archive'; Severity = 'policy'
                BlockId = $b.BlockId; Header = $b.Header; Detail = "status='$($b.StatusLabel)'"
                CanonicalId = $cid; Sha256 = $b.Sha256
            })
        }
        if ($b.StatusClass -eq 'Unparseable') {
            $integrityFailures.Add([pscustomobject]@{
                Kind = 'status-unparseable'; Severity = 'integrity'
                BlockId = $b.BlockId; Header = $b.Header
                Detail = 'no backtick or bare vocabulary status token found, and not a whitelisted annotation header'
            })
        }
    }

    # (b) terminal ORDER block in archive with no linked REVIEW anywhere in archive
    # (canonical-id-level linking -- see final report deviations note for why).
    # Self-attesting terminal verbs (REVIEWED / REVIEWED/CLOSED) already ARE the review --
    # reviewer + date are embedded in the verb itself -- so they never need a separate
    # "## REVIEW ORDER-x" block pointing at them. Only execution-only terminal verbs
    # (DONE / DONE-PHASE1 / DONE-STOPPED-AT-STAGE-n / bare CLOSED / SKIPPED / BUILT* /
    # FUNNELED / STAGE2-DONE) require a companion review block, matching the real archive's
    # two eras: pre-068 orders self-reviewed inline; 068+ split "DONE(agent)" execution from
    # a separate "## REVIEW ORDER-x" judging pass.
    $reviewedIds = New-Object System.Collections.Generic.HashSet[string]
    foreach ($b in $CurrentArchiveBlocks) {
        if ($b.BlockType -eq 'REVIEW-NOTE') {
            foreach ($id in $b.CanonicalIds) { [void]$reviewedIds.Add($id) }
        }
    }
    foreach ($b in $CurrentArchiveBlocks) {
        if ($b.BlockType -eq 'ORDER' -and $b.StatusClass -eq 'Terminal' -and $b.StatusLabel -notlike 'REVIEWED*') {
            $ownId = $null
            if ($b.CanonicalIds.Count -gt 0) { $ownId = $b.CanonicalIds[0] }
            if ($ownId -and -not $reviewedIds.Contains($ownId)) {
                $policyExceptions.Add([pscustomobject]@{
                    Kind = 'terminal-no-linked-review'; Severity = 'policy'
                    BlockId = $b.BlockId; Header = $b.Header
                    Detail = "canonical_id=$ownId terminal ($($b.StatusLabel)) but no REVIEW block in archive references it"
                    CanonicalId = $ownId; Sha256 = $b.Sha256
                })
            }
        }
    }

    # (a2) mixed/partial-stage archived block: header carries a pending-stage marker
    # OUTSIDE the backtick status span (e.g. ORDER-071's `STAGE2-DONE(...)` followed by
    # "-- Stage 3 = รอ main session ตัดสิน..."). The backtick verb alone is terminal, so
    # the (a) StatusClass check above never flags it -- flag it here explicitly, IN
    # ADDITION to whatever else this block already triggered (including possibly
    # nothing else at all).
    foreach ($b in $CurrentArchiveBlocks) {
        $pendingLabel = Test-HasPendingStageMarker -Header $b.Header
        if ($pendingLabel) {
            $cid = ''; if ($b.CanonicalIds.Count -gt 0) { $cid = $b.CanonicalIds[0] }
            $policyExceptions.Add([pscustomobject]@{
                Kind = 'non-terminal-in-archive'; Severity = 'policy'
                BlockId = $b.BlockId; Header = $b.Header
                Detail = "mixed/partial status: header carries pending-stage marker '$pendingLabel' OUTSIDE the backtick status token (backtick status='$($b.StatusLabel)') -- treated as non-terminal-in-archive despite the terminal verb"
                CanonicalId = $cid; Sha256 = $b.Sha256
            })
        }
    }

    # (c) canonical_id present in both current active AND current archive (ORDER blocks only)
    $activeIds = New-Object System.Collections.Generic.HashSet[string]
    $activeHeaderById = @{}
    foreach ($b in $CurrentActiveBlocks) {
        if ($b.BlockType -eq 'ORDER' -and $b.CanonicalIds.Count -gt 0) {
            [void]$activeIds.Add($b.CanonicalIds[0])
            if (-not $activeHeaderById.ContainsKey($b.CanonicalIds[0])) { $activeHeaderById[$b.CanonicalIds[0]] = $b.Header }
        }
    }
    $seenCross = New-Object System.Collections.Generic.HashSet[string]
    foreach ($b in $CurrentArchiveBlocks) {
        if ($b.BlockType -eq 'ORDER' -and $b.CanonicalIds.Count -gt 0) {
            $id = $b.CanonicalIds[0]
            if ($activeIds.Contains($id) -and -not $seenCross.Contains($id)) {
                [void]$seenCross.Add($id)
                $policyExceptions.Add([pscustomobject]@{
                    Kind = 'cross-active-and-archive'; Severity = 'policy'
                    BlockId = $b.BlockId; Header = $b.Header
                    Detail = "canonical_id=$id also present in current active board: '$($activeHeaderById[$id])' -- needs Opus to classify (annotation / obsolete-phase / active-continuation)"
                    CanonicalId = $id; Sha256 = $b.Sha256
                })
            }
        }
    }

    return [pscustomobject]@{ Policy = $policyExceptions.ToArray(); Integrity = $integrityFailures.ToArray() }
}

# ============================================================================
# CONTRACT C1 -- CANONICAL REVIEW LINKAGE (closure sources A + B)
# ============================================================================
#
# ORDER-102 Contract C1 upgrade: policy exceptions raised by Invoke-ExceptionScan
# above are "raw" -- unchanged from C0. This section is a READ-ONLY post-processing
# layer that closes a subset of those raw exceptions via two canonical sources,
# reported separately (never silently folded back into "raw"):
#
#   Source A -- REVIEW-BLOCK LINKAGE: a block whose header (after "## ") matches
#   '^REVIEW ORDER-<canonicalid>' AND whose backtick status verb is terminal with
#   label REVIEWED or REVIEWED/CLOSED is a canonical review of every ORDER-<id>
#   referenced anywhere in that same header. ANY raw policy exception (of any of
#   the 3 kinds Invoke-ExceptionScan can produce) whose CanonicalId is covered by
#   such a block is CLOSED. This is deliberately broader than the pre-existing
#   ad-hoc $reviewedIds check inside the terminal-no-linked-review branch above
#   (which only ever suppressed that ONE kind, silently, before the exception was
#   even counted as "raw") -- Source A additionally closes non-terminal-in-archive
#   and cross-active-and-archive exceptions for the same canonical id, and reports
#   the closure explicitly instead of hiding it. The two mechanisms overlap for
#   terminal-no-linked-review by design (both keyed on canonical id); left as-is
#   rather than deleted so raw_detected keeps its current, already-measured value.
#
#   Source B -- C1-CLOSURE BLOCK: a single canonical block, header starting
#   '## C1-CLOSURE', status REVIEWED(Opus, ...), containing a markdown table with
#   columns kind | block_id | block_sha256 | disposition | evidence. Each row
#   closes the ONE raw exception whose (Kind, BlockId) matches the row AND whose
#   CURRENT Sha256 equals the row's block_sha256 (keyed on kind+block_id, NOT
#   canonical id -- a closure for one kind of a block must not silently close a
#   DIFFERENT kind of the same block_id). A block_sha256 mismatch = STALE: the
#   exception stays unresolved and the staleness is reported, never silently
#   honored. An unknown or duplicate closure row is an INTEGRITY failure.
#
# Both sources are evaluated against blocks already read from the canonical
# corpus (current-active + current-archive) -- no new IO.

function Get-CanonicalReviewIds {
    <#
        Source A eligibility scan. Returns a HashSet[string] of every canonical id
        covered by a qualifying REVIEW block found anywhere in $Blocks (both active
        and archive corpora are expected to be passed in -- see the C1-CLOSURE spec
        note "found in the canonical corpus (active taskboard or archive)").
    #>
    param($Blocks)
    $ids = New-Object System.Collections.Generic.HashSet[string]
    foreach ($b in $Blocks) {
        if ($b.BlockType -ne 'REVIEW-NOTE') { continue }
        $headerBody = $b.Header.Substring(3)
        if ($headerBody -notmatch '^REVIEW ORDER-\d') { continue }   # must be "REVIEW ORDER-<canonicalid>", not any bare "REVIEW ..." note
        if ($b.StatusClass -ne 'Terminal') { continue }
        if ($b.StatusLabel -notmatch '^REVIEWED') { continue }        # REVIEWED or REVIEWED/CLOSED only
        foreach ($id in $b.CanonicalIds) { [void]$ids.Add($id) }
    }
    # NOTE: `return $ids` would let PowerShell auto-enumerate the HashSet into the
    # pipeline (0 elements -> $null at the call site, 1 element -> a bare string, only
    # >=2 elements -> something array-like) instead of returning the HashSet object
    # itself. The unary comma operator suppresses that enumeration so the caller always
    # gets exactly one HashSet[string], regardless of how many ids it contains.
    return ,$ids
}

function Find-C1ClosureBlocks {
    <# Returns every block whose header starts with the literal token "C1-CLOSURE". #>
    param($Blocks)
    $found = New-Object System.Collections.Generic.List[object]
    foreach ($b in $Blocks) {
        $headerBody = $b.Header.Substring(3)
        if ($headerBody -match '^C1-CLOSURE\b') { $found.Add($b) }
    }
    # See the comma-operator note in Get-CanonicalReviewIds -- without it, a
    # single-match List[object] unrolls to the bare block object (losing .Count),
    # which would silently skip processing the one real C1-CLOSURE block.
    return ,$found
}

function ConvertFrom-MarkdownTableRow {
    <#
        Splits one "| a | b | c |" markdown table row into trimmed cell strings.
        block_id values legitimately contain literal '|' (e.g.
        "003|ORDER|current-archive#4") and must be escaped as '\|' when embedded in
        a table cell (mirrors Escape-MarkdownTableCell used for OUTPUT elsewhere) --
        this is the matching INPUT-side unescape: '\|' is protected with a sentinel
        before splitting on bare '|', then restored per-cell.
    #>
    param([string]$Line)
    $sentinel = [char]0xE000   # private-use-area char, will never appear in authored markdown
    $tmp = $Line.Replace('\|', [string]$sentinel)
    $trimmed = $tmp.Trim()
    if ($trimmed.StartsWith('|')) { $trimmed = $trimmed.Substring(1) }
    if ($trimmed.EndsWith('|')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1) }
    $cells = $trimmed -split '\|'
    return @($cells | ForEach-Object { $_.Trim().Replace([string]$sentinel, '|') })
}

function Get-C1ClosureTableRows {
    <#
        Parses the kind|block_id|block_sha256|disposition|evidence table out of a
        single C1-CLOSURE block's Content. Returns an array of pscustomobjects with
        Kind/BlockId/BlockSha256/Disposition/Evidence. Tolerant of the header row
        appearing anywhere in the block body (not just immediately after the H2
        line) and of the markdown separator row ("|---|---|...").
    #>
    param($Block)
    $lines = $Block.Content -split "`n"
    $rows = New-Object System.Collections.Generic.List[object]
    $headerIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if ($line -notmatch '^\|.*\|$') { continue }
        $cells = @(ConvertFrom-MarkdownTableRow -Line $line)

        if ($headerIdx -lt 0) {
            $norm = @($cells | ForEach-Object { $_.ToLowerInvariant() })
            if (($norm.Count -eq 5) -and ($norm[0] -eq 'kind') -and ($norm[1] -eq 'block_id') -and
                ($norm[2] -eq 'block_sha256') -and ($norm[3] -eq 'disposition') -and ($norm[4] -eq 'evidence')) {
                $headerIdx = $i
            }
            continue
        }
        if ($i -eq ($headerIdx + 1) -and ($line -match '^\|?[\s:|-]+\|?$')) { continue }  # separator row
        if ($cells.Count -lt 5) { continue }

        $rows.Add([pscustomobject]@{
            Kind = $cells[0]; BlockId = $cells[1]; BlockSha256 = $cells[2]
            Disposition = $cells[3]; Evidence = $cells[4]
        })
    }
    return $rows.ToArray()
}

function Invoke-ExceptionClosure {
    <#
        Applies Source A + Source B to $PolicyExceptions (the raw list from
        Invoke-ExceptionScan, each already carrying .Kind/.BlockId/.CanonicalId/.Sha256).
        Returns @{ Reviewed = [...]; Unresolved = [...]; IntegrityFailures = [...] }.
        Reviewed + Unresolved together are always a partition of $PolicyExceptions
        (every raw exception appears in exactly one of the two output lists).
    #>
    param($PolicyExceptions, $ActiveBlocks, $ArchiveBlocks)

    $corpus = New-Object System.Collections.Generic.List[object]
    foreach ($b in $ActiveBlocks) { $corpus.Add($b) }
    foreach ($b in $ArchiveBlocks) { $corpus.Add($b) }

    $closureIntegrity = New-Object System.Collections.Generic.List[object]

    # --- Source A ---
    $reviewedIdsA = Get-CanonicalReviewIds -Blocks $corpus

    # --- Source B: locate + parse the (at most one) C1-CLOSURE block ---
    # NOTE: do NOT wrap this call in @(...) -- Find-C1ClosureBlocks already uses the
    # comma operator internally (",$found") to guarantee it always emits exactly one
    # List[object], however many blocks it found (0, 1, or many). Wrapping the call
    # site in @() too would re-box that single List into a 1-element OUTER array,
    # making .Count always report 1 regardless of the real match count.
    $c1Blocks = Find-C1ClosureBlocks -Blocks $corpus
    $c1Rows = @()
    if ($c1Blocks.Count -gt 1) {
        $closureIntegrity.Add([pscustomobject]@{
            Kind = 'c1-closure-ambiguous'; Severity = 'integrity'
            Detail = "$($c1Blocks.Count) blocks matched header '## C1-CLOSURE' (expected at most 1) -- ambiguous, not parsed"
        })
    } elseif ($c1Blocks.Count -eq 1) {
        $block = $c1Blocks[0]
        if (-not (($block.StatusClass -eq 'Terminal') -and ($block.StatusLabel -match '^REVIEWED'))) {
            $closureIntegrity.Add([pscustomobject]@{
                Kind = 'c1-closure-not-reviewed'; Severity = 'integrity'
                BlockId = $block.BlockId; Header = $block.Header
                Detail = "C1-CLOSURE block found but its status is not a REVIEWED(...) verb (status='$($block.StatusLabel)') -- not parsed/honored"
            })
        } else {
            $c1Rows = @(Get-C1ClosureTableRows -Block $block)
        }
    }

    # Index raw exceptions by (Kind, BlockId) -> list of array-indices (almost always
    # singleton, but kept as a list defensively in case the same block ever produces
    # two exceptions of the identical kind).
    $excIndexByKey = @{}
    for ($i = 0; $i -lt $PolicyExceptions.Count; $i++) {
        $e = $PolicyExceptions[$i]
        $key = $e.Kind + '||' + $e.BlockId
        if (-not $excIndexByKey.ContainsKey($key)) { $excIndexByKey[$key] = New-Object System.Collections.Generic.List[int] }
        $excIndexByKey[$key].Add($i)
    }

    # --- Source B row processing: unknown/duplicate rows = integrity; else match sha ---
    $seenRowKeys = New-Object System.Collections.Generic.HashSet[string]
    $bClosedIndex = @{}   # array-index -> row that closed it
    $bStaleIndex  = @{}   # array-index -> row that matched key but had a stale sha

    foreach ($row in $c1Rows) {
        $rowKey = $row.Kind + '||' + $row.BlockId
        if ($seenRowKeys.Contains($rowKey)) {
            $closureIntegrity.Add([pscustomobject]@{
                Kind = 'c1-closure-duplicate-row'; Severity = 'integrity'
                Detail = "duplicate C1-CLOSURE row for kind='$($row.Kind)' block_id='$($row.BlockId)'"
            })
            continue
        }
        [void]$seenRowKeys.Add($rowKey)

        if (-not $excIndexByKey.ContainsKey($rowKey)) {
            $closureIntegrity.Add([pscustomobject]@{
                Kind = 'c1-closure-unknown-row'; Severity = 'integrity'
                Detail = "C1-CLOSURE row for kind='$($row.Kind)' block_id='$($row.BlockId)' matches no detected policy exception"
            })
            continue
        }

        foreach ($idx in $excIndexByKey[$rowKey]) {
            $e = $PolicyExceptions[$idx]
            if ($e.Sha256 -eq $row.BlockSha256) {
                $bClosedIndex[$idx] = $row
            } else {
                $bStaleIndex[$idx] = $row
            }
        }
    }

    # --- Partition: every raw exception -> Reviewed (A or B) or Unresolved ---
    $reviewed = New-Object System.Collections.Generic.List[object]
    $unresolved = New-Object System.Collections.Generic.List[object]

    for ($i = 0; $i -lt $PolicyExceptions.Count; $i++) {
        $e = $PolicyExceptions[$i]

        if ($e.CanonicalId -and $reviewedIdsA.Contains($e.CanonicalId)) {
            $reviewed.Add([pscustomobject]@{
                Kind = $e.Kind; BlockId = $e.BlockId; Header = $e.Header; Detail = $e.Detail
                CanonicalId = $e.CanonicalId; Sha256 = $e.Sha256
                ClosureSource = 'A-review-block'
                ClosureDetail = "canonical_id=$($e.CanonicalId) covered by a REVIEWED '## REVIEW ORDER-$($e.CanonicalId)'-style block"
            })
            continue
        }

        if ($bClosedIndex.ContainsKey($i)) {
            $row = $bClosedIndex[$i]
            $reviewed.Add([pscustomobject]@{
                Kind = $e.Kind; BlockId = $e.BlockId; Header = $e.Header; Detail = $e.Detail
                CanonicalId = $e.CanonicalId; Sha256 = $e.Sha256
                ClosureSource = 'B-C1-closure-block'
                ClosureDetail = "closed by C1-CLOSURE row (disposition='$($row.Disposition)'; evidence='$($row.Evidence)')"
            })
            continue
        }

        $staleNote = $null
        if ($bStaleIndex.ContainsKey($i)) {
            $row = $bStaleIndex[$i]
            $staleNote = "STALE C1-CLOSURE row found for kind='$($e.Kind)' block_id='$($e.BlockId)' but block_sha256 mismatch (row='$($row.BlockSha256)' current='$($e.Sha256)') -- closure NOT honored, exception stays unresolved"
        }
        $unresolved.Add([pscustomobject]@{
            Kind = $e.Kind; BlockId = $e.BlockId; Header = $e.Header; Detail = $e.Detail
            CanonicalId = $e.CanonicalId; Sha256 = $e.Sha256
            StaleClosureNote = $staleNote
        })
    }

    return [pscustomobject]@{
        Reviewed = $reviewed.ToArray()
        Unresolved = $unresolved.ToArray()
        IntegrityFailures = $closureIntegrity.ToArray()
    }
}

# ============================================================================
# ARTIFACTS: MANIFEST + INDEX
# ============================================================================

function New-ArchiveManifestRows {
    param($CurrentArchiveBlocks, [string]$ArchiveBlobSha)
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($b in $CurrentArchiveBlocks) {
        $canon = ''
        if ($b.CanonicalIds.Count -gt 0) { $canon = $b.CanonicalIds[0] }
        $rows.Add([pscustomobject]@{
            block_id         = $b.BlockId
            canonical_id     = $canon
            block_type       = $b.BlockType
            sha256           = $b.Sha256
            archive_blob_sha = $ArchiveBlobSha
            source_anchor    = $b.Ordinal
        })
    }
    return $rows
}

function Write-ArchiveManifestCsv {
    param($Rows, [string]$Path)
    $Rows | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

function Test-ManifestBijection {
    <#
        Verifies: exactly one manifest row per current-archive block, every row
        resolves back to exactly one block (by source_anchor), and that EVERY
        tracked field of the resolved block matches the row -- not just hash +
        source-identity + the overall ID-set (ORDER-101 fix 3). Concretely, for
        each row: resolve source_anchor -> block, then assert
            row.sha256           == block.Sha256
            row.archive_blob_sha == ExpectedArchiveBlobSha
            row.block_id         == block.BlockId
            row.canonical_id     == block's own canonical id (first CanonicalIds entry, or '')
            row.block_type       == block.BlockType
        This is what catches a block_id (or canonical_id/block_type) SWAP between
        two rows even when their anchors/hashes are individually untouched and the
        archive-wide ID set still looks "complete" -- the pre-fix-3 checks below
        (duplicate block_id, row count, "every block has a row") do not detect a
        pure swap because both IDs are still present, just attached to the wrong row.
    #>
    param($ManifestRows, $CurrentArchiveBlocks, [string]$ExpectedArchiveBlobSha)

    $failures = New-Object System.Collections.Generic.List[string]

    $blocksByOrdinal = @{}
    foreach ($b in $CurrentArchiveBlocks) { $blocksByOrdinal[[int]$b.Ordinal] = $b }

    $rowIdCounts = @{}
    foreach ($r in $ManifestRows) {
        if ($rowIdCounts.ContainsKey($r.block_id)) { $rowIdCounts[$r.block_id]++ } else { $rowIdCounts[$r.block_id] = 1 }
    }
    foreach ($id in $rowIdCounts.Keys) {
        if ($rowIdCounts[$id] -gt 1) { $failures.Add("duplicate block_id in manifest: $id (x$($rowIdCounts[$id]))") }
    }

    if ($ManifestRows.Count -ne $CurrentArchiveBlocks.Count) {
        $failures.Add("row count ($($ManifestRows.Count)) != archive block count ($($CurrentArchiveBlocks.Count))")
    }

    foreach ($r in $ManifestRows) {
        $ordinalOk = $true
        $ordinal = 0
        try { $ordinal = [int]$r.source_anchor } catch { $ordinalOk = $false }
        if (-not $ordinalOk -or -not $blocksByOrdinal.ContainsKey($ordinal)) {
            $failures.Add("source_anchor '$($r.source_anchor)' (block_id=$($r.block_id)) does not resolve to any current-archive block")
            continue
        }
        $block = $blocksByOrdinal[$ordinal]

        if ($block.Sha256 -ne $r.sha256) {
            $failures.Add("sha256 mismatch for block_id=$($r.block_id): manifest=$($r.sha256) recomputed=$($block.Sha256)")
        }
        if ($r.archive_blob_sha -ne $ExpectedArchiveBlobSha) {
            $failures.Add("archive_blob_sha mismatch for block_id=$($r.block_id): manifest=$($r.archive_blob_sha) expected=$ExpectedArchiveBlobSha")
        }
        if ($r.block_id -ne $block.BlockId) {
            $failures.Add("block_id mismatch at source_anchor=$($r.source_anchor): manifest row's own block_id='$($r.block_id)' but the block actually resolved at that anchor has block_id='$($block.BlockId)' (header='$($block.Header)')")
        }
        $expectedCanon = ''
        if ($block.CanonicalIds.Count -gt 0) { $expectedCanon = $block.CanonicalIds[0] }
        if ([string]$r.canonical_id -ne $expectedCanon) {
            $failures.Add("canonical_id mismatch at source_anchor=$($r.source_anchor) (block_id=$($r.block_id)): manifest=$($r.canonical_id) resolved-block=$expectedCanon")
        }
        if ($r.block_type -ne $block.BlockType) {
            $failures.Add("block_type mismatch at source_anchor=$($r.source_anchor) (block_id=$($r.block_id)): manifest=$($r.block_type) resolved-block=$($block.BlockType)")
        }
    }

    $manifestBlockIds = New-Object System.Collections.Generic.HashSet[string]
    foreach ($r in $ManifestRows) { [void]$manifestBlockIds.Add($r.block_id) }
    foreach ($b in $CurrentArchiveBlocks) {
        if (-not $manifestBlockIds.Contains($b.BlockId)) {
            $failures.Add("archive block (ordinal=$($b.Ordinal), header='$($b.Header)') has no manifest row")
        }
    }

    return [pscustomobject]@{ IsClean = ($failures.Count -eq 0); Failures = @($failures) }
}

function Escape-MarkdownTableCell {
    <#
        Escapes a value for safe embedding in a `| ... |` markdown table cell. block_id
        values are themselves built with literal '|' separators (e.g.
        "001|ORDER|current-archive#1"), which -- unescaped -- renders as extra table
        columns. Applied defensively to every cell (cheap, harmless on cells that never
        contain a pipe, like canonical_id/block_type/source_anchor/sha256).
    #>
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return $Value.Replace('|', '\|')
}

function Build-ArchiveIndexMarkdown {
    param($ManifestRows, [string]$ArchiveBlobSha, [string]$ArchiveRawFileSha256)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# ARCHIVE_INDEX.md')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('> **GENERATED -- read-only -- do not edit.** Derived from `ARCHIVE_MANIFEST.csv` by')
    [void]$sb.AppendLine('> `scripts/check_taskboard_archive.ps1 -Generate` (only `-Generate` writes this file;')
    [void]$sb.AppendLine('> `-Audit`/`-Strict` are read-only). Re-running the generator against the same')
    [void]$sb.AppendLine('> manifest reproduces this file byte-for-byte (no timestamps/run-ids embedded).')
    [void]$sb.AppendLine('> Archive content identity (git blob SHA of ARCHIVE_TASKBOARD_2026-07A.md content --')
    [void]$sb.AppendLine('> NOT repo HEAD; stable across any commit that does not touch that file): `' + $ArchiveBlobSha + '`')
    [void]$sb.AppendLine('> Archive whole-file RAW-BYTE SHA256 (as committed, CRLF-as-is -- detects file-level')
    [void]$sb.AppendLine('> EOL/whitespace drift the per-block hashes below cannot see): `' + $ArchiveRawFileSha256 + '`')
    [void]$sb.AppendLine('> HASH NOTE: the per-block `sha256` column below is a CANONICAL-TEXT hash (CRLF/CR')
    [void]$sb.AppendLine('> normalized to LF before hashing), not a raw-byte hash -- a CRLF-only edit inside one')
    [void]$sb.AppendLine('> block will not change that block''s sha256; rely on the whole-file raw-byte hash above.')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| block_id | canonical_id | block_type | source_anchor | sha256 |')
    [void]$sb.AppendLine('|---|---|---|---|---|')
    $sorted = $ManifestRows | Sort-Object { [int]$_.source_anchor }
    foreach ($r in $sorted) {
        $cBlockId   = Escape-MarkdownTableCell $r.block_id
        $cCanonical = Escape-MarkdownTableCell $r.canonical_id
        $cType      = Escape-MarkdownTableCell $r.block_type
        $cAnchor    = Escape-MarkdownTableCell ([string]$r.source_anchor)
        $cSha       = Escape-MarkdownTableCell $r.sha256
        [void]$sb.AppendLine('| ' + $cBlockId + ' | ' + $cCanonical + ' | ' + $cType + ' | ' + $cAnchor + ' | ' + $cSha + ' |')
    }
    return $sb.ToString()
}

function Write-TextFileLfNoBom {
    param([string]$Path, [string]$Text)
    # Write with LF line endings and no BOM so re-generation is byte-identical
    # regardless of the platform default the file happens to be opened on.
    $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

# ============================================================================
# CORE CHECK (parameterized so real-repo run and negative tests share one path)
# ============================================================================

function Invoke-TaskboardArchiveCheck {
    param(
        [string]$RepoRoot,
        [string]$PreSplitSource,
        [string]$SplitActiveSource,
        [string]$SplitArchiveSource,
        [string]$CurrentActiveSource,
        [string]$CurrentArchiveSource,
        [ValidateSet('Audit', 'Strict', 'Generate')]
        [string]$Mode,
        [bool]$SkipArtifacts,
        [string]$ManifestPath,
        [string]$IndexPath,
        [string]$ExceptionsPath
    )

    $isStrict   = ($Mode -eq 'Strict')
    $isGenerate = ($Mode -eq 'Generate')
    # ORDER-101 fix 1: only -Generate ever writes ARCHIVE_MANIFEST.csv / ARCHIVE_INDEX.md /
    # RECONCILE_EXCEPTIONS.md. -Audit and -Strict are read-only: they read whatever is
    # ALREADY on disk at ManifestPath/IndexPath and validate it against the live archive --
    # a corrupt or stale committed manifest/index must be caught (exit 2), never silently
    # regenerated-then-reported-clean.
    $writeArtifacts = ($isGenerate -and -not $SkipArtifacts)

    $report = [ordered]@{}

    $preBytes            = Get-SourceBytes -RepoRoot $RepoRoot -SourceSpec $PreSplitSource
    $activeSplitBytes     = Get-SourceBytes -RepoRoot $RepoRoot -SourceSpec $SplitActiveSource
    $archiveSplitBytes    = Get-SourceBytes -RepoRoot $RepoRoot -SourceSpec $SplitArchiveSource
    $activeCurrentBytes   = Get-SourceBytes -RepoRoot $RepoRoot -SourceSpec $CurrentActiveSource
    $archiveCurrentBytes  = Get-SourceBytes -RepoRoot $RepoRoot -SourceSpec $CurrentArchiveSource

    $report.PreStateHashes = [ordered]@{
        CurrentActiveFileSha256  = Get-Sha256Hex -Bytes $activeCurrentBytes
        CurrentArchiveFileSha256 = Get-Sha256Hex -Bytes $archiveCurrentBytes
    }

    $preText           = Get-NormalizedTextFromBytes -Bytes $preBytes
    $activeSplitText   = Get-NormalizedTextFromBytes -Bytes $activeSplitBytes
    $archiveSplitText  = Get-NormalizedTextFromBytes -Bytes $archiveSplitBytes
    $activeCurrentText = Get-NormalizedTextFromBytes -Bytes $activeCurrentBytes
    $archiveCurrentText = Get-NormalizedTextFromBytes -Bytes $archiveCurrentBytes

    $preBlocks           = @(Get-ClassifiedBlocks -Text $preText -SourceTag 'presplit')
    $activeSplitBlocks   = @(Get-ClassifiedBlocks -Text $activeSplitText -SourceTag 'split-active')
    $archiveSplitBlocks  = @(Get-ClassifiedBlocks -Text $archiveSplitText -SourceTag 'split-archive')
    $activeCurrentBlocks = @(Get-ClassifiedBlocks -Text $activeCurrentText -SourceTag 'current-active')
    $archiveCurrentBlocks = @(Get-ClassifiedBlocks -Text $archiveCurrentText -SourceTag 'current-archive')

    $report.BlockCounts = [ordered]@{
        PreSplitH2       = $preBlocks.Count
        SplitActiveH2    = $activeSplitBlocks.Count
        SplitArchiveH2   = $archiveSplitBlocks.Count
        CurrentActiveH2  = $activeCurrentBlocks.Count
        CurrentArchiveH2 = $archiveCurrentBlocks.Count
    }

    $splitIntegrity = Invoke-SplitIntegrityCheck -PreBlocks $preBlocks -ActiveSplitBlocks $activeSplitBlocks -ArchiveSplitBlocks $archiveSplitBlocks
    $report.SplitIntegrity = $splitIntegrity

    $activeConservation = Invoke-ActiveConservationCheck -SplitActiveBlocks $activeSplitBlocks -CurrentActiveBlocks $activeCurrentBlocks -CurrentArchiveBlocks $archiveCurrentBlocks
    $archiveAppendOnly = Invoke-ArchiveAppendOnlyCheck -SplitArchiveBlocks $archiveSplitBlocks -CurrentArchiveBlocks $archiveCurrentBlocks
    $report.ActiveConservation = $activeConservation
    $report.ArchiveAppendOnly = $archiveAppendOnly

    $exceptions = Invoke-ExceptionScan -CurrentActiveBlocks $activeCurrentBlocks -CurrentArchiveBlocks $archiveCurrentBlocks
    $report.Exceptions = $exceptions

    # ORDER-102 Contract C1: canonical-review-linkage closure (Source A: REVIEW-block
    # linkage; Source B: a C1-CLOSURE block). READ-ONLY -- only classifies the raw
    # exceptions above, never mutates AGENT_TASKBOARD.md/ARCHIVE_TASKBOARD_2026-07A.md.
    $closure = Invoke-ExceptionClosure -PolicyExceptions $exceptions.Policy -ActiveBlocks $activeCurrentBlocks -ArchiveBlocks $archiveCurrentBlocks
    $report.CanonicallyReviewed = @($closure.Reviewed)
    $report.UnresolvedPolicyExceptions = @($closure.Unresolved)

    $integrityFailures = New-Object System.Collections.Generic.List[object]
    foreach ($f in $exceptions.Integrity) { $integrityFailures.Add($f) }
    foreach ($f in $closure.IntegrityFailures) { $integrityFailures.Add($f) }

    if ($splitIntegrity.Missing.Count -gt 0) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'split-integrity-missing'; Severity = 'integrity'; Detail = "$($splitIntegrity.Missing.Count) pre-split block(s) missing from split active+archive union" })
    }
    if ($splitIntegrity.Mutated.Count -gt 0) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'split-integrity-mutated'; Severity = 'integrity'; Detail = "$($splitIntegrity.Mutated.Count) block(s) mutated across the split" })
    }
    if ($splitIntegrity.Duplicated.Count -gt 0) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'split-integrity-duplicated'; Severity = 'integrity'; Detail = "$($splitIntegrity.Duplicated.Count) block(s) duplicated across the split" })
    }
    if ($activeConservation.OrderLost.Count -gt 0) {
        foreach ($lost in $activeConservation.OrderLost) {
            $cid = ''; if ($lost.CanonicalIds.Count -gt 0) { $cid = $lost.CanonicalIds[0] }
            $integrityFailures.Add([pscustomobject]@{
                Kind = 'active-order-lost'; Severity = 'integrity'
                BlockId = $lost.BlockId; Header = $lost.Header
                Detail = "canonical_id=$cid was an ORDER block in the split-active board but is resolvable in NEITHER current-active NOR current-archive -- order silently lost"
            })
        }
    }
    if (-not $archiveAppendOnly.IsAppendOnlyClean) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'archive-not-append-only'; Severity = 'integrity'; Detail = "archive diverged from append-only: $($archiveAppendOnly.Missing.Count) split-archive block(s) missing, $($archiveAppendOnly.Mutated.Count) mutated (post-split appends are allowed and reported separately: $($archiveAppendOnly.PostSplitAppends.Count))" })
    }
    if ($splitIntegrity.GeneratedExtras.Count -ne 1) {
        # ORDER-101 hardening 5 (tightened by the ORDER-101 blind review, off-by-one fix):
        # the generated-extra exclusion is pinned to EXACTLY the ONE known manual-index
        # block ("## ... ARCHIVED ORDERS INDEX"). The old guard only fired on -gt 1, so
        # ZERO matches silently passed too -- meaning the expected block going missing (or
        # its header being renamed/reworded so the pattern no longer matches) would never
        # be caught. 0 matches = expected block missing/renamed (exclusion silently does
        # nothing); >1 matches = ambiguous exclusion (would silently multi-exclude). Both
        # are integrity failures to investigate, not something to wave through.
        $integrityFailures.Add([pscustomobject]@{ Kind = 'generated-extra-ambiguous'; Severity = 'integrity'; Detail = "$($splitIntegrity.GeneratedExtras.Count) block(s) matched the generated-extra header pattern (expected EXACTLY 1 -- the single known manual 'ARCHIVED ORDERS INDEX' block); 0 = missing/renamed expected block, >1 = ambiguous exclusion, so either is an integrity failure instead" })
    }

    # ORDER-101 fix 2: archive-content identity (git blob SHA), NOT repo HEAD. See
    # Get-ArchiveContentIdentity for why this makes regeneration after an unrelated
    # commit byte-identical.
    $archiveBlobSha = Get-ArchiveContentIdentity -RepoRoot $RepoRoot -SourceSpec $CurrentArchiveSource
    $report.ArchiveBlobSha = $archiveBlobSha
    $manifestRows = @(New-ArchiveManifestRows -CurrentArchiveBlocks $archiveCurrentBlocks -ArchiveBlobSha $archiveBlobSha)

    if ($writeArtifacts) {
        Write-ArchiveManifestCsv -Rows $manifestRows -Path $ManifestPath
    }

    # -Audit/-Strict: read whatever is ALREADY on disk (never written above) and validate
    # it. -Generate (non-skip): re-read what was just written, same code path either way.
    if (-not (Test-Path $ManifestPath)) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'manifest-missing'; Severity = 'integrity'; Detail = "no manifest file found at '$ManifestPath' -- -Audit/-Strict are read-only and never create it; run -Generate first" })
        $manifestOnDisk = @()
    } else {
        $manifestOnDisk = @(Import-Csv -Path $ManifestPath)
    }
    $bijection = Test-ManifestBijection -ManifestRows $manifestOnDisk -CurrentArchiveBlocks $archiveCurrentBlocks -ExpectedArchiveBlobSha $archiveBlobSha
    $report.ManifestBijection = $bijection
    if (-not $bijection.IsClean) {
        foreach ($f in $bijection.Failures) { $integrityFailures.Add([pscustomobject]@{ Kind = 'manifest-bijection'; Severity = 'integrity'; Detail = $f }) }
    }

    $indexText = Build-ArchiveIndexMarkdown -ManifestRows $manifestOnDisk -ArchiveBlobSha $archiveBlobSha -ArchiveRawFileSha256 $report.PreStateHashes.CurrentArchiveFileSha256
    if ($writeArtifacts) {
        Write-TextFileLfNoBom -Path $IndexPath -Text $indexText
    }
    if (Test-Path $IndexPath) {
        $onDiskIndexBytes = [System.IO.File]::ReadAllBytes($IndexPath)
        $onDiskIndexText = Get-NormalizedTextFromBytes -Bytes $onDiskIndexBytes
        $rebuiltNormalized = $indexText.Replace("`r`n", "`n").Replace("`r", "`n")
        $indexZeroDiff = ($onDiskIndexText -eq $rebuiltNormalized)
    } else {
        $indexZeroDiff = $false
        $integrityFailures.Add([pscustomobject]@{ Kind = 'index-missing'; Severity = 'integrity'; Detail = "no index file found at '$IndexPath' -- -Audit/-Strict are read-only and never create it; run -Generate first" })
    }
    $report.IndexRebuildZeroDiff = $indexZeroDiff
    if ((Test-Path $IndexPath) -and -not $indexZeroDiff) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'index-rebuild-not-zero-diff'; Severity = 'integrity'; Detail = 'ARCHIVE_INDEX.md on disk does not match a fresh rebuild from the on-disk manifest (stale index)' })
    }

    $report.IntegrityFailures = $integrityFailures.ToArray()
    $report.PolicyExceptions = @($exceptions.Policy)

    # ORDER-101 fix 1 (blind-review blocker): -Audit/-Strict validated the manifest CSV
    # and the generated index but never RECONCILE_EXCEPTIONS.md itself -- the key input
    # Opus/C1 consumes -- so a stale, hand-corrupted, or deleted committed exceptions
    # report left Audit/Strict green. Recompute the expected exceptions content from the
    # report state as accumulated so far (deliberately BEFORE this very check is added to
    # it, to avoid self-reference) and compare it to whatever is on disk, using a
    # CONTENT-CANONICAL (LF-normalized) comparison -- NOT raw bytes -- exactly like the
    # index-rebuild-not-zero-diff check above. This is deliberate: core.autocrlf=true
    # in this repo means the working-tree file is CRLF while git stores LF, so a raw
    # byte compare of a canonical-LF rebuild vs the CRLF working-tree file would
    # false-fail EVERY clean run. The canonical compare catches all content drift/
    # corruption/deletion of a COMMITTED exceptions file (proven by the stale-exceptions
    # test); a CRLF-only difference is autocrlf normalization noise, not corruption.
    # -Generate writes the fresh file first (so the immediate read-back matches);
    # -Audit/-Strict never write.
    $expectedExceptionsText = Build-ExceptionsMarkdown -Report $report
    if ($writeArtifacts) {
        Write-TextFileLfNoBom -Path $ExceptionsPath -Text $expectedExceptionsText
    }
    if (Test-Path $ExceptionsPath) {
        $onDiskExceptionsBytes = [System.IO.File]::ReadAllBytes($ExceptionsPath)
        $onDiskExceptionsText = Get-NormalizedTextFromBytes -Bytes $onDiskExceptionsBytes
        $rebuiltExceptionsNormalized = $expectedExceptionsText.Replace("`r`n", "`n").Replace("`r", "`n")
        $exceptionsZeroDiff = ($onDiskExceptionsText -eq $rebuiltExceptionsNormalized)
    } else {
        $exceptionsZeroDiff = $false
        $integrityFailures.Add([pscustomobject]@{ Kind = 'exceptions-missing'; Severity = 'integrity'; Detail = "no exceptions file found at '$ExceptionsPath' -- -Audit/-Strict are read-only and never create it; run -Generate first" })
    }
    $report.ExceptionsRebuildZeroDiff = $exceptionsZeroDiff
    if ((Test-Path $ExceptionsPath) -and -not $exceptionsZeroDiff) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'exceptions-rebuild-not-zero-diff'; Severity = 'integrity'; Detail = 'RECONCILE_EXCEPTIONS.md on disk does not match a fresh rebuild from the current findings (stale or corrupted exceptions file)' })
    }
    $report.IntegrityFailures = $integrityFailures.ToArray()

    # EXIT SEMANTICS (ORDER-102 Contract C1 update): -Strict now gates on UNRESOLVED
    # exceptions (raw minus canonically-reviewed via Source A/B), not raw policy count
    # -- a policy exception canonically closed by a REVIEW block or a C1-CLOSURE row
    # no longer blocks -Strict. -Audit is unchanged: it only ever cared about
    # integrity failures, never policy/unresolved count.
    if ($integrityFailures.Count -gt 0) {
        $exitCode = $script:EXIT_INTEGRITY
    } elseif ($isStrict -and $report.UnresolvedPolicyExceptions.Count -gt 0) {
        $exitCode = $script:EXIT_POLICY
    } else {
        $exitCode = $script:EXIT_OK
    }
    $report.ExitCode = $exitCode

    return $report
}

function Build-ExceptionsMarkdown {
    <#
        Returns the RECONCILE_EXCEPTIONS.md text for the given report, WITHOUT writing
        anything. Split out from Write-ExceptionsMarkdown (ORDER-101 fix 1) so
        Invoke-TaskboardArchiveCheck can recompute the expected content in-memory in
        -Audit/-Strict and compare it byte-for-byte to whatever is already on disk --
        the same pattern Build-ArchiveIndexMarkdown already uses for the index-rebuild
        check. Deterministic: driven only by $Report.PolicyExceptions/$Report.IntegrityFailures,
        which are themselves built by iterating fixed-order block lists -- no timestamps,
        run-ids, or non-deterministic hashtable enumeration feed into this text.
    #>
    param($Report)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# RECONCILE_EXCEPTIONS.md')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('> Generated by `scripts/check_taskboard_archive.ps1 -Generate` (ORDER-101 Contract C0 +')
    [void]$sb.AppendLine('> ORDER-102 Contract C1 canonical-review-linkage).')
    [void]$sb.AppendLine('> **Worker does not resolve or move anything here.** Every row below needs an Opus')
    [void]$sb.AppendLine('> (or user) classification decision. This file is regenerated only by `-Generate`')
    [void]$sb.AppendLine('> (`-Audit`/`-Strict` are read-only and never touch it) -- do not hand-edit it; land')
    [void]$sb.AppendLine('> Opus decisions in PROJECT_STATE.md / the taskboard instead.')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('> **Counts:** raw_detected=' + $Report.PolicyExceptions.Count +
        ' | canonically_reviewed=' + $Report.CanonicallyReviewed.Count +
        ' | unresolved=' + $Report.UnresolvedPolicyExceptions.Count)
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Policy exceptions -- raw_detected (severity 1, before any closure)')
    [void]$sb.AppendLine('')
    if ($Report.PolicyExceptions.Count -eq 0) {
        [void]$sb.AppendLine('_None found._')
    } else {
        [void]$sb.AppendLine('| kind | block_id | header | detail |')
        [void]$sb.AppendLine('|---|---|---|---|')
        foreach ($e in $Report.PolicyExceptions) {
            $bid    = $e.BlockId.Replace('|', '\|')   # block_id contains literal '|' (e.g. 003|ORDER|current-archive#4)
            $header = $e.Header.Replace('|', '\|')
            $detail = $e.Detail.Replace('|', '\|')
            [void]$sb.AppendLine('| ' + $e.Kind + ' | ' + $bid + ' | ' + $header + ' | ' + $detail + ' |')
        }
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Canonically reviewed -- CLOSED (Contract C1 Source A: REVIEW-block linkage /')
    [void]$sb.AppendLine('## Source B: C1-CLOSURE block; no further action needed)')
    [void]$sb.AppendLine('')
    if ($Report.CanonicallyReviewed.Count -eq 0) {
        [void]$sb.AppendLine('_None found._')
    } else {
        [void]$sb.AppendLine('| kind | block_id | closure_source | closure_detail |')
        [void]$sb.AppendLine('|---|---|---|---|')
        foreach ($e in $Report.CanonicallyReviewed) {
            $bid = $e.BlockId.Replace('|', '\|')
            $csrc = $e.ClosureSource.Replace('|', '\|')
            $cdet = $e.ClosureDetail.Replace('|', '\|')
            [void]$sb.AppendLine('| ' + $e.Kind + ' | ' + $bid + ' | ' + $csrc + ' | ' + $cdet + ' |')
        }
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Unresolved -- raw_detected minus canonically_reviewed (needs a C1-CLOSURE row)')
    [void]$sb.AppendLine('')
    if ($Report.UnresolvedPolicyExceptions.Count -eq 0) {
        [void]$sb.AppendLine('_None found._')
    } else {
        [void]$sb.AppendLine('| kind | block_id | header | detail |')
        [void]$sb.AppendLine('|---|---|---|---|')
        foreach ($e in $Report.UnresolvedPolicyExceptions) {
            $bid    = $e.BlockId.Replace('|', '\|')
            $header = $e.Header.Replace('|', '\|')
            $detail = $e.Detail.Replace('|', '\|')
            if ($e.StaleClosureNote) { $detail = $detail + ' [' + $e.StaleClosureNote.Replace('|', '\|') + ']' }
            [void]$sb.AppendLine('| ' + $e.Kind + ' | ' + $bid + ' | ' + $header + ' | ' + $detail + ' |')
        }
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Integrity / tooling failures (severity 2 -- blocks both -Audit and -Strict)')
    [void]$sb.AppendLine('')
    if ($Report.IntegrityFailures.Count -eq 0) {
        [void]$sb.AppendLine('_None found._')
    } else {
        [void]$sb.AppendLine('| kind | block_id | header | detail |')
        [void]$sb.AppendLine('|---|---|---|---|')
        foreach ($e in $Report.IntegrityFailures) {
            $bid = ''; if ($e.PSObject.Properties['BlockId']) { $bid = $e.BlockId.Replace('|', '\|') }
            $hdr = ''; if ($e.PSObject.Properties['Header']) { $hdr = $e.Header.Replace('|', '\|') }
            $detail = $e.Detail.Replace('|', '\|')
            [void]$sb.AppendLine('| ' + $e.Kind + ' | ' + $bid + ' | ' + $hdr + ' | ' + $detail + ' |')
        }
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Other findings (not policy/integrity exceptions, still worth Opus attention)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('- Manual `## ARCHIVED ORDERS INDEX` block embedded in the active taskboard violates')
    [void]$sb.AppendLine('  the "generated index must be read-only" rule (design source Sec 20.7). C0 is read-only')
    [void]$sb.AppendLine('  and does not touch it; replacing it with a generated view is C1 scope.')
    [void]$sb.AppendLine('- Source A (REVIEW-block linkage) closes by **canonical id** -- any of the 3 raw-')
    [void]$sb.AppendLine('  exception kinds for a canonical id covered by a REVIEWED `## REVIEW ORDER-<id>`-style')
    [void]$sb.AppendLine('  block are closed. Source B (a `## C1-CLOSURE` block) closes by the EXACT (kind,')
    [void]$sb.AppendLine('  block_id, block_sha256) triple -- never by canonical id alone -- so one kind of a')
    [void]$sb.AppendLine('  block can be closed without silently closing a different kind of the same block_id,')
    [void]$sb.AppendLine('  and a stale block_sha256 (block edited since the closure row was written) is reported')
    [void]$sb.AppendLine('  rather than silently honored.')
    [void]$sb.AppendLine('')
    return $sb.ToString()
}

function Write-ExceptionsMarkdown {
    <# Thin wrapper kept for callers that want build+write in one step. #>
    param($Report, [string]$Path)
    Write-TextFileLfNoBom -Path $Path -Text (Build-ExceptionsMarkdown -Report $Report)
}

# ============================================================================
# ENTRY POINT (guarded so dot-sourcing this file for its functions, e.g. from a
# test harness, does not also run the real-repo Main pass)
# ============================================================================

function Invoke-Main {
    param([string]$Mode)

    if (-not $CurrentActiveSource)  { $script:CurrentActiveSource  = 'FILE:' + (Join-Path $RepoRoot 'AGENT_TASKBOARD.md') }
    if (-not $CurrentArchiveSource) { $script:CurrentArchiveSource = 'FILE:' + (Join-Path $RepoRoot 'ARCHIVE_TASKBOARD_2026-07A.md') }
    if (-not $ManifestPath)   { $script:ManifestPath = Join-Path $RepoRoot 'docs/memory_control/ARCHIVE_MANIFEST.csv' }
    if (-not $IndexPath)      { $script:IndexPath = Join-Path $RepoRoot 'docs/memory_control/ARCHIVE_INDEX.md' }
    if (-not $ExceptionsPath) { $script:ExceptionsPath = Join-Path $RepoRoot 'docs/memory_control/RECONCILE_EXCEPTIONS.md' }

    $isGenerate = ($Mode -eq 'Generate')
    $writeArtifacts = ($isGenerate -and -not $SkipArtifacts)

    # NOTE: RECONCILE_EXCEPTIONS.md is now written (under -Generate) AND validated
    # (under all modes, ORDER-101 fix 1) INSIDE Invoke-TaskboardArchiveCheck, the same
    # place ARCHIVE_MANIFEST.csv/ARCHIVE_INDEX.md are written+validated -- no separate
    # write-after-the-fact call here anymore.
    $report = Invoke-TaskboardArchiveCheck -RepoRoot $RepoRoot `
        -PreSplitSource $PreSplitSource -SplitActiveSource $SplitActiveSource -SplitArchiveSource $SplitArchiveSource `
        -CurrentActiveSource $CurrentActiveSource -CurrentArchiveSource $CurrentArchiveSource `
        -Mode $Mode -SkipArtifacts $SkipArtifacts.IsPresent `
        -ManifestPath $ManifestPath -IndexPath $IndexPath -ExceptionsPath $ExceptionsPath

    $modeLabel = $Mode.ToUpper()
    $roTag = if ($isGenerate) { '' } else { ' (READ-ONLY -- never writes manifest/index/exceptions)' }
    Write-Host "=== check_taskboard_archive.ps1 [$modeLabel]$roTag ==="
    Write-Host ('Pre-state hash  AGENT_TASKBOARD.md            = ' + $report.PreStateHashes.CurrentActiveFileSha256)
    Write-Host ('Pre-state hash  ARCHIVE_TASKBOARD_2026-07A.md = ' + $report.PreStateHashes.CurrentArchiveFileSha256)
    Write-Host ('Archive content identity (git blob sha)       = ' + $report.ArchiveBlobSha)
    Write-Host ('Block counts: presplit H2=' + $report.BlockCounts.PreSplitH2 + ' | split-active H2=' + $report.BlockCounts.SplitActiveH2 + ' | split-archive H2=' + $report.BlockCounts.SplitArchiveH2 + ' | current-active H2=' + $report.BlockCounts.CurrentActiveH2 + ' | current-archive H2=' + $report.BlockCounts.CurrentArchiveH2)
    Write-Host ''
    Write-Host '--- 1a SPLIT-INTEGRITY (multiset-by-hash) ---'
    Write-Host ('missing=' + $report.SplitIntegrity.Missing.Count + '  mutated=' + $report.SplitIntegrity.Mutated.Count + '  duplicated=' + $report.SplitIntegrity.Duplicated.Count)
    Write-Host ('generated-extras (excluded from must-match set, listed separately): ' + $report.SplitIntegrity.GeneratedExtras.Count)
    foreach ($g in $report.SplitIntegrity.GeneratedExtras) { Write-Host ('  - ' + $g.Header) }
    foreach ($m in $report.SplitIntegrity.Missing) { Write-Host ('  MISSING: ' + $m.Header) }
    foreach ($d in $report.SplitIntegrity.Duplicated) { Write-Host ('  DUPLICATED: ' + $d.Header) }
    foreach ($mu in $report.SplitIntegrity.Mutated) { Write-Host ('  MUTATED: ' + $mu.Before.Header + '  ->  ' + $mu.After.Header) }
    Write-Host ''
    Write-Host '--- 1b POST-SPLIT: ACTIVE CONSERVATION (writable queue -- ORDER blocks must be conserved active-or-archive) ---'
    Write-Host ('active-now vs split-active: ' + $report.ActiveConservation.Additions.Count + ' addition(s), ' + $report.ActiveConservation.Mutations.Count + ' mutation(s), ' + $report.ActiveConservation.RemovedNonOrder.Count + ' removed-non-order (allowed), ' + $report.ActiveConservation.OrderLost.Count + ' active-order-lost')
    foreach ($a in $report.ActiveConservation.Additions) { Write-Host ('  ADD: ' + $a.Header) }
    foreach ($m in $report.ActiveConservation.Mutations) { Write-Host ('  MUTATE: ' + $m.Before.Header + '  ->  ' + $m.After.Header) }
    foreach ($r in $report.ActiveConservation.RemovedNonOrder) { Write-Host ('  removed-non-order (ok): ' + $r.Header) }
    foreach ($l in $report.ActiveConservation.OrderLost) { Write-Host ('  ACTIVE-ORDER-LOST(!): ' + $l.Header) }
    Write-Host ''
    Write-Host '--- 1b POST-SPLIT: ARCHIVE APPEND-ONLY LOG (superset by block content; extras allowed) ---'
    Write-Host ('archive-now vs split-archive: append-only clean = ' + $report.ArchiveAppendOnly.IsAppendOnlyClean + ' | missing=' + $report.ArchiveAppendOnly.Missing.Count + ' mutated=' + $report.ArchiveAppendOnly.Mutated.Count + ' post_split_archive_appends=' + $report.ArchiveAppendOnly.PostSplitAppends.Count)
    foreach ($m in $report.ArchiveAppendOnly.Missing) { Write-Host ('  MISSING(!): ' + $m.Header) }
    foreach ($mu in $report.ArchiveAppendOnly.Mutated) { Write-Host ('  MUTATED(!): ' + $mu.Before.Header + '  ->  ' + $mu.After.Header) }
    foreach ($p in $report.ArchiveAppendOnly.PostSplitAppends) { Write-Host ('  post-split append (ok): ' + $p.Header) }
    Write-Host ''
    Write-Host '--- EXCEPTION SCAN (current archive) ---'
    Write-Host ('raw_detected policy exceptions: ' + $report.PolicyExceptions.Count)
    foreach ($e in $report.PolicyExceptions) { Write-Host ('  [' + $e.Kind + '] ' + $e.BlockId + ' :: ' + $e.Detail) }
    Write-Host ''
    Write-Host ('canonically_reviewed (closed, Contract C1 Source A/B): ' + $report.CanonicallyReviewed.Count)
    foreach ($e in $report.CanonicallyReviewed) { Write-Host ('  [' + $e.Kind + '] ' + $e.BlockId + ' :: closed via ' + $e.ClosureSource + ' -- ' + $e.ClosureDetail) }
    Write-Host ''
    Write-Host ('unresolved (raw minus canonically_reviewed): ' + $report.UnresolvedPolicyExceptions.Count)
    foreach ($e in $report.UnresolvedPolicyExceptions) {
        $staleTag = ''
        if ($e.StaleClosureNote) { $staleTag = ' [STALE CLOSURE: ' + $e.StaleClosureNote + ']' }
        Write-Host ('  [' + $e.Kind + '] ' + $e.BlockId + ' :: ' + $e.Detail + $staleTag)
    }
    Write-Host ''
    Write-Host ('integrity failures: ' + $report.IntegrityFailures.Count)
    foreach ($e in $report.IntegrityFailures) {
        $bid = ''; if ($e.PSObject.Properties['BlockId']) { $bid = $e.BlockId }
        $hdr = ''; if ($e.PSObject.Properties['Header']) { $hdr = $e.Header }
        $tag = ''
        if ($bid -or $hdr) { $tag = ' (' + $bid + ' :: ' + $hdr + ')' }
        Write-Host ('  [' + $e.Kind + ']' + $tag + ' ' + $e.Detail)
    }
    Write-Host ''
    Write-Host ('manifest bijection clean:    ' + $report.ManifestBijection.IsClean)
    Write-Host ('index rebuild zero-diff:     ' + $report.IndexRebuildZeroDiff)
    Write-Host ('exceptions rebuild zero-diff: ' + $report.ExceptionsRebuildZeroDiff)
    Write-Host ''
    Write-Host ('EXIT CODE: ' + $report.ExitCode)

    $global:LastCheckReport = $report
    exit $report.ExitCode
}

if ($MyInvocation.InvocationName -ne '.') {
    # ParameterSetName is 'Audit' | 'Strict' | 'Generate' ('Audit' is also the default
    # when the script is invoked with none of -Audit/-Strict/-Generate given).
    Invoke-Main -Mode $PSCmdlet.ParameterSetName
}
