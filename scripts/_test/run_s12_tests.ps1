<#
run_s12_tests.ps1 - ORDER-1180 (slice S12), wrapping the cage for the direct Telegram sender.

WHAT IT GUARDS. _triage\factory_os\notifier.py -- the local/sender seam, the dedupe key, the
per-channel delivery ledger, the recovery rule (borrowed from control_center.fold_finding, never
copied) and the FLAPPING reminder. The python suite drives all of it in one process against
fixtures, plus three subprocesses for the one claim in-process code cannot honestly make: that
the ledger stops a second send ACROSS PROCESS BOUNDARIES.

WHAT THIS FILE ADDS ON TOP OF THE PYTHON. Two claims that live outside python entirely:

  B1  THE TOKEN IS NOT IN THE REPOSITORY. design 10's prohibition for this slice is "no token in
      git / logs / generated HTML / chat". A python suite can assert what notifier.py writes; it
      cannot assert what git TRACKS. So this asks git directly whether scripts\config.yaml is
      ignored, and greps the tracked tree for a Telegram token shape. A prohibition nobody can
      check is a sentence.

  B2  THE RUNTIME STATE IS NOT IN THE REPOSITORY EITHER. ops\ is per-machine append-only
      evidence; committing it would put a scheduled writer on master, which is a lane the commit
      guards cannot see (memory: negative-claims-over-a-commit-range).

  WHY NOT AN END-TO-END SEND HERE. Because a suite that sends a real Telegram message every time
  the fast tier runs would train its operator to ignore it, and design 10 forbids sending
  without the owner's go-ahead. The real leg was driven ONCE, by hand, in the lane that built
  this -- receipt recorded in ops\delivery_ledger.jsonl and quoted in ORDER-1180.

MEASURED three times, not once, per memory phantom-regression-from-two-single-samples. The
numbers are in run_fast_cages.ps1's registration comment, where the tier's budget argument lives.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_s12_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py    = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite = Join-Path $RepoRoot '_triage\factory_os\run_s12_tests.py'

if (-not (Test-Path -LiteralPath $py))    { Write-Host "[s12] FAIL: interpreter not found at $py" -ForegroundColor Red; exit 2 }
# A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0.
if (-not (Test-Path -LiteralPath $suite)) { Write-Host "[s12] FAIL: suite not found at $suite" -ForegroundColor Red; exit 2 }

# ---------------------------------------------------------------------------------------
# PART A -- the python cage
# ---------------------------------------------------------------------------------------
# PIN THE CHILD'S OUTPUT ENCODING. Every message in this repo is Thai, and python takes its
# stdout encoding from the console codepage: interactively that is UTF-8, but a child of the
# pre-commit hook gets a pipe under the ANSI codepage, where the first Thai character raises
# UnicodeEncodeError. The traceback lands on stderr, and `2>&1` below under
# $ErrorActionPreference='Stop' turns any stderr line into a TERMINATING error -- so the tier
# reports `exit -1  SUITE THREW` and the actual cause never appears. Both this suite and S11's
# failed exactly that way inside a real commit while passing every interactive run.
# The projection is a derived build artifact, not a tracked input.  The four end-to-end cases
# below deliberately drive the sender against the REAL repository and its generated projection;
# a clean staged snapshot therefore has to build the same artifact before the Python cage starts.
# Run the production builder so snapshot validation, shape checks, and fail-closed projection
# validation remain in force.  This also makes the fixture independent of a stale ignored file in
# whichever checkout happened to launch the tier.
$safeProjection = Join-Path $RepoRoot '_triage\factory_os\safe_projection.py'
$buildOutput = & $py $safeProjection build --repo-root $RepoRoot 2>&1
$buildCode = $LASTEXITCODE
$buildOutput | ForEach-Object { Write-Host $_ }
if ($buildCode -ne 0) {
    Write-Host "[s12] FAIL: safe projection fixture could not be built (exit $buildCode)" -ForegroundColor Red
    exit 1
}

$env:PYTHONIOENCODING = 'utf-8'
$out  = & $py $suite 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }
if ($code -ne 0) { Write-Host "[s12] the S12 cage FAILED (exit $code)" -ForegroundColor Red; exit 1 }

# Assert the COMPLETENESS half actually ran. A green run whose roll-ups quietly stopped being
# computed proves less than yesterday's and says nothing in its exit code.
$joined = ($out -join "`n")
if ($joined -notmatch 'scenario\(s\), 0 failed, 0 roll-up problem\(s\)') {
    Write-Host "[s12] FAIL: the run never printed its roll-up line, so its claims rest on whatever subset happened to run" -ForegroundColor Red
    exit 1
}
# The four acceptance cases, by name. If any of them stops running, the suite can still be green
# while the acceptance it exists for is no longer measured.
foreach ($needle in @('D02', 'L10', 'V01', 'W05', 'C06', 'O05')) {
    if ($joined -notmatch ("\s" + [regex]::Escape($needle) + "\s")) {
        Write-Host "[s12] FAIL: case $needle did not appear in the run" -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------------------------------
# PART B -- the prohibitions, asked of git rather than of python
# ---------------------------------------------------------------------------------------
$partB = 0
$partBFail = 0
function B($label, $cond, $detail) {
    $script:partB++
    if ($cond) { Write-Host "  [OK ] $label" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $label" -ForegroundColor Red; if ($detail) { Write-Host "        -> $detail" -ForegroundColor Red }; $script:partBFail++ }
}

Write-Host ''
Write-Host 'PART B -- design 10 prohibitions, asked of git'

# NO `2>$null` ON ANY NATIVE COMMAND BELOW. Windows PowerShell 5.1 wraps a redirected native
# stderr line in an ErrorRecord, which under `$ErrorActionPreference = 'Stop'` THROWS -- so the
# checks would die on the very condition they exist to report. This cost one red run of this
# file. Every call below is chosen to signal through its exit code or its stdout instead.
Push-Location $RepoRoot
try {
    # B1a scripts\config.yaml holds the real token and must be ignored by git. `git check-ignore`
    #     answers about the RULES, so this is true whether or not the file exists right now.
    & git check-ignore -q 'scripts/config.yaml'
    B 'B1a git ignores scripts/config.yaml (where both bot tokens live)' ($LASTEXITCODE -eq 0) "check-ignore exit $LASTEXITCODE"

    # B1b ...and it is not tracked anyway. `check-ignore` says nothing about a file that was
    #     committed BEFORE the rule existed, which is exactly how a token gets into history.
    #     `ls-files` without --error-unmatch prints nothing and exits 0 for an untracked path.
    $tracked = @(& git ls-files -- 'scripts/config.yaml')
    B 'B1b ...and it is not TRACKED (a rule added after a commit does not un-commit it)' `
      ($tracked.Count -eq 0) "tracked as: $($tracked -join ',')"

    # B1c no Telegram token SHAPE anywhere in the tracked tree. The example file carries a
    #     placeholder, which does not match this pattern -- and a match here is a real incident.
    #     The three exclusions are THIS suite's own fixture, the regex that defines the shape,
    #     and the schema that documents it: a closed, named list, not a pattern.
    #     `:!_triage/...` is a FATAL pathspec error, not an exclusion: git reads the `_` after
    #     `!` as pathspec magic. It cost a green B1c over a git that had died before searching
    #     anything -- a guard reporting CLEAN because its instrument failed, which is the single
    #     most repeated defect in this repo. B3b below is the control that now catches it.
    # A CLOSED DECLARATION with a COUNT, not an exclusion pattern. Excluding a file outright
    # disarms this check for that file forever; declaring "this file has exactly N known hits,
    # for this reason" keeps it armed against the N+1th. Anything in a file not named here is a
    # failure, and so is one more hit in a file that is.
    #   run_s12_tests.ps1 / run_s12_tests.py  this suite's own fixtures and this pattern itself
    #   safe_projection.py / schemas.json     where the shape is DEFINED and documented
    #   run_s11_tests.py                      S11's planted token fixture (1)
    #   _triage/FXDREEMA_XRAY.md              FOUND BY THIS CHECK 2026-08-02, REDACTED 2026-08-03
    #     (ORDER-1200, owner-ratified). A THIRD PARTY's live-shaped Telegram bot token and the
    #     chat id beside it, committed inside the x-ray of a downloaded fxDreema EA. Not this
    #     project's credential and nothing here ever used it. Both VALUES removed at HEAD; the
    #     input NAMES stay, because "this EA ships a hardcoded Telegram bot" is the analytical
    #     fact the x-ray exists to record. History was NOT rewritten: this repo pins blob ids in
    #     OwnerRef and in the S2a attestation, and a rewrite would point every one of them at a
    #     blob that no longer exists.
    #     The entry stays here at **0**, deliberately, and that is the whole point of declaring a
    #     COUNT rather than an exclusion: the file is still watched, so a credential reappearing
    #     in it fails this check instead of being silently permitted by an old exemption.
    $KNOWN = @{
        'scripts/_test/run_s12_tests.ps1'       = 99
        '_triage/factory_os/run_s12_tests.py'   = 99
        '_triage/factory_os/safe_projection.py' = 99
        '_triage/factory_os/schemas.json'       = 99
        '_triage/factory_os/run_s11_tests.py'   = 1
        '_triage/FXDREEMA_XRAY.md'              = 0
    }
    $counts = @(& git grep -I -c -E '[0-9]{6,}:[A-Za-z0-9_-]{30,}' -- ':(exclude)*.jsonl' ':(exclude)_triage/chatgpt_convs/*')
    $bad = @()
    foreach ($row in $counts) {
        if (-not $row) { continue }
        $i = $row.LastIndexOf(':')
        $path = $row.Substring(0, $i); $n = [int]$row.Substring($i + 1)
        if (-not $KNOWN.ContainsKey($path)) { $bad += "$path ($n hit(s), NOT declared)" }
        elseif ($n -gt $KNOWN[$path])       { $bad += "$path ($n hit(s), declared $($KNOWN[$path]))" }
    }
    B 'B1c no UNDECLARED Telegram bot-token shape in any tracked file' ($bad.Count -eq 0) ($bad -join ' | ')

    # B2  the per-machine ledger and journal stay out of the repository.
    & git check-ignore -q 'ops/delivery_ledger.jsonl'
    B 'B2 git ignores ops/ (the delivery ledger and the finding journal)' ($LASTEXITCODE -eq 0) "check-ignore exit $LASTEXITCODE"

    # B3  THE CONTROL. B1c only means something if that grep can actually find a token shape.
    #     A search that cannot match anything reports CLEAN forever.
    $probe = Join-Path ([System.IO.Path]::GetTempPath()) ("s12_" + [guid]::NewGuid().ToString('N') + '.txt')
    [IO.File]::WriteAllText($probe, "bot 7788990011:AAHfakefakefakefakefakefakefakefake12`n", (New-Object System.Text.UTF8Encoding $false))
    $selfTest = @(Select-String -LiteralPath $probe -Pattern '[0-9]{6,}:[A-Za-z0-9_-]{30,}')
    Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    B 'B3a CONTROL the token-shape pattern really matches a token (the REGEX can fail)' ($selfTest.Count -eq 1) "matched $($selfTest.Count)"

    # B3b THE OTHER CONTROL, and the one that was missing. B3a proves the PATTERN works; it says
    #     nothing about whether the `git grep` INVOCATION above ran at all. It did not: a fatal
    #     pathspec error produced zero output and B1c reported CLEAN. So drive the identical
    #     invocation with a string that is certainly in the tracked tree and require a hit.
    $probeHits = @(& git grep -I -n -E 'PLACEHOLDER_TELEGRAM_BOT_TOKEN' -- ':(exclude)*.jsonl' ':(exclude)_triage/chatgpt_convs/*')
    B 'B3b CONTROL the same git grep INVOCATION really searches (a dead git reports CLEAN)' `
      ($probeHits.Count -ge 1) "the invocation returned $($probeHits.Count) hit(s) for a string that is definitely tracked"
} finally {
    Pop-Location
}

if ($partBFail -gt 0) {
    Write-Host "[s12] PART B: $partBFail of $partB check(s) FAILED -- a design 10 prohibition is not holding" -ForegroundColor Red
    exit 1
}
Write-Host "[s12] S12 cage green; $partB prohibition check(s) driven against git" -ForegroundColor Green
exit 0
