<#
.SYNOPSIS
    ORDER-101 Contract C0 -- READ-ONLY reconcile + validator for the
    AGENT_TASKBOARD.md / ARCHIVE_TASKBOARD_2026-07A.md split.

.DESCRIPTION
    Proves the manual 2026-07-12 taskboard split lost/duplicated/mutated nothing
    (1a split-integrity, multiset-by-hash against committed states), tracks what
    has changed since the split (1b post-split drift), scans the current archive
    for policy/integrity exceptions, and emits a manifest + generated index.

    This script NEVER writes to AGENT_TASKBOARD.md or ARCHIVE_TASKBOARD_2026-07A.md.
    It only reads them (working tree + git history) and writes new artifact files
    under docs/memory_control/.

.PARAMETER Audit
    Report everything. Exit 0 if clean OR only policy exceptions exist.
    Exit 2 if any INTEGRITY/tooling failure exists.

.PARAMETER Strict
    Exit 0 only if fully clean. Exit 1 if any policy exceptions exist (no
    integrity failures). Exit 2 if any INTEGRITY/tooling failure exists.

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
    Do not (re)write ARCHIVE_MANIFEST.csv / ARCHIVE_INDEX.md / RECONCILE_EXCEPTIONS.md.
    Used by negative tests that want to feed a hand-corrupted manifest/index into
    the checker without a normal run overwriting it back to clean first.

.PARAMETER ManifestPath / IndexPath / ExceptionsPath
    Override output artifact locations (tests point these at scripts/_test/fixtures/...).
#>
[CmdletBinding(DefaultParameterSetName = 'Audit')]
param(
    [Parameter(ParameterSetName = 'Audit')]
    [switch]$Audit,

    [Parameter(ParameterSetName = 'Strict')]
    [switch]$Strict,

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

function Invoke-ActiveDriftCheck {
    <#
        Group by (CanonicalId, BlockType) in file order to line up "the Nth ORDER-x
        block" in the split snapshot with "the Nth ORDER-x block" now, even when a
        canonical id has multiple blocks (e.g. ORDER-082 main + ORDER-082 AMENDMENT).
    #>
    param($SplitActiveBlocks, $CurrentActiveBlocks)

    $oldGroups = Group-BlocksByIdType -Blocks $SplitActiveBlocks
    $newGroups = Group-BlocksByIdType -Blocks $CurrentActiveBlocks

    $additions = New-Object System.Collections.Generic.List[object]
    $mutations = New-Object System.Collections.Generic.List[object]
    $removals  = New-Object System.Collections.Generic.List[object]

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
                $removals.Add($old)
            } elseif ($old.Sha256 -ne $new.Sha256) {
                $mutations.Add([pscustomobject]@{ Before = $old; After = $new })
            }
        }
    }

    return [pscustomobject]@{ Additions = $additions; Mutations = $mutations; Removals = $removals }
}

function Invoke-ArchiveDriftCheck {
    param($SplitArchiveBlocks, $CurrentArchiveBlocks)
    # Archive must be append-once after the split -> EXACT multiset equality required.
    $splitMultiset = Get-HashMultiset -Blocks $SplitArchiveBlocks
    $currentMultiset = Get-HashMultiset -Blocks $CurrentArchiveBlocks

    $diffs = New-Object System.Collections.Generic.List[object]
    $allHashesSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in $splitMultiset.Keys) { [void]$allHashesSet.Add($k) }
    foreach ($k in $currentMultiset.Keys) { [void]$allHashesSet.Add($k) }

    foreach ($h in $allHashesSet) {
        $sc = 0; if ($splitMultiset.ContainsKey($h)) { $sc = $splitMultiset[$h].Count }
        $cc = 0; if ($currentMultiset.ContainsKey($h)) { $cc = $currentMultiset[$h].Count }
        if ($sc -ne $cc) { $diffs.Add([pscustomobject]@{ Sha256 = $h; SplitCount = $sc; CurrentCount = $cc }) }
    }
    return [pscustomobject]@{ IsEmpty = ($diffs.Count -eq 0); Diffs = $diffs }
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
            $policyExceptions.Add([pscustomobject]@{
                Kind = 'non-terminal-in-archive'; Severity = 'policy'
                BlockId = $b.BlockId; Header = $b.Header; Detail = "status='$($b.StatusLabel)'"
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
                })
            }
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
                })
            }
        }
    }

    return [pscustomobject]@{ Policy = $policyExceptions.ToArray(); Integrity = $integrityFailures.ToArray() }
}

# ============================================================================
# ARTIFACTS: MANIFEST + INDEX
# ============================================================================

function New-ArchiveManifestRows {
    param($CurrentArchiveBlocks, [string]$SourceCommitSha)
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($b in $CurrentArchiveBlocks) {
        $canon = ''
        if ($b.CanonicalIds.Count -gt 0) { $canon = $b.CanonicalIds[0] }
        $rows.Add([pscustomobject]@{
            block_id      = $b.BlockId
            canonical_id  = $canon
            block_type    = $b.BlockType
            sha256        = $b.Sha256
            source_commit = $SourceCommitSha
            source_anchor = $b.Ordinal
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
        resolves back to exactly one block (by block_id / source_anchor), and
        re-hashing the block named by source_anchor reproduces the row's sha256.
    #>
    param($ManifestRows, $CurrentArchiveBlocks, [string]$ExpectedSourceCommit)

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
        if ($r.source_commit -ne $ExpectedSourceCommit) {
            $failures.Add("source_commit mismatch for block_id=$($r.block_id): manifest=$($r.source_commit) expected=$ExpectedSourceCommit")
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

function Build-ArchiveIndexMarkdown {
    param($ManifestRows, [string]$SourceCommitSha)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# ARCHIVE_INDEX.md')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('> **GENERATED -- read-only -- do not edit.** Derived from `ARCHIVE_MANIFEST.csv` by')
    [void]$sb.AppendLine('> `scripts/check_taskboard_archive.ps1`. Re-running the generator against the same')
    [void]$sb.AppendLine('> manifest reproduces this file byte-for-byte (no timestamps/run-ids embedded).')
    [void]$sb.AppendLine('> Source archive commit: `' + $SourceCommitSha + '`')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| block_id | canonical_id | block_type | source_anchor | sha256 |')
    [void]$sb.AppendLine('|---|---|---|---|---|')
    $sorted = $ManifestRows | Sort-Object { [int]$_.source_anchor }
    foreach ($r in $sorted) {
        [void]$sb.AppendLine('| ' + $r.block_id + ' | ' + $r.canonical_id + ' | ' + $r.block_type + ' | ' + $r.source_anchor + ' | ' + $r.sha256 + ' |')
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
        [bool]$IsStrict,
        [bool]$SkipArtifacts,
        [string]$ManifestPath,
        [string]$IndexPath,
        [string]$ExceptionsPath
    )

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

    $activeDrift = Invoke-ActiveDriftCheck -SplitActiveBlocks $activeSplitBlocks -CurrentActiveBlocks $activeCurrentBlocks
    $archiveDrift = Invoke-ArchiveDriftCheck -SplitArchiveBlocks $archiveSplitBlocks -CurrentArchiveBlocks $archiveCurrentBlocks
    $report.ActiveDrift = $activeDrift
    $report.ArchiveDrift = $archiveDrift

    $exceptions = Invoke-ExceptionScan -CurrentActiveBlocks $activeCurrentBlocks -CurrentArchiveBlocks $archiveCurrentBlocks
    $report.Exceptions = $exceptions

    $integrityFailures = New-Object System.Collections.Generic.List[object]
    foreach ($f in $exceptions.Integrity) { $integrityFailures.Add($f) }

    if ($splitIntegrity.Missing.Count -gt 0) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'split-integrity-missing'; Severity = 'integrity'; Detail = "$($splitIntegrity.Missing.Count) pre-split block(s) missing from split active+archive union" })
    }
    if ($splitIntegrity.Mutated.Count -gt 0) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'split-integrity-mutated'; Severity = 'integrity'; Detail = "$($splitIntegrity.Mutated.Count) block(s) mutated across the split" })
    }
    if ($splitIntegrity.Duplicated.Count -gt 0) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'split-integrity-duplicated'; Severity = 'integrity'; Detail = "$($splitIntegrity.Duplicated.Count) block(s) duplicated across the split" })
    }
    if ($activeDrift.Removals.Count -gt 0) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'active-drift-unexpected-removal'; Severity = 'integrity'; Detail = "$($activeDrift.Removals.Count) block(s) present at split but missing from current active board" })
    }
    if (-not $archiveDrift.IsEmpty) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'archive-not-append-only'; Severity = 'integrity'; Detail = "archive diverged from split-time content: $($archiveDrift.Diffs.Count) hash-count mismatch(es)" })
    }

    $currentCommit = (& git -C $RepoRoot rev-parse HEAD 2>$null)
    if (-not $currentCommit) { $currentCommit = 'UNKNOWN' } else { $currentCommit = $currentCommit.Trim() }
    $manifestRows = @(New-ArchiveManifestRows -CurrentArchiveBlocks $archiveCurrentBlocks -SourceCommitSha $currentCommit)

    if (-not $SkipArtifacts) {
        Write-ArchiveManifestCsv -Rows $manifestRows -Path $ManifestPath
    }
    # Re-read whatever is actually on disk at $ManifestPath for bijection-checking --
    # this is what lets negative tests hand-corrupt the CSV and have the checker see it.
    $manifestOnDisk = @(Import-Csv -Path $ManifestPath)
    $bijection = Test-ManifestBijection -ManifestRows $manifestOnDisk -CurrentArchiveBlocks $archiveCurrentBlocks -ExpectedSourceCommit $currentCommit
    $report.ManifestBijection = $bijection
    if (-not $bijection.IsClean) {
        foreach ($f in $bijection.Failures) { $integrityFailures.Add([pscustomobject]@{ Kind = 'manifest-bijection'; Severity = 'integrity'; Detail = $f }) }
    }

    $indexText = Build-ArchiveIndexMarkdown -ManifestRows $manifestOnDisk -SourceCommitSha $currentCommit
    if (-not $SkipArtifacts) {
        Write-TextFileLfNoBom -Path $IndexPath -Text $indexText
    }
    if (Test-Path $IndexPath) {
        $onDiskIndexBytes = [System.IO.File]::ReadAllBytes($IndexPath)
        $onDiskIndexText = Get-NormalizedTextFromBytes -Bytes $onDiskIndexBytes
        $rebuiltNormalized = $indexText.Replace("`r`n", "`n").Replace("`r", "`n")
        $indexZeroDiff = ($onDiskIndexText -eq $rebuiltNormalized)
    } else {
        $indexZeroDiff = $false
    }
    $report.IndexRebuildZeroDiff = $indexZeroDiff
    if (-not $indexZeroDiff) {
        $integrityFailures.Add([pscustomobject]@{ Kind = 'index-rebuild-not-zero-diff'; Severity = 'integrity'; Detail = 'ARCHIVE_INDEX.md on disk does not match a fresh rebuild from the manifest (stale index)' })
    }

    $report.IntegrityFailures = $integrityFailures.ToArray()
    $report.PolicyExceptions = @($exceptions.Policy)

    if ($integrityFailures.Count -gt 0) {
        $exitCode = $script:EXIT_INTEGRITY
    } elseif ($IsStrict -and $exceptions.Policy.Count -gt 0) {
        $exitCode = $script:EXIT_POLICY
    } else {
        $exitCode = $script:EXIT_OK
    }
    $report.ExitCode = $exitCode

    return $report
}

function Write-ExceptionsMarkdown {
    param($Report, [string]$Path)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# RECONCILE_EXCEPTIONS.md')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('> Generated by `scripts/check_taskboard_archive.ps1` (ORDER-101 Contract C0).')
    [void]$sb.AppendLine('> **Worker does not resolve or move anything here.** Every row below needs an Opus')
    [void]$sb.AppendLine('> (or user) classification decision. This file is regenerated on each run -- do not')
    [void]$sb.AppendLine('> hand-edit it; land Opus decisions in PROJECT_STATE.md / the taskboard instead.')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Policy exceptions (severity 1 -- worker may not resolve)')
    [void]$sb.AppendLine('')
    if ($Report.PolicyExceptions.Count -eq 0) {
        [void]$sb.AppendLine('_None found._')
    } else {
        [void]$sb.AppendLine('| kind | block_id | header | detail |')
        [void]$sb.AppendLine('|---|---|---|---|')
        foreach ($e in $Report.PolicyExceptions) {
            $header = $e.Header.Replace('|', '\|')
            $detail = $e.Detail.Replace('|', '\|')
            [void]$sb.AppendLine('| ' + $e.Kind + ' | ' + $e.BlockId + ' | ' + $header + ' | ' + $detail + ' |')
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
            $bid = ''; if ($e.PSObject.Properties['BlockId']) { $bid = $e.BlockId }
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
    [void]$sb.AppendLine('- Review linking in the exception scan above is done at **canonical-id granularity**,')
    [void]$sb.AppendLine('  not full block_id-level many-to-many. See the final report deviations note for why.')
    [void]$sb.AppendLine('')
    Write-TextFileLfNoBom -Path $Path -Text $sb.ToString()
}

# ============================================================================
# ENTRY POINT (guarded so dot-sourcing this file for its functions, e.g. from a
# test harness, does not also run the real-repo Main pass)
# ============================================================================

function Invoke-Main {
    param([bool]$IsStrict)

    if (-not $CurrentActiveSource)  { $script:CurrentActiveSource  = 'FILE:' + (Join-Path $RepoRoot 'AGENT_TASKBOARD.md') }
    if (-not $CurrentArchiveSource) { $script:CurrentArchiveSource = 'FILE:' + (Join-Path $RepoRoot 'ARCHIVE_TASKBOARD_2026-07A.md') }
    if (-not $ManifestPath)   { $script:ManifestPath = Join-Path $RepoRoot 'docs/memory_control/ARCHIVE_MANIFEST.csv' }
    if (-not $IndexPath)      { $script:IndexPath = Join-Path $RepoRoot 'docs/memory_control/ARCHIVE_INDEX.md' }
    if (-not $ExceptionsPath) { $script:ExceptionsPath = Join-Path $RepoRoot 'docs/memory_control/RECONCILE_EXCEPTIONS.md' }

    $report = Invoke-TaskboardArchiveCheck -RepoRoot $RepoRoot `
        -PreSplitSource $PreSplitSource -SplitActiveSource $SplitActiveSource -SplitArchiveSource $SplitArchiveSource `
        -CurrentActiveSource $CurrentActiveSource -CurrentArchiveSource $CurrentArchiveSource `
        -IsStrict $IsStrict -SkipArtifacts $SkipArtifacts.IsPresent `
        -ManifestPath $ManifestPath -IndexPath $IndexPath -ExceptionsPath $ExceptionsPath

    if (-not $SkipArtifacts) {
        Write-ExceptionsMarkdown -Report $report -Path $ExceptionsPath
    }

    $modeLabel = 'AUDIT'
    if ($IsStrict) { $modeLabel = 'STRICT' }
    Write-Host "=== check_taskboard_archive.ps1 [$modeLabel] ==="
    Write-Host ('Pre-state hash  AGENT_TASKBOARD.md            = ' + $report.PreStateHashes.CurrentActiveFileSha256)
    Write-Host ('Pre-state hash  ARCHIVE_TASKBOARD_2026-07A.md = ' + $report.PreStateHashes.CurrentArchiveFileSha256)
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
    Write-Host '--- 1b POST-SPLIT DRIFT ---'
    Write-Host ('active-now vs split-active: ' + $report.ActiveDrift.Additions.Count + ' addition(s), ' + $report.ActiveDrift.Mutations.Count + ' mutation(s), ' + $report.ActiveDrift.Removals.Count + ' unexpected removal(s)')
    foreach ($a in $report.ActiveDrift.Additions) { Write-Host ('  ADD: ' + $a.Header) }
    foreach ($m in $report.ActiveDrift.Mutations) { Write-Host ('  MUTATE: ' + $m.Before.Header + '  ->  ' + $m.After.Header) }
    foreach ($r in $report.ActiveDrift.Removals) { Write-Host ('  REMOVED(!): ' + $r.Header) }
    Write-Host ('archive-now vs split-archive: empty diff = ' + $report.ArchiveDrift.IsEmpty)
    Write-Host ''
    Write-Host '--- EXCEPTION SCAN (current archive) ---'
    Write-Host ('policy exceptions: ' + $report.PolicyExceptions.Count)
    foreach ($e in $report.PolicyExceptions) { Write-Host ('  [' + $e.Kind + '] ' + $e.BlockId + ' :: ' + $e.Detail) }
    Write-Host ('integrity failures: ' + $report.IntegrityFailures.Count)
    foreach ($e in $report.IntegrityFailures) {
        $bid = ''; if ($e.PSObject.Properties['BlockId']) { $bid = $e.BlockId }
        $hdr = ''; if ($e.PSObject.Properties['Header']) { $hdr = $e.Header }
        $tag = ''
        if ($bid -or $hdr) { $tag = ' (' + $bid + ' :: ' + $hdr + ')' }
        Write-Host ('  [' + $e.Kind + ']' + $tag + ' ' + $e.Detail)
    }
    Write-Host ''
    Write-Host ('manifest bijection clean: ' + $report.ManifestBijection.IsClean)
    Write-Host ('index rebuild zero-diff:  ' + $report.IndexRebuildZeroDiff)
    Write-Host ''
    Write-Host ('EXIT CODE: ' + $report.ExitCode)

    $global:LastCheckReport = $report
    exit $report.ExitCode
}

if ($MyInvocation.InvocationName -ne '.') {
    $script:IsStrictMode = ($PSCmdlet.ParameterSetName -eq 'Strict')
    Invoke-Main -IsStrict $script:IsStrictMode
}
