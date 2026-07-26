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
    CANONICALLY REVIEWED (Contract C1: closed by an exact Source-A binding record or
    a C1-CLOSURE row; see the CONTRACT C1 section below), not merely "zero raw
    exceptions". Exit 1 if any UNRESOLVED policy exception remains (raw minus
    canonically-reviewed; no integrity failures). Exit 2 if any INTEGRITY/tooling
    failure exists.

.NOTES (CONTRACT C1 -- CANONICAL REVIEW LINKAGE, ORDER-102)
    A raw policy exception from the exception scan can be closed two ways, both
    READ-ONLY and both reported separately (raw_detected / canonically_reviewed /
    unresolved counts, never silently merged):
      Source A -- EXACT BINDING RECORD: an appended
        '## C1-ENFORCE-SOURCEA-BINDING' block closes only the ONE raw exception
        whose exact (kind, block_id, block_sha256) tuple matches its binding row.
        A sha mismatch is STALE (reported, not honored); canonical id or a bare
        REVIEW-block match is never a wildcard closure.
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
    [string]$ExceptionsPath = '',

    # ORDER-103 Fix 1: append-CHAIN integrity gate (checkpoint-pinned, first-parent).
    [string]$ChainCheckpointSha = '0ced19485c6c6ce9a23541f785ab82bae4fcad25',
    [string]$ChainArchivePath = 'ARCHIVE_TASKBOARD_2026-07A.md',
    [switch]$SkipChainCheck
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

# ORDER-260: the same vocabulary anchored to the start of a backtick status span, used
# when a header HAS backticks (the normal case). Precomputed once rather than rebuilt on
# every Get-StatusClass call -- .NET's Regex cache is 15 entries by default and this file
# already exceeds that, so per-call string construction risked recompiling on every block.
# See Get-StatusClass for why anchoring is the correct rule and why the no-backtick
# fallback deliberately stays unanchored.
$script:NonTerminalPatternsAnchored = @(
    $script:NonTerminalPatternsOrdered | ForEach-Object { '^[^A-Za-z]*' + $_ + '\b' }
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

function Get-GitFilteredBlobBytes {
    <# Materialize a committed blob exactly as Git would place it in the working
       tree for $Path (attributes + checkout filters, including autocrlf). This
       lets working-tree integrity checks compare raw bytes without treating the
       checkout's legitimate smudge conversion as tamper. #>
    param([string]$RepoRoot, [string]$Ref, [string]$Path)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = 'cat-file --filters --path="{0}" "{1}:{0}"' -f $Path, $Ref
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
        throw ('git cat-file --filters {0}:{1} failed (exit {2}): {3}' -f $Ref, $Path, $proc.ExitCode, $stderrText)
    }
    return $ms.ToArray()
}

function Get-SourceBytes {
    param([string]$RepoRoot, [string]$SourceSpec)
    # An empty ref is the git-index/staged snapshot: GIT::<path> maps to
    # `git show :<path>`.  This keeps the bytes and identity tied to the exact
    # object that a pending commit will contain instead of mixing FILE bytes
    # with HEAD:<path> identity.
    if ($SourceSpec -match '^GIT:(.*?):(.+)$') {
        return Get-GitBlobBytes -RepoRoot $RepoRoot -Ref $Matches[1] -Path $Matches[2]
    } elseif ($SourceSpec -match '^FILE:(.+)$') {
        return [System.IO.File]::ReadAllBytes($Matches[1])
    } else {
        throw "Unrecognized source spec (expected GIT:ref:path, GIT::path for staged content, or FILE:path): $SourceSpec"
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
        - SourceSpec "GIT::<path>"       -> staged/index identity via `git rev-parse :<path>`.
        - SourceSpec "FILE:<abs-path>"   -> path is made repo-relative and resolved
          as `git rev-parse HEAD:<rel-path>` (the working-tree file must be committed;
          this is the normal real-repo case where CurrentArchiveSource defaults to
          FILE:<RepoRoot>/ARCHIVE_TASKBOARD_2026-07A.md).
    #>
    param([string]$RepoRoot, [string]$SourceSpec)

    if ($SourceSpec -match '^GIT:(.*?):(.+)$') {
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
        throw "Get-ArchiveContentIdentity: unrecognized source spec (expected GIT:ref:path, GIT::path for staged content, or FILE:path): $SourceSpec"
    }

    $spec = '{0}:{1}' -f $ref, $relPath
    $out = & git -C $RepoRoot rev-parse $spec 2>$null
    if (-not $out) {
        throw "Get-ArchiveContentIdentity: 'git rev-parse $spec' failed -- is the archive file committed at that ref/path?"
    }
    return ([string]$out).Trim()
}

# ============================================================================
# ORDER-103 Fix 4 -- SINGLE SNAPSHOT-SOURCE IDENTITY
#
# Problem this closes: the old FILE:/GIT: split had BYTES coming from one place
# (working-tree file / a git blob) and IDENTITY coming from another (always
# Get-ArchiveContentIdentity, which for a FILE: source resolves via HEAD:<path>
# -- i.e. the COMMITTED blob, not the working-tree bytes actually being hashed).
# That mixed-source design is fine for C0 Audit/Strict (deliberately left
# unchanged below -- see the .NOTES on Get-ArchiveContentIdentity) but is unsafe
# for the append-CHAIN gate (Fix 1) and the pre-commit hook (Fix 2), which must
# reason about the STAGED candidate specifically: bytes and identity have to be
# the *same* git object, not two different reads that can diverge (e.g. a clean
# filter normalizing CRLF->LF on `git add` while a naive `git hash-object
# <working-file>` would hash the raw un-normalized working-tree bytes instead).
#
# Get-Snapshot below is the one primitive both Fix 1 (chain walk) and Fix 2
# (hook) use. It always reads BYTES and IDENTITY from the SAME underlying git
# object:
#   Staged    -> bytes = `git show :<path>`         identity = `git rev-parse :<path>`
#   Committed -> bytes = `git show <sha>:<path>`     identity = `git rev-parse <sha>:<path>`
#   Working   -> bytes = raw file bytes off disk     identity = `git hash-object <file>`
#                (Working is provided for completeness/diagnostics only -- Fix 1's
#                chain walk and Fix 2's hook both use Staged, never Working, for
#                exactly the CRLF/clean-filter reason above; see the CRLF-parity
#                negTest.)
# ============================================================================

function Invoke-GitRaw {
    <# Generic `git <args>` runner (RepoRoot as cwd), returns ExitCode/StdOut/StdErr.
       Used by every Fix 1/Fix 4 git primitive below so they share one process-spawn
       implementation instead of each hand-rolling ProcessStartInfo. #>
    param([string]$RepoRoot, [string]$Arguments)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $RepoRoot
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [pscustomobject]@{ ExitCode = $proc.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

function Get-GitObjectId {
    <# `git rev-parse <spec>` (e.g. ":path", "<sha>:path", "<sha>") -> trimmed 40-char sha. #>
    param([string]$RepoRoot, [string]$Spec)
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -Arguments ('rev-parse "{0}"' -f $Spec)
    if ($r.ExitCode -ne 0) { throw "git rev-parse $Spec failed (exit $($r.ExitCode)): $($r.StdErr)" }
    $val = $r.StdOut.Trim()
    if (-not $val) { throw "git rev-parse $Spec returned empty output" }
    return $val
}

function Get-GitHashObjectId {
    <# `git hash-object -- <relpath>` against the RAW working-tree bytes (no clean
       filter applied) -- provided for the Working snapshot mode / diagnostics only.
       NOT used by Fix 1 chain walk or Fix 2 hook (see module doc comment above). #>
    param([string]$RepoRoot, [string]$RelPath)
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -Arguments ('hash-object -- "{0}"' -f $RelPath)
    if ($r.ExitCode -ne 0) { throw "git hash-object $RelPath failed (exit $($r.ExitCode)): $($r.StdErr)" }
    return $r.StdOut.Trim()
}

function Get-Snapshot {
    <#
        ORDER-103 Fix 4 primitive. Returns [pscustomobject]@{ Bytes; Identity; Mode }
        where Bytes and Identity always come from the SAME git object (never a
        working-tree read paired with a committed-ref identity, or vice versa).
    #>
    param(
        [string]$RepoRoot,
        [ValidateSet('Staged', 'Committed', 'Working')]
        [string]$Mode,
        [string]$RelPath,
        [string]$CommitSha = ''
    )
    switch ($Mode) {
        'Staged' {
            $bytes = Get-GitBlobBytes -RepoRoot $RepoRoot -Ref '' -Path $RelPath
            $identity = Get-GitObjectId -RepoRoot $RepoRoot -Spec (':{0}' -f $RelPath)
        }
        'Committed' {
            if (-not $CommitSha) { throw 'Get-Snapshot -Mode Committed requires -CommitSha' }
            $bytes = Get-GitBlobBytes -RepoRoot $RepoRoot -Ref $CommitSha -Path $RelPath
            $identity = Get-GitObjectId -RepoRoot $RepoRoot -Spec ('{0}:{1}' -f $CommitSha, $RelPath)
        }
        'Working' {
            $fullPath = Join-Path $RepoRoot $RelPath
            $bytes = [System.IO.File]::ReadAllBytes($fullPath)
            $identity = Get-GitHashObjectId -RepoRoot $RepoRoot -RelPath $RelPath
        }
    }
    return [pscustomobject]@{ Bytes = $bytes; Identity = $identity; Mode = $Mode }
}

# ============================================================================
# ORDER-103 Fix 1 -- APPEND-CHAIN INTEGRITY (checkpoint-pinned, first-parent,
# raw-byte prefix-chain)
# ============================================================================

function Test-BytePrefix {
    <# True iff $Prefix's bytes are byte-identical to the leading $Prefix.Length
       bytes of $Full (Full may be longer -- that's the "extension" case). #>
    param([byte[]]$Prefix, [byte[]]$Full)
    if ($Prefix.Length -gt $Full.Length) { return $false }
    for ($i = 0; $i -lt $Prefix.Length; $i++) {
        if ($Prefix[$i] -ne $Full[$i]) { return $false }
    }
    return $true
}

function Test-SuffixOpensNewH2Block {
    <# An appended archive block may be separated from the preceding block by
       blank lines and at most one Markdown horizontal-rule line (`---`). The
       first remaining line must be a column-zero H2 heading. Anything else is
       prose/a table row/etc. extending the prior final block and must fail. #>
    param([string]$NormalizedSuffixText)

    $seenHorizontalRule = $false
    foreach ($line in ($NormalizedSuffixText -split "`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.Trim() -eq '---') {
            if ($seenHorizontalRule) { return $false }
            $seenHorizontalRule = $true
            continue
        }
        return $line.StartsWith('## ')
    }
    return $false
}

function Test-IsArchiveInterBlockSeparator {
    <# True when the whole text is only the permitted separator region between
       two H2 blocks: blank lines and at most one `---` line. #>
    param([string]$Text)
    if ($Text.Length -eq 0) { return $true }
    $seenHorizontalRule = $false
    foreach ($line in ($Text -split "`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.Trim() -eq '---') {
            if ($seenHorizontalRule) { return $false }
            $seenHorizontalRule = $true
            continue
        }
        return $false
    }
    return $true
}

function Test-GitIsAncestor {
    param([string]$RepoRoot, [string]$AncestorSha, [string]$Ref)
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -Arguments ('merge-base --is-ancestor "{0}" "{1}"' -f $AncestorSha, $Ref)
    if ($r.ExitCode -eq 0) { return $true }
    if ($r.ExitCode -eq 1) { return $false }
    throw "git merge-base --is-ancestor $AncestorSha $Ref failed unexpectedly (exit $($r.ExitCode)): $($r.StdErr)"
}

function Test-GitCommitObjectExists {
    param([string]$RepoRoot, [string]$Sha)
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -Arguments ('cat-file -e "{0}^{{commit}}"' -f $Sha)
    return ($r.ExitCode -eq 0)
}

function Get-GitFirstParentChain {
    <# Ordered array of full SHAs from $FromSha through $ToRef, inclusive, using
       only the literal first-parent line of $ToRef. An any-path ancestor is not
       sufficient: $FromSha itself must appear in that line. #>
    param([string]$RepoRoot, [string]$FromSha, [string]$ToRef)
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -Arguments ('rev-list --first-parent --reverse "{0}"' -f $ToRef)
    if ($r.ExitCode -ne 0) { throw "git rev-list --first-parent --reverse $ToRef failed (exit $($r.ExitCode)): $($r.StdErr)" }
    $line = @($r.StdOut -split "`r?`n" | Where-Object { $_ -ne '' })
    $checkpointIndex = -1
    for ($i = 0; $i -lt $line.Count; $i++) {
        if ([string]::Equals($line[$i], $FromSha, [System.StringComparison]::Ordinal)) {
            $checkpointIndex = $i
            break
        }
    }
    if ($checkpointIndex -lt 0) {
        throw "TRUSTED CHECKPOINT $FromSha is not a literal member of git rev-list --first-parent $ToRef"
    }
    return @($line[$checkpointIndex..($line.Count - 1)])
}

function Get-GitCommitParents {
    <# Returns a commit's parent SHAs in Git's recorded order (first parent first).
       Merge handling deliberately uses this order because ORDER-103 defines the
       checkpoint walk by first-parent semantics. #>
    param([string]$RepoRoot, [string]$CommitSha)
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -Arguments ('rev-list --parents -n 1 "{0}"' -f $CommitSha)
    if ($r.ExitCode -ne 0) { throw "git rev-list --parents -n 1 $CommitSha failed (exit $($r.ExitCode)): $($r.StdErr)" }
    $parts = @($r.StdOut.Trim() -split '\s+' | Where-Object { $_ })
    if ($parts.Count -eq 0 -or $parts[0] -ne $CommitSha) {
        throw "git rev-list --parents returned an unexpected row for ${CommitSha}: '$($r.StdOut.Trim())'"
    }
    if ($parts.Count -le 1) { return @() }
    return @($parts[1..($parts.Count - 1)])
}

function Invoke-ArchiveChainIntegrityCheck {
    <#
        ORDER-103 Fix 1. Walks the FIRST-PARENT commit chain from the TRUSTED
        CHECKPOINT to $HeadRef (optionally one further synthetic step to the
        STAGED index snapshot, for the pre-commit hook -- Fix 2/-IncludeStaged),
        over the archive file, and requires every step's archive bytes to be a
        raw-byte PREFIX-EXTENSION of the previous step's archive bytes, where any
        non-empty suffix must open a NEW '## ' (H2) block boundary (a suffix that
        only extends/mutates the meaning of the prior last block is rejected).

        Merge rule (explicit first-parent DAG semantics): merges may exist in the
        first-parent walk, but a merge commit MUST NOT change the archive relative
        to its first parent. Legitimate archive appends are plain non-merge commits;
        rejecting archive-changing merges prevents content from entering through a
        non-first parent without being validated as a first-parent append.

        FAIL-CLOSED (IsClean=$false) on: checkpoint object missing (shallow clone
        lacking it, or wrong SHA); checkpoint not an ancestor of $HeadRef (history
        rewrite/force-push/squash); checkpoint reachable only outside $HeadRef's
        literal first-parent line; any git command failure; archive path unreadable
        at any step (renamed/deleted mid-chain); a non-prefix mutation at any step;
        a suffix that does not open a new H2 boundary. A fresh full clone passes; a
        detached HEAD with full ancestry passes (detached-ness alone is never a
        failure reason).

        Threat-model boundary (documented, not silently promised): this defends
        against tamper-then-regenerate within reachable history rooted at the
        checkpoint, and detects checkpoint-severing history rewrites. It does NOT
        guarantee safety against an attacker who controls the remote and force-
        pushes a rewritten line that also rewrites/removes the checkpoint commit
        itself out of every clone's reachable history -- that requires a
        protected ref / signed checkpoint / external receipt, out of scope here.
    #>
    param(
        [string]$RepoRoot,
        [string]$CheckpointSha,
        [string]$ArchiveRelPath,
        [string]$HeadRef = 'HEAD',
        [switch]$IncludeStaged
    )

    if (-not (Test-GitCommitObjectExists -RepoRoot $RepoRoot -Sha $CheckpointSha)) {
        return [pscustomobject]@{ IsClean = $false; Reason = "TRUSTED CHECKPOINT $CheckpointSha not found as a commit object in this repository (missing/wrong SHA, or a shallow clone that does not carry it) -- fail-closed"; Steps = @(); IsShallow = $null }
    }

    $isShallowResult = Invoke-GitRaw -RepoRoot $RepoRoot -Arguments 'rev-parse --is-shallow-repository'
    $isShallow = ($isShallowResult.ExitCode -eq 0) -and ($isShallowResult.StdOut.Trim() -eq 'true')

    $ancestorOk = $false
    try {
        $ancestorOk = Test-GitIsAncestor -RepoRoot $RepoRoot -AncestorSha $CheckpointSha -Ref $HeadRef
    } catch {
        return [pscustomobject]@{ IsClean = $false; Reason = "checkpoint-ancestry check failed: $($_.Exception.Message)"; Steps = @(); IsShallow = $isShallow }
    }
    if (-not $ancestorOk) {
        return [pscustomobject]@{ IsClean = $false; Reason = "TRUSTED CHECKPOINT $CheckpointSha is NOT an ancestor of $HeadRef -- history rewrite/force-push/squash suspected (fail-closed)"; Steps = @(); IsShallow = $isShallow }
    }

    $chain = $null
    try {
        $chain = Get-GitFirstParentChain -RepoRoot $RepoRoot -FromSha $CheckpointSha -ToRef $HeadRef
    } catch {
        if ($_.Exception.Message -match 'not a literal member of git rev-list --first-parent') {
            return [pscustomobject]@{ IsClean = $false; Reason = "TRUSTED CHECKPOINT $CheckpointSha is reachable only via a non-first-parent path relative to $HeadRef (for example, a merge's second parent) -- rejected, possible checkpoint laundering (fail-closed)"; Steps = @(); IsShallow = $isShallow }
        }
        return [pscustomobject]@{ IsClean = $false; Reason = "first-parent chain walk failed: $($_.Exception.Message)"; Steps = @(); IsShallow = $isShallow }
    }
    if ($IncludeStaged) { $chain = @($chain) + @('STAGED') }

    $steps = New-Object System.Collections.Generic.List[object]

    for ($i = 1; $i -lt $chain.Count; $i++) {
        $prevSha = $chain[$i - 1]
        $curSha  = $chain[$i]

        try {
            $prevBytes = if ($prevSha -eq 'STAGED') { Get-GitBlobBytes -RepoRoot $RepoRoot -Ref '' -Path $ArchiveRelPath } else { Get-GitBlobBytes -RepoRoot $RepoRoot -Ref $prevSha -Path $ArchiveRelPath }
        } catch {
            return [pscustomobject]@{ IsClean = $false; Reason = "archive path '$ArchiveRelPath' not readable at $prevSha (renamed/deleted mid-chain?): $($_.Exception.Message)"; Steps = $steps.ToArray(); IsShallow = $isShallow }
        }
        try {
            $curBytes = if ($curSha -eq 'STAGED') { Get-GitBlobBytes -RepoRoot $RepoRoot -Ref '' -Path $ArchiveRelPath } else { Get-GitBlobBytes -RepoRoot $RepoRoot -Ref $curSha -Path $ArchiveRelPath }
        } catch {
            return [pscustomobject]@{ IsClean = $false; Reason = "archive path '$ArchiveRelPath' not readable at $curSha (renamed/deleted mid-chain?): $($_.Exception.Message)"; Steps = $steps.ToArray(); IsShallow = $isShallow }
        }

        if ($curSha -ne 'STAGED') {
            try {
                $parents = @(Get-GitCommitParents -RepoRoot $RepoRoot -CommitSha $curSha)
            } catch {
                return [pscustomobject]@{ IsClean = $false; Reason = "merge-parent inspection failed at ${curSha}: $($_.Exception.Message)"; Steps = $steps.ToArray(); IsShallow = $isShallow }
            }
            if ($parents.Count -gt 1) {
                if ($parents[0] -ne $prevSha) {
                    return [pscustomobject]@{ IsClean = $false; Reason = "first-parent chain mismatch at merge commit $curSha (walker previous=$prevSha, recorded first parent=$($parents[0])) -- fail-closed"; Steps = $steps.ToArray(); IsShallow = $isShallow }
                }
                $mergeArchiveUnchanged = (($prevBytes.Length -eq $curBytes.Length) -and (Test-BytePrefix -Prefix $prevBytes -Full $curBytes))
                if (-not $mergeArchiveUnchanged) {
                    return [pscustomobject]@{ IsClean = $false; Reason = "archive changed via merge commit $curSha relative to first parent $prevSha -- rejected (merges must not change the archive; content may have arrived via a non-first-parent)"; Steps = $steps.ToArray(); IsShallow = $isShallow }
                }
            }
        }

        if (($prevBytes.Length -eq $curBytes.Length) -and (Test-BytePrefix -Prefix $prevBytes -Full $curBytes)) {
            $steps.Add([pscustomobject]@{ From = $prevSha; To = $curSha; Changed = $false })
            continue
        }

        if ($curBytes.Length -lt $prevBytes.Length) {
            return [pscustomobject]@{ IsClean = $false; Reason = "archive shrank from $prevSha ($($prevBytes.Length) bytes) to $curSha ($($curBytes.Length) bytes) -- truncation/removal detected (fail-closed)"; Steps = $steps.ToArray(); IsShallow = $isShallow }
        }

        if (-not (Test-BytePrefix -Prefix $prevBytes -Full $curBytes)) {
            return [pscustomobject]@{ IsClean = $false; Reason = "archive at $curSha is NOT a raw-byte prefix-extension of $prevSha -- earlier bytes were mutated (fail-closed; manifest regeneration cannot bless this)"; Steps = $steps.ToArray(); IsShallow = $isShallow }
        }

        $suffixBytes = New-Object 'byte[]' ($curBytes.Length - $prevBytes.Length)
        [Array]::Copy($curBytes, $prevBytes.Length, $suffixBytes, 0, $suffixBytes.Length)
        $suffixText = Get-NormalizedTextFromBytes -Bytes $suffixBytes
        if (-not (Test-SuffixOpensNewH2Block -NormalizedSuffixText $suffixText)) {
            return [pscustomobject]@{ IsClean = $false; Reason = "archive suffix added between $prevSha and $curSha does not open with a new '## ' (H2) block boundary -- looks like it extends/mutates the prior final block's meaning (fail-closed)"; Steps = $steps.ToArray(); IsShallow = $isShallow }
        }

        $steps.Add([pscustomobject]@{ From = $prevSha; To = $curSha; Changed = $true; AddedBytes = ($curBytes.Length - $prevBytes.Length) })
    }

    return [pscustomobject]@{ IsClean = $true; Reason = $null; Steps = $steps.ToArray(); IsShallow = $isShallow; ChainLength = $chain.Count }
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

    # ORDER-260 fix. The non-terminal vocabulary is matched ANCHORED to the start of a
    # backtick status span, not as a bare substring anywhere inside it.
    #
    # Unanchored and case-insensitive, 'HOLD' matched inside "holdout" and 'OPEN' inside
    # "open question". So a status of
    #     `REVIEWED(Claude/Opus 2026-07-23) -- 4/5 cells died at holdout`
    # classified NonTerminal, label "hold". Measured 2026-07-26: of ~45 headers whose
    # status verb genuinely is REVIEWED, only 22 were Terminal; 17 were lost to this
    # exactly. Those orders were unarchivable for describing their own results, and
    # because StatusClass feeds the whole exception scan, the validator's picture of the
    # board was wrong in the same direction.
    #
    # Anchoring is the correct rule, not a patch: by the board's own convention the
    # status verb is the FIRST token of the backtick span. Leading non-letters are
    # skipped so an emoji-prefixed status still matches. \b at the end keeps
    # OPEN-STANDING and WAITING-USER matching while rejecting "holdout".
    #
    # The no-backtick fallback stays UNANCHORED on purpose: there the search space is
    # the entire header, where the verb never sits at position 0 (the header starts
    # "ORDER-091C-D1e -- ..."), so anchoring would silently stop classifying it.
    # Anchored variants are precomputed ONCE at script scope
    # ($script:NonTerminalPatternsAnchored), not rebuilt per call. .NET's Regex cache
    # holds only 15 patterns by default; this file already uses more than that, so
    # constructing 6 fresh pattern strings on every Get-StatusClass call risked
    # thrashing the cache into recompiling regexes for every block.
    $anchorNonTerminal = ($backtickMatches.Count -gt 0)
    if ($anchorNonTerminal) { $ntPatterns = $script:NonTerminalPatternsAnchored }
    else                    { $ntPatterns = $script:NonTerminalPatternsOrdered }
    foreach ($s in $searchSpaces) {
        foreach ($pat in $ntPatterns) {
            if ($s -match $pat) { return [pscustomobject]@{ Class = 'NonTerminal'; Label = $Matches[0].Trim() } }
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

function Get-BytesBeforeFirstH2 {
    <# Returns every raw byte before the first column-zero `## ` heading. The
       pre-H2 region is not part of any parsed block and is never appendable; it
       therefore needs its own comparison. If no H2 exists, the whole file is
       preamble. #>
    param([byte[]]$Bytes)
    $start = -1
    for ($i = 0; $i -le ($Bytes.Length - 3); $i++) {
        $atLineStart = ($i -eq 0) -or ($Bytes[$i - 1] -eq 10)
        if ($atLineStart -and $Bytes[$i] -eq 35 -and $Bytes[$i + 1] -eq 35 -and $Bytes[$i + 2] -eq 32) {
            $start = $i
            break
        }
    }
    $length = if ($start -ge 0) { $start } else { $Bytes.Length }
    $result = New-Object 'byte[]' $length
    if ($length -gt 0) { [Array]::Copy($Bytes, 0, $result, 0, $length) }
    return $result
}

function Invoke-ArchiveWorkingTreeExtensionCheck {
    <# ORDER-103 rework, BLOCKER 1: close checkpoint->HEAD->working durability.
       The committed chain remains raw-byte exact. This final HEAD->working leg
       deliberately compares canonical-LF H2 block hashes because a checkout may
       be CRLF/mixed while the git blob is LF (core.autocrlf=true). Every HEAD H2
       block must remain byte-identical after LF normalization and in the same
       ordinal position; only whole trailing blocks may be added. Bytes before
       the first H2 are outside the parser and must match byte-for-byte against
       HEAD materialized through Git's own checkout filters. #>
    param(
        [string]$RepoRoot,
        [string]$ArchiveRelPath,
        [byte[]]$CurrentBytes
    )

    try {
        $headBytes = Get-GitBlobBytes -RepoRoot $RepoRoot -Ref 'HEAD' -Path $ArchiveRelPath
        $headCheckoutBytes = Get-GitFilteredBlobBytes -RepoRoot $RepoRoot -Ref 'HEAD' -Path $ArchiveRelPath
        $headPreamble = Get-BytesBeforeFirstH2 -Bytes $headCheckoutBytes
        $currentPreamble = Get-BytesBeforeFirstH2 -Bytes $CurrentBytes
        $headBlocks = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $headBytes) -SourceTag 'head-archive')
        $currentBlocks = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $CurrentBytes) -SourceTag 'working-archive')
    } catch {
        return [pscustomobject]@{ IsClean = $false; Reason = "HEAD->working archive block-prefix check failed to read/classify content: $($_.Exception.Message)"; HeadBlockCount = $null; CurrentBlockCount = $null; AppendedBlockCount = $null }
    }

    $preambleMatches = (($headPreamble.Length -eq $currentPreamble.Length) -and (Test-BytePrefix -Prefix $headPreamble -Full $currentPreamble))
    if (-not $preambleMatches) {
        return [pscustomobject]@{
            IsClean = $false
            Reason = "working archive pre-H2 preamble differs byte-for-byte from HEAD materialized through Git checkout filters (expected=$($headPreamble.Length) bytes, working=$($currentPreamble.Length) bytes) -- prepended/mutated content before the first '## ' heading detected (fail-closed)"
            HeadBlockCount = $headBlocks.Count
            CurrentBlockCount = $currentBlocks.Count
            AppendedBlockCount = [Math]::Max(0, $currentBlocks.Count - $headBlocks.Count)
        }
    }

    if ($currentBlocks.Count -lt $headBlocks.Count) {
        return [pscustomobject]@{ IsClean = $false; Reason = "working archive has fewer H2 blocks than HEAD ($($currentBlocks.Count) < $($headBlocks.Count)) -- removal/truncation detected (fail-closed)"; HeadBlockCount = $headBlocks.Count; CurrentBlockCount = $currentBlocks.Count; AppendedBlockCount = 0 }
    }

    for ($i = 0; $i -lt $headBlocks.Count; $i++) {
        if ($headBlocks[$i].Sha256 -ne $currentBlocks[$i].Sha256) {
            # Get-Blocks assigns bytes before the next H2 to the previous block.
            # Therefore a legitimate `blank/---/blank + new H2` append makes the
            # former HEAD-final block appear to have gained separator bytes. Treat
            # that narrow region as delimiter ownership, not a content mutation.
            $isFormerFinalBlockWithSeparator = $false
            if (($i -eq ($headBlocks.Count - 1)) -and ($currentBlocks.Count -gt $headBlocks.Count) -and
                $currentBlocks[$i].Content.StartsWith($headBlocks[$i].Content, [System.StringComparison]::Ordinal)) {
                $separatorTail = $currentBlocks[$i].Content.Substring($headBlocks[$i].Content.Length)
                $isFormerFinalBlockWithSeparator = Test-IsArchiveInterBlockSeparator -Text $separatorTail
            }
            if ($isFormerFinalBlockWithSeparator) { continue }

            return [pscustomobject]@{
                IsClean = $false
                Reason = "working archive H2 block #$($i + 1) is not the canonical-LF byte-identical prefix block from HEAD (HEAD='$($headBlocks[$i].Header)', working='$($currentBlocks[$i].Header)') -- mutation/reorder detected (fail-closed; manifest regeneration cannot bless this)"
                HeadBlockCount = $headBlocks.Count
                CurrentBlockCount = $currentBlocks.Count
                AppendedBlockCount = [Math]::Max(0, $currentBlocks.Count - $headBlocks.Count)
            }
        }
    }

    return [pscustomobject]@{ IsClean = $true; Reason = $null; HeadBlockCount = $headBlocks.Count; CurrentBlockCount = $currentBlocks.Count; AppendedBlockCount = ($currentBlocks.Count - $headBlocks.Count) }
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
# CONTRACT C1 -- EXACT-ID CLOSURE SOURCES A + B
# ============================================================================
#
# ORDER-102 Contract C1 upgrade: policy exceptions raised by Invoke-ExceptionScan
# above are "raw" -- unchanged from C0. This section is a READ-ONLY post-processing
# layer that closes a subset of those raw exceptions via two canonical sources,
# reported separately (never silently folded back into "raw"):
#
#   Source A -- C1-ENFORCE-SOURCEA-BINDING: one or more appended, REVIEWED binding
#   blocks contain kind | block_id | block_sha256 | review_ref rows. A row closes
#   only the ONE raw exception matching the exact (kind, block_id, current sha256)
#   tuple. Canonical id and review_ref are traceability metadata, never wildcard
#   closure authority. A stale hash stays unresolved; malformed, unknown, or
#   duplicate rows are integrity failures.
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

function Find-C1ClosureBlocks {
    <# Returns every block whose header starts with the literal token "C1-CLOSURE". #>
    param($Blocks)
    $found = New-Object System.Collections.Generic.List[object]
    foreach ($b in $Blocks) {
        $headerBody = $b.Header.Substring(3)
        if ($headerBody -match '^C1-CLOSURE\b') { $found.Add($b) }
    }
    # Suppress pipeline enumeration so a single match remains a List[object] with
    # a reliable .Count instead of unrolling to the bare block object.
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

function Find-SourceABindingBlocks {
    <# Returns every block whose header starts with the literal token
       "C1-ENFORCE-SOURCEA-BINDING" (ORDER-103 Fix 3). #>
    param($Blocks)
    $found = New-Object System.Collections.Generic.List[object]
    foreach ($b in $Blocks) {
        $headerBody = $b.Header.Substring(3)
        if ($headerBody -match '^C1-ENFORCE-SOURCEA-BINDING\b') { $found.Add($b) }
    }
    # See the comma-operator note on Find-C1ClosureBlocks -- without it a single-match
    # List[object] unrolls to the bare block (losing .Count).
    return ,$found
}

function Get-SourceABindingTableRows {
    <#
        Parses the kind|block_id|block_sha256|review_ref table out of a single
        C1-ENFORCE-SOURCEA-BINDING block's Content. Same tolerant parsing shape as
        Get-C1ClosureTableRows (header row anywhere, markdown separator row skipped).
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
            if (($norm.Count -eq 4) -and ($norm[0] -eq 'kind') -and ($norm[1] -eq 'block_id') -and
                ($norm[2] -eq 'block_sha256') -and ($norm[3] -eq 'review_ref')) {
                $headerIdx = $i
            }
            continue
        }
        if ($i -eq ($headerIdx + 1) -and ($line -match '^\|?[\s:|-]+\|?$')) { continue }  # separator row
        if ($cells.Count -lt 4) { continue }

        $rows.Add([pscustomobject]@{
            Kind = $cells[0]; BlockId = $cells[1]; BlockSha256 = $cells[2]; ReviewRef = $cells[3]
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

        ORDER-103 Fix 3: Source A no longer closes by canonical-id wildcard (any raw
        exception whose canonical id happened to be covered by ANY REVIEWED
        '## REVIEW ORDER-<id>' block anywhere in the corpus -- which let a REVIEW of
        one block silently close an unrelated later block sharing the same id, e.g.
        the real ORDER-071 hole this order exists to close). Source A now requires an
        APPENDED '## C1-ENFORCE-SOURCEA-BINDING' block (append-only -- never edits the
        REVIEW block or the target block) whose table row matches the EXACT
        (kind, block_id, current block_sha256) triple -- same discipline Source B
        already used. review_ref is carried for traceability (must reference an
        operator traceability metadata only; closure itself is keyed on
        (kind, block_id, sha), never on canonical id or review_ref.
    #>
    param($PolicyExceptions, $ActiveBlocks, $ArchiveBlocks)

    $corpus = New-Object System.Collections.Generic.List[object]
    foreach ($b in $ActiveBlocks) { $corpus.Add($b) }
    foreach ($b in $ArchiveBlocks) { $corpus.Add($b) }

    $closureIntegrity = New-Object System.Collections.Generic.List[object]

    # --- Source A: locate + parse ALL '## C1-ENFORCE-SOURCEA-BINDING' blocks (ORDER-103
    # Fix 3). Unlike Source B's C1-CLOSURE (at most one block, singular), binding blocks
    # may be appended incrementally over time (each migration appends its own), so every
    # matching block's rows are pooled together before dup/unknown detection.
    $bindingBlocks = Find-SourceABindingBlocks -Blocks $corpus
    $aRows = New-Object System.Collections.Generic.List[object]
    foreach ($block in $bindingBlocks) {
        if (-not (($block.StatusClass -eq 'Terminal') -and ($block.StatusLabel -match '^REVIEWED'))) {
            $closureIntegrity.Add([pscustomobject]@{
                Kind = 'sourcea-binding-not-reviewed'; Severity = 'integrity'
                BlockId = $block.BlockId; Header = $block.Header
                Detail = "C1-ENFORCE-SOURCEA-BINDING block found but its status is not a REVIEWED(...) verb (status='$($block.StatusLabel)') -- not parsed/honored"
            })
            continue
        }
        foreach ($row in @(Get-SourceABindingTableRows -Block $block)) { $aRows.Add($row) }
    }

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

    # --- Source A row processing: malformed hash / unknown / duplicate = integrity;
    # else exact (kind, block_id, sha) match closes, mismatch = STALE (reported, not honored). ---
    $shaHexPattern = '^[0-9a-f]{64}$'
    $aSeenRowKeys = New-Object System.Collections.Generic.HashSet[string]
    $aClosedIndex = @{}   # array-index -> row that closed it
    $aStaleIndex  = @{}   # array-index -> row that matched key but had a stale sha

    foreach ($row in $aRows) {
        if ($row.BlockSha256 -notmatch $shaHexPattern) {
            $closureIntegrity.Add([pscustomobject]@{
                Kind = 'sourcea-binding-malformed-hash'; Severity = 'integrity'
                Detail = "C1-ENFORCE-SOURCEA-BINDING row for kind='$($row.Kind)' block_id='$($row.BlockId)' has a malformed block_sha256 ('$($row.BlockSha256)') -- expected 64 lowercase hex chars"
            })
            continue
        }
        $rowKey = $row.Kind + '||' + $row.BlockId
        if ($aSeenRowKeys.Contains($rowKey)) {
            $closureIntegrity.Add([pscustomobject]@{
                Kind = 'sourcea-binding-duplicate-row'; Severity = 'integrity'
                Detail = "duplicate C1-ENFORCE-SOURCEA-BINDING row for kind='$($row.Kind)' block_id='$($row.BlockId)'"
            })
            continue
        }
        [void]$aSeenRowKeys.Add($rowKey)

        if (-not $excIndexByKey.ContainsKey($rowKey)) {
            $closureIntegrity.Add([pscustomobject]@{
                Kind = 'sourcea-binding-unknown-row'; Severity = 'integrity'
                Detail = "C1-ENFORCE-SOURCEA-BINDING row for kind='$($row.Kind)' block_id='$($row.BlockId)' matches no detected policy exception"
            })
            continue
        }

        foreach ($idx in $excIndexByKey[$rowKey]) {
            $e = $PolicyExceptions[$idx]
            if ($e.Sha256 -eq $row.BlockSha256) {
                $aClosedIndex[$idx] = $row
            } else {
                $aStaleIndex[$idx] = $row
            }
        }
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

        # Precedence (ORDER-103 Fix 3, deterministic, never double-counted): Source A
        # (appended binding record) is checked first. If B would ALSO have closed the
        # identical exception, that fact is noted in the closure detail rather than
        # silently dropped -- A wins the ClosureSource classification either way.
        if ($aClosedIndex.ContainsKey($i)) {
            $row = $aClosedIndex[$i]
            $alsoB = if ($bClosedIndex.ContainsKey($i)) { ' [also independently closable via B-C1-closure-block -- A precedence applied, not double-counted]' } else { '' }
            $reviewed.Add([pscustomobject]@{
                Kind = $e.Kind; BlockId = $e.BlockId; Header = $e.Header; Detail = $e.Detail
                CanonicalId = $e.CanonicalId; Sha256 = $e.Sha256
                ClosureSource = 'A-sourcea-binding'
                ClosureDetail = "closed by C1-ENFORCE-SOURCEA-BINDING row (review_ref='$($row.ReviewRef)')$alsoB"
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
        if ($aStaleIndex.ContainsKey($i)) {
            $row = $aStaleIndex[$i]
            $staleNote = "STALE C1-ENFORCE-SOURCEA-BINDING row found for kind='$($e.Kind)' block_id='$($e.BlockId)' but block_sha256 mismatch (row='$($row.BlockSha256)' current='$($e.Sha256)') -- closure NOT honored, exception stays unresolved"
        } elseif ($bStaleIndex.ContainsKey($i)) {
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
        [string]$ExceptionsPath,
        [string]$ChainCheckpointSha = '0ced19485c6c6ce9a23541f785ab82bae4fcad25',
        [string]$ChainArchivePath = 'ARCHIVE_TASKBOARD_2026-07A.md',
        [bool]$SkipChainCheck = $false,
        [bool]$CheckRealWorkingArchive = $false
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

    # Contract C1 exact closure (Source A: C1-ENFORCE-SOURCEA-BINDING;
    # Source B: C1-CLOSURE). READ-ONLY -- only classifies the raw
    # exceptions above, never mutates AGENT_TASKBOARD.md/ARCHIVE_TASKBOARD_2026-07A.md.
    $closure = Invoke-ExceptionClosure -PolicyExceptions $exceptions.Policy -ActiveBlocks $activeCurrentBlocks -ArchiveBlocks $archiveCurrentBlocks
    $report.CanonicallyReviewed = @($closure.Reviewed)
    $report.UnresolvedPolicyExceptions = @($closure.Unresolved)

    $integrityFailures = New-Object System.Collections.Generic.List[object]
    foreach ($f in $exceptions.Integrity) { $integrityFailures.Add($f) }
    foreach ($f in $closure.IntegrityFailures) { $integrityFailures.Add($f) }

    # ORDER-103 Fix 1: committed append-CHAIN integrity gate. Independent of which
    # Current*/Split*Source specs were passed in (those drive the block-content
    # checks above) -- this always walks the REAL git history of $RepoRoot for
    # $ChainArchivePath from $ChainCheckpointSha to HEAD. Read-only in every mode.
    $chainResult = $null
    if (-not $SkipChainCheck) {
        try {
            $chainResult = Invoke-ArchiveChainIntegrityCheck -RepoRoot $RepoRoot -CheckpointSha $ChainCheckpointSha -ArchiveRelPath $ChainArchivePath -HeadRef 'HEAD'
        } catch {
            $chainResult = [pscustomobject]@{ IsClean = $false; Reason = "chain integrity check threw: $($_.Exception.Message)"; Steps = @() }
        }
        if (-not $chainResult.IsClean) {
            $integrityFailures.Add([pscustomobject]@{ Kind = 'archive-chain-broken'; Severity = 'integrity'; Detail = $chainResult.Reason })
        }
    }
    $report.ChainIntegrity = $chainResult

    # ORDER-103 rework BLOCKER 1: Audit/Strict also close the final HEAD->working
    # leg when CurrentArchiveSource is the real working archive. Compare the H2
    # sequence as a canonical-LF block prefix so core.autocrlf/mixed EOL does not
    # create false divergence. Generate intentionally does not enforce this leg:
    # it may regenerate evidence for diagnostics, but the following read-only
    # Strict/Audit invocation must still reject any mutation.
    $workingTreeExtensionResult = $null
    if ((-not $isGenerate) -and (-not $SkipChainCheck)) {
        $realArchivePath = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $ChainArchivePath))
        $workingBytesForCheck = $null

        # Explicit FILE:<real archive> callers already supplied the working bytes.
        # Default Audit/Strict callers deliberately validate artifacts against the
        # committed HEAD snapshot (stable across CRLF and unrelated working-board
        # edits), but still close the independent HEAD->working tamper leg here.
        if ($CurrentArchiveSource -match '^FILE:(.+)$') {
            $sourceArchivePath = [System.IO.Path]::GetFullPath($Matches[1])
            if ($sourceArchivePath -eq $realArchivePath) { $workingBytesForCheck = $archiveCurrentBytes }
        } elseif ($CheckRealWorkingArchive -and (Test-Path -LiteralPath $realArchivePath)) {
            $workingBytesForCheck = [System.IO.File]::ReadAllBytes($realArchivePath)
        }

        if ($null -ne $workingBytesForCheck) {
            try {
                $workingTreeExtensionResult = Invoke-ArchiveWorkingTreeExtensionCheck -RepoRoot $RepoRoot -ArchiveRelPath $ChainArchivePath -CurrentBytes $workingBytesForCheck
            } catch {
                $workingTreeExtensionResult = [pscustomobject]@{ IsClean = $false; Reason = "HEAD->working archive block-prefix check threw: $($_.Exception.Message)" }
            }
            if (-not $workingTreeExtensionResult.IsClean) {
                $integrityFailures.Add([pscustomobject]@{ Kind = 'archive-working-prefix-broken'; Severity = 'integrity'; Detail = $workingTreeExtensionResult.Reason })
            }
        }
    }
    $report.WorkingTreeExtensionIntegrity = $workingTreeExtensionResult

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
    [void]$sb.AppendLine('## Canonically reviewed -- CLOSED (Contract C1 Source A: exact binding record /')
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
    [void]$sb.AppendLine('## Unresolved -- raw_detected minus canonically_reviewed (needs an exact Source A binding or C1-CLOSURE row)')
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
    [void]$sb.AppendLine('- Source A uses an appended `## C1-ENFORCE-SOURCEA-BINDING` record and closes only')
    [void]$sb.AppendLine('  the exact **(kind, block_id, block_sha256)** tuple in a binding row; a canonical-id')
    [void]$sb.AppendLine('  or bare REVIEW-block match is never a wildcard closure. Source B (a `## C1-CLOSURE`')
    [void]$sb.AppendLine('  block) also closes by the EXACT (kind, block_id, block_sha256) triple, so one kind of a')
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

    $isGenerate = ($Mode -eq 'Generate')
    $defaultActiveSource = -not $CurrentActiveSource
    $defaultArchiveSource = -not $CurrentArchiveSource

    if ($defaultActiveSource) {
        $script:CurrentActiveSource = if ($isGenerate) { 'FILE:' + (Join-Path $RepoRoot 'AGENT_TASKBOARD.md') } else { 'GIT:HEAD:AGENT_TASKBOARD.md' }
    }
    if ($defaultArchiveSource) {
        $script:CurrentArchiveSource = if ($isGenerate) { 'FILE:' + (Join-Path $RepoRoot 'ARCHIVE_TASKBOARD_2026-07A.md') } else { 'GIT:HEAD:ARCHIVE_TASKBOARD_2026-07A.md' }
    }
    if (-not $ManifestPath)   { $script:ManifestPath = Join-Path $RepoRoot 'docs/memory_control/ARCHIVE_MANIFEST.csv' }
    if (-not $IndexPath)      { $script:IndexPath = Join-Path $RepoRoot 'docs/memory_control/ARCHIVE_INDEX.md' }
    if (-not $ExceptionsPath) { $script:ExceptionsPath = Join-Path $RepoRoot 'docs/memory_control/RECONCILE_EXCEPTIONS.md' }

    $writeArtifacts = ($isGenerate -and -not $SkipArtifacts)

    # NOTE: RECONCILE_EXCEPTIONS.md is now written (under -Generate) AND validated
    # (under all modes, ORDER-101 fix 1) INSIDE Invoke-TaskboardArchiveCheck, the same
    # place ARCHIVE_MANIFEST.csv/ARCHIVE_INDEX.md are written+validated -- no separate
    # write-after-the-fact call here anymore.
    $report = Invoke-TaskboardArchiveCheck -RepoRoot $RepoRoot `
        -PreSplitSource $PreSplitSource -SplitActiveSource $SplitActiveSource -SplitArchiveSource $SplitArchiveSource `
        -CurrentActiveSource $CurrentActiveSource -CurrentArchiveSource $CurrentArchiveSource `
        -Mode $Mode -SkipArtifacts $SkipArtifacts.IsPresent `
        -ManifestPath $ManifestPath -IndexPath $IndexPath -ExceptionsPath $ExceptionsPath `
        -ChainCheckpointSha $ChainCheckpointSha -ChainArchivePath $ChainArchivePath -SkipChainCheck $SkipChainCheck.IsPresent `
        -CheckRealWorkingArchive ((-not $isGenerate) -and $defaultArchiveSource)

    $modeLabel = $Mode.ToUpper()
    $roTag = if ($isGenerate) { '' } else { ' (READ-ONLY -- never writes manifest/index/exceptions)' }
    Write-Host "=== check_taskboard_archive.ps1 [$modeLabel]$roTag ==="
    Write-Host ('Pre-state hash  AGENT_TASKBOARD.md            = ' + $report.PreStateHashes.CurrentActiveFileSha256)
    Write-Host ('Pre-state hash  ARCHIVE_TASKBOARD_2026-07A.md = ' + $report.PreStateHashes.CurrentArchiveFileSha256)
    Write-Host ('Archive content identity (git blob sha)       = ' + $report.ArchiveBlobSha)
    if ($report.ChainIntegrity) {
        Write-Host ('Chain integrity (checkpoint->HEAD, first-parent) clean = ' + $report.ChainIntegrity.IsClean + $(if (-not $report.ChainIntegrity.IsClean) { ' :: ' + $report.ChainIntegrity.Reason } else { '' }))
    } else {
        Write-Host 'Chain integrity check: SKIPPED (-SkipChainCheck)'
    }
    if ($report.WorkingTreeExtensionIntegrity) {
        Write-Host ('Working extension (HEAD->FILE, canonical-LF H2 prefix) clean = ' + $report.WorkingTreeExtensionIntegrity.IsClean + $(if (-not $report.WorkingTreeExtensionIntegrity.IsClean) { ' :: ' + $report.WorkingTreeExtensionIntegrity.Reason } else { ' | appended_blocks=' + $report.WorkingTreeExtensionIntegrity.AppendedBlockCount }))
    }
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
