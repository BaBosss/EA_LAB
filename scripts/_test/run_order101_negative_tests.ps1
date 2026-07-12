<#
.SYNOPSIS
    ORDER-101 Contract C0 -- negative/structural test suite for check_taskboard_archive.ps1.

.DESCRIPTION
    Exercises the validator against small synthetic fixtures under
    scripts/_test/fixtures/order101/ (NOT the real repo taskboard/archive) so the
    same parsing/scoring code path is proven correct without any risk to real
    repo content. Each corrupted-input case is invoked as a CHILD PowerShell
    process (the validator itself calls `exit`, so it cannot be dot-sourced or
    called in-process without terminating this harness).

    Cases and their required outcome:
      clean-baseline       -> Audit=0, Strict=0   (sanity check: the harness itself works)
      delete-block         -> Audit=2, Strict=2   (integrity: 1a missing>0)
      mutate-byte          -> Audit=2, Strict=2   (integrity: archive not append-only)
      extra-manifest-row   -> Audit=2, Strict=2   (integrity: manifest bijection broken)
      dup-block_id         -> Audit=2, Strict=2   (integrity: manifest bijection broken)
      corrupt-hash         -> Audit=2, Strict=2   (integrity: manifest bijection broken)
      stale-index          -> Audit=2, Strict=2   (integrity: index rebuild not zero-diff)
      archived-OPEN        -> Audit=0, Strict=1   (POLICY only, by design -- Audit tolerates
                                                    policy debt, Strict does not; neither
                                                    mode has an integrity failure here)

    ORDER-101 review-fix cases (added after the blind-review pass that found the C0
    validator itself had 4 blocker-class bugs -- see check_taskboard_archive.ps1's own
    doc comment for the fix numbering):
      corrupt-committed-manifest-caught-by-normal-run
                            -> Audit=2, Strict=2, AND the on-disk manifest file bytes
                               must be UNCHANGED after the run (fix 1: -Audit/-Strict
                               are read-only -- a corrupt COMMITTED manifest must be
                               caught, never silently regenerated-then-reported-clean;
                               tested with a NORMAL run, deliberately NOT -SkipArtifacts)
      cross-HEAD-zero-diff -> two -Generate runs against the REAL repo's archive file
                               read from two different git refs (HEAD and 4aebbc37) that
                               are known to carry byte-identical content (fix 2: manifest
                               identity is the archive's git blob SHA, not repo HEAD, so
                               it must not matter which commit HEAD is on) -- asserts the
                               two manifests/indexes are byte-identical, both exit 0
      block_id-swap-caught -> a manifest with two rows' block_id fields swapped (anchors,
                               hashes, and canonical_id left untouched, so the archive-wide
                               ID set still looks "complete") must still be caught
                               (fix 3: bijection now cross-checks every row field against
                               the block its anchor resolves to) -> Audit=2, Strict=2
      partial-stage-archived
                            -> Audit=0, Strict=1 (POLICY only). A block whose backtick
                               status verb is terminal (`STAGE2-DONE(...)`) but whose
                               header ALSO carries a pending-stage marker outside the
                               backticks (e.g. "-- Stage 2 = รอ...ตัดสิน...", mirroring the
                               real ORDER-071 case) must be flagged non-terminal-in-archive
                               despite the terminal verb (fix 4)

    Run: powershell -NoProfile -File scripts\_test\run_order101_negative_tests.ps1
    Exit code: 0 if every case matched its expected outcome, 1 otherwise.
#>
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
$fx = Join-Path $PSScriptRoot 'fixtures\order101'
$out = Join-Path $fx 'out'
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Force -Path $out | Out-Null }
$validator = Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1'

function Invoke-Validator {
    <#
        Runs the validator in a CHILD process (it calls `exit`) and returns the exit code.
        Uses powershell.exe explicitly so this harness's own exit code is unaffected.
    #>
    param([string]$Mode, [hashtable]$Params)

    function ConvertTo-QuotedArg {
        param([string]$Value)
        return '"' + ($Value -replace '"', '\"') + '"'
    }

    $argParts = New-Object System.Collections.Generic.List[string]
    $argParts.Add('-NoProfile')
    $argParts.Add('-File')
    $argParts.Add((ConvertTo-QuotedArg $validator))
    $argParts.Add("-$Mode")
    foreach ($key in $Params.Keys) {
        if ($key -eq 'SkipArtifacts') {
            if ($Params[$key]) { $argParts.Add('-SkipArtifacts') }
            continue
        }
        $argParts.Add("-$key")
        $argParts.Add((ConvertTo-QuotedArg ([string]$Params[$key])))
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = [string]::Join(' ', $argParts)
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [pscustomobject]@{ ExitCode = $proc.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

function New-CaseParams {
    param([string]$PreSplit, [string]$SplitActive, [string]$SplitArchive, [string]$CurrentActive, [string]$CurrentArchive, [string]$Tag, [switch]$SkipArtifacts, [string]$ManifestOverride, [string]$IndexOverride)
    $p = [ordered]@{
        RepoRoot             = $RepoRoot
        PreSplitSource       = "FILE:$PreSplit"
        SplitActiveSource    = "FILE:$SplitActive"
        SplitArchiveSource   = "FILE:$SplitArchive"
        CurrentActiveSource  = "FILE:$CurrentActive"
        CurrentArchiveSource = "FILE:$CurrentArchive"
        ManifestPath         = if ($ManifestOverride) { $ManifestOverride } else { Join-Path $out "$Tag`_manifest.csv" }
        IndexPath            = if ($IndexOverride) { $IndexOverride } else { Join-Path $out "$Tag`_index.md" }
        ExceptionsPath       = Join-Path $out "$Tag`_exceptions.md"
    }
    return $p
}

$results = New-Object System.Collections.Generic.List[object]

function Add-CaseResult {
    <#
        By default, seeds ManifestPath/IndexPath/ExceptionsPath with a matching
        -Generate pass FIRST (this is what a real workflow does: -Generate once,
        commit, then -Audit/-Strict validate read-only), then runs -Audit and
        -Strict against that. This is required now that -Audit/-Strict never write
        (ORDER-101 fix 1) -- without a prior -Generate, a "clean" fixture scenario
        would fail on 'manifest-missing' instead of exercising the actual check
        being tested.

        Pass -SkipSeedGenerate for cases that intentionally feed a PRE-CORRUPTED,
        already-on-disk manifest/index (the whole point of that case is that
        -Audit/-Strict must catch the corruption, not that this harness should
        regenerate a clean one first and paper over it).
    #>
    param([string]$Name, [hashtable]$Params, [int]$ExpectAudit, [int]$ExpectStrict, [switch]$SkipArtifacts, [switch]$SkipSeedGenerate)
    if ($SkipArtifacts) { $Params['SkipArtifacts'] = $true }
    if (-not $SkipSeedGenerate) {
        Invoke-Validator -Mode 'Generate' -Params $Params | Out-Null
    }
    $a = Invoke-Validator -Mode 'Audit' -Params $Params
    $s = Invoke-Validator -Mode 'Strict' -Params $Params
    $pass = ($a.ExitCode -eq $ExpectAudit) -and ($s.ExitCode -eq $ExpectStrict)
    $results.Add([pscustomobject]@{
        Name = $Name; ExpectAudit = $ExpectAudit; ActualAudit = $a.ExitCode
        ExpectStrict = $ExpectStrict; ActualStrict = $s.ExitCode; Pass = $pass
        AuditOut = $a.StdOut; StrictOut = $s.StdOut
    })
}

# --- 1. clean baseline (sanity check the harness + fixtures themselves) ---
$p = New-CaseParams -Tag 'clean' `
    -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\clean_current_archive.md"
Add-CaseResult -Name 'clean-baseline' -Params $p -ExpectAudit 0 -ExpectStrict 0

# --- 2. delete-block: ORDER-202 removed from split-archive AND current-archive (isolates to 1a) ---
$p = New-CaseParams -Tag 'del' `
    -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\del_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\del_current_archive.md"
Add-CaseResult -Name 'delete-block' -Params $p -ExpectAudit 2 -ExpectStrict 2

# --- 3. mutate-byte: current-archive ORDER-202 body byte-flipped vs split-archive (archive not append-only) ---
$p = New-CaseParams -Tag 'mut' `
    -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\mutate_current_archive.md"
Add-CaseResult -Name 'mutate-byte' -Params $p -ExpectAudit 2 -ExpectStrict 2

# --- 4. archived-OPEN: ORDER-204 non-terminal, consistently present everywhere (policy-only, no drift) ---
$p = New-CaseParams -Tag 'open' `
    -PreSplit "$fx\openarchive_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\openarchive_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\openarchive_current_archive.md"
Add-CaseResult -Name 'archived-OPEN (policy, not integrity)' -Params $p -ExpectAudit 0 -ExpectStrict 1

# --- 5-8. manifest/index corruption: reuse clean fixture content, hand-corrupt the ARTIFACT files,
#          rerun with -SkipArtifacts so the checker reads the corrupted file instead of regenerating it ---
$cleanP = New-CaseParams -Tag 'clean' `
    -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\clean_current_archive.md"
# Make sure a clean manifest/index exist on disk to seed the corrupted copies from.
# NOTE: only -Generate ever writes -- -Audit is now read-only (ORDER-101 fix 1), so seeding
# must use -Generate here (this used to say -Audit before the fix restructured the modes).
Invoke-Validator -Mode 'Generate' -Params $cleanP | Out-Null

foreach ($corrupt in @(
    @{ Name = 'extra-manifest-row'; ManifestFile = "$out\extra_row_manifest.csv" },
    @{ Name = 'dup-block_id';       ManifestFile = "$out\dup_id_manifest.csv" },
    @{ Name = 'corrupt-hash';       ManifestFile = "$out\corrupt_hash_manifest.csv" }
)) {
    $p = New-CaseParams -Tag 'clean' `
        -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
        -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\clean_current_archive.md" `
        -ManifestOverride $corrupt.ManifestFile -IndexOverride "$out\clean_index.md"
    Add-CaseResult -Name $corrupt.Name -Params $p -ExpectAudit 2 -ExpectStrict 2 -SkipArtifacts -SkipSeedGenerate
}

$p = New-CaseParams -Tag 'clean' `
    -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\clean_current_archive.md" `
    -ManifestOverride "$out\clean_manifest.csv" -IndexOverride "$out\stale_index.md"
Add-CaseResult -Name 'stale-index' -Params $p -ExpectAudit 2 -ExpectStrict 2 -SkipArtifacts -SkipSeedGenerate

# --- 9. FIX 1 (blocker): a corrupt COMMITTED manifest must be caught by a NORMAL -Audit/-Strict
#        run (no -SkipArtifacts) -- and, critically, that normal run must NOT overwrite it. This is
#        the exact bug the blind review found: -Audit used to regenerate (write) the manifest BEFORE
#        validating, so a corrupt committed manifest was silently overwritten and reported clean. ---
$fix1P = New-CaseParams -Tag 'fix1' `
    -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\clean_current_archive.md"
Invoke-Validator -Mode 'Generate' -Params $fix1P | Out-Null   # seed a clean, "committed-style" manifest+index
$fix1Rows = @(Import-Csv -Path $fix1P['ManifestPath'])
$fix1Rows[0].sha256 = ('deadbeef' * 8).Substring(0, 64)        # corrupt row 1's hash
$fix1Rows | Export-Csv -Path $fix1P['ManifestPath'] -NoTypeInformation -Encoding UTF8
$fix1Before = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($fix1P['ManifestPath']))

$fix1Audit  = Invoke-Validator -Mode 'Audit'  -Params $fix1P   # NORMAL run -- deliberately NOT -SkipArtifacts
$fix1Strict = Invoke-Validator -Mode 'Strict' -Params $fix1P   # NORMAL run -- deliberately NOT -SkipArtifacts
$fix1After  = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($fix1P['ManifestPath']))
$fix1NotOverwritten = ($fix1Before -eq $fix1After)

$results.Add([pscustomobject]@{
    Name = 'corrupt-committed-manifest-caught-by-normal-run (fix 1)'
    ExpectAudit = 2; ActualAudit = $fix1Audit.ExitCode
    ExpectStrict = 2; ActualStrict = $fix1Strict.ExitCode
    Pass = ($fix1Audit.ExitCode -eq 2) -and ($fix1Strict.ExitCode -eq 2) -and $fix1NotOverwritten
    AuditOut = $fix1Audit.StdOut + "`n[manifest file bytes unchanged after normal -Audit/-Strict run: $fix1NotOverwritten]"
    StrictOut = $fix1Strict.StdOut
})

# --- 10. FIX 2 (blocker): manifest identity must be the ARCHIVE's git blob SHA, not repo HEAD.
#        Proven against the REAL repo (not the synthetic fixtures): ARCHIVE_TASKBOARD_2026-07A.md's
#        content is byte-identical between HEAD and the 4aebbc37 split commit (verified: `git diff
#        4aebbc37 HEAD -- ARCHIVE_TASKBOARD_2026-07A.md` is empty), yet HEAD is a different commit SHA
#        than 4aebbc37 -- a "simulated HEAD difference" without creating any new commit. Regenerating
#        against CurrentArchiveSource=GIT:HEAD:... vs GIT:4aebbc37:... must produce byte-identical
#        manifest + index. ---
$fix2OutA = Join-Path $out 'fix2_headA'
$fix2OutB = Join-Path $out 'fix2_headB'
foreach ($d in @($fix2OutA, $fix2OutB)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null } }

$fix2Common = [ordered]@{
    RepoRoot            = $RepoRoot
    PreSplitSource      = 'GIT:4aebbc37^:AGENT_TASKBOARD.md'
    SplitActiveSource   = 'GIT:4aebbc37:AGENT_TASKBOARD.md'
    SplitArchiveSource  = 'GIT:4aebbc37:ARCHIVE_TASKBOARD_2026-07A.md'
    CurrentActiveSource = 'GIT:HEAD:AGENT_TASKBOARD.md'
}
$fix2A = [ordered]@{}; foreach ($k in $fix2Common.Keys) { $fix2A[$k] = $fix2Common[$k] }
$fix2A['CurrentArchiveSource'] = 'GIT:HEAD:ARCHIVE_TASKBOARD_2026-07A.md'
$fix2A['ManifestPath']   = Join-Path $fix2OutA 'manifest.csv'
$fix2A['IndexPath']      = Join-Path $fix2OutA 'index.md'
$fix2A['ExceptionsPath'] = Join-Path $fix2OutA 'exceptions.md'

$fix2B = [ordered]@{}; foreach ($k in $fix2Common.Keys) { $fix2B[$k] = $fix2Common[$k] }
$fix2B['CurrentArchiveSource'] = 'GIT:4aebbc37:ARCHIVE_TASKBOARD_2026-07A.md'
$fix2B['ManifestPath']   = Join-Path $fix2OutB 'manifest.csv'
$fix2B['IndexPath']      = Join-Path $fix2OutB 'index.md'
$fix2B['ExceptionsPath'] = Join-Path $fix2OutB 'exceptions.md'

$fix2AResult = Invoke-Validator -Mode 'Generate' -Params $fix2A
$fix2BResult = Invoke-Validator -Mode 'Generate' -Params $fix2B
$fix2ManifestEqual = ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($fix2A['ManifestPath'])) -eq [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($fix2B['ManifestPath'])))
$fix2IndexEqual    = ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($fix2A['IndexPath']))    -eq [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($fix2B['IndexPath'])))

$results.Add([pscustomobject]@{
    Name = 'cross-HEAD-zero-diff (fix 2, real repo, HEAD vs 4aebbc37)'
    ExpectAudit = 0; ActualAudit = $fix2AResult.ExitCode
    ExpectStrict = 0; ActualStrict = $fix2BResult.ExitCode
    Pass = $fix2ManifestEqual -and $fix2IndexEqual -and ($fix2AResult.ExitCode -eq 0) -and ($fix2BResult.ExitCode -eq 0)
    AuditOut = $fix2AResult.StdOut + "`n[manifest byte-identical across HEAD vs 4aebbc37: $fix2ManifestEqual] [index byte-identical: $fix2IndexEqual]"
    StrictOut = $fix2BResult.StdOut
})

# --- 11. FIX 3 (blocker): swapping two rows' block_id (anchors/hashes/canonical_id left untouched,
#        so the archive-wide ID set still looks "complete") must be caught by the new per-row
#        cross-check against the block each row's source_anchor actually resolves to. ---
$fix3P = New-CaseParams -Tag 'fix3' `
    -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\clean_current_archive.md"
Invoke-Validator -Mode 'Generate' -Params $fix3P | Out-Null
$fix3Rows = @(Import-Csv -Path $fix3P['ManifestPath'])
if ($fix3Rows.Count -lt 2) { throw 'fix3 fixture needs at least 2 archive blocks to swap block_id between' }
$tmp = $fix3Rows[0].block_id
$fix3Rows[0].block_id = $fix3Rows[1].block_id
$fix3Rows[1].block_id = $tmp
$fix3Rows | Export-Csv -Path $fix3P['ManifestPath'] -NoTypeInformation -Encoding UTF8

$fix3Audit  = Invoke-Validator -Mode 'Audit'  -Params $fix3P
$fix3Strict = Invoke-Validator -Mode 'Strict' -Params $fix3P
$results.Add([pscustomobject]@{
    Name = 'block_id-swap-caught-by-manifest-bijection (fix 3)'
    ExpectAudit = 2; ActualAudit = $fix3Audit.ExitCode
    ExpectStrict = 2; ActualStrict = $fix3Strict.ExitCode
    Pass = ($fix3Audit.ExitCode -eq 2) -and ($fix3Strict.ExitCode -eq 2)
    AuditOut = $fix3Audit.StdOut; StrictOut = $fix3Strict.StdOut
})

# --- 12. FIX 4: a block whose backtick status verb is terminal (`STAGE2-DONE(...)`) but whose header
#        ALSO carries a pending-stage marker OUTSIDE the backticks (mirrors the real ORDER-071 case:
#        "`STAGE2-DONE(...)` -- Stage 3 = รอ main session ตัดสินตามเกณฑ์...") must be flagged
#        non-terminal-in-archive despite the terminal verb. Policy-only (no drift/integrity issue). ---
$p = New-CaseParams -Tag 'partial' `
    -PreSplit "$fx\partialstage_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\partialstage_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\partialstage_current_archive.md"
Add-CaseResult -Name 'partial-stage-archived (fix 4, mirrors real ORDER-071)' -Params $p -ExpectAudit 0 -ExpectStrict 1

# --- report ---
Write-Host ''
Write-Host '=== ORDER-101 negative test suite results ==='
$allPass = $true
foreach ($r in $results) {
    $status = if ($r.Pass) { 'PASS' } else { $allPass = $false; 'FAIL' }
    Write-Host ("[{0}] {1,-40} audit expect={2} actual={3} | strict expect={4} actual={5}" -f `
        $status, $r.Name, $r.ExpectAudit, $r.ActualAudit, $r.ExpectStrict, $r.ActualStrict)
}
Write-Host ''
if ($allPass) {
    Write-Host 'ALL CASES PASSED'
    exit 0
} else {
    Write-Host 'ONE OR MORE CASES FAILED -- see above'
    exit 1
}
