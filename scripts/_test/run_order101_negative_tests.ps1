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
    param([string]$Name, [hashtable]$Params, [int]$ExpectAudit, [int]$ExpectStrict, [switch]$SkipArtifacts)
    if ($SkipArtifacts) { $Params['SkipArtifacts'] = $true }
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
Invoke-Validator -Mode 'Audit' -Params $cleanP | Out-Null

foreach ($corrupt in @(
    @{ Name = 'extra-manifest-row'; ManifestFile = "$out\extra_row_manifest.csv" },
    @{ Name = 'dup-block_id';       ManifestFile = "$out\dup_id_manifest.csv" },
    @{ Name = 'corrupt-hash';       ManifestFile = "$out\corrupt_hash_manifest.csv" }
)) {
    $p = New-CaseParams -Tag 'clean' `
        -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
        -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\clean_current_archive.md" `
        -ManifestOverride $corrupt.ManifestFile -IndexOverride "$out\clean_index.md"
    Add-CaseResult -Name $corrupt.Name -Params $p -ExpectAudit 2 -ExpectStrict 2 -SkipArtifacts
}

$p = New-CaseParams -Tag 'clean' `
    -PreSplit "$fx\clean_presplit.md" -SplitActive "$fx\clean_split_active.md" -SplitArchive "$fx\clean_split_archive.md" `
    -CurrentActive "$fx\clean_current_active.md" -CurrentArchive "$fx\clean_current_archive.md" `
    -ManifestOverride "$out\clean_manifest.csv" -IndexOverride "$out\stale_index.md"
Add-CaseResult -Name 'stale-index' -Params $p -ExpectAudit 2 -ExpectStrict 2 -SkipArtifacts

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
