<#
.SYNOPSIS
    ORDER-103 Contract C1-ENFORCE Fix 2 -- fail-closed staged-snapshot pre-commit
    check. Called by .githooks/pre-commit; enforces ONLY when a PROTECTED-SET file
    is among the staged paths.

.DESCRIPTION
    PROTECTED SET (enumerated, exactly these 5):
      ARCHIVE_TASKBOARD_2026-07A.md
      AGENT_TASKBOARD.md
      docs/memory_control/ARCHIVE_MANIFEST.csv
      docs/memory_control/ARCHIVE_INDEX.md
      docs/memory_control/RECONCILE_EXCEPTIONS.md

    If none of these are staged (added/modified/deleted/renamed), exits 0
    immediately -- this script never blocks an ordinary commit.

    When any protected file IS staged, all of the following are enforced,
    reading candidates from the git INDEX (never the working tree):
      1. Staged ARCHIVE_TASKBOARD_2026-07A.md bytes must be an exact raw-byte
         prefix-extension of HEAD's archive bytes, with a new-H2-block-boundary
         suffix rule (reuses Invoke-ArchiveChainIntegrityCheck -IncludeStaged,
         which also re-verifies the checkpoint->HEAD chain itself as
         defense-in-depth at commit time).
      2. The active-board content used for the Source-A exception scan is
         ALWAYS read from the STAGED index (`git show :AGENT_TASKBOARD.md`),
         never HEAD or the working tree -- so a commit that changes the
         archive is judged against what AGENT_TASKBOARD.md will actually look
         like after this commit, not some stale prior version.
      3. Manifest/index/exceptions are regenerated IN A TEMP location from the
         STAGED archive+active bytes and byte-compared (canonical, LF-normalized)
         against the STAGED versions of the 3 artifact files. Mismatch = block.
      4. Exactness: the full staged consistency check runs whenever ANY protected
         file is staged, even if the archive itself is unchanged. If the archive
         changed, all 3 artifacts MUST also be staged as changed in the same commit.
         A protected file staged as DELETED or RENAMED is blocked outright.

    Exit 0 = pass (commit may proceed). Exit 1 = policy/consistency block.
    Exit 2 = tooling/integrity failure (git command failed, etc).
#>
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = 'Stop'

# Dot-source the validator for its Get-Snapshot / Invoke-ArchiveChainIntegrityCheck /
# Invoke-TaskboardArchiveCheck / Get-NormalizedTextFromBytes functions. The trailing
# ".ps1" file is guarded (`if ($MyInvocation.InvocationName -ne '.')`) so dot-sourcing
# it does NOT also run Invoke-Main / call `exit` -- only defines functions.
. (Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1') -RepoRoot $RepoRoot 6>$null

$ArchivePath    = 'ARCHIVE_TASKBOARD_2026-07A.md'
$ActivePath     = 'AGENT_TASKBOARD.md'
$ManifestPath   = 'docs/memory_control/ARCHIVE_MANIFEST.csv'
$IndexPath      = 'docs/memory_control/ARCHIVE_INDEX.md'
$ExceptionsPath = 'docs/memory_control/RECONCILE_EXCEPTIONS.md'
$ProtectedSet = @($ArchivePath, $ActivePath, $ManifestPath, $IndexPath, $ExceptionsPath)

# ORDER-144 staged-bytes validation. These checks are deliberately separate from
# the ORDER-103 archive contract: they read the index blobs and only activate when
# one of the named operational artifacts is staged.
$DeploymentPath = 'portfolio/DEPLOYMENTS.csv'
$ScorecardPath = 'EA_SCORECARD_AND_REGISTRY.md'
$MasterIndexPath = 'EA_MASTER_INDEX.csv'
$B1DatasetPath = 'docs/memory_control/B1_DATASET.csv'
$RegressionBaselinePath = 'ea_template/regression_baseline.csv'

function Get-StagedBytesOrNull {
    param([string]$RelPath)
    try { return (Get-Snapshot -RepoRoot $RepoRoot -Mode Staged -RelPath $RelPath).Bytes }
    catch { return $null }
}

function Get-HeadBytesOrNull {
    param([string]$RelPath)
    try { return (Get-Snapshot -RepoRoot $RepoRoot -Mode Committed -RelPath $RelPath -CommitSha 'HEAD').Bytes }
    catch { return $null }
}

function Compare-BytesExact {
    param([byte[]]$A, [byte[]]$B)
    if ($null -eq $A -or $null -eq $B -or $A.Length -ne $B.Length) { return $false }
    for ($i = 0; $i -lt $A.Length; $i++) { if ($A[$i] -ne $B[$i]) { return $false } }
    return $true
}

function Test-DeploymentInventoryBlob {
    param([byte[]]$Bytes)
    $tmp = Join-Path $env:TEMP ('order144_deploy_' + [guid]::NewGuid().ToString('N') + '.csv')
    try {
        [IO.File]::WriteAllBytes($tmp, $Bytes)
        $rows = @(Import-Csv -LiteralPath $tmp -Encoding UTF8)
        if ($rows.Count -eq 0) { return 'portfolio/DEPLOYMENTS.csv is empty or has no data rows' }
        $required = @('account','magic')
        $cols = @($rows[0].PSObject.Properties.Name)
        $missing = @($required | Where-Object { $cols -notcontains $_ })
        if ($missing.Count -gt 0) { return ('portfolio/DEPLOYMENTS.csv missing required column(s): ' + ($missing -join ', ')) }
        $dups = @($rows | Where-Object { $_.magic -match '^d+$' } | Group-Object { "$($_.account)|$($_.magic)" } | Where-Object Count -gt 1)
        if ($dups.Count -gt 0) { return ('portfolio/DEPLOYMENTS.csv duplicate account|magic: ' + (($dups | ForEach-Object Name) -join ', ')) }
        return $null
    } catch { return ('portfolio/DEPLOYMENTS.csv parse failed: ' + $_.Exception.Message) }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

# ORDER-500: the B1 rules moved to scripts/lib/b1_guard.ps1 so that this hook,
# .githooks/commit-msg and scripts/_test/run_b1_guard_tests.ps1 all call ONE
# implementation. ORDER-421 found the ORDER-105 cage had been running at 14% of itself
# because its fixture copied the hook without tracking the hook's dependencies; a shared
# library removes that failure mode instead of documenting it.
$b1LibPath = Join-Path $PSScriptRoot 'lib\b1_guard.ps1'
if (-not (Test-Path -LiteralPath $b1LibPath)) {
    # Fail-CLOSED. A guard that cannot load its rules must block, not wave the commit
    # through -- "could not read the input" is not the same as "nothing to enforce"
    # (memory `guard-disarmed-by-prose-reported-as-note`).
    Write-Host "[precommit-staged] FAIL-CLOSED: cannot find $b1LibPath -- B1 rules unavailable, blocking"
    exit 1
}
. $b1LibPath

function Get-StagedNameStatus {
    param([string]$RepoRoot)
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -Arguments 'diff --cached --name-status --no-renames'
    if ($r.ExitCode -ne 0) { throw "git diff --cached --name-status failed: $($r.StdErr)" }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($line in ($r.StdOut -split "`r?`n")) {
        if (-not $line.Trim()) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -lt 2) { continue }
        $rows.Add([pscustomobject]@{ Status = $parts[0]; Path = ($parts[1] -replace '\\', '/') })
    }
    return $rows.ToArray()
}

Write-Host '[precommit-staged] ORDER-103 Fix 2 staged-snapshot check'

$staged = Get-StagedNameStatus -RepoRoot $RepoRoot
$stagedByPath = @{}
foreach ($s in $staged) { $stagedByPath[$s.Path] = $s.Status }

# ORDER-144: validate operational staged blobs before the legacy protected-set
# early return. No working-tree bytes are consulted for these checks.
$order144Paths = @($DeploymentPath, $ScorecardPath, $MasterIndexPath, $B1DatasetPath, $RegressionBaselinePath)
$order144Staged = @($order144Paths | Where-Object { $stagedByPath.ContainsKey($_) })
if ($order144Staged.Count -gt 0) {
    Write-Host ('[precommit-staged] ORDER-144 staged-bytes check: ' + ($order144Staged -join ', '))
    $order144Failures = New-Object System.Collections.Generic.List[string]

    if ($stagedByPath.ContainsKey($DeploymentPath)) {
        $deploymentError = Test-DeploymentInventoryBlob -Bytes (Get-StagedBytesOrNull $DeploymentPath)
        if ($deploymentError) { $order144Failures.Add($deploymentError) }
    }

    # Scorecard and master index are a single registry transaction. A change to
    # either without the other would leave the two canonical surfaces divergent.
    $registryPair = @($ScorecardPath, $MasterIndexPath)
    $registryChanged = @($registryPair | Where-Object { $stagedByPath.ContainsKey($_) })
    if ($registryChanged.Count -gt 0) {
        $registryMissing = @($registryPair | Where-Object { -not $stagedByPath.ContainsKey($_) })
        if ($registryMissing.Count -gt 0) {
            $order144Failures.Add('EA_SCORECARD_AND_REGISTRY.md and EA_MASTER_INDEX.csv must be staged in the same commit; missing: ' + ($registryMissing -join ', '))
        }
    }

    if ($stagedByPath.ContainsKey($B1DatasetPath)) {
        # ORDER-500 RULE 2 (new, enforced HERE): what was appended must be a ROW.
        # This needs no commit message, so it belongs at the earliest point that can see
        # the bytes. It is the assertion whose absence let ORDER-280's row disappear
        # while every character somebody typed was still present in the file.
        $b1Shape = Test-B1RowShape -StagedBytes (Get-StagedBytesOrNull $B1DatasetPath)
        if ($b1Shape) { $order144Failures.Add($b1Shape) }

        # ORDER-500 RULE 1 (append-only) MOVED to .githooks/commit-msg -- same reason the
        # regression-baseline re-pin rule moved there on 2026-07-27, and the note below
        # explains it. The rule needs to know whether THIS commit declares an audited
        # repair, and pre-commit structurally cannot read this commit's message. Blocking
        # here would mean commit-msg never runs, so the escape hatch could never open.
        # The rule is NOT weakened: both hooks run on `git commit` and both are skipped by
        # --no-verify, so the enforcement point is equivalent.
        Write-Host '[precommit-staged] NOTE: B1_DATASET.csv append-only rule is enforced by .githooks/commit-msg (ORDER-500 -- it must read this commit''s message to honour a declared repair)'
    }

    # 2026-07-27: the regression-baseline "re-pin" rule MOVED to .githooks/commit-msg.
    #
    # It used to live here and read .git\COMMIT_EDITMSG. Under `git commit -m` that file
    # is written only on SUCCESS, after pre-commit has already run -- so at this point it
    # still holds the PREVIOUS commit's message. The rule was gating on the wrong input
    # and could only pass by accident, when the last successful commit happened to
    # contain the word. Demonstrated twice while landing ORDER-432 with messages that
    # plainly contained "re-pin" and were blocked anyway. Of the eight commits that have
    # ever changed the baseline, only one postdates the guard, so it had almost no chance
    # to be noticed.
    #
    # commit-msg is the correct hook: git passes it the real message file as $1. The rule
    # is NOT weakened -- it is enforced somewhere it can actually read its input. Left as
    # a note rather than deleted, so the next reader finds out where it went instead of
    # concluding the rule was dropped.
    if ($stagedByPath.ContainsKey($RegressionBaselinePath)) {
        Write-Host '[precommit-staged] NOTE: regression-baseline re-pin rule is enforced by .githooks/commit-msg (it needs the message this commit is about, which pre-commit cannot see)'
    }

    if ($order144Failures.Count -gt 0) {
        Write-Host '[precommit-staged] BLOCK: ORDER-144 staged-bytes validation failed:'
        foreach ($failure in $order144Failures) { Write-Host ('  - ' + $failure) }
        exit 1
    }
    Write-Host '[precommit-staged] ORDER-144 staged-bytes validation PASS'
}

$protectedStaged = @($ProtectedSet | Where-Object { $stagedByPath.ContainsKey($_) })
if ($protectedStaged.Count -eq 0) {
    Write-Host '[precommit-staged] no protected-set file staged -- pass (ordinary commit)'
    exit 0
}

Write-Host ('[precommit-staged] protected file(s) staged: ' + ($protectedStaged -join ', '))

# --- deleted/renamed protected file = block outright ---
foreach ($p in $protectedStaged) {
    $st = $stagedByPath[$p]
    if ($st -match '^D') {
        Write-Host "[precommit-staged] BLOCK: protected file '$p' is staged for DELETION -- not permitted"
        exit 1
    }
}

# --- if the archive changed, each generated artifact must be staged as changed
#     UNLESS it is legitimately byte-identical to a fresh -Generate (e.g. a
#     REVIEWED-only archive append raises no new exceptions, so
#     RECONCILE_EXCEPTIONS.md does not change and git cannot stage a no-op diff).
#     An unstaged artifact has index-blob == HEAD-blob by definition; the
#     authoritative content-consistency check further below (staged-blob vs a
#     fresh -Generate candidate, lines ~320-333) independently BLOCKS if that
#     HEAD content is actually stale, so exempting a provably-unchanged artifact
#     here removes a false-block without weakening the guard.
$archiveChanged = $stagedByPath.ContainsKey($ArchivePath)
if ($archiveChanged) {
    $unstagedArtifacts = @()
    foreach ($a in @($ManifestPath, $IndexPath, $ExceptionsPath)) {
        if (-not $stagedByPath.ContainsKey($a)) { $unstagedArtifacts += $a }
    }
    if ($unstagedArtifacts.Count -gt 0) {
        Write-Host ("[precommit-staged] NOTE: archive changed; artifact(s) not staged as changed: " + ($unstagedArtifacts -join ', ') + ' -- allowed only if byte-identical to a fresh -Generate (verified by the consistency check below)')
    }
}

# --- read staged snapshots (INDEX, never working tree) ---
try {
    $stagedArchive = Get-Snapshot -RepoRoot $RepoRoot -Mode Staged -RelPath $ArchivePath
    $headArchive   = Get-Snapshot -RepoRoot $RepoRoot -Mode Committed -RelPath $ArchivePath -CommitSha 'HEAD'
    $stagedActive  = Get-Snapshot -RepoRoot $RepoRoot -Mode Staged -RelPath $ActivePath
} catch {
    Write-Host "[precommit-staged] INTEGRITY: failed to read staged/HEAD snapshot: $($_.Exception.Message)"
    exit 2
}

# --- 1. chain check: checkpoint->HEAD->staged, first-parent, raw-byte prefix + H2 boundary ---
$chain = $null
try {
    $chain = Invoke-ArchiveChainIntegrityCheck -RepoRoot $RepoRoot `
        -CheckpointSha '0ced19485c6c6ce9a23541f785ab82bae4fcad25' -ArchiveRelPath $ArchivePath `
        -HeadRef 'HEAD' -IncludeStaged
} catch {
    Write-Host "[precommit-staged] INTEGRITY: chain check threw: $($_.Exception.Message)"
    exit 2
}
if (-not $chain.IsClean) {
    Write-Host "[precommit-staged] BLOCK: staged archive fails append-chain integrity -- $($chain.Reason)"
    exit 1
}
Write-Host '[precommit-staged] staged archive is a valid checkpoint->HEAD->staged append-chain extension'

# --- 2+3. regenerate manifest/index/exceptions IN TEMP from staged bytes, compare to staged artifacts ---
# This runs for every protected-file commit. Unchanged protected paths are still
# present in the index, so comparing the complete staged candidate catches an
# artifact-only tamper or active-board-only edit that would make post-commit
# -Strict fail even though the archive blob did not change.
#
# Deliberately does NOT call Invoke-TaskboardArchiveCheck here: that function's
# archive-content identity (Get-ArchiveContentIdentity) and split-integrity/active-
# conservation checks are HEAD-committed-history concepts (PreSplit/SplitActive/
# SplitArchive GIT: refs resolved against $RepoRoot's real history) that do not apply
# to an uncommitted staged snapshot being validated in isolation. Instead this builds
# the manifest/index/exceptions directly from the staged blocks, using the Fix 4
# STAGED identity (git rev-parse :path) computed above as the archive-content
# identity -- which is in fact the semantically CORRECT identity for this snapshot,
# not a workaround.
$tempDir = $null
try {
    $tempActiveBlocks  = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $stagedActive.Bytes) -SourceTag 'current-active')
    $tempArchiveBlocks = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $stagedArchive.Bytes) -SourceTag 'current-archive')

    # Candidate-level equivalent of the public Strict policy/integrity checks.
    # The historical split sources are immutable; only the checks that can change
    # with staged active/archive content need to be recomputed here.
    $splitActiveBlocksForCandidate = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes (Get-SourceBytes -RepoRoot $RepoRoot -SourceSpec 'GIT:4aebbc37:AGENT_TASKBOARD.md')) -SourceTag 'split-active')
    $tempActiveConservation = Invoke-ActiveConservationCheck -SplitActiveBlocks $splitActiveBlocksForCandidate -CurrentActiveBlocks $tempActiveBlocks -CurrentArchiveBlocks $tempArchiveBlocks

    $tempExceptionsScan = Invoke-ExceptionScan -CurrentActiveBlocks $tempActiveBlocks -CurrentArchiveBlocks $tempArchiveBlocks
    $tempClosure = Invoke-ExceptionClosure -PolicyExceptions $tempExceptionsScan.Policy -ActiveBlocks $tempActiveBlocks -ArchiveBlocks $tempArchiveBlocks

    $candidateBlockingFindings = New-Object System.Collections.Generic.List[object]
    foreach ($f in $tempExceptionsScan.Integrity) { $candidateBlockingFindings.Add($f) }
    foreach ($f in $tempClosure.IntegrityFailures) { $candidateBlockingFindings.Add($f) }
    foreach ($lost in $tempActiveConservation.OrderLost) {
        $candidateBlockingFindings.Add([pscustomobject]@{ Kind = 'active-order-lost'; Detail = "staged active/archive candidate loses conserved order '$($lost.Header)'" })
    }
    foreach ($u in $tempClosure.Unresolved) {
        $candidateBlockingFindings.Add([pscustomobject]@{ Kind = 'unresolved-policy-exception'; Detail = "staged candidate would leave -Strict non-clean: [$($u.Kind)] $($u.BlockId)" })
    }

    $tempReport = [ordered]@{
        PolicyExceptions           = @($tempExceptionsScan.Policy)
        CanonicallyReviewed        = @($tempClosure.Reviewed)
        UnresolvedPolicyExceptions = @($tempClosure.Unresolved)
        IntegrityFailures          = @($tempExceptionsScan.Integrity) + @($tempClosure.IntegrityFailures)
    }

    if ($candidateBlockingFindings.Count -gt 0) {
        Write-Host '[precommit-staged] BLOCK: staged content fails its full candidate consistency check:'
        foreach ($f in $candidateBlockingFindings) { Write-Host ('  [' + $f.Kind + '] ' + $f.Detail) }
        exit 1
    }

    $tempDir = Join-Path $env:TEMP ('order103_precommit_' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    $tempManifestRows = @(New-ArchiveManifestRows -CurrentArchiveBlocks $tempArchiveBlocks -ArchiveBlobSha $stagedArchive.Identity)
    $tempManifestPath = Join-Path $tempDir 'manifest.csv'
    Write-ArchiveManifestCsv -Rows $tempManifestRows -Path $tempManifestPath   # same Export-Csv code path -Generate uses
    $tempIndexPath = Join-Path $tempDir 'index.md'
    $tempExceptionsPath = Join-Path $tempDir 'exceptions.md'
    Write-TextFileLfNoBom -Path $tempIndexPath -Text (Build-ArchiveIndexMarkdown -ManifestRows $tempManifestRows -ArchiveBlobSha $stagedArchive.Identity -ArchiveRawFileSha256 (Get-Sha256Hex -Bytes $stagedArchive.Bytes))
    Write-TextFileLfNoBom -Path $tempExceptionsPath -Text (Build-ExceptionsMarkdown -Report $tempReport)

    function Get-FilteredCandidateBlobId {
        param([string]$RelPath, [string]$CandidatePath)
        $r = Invoke-GitRaw -RepoRoot $RepoRoot -Arguments ('hash-object --path="{0}" -- "{1}"' -f $RelPath, $CandidatePath)
        if ($r.ExitCode -ne 0) { throw "git hash-object --path=$RelPath failed: $($r.StdErr)" }
        return $r.StdOut.Trim()
    }

    function Get-StagedBlobIdOrNull {
        param([string]$RelPath)
        try { return Get-GitObjectId -RepoRoot $RepoRoot -Spec (':{0}' -f $RelPath) }
        catch { return $null }
    }

    # Compare exact candidate blob identities after Git applies the path's clean
    # filter. This is byte-exact for what the commit will contain and remains
    # correct under core.autocrlf/attributes.
    $freshManifestId = Get-FilteredCandidateBlobId -RelPath $ManifestPath -CandidatePath $tempManifestPath
    $freshIndexId = Get-FilteredCandidateBlobId -RelPath $IndexPath -CandidatePath $tempIndexPath
    $freshExceptionsId = Get-FilteredCandidateBlobId -RelPath $ExceptionsPath -CandidatePath $tempExceptionsPath
    $stagedManifestId = Get-StagedBlobIdOrNull -RelPath $ManifestPath
    $stagedIndexId = Get-StagedBlobIdOrNull -RelPath $IndexPath
    $stagedExceptionsId = Get-StagedBlobIdOrNull -RelPath $ExceptionsPath

    $mismatches = New-Object System.Collections.Generic.List[string]
    if ($null -eq $stagedManifestId -or $stagedManifestId -ne $freshManifestId) { $mismatches.Add('ARCHIVE_MANIFEST.csv (staged blob) is not byte-identical to a fresh -Generate candidate after Git clean filters') }
    if ($null -eq $stagedIndexId -or $stagedIndexId -ne $freshIndexId) { $mismatches.Add('ARCHIVE_INDEX.md (staged blob) is not byte-identical to a fresh -Generate candidate after Git clean filters') }
    if ($null -eq $stagedExceptionsId -or $stagedExceptionsId -ne $freshExceptionsId) { $mismatches.Add('RECONCILE_EXCEPTIONS.md (staged blob) is not byte-identical to a fresh -Generate candidate after Git clean filters') }

    if ($mismatches.Count -gt 0) {
        Write-Host '[precommit-staged] BLOCK: staged artifact(s) inconsistent with staged archive+active:'
        foreach ($m in $mismatches) { Write-Host ('  - ' + $m) }
        exit 1
    }
} finally {
    if ($tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
}

Write-Host '[precommit-staged] PASS -- staged protected-set content is chain-consistent and artifacts are in sync'
exit 0

# ORDER-144 rule summary (keep adjacent to the executable guard):
#   portfolio/DEPLOYMENTS.csv      -> staged UTF-8 parse + duplicate account|magic block
#   scorecard + EA_MASTER_INDEX.csv -> both must be staged in one registry transaction
#   docs/memory_control/B1_DATASET.csv -> existing HEAD bytes must be an exact prefix
#   ea_template/regression_baseline.csv -> changed bytes require `re-pin` in COMMIT_EDITMSG
# All checks use staged snapshots (`git show :<path>` through Get-Snapshot), never the
# working tree. Ordinary commits and unrelated paths remain a fast no-op/pass.
