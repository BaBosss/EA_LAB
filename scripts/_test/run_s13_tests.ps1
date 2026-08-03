<#
run_s13_tests.ps1 -- ORDER-1210 (slice S13).

Drives the cage for _triage/factory_os/check_pilot_acceptance.py, which turns design section 8.6
-- "the pass/fail for the whole Stage-4 pilot" -- from fourteen markdown tickboxes into a
mechanical verdict about EVIDENCE COMPLETENESS.

WHAT THE CAGE IS FOR, stated here because the suite's shape only makes sense with it: the checker's
commonest answer today is BLOCKED (most of the pilot has not been run). A reporter whose usual
output is "not yet" is trivially green and would keep saying "not yet" long after the mechanism
under it had rotted. So the cases attack the three ways it could be wrong -- the checklist and the
handlers drifting apart, BLOCKED quietly satisfying the roll-up, and the process dying with its
reason swallowed -- rather than the one way it is right.

🚫 design section 10 stops this slice's automation at EVIDENCE_COMPLETE. PART 4 of the suite
asserts the checker emits no verdict vocabulary, and drives a handler that WOULD emit one to prove
the detector fires.

ASCII-only (Windows PowerShell 5.1 decodes a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_s13_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$python = Join-Path $RepoRoot 'tools\python312\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    # A missing interpreter is a FAILURE, not a skip. A cage that silently opts out when its tool
    # is absent is the defect class this repo has hit five times.
    Write-Host "[s13] FAIL: interpreter not found at $python" -ForegroundColor Red
    exit 1
}

# 🔴 REQUIRED, and it is not boilerplate. design 8.6's own wording carries `section`, `<=` and `.`
# as non-ASCII glyphs, and this suite PRINTS the checklist. python takes its stdout encoding from
# the console codepage, so a child of the pre-commit hook gets an ANSI-codepage pipe and the first
# such character raises UnicodeEncodeError -- which the tier surfaces as `exit -1 SUITE THREW`
# with the cause swallowed. It took down S11's suite latently for as long as that suite existed
# (memory `thai-output-kills-a-suite-inside-the-hook`). Reproduce the failure with `chcp 1252`.
# The module ALSO reconfigures its own streams; both are kept, because this wrapper is not the
# only caller and the module is not the only thing that prints.
$prevEnc = $env:PYTHONIOENCODING
$env:PYTHONIOENCODING = 'utf-8'
try {
    $out = & $python (Join-Path $RepoRoot '_triage\factory_os\run_s13_tests.py') 2>&1
    $rc = $LASTEXITCODE
    Write-Host ($out | Out-String).TrimEnd()
    if ($rc -ne 0) {
        Write-Host "[s13] FAIL: the S13 cage exited $rc" -ForegroundColor Red
        exit 1
    }

    # ...and DRIVE the real checker over the real repository, which the cage above deliberately
    # does not do (its fixtures are synthetic so it stays green whatever the pilot's state
    # becomes). This half asserts the checker can still RUN end-to-end against committed
    # evidence -- a module that only works on fixtures is the `pure-cage-proves-only-the-pure-half`
    # shape, and 9 of 9 defects in that memory lived in the half the pure cage could not reach.
    #
    # Exit codes: 0 EVIDENCE_COMPLETE - 1 at least one item FAIL - 2 the checker could not answer
    # - 3 blocked only. Only 2 is a failure OF THIS SUITE: 1 and 3 are the checker working and
    # reporting honestly about a pilot that has not been run. Treating 1 or 3 as red here would
    # make this cage go permanently red for a true report, which is how a suite earns being
    # switched off.
    $real = & $python (Join-Path $RepoRoot '_triage\factory_os\check_pilot_acceptance.py') 2>&1
    $realRc = $LASTEXITCODE
    $realText = ($real | Out-String)
    if ($realRc -eq 2) {
        Write-Host '[s13] FAIL: check_pilot_acceptance REFUSED against the real repository --' -ForegroundColor Red
        Write-Host '       the checklist binding or an input read is broken. This is a defect in' -ForegroundColor Red
        Write-Host '       the checker, NOT a statement about the pilot.' -ForegroundColor Red
        Write-Host $realText.TrimEnd()
        exit 1
    }
    if ($realRc -notin @(0, 1, 3)) {
        Write-Host "[s13] FAIL: check_pilot_acceptance returned an undeclared exit code $realRc" -ForegroundColor Red
        exit 1
    }
    # The marker proves WHICH BYTES were judged, and the tier verifies it per suite.
    if ($realText -notmatch '##EVIDENCE-MODE## check_pilot_acceptance ') {
        Write-Host '[s13] FAIL: the real run emitted no evidence-mode marker' -ForegroundColor Red
        exit 1
    }
    # The roll-up line must always be present -- a run that printed items and then died before
    # summarising is the "guard reports nothing" shape, and it would otherwise look like a pass.
    if ($realText -notmatch '\[pilot-acceptance\] \d+ item\(s\):') {
        Write-Host '[s13] FAIL: the real run printed no roll-up line' -ForegroundColor Red
        Write-Host $realText.TrimEnd()
        exit 1
    }
    # @() IS LOAD-BEARING. A Where-Object yielding exactly ONE line returns a bare [string], and
    # `[0]` then indexes into that STRING and hands back a [char] -- which has no .Trim(). This
    # line threw on its first run for precisely that reason. Same family as memory
    # `powershell-pipeline-count-null-on-single-result`, and it is always one match here, so the
    # unwrapped form would have failed every single time rather than intermittently.
    $summary = @($realText -split "`n" | Where-Object { $_ -match '\[pilot-acceptance\] \d+ item' })[0]
    Write-Host ''
    Write-Host ('[s13] real repository: ' + $summary.Trim())
    Write-Host '[s13] S13 cage green; the 8.6 checklist is derived from the design, not restated here'
    exit 0
} finally {
    if ($null -eq $prevEnc) { Remove-Item Env:PYTHONIOENCODING -ErrorAction SilentlyContinue }
    else { $env:PYTHONIOENCODING = $prevEnc }
}
