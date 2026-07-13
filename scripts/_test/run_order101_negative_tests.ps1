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
                            -> Audit=0, Strict=0 (was Strict=1 before ORDER-102 Contract
                               C1: this fixture's ORDER-205 carries a terminal backtick
                               verb (`STAGE2-DONE(...)`) PLUS a pending-stage marker
                               outside the backticks -- raising a raw non-terminal-in-
                               archive exception (fix 4, unchanged) -- but the fixture
                               also already ships a matching `## REVIEW ORDER-205`
                               REVIEWED block (mirroring the real archive's `## REVIEW
                               ORDER-071`). Contract C1 Source A now canonically closes
                               any raw exception whose canonical id is covered by such a
                               block, so this fixture's one raw exception is closed and
                               unresolved=0 -- Strict flips to 0. See
                               reviewmismatch-does-not-close below for the negative
                               (wrong id = stays unresolved) counterpart.

    ORDER-101 blind-review round 2 cases (3 fixes + 1 polish):
      stale-exceptions-caught-by-normal-run (fix 1)
                            -> Audit=2, Strict=2, AND the on-disk RECONCILE_EXCEPTIONS.md
                               bytes must be UNCHANGED after the run. Mirrors
                               corrupt-committed-manifest-caught-by-normal-run above, but
                               for the exceptions report: -Audit/-Strict never wrote it
                               before this fix, so a stale/corrupted/deleted committed
                               RECONCILE_EXCEPTIONS.md was never caught. Tested with a
                               NORMAL run (deliberately NOT -SkipArtifacts).
      generated-extra-zero-matches (fix 3)
                            -> Audit=2, Strict=2 (integrity: generated-extra-ambiguous,
                               count=0). The old guard (`-gt 1`) let 0 matches silently
                               pass; fixed guard (`-ne 1`) requires EXACTLY 1.
      generated-extra-two-matches (fix 3)
                            -> Audit=2, Strict=2 (integrity: generated-extra-ambiguous,
                               count=2). Already caught by the old guard too, but kept as
                               an explicit regression case alongside zero-matches.

    ORDER-101 fixture hygiene (fix 2): ALL generator output written by this harness goes
    under a throwaway directory in $env:TEMP -- never into scripts/_test/fixtures/order101/
    (tracked fixtures are INPUTS only). The handful of genuinely pre-corrupted INPUT
    fixtures the tests read (corrupt_hash_manifest.csv, extra_row_manifest.csv,
    dup_id_manifest.csv, stale_index.md) live directly under fixtures/order101/, not in a
    generated-output directory.

    ORDER-102 Contract C1 cases (canonical review linkage: closes raw exceptions via a
    REVIEW-block, Source A, or a C1-CLOSURE block, Source B -- see check_taskboard_archive.ps1's
    "CONTRACT C1" section):
      reviewmismatch-does-not-close
                            -> Audit=0, Strict=1. ORDER-206 raises 2 raw exceptions
                               (terminal-no-linked-review + non-terminal-in-archive,
                               mirroring ORDER-205/real ORDER-071) but the only REVIEW
                               block anywhere in this fixture targets a DIFFERENT
                               canonical id (209, not 206) -- Source A must NOT close
                               206's exceptions just because *a* REVIEWED REVIEW block
                               exists somewhere in the corpus. Negative counterpart of
                               partial-stage-archived above.
      c1closure-correct-sha-closes-exactly-one-kind
                            -> Audit=0, Strict=1. ORDER-210 raises 2 raw exceptions of
                               DIFFERENT kinds against the SAME block_id
                               (terminal-no-linked-review + cross-active-and-archive). A
                               C1-CLOSURE block with one row keyed
                               (terminal-no-linked-review, that block_id, its CURRENT
                               sha256) must close ONLY that one kind -- the
                               cross-active-and-archive exception for the identical
                               block_id must remain unresolved (Source B keys on the
                               EXACT (kind, block_id, block_sha256) triple, never on
                               canonical id or block_id alone).
      c1closure-stale-sha-stays-unresolved
                            -> Audit=0, Strict=1 (still, not 0). Same fixture as above
                               but the C1-CLOSURE row's block_sha256 is deliberately
                               wrong (block "edited" since the row was written) -- the
                               closure must be rejected as STALE, reported as such, and
                               both raw exceptions must stay unresolved (never silently
                               honored on a hash mismatch).
      c1closure-unknown-row-is-integrity
                            -> Audit=2, Strict=2. A C1-CLOSURE row whose (kind,
                               block_id) matches no detected raw exception at all is an
                               INTEGRITY failure (kind='c1-closure-unknown-row'), not a
                               silently-ignored no-op.
      c1closure-duplicate-row-is-integrity
                            -> Audit=2, Strict=2. Two C1-CLOSURE rows for the identical
                               (kind, block_id) is an INTEGRITY failure
                               (kind='c1-closure-duplicate-row'), even though the first
                               row alone would have closed its exception validly.

    Run: powershell -NoProfile -File scripts\_test\run_order101_negative_tests.ps1
    Exit code: 0 if every case matched its expected outcome, 1 otherwise.
#>
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
$fx = Join-Path $PSScriptRoot 'fixtures\order101'
# ORDER-101 fix 2: ALL test-generated output goes to a throwaway dir under $env:TEMP --
# never into the tracked fixtures directory (a prior version wrote -Generate output over
# scripts/_test/fixtures/order101/out/, leaving tracked fixtures dirty after every run).
# Wiped and recreated at the start of every run so stale leftovers from a prior run can't
# contaminate results.
# Per-process unique dir ($PID) so two suites running concurrently can't collide on
# a shared scratch path (hygiene fix, Codex r3).
$out = Join-Path $env:TEMP ("order101_negtests_" + $PID)
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force -Path $out | Out-Null
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
    @{ Name = 'extra-manifest-row'; ManifestFile = "$fx\extra_row_manifest.csv" },
    @{ Name = 'dup-block_id';       ManifestFile = "$fx\dup_id_manifest.csv" },
    @{ Name = 'corrupt-hash';       ManifestFile = "$fx\corrupt_hash_manifest.csv" }
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
    -ManifestOverride "$out\clean_manifest.csv" -IndexOverride "$fx\stale_index.md"
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

# --- 9b. FIX 1, round 2 (blind-review blocker): -Audit/-Strict validated the manifest +
#         index but never RECONCILE_EXCEPTIONS.md itself. A corrupt COMMITTED exceptions
#         report must be caught by a NORMAL run (no -SkipArtifacts) -- and, critically,
#         that normal run must NOT overwrite it. Mirrors the fix-1 manifest case above,
#         but corrupting ExceptionsPath instead of ManifestPath. ---
$fixExP = New-CaseParams -Tag 'fixex' `
    -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\clean_current_archive.md"
Invoke-Validator -Mode 'Generate' -Params $fixExP | Out-Null   # seed a clean, "committed-style" manifest+index+exceptions
'# CORRUPTED -- hand-edited stray content, generator was not re-run' | Set-Content -Path $fixExP['ExceptionsPath'] -Encoding UTF8 -NoNewline
$fixExBefore = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($fixExP['ExceptionsPath']))

$fixExAudit  = Invoke-Validator -Mode 'Audit'  -Params $fixExP   # NORMAL run -- deliberately NOT -SkipArtifacts
$fixExStrict = Invoke-Validator -Mode 'Strict' -Params $fixExP   # NORMAL run -- deliberately NOT -SkipArtifacts
$fixExAfter  = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($fixExP['ExceptionsPath']))
$fixExNotOverwritten = ($fixExBefore -eq $fixExAfter)

$results.Add([pscustomobject]@{
    Name = 'stale-exceptions-caught-by-normal-run (fix 1)'
    ExpectAudit = 2; ActualAudit = $fixExAudit.ExitCode
    ExpectStrict = 2; ActualStrict = $fixExStrict.ExitCode
    Pass = ($fixExAudit.ExitCode -eq 2) -and ($fixExStrict.ExitCode -eq 2) -and $fixExNotOverwritten
    AuditOut = $fixExAudit.StdOut + "`n[exceptions file bytes unchanged after normal -Audit/-Strict run: $fixExNotOverwritten]"
    StrictOut = $fixExStrict.StdOut
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
# ORDER-102 Contract C1: this fixture's ORDER-205 raises a raw non-terminal-in-archive
# exception (fix 4, unchanged) but ships its own matching REVIEWED "## REVIEW ORDER-205"
# block (mirroring the real "## REVIEW ORDER-071"), so Source A now canonically closes
# it -> unresolved=0 -> Strict=0 (was Strict=1 pre-C1; see docstring above).
Add-CaseResult -Name 'partial-stage-archived (fix 4, closed by C1 Source A via its own REVIEW ORDER-205)' -Params $p -ExpectAudit 0 -ExpectStrict 0

# --- 13. FIX 3 off-by-one, zero matches: the generated-extra header pattern matches NO
#         block in split-active+split-archive (the expected manual "## ... ARCHIVED
#         ORDERS INDEX" block is missing/renamed). The OLD guard (`-gt 1`) let this
#         through silently; the fixed guard (`-ne 1`) must catch it. ---
$p = New-CaseParams -Tag 'zero' `
    -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\zero_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
    -CurrentActive "$fx\zero_current_active.md" -CurrentArchive "$fx\clean_current_archive.md"
Add-CaseResult -Name 'generated-extra-zero-matches (fix 3)' -Params $p -ExpectAudit 2 -ExpectStrict 2

# --- 14. FIX 3 off-by-one, two matches: the generated-extra header pattern matches TWO
#         blocks (ambiguous exclusion). Already caught by the OLD guard too (`-gt 1`) --
#         kept as an explicit regression case alongside zero-matches. ---
$p = New-CaseParams -Tag 'two' `
    -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\two_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
    -CurrentActive "$fx\two_current_active.md" -CurrentArchive "$fx\clean_current_archive.md"
Add-CaseResult -Name 'generated-extra-two-matches (fix 3)' -Params $p -ExpectAudit 2 -ExpectStrict 2

# ============================================================================
# ORDER-102 Contract C1: canonical review linkage (Source A REVIEW-block / Source B
# C1-CLOSURE block). See the docstring above for the full description of each case.
# ============================================================================

# --- 15. Source A negative: a REVIEW block exists in the corpus, but it targets a
#         DIFFERENT canonical id than the one raising the raw exception -- must NOT
#         close it. Negative counterpart of partial-stage-archived (test 12 above),
#         which is the Source A POSITIVE case (REVIEW-block closes the matching
#         exception). ---
$p = New-CaseParams -Tag 'reviewmismatch' `
    -PreSplit "$fx\reviewmismatch_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\reviewmismatch_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\reviewmismatch_current_archive.md"
Add-CaseResult -Name 'reviewmismatch-does-not-close (Source A id must match exactly)' -Params $p -ExpectAudit 0 -ExpectStrict 1

# --- 16-19. Source B (C1-CLOSURE block): ORDER-210 raises 2 raw exceptions of DIFFERENT
#         kinds against the SAME block_id (terminal-no-linked-review archive-side +
#         cross-active-and-archive, since 210 is unreviewed and appears in both boards).
#         Each variant below is identical except for its C1-CLOSURE table's row(s). ---
function New-C1ClosureParams {
    param([string]$ActiveVariantFile, [string]$Tag)
    return New-CaseParams -Tag $Tag `
        -PreSplit "$fx\c1closure_presplit.md" -SplitActive "$fx\c1closure_split_active.md" -SplitArchive "$fx\c1closure_split_archive.md" `
        -CurrentActive "$fx\$ActiveVariantFile" -CurrentArchive "$fx\c1closure_current_archive.md"
}

# --- 16. Correct sha closes EXACTLY the one (kind, block_id) it targets; the other
#         kind of the identical block_id must remain unresolved. Checked both by exit
#         code (Strict=1, not 0) AND by inspecting stdout for the specific kind that
#         stayed unresolved, so a bug that closed BOTH (or neither) can't hide behind
#         a coincidentally-matching exit code. ---
$c1CorrectP = New-C1ClosureParams -ActiveVariantFile 'c1closure_current_active_correct.md' -Tag 'c1correct'
Invoke-Validator -Mode 'Generate' -Params $c1CorrectP | Out-Null
$c1CorrectAudit  = Invoke-Validator -Mode 'Audit'  -Params $c1CorrectP
$c1CorrectStrict = Invoke-Validator -Mode 'Strict' -Params $c1CorrectP
$c1CorrectClosedRight   = $c1CorrectStrict.StdOut -match 'closed via B-C1-closure-block'
$c1CorrectOnlyOneLeft   = ($c1CorrectStrict.StdOut -match 'unresolved \(raw minus canonically_reviewed\): 1') -and
                          ($c1CorrectStrict.StdOut -match '\[cross-active-and-archive\][^\r\n]*210\|ORDER\|current-archive#1')
$results.Add([pscustomobject]@{
    Name = 'c1closure-correct-sha-closes-exactly-one-kind'
    ExpectAudit = 0; ActualAudit = $c1CorrectAudit.ExitCode
    ExpectStrict = 1; ActualStrict = $c1CorrectStrict.ExitCode
    Pass = ($c1CorrectAudit.ExitCode -eq 0) -and ($c1CorrectStrict.ExitCode -eq 1) -and $c1CorrectClosedRight -and $c1CorrectOnlyOneLeft
    AuditOut = $c1CorrectAudit.StdOut + "`n[closed-via-B found: $c1CorrectClosedRight] [exactly cross-active-and-archive left unresolved: $c1CorrectOnlyOneLeft]"
    StrictOut = $c1CorrectStrict.StdOut
})

# --- 17. Stale sha (block_sha256 in the C1-CLOSURE row does not match the block's
#         CURRENT hash) must NOT be honored -- both raw exceptions stay unresolved and
#         the staleness must be reported in the output, not silently swallowed. ---
$c1StaleP = New-C1ClosureParams -ActiveVariantFile 'c1closure_current_active_stale.md' -Tag 'c1stale'
Invoke-Validator -Mode 'Generate' -Params $c1StaleP | Out-Null
$c1StaleAudit  = Invoke-Validator -Mode 'Audit'  -Params $c1StaleP
$c1StaleStrict = Invoke-Validator -Mode 'Strict' -Params $c1StaleP
$c1StaleReported = $c1StaleStrict.StdOut -match 'STALE'
$c1StaleBothLeft = $c1StaleStrict.StdOut -match 'unresolved \(raw minus canonically_reviewed\): 2'
$results.Add([pscustomobject]@{
    Name = 'c1closure-stale-sha-stays-unresolved'
    ExpectAudit = 0; ActualAudit = $c1StaleAudit.ExitCode
    ExpectStrict = 1; ActualStrict = $c1StaleStrict.ExitCode
    Pass = ($c1StaleAudit.ExitCode -eq 0) -and ($c1StaleStrict.ExitCode -eq 1) -and $c1StaleReported -and $c1StaleBothLeft
    AuditOut = $c1StaleAudit.StdOut + "`n[STALE reported: $c1StaleReported] [both raw exceptions still unresolved: $c1StaleBothLeft]"
    StrictOut = $c1StaleStrict.StdOut
})

# --- 18. A C1-CLOSURE row whose (kind, block_id) matches no detected raw exception at
#         all is an INTEGRITY failure (c1-closure-unknown-row), not a silent no-op. ---
$c1UnknownP = New-C1ClosureParams -ActiveVariantFile 'c1closure_current_active_unknown.md' -Tag 'c1unknown'
Add-CaseResult -Name 'c1closure-unknown-row-is-integrity' -Params $c1UnknownP -ExpectAudit 2 -ExpectStrict 2

# --- 19. Two C1-CLOSURE rows for the identical (kind, block_id) is an INTEGRITY
#         failure (c1-closure-duplicate-row), even though the first row alone would
#         have closed its exception validly. ---
$c1DupP = New-C1ClosureParams -ActiveVariantFile 'c1closure_current_active_duplicate.md' -Tag 'c1dup'
Add-CaseResult -Name 'c1closure-duplicate-row-is-integrity' -Params $c1DupP -ExpectAudit 2 -ExpectStrict 2

# ============================================================================
# ORDER-103: LIVING APPEND-ONLY LOG evolution (Contract C1 migration legitimacy).
# Shared base fixtures: livinglog_presplit.md / livinglog_split_active.md
# (manual index + ORDER-302 OPEN) / livinglog_split_archive.md (ORDER-301 DONE +
# its REVIEW). Each case below varies only CurrentActiveSource/CurrentArchiveSource
# to isolate exactly one behavior of the new (1b-ARCHIVE append-only) or
# (1b-ACTIVE conservation) checks.
# ============================================================================

# --- 20. archive-append-allowed: current-archive = split-archive + one NEW terminal
#         block (a self-attesting REVIEWED REVIEW-note for ORDER-302, appended after
#         split -- mirrors a C1 migration landing a closure/review block). Must NOT be
#         a failure -- it is a post-split append, reported not rejected. ---
$p = New-CaseParams -Tag 'llappend' `
    -PreSplit "$fx\livinglog_presplit.md" -SplitActive "$fx\livinglog_split_active.md" -SplitArchive "$fx\livinglog_split_archive.md" `
    -CurrentActive "$fx\livinglog_split_active.md" -CurrentArchive "$fx\livinglog_current_archive_append.md"
$llAppendAudit  = Invoke-Validator -Mode 'Generate' -Params $p
$llAppendAudit  = Invoke-Validator -Mode 'Audit'  -Params $p
$llAppendStrict = Invoke-Validator -Mode 'Strict' -Params $p
$llAppendListed = $llAppendAudit.StdOut -match 'post_split_archive_appends=1' -and $llAppendAudit.StdOut -match 'post-split append \(ok\):\s*## REVIEW ORDER-302'
$results.Add([pscustomobject]@{
    Name = 'archive-append-allowed (ORDER-103 1b-ARCHIVE)'
    ExpectAudit = 0; ActualAudit = $llAppendAudit.ExitCode
    ExpectStrict = 0; ActualStrict = $llAppendStrict.ExitCode
    Pass = ($llAppendAudit.ExitCode -eq 0) -and ($llAppendStrict.ExitCode -eq 0) -and $llAppendListed
    AuditOut = $llAppendAudit.StdOut + "`n[appended block listed as post-split append, not a failure: $llAppendListed]"
    StrictOut = $llAppendStrict.StdOut
})

# --- 21. archive-mutate-split-block: ORDER-301's body byte-changed in current-archive
#         vs split-archive (header unchanged) -- the immutable prefix must be caught. ---
$p = New-CaseParams -Tag 'llmutate' `
    -PreSplit "$fx\livinglog_presplit.md" -SplitActive "$fx\livinglog_split_active.md" -SplitArchive "$fx\livinglog_split_archive.md" `
    -CurrentActive "$fx\livinglog_split_active.md" -CurrentArchive "$fx\livinglog_current_archive_mutate.md"
Add-CaseResult -Name 'archive-mutate-split-block (ORDER-103 1b-ARCHIVE)' -Params $p -ExpectAudit 2 -ExpectStrict 2

# --- 22. archive-delete-split-block: REVIEW ORDER-301 removed entirely from
#         current-archive vs split-archive -- a true deletion, not an append, must
#         still be caught. ---
$p = New-CaseParams -Tag 'lldelete' `
    -PreSplit "$fx\livinglog_presplit.md" -SplitActive "$fx\livinglog_split_active.md" -SplitArchive "$fx\livinglog_split_archive.md" `
    -CurrentActive "$fx\livinglog_split_active.md" -CurrentArchive "$fx\livinglog_current_archive_delete.md"
Add-CaseResult -Name 'archive-delete-split-block (ORDER-103 1b-ARCHIVE)' -Params $p -ExpectAudit 2 -ExpectStrict 2

# --- 23. active-remove-nonorder: the manual "## ... ARCHIVED ORDERS INDEX" block is
#         dropped from current-active (ORDER-302 untouched) -- a non-order removal is
#         explicitly ALLOWED under the conservation model (it was never a conserved
#         unit), must not be a failure. ---
$p = New-CaseParams -Tag 'llnonorder' `
    -PreSplit "$fx\livinglog_presplit.md" -SplitActive "$fx\livinglog_split_active.md" -SplitArchive "$fx\livinglog_split_archive.md" `
    -CurrentActive "$fx\livinglog_current_active_removenonorder.md" -CurrentArchive "$fx\livinglog_split_archive.md"
Add-CaseResult -Name 'active-remove-nonorder (ORDER-103 1b-ACTIVE, allowed)' -Params $p -ExpectAudit 0 -ExpectStrict 0

# --- 24. active-order-lost: ORDER-302 removed from current-active and NOT placed in
#         current-archive either -- the order vanished with no trace. Must be caught
#         as an INTEGRITY failure (active-order-lost), the one thing conservation
#         actually gates on. ---
$p = New-CaseParams -Tag 'lllost' `
    -PreSplit "$fx\livinglog_presplit.md" -SplitActive "$fx\livinglog_split_active.md" -SplitArchive "$fx\livinglog_split_archive.md" `
    -CurrentActive "$fx\livinglog_current_active_orderlost.md" -CurrentArchive "$fx\livinglog_split_archive.md"
$llLostAudit = Invoke-Validator -Mode 'Generate' -Params $p
$llLostAudit  = Invoke-Validator -Mode 'Audit'  -Params $p
$llLostStrict = Invoke-Validator -Mode 'Strict' -Params $p
$llLostReported = $llLostAudit.StdOut -match 'active-order-lost' -and $llLostAudit.StdOut -match 'ACTIVE-ORDER-LOST'
$results.Add([pscustomobject]@{
    Name = 'active-order-lost (ORDER-103 1b-ACTIVE, integrity failure)'
    ExpectAudit = 2; ActualAudit = $llLostAudit.ExitCode
    ExpectStrict = 2; ActualStrict = $llLostStrict.ExitCode
    Pass = ($llLostAudit.ExitCode -eq 2) -and ($llLostStrict.ExitCode -eq 2) -and $llLostReported
    AuditOut = $llLostAudit.StdOut + "`n[active-order-lost kind reported: $llLostReported]"
    StrictOut = $llLostStrict.StdOut
})

# --- 25. active-order-moved-verbatim: ORDER-302 removed from current-active but
#         appended VERBATIM (byte-identical block) to current-archive -- conserved,
#         not lost, so NOT an integrity failure. It DOES still carry its original
#         `OPEN` status, which independently raises a raw non-terminal-in-archive
#         POLICY exception now that it lives in the archive (Strict=1) -- proving the
#         conservation (integrity) and policy-hygiene checks are decoupled: moving an
#         order verbatim is always structurally safe even when it still needs a
#         status cleanup. ---
$p = New-CaseParams -Tag 'llmoved' `
    -PreSplit "$fx\livinglog_presplit.md" -SplitActive "$fx\livinglog_split_active.md" -SplitArchive "$fx\livinglog_split_archive.md" `
    -CurrentActive "$fx\livinglog_current_active_orderlost.md" -CurrentArchive "$fx\livinglog_current_archive_orderconserved.md"
$llMovedAudit = Invoke-Validator -Mode 'Generate' -Params $p
$llMovedAudit  = Invoke-Validator -Mode 'Audit'  -Params $p
$llMovedStrict = Invoke-Validator -Mode 'Strict' -Params $p
$llMovedNotLost = -not ($llMovedAudit.StdOut -match 'ACTIVE-ORDER-LOST\(!\)')
$llMovedAppended = $llMovedAudit.StdOut -match 'post_split_archive_appends=1'
$results.Add([pscustomobject]@{
    Name = 'active-order-moved-verbatim (ORDER-103, conserved, integrity clean)'
    ExpectAudit = 0; ActualAudit = $llMovedAudit.ExitCode
    ExpectStrict = 1; ActualStrict = $llMovedStrict.ExitCode
    Pass = ($llMovedAudit.ExitCode -eq 0) -and ($llMovedStrict.ExitCode -eq 1) -and $llMovedNotLost -and $llMovedAppended
    AuditOut = $llMovedAudit.StdOut + "`n[not reported as active-order-lost: $llMovedNotLost] [counted as post-split append: $llMovedAppended]"
    StrictOut = $llMovedStrict.StdOut
})

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
