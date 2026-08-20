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

<#
AUDIT C REPAIR (2026-08-20, lane M0-L1). Integrity is not freshness, and a digest recorded at
build time is not a digest that still holds.

  C-A1  MEASURED on canonical 649207d6: portfolio\control_room_snapshot.json was generated
        2026-08-16T20:17:59 -- 82.8 hours old against its OWN declared bar of 30 -- and
        Get-VerifiedSnapshot returned State=OK, so Format-ControlRoomBlock printed every
        reconciliation number plus "mandatory sources: ...=fresh". Those three words were TRUE
        WHEN WRITTEN and were being re-published three and a half days later as a present-tense
        claim. No new threshold is invented here: meta.stale_bar_hours is the snapshot's own
        bar, written by scripts\control_room_snapshot.ps1. An ABSENT or unusable bar is
        UNKNOWN -- a document that names no bar cannot be called fresh by the reader.

  C-A6  MEASURED on the same file: meta.sources[].sha256 is recorded by snapshot_build.py and
        NOTHING ever recomputed it. attestation_map (portfolio\ATTESTATION_MAP.csv) had ALREADY
        changed on disk (recorded a5278ffa282c, on disk d169e9403a74) while the snapshot still
        rendered it as read_ok=true / fresh. A digest nobody rechecks is a comment.

The three-state Document contract described above is UNCHANGED: State/Code remain statements
about the DOCUMENT'S OWN INTEGRITY, which is what snapshot_validator answers. Freshness and
source drift are separate questions, so they get separate fields plus ONE derived token that
readers switch on:

  Trust  'OK'          integrity OK, age within the document's own bar, and every recorded
                       source digest still matches the bytes on disk. The ONLY value that may
                       render a number.
         'STALE'       intact, but describing a world that has moved: older than its own bar,
                       age not establishable, or a recorded source changed / was never digested.
         'REFUSED'     unchanged.
         'UNAVAILABLE' unchanged, PLUS a source this reader could not read at all. An unreadable
                       input must refuse, never be skipped (memory:
                       unreadable-input-must-refuse-not-skip).

  Document is populated ONLY for Trust='OK'. A stale-but-intact document comes back under the
  deliberately awkward name UntrustedDocument, so every read of it is greppable and intentional.
  A caller that keeps doing `if (State -eq 'OK') { read Document }` therefore gets $null and
  fails closed WITHOUT being edited -- which is the whole reason the gate lives here.
#>

function Get-SnapshotAgeState {
    <#
      Age of a parsed snapshot against ITS OWN meta.stale_bar_hours. Never invents a bar.
        State 'FRESH' | 'STALE' | 'UNKNOWN'
      UNKNOWN is not a soft OK: it means the reader cannot bound the age, and the Trust mapping
      treats it exactly as harshly as STALE.
    #>
    param($Document, [datetime]$Now = (Get-Date))

    if ($null -eq $Document -or $null -eq $Document.meta) {
        return [pscustomobject]@{
            State = 'UNKNOWN'; AgeHours = $null; StaleBarHours = $null; GeneratedAt = $null
            Reason = 'the document carries no meta section, so its age cannot be bounded'
        }
    }
    $barRaw = "$($Document.meta.stale_bar_hours)"
    $bar = $null
    if ($barRaw -match '^[0-9]+(\.[0-9]+)?$' -and [double]$barRaw -gt 0) { $bar = [double]$barRaw }
    $genRaw = "$($Document.meta.generated_at)"
    $gen = [datetime]::MinValue
    $genOk = [datetime]::TryParse($genRaw, [ref]$gen)
    if ($null -eq $bar) {
        return [pscustomobject]@{
            State = 'UNKNOWN'; AgeHours = $null; StaleBarHours = $null
            GeneratedAt = $(if ($genOk) { $gen.ToString('s') } else { $null })
            Reason = "meta.stale_bar_hours is absent or unusable ('$barRaw'), so this snapshot names no freshness bar and cannot be called fresh"
        }
    }
    if (-not $genOk) {
        return [pscustomobject]@{
            State = 'UNKNOWN'; AgeHours = $null; StaleBarHours = $bar; GeneratedAt = $null
            Reason = "meta.generated_at is absent or unparseable ('$genRaw'), so the age of these numbers is unknown"
        }
    }
    $ageH = [math]::Round(($Now - $gen).TotalHours, 2)
    if ($ageH -lt -1) {
        # A snapshot from the future is a clock disagreement, not proof of freshness.
        return [pscustomobject]@{
            State = 'UNKNOWN'; AgeHours = $ageH; StaleBarHours = $bar; GeneratedAt = $gen.ToString('s')
            Reason = "meta.generated_at ($genRaw) is $([math]::Abs($ageH))h in the FUTURE -- a clock disagreement is not evidence of freshness"
        }
    }
    if ($ageH -gt $bar) {
        return [pscustomobject]@{
            State = 'STALE'; AgeHours = $ageH; StaleBarHours = $bar; GeneratedAt = $gen.ToString('s')
            Reason = "generated $genRaw = ${ageH}h ago, past this snapshot's own stale_bar_hours of $bar"
        }
    }
    return [pscustomobject]@{
        State = 'FRESH'; AgeHours = $ageH; StaleBarHours = $bar; GeneratedAt = $gen.ToString('s')
        Reason = ''
    }
}

function Get-SnapshotSourceIntegrity {
    <#
      RECOMPUTES the sha256 of every meta.sources[] entry against the bytes on disk now.
        State 'OK' | 'CHANGED' | 'UNREADABLE' | 'UNKNOWN'
      Checked  how many rows were actually digested. A 0 here means this check is INERT for this
               document, and it is reported as UNKNOWN, never as a pass.
    #>
    param($Document, [string]$RepoRoot)

    $rows = @()
    if ($null -ne $Document -and $null -ne $Document.meta) { $rows = @($Document.meta.sources) }
    if ($rows.Count -eq 0) {
        return [pscustomobject]@{
            State = 'UNKNOWN'; Checked = 0; Changed = @(); Unreadable = @(); Undigested = @()
            Reason = 'the document enumerates no meta.sources rows, so no recorded digest could be rechecked'
        }
    }
    $changed = New-Object System.Collections.Generic.List[string]
    $unreadable = New-Object System.Collections.Generic.List[string]
    $undigested = New-Object System.Collections.Generic.List[string]
    $checked = 0
    foreach ($s in $rows) {
        $name = "$($s.name)"
        if ($name -eq '') { $name = '(unnamed source)' }
        $rel = "$($s.path)"
        $claim = "$($s.sha256)".ToLower()
        if ($rel -eq '') { $undigested.Add("$name records no path") | Out-Null; continue }
        if ($claim -notmatch '^[0-9a-f]{64}$') {
            $undigested.Add("$name ($rel) carries no usable sha256, so nothing about it can be rechecked") | Out-Null
            continue
        }
        $p = if ([System.IO.Path]::IsPathRooted($rel)) { $rel } else { Join-Path $RepoRoot $rel }
        if (-not (Test-Path -LiteralPath $p)) {
            $unreadable.Add("$name is GONE from disk ($rel)") | Out-Null
            continue
        }
        $bytes = $null
        try { $bytes = [System.IO.File]::ReadAllBytes($p) }
        catch {
            $unreadable.Add("$name could not be read ($rel): $($_.Exception.Message)") | Out-Null
            continue
        }
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { $mine = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLower() }
        finally { $sha.Dispose() }
        $checked++
        if ($mine -ne $claim) {
            $changed.Add("$name changed since this snapshot was built (recorded $($claim.Substring(0,12)), on disk $($mine.Substring(0,12)))") | Out-Null
        }
    }
    $state = 'OK'
    if ($unreadable.Count -gt 0)  { $state = 'UNREADABLE' }
    elseif ($changed.Count -gt 0) { $state = 'CHANGED' }
    elseif ($checked -eq 0)       { $state = 'UNKNOWN' }
    $parts = @()
    if ($unreadable.Count -gt 0) { $parts += ($unreadable -join '; ') }
    if ($changed.Count -gt 0)    { $parts += ($changed -join '; ') }
    if ($undigested.Count -gt 0) { $parts += ($undigested -join '; ') }
    if ($checked -eq 0 -and $parts.Count -eq 0) { $parts += 'no source row could be digested at all' }
    return [pscustomobject]@{
        State = $state; Checked = $checked
        Changed = $changed.ToArray(); Unreadable = $unreadable.ToArray(); Undigested = $undigested.ToArray()
        Reason = ($parts -join ' | ')
    }
}

function Get-VerifiedSnapshot {
    <#
      Integrity (from Get-VerifiedSnapshotDocument, whose contract is unchanged) PLUS the
      freshness and source-drift gates. See the AUDIT C REPAIR block above.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SnapshotPath,
        [string]$RepoRoot = ''
    )
    if (-not $RepoRoot) { $RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSScriptRoot }
    $v = Get-VerifiedSnapshotDocument -SnapshotPath $SnapshotPath -RepoRoot $RepoRoot

    if ($v.State -ne 'OK') {
        return [pscustomobject]@{
            State = $v.State; Code = $v.Code; Document = $null; UntrustedDocument = $null
            Trust = $v.State; Reason = $v.Reason
            Age = (Get-SnapshotAgeState -Document $null)
            SourceIntegrity = (Get-SnapshotSourceIntegrity -Document $null -RepoRoot $RepoRoot)
        }
    }

    $age = Get-SnapshotAgeState -Document $v.Document
    $src = Get-SnapshotSourceIntegrity -Document $v.Document -RepoRoot $RepoRoot
    $trust = 'OK'
    $reasons = @()
    if ($src.State -eq 'UNREADABLE') {
        $trust = 'UNAVAILABLE'
        $reasons += "a recorded source could not be read: $($src.Reason)"
    } elseif ($src.State -ne 'OK') {
        $trust = 'STALE'
        $reasons += "source drift ($($src.State)): $($src.Reason)"
    }
    if ($age.State -ne 'FRESH') {
        if ($trust -eq 'OK') { $trust = 'STALE' }
        $reasons += "age $($age.State): $($age.Reason)"
    }
    if ($trust -eq 'OK') {
        return [pscustomobject]@{
            State = 'OK'; Code = 'OK'; Document = $v.Document; UntrustedDocument = $null
            Trust = 'OK'; Reason = ''
            Age = $age; SourceIntegrity = $src
        }
    }
    # Document is deliberately $null here.
    return [pscustomobject]@{
        State = 'OK'; Code = 'OK'; Document = $null; UntrustedDocument = $v.Document
        Trust = $trust; Reason = ($reasons -join ' | ')
        Age = $age; SourceIntegrity = $src
    }
}

function Get-VerifiedSnapshotDocument {
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


function Resolve-SnapshotTrustToken {
    <#
      The ONE place a renderer turns a Get-VerifiedSnapshot result into a render decision.

      FAIL-CLOSED ON AN UNDECORATED OBJECT, and that is the load-bearing part: a caller that
      hand-builds a result object (or an older caller that predates the Trust field) gets
      'UNAVAILABLE', never 'OK'. A gate whose default is "render the numbers" is not a gate.
    #>
    param($Verified)
    if ($null -eq $Verified) { return 'UNAVAILABLE' }
    $hasTrust = $null -ne $Verified.PSObject.Properties['Trust']
    if ($hasTrust) {
        $t = "$($Verified.Trust)"
        if ($t -in @('OK','STALE','REFUSED','UNAVAILABLE')) { return $t }
    }
    if ("$($Verified.State)" -eq 'REFUSED') { return 'REFUSED' }
    return 'UNAVAILABLE'
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
    $trust = Resolve-SnapshotTrustToken $Verified
    if ($trust -eq 'OK') {
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
      # AUDIT C (C-A1/C-A6): the source states below are the BUILD-TIME record, so they are
      # labelled as such, and the reader's own RE-CHECK is printed next to them. Without that
      # second line "sources: x=fresh" reads as a present-tense claim about a file the reader
      # never looked at -- which is exactly what it was.
      $out += "- mandatory sources (as recorded AT BUILD TIME): " + ((@($m.sources) | ForEach-Object { "$($_.name)=" + $(if ($_.read_ok) { if ($_.fresh) { 'fresh' } else { "stale($($_.age_hours)h)" } } else { 'UNREADABLE' }) }) -join ', ')
      $out += "- reader re-check NOW: age $($Verified.Age.AgeHours)h vs bar $($Verified.Age.StaleBarHours)h = **$($Verified.Age.State)** - source digests recomputed $($Verified.SourceIntegrity.Checked)/$(@($m.sources).Count), drift **$($Verified.SourceIntegrity.State)**"
    } elseif ($trust -eq 'STALE') {
      # C-A1/C-A6. Intact, and therefore the most dangerous state there is: every number in it
      # would render perfectly. NONE of them are shown.
      $out += "> :hourglass: **SNAPSHOT STALE - no Control Room numbers are shown on this page.**"
      $out += ">"
      $out += "> The document is internally valid, so it would render cleanly. That is precisely why it"
      $out += "> is withheld: it describes a world that has moved. Freshness is measured against the"
      $out += "> snapshot's OWN ``meta.stale_bar_hours``, and every source digest it recorded is"
      $out += "> recomputed against the bytes on disk now. Rebuild it with"
      $out += "> ``scripts\control_room_snapshot.ps1`` before trusting any figure."
      $out += ">"
      $out += "> age: $($Verified.Age.AgeHours)h vs bar $($Verified.Age.StaleBarHours)h = ``$($Verified.Age.State)`` - source drift ``$($Verified.SourceIntegrity.State)`` ($($Verified.SourceIntegrity.Checked) digest(s) rechecked)"
      $out += ">"
      $out += "> ``$($Verified.Reason)``"
    } elseif ($trust -eq 'REFUSED') {
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


function Format-ControlRoomHtml {
    <#
      HTML twin of Format-ControlRoomBlock, for STATUS.html (scripts\make_status_html.ps1).

      WHY THIS EXISTS. STATUS.html is the OneDrive-synced, phone-read mobile dashboard (its own
      header says so: "regenerate every commit"; make_status_html.ps1 is the ONLY writer). Until
      this function, it was generated from PROJECT_STATE.md / DEMO_DEPLOYMENT_PLAN.md / taskboard
      files ONLY -- scripts\status_template.html had zero mention of "Control Room", "snapshot", or
      "DEGRADED" anywhere in it (grepped, ORDER: monitoring-status-audit). So the one artifact this
      repo's own workflow describes as the owner's daily phone read was silently the ONE consumer
      that never rendered the verified-snapshot machinery snapshot_reader.ps1 exists to protect --
      while STATUS.md (the markdown twin, same generator, same commit) rendered it correctly. A
      reader who only opens the phone page could not see WHY monitoring is DEGRADED_MONITORING, or
      that it is degraded at all: the page showed order/EA counts with no Control Room section at
      all, not even a blank one.

      This mirrors Format-ControlRoomBlock's three-state contract exactly (same function, same
      inputs, only the sink differs) so the same C6 guarantee holds here: NEITHER RENDERER EVER
      EMITS A NUMBER FROM AN UNVERIFIED SNAPSHOT. OK renders counts; REFUSED and UNAVAILABLE render
      a banner with the reason text and nothing else -- HTML-escaped, since Reason strings can carry
      arbitrary text (a validator error message, a file path) and this sink is a browser.

      Cage: scripts\_test
un_snapshot_s4_tests.ps1 (same fixtures as Format-ControlRoomBlock's C6 block).
    #>
    param([Parameter(Mandatory = $true)]$Verified)

    function _Esc([string]$s) {
        if ($null -eq $s) { return '' }
        return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
    }

    $trust = Resolve-SnapshotTrustToken $Verified
    if ($trust -eq 'OK') {
        $m = $Verified.Document.meta
        $v = $Verified.Document.verdict
        $r = $m.reconciliation
        $reasonsHtml = ''
        if (@($v.reasons).Count -gt 0) {
            $items = (@($v.reasons) | ForEach-Object { "<li><span class='mono'>$(_Esc $_.code)</span> $(_Esc $_.detail)</li>" }) -join "`n"
            $reasonsHtml = "<div class='note'>reasons (not a fleet-health verdict - order/coverage reconciliation and mandatory-source freshness only):</div><ul>$items</ul>"
        }
        $sourcesHtml = (@($m.sources) | ForEach-Object {
            $state = if ($_.read_ok) { if ($_.fresh) { 'fresh' } else { "stale($($_.age_hours)h)" } } else { 'UNREADABLE' }
            $cls = if ($state -eq 'fresh') { 't-live' } elseif ($state -eq 'UNREADABLE') { 't-user' } else { 't-watch' }
            "<span class='tag $cls'>$(_Esc $_.name)=$(_Esc $state)</span>"
        }) -join ' '
        $clearTag = if ($v.reconciliation_clear) { "<span class='tag t-live'>CLEAR</span>" } else { "<span class='tag t-user'>NOT CLEAR</span>" }
        return @"
<div class="note">Verified snapshot - build <span class="mono">$(_Esc $m.build_id)</span> - v$(_Esc $m.version) - generated $(_Esc $m.generated_at) - git <span class="mono">$(_Esc $m.git_head)</span></div>
<div style="margin:8px 0">reconciliation_clear: $clearTag</div>
$reasonsHtml
<div class="note">orders discovered $(_Esc $r.discovered) / categorized $(_Esc $r.categorized) - unclassified $(_Esc $r.unclassified) - duplicates $(_Esc $r.duplicates) - conflicts $(_Esc $r.conflicts)</div>
<div class="note">coverage cells $(_Esc $r.coverage.cells_in_universe) = tested $(_Esc $r.coverage.tested) + untested $(_Esc $r.coverage.untested) + n/a $(_Esc $r.coverage.not_applicable)</div>
<div class="note">mandatory sources AS RECORDED AT BUILD TIME: $sourcesHtml</div>
<div class="note">reader re-check NOW: age $(_Esc $Verified.Age.AgeHours)h vs bar $(_Esc $Verified.Age.StaleBarHours)h = <b>$(_Esc $Verified.Age.State)</b> &middot; source digests recomputed $(_Esc $Verified.SourceIntegrity.Checked), drift <b>$(_Esc $Verified.SourceIntegrity.State)</b></div>
"@
    } elseif ($trust -eq 'STALE') {
        return @"
<div class="todo"><span class="dot" style="color:var(--amber)">&#9679;</span><div><b>SNAPSHOT STALE</b> - no Control Room numbers are shown on this page.<br>The document is internally valid, so it would render cleanly - which is exactly why it is withheld: it describes a world that has moved. Age is measured against the snapshot's OWN <span class="mono">meta.stale_bar_hours</span>, and every source digest it recorded is recomputed against the bytes on disk now. Rebuild with <span class="mono">scripts\control_room_snapshot.ps1</span> before trusting any figure.<br>age $(_Esc $Verified.Age.AgeHours)h vs bar $(_Esc $Verified.Age.StaleBarHours)h = <span class="mono">$(_Esc $Verified.Age.State)</span> &middot; source drift <span class="mono">$(_Esc $Verified.SourceIntegrity.State)</span> ($(_Esc $Verified.SourceIntegrity.Checked) digest(s) rechecked)<br><span class="mono">$(_Esc $Verified.Reason)</span></div></div>
"@
    } elseif ($trust -eq 'REFUSED') {
        return @"
<div class="todo"><span class="dot">&#9679;</span><div><b>SNAPSHOT REFUSED</b> - no Control Room numbers are shown on this page.<br>The snapshot exists and <span class="mono">snapshot_validator</span> refused it (<span class="mono">$(_Esc $Verified.Code)</span>). Rendering it anyway would produce a stale-but-pretty page, which is the failure this block exists to prevent. The daily monitoring chain fails hard on this same state.<br><span class="mono">$(_Esc $Verified.Reason)</span></div></div>
"@
    } else {
        return @"
<div class="todo"><span class="dot" style="color:var(--amber)">&#9679;</span><div><b>SNAPSHOT UNAVAILABLE</b> - no Control Room numbers are shown on this page.<br>This is a statement about the INSTRUMENT (<span class="mono">$(_Esc $Verified.Code)</span>), not about the fleet: either no snapshot has been built, or the checker could not run. It is not treated as a failure HERE because this page regenerates after every commit; the daily monitoring chain, whose job this actually is, returns a hard failure token for the same state.<br><span class="mono">$(_Esc $Verified.Reason)</span></div></div>
"@
    }
}
