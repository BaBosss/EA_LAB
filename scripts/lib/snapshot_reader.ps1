<#
snapshot_reader.ps1 - ORDER-612 (slice S4). The ONE way a PowerShell reader obtains the
control-room snapshot.

WHY THIS EXISTS
  Codex audit 6 measured that NO reader called load_verified(). Every consumer did
  `Get-Content | ConvertFrom-Json` and trusted whatever came back, which means the whole
  build-side verdict machinery was protecting a door nobody walked through. This is that door.

THREE STATES, AND WHY THREE
  OK           the file exists AND its stored verdict is the verdict its own evidence produces
               AND it validates against ControlRoomSnapshotV5.
  REFUSED      the file exists and the check said NO. A statement about the DOCUMENT.
  UNAVAILABLE  the file is not there, or the checker could not run at all (no interpreter, no
               ajv/node, unreadable schema). A statement about THE INSTRUMENT.

  Two states would be a bug, not a simplification. Collapsing UNAVAILABLE into REFUSED reports an
  uninstalled node as a corrupt snapshot; collapsing it into OK is the defect this whole slice
  exists to close.

  A second field, Code, subdivides them WITHOUT letting a caller pattern-match on prose:
    OK        -> Code OK
    REFUSED   -> Code MALFORMED  (exit 4: unparseable bytes, or valid JSON that is not one of
                                  these documents -- "we have no coverage data")
              -> Code VERDICT    (exit 1: it IS one of these and its own evidence refuses it)
    UNAVAILABLE -> Code MISSING  (no file)
                -> Code TOOL     (exit 3, or no interpreter / validator / a crash)
  Callers map Code to their own tokens. Deriving a token by matching the Reason STRING would be
  shape 2 -- testing a name where a value is what matters -- so Reason is for humans only.

  snapshot_validator exits 0 / 1 / 3 / 4, and it grew BOTH 3 and 4 for this caller: ORDER-612
  measured that "ajv is missing", "this file is corrupt" and "this verdict is a lie" all shared
  exit 1, the last one as an unhandled traceback.

WHAT EACH READER DOES WITH THEM IS PRE-REGISTERED, NOT DECIDED HERE, and the two differ
ON PURPOSE because the cost of failing closed is not the same in both places:

  scripts\make_status.ps1        runs after EVERY commit and does not own the fleet verdict.
                                 OK -> render. REFUSED -> banner, NO numbers, exit 0.
                                 UNAVAILABLE -> banner, NO numbers, exit 0.
                                 Failing closed here would turn "there is no snapshot yet" into
                                 "this repo cannot finish a commit", which is a self-inflicted
                                 outage, not a safety property.

  scripts\lib\monitor_coverage   is the daily chain whose ENTIRE JOB is coverage.
                                 OK -> proceed. REFUSED -> failure token. UNAVAILABLE -> failure
                                 token. Here, absence IS the loudest finding available, and the
                                 chain is not on anybody's commit path.

  The invariant both share, and the only one that matters: NEITHER EVER RENDERS A NUMBER FROM AN
  UNVERIFIED SNAPSHOT. "Refuse to render" is about the numbers, not about the exit code.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
NOTE: this file deliberately sets NO $ErrorActionPreference and NO Set-StrictMode. Dot-sourcing
does not create a scope, so either would silently change the rules the CALLING script runs under
for the rest of that script (memory: strictmode-in-dotsourced-library-leaks).
#>
. (Join-Path $PSScriptRoot 'repo_paths.ps1')

function Get-VerifiedSnapshot {
    <#
      Returns:
        State     [string] 'OK' | 'REFUSED' | 'UNAVAILABLE'
        Reason    [string] one line, always populated for REFUSED/UNAVAILABLE, '' for OK
        Document  [object] the parsed snapshot, ONLY when State is 'OK'. $null otherwise --
                           deliberately, so a caller cannot accidentally read numbers off a
                           document the checker rejected.
      Never throws. An unverifiable snapshot is a RESULT, not an exception.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SnapshotPath,
        [string]$RepoRoot = ''
    )

    if (-not $RepoRoot) { $RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSScriptRoot }

    $py = Join-Path $RepoRoot 'tools\python312\python.exe'
    $validator = Join-Path $RepoRoot '_triage\factory_os\snapshot_validator.py'

    if (-not (Test-Path -LiteralPath $SnapshotPath)) {
        return [pscustomobject]@{
            State = 'UNAVAILABLE'; Document = $null
            Code = 'MISSING'
            Reason = "no snapshot at $SnapshotPath"
        }
    }
    if (-not (Test-Path -LiteralPath $py)) {
        return [pscustomobject]@{
            State = 'UNAVAILABLE'; Document = $null
            Code = 'TOOL'
            Reason = "the pinned interpreter $py is missing, so the snapshot could not be checked -- this says nothing about the snapshot"
        }
    }
    if (-not (Test-Path -LiteralPath $validator)) {
        return [pscustomobject]@{
            State = 'UNAVAILABLE'; Document = $null
            Code = 'TOOL'
            Reason = "$validator is missing, so the snapshot could not be checked"
        }
    }

    # The validator must run from the repo root: SCHEMA_PATH inside it is repo-relative, and a
    # schema it cannot find is a TOOL FAILURE it reports as exit 3 -- which is correct, but it
    # would make every caller report UNAVAILABLE for a reason that is entirely our fault.
    #
    # MEASURED 2026-07-31, and it is why stderr goes to a FILE instead of through `2>&1`:
    # merging a native command's stderr into the pipeline wraps each line in an ErrorRecord, so
    # under $ErrorActionPreference = 'Stop' the merge THROWS -- and this function then reported a
    # corrupt snapshot as UNAVAILABLE ("could not invoke") while reporting the SAME file as
    # REFUSED under 'Continue'. The verdict depended on the CALLER'S preference variable, which is
    # exactly the hazard run_monitor_integrity_tests.ps1 already asserts against for this library
    # ("malformed json is still caught under $ErrorActionPreference = Continue"). That existing
    # cage is what caught it. A reader whose answer depends on an ambient preference is not a
    # reader. Redirecting to a file keeps stderr as plain text and out of the pipeline entirely.
    $prev = Get-Location
    $errFile = Join-Path ([System.IO.Path]::GetTempPath()) ("snapread_" + [guid]::NewGuid().ToString('N') + ".err")
    $out = $null
    $rc = $null
    try {
        Set-Location -LiteralPath $RepoRoot
        $out = & $py $validator verify $SnapshotPath 2>$errFile
        $rc = $LASTEXITCODE
    } catch {
        return [pscustomobject]@{
            State = 'UNAVAILABLE'; Code = 'TOOL'; Document = $null
            Reason = "could not invoke the snapshot validator: $($_.Exception.Message)"
        }
    } finally {
        Set-Location -LiteralPath $prev
    }
    $errText = ''
    if (Test-Path -LiteralPath $errFile) {
        $errText = (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
        Remove-Item -LiteralPath $errFile -ErrorAction SilentlyContinue
    }
    $text = ((@($out) -join ' ') + ' ' + $errText).Trim()

    if ($rc -eq 0) {
        # SHAPE-1 FIX (ORDER-612 round 1, found by probing). This used to run the validator over
        # $SnapshotPath and then read $SnapshotPath AGAIN to parse it -- two reads, two moments,
        # and the bytes handed to the caller were not the bytes anything had checked. The
        # validator now publishes the sha256 of the exact bytes it verified; this read is hashed
        # and compared, so a file that changed in between is UNAVAILABLE ("the instrument lost
        # its footing") rather than silently accepted.
        $claimed = ''
        foreach ($line in @($out)) {
            if ("$line" -match '^verified-sha256:\s*([0-9a-f]{64})$') { $claimed = $Matches[1] }
        }
        if ($claimed -eq '') {
            return [pscustomobject]@{
                State = 'UNAVAILABLE'; Code = 'TOOL'; Document = $null
                Reason = "the validator reported OK but published no verified-sha256 line, so this reader cannot prove it is reading the bytes that were verified"
            }
        }
        # ONE READ. BLIND AUDIT 2026-07-31, reproduced: the first fix hashed the file with
        # Get-FileHash and then opened it AGAIN with Get-Content to parse -- so it proved a digest
        # about one read and handed back a different one. Swapping the file between the two
        # commands produced State=OK carrying an edited verdict, while the validator run against
        # that same file afterwards exited 1. The fix for the first two-read defect was itself a
        # two-read defect.
        #
        # The bytes are read once into memory, hashed FROM THAT BUFFER, and parsed FROM THAT
        # BUFFER. There is no second read to disagree with the first.
        $bytes = $null
        try {
            $bytes = [System.IO.File]::ReadAllBytes($SnapshotPath)
        } catch {
            return [pscustomobject]@{
                State = 'UNAVAILABLE'; Code = 'TOOL'; Document = $null
                Reason = "the validator accepted the snapshot but this reader could not read its bytes: $($_.Exception.Message)"
            }
        }
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { $mine = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLower() }
        finally { $sha.Dispose() }
        if ($mine -ne $claimed) {
            return [pscustomobject]@{
                State = 'UNAVAILABLE'; Code = 'TOOL'; Document = $null
                Reason = "the snapshot changed between being verified ($($claimed.Substring(0,12))) and being read ($($mine.Substring(0,12))) -- refusing to hand back bytes nothing checked"
            }
        }
        try {
            # From the SAME buffer that was hashed above, never from a fresh read of the path.
            # The UTF-8 BOM is stripped explicitly: ConvertFrom-Json chokes on it, and reaching
            # for Get-Content to avoid that is what re-opened the file in the first place.
            $text = [System.Text.Encoding]::UTF8.GetString($bytes)
            if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
            $doc = $text | ConvertFrom-Json
        } catch {
            # The validator read it and PowerShell could not. That is an instrument problem on
            # this side, not a verdict about the document, so it is UNAVAILABLE rather than
            # REFUSED -- and it is reported rather than swallowed.
            return [pscustomobject]@{
                State = 'UNAVAILABLE'; Code = 'TOOL'; Document = $null
                Reason = "the validator accepted the snapshot but PowerShell could not parse it: $($_.Exception.Message)"
            }
        }
        return [pscustomobject]@{ State = 'OK'; Code = 'OK'; Document = $doc; Reason = '' }
    }
    # exit 4 = MalformedDocument: unparseable bytes, or valid JSON that is not one of these
    # documents. "We have no coverage data." Kept DISTINCT from exit 1 because the fixes differ --
    # a truncated write versus somebody typing an answer into the verdict.
    if ($rc -eq 4) {
        return [pscustomobject]@{ State = 'REFUSED'; Code = 'MALFORMED'; Document = $null; Reason = $text }
    }
    # exit 1 = the document IS one of these and its own evidence refuses it.
    if ($rc -eq 1) {
        return [pscustomobject]@{ State = 'REFUSED'; Code = 'VERDICT'; Document = $null; Reason = $text }
    }
    # 3 = the validator's ToolFailure. 2 = its usage message. Anything else = it did not run at
    # all (a crashed interpreter, an import error). None of those are findings about the fleet.
    return [pscustomobject]@{
        State = 'UNAVAILABLE'; Code = 'TOOL'; Document = $null
        Reason = "the snapshot checker did not produce a verdict (exit $rc): $text"
    }
}


function Format-ControlRoomBlock {
    <#
      Renders the Control Room section of STATUS.md from a Get-VerifiedSnapshot result.

      It lives HERE and not inline in make_status.ps1 for one reason: make_status.ps1 takes no
      parameters and always reads the canonical path, so its three states could only be exercised
      by moving the real snapshot out of the way -- i.e. they would not have been exercised. This
      seam is what makes "REFUSED renders no numbers" a thing a fixture can prove.
      Cage: scripts\_test
un_snapshot_s4_tests.ps1.
    #>
    param([Parameter(Mandatory = $true)]$Verified)
    $out = @()
    if ($Verified.State -eq 'OK') {
      $m = $Verified.Document.meta
      $v = $Verified.Document.verdict
      $r = $m.reconciliation
      $out += "**Verified snapshot** - build ``$($m.build_id)`` - v$($m.version) - generated $($m.generated_at) - git ``$($m.git_head)``"
      $out += ""
      $out += "- reconciliation_clear: **$($v.reconciliation_clear)**"
      if (@($v.reasons).Count -gt 0) {
        $out += "- reasons (this is NOT a fleet-health verdict - it covers the order/coverage reconciliation and mandatory-source freshness only):"
        foreach ($rs in @($v.reasons)) { $out += "  - ``$($rs.code)`` $($rs.detail)" }
      }
      $out += "- orders discovered $($r.discovered) / categorized $($r.categorized) - unclassified $($r.unclassified) - duplicates $($r.duplicates) - conflicts $($r.conflicts)"
      $out += "- coverage cells $($r.coverage.cells_in_universe) = tested $($r.coverage.tested) + untested $($r.coverage.untested) + n/a $($r.coverage.not_applicable)"
      $out += "- mandatory sources: " + ((@($m.sources) | ForEach-Object { "$($_.name)=" + $(if ($_.read_ok) { if ($_.fresh) { 'fresh' } else { "stale($($_.age_hours)h)" } } else { 'UNREADABLE' }) }) -join ', ')
    } elseif ($Verified.State -eq 'REFUSED') {
      $out += "> :x: **SNAPSHOT REFUSED - no Control Room numbers are shown on this page.**"
      $out += ">"
      $out += "> The snapshot exists and ``snapshot_validator`` refused it (``$($Verified.Code)``). Rendering it"
      $out += "> anyway would produce a stale-but-pretty page, which is the failure this block exists to"
      $out += "> prevent. The daily monitoring chain fails hard on this same state."
      $out += ">"
      $out += "> ``$($Verified.Reason)``"
    } else {
      $out += "> :warning: **SNAPSHOT UNAVAILABLE - no Control Room numbers are shown on this page.**"
      $out += ">"
      $out += "> This is a statement about the INSTRUMENT (``$($Verified.Code)``), not about the fleet: either no"
      $out += "> snapshot has been built, or the checker could not run. It is not treated as a failure"
      $out += "> HERE because this page regenerates after every commit; the daily monitoring chain,"
      $out += "> whose job this actually is, returns a hard failure token for the same state."
      $out += ">"
      $out += "> ``$($Verified.Reason)``"
    }
    return $out
}
